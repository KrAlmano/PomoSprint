import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Duraklatılmış seans, süre çipine dokunarak (seçili olana bile) onaysız
// silinmemeli; seansı bırakmanın yolu onaylı "Sıfırla"dır.
void main() {
  const owner = 'u1';
  final category = CourseCategory.initialCategories().first;

  Future<void> pumpPausedTimer(WidgetTester tester) async {
    // Dikey ekran (yatayda süre çipleri gizlenir). Test yazı tipi kare
    // glifli olduğu için genişlik gerçek telefondan biraz fazla tutulur.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final paused = ActiveTimerSession.start(
      clientUuid: 'paused-1',
      categoryId: category.id,
      categoryName: category.name,
      durationMinutes: 25,
      totalSeconds: 25 * 60,
      now: now.subtract(const Duration(minutes: 20)),
    ).pauseAt(now.subtract(const Duration(seconds: 30)));
    await TimerPersistence.instance.save(owner, paused);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TimerScreen(
        categories: [category],
        sessionOwnerKey: owner,
        onOpenSettings: () {},
        onSessionCompleted: (_) async {},
      ),
    ));
    // Kayıt (SharedPreferences) geri yüklenir.
    await tester.pump();
  }

  // Cihazdaki seans kaydının sahibi (yoksa null). TimerPersistence tekil
  // ve kilitli olduğu için tüm işlemler aynı (fake async) bölgede yapılır;
  // runAsync ile karıştırılırsa kilit zinciri hiç ilerlemez.
  Future<String?> stored(WidgetTester tester) async {
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(TimerPersistence.keyFor(owner));
    return raw == null ? null : ActiveTimerSession.fromJson(jsonDecode(raw))?.clientUuid;
  }

  // Ekran kapanırken seansı kaydeder; test bitmeden tamamlanmalı.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  // Tek test: TimerPersistence tekil ve kilidinin Future zinciri, onu
  // oluşturan testin fake async bölgesine bağlı kalır; ikinci bir testWidgets
  // o zinciri bekleyince hiç ilerlemez.
  testWidgets('süre çipleri seansı silmez; Sıfırla onay ister', (tester) async {
    await pumpPausedTimer(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.timerResetBtn), findsOneWidget);

    // 1) Süre çiplerine (seçili 25 dahil) dokunmak seansı silmez.
    await tester.tap(find.textContaining('25 '));
    await tester.pump();
    await tester.tap(find.textContaining('50 '));
    await tester.pump();
    expect(await stored(tester), 'paused-1');
    expect(find.text(l10n.timerDurationLocked), findsOneWidget);
    expect(find.text(l10n.timerResetBtn), findsOneWidget);

    // 2) Sıfırla onay ister; vazgeçince seans kalır.
    await tester.tap(find.text(l10n.timerResetBtn));
    await tester.pump();
    expect(find.text(l10n.timerResetConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pump();
    expect(await stored(tester), 'paused-1');
    expect(find.text(l10n.timerResetBtn), findsOneWidget);

    // 3) Onaylayınca seans silinir.
    await tester.tap(find.text(l10n.timerResetBtn));
    await tester.pump();
    await tester.tap(find.text(l10n.timerResetConfirmAction).last);
    await tester.pump();
    expect(find.text(l10n.timerResetBtn), findsNothing);
    expect(await stored(tester), isNull);

    // Ekran kapanırken silinmiş seans geri yazılmaz.
    await unmount(tester);
    expect(await stored(tester), isNull);
  });
}
