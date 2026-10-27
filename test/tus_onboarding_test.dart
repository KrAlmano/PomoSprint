import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/category_names.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'TUS 11 ders önerir; ücretsiz 8 seçim sınırı ve TR/EN eşlemesi korunur',
    () {
      final recommended = recommendedCategoryNames('tus');
      expect(recommended, hasLength(11));
      final selected = autoSelectedCategoryNames('tus', kept: [], limit: 8);
      expect(selected, hasLength(8));
      expect(
        selected,
        containsAll(['Anatomi', 'Farmakoloji', 'Dahiliye', 'Pediatri']),
      );
      for (final name in recommended) {
        final english = localizedKnownCategoryName(name, turkish: false);
        expect(english, isNot(name));
        expect(categoryMatchKey(english), categoryMatchKey(name));
      }
      expect(
        categorySeedPayload(recommended, turkish: false).first['name'],
        'Anatomy',
      );
    },
  );

  test(
    'TUS eski CHECK reddinde diğer profil tercihleri korunarak tamamlanır',
    () async {
      final update = SupabaseService.onboardingProfileUpdate(
        birthYear: 2000,
        userSegment: 'tus',
        dailyGoalMinutes: 120,
        showInSocialFeed: false,
        completedAt: DateTime.utc(2026, 10, 27),
      );
      expect(update['user_segment'], 'tus');
      final writes = <Map<String, dynamic>>[];
      final saved =
          await SupabaseService.writeOnboardingProfileWithSegmentFallback(
            update,
            (value) async {
              writes.add(value);
              if (writes.length == 1) {
                throw const PostgrestException(
                  message:
                      'violates check constraint profiles_user_segment_check',
                  code: '23514',
                );
              }
            },
          );
      expect(writes, hasLength(2));
      expect(saved, {...update, 'user_segment': null});
      expect(saved['show_in_social_feed'], isFalse);
    },
  );

  for (final language in AppLanguage.values) {
    testWidgets(
      'TUS seçimi ve uzun ders adları ${language.name} dar ekranda taşmaz',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await LanguageService.instance.setLanguage(language);
        final service = SupabaseService.instance;
        const uid = 'tus-onboarding';
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
        await tester.ensureVisible(find.text(l10n.onboardingSegmentTus));
        await tester.tap(find.text(l10n.onboardingSegmentTus));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.continueBtn));
        await tester.pumpAndSettle();
        final chips = tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .toList();
        expect(chips, hasLength(11));
        expect(chips.where((chip) => chip.selected), hasLength(8));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
