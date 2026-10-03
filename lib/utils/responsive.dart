import 'package:flutter/widgets.dart';

/// Pencere genişlik sınıfları (Material 3 eşikleri): telefon dikey compact,
/// büyük telefon yatay ve tablet dikey medium, tablet yatay expanded.
enum ScreenClass { compact, medium, expanded }

/// Ekranın genişlik sınıfı ve yönü. Tüm ekranlar düzen kararını buradan
/// verir; böylece telefon, yatay telefon ve tablet aynı kurallarla ölçeklenir.
@immutable
class Responsive {
  const Responsive._(this.screenClass, this.width, this.height);

  /// Saf hesap; widget testlerinde boyut vererek de kullanılabilir.
  factory Responsive.fromSize(Size size) {
    final w = size.width;
    final screenClass = w >= expandedMinWidth
        ? ScreenClass.expanded
        : w >= mediumMinWidth
            ? ScreenClass.medium
            : ScreenClass.compact;
    return Responsive._(screenClass, w, size.height);
  }

  factory Responsive.of(BuildContext context) =>
      Responsive.fromSize(MediaQuery.sizeOf(context));

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;

  /// Yatay telefonda kullanılabilir yükseklik bu değerin altına düşer;
  /// dikey yığılmış düzenler ya kaydırılmalı ya iki sütuna bölünmelidir.
  static const double shortHeight = 500;

  final ScreenClass screenClass;
  final double width;
  final double height;

  bool get isCompact => screenClass == ScreenClass.compact;
  bool get isMediumOrWider => screenClass != ScreenClass.compact;
  bool get isExpanded => screenClass == ScreenClass.expanded;
  bool get isLandscape => width > height;

  /// Yatay telefon gibi dikey alanı kıt ekranlar.
  bool get isShortHeight => height < shortHeight;

  /// Alt gezinme çubuğu yerine yan gezinme (NavigationRail) kullanılmalı mı:
  /// tablet ve yatay telefonda dikey alanı korur.
  bool get useSideNavigation => isMediumOrWider || (isLandscape && isShortHeight);

  /// Kart ızgaraları için sütun sayısı.
  int columns({int compact = 1, int medium = 2, int expanded = 3}) {
    switch (screenClass) {
      case ScreenClass.compact:
        return compact;
      case ScreenClass.medium:
        return medium;
      case ScreenClass.expanded:
        return expanded;
    }
  }

  /// Sayfa kenar boşluğu.
  double get pagePadding => isCompact ? 16 : 24;
}

/// İçeriği geniş ekranlarda ortalar ve okunabilir bir genişlikte tutar.
/// Telefonda etkisi yoktur; tablette formların ve listelerin kenara
/// yapışıp aşırı uzamasını önler.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = reading,
    this.alignment = Alignment.topCenter,
  });

  /// Giriş/kayıt formları ve diyaloglar.
  static const double form = 480;

  /// Liste ve okuma ekranları (profil, ayarlar, sosyal).
  static const double reading = 720;

  /// Kart ızgaralı panolar (raporlar).
  static const double dashboard = 1080;

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
