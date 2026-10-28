// Isolated proposed32 DUS/current reward revision only. Real native UI, real server time, no date/catalog
// mutation. Root supplies a fresh, confirmed fictional account on port54351.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/exam_reward_policy.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';

const _email = String.fromEnvironment('E2E_EXAM_FIXTURE_EMAIL');
AppLocalizations get _l10n => lookupAppLocalizations(
  Locale(LanguageService.instance.isTurkish ? 'tr' : 'en'),
);
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

Future<void> _language(WidgetTester tester, String language) async {
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
  await tapOn(tester, find.text(language == 'tr' ? 'Türkçe' : 'English'));
  await pumpUntilTrue(
    tester,
    () => LanguageService.instance.currentLocale.languageCode == language,
    reason: 'profile language $language',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() condition,
  String reason,
) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    if (await condition()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(reason);
}

Future<void> _guardExistingWork() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_marathon_process_probe_') ||
        key.startsWith('e2e_first_use_real25_')) {
      expect(
        (jsonDecode(prefs.getString(key)!) as Map)['completion_verified'],
        isTrue,
        reason: 'Never reset an unfinished device probe',
      );
    }
    if (key.startsWith('active_session_uid_')) {
      fail('Preserve existing focus before the proposed32 run: $key');
    }
    if (key.startsWith('exam_journal_uid_')) {
      final owner = key.substring('exam_journal_uid_'.length);
      for (final row in await ExamPersistence().read(owner)) {
        expect(
          row.pendingAction,
          isNull,
          reason: 'Preserve queued exam mutation',
        );
        expect(
          row.attempt?.status,
          isNot(ExamAttemptStatus.active),
          reason: 'Preserve active exam',
        );
      }
    }
  }
}

Future<void> _input(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await pumpFor(tester, const Duration(milliseconds: 100));
  await tapOn(tester, finder, settle: const Duration(milliseconds: 100));
  await tester.enterText(finder, value);
  await tester.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(tester, const Duration(milliseconds: 100));
}

Future<Map<String, dynamic>> _proof(
  String owner,
  String attempt,
) async => (await E2eHost.row(
  'select a.id::text,a.client_uuid::text,a.status,a.elapsed_seconds,'
  "(a.definition->>'duration_seconds')::int as planned_seconds,"
  'a.points_earned,a.exam_coins_earned,a.details_revision,a.title,a.note,'
  'to_json(a.selected_module_ids) as modules,'
  '(select count(*) from public.exam_subject_results r where r.attempt_id=a.id) as result_count,'
  '(select coalesce(sum(r.correct),0) from public.exam_subject_results r where r.attempt_id=a.id) as correct_count,'
  'p.total_minutes,p.lifetime_points,p.coins,p.current_streak,'
  'coalesce(w.lifetime_points,0) as wallet_points,coalesce(w.coins,0) as wallet_coins '
  'from public.exam_attempts a join public.profiles p on p.id=a.user_id '
  'left join public.exam_wallets w on w.user_id=a.user_id '
  'where a.user_id=${sqlText(owner)} and a.id=${sqlText(attempt)}',
))!;

