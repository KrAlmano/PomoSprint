// Onboarding'de hedefe göre kategori ataması: segment seçilince önerileri
// otomatik seçili gelir, segment değişince yalnızca otomatik gelenler
// değişir (elle seçilenler ve özel kategoriler korunur). Yeni hedefler
// (KPSS, dil sınavı) ve CHECK'i henüz genişletilmemiş sunucuya (canlı;
// supabase/proposed/26 uygulanmadan) gönderilen hedefin geri düşüşü.
//
// Supabase başlatılmadan çalışır (bulut kapalı). Sunucuyla uçtan uca
// doğrulama: tool/local_supabase/e2e/t2_onboarding_categories/segment_fallback_e2e_test.dart.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _user = UserModel(id: 'uid-goal', name: 'Ayşe', email: 'ayse@example.com');

const _yksFirst8 = ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe'];

Future<AppLocalizations> _pump(WidgetTester tester, {Locale locale = const Locale('tr')}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PostAuthOnboardingScreen(onCompleted: () {}),
  ));
  await tester.pumpAndSettle();
  // Taslak okuması (SharedPreferences) gerçek zamanda biter.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(PostAuthOnboardingScreen)))!;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Yaş adımını geçer (20 yıl öncesi) ve segment adımına gelir.
Future<void> _toSegmentStep(WidgetTester tester, AppLocalizations l10n) async {
  await tester.drag(find.byType(CupertinoPicker), const Offset(0, -1040));
  await tester.pumpAndSettle();
  await _tap(tester, find.text(l10n.continueBtn));
  expect(find.text('2/7'), findsOneWidget);
}

List<String> _chips(WidgetTester tester, {bool selectedOnly = false}) => [
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)))
        if (!selectedOnly || chip.selected) (chip.label as Text).data!,
    ];

Future<OnboardingDraft> _savedDraft() async {
  final prefs = await SharedPreferences.getInstance();
  return OnboardingDraft.fromJson(jsonDecode(prefs.getString(OnboardingDraftStore.keyFor(_user.id!))!))!;
}

PostgrestException _segmentCheckViolation() => const PostgrestException(
      message: 'new row for relation "profiles" violates check constraint "profiles_user_segment_check"',
      code: '23514',
      details: 'Failing row contains (...).',
    );

