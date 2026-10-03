import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations_tr.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';

// Canlı sözleşme (3 Ekim 2026): get_public_monthly_leaderboard ve
// get_public_alltime_leaderboard is_me döndürür; get_my_league_ranking lig
// yokken tek satır (member_count 1, bölgeler 1/999) döndürür.
void main() {
  group('RankingEntry.fromRow', () {
    test('kendi satırı yalnızca is_me ile bilinir, isimle eşlenmez', () {
      final rows = [
        {'name': 'Ali', 'avatar_id': 'avatar_2_glasses', 'total_points': 40, 'total_minutes': 200, 'is_me': false},
        {'name': 'Ali', 'avatar_id': 'avatar_16_basic', 'total_points': 30, 'total_minutes': 150, 'is_me': true},
        {'name': 'Ayşe', 'avatar_id': 'avatar_5_flower', 'total_points': 20, 'total_minutes': 100},
      ];
      final entries = [for (final r in rows) RankingEntry.fromRow(r, pointsKey: 'total_points')];
      expect(entries.map((e) => e.isMe), [false, true, false]);
      expect(entries[1].points, 30);
      expect(entries[1].minutes, 150);
    });

    test('tüm zamanlar satırı (lifetime_points) is_me ile', () {
      final entry = RankingEntry.fromRow(
        const {'name': 'Can', 'avatar_id': 'avatar_9_viking', 'total_minutes': 500, 'lifetime_points': 120, 'is_premium': false, 'is_me': true},
        pointsKey: 'lifetime_points',
      );
      expect(entry.isMe, isTrue);
      expect(entry.points, 120);
    });
  });

  group('LeagueSnapshot', () {
    final l10n = AppLocalizationsTr();

    test('lig yokken sunucunun tek satırı: yerleşme bekleniyor, bölge gösterilmez', () {
      final rows = [
        {
          'name': 'Ben',
          'avatar_id': 'avatar_16_basic',
          'weekly_points': 0,
          'tier': null,
          'end_date': '2026-10-11T20:59:59+00:00',
          'is_me': true,
          'promotion_zone_end': 1,
          'demotion_zone_start': 999,
          'member_count': 1,
        },
      ];
      final league = LeagueSnapshot.fromRows(rows);
      expect(league.awaitingPlacement, isTrue);
      expect(league.tier, 1);
      expect(league.endDate, DateTime.utc(2026, 10, 11, 20, 59, 59));
      expect(league.isPromotionRank(1, 0), isFalse);
      expect(league.isDemotionRank(1), isFalse);
      expect(league.demotionCount, 0);
      expect(promotionDemotionText(l10n, league), l10n.leagueAwaitingPlacementBody);
    });

    test('tek kişilik odada puan varsa gerçek oda sayılır (puanlı 1. terfi eder)', () {
      final league = LeagueSnapshot.fromRows([
        {'weekly_points': 12, 'tier': 2, 'end_date': '2026-10-11T20:59:59Z', 'is_me': true, 'promotion_zone_end': 1, 'demotion_zone_start': 999, 'member_count': 1},
      ]);
      expect(league.awaitingPlacement, isFalse);
      expect(league.myPoints, 12);
      expect(league.isPromotionRank(1, 12), isTrue);
    });

    test('gerçek oda: bölgeler ve puan kendi satırından', () {
      final rows = [
        for (var i = 0; i < 12; i++)
          {
            'weekly_points': 100 - i,
            'tier': 2,
            'end_date': '2026-10-11T20:59:59Z',
            'is_me': i == 4,
            'promotion_zone_end': 3,
            'demotion_zone_start': 10,
            'member_count': 12,
          },
      ];
      final league = LeagueSnapshot.fromRows(rows);
      expect(league.awaitingPlacement, isFalse);
      expect(league.myPoints, 96);
      expect(league.demotionCount, 3);
      expect(league.isPromotionRank(3, 98), isTrue);
      expect(league.isPromotionRank(3, 0), isFalse, reason: 'sunucu 0 puanla terfi ettirmez');
      expect(league.isDemotionRank(10), isTrue);
      expect(promotionDemotionText(l10n, league), '${l10n.leagueInfoPromote(3)}\n${l10n.leagueInfoDemote(3)}');
    });

    test('küçük odada terfi bölgesi podyumun içinde; 0 puanlı terfi etmez', () {
      // 3 kişilik Bronz oda: promotion_zone_end = min(3, ceil(3/2)) = 2, düşme yok.
      final league = LeagueSnapshot.fromRows([
        for (final (i, points) in [(0, 20), (1, 10), (2, 5)])
          {
            'weekly_points': points,
            'tier': 1,
            'end_date': '2026-10-11T20:59:59Z',
            'is_me': i == 2,
            'promotion_zone_end': 2,
            'demotion_zone_start': 999,
            'member_count': 3,
          },
      ]);
      expect(league.zoneOf(1, 20), LeagueZone.promotion);
      expect(league.zoneOf(2, 10), LeagueZone.promotion);
      expect(league.zoneOf(3, 5), LeagueZone.none, reason: '3. terfi etmez');
      expect(league.zoneOf(2, 0), LeagueZone.promotionNeedsPoints);
    });

    test('12 kişilik oda: terfi 1-3 (podyum), düşme 10-12; en üst/en alt kademe istisnası', () {
      Map<String, dynamic> row(int tier) => {
            'weekly_points': 5,
            'tier': tier,
            'is_me': true,
            'promotion_zone_end': 3,
            'demotion_zone_start': 10,
            'member_count': 12,
          };
      final mid = LeagueSnapshot.fromRows([row(2)]);
      expect([for (var r = 1; r <= 12; r++) mid.zoneOf(r, 5)], [
        for (var r = 1; r <= 12; r++) r <= 3 ? LeagueZone.promotion : (r >= 10 ? LeagueZone.demotion : LeagueZone.none),
      ]);
      expect(LeagueSnapshot.fromRows([row(kLeagueTierCount)]).zoneOf(1, 5), LeagueZone.none, reason: 'en üst lig');
      expect(LeagueSnapshot.fromRows([row(1)]).zoneOf(12, 5), LeagueZone.none, reason: 'Bronzda düşme yok');
    });

    test('yerleşme beklenirken bölge yok', () {
      final league = LeagueSnapshot.fromRows([
        {'weekly_points': 0, 'tier': 1, 'is_me': true, 'promotion_zone_end': 1, 'demotion_zone_start': 999, 'member_count': 1},
      ]);
      expect(league.zoneOf(1, 0), LeagueZone.none);
    });

    test('end_date gelmezse 14 günlük dönem varsayımı (Türkiye saati)', () {
      // Cumartesi 3 Ekim 15:00 (TR) → bu haftanın Pazartesi'si 28 Eylül + 13 gün.
      final league = LeagueSnapshot.fromRows(
        [
          {'weekly_points': 0, 'tier': 1, 'is_me': true, 'promotion_zone_end': 1, 'demotion_zone_start': 999, 'member_count': 1},
        ],
        now: DateTime.utc(2026, 10, 3, 12),
      );
      expect(league.endDate, DateTime.utc(2026, 10, 11, 20, 59, 59));
    });
  });

  group('assumedLeaguePeriodEnd', () {
    test('Pazar gecesi UTC iken TR saatinde Pazartesi: yeni haftadan sayılır', () {
      // 4 Ekim 22:30 UTC = 5 Ekim 01:30 (TR), Pazartesi.
      expect(assumedLeaguePeriodEnd(DateTime.utc(2026, 10, 4, 22, 30)), DateTime.utc(2026, 10, 18, 20, 59, 59));
    });

    test('dönem uzunluğu 14 gün', () {
      expect(kLeaguePeriod, const Duration(days: 14));
      final monday = assumedLeaguePeriodEnd(DateTime.utc(2026, 9, 28, 6));
      final sunday = assumedLeaguePeriodEnd(DateTime.utc(2026, 10, 4, 20));
      expect(monday, sunday, reason: 'aynı hafta içinde aynı dönem sonu');
    });
  });
}
