// Raporlar ekranının (Günlük / Haftalık / Aylık) her metriğini sabit bir
// veri setiyle uçtan uca doğrular. Veri, ReportsScreen'in kullandığı yoldan
// geçer: sunucu satırı (JSON, UTC) → StudySession → çalışma günü (profil
// diliminde 04:00) → kuyruktaki seanslar (overlap ve kopya ayıklanır) →
// mergeStatSessions → ekranlar. Bulunan hatalardan bağımsız olarak doğru
// davranışı da kilitler.
//
// Veri seti (İstanbul saati, UTC+3; profil dilimi Europe/Istanbul):
//   Kategoriler: Matematik (aktif, kırmızı), Fizik (aktif, mavi),
//                Kimya (ARŞİVLENMİŞ, yeşil; aktif listede yok)
//   10 Eyl 10:00  Mat 50
//   30 Eyl 23:40  Kim 25   (1 Eki 00:05'te biter → yine 30 Eylül)
//    1 Eki 20:00  Mat 50 + 21:00 Mat 25
//    6 Eki        Mat 5 × 50
//   11 Eki 15:00  Mat 50   (Pazar: önceki hafta)
//   12 Eki 10:00  Fiz 50 + 11:00 Fiz 50
//   14 Eki 03:55  Mat 25   (04:00'ten önce → 13 Ekim)
//   14 Eki 09:00  Mat 50
//   14 Eki 23:50  Fiz 25   (gece yarısını geçer → 14 Ekim)
//   15 Eki 03:30  Kim 25   (04:00'ten önce → 14 Ekim; arşivlenmiş kategori)
//   Kuyruk: 14 Eki 12:00 Mat 25 (bekliyor), 14 Eki 09:10 Fiz 25 (overlap →
//           sayılmaz), 14 Eki 09:00 Mat 50 (sunucuya ulaşmış kopya → sayılmaz)
//   Bugün: Çarşamba 14 Ekim 2026. Günlük hedef 200 dk.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/stats_format.dart';
import 'package:pomodoro/utils/study_day.dart';

import 'support/fake_supabase_service.dart';

const _math = 'aaaaaaaa-0000-4000-8000-000000000001';
const _physics = 'aaaaaaaa-0000-4000-8000-000000000002';
const _chem = 'aaaaaaaa-0000-4000-8000-000000000003';

const _red = Color(0xFFEF4444);
const _blue = Color(0xFF3B82F6);
const _green = Color(0xFF10B981);

final _today = DateTime(2026, 10, 14);
const _goal = 200;

/// İstanbul saatini (UTC+3, yaz saati yok) UTC'ye çevirir.
DateTime _ist(int month, int day, int hour, [int minute = 0]) => DateTime.utc(2026, month, day, hour - 3, minute);

// Aktif kategoriler (Kimya arşivlendiği için kabuk onu vermez).
final _active = [
  CourseCategory.fromServerRow({'id': _math, 'name': 'Matematik', 'color_hex': '#EF4444', 'icon_name': 'calculate'}),
  CourseCategory.fromServerRow({'id': _physics, 'name': 'Fizik', 'color_hex': '#3B82F6', 'icon_name': 'science'}),
];

var _rowId = 0;
Map<String, dynamic> _row(String categoryId, DateTime startedUtc, int minutes, {String? uuid}) {
  final (name, hex, icon) = switch (categoryId) {
    _math => ('Matematik', '#EF4444', 'calculate'),
    _physics => ('Fizik', '#3B82F6', 'science'),
    _ => ('Kimya', '#10B981', 'biotech'),
  };
  _rowId++;
  return {
    'id': 'r$_rowId',
    'user_id': 'u',
    'category': name,
    'category_id': categoryId,
    'duration_minutes': minutes,
    'started_at': startedUtc.toIso8601String(),
    'completed_at': startedUtc.add(Duration(minutes: minutes)).toIso8601String(),
    'client_uuid': uuid ?? 'c$_rowId',
    'categories': {'name': name, 'color_hex': hex, 'icon_name': icon},
  };
}

