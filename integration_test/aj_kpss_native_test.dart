// Real native KPSS smoke test against one isolated local proposed32 database.
// Keeps official durations intact; starts and abandons only new QA work.
// No SQL mutations, clock changes, reward grants or catalog edits are used.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/exam_reward_policy.dart';
import 'package:pomodoro/models/kpss_catalog.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';

AppLocalizations get _l10n => lookupAppLocalizations(
  Locale(LanguageService.instance.isTurkish ? 'tr' : 'en'),
);

Future<void> _guardExistingWork() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_') ||
        key.startsWith('e2e_marathon_process_probe_') ||
        key.startsWith('e2e_first_use_real25_')) {
      final marker = jsonDecode(prefs.getString(key)!) as Map;
      expect(
        marker['completion_verified'],
        isTrue,
        reason: 'Never reset an unfinished native probe',
      );
    }
    expect(
      key.startsWith('active_session_uid_'),
      isFalse,
      reason: 'Preserve any existing focus or Marathon timer',
    );
    if (key.startsWith('pending_sessions_')) {
      expect(
        jsonDecode(prefs.getString(key)!),
        isEmpty,
        reason: 'Preserve every owner’s pending study queue',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      // Parse raw records so a damaged journal cannot be silently discarded.
      for (final raw in jsonDecode(prefs.getString(key)!) as List) {
        final record = ExamLocalRecord.fromJson(raw);
        expect(record, isNotNull, reason: 'Preserve damaged exam records');
        expect(record!.requiresAttention, isFalse);
        expect(record.detailsDraft, isNull, reason: 'Preserve unsaved results');
        expect(record.pendingResults, isNull);
        expect(record.pendingDetails, isNull);
        expect(record.attempt?.status, isNot(ExamAttemptStatus.active));
      }
    }
  }
  expect(
    ExamService.instance.activeRecord,
    isNull,
    reason: 'Preserve an in-memory active or pending exam',
  );
}

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
    reason: 'profile language $code',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() ready,
  String reason,
) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    if (await ready()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(reason);
}

Finder get _kpssCards => find.byWidgetPredicate(
  (widget) =>
      widget is Card &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('exam-card-kpss_'),
);

void _verifyCatalog(ExamService service) {
  expect(service.catalog.available, isTrue);
  expect(service.catalog.fromServer, isTrue);
  expect(service.catalog.exams, hasLength(20));
  final kpss = service.catalog.exams.where((exam) => exam.segment == 'kpss');
  expect(kpss, hasLength(12));
  for (final expected in kpssExamDefinitions) {
    final actual = service.catalog.byId(expected.id)!;
    expect(actual.nameTr, expected.nameTr);
    expect(actual.nameEn, expected.nameEn);
    expect(actual.durationSeconds, expected.durationSeconds);
    expect(actual.totalQuestions, expected.totalQuestions);
    expect(actual.wrongAnswerDivisor, 4);
    expect(
      actual.subjects.map((s) => s.toJson()).toList(),
      expected.subjects.map((s) => s.toJson()).toList(),
    );
    expect(actual.effectiveRewardPolicyVersion, 2);
    expect(actual.fullRewardCoins, ExamRewardPolicy.byExam[actual.id]!.sand);
    expect(actual.fullRewardPoints, ExamRewardPolicy.byExam[actual.id]!.points);
  }
}

