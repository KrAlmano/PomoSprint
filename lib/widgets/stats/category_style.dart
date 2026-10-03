import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../utils/color_hex.dart';

/// İstatistiklerde kategorisi bulunamayan (ör. silinmiş) seanslar için nötr renk.
const Color kStatsNeutralColor = Color(0xFF9E9E9E);

class CategoryStyle {
  const CategoryStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

/// Bir istatistik satırının rengi ve ikonu; tüm sekmelerde aynı kural:
/// renk önce seansın sunucudaki kategori renginden (arşivlenmiş kategoriler
/// dahil), yoksa aktif kategoriden (önce kimlik, sonra ad), en son nötr renk.
CategoryStyle categoryStyleFor({
  required String name,
  String? categoryId,
  String? colorHex,
  required List<CourseCategory> categories,
}) {
  CourseCategory? match;
  if (categoryId != null) match = categories.where((c) => c.id == categoryId).firstOrNull;
  match ??= categories.where((c) => c.name == name).firstOrNull;
  final fallback = match?.color ?? kStatsNeutralColor;
  return CategoryStyle(
    color: colorHex == null ? fallback : colorFromHex(colorHex, fallback: fallback),
    icon: match?.icon ?? Icons.book_outlined,
  );
}
