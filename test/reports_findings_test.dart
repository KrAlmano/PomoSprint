// Raporlar ekranı bulgularının (REP-*, MH-*, X-*) yeniden üretimi. Her test
// bulguyu düzeltmeden önce başarısız olacak biçimde yazıldı; düzeltmeden
// sonra davranışı kilitler.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:pomodoro/widgets/stats/daily_goal_sheet.dart';

import 'support/fake_supabase_service.dart';

const _mathId = 'aaaaaaaa-0000-4000-8000-000000000001';
const _physicsId = 'aaaaaaaa-0000-4000-8000-000000000002';

Map<String, dynamic> _row(
  String id,
  DateTime startedAt, {
  int minutes = 25,
  String name = 'Matematik',
  String? categoryId = _mathId,
  String colorHex = '#EF4444',
  String? iconName,
  String? clientUuid,
}) =>
    {
      'id': id,
      'user_id': 'user-1',
      'category': name,
      'category_id': categoryId,
      'duration_minutes': minutes,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': startedAt.add(Duration(minutes: minutes)).toUtc().toIso8601String(),
      'client_uuid': clientUuid,
      'categories': categoryId == null ? null : {'name': name, 'color_hex': colorHex, 'icon_name': iconName},
    };

PendingSession _pending(
  String uuid,
  DateTime startedAt, {
  int minutes = 25,
  String name = 'Matematik',
  String? categoryId = _mathId,
  int? clockOffsetMs,
  String? lastError,
}) =>
    PendingSession(
      clientUuid: uuid,
      categoryId: categoryId,
      categoryName: name,
      minutes: minutes,
      wasPaused: false,
      foregroundSeconds: minutes * 60,
      startedAt: startedAt.toUtc(),
      queuedAt: startedAt.add(Duration(minutes: minutes)).toUtc(),
      clockOffsetMs: clockOffsetMs,
      lastError: lastError,
    );

// Raporlar ekranının "bugün"ü (gerçek saat, profil diliminde 04:00).
DateTime get _today => studyDayOf(DateTime.now());

/// Bugünün çalışma günü başlangıcından [hours] saat sonra.
DateTime _todayAt(int hours, [int minutes = 0]) =>
    studyDayStart(_today).add(Duration(hours: hours, minutes: minutes));

late AppLocalizations l10n;

