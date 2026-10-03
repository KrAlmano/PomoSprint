import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yarıda kalan onboarding'in cihazdaki taslağı (adım ve seçimler). Android
/// süreci arka planda öldürürse ya da kullanıcı onay e-postasına gidip
/// dönerse seçimler kaybolmaz. Hesaba bağlıdır; onboarding bitince ve hesap
/// silinince silinir.
@immutable
class OnboardingDraft {
  final int step;
  final int? birthYear;
  final String? segment;
  final List<String> selectedCategories;
  final List<String> customCategories;
  final int? dailyGoalMinutes;

  const OnboardingDraft({
    required this.step,
    this.birthYear,
    this.segment,
    this.selectedCategories = const [],
    this.customCategories = const [],
    this.dailyGoalMinutes,
  });

  Map<String, dynamic> toJson() => {
        'step': step,
        'birth_year': birthYear,
        'segment': segment,
        'selected': selectedCategories,
        'custom': customCategories,
        'goal': dailyGoalMinutes,
      };

  /// Bozuk ya da eksik kayıtta null; listelerdeki metin dışı öğeler atılır.
  static OnboardingDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final step = json['step'];
    if (step is! int) return null;
    List<String> strings(Object? v) =>
        v is List ? v.whereType<String>().where((s) => s.trim().isNotEmpty).toList() : const <String>[];
    final birthYear = json['birth_year'];
    final segment = json['segment'];
    final goal = json['goal'];
    return OnboardingDraft(
      step: step,
      birthYear: birthYear is int ? birthYear : null,
      segment: segment is String ? segment : null,
      selectedCategories: strings(json['selected']),
      customCategories: strings(json['custom']),
      dailyGoalMinutes: goal is int ? goal : null,
    );
  }
}

class OnboardingDraftStore {
  OnboardingDraftStore._();

  static String keyFor(String uid) => 'onboarding_draft_uid_$uid';

  static Future<OnboardingDraft?> load(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(uid));
      if (raw == null || raw.isEmpty) return null;
      return OnboardingDraft.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('[ONBOARDING] Taslak okunamadı: $e');
      return null;
    }
  }

  static Future<void> save(String uid, OnboardingDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(uid), jsonEncode(draft.toJson()));
    } catch (e) {
      debugPrint('[ONBOARDING] Taslak kaydedilemedi: $e');
    }
  }

  static Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(uid));
  }
}
