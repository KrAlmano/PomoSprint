// İstemci ↔ sunucu önerileri 20–25: uygulamanın GERÇEK ayrıştırma ve karar
// kodu (lib/), iki yerel sunucuya gerçek HTTP ile:
//  - ESKİ = ana yerel kopya (canlıyla eşit; parity_check.sh): http://127.0.0.1:54321
//  - YENİ = zincir (12 → … → 14) + 20–25 uygulanmış kopya. Giriş (Auth) ana
//    kopyada; REST istekleri kopyaya bağlı PostgREST'e yönlendirilir. Kayıt
//    olan kullanıcının auth.users satırı kopyaya aktarılır (kopyadaki
//    handle_new_user tetiklenir: yeni sunucuda kayıt gibi).
//
// Hazırlık (yalnızca yerel kopya açıkken; normal `flutter test` bunu almaz):
//   CHAIN_DB=pomosprint_chain_client NO_DOWN=1 KEEP_DB=1 REST_PORT=54331 \
//     tool/local_supabase/proposed_chain_check.sh
//   flutter test tool/local_supabase/e2e/client_compat/client_compat_e2e_test.dart
//   CHAIN_DB=pomosprint_chain_client DROP_ONLY=1 tool/local_supabase/proposed_chain_check.sh
// Ortam: CHAIN_DB (vars. pomosprint_chain_client), CHAIN_REST_URL (vars.
// http://127.0.0.1:54331). Kopya yoksa YENİ grubu atlanır.
//
// Kendi hesaplarını açar (compat-<zaman>-…@pomosprint.local) ve sonda iki
// veritabanından da siler; test1/test2'ye dokunmaz. Ana kopyanın şeması
// değişmez (yalnızca bu hesapların verisi yazılıp silinir).
//
// Dosya test/ dışında: analizör @visibleForTesting üyelerini test saymıyor.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:pomodoro/l10n/app_localizations_tr.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/league_rules.dart';
import 'package:pomodoro/screens/friends_sheet.dart' show friendResponseCode;
import 'package:pomodoro/services/avatar_equip.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/service_errors.dart';
import 'package:pomodoro/utils/friend_code.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart' show promotionDemotionText;
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'http://127.0.0.1:54321';
const _anon =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9'
    '.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const _password = 'pomosprint-yerel-test';
const _pg = 'postgresql://postgres:postgres@127.0.0.1:54322';

final _chainDb = Platform.environment['CHAIN_DB'] ?? 'pomosprint_chain_client';
final _chainRest = Platform.environment['CHAIN_REST_URL'] ?? 'http://127.0.0.1:54331';
final _stamp = DateTime.now().millisecondsSinceEpoch;
final _l10n = AppLocalizationsTr();

/// /rest/v1/* isteklerini zincir kopyasının PostgREST'ine yönlendirir; Auth
/// istekleri ana kopyada kalır (aynı JWT anahtarı).
class _RestRouter extends http.BaseClient {
  _RestRouter(this._rest);
  final Uri _rest;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final url = request.url;
    if (!url.path.startsWith('/rest/v1/')) return _inner.send(request);
    if (request is! http.Request) throw StateError('beklenmeyen istek türü: ${request.runtimeType}');
    final target = url.replace(
      scheme: _rest.scheme,
      host: _rest.host,
      port: _rest.port,
      path: url.path.substring('/rest/v1'.length),
    );
    final copy = http.Request(request.method, target)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..bodyBytes = request.bodyBytes;
    return _inner.send(copy);
  }
}

Future<String> _psql(String db, String sql) async {
  final r = await Process.run('psql', ['$_pg/$db', '-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-c', sql]);
  if (r.exitCode != 0) throw StateError('psql $db: ${r.stderr}');
  return (r.stdout as String).trim();
}

class _Backend {
  _Backend(this.label, {required this.db, this.restUrl});
  final String label;
  final String db;
  final String? restUrl;
  bool get isNew => restUrl != null;
  final List<String> users = [];
  final List<String> leagues = [];

