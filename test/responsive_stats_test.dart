import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/service_errors.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/widgets/stats/daily_goal_sheet.dart';
import 'package:pomodoro/widgets/stats/progress_ring.dart';
import 'package:pomodoro/widgets/stats/stats_empty_card.dart';
import 'package:pomodoro/widgets/stats/stats_layout.dart';
import 'package:pomodoro/widgets/stats/stats_load_state.dart';

// İstatistik ekranları ve parçaları, telefon (dikey/yatay) ve tablet
// boyutlarında, büyütülmüş yazıyla da taşmadan (RenderFlex overflow vb.)
// çizilmeli. Ekranlar veriyi parametreyle aldığı için Supabase gerekmez.

const _sizes = <String, Size>{
  'telefon dikey 390x844': Size(390, 844),
  'telefon yatay 844x390': Size(844, 390),
  'küçük telefon yatay 568x320': Size(568, 320),
  'küçük telefon dikey 320x568': Size(320, 568),
  'iPad Slide Over 320x1000': Size(320, 1000),
  'iPad Split View 507x1024': Size(507, 1024),
  'iPad dikey 820x1180': Size(820, 1180),
  'iPad yatay 1180x820': Size(1180, 820),
  'büyük tablet 1366x1024': Size(1366, 1024),
};

const _textScales = [1.0, 1.5];

// Yan gezinme çubuğu (NavigationRail) olan düzende sekmeye kalan genişliği
// de denemek için.
const double _railWidth = 80;

final _today = DateTime(2026, 10, 15);
final _categories = CourseCategory.initialCategories();

