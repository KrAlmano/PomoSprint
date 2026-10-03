import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/avatar_model.dart';

void main() {
  setUp(AvatarCharacter.clearCachedAvatars);
  tearDown(AvatarCharacter.clearCachedAvatars);

  group('katalog boşken güvenli davranış', () {
    test('allAvatars asla boş dönmez (gömülü katalog)', () {
      expect(AvatarCharacter.hasServerCatalog, isFalse);
      expect(AvatarCharacter.allAvatars(), isNotEmpty);
      expect(AvatarCharacter.allAvatars().any((a) => a.id == kDefaultAvatarId), isTrue);
    });

    test('byId bilinmeyen/boş kimlikte fırlatmaz, varsayılana düşer', () {
      expect(AvatarCharacter.byId(null).id, kDefaultAvatarId);
      expect(AvatarCharacter.byId('yok_boyle_bir_avatar').id, kDefaultAvatarId);
      expect(AvatarCharacter.byId('avatar_9_viking').id, 'avatar_9_viking');
      expect(AvatarCharacter.byId('league_gold_weekly').isLeagueAward, isTrue);
    });

    test('boş liste önbelleği silmez', () {
      AvatarCharacter.setCachedAvatars(const []);
      expect(AvatarCharacter.allAvatars(), isNotEmpty);
    });

    test('sunucu kataloğu varsa önce o kullanılır, yoksa gömülüye düşülür', () {
      AvatarCharacter.setCachedAvatars(const [
        AvatarCharacter(id: 'only_server', nameTr: 'S', nameEn: 'S', imagePath: 'x.png', isDefault: true),
      ]);
      expect(AvatarCharacter.allAvatars().single.id, 'only_server');
      expect(AvatarCharacter.byId('only_server').id, 'only_server');
      expect(AvatarCharacter.byId('avatar_9_viking').id, 'avatar_9_viking');
      expect(AvatarCharacter.byId('yok').id, kDefaultAvatarId);
    });

    test('varsayılan avatar ücretsiz ve sahiplik kaydı gerektirmez', () {
      expect(AvatarCharacter.byId(kDefaultAvatarId).isFree, isTrue);
      expect(AvatarCharacter.isFreeAvatarId(kDefaultAvatarId), isTrue);
      expect(AvatarCharacter.isFreeAvatarId('avatar_1_gamer'), isFalse, reason: '200 kum tanesi');
      expect(AvatarCharacter.isFreeAvatarId('avatar_11_doctor'), isFalse, reason: 'Premium');
      expect(AvatarCharacter.isFreeAvatarId(null), isFalse);
    });
  });

  group('sahiplik ve satın alınabilirlik', () {
    final viking = AvatarCharacter.byId('avatar_9_viking');
    final doctor = AvatarCharacter.byId('avatar_11_doctor');
    final league = AvatarCharacter.byId('league_gold_weekly');
    final basic = AvatarCharacter.byId(kDefaultAvatarId);

    test('bakiyenin yetmesi sahiplik sayılmaz', () {
      expect(viking.isOwned(const []), isFalse);
      expect(viking.canAfford(250), isTrue);
      expect(viking.canAfford(150), isFalse);
      expect(viking.isOwned(const ['avatar_9_viking']), isTrue);
    });

    test('ücretsiz avatar her zaman sahiplidir', () {
      expect(basic.isOwned(const []), isTrue);
    });

    test('Premium avatar kum tanesiyle alınamaz, Premium kullanıcı açabilir', () {
      expect(doctor.isOwned(const []), isFalse);
      expect(doctor.canAfford(100000), isFalse);
      expect(doctor.canUnlockWithPremium(true), isTrue);
      expect(doctor.canUnlockWithPremium(false), isFalse);
    });

    test('lig ödülü yalnızca kazanılarak açılır', () {
      expect(league.isOwned(const []), isFalse);
      expect(league.canAfford(100000), isFalse);
      expect(league.canUnlockWithPremium(true), isFalse);
      expect(league.isOwned(const ['league_gold_weekly']), isTrue);
    });
  });

  group('canlı avatars sözleşmesi', () {
    test('varsayılan (ücretsiz) avatarlar canlıdaki is_default listesiyle aynı', () {
      final free = AvatarCharacter.fallbackCatalog.where((a) => a.isFree).map((a) => a.id).toSet();
      expect(free, {
        'avatar_16_basic',
        'avatar_2_glasses',
        'avatar_3_gentleman',
        'avatar_5_flower',
        'avatar_6_cool',
        'avatar_7_scholar',
        'avatar_8_striped',
      });
      expect(kDefaultAvatarId, 'avatar_16_basic');
    });

    test('200 kum tanesi, Premium ve lig ödülü avatarları', () {
      for (final id in ['avatar_1_gamer', 'avatar_4_bowtie', 'avatar_9_viking', 'avatar_10_dentist']) {
        expect(AvatarCharacter.byId(id).requiredCoins, 200, reason: id);
        expect(AvatarCharacter.isFreeAvatarId(id), isFalse, reason: id);
      }
      for (var i = 11; i <= 15; i++) {
        final premium = AvatarCharacter.fallbackCatalog.firstWhere((a) => a.id.startsWith('avatar_${i}_'));
        expect(premium.isPremiumOnly, isTrue, reason: premium.id);
      }
      final awards = AvatarCharacter.fallbackCatalog.where((a) => a.isLeagueAward).map((a) => a.id).toSet();
      expect(awards, {
        for (final tier in ['bronze', 'silver', 'gold', 'sapphire', 'diamond'])
          for (final period in ['weekly', 'monthly']) 'league_${tier}_$period',
      });
      expect(AvatarCharacter.fallbackCatalog.any((a) => a.id == 'tomato_basic'), isFalse, reason: 'canlıda pasif');
    });

    test('lig ödülü adı ve türü canlı ödül kuralından (1. → monthly, 2.-3. → weekly)', () {
      final champion = AvatarCharacter.fromMap(const {
        'id': 'league_gold_monthly',
        'name_tr': 'Altın Lig Aylık Ödülü',
        'name_en': 'Gold League Monthly Award',
      });
      final podium = AvatarCharacter.byId('league_bronze_weekly');
      expect(champion.isChampionAward, isTrue);
      expect(champion.isPodiumAward, isFalse);
      expect(podium.isPodiumAward, isTrue);
      // Sunucudaki "Haftalık/Aylık" adı dönemle uyuşmadığı için kullanılmaz.
      expect(champion.getName(true), 'Altın Lig Şampiyonluk Ödülü');
      expect(champion.getName(false), 'Gold League Champion Award');
      expect(podium.getName(true), 'Bronz Lig Podyum Ödülü');
      expect(podium.getName(false), 'Bronze League Podium Award');
      expect(AvatarCharacter.byId('avatar_9_viking').getName(true), 'Viking Kum Saati');
    });

    test('is_league_award kolonu yoksa lig ödülü kimlik önekinden tanınır', () {
      final award = AvatarCharacter.fromMap(const {
        'id': 'league_gold_weekly',
        'name_tr': 'Altın',
        'name_en': 'Gold',
        'asset_key': 'assets/avatars/league_gold_weekly.png',
        'cost_coins': 0,
        'is_premium_only': false,
        'is_default': false,
      });
      expect(award.isLeagueAward, isTrue);
      expect(award.isFree, isFalse);
      expect(award.isOwned(const []), isFalse);
      expect(award.canAfford(100000), isFalse);

      final explicit = AvatarCharacter.fromMap(const {'id': 'league_x', 'is_league_award': false});
      expect(explicit.isLeagueAward, isFalse, reason: 'sunucu değeri önceliklidir');
    });

    test('0 kum tanesi ama varsayılan olmayan avatar ücretsiz sayılmaz (sahiplik kaydı gerekir)', () {
      AvatarCharacter.setCachedAvatars(const [
        AvatarCharacter(id: 'zero_cost', nameTr: 'Z', nameEn: 'Z', imagePath: 'z.png'),
        AvatarCharacter(id: kDefaultAvatarId, nameTr: 'B', nameEn: 'B', imagePath: 'b.png', isDefault: true),
      ]);
      expect(AvatarCharacter.isFreeAvatarId('zero_cost'), isFalse);
      expect(AvatarCharacter.byId('zero_cost').isOwned(const []), isFalse);
      expect(AvatarCharacter.byId('zero_cost').isOwned(const ['zero_cost']), isTrue);
      expect(AvatarCharacter.isFreeAvatarId(kDefaultAvatarId), isTrue);
    });
  });

  test('toMap/fromMap gidiş-dönüşü (katalog önbelleği)', () {
    final original = AvatarCharacter.byId('avatar_11_doctor');
    final copy = AvatarCharacter.fromMap(original.toMap());
    expect(copy.toMap(), original.toMap());
  });
}