void main() {
  initE2e();
  testWidgets(
    'isolated32 AYT early finish, atomic details, history and reports TR EN',
    (tester) async {
      expect(Uri.parse(kSupabaseUrl).port, 54351);
      expect({54359, 54369}, contains(kE2eHostPort));
      expect(
        (await E2eHost.row(
          "select current_database()='pomosprint_review32_dus' as correct_database",
        ))!['correct_database'],
        isTrue,
      );
      await _guardExistingWork();
      final ApiAccount account;
      if (_email.isEmpty) {
        account = await openShellWithNewAccount(
          tester,
          'exam32',
          name: 'Deneme Kontrol',
          segment: 'yks',
        );
      } else {
        expect(
          RegExp(
            r'^e2e-sim-exam32-[a-z0-9-]+@pomosprint\.local$',
          ).hasMatch(_email),
          isTrue,
        );
        await resetAppState(tester);
        await launchApp(tester);
        await waitPastSplash(tester);
        await loginViaUi(tester, _email);
        await pumpUntil(tester, find.byType(MainNavigationShell));
        final signed =
            await LocalApi.request(
                  'POST',
                  '/auth/v1/token?grant_type=password',
                  body: {'email': _email, 'password': kE2ePassword},
                )
                as Map;
        account = ApiAccount(
          SupabaseService.instance.currentUser.value!.id!,
          _email,
          signed['access_token'] as String,
        );
      }
      final owner = account.id;
      expect(
        (await E2eHost.row(
          'select count(*) as n from public.exam_attempts where user_id=${sqlText(owner)}',
        ))!['n'],
        0,
        reason: 'Dedicated fresh proposed32 owner required',
      );
      final examService = ExamService.instance;
      var completed = 0;
      for (final language in ['tr', 'en']) {
        await _language(tester, language);
        await _tab(tester, 4);
        await pumpUntil(tester, find.byType(ExamScreen));
        await examService.refresh();
        expect(examService.catalog.exams, hasLength(8));
        expect(
          examService.catalog.exams.map((e) => e.id),
          unorderedEquals(ExamRewardPolicy.byExam.keys),
        );
        for (final definition in examService.catalog.exams) {
          expect(
            definition.fullRewardPoints,
            ExamRewardPolicy.byExam[definition.id]!.points,
          );
          expect(
            definition.fullRewardCoins,
            ExamRewardPolicy.byExam[definition.id]!.sand,
          );
        }
        expect(examService.supportsDetails, isTrue);
        expect(examService.catalog.capabilities.aytEarlyFinish, isTrue);
        final newChip = find.byKey(const ValueKey('exam-tab-new'));
        await tapOn(tester, newChip);
        await tapOn(tester, find.byKey(const ValueKey('exam-start-ayt')));
        await pumpUntil(tester, find.text(_l10n.examRulesTitle));
        await tapOn(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, _l10n.examReady),
          ),
        );
        await pumpUntilTrue(
          tester,
          () => examService.activeRecord?.attempt != null,
          reason: 'Server accepted fresh AYT',
        );
        final active = examService.activeRecord!.attempt!;
        expect(active.plannedSeconds, 10800);
        expect(active.totalQuestions, 160);
        await pumpFor(tester, const Duration(seconds: 3));
        await E2eHost.screenshot(tester, 'e2e-ah32-running-$language');
        await tapOn(tester, find.byKey(const ValueKey('exam-finish-early')));
        await pumpUntil(tester, find.text(_l10n.examFinishEarlyTitle));
        await tapOn(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, _l10n.examFinishEarly),
          ),
        );
        await pumpUntil(tester, find.text(_l10n.examDetailsTitle));
        final accepted = examService.attempts.singleWhere(
          (a) => a.id == active.id,
        );
        expect(accepted.finishedEarly, isTrue);
        expect(accepted.actualSeconds, inInclusiveRange(1, 119));
        expect(accepted.durationSeconds, accepted.actualSeconds);
        expect(accepted.reportMinutes, accepted.actualSeconds ~/ 60);
        expect(
          find.byKey(const ValueKey('exam-result-mathematics-0')),
          findsNothing,
        );
        for (final module in ['mathematics', 'science']) {
          await tapOn(tester, find.byKey(ValueKey('exam-module-$module')));
        }
        await _input(tester, 'exam-result-mathematics-0', '25');
        await _input(tester, 'exam-result-mathematics-1', '4');
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('exam-result-mathematics-2')),
              )
              .controller!
              .text,
          '11',
        );
        await _input(tester, 'exam-result-physics-0', '10');
        await _input(tester, 'exam-result-physics-1', '1');
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('exam-result-physics-2')),
              )
              .controller!
              .text,
          '3',
        );
        final title = language == 'tr' ? 'AYT denemem' : 'My AYT attempt';
        final note = language == 'tr'
            ? 'Fizikte tekrar yapacağım.'
            : 'I will review physics.';
        await _input(tester, 'exam-detail-title', title);
        await _input(tester, 'exam-detail-note', note);
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFor(tester, const Duration(milliseconds: 300));
        await E2eHost.screenshot(tester, 'e2e-ah32-details-$language');
        await tapOn(
          tester,
          find.widgetWithText(FilledButton, _l10n.examSaveResults),
        );
        await pumpUntilGone(tester, find.byType(AlertDialog));
        await pumpUntilTrue(
          tester,
          () =>
              examService.attempts
                  .singleWhere((a) => a.id == active.id)
                  .detailsRevision ==
              1,
          reason: 'Atomic details receipt',
        );
        var stored = examService.attempts.singleWhere((a) => a.id == active.id);
        expect(stored.title, title);
        expect(stored.note, note);
        expect(stored.selectedQuestionCount, 80);
        expect(stored.subjectResults, hasLength(2));
        expect(examService.blocksOtherSessions.value, isFalse);
        final before = await _proof(owner, active.id);
        expect(before['planned_seconds'], 10800);
        expect(before['elapsed_seconds'], accepted.actualSeconds);
        expect(before['details_revision'], 1);
        expect(before['result_count'], 2);
        expect(before['correct_count'], 35);
        expect(before['modules'], ['mathematics', 'science']);
        final duplicate =
            await LocalApi.rpc('save_exam_details', account, {
                  'p_attempt_id': active.id,
                  'p_details': {
                    'title': title,
                    'note': note,
                    'selected_module_ids': ['mathematics', 'science'],
                  },
                  'p_subject_results': stored.subjectResults
                      .map((r) => r.toJson())
                      .toList(),
                  'p_expected_revision': 0,
                })
                as Map;
        expect(duplicate['duplicate'], isTrue);
        final earlyDuplicate =
            await LocalApi.rpc('finish_ayt_early', account, {
                  'p_attempt_id': active.id,
                })
                as Map;
        expect(earlyDuplicate['duplicate'], isTrue);
        expect(
          await _proof(owner, active.id),
          before,
          reason:
              'Lost-ACK retry preserves exactly one reward/details revision',
        );
        completed++;
        final historyCard = find
            .ancestor(of: find.text(title), matching: find.byType(Card))
            .first;
        await tapOn(
          tester,
          find.descendant(
            of: historyCard,
            matching: find.widgetWithText(TextButton, _l10n.examDetailsEdit),
          ),
        );
        await pumpUntil(tester, find.byType(AlertDialog));
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('exam-detail-note')))
              .controller!
              .text,
          note,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('exam-module-science')),
              )
              .value,
          isTrue,
        );
        await tapOn(tester, find.widgetWithText(TextButton, _l10n.cancel));
        await pumpUntilGone(tester, find.byType(AlertDialog));
        await E2eHost.screenshot(tester, 'e2e-ah32-history-$language');
        await _tab(tester, 1);
        await pumpUntil(tester, find.byType(ReportsScreen));
        await pumpUntilTrue(
          tester,
          () =>
              find.byType(SessionTypeSummary).evaluate().isNotEmpty &&
              tester
                      .widget<SessionTypeSummary>(
                        find.byType(SessionTypeSummary),
                      )
                      .counts
                      .completedExams ==
                  completed,
          reason: 'Reports include each accepted short early completion once',
        );
        final combined = combineStudyAndExamSessions(
          study: [],
          exams: examService.attempts,
        );
        expect(
          combined.fold<int>(0, (sum, s) => sum + s.minutes),
          examService.attempts.fold<int>(0, (sum, a) => sum + a.reportMinutes),
        );
        expect(
          tester
              .widget<SessionTypeSummary>(find.byType(SessionTypeSummary))
              .counts
              .normalSessions,
          0,
        );
        await E2eHost.screenshot(tester, 'e2e-ah32-report-$language');
        debugPrint(
          '[AH32] $language actual=${accepted.actualSeconds}s planned=10800s credited=${accepted.reportMinutes}m revision=1 subjects=2 modules=80/160 duplicate=PASS reportCount=$completed',
        );
      }
      // The normal timer is genuinely available after early completion.
      await _tab(tester, 0);
      await tapOn(tester, find.byKey(const ValueKey('timer-start-pause')));
      await _until(
        tester,
        () async =>
            (await TimerPersistence.instance.load(owner))?.isRunning == true,
        'Normal focus allowed after completed AYT',
      );
      await tapOn(tester, find.widgetWithText(TextButton, _l10n.timerResetBtn));
      await tapOn(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(
            TextButton,
            _l10n.timerResetConfirmAction,
          ),
        ),
      );
      await _until(
        tester,
        () async => await TimerPersistence.instance.load(owner) == null,
        'QA incomplete focus reset',
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        '[AH32] normal focus overlap released; reset only unfinished QA focus; PASS',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
