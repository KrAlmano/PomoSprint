// Official DUS start/abandon or explicitly opted-in natural60s/zero-reward QA.
// Root owns temporary catalog setup/exact restore; this test never writes it.
// This file never changes catalog, timestamps, rewards or server configuration.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/exam_reward_policy.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';

const shortMode = bool.fromEnvironment('E2E_DUS_SHORT');

AppLocalizations get l10n => lookupAppLocalizations(
  Locale(LanguageService.instance.isTurkish ? 'tr' : 'en'),
);
Future<void> waitFor(
  WidgetTester tester,
  bool Function() ready,
  String reason, {
  Duration timeout = const Duration(seconds: 30),
}) async => pumpUntilTrue(tester, ready, reason: reason, timeout: timeout);
Future<void> language(WidgetTester tester, String value) async {
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
  await tapOn(tester, find.text(value == 'tr' ? 'Türkçe' : 'English'));
  await waitFor(
    tester,
    () => LanguageService.instance.currentLocale.languageCode == value,
    'language $value',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<void> preserveExistingWork() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_marathon_process_probe_') ||
        key.startsWith('e2e_first_use_real25_')) {
      expect(
        (jsonDecode(prefs.getString(key)!) as Map)['completion_verified'],
        isTrue,
        reason: 'Preserve unfinished probe',
      );
    }
    expect(
      key.startsWith('active_session_uid_'),
      isFalse,
      reason: 'Preserve active normal focus',
    );
    if (key.startsWith('exam_journal_uid_')) {
      for (final row in await ExamPersistence().read(
        key.substring('exam_journal_uid_'.length),
      )) {
        expect(
          row.pendingAction,
          isNull,
          reason: 'Preserve pending exam action',
        );
        expect(row.attempt?.status, isNot(ExamAttemptStatus.active));
      }
    }
  }
}