Future<void> _verifySelections(WidgetTester tester, String code) async {
  final service = ExamService.instance;
  final labels = [
    _l10n.examKpssBachelor,
    _l10n.examKpssAssociate,
    _l10n.examKpssSecondary,
    _l10n.examKpssField,
  ];
  expect(find.text(_l10n.examKpssChooseTrack), findsOneWidget);
  for (final label in labels) {
    expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
  }
  for (final track in KpssExamTrack.values) {
    await tapOn(tester, find.byKey(ValueKey('exam-kpss-track-${track.name}')));
    final expected = service.catalog.exams.where(
      (exam) => exam.segment == 'kpss' && kpssTrackForExam(exam.id) == track,
    );
    expect(_kpssCards, findsNWidgets(track == KpssExamTrack.field ? 9 : 1));
    for (final exam in expected) {
      final card = find.byKey(ValueKey('exam-card-${exam.id}'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(exam.name(code == 'tr'))),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text(_l10n.examSubjectQuestions(exam.totalQuestions)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            '${exam.durationSeconds ~/ 60} ${_l10n.minutesUnit}',
          ),
        ),
        findsOneWidget,
      );
    }
    if (track == KpssExamTrack.bachelor || track == KpssExamTrack.field) {
      await E2eHost.screenshot(tester, 'e2e-kpss-${track.name}-$code');
    }
  }
  expect(tester.takeException(), isNull);
}

Future<void> _startAndAbandon(
  WidgetTester tester,
  ApiAccount account,
  String code,
) async {
  final service = ExamService.instance;
  await tapOn(tester, find.byKey(const ValueKey('exam-kpss-track-bachelor')));
  await tapOn(
    tester,
    find.byKey(const ValueKey('exam-start-kpss_bachelor_gygk')),
  );
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
    () => service.activeRecord?.attempt != null,
    reason: 'Official KPSS start is accepted',
  );
  final attempt = service.activeRecord!.attempt!;
  expect(attempt.examId, 'kpss_bachelor_gygk');
  expect(attempt.durationSeconds, 7800);
  expect(attempt.plannedSeconds, 7800);
  expect(service.canFinishEarly(service.activeRecord!), isFalse);
  await pumpFor(tester, const Duration(seconds: 3));
  // The server deadline is rounded up to a displayed second. Wait for the
  // observed deadline instead of assuming three pumped seconds cross it.
  await _until(
    tester,
    () async => attempt.remainingSecondsAt(service.now()) <= 7797,
    'The official KPSS deadline must advance by at least three seconds',
  );
  expect(
    attempt.remainingSecondsAt(service.now()),
    inInclusiveRange(7700, 7797),
  );
  expect(find.text(_l10n.examNoPause), findsOneWidget);
  expect(find.byKey(const ValueKey('exam-finish-early')), findsNothing);
  await E2eHost.screenshot(tester, 'e2e-kpss-running-$code');
  await tapOn(tester, find.widgetWithText(TextButton, _l10n.examAbandon));
  await pumpUntil(tester, find.text(_l10n.examAbandonTitle));
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, _l10n.examAbandon),
    ),
  );
  await pumpUntilTrue(
    tester,
    () => service.activeRecord == null,
    reason: 'KPSS abandonment releases active work',
  );
  final saved = service.attempts.singleWhere((entry) => entry.id == attempt.id);
  expect(saved.status, ExamAttemptStatus.abandoned);
  expect(saved.reportMinutes, 0);
  expect(saved.pointsEarned, 0);
  expect(saved.examCoinsEarned, 0);
  await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
  await E2eHost.screenshot(tester, 'e2e-kpss-abandoned-$code');
  final proof = (await E2eHost.row(
    'select a.status,a.elapsed_seconds,a.points_earned,a.exam_coins_earned,'
    "(a.definition->>'duration_seconds')::int as planned_seconds,"
    'p.user_segment,p.total_minutes,p.lifetime_points,p.coins,'
    'coalesce(w.lifetime_points,0) as exam_points,coalesce(w.coins,0) as exam_coins '
    'from public.exam_attempts a join public.profiles p on p.id=a.user_id '
    'left join public.exam_wallets w on w.user_id=p.id '
    'where a.id=${sqlText(attempt.id)} and a.user_id=${sqlText(account.id)}',
  ))!;
  expect(proof['status'], 'abandoned');
  expect(proof['user_segment'], 'kpss');
  expect(proof['planned_seconds'], 7800);
  for (final key in [
    'points_earned',
    'exam_coins_earned',
    'total_minutes',
    'lifetime_points',
    'coins',
    'exam_points',
    'exam_coins',
  ]) {
    expect(proof[key], 0, reason: key);
  }
}

