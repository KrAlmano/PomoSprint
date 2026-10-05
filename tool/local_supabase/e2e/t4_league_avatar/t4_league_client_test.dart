// t4: istemcinin lig/avatar yorumunu GERÇEK sunucu çıktısıyla çapraz kontrol.
//
//   cd tool/local_supabase/e2e/t4_league_avatar && \
//     psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -qAt \
//       -f 09_capture_league_fixture.sql > league_fixture.json
//   flutter test tool/local_supabase/e2e/t4_league_avatar/t4_league_client_test.dart
//
// league_fixture.json: her odada bir üyenin gördüğü get_my_league_ranking
// satırları (process ÖNCESİ) + process_weekly_leagues sonrası herkesin gerçek
// kademe değişimi ve aldığı ödüller (geri alınan transaction).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/services/service_errors.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final fx = jsonDecode(File('tool/local_supabase/e2e/t4_league_avatar/league_fixture.json').readAsStringSync())
      as Map<String, dynamic>;
  final rooms = (fx['rooms'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()),
  );
  final outcomes = Map<String, dynamic>.from(fx['outcomes'] as Map);
  final capturedAt = DateTime.parse(fx['captured_at'] as String);

  group('LeagueSnapshot.zoneOf == process_weekly_leagues sonucu', () {
    for (final room in rooms.keys) {
      test('oda $room (${rooms[room]!.length} üye)', () {
        final rows = rooms[room]!;
        final snap = LeagueSnapshot.fromRows(rows, now: capturedAt);
        expect(snap.memberCount, rows.length);
        final mismatches = <String>[];
        for (var i = 0; i < rows.length; i++) {
          final entry = RankingEntry.fromRow(rows[i], pointsKey: 'weekly_points');
          final zone = snap.zoneOf(i + 1, entry.points);
          final predicted = switch (zone) {
            LeagueZone.promotion => 1,
            LeagueZone.demotion => -1,
            LeagueZone.promotionNeedsPoints || LeagueZone.none => 0,
          };
          final o = outcomes[entry.name] as Map<String, dynamic>;
          final actual = (o['tier_after'] as int) - (o['tier_before'] as int);
          if (predicted != actual) {
            mismatches.add('#${i + 1} ${entry.name} ${entry.points}p: istemci $zone, sunucu $actual');
          }
        }
        expect(mismatches, isEmpty);
      });
    }
  });

  group('Sıralamadaki ödül avatarı (get_league_ranking) == dönem sonunda verilen ödül', () {
    for (final room in rooms.keys) {
      test('oda $room', () {
        final rows = rooms[room]!;
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          final awards = ((outcomes[row['name']] as Map)['awards'] as List).cast<String>();
          final avatar = AvatarCharacter.byId(row['avatar_id'] as String?);
          if (avatar.isLeagueAward) {
            expect(awards, [avatar.id], reason: '${row['name']} (#${i + 1}) ödül avatarıyla görünüyor');
            expect(avatar.isChampionAward, i == 0);
            expect(avatar.isPodiumAward, i == 1 || i == 2);
          } else {
            expect(awards, isEmpty, reason: '${row['name']} (#${i + 1}) ödül avatarı görünmüyor ama ödül aldı');
          }
        }
      });
    }
  });

  test('Ligsiz kullanıcı satırı → awaitingPlacement (yerleştirme görünümü)', () {
    final snap = LeagueSnapshot.fromRows([
      {'name': 'x', 'avatar_id': 'avatar_16_basic', 'weekly_points': 0, 'tier': 1,
       'end_date': '2026-10-18T20:59:59+00:00', 'is_me': true, 'promotion_zone_end': 1,
       'demotion_zone_start': 999, 'member_count': 0},
    ]);
    expect(snap.awaitingPlacement, isTrue);
    expect(snap.endDate, DateTime.utc(2026, 10, 18, 20, 59, 59));
  });

  // t4-F6 (istemcide düzeldi): terfi edip yeni (boş) odaya tek başına
  // yerleşen kullanıcının satırı canlıda ligsiz satırla birebir aynı. Uygulama
  // satırı kullanıcının ömür boyu puanıyla okur (terfi eden puan kazanmıştır;
  // LeagueSnapshot.fromRows hasLeagueHistory). Satır t4-02 çıktısından (d1,
  // tier 5, yeni oda). proposed/20 sonrası ligsiz satır member_count 0 döner.
  test('t4-F6: terfi sonrası yeni odada tek kalan kullanıcı "odada değilsin" görmez', () {
    final row = {'name': 't4-d1', 'avatar_id': 'avatar_16_basic', 'weekly_points': 0, 'tier': 5,
       'end_date': '2026-10-18T20:59:59+00:00', 'is_me': true, 'promotion_zone_end': 1,
       'demotion_zone_start': 999, 'member_count': 1};
    final snap = LeagueSnapshot.fromRows([row], hasLeagueHistory: true);
    expect(snap.awaitingPlacement, isFalse, reason: 'kullanıcı tier-5 odasında');
    expect(snap.isAloneInRoom, isTrue);
    expect(LeagueSnapshot.fromRows([row], hasLeagueHistory: false).awaitingPlacement, isTrue,
        reason: 'puanı hiç olmamış kullanıcı canlıda gerçekten ligsizdir');
  });

  group('Sunucu hata metinleri → ServiceErrorCode (purchase_avatar / set_equipped_avatar)', () {
    final cases = <String, ServiceErrorCode>{
      'Yetersiz bakiye. Bu avatar için 200 kum tanesi gerekiyor, senin 0 kum tanen var.': ServiceErrorCode.insufficientCoins,
      'Bu avatar sadece Premium kullanıcılar içindir.': ServiceErrorCode.premiumRequired,
      'Bu avatar kilitli.': ServiceErrorCode.avatarLocked,
      'Avatar bulunamadı veya pasif durumda.': ServiceErrorCode.notFound,
      'Not authenticated': ServiceErrorCode.notSignedIn,
      "Bu avatar satın alınamaz. Yalnızca lig sıralamasında ilk 3'e girerek kazanılabilir.": ServiceErrorCode.server,
    };
    cases.forEach((message, code) {
      test(message, () {
        expect(serviceErrorCodeOf(PostgrestException(message: message, code: 'P0001')), code);
      });
    });
  });

  test('Avatar sahiplik kuralları sunucuyla aynı', () {
    final gamer = AvatarCharacter.byId('avatar_1_gamer');
    final doctor = AvatarCharacter.byId('avatar_11_doctor');
    final award = AvatarCharacter.byId('league_gold_monthly');
    final basic = AvatarCharacter.byId('avatar_16_basic');
    expect(basic.isOwned(const []), isTrue); // give_default_avatars her profile açar
    expect(gamer.isOwned(const []), isFalse);
    expect(gamer.canAfford(199), isFalse);
    expect(gamer.canAfford(200), isTrue);
    expect(doctor.canAfford(100000), isFalse); // Premium kumla alınmaz
    expect(doctor.canUnlockWithPremium(true), isTrue);
    expect(award.canAfford(100000), isFalse);
    expect(award.canUnlockWithPremium(true), isFalse);
    expect(award.isListedInShop(unlockedAvatars: const [], isPremium: true), isFalse);
    expect(award.isOwned(const ['league_gold_monthly']), isTrue);
  });
}