  Future<(SupabaseClient, String)> newUser(String tag) async {
    final client = SupabaseClient(
      _url,
      _anon,
      httpClient: restUrl == null ? null : _RestRouter(Uri.parse(restUrl!)),
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    final email = 'compat-$_stamp-${isNew ? 'yeni' : 'eski'}-$tag@pomosprint.local';
    final res = await client.auth.signUp(email: email, password: _password, data: {
      'name': 'Compat ${isNew ? 'Yeni' : 'Eski'} $tag',
      'avatar_id': 'avatar_16_basic',
      'newsletter': false,
      'marketing_consent': false,
      'terms_version': '2026-10-03',
      'privacy_version': '2026-10-03',
      'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
    });
    final uid = res.user!.id;
    users.add(uid);
    if (isNew) {
      // Ana kopyadaki auth.users satırı kopyaya: kopyanın handle_new_user'ı
      // (13/14 gövdesi) profili kurar.
      final row = await _psql('postgres', "select row_to_json(u)::text from auth.users u where id = '$uid'");
      await _psql(db, '''
        insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                                raw_app_meta_data, raw_user_meta_data, created_at, updated_at, is_sso_user, is_anonymous)
        select instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
               raw_app_meta_data, raw_user_meta_data, created_at, updated_at, is_sso_user, is_anonymous
          from json_populate_record(null::auth.users, \$j\$$row\$j\$::json)''');
    }
    return (client, uid);
  }

  Future<void> cleanup() async {
    if (users.isEmpty) return;
    final ids = users.map((u) => "'$u'").join(',');
    for (final database in {db, 'postgres'}) {
      await _psql(database, 'delete from auth.users where id in ($ids)');
    }
    if (leagues.isNotEmpty) {
      await _psql(db, 'delete from public.leagues where id in (${leagues.map((l) => "'$l'").join(',')})');
    }
  }
}

/// SupabaseService._guard gibi: ham hata ServiceException'a sarılır.
Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    throw ServiceException.wrap(e);
  }
}

/// SupabaseService.getLeagueRules ile aynı karar.
Future<LeagueRules> _readRules(SupabaseClient client) async {
  try {
    return LeagueRules.fromAppConfigResponse(await client.rpc('get_app_config'));
  } catch (e) {
    if (isMissingRpcError(e)) return LeagueRules.standard;
    rethrow;
  }
}

Future<Map<String, dynamic>> _profile(SupabaseClient client, String uid) async =>
    Map<String, dynamic>.from(await client
        .from('profiles')
        .select('avatar_id, coins, lifetime_points, friend_code, league_tier, onboarding_completed_at')
        .eq('id', uid)
        .single());

Future<List<CourseCategory>> _categories(SupabaseClient client, String uid) async {
  final rows = await client
      .from('categories')
      .select('id, name, color_hex, icon_name, sort_order, is_archived')
      .eq('user_id', uid)
      .order('sort_order')
      .order('created_at')
      .order('id');
  return [for (final r in rows) CourseCategory.fromServerRow(Map<String, dynamic>.from(r))];
}

/// SupabaseService'in onboarding uzlaştırmasıyla aynı yazımlar.
Future<OnboardingCategoriesResult?> _reconcile(
  SupabaseClient client,
  String uid,
  List<Map<String, dynamic>> requested, {
  required bool canArchive,
}) =>
    reconcileOnboardingCategories(
      requested: requested,
      fetchAll: () => _categories(client, uid),
      canArchive: () async => canArchive,
      archive: (id) => client.from('categories').update({'is_archived': true}).eq('id', id).eq('user_id', uid),
      unarchive: (id) => client.from('categories').update({'is_archived': false}).eq('id', id).eq('user_id', uid),
      setup: (payload) async => OnboardingCategoriesResult.fromResponse(
        await client.rpc('setup_onboarding_categories', params: {'p_categories': payload}),
      ),
    );

Set<String> _activeNames(List<CourseCategory> cats) => {for (final c in cats) if (!c.isArchived) c.name};

Future<Map<String, dynamic>> _addFriend(SupabaseClient client, String typed) async =>
    Map<String, dynamic>.from(await client.rpc('add_friend_by_code', params: {'p_code': normalizeFriendCode(typed)}) as Map);

