// Opt-in native presentation check. The explicitly prepared local owner has
// two historical TYTs and one 25-minute Turkish study fixture between them.
// This is not a full-duration exam or 25-minute wall-clock test.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';

const _enabled = bool.fromEnvironment('E2E_EXAM_INSIGHTS');
const _email = String.fromEnvironment('E2E_EXAM_INSIGHT_EMAIL');
const _owner = String.fromEnvironment('E2E_EXAM_INSIGHT_OWNER');

Future<void> _preserveActiveWork() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_') ||
        key.startsWith('e2e_first_use_real25_')) {
      final marker = jsonDecode(prefs.getString(key)!) as Map;
      expect(
        marker['completion_verified'],
        isTrue,
        reason: 'An unfinished native probe owns this installation',
      );
    }
    if (key.startsWith('active_session_uid_')) {
      expect(
        prefs.getString(key),
        isNull,
        reason: 'Never replace a persisted timer for an insight fixture',
      );
    }
    if (key.startsWith('pending_sessions_')) {
      expect(
        jsonDecode(prefs.getString(key)!),
        isEmpty,
        reason: 'Never replace another owner\'s pending study records',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      final rows = jsonDecode(prefs.getString(key)!) as List;
      for (final raw in rows) {
        final record = ExamLocalRecord.fromJson(raw);
        expect(record, isNotNull);
        expect(record!.pendingAction, isNull);
        expect(record.attempt?.status, isNot(ExamAttemptStatus.active));
      }
    }
  }
}

Future<Map<String, dynamic>> _snapshot() async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,'
  'coalesce(w.lifetime_points,0) as exam_points,coalesce(w.coins,0) as exam_coins,'
  '(select count(*)::integer from public.study_sessions s where s.user_id=p.id) as study_count,'
  '(select count(*)::integer from public.exam_attempts a where a.user_id=p.id) as exam_count '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(_owner)}',
))!;

Future<void> _tab(WidgetTester tester, int index) async {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) {
    await openTab(tester, index);
  } else {
    tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .onDestinationSelected!(index);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }
}

