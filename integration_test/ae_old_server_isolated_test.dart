// A8: a real app against an isolated old local Auth+REST stack, not shared Auth.
// Run only with API54341; E2eHost is used for screenshots, never SQL/email.
// The 25-minute report row is an explicit historical RPC fixture. The visible
// normal timer is started and cancelled; no accelerated timer is enabled.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/onboarding_segment_intent.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/widgets/auth/legal_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'support/e2e.dart';

final _proofs = <String, Object?>{};

Future<void> _guardBeforeReset() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_marathon_process_probe_') ||
        key.startsWith('e2e_first_use_real25_')) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final proof = jsonDecode(raw) as Map;
      expect(
        proof['completion_verified'],
        isTrue,
        reason: 'Do not reset an unfinished real-duration actor',
      );
    }
    expect(
      key.startsWith('active_session_uid_'),
      isFalse,
      reason: 'Do not clear an existing focus timer',
    );
    if (key.startsWith('exam_journal_uid_')) {
      for (final record in jsonDecode(prefs.getString(key)!) as List) {
        final row = record as Map;
        expect(
          row['pending_action'],
          isNull,
          reason: 'Keep any incomplete old/new exam journal',
        );
        expect((row['attempt'] as Map?)?['status'], isNot('active'));
      }
    }
  }
}

Future<ApiAccount> _signUp(String language) async {
  final email = e2eEmail('old-$language');
  final result =
      await LocalApi.request(
            'POST',
            '/auth/v1/signup',
            body: {
              'email': email,
              'password': kE2ePassword,
              'data': {
                'name': 'Legacy QA ${language.toUpperCase()}',
                'avatar_id': 'avatar_16_basic',
                'newsletter': false,
                'marketing_consent': false,
                'terms_version': kLegalDocumentsVersion,
                'privacy_version': kLegalDocumentsVersion,
                'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
              },
            },
          )
          as Map;
  final token = result['access_token'] as String?;
  // This stack autoconfirms. Never fall back to the shared host's Mailpit/Auth.
  expect(token, isNotNull, reason: 'Isolated autoconfirm session required');
  return ApiAccount((result['user'] as Map)['id'] as String, email, token!);
}

Future<Map<String, dynamic>> _verify(ApiAccount account) async {
  final session = Supabase.instance.client.auth.currentSession!;
  expect(session.user.id, account.id);
  final result = Map<String, dynamic>.from(
    await LocalApi.request('GET', '/qa/v1/verify', token: session.accessToken)
        as Map,
  );
  expect(result['database'], 'pomosprint_verify_old_20261028');
  expect(result['exam_rpc_missing'], isTrue);
  expect(result['monthly_rpc_missing'], isTrue);
  expect(result['welcome_disabled'], isTrue);
  expect((result['profile'] as Map)['id'], account.id);
  return result;
}

Future<void> _onboard(WidgetTester tester, String language) async {
  final l10n = lookupAppLocalizations(Locale(language));
  await pumpUntil(
    tester,
    find.byKey(ValueKey('onboarding-language-$language')),
  );
  await tapOn(tester, find.byKey(ValueKey('onboarding-language-$language')));
  await tapOn(
    tester,
    find.byKey(const ValueKey('onboarding-language-continue')),
  );
  await pumpUntil(tester, find.byType(PostAuthOnboardingScreen));
  final picker = find.byType(CupertinoPicker);
  await tester.timedDrag(
    picker,
    const Offset(0, -52.0 * 20),
    const Duration(milliseconds: 1500),
  );
  await pumpFor(tester, const Duration(seconds: 2));
  expect(
    tester.widget<CupertinoPicker>(picker).scrollController!.selectedItem,
    greaterThan(13),
  );
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingSegmentTitle));
  await tapOn(tester, find.text(l10n.onboardingSegmentTus));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingCategoryStepPreparedTitle));
  await E2eHost.screenshot(tester, 'e2e-a8-old-$language-tus-categories');
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingVisibilityYes));
  await tapOn(tester, find.text(l10n.onboardingVisibilityYes));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.gameRulesTitle));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingGoal2h));
  await tapOn(tester, find.text(l10n.onboardingGoal2h));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingGuideTitle));
  await tester.ensureVisible(find.text(l10n.onboardingGuideProfileBody));
  await tapOn(
    tester,
    find.widgetWithText(ElevatedButton, l10n.onboardingFinishBtn),
  );
  await pumpUntil(
    tester,
    find.byType(MainNavigationShell),
    timeout: const Duration(seconds: 45),
  );
  expect(find.text(l10n.onboardingSaveError), findsNothing);
}