Future<void> _normalStartAndCancel(WidgetTester tester, String owner) async {
  await _tab(tester, 0);
  await pumpUntil(tester, find.byType(TimerScreen));
  await tapOn(tester, find.byKey(const ValueKey('timer-start-pause')));
  await _until(
    tester,
    () async =>
        (await TimerPersistence.instance.load(owner))?.isRunning == true,
    'Normal focus must start after an abandoned KPSS attempt',
  );
  expect(ExamService.instance.activeRecord, isNull);
  // A denied-notification notice can cover the bottom controls. Dismiss the
  // notice and let the active-session layout settle before scrolling to Reset.
  ScaffoldMessenger.of(
    tester.element(find.byType(TimerScreen)),
  ).clearSnackBars();
  await pumpFor(tester, const Duration(milliseconds: 700));
  final reset = find.widgetWithText(TextButton, _l10n.timerResetBtn);
  await tester.ensureVisible(reset);
  await pumpFor(tester, const Duration(milliseconds: 500));
  await tapOn(tester, reset);
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, _l10n.timerResetConfirmAction),
    ),
  );
  await _until(
    tester,
    () async => await TimerPersistence.instance.load(owner) == null,
    'Only the fresh QA normal focus is cancelled',
  );
  expect(tester.takeException(), isNull);
}

void main() {
  initE2e();
  testWidgets(
    'KPSS official catalog, explicit selections, start and abandon TR EN',
    (tester) async {
      expect(Uri.parse(kSupabaseUrl).port, 54401);
      expect(kE2eHostPort, 54409);
      expect(
        (await E2eHost.row(
          "select current_database()='pomosprint_review32_kpss' as correct_database",
        ))!['correct_database'],
        isTrue,
      );
      await _guardExistingWork();
      final account = await openShellWithNewAccount(
        tester,
        'kpss-${DateTime.now().microsecondsSinceEpoch}',
        name: 'KPSS Kontrol',
        segment: 'kpss',
      );
      expect(SupabaseService.instance.currentUser.value?.id, account.id);
      final service = ExamService.instance;
      for (final code in ['tr', 'en']) {
        await _language(tester, code);
        await _tab(tester, 4);
        await pumpUntil(tester, find.byType(ExamScreen));
        await service.refresh();
        _verifyCatalog(service);
        await tapOn(tester, find.byKey(const ValueKey('exam-tab-new')));
        await tapOn(tester, find.byKey(const ValueKey('exam-filter-kpss')));
        if (code == 'tr') {
          expect(
            _kpssCards,
            findsNothing,
            reason: 'Never infer the exam track',
          );
        }
        await _verifySelections(tester, code);
        await _startAndAbandon(tester, account, code);
        await _normalStartAndCancel(tester, account.id);
        debugPrint(
          '[KPSS_NATIVE] $code official catalog12 tracks4 subjects120/40 '
          'durations130/50/60 TR-EN cards PASS; real3s start-abandon '
          'zeroRewards; normalFocusReleased PASS',
        );
      }
      final totals = (await E2eHost.row(
        'select p.total_minutes,p.lifetime_points,p.coins,'
        'coalesce(w.lifetime_points,0) as exam_points,coalesce(w.coins,0) as exam_coins,'
        '(select count(*) from public.exam_attempts a where a.user_id=p.id '
        "and a.status='abandoned') as abandoned,"
        '(select count(*) from public.study_sessions s where s.user_id=p.id) as studies '
        'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
        'where p.id=${sqlText(account.id)}',
      ))!;
      expect(totals['abandoned'], 2);
      for (final key in [
        'total_minutes',
        'lifetime_points',
        'coins',
        'exam_points',
        'exam_coins',
        'studies',
      ]) {
        expect(totals[key], 0, reason: key);
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
