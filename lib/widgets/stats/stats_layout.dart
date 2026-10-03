import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../utils/responsive.dart';

/// Rapor sekmelerinin yatay kenar boşluğu (telefonda bugünkü değer).
const double kStatsHorizontalPadding = 24;

/// İstatistik sayfalarının (bottom sheet) geniş ekrandaki en büyük genişliği;
/// tablette tam genişliğe yayılmazlar.
const double kStatsSheetMaxWidth = 640;

/// Rapor sekmelerinin ortak düzen kararları.
///
/// Sütun sayısı pencerenin değil sekmeye kalan genişliğin (yan gezinme
/// çubuğu ve güvenli alan düşülmüş, [ContentWidth] ile sınırlanmış) sınıfına
/// göre verilir; yükseklik kararları (yatay telefon) pencereden gelir.
@immutable
class StatsLayout {
  const StatsLayout._(this.responsive, this.contentWidth, this._window);

  /// [availableWidth]: sekmenin LayoutBuilder genişliği. [maxContentWidth]:
  /// içeriğin geniş ekrandaki üst sınırı ([ContentWidth.dashboard] ya da
  /// [ContentWidth.reading]).
  factory StatsLayout.of(
    BuildContext context,
    double availableWidth, {
    double maxContentWidth = ContentWidth.dashboard,
  }) {
    final window = Responsive.of(context);
    final width = math.min(availableWidth, maxContentWidth);
    return StatsLayout._(
      Responsive.fromSize(Size(width, window.height)),
      math.max(0, width - 2 * kStatsHorizontalPadding),
      window,
    );
  }

  /// İçerik alanının sınıfı (genişlik: içerik alanı, yükseklik: pencere).
  final Responsive responsive;

  /// Kenar boşlukları düşülmüş, kartların yerleştiği genişlik.
  final double contentWidth;

  final Responsive _window;

  bool get isWide => responsive.isMediumOrWider;
  bool get isExpanded => responsive.isExpanded;

  /// Yatay telefon gibi dikey alanı kıt pencere.
  bool get isShortHeight => _window.isShortHeight;

  int columns({int compact = 1, int medium = 2, int expanded = 3}) =>
      responsive.columns(compact: compact, medium: medium, expanded: expanded);

  /// Grafik yüksekliği: dikey telefonda [base] (bugünkü değer), yatay
  /// telefonda kısa ama okunur, tablette daha yüksek.
  double chartHeight(double base) {
    if (isShortHeight) return base * 0.75;
    if (_window.isMediumOrWider && _window.height >= 700) return base * 1.25;
    return base;
  }

  /// Kaydırılan içeriğin üst/alt boşluğu.
  double get verticalPadding => isShortHeight ? 12 : 16;

  /// Sayfa sonundaki boşluk. Alt gezinme çubuğu olan dikey telefonda
  /// bugünkü değer korunur; yan gezinmede gereksiz boşluk bırakılmaz.
  double bottomSpacing(double phoneValue) => _window.useSideNavigation ? 24 : phoneValue;
}

/// Rapor sekmesinin kaydırılan gövdesi. Kaydırma tüm genişlikte çalışır;
/// içerik geniş ekranda [maxWidth] ile ortalanır, kenar boşluğu telefondaki
/// gibi [kStatsHorizontalPadding] kalır. Yatay telefonda da tüm içerik
/// kaydırılabilir.
class StatsScrollView extends StatelessWidget {
  const StatsScrollView({
    super.key,
    required this.layout,
    required this.maxWidth,
    required this.children,
  });

  final StatsLayout layout;
  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.symmetric(vertical: layout.verticalPadding),
      child: ContentWidth(
        maxWidth: maxWidth,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kStatsHorizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartları [columns] sütunlu satırlara dizer; bir satırdaki kartlar aynı
/// yüksekliğe uzar ve metin büyütüldüğünde birlikte büyür (taşma olmaz).
/// Son satırdaki boş hücreler yer tutar, böylece kart genişlikleri eşit
/// kalır. Tek sütunda düz bir dikey listedir.
///
/// Satırlar [IntrinsicHeight] ile ölçüldüğü için hücrelerde LayoutBuilder,
/// GridView ya da ListView kullanılmamalıdır.
class StatsGrid extends StatelessWidget {
  const StatsGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final int columns;
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final perRow = math.max(1, columns);
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += perRow) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
      if (perRow == 1) {
        rows.add(children[start]);
        continue;
      }
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < perRow; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(
                child: start + i < children.length ? children[start + i] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// [columns] sütunlu ızgarada bir hücrenin genişliği.
double statsCellWidth(double totalWidth, int columns, double spacing) {
  final perRow = math.max(1, columns);
  return math.max(0, (totalWidth - spacing * (perRow - 1)) / perRow);
}