Future<void> _reports(
  WidgetTester tester,
  String language,
  Map<String, dynamic> sql,
) async {
  final l10n = lookupAppLocalizations(Locale(language));
  String day(DateTime value) => value.toIso8601String().substring(0, 10);
  int sqlMinutes(DateTime first, DateTime last) => (sql['studies'] as List)
      .where(
        (r) =>
            (r['study_day'] as String).compareTo(day(first)) >= 0 &&
            (r['study_day'] as String).compareTo(day(last)) <= 0,
      )
      .fold<int>(0, (n, r) => n + (r['minutes'] as int));
  await openTab(tester, 1);
  await tapOn(tester, find.text(l10n.reportsDailyTab));
  await pumpUntil(tester, find.byType(DailyReportView));
  await tester
      .widget<DailyReportView>(find.byType(DailyReportView))
      .onRefresh();
  await pumpUntilTrue(
    tester,
    () =>
        tester
            .widget<DailyReportView>(find.byType(DailyReportView))
            .sessions
            .length ==
        1,
    reason: 'legacy report fallback loads its single RPC fixture',
  );
  final daily = tester.widget<DailyReportView>(find.byType(DailyReportView));
  expect(
    sumMinutesBetween(daily.sessions, daily.today, daily.today),
    sqlMinutes(daily.today, daily.today),
  );
  expect(
    daily.sessions.single.kind,
    StudySessionKind.unknown,
    reason:
        'Old server has no kind metadata; do not invent a Marathon/normal kind',
  );
  expect(daily.sessions.single.pending, isFalse);
  await E2eHost.screenshot(tester, 'e2e-a8-old-$language-daily');
  await tapOn(tester, find.text(l10n.reportsWeeklyTab));
  await pumpUntil(tester, find.byType(HistoryScreen));
  final weekly = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
  expect(
    sumMinutesBetween(
      weekly.sessions,
      mondayOf(weekly.today),
      addDays(mondayOf(weekly.today), 6),
    ),
    sqlMinutes(mondayOf(weekly.today), addDays(mondayOf(weekly.today), 6)),
  );
  await tapOn(tester, find.text(l10n.reportsMonthlyTab));
  await pumpUntil(tester, find.byType(MonthlyTrackingScreen));
  final monthly = tester.widget<MonthlyTrackingScreen>(
    find.byType(MonthlyTrackingScreen),
  );
  expect(
    sumMinutesBetween(
      monthly.sessions,
      monthStartOf(monthly.today),
      monthEndOf(monthly.today),
    ),
    sqlMinutes(monthStartOf(monthly.today), monthEndOf(monthly.today)),
  );
  await E2eHost.screenshot(tester, 'e2e-a8-old-$language-monthly');
}

