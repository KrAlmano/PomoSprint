import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/utils/category_names.dart';

CourseCategory _cat(String id, String name, {bool archived = false}) =>
    CourseCategory(id: id, name: name, color: Colors.red, icon: Icons.book, isArchived: archived);

List<String> _names(List<Map<String, dynamic>> payload) => [for (final p in payload) p['name'] as String];

void main() {
  group('t2-03 yeniden denenen onboarding kategorileri uzlaştırılır', () {
    final yks = [
      for (final (i, n) in ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe'].indexed)
        _cat('y$i', n),
    ];

    test('önceki denemenin kategorileri seçimde yoksa arşivlenir, yeni seçim kurulur', () {
      // İlk "Bitir": YKS 8 kategori kuruldu, profil yazılamadı. Kullanıcı
      // 'work' seçip bitiriyor: limit dolu olduğu için yeni seçim düşüyordu.
      final requested = categorySeedPayload(['Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje'], turkish: true);
      final plan = planOnboardingCategories(requested: requested, existing: yks, canArchive: true);
      expect(plan.archiveIds, [for (final c in yks) c.id]);
      expect(plan.unarchiveIds, isEmpty);
      expect(_names(plan.payload), ['Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje']);
    });

    test('dil değişince TR/EN çifti oluşmaz: aynı kategori yeniden gönderilmez', () {
      final lgsTr = [
        for (final (i, n) in ['Matematik', 'Fen Bilimleri', 'Türkçe', 'T.C. İnkılap Tarihi', 'İngilizce', 'Din Kültürü'].indexed)
          _cat('l$i', n),
      ];
      final requestedEn = categorySeedPayload(['Matematik', 'Fen Bilimleri'], turkish: false);
      expect(_names(requestedEn), ['Mathematics', 'Science']);
      final plan = planOnboardingCategories(requested: requestedEn, existing: lgsTr, canArchive: true);
      expect(plan.payload, isEmpty, reason: "'Matematik' = 'Mathematics'");
      expect(plan.archiveIds, ['l2', 'l3', 'l4', 'l5']);
    });

    test('önceki denemede arşivlenen kategori yeniden seçilirse kopyası açılmaz, arşivden döner', () {
      final existing = [_cat('a', 'Okuma'), _cat('b', 'Matematik', archived: true)];
      final requested = categorySeedPayload(['Matematik', 'Okuma', 'Proje'], turkish: true);
      final plan = planOnboardingCategories(requested: requested, existing: existing, canArchive: true);
      expect(plan.archiveIds, isEmpty);
      expect(plan.unarchiveIds, ['b']);
      expect(_names(plan.payload), ['Proje']);
    });

    test('seansı olan hesapta hiçbir kategori arşivlenmez; yalnızca eksikler eklenir', () {
      final requested = categorySeedPayload(['Matematik', 'Derin Çalışma'], turkish: true);
      final plan = planOnboardingCategories(requested: requested, existing: yks, canArchive: false);
      expect(plan.archiveIds, isEmpty);
      expect(plan.unarchiveIds, isEmpty);
      expect(_names(plan.payload), ['Derin Çalışma']);
    });

    test('istekteki tekrarlar ve boş adlar atılır', () {
      final plan = planOnboardingCategories(
        requested: [
          {'name': 'Fizik'},
          {'name': 'physics'},
          {'name': ' '},
        ],
        existing: const [],
        canArchive: true,
      );
      expect(_names(plan.payload), ['Fizik']);
    });
  });

  group('t2-09 kategorisiz hesabın varsayılanları segmente ve dile göre', () {
    test("'work' kullanıcısına okul dersleri değil iş önerileri açılır", () {
      expect(_names(defaultCategorySeed(segment: 'work', turkish: true)), ['Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje']);
      expect(_names(defaultCategorySeed(segment: 'work', turkish: false)), ['Deep Work', 'Reading', 'Learning', 'Project']);
    });

    test('YKS ilk beş öneri; segmentsiz genel öneriler; renkler paletten', () {
      expect(_names(defaultCategorySeed(segment: 'yks', turkish: true)), ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe']);
      final general = defaultCategorySeed(segment: null, turkish: true);
      expect(_names(general), ['Ders Çalışma', 'Okuma', 'Öğrenme', 'Proje']);
      expect(general.map((c) => c['color_hex']).toSet(), hasLength(general.length));
      expect(general.every((c) => c['icon_name'] == 'book'), isTrue);
    });
  });

  group('Yeni hedefler: KPSS ve dil sınavı', () {
    test('öneriler ve kategorisiz hesabın varsayılanı', () {
      expect(recommendedCategoryNames('kpss'),
          ['Türkçe', 'Matematik', 'Tarih', 'Coğrafya', 'Vatandaşlık', 'Güncel Bilgiler']);
      expect(recommendedCategoryNames('language'), ['Kelime', 'Okuma', 'Dilbilgisi', 'Dinleme', 'Yazma', 'Konuşma']);
      expect(_names(defaultCategorySeed(segment: 'kpss', turkish: false)),
          ['Turkish', 'Mathematics', 'History', 'Geography', 'Citizenship']);
      expect(_names(defaultCategorySeed(segment: 'language', turkish: false)),
          ['Vocabulary', 'Reading', 'Grammar', 'Listening', 'Writing']);
    });

    test('her öneri iki dilde bilinir; TR ve EN adı aynı kategori anahtarına düşer', () {
      final all = {...kGeneralCategoryRecommendations, for (final names in kRecommendedCategoriesBySegment.values) ...names};
      for (final name in all) {
        final en = localizedKnownCategoryName(name, turkish: false);
        expect(en, isNot(name), reason: '$name için İngilizce karşılık yok');
        expect(localizedKnownCategoryName(en, turkish: true), name);
        expect(categoryMatchKey(en), categoryMatchKey(name));
        expect(isRecommendedCategoryName(name), isTrue);
      }
      expect(isRecommendedCategoryName('Kendi Kategorim'), isFalse);
    });

    test('dilden bağımsız eşleme bozulmaz: hiçbir ad iki ayrı kategoriye düşmez', () {
      final keyOfName = <String, String>{};
      for (final (tr, en) in kKnownCategoryNames) {
        for (final name in [tr, en]) {
          final normalized = name.trim().toLowerCase().replaceAll('\u0307', '');
          final previous = keyOfName[normalized];
          expect(previous == null || previous == tr, isTrue, reason: "'$name' hem '$previous' hem '$tr' eşinde");
          keyOfName[normalized] = tr;
        }
      }
      // Yeni eşler mevcut eşlemeyi değiştirmez.
      expect(categoryMatchKey('Reading'), categoryMatchKey('Okuma'));
      expect(categoryMatchKey('Grammar'), isNot(categoryMatchKey('Türkçe')));
      expect(categoryMatchKey('Speaking'), categoryMatchKey('konuşma'));
    });
  });

  group('Hedefe göre otomatik seçilen öneriler', () {
    test('segmentin önerileri sırayla, limite kadar', () {
      expect(autoSelectedCategoryNames('yks', kept: const [], limit: 8),
          ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe']);
      expect(autoSelectedCategoryNames('yks', kept: const [], limit: 15), recommendedCategoryNames('yks'));
      expect(autoSelectedCategoryNames('kpss', kept: const [], limit: 8), recommendedCategoryNames('kpss'));
      expect(autoSelectedCategoryNames(null, kept: const [], limit: 8), kGeneralCategoryRecommendations);
    });

    test('elle seçilenler korunur, limite sayılır ve aynı kategori iki kez seçilmez', () {
      // Elle seçilen Felsefe, KPSS’nin altı genel önerisiyle korunur.
      expect(autoSelectedCategoryNames('kpss', kept: ['Felsefe'], limit: 8), recommendedCategoryNames('kpss'));
      // İki elle seçim: KPSS'nin ilk 6'sı.
      expect(autoSelectedCategoryNames('kpss', kept: ['Felsefe', 'Kendi'], limit: 8),
          recommendedCategoryNames('kpss').take(6).toList());
      // 'Mathematics' (İngilizce özel ad) = 'Matematik': yeniden seçilmez.
      expect(autoSelectedCategoryNames('kpss', kept: ['Mathematics'], limit: 8),
          ['Türkçe', 'Tarih', 'Coğrafya', 'Vatandaşlık', 'Güncel Bilgiler']);
      expect(autoSelectedCategoryNames('language', kept: List.generate(8, (i) => 'K$i'), limit: 8), isEmpty);
    });
  });
}
