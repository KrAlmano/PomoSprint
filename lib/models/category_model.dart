import 'package:flutter/material.dart';

class CourseCategory {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  int sessionsCount;
  int totalMinutes;
  final bool isArchived;
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
    this.colorHex = '#FF0000',
    this.iconName = 'book',
  });

  String get localizedName {
    if (id == '1' || name.toLowerCase() == 'matematik') {
      return 'Matematik';
    }
    if (id == '2' || name.toLowerCase() == 'fizik') {
      return 'Fizik';
    }
    return name;
  }

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
  // Yerel önbellekten (SharedPreferences) geri okunan ikonlar sadece bir
  // codePoint int'i olarak saklandığı için IconData(dynamicInt, ...) ile
  // yeniden kurulamaz — bu, `flutter build apk/appbundle/ipa`'yı kırar
  // (debug'da tree-shaking kapalı olduğu için fark edilmiyordu). Bunun
  // yerine, gerçekten kullanılan sabit ikon setine codePoint üzerinden
  // geri dönüyoruz; tanınmayan bir değer gelirse güvenli varsayılana düşer.
  static const Map<int, IconData> _knownIcons = {
    0xef10: Icons.calculate_outlined,
    0xf33d: Icons.science_outlined,
    0xeecf: Icons.biotech_outlined,
    0xf14f: Icons.language_outlined,
    0xf1c2: Icons.menu_book_outlined,
    0xeedf: Icons.book_outlined,
  };

  factory CourseCategory.fromJson(Map<String, dynamic> json) {
    final iconCode = json['icon'] as int?;
    return CourseCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      icon: _knownIcons[iconCode] ?? Icons.book_outlined,
      sessionsCount: json['sessionsCount'] as int? ?? 0,
      totalMinutes: json['totalMinutes'] as int? ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
      colorHex: json['colorHex'] as String? ?? '#FF0000',
      iconName: json['iconName'] as String? ?? 'book',
    );
  }

  static List<CourseCategory> initialCategories() {
    return [
      CourseCategory(
        id: '1',
        name: 'Matematik',
        color: const Color(0xFFEF4444),
        icon: Icons.calculate_outlined,
      ),
      CourseCategory(
        id: '2',
        name: 'Fizik',
        color: const Color(0xFF3B82F6),
        icon: Icons.science_outlined,
      ),
      CourseCategory(
        id: '3',
        name: 'Kimya',
        color: const Color(0xFF10B981),
        icon: Icons.biotech_outlined,
      ),
      CourseCategory(
        id: '4',
        name: 'İngilizce',
        color: const Color(0xFFF59E0B),
        icon: Icons.language_outlined,
      ),
      CourseCategory(
        id: '5',
        name: 'Türkçe',
        color: const Color(0xFF8B5CF6),
        icon: Icons.menu_book_outlined,
      ),
    ];
  }
}
