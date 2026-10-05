import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'support/fake_supabase_service.dart';

class FriendsFake extends FakeSupabaseService {
  List<Map<String, dynamic>> friends = [
    {'id': 'friend', 'name': 'Ali', 'lifetime_points': 5},
  ];
  int removes = 0;
  Completer<void>? gate;
  @override
  Future<String?> getMyFriendCode() async => 'ABC123';
  @override
  Future<List<Map<String, dynamic>>> fetchFriends() async => List.of(friends);
  @override
  Future<List<Map<String, dynamic>>> fetchPendingFriendRequests() async => [];
  @override
  Future<List<Map<String, dynamic>>> fetchOutgoingFriendRequests() async => [
    {'id': 'out', 'name': 'Ayşe'},
  ];
  @override
  Future<List<Map<String, dynamic>>> fetchBlockedUsers() async => [
    {'id': 'blocked', 'name': 'Mert'},
  ];
  @override
  Future<Map<String, dynamic>> removeFriend(String id) async {
    removes++;
    if (gate != null) await gate!.future;
    friends = [];
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> blockUser(String id) async =>
      throw const ServiceException(ServiceErrorCode.network);
}

Future<AppLocalizations> pump(
  WidgetTester tester,
  FriendsFake service, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('tr'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
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
    'silme onayı iptal edilince yazılmaz; bekleyen işlem ikinci kez gönderilmez',
    (tester) async {
      addTearDown(tester.view.reset);
      final service = FriendsFake();
      final l = await pump(tester, service);
      await tester.scrollUntilVisible(
        find.byTooltip(l.userActionsTooltip),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip(l.userActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.friendsRemoveAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.friendActionCancel));
      await tester.pumpAndSettle();
      expect(service.removes, 0);
      expect(find.text('Ali'), findsOneWidget);
      await tester.tap(find.byTooltip(l.userActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.friendsRemoveAction));
      await tester.pumpAndSettle();
      service.gate = Completer<void>();
      await tester.tap(find.text(l.friendActionConfirm));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(service.removes, 1);
      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsNothing);
      expect(find.text(l.friendsYourFriends(0)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ağ hatası kullanıcıyı engellenmiş gibi göstermez, İngilizce hata ve tekrar yolu kalır',
    (tester) async {
      addTearDown(tester.view.reset);
      final service = FriendsFake();
      final l = await pump(tester, service, locale: const Locale('en'));
      await tester.scrollUntilVisible(
        find.byTooltip(l.userActionsTooltip),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip(l.userActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.blockUserAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.friendActionConfirm));
      await tester.pumpAndSettle();
      expect(find.text(l.socialErrNetwork), findsOneWidget);
      expect(service.friends.single['name'], 'Ali');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1366, 1024),
  ]) {
    testWidgets(
      'giden/engellenen listeleri taşmaz ${size.width}x${size.height}',
      (tester) async {
        addTearDown(tester.view.reset);
        await pump(tester, FriendsFake(), size: size);
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
