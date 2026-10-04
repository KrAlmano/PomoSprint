import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/services/onboarding_categories.dart';

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
}
