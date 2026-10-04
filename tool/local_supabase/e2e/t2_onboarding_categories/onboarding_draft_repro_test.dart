// t2 — Onboarding taslağı (yarıda kalan onboarding) istemci reprosu.
//
//   flutter test tool/local_supabase/e2e/t2_onboarding_categories/onboarding_draft_repro_test.dart
//
// Bulut kapalı çalışır (Supabase başlatılmaz). Her test BEKLENEN doğru
// davranışı iddia eder; kırmızı test bulgudur. Kurulum
// test/account_session_test.dart'taki taslak testiyle aynıdır.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/auth/category_name_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _user = UserModel(id: 'uid-t2', name: 'Ayşe', email: 't2@example.com');

Future<AppLocalizations> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byWidget(home)))!;
}

Future<OnboardingDraft> _restore(WidgetTester tester, OnboardingDraft draft) async {
  SupabaseService.instance.currentUser.value = _user;
  // Dosya test/ dışında olduğu için analizci uyarır; burada da bir testtir.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({OnboardingDraftStore.keyFor('uid-t2'): jsonEncode(draft.toJson())});
  await _pump(tester, PostAuthOnboardingScreen(onCompleted: () {}));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  final prefs = await SharedPreferences.getInstance();
  return OnboardingDraft.fromJson(jsonDecode(prefs.getString(OnboardingDraftStore.keyFor('uid-t2'))!))!;
}

void main() {
  setUpAll(() {
    expect(SupabaseService.instance, isNotNull);
    expect(TimerPersistence.instance, isNotNull);
  });
  tearDown(() => SupabaseService.instance.currentUser.value = null);

  testWidgets('T2-DRAFT-1: "Diğer" segmentli taslak geri yüklenince seçimler ve adım korunur', (tester) async {
    final saved = await _restore(
      tester,
      const OnboardingDraft(
        step: 4, // kurallar adımı: yaş, segment, kategori, görünürlük geçildi
        birthYear: 1990,
        segment: 'other',
        selectedCategories: ['Okuma', 'Proje'],
        dailyGoalMinutes: 120,
      ),
    );
    // ignore: avoid_print
    print('T2-DRAFT-1 gerçek: ekranda=${_stepText(tester)} kaydedilen taslak=${jsonEncode(saved.toJson())}');
    expect(saved.segment, 'other', reason: '"Diğer" seçimi taslaktan geri gelmeli');
    expect(saved.selectedCategories, ['Okuma', 'Proje'], reason: 'genel önerilerden yapılan seçim kaybolmamalı');
    expect(find.text('5/6'), findsOneWidget, reason: 'kullanıcı kaldığı adıma (5/6) dönmeli');
  });

  testWidgets('T2-DRAFT-2: segment seçmeden (isteğe bağlı) ilerleyen kullanıcının taslağı korunur', (tester) async {
    final saved = await _restore(
      tester,
      const OnboardingDraft(step: 3, birthYear: 2000, selectedCategories: ['Ders Çalışma'], dailyGoalMinutes: 60),
    );
    // ignore: avoid_print
    print('T2-DRAFT-2 gerçek: ekranda=${_stepText(tester)} kaydedilen taslak=${jsonEncode(saved.toJson())}');
    expect(saved.selectedCategories, ['Ders Çalışma']);
    expect(find.text('4/6'), findsOneWidget);
  });

  testWidgets('T2-DRAFT-3: taslaktan dönen kullanıcı görünürlük sorusunu yanıtlamadan bitiremez', (tester) async {
    await _restore(
      tester,
      const OnboardingDraft(
        step: 5,
        birthYear: 2008,
        segment: 'yks',
        selectedCategories: ['Fizik'],
        dailyGoalMinutes: 60,
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    // ignore: avoid_print
    print('T2-DRAFT-3 gerçek: ekranda=${_stepText(tester)}');
    expect(find.text('6/6'), findsOneWidget, reason: 'taslak son adıma döndü');
    await tester.tap(find.text(l10n.onboardingFinishBtn));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final askedVisibility = find.text(l10n.onboardingSelectOptionError).evaluate().isNotEmpty ||
        find.text(l10n.onboardingVisibilityYes).evaluate().isNotEmpty;
    final triedToSave = find.text(l10n.onboardingTimeoutError).evaluate().isNotEmpty;
    // ignore: avoid_print
    print('T2-DRAFT-3 gerçek: görünürlük soruldu=$askedVisibility, kayda gidildi=$triedToSave');
    expect(triedToSave, isFalse,
        reason: 'show_in_social_feed açıkça seçilmeden completeOnboarding çağrılmamalı (sunucu varsayılanı TRUE)');
    expect(askedVisibility, isTrue);
  });

  test('T2-NAME-1: Türkçe İ ile başlayan özel ad küçük harfli eşiyle aynı sayılmalı', () {
    // Sunucu yalnızca birebir ad eşitliğinde çoğaltmayı engeller; istemci
    // denetimi tek savunma.
    final taken = isCategoryNameTaken('istatistik', ['İstatistik']);
    // ignore: avoid_print
    print('T2-NAME-1 gerçek: isCategoryNameTaken(istatistik, [İstatistik]) = $taken; '
        'key1=${categoryNameKey('İstatistik').codeUnits} key2=${categoryNameKey('istatistik').codeUnits}');
    expect(taken, isTrue);
  });
}

String _stepText(WidgetTester tester) {
  for (var i = 1; i <= 6; i++) {
    if (find.text('$i/6').evaluate().isNotEmpty) return '$i/6';
  }
  return '?';
}
