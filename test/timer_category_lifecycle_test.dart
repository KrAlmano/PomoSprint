import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

// CAT-08: yer tutucudan (Türkçe ad) İngilizce adlı sunucu kategorisine
// geçişte seçim ilk kategoriye atlamaz.
// CAT-05: süren/duraklatılmış seansın kategorisi arşivlenince sayaç seansın
// ad ve rengini korur; uygulama yeniden açılınca da (renk kayıttan).
// (TimerPersistence tekil olduğu için dosyada tek testWidgets var.)
void main() {
  const owner = 'u-cat';
  final placeholders = CourseCategory.initialCategories().take(2).toList(); // Matematik '1', Fizik '2'
  final math = CourseCategory(
    id: 'aaaaaaaa-0000-4000-8000-000000000001',
    name: 'Mathematics',
    color: const Color(0xFFEF4444),
    icon: Icons.calculate_outlined,
  );
  final physics = CourseCategory(
    id: 'aaaaaaaa-0000-4000-8000-000000000002',
    name: 'Physics',
    color: const Color(0xFF3B82F6),
    icon: Icons.science_outlined,
  );

  testWidgets('kategori seçimi dilden bağımsız eşlenir; seansın kategorisi arşivde de korunur', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    unawaited(LanguageService.instance.setLanguage(AppLanguage.tr));
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    final lang = LanguageService.instance;
    final lockScreen = LockScreenTimer(
      platform: FakeLockScreenPlatform(),
      isEnabled: () async => true,
      categoryLabel: (name) => name,
    );

    Widget app(List<CourseCategory> categories) => MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TimerScreen(
            categories: categories,
            sessionOwnerKey: owner,
            onOpenSettings: () {},
            onSessionCompleted: (_) async => null,
            lockScreenTimer: lockScreen,
          ),
        );

    // Çipler arayüz dilinde (TR) görünür: 'Physics' → 'Fizik'.
    FilterChip chip(String label) => tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
    Color? sand() => tester.widget<HourglassWidget>(find.byType(HourglassWidget)).sandColor;

    // --- CAT-08 ---
    await tester.pumpWidget(app(placeholders));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Fizik'));
    await tester.pump();
    expect(chip('Fizik').selected, isTrue);

    // Bağlantı geldi: sunucu kategorileri İngilizce adlı (İngilizce onboarding).
    await tester.pumpWidget(app([math, physics]));
    await tester.pump();
    expect(chip('Fizik').selected, isTrue, reason: 'seçim ilk kategoriye atlamamalı');
    expect(chip('Matematik').selected, isFalse);

    // --- CAT-05: seans Fizik'le başlar (3-2-1 sonrası), hemen duraklatılır.
    await tester.tap(find.text(lang.translate('btn_start')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.text(lang.translate('btn_pause')));
    await tester.pump();
    expect(find.text(l10n.timerResetBtn), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final record = jsonDecode(prefs.getString(TimerPersistence.keyFor(owner))!) as Map<String, dynamic>;
    expect(record['category_id'], physics.id);
    expect(record['category_color'], physics.colorHex);

    // Fizik seans duraklatılmışken arşivlendi (aktif listeden çıktı).
    await tester.pumpWidget(app([math]));
    await tester.pump();
    expect(chip('Fizik').selected, isTrue);
    expect(chip('Matematik').selected, isFalse);
    expect(sand(), physics.color);

    // Uygulama kapanıp açıldı: renk seans kaydından gelir.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(app([math]));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.timerResetBtn), findsOneWidget);
    expect(chip('Fizik').selected, isTrue);
    expect(sand(), physics.color);

    // Seans bırakılınca arşivdeki kategori çipi kalkar, aktif kategori seçilir.
    await tester.tap(find.text(l10n.timerResetBtn));
    await tester.pump();
    await tester.tap(find.text(l10n.timerResetConfirmAction).last);
    await tester.pump();
    expect(find.widgetWithText(FilterChip, 'Fizik'), findsNothing);
    expect(chip('Matematik').selected, isTrue);
    expect(sand(), math.color);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
