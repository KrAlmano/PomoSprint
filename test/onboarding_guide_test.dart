import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase_service.dart';

const _uid = 'onboarding-guide-owner';
const _sizes = [
  Size(320, 568),
  Size(390, 844),
  Size(568, 320),
  Size(844, 390),
  Size(820, 1180),
  Size(1180, 820),
];

class _GuideService extends FakeSupabaseService {
  _GuideService()
    : super(
        user: UserModel(
          id: _uid,
          name: 'Guide User',
          email: 'guide@example.com',
        ),
      );

  int completed = 0;
  int? savedGoal;
  bool? savedVisibility;
  List<Map<String, dynamic>> savedCategories = [];

  @override
  Future<OnboardingCategoriesResult?> completeOnboarding({
    int? birthYear,
    String? userSegment,
    required int dailyGoalMinutes,
    List<Map<String, dynamic>> categories = const [],
    required bool showInSocialFeed,
  }) async {
    completed++;
    savedGoal = dailyGoalMinutes;
    savedVisibility = showInSocialFeed;
    savedCategories = categories;
    currentUser.value = currentUser.value!.copyWith(
      onboardingCompletedAt: DateTime.now(),
    );
    return null;
  }
}

Future<AppLocalizations> _open(
  WidgetTester tester,
  _GuideService service, {
  int step = 6,
  Size size = const Size(390, 844),
  Locale locale = const Locale('tr'),
  double scale = 1,
  VoidCallback? onCompleted,
}) async {
  SharedPreferences.setMockInitialValues({
    OnboardingDraftStore.keyFor(_uid): jsonEncode(
      OnboardingDraft(
        step: step,
        birthYear: 2000,
        segment: 'yks',
        selectedCategories: const ['Fizik'],
        autoCategories: const [],
        showInRankings: false,
        dailyGoalMinutes: 120,
      ).toJson(),
    ),
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: PostAuthOnboardingScreen(
        service: service,
        onCompleted: onCompleted ?? () {},
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(
    tester.element(find.byType(PostAuthOnboardingScreen)),
  )!;
}

void main() {
  for (final locale in [const Locale('tr'), const Locale('en')]) {
    for (final size in _sizes) {
      testWidgets(
        'screen guide readable and Finish reachable: ${locale.languageCode} $size x2',
        (tester) async {
          final service = _GuideService();
          final l10n = await _open(
            tester,
            service,
            size: size,
            locale: locale,
            scale: 2,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('7/7'), findsOneWidget);
          expect(find.text(l10n.onboardingGuideTitle), findsOneWidget);
          for (final (title, body) in [
            (l10n.onboardingGuidePomoTitle, l10n.onboardingGuidePomoBody),
            (
              l10n.onboardingGuideMarathonTitle,
              l10n.onboardingGuideMarathonBody,
            ),
            (l10n.onboardingGuideReportsTitle, l10n.onboardingGuideReportsBody),
            (l10n.onboardingGuideRankingTitle, l10n.onboardingGuideRankingBody),
            (l10n.onboardingGuideSocialTitle, l10n.onboardingGuideSocialBody),
            (l10n.onboardingGuideProfileTitle, l10n.onboardingGuideProfileBody),
          ]) {
            expect(find.text(title), findsOneWidget);
            expect(find.text(body), findsOneWidget);
            await tester.ensureVisible(find.text(body));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'scrolling to $title',
            );
          }
          final finish = find.widgetWithText(
            ElevatedButton,
            l10n.onboardingFinishBtn,
          );
          final rect = tester.getRect(finish);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(
            service.completed,
            0,
            reason: 'reading/restoring the guide does not submit onboarding',
          );
          expect(
            l10n.onboardingGuideSocialBody,
            isNot(contains('Maraton yapıyor')),
          );
          expect(
            l10n.onboardingGuideSocialBody,
            isNot(contains('Doing a marathon')),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'old goal draft continues to guide, Back preserves choices, Finish saves once',
    (tester) async {
      final service = _GuideService();
      var completedCallback = 0;
      final l10n = await _open(
        tester,
        service,
        step: 5,
        onCompleted: () => completedCallback++,
      );
      expect(find.text('6/7'), findsOneWidget);
      expect(find.text(l10n.onboardingGoalStepTitle), findsOneWidget);
      expect(find.text(l10n.onboardingFinishBtn), findsNothing);
      await tester.tap(find.text(l10n.continueBtn));
      await tester.pumpAndSettle();
      expect(find.text('7/7'), findsOneWidget);
      expect(service.completed, 0);
      final prefs = await SharedPreferences.getInstance();
      final draft = OnboardingDraft.fromJson(
        jsonDecode(prefs.getString(OnboardingDraftStore.keyFor(_uid))!),
      )!;
      expect(draft.step, 6);
      expect(draft.dailyGoalMinutes, 120);
      expect(draft.showInRankings, isFalse);

      final back = MaterialLocalizations.of(
        tester.element(find.byType(PostAuthOnboardingScreen)),
      ).backButtonTooltip;
      await tester.tap(find.byTooltip(back));
      await tester.pumpAndSettle();
      expect(find.text('6/7'), findsOneWidget);
      await tester.tap(find.text(l10n.continueBtn));
      await tester.pumpAndSettle();
      expect(find.text('7/7'), findsOneWidget);
      await tester.tap(find.text(l10n.onboardingFinishBtn));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(service.completed, 1);
      expect(completedCallback, 1);
      expect(service.savedGoal, 120);
      expect(service.savedVisibility, isFalse);
      expect(service.savedCategories, hasLength(1));
      expect(prefs.getString(OnboardingDraftStore.keyFor(_uid)), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('out-of-range draft safely clamps to guide without auto-saving', (
    tester,
  ) async {
    final service = _GuideService();
    final l10n = await _open(tester, service, step: 99);
    expect(find.text('7/7'), findsOneWidget);
    expect(find.text(l10n.onboardingGuideTitle), findsOneWidget);
    expect(service.completed, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
