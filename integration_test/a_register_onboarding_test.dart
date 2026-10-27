// (a) KAYIT + ONBOARDING, Türkçe arayüz, gerçek simülatör + yerel Supabase.
//
// 1. Kayıt ekranı (ad, e-posta, şifre, iki zorunlu onay) → onboarding: yaş,
//    hedef YKS → kategori adımında YKS dersleri OTOMATİK seçili (Matematik,
//    Fizik dahil) → görünürlük → kurallar → hedef → ekran rehberi → sayaç ve YKS
//    çipleri. Sunucuda (psql) profil alanları ve kategoriler.
// 2. KPSS hedefi: profiles_user_segment_check kpss'yi tanıyorsa
//    (proposed/26, 5 Ekim 2026'dan beri canlıda) hedef saklanır; tanımıyorsa
//    (eski sunucu) istemci segmentsiz yazar. İki durumda da onboarding
//    hatasız biter.
//
// Çalıştırma: tool/local_supabase/e2e/sim/run_sim_e2e.sh a

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/screens/register_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/supabase_service.dart';

import 'support/e2e.dart';

void main() {
  initE2e();
  final l10n = trL10n;

  /// Onboarding'i ekranda yürütür; seçilen doğum yılını döndürür.
  Future<int> runOnboarding(
    WidgetTester tester, {
    required String segmentLabel,
    required String shotPrefix,
    required void Function() verifyCategoryStep,
  }) async {
    await pumpUntil(
      tester,
      find.byType(PostAuthOnboardingScreen),
      timeout: const Duration(seconds: 40),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    // 1/7 yaş: tekerlek ~20 yıl geriye çevrilir (ileri savrulabilir; her
    // durumda 13 yaşından büyük).
    final picker = find.byType(CupertinoPicker);
    await tester.timedDrag(
      picker,
      const Offset(0, -52.0 * 20),
      const Duration(milliseconds: 1500),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    final index = tester
        .widget<CupertinoPicker>(picker)
        .scrollController!
        .selectedItem;
    final birthYear = DateTime.now().year - (index - 1);
    expect(
      index,
      greaterThan(13),
      reason: 'en az 13 yaş: seçili yıl $birthYear',
    );
    await tapOn(tester, find.text(l10n.continueBtn));

    // 2/7 hedef
    await pumpUntil(tester, find.text(l10n.onboardingSegmentTitle));
    await tapOn(tester, find.text(segmentLabel));
    await tapOn(tester, find.text(l10n.continueBtn));

    // 3/7 kategoriler: hedefe göre hazır
    await pumpUntil(
      tester,
      find.text(l10n.onboardingCategoryStepPreparedTitle),
    );
    verifyCategoryStep();
    await E2eHost.screenshot(tester, '$shotPrefix-onboarding-kategoriler');
    await tapOn(tester, find.text(l10n.continueBtn));

    // 4/7 görünürlük
    await pumpUntil(tester, find.text(l10n.onboardingVisibilityYes));
    await tapOn(tester, find.text(l10n.onboardingVisibilityYes));
    await tapOn(tester, find.text(l10n.continueBtn));

    // 5/7 kurallar
    await pumpUntil(tester, find.text(l10n.gameRulesTitle));
    await tapOn(tester, find.text(l10n.continueBtn));

    // 6/7 hedef: 2 saat
    await pumpUntil(tester, find.text(l10n.onboardingGoal2h));
    await tapOn(tester, find.text(l10n.onboardingGoal2h));
    await tapOn(tester, find.text(l10n.continueBtn));

    // 7/7: bütün ana ekranların rehberi; kaydetme yalnız Bitir'de.
    await pumpUntil(tester, find.text(l10n.onboardingGuideTitle));
    for (final body in [
      l10n.onboardingGuidePomoBody,
      l10n.onboardingGuideMarathonBody,
      l10n.onboardingGuideReportsBody,
      l10n.onboardingGuideRankingBody,
      l10n.onboardingGuideSocialBody,
      l10n.onboardingGuideProfileBody,
    ]) {
      expect(find.text(body), findsOneWidget);
    }
    await tester.ensureVisible(find.text(l10n.onboardingGuideProfileBody));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await E2eHost.screenshot(tester, '$shotPrefix-onboarding-ekran-rehberi');
    await tapOn(
      tester,
      find.widgetWithText(ElevatedButton, l10n.onboardingFinishBtn),
      settle: const Duration(milliseconds: 200),
    );
    return birthYear;
  }

  /// Onboarding sonrası: kabuk, sayaç; hata metni yok.
  Future<void> expectShell(WidgetTester tester) async {
    await pumpUntil(
      tester,
      find.byType(MainNavigationShell),
      timeout: const Duration(seconds: 40),
      reason: 'kabuk',
    );
    expect(find.text(l10n.onboardingSaveError), findsNothing);
    expect(find.text(l10n.onboardingTimeoutError), findsNothing);
    await pumpUntil(tester, find.byType(TimerScreen), reason: 'sayaç sekmesi');
  }

  List<String> timerChipLabels(WidgetTester tester) => [
    for (final chip in tester.widgetList<FilterChip>(
      find.descendant(
        of: find.byType(TimerScreen),
        matching: find.byType(FilterChip),
      ),
    ))
      ((chip.label as Text).data ?? ''),
  ];

  testWidgets(
    'a1 · kayıt + onboarding (YKS): otomatik ders seçimi, kabuk, sunucu kaydı',
    (tester) async {
      await resetAppState(tester);
      await launchApp(tester);
      await waitPastSplash(tester);
      final email = e2eEmail('kayit');

      // Kayıt ekranı
      await tapOn(tester, find.text(l10n.signUpLink));
      await pumpUntil(tester, find.byType(RegisterScreen));
      final fields = find.descendant(
        of: find.byType(RegisterScreen),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'Sim Kayıt');
      await tester.enterText(fields.at(1), email);
      await tester.enterText(fields.at(2), kE2ePassword);
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 600));

      // Zorunlu iki onay (ticari ileti isteğe bağlı, kapalı kalır).
      final checkboxes = find.descendant(
        of: find.byType(RegisterScreen),
        matching: find.byType(Checkbox),
      );
      expect(checkboxes, findsNWidgets(3));
      await tapOn(tester, checkboxes.at(0));
      await tapOn(tester, checkboxes.at(1));
      expect(tester.widget<Checkbox>(checkboxes.at(0)).value, isTrue);
      expect(tester.widget<Checkbox>(checkboxes.at(1)).value, isTrue);
      expect(tester.widget<Checkbox>(checkboxes.at(2)).value, isFalse);
      await tester.ensureVisible(fields.at(0));
      await E2eHost.screenshot(tester, 'e2e-kayit');
      await tapOn(
        tester,
        find.widgetWithText(ElevatedButton, l10n.registerBtn),
        settle: const Duration(milliseconds: 200),
      );

      late List<String> autoNames;
      final birthYear = await runOnboarding(
        tester,
        segmentLabel: l10n.onboardingSegmentYks,
        shotPrefix: 'e2e',
        verifyCategoryStep: () {
          autoNames = autoSelectedCategoryNames(
            'yks',
            kept: const [],
            limit: 8,
          );
          final chips = {
            for (final chip in tester.widgetList<ChoiceChip>(
              find.byType(ChoiceChip),
            ))
              ((chip.label as Text).data ?? ''): chip.selected,
          };
          expect(
            chips['Matematik'],
            isTrue,
            reason: 'YKS: Matematik otomatik seçili',
          );
          expect(chips['Fizik'], isTrue, reason: 'YKS: Fizik otomatik seçili');
          for (final name in autoNames) {
            expect(chips[name], isTrue, reason: 'YKS önerisi seçili: $name');
          }
          expect(find.text('${autoNames.length} / 8'), findsOneWidget);
        },
      );

      await expectShell(tester);
      await pumpUntilTrue(
        tester,
        () => timerChipLabels(tester).length == autoNames.length,
        reason: 'sayaçta YKS kategori çipleri (sunucudan)',
      );
      expect(
        timerChipLabels(tester),
        autoNames,
        reason: 'kabukta YKS çipleri, sırasıyla',
      );
      expect(find.text(tr('btn_start')), findsOneWidget);
      await E2eHost.screenshot(tester, 'e2e-sayac-yks');

      // Sunucu (psql): profil, kategoriler, kayıt onayları.
      final uid = SupabaseService.instance.currentUser.value!.id!;
      final profile = (await E2eHost.row(
        'select name, birth_year, user_segment, daily_goal_minutes, show_in_social_feed, '
        'onboarding_completed_at is not null as onboarded, lifetime_points, coins '
        'from public.profiles where id = ${sqlText(uid)}',
      ))!;
      expect(profile['name'], 'Sim Kayıt');
      expect(profile['birth_year'], birthYear);
      expect(profile['user_segment'], 'yks');
      expect(profile['daily_goal_minutes'], 120);
      expect(profile['show_in_social_feed'], isTrue);
      expect(profile['onboarded'], isTrue);
      final categories = await E2eHost.rows(
        'select name from public.categories where user_id = ${sqlText(uid)} and not is_archived '
        'order by sort_order, created_at, id',
      );
      expect([for (final c in categories) c['name']], autoNames);
      final meta = (await E2eHost.row(
        "select raw_user_meta_data->>'terms_version' as terms, raw_user_meta_data->>'marketing_consent' as marketing "
        'from auth.users where id = ${sqlText(uid)}',
      ))!;
      expect(meta['terms'], isNotEmpty);
      expect(meta['marketing'], 'false');
    },
  );

  testWidgets(
    'a2 · KPSS hedefi: onboarding hatasız biter (26 varsa kpss, yoksa segmentsiz)',
    (tester) async {
      await resetAppState(tester);
      final account = await signUpViaApi(e2eEmail('kpss'), 'Sim KPSS');
      await launchApp(tester);
      await waitPastSplash(tester);
      await loginViaUi(tester, account.email);

      final kpssNames = autoSelectedCategoryNames(
        'kpss',
        kept: const [],
        limit: 8,
      );
      await runOnboarding(
        tester,
        segmentLabel: l10n.onboardingSegmentKpss,
        shotPrefix: 'e2e-kpss',
        verifyCategoryStep: () {
          final selected = [
            for (final chip in tester.widgetList<ChoiceChip>(
              find.byType(ChoiceChip),
            ))
              if (chip.selected) ((chip.label as Text).data ?? ''),
          ];
          expect(selected, kpssNames, reason: 'KPSS önerileri otomatik seçili');
        },
      );
      await expectShell(tester);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'kullanıcı hata görmez',
      );
      await pumpUntilTrue(
        tester,
        () => timerChipLabels(tester).length == kpssNames.length,
        reason: 'KPSS çipleri',
      );

      final profile = (await E2eHost.row(
        'select user_segment, onboarding_completed_at is not null as onboarded, daily_goal_minutes, show_in_social_feed '
        'from public.profiles where id = ${sqlText(account.id)}',
      ))!;
      final segmentCheck = await E2eHost.psql(
        "select pg_get_constraintdef(oid) like '%kpss%' from pg_constraint where conname = 'profiles_user_segment_check'",
      );
      if (segmentCheck == 'f') {
        expect(
          profile['user_segment'],
          isNull,
          reason: 'CHECK kpss tanımıyor: segmentsiz geri düşüş',
        );
      } else {
        expect(profile['user_segment'], 'kpss');
      }
      expect(profile['onboarded'], isTrue);
      expect(profile['daily_goal_minutes'], 120);
      expect(profile['show_in_social_feed'], isTrue);
      final categories = await E2eHost.rows(
        'select name from public.categories where user_id = ${sqlText(account.id)} and not is_archived '
        'order by sort_order, created_at, id',
      );
      expect([for (final c in categories) c['name']], kpssNames);
    },
  );
}
