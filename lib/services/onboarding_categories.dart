import 'package:flutter/foundation.dart';

import '../models/category_model.dart';
import '../utils/category_names.dart';
import '../widgets/auth/category_name_dialog.dart' show kCategoryPalette;

/// Segmente göre önerilen kategoriler. Türkçe anahtarlarla tutulur; ekranda
/// ve kayıtta kullanıcının diline çevrilir ([localizedKnownCategoryName]).
/// Onboarding ekranı ve kategorisiz hesabın varsayılan tohumu aynı tabloyu
/// kullanır.
const Map<String, List<String>> kRecommendedCategoriesBySegment = {
  'lgs': ['Matematik', 'Fen Bilimleri', 'Türkçe', 'T.C. İnkılap Tarihi', 'İngilizce', 'Din Kültürü'],
  'yks': ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe', 'İngilizce'],
  'university': ['Ders Çalışma', 'Ödev', 'Proje', 'Sınav Hazırlık'],
  'work': ['Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje'],
};

/// Segment seçilmediğinde ya da "Diğer" seçildiğinde genel öneriler.
const List<String> kGeneralCategoryRecommendations = ['Ders Çalışma', 'Okuma', 'Öğrenme', 'Proje'];

/// [segment] için öneriler (bilinmeyen/boş segment: genel öneriler).
List<String> recommendedCategoryNames(String? segment) =>
    kRecommendedCategoriesBySegment[segment] ?? kGeneralCategoryRecommendations;

/// setup_onboarding_categories gövdesi: adlar kullanıcının dilinde, renkler
/// paletten sırayla.
List<Map<String, dynamic>> categorySeedPayload(Iterable<String> names, {required bool turkish}) {
  final list = names.toList();
  return [
    for (var i = 0; i < list.length; i++)
      {
        'name': localizedKnownCategoryName(list[i], turkish: turkish),
        'color_hex': kCategoryPalette[i % kCategoryPalette.length],
        'icon_name': 'book',
      },
  ];
}

/// Hiç kategorisi olmayan hesaba açılacak varsayılanlar: kullanıcının
/// segmentinin ilk [count] önerisi, kullanıcının dilinde. Eskiden segment
/// ve dil yok sayılıp herkese okul dersleri (Matematik, Fizik…) açılıyordu.
List<Map<String, dynamic>> defaultCategorySeed({String? segment, required bool turkish, int count = 5}) =>
    categorySeedPayload(recommendedCategoryNames(segment).take(count), turkish: turkish);

/// Onboarding kategorilerinin sunucudaki mevcut kategorilerle uzlaştırılması.
@immutable
class OnboardingCategoryPlan {
  const OnboardingCategoryPlan({required this.payload, required this.archiveIds, required this.unarchiveIds});

  /// setup_onboarding_categories'e gidecek (sunucuda henüz olmayan) kategoriler.
  final List<Map<String, dynamic>> payload;

  /// Önceki onboarding denemesinden kalan, yeni seçimde olmayan aktif kategoriler.
  final List<String> archiveIds;

  /// Seçimde olan ama önceki denemede arşivlenmiş kategoriler (yeniden açılır,
  /// kopyası oluşturulmaz).
  final List<String> unarchiveIds;
}

/// Yeniden denenen onboarding'in kategori planı.
///
/// setup_onboarding_categories var olan kategorileri hiç ele almıyor: limitte
/// sessizce duruyor ve aynı adı yalnızca birebir (dile duyarlı) eşliyor.
/// Önceki deneme kategorileri kurup profil yazılamadan yarıda kaldıysa yeni
/// seçim limite takılıp düşüyor, dil değişince 'Matematik' + 'Mathematics'
/// çifti oluşuyordu.
///
/// Adlar dilden bağımsız anahtarla ([categoryMatchKey]) eşlenir: zaten
/// aktif olan (ya da arşivden geri açılacak) kategori yeniden gönderilmez.
/// [canArchive] (onboarding bitmemiş ve hiç seansı olmayan hesap) ise yeni
/// seçimde olmayan aktif kategoriler arşivlenir; seansı olan hesapta hiçbir
/// kategoriye dokunulmaz.
OnboardingCategoryPlan planOnboardingCategories({
  required List<Map<String, dynamic>> requested,
  required List<CourseCategory> existing,
  required bool canArchive,
}) {
  String keyOf(Object? name) => categoryMatchKey(name?.toString() ?? '');
  final wanted = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final item in requested) {
    final key = keyOf(item['name']);
    if (key.isEmpty || !wanted.add(key)) continue;
    unique.add(item);
  }

  final archiveIds = <String>[];
  final available = <String>{};
  for (final c in existing.where((c) => !c.isArchived)) {
    final key = categoryMatchKey(c.name);
    if (wanted.contains(key)) {
      available.add(key);
    } else if (canArchive) {
      archiveIds.add(c.id);
    }
  }

  final unarchiveIds = <String>[];
  if (canArchive) {
    for (final c in existing.where((c) => c.isArchived)) {
      final key = categoryMatchKey(c.name);
      if (wanted.contains(key) && available.add(key)) unarchiveIds.add(c.id);
    }
  }

  return OnboardingCategoryPlan(
    payload: [for (final item in unique) if (!available.contains(keyOf(item['name']))) item],
    archiveIds: archiveIds,
    unarchiveIds: unarchiveIds,
  );
}
