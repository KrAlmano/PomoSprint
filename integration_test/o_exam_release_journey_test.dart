// Native UI + gerçek yerel API. Standart katalog süreleri asla kısaltılmaz.
// o1 gerçek başlangıç/vazgeçmedir; o2 açıkça hazırlanmış geçmiş fixture'ını
// kullanır ve gerçek süre boyunca beklenmiş deneme kanıtı değildir.
// o2: --dart-define=E2E_EXAM_FIXTURE_EMAIL=e2e-sim-...@pomosprint.local
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';

import 'support/e2e.dart';

const _fixtureEmail = String.fromEnvironment('E2E_EXAM_FIXTURE_EMAIL');

Future<void> _tab(WidgetTester tester, int index) async {
  final bar = find.byType(NavigationBar);
  if (bar.evaluate().isNotEmpty) {
    await openTab(tester, index);
  } else {
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    rail.onDestinationSelected!(index);
    await pumpFor(tester, const Duration(milliseconds: 700));
  }
}

Future<void> _language(WidgetTester tester, {required bool english}) async {
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
  await tapOn(tester, find.text(english ? 'English' : 'Türkçe'));
  await pumpUntilTrue(
    tester,
    () => LanguageService.instance.isTurkish != english,
    reason: 'profil dil tercihi uygulanır',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<void> _orientation(
  WidgetTester tester,
  DeviceOrientation orientation,
) async {
  await SystemChrome.setPreferredOrientations([orientation]);
  final landscape = orientation == DeviceOrientation.landscapeLeft;
  await pumpUntilTrue(tester, () {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return landscape ? size.width > size.height : size.height > size.width;
  }, reason: landscape ? 'native yatay görünüm' : 'native dikey görünüm');
  await pumpFor(tester, const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull, reason: 'yön değişiminde taşma yok');
}

Future<void> _showActiveTimer(WidgetTester tester) async {
  final clock = find.byKey(const ValueKey('exam-countdown'));
  await pumpUntil(tester, clock);
  await Scrollable.ensureVisible(tester.element(clock), alignment: 0.35);
  await pumpFor(tester, const Duration(milliseconds: 500));
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final rect = tester.getRect(clock);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
}

Future<void> _enterTextWithNativeFocus(
  WidgetTester tester,
  Finder field,
  String value, {
  String? checkpoint,
}) async {
  void mark(String step) {
    if (checkpoint != null) {
      debugPrint('[EXAM_O2] $checkpoint: $step');
    }
  }

  mark('scroll begin');
  expect(field, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(field), alignment: 0.5);
  await pumpFor(tester, const Duration(milliseconds: 300));
  mark('scroll ready');
  expect(field.hitTestable(), findsOneWidget);
  // Reopening the same field after unfocus needs a real tap: showKeyboard's
  // cached focusedEditable may otherwise skip requesting a new native client.
  await tester.tap(field);
  await pumpFor(tester, const Duration(milliseconds: 300));
  mark('tap ready');
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
  mark('enterText begin');
  await tester.enterText(field, value);
  mark('enterText returned');
  await pumpFor(tester, const Duration(milliseconds: 300));
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(tester, const Duration(milliseconds: 300));
  expect(
    tester.widget<TextField>(field).controller!.text == value,
    isTrue,
    reason: '${checkpoint ?? 'result field'} retains the entered value',
  );
  mark('verified and unfocused');
}

Future<void> _loginFixtureViaUi(WidgetTester tester) async {
  debugPrint('[EXAM_O2] login screen wait begin');
  await pumpUntil(tester, find.byType(LoginScreen), reason: 'fixture login');
  debugPrint('[EXAM_O2] login screen ready');
  final fields = find.descendant(
    of: find.byType(LoginScreen),
    matching: find.byType(TextField),
  );
  expect(fields, findsNWidgets(2));
  await _enterTextWithNativeFocus(
    tester,
    fields.at(0),
    _fixtureEmail,
    checkpoint: 'login email',
  );
  await _enterTextWithNativeFocus(
    tester,
    fields.at(1),
    kE2ePassword,
    checkpoint: 'login password',
  );
  debugPrint('[EXAM_O2] login button begin');
  await tapOn(tester, find.widgetWithText(ElevatedButton, trL10n.loginBtn));
  debugPrint('[EXAM_O2] login button returned');
}

Future<Map<String, dynamic>> _economy(String owner) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,p.current_streak,'
  "coalesce(w.coins,0) as exam_coins,coalesce(w.lifetime_points,0) as exam_points "
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(owner)}',
))!;