Future<void> enterField(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await pumpFor(tester, const Duration(milliseconds: 100));
  await tapOn(tester, finder, settle: const Duration(milliseconds: 100));
  await tester.enterText(finder, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(tester, const Duration(milliseconds: 100));
}

Future<void> finishShort(
  WidgetTester tester,
  ApiAccount account,
  ExamAttempt attempt,
  String code,
  int completed,
) async {
  final service = ExamService.instance;
  await waitFor(
    tester,
    () => service.activeRecord == null,
    'Natural60s DUS completion',
    timeout: const Duration(seconds: 95),
  );
  final done = service.attempts.singleWhere((a) => a.id == attempt.id);
  expect(done.status, ExamAttemptStatus.completed);
  expect(done.durationSeconds, 60);
  expect(done.actualSeconds, 60);
  expect(done.plannedSeconds, 60);
  expect(done.pointsEarned, 0);
  expect(done.examCoinsEarned, 0);
  expect(done.reportMinutes, 1);
  expect(done.definition!.fullRewardPoints, 0);
  expect(done.definition!.fullRewardCoins, 0);
  await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
  await tapOn(
    tester,
    find.widgetWithText(TextButton, l10n.examDetailsEdit).first,
  );
  await pumpUntil(tester, find.byType(AlertDialog));
  expect(find.byType(CheckboxListTile), findsNothing);
  for (final subject in done.definition!.subjects) {
    expect(find.byKey(ValueKey('exam-result-${subject.id}-0')), findsOneWidget);
  }
  await enterField(tester, 'exam-result-anatomy-0', '3');
  await enterField(tester, 'exam-result-anatomy-1', '1');
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('exam-result-anatomy-2')))
        .controller!
        .text,
    '2',
  );
  await enterField(tester, 'exam-result-pediatric_dentistry-0', '7');
  await enterField(tester, 'exam-result-pediatric_dentistry-1', '2');
  expect(
    tester
        .widget<TextField>(
          find.byKey(const ValueKey('exam-result-pediatric_dentistry-2')),
        )
        .controller!
        .text,
    '1',
  );
  final title = code == 'tr' ? 'DUS kısa kontrol' : 'DUS short check';
  final note = code == 'tr'
      ? 'Kontrollü60 saniye, sıfır ödül.'
      : 'Controlled60 seconds, zero reward.';
  await enterField(tester, 'exam-detail-title', title);
  await enterField(tester, 'exam-detail-note', note);
  await E2eHost.screenshot(tester, 'e2e-dus-short-details-$code');
  await tapOn(tester, find.widgetWithText(FilledButton, l10n.examSaveResults));
  await pumpUntilGone(tester, find.byType(AlertDialog));
  await waitFor(
    tester,
    () =>
        service.attempts
            .singleWhere((a) => a.id == attempt.id)
            .detailsRevision ==
        1,
    'One atomic DUS details revision',
  );
  final saved = service.attempts.singleWhere((a) => a.id == attempt.id);
  expect(saved.title, title);
  expect(saved.note, note);
  expect(saved.subjectResults, hasLength(2));
  final replay =
      await LocalApi.rpc('save_exam_details', account, {
            'p_attempt_id': attempt.id,
            'p_details': {'title': title, 'note': note},
            'p_subject_results': saved.subjectResults
                .map((r) => r.toJson())
                .toList(),
            'p_expected_revision': 0,
          })
          as Map;
  expect(replay['duplicate'], isTrue);
  final completionReplay =
      await LocalApi.rpc('complete_exam_attempt', account, {
            'p_attempt_id': attempt.id,
          })
          as Map;
  expect(completionReplay['duplicate'], isTrue);
  final proof = (await E2eHost.row(
    'select a.status,a.elapsed_seconds,a.points_earned,a.exam_coins_earned,a.details_revision,p.total_minutes,p.lifetime_points,p.coins,(select count(*) from public.exam_subject_results r where r.attempt_id=a.id) as results from public.exam_attempts a join public.profiles p on p.id=a.user_id where a.id=${sqlText(attempt.id)} and a.user_id=${sqlText(account.id)}',
  ))!;
  expect(proof['status'], 'completed');
  expect(proof['elapsed_seconds'], 60);
  expect(proof['details_revision'], 1);
  expect(proof['results'], 2);
  expect(proof['total_minutes'], completed);
  for (final key in [
    'points_earned',
    'exam_coins_earned',
    'lifetime_points',
    'coins',
  ]) {
    expect(proof[key], 0, reason: key);
  }
  await E2eHost.screenshot(tester, 'e2e-dus-short-history-$code');
  await openTab(tester, 1);
  await pumpUntil(tester, find.byType(ReportsScreen));
  await waitFor(
    tester,
    () =>
        find.byType(SessionTypeSummary).evaluate().isNotEmpty &&
        tester
                .widget<SessionTypeSummary>(find.byType(SessionTypeSummary))
                .counts
                .completedExams ==
            completed,
    'DUS report count',
  );
  expect(
    combineStudyAndExamSessions(
      study: [],
      exams: service.attempts,
    ).fold<int>(0, (n, s) => n + s.minutes),
    completed,
  );
  expect(
    tester
        .widget<SessionTypeSummary>(find.byType(SessionTypeSummary))
        .counts
        .normalSessions,
    0,
  );
  await E2eHost.screenshot(tester, 'e2e-dus-short-report-$code');
  debugPrint(
    '[DUS_SHORT] $code actual60s planned60s zeroRewards results2 revision1 reportCount=$completed reportMinutes=$completed duplicatePASS; CONTROLLED CATALOG, NOT official150min30/120 proof',
  );
}