void main() {
  final service = SupabaseService.instance;

  // Tekil servisler (AsyncLock zincirleri) gerçek zone'da kurulmalı.
  setUpAll(() {
    expect(SupabaseService.instance, isNotNull);
    expect(TimerPersistence.instance, isNotNull);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.currentUser.value = _user;
  });

  tearDown(() => service.currentUser.value = null);

  group('Hedefe göre kategori ataması', () {
    testWidgets('YKS seçilince ilk 8 öneri seçili gelir; başlık hazırlandığını söyler, seçmeden ilerlenir',
        (tester) async {
      final l10n = await _pump(tester);
      await _toSegmentStep(tester, l10n);
      await _tap(tester, find.text(l10n.onboardingSegmentYks));
      await _tap(tester, find.text(l10n.continueBtn));

      expect(find.text('3/7'), findsOneWidget);
      expect(find.text(l10n.onboardingCategoryStepPreparedTitle), findsOneWidget);
      expect(find.text(l10n.onboardingCategoryStepPreparedBody(8)), findsOneWidget);
      expect(_chips(tester, selectedOnly: true), _yksFirst8);
      expect(_chips(tester), contains('İngilizce'), reason: 'limit (8) dışındaki öneri seçilmeden görünür');
      expect(find.text('8 / 8'), findsOneWidget);
      expect((await _savedDraft()).autoCategories, _yksFirst8);

      await _tap(tester, find.text(l10n.continueBtn));
      expect(find.text('4/7'), findsOneWidget, reason: 'hazır seçimle doğrudan devam edilir');
    });

    testWidgets('segment değişince yalnızca otomatik gelenler değişir; elle seçilen ve özel kategori korunur',
        (tester) async {
      final l10n = await _pump(tester);
      await _toSegmentStep(tester, l10n);
      await _tap(tester, find.text(l10n.onboardingSegmentYks));
      await _tap(tester, find.text(l10n.continueBtn));

      // İki otomatik öneri kaldırılır, sınır dışındaki öneri elle seçilir ve
      // özel kategori eklenir.
      await _tap(tester, find.text('Kimya'));
      await _tap(tester, find.text('Biyoloji'));
      await _tap(tester, find.text('İngilizce'));
      await _tap(tester, find.text(l10n.onboardingCreateOwnCategory));
      await tester.enterText(find.byType(TextField), 'Robotik');
      await _tap(tester, find.text(l10n.addBtn));
      expect(find.text('8 / 8'), findsOneWidget);

      // Segment adımına dönüp KPSS: YKS'nin otomatik gelenleri gider.
      await _tap(tester, find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(Scaffold))).backButtonTooltip));
      expect(find.text('2/7'), findsOneWidget);
      await _tap(tester, find.text(l10n.onboardingSegmentKpss));
      await _tap(tester, find.text(l10n.continueBtn));

      const kpssFirst6 = ['Türkçe', 'Matematik', 'Tarih', 'Coğrafya', 'Vatandaşlık', 'Güncel Bilgiler'];
      expect(_chips(tester, selectedOnly: true).toSet(), {...kpssFirst6, 'İngilizce', 'Robotik'});
      expect(_chips(tester), containsAll(['Eğitim Bilimleri', 'Robotik', 'İngilizce']),
          reason: 'korunan elle seçim KPSS önerisi olmasa da görünür kalır');
      expect(_chips(tester), isNot(contains('Fizik')));
      expect(_chips(tester, selectedOnly: true), isNot(contains('Eğitim Bilimleri')), reason: 'limit 8');

      final draft = await _savedDraft();
      expect(draft.segment, 'kpss');
      expect(draft.autoCategories, kpssFirst6);
      expect(draft.customCategories, ['Robotik']);
      expect(draft.selectedCategories.toSet(), {...kpssFirst6, 'İngilizce', 'Robotik'});
    });

    testWidgets('"Diğer" genel önerileri seçili getirir; başlık hedef demez', (tester) async {
      final l10n = await _pump(tester);
      await _toSegmentStep(tester, l10n);
      await _tap(tester, find.text(l10n.onboardingSegmentOther));
      await _tap(tester, find.text(l10n.continueBtn));
      expect(_chips(tester, selectedOnly: true), kGeneralCategoryRecommendations);
      expect(find.text(l10n.onboardingCategoryStepTitle), findsOneWidget);
      expect(find.text(l10n.onboardingCategoryStepPreparedTitle), findsNothing);
    });

    testWidgets('Premium limitinde (15) YKS önerilerinin hepsi seçili gelir', (tester) async {
      service.currentUser.value = UserModel(id: _user.id, name: _user.name, email: _user.email, isPremium: true);
      final l10n = await _pump(tester);
      await _toSegmentStep(tester, l10n);
      await _tap(tester, find.text(l10n.onboardingSegmentYks));
      await _tap(tester, find.text(l10n.continueBtn));
      expect(_chips(tester, selectedOnly: true), recommendedCategoryNames('yks'));
      expect(find.text(l10n.onboardingCategoryStepPreparedBody(15)), findsOneWidget);
    });
  });

  group('Yeni hedefler: KPSS ve dil sınavı', () {
    testWidgets('segment sırası: LGS, YKS, KPSS, Dil sınavı, Üniversite, İş, Diğer', (tester) async {
      final l10n = await _pump(tester);
      await _toSegmentStep(tester, l10n);
      final labels = [
        l10n.onboardingSegmentLgs,
        l10n.onboardingSegmentYks,
        l10n.onboardingSegmentKpss,
        l10n.onboardingSegmentLanguage,
        l10n.onboardingSegmentUniversity,
        l10n.onboardingSegmentWork,
        l10n.onboardingSegmentOther,
      ];
      final tops = [for (final label in labels) tester.getTopLeft(find.text(label)).dy];
      expect(tops, [...tops]..sort(), reason: 'yukarıdan aşağı bu sırayla');
      expect(l10n.onboardingSegmentLanguage, contains('YDS'));
    });

    testWidgets('İngilizce arayüzde dil sınavı önerileri İngilizce ve seçili', (tester) async {
      final lang = LanguageService.instance;
      await tester.runAsync(() => lang.setLanguage(AppLanguage.en));
      addTearDown(() => tester.runAsync(() => lang.setLanguage(AppLanguage.tr)));
      final l10n = await _pump(tester, locale: const Locale('en'));
      await _toSegmentStep(tester, l10n);
      expect(l10n.onboardingSegmentKpss, contains('civil service'));
      await _tap(tester, find.text(l10n.onboardingSegmentLanguage));
      await _tap(tester, find.text(l10n.continueBtn));
      expect(_chips(tester, selectedOnly: true), ['Vocabulary', 'Reading', 'Grammar', 'Listening', 'Writing', 'Speaking']);
    });
  });

  group('Segment CHECK geri düşüşü (proposed/26 canlıda değil)', () {
    final at = DateTime.utc(2026, 10, 5, 12);
    Map<String, dynamic> update(String? segment) => SupabaseService.onboardingProfileUpdate(
          birthYear: 1995,
          userSegment: segment,
          dailyGoalMinutes: 120,
          showInSocialFeed: false,
          completedAt: at,
        );

    test("istemci 'kpss' ve 'language'ı gönderir; 'Diğer' ve bilinmeyen null", () {
      expect(update('kpss')['user_segment'], 'kpss');
      expect(update('language')['user_segment'], 'language');
      expect(update('yks')['user_segment'], 'yks');
      expect(update('other')['user_segment'], isNull);
      expect(update('abc')['user_segment'], isNull);
    });

    test('CHECK ihlali tanınır (ham ve sarılmış); başka 23514 ve başka hata değil', () {
      expect(SupabaseService.isUserSegmentCheckViolation(_segmentCheckViolation()), isTrue);
      expect(SupabaseService.isUserSegmentCheckViolation(ServiceException.wrap(_segmentCheckViolation())), isTrue);
      expect(
        SupabaseService.isUserSegmentCheckViolation(
            const PostgrestException(message: 'birth_year_under_minimum_age', code: '23514')),
        isFalse,
      );
      expect(SupabaseService.isUserSegmentCheckViolation(TimeoutException('x')), isFalse);
    });

    test('sunucu yeni hedefi reddederse segment null yazılır, onboarding tamamlanır', () async {
      final writes = <Map<String, dynamic>>[];
      final written = await SupabaseService.writeOnboardingProfileWithSegmentFallback(update('kpss'), (values) async {
        writes.add(values);
        // Canlıdaki CHECK: yalnızca lgs, yks, university, work (ve null).
        final segment = values['user_segment'];
        if (segment != null && !{'lgs', 'yks', 'university', 'work'}.contains(segment)) {
          throw ServiceException.wrap(_segmentCheckViolation());
        }
      });
      expect(writes, hasLength(2));
      expect(writes.first['user_segment'], 'kpss');
      expect(written['user_segment'], isNull);
      final expected = {...update('kpss'), 'user_segment': null};
      expect(written, expected, reason: 'diğer alanlar (tamamlanma zamanı, görünürlük) aynen yazılır');
    });

    test('26 uygulanmışsa tek yazım, hedef korunur', () async {
      final writes = <Map<String, dynamic>>[];
      final written =
          await SupabaseService.writeOnboardingProfileWithSegmentFallback(update('language'), (v) async => writes.add(v));
      expect(writes, hasLength(1));
      expect(written['user_segment'], 'language');
    });

    test('başka hatalarda yeniden denenmez, hata kullanıcıya iletilir', () async {
      for (final error in [
        ServiceException.wrap(const PostgrestException(message: 'birth_year_under_minimum_age', code: '23514')),
        ServiceException.wrap(TimeoutException('zaman aşımı')),
        const ServiceException(ServiceErrorCode.notFound),
      ]) {
        var calls = 0;
        await expectLater(
          SupabaseService.writeOnboardingProfileWithSegmentFallback(update('kpss'), (_) async {
            calls++;
            throw error;
          }),
          throwsA(same(error)),
        );
        expect(calls, 1, reason: '$error');
      }
      // Segment gönderilmediyse CHECK ihlali de olduğu gibi iletilir.
      var calls = 0;
      await expectLater(
        SupabaseService.writeOnboardingProfileWithSegmentFallback(update('other'), (_) async {
          calls++;
          throw ServiceException.wrap(_segmentCheckViolation());
        }),
        throwsA(isA<ServiceException>()),
      );
      expect(calls, 1);
    });
  });
}
