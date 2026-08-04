import 'package:flutter/material.dart';

class CourseCategory {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  int sessionsCount;
  int totalMinutes;

  CourseCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.sessionsCount = 0,
    this.totalMinutes = 0,
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
    };
  }

  factory CourseCategory.fromJson(Map<String, dynamic> json) {
    final iconCode = json['icon'] as int? ?? 0xe112;
    return CourseCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      // ignore: non_const_argument_for_const_parameter
      icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
      sessionsCount: json['sessionsCount'] as int? ?? 0,
      totalMinutes: json['totalMinutes'] as int? ?? 0,
    );
  }

  static List<CourseCategory> initialCategories() {
    return [
      CourseCategory(
        id: '1',
        name: 'Matematik',
        color: const Color(0xFFEF4444),
        icon: Icons.calculate_outlined,
        sessionsCount: 16,
        totalMinutes: 500,
      ),
      CourseCategory(
        id: '2',
        name: 'Fizik',
        color: const Color(0xFF3B82F6),
        icon: Icons.science_outlined,
        sessionsCount: 10,
        totalMinutes: 310,
      ),
      CourseCategory(
        id: '3',
        name: 'Kimya',
        color: const Color(0xFF10B981),
        icon: Icons.biotech_outlined,
        sessionsCount: 8,
        totalMinutes: 250,
      ),
      CourseCategory(
        id: '4',
        name: 'İngilizce',
        color: const Color(0xFFF59E0B),
        icon: Icons.language_outlined,
        sessionsCount: 6,
        totalMinutes: 190,
      ),
      CourseCategory(
        id: '5',
        name: 'Türkçe',
        color: const Color(0xFF8B5CF6),
        icon: Icons.menu_book_outlined,
        sessionsCount: 4,
        totalMinutes: 125,
      ),
    ];
  }
}