List<Map<String, dynamic>> _remoteRows() => [
      _row(_math, _ist(9, 10, 10), 50),
      _row(_chem, _ist(9, 30, 23, 40), 25),
      _row(_math, _ist(10, 1, 20), 50),
      _row(_math, _ist(10, 1, 21), 25),
      for (var h = 9; h <= 13; h++) _row(_math, _ist(10, 6, h), 50),
      _row(_math, _ist(10, 11, 15), 50),
      _row(_physics, _ist(10, 12, 10), 50),
      _row(_physics, _ist(10, 12, 11), 50),
      _row(_math, _ist(10, 14, 3, 55), 25),
      _row(_math, _ist(10, 14, 9), 50, uuid: 'delivered'),
      _row(_physics, _ist(10, 14, 23, 50), 25),
      _row(_chem, _ist(10, 15, 3, 30), 25),
    ];

PendingSession _queued(String uuid, String categoryId, String name, DateTime startedUtc, int minutes, {String? lastError}) =>
    PendingSession(
      clientUuid: uuid,
      categoryId: categoryId,
      categoryName: name,
      minutes: minutes,
      wasPaused: false,
      foregroundSeconds: minutes * 60,
      startedAt: startedUtc,
      queuedAt: startedUtc.add(Duration(minutes: minutes)),
      clockOffsetMs: 0,
      lastError: lastError,
    );

List<PendingSession> _queue() => [
      _queued('p-1', _math, 'Matematik', _ist(10, 14, 12), 25),
      _queued('p-overlap', _physics, 'Fizik', _ist(10, 14, 9, 10), 25, lastError: SessionReason.overlap),
      _queued('delivered', _math, 'Matematik', _ist(10, 14, 9), 50, lastError: SessionReason.timeout),
    ];

/// ReportsScreen'in yaptığı birleştirmenin aynısı.
List<StatSession> _sessions() => mergeStatSessions(
      remote: _remoteRows().map(StudySession.fromJson).map(StatSession.fromStudySession).toList(),
      pending: pendingStatSessions(_queue()),
      categories: _active,
    );

late AppLocalizations l10n;
final _lang = LanguageService.instance;
String _d(int minutes) => formatStudyMinutes(minutes, hourAbbr: 'sa', minAbbr: 'dk');

