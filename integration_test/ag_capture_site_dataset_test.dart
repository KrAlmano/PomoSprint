// Controlled capture: isolated final32 local API and same fictional observer.
// Same explicitly prepared local observer, native iOS, TR/EN real UI footage.
// Never signs up, clears preferences, reseeds history, changes clock/catalogue,
// saves net results or purchases/equips an avatar.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/screens/character_collection_screen.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/marathon_progress_card.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';
import 'y_site_media_capture_test.dart' show mediaTapWithoutPointerOverlay;

const _enabled = bool.fromEnvironment('E2E_MEDIA_CAPTURE');
const _email = String.fromEnvironment('E2E_EXAM_FIXTURE_EMAIL');
const _captureVideos = bool.fromEnvironment(
  'E2E_SITE_CAPTURE_VIDEOS',
  defaultValue: true,
);

AppLocalizations get _l10n => lookupAppLocalizations(
  Locale(LanguageService.instance.currentLocale.languageCode),
);

String get _language => LanguageService.instance.currentLocale.languageCode;

/// Same JSON schema as the existing video encoder. Each locale is extracted
/// into its own log using SITE_CAPTURE_LOCALE begin/end records before encoding.
/// The logical coordinates immediately precede actual device-path pointer taps.
class _Events {
  String? scene;

  void emit(Map<String, Object> value) =>
      debugPrint('[MEDIA_EVENT] ${jsonEncode(value)}');

  Future<void> begin(WidgetTester tester, String name) async {
    expect(scene, isNull);
    expect({'timer', 'marathon'}, contains(name));
    scene = name;
    emit({
      'kind': 'scene_start',
      'scene': name,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await pumpFor(tester, const Duration(seconds: 1));
  }

  void end() {
    expect(scene, isNotNull);
    emit({
      'kind': 'scene_end',
      'scene': scene!,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    scene = null;
  }

  Future<void> tap(
    WidgetTester tester,
    Finder target, {
    Duration settle = const Duration(milliseconds: 700),
  }) async {
    expect(target, findsOneWidget);
    if (target.hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(target);
    }
    await pumpUntilTrue(
      tester,
      () => target.hitTestable().evaluate().length == 1,
      reason: 'A capture tap must hit the real visible control',
    );
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    final at = tester.getCenter(target);
    expect(at.dx, inInclusiveRange(0, viewport.width));
    expect(at.dy, inInclusiveRange(0, viewport.height));
    if (scene != null) {
      emit({
        'kind': 'tap',
        'scene': scene!,
        'at': DateTime.now().toUtc().toIso8601String(),
        'x': at.dx,
        'y': at.dy,
        'width': viewport.width,
        'height': viewport.height,
      });
    }
    await mediaTapWithoutPointerOverlay(tester, at);
    await pumpFor(tester, settle);
    expect(tester.takeException(), isNull);
  }
}

final _events = _Events();

Future<void> _preserveDeviceWork() async {
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
    expect(
      key.startsWith('active_session_uid_'),
      isFalse,
      reason: 'Capture never clears an existing timer',
    );
    if (key.startsWith('pending_sessions_')) {
      expect(
        jsonDecode(prefs.getString(key)!),
        isEmpty,
        reason: 'Capture never replaces pending study records',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      for (final raw in jsonDecode(prefs.getString(key)!) as List) {
        final record = ExamLocalRecord.fromJson(raw);
        expect(record, isNotNull);
        expect(record!.pendingAction, isNull);
        expect(
          record.detailsDraft,
          isNull,
          reason: 'Capture preserves unsaved exam details',
        );
        expect(record.attempt?.status, isNot(ExamAttemptStatus.active));
      }
    }
  }
}

Future<Map<String, dynamic>> _economy(String owner) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,'
  'p.current_streak,p.longest_streak,p.last_study_date::text,'
  'coalesce(w.lifetime_points,0) as exam_points,'
  'coalesce(w.coins,0) as exam_coins '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(owner)}',
))!;

Future<void> _tab(WidgetTester tester, int index) async {
  final targets = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byType(NavigationDestination),
  );
  expect(targets, findsNWidgets(5), reason: 'Only the current five-tab app');
  await _events.tap(tester, targets.at(index));
}

