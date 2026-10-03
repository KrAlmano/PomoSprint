import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama teması. Tercih SharedPreferences'ta ('theme_mode') kalıcıdır;
/// kullanıcı hiç seçmediyse sistem teması izlenir.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final ThemeController instance = ThemeController._();

  static const String _prefsKey = 'theme_mode';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = ThemeMode.values.asNameMap()[prefs.getString(_prefsKey)] ?? ThemeMode.system;
    } catch (e) {
      debugPrint('[THEME] Tema tercihi okunamadı: $e');
    }
  }

  /// Profildeki 'Karanlık Mod' anahtarı: açık/koyu tercihini kaydeder.
  Future<void> setDarkMode(bool isDark) async {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.name);
    } catch (e) {
      debugPrint('[THEME] Tema tercihi kaydedilemedi: $e');
    }
  }
}
