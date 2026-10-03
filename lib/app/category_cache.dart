import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category_model.dart';

/// Kategorilerin cihazdaki önbelleği (`saved_categories_uid_<uid>`). Çıkışta
/// SupabaseService temizler.
///
/// Eski sürümler anahtarda e-postayı kullanıyordu (`saved_categories_<e-posta>`,
/// iOS'ta yedeğe giren düz plist). [uid] verilince eski kayıt ilk okumada uid
/// anahtarına taşınır, yazmada silinir. Kimliği olmayan (çok eski) önbellekte
/// eski anahtar kullanılmaya devam eder.
abstract final class CategoryCache {
  /// Eski (e-postalı) anahtar; kimlik yokken ve taşıma/temizlik için.
  static String keyFor(String? email) => email != null ? 'saved_categories_$email' : 'saved_categories';

  static String keyForUid(String uid) => 'saved_categories_uid_$uid';

  static String? _id(String? uid) => (uid == null || uid.isEmpty) ? null : uid;

  /// Önbellek yoksa ya da okunamazsa null.
  static Future<List<CourseCategory>?> read(String? email, {String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = _id(uid);
      final current = id == null ? null : prefs.getString(keyForUid(id));
      if (current != null && current.isNotEmpty) return _decode(current);
      final legacyKey = keyFor(email);
      final legacy = prefs.getString(legacyKey);
      if (legacy == null || legacy.isEmpty) return null;
      final categories = _decode(legacy);
      if (id != null) {
        await prefs.setString(keyForUid(id), legacy);
        await prefs.remove(legacyKey);
      }
      return categories;
    } catch (e) {
      debugPrint('[CATEGORIES] Önbellek okunamadı: $e');
      return null;
    }
  }

  static Future<void> write(String email, List<CourseCategory> categories, {String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(categories.map((c) => c.toJson()).toList());
      final id = _id(uid);
      if (id == null) {
        await prefs.setString(keyFor(email), encoded);
        return;
      }
      await prefs.setString(keyForUid(id), encoded);
      if (email.isNotEmpty) await prefs.remove(keyFor(email));
    } catch (e) {
      debugPrint('[CATEGORIES] Önbellek yazılamadı: $e');
    }
  }

  static List<CourseCategory> _decode(String raw) => (jsonDecode(raw) as List<dynamic>)
      .map((item) => CourseCategory.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}