Future<void> _back(WidgetTester tester, Type screen) async {
  await _events.tap(
    tester,
    find.descendant(
      of: find.byType(screen),
      matching: find.widgetWithIcon(IconButton, Icons.arrow_back),
    ),
  );
  await pumpUntilGone(tester, find.byType(screen));
}

Future<void> _profile(WidgetTester tester) async {
  await _events.tap(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
}

Future<void> _setLanguage(WidgetTester tester, String language) async {
  expect({'tr', 'en'}, contains(language));
  await _profile(tester);
  await _events.tap(tester, find.text(language == 'tr' ? 'Türkçe' : 'English'));
  await pumpUntilTrue(
    tester,
    () => _language == language,
    reason: 'Real Profile language control selects $language',
  );
  await _back(tester, ProfileScreen);
}

Future<void> _top(WidgetTester tester, Finder screen) async {
  final scroll = find.descendant(of: screen, matching: find.byType(Scrollable));
  // Select a vertical viewport; report tab strips can also scroll horizontally.
  for (final element in scroll.evaluate()) {
    final state = tester.state<ScrollableState>(
      find.byElementPredicate((candidate) => identical(candidate, element)),
    );
    if (state.position.axis == Axis.vertical) {
      state.position.jumpTo(0);
      await pumpFor(tester, const Duration(milliseconds: 350));
      return;
    }
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  String localizedText,
) async {
  expect(_language, anyOf('tr', 'en'));
  final label = find.text(localizedText);
  expect(label, findsWidgets, reason: 'Localized capture anchor $name');
  expect(
    label.hitTestable(),
    findsWidgets,
    reason: 'The localized label must actually be visible in $name',
  );
  expect(
    find.byType(SnackBar),
    findsNothing,
    reason: 'Transient snackbars cannot obscure published screenshots',
  );
  expect(
    tester.view.viewInsets.bottom,
    0,
    reason: 'No system keyboard may obscure published screenshots',
  );
  expect(
    tester.view.physicalSize.height,
    greaterThan(tester.view.physicalSize.width),
  );
  debugPrint(
    '[SITE_CAPTURE] ${jsonEncode({'language': _language, 'name': name, 'visible_label': localizedText, 'at': DateTime.now().toUtc().toIso8601String(), 'native_width': tester.view.physicalSize.width, 'native_height': tester.view.physicalSize.height})}',
  );
  await E2eHost.screenshot(tester, 'e2e-site-20261028-$_language-$name');
  expect(tester.takeException(), isNull);
}

Future<ActiveTimerSession> _timer(
  WidgetTester tester,
  String owner,
  bool Function(ActiveTimerSession) accept,
) async {
  final until = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(until)) {
    final timer = await TimerPersistence.instance.load(owner);
    if (timer != null && accept(timer)) return timer;
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
  fail('A real persisted timer did not arrive');
}

Future<void> _cancelFocus(
  WidgetTester tester,
  String owner, {
  required bool marathon,
}) async {
  await _events.tap(
    tester,
    marathon
        ? find.byKey(const ValueKey('marathon-stop'))
        : find.descendant(
            of: find.byType(TimerScreen),
            matching: find.text(_l10n.timerResetBtn),
          ),
  );
  final dialog = find.byType(AlertDialog);
  await pumpUntil(tester, dialog);
  await _events.tap(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(
        TextButton,
        marathon
            ? _l10n.marathonStopConfirmAction
            : _l10n.timerResetConfirmAction,
      ),
    ),
  );
  await pumpUntilGone(tester, dialog);
  await pumpUntilTrue(
    tester,
    () =>
        find.byKey(const ValueKey('marathon-open-planner')).evaluate().length ==
        1,
    reason: 'Cancelled native focus returns to normal idle layout',
  );
  expect(await TimerPersistence.instance.load(owner), isNull);
  await pumpUntilGone(tester, find.byType(SnackBar));
}

Future<void> _videos(WidgetTester tester, String owner) async {
  await _tab(tester, 0);
  await pumpUntilGone(tester, find.byType(SnackBar));
  final primary = find.byKey(const ValueKey('timer-start-pause'));
  await _events.begin(tester, 'timer');
  for (final minutes in [50, 25]) {
    await _events.tap(tester, find.byKey(ValueKey('timer-duration-$minutes')));
    expect(find.text('$minutes:00'), findsOneWidget);
  }
  final categories = find.descendant(
    of: find.byType(TimerScreen),
    matching: find.byType(FilterChip),
  );
  expect(categories.evaluate().length, greaterThanOrEqualTo(2));
  await _events.tap(tester, categories.at(1));
  await _events.tap(tester, primary);
  final first = await _timer(tester, owner, (s) => s.isRunning);
  expect(first.totalSeconds, 1500);
  expect(first.isQuickTest || first.recordAccelerated, isFalse);
  expect(first.marathon, isNull);
  await pumpFor(tester, const Duration(seconds: 2));
  await _events.tap(tester, primary);
  final paused = await _timer(tester, owner, (s) => !s.isRunning);
  expect(paused.pauseUsedCount, 1);
  await pumpUntilGone(tester, find.byType(SnackBar));
  await _events.tap(tester, primary);
  final resumed = await _timer(tester, owner, (s) => s.isRunning);
  expect(resumed.clientUuid, first.clientUuid);
  await pumpFor(tester, const Duration(seconds: 2));
  await _cancelFocus(tester, owner, marathon: false);
  _events.end();

  await _events.begin(tester, 'marathon');
  await _events.tap(
    tester,
    find.byKey(const ValueKey('marathon-open-planner')),
  );
  final planner = find.byKey(const ValueKey('marathon-planner-dialog'));
  await pumpUntil(tester, planner);
  final preview = find.descendant(
    of: planner,
    matching: find.byType(MarathonProgressCard),
  );
  for (final count in [2, 3, 4]) {
    await _events.tap(tester, find.byKey(ValueKey('marathon-count-$count')));
    expect(tester.widget<MarathonProgressCard>(preview).totalSessions, count);
  }
  for (final minutes in [50, 25]) {
    await _events.tap(
      tester,
      find.byKey(ValueKey('marathon-duration-$minutes')),
    );
    expect(
      tester.widget<MarathonProgressCard>(preview).durationMinutes,
      minutes,
    );
  }
  await _events.tap(tester, find.byKey(const ValueKey('marathon-start')));
  final marathon = await _timer(
    tester,
    owner,
    (s) => s.isRunning && s.marathon != null,
  );
  expect(marathon.totalSeconds, 1500);
  expect(marathon.marathon!.phase, MarathonPhase.focus);
  expect(marathon.marathon!.totalSessions, 4);
  expect(marathon.marathon!.completedSessions, 0);
  expect(marathon.marathon!.breakSeconds, 300);
  await pumpUntilGone(tester, find.byType(SnackBar));
  await pumpFor(tester, const Duration(seconds: 2));
  await _cancelFocus(tester, owner, marathon: true);
  _events.end();
}

Future<void> _examScreens(WidgetTester tester) async {
  await _tab(tester, 4);
  await pumpUntil(tester, find.byType(ExamScreen));
  await pumpUntilTrue(
    tester,
    () =>
        ExamService.instance.catalog.available &&
        ExamService.instance.supportsDetails &&
        ExamService.instance.attempts.length >= 2,
    reason: 'Real official catalogue and prepared completed history',
  );
  expect(
    ExamService.instance.catalog.exams.map((exam) => exam.id).toSet(),
    {
      'tyt',
      'ayt',
      'ydt',
      'lgs_verbal',
      'lgs_quantitative',
      'tus_basic',
      'tus_clinical',
      'dus',
    },
    reason:
        'The final site capture must show the current eight-exam DUS catalog',
  );
  expect(ExamService.instance.catalog.byId('dus')!.durationSeconds, 9000);
  expect(ExamService.instance.catalog.byId('dus')!.totalQuestions, 120);
  await _events.tap(tester, find.byKey(const ValueKey('exam-tab-new')));
  await _top(tester, find.byType(ExamScreen));
  expect(find.byKey(const ValueKey('exam-start-tyt')), findsOneWidget);
  await _shot(tester, 'exam-catalog', _l10n.examTitle);

  await _events.tap(tester, find.byKey(const ValueKey('exam-tab-history')));
  await _top(tester, find.byType(ExamScreen));
  expect(find.text(_l10n.examCompleted), findsWidgets);
  expect(find.text(_l10n.examNoHistory), findsNothing);
  await _shot(tester, 'exam-history', _l10n.examTabHistory);
  final edit = find.widgetWithText(TextButton, _l10n.examDetailsEdit).first;
  await _events.tap(tester, edit);
  await pumpUntil(tester, find.byType(AlertDialog));
  final correct = find.byKey(const ValueKey('exam-result-turkish-0'));
  expect(correct, findsOneWidget);
  expect(tester.widget<TextField>(correct).controller!.text, isNotEmpty);
  expect(ExamService.instance.supportsDetails, isTrue);
  expect(find.byKey(const ValueKey('exam-detail-title')), findsOneWidget);
  expect(find.byKey(const ValueKey('exam-detail-note')), findsOneWidget);
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('exam-detail-title')))
        .controller!
        .text,
    'TYT 02',
  );
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('exam-detail-note')))
        .controller!
        .text,
    '30/4 · 26/5 · 5/1',
  );
  await _shot(tester, 'exam-results', _l10n.examDetailsTitle);
  await _events.tap(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, _l10n.cancel),
    ),
  );
  await pumpUntilGone(tester, find.byType(AlertDialog));

  final paragraph = _l10n.examInsightsChange(
    _language == 'tr' ? 'Fizik' : 'Physics',
    75,
    _language == 'tr' ? '1,75' : '1.75',
    _language == 'tr' ? '4,75' : '4.75',
  );
  final insight = find.text(paragraph);
  await pumpUntil(tester, insight);
  await Scrollable.ensureVisible(tester.element(insight), alignment: .35);
  await pumpFor(tester, const Duration(milliseconds: 400));
  expect(find.text(_l10n.examInsightsEmpty), findsNothing);
  await _shot(tester, 'exam-insights', paragraph);

  await _top(tester, find.byType(ExamScreen));
  await _events.tap(tester, find.byKey(const ValueKey('exam-tab-league')));
  await _top(tester, find.byType(ExamScreen));
  await _events.tap(
    tester,
    find.widgetWithText(ChoiceChip, _l10n.examTargetGroup),
  );
  await pumpUntilTrue(
    tester,
    () => find
        .descendant(
          of: find.byType(ExamScreen),
          matching: find.byType(ListTile),
        )
        .evaluate()
        .isNotEmpty,
    reason: 'Non-empty current-category practice league',
  );
  await _shot(tester, 'league-exam', _l10n.examTabLeague);
}