void main() {
  initE2e();
  testWidgets(
    shortMode
        ? 'DUS controlled60s zero-reward completion details reports TR EN'
        : 'DUS official150min120questions real start-abandon TR EN',
    (tester) async {
      expect(
        (await E2eHost.row(
          "select current_database()='pomosprint_review32_dus' as target",
        ))!['target'],
        isTrue,
      );
      final snapshot = (await E2eHost.row(
        "select (definition->>'duration_seconds')::int as seconds,(definition->>'reward_points')::int as points,(definition->>'reward_coins')::int as coins from public.exam_catalog where id='dus' and enabled",
      ))!;
      expect(snapshot, {
        'seconds': shortMode ? 60 : 9000,
        'points': shortMode ? 0 : 30,
        'coins': shortMode ? 0 : 120,
      }, reason: 'Exact isolated DUS catalog before account/reset');
      if (shortMode) {
        debugPrint(
          '[DUS_SHORT] Controlled60s/0points/0sand; root owns exact catalog restore; no official150min award claim',
        );
      }
      await preserveExistingWork();
      final account = await openShellWithNewAccount(
        tester,
        shortMode ? 'dus-short' : 'dus',
        name: 'DUS Kontrol',
        segment: 'dus',
      );
      final service = ExamService.instance;
      for (final code in ['tr', 'en']) {
        await language(tester, code);
        await openTab(tester, 4);
        await pumpUntil(tester, find.byType(ExamScreen));
        await service.refresh();
        expect(service.catalog.exams, hasLength(8));
        final dus = service.catalog.byId('dus')!;
        expect(dus.durationSeconds, shortMode ? 60 : 9000);
        expect(dus.totalQuestions, 120);
        expect(dus.subjects, hasLength(16));
        expect(
          dus.subjects.take(8).fold<int>(0, (n, s) => n + s.questionCount),
          40,
        );
        expect(
          dus.subjects.skip(8).fold<int>(0, (n, s) => n + s.questionCount),
          80,
        );
        expect(dus.fullRewardPoints, shortMode ? 0 : 30);
        expect(dus.fullRewardCoins, shortMode ? 0 : 120);
        for (final other in service.catalog.exams.where((e) => e.id != 'dus')) {
          expect(
            other.fullRewardPoints,
            ExamRewardPolicy.byExam[other.id]!.points,
          );
          expect(
            other.fullRewardCoins,
            ExamRewardPolicy.byExam[other.id]!.sand,
          );
        }
        await tapOn(tester, find.byKey(const ValueKey('exam-tab-new')));
        await tapOn(tester, find.widgetWithText(ChoiceChip, 'DUS'));
        expect(find.byKey(const ValueKey('exam-start-tyt')), findsNothing);
        await E2eHost.screenshot(
          tester,
          shortMode ? 'e2e-dus-short-catalog-$code' : 'e2e-dus-catalog-$code',
        );
        await tapOn(tester, find.byKey(const ValueKey('exam-start-dus')));
        await pumpUntil(tester, find.text(l10n.examRulesTitle));
        await tapOn(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, l10n.examReady),
          ),
        );
        await waitFor(
          tester,
          () => service.activeRecord?.attempt != null,
          'DUS accepted',
        );
        final attempt = service.activeRecord!.attempt!;
        expect(attempt.examId, 'dus');
        expect(attempt.durationSeconds, shortMode ? 60 : 9000);
        await pumpFor(tester, const Duration(seconds: 3));
        expect(
          attempt.remainingSecondsAt(service.now()),
          shortMode ? inInclusiveRange(1, 59) : inInclusiveRange(8800, 8999),
        );
        expect(find.text(l10n.examNoPause), findsOneWidget);
        expect(find.byKey(const ValueKey('exam-finish-early')), findsNothing);
        await E2eHost.screenshot(
          tester,
          shortMode ? 'e2e-dus-short-running-$code' : 'e2e-dus-running-$code',
        );
        if (shortMode) {
          await finishShort(
            tester,
            account,
            attempt,
            code,
            code == 'tr' ? 1 : 2,
          );
          continue;
        }
        await tapOn(tester, find.widgetWithText(TextButton, l10n.examAbandon));
        await pumpUntil(tester, find.text(l10n.examAbandonTitle));
        await tapOn(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, l10n.examAbandon),
          ),
        );
        await waitFor(
          tester,
          () => service.activeRecord == null,
          'DUS abandonment accepted',
        );
        final saved = service.attempts.singleWhere((a) => a.id == attempt.id);
        expect(saved.status, ExamAttemptStatus.abandoned);
        expect(saved.pointsEarned, 0);
        expect(saved.examCoinsEarned, 0);
        expect(saved.reportMinutes, 0);
        await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
        await E2eHost.screenshot(tester, 'e2e-dus-abandoned-$code');
        final proof = (await E2eHost.row(
          'select a.status,a.elapsed_seconds,a.points_earned,a.exam_coins_earned,p.total_minutes,p.lifetime_points,p.coins from public.exam_attempts a join public.profiles p on p.id=a.user_id where a.id=${sqlText(attempt.id)} and a.user_id=${sqlText(account.id)}',
        ))!;
        expect(proof['status'], 'abandoned');
        for (final key in [
          'points_earned',
          'exam_coins_earned',
          'total_minutes',
          'lifetime_points',
          'coins',
        ]) {
          expect(proof[key], 0, reason: key);
        }
        debugPrint(
          '[DUS_NATIVE] $code official9000s questions120 subjects16 fullReference30/120 start-abandon zeroAward PASS',
        );
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
