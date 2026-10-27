// t2 — Yeni onboarding hedefleri (KPSS, dil sınavı) ve CHECK'i henüz
// genişletilmemiş sunucu: istemcinin geri düşüşü, uçtan uca.
//
// Uygulamanın GERÇEK SupabaseService'i (completeOnboarding: profil garantisi
// → kategori uzlaştırma → setup_onboarding_categories → profiles PATCH →
// segment CHECK ihlalinde segmentsiz ikinci PATCH) ve son testte GERÇEK
// onboarding ekranı (KPSS seçimi → otomatik kategoriler → "Bitir") yerel
// Supabase kopyasına (http://127.0.0.1:54321) gerçek HTTP ile bağlanır. Ana yerel kopya canlıyla
// eşittir: supabase/proposed/26 UYGULANMAMIŞ (profiles_user_segment_check
// yalnızca lgs/yks/university/work). Kopya 26'yı tanıyorsa testler bunu söyler.
//
// Çalıştırma (yalnızca yerel kopya açıkken; normal `flutter test` bunu almaz):
//   flutter test tool/local_supabase/e2e/t2_onboarding_categories/segment_fallback_e2e_test.dart
//
// Her senaryo kendi hesabını açar (t2-seg-<hedef>-<zaman>@pomosprint.local);
// test1/test2'ye dokunmaz.

// Dosya test/ dışında olduğu için analizör @visibleForTesting üyelerini
// test kullanımı saymıyor.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/utils/category_names.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'http://127.0.0.1:54321';
const _anon =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9'
    '.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const _password = 'pomosprint-yerel-test';