void main() {
  late bool chainReady;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      final r = await http.get(Uri.parse('$_chainRest/'));
      chainReady = r.statusCode == 200 && (await _psql(_chainDb, "select to_regprocedure('public.rotate_friend_code()') is not null")) == 't';
    } catch (_) {
      chainReady = false;
    }
  });

  final backends = [
    _Backend('ESKİ (canlı = ana yerel kopya)', db: 'postgres'),
    _Backend('YENİ (zincir + 20–25)', db: _chainDb, restUrl: _chainRest),
  ];

  for (final b in backends) {
    group(b.label, () {
      setUpAll(() {
        if (b.isNew && !chainReady) {
          // ignore: avoid_print
          print('ATLANDI: zincir kopyası yok; önce proposed_chain_check.sh (REST_PORT ile)');
        }
      });
      tearDownAll(b.cleanup);

      bool skip() => b.isNew && !chainReady;

      test('6) get_app_config: eskide PGRST202 → bugünkü kural; yenide 20 anahtarları', () async {
        if (skip()) return;
        final (client, _) = await b.newUser('kural');
        if (!b.isNew) {
          await expectLater(client.rpc('get_app_config'), throwsA(predicate(isMissingRpcError)));
        }
        final rules = await _readRules(client);
        expect(rules.fromServer, b.isNew);
        expect([rules.awardMinMembers, rules.awardMinPoints, rules.promotionMinPoints], [1, 1, 1]);
        expect(rules, b.isNew ? const LeagueRules(fromServer: true) : LeagueRules.standard);
      });

      test('3) ligsiz kullanıcı: "henüz odada değilsin" (eski member_count 1, yeni 0)', () async {
        if (skip()) return;
        final (client, uid) = await b.newUser('ligsiz');
        final rows = [for (final r in await client.rpc('get_my_league_ranking') as List) Map<String, dynamic>.from(r as Map)];
        expect(rows, hasLength(1));
        expect(rows.single['member_count'], b.isNew ? 0 : 1);
        final profile = await _profile(client, uid);
        final league = LeagueSnapshot.fromRows(
          rows,
          rules: await _readRules(client),
          hasLeagueHistory: (profile['lifetime_points'] as int) > 0,
        );
        expect(league.awaitingPlacement, isTrue);
        expect(league.isAloneInRoom, isFalse);
        expect(promotionDemotionText(_l10n, league), _l10n.leagueAwaitingPlacementBody);
      });

      test('3) t4-F6: terfi edip yeni odasında tek ve puansız kalan "odanda yalnızsın" görür', () async {
        if (skip()) return;
        final (client, uid) = await b.newUser('yalniz');
        // Sunucu durumu: kademe 3'te yeni açılmış odada tek üye, 0 puan;
        // geçmiş dönemlerden ömür boyu puanı var.
        final leagueId = await _psql(b.db, '''
          update public.profiles set league_tier = 3, lifetime_points = 40 where id = '$uid';
          with l as (insert into public.leagues (tier, end_date) values (3, now() + interval '10 days') returning id)
          insert into public.league_memberships (league_id, user_id, weekly_points)
          select id, '$uid', 0 from l returning league_id''');
        b.leagues.add(leagueId);
        final rows = [for (final r in await client.rpc('get_my_league_ranking') as List) Map<String, dynamic>.from(r as Map)];
        expect(rows.single['member_count'], 1);
        expect(rows.single['tier'], 3);
        final profile = await _profile(client, uid);
        final rules = await _readRules(client);
        final league = LeagueSnapshot.fromRows(rows, rules: rules, hasLeagueHistory: (profile['lifetime_points'] as int) > 0);
        expect(league.awaitingPlacement, isFalse);
        expect(league.isAloneInRoom, isTrue);
        expect(promotionDemotionText(_l10n, league), isNot(_l10n.leagueAwaitingPlacementBody));
        // Yeni sunucuda kural sunucudan geldiği için geçmiş bilinmese de doğru.
        expect(LeagueSnapshot.fromRows(rows, rules: rules, hasLeagueHistory: false).isAloneInRoom, b.isNew);
      });

      test('2) onboarding yeniden denenir: uzlaşır, seçimdeki kategori arşive gitmez', () async {
        if (skip()) return;
        final (client, uid) = await b.newUser('onb');
        // 1. deneme (TR): kategoriler kuruldu, profil yazılamadı.
        final first = await _reconcile(client, uid, categorySeedPayload(['Matematik', 'Okuma'], turkish: true),
            canArchive: true);
        expect(first == null, !b.isNew, reason: 'eski sunucu void, 23 jsonb');
        if (b.isNew) expect(first!.created, 2);
        // 2. deneme (EN): Matematik (= Mathematics) ve Fizik seçildi.
        final second = await _reconcile(client, uid, categorySeedPayload(['Matematik', 'Fizik'], turkish: false),
            canArchive: true);
        final cats = await _categories(client, uid);
        expect(_activeNames(cats), {'Matematik', 'Physics'});
        expect({for (final c in cats) if (c.isArchived) c.name}, {'Okuma'});
        if (b.isNew) {
          expect(second!.created, 1);
          expect(second.skippedLimit, 0);
          expect(second.archived, 0, reason: 'aktif kalacaklar yükte: 23 arşivlemez');
        } else {
          expect(second, isNull);
        }
      });

      test('2) neden: yalnız eksikler gönderilseydi 23 seçimdeki kategoriyi arşivlerdi', () async {
        if (skip()) return;
        final (client, uid) = await b.newUser('onb-eksik');
        await client.rpc('setup_onboarding_categories', params: {
          'p_categories': categorySeedPayload(['Matematik', 'Okuma'], turkish: true),
        });
        final okuma = (await _categories(client, uid)).firstWhere((c) => c.name == 'Okuma');
        await client.from('categories').update({'is_archived': true}).eq('id', okuma.id);
        // Eski istemcinin yükü: yalnızca eksik 'Fizik'.
        await client.rpc('setup_onboarding_categories', params: {
          'p_categories': categorySeedPayload(['Fizik'], turkish: true),
        });
        final active = _activeNames(await _categories(client, uid));
        expect(active.contains('Matematik'), !b.isNew);
      });

      test('2) skipped_limit: limit doluyken seçilenler (yenide sayı döner, eskide sessiz)', () async {
        if (skip()) return;
        final (client, uid) = await b.newUser('limit');
        const yks = ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe'];
        await _reconcile(client, uid, categorySeedPayload(yks, turkish: true), canArchive: true);
        // Kuyrukta seans var (arşivleme yok): iki yeni seçim limite takılır.
        final result = await _reconcile(client, uid, categorySeedPayload(['Derin Çalışma', 'Okuma'], turkish: true),
            canArchive: false);
        final cats = await _categories(client, uid);
        expect(_activeNames(cats), yks.toSet());
        if (b.isNew) {
          expect(result!.skippedLimit, 2);
          expect(result.archived, 0);
          expect(_l10n.onboardingCategoriesSkippedLimit(result.skippedLimit, 8), contains('2'));
        } else {
          expect(result, isNull, reason: 'canlı sunucu sonucu bildirmez: bilgi gösterilmez');
        }
      });

      test('1) yeni hata metinleri anlaşılır koda çevrilir (eskide kabul edilir)', () async {
        if (skip()) return;
        final (client, uid) = await b.newUser('hata');
        Future<ServiceErrorCode?> codeOf(Future<Object?> Function() call) async {
          try {
            await call();
            return null;
          } catch (e) {
            return serviceErrorCodeOf(e);
          }
        }

        final color = await codeOf(() => client.rpc('create_category',
            params: {'p_name': 'Renk Testi', 'p_color_hex': 'kirmizi', 'p_icon_name': 'book'}));
        final icon = await codeOf(() => client.rpc('create_category',
            params: {'p_name': 'İkon Testi', 'p_color_hex': '#EF4444', 'p_icon_name': 'Kötü-İkon'}));
        await client.rpc('create_category', params: {'p_name': 'Matematik', 'p_color_hex': '#EF4444', 'p_icon_name': 'book'});
        final duplicate = await codeOf(() => client.rpc('create_category',
            params: {'p_name': 'matematik', 'p_color_hex': '#3B82F6', 'p_icon_name': 'book'}));
        final underAge = await codeOf(() => client.from('profiles').update({
              'birth_year': DateTime.now().year - 5,
              'daily_goal_minutes': 60,
              'show_in_social_feed': false,
              'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', uid).select('id'));
        if (b.isNew) {
          expect(color, ServiceErrorCode.categoryColorInvalid);
          expect(icon, ServiceErrorCode.categoryIconInvalid);
          expect(duplicate, ServiceErrorCode.categoryNameExists);
          expect(underAge, ServiceErrorCode.underMinimumAge);
        } else {
          expect([color, icon, duplicate, underAge], [null, null, null, null],
              reason: 'canlı bunları doğrulamıyor (t2-05, t2-06)');
        }
      });

      test('4) t4-F9: kaydı olmayan varsayılan avatar kuşanılır, kum harcanmaz', () async {
        if (skip()) return;
        final (client, uid) = await b.newUser('avatar');
        // Kataloğa sonradan eklenmiş varsayılan avatar: sahiplik kaydı yok.
        await _psql(b.db, "delete from public.avatar_unlocks where user_id = '$uid' and avatar_id = 'avatar_2_glasses'");
        final coinsBefore = (await _profile(client, uid))['coins'] as int;
        final unlockedByClient = await equipAvatarWithDefaultUnlock(
          avatarId: 'avatar_2_glasses',
          equip: () => _guard(() => client.rpc('set_equipped_avatar', params: {'p_avatar_id': 'avatar_2_glasses'})),
          unlockFree: () => _guard(() => client.rpc('purchase_avatar', params: {'p_avatar_id': 'avatar_2_glasses'})),
        );
        expect(unlockedByClient, !b.isNew, reason: '22 öncesi istemci kaydı açar; 22 sonrası sunucu');
        final profile = await _profile(client, uid);
        expect(profile['avatar_id'], 'avatar_2_glasses');
        expect(profile['coins'], coinsBefore);
        expect(
          await _psql(b.db, "select count(*) from public.avatar_unlocks where user_id = '$uid' and avatar_id = 'avatar_2_glasses'"),
          '1',
        );

        // Ücretli avatar: kilitli hatası aynen döner, satın alınmaz.
        final calls = <String>[];
        await expectLater(
          equipAvatarWithDefaultUnlock(
            avatarId: 'avatar_1_gamer',
            equip: () => _guard(() => client.rpc('set_equipped_avatar', params: {'p_avatar_id': 'avatar_1_gamer'})),
            unlockFree: () async => calls.add('unlock'),
          ),
          throwsA(isA<ServiceException>().having((e) => e.code, 'code', ServiceErrorCode.avatarLocked)),
        );
        expect(calls, isEmpty);
      });

      test('5) arkadaş kodu: yazım biçimi normalize edilir; code alanı (yeni) ya da mesaj (eski)', () async {
        if (skip()) return;
        final (a, aId) = await b.newUser('arkadas-a');
        final (bClient, _) = await b.newUser('arkadas-b');
        final bCode = (await _profile(bClient, (bClient.auth.currentUser!.id)))['friend_code'] as String;
        expect(isValidFriendCode(bCode), isTrue, reason: 'eski 6 hex / yeni Crockford');
        // Kullanıcının yazdığı: küçük harf, tire, boşluk; 0/1 yerine O/L.
        final typed = ' ${bCode.substring(0, 3)}-${bCode.substring(3)} '.toLowerCase().replaceAll('0', 'o').replaceAll('1', 'l');
        expect(normalizeFriendCode(typed), bCode);

        final sent = await _addFriend(a, typed);
        expect(sent['success'], isTrue, reason: '$sent');
        expect(sent['auto_accepted'], isFalse);
        expect(sent['code'], b.isNew ? 'request_sent' : isNull);
        expect((sent['friend'] as Map).containsKey('id'), !b.isNew, reason: '13: kabulden önce id yok');

        final accepted = Map<String, dynamic>.from(
            await bClient.rpc('respond_friend_request', params: {'p_from_user_id': aId, 'p_accept': true}) as Map);
        expect(accepted['success'], isTrue);
        expect(accepted['code'], b.isNew ? 'accepted' : isNull);

        expect(friendResponseCode(await _addFriend(a, typed)), 'already_friends');
        final ownCode = (await _profile(a, aId))['friend_code'] as String;
        expect(friendResponseCode(await _addFriend(a, ownCode)), 'self_add');
        expect(friendResponseCode(await _addFriend(a, 'ZZZZZZ')), 'not_found');

        // 13: saatte 20 deneme; eskide sınır yok.
        String? last;
        for (var i = 0; i < 20 && last != 'rate_limited'; i++) {
          last = friendResponseCode(await _addFriend(a, 'ZZZZZZ'));
        }
        expect(last, b.isNew ? 'rate_limited' : 'not_found');
      });
    });
  }
}
