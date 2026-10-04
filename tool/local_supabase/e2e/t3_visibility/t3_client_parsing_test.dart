// t3: istemcinin sosyal RPC yanıtlarını GERÇEK sunucu çıktısıyla ayrıştırması.
//
//   python3 tool/local_supabase/e2e/t3_visibility/t3_capture_fixtures.py
//   flutter test tool/local_supabase/e2e/t3_visibility/t3_client_parsing_test.dart
//
// fixtures.json yerel Supabase kopyasından alınır (lig/aylık satırları geri
// alınan transaction'da üretilir).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/hidden_users.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fx = jsonDecode(File('tool/local_supabase/e2e/t3_visibility/fixtures.json').readAsStringSync())
      as Map<String, dynamic>;
  List<Map<String, dynamic>> rows(String key) =>
      (fx[key] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  final uids = Map<String, String>.from(fx['uids'] as Map);
  final names = Map<String, String>.from(fx['names'] as Map);

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageService.instance.setLanguage(AppLanguage.tr));

  test('lig: get_my_league_ranking satırları → tek is_me, LeagueSnapshot sunucu değerleri', () {
    final r = rows('league');
    final entries = [for (final row in r) RankingEntry.fromRow(row, pointsKey: 'weekly_points')];
    expect(entries.where((e) => e.isMe).length, 1);
    expect(entries.firstWhere((e) => e.isMe).name, names['A']);
    expect(entries.every((e) => e.userId == null), isTrue, reason: 'lig RPC kimlik döndürmez');
    final snap = LeagueSnapshot.fromRows(r);
    expect(snap.memberCount, r.length);
    expect(snap.tier, r.first['tier']);
    expect(snap.endDate, DateTime.parse(r.first['end_date'] as String));
    expect(snap.promotionZoneEnd, r.first['promotion_zone_end']);
    expect(snap.demotionZoneStart, r.first['demotion_zone_start']);
    expect(snap.myPoints, r.firstWhere((x) => x['is_me'] == true)['weekly_points']);
    expect(snap.awaitingPlacement, isFalse);
  });

  test('aylık: total_points okunur, yalnızca is_me ile ben; anon adları maskeli', () {
    final m = [for (final row in rows('monthly')) RankingEntry.fromRow(row, pointsKey: 'total_points')];
    expect(m.where((e) => e.isMe).map((e) => e.name), [names['A']]);
    expect(m.every((e) => e.points >= 0 && e.minutes != null), isTrue);
    final anon = rows('monthly_anon');
    expect(anon.every((x) => x['is_me'] == false), isTrue);
    expect(anon.map((x) => x['name']), isNot(contains(names['B'])));
  });

  test('arkadaşlar: get_my_friends → userId, lifetime_points; gelen istek id = gönderen', () {
    final f = [for (final row in rows('friends_A')) RankingEntry.fromRow(row, pointsKey: 'lifetime_points')];
    expect(f.map((e) => e.userId).toSet(), {uids['B'], uids['D']});
    expect(f.every((e) => !e.isMe), isTrue);
    final inc = rows('incoming_A');
    expect(inc.single['id'], uids['C']);
  });

  test('canlı: get_live_friends satırı kategori adını gösterir; gizleme id ile çalışır', () async {
    final live = rows('live_A');
    expect(live.map((x) => x['id']).toSet(), {uids['B'], uids['D']});
    await LanguageService.instance.setLanguage(AppLanguage.en);
    final en = lookupAppLocalizations(const Locale('en'));
    final b = live.firstWhere((x) => x['id'] == uids['B']);
    expect(SocialScreen.liveStatusText(b, en), en.socialFocusingOn('Mathematics'));
    final hidden = HiddenUserList([HiddenUser(id: uids['B'], name: 'başka ad')]);
    expect(SocialScreen.withoutHidden(live, hidden).map((x) => x['id']), [uids['D']]);
  });

  test('yanıt sözleşmesi: sunucu add/respond yanıtlarında makine-okunur code YOK', () {
    // friends_sheet.dart `result['code']` ile not_found/already_friends dallarını
    // seçiyor; canlı/yerel sunucu bu alanı hiç döndürmüyor.
    for (final key in ['add_already_friends', 'add_not_found', 'respond_gone']) {
      final r = Map<String, dynamic>.from(fx[key] as Map);
      expect(r['success'], isFalse, reason: key);
      expect(r.containsKey('code'), isFalse, reason: key);
      expect(r['message'], isA<String>(), reason: key);
    }
  });

  test('Apple: ad bilgisi yoksa e-postanın yerel kısmı profil adı olarak KALIR (EM1 istemci tarafı)', () {
    // handle_new_user adı 'erdal.yilmaz.1987' yaptı (bkz. t3_rollback_test EM1).
    final update = SupabaseService.providerFirstNameUpdate(
      currentName: 'erdal.yilmaz.1987',
      email: 'erdal.yilmaz.1987@icloud.com',
      provider: 'apple',
      metadata: const <String, dynamic>{},
      onboardingCompleted: false,
      givenName: null, // Apple adı yalnızca ilk yetkilendirmede verir
    );
    expect(update, isNull, reason: 'istemci adı düzeltmiyor; ad herkese açık listede maskesiz kalıyor');
  });
}
