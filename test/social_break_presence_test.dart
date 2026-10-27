import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/hidden_users.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/social/presence_dot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase_service.dart';

class _LiveFriendsService extends FakeSupabaseService {
  List<Map<String, dynamic>> rows = [];

  @override
  Future<List<Map<String, dynamic>>> getLiveFriends() async => List.of(rows);
}

class _DeferredLiveFriendsService extends _LiveFriendsService {
  bool defer = false;
  final requests = <Completer<List<Map<String, dynamic>>>>[];

  @override
  Future<List<Map<String, dynamic>>> getLiveFriends() {
    if (!defer) return super.getLiveFriends();
    final request = Completer<List<Map<String, dynamic>>>();
    requests.add(request);
    return request.future;
  }
}

Map<String, dynamic> _friend(String id, String name, {String? status}) => {
  'id': id,
  'name': name,
  'avatar_id': 'avatar_16_basic',
  'category_name': 'Fizik',
  'status': ?status,
};

Future<AppLocalizations> _mount(
  WidgetTester tester,
  _LiveFriendsService service, {
  Size size = const Size(390, 844),
  String locale = 'tr',
  double textScale = 1,
  bool reducedMotion = true,
  bool visible = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: TickerMode(
        enabled: visible,
        child: SocialScreen(service: service),
      ),
    ),
  );
  if (reducedMotion) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return AppLocalizations.delegate.load(Locale(locale));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HiddenUsersStore.instance.resetForTest();
  });
  tearDown(() => HiddenUsersStore.instance.resetForTest());

  test(
    'One list includes legacy focus, focus, break and exam; unknown stays hidden',
    () {
      final rows = [
        _friend('legacy', 'Legacy'),
        _friend('focus', 'Focus', status: 'focus'),
        _friend('break', 'Break', status: 'break'),
        _friend('exam', 'Exam', status: 'exam'),
        _friend('unknown', 'Unknown', status: 'future'),
      ];
      expect(SocialScreen.visibleFriends(rows).map((r) => r['id']), [
        'legacy',
        'focus',
        'break',
        'exam',
      ]);
    },
  );

  test(
    'Localized labels follow explicit presence, not category or inferred marathon',
    () async {
      for (final locale in ['tr', 'en']) {
        final l10n = await AppLocalizations.delegate.load(Locale(locale));
        expect(
          SocialScreen.liveStatusText(
            _friend('f', 'Focus', status: 'focus'),
            l10n,
          ),
          l10n.socialFocusing,
        );
        expect(
          SocialScreen.liveStatusText({
            ..._friend('m', 'Marathon', status: 'focus'),
            'is_marathon': true,
          }, l10n),
          l10n.socialFocusing,
        );
        expect(
          SocialScreen.liveStatusText({
            ..._friend('b', 'Break', status: 'break'),
            'is_marathon': true,
          }, l10n),
          l10n.socialOnBreak,
        );
        expect(
          SocialScreen.liveStatusText(
            _friend('e', 'Exam', status: 'exam'),
            l10n,
          ),
          l10n.socialTakingExam,
        );
        expect(
          SocialScreen.liveStatusText(_friend('l', 'Legacy'), l10n),
          l10n.socialFocusing,
        );
      }
    },
  );

  testWidgets(
    'One list shows focus and break together and changes the same friend status',
    (tester) async {
      final service = _LiveFriendsService()
        ..rows = [
          _friend('a', 'Focused Alice', status: 'focus'),
          _friend('b', 'Resting Bob', status: 'break'),
          _friend('b', 'Resting Bob', status: 'break'),
          _friend('c', 'Legacy Carol'),
          _friend('d', 'Exam Dani', status: 'exam'),
        ];
      final l10n = await _mount(tester, service);
      expect(find.text('Focused Alice'), findsOneWidget);
      expect(find.text('Legacy Carol'), findsOneWidget);
      expect(find.text('Resting Bob'), findsOneWidget);
      expect(find.text('Exam Dani'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text(l10n.socialFocusing), findsNWidgets(2));
      expect(find.text(l10n.socialOnBreak), findsOneWidget);
      expect(find.text(l10n.socialTakingExam), findsOneWidget);
      final examDot = find.descendant(
        of: find.byKey(const ValueKey('social-friend-d')),
        matching: find.byType(SocialPresenceDot),
      );
      expect(tester.widget<SocialPresenceDot>(examDot).onBreak, isFalse);
      final bobCard = find.byKey(const ValueKey('social-friend-b'));
      final bobDot = find.descendant(
        of: bobCard,
        matching: find.byType(SocialPresenceDot),
      );
      expect(tester.widget<SocialPresenceDot>(bobDot).onBreak, isTrue);
      expect(
        (tester
                    .widget<Container>(
                      find.descendant(
                        of: bobCard,
                        matching: find.byKey(
                          const ValueKey('social-presence-dot'),
                        ),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        Colors.green,
      );
      expect(find.byIcon(Icons.coffee_rounded), findsNothing);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);

      service.rows = [_friend('b', 'Resting Bob', status: 'focus')];
      service.notifyStatsChanged();
      await tester.pumpAndSettle();
      expect(find.text('Resting Bob'), findsOneWidget);
      expect(find.text(l10n.socialFocusing), findsOneWidget);
      expect(find.text(l10n.socialOnBreak), findsNothing);
      expect(find.text(l10n.socialTakingExam), findsNothing);
      expect(tester.widget<SocialPresenceDot>(bobDot).onBreak, isFalse);
      expect(
        (tester
                    .widget<Container>(
                      find.descendant(
                        of: bobCard,
                        matching: find.byKey(
                          const ValueKey('social-presence-dot'),
                        ),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        AppColors.primaryContainer,
      );
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets('Hiding a user removes break presence immediately', (
    tester,
  ) async {
    final service = _LiveFriendsService()
      ..rows = [_friend('b', 'Resting Bob', status: 'break')];
    final l10n = await _mount(tester, service);
    expect(find.text('Resting Bob'), findsOneWidget);
    await HiddenUsersStore.instance.hide(
      service.currentUser.value!.id!,
      const HiddenUser(id: 'b', name: 'Resting Bob'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resting Bob'), findsNothing);
    expect(find.text(l10n.socialNoLiveFriends), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
    'A late earlier response cannot replace the newest live friends',
    (tester) async {
      final service = _DeferredLiveFriendsService()
        ..rows = [_friend('initial', 'Initial Friend', status: 'focus')];
      await _mount(tester, service);
      expect(find.text('Initial Friend'), findsOneWidget);

      // Two overlapping refreshes: the server response for the newer request
      // arrives first. The older response must not restore a stale presence.
      service.defer = true;
      service.notifyStatsChanged();
      service.notifyStatsChanged();
      expect(service.requests, hasLength(2));
      service.requests[1].complete([
        _friend('current', 'Current Friend', status: 'focus'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Current Friend'), findsOneWidget);
      expect(find.text('Initial Friend'), findsNothing);

      service.requests[0].complete([
        _friend('stale', 'Stale Friend', status: 'focus'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Current Friend'), findsOneWidget);
      expect(find.text('Stale Friend'), findsNothing);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets('Old server focus remains visible in the single list', (
    tester,
  ) async {
    final service = _LiveFriendsService()
      ..rows = [_friend('a', 'Legacy Alice')];
    final l10n = await _mount(tester, service);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text(l10n.socialOnBreak), findsNothing);
    expect(find.text('Legacy Alice'), findsOneWidget);
    expect(find.text(l10n.socialFocusing), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
    'Presence pulse is subtle and stops for reduced motion, hidden tab and background',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      Widget dotApp({bool reduced = false, bool visible = true}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: Scaffold(
          body: TickerMode(
            enabled: visible,
            child: const SocialPresenceDot(onBreak: false),
          ),
        ),
      );
      double opacity() => tester
          .widget<Opacity>(
            find.byKey(const ValueKey('social-presence-opacity')),
          )
          .opacity;
      double scale() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('social-presence-scale')),
          )
          .transform
          .storage[0];
      await tester.pumpWidget(dotApp());
      final initial = opacity();
      final rect = tester.getRect(find.byType(SocialPresenceDot));
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), isNot(initial));
      expect(opacity(), inInclusiveRange(0.7, 0.95));
      expect(scale(), inInclusiveRange(0.85, 1.0));
      expect(tester.getRect(find.byType(SocialPresenceDot)), rect);

      await tester.pumpWidget(dotApp(reduced: true));
      await tester.pump();
      final still = opacity();
      await tester.pump(const Duration(seconds: 5));
      expect(opacity(), still);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(dotApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(dotApp(visible: false));
      await tester.pump();
      final hidden = opacity();
      await tester.pump(const Duration(seconds: 5));
      expect(opacity(), hidden);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(dotApp());
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final paused = opacity();
      await tester.pump(const Duration(seconds: 5));
      expect(opacity(), paused);
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // A restarted ticker takes its first frame as the elapsed-time origin.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), isNot(paused));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  const sizes = [
    Size(390, 844),
    Size(844, 390),
    Size(320, 568),
    Size(568, 320),
    Size(820, 1180),
    Size(1180, 820),
  ];
  for (final locale in ['tr', 'en']) {
    for (final size in sizes) {
      testWidgets(
        'Loaded focus/break layout fits $locale $size at text scale2',
        (tester) async {
          final service = _LiveFriendsService()
            ..rows = [
              _friend(
                'a',
                'Çok uzun isimli odaklanmış arkadaş kullanıcısı',
                status: 'focus',
              ),
              _friend(
                'b',
                'Çok uzun isimli mola veren arkadaş kullanıcısı',
                status: 'break',
              ),
            ];
          final l10n = await _mount(
            tester,
            service,
            size: size,
            locale: locale,
            textScale: 2,
          );
          expect(tester.takeException(), isNull);
          if (size.height < 500) {
            // Başlık büyük yazıda listeyi birkaç piksele sıkıştırmaz.
            expect(
              tester.getSize(find.byType(CustomScrollView)).height,
              size.height,
            );
          }
          final breakDot = find.descendant(
            of: find.byKey(const ValueKey('social-friend-b')),
            matching: find.byType(SocialPresenceDot),
          );
          await tester.scrollUntilVisible(breakDot, 120);
          await tester.pumpAndSettle();
          expect(breakDot, findsOneWidget);
          expect(tester.widget<SocialPresenceDot>(breakDot).onBreak, isTrue);
          expect(tester.getRect(breakDot).overlaps(Offset.zero & size), isTrue);
          service.rows = [];
          service.notifyStatsChanged();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(l10n.socialNoLiveFriends), findsOneWidget);
          await _unmount(tester);
        },
      );
    }
  }
}
