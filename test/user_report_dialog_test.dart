import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/widgets/social/user_report_dialog.dart';
import 'package:pomodoro/widgets/social/user_safety.dart';

import 'support/fake_supabase_service.dart';

class _ReportService extends FakeSupabaseService {
  final reports = <(String, String, String, String?)>[];
  Completer<void>? gate;
  Map<String, dynamic> response = {'success': true, 'duplicate': false};
  @override
  Future<Map<String, dynamic>> submitUserReport({
    required String targetUserId,
    required String place,
    required String reason,
    String? details,
  }) async {
    reports.add((targetUserId, place, reason, details));
    await gate?.future;
    return response;
  }
}

void main() {
  Future<AppLocalizations> pumpReport(
    WidgetTester tester,
    _ReportService service, {
    Size size = const Size(390, 844),
    double scale = 1,
    Locale locale = const Locale('tr'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUserSafetySheet(
                context,
                target: const UserSafetyTarget(
                  name: 'Bildirilecek kullanıcı',
                  userId: 'target-uuid',
                ),
                place: UserReportPlace.monthly,
                allowHide: false,
                service: service,
              ),
              child: const Text('menü'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('menü'));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(locale);
    await tester.tap(find.text(l10n.reportUserAction));
    await tester.pumpAndSettle();
    return l10n;
  }

  Future<void> chooseSpam(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reportReasonSpam).last);
    await tester.pumpAndSettle();
  }

  test('bildirim yerleri sunucu kodlarıyla eşlenir', () {
    expect(
      [for (final place in UserReportPlace.values) userReportPlaceCode(place)],
      [
        'league',
        'monthly',
        'friends_ranking',
        'live_feed',
        'friends_list',
        'friend_request',
      ],
    );
  });

  testWidgets(
    'neden gerekli; e-postaya çıkmadan tek işlemle nedeni ve notu gönderir',
    (tester) async {
      final service = _ReportService();
      final l10n = await pumpReport(tester, service);
      await tester.tap(find.text(l10n.reportSendButton));
      await tester.pumpAndSettle();
      expect(service.reports, isEmpty);
      expect(find.text(l10n.reportChooseReason), findsOneWidget);
      await chooseSpam(tester, l10n);
      await tester.enterText(
        find.byType(TextFormField),
        '  İstenmeyen içerik  ',
      );
      service.gate = Completer<void>();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      button.onPressed!();
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      button.onPressed!();
      await tester.pump();
      expect(service.reports, [
        ('target-uuid', 'monthly', 'spam', 'İstenmeyen içerik'),
      ]);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'gönderim sürerken geri ile terk edilmez',
      );
      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.reportSent), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mükerrer bildirim başarıyla açıklanır; boş not null gönderilir',
    (tester) async {
      final service = _ReportService()
        ..response = {'success': true, 'duplicate': true};
      final l10n = await pumpReport(
        tester,
        service,
        locale: const Locale('en'),
      );
      await chooseSpam(tester, l10n);
      await tester.tap(find.text(l10n.reportSendButton));
      await tester.pumpAndSettle();
      expect(service.reports.single.$4, isNull);
      expect(find.text(l10n.reportAlreadyReceived), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hız sınırı yanlış başarı göstermez; iptal yeni kayıt açmaz', (
    tester,
  ) async {
    final service = _ReportService()
      ..response = {'success': false, 'code': 'rate_limited'};
    final l10n = await pumpReport(tester, service);
    await chooseSpam(tester, l10n);
    await tester.tap(find.text(l10n.reportSendButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reportRateLimited), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(service.reports.length, 1);
    expect(find.text(l10n.reportSent), findsNothing);
  });

  testWidgets(
    'hesap gönderimden önce değişirse eski hedef yeni hesapla gönderilmez',
    (tester) async {
      final service = _ReportService();
      final l10n = await pumpReport(tester, service);
      await chooseSpam(tester, l10n);
      service.currentUser.value = null;
      await tester.tap(find.text(l10n.reportSendButton));
      await tester.pumpAndSettle();
      expect(service.reports, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.reportSent), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [Size(320, 568), Size(844, 390), Size(768, 1024)]) {
    testWidgets('bildirim formu büyük yazıda taşmaz $size', (tester) async {
      await pumpReport(tester, _ReportService(), size: size, scale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