void main() {
  final binding = initE2e();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  for (final language in ['tr', 'en']) {
    testWidgets(
      'ae · isolated old server keeps TUS intent and normal reports ($language)',
      (tester) async {
        final uri = Uri.parse(kSupabaseUrl);
        expect(uri.host, '127.0.0.1');
        expect(
          uri.port,
          54341,
          reason: 'Never bind this legacy scenario to shared/hosted Auth',
        );
        expect(E2eHost.available, isTrue);
        await _guardBeforeReset();
        await resetAppState(tester);
        final account = await _signUp(language);
        await launchApp(tester);
        await waitPastSplash(tester);
        await loginViaUi(tester, account.email);
        await _onboard(tester, language);
        final l10n = lookupAppLocalizations(Locale(language));
        final prefs = await SharedPreferences.getInstance();
        final intentKey = OnboardingSegmentIntentStore.keyFor(account.id);
        expect(prefs.getString(intentKey), 'tus');
        final first = await _verify(account);
        expect((first['profile'] as Map)['segment'], isNull);
        expect((first['profile'] as Map)['onboarded'], isTrue);
        expect(first['categories'] as List, hasLength(8));
        await NotificationService.instance.setEnabled(false);
        await prefs.setBool('league_info_shown_${account.id}', true);

        await openTab(tester, 4);
        await pumpUntil(tester, find.byType(ExamScreen));
        await pumpUntil(tester, find.text(l10n.examUnavailable));
        expect(ExamService.instance.catalog.available, isFalse);
        expect(ExamService.instance.blocksOtherSessions.value, isFalse);
        for (final exam in ExamService.instance.catalog.exams) {
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(ValueKey('exam-start-${exam.id}')),
                )
                .onPressed,
            isNull,
          );
        }
        await E2eHost.screenshot(
          tester,
          'e2e-a8-old-$language-exam-unavailable',
        );

        await openTab(tester, 0);
        await pumpUntil(tester, find.byType(TimerScreen));
        await tapOn(tester, find.byKey(const ValueKey('timer-start-pause')));
        final end = DateTime.now().add(const Duration(seconds: 25));
        ActiveTimerSession? running;
        while (DateTime.now().isBefore(end)) {
          running = await TimerPersistence.instance.load(account.id);
          if (running?.isRunning == true) break;
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(running, isNotNull);
        expect(running!.totalSeconds, 1500);
        expect(running.recordAccelerated, isFalse);
        expect(running.isQuickTest, isFalse);
        await E2eHost.screenshot(tester, 'e2e-a8-old-$language-normal-start');
        await tapOn(tester, find.text(l10n.timerResetBtn));
        await pumpUntil(tester, find.text(l10n.timerResetConfirmTitle));
        await tapOn(tester, find.text(l10n.timerResetConfirmAction).last);
        await pumpUntilGone(tester, find.byType(AlertDialog));
        expect(await TimerPersistence.instance.load(account.id), isNull);
        expect((await _verify(account))['studies'] as List, isEmpty);

        final category = (first['categories'] as List).first as Map;
        final uuid = const Uuid().v4();
        final started = DateTime.now().toUtc().subtract(
          const Duration(minutes: 25, seconds: 3),
        );
        final args = <String, Object?>{
          'p_client_uuid': uuid,
          'p_category_id': category['id'],
          'p_duration_minutes': 25,
          'p_was_paused': false,
          'p_is_verified': 0,
          'p_started_at': started.toIso8601String(),
        };
        final accepted =
            await LocalApi.rpc('complete_study_session', account, args) as Map;
        expect(accepted['duplicate'], isFalse);
        expect(accepted['total_points'], 5);
        expect(accepted['coins_earned'], 20);
        final duplicate =
            await LocalApi.rpc('complete_study_session', account, args) as Map;
        expect(duplicate['duplicate'], isTrue);
        final sql = await _verify(account);
        expect((sql['profile'] as Map)['total_minutes'], 25);
        expect((sql['profile'] as Map)['points'], 5);
        expect((sql['profile'] as Map)['coins'], 20);
        expect(sql['studies'] as List, hasLength(1));
        await SupabaseService.instance.fetchCurrentUserModel();
        await _reports(tester, language, sql);

        await launchApp(tester); // Same owner/auth/preferences; no reset.
        await pumpUntil(
          tester,
          find.byType(MainNavigationShell),
          timeout: const Duration(seconds: 45),
        );
        await SupabaseService.instance.fetchCurrentUserModel();
        expect(SupabaseService.instance.currentUser.value?.id, account.id);
        expect(prefs.getString(intentKey), 'tus');
        final finalSql = await _verify(account);
        expect((finalSql['profile'] as Map)['segment'], isNull);
        expect((finalSql['profile'] as Map)['total_minutes'], 25);
        expect(finalSql['studies'] as List, hasLength(1));
        expect(tester.takeException(), isNull);
        _proofs[language] = {
          'owner_id': account.id,
          'language': language,
          'old_database': finalSql['database'],
          'exam_unavailable': true,
          'tus_intent_retained': true,
          'normal_ui_started_and_cancelled': true,
          'report_minutes': 25,
          'points': 5,
          'coins': 20,
          'study_rows': 1,
          'history_is_controlled_fixture': true,
          'natural_25_minute_wait_claimed': false,
          'shared_auth_used': false,
          'completion_verified': true,
        };
        await prefs.setString(
          'e2e_isolated_old_verified_$e2eRunId',
          jsonEncode(_proofs),
        );
        debugPrint('[ISOLATED_OLD_A8] ${jsonEncode(_proofs[language])}');
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}