void main() {
  initE2e();
  final en = lookupAppLocalizations(const Locale('en'));

  testWidgets(
    'o1 · gerçek deneme başlangıcı, kalıcılık, dil, yön, sahip ve vazgeçme',
    (tester) async {
      final service = SupabaseService.instance;
      final exams = ExamService.instance;
      ApiAccount? account;
      String? activeUuid;
      try {
        await _orientation(tester, DeviceOrientation.portraitUp);
        account = await openShellWithNewAccount(
          tester,
          'exam-${DateTime.now().microsecondsSinceEpoch}',
          name: 'QA Deneme',
        );
        await NotificationService.instance.setEnabled(false);
        final before = await _economy(account.id);
        await _tab(tester, 4);
        await pumpUntil(tester, find.byType(ExamScreen));
        await pumpUntilTrue(
          tester,
          () => exams.catalog.available,
          reason: 'yerel sunucu deneme kataloğu açık',
        );
        expect(exams.catalog.exams, hasLength(7));
        expect(
          {
            for (final exam in exams.catalog.exams)
              exam.id: exam.durationSeconds,
          },
          {
            'tyt': 9900,
            'ayt': 10800,
            'ydt': 7200,
            'lgs_verbal': 4500,
            'lgs_quantitative': 4800,
            'tus_basic': 8100,
            'tus_clinical': 8100,
          },
          reason: 'üretim kataloğu gerçek standart sürelerle gelir',
        );
        await E2eHost.screenshot(tester, 'e2e-exam-catalog-tr');
        await tapOn(tester, find.byKey(const ValueKey('exam-start-tyt')));
        await pumpUntil(tester, find.text(trL10n.examRulesTitle));
        expect(find.text(trL10n.examRulesBody), findsOneWidget);
        await tapOn(
          tester,
          find.widgetWithText(FilledButton, trL10n.examReady),
          // Observe the first transient countdown frame immediately.
          settle: Duration.zero,
        );
        for (final number in ['3', '2', '1']) {
          await pumpUntil(tester, find.text(number));
        }
        await pumpUntil(tester, find.byKey(const ValueKey('exam-countdown')));
        await pumpUntilTrue(
          tester,
          () => exams.activeRecord?.attempt != null,
          reason: 'sunucu başlangıcı ve kalıcı kayıt',
        );
        final initial = exams.activeRecord!.attempt!;
        activeUuid = initial.clientUuid;
        expect(initial.durationSeconds, 9900);
        expect(initial.endsAt.difference(initial.startedAt).inSeconds, 9900);
        expect(
          initial.remainingSecondsAt(exams.now()),
          inInclusiveRange(9850, 9900),
        );
        expect(find.text(trL10n.examNoPause), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ExamScreen),
            matching: find.byIcon(Icons.pause),
          ),
          findsNothing,
          reason: 'deneme sırasında duraklatma kontrolü yok',
        );
        final disk = await ExamPersistence().read(account.id);
        expect(disk.single.attempt!.id, initial.id);
        expect(disk.single.pendingAction, isNull);
        Object? earlyError;
        try {
          await LocalApi.rpc('complete_exam_attempt', account, {
            'p_attempt_id': initial.id,
          });
        } catch (error) {
          earlyError = error;
        }
        expect(earlyError, isA<LocalApiError>());
        expect(earlyError.toString(), contains('exam_not_elapsed'));
        await _language(tester, english: true);
        expect(find.text(en.examNoPause), findsOneWidget);
        expect(find.text(trL10n.examNoPause), findsNothing);
        await _showActiveTimer(tester);
        await E2eHost.screenshot(tester, 'e2e-exam-running-en');
        await _orientation(tester, DeviceOrientation.landscapeLeft);
        expect(find.byKey(const ValueKey('exam-countdown')), findsOneWidget);
        expect(find.text(en.examNoPause), findsOneWidget);
        await _showActiveTimer(tester);
        await E2eHost.screenshot(tester, 'e2e-exam-landscape');
        await _orientation(tester, DeviceOrientation.portraitUp);

        // Ağaç kapanır/açılır; bu gerçek işletim sistemi process kill değildir.
        // Disk ayrıca yukarıda doğrudan doğrulanır; sayaç başlangıcı sıfırlanmaz.
        await launchApp(tester);
        await pumpUntil(tester, find.byType(MainNavigationShell));
        await _tab(tester, 4);
        await pumpUntil(tester, find.byKey(const ValueKey('exam-countdown')));
        expect(exams.activeRecord!.attempt!.id, initial.id);
        expect(exams.activeRecord!.attempt!.startedAt, initial.startedAt);
        expect(
          exams.activeRecord!.attempt!.remainingSecondsAt(exams.now()),
          lessThan(9900),
        );
        expect(LanguageService.instance.isTurkish, isFalse);

        // Sahip değişiminde A'nın devam eden denemesi B'ye gösterilmez.
        final other = await signUpViaApi(
          e2eEmail('exam-other-${DateTime.now().microsecondsSinceEpoch}'),
          'QA Diğer Deneme',
        );
        await completeOnboardingViaApi(other);
        await _language(tester, english: false);
        await service.signOutFully();
        await pumpUntil(tester, find.byType(LoginScreen));
        await loginViaUi(tester, other.email);
        await pumpUntil(tester, find.byType(MainNavigationShell));
        await _tab(tester, 4);
        await pumpUntilTrue(
          tester,
          () => exams.catalog.available && exams.backend.ownerId == other.id,
          reason: 'ikinci hesabın kataloğu',
        );
        expect(exams.attempts, isEmpty);
        expect(exams.activeRecord, isNull);
        expect(find.byKey(const ValueKey('exam-countdown')), findsNothing);
        await service.signOutFully();
        await pumpUntil(tester, find.byType(LoginScreen));
        await loginViaUi(tester, account.email);
        await pumpUntil(tester, find.byType(MainNavigationShell));
        await _tab(tester, 4);
        await pumpUntil(tester, find.byKey(const ValueKey('exam-countdown')));
        expect(exams.activeRecord!.attempt!.id, initial.id);
        await _language(tester, english: true);

        await tapOn(tester, find.widgetWithText(TextButton, en.examAbandon));
        await pumpUntil(tester, find.text(en.examAbandonTitle));
        await tapOn(tester, find.widgetWithText(FilledButton, en.examAbandon));
        await pumpUntilGone(
          tester,
          find.byKey(const ValueKey('exam-countdown')),
        );
        await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
        await pumpUntil(tester, find.text(en.examAbandoned));
        expect(find.text(en.examNoAward), findsOneWidget);
        expect(find.text(en.examEnterResults), findsNothing);
        final row = await E2eHost.row(
          'select status,elapsed_seconds,points_earned,exam_coins_earned '
          'from public.exam_attempts where id=${sqlText(initial.id)} '
          'and user_id=${sqlText(account.id)}',
        );
        expect(row!['status'], 'abandoned');
        expect(row['elapsed_seconds'], greaterThan(0));
        expect(row['points_earned'], 0);
        expect(row['exam_coins_earned'], 0);
        expect(await _economy(account.id), before);
        await E2eHost.screenshot(tester, 'e2e-exam-abandoned-history');
        debugPrint(
          '[EXAM_E2E] ${account.id} ${account.email} real-start-abandon PASS',
        );
        expect(tester.takeException(), isNull);
      } finally {
        // Yalnız bu testin hesabına ait açık deneme temizlenir.
        final cleanup = exams.activeRecord;
        if (account != null &&
            exams.backend.ownerId == account.id &&
            cleanup != null &&
            (activeUuid == null || cleanup.clientUuid == activeUuid)) {
          await exams.abandon(cleanup.clientUuid);
        }
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'o2 · açık geçmiş fixture: net doğrulama, düzenleme, ekonomi ve rapor ayrımı',
    (tester) async {
      addTearDown(
        () => SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]),
      );
      expect(
        _fixtureEmail.startsWith('e2e-sim-') &&
            _fixtureEmail.endsWith('@pomosprint.local'),
        isTrue,
        reason: 'yalnız açıkça hazırlanmış yerel E2E hesabı',
      );
      debugPrint('[EXAM_O2] reset begin');
      await resetAppState(tester);
      debugPrint('[EXAM_O2] reset ready; launch begin');
      await launchApp(tester);
      debugPrint('[EXAM_O2] launch returned; splash wait begin');
      await waitPastSplash(tester);
      debugPrint('[EXAM_O2] splash ready; login begin');
      await _loginFixtureViaUi(tester);
      debugPrint('[EXAM_O2] login returned; shell wait begin');
      await pumpUntil(tester, find.byType(MainNavigationShell));
      debugPrint('[EXAM_O2] shell ready');
      await NotificationService.instance.setEnabled(false);
      final exams = ExamService.instance;
      final owner = SupabaseService.instance.currentUser.value!.id!;
      await _tab(tester, 4);
      await pumpUntilTrue(
        tester,
        () =>
            exams.attempts
                .where((a) => a.isCompleted && a.examId == 'tyt')
                .length >=
            2,
        reason: 'iki standart süreli açık geçmiş fixture',
      );
      expect(exams.activeRecord, isNull);
      final attempt = exams.attempts.firstWhere(
        (a) => a.isCompleted && a.examId == 'tyt',
      );
      expect(attempt.durationSeconds, 9900);
      final before = await _economy(owner);
      await _language(tester, english: true);
      await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
      final edit = find.text(en.examEditResults);
      await tapOn(tester, edit.first);
      await pumpUntil(
        tester,
        find.byKey(const ValueKey('exam-result-turkish-0')),
      );
      expect(find.text(en.examResultsInfo), findsOneWidget);
      expect(find.text('Turkish'), findsOneWidget);
      await _enterTextWithNativeFocus(
        tester,
        find.byKey(const ValueKey('exam-result-turkish-0')),
        '41',
        checkpoint: 'invalid result',
      );
      await tapOn(
        tester,
        find.widgetWithText(FilledButton, en.examSaveResults),
      );
      await pumpUntil(tester, find.text(en.examResultsInvalid));
      expect(find.byType(AlertDialog), findsOneWidget);
      for (final (index, value) in [(0, '30'), (1, '4'), (2, '6')]) {
        final field = find.byKey(ValueKey('exam-result-turkish-$index'));
        await _enterTextWithNativeFocus(
          tester,
          field,
          value,
          checkpoint: 'result $index',
        );
      }
      await _orientation(tester, DeviceOrientation.landscapeLeft);
      expect(
        find.byKey(const ValueKey('exam-result-turkish-0')),
        findsOneWidget,
      );
      for (final (index, value) in [(0, '30'), (1, '4'), (2, '6')]) {
        expect(
          tester
              .widget<TextField>(
                find.byKey(ValueKey('exam-result-turkish-$index')),
              )
              .controller!
              .text,
          value,
        );
      }
      expect(
        find.text('${en.examNet}: 29.00'),
        findsOneWidget,
        reason: visibleTexts(
          find.byType(AlertDialog),
        ).where((s) => s.contains(en.examNet)).join(' | '),
      );
      final netLine = find.text('${en.examNet}: 29.00');
      await Scrollable.ensureVisible(tester.element(netLine), alignment: 0.9);
      await pumpFor(tester, const Duration(milliseconds: 300));
      final netRect = tester.getRect(netLine);
      final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(netRect.top, greaterThanOrEqualTo(0));
      expect(netRect.bottom, lessThanOrEqualTo(viewport.height));
      await E2eHost.screenshot(tester, 'e2e-exam-net-landscape');
      await _orientation(tester, DeviceOrientation.portraitUp);
      await tapOn(
        tester,
        find.widgetWithText(FilledButton, en.examSaveResults),
      );
      await pumpUntilGone(tester, find.byType(AlertDialog));
      await pumpUntilTrue(
        tester,
        () => exams.attempts
            .firstWhere((a) => a.id == attempt.id)
            .subjectResults
            .any(
              (r) =>
                  r.subjectId == 'turkish' &&
                  r.correct == 30 &&
                  r.wrong == 4 &&
                  r.blank == 6,
            ),
        reason: 'net düzenlemesi gerçek sunucu yanıtıyla kaydedilir',
      );
      final saved = await E2eHost.row(
        'select correct,wrong,blank,net::float from public.exam_subject_results '
        'where attempt_id=${sqlText(attempt.id)} and subject_id=\'turkish\'',
      );
      expect(saved, {'correct': 30, 'wrong': 4, 'blank': 6, 'net': 29});
      expect(
        await _economy(owner),
        before,
        reason: 'net puan/kum/çalışma süresini değiştirmez',
      );
      expect(find.text(en.examInsights), findsOneWidget);
      await E2eHost.screenshot(tester, 'e2e-exam-net-history-en');
      await _tab(tester, 1);
      await tapOn(tester, find.text(tr('reports_tab_history')));
      await pumpUntil(tester, find.byType(HistoryScreen));
      await pumpUntilTrue(
        tester,
        () => tester
            .widget<HistoryScreen>(find.byType(HistoryScreen))
            .sessions
            .any((s) => s.kind == StudySessionKind.exam),
        reason: 'tamamlanan denemeler ortak haftalık rapora yansır',
      );
      final weekly = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
      final first = mondayOf(weekly.today);
      final last = addDays(first, 6);
      final totals = await E2eHost.row(
        'select coalesce(sum(t.minutes),0)::int as minutes from ('
        'select s.duration_minutes as minutes,s.started_at,s.user_id '
        'from public.study_sessions s where s.user_id=${sqlText(owner)} '
        "union all select (a.definition->>'duration_seconds')::integer/60,"
        'a.started_at,a.user_id '
        "from public.exam_attempts a where a.user_id=${sqlText(owner)} and a.status='completed'"
        ') t join public.profiles p on p.id=t.user_id '
        "where ((t.started_at at time zone p.timezone)-interval '4 hours')::date between "
        '${sqlText(first.toIso8601String().substring(0, 10))}::date and '
        '${sqlText(last.toIso8601String().substring(0, 10))}::date',
      );
      expect(
        sumMinutesBetween(weekly.sessions, first, last),
        totals!['minutes'],
      );
      expect(
        weekly.sessions
            .where((s) => s.kind == StudySessionKind.exam)
            .every((s) => s.pomodoros == 0),
        isTrue,
        reason: 'deneme süresi Pomodoro sayısını yükseltmez',
      );
      await E2eHost.screenshot(tester, 'e2e-exam-weekly-reports');
      await tapOn(tester, find.text(en.statsOpenExamDetails).first);
      await pumpUntil(tester, find.byType(ExamScreen));
      expect(tester.takeException(), isNull);
    },
    skip: _fixtureEmail.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
