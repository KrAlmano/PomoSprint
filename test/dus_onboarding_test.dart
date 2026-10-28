import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/competition_target.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/services/onboarding_segment_intent.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/category_names.dart';
import 'package:pomodoro/widgets/competition_target_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('DUS adds a target without removing any existing personal goal', () {
    expect(
      CompetitionTarget.segments,
      containsAll([
        'lgs',
        'yks',
        'tus',
        'dus',
        'kpss',
        'language',
        'university',
        'work',
        'other',
      ]),
    );
    expect(
      SupabaseService.validUserSegments,
      containsAll([
        'lgs',
        'yks',
        'tus',
        'dus',
        'kpss',
        'language',
        'university',
        'work',
      ]),
    );
    expect(
      CompetitionTarget.fromJson({'current_segment': 'dus'})!.currentSegment,
      'dus',
    );
    expect(
      CompetitionTarget.fromJson({
        'current_segment': 'yks',
        'pending_segment': 'dus',
        'effective_at': '2026-11-01T00:00:00+03:00',
      })!.pendingSegment,
      'dus',
    );
  });
  test('DUS16 translated categories preserve the free8 selection limit', () {
    final names = recommendedCategoryNames('dus');
    expect(names, hasLength(16));
    expect(names.toSet(), hasLength(16));
    expect(autoSelectedCategoryNames('dus', kept: [], limit: 8), hasLength(8));
    for (final name in names) {
      final english = localizedKnownCategoryName(name, turkish: false);
      expect(english, isNot(name), reason: name);
      expect(categoryMatchKey(english), categoryMatchKey(name));
    }
  });
  test(
    'legacy CHECK fallback remembers DUS per owner and replays once',
    () async {
      final store = OnboardingSegmentIntentStore();
      final update = SupabaseService.onboardingProfileUpdate(
        birthYear: 2000,
        userSegment: 'dus',
        dailyGoalMinutes: 120,
        showInSocialFeed: false,
        completedAt: DateTime.utc(2026, 10, 28),
      );
      final writes = <Map<String, dynamic>>[];
      final result =
          await SupabaseService.writeOnboardingProfileWithSegmentFallback(
            update,
            (value) async {
              writes.add(value);
              if (value['user_segment'] == 'dus') {
                throw const PostgrestException(
                  message:
                      'violates check constraint profiles_user_segment_check',
                  code: '23514',
                );
              }
            },
            onUnsupportedSegment: (segment) async {
              expect(
                await store.remember('owner-a', segment, isCurrent: () => true),
                isTrue,
              );
            },
          );
      expect(result['user_segment'], isNull);
      expect(result['birth_year'], 2000);
      expect(result['show_in_social_feed'], isFalse);
      expect(writes, hasLength(2));
      expect(await OnboardingSegmentIntentStore().read('owner-a'), 'dus');
      expect(await store.read('owner-b'), isNull);
      var replayed = 0;
      final replay = await store.replay(
        'owner-a',
        serverSegment: null,
        isCurrent: () => true,
        writeIfStillNull: (segment) async {
          expect(segment, 'dus');
          replayed++;
          return true;
        },
      );
      expect(replay, 'dus');
      expect(replayed, 1);
      expect(await store.read('owner-a'), isNull);
      await store.remember('owner-a', 'dus', isCurrent: () => true);
      expect(
        await store.replay(
          'owner-a',
          serverSegment: 'tus',
          isCurrent: () => true,
          writeIfStillNull: (_) async {
            fail('existing non-null target wins');
          },
        ),
        'tus',
      );
      expect(await store.read('owner-a'), isNull);
    },
  );
  for (final language in AppLanguage.values) {
    testWidgets(
      'DUS sits beside TUS and all16 category labels fit ${language.name}',
      (tester) async {
        await LanguageService.instance.setLanguage(language);
        final service = SupabaseService.instance;
        const uid = 'dus-onboarding';
        service.currentUser.value = UserModel(
          id: uid,
          name: 'QA',
          email: 'qa@example.test',
        );
        addTearDown(() => service.currentUser.value = null);
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await OnboardingDraftStore.save(
          uid,
          const OnboardingDraft(step: 1, birthYear: 2000),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language.name),
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PostAuthOnboardingScreen(onCompleted: () {}),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(PostAuthOnboardingScreen)),
        )!;
        expect(competitionTargetLabel(l10n, 'dus'), l10n.onboardingSegmentDus);
        await tester.ensureVisible(find.text(l10n.onboardingSegmentDus));
        await tester.tap(find.text(l10n.onboardingSegmentDus));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.continueBtn));
        await tester.pumpAndSettle();
        final chips = tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .toList();
        expect(chips, hasLength(16));
        expect(chips.where((c) => c.selected), hasLength(8));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
