import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category_model.dart';

/// Kategorilerin cihazdaki önbelleği (`saved_categories_<e-posta>`). Çıkışta
/// SupabaseService temizler.
abstract final class CategoryCache {
  static String keyFor(String? email) => email != null ? 'saved_categories_$email' : 'saved_categories';

  /// Önbellek yoksa ya da okunamazsa null.
  static Future<List<CourseCategory>?> read(String? email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(email));
      if (raw == null || raw.isEmpty) return null;
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => CourseCategory.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[CATEGORIES] Önbellek okunamadı: $e');
      return null;
    }
  }

  static Future<void> write(String email, List<CourseCategory> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(email), jsonEncode(categories.map((c) => c.toJson()).toList()));
    } catch (e) {
      debugPrint('[CATEGORIES] Önbellek yazılamadı: $e');
    }
  }
}
