import 'package:flutter/foundation.dart';

import '../models/category_model.dart';
import '../utils/category_names.dart';
import '../widgets/auth/category_name_dialog.dart' show kCategoryPalette;

/// Segmente göre önerilen kategoriler. Türkçe anahtarlarla tutulur; ekranda
/// ve kayıtta kullanıcının diline çevrilir ([localizedKnownCategoryName];
/// her ad kKnownCategoryNames'te olmalı). Onboarding ekranı ve kategorisiz
/// hesabın varsayılan tohumu aynı tabloyu kullanır. 'kpss' ve 'language'
/// sunucuda proposed/26 ile kabul edilir (bkz. SupabaseService.completeOnboarding).
const Map<String, List<String>> kRecommendedCategoriesBySegment = {
  'lgs': [
    'Matematik',
    'Fen Bilimleri',
    'Türkçe',
    'T.C. İnkılap Tarihi',
    'İngilizce',
    'Din Kültürü',
  ],
  'yks': [
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Türkçe',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'İngilizce',
  ],
  'tus': [
    'Anatomi',
    'Fizyoloji, Histoloji ve Embriyoloji',
    'Biyokimya',
    'Mikrobiyoloji',
    'Patoloji',
    'Farmakoloji',
    'Dahiliye',
    'Pediatri',
    'Genel Cerrahi',
    'Kadın Hastalıkları ve Doğum',
    'Küçük Stajlar',
  ],
  'kpss': [
    'Türkçe',
    'Matematik',
    'Tarih',
    'Coğrafya',
    'Vatandaşlık',
    'Güncel Bilgiler',
    'Eğitim Bilimleri',
  ],
  'language': ['Kelime', 'Okuma', 'Dilbilgisi', 'Dinleme', 'Yazma', 'Konuşma'],
  'university': ['Ders Çalışma', 'Ödev', 'Proje', 'Sınav Hazırlık'],
  'work': ['Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje'],
};

/// Segment seçilmediğinde ya da "Diğer" seçildiğinde genel öneriler.
const List<String> kGeneralCategoryRecommendations = [
  'Ders Çalışma',
  'Okuma',
  'Öğrenme',
  'Proje',
];

/// [segment] için öneriler (bilinmeyen/boş segment: genel öneriler).
List<String> recommendedCategoryNames(String? segment) =>
    kRecommendedCategoriesBySegment[segment] ?? kGeneralCategoryRecommendations;

/// [name] herhangi bir segmentin (ya da genel listenin) önerisi mi? Segment
/// değişince elle seçilip korunan öneri de taslaktan geri gelebilsin diye.
bool isRecommendedCategoryName(String name) =>
    kGeneralCategoryRecommendations.contains(name) ||
    kRecommendedCategoriesBySegment.values.any((names) => names.contains(name));

/// Segment seçilince otomatik seçili gelen öneriler: [segment]'in önerileri
/// sırayla, [kept] (kullanıcının elle seçtikleri; korunur) ile aynı kategori
/// olmayanlar ([categoryMatchKey]), toplam seçim [limit]'i aşmayacak kadar.
List<String> autoSelectedCategoryNames(
  String? segment, {
  required Iterable<String> kept,
  required int limit,
}) {
  final keptNames = kept.toList();
  final taken = {for (final name in keptNames) categoryMatchKey(name)};
  final picked = <String>[];
  for (final name in recommendedCategoryNames(segment)) {
    if (keptNames.length + picked.length >= limit) break;
    if (taken.add(categoryMatchKey(name))) picked.add(name);
  }
  return picked;
}