Finder _semantics(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

/// [text]'i içeren satırda (Row) [value] metni var mı?
Finder _inSameRow(String text, String value) => find.descendant(
      of: find.ancestor(of: find.text(text), matching: find.byType(Row)).first,
      matching: find.text(value),
    );

Future<void> _noop() async {}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(420, 3200);
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

Widget _daily({bool percent = false}) => DailyReportView(
      sessions: _sessions(),
      today: _today,
      dailyGoalMinutes: _goal,
      hasHistory: true,
      categories: _active,
      onRefresh: _noop,
      showDistributionPercent: percent,
      onDistributionModeChanged: (_) {},
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() {
    setStudyTimeZone('Europe/Istanbul');
    _lang.setLanguage(AppLanguage.tr);
  });
  tearDown(() => setStudyTimeZone(null));

  group('Veri hattı', () {
    test('seanslar 04:00 kuralıyla başlangıç gününe atanır', () {
      final days = {
        for (final s in _remoteRows().map(StudySession.fromJson)) s.startedAt!.toUtc(): s.studyDay,
      };
      expect(days[_ist(9, 30, 23, 40)], DateTime(2026, 9, 30), reason: 'gece yarısını geçen seans başladığı güne');
      expect(days[_ist(10, 14, 3, 55)], DateTime(2026, 10, 13), reason: '04:00 öncesi önceki güne');
      expect(days[_ist(10, 14, 23, 50)], DateTime(2026, 10, 14));
      expect(days[_ist(10, 15, 3, 30)], DateTime(2026, 10, 14));
    });

    test('overlap ve sunucuya ulaşmış kopya sayılmaz; bekleyen tek seans sayılır', () {
      final s = _sessions();
      expect(s.where((x) => x.pending).map((x) => x.clientUuid), ['p-1']);
      expect(sumMinutes(s), 50 + 25 + 75 + 250 + 50 + 100 + 25 + 50 + 25 + 25 + 25);
    });

    test('arşivlenmiş kategori adı, rengi ve ikonu sunucu birleşiminden gelir', () {
      final chem = totalsByCategory(sessionsBetween(_sessions(), _today, _today)).firstWhere((c) => c.name == 'Kimya');
      expect(chem.categoryId, _chem);
      expect(chem.colorHex, '#10B981');
      expect(chem.iconName, 'biotech');
    });
  });

  group('Günlük', () {
    testWidgets('hedef kartı: süre, pomodoro, bekleyen', (tester) async {
      await _pump(tester, _daily());
      expect(find.text('${_d(125)} / ${_d(_goal)}'), findsOneWidget);
      expect(_semantics(l10n.statsTodayPomodoros(5)), findsOneWidget);
      expect(find.text(l10n.statsPendingSessions(1)), findsOneWidget);
    });

    testWidgets('verimlilik: %62, "yaklaşıyorsun", trend oku yok', (tester) async {
      await _pump(tester, _daily());
      expect(find.text('%62'), findsOneWidget);
      expect(find.text(_lang.translate('efficiency_msg_close')), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
      expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
    });

    testWidgets('ders kartları: sıra, süre, renk, ikon, bekleyen işareti', (tester) async {
      await _pump(tester, _daily());
      final durations = tester
          .widgetList<Text>(find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 22 && w.style?.fontWeight == FontWeight.w600))
          .map((t) => t.data)
          .toList();
      expect(durations, [_d(75), _d(25), _d(25)]);
      // Eşit sürede ada göre: Fizik, Kimya.
      // 2 sütunlu ızgara: Matematik | Fizik, altında Kimya.
      Offset at(String n) => tester.getTopLeft(find.text(n).first);
      expect(at('Matematik').dy, at('Fizik').dy);
      expect(at('Matematik').dx, lessThan(at('Fizik').dx));
      expect(at('Kimya').dy, greaterThan(at('Matematik').dy));

      Icon iconOf(IconData data) => tester.widget<Icon>(find.byIcon(data));
      expect(iconOf(Icons.calculate_outlined).color, _red);
      expect(iconOf(Icons.science_outlined).color, _blue);
      expect(iconOf(Icons.biotech_outlined).color, _green, reason: 'arşivlenmiş kategori rengini korur');
      // Bekleyen işareti: hedef kartında ve Matematik kartında (Fizik/Kimya'da yok).
      final clouds = tester.widgetList<Icon>(find.byIcon(Icons.cloud_upload_outlined)).toList();
      expect(clouds, hasLength(2));
      expect(clouds.where((i) => i.semanticLabel == l10n.statsPendingSessions(1)), hasLength(1));
    });

    testWidgets('dağılım: toplam ve süreler; yüzdeler 60/20/20', (tester) async {
      await _pump(tester, _daily());
      expect(find.text(_d(125)), findsOneWidget, reason: 'halkanın ortasındaki toplam');
      // Lejant satırları (ad + süre); ad kartta da geçtiği için sonuncusu.
      Finder legend(String name, String value) => find.descendant(
            of: find.ancestor(of: find.text(name).last, matching: find.byType(Row)).first,
            matching: find.text(value),
          );
      expect(legend('Matematik', _d(75)), findsOneWidget);
      expect(legend('Fizik', _d(25)), findsOneWidget);
      expect(legend('Kimya', _d(25)), findsOneWidget);

      await _pump(tester, _daily(percent: true));
      final percents = tester
          .widgetList<Text>(find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 12))
          .map((t) => t.data ?? '')
          .where((d) => RegExp(r'^%\d+$').hasMatch(d))
          .toList();
      expect(percents, ['%60', '%20', '%20']);
    });
  });

  group('Haftalık (12-18 Ekim)', () {
    Widget weekly() => HistoryScreen(
          sessions: _sessions(),
          today: _today,
          dailyGoalMinutes: _goal,
          categories: _active,
          onRefresh: _noop,
        );

    testWidgets('trend: her gün doğru süre, bugün seçili', (tester) async {
      await _pump(tester, weekly());
      final none = _lang.translate('no_study_this_day');
      expect(_semantics('Pazartesi, 12 Ekim: ${_d(100)}'), findsOneWidget);
      expect(_semantics('Salı, 13 Ekim: ${_d(25)}'), findsOneWidget);
      expect(_semantics('Çarşamba, 14 Ekim: ${_d(125)}'), findsOneWidget);
      expect(_semantics('Perşembe, 15 Ekim: $none'), findsOneWidget);
      expect(_semantics('Pazar, 18 Ekim: $none'), findsOneWidget);
      expect(find.text('14 Eki'), findsOneWidget);
    });

    testWidgets('verimlilik %17 (haftalık hedef), etiket geçen 3 güne göre', (tester) async {
      await _pump(tester, weekly());
      expect(find.text('%17'), findsOneWidget); // 250 / 1400
      // 250 / (200 × 3) = %41 → 'Normal'
      expect(find.text(_lang.translate('eff_normal')), findsOneWidget);
      expect(find.text(l10n.statsWeeklyGoalSubtitle(_d(_goal * 7))), findsOneWidget);
    });

    testWidgets('toplam odak 4sa 10dk, en verimli gün Çarşamba', (tester) async {
      await _pump(tester, weekly());
      final total = _lang.translate('total_focus_label').replaceAll('\n', ' ');
      expect(_semantics('$total: ${_d(250)}'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Çarşamba'), findsOneWidget);
    });

    testWidgets('ders analizi: Fizik 2sa 5dk, Matematik 1sa 40dk (bekleyen), Kimya 25dk', (tester) async {
      await _pump(tester, weekly());
      expect(_inSameRow('Fizik', _d(125)), findsOneWidget);
      expect(_inSameRow('Matematik', _d(100)), findsOneWidget);
      expect(_inSameRow('Kimya', _d(25)), findsOneWidget);
      final ys = [for (final n in ['Fizik', 'Matematik', 'Kimya']) tester.getTopLeft(find.text(n)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.descendant(of: find.ancestor(of: find.text('Matematik'), matching: find.byType(Row)).first, matching: find.byIcon(Icons.cloud_upload_outlined)), findsOneWidget);
    });
  });

  group('Aylık (Ekim)', () {
    Widget monthly() => MonthlyTrackingScreen(
          sessions: _sessions(),
          today: _today,
          categories: _active,
          onRefresh: _noop,
        );

    testWidgets('ısı haritası günleri', (tester) async {
      await _pump(tester, monthly());
      final none = _lang.translate('no_study_this_day');
      expect(_semantics('1 Ekim: ${_d(75)}'), findsOneWidget);
      expect(_semantics('2 Ekim: $none'), findsOneWidget);
      expect(_semantics('6 Ekim: ${_d(250)}'), findsOneWidget);
      expect(_semantics('11 Ekim: ${_d(50)}'), findsOneWidget);
      expect(_semantics('13 Ekim: ${_d(25)}'), findsOneWidget);
      expect(_semantics('14 Ekim: ${_d(125)}'), findsOneWidget);
      expect(_semantics('31 Ekim: $none'), findsOneWidget);
    });

    testWidgets('konu karşılaştırması: haftalık seriler', (tester) async {
      await _pump(tester, monthly());
      String w(int i, int m) => '${l10n.statsWeekLabel(i)} ${_d(m)}';
      final summary = [
        'Matematik: ${[w(1, 75), w(2, 300), w(3, 100)].join(', ')}',
        'Fizik: ${[w(1, 0), w(2, 0), w(3, 125)].join(', ')}',
        'Kimya: ${[w(1, 0), w(2, 0), w(3, 25)].join(', ')}',
      ].join('; ');
      expect(_semantics(summary), findsOneWidget);
    });

    testWidgets('haftalık özet kartları ve rozetler', (tester) async {
      await _pump(tester, monthly());
      expect(find.text(l10n.statsWeekStudyTotal(_d(250))), findsOneWidget); // 12-14 Ekim
      expect(find.text(l10n.statsWeekStudyTotal(_d(300))), findsOneWidget); // 5-11 Ekim
      expect(find.text(l10n.statsWeekStudyTotal(_d(75))), findsOneWidget); // 1-4 Ekim
      expect(_semantics(l10n.statsWeekChangeSame), findsOneWidget); // 250 / 250
      expect(_semantics(l10n.statsWeekChangeUp('%200')), findsOneWidget); // 300 / 100 (30 Eyl + 1 Eki)
      expect(find.text(_lang.translate('new_week_label')), findsOneWidget); // 75 / 0
      // Ay başından bugüne 625 dk, Eylül'ün aynı dönemi 50 dk.
      expect(find.text(l10n.statsMonthMotivation(formatPercent(1150, 'tr'))), findsOneWidget);
    });

    testWidgets('hafta dökümü: yalnız bugüne kadarki günler, kategoriler ve bekleyen', (tester) async {
      await _pump(tester, monthly());
      final weekCard = find.byKey(ValueKey('monthly-week-${dayKeyOf(mondayOf(_today))}'));
      await tester.ensureVisible(weekCard);
      await tester.tap(weekCard); // en yeni hafta (12-14 Ekim)
      await tester.pumpAndSettle();
      expect(find.text('12 Ekim, Pazartesi'), findsOneWidget);
      expect(find.text('14 Ekim, Çarşamba'), findsOneWidget);
      expect(find.text('15 Ekim, Perşembe'), findsNothing);
      expect(find.text('Fizik • ${_d(100)}'), findsOneWidget);
      expect(find.text('Matematik • ${_d(25)}'), findsOneWidget);
      expect(find.text('Matematik • ${_d(75)}'), findsOneWidget);
      expect(find.text('Fizik • ${_d(25)}'), findsOneWidget);
      expect(find.text('Kimya • ${_d(25)}'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });
  });

  group('Farklı saat dilimi', () {
    test('gün sınırı profil dilimindeki 04:00 (cihazın değil)', () {
      // 14 Eki 03:30Z = İstanbul 06:30 (14 Ekim) = New York 23:30 (13 Ekim)
      // 14 Eki 07:30Z = İstanbul 10:30 (14 Ekim) = New York 03:30 (04:00 öncesi → 13 Ekim)
      final rows = [
        _row(_math, DateTime.utc(2026, 10, 14, 3, 30), 25),
        _row(_math, DateTime.utc(2026, 10, 14, 7, 30), 25),
      ];
      List<DateTime> days() => [for (final r in rows) StatSession.fromStudySession(StudySession.fromJson(r)).day];

      setStudyTimeZone('Europe/Istanbul');
      expect(days(), [DateTime(2026, 10, 14), DateTime(2026, 10, 14)]);
      setStudyTimeZone('America/New_York');
      expect(days(), [DateTime(2026, 10, 13), DateTime(2026, 10, 13)]);
    });

    testWidgets('New York profilinde günlük toplam o dilimin gününe göre', (tester) async {
      setStudyTimeZone('America/New_York');
      final sessions = [
        StatSession.fromStudySession(StudySession.fromJson(_row(_math, DateTime.utc(2026, 10, 14, 7, 30), 25))),
        StatSession.fromStudySession(StudySession.fromJson(_row(_math, DateTime.utc(2026, 10, 14, 15), 50))),
      ];
      await _pump(
        tester,
        DailyReportView(
          sessions: sessions,
          today: DateTime(2026, 10, 14),
          dailyGoalMinutes: _goal,
          hasHistory: true,
          categories: _active,
          onRefresh: _noop,
          showDistributionPercent: false,
          onDistributionModeChanged: (_) {},
        ),
      );
      expect(find.text('${_d(50)} / ${_d(_goal)}'), findsOneWidget);
    });
  });

  testWidgets('Raporlar: üç sekme aynı birleşik veriyi gösterir', (tester) async {
    // ReportsScreen gerçek 'bugün'ü kullanır: bugüne ait bir sunucu seansı,
    // bir bekleyen seans, bir overlap ve sunucuya ulaşmış bir kopya.
    final today = studyDayOf(DateTime.now());
    final start = studyDayStart(today).toUtc();
    final service = FakeSupabaseService()
      ..remoteRows = [_row(_math, start.add(const Duration(hours: 1)), 50, uuid: 'a')]
      ..queue = [
        _queued('a', _math, 'Matematik', start.add(const Duration(hours: 1)), 50, lastError: SessionReason.timeout),
        _queued('b', _physics, 'Fizik', start.add(const Duration(hours: 2)), 25),
        _queued('c', _physics, 'Fizik', start.add(const Duration(hours: 1, minutes: 10)), 25,
            lastError: SessionReason.overlap),
      ];
    // Sekme çubuğu sığsın diye geniş görünüm.
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReportsScreen(categories: _active, service: service),
    ));
    await tester.pumpAndSettle();

    expect(find.text('${_d(75)} / ${_d(_goal)}'), findsOneWidget);
    expect(find.text(l10n.statsPendingSessions(1)), findsOneWidget);

    await tester.tap(find.text(_lang.translate('reports_tab_history')));
    await tester.pumpAndSettle();
    final total = _lang.translate('total_focus_label').replaceAll('\n', ' ');
    expect(_semantics('$total: ${_d(75)}'), findsOneWidget);

    await tester.tap(find.text(_lang.translate('reports_tab_monthly')));
    await tester.pumpAndSettle();
    expect(_semantics('${DateFormat('d MMMM', 'tr_TR').format(today)}: ${_d(75)}'), findsOneWidget);

    // Gün dönümü zamanlayıcısı iptal edilsin.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