void main() {
  // Ekran testi için test bağlamı; flutter_test'in sahte HTTP'si kapatılır
  // (istekler gerçekten yerel kopyaya gider).
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  final service = SupabaseService.instance;
  SupabaseClient client() => Supabase.instance.client;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Uygulamadaki gibi (SupabaseService.initialize): implicit akış.
    await Supabase.initialize(
      url: _url,
      // ignore: deprecated_member_use
      anonKey: _anon,
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit, detectSessionInUri: false),
    );
    service.debugCloudInitializer = () async {};
    service.debugCloudActive = true;
  });

  /// Yeni hesap açar (yerelde e-posta onayı kapalı: oturum açılır) ve
  /// currentUser'ı sunucudan yükler; onboarding bitmemiş.
  Future<String> signUp(String tag) async {
    if (client().auth.currentUser != null) await client().auth.signOut();
    service.currentUser.value = null;
    final email = 't2-seg-$tag-${DateTime.now().millisecondsSinceEpoch}@pomosprint.local';
    final res = await client().auth.signUp(email: email, password: _password, data: {
      'name': 'T2 Segment',
      'avatar_id': 'avatar_16_basic',
      'newsletter': false,
      'marketing_consent': false,
      'terms_version': '2026-10-03',
      'privacy_version': '2026-10-03',
      'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
    });
    final uid = res.user!.id;
    expect(client().auth.currentUser?.id, uid, reason: 'yerelde e-posta onayı kapalı: kayıt oturum açmalı');
    final user = await service.fetchCurrentUserModel();
    expect(user?.onboardingCompletedAt, isNull);
    return uid;
  }

  Future<Map<String, dynamic>> profile(String uid) => client()
      .from('profiles')
      .select('user_segment, birth_year, daily_goal_minutes, show_in_social_feed, onboarding_completed_at')
      .eq('id', uid)
      .single();

  Future<void> completeWith(String segment, {required bool turkish}) => service.completeOnboarding(
        birthYear: 1995,
        userSegment: segment,
        dailyGoalMinutes: 120,
        // Ekranın segment seçilince otomatik seçtiği kategoriler (ücretsiz limit 8).
        categories: categorySeedPayload(autoSelectedCategoryNames(segment, kept: const [], limit: 8), turkish: turkish),
        showInSocialFeed: false,
      );

  test('yerel kopya canlı hâlde: profiles_user_segment_check KPSS\'yi 23514 ile reddeder', () async {
    final uid = await signUp('probe');
    Object? error;
    try {
      await client().from('profiles').update({'user_segment': 'kpss'}).eq('id', uid).select('id');
    } catch (e) {
      error = e;
    }
    expect(error, isA<PostgrestException>(),
        reason: 'proposed/26 bu kopyada uygulanmış görünüyor; geri düşüş sınanamaz (ana kopya canlıyla eşit olmalı)');
    expect((error! as PostgrestException).code, '23514');
    expect(SupabaseService.isUserSegmentCheckViolation(error), isTrue, reason: 'sunucunun gerçek hatası tanınır');
    expect(SupabaseService.isUserSegmentCheckViolation(ServiceException.wrap(error)), isTrue);
  });

  for (final (segment, turkish, names) in [
    ('kpss', true, ['Türkçe', 'Matematik', 'Tarih', 'Coğrafya', 'Vatandaşlık', 'Güncel Bilgiler', 'Eğitim Bilimleri']),
    ('language', false, ['Vocabulary', 'Reading', 'Grammar', 'Listening', 'Writing', 'Speaking']),
  ]) {
    test("'$segment': hata yok, onboarding segmentsiz tamamlanır, kategoriler kurulur", () async {
      final uid = await signUp(segment);
      await completeWith(segment, turkish: turkish); // fırlatmaz

      final row = await profile(uid);
      expect(row['user_segment'], isNull, reason: 'CHECK yeni hedefi tanımıyor: null yazıldı');
      expect(row['onboarding_completed_at'], isNotNull, reason: 'onboarding tamamlandı');
      expect(row['birth_year'], 1995);
      expect(row['daily_goal_minutes'], 120);
      expect(row['show_in_social_feed'], isFalse, reason: 'görünürlük yanıtı ikinci yazımda da korunur');

      final categories = await service.fetchUserCategories();
      expect([for (final c in categories) c.name], names);

      final user = service.currentUser.value!;
      expect(user.onboardingCompletedAt, isNotNull, reason: 'AppGate kabuğa geçer');
      expect(user.userSegment, isNull);
      expect(user.dailyGoalMinutes, 120);
    });
  }

  test("eski hedef ('yks') tek yazımda olduğu gibi saklanır", () async {
    final uid = await signUp('yks');
    await completeWith('yks', turkish: true);
    final row = await profile(uid);
    expect(row['user_segment'], 'yks');
    expect(row['onboarding_completed_at'], isNotNull);
    expect((await service.fetchUserCategories()).length, 8);
  });

  testWidgets("ekran: KPSS seçilip 'Bitir'e basılınca hata görünmez, onboarding tamamlanır", (tester) async {
    late String uid;
    await tester.runAsync(() async => uid = await signUp('ekran'));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var completed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PostAuthOnboardingScreen(onCompleted: () => completed = true),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(PostAuthOnboardingScreen)))!;
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -1040));
    await tester.pumpAndSettle();
    await tap(find.text(l10n.continueBtn));
    await tap(find.text(l10n.onboardingSegmentKpss));
    await tap(find.text(l10n.continueBtn));
    expect(find.text(l10n.onboardingCategoryStepPreparedTitle), findsOneWidget);
    await tap(find.text(l10n.continueBtn)); // otomatik seçili kategorilerle
    await tap(find.text(l10n.onboardingVisibilityNo));
    await tap(find.text(l10n.continueBtn));
    await tap(find.text(l10n.continueBtn));
    expect(find.text('6/7'), findsOneWidget);
    await tap(find.text(l10n.continueBtn));
    expect(find.text('7/7'), findsOneWidget);
    expect(find.text(l10n.onboardingGuideTitle), findsOneWidget);

    // "Bitir" gerçek zamanda: ağ istekleri yerel kopyaya gider.
    final finish = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.onboardingFinishBtn));
    await tester.runAsync(() async {
      finish.onPressed!();
      for (var i = 0; i < 150 && !completed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pump();
    expect(completed, isTrue, reason: 'onCompleted çağrıldı (AppGate kabuğa geçer)');
    expect(find.text(l10n.onboardingSaveError), findsNothing);
    expect(find.text(l10n.onboardingTimeoutError), findsNothing);
    expect(find.byType(SnackBar), findsNothing, reason: 'kullanıcı hata görmez');

    late Map<String, dynamic> row;
    late List<String> names;
    await tester.runAsync(() async {
      row = await profile(uid);
      names = [for (final c in await service.fetchUserCategories()) c.name];
    });
    expect(row['user_segment'], isNull);
    expect(row['onboarding_completed_at'], isNotNull);
    expect(row['show_in_social_feed'], isFalse);
    expect(row['daily_goal_minutes'], 60);
    final turkish = LanguageService.instance.isTurkish;
    expect(names, [for (final n in recommendedCategoryNames('kpss')) localizedKnownCategoryName(n, turkish: turkish)]);
  });

  tearDownAll(() async {
    if (client().auth.currentUser != null) await client().auth.signOut();
    service.currentUser.value = null;
  });
}
