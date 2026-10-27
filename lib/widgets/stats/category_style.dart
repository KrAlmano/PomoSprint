import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../utils/color_hex.dart';
import '../../utils/stats_calculator.dart' show kExamStatsCategoryId;

/// İstatistiklerde kategorisi bulunamayan (ör. silinmiş) seanslar için nötr renk.
const Color kStatsNeutralColor = Color(0xFF9E9E9E);

class CategoryStyle {
  const CategoryStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

/// Bir istatistik satırının rengi ve ikonu; tüm sekmelerde aynı kural:
/// renk ve ikon önce seansın sunucudaki kategorisinden (arşivlenmiş
/// kategoriler dahil; [colorHex], [iconName]), yoksa aktif kategoriden (önce
/// kimlik, sonra ad), en son nötr renk ve kitap ikonu. Renk ve ikon aynı
/// kaynaktan gelir; yarı eski yarı yeni görünüm oluşmaz.
CategoryStyle categoryStyleFor({
  required String name,
  String? categoryId,
  String? colorHex,
  String? iconName,
  required List<CourseCategory> categories,
}) {
  if (categoryId == kExamStatsCategoryId) {
    return const CategoryStyle(
      color: Color(0xFF0055D4),
      icon: Icons.assignment_outlined,
    );
  }
  CourseCategory? match;
  if (categoryId != null) {
    match = categories.where((c) => c.id == categoryId).firstOrNull;
  }
  match ??= categories.where((c) => c.name == name).firstOrNull;
  final fallback = match?.color ?? kStatsNeutralColor;
  return CategoryStyle(
    color: colorHex == null
        ? fallback
        : colorFromHex(colorHex, fallback: fallback),
    icon: colorHex != null && iconName != null
        ? CourseCategory.iconForName(iconName)
        : (match?.icon ?? CourseCategory.iconForName(iconName)),
  );
}