Future<void> _pumpReports(
  WidgetTester tester,
  FakeSupabaseService service, {
  List<CourseCategory> categories = const [],
  ValueNotifier<bool>? visible,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final isVisible = visible ?? ValueNotifier(true);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ValueListenableBuilder<bool>(
      valueListenable: isVisible,
      builder: (_, v, _) => TickerMode(
        enabled: v,
        child: ReportsScreen(categories: categories, service: service),
      ),
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

// Gün dönümü zamanlayıcısı test bitmeden iptal edilsin.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _pumpView(WidgetTester tester, Widget child, {Size size = const Size(800, 3000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ));
  await tester.pumpAndSettle();
}

String _goal(String today) => '$today / 3sa 20dk';

Future<void> _noop() async {}

StatSession _s(DateTime day, int minutes, String name, {String? id, bool pending = false}) =>
    StatSession(day: day, minutes: minutes, categoryName: name, categoryId: id, pending: pending);

Widget _daily(List<StatSession> sessions, DateTime today, {int goal = 200, bool percent = false}) => DailyReportView(
      sessions: sessions,
      today: today,
      dailyGoalMinutes: goal,
      hasHistory: true,
      categories: const [],
      onRefresh: _noop,
      showDistributionPercent: percent,
      onDistributionModeChanged: (_) {},
    );

Widget _weekly(List<StatSession> sessions, DateTime today, {int goal = 200}) => HistoryScreen(
      sessions: sessions,
      today: today,
      dailyGoalMinutes: goal,
      categories: const [],
      onRefresh: _noop,
    );

Widget _monthly(List<StatSession> sessions, DateTime today) => MonthlyTrackingScreen(
      sessions: sessions,
      today: today,
      categories: const [],
      onRefresh: _noop,
    );

int _parseDuration(String text) {
  final h = RegExp(r'(\d+)sa').firstMatch(text);
  final m = RegExp(r'(\d+)dk').firstMatch(text);
  return (h == null ? 0 : int.parse(h.group(1)!) * 60) + (m == null ? 0 : int.parse(m.group(1)!));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() => LanguageService.instance.setLanguage(AppLanguage.tr));

  group('Raporlar: veri birleştirme (ReportsScreen)', () {
    testWidgets('REP-01/X1: uygulama çevrimdışı açılınca bekleyen seanslar gösterilir', (tester) async {
      final service = FakeSupabaseService()
        ..fetchError = const ServiceException(ServiceErrorCode.network)
        ..queue = [_pending('p-1', _todayAt(2))];
      await _pumpReports(tester, service);

      expect(find.text(l10n.statsLoadErrorTitle), findsNothing);
      expect(find.text(_goal('25dk')), findsOneWidget);
      expect(find.text(l10n.statsPendingSessions(1)), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('REP-01/X1: bir kez yüklendikten sonra çevrimdışı tamamlanan seans görünür', (tester) async {
      final visible = ValueNotifier(true);
      final service = FakeSupabaseService()..remoteRows = [_row('r-1', _todayAt(1), minutes: 50)];
      await _pumpReports(tester, service, visible: visible);
      expect(find.text(_goal('50dk')), findsOneWidget);

      // Pomo sekmesine geçildi, uçak modu açıldı, seans kuyruğa girdi.
      visible.value = false;
      await tester.pumpAndSettle();
      service
        ..fetchError = const ServiceException(ServiceErrorCode.network)
        ..queue = [_pending('p-1', _todayAt(2))];
      service.pendingSessionCount.value = 1;
      service.notifyStatsChanged();

      visible.value = true;
      await tester.pumpAndSettle();
      expect(find.text(_goal('1sa 15dk')), findsOneWidget);
      expect(find.text(l10n.statsPendingSessions(1)), findsOneWidget);
      expect(find.text(l10n.statsStaleNotice), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('REP-02/MH-3/X6: sunucuya yazılmış ama kuyrukta kalan seans bir kez sayılır', (tester) async {
      final service = FakeSupabaseService()
        ..remoteRows = [_row('r-1', _todayAt(1), clientUuid: 'c-1')]
        ..queue = [_pending('c-1', _todayAt(1))];
      await _pumpReports(tester, service);

      expect(find.text(_goal('25dk')), findsOneWidget);
      expect(find.text(l10n.statsPendingSessions(1)), findsNothing);
      await _unmount(tester);
    });

    testWidgets('REP-03/MH-3: senkron anında toplam düşmez, yenileme başarısız olsa da kalır', (tester) async {
      final service = FakeSupabaseService()..queue = [_pending('c-1', _todayAt(1))];
      service.pendingSessionCount.value = 1;
      await _pumpReports(tester, service);
      expect(find.text(_goal('25dk')), findsOneWidget);

      // Kuyruk turu seansı gönderdi: kuyruk boşaldı, sunucuda var; uzak
      // okuma henüz sürüyor.
      service
        ..queue = []
        ..remoteRows = [_row('r-1', _todayAt(1), clientUuid: 'c-1')]
        ..fetchGate = Completer<void>();
      service.pendingSessionCount.value = 0;
      service.notifyStatsChanged();
      await tester.pump();
      await tester.pump();
      expect(find.text(_goal('25dk')), findsOneWidget, reason: 'uzak okuma sürerken');

      // Bağlantı tam o anda koptu.
      service.fetchError = const ServiceException(ServiceErrorCode.network);
      service.fetchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(_goal('25dk')), findsOneWidget, reason: 'uzak okuma başarısız');
      await _unmount(tester);
    });

    testWidgets('REP-04/MH-4: overlap ile bekleyen seans toplama girmez', (tester) async {
      final service = FakeSupabaseService()
        ..remoteRows = [_row('r-1', _todayAt(6), clientUuid: 'a')]
        ..queue = [_pending('b', _todayAt(6, 5), lastError: SessionReason.overlap)];
      await _pumpReports(tester, service);

      expect(find.text(_goal('25dk')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('REP-06/MH-4/X12: bekleyen seansın günü kuyruğun gönderdiği düzeltilmiş saatle', (tester) async {
      // Cihaz 10 dk ileri (sunucu - cihaz = -10 dk): cihazda 04:02, gerçekte 03:52 → önceki gün.
      final service = FakeSupabaseService()
        ..queue = [_pending('p-1', _todayAt(0, 2), clockOffsetMs: -10 * 60 * 1000)];
      await _pumpReports(tester, service);

      expect(find.text(_goal('0dk')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('REP-05/MH-2/CAT-04/X4: kategori değişince Raporlar yenilenir (görünürken)', (tester) async {
      final service = FakeSupabaseService()..remoteRows = [_row('r-1', _todayAt(1))];
      await _pumpReports(tester, service);
      expect(find.text('Matematik'), findsWidgets);

      service.remoteRows = [_row('r-1', _todayAt(1), name: 'Analiz', colorHex: '#3B82F6')];
      service.categoriesRevision.value++;
      await tester.pumpAndSettle();
      expect(find.text('Analiz'), findsWidgets);
      expect(find.text('Matematik'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('REP-05/MH-2: kategori görünmezken değişirse dönünce yenilenir (30 sn dolmadan)', (tester) async {
      final visible = ValueNotifier(true);
      final service = FakeSupabaseService()..remoteRows = [_row('r-1', _todayAt(1))];
      await _pumpReports(tester, service, visible: visible);
      visible.value = false;
      await tester.pumpAndSettle();

      service.remoteRows = [_row('r-1', _todayAt(1), name: 'Analiz')];
      service.categoriesRevision.value++;
      visible.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Analiz'), findsWidgets);
      await _unmount(tester);
    });

    testWidgets('REP-05: arşivlenmiş kategorinin ikonu sunucudan gelir (kitaba dönmez)', (tester) async {
      final service = FakeSupabaseService()
        ..remoteRows = [_row('r-1', _todayAt(1), name: 'Fizik', categoryId: _physicsId, iconName: 'science')];
      await _pumpReports(tester, service);

      expect(find.byIcon(Icons.science_outlined), findsOneWidget);
      expect(find.byIcon(Icons.book_outlined), findsNothing);
      await _unmount(tester);
    });

    testWidgets('REP-05: yalnız bekleyen seansı olan arşivlenmiş kategori rengini korur', (tester) async {
      const blue = Color(0xFF3B82F6);
      final service = FakeSupabaseService()
        ..remoteRows = [
          _row('r-1', _todayAt(-20), name: 'Fizik', categoryId: _physicsId, colorHex: '#3B82F6', iconName: 'science'),
        ]
        ..queue = [_pending('p-1', _todayAt(1), name: 'Fizik', categoryId: _physicsId)];
      await _pumpReports(tester, service);

      final icon = tester.widget<Icon>(find.byIcon(Icons.science_outlined));
      expect(icon.color, blue);
      await _unmount(tester);
    });

    testWidgets('X5/CAT-04: yeniden adlandırılan kategorinin bekleyen seansı ayrı satır olmaz', (tester) async {
      final service = FakeSupabaseService()
        ..remoteRows = [_row('r-1', _todayAt(1), minutes: 50, name: 'Calculus')]
        ..queue = [_pending('p-1', _todayAt(2), name: 'Matematik')];
      await _pumpReports(tester, service);

      expect(find.text('Matematik'), findsNothing);
      expect(find.text('Calculus'), findsWidgets);
      expect(find.text('1sa 15dk'), findsWidgets);
      await _unmount(tester);
    });

    testWidgets('yer tutucu kimlikli bekleyen seans aynı adlı sunucu kategorisine katılır', (tester) async {
      final service = FakeSupabaseService()
        ..remoteRows = [_row('r-1', _todayAt(1))]
        ..queue = [_pending('p-1', _todayAt(2), categoryId: '1')];
      await _pumpReports(tester, service);

      expect(find.text('50dk'), findsWidgets);
      expect(find.text('Matematik'), findsNWidgets(2)); // kart + lejant
      await _unmount(tester);
    });
  });

  group('Günlük görünüm', () {
    final today = DateTime(2026, 10, 15);

    testWidgets('REP-07/X8: dağılım yüzdelerinin toplamı 100', (tester) async {
      for (final n in [3, 6]) {
        await _pumpView(
          tester,
          _daily([for (var i = 0; i < n; i++) _s(today, 25, 'Ders $i')], today, percent: true),
        );
        final percents = tester
            .widgetList<Text>(find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 12))
            .map((t) => t.data ?? '')
            .where((d) => RegExp(r'^%\d+$').hasMatch(d))
            .map((d) => int.parse(d.substring(1)))
            .toList();
        expect(percents, hasLength(n));
        expect(percents.fold<int>(0, (a, b) => a + b), 100, reason: '$n kategori: $percents');
      }
    });

    testWidgets('REP-08: ders kartlarının toplamı bugünün toplamını tutar (5 kategori)', (tester) async {
      await _pumpView(
        tester,
        _daily([
          _s(today, 50, 'A'),
          _s(today, 25, 'B'),
          _s(today, 25, 'C'),
          _s(today, 25, 'D'),
          _s(today, 25, 'E'),
        ], today, percent: true),
      );
      final cardTotal = tester
          .widgetList<Text>(find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 22))
          .map((t) => _parseDuration(t.data ?? ''))
          .fold<int>(0, (a, b) => a + b);
      expect(cardTotal, 150);
    });

    testWidgets('REP-09/X9: hedef tam tutturulunca "aştın" denmez; aşınca yüzde kırpılmaz', (tester) async {
      final exceeded = LanguageService.instance.translate('efficiency_msg_exceeded');
      await _pumpView(tester, _daily([_s(today, 200, 'A')], today));
      expect(find.text(exceeded), findsNothing);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);

      await _pumpView(tester, _daily([_s(today, 300, 'A')], today));
      expect(find.text('%150'), findsOneWidget);
      expect(find.text(exceeded), findsOneWidget);

      // Önceki dönemle kıyas yokken trend oku gösterilmez.
      await _pumpView(tester, _daily([_s(today, 95, 'A')], today));
      expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
    });

    testWidgets('REP-10: verimlilik ipucunda kaynaksız sayısal iddia yok', (tester) async {
      for (final day in [DateTime(2026, 10, 16), DateTime(2026, 10, 17), DateTime(2026, 10, 18), DateTime(2026, 10, 19)]) {
        await _pumpView(tester, _daily([_s(day, 25, 'A')], day));
        expect(find.textContaining('%15'), findsNothing, reason: '$day');
        expect(find.textContaining('15%'), findsNothing, reason: '$day');
      }
    });
  });

  group('Haftalık görünüm', () {
    testWidgets('REP-11/X13/MH-8: sıfır toplam "0dk" (0 sa değil)', (tester) async {
      await _pumpView(tester, _weekly(const [], DateTime(2026, 10, 15)));
      expect(find.text(LanguageService.instance.translate('hour_abbr')), findsNothing);
      expect(find.text(LanguageService.instance.translate('min_abbr')), findsOneWidget);
    });

    testWidgets('X10/MH-8: verimlilik etiketi geçen günlere göre; %0 "Normal" değil', (tester) async {
      final monday = DateTime(2026, 10, 12);
      await _pumpView(tester, _weekly([_s(monday, 200, 'A')], monday));
      expect(find.text(LanguageService.instance.translate('eff_very_high')), findsOneWidget);

      await _pumpView(tester, _weekly(const [], DateTime(2026, 10, 15)));
      expect(find.text(LanguageService.instance.translate('eff_normal')), findsNothing);
    });

    testWidgets('MH-5: haftalık ders analizinde bekleyen seans işaretlenir', (tester) async {
      final day = DateTime(2026, 10, 15);
      await _pumpView(tester, _weekly([_s(day, 25, 'A', pending: true), _s(day, 50, 'B')], day));
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.cloud_upload_outlined)).semanticLabel, l10n.statsPendingSessions(1));
    });
  });

  group('Aylık görünüm', () {
    testWidgets('MH-5: gün dökümünde bekleyen seans işaretlenir', (tester) async {
      final day = DateTime(2026, 10, 15);
      await _pumpView(tester, _monthly([_s(day, 25, 'A', pending: true)], day));
      final weekCard = find.byKey(ValueKey('monthly-week-${dayKeyOf(mondayOf(day))}'));
      await tester.ensureVisible(weekCard);
      await tester.tap(weekCard);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_upload_outlined), findsWidgets);
    });

    testWidgets('MH-6: tek haftalık ayda "Hafta 1" etiketi noktanın altında (ortada)', (tester) async {
      final today = DateTime(2026, 10, 3);
      await _pumpView(tester, _monthly([_s(DateTime(2026, 10, 2), 25, 'A')], today));
      final chart = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_MultiLineChartPainter',
      );
      final label = find.text(l10n.statsWeekLabel(1));
      expect(tester.getCenter(label).dx, closeTo(tester.getCenter(chart).dx, 2));
    });

    testWidgets('MH-7: 0/0 haftada rozet yok, eşit haftada nötr rozet, "Yeni" yalnız ilk çalışmada', (tester) async {
      final today = DateTime(2026, 10, 14); // Çarşamba: haftalar 1-4, 5-11, 12-14 Ekim
      await _pumpView(
        tester,
        _monthly([
          _s(DateTime(2026, 9, 29), 50, 'A'), // 5-11 Ekim'in kıyası (28 Eyl - 4 Eki): 50
          _s(DateTime(2026, 10, 6), 50, 'A'), // 5-11 Ekim: 50 → değişim yok
          _s(DateTime(2026, 10, 13), 25, 'A'), // 12-14 Ekim: 25, kıyası 5-7 Ekim: 50 → düşüş
        ], today),
      );
      final newLabel = LanguageService.instance.translate('new_week_label');
      // 1-4 Ekim: 0 dk, kıyası (24-27 Eyl) 0 dk → rozet yok.
      expect(find.text(newLabel), findsNothing);
      expect(find.byIcon(Icons.trending_flat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);

      // Önceki aynı günlerde çalışma yokken ilk çalışma: "Yeni".
      await _pumpView(tester, _monthly([_s(DateTime(2026, 10, 2), 25, 'A')], DateTime(2026, 10, 3)));
      expect(find.text(newLabel), findsOneWidget);
    });

    testWidgets('MH-9: kullanıcının "Diğer" kategorisi ile toplu seri ayrı adlarla', (tester) async {
      final today = DateTime(2026, 10, 20);
      await _pumpView(
        tester,
        _monthly([
          _s(DateTime(2026, 10, 2), 300, 'Diğer'),
          for (var i = 0; i < 6; i++) _s(DateTime(2026, 10, 3 + i), 100 - i, 'K$i'),
        ], today),
      );
      expect(find.text('Diğer'), findsOneWidget);
    });
  });

  testWidgets('X7: hedef sayfası hedefe ulaşmak için gereken pomodoroyu söyler (yukarı yuvarlar)', (tester) async {
    await _pumpView(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDailyGoalSheet(context, initialGoalMinutes: 60),
          child: const Text('aç'),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 Pomodoro'), findsOneWidget);
    expect(find.textContaining('2 Pomodoro'), findsNothing);
  });
}