Future<void> _screens(WidgetTester tester, String owner) async {
  await _tab(tester, 0);
  await _events.tap(tester, find.byKey(const ValueKey('timer-duration-25')));
  expect(find.text('25:00'), findsOneWidget);
  await _shot(tester, 'timer', _l10n.marathonStart);
  await _events.tap(
    tester,
    find.byKey(const ValueKey('marathon-open-planner')),
  );
  final planner = find.byKey(const ValueKey('marathon-planner-dialog'));
  await pumpUntil(tester, planner);
  await _events.tap(tester, find.byKey(const ValueKey('marathon-count-3')));
  await _events.tap(tester, find.byKey(const ValueKey('marathon-duration-25')));
  await _shot(tester, 'marathon-plan', _l10n.marathonChooseCount);
  await _events.tap(tester, find.byKey(const ValueKey('marathon-plan-cancel')));
  await pumpUntilGone(tester, planner);
  expect(await TimerPersistence.instance.load(owner), isNull);

  await _examScreens(tester);

  await _tab(tester, 1);
  await pumpUntil(tester, find.byType(ReportsScreen));
  final reports = find.byType(ReportsScreen);
  for (final range in [
    ('daily', _l10n.reportsDailyTab, DailyReportView),
    ('weekly', _l10n.reportsWeeklyTab, HistoryScreen),
    ('monthly', _l10n.reportsMonthlyTab, MonthlyTrackingScreen),
  ]) {
    await _events.tap(
      tester,
      find.descendant(of: reports, matching: find.text(range.$2)),
    );
    final reportView = find.descendant(
      of: reports,
      matching: find.byType(range.$3),
    );
    await pumpUntil(tester, reportView);
    final sessions = switch (range.$1) {
      'daily' => tester.widget<DailyReportView>(reportView).sessions,
      'weekly' => tester.widget<HistoryScreen>(reportView).sessions,
      _ => tester.widget<MonthlyTrackingScreen>(reportView).sessions,
    };
    expect(
      sessions.fold<int>(0, (total, item) => total + item.minutes),
      455,
      reason: 'Published reports use the complete prepared shared dataset',
    );
    await _top(tester, reports);
    await pumpFor(tester, const Duration(milliseconds: 350));
    await _shot(tester, 'reports-${range.$1}', range.$2);
  }

  await _tab(tester, 2);
  await pumpUntil(tester, find.byType(RankingScreen));
  for (final league in [
    ('category', _l10n.rankingTabLeague),
    ('global', _l10n.rankingTabGlobal),
  ]) {
    await _events.tap(
      tester,
      find.descendant(
        of: find.byType(RankingScreen),
        matching: find.text(league.$2),
      ),
    );
    await _top(tester, find.byType(RankingScreen));
    await pumpUntilTrue(tester, () {
      final standings = find.byType(RankingStandings);
      return standings.evaluate().length == 1 &&
          tester.widget<RankingStandings>(standings).entries.isNotEmpty;
    }, reason: 'Prepared normal ${league.$1} league is populated');
    await _shot(tester, 'league-${league.$1}', league.$2);
  }

  await _tab(tester, 3);
  await pumpUntil(tester, find.byType(SocialScreen));
  await _top(tester, find.byType(SocialScreen));
  await pumpUntilTrue(
    tester,
    () =>
        find.text(_l10n.socialFocusing).evaluate().length == 2 &&
        find.text(_l10n.socialOnBreak).evaluate().length == 2 &&
        find.text(_l10n.socialTakingExam).evaluate().length == 2,
    reason: 'All six exact local friends: two focus, two break, two exam',
  );
  final social = find.byType(SocialScreen);
  final cards = find.descendant(
    of: social,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('social-friend-'),
    ),
  );
  expect(cards, findsNWidgets(6));
  // Inspect all actual card rectangles, rather than claiming a sixth offscreen
  // friend is visible merely because its widget was built.
  final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
  final socialViewport = find.descendant(
    of: social,
    matching: find.byType(CustomScrollView),
  );
  expect(socialViewport, findsOneWidget);
  final visibleListBounds = tester.getRect(socialViewport);
  for (final name in ['Ece', 'Mert', 'Ada', 'Arda', 'Duru', 'Can']) {
    expect(
      find.descendant(of: social, matching: find.text(name)).hitTestable(),
      findsOneWidget,
    );
  }
  for (var i = 0; i < 6; i++) {
    final rect = tester.getRect(cards.at(i));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(viewport.height));
    expect(rect.top, greaterThanOrEqualTo(visibleListBounds.top));
    expect(rect.bottom, lessThanOrEqualTo(visibleListBounds.bottom));
    expect(cards.at(i).hitTestable(), findsOneWidget);
  }
  await _shot(tester, 'social', _l10n.socialYourFriends);

  await _profile(tester);
  final avatarChange = find.descendant(
    of: find.byType(ProfileScreen),
    matching: find.byWidgetPredicate(
      (widget) => widget is AvatarWidget && widget.size == 96,
    ),
  );
  await _events.tap(tester, avatarChange);
  await pumpUntil(tester, find.byType(CharacterCollectionScreen));
  await _top(tester, find.byType(CharacterCollectionScreen));
  await _shot(tester, 'avatar-collection', _l10n.selectCharacter);
  await _back(tester, CharacterCollectionScreen);
  await _back(tester, ProfileScreen);
}