List<StatSession> _sampleSessions() {
  final monday = mondayOf(_today);
  StatSession s(DateTime day, int minutes, String name, {String? id, bool pending = false}) =>
      StatSession(day: day, minutes: minutes, categoryName: name, categoryId: id, pending: pending);
  final math = _categories[0];
  final physics = _categories[1];
  return [
    // Bugün: birden çok ders, bekleyen seans, adı çözülemeyen ve uzun adlı kategori.
    s(_today, 75, math.name, id: math.id),
    s(_today, 50, physics.name, id: physics.id),
    s(_today, 25, physics.name, id: physics.id, pending: true),
    s(_today, 30, 'Diğer'),
    s(_today, 45, 'Çok Uzun Adlı Bir Ders Kategorisi Örneği'),
    // Bu hafta
    s(monday, 125, math.name, id: math.id),
    s(addDays(monday, 1), 600, physics.name, id: physics.id),
    // Bu ay ve önceki ay (kıyaslar, büyüme mesajı)
    s(DateTime(2026, 10, 2), 100, math.name, id: math.id),
    s(DateTime(2026, 10, 7), 50, 'Kimya'),
    s(DateTime(2026, 9, 3), 40, math.name, id: math.id),
    s(DateTime(2026, 9, 9), 25, physics.name, id: physics.id),
    s(DateTime(2026, 9, 30), 25, 'Biyoloji'),
  ];
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {
  double textScale = 1,
  bool withRail = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: SafeArea(
        child: withRail
            ? Row(children: [const SizedBox(width: _railWidth), Expanded(child: child)])
            : child,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _noop() async {}

Widget _daily({List<StatSession>? sessions, bool hasHistory = true}) => DailyReportView(
      sessions: sessions ?? _sampleSessions(),
      today: _today,
      dailyGoalMinutes: 240,
      hasHistory: hasHistory,
      categories: _categories,
      onRefresh: _noop,
      showDistributionPercent: false,
      onDistributionModeChanged: (_) {},
      onShowDetails: () {},
      onStartTimer: () {},
    );

Widget _weekly({List<StatSession>? sessions}) => HistoryScreen(
      sessions: sessions ?? _sampleSessions(),
      today: _today,
      dailyGoalMinutes: 240,
      categories: _categories,
      onRefresh: _noop,
      onStartTimer: () {},
    );

Widget _monthly({List<StatSession>? sessions}) => MonthlyTrackingScreen(
      sessions: sessions ?? _sampleSessions(),
      today: _today,
      categories: _categories,
      onRefresh: _noop,
    );

// Bottom sheet'in görünen yüzeyi (BottomSheet, genişlik sınırını dıştaki
// hizalama kutusuyla uygular).
Size _sheetSize(WidgetTester tester) => tester.getSize(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first,
    );

Widget _parts() => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          StatsStaleBanner(onRetry: () {}),
          const SizedBox(height: 16),
          StatsEmptyCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Bugün henüz çalışmadın',
            description: 'Bir pomodoro başlat; çalışmaların burada ders ders görünsün.',
            actionLabel: 'Hemen Çalışmaya Başla',
            onAction: () {},
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: ProgressRingPainter(
                progress: 0.6,
                trackColor: Colors.black12,
                progressColor: Colors.red,
                strokeWidth: 6,
              ),
            ),
          ),
        ],
      ),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  final views = <String, Widget Function()>{
    'Günlük (veri var)': () => _daily(),
    'Günlük (bugün boş)': () => _daily(sessions: _sampleSessions().where((s) => !isSameDay(s.day, _today)).toList()),
    'Günlük (ilk kullanım)': () => _daily(sessions: const [], hasHistory: false),
    'Haftalık (veri var)': () => _weekly(),
    'Haftalık (boş)': () => _weekly(sessions: const []),
    'Aylık (veri var)': () => _monthly(),
    'Aylık (boş)': () => _monthly(sessions: const []),
    'Hata durumu': () => StatsErrorView(code: ServiceErrorCode.network, onRetry: () {}),
    'Parçalar (uyarı, boş kart, halka)': _parts,
  };

  for (final size in _sizes.entries) {
    for (final scale in _textScales) {
      group('${size.key}, yazı ×$scale', () {
        for (final view in views.entries) {
          testWidgets('${view.key} taşmaz', (tester) async {
            await _pumpAt(tester, size.value, view.value(), textScale: scale);
            expect(tester.takeException(), isNull);
          });
        }
      });
    }

    // Yatay telefon ve tablette kabuk yan gezinme çubuğu gösterir; sekmeye
    // kalan dar genişlik de taşmamalı.
    if (size.value.width >= 568) {
      group('${size.key}, yan gezinmeyle', () {
        for (final view in views.entries) {
          testWidgets('${view.key} taşmaz', (tester) async {
            await _pumpAt(tester, size.value, view.value(), withRail: true);
            expect(tester.takeException(), isNull);
          });
        }
      });
    }
  }

  group('Dikey telefonda en büyük yazı', () {
    // 320 pt: iPhone SE (1. nesil) ve iPad Slide Over.
    for (final size in const [Size(390, 844), Size(320, 568), Size(320, 1000)]) {
      for (final view in views.entries) {
        testWidgets('${view.key} $size ×2 taşmaz', (tester) async {
          await _pumpAt(tester, size, view.value(), textScale: 2);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Günlük hedef sayfası', () {
    final title = LanguageService.instance.translate('set_daily_goal_title');
    for (final size in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('${size.key}, yazı ×$scale: taşmaz, en çok 640 px', (tester) async {
          await _pumpAt(
            tester,
            size.value,
            Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showDailyGoalSheet(context, initialGoalMinutes: 120),
                  child: const Text('aç'),
                ),
              ),
            ),
            textScale: scale,
          );
          await tester.tap(find.text('aç'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(title), findsOneWidget);
          expect(_sheetSize(tester).width, lessThanOrEqualTo(kStatsSheetMaxWidth));

          // Kaydırılabilir içerikte kaydet düğmesine ulaşılabilir.
          final save = find.text(LanguageService.instance.translate('save_goal_btn'));
          await tester.ensureVisible(save);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Hafta dökümü sayfası', () {
    for (final size in _sizes.entries) {
      testWidgets('${size.key}: taşmaz, en çok 640 px', (tester) async {
        await _pumpAt(tester, size.value, _monthly());
        final card = find.byKey(ValueKey('monthly-week-${dayKeyOf(mondayOf(_today))}'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(LanguageService.instance.translate('week_day_breakdown_title')), findsOneWidget);
        expect(_sheetSize(tester).width, lessThanOrEqualTo(kStatsSheetMaxWidth));
      });
    }
  });

  group('Düzen kararları', () {
    testWidgets('dikey telefonda aylık kartlar alt alta, tablette yan yana', (tester) async {
      final heatmapTitle = find.textContaining(LanguageService.instance.translate('month_intensity_suffix'));
      final chartTitle = find.text(LanguageService.instance.translate('topic_comparison_title'));

      await _pumpAt(tester, const Size(390, 844), _monthly());
      expect(tester.getTopLeft(chartTitle).dy, greaterThan(tester.getBottomLeft(heatmapTitle).dy));

      await _pumpAt(tester, const Size(1180, 820), _monthly());
      expect(tester.getTopLeft(chartTitle).dy, tester.getTopLeft(heatmapTitle).dy);
      expect(tester.getTopLeft(chartTitle).dx, greaterThan(tester.getTopRight(heatmapTitle).dx));
    });

    testWidgets('dağılım lejantı 320 pt ekranda halkanın altında, telefonda yanında', (tester) async {
      final donut = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_DonutChartPainter',
      );
      final card = find.ancestor(of: donut, matching: find.byWidgetPredicate((w) => w is Semantics && w.excludeSemantics));
      Rect legendValue() => tester.getRect(find.descendant(of: card, matching: find.byType(Text)).last);

      await _pumpAt(tester, const Size(320, 568), _daily());
      expect(tester.takeException(), isNull);
      expect(legendValue().top, greaterThanOrEqualTo(tester.getRect(donut).bottom));

      await _pumpAt(tester, const Size(390, 844), _daily());
      expect(legendValue().left, greaterThanOrEqualTo(tester.getRect(donut).right));
    });

    testWidgets('haftalık toplam ve en verimli gün kartları 320 pt ekranda alt alta, telefonda yan yana', (tester) async {
      final total = find.text(LanguageService.instance.translate('total_focus_label'));
      final best = find.text(LanguageService.instance.translate('most_efficient_day_label'));

      await _pumpAt(tester, const Size(320, 568), _weekly());
      await tester.ensureVisible(best);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(best).dy, greaterThan(tester.getBottomLeft(total).dy));
      expect(tester.getTopLeft(best).dx, tester.getTopLeft(total).dx);

      await _pumpAt(tester, const Size(390, 844), _weekly());
      await tester.ensureVisible(best);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(best).dy, tester.getTopLeft(total).dy);
      expect(tester.getTopLeft(best).dx, greaterThan(tester.getTopRight(total).dx));
    });

    testWidgets('geniş ekranda içerik pano genişliğinde ortalanır', (tester) async {
      await _pumpAt(tester, const Size(1366, 1024), _daily());
      final goal = find.text(LanguageService.instance.translate('daily_goal_label'));
      final tip = find.text(LanguageService.instance.translate('efficiency_tip_header'));
      // Özet satırı: hedef, verimlilik ve ipucu aynı ızgara satırında.
      final summary = tester.getRect(find.byType(StatsGrid).first);
      expect(summary.contains(tester.getCenter(goal)), isTrue);
      expect(summary.contains(tester.getCenter(tip)), isTrue);
      // İçerik 1080 px'lik pano genişliğinde ortalanır (kenar boşlukları eşit).
      final scroll = tester.getRect(find.byType(SingleChildScrollView).first);
      final column = summary;
      expect(column.width, lessThanOrEqualTo(1080 - 2 * kStatsHorizontalPadding));
      expect(column.left - scroll.left, closeTo(scroll.right - column.right, 1));
    });

    testWidgets('haftalık liste okuma genişliğinde kalır', (tester) async {
      await _pumpAt(tester, const Size(1366, 1024), _weekly());
      final caption = find.text(LanguageService.instance.translate('weekly_trend_caption'));
      final left = tester.getTopLeft(caption).dx;
      // 720 px'lik okuma sütunu ortada: sol kenar (1366 - 720) / 2 + 24 + 20.
      expect(left, closeTo((1366 - 720) / 2 + kStatsHorizontalPadding + 20, 1));
    });
  });
}
