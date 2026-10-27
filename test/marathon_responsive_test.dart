import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/responsive.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:pomodoro/widgets/shell_app_bar.dart';
import 'package:pomodoro/widgets/shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

const _sizes = [
  Size(320, 568),
  Size(390, 844),
  Size(568, 320),
  Size(844, 390),
  Size(820, 1180),
  Size(1180, 820),
];

// Same portable SDK lookup as timer_screenshots_test.dart. The broad layout
// matrix uses Flutter's deliberately wide Ahem font; exact initial viewport
// visibility below uses the app's real Roboto/Material fonts.
Future<void> _loadSdkFonts() async {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  final executable = Platform.resolvedExecutable;
  final cacheIndex = executable.indexOf(
    '${Platform.pathSeparator}bin${Platform.pathSeparator}cache',
  );
  final root = fromEnv != null && fromEnv.isNotEmpty
      ? fromEnv
      : cacheIndex > 0
      ? executable.substring(0, cacheIndex)
      : '';
  final fontDirectory = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.view((await File('$fontDirectory/$name').readAsBytes()).buffer);
  final roboto = FontLoader('Roboto');
  for (final file in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
  ]) {
    roboto.addFont(read(file));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

void main() {
  // One fake-async region keeps TimerPersistence's singleton lock local.
  // No network/platform channels are used in this geometry/interaction matrix.
  testWidgets(
    'Maraton popup ve normal sayaç geometrisi altı boyutta TR/EN büyük yazıda korunur',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(tester.view.reset);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final now = DateTime(2026, 10, 7, 12);
      var serial = 0;
      var unexpectedSubmissions = 0;
      var unexpectedConfirmations = 0;
      var focusStarts = 0;

      Future<void> drain() async {
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }

      Future<void> unmount() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await drain();
      }

      Future<void> tapKey(String key) async {
        final finder = find.byKey(ValueKey(key));
        expect(finder, findsOneWidget, reason: '$key exists');
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder);
        await drain();
      }

      Future<void> expectReachable(
        Finder finder,
        Size size,
        String label,
      ) async {
        expect(finder, findsOneWidget, reason: label);
        await tester.ensureVisible(finder);
        await tester.pump();
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(0), reason: label);
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: label);
        expect(
          rect.width,
          greaterThanOrEqualTo(kMinInteractiveDimension - .001),
          reason: label,
        );
        expect(
          rect.height,
          greaterThanOrEqualTo(kMinInteractiveDimension - .001),
          reason: label,
        );
        expect(
          finder.hitTestable(),
          findsOneWidget,
          reason:
              '$label target $rect; visible SnackBars: ${[for (var i = 0; i < find.byType(SnackBar).evaluate().length; i++) tester.getRect(find.byType(SnackBar).at(i))]}',
        );
        expect(tester.takeException(), isNull, reason: label);
      }

      void expectEntryDesign(
        String label, {
        bool active = false,
        bool disabled = false,
      }) {
        final key = active
            ? 'marathon-active-progress'
            : 'marathon-open-planner';
        final entry = find.byKey(ValueKey(key));
        final button = tester.widget<ButtonStyleButton>(entry);
        final states = disabled
            ? const <WidgetState>{WidgetState.disabled}
            : const <WidgetState>{};
        final surface = find.byKey(const ValueKey('marathon-entry-surface'));
        final decoration =
            tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
        expect(
          decoration.color!.a,
          greaterThan(0),
          reason: '$label shared Maraton box has visible fill',
        );
        final border = decoration.border! as Border;
        expect(
          border.top.width,
          greaterThan(0),
          reason: '$label shared Maraton box has outline',
        );
        expect(
          border.top.color.a,
          greaterThan(0),
          reason: '$label shared Maraton outline visible',
        );
        expect(
          button.style!.shape!.resolve(states),
          isA<StadiumBorder>(),
          reason: '$label main action has pill-shaped feedback',
        );
        final entryRect = tester.getRect(entry);
        expect(
          entryRect.height,
          closeTo(48, .001),
          reason: '$label accessible row height is preserved',
        );
        final surfaceRect = tester.getRect(surface);
        expect(
          surfaceRect.height,
          closeTo(40, .001),
          reason: '$label visible Maraton box is smaller',
        );
        expect(
          surfaceRect.width,
          lessThanOrEqualTo(280.001),
          reason: '$label visible Maraton box is compact',
        );
        final info = find.byKey(const ValueKey('marathon-info'));
        final help = tester.widget<IconButton>(info);
        expect(
          help.style!.shape!.resolve(const <WidgetState>{}),
          isA<CircleBorder>(),
          reason: '$label help retains circular touch feedback',
        );
        final circle = find.byKey(const ValueKey('marathon-info-circle'));
        final helpCircle = tester.widget<Container>(circle);
        final circleDecoration = helpCircle.decoration! as BoxDecoration;
        expect(circleDecoration.shape, BoxShape.circle);
        expect(circleDecoration.color!.a, greaterThan(0));
        expect(
          (helpCircle.child! as Icon).icon,
          Icons.question_mark_rounded,
          reason: '$label help displays the question mark',
        );
        final circleRect = tester.getRect(circle);
        expect(circleRect.width, closeTo(18, .001));
        expect(circleRect.height, closeTo(18, .001));
        expect(circleRect.left, greaterThan(entryRect.right));
        expect(circleRect.right, lessThan(surfaceRect.right));
        expect(circleRect.top, greaterThan(surfaceRect.top));
        expect(circleRect.bottom, lessThan(surfaceRect.bottom));
        final helpRect = tester.getRect(info);
        expect(helpRect.width, closeTo(48, .001));
        expect(helpRect.height, closeTo(48, .001));
        expect(
          helpRect.top,
          closeTo(entryRect.top, .001),
          reason: '$label actions share the same row',
        );
        expect(
          helpRect.left,
          closeTo(entryRect.right, .001),
          reason: '$label help is inside the shared box without an outside gap',
        );
      }

      void expectPlannerCountDesign(
        AppLocalizations l10n,
        String label, {
        required int selected,
      }) {
        expect(
          find.text(l10n.marathonChooseCount),
          findsOneWidget,
          reason: '$label popup title is the count question',
        );
        final rects = <Rect>[];
        for (final count in [2, 3, 4]) {
          final option = find.byKey(ValueKey('marathon-count-$count'));
          final button = tester.widget<OutlinedButton>(option);
          expect(
            button.style!.shape!.resolve(const <WidgetState>{}),
            isA<CircleBorder>(),
            reason: '$label count$count is circular',
          );
          final rect = tester.getRect(option);
          expect(
            rect.width,
            closeTo(56, .001),
            reason: '$label count$count 56dp width',
          );
          expect(
            rect.height,
            closeTo(56, .001),
            reason: '$label count$count 56dp height',
          );
          rects.add(rect);
          final semantics = tester.widget<Semantics>(
            find.byKey(ValueKey('marathon-count-semantics-$count')),
          );
          expect(semantics.properties.label, l10n.marathonSessionCount(count));
          expect(
            semantics.properties.selected,
            count == selected,
            reason: '$label count$count selected semantics',
          );
          expect(
            find.descendant(of: option, matching: find.text('$count')),
            findsOneWidget,
            reason: '$label numeric count$count',
          );
        }
        expect(
          rects[0].center.dy,
          closeTo(rects[1].center.dy, .001),
          reason: '$label circles one row',
        );
        expect(
          rects[1].center.dy,
          closeTo(rects[2].center.dy, .001),
          reason: '$label circles one row',
        );
        expect(
          rects[1].center.dx - rects[0].center.dx,
          closeTo(rects[2].center.dx - rects[1].center.dx, .001),
          reason: '$label equal circle spacing',
        );
      }

      Rect hourglassRect() => tester.getRect(find.byType(HourglassWidget));
      double hourglassSize() =>
          tester.widget<HourglassWidget>(find.byType(HourglassWidget)).size;

      Future<void> expectLandscape(
        AppLocalizations l10n,
        Size size,
        String label, {
        MarathonPhase? phase,
        bool paused = false,
        bool pauseUsed = false,
      }) async {
        final onBreak = phase == MarathonPhase.breakTime;
        final onPresence = phase == MarathonPhase.awaitingPresence;
        for (final key in [
          'timer-duration-25',
          'timer-duration-50',
          'marathon-open-planner',
          'marathon-active-progress',
          'marathon-info',
          'marathon-count-2',
        ]) {
          expect(
            find.byKey(ValueKey(key)),
            findsNothing,
            reason: '$label landscape excludes $key',
          );
        }
        expect(find.byType(AppBar), findsNothing, reason: '$label no header');
        expect(
          find.byType(NavigationBar),
          findsNothing,
          reason: '$label no bar',
        );
        expect(
          find.byType(NavigationRail),
          findsNothing,
          reason: '$label no rail',
        );
        final pauseIndicator = find.byKey(const ValueKey('timer-pause-credit'));
        if (onBreak || onPresence) {
          expect(pauseIndicator, findsNothing);
        } else {
          expect(pauseIndicator, findsOneWidget);
          expect(
            find.text(
              paused || pauseUsed
                  ? l10n.pauseCreditUsed
                  : l10n.pauseCreditAvailable,
            ),
            findsOneWidget,
            reason: '$label landscape keeps the current pause allowance',
          );
          final labelText = find.descendant(
            of: pauseIndicator,
            matching: find.byType(Text),
          );
          expect(tester.widget<Text>(labelText).maxLines, 1);
          expect(
            find.ancestor(of: labelText, matching: find.byType(FittedBox)),
            findsOneWidget,
            reason: '$label long allowance text fits without growing controls',
          );
          final pauseRect = tester.getRect(pauseIndicator);
          expect(pauseRect.top, greaterThanOrEqualTo(0));
          expect(pauseRect.bottom, lessThanOrEqualTo(size.height));
        }
        for (final category in CourseCategory.initialCategories().take(2)) {
          expect(
            find.text(LanguageService.instance.translateCatName(category.name)),
            findsNothing,
            reason: '$label no category selector',
          );
        }
        expect(find.byIcon(Icons.waving_hand), findsNothing);
        expect(find.byIcon(Icons.waving_hand_rounded), findsNothing);
        expect(
          find.byType(HourglassWidget),
          onBreak ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('marathon-break-cup')),
          onBreak ? findsOneWidget : findsNothing,
          reason: '$label coffee is limited to break',
        );
        expect(
          find.byKey(const ValueKey('marathon-presence')),
          onPresence ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('timer-landscape-control')),
          findsOneWidget,
          reason: '$label minimal control row',
        );
        final clock = find.byKey(const ValueKey('timer-landscape-clock'));
        expect(clock, findsOneWidget);
        final clockRect = tester.getRect(clock);
        expect(
          clockRect.top,
          greaterThanOrEqualTo(0),
          reason: '$label clock visible',
        );
        expect(
          clockRect.bottom,
          lessThanOrEqualTo(size.height),
          reason: '$label clock visible',
        );
        expect(clockRect.width, greaterThan(0));
        expect(clockRect.height, greaterThan(0));
        final mainKey = onBreak
            ? 'marathon-stop'
            : onPresence
            ? 'marathon-presence-confirm'
            : 'timer-start-pause';
        final main = find.byKey(ValueKey(mainKey));
        expect(tester.widget<ElevatedButton>(main).onPressed, isNotNull);
        await expectReachable(main, size, '$label minimal primary control');
        if (!onPresence) {
          expect(
            find.descendant(
              of: main,
              matching: find.byIcon(
                onBreak
                    ? Icons.stop_rounded
                    : phase == MarathonPhase.focus && !paused
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            findsOneWidget,
            reason: '$label phase has correct action icon',
          );
        } else {
          expect(find.text(l10n.marathonPresenceConfirm), findsOneWidget);
        }
        if (phase != null && !onBreak) {
          await expectReachable(
            find.byKey(const ValueKey('marathon-stop')),
            size,
            '$label independent stop control',
          );
        }
        final visibleClockAfterControls = tester.getRect(clock);
        expect(
          visibleClockAfterControls.top,
          greaterThanOrEqualTo(0),
          reason: '$label actions never scroll the clock offscreen',
        );
        expect(
          visibleClockAfterControls.bottom,
          lessThanOrEqualTo(size.height),
          reason: '$label clock and actions remain visible together',
        );
        expect(tester.takeException(), isNull, reason: '$label minimal layout');
      }

      void expectSameSession(
        ActiveTimerSession actual,
        ActiveTimerSession before,
        String label,
      ) {
        expect(actual.clientUuid, before.clientUuid, reason: '$label UUID');
        expect(actual.startedAt, before.startedAt, reason: '$label start');
        expect(actual.endsAt, before.endsAt, reason: '$label end');
        expect(
          actual.pauseUsedCount,
          before.pauseUsedCount,
          reason: '$label pause count',
        );
        expect(
          actual.pausedRemainingSeconds,
          before.pausedRemainingSeconds,
          reason: '$label paused remaining',
        );
        expect(
          actual.marathon?.toJson(),
          before.marathon?.toJson(),
          reason: '$label phase and fixed break/presence deadlines',
        );
      }

      // Frozen pre-Maraton geometry from commit 5f99f90. The new modal entry
      // must use the old screen's spare budget, rather than resize its hourglass.
      // Checking only idle-vs-active invariance could accidentally bless a
      // permanently shrunken hourglass in both states.
      double? legacyPortraitSize() {
        final context = tester.element(find.byType(HourglassWidget));
        Size? available;
        context.visitAncestorElements((element) {
          if (element.widget is LayoutBuilder) {
            available = (element.renderObject! as RenderBox).size;
            return false;
          }
          return true;
        });
        final area = available!;
        if (area.width >= 600 || area.width > area.height) return null;
        final base = DefaultTextStyle.of(context).style;
        final scaler = MediaQuery.textScalerOf(context);
        double height(double fontSize, FontWeight weight) {
          final painter = TextPainter(
            text: TextSpan(
              text: '0',
              style: base.merge(
                TextStyle(fontSize: fontSize, fontWeight: weight),
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final value = painter.height;
          painter.dispose();
          return value;
        }

        final dense = area.height < 540;
        final controls =
            math.max(48, height(13, FontWeight.bold) + 24) +
            height(dense ? 42 : 52, FontWeight.bold) +
            math.max(48, height(16, FontWeight.bold) + (dense ? 14 : 22)) +
            math.max(13, height(11, FontWeight.w600)) +
            12 +
            math.max(dense ? 44 : 48, height(17, FontWeight.bold) + 16) +
            math.max(48, height(14, FontWeight.w500) + 16) +
            (dense ? 26 : 42);
        final ceiling = math.min(275.0, area.width - 32);
        final floor = math.min(
          ceiling,
          dense ? (area.height * .34).clamp(120.0, 220.0) : 220.0,
        );
        return ((area.height - 16 - controls) / 1.05)
            .clamp(floor, ceiling)
            .toDouble();
      }

      for (final locale in const [Locale('tr'), Locale('en')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        await LanguageService.instance.setLanguage(
          locale.languageCode == 'tr' ? AppLanguage.tr : AppLanguage.en,
        );
        for (final size in _sizes) {
          for (final scale in [1.0, 2.0]) {
            final label = '$locale $size x$scale';
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            final safe = size.width < size.height
                ? const FakeViewPadding(top: 24, bottom: 20)
                : const FakeViewPadding();
            tester.view.padding = safe;
            tester.view.viewPadding = safe;
            final lockPlatform = FakeLockScreenPlatform();
            final lock = LockScreenTimer(
              platform: lockPlatform,
              isEnabled: () async => true,
              categoryLabel: (name) => name,
              clock: () => now,
            );
            final owner = 'marathon-responsive-${serial++}';
            Widget app({
              bool available = true,
              bool dark = false,
              bool reducedMotion = false,
            }) => MaterialApp(
              key: UniqueKey(),
              locale: locale,
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: reducedMotion,
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) => ShellNavigationScaffold(
                  selectedIndex: 0,
                  showNavigation:
                      MediaQuery.orientationOf(context) !=
                      Orientation.landscape,
                  onDestinationSelected: (_) {},
                  destinations: [
                    ShellDestination(
                      icon: Icons.timer_outlined,
                      selectedIcon: Icons.timer,
                      label: l10n.navTimer,
                    ),
                    ShellDestination(
                      icon: Icons.analytics_outlined,
                      selectedIcon: Icons.analytics,
                      label: l10n.navReports,
                    ),
                    ShellDestination(
                      icon: Icons.leaderboard_outlined,
                      selectedIcon: Icons.leaderboard,
                      label: l10n.navRanking,
                    ),
                    ShellDestination(
                      icon: Icons.groups_outlined,
                      selectedIcon: Icons.groups,
                      label: l10n.navSocial,
                    ),
                  ],
                  appBar:
                      MediaQuery.orientationOf(context) == Orientation.landscape
                      ? null
                      : AppBar(
                          toolbarHeight: MediaQuery.sizeOf(context).height < 500
                              ? 56
                              : 76,
                          title: const Text('PomoSprint'),
                        ),
                  body: TimerScreen(
                    categories: CourseCategory.initialCategories()
                        .take(2)
                        .toList(),
                    sessionOwnerKey: owner,
                    onOpenSettings: () {},
                    onSessionCompleted: (_) async {
                      unexpectedSubmissions++;
                      return null;
                    },
                    onTimerStateChanged: (running, _, _) {
                      if (running) focusStarts++;
                    },
                    onConfirmMarathonPresence: (_, _) async {
                      unexpectedConfirmations++;
                      return false;
                    },
                    lockScreenTimer: lock,
                    marathonAvailable: available,
                    clock: () => now,
                  ),
                ),
              ),
            );

            await tester.pumpWidget(app());
            await drain();
            expect(
              tester.takeException(),
              isNull,
              reason: '$label initial layout',
            );
            if (size.width > size.height) {
              await expectLandscape(l10n, size, '$label idle');
              expect(await TimerPersistence.instance.load(owner), isNull);
              expect(focusStarts, 0);
              for (final state in ['focus', 'paused', 'break', 'presence']) {
                final phase = state == 'break'
                    ? MarathonPhase.breakTime
                    : state == 'presence'
                    ? MarathonPhase.awaitingPresence
                    : MarathonPhase.focus;
                for (final dark
                    in state == 'presence' ? [false, true] : [false]) {
                  final stateLabel = '$label $state dark=$dark';
                  await unmount();
                  const base = MarathonProgress(
                    totalSessions: 3,
                    marathonUuid: 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                  );
                  final progress = switch (phase) {
                    MarathonPhase.breakTime =>
                      base.beginCompletion().finishFocus(now),
                    MarathonPhase.awaitingPresence =>
                      base
                          .beginCompletion()
                          .finishFocus(now.subtract(const Duration(minutes: 5)))
                          .beginPresenceCheck(),
                    _ => base,
                  };
                  final category = CourseCategory.initialCategories().first;
                  var session = ActiveTimerSession.start(
                    clientUuid: 'landscape-restored-$state',
                    categoryId: category.id,
                    categoryName: category.name,
                    durationMinutes: 25,
                    totalSeconds: 1500,
                    now: phase == MarathonPhase.focus
                        ? now.subtract(const Duration(minutes: 2))
                        : now.subtract(const Duration(minutes: 25)),
                    marathon: progress,
                  );
                  if (state == 'paused') {
                    session = session.pauseAt(
                      now.subtract(const Duration(minutes: 1)),
                    );
                  }
                  await TimerPersistence.instance.save(owner, session);
                  final startsBefore = focusStarts;
                  await tester.pumpWidget(app(dark: dark, reducedMotion: dark));
                  await drain();
                  await expectLandscape(
                    l10n,
                    size,
                    stateLabel,
                    phase: phase,
                    paused: state == 'paused',
                  );
                  final restored = (await TimerPersistence.instance.load(
                    owner,
                  ))!;
                  expectSameSession(restored, session, '$stateLabel restored');
                  expect(
                    focusStarts,
                    startsBefore + (state == 'focus' ? 1 : 0),
                    reason: '$stateLabel restore starts only running focus',
                  );

                  // Rotate the same mounted timer through portrait and back.
                  // A layout switch cannot create a new focus or renew presence.
                  final restoredStarts = focusStarts;
                  final portrait = Size(size.height, size.width);
                  tester.view.physicalSize = portrait;
                  tester.view.padding = const FakeViewPadding(
                    top: 24,
                    bottom: 20,
                  );
                  tester.view.viewPadding = tester.view.padding;
                  await drain();
                  expect(
                    find.byKey(const ValueKey('timer-landscape-clock')),
                    findsNothing,
                  );
                  expect(find.byType(AppBar), findsOneWidget);
                  final portraitRail = Responsive.fromSize(
                    portrait,
                  ).useSideNavigation;
                  expect(
                    find.byType(NavigationBar),
                    portraitRail ? findsNothing : findsOneWidget,
                  );
                  expect(
                    find.byType(NavigationRail),
                    portraitRail ? findsOneWidget : findsNothing,
                  );
                  expectEntryDesign(
                    '$stateLabel rotated portrait',
                    active: true,
                  );
                  expect(
                    find.byKey(const ValueKey('timer-duration-25')),
                    findsOneWidget,
                  );
                  expectSameSession(
                    (await TimerPersistence.instance.load(owner))!,
                    restored,
                    '$stateLabel portrait rotation',
                  );
                  expect(focusStarts, restoredStarts);
                  tester.view.physicalSize = size;
                  tester.view.padding = const FakeViewPadding();
                  tester.view.viewPadding = const FakeViewPadding();
                  await drain();
                  await expectLandscape(
                    l10n,
                    size,
                    '$stateLabel rotated back',
                    phase: phase,
                    paused: state == 'paused',
                  );
                  expectSameSession(
                    (await TimerPersistence.instance.load(owner))!,
                    restored,
                    '$stateLabel landscape rotation',
                  );
                  expect(focusStarts, restoredStarts);
                  if (size == const Size(568, 320) &&
                      scale == 2 &&
                      state == 'focus') {
                    await tapKey('timer-start-pause');
                    final paused = (await TimerPersistence.instance.load(
                      owner,
                    ))!;
                    expect(paused.isRunning, isFalse);
                    expect(paused.pauseUsedCount, 1);
                    expect(paused.clientUuid, restored.clientUuid);
                    expect(paused.startedAt, restored.startedAt);
                    expect(
                      paused.marathon!.toJson(),
                      restored.marathon!.toJson(),
                    );
                    await expectLandscape(
                      l10n,
                      size,
                      '$stateLabel paused by landscape button',
                      phase: phase,
                      paused: true,
                    );
                    await tapKey('timer-start-pause');
                    for (var second = 0; second < 4; second++) {
                      await tester.pump(const Duration(seconds: 1));
                    }
                    await drain();
                    final resumed = (await TimerPersistence.instance.load(
                      owner,
                    ))!;
                    expect(resumed.isRunning, isTrue);
                    expect(resumed.pauseUsedCount, 1);
                    expect(resumed.clientUuid, restored.clientUuid);
                    expect(resumed.startedAt, restored.startedAt);
                    expect(resumed.endsAt, restored.endsAt);
                    expect(
                      resumed.marathon!.toJson(),
                      restored.marathon!.toJson(),
                    );
                    expect(focusStarts, restoredStarts + 1);
                    await expectLandscape(
                      l10n,
                      size,
                      '$stateLabel resumed by landscape button',
                      phase: phase,
                      pauseUsed: true,
                    );
                  }
                  final beforeStopDialog = (await TimerPersistence.instance
                      .load(owner))!;
                  final startsBeforeStopDialog = focusStarts;
                  await tapKey('marathon-stop');
                  expect(
                    find.text(l10n.marathonStopConfirmTitle),
                    findsOneWidget,
                  );
                  final cancel = find.widgetWithText(TextButton, l10n.cancel);
                  await tester.ensureVisible(cancel);
                  await tester.tap(cancel);
                  await drain();
                  expectSameSession(
                    (await TimerPersistence.instance.load(owner))!,
                    beforeStopDialog,
                    '$stateLabel cancelling stop',
                  );
                  expect(focusStarts, startsBeforeStopDialog);
                  expect(unexpectedSubmissions, 0);
                  expect(unexpectedConfirmations, 0);
                }
              }
              await unmount();
              await TimerPersistence.instance.clear(owner);
              await tester.pumpWidget(app(available: false));
              await drain();
              await expectLandscape(
                l10n,
                size,
                '$label unsupported-server idle',
              );
              expect(await TimerPersistence.instance.load(owner), isNull);
              await unmount();
              focusStarts = 0;
              continue;
            }
            expectEntryDesign(label);
            final originalRect = hourglassRect();
            final originalSize = hourglassSize();
            expect(
              originalSize,
              greaterThanOrEqualTo(64),
              reason: '$label legacy landscape/tablet minimum',
            );
            final legacySize = legacyPortraitSize();
            if (legacySize != null) {
              expect(
                originalSize,
                closeTo(legacySize, .001),
                reason: '$label literal pre-Maraton hourglass geometry',
              );
            }
            expect(
              find.byKey(const ValueKey('marathon-count-3')),
              findsNothing,
              reason: '$label no inline card',
            );
            final mainStart = find.byKey(const ValueKey('timer-start-pause'));
            await expectReachable(mainStart, size, '$label regular START');
            await tapKey('marathon-open-planner');
            expect(
              find.byKey(const ValueKey('marathon-planner-dialog')),
              findsOneWidget,
            );
            expect(
              hourglassRect(),
              originalRect,
              reason: '$label opening popup leaves hourglass rect unchanged',
            );
            expect(
              hourglassSize(),
              originalSize,
              reason: '$label opening popup leaves hourglass size unchanged',
            );
            await tapKey('marathon-count-4');
            await tapKey('marathon-duration-50');
            expectPlannerCountDesign(l10n, label, selected: 4);
            expect(
              hourglassRect(),
              originalRect,
              reason: '$label draft selection leaves background unchanged',
            );
            expect(
              tester
                  .widget<HourglassWidget>(find.byType(HourglassWidget))
                  .totalSeconds,
              1500,
              reason: '$label draft duration is not regular duration',
            );
            await expectReachable(
              find.byKey(const ValueKey('marathon-start')),
              size,
              '$label popup START',
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$label popup layout',
            );
            await tapKey('marathon-plan-cancel');
            expect(
              find.byKey(const ValueKey('marathon-planner-dialog')),
              findsNothing,
            );
            expect(
              hourglassRect(),
              originalRect,
              reason: '$label cancel leaves hourglass rect unchanged',
            );
            expect(
              hourglassSize(),
              originalSize,
              reason: '$label cancel leaves hourglass size unchanged',
            );
            expect(
              await TimerPersistence.instance.load(owner),
              isNull,
              reason: '$label planning/cancel never persists focus',
            );
            expect(
              focusStarts,
              0,
              reason: '$label planning/cancel never starts focus',
            );
            expect(unexpectedSubmissions, 0);
            expect(unexpectedConfirmations, 0);

            for (final phase in const [
              MarathonPhase.focus,
              MarathonPhase.breakTime,
              MarathonPhase.awaitingPresence,
            ]) {
              for (final dark
                  in phase == MarathonPhase.awaitingPresence
                      ? [false, true]
                      : [false]) {
                final onBreak = phase == MarathonPhase.breakTime;
                final onPresence = phase == MarathonPhase.awaitingPresence;
                final stateLabel = '$label ${phase.name} dark=$dark';
                await unmount();
                const base = MarathonProgress(
                  totalSessions: 3,
                  marathonUuid: 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                );
                final progress = switch (phase) {
                  MarathonPhase.breakTime => base.beginCompletion().finishFocus(
                    now,
                  ),
                  MarathonPhase.awaitingPresence =>
                    base
                        .beginCompletion()
                        .finishFocus(now.subtract(const Duration(minutes: 5)))
                        .beginPresenceCheck(),
                  _ => base,
                };
                final category = CourseCategory.initialCategories().first;
                await TimerPersistence.instance.save(
                  owner,
                  ActiveTimerSession.start(
                    clientUuid: 'restored-${phase.name}',
                    categoryId: category.id,
                    categoryName: category.name,
                    durationMinutes: 25,
                    totalSeconds: 1500,
                    now: phase != MarathonPhase.focus
                        ? now.subtract(const Duration(minutes: 25))
                        : now,
                    marathon: progress,
                  ),
                );
                final startsBefore = focusStarts;
                lockPlatform.calls.clear();
                await tester.pumpWidget(app(dark: dark, reducedMotion: dark));
                await drain();
                expect(tester.takeException(), isNull, reason: stateLabel);
                expect(
                  find.byKey(const ValueKey('marathon-active-progress')),
                  findsOneWidget,
                  reason: stateLabel,
                );
                expectEntryDesign(stateLabel, active: true);
                expect(
                  find.byKey(const ValueKey('marathon-open-planner')),
                  findsNothing,
                  reason: '$stateLabel no new-plan action',
                );
                expect(
                  find.byKey(const ValueKey('marathon-presence')),
                  onPresence ? findsOneWidget : findsNothing,
                  reason: stateLabel,
                );
                if (phase == MarathonPhase.focus || onPresence) {
                  expect(
                    hourglassRect(),
                    originalRect,
                    reason:
                        '$stateLabel focus/presence retains original hourglass rect',
                  );
                  expect(
                    hourglassSize(),
                    originalSize,
                    reason:
                        '$stateLabel focus/presence retains original hourglass size',
                  );
                }
                if (onPresence) {
                  expect(
                    focusStarts,
                    startsBefore,
                    reason: '$stateLabel restore never starts focus',
                  );
                  expect(
                    lockPlatform.calls.where(
                      (call) => call.startsWith('show:'),
                    ),
                    isEmpty,
                    reason: '$stateLabel no native focus activity',
                  );
                  final confirm = find.byKey(
                    const ValueKey('marathon-presence-confirm'),
                  );
                  expect(
                    tester.widget<ButtonStyleButton>(confirm).onPressed,
                    isNotNull,
                    reason: stateLabel,
                  );
                  expect(
                    find.text(l10n.marathonPresenceConfirm),
                    findsOneWidget,
                    reason: stateLabel,
                  );
                  await expectReachable(
                    confirm,
                    size,
                    '$stateLabel confirmation',
                  );
                  await tapKey('marathon-info');
                  expect(
                    find.byType(AlertDialog),
                    findsOneWidget,
                    reason: '$stateLabel info action',
                  );
                  expect(
                    find.textContaining(l10n.marathonAutomaticHint),
                    findsOneWidget,
                    reason: stateLabel,
                  );
                  final close = find.widgetWithText(
                    TextButton,
                    l10n.sessionResultOk,
                  );
                  await tester.ensureVisible(close);
                  await tester.tap(close);
                  await drain();
                  expect(
                    tester.takeException(),
                    isNull,
                    reason: '$stateLabel info dialog',
                  );
                  expect(
                    focusStarts,
                    startsBefore,
                    reason: '$stateLabel info never confirms presence',
                  );
                }
                // The animated detailed card is in a popup, never a main-layout child.
                await tapKey('marathon-active-progress');
                expect(
                  find.byKey(const ValueKey('marathon-progress-dialog')),
                  findsOneWidget,
                  reason: stateLabel,
                );
                expect(
                  find.byKey(const ValueKey('marathon-progress')),
                  findsOneWidget,
                  reason: stateLabel,
                );
                await tapKey('marathon-progress-close');
                expect(
                  find.byKey(const ValueKey('marathon-progress')),
                  findsNothing,
                  reason: '$stateLabel no inline progress card',
                );
                expect(
                  find.byKey(const ValueKey('marathon-break')),
                  onBreak ? findsOneWidget : findsNothing,
                  reason: stateLabel,
                );
                await expectReachable(
                  find.byKey(const ValueKey('marathon-stop')),
                  size,
                  '$stateLabel stop',
                );
                expect(
                  unexpectedSubmissions,
                  0,
                  reason: '$stateLabel layout never completes focus',
                );
                expect(
                  unexpectedConfirmations,
                  0,
                  reason:
                      '$stateLabel layout/info/progress never invokes confirm RPC',
                );
              }
            }
            await unmount();
            await TimerPersistence.instance.clear(owner);
            await tester.pumpWidget(app(available: false));
            await drain();
            expect(
              tester.takeException(),
              isNull,
              reason: '$label unavailable',
            );
            expectEntryDesign('$label unavailable', disabled: true);
            final unavailablePlanner = find.byKey(
              const ValueKey('marathon-open-planner'),
            );
            expect(
              tester.widget<ButtonStyleButton>(unavailablePlanner).onPressed,
              isNull,
              reason: '$label unsupported server cannot open planner',
            );
            expect(
              find.byKey(const ValueKey('marathon-count-2')),
              findsNothing,
            );
            expect(
              tester.widget<ButtonStyleButton>(mainStart).onPressed,
              isNotNull,
              reason: '$label normal focus remains usable',
            );
            await expectReachable(
              mainStart,
              size,
              '$label unavailable regular START',
            );
            await unmount();
            // Reset only expected restore callbacks; any planning start above fails.
            focusStarts = 0;
          }
        }
      }

      // Real Roboto/Material with real shell header and modern iPhone insets.
      // No ensureVisible before measurements: primary action is initially visible.
      await tester.runAsync(_loadSdkFonts);
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      const phoneInsets = FakeViewPadding(top: 62, bottom: 34);
      tester.view.padding = phoneInsets;
      tester.view.viewPadding = phoneInsets;
      for (final locale in const [Locale('tr'), Locale('en')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        await LanguageService.instance.setLanguage(
          locale.languageCode == 'tr' ? AppLanguage.tr : AppLanguage.en,
        );
        for (final count in [2, 3, 4]) {
          final owner = 'marathon-primary-fold-${serial++}';
          final lock = LockScreenTimer(
            platform: FakeLockScreenPlatform(),
            isEnabled: () async => true,
            categoryLabel: (name) => name,
            clock: () => now,
          );
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              locale: locale,
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => ShellNavigationScaffold(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  destinations: [
                    ShellDestination(
                      icon: Icons.timer_outlined,
                      selectedIcon: Icons.timer,
                      label: l10n.navTimer,
                    ),
                    ShellDestination(
                      icon: Icons.analytics_outlined,
                      selectedIcon: Icons.analytics,
                      label: l10n.navReports,
                    ),
                    ShellDestination(
                      icon: Icons.leaderboard_outlined,
                      selectedIcon: Icons.leaderboard,
                      label: l10n.navRanking,
                    ),
                    ShellDestination(
                      icon: Icons.groups_outlined,
                      selectedIcon: Icons.groups,
                      label: l10n.navSocial,
                    ),
                  ],
                  appBar: buildShellAppBar(
                    context,
                    streakDays: 0,
                    points: 0,
                    coins: 0,
                    onStatsTap: () {},
                    onFriendsTap: () {},
                    onProfileTap: () {},
                    avatarBuilder: (size) =>
                        SizedBox(width: size, height: size),
                  ),
                  body: TimerScreen(
                    categories: CourseCategory.initialCategories()
                        .take(2)
                        .toList(),
                    sessionOwnerKey: owner,
                    onOpenSettings: () {},
                    onSessionCompleted: (_) async {
                      unexpectedSubmissions++;
                      return null;
                    },
                    lockScreenTimer: lock,
                    clock: () => now,
                  ),
                ),
              ),
            ),
          );
          await drain();
          expectEntryDesign('$locale real shell');
          final mainStart = find.byKey(const ValueKey('timer-start-pause'));
          final originalRect = hourglassRect();
          final originalSize = hourglassSize();
          expect(
            originalSize,
            greaterThanOrEqualTo(220),
            reason: '$locale restores normal portrait hourglass floor',
          );
          expect(
            originalSize,
            closeTo(legacyPortraitSize()!, .001),
            reason: '$locale keeps exact pre-Maraton hourglass size',
          );
          final rect = tester.getRect(mainStart);
          final navigationTop = tester.getRect(find.byType(NavigationBar)).top;
          expect(
            rect.top,
            greaterThanOrEqualTo(0),
            reason: '$locale primary fold',
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(navigationTop),
            reason: '$locale regular START visible before scrolling',
          );
          expect(
            mainStart.hitTestable(),
            findsOneWidget,
            reason: '$locale regular START hit target',
          );
          final rowRect = tester.getRect(
            find.byKey(const ValueKey('marathon-open-planner')),
          );
          final durationRect = tester.getRect(
            find.byKey(const ValueKey('timer-duration-25')),
          );
          expect(
            rowRect.bottom,
            lessThanOrEqualTo(durationRect.top),
            reason: '$locale planner row directly above 25/50',
          );
          await tester.tap(find.byKey(const ValueKey('marathon-open-planner')));
          await drain();
          await tapKey('marathon-count-$count');
          await tapKey('marathon-plan-cancel');
          expect(
            hourglassRect(),
            originalRect,
            reason: '$locale $count-session popup did not move hourglass',
          );
          expect(
            hourglassSize(),
            originalSize,
            reason: '$locale $count-session popup did not shrink hourglass',
          );
          expect(
            tester.getRect(mainStart),
            rect,
            reason: '$locale $count-session popup did not move regular START',
          );
          expect(await TimerPersistence.instance.load(owner), isNull);
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale $count-session real-shell layout',
          );
          await unmount();
          await TimerPersistence.instance.clear(owner);
        }
      }
      expect(unexpectedSubmissions, 0);
      expect(unexpectedConfirmations, 0);
    },
  );
}