Future<void> _runningPair(WidgetTester tester, String owner) async {
  await _setLanguage(tester, 'tr');
  await _tab(tester, 4);
  await _events.tap(tester, find.byKey(const ValueKey('exam-tab-new')));
  await _top(tester, find.byType(ExamScreen));
  final exam = ExamService.instance.catalog.byId('tyt');
  expect(exam, isNotNull);
  expect(
    exam!.durationSeconds,
    9900,
    reason:
        'Media must show the real official catalogue, never a short fixture',
  );
  expect(exam.totalQuestions, 120);
  await _events.tap(tester, find.byKey(const ValueKey('exam-start-tyt')));
  await pumpUntil(tester, find.text(_l10n.examRulesTitle));
  await _events.tap(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, _l10n.examReady),
    ),
  );
  await pumpUntil(
    tester,
    find.byKey(const ValueKey('exam-countdown')),
    timeout: const Duration(seconds: 20),
  );
  final attempt = ExamService.instance.activeRecord!.attempt!;
  expect(attempt.durationSeconds, 9900);
  expect(attempt.status, ExamAttemptStatus.active);
  for (final language in ['tr', 'en']) {
    if (_language != language) await _setLanguage(tester, language);
    await _top(tester, find.byType(ExamScreen));
    expect(find.text(_l10n.examNoPause), findsOneWidget);
    await _shot(tester, 'exam-running', _l10n.examRunning);
  }
  // Only one new abandoned history row, AFTER both history/net/insight sets.
  await _events.tap(tester, find.widgetWithText(TextButton, _l10n.examAbandon));
  await pumpUntil(tester, find.byType(AlertDialog));
  await _events.tap(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, _l10n.examAbandon),
    ),
  );
  await pumpUntilTrue(
    tester,
    () => ExamService.instance.activeRecord == null,
    reason: 'Final official demo attempt explicitly abandoned via UI',
  );
  final row = await E2eHost.row(
    'select status,points_earned,exam_coins_earned from public.exam_attempts '
    'where id=${sqlText(attempt.id)} and user_id=${sqlText(owner)}',
  );
  expect(row, {
    'status': 'abandoned',
    'points_earned': 0,
    'exam_coins_earned': 0,
  });
}

