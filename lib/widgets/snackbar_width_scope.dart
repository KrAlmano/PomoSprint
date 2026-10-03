import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Geniş ekranda (tablet, yatay telefon) yüzen SnackBar'ları tam genişliğe
/// yaymaz, okunabilir genişlikte ortalar. Dikey telefonda tema olduğu gibi
/// kalır (bugünkü görünüm).
///
/// MaterialApp.builder'da Navigator'ın üstüne konur. Ağaç her boyutta aynı
/// kalır (yalnızca tema değeri değişir); telefon döndürülünce Navigator
/// yeniden kurulmaz. Uygulamadaki tüm SnackBar'lar zaten floating olduğu
/// için geniş ekranda temaya floating + genişlik vermek başka bir şeyi
/// değiştirmez (genişlik yalnızca floating ile geçerlidir).
class SnackBarWidthScope extends StatelessWidget {
  const SnackBarWidthScope({super.key, required this.child});

  /// Geniş ekrandaki SnackBar genişliği (formlar ve diyaloglarla aynı).
  static const double wideWidth = ContentWidth.form;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = Responsive.of(context).isMediumOrWider;
    return Theme(
      data: wide
          ? theme.copyWith(
              // Tema genişliği floating davranışla birlikte verilmeli.
              snackBarTheme: theme.snackBarTheme.copyWith(
                behavior: SnackBarBehavior.floating,
                width: wideWidth,
              ),
            )
          : theme,
      child: child,
    );
  }
}
