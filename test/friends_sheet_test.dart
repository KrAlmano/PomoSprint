import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/theme.dart';

import 'support/fake_supabase_service.dart';

/// Arkadaş sayfasının kullandığı RPC'lerin sahtesi. Yanıtlar canlı
/// sunucunun biçimindedir: makine-okunur 'code' alanı yok, yalnızca
/// {success, message} (t3-F13d).
class _FriendsFake extends FakeSupabaseService {
  List<Map<String, dynamic>> pending = [
    {
      'id': 'a-1',
      'name': 'Ali',
      'avatar_id': 'avatar_16_basic',
      'lifetime_points': 0,
      'total_minutes': 0,
    },
  ];
  Map<String, dynamic> respondResult = const {'success': true};
  Map<String, dynamic> addResult = const {'success': true};
  int pendingFetches = 0;

  @override
  Future<String?> getMyFriendCode() async => 'ABC123';

  @override
  Future<List<Map<String, dynamic>>> fetchFriends() async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchPendingFriendRequests() async {
    pendingFetches++;
    return List.of(pending);
  }

  @override
  Future<Map<String, dynamic>> respondToFriendRequest(
    String fromUserId,
    bool accept,
  ) async => respondResult;

  @override
  Future<Map<String, dynamic>> addFriendByCode(String code) async => addResult;
}

Future<AppLocalizations> _pump(
  WidgetTester tester,
  _FriendsFake service, {
  Locale locale = const Locale('tr'),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FriendsSheet(service: service)),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(locale);
}

void main() {
  testWidgets(
    'bayat istek ("Bekleyen bir istek bulunamadı."): "geçerli değil" denir ve liste tazelenir',
    (tester) async {
      final service = _FriendsFake();
      final l10n = await _pump(tester, service);
      expect(find.text('Ali'), findsOneWidget);
      final fetchesBefore = service.pendingFetches;

      // Başka cihazdan kabul edildi / gönderen hesabını sildi.
      service.respondResult = const {
        'success': false,
        'message': 'Bekleyen bir istek bulunamadı.',
      };
      service.pending = [];
      await tester.tap(find.byTooltip(l10n.friendsAccept));
      await tester.pumpAndSettle();

      expect(find.text(l10n.friendsRequestGone), findsOneWidget);
      expect(find.text(l10n.friendsRespondFailed), findsNothing);
      expect(service.pendingFetches, greaterThan(fetchesBefore));
      expect(find.text('Ali'), findsNothing, reason: 'bayat kart kalmaz');
    },
  );

  testWidgets('başka bir ret de listeyi tazeler (kart takılı kalmaz)', (
    tester,
  ) async {
    final service = _FriendsFake();
    final l10n = await _pump(tester, service);
    final fetchesBefore = service.pendingFetches;
    service.respondResult = const {
      'success': false,
      'message': 'Beklenmeyen durum.',
    };
    await tester.tap(find.byTooltip(l10n.friendsReject));
    await tester.pumpAndSettle();
    expect(find.text(l10n.friendsRespondFailed), findsOneWidget);
    expect(service.pendingFetches, greaterThan(fetchesBefore));
  });

  group(
    'İngilizce arayüzde ekleme hataları sunucunun Türkçe mesajından yerelleştirilir',
    () {
      final cases = <String, String Function(AppLocalizations)>{
        'Bu kod ile bir kullanıcı bulunamadı.': (l) => l.friendsErrNotFound,
        'Kendini arkadaş olarak ekleyemezsin.': (l) => l.friendsErrSelf,
        'Bu kullanıcı zaten arkadaşın.': (l) => l.friendsErrAlreadyFriends,
        'Bu kullanıcıya zaten istek gönderdin.': (l) =>
            l.friendsErrAlreadyPending,
      };
      for (final MapEntry(key: message, value: expected) in cases.entries) {
        testWidgets(message, (tester) async {
          final service = _FriendsFake()
            ..addResult = {'success': false, 'message': message};
          final l10n = await _pump(tester, service, locale: const Locale('en'));
          await tester.enterText(find.byType(TextField), 'XYZ789');
          await tester.tap(find.text(l10n.addBtn));
          await tester.pumpAndSettle();
          expect(find.text(expected(l10n)), findsOneWidget);
          expect(find.text(l10n.friendsErrAddFailed), findsNothing);
        });
      }
    },
  );

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets(
      'unknown server messages never leak into ${locale.languageCode} UI',
      (tester) async {
        const rawMessage =
            'internal database error: private implementation details';
        final service = _FriendsFake()
          ..addResult = const {
            'success': false,
            'code': 'unknown',
            'message': rawMessage,
          };
        final l10n = await _pump(tester, service, locale: locale);
        await tester.enterText(find.byType(TextField), 'XYZ789');
        await tester.tap(find.text(l10n.addBtn));
        await tester.pumpAndSettle();
        expect(find.text(l10n.friendsErrAddFailed), findsOneWidget);
        expect(find.text(rawMessage), findsNothing);
      },
    );
  }

  test(
    'friendResponseCode: makine-okunur kod varsa o, yoksa canlı mesajdan çıkarılır',
    () {
      expect(
        friendResponseCode(const {
          'success': false,
          'code': 'already_pending',
          'message': 'x',
        }),
        'already_pending',
      );
      expect(
        friendResponseCode(const {
          'success': false,
          'message': 'Bekleyen bir istek bulunamadı.',
        }),
        'not_found',
      );
      expect(
        friendResponseCode(const {
          'success': false,
          'message': 'Yeni bir hata',
        }),
        isNull,
      );
      expect(friendResponseCode(null), isNull);
    },
  );
}
