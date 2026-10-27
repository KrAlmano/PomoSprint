import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Geniş ekranda (tablet, yatay telefon) yüzen SnackBar'ları tam genişliğe
/// yaymaz, okunabilir genişlikte ortalar. Dikey telefonda tema olduğu gibi
/// genişlik kısıtı eklenmez (bugünkü görünüm).
///
/// MaterialApp.builder'da Navigator'ın üstüne konur. Ağaç her boyutta aynı
/// kalır (yalnızca tema değeri değişir); telefon döndürülünce Navigator
/// yeniden kurulmaz. Uygulamadaki tüm SnackBar'lar zaten floating olduğu
/// için her iki boyutta da floating davranışını sabit tutmak görünümü
/// değiştirmez. Açık diyalogdaki AnimatedTheme, döndürme sırasında genişliği
/// ara değerlerle canlandırırken davranışı artık null/fixed yapamaz;
/// genişlik yalnızca floating ile geçerlidir.
class SnackBarWidthScope extends StatelessWidget {
  const SnackBarWidthScope({super.key, required this.child});

  /// Geniş ekrandaki SnackBar genişliği (formlar ve diyaloglarla aynı).
  static const double wideWidth = ContentWidth.form;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = Responsive.of(context).isMediumOrWider;
    final snackBarTheme = theme.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
    );
    return Theme(
      data: theme.copyWith(
        snackBarTheme: wide
            ? snackBarTheme.copyWith(width: wideWidth)
            : snackBarTheme,
      ),
      child: child,
    );
  }
}
