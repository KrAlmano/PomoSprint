import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/utils/study_day.dart' show kDefaultStudyTimeZone;

void main() {
  group('UserModel', () {
    final full = UserModel(
      id: '0f8fad5b-d9cb-469f-a165-70867728950e',
      name: 'Ali',
      email: 'ali@example.com',
      avatarId: 'avatar_9_viking',
      totalMinutes: 300,
      lifetimePoints: 120,
      coins: 45,
      currentStreak: 7,
      longestStreak: 12,
      lastStudyDate: '2026-10-02',
      isPremium: true,
      unlockedAvatars: const ['avatar_9_viking', 'avatar_16_basic'],
      userSegment: 'university',
      dailyGoalMinutes: 120,
      birthYear: 2001,
      onboardingCompletedAt: DateTime.utc(2026, 9, 1, 10, 30).toLocal(),
      timezone: 'Europe/Istanbul',
    );

    test('toMap/fromMap gidiş-dönüşü tüm alanları korur (saved_user)', () {
      final copy = UserModel.fromMap(full.toMap());
      expect(copy.toMap(), full.toMap());
      expect(copy.id, full.id);
      expect(copy.currentStreak, 7);
      expect(copy.longestStreak, 12);
      expect(copy.lastStudyDate, '2026-10-02');
      expect(copy.unlockedAvatars, full.unlockedAvatars);
      expect(copy.dailyGoalMinutes, 120);
      expect(copy.onboardingCompletedAt, full.onboardingCompletedAt);
      expect(copy.timezone, 'Europe/Istanbul');
    });

    test('profil saat dilimi okunur; yoksa sunucu varsayılanı', () {
      expect(UserModel.fromMap({'name': 'x', 'email': 'y', 'timezone': 'Europe/Berlin'}).timezone, 'Europe/Berlin');
      expect(UserModel.fromMap({'name': 'x', 'email': 'y'}).timezone, kDefaultStudyTimeZone);
      expect(UserModel.fromMap({'name': 'x', 'email': 'y', 'timezone': ''}).timezone, kDefaultStudyTimeZone);
    });

    test('toMap seri ve son çalışma gününü yazar', () {
      final map = full.toMap();
      expect(map['current_streak'], 7);
      expect(map['last_study_date'], '2026-10-02');
      expect(map['longest_streak'], 12);
    });

    test('id String olarak okunur (UUID)', () {
      final u = UserModel.fromMap({'id': 'abc-uuid', 'name': 'x', 'email': 'y'});
      expect(u.id, 'abc-uuid');
    });

    test('eksik alanlarda güvenli varsayılanlar; coins puandan türetilmez', () {
      final u = UserModel.fromMap({'name': 'x', 'email': 'y', 'lifetime_points': 500});
      expect(u.id, isNull);
      expect(u.coins, 0);
      expect(u.avatarId, kDefaultAvatarId);
      expect(u.unlockedAvatars, isEmpty);
      expect(u.onboardingCompletedAt, isNull);
    });

    test('sahip olunan avatar listesi değiştirilemez', () {
      expect(() => full.unlockedAvatars.add('x'), throwsUnsupportedError);
      final updated = full.copyWith(unlockedAvatars: [...full.unlockedAvatars, 'avatar_1_gamer']);
      expect(updated.unlockedAvatars, contains('avatar_1_gamer'));
      expect(full.unlockedAvatars, isNot(contains('avatar_1_gamer')));
    });

    test('gösterilen seri sunucu kuralına (profil dilimi) göre normalize edilir', () {
      // Son çalışma günü 2 Ekim; anlar UTC (İstanbul = UTC+3).
      expect(full.streakOn(DateTime.utc(2026, 10, 2, 19)), 7, reason: 'aynı gün (22:00)');
      expect(full.streakOn(DateTime.utc(2026, 10, 3, 12)), 7, reason: 'ertesi gün: seri sürüyor');
      expect(full.streakOn(DateTime.utc(2026, 10, 4, 0, 59)), 7, reason: '03:59: hâlâ 3 Ekim çalışma günü');
      expect(full.streakOn(DateTime.utc(2026, 10, 4, 1)), 0, reason: '04:00: 4 Ekim çalışma günü, seri kırıldı');
      // Aynı an New York profilinde hâlâ 3 Ekim akşamı: seri sürüyor.
      expect(full.copyWith(timezone: 'America/New_York').streakOn(DateTime.utc(2026, 10, 4, 1)), 7);
    });
  });

  group('StudySession', () {
    test('gösterim zamanı gerçek bitiştir (started_at + süre), completed_at değil', () {
      final s = StudySession.fromJson({
        'id': 's1',
        'user_id': 'u1',
        'category': 'Fizik',
        'duration_minutes': 25,
        'started_at': '2026-10-01T20:00:00Z',
        'completed_at': '2026-10-02T09:00:00Z', // çevrimdışı kuyruktan geç senkron
      });
      expect(s.createdAt, DateTime.utc(2026, 10, 1, 20, 25).toLocal());
      expect(s.completedAt, DateTime.utc(2026, 10, 2, 9).toLocal());
      expect(s.categoryName, 'Fizik');
      expect(s.pomodoros, 1);
    });

    test("started_at yoksa completed_at'e düşer; join'li kategori adı öncelikli", () {
      final s = StudySession.fromJson({
        'id': 's1',
        'user_id': 'u1',
        'category': 'Eski Ad',
        'categories': {'name': 'Fizik', 'color_hex': '#3B82F6'},
        'duration_minutes': 50,
        'completed_at': '2026-10-02T09:00:00Z',
      });
      expect(s.startedAt, isNull);
      expect(s.createdAt, s.completedAt);
      expect(s.categoryName, 'Fizik');
      expect(s.colorHex, '#3B82F6');
      expect(s.pomodoros, 2);
    });
  });
}