void main() {
  final binding = _enabled
      ? initE2e()
      : IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    'ag · same local Deniz demo, current iPhone TR/EN site dataset',
    (tester) async {
      expect(Platform.isIOS, isTrue, reason: 'Website media is iOS only');
      expect(E2eHost.available, isTrue);
      expect(
        kSupabaseUrl,
        'http://127.0.0.1:54361',
        reason: 'Capture refuses shared main Auth and hosted APIs',
      );
      expect(
        kE2eHostPort,
        54379,
        reason: 'Only the dedicated isolated final32 screenshot/SQL host',
      );
      expect(
        const String.fromEnvironment(
          'E2E_HOST_ADDRESS',
          defaultValue: '127.0.0.1',
        ),
        '127.0.0.1',
      );
      final target = await E2eHost.row(
        "select current_database() as database, "
        "exists(select 1 from supabase_migrations.schema_migrations where version='20261028060000') as has32, "
        "exists(select 1 from supabase_migrations.schema_migrations where version='20261028050000') as has31",
      );
      expect(target, {
        'database': 'pomosprint_site32_dus',
        'has32': true,
        'has31': false,
      });
      expect(
        RegExp(
          r'^e2e-sim-site-demo-[a-z0-9][a-z0-9-]{0,23}-observer@pomosprint\.local$',
        ).hasMatch(_email),
        isTrue,
      );
      await _preserveDeviceWork();
      final identity = await E2eHost.row(
        'select id::text,email,'
        "raw_user_meta_data->>'qa_site_capture' as tag,"
        "raw_user_meta_data->>'qa_fixture_role' as role,"
        "raw_user_meta_data->>'qa_fixture_run' as run "
        'from auth.users where email=${sqlText(_email)}',
      );
      expect(identity, isNotNull);
      expect(identity!['tag'], 'controlled-local-demo-v1');
      expect(identity['role'], 'observer');
      expect(identity['email'], _email);
      expect(
        identity['run'],
        _email.substring(
          'e2e-sim-site-demo-'.length,
          _email.length - '-observer@pomosprint.local'.length,
        ),
        reason: 'Exact observer email and seed-run metadata must match',
      );
      final owner = identity['id'] as String;
      final before = await _economy(owner);
      expect(before['total_minutes'], 455);
      expect(before['lifetime_points'], 29);
      expect(before['coins'], 80);
      expect(before['exam_points'], 66);
      expect(before['exam_coins'], 260);
      expect(before['current_streak'], 2);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await launchApp(tester);
      await waitPastSplash(tester);
      final service = SupabaseService.instance;
      if (service.currentUser.value?.id != owner) {
        if (service.currentUser.value != null) {
          await service.signOutFully();
          await pumpUntil(tester, find.byType(LoginScreen));
        }
        // The existing login helper uses the TR submit label. Select TR through
        // the actual public login language control; do not clear saved prefs.
        if (_language != 'tr') {
          await _events.tap(
            tester,
            find.descendant(
              of: find.byType(LoginScreen),
              matching: find.text('TR'),
            ),
          );
          await pumpUntilTrue(
            tester,
            () => _language == 'tr',
            reason: 'Existing login UI helper uses the real Turkish form',
          );
        }
        await loginViaUi(tester, _email);
      }
      await pumpUntil(tester, find.byType(MainNavigationShell));
      expect(service.currentUser.value?.id, owner);
      expect(service.currentUser.value?.name, 'Deniz');
      await NotificationService.instance.setEnabled(false);
      // Skip a previously unseen help sheet only for this exact demo installation.
      // No preferences are cleared and no account/history is reset.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('league_info_shown_$owner', true);
      try {
        for (final language in ['tr', 'en']) {
          await _setLanguage(tester, language);
          debugPrint(
            '[SITE_CAPTURE_LOCALE] ${jsonEncode({'kind': 'begin', 'language': language})}',
          );
          await _screens(tester, owner);
          expect(
            await _economy(owner),
            before,
            reason:
                'Viewing all translated pages does not change either economy',
          );
          if (_captureVideos) await _videos(tester, owner);
          expect(
            await _economy(owner),
            before,
            reason: 'Clips cancel incomplete focus; no fabricated rewards',
          );
          debugPrint(
            '[SITE_CAPTURE_LOCALE] ${jsonEncode({'kind': 'end', 'language': language})}',
          );
        }
        await _runningPair(tester, owner);
        expect(
          await _economy(owner),
          before,
          reason:
              'One explicitly abandoned demo exam earns no duration/rewards',
        );
        expect(tester.takeException(), isNull);
        debugPrint(
          '[SITE_CAPTURE_COMPLETE] thirty actual screenshots; same Deniz owner, TR/EN, official durations, no history reseed',
        );
      } finally {
        // Restrict emergency cancellation to this exact freshly tagged observer.
        // Preserve all history, pending queues, other owners and real probe data.
        if (service.currentUser.value?.id == owner) {
          final active = ExamService.instance.activeRecord;
          if (active?.attempt?.status == ExamAttemptStatus.active) {
            await ExamService.instance.abandon(active!.clientUuid);
          }
          final timer = await TimerPersistence.instance.load(owner);
          if (timer != null && !timer.isFinishedAt(DateTime.now())) {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await service.cancelStudySession();
            await TimerPersistence.instance.clear(
              owner,
              onlyClientUuid: timer.clientUuid,
            );
          }
        }
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