Future<void> _language(WidgetTester tester, String code) async {
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
  await tapOn(tester, find.text(code == 'tr' ? 'Türkçe' : 'English'));
  await pumpUntilTrue(
    tester,
    () => LanguageService.instance.currentLocale.languageCode == code,
    reason: 'native profile changes language',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<void> _assertVisibleParagraph(
  WidgetTester tester,
  String text,
  String shot,
) async {
  final paragraph = find.descendant(
    of: find.byType(ExamScreen),
    matching: find.text(text),
  );
  await pumpUntil(tester, paragraph);
  expect(paragraph, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(paragraph), alignment: 0.4);
  await pumpFor(tester, const Duration(milliseconds: 400));
  final rect = tester.getRect(paragraph);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
  await E2eHost.screenshot(tester, shot);
}

void main() {
  if (_enabled) {
    initE2e();
  } else {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  }
  testWidgets(
    'aa/o3 · positive Turkish study–net insight in TR and EN',
    (tester) async {
      expect(E2eHost.available, isTrue);
      expect(
        RegExp(
          r'^e2e-sim-exam-fixture-insight-[a-z0-9-]{1,30}@pomosprint\.local$',
        ).hasMatch(_email),
        isTrue,
      );
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(_owner),
        isTrue,
      );
      await _preserveActiveWork();
      final identity = (await E2eHost.row(
        'select email=${sqlText(_email)} as exact_owner,'
        "created_at>now()-interval '12 hours' as recent,"
        "raw_user_meta_data->>'qa_fixture_run'=${sqlText(_email.split('@').first)} as tagged "
        'from auth.users where id=${sqlText(_owner)}',
      ))!;
      expect(identity, {'exact_owner': true, 'recent': true, 'tagged': true});
      final baseline = await _snapshot();
      expect(baseline, {
        'total_minutes': 355,
        'lifetime_points': 5,
        'coins': 20,
        'exam_points': 66,
        'exam_coins': 12,
        'study_count': 1,
        'exam_count': 2,
      });
      final inputs = await E2eHost.rows(
        'select a.id::text,a.exam_id,a.status,'
        "(a.definition->>'catalog_version')::integer as catalog_version,"
        "(a.definition->>'duration_seconds')::integer as duration_seconds,"
        'a.started_at,a.ends_at,r.net::float as net '
        'from public.exam_attempts a join public.exam_subject_results r '
        "on r.attempt_id=a.id and r.subject_id='turkish' "
        'where a.user_id=${sqlText(_owner)} order by a.started_at',
      );
      expect(inputs, hasLength(2));
      expect(inputs.map((r) => r['net']), [19.25, 27.5]);
      expect(
        inputs.every(
          (r) =>
              r['exam_id'] == 'tyt' &&
              r['status'] == 'completed' &&
              r['duration_seconds'] == 9900,
        ),
        isTrue,
      );
      expect(inputs.first['catalog_version'], inputs.last['catalog_version']);
      final study = (await E2eHost.row(
        'select s.category,s.duration_minutes,s.started_at,s.completed_at '
        'from public.study_sessions s where s.user_id=${sqlText(_owner)}',
      ))!;
      expect(study['category'], 'Türkçe');
      expect(study['duration_minutes'], 25);
      expect(
        DateTime.parse(
          study['started_at'] as String,
        ).isAfter(DateTime.parse(inputs.first['ends_at'] as String)),
        isTrue,
      );
      expect(
        DateTime.parse(
          study['completed_at'] as String,
        ).isBefore(DateTime.parse(inputs.last['started_at'] as String)),
        isTrue,
      );

      await resetAppState(tester);
      await launchApp(tester);
      await waitPastSplash(tester);
      await loginViaUi(tester, _email);
      await pumpUntil(tester, find.byType(MainNavigationShell));
      expect(SupabaseService.instance.currentUser.value?.id, _owner);
      await NotificationService.instance.setEnabled(false);
      await _language(tester, 'tr');
      await _tab(tester, 4);
      await pumpUntil(tester, find.byType(ExamScreen));
      await pumpUntilTrue(
        tester,
        () => ExamService.instance.attempts.length == 2,
        reason: 'same-owner completed exam history',
      );
      await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
      const trParagraph =
          'İlişkili çalışma kategorilerinde 25 dk; Türkçe neti: 19,25 → 27,50.';
      expect(
        trL10n.examInsightsChange('Türkçe', 25, '19,25', '27,50'),
        trParagraph,
      );
      await _assertVisibleParagraph(
        tester,
        trParagraph,
        'e2e-insight-positive-tr',
      );
      expect(
        find.text(trL10n.examInsightsChange('Temel Matematik', 0, '0,00', '0,00')),
        findsNothing,
        reason: 'Entirely blank subjects do not crowd the insight list',
      );
      await _assertVisibleParagraph(
        tester,
        trL10n.examInsightsDisclaimer,
        'e2e-insight-disclaimer-tr',
      );
      expect(find.text(trL10n.examInsightsEmpty), findsNothing);

      await _language(tester, 'en');
      final en = lookupAppLocalizations(const Locale('en'));
      const enParagraph =
          'In related study categories: 25 min; Turkish net score: 19.25 → 27.50.';
      expect(
        en.examInsightsChange('Turkish', 25, '19.25', '27.50'),
        enParagraph,
      );
      await _assertVisibleParagraph(
        tester,
        enParagraph,
        'e2e-insight-positive-en',
      );
      expect(
        find.text(en.examInsightsChange('Basic Mathematics', 0, '0.00', '0.00')),
        findsNothing,
      );
      await _assertVisibleParagraph(
        tester,
        en.examInsightsDisclaimer,
        'e2e-insight-disclaimer-en',
      );
      expect(find.text(trParagraph), findsNothing);
      expect(find.text(en.examInsightsEmpty), findsNothing);
      expect(
        await _snapshot(),
        baseline,
        reason: 'Viewing/translating an insight never changes either economy',
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        '[EXAM_INSIGHT_NATIVE] PASS: explicit historical fixtures, '
        '25 matching minutes, 19.25→27.50, TR/EN visible text and disclaimer. '
        'This is not a real-duration exam/focus test.',
      );
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