/// setup_onboarding_categories gövdesi: adlar kullanıcının dilinde, renkler
/// paletten sırayla.
List<Map<String, dynamic>> categorySeedPayload(
  Iterable<String> names, {
  required bool turkish,
}) {
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
List<Map<String, dynamic>> defaultCategorySeed({
  String? segment,
  required bool turkish,
  int count = 5,
}) => categorySeedPayload(
  recommendedCategoryNames(segment).take(count),
  turkish: turkish,
);

/// Onboarding kategorilerinin sunucudaki mevcut kategorilerle uzlaştırılması.
@immutable
class OnboardingCategoryPlan {
  const OnboardingCategoryPlan({
    required this.payload,
    required this.archiveIds,
    required this.unarchiveIds,
    this.keep = const [],
  });

  /// setup_onboarding_categories'e gidecek (sunucuda henüz olmayan) kategoriler.
  final List<Map<String, dynamic>> payload;

  /// Önceki onboarding denemesinden kalan, yeni seçimde olmayan aktif kategoriler.
  final List<String> archiveIds;

  /// Seçimde olan ama önceki denemede arşivlenmiş kategoriler (yeniden açılır,
  /// kopyası oluşturulmaz).
  final List<String> unarchiveIds;

  /// Plan uygulandıktan sonra aktif kalacak mevcut kategoriler, sunucudaki
  /// adlarıyla. Yalnızca [rpcPayload]'a eklenir; hiçbiri yeniden oluşturulmaz.
  final List<Map<String, dynamic>> keep;

  /// setup_onboarding_categories'e gönderilecek tam yük: eksikler + aktif
  /// kalacaklar. Canlı sunucu birebir aynı aktif adı zaten atlıyor (no-op).
  /// proposed/23 ise onboarding bitmemişken yükte OLMAYAN seansız aktif
  /// kategorileri arşivliyor: yalnızca eksikler gönderilirse istemcinin
  /// tuttuğu (seçimde olan ya da kuyrukta seansı bekleyen) kategoriler
  /// sunucuda arşive giderdi. Çağrı yalnızca [payload] boş değilse yapılır.
  List<Map<String, dynamic>> get rpcPayload => [...payload, ...keep];
}

/// setup_onboarding_categories yanıtı. Canlı sunucu void döndürür (yanıt
/// null): sonuç bilinmez. proposed/23 jsonb döndürür: {created, restored,
/// skipped_existing, skipped_limit, skipped_invalid, archived}.
@immutable
class OnboardingCategoriesResult {
  const OnboardingCategoriesResult({
    this.created = 0,
    this.restored = 0,
    this.skippedExisting = 0,
    this.skippedLimit = 0,
    this.skippedInvalid = 0,
    this.archived = 0,
  });

  final int created;
  final int restored;
  final int skippedExisting;

  /// Kategori sınırı dolduğu için eklenemeyen seçimler.
  final int skippedLimit;
  final int skippedInvalid;
  final int archived;

  /// Sunucu yanıtını okur; void (null) ya da tanınmayan yanıtta null.
  static OnboardingCategoriesResult? fromResponse(Object? response) {
    if (response is! Map) return null;
    int read(String key) {
      final v = response[key];
      return v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return OnboardingCategoriesResult(
      created: read('created'),
      restored: read('restored'),
      skippedExisting: read('skipped_existing'),
      skippedLimit: read('skipped_limit'),
      skippedInvalid: read('skipped_invalid'),
      archived: read('archived'),
    );
  }

  @override
  String toString() =>
      'OnboardingCategoriesResult(created: $created, restored: $restored, '
      'skippedExisting: $skippedExisting, skippedLimit: $skippedLimit, skippedInvalid: $skippedInvalid, '
      'archived: $archived)';
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

  final payload = [
    for (final item in unique)
      if (!available.contains(keyOf(item['name']))) item,
  ];
  // Aktif kalacaklar (arşivlenmeyen aktifler + arşivden açılacaklar) kendi
  // sunucu adlarıyla; renk/ikon geçerli bir değerle (proposed/23 doğrular,
  // mevcut kategoriye yazılmaz). Bkz. [OnboardingCategoryPlan.rpcPayload].
  final archived = archiveIds.toSet();
  final unarchived = unarchiveIds.toSet();
  final keep = [
    for (final c in existing)
      if ((!c.isArchived && !archived.contains(c.id)) ||
          unarchived.contains(c.id))
        {
          'name': c.name,
          'color_hex': kCategoryPalette.first,
          'icon_name': 'book',
        },
  ];

  return OnboardingCategoryPlan(
    payload: payload,
    archiveIds: archiveIds,
    unarchiveIds: unarchiveIds,
    keep: payload.isEmpty ? const [] : keep,
  );
}

/// Onboarding kategorilerinin sunucuya yazılma sırası (servis ve yerel
/// uçtan uca testler aynı kodu çalıştırır): mevcutlar okunur; hiç yoksa
/// istenenler olduğu gibi kurulur. Varsa [planOnboardingCategories]: önce
/// arşivleme, sonra arşivden açma, en son eksikler varsa
/// setup_onboarding_categories ([OnboardingCategoryPlan.rpcPayload]).
/// [canArchive] yalnızca mevcut kategori varsa sorulur. Kurulumun sunucu
/// sonucunu döndürür (canlıda ya da kurulum yapılmadıysa null).
Future<OnboardingCategoriesResult?> reconcileOnboardingCategories({
  required List<Map<String, dynamic>> requested,
  required Future<List<CourseCategory>> Function() fetchAll,
  required Future<bool> Function() canArchive,
  required Future<void> Function(String id) archive,
  required Future<void> Function(String id) unarchive,
  required Future<OnboardingCategoriesResult?> Function(
    List<Map<String, dynamic>> payload,
  )
  setup,
}) async {
  final existing = await fetchAll();
  if (existing.isEmpty) return setup(requested);
  final plan = planOnboardingCategories(
    requested: requested,
    existing: existing,
    canArchive: await canArchive(),
  );
  for (final id in plan.archiveIds) {
    await archive(id);
  }
  for (final id in plan.unarchiveIds) {
    await unarchive(id);
  }
  if (plan.payload.isEmpty) return null;
  return setup(plan.rpcPayload);
}
