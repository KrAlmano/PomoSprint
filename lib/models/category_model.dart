import 'package:flutter/material.dart';

import '../utils/color_hex.dart';

/// Aktif kategori limitleri. Sunucudaki enforce_category_limit trigger'ı ve
/// create_category / setup_onboarding_categories RPC'leri aynı değerleri
/// zorunlu kılar; istemcideki tüm limit gösterimleri buradan okunmalıdır.
const int kFreeCategoryLimit = 8;
const int kPremiumCategoryLimit = 15;

int categoryLimitFor({required bool isPremium}) =>
    isPremium ? kPremiumCategoryLimit : kFreeCategoryLimit;

class CourseCategory {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  int sessionsCount;
  int totalMinutes;
  final bool isArchived;

  /// '#RRGGBB'. Verilmezse [color]'dan türetilir; ikisi her zaman tutarlıdır.
  final String colorHex;
  final String iconName;

  CourseCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.sessionsCount = 0,
    this.totalMinutes = 0,
    this.isArchived = false,
    String? colorHex,
    this.iconName = 'book',
  }) : colorHex = colorHex ?? colorToHex(color);

  /// Sunucudaki `categories` satırından kurar.
  factory CourseCategory.fromServerRow(Map<String, dynamic> row) {
    final color = colorFromHex(row['color_hex'] as String?);
    final iconName = row['icon_name'] as String? ?? 'book';
    return CourseCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      color: color,
      icon: iconForName(iconName),
      isArchived: row['is_archived'] as bool? ?? false,
      colorHex: colorToHex(color),
      iconName: iconName,
    );
  }

  /// setup_onboarding_categories / create_category için gövde.
  Map<String, dynamic> toServerJson() => {
        'name': name,
        'color_hex': colorHex,
        'icon_name': iconName,
      };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'icon': icon.codePoint,
      'sessionsCount': sessionsCount,
      'totalMinutes': totalMinutes,
      'isArchived': isArchived,
      'colorHex': colorHex,
      'iconName': iconName,
    };
  }

  // Release build'lerde ikon tree-shaking, uygulamadaki TÜM IconData
  // kullanımlarının derleme zamanında sabit (const) olmasını şart koşar.
  // Bu yüzden ikonlar codePoint ya da isimden sabit bir haritaya eşlenir;
  // tanınmayan değer güvenli varsayılana (book_outlined) düşer.
  static const Map<int, IconData> _knownIcons = {
    0xef10: Icons.calculate_outlined,
    0xf33d: Icons.science_outlined,
    0xeecf: Icons.biotech_outlined,
    0xf14f: Icons.language_outlined,
    0xf1c2: Icons.menu_book_outlined,
    0xeedf: Icons.book_outlined,
  };

  static const Map<String, IconData> _iconsByName = {
    'calculate': Icons.calculate_outlined,
    'science': Icons.science_outlined,
    'biotech': Icons.biotech_outlined,
    'language': Icons.language_outlined,
    'menu_book': Icons.menu_book_outlined,
    'book': Icons.book_outlined,
  };

  /// Sunucudaki icon_name değerini sabit bir ikona çevirir.
  static IconData iconForName(String? name) => _iconsByName[name] ?? Icons.book_outlined;

  factory CourseCategory.fromJson(Map<String, dynamic> json) {
    final iconCode = json['icon'] as int?;
    final color = Color(json['color'] as int);
    return CourseCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      color: color,
      icon: _knownIcons[iconCode] ?? Icons.book_outlined,
      sessionsCount: json['sessionsCount'] as int? ?? 0,
      totalMinutes: json['totalMinutes'] as int? ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
      colorHex: json['colorHex'] as String? ?? colorToHex(color),
      iconName: json['iconName'] as String? ?? 'book',
    );
  }

  /// Bulut erişilemezken gösterilen yer tutucu kategoriler. Kimlikleri UUID
  /// değildir; bu kategorilerle tamamlanan seanslar gönderilmeden önce
  /// isimle sunucu kategorisine eşlenir (bkz. SessionQueue).
  static List<CourseCategory> initialCategories() {
    return [
      CourseCategory(
        id: '1',
        name: 'Matematik',
        color: const Color(0xFFEF4444),
        icon: Icons.calculate_outlined,
        iconName: 'calculate',
      ),
      CourseCategory(
        id: '2',
        name: 'Fizik',
        color: const Color(0xFF3B82F6),
        icon: Icons.science_outlined,
        iconName: 'science',
      ),
      CourseCategory(
        id: '3',
        name: 'Kimya',
        color: const Color(0xFF10B981),
        icon: Icons.biotech_outlined,
        iconName: 'biotech',
      ),
      CourseCategory(
        id: '4',
        name: 'İngilizce',
        color: const Color(0xFFF59E0B),
        icon: Icons.language_outlined,
        iconName: 'language',
      ),
      CourseCategory(
        id: '5',
        name: 'Türkçe',
        color: const Color(0xFF8B5CF6),
        icon: Icons.menu_book_outlined,
        iconName: 'menu_book',
      ),
    ];
  }
}
