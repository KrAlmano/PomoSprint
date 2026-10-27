// Sunucu önerileri 20–25 (supabase/proposed/README.md "Öneriler 20–25") ile
// ileriye uyumlu istemci. Her senaryo iki yanıt biçimiyle sınanır:
//  - ESKİ: bugünkü canlı sunucu (= tool/local_supabase ana kopyası);
//  - YENİ: zincir (12 → … → 14) + 20–25 uygulanmış sunucu
//    (tool/local_supabase/proposed_chain_check.sh kopyası).
// Biçimler yerel kopyalardan alındı; uçtan uca sınama:
// tool/local_supabase/e2e/client_compat/client_compat_e2e_test.dart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/l10n/app_localizations_en.dart';
import 'package:pomodoro/l10n/app_localizations_tr.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/league_rules.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/categories_management_screen.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/avatar_equip.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/friend_code.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart';
import 'package:pomodoro/widgets/social/league_rule_texts.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:pomodoro/widgets/social/social_error_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'support/fake_supabase_service.dart';

final tr = AppLocalizationsTr();
final en = AppLocalizationsEn();

PostgrestException _pg(String message, String code) =>
    PostgrestException(message: message, code: code);

CourseCategory _cat(String id, String name, {bool archived = false}) =>
    CourseCategory.fromServerRow({
      'id': id,
      'name': name,
      'color_hex': '#EF4444',
      'icon_name': 'book',
      'is_archived': archived,
    });

/// get_my_league_ranking'in ligsiz satırı. Eski: member_count 1 (tek
/// kişilik gerçek odayla aynı). Yeni (14 + 20): id, is_blocked ve
/// member_count 0.
Map<String, dynamic> _unplacedRow({required bool newServer}) => {
  'name': 'Ben',
  'avatar_id': 'avatar_16_basic',
  'weekly_points': 0,
  'tier': 2,
  'end_date': '2026-10-18T20:59:59+00:00',
  'is_me': true,
  'promotion_zone_end': 1,
  'demotion_zone_start': 999,
  'member_count': newServer ? 0 : 1,
  if (newServer) ...{'id': 'u-1', 'is_blocked': false},
};

/// Terfi edip yeni odasında tek kalan (puansız) kullanıcının satırı:
/// iki sunucuda da member_count 1.
Map<String, dynamic> _aloneRow({required bool newServer, int points = 0}) => {
  ..._unplacedRow(newServer: newServer),
  'weekly_points': points,
  'member_count': 1,
};

const _newRules = {
  'server_time': '2026-10-05T10:00:00Z',
  'config_schema': 1,
  'friend_code_length': 6,
  'league_award_min_members': 1,
  'league_award_min_points': 1,
  'league_promotion_min_points': 1,
  'unverified_session_daily_cap': null,
};

void main() {
  group('1) yeni hata metinleri (23514) anlaşılır koda çevrilir', () {
    test('23: renk / ikon, 24: 13 yaş, 13: ad içerik denetimi', () {
      expect(
        serviceErrorCodeOf(_pg('category_color_invalid', '23514')),
        ServiceErrorCode.categoryColorInvalid,
      );
      expect(
        serviceErrorCodeOf(_pg('category_icon_invalid', '23514')),
        ServiceErrorCode.categoryIconInvalid,
      );
      expect(
        serviceErrorCodeOf(_pg('birth_year_under_minimum_age', '23514')),
        ServiceErrorCode.underMinimumAge,
      );
      expect(
        serviceErrorCodeOf(_pg('profile_name_not_allowed', '23514')),
        ServiceErrorCode.nameNotAllowed,
      );
      expect(
        serviceErrorCodeOf(_pg('category_name_not_allowed', '23514')),
        ServiceErrorCode.nameNotAllowed,
      );
      // Servis sarmalı da aynı kodu taşır.
      expect(
        serviceErrorCodeOf(
          ServiceException.wrap(_pg('category_color_invalid', '23514')),
        ),
        ServiceErrorCode.categoryColorInvalid,
      );
    });

    test(
      'bugünkü metinler değişmedi (23 çift adı 23505 ile aynı metni verir)',
      () {
        expect(
          serviceErrorCodeOf(
            _pg('Bu isimde aktif bir kategori zaten var.', '23505'),
          ),
          ServiceErrorCode.categoryNameExists,
        );
        expect(
          serviceErrorCodeOf(
            _pg(
              'Ücretsiz planda en fazla 8 kategori ekleyebilirsin. Premium ile 15\'e çıkar.',
              'P0001',
            ),
          ),
          ServiceErrorCode.categoryLimitReached,
        );
        expect(
          serviceErrorCodeOf(_pg('Bu avatar kilitli.', 'P0001')),
          ServiceErrorCode.avatarLocked,
        );
        expect(
          serviceErrorCodeOf(_pg('new row violates check constraint', '23514')),
          ServiceErrorCode.invalidInput,
        );
      },
    );

    test('sosyal metin yeni kodlarda genel metne düşer (çökmez)', () {
      for (final code in [
        ServiceErrorCode.categoryColorInvalid,
        ServiceErrorCode.categoryIconInvalid,
        ServiceErrorCode.underMinimumAge,
      ]) {
        expect(
          socialErrorText(tr, ServiceException(code)),
          tr.socialErrGeneric,
        );
      }
    });

    test('PGRST202 (RPC sunucuda yok) tanınır', () {
      expect(
        isMissingRpcError(
          _pg(
            'Could not find the function public.get_app_config without parameters',
            'PGRST202',
          ),
        ),
        isTrue,
      );
      expect(isMissingRpcError(_pg('x', 'P0001')), isFalse);
      expect(isMissingRpcError(StateError('x')), isFalse);
    });

    testWidgets(
      'Kategorilerim: sunucu rengi reddederse "renk kullanılamıyor" denir',
      (tester) async {
        final l10n = await _pumpCategories(
          tester,
          _pg('category_color_invalid', '23514'),
        );
        expect(find.text(l10n.categoryColorInvalidMsg), findsOneWidget);
        expect(find.text(l10n.categorySaveError), findsNothing);
      },
    );

    testWidgets(
      'Kategorilerim: ad içerik denetimi (13) "Bu ad uygun değil" der',
      (tester) async {
        final l10n = await _pumpCategories(
          tester,
          _pg('category_name_not_allowed', '23514'),
        );
        expect(find.text(l10n.nameNotAllowed), findsOneWidget);
      },
    );
  });

  group('2) setup_onboarding_categories: void (eski) ve jsonb (23)', () {
    test('eski sunucu void döndürür: sonuç bilinmez', () {
      expect(OnboardingCategoriesResult.fromResponse(null), isNull);
      expect(OnboardingCategoriesResult.fromResponse(''), isNull);
    });

    test('23 sayıları okunur', () {
      final r = OnboardingCategoriesResult.fromResponse(const {
        'created': 2,
        'restored': 1,
        'skipped_existing': 3,
        'skipped_limit': 4,
        'skipped_invalid': 0,
        'archived': 5,
      })!;
      expect(
        [
          r.created,
          r.restored,
          r.skippedExisting,
          r.skippedLimit,
          r.skippedInvalid,
          r.archived,
        ],
        [2, 1, 3, 4, 0, 5],
      );
      expect(
        OnboardingCategoriesResult.fromResponse(const {
          'created': 1,
        })!.skippedLimit,
        0,
      );
    });

    test(
      'uzlaştırma yükü aktif kalacakları da taşır (23 onları arşivlemesin)',
      () {
        // Önceki deneme: Okuma, Matematik (aktif), Fizik (arşivde). Yeni seçim:
        // Matematik, Fizik, Proje. 23 onboarding bitmemişken yükte olmayan
        // seansız aktif kategoriyi arşivler: yalnızca 'Proje' gönderilseydi
        // Matematik ve geri açılan Fizik sunucuda arşive giderdi.
        final plan = planOnboardingCategories(
          requested: categorySeedPayload([
            'Matematik',
            'Fizik',
            'Proje',
          ], turkish: true),
          existing: [
            _cat('o', 'Okuma'),
            _cat('m', 'Matematik'),
            _cat('f', 'Fizik', archived: true),
          ],
          canArchive: true,
        );
        expect(plan.archiveIds, ['o']);
        expect(plan.unarchiveIds, ['f']);
        expect([for (final p in plan.payload) p['name']], ['Proje']);
        expect(
          [for (final p in plan.rpcPayload) p['name']],
          ['Proje', 'Matematik', 'Fizik'],
        );
        for (final item in plan.rpcPayload) {
          expect(
            item['color_hex'],
            matches(RegExp(r'^#[0-9A-Fa-f]{6}$')),
            reason: '23 renk doğrular',
          );
          expect(
            item['icon_name'],
            matches(RegExp(r'^[a-z0-9_]{1,40}$')),
            reason: '23 ikon doğrular',
          );
        }
      },
    );

    test(
      'arşivlenemeyen (seanslı) hesapta tüm aktifler korunur; dil değişse de ad sunucudaki gibi',
      () {
        final plan = planOnboardingCategories(
          requested: categorySeedPayload([
            'Matematik',
            'Derin Çalışma',
          ], turkish: false),
          existing: [_cat('m', 'Matematik'), _cat('k', 'Kimya')],
          canArchive: false,
        );
        expect([for (final p in plan.payload) p['name']], ['Deep Work']);
        expect(
          [for (final p in plan.rpcPayload) p['name']],
          ['Deep Work', 'Matematik', 'Kimya'],
        );
      },
    );

    test(
      'yazma sırası: arşivle → arşivden aç → eksikler + aktif kalacaklar; sonuç döner',
      () async {
        final calls = <String>[];
        const serverResult = OnboardingCategoriesResult(
          created: 1,
          skippedExisting: 2,
        );
        final result = await reconcileOnboardingCategories(
          requested: categorySeedPayload([
            'Matematik',
            'Fizik',
            'Proje',
          ], turkish: true),
          fetchAll: () async => [
            _cat('o', 'Okuma'),
            _cat('m', 'Matematik'),
            _cat('f', 'Fizik', archived: true),
          ],
          canArchive: () async => true,
          archive: (id) async => calls.add('archive $id'),
          unarchive: (id) async => calls.add('unarchive $id'),
          setup: (payload) async {
            calls.add(
              'setup ${[for (final p in payload) p['name']].join(',')}',
            );
            return serverResult;
          },
        );
        expect(calls, [
          'archive o',
          'unarchive f',
          'setup Proje,Matematik,Fizik',
        ]);
        expect(result, same(serverResult));

        // Hiç kategori yoksa istenenler olduğu gibi; arşiv sorusu sorulmaz.
        calls.clear();
        await reconcileOnboardingCategories(
          requested: categorySeedPayload(['Okuma'], turkish: true),
          fetchAll: () async => const [],
          canArchive: () async => throw StateError('sorulmamalı'),
          archive: (id) async => calls.add('archive $id'),
          unarchive: (id) async => calls.add('unarchive $id'),
          setup: (payload) async {
            calls.add(
              'setup ${[for (final p in payload) p['name']].join(',')}',
            );
            return null;
          },
        );
        expect(calls, ['setup Okuma']);
      },
    );

    test('eksik yoksa çağrı yapılmaz (yük boş)', () {
      final plan = planOnboardingCategories(
        requested: categorySeedPayload(['Matematik'], turkish: false),
        existing: [_cat('m', 'Matematik')],
        canArchive: true,
      );
      expect(plan.payload, isEmpty);
      expect(plan.rpcPayload, isEmpty);
    });

    testWidgets('skipped_limit > 0 ise bilgi verilir', (tester) async {
      final service = _OnboardingFake(
        result: const OnboardingCategoriesResult(created: 3, skippedLimit: 2),
      );
      final l10n = await _finishOnboarding(tester, service);
      expect(service.completed, 1);
      expect(
        find.text(l10n.onboardingCategoriesSkippedLimit(2, 8)),
        findsOneWidget,
      );
    });

    for (final (label, result) in [
      ('eski sunucu (void, sonuç yok)', null),
      ('23, atlanan yok', const OnboardingCategoriesResult(created: 3)),
    ]) {
      testWidgets('$label: bilgi yok', (tester) async {
        final service = _OnboardingFake(result: result);
        final l10n = await _finishOnboarding(tester, service);
        expect(service.completed, 1);
        expect(
          find.textContaining(
            l10n.onboardingCategoriesSkippedLimit(2, 8).split('(').first,
          ),
          findsNothing,
        );
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets(
      '24: sunucu 13 yaş altı derse yaş adımına dönülür ve yıl kilitlenir',
      (tester) async {
        final service = _OnboardingFake(
          error: _pg('birth_year_under_minimum_age', '23514'),
        );
        final l10n = await _finishOnboarding(tester, service);
        expect(find.text('1/7'), findsOneWidget);
        expect(find.text(l10n.onboardingUnder13Error), findsWidgets);
        expect(find.text(l10n.onboardingSaveError), findsNothing);
        expect(
          find.text(l10n.deleteAccount),
          findsOneWidget,
          reason: 'yaş sınırı görünümü (çıkış / hesap silme)',
        );
      },
    );
  });

  group('3) ligsiz satır: eski (member_count 1) ve yeni (member_count 0)', () {
    test('gerçekten ligsiz: iki biçimde de "henüz odada değilsin"', () {
      final oldRow = LeagueSnapshot.fromRows([
        _unplacedRow(newServer: false),
      ], hasLeagueHistory: false);
      final newRow = LeagueSnapshot.fromRows(
        [_unplacedRow(newServer: true)],
        rules: LeagueRules.fromAppConfig(_newRules),
        hasLeagueHistory: false,
      );
      for (final league in [oldRow, newRow]) {
        expect(league.awaitingPlacement, isTrue);
        expect(league.isAloneInRoom, isFalse);
        expect(
          promotionDemotionText(tr, league),
          tr.leagueAwaitingPlacementBody,
        );
      }
      // Yeni biçimde member_count 0 kesin: puan geçmişi olsa da (ör. önbellek) ligsiz.
      expect(
        LeagueSnapshot.fromRows([
          _unplacedRow(newServer: true),
        ], hasLeagueHistory: true).awaitingPlacement,
        isTrue,
      );
    });

    test(
      't4-F6: terfi edip yeni odasında tek kalan "henüz odada değilsin" görmez',
      () {
        // Eski sunucu: satır ligsizle aynı; ömür boyu puanı olan kullanıcı bir odadadır.
        final oldAlone = LeagueSnapshot.fromRows([
          _aloneRow(newServer: false),
        ], hasLeagueHistory: true);
        // Yeni sunucu: kural sunucudan okundu (20 uygulanmış) → 1 gerçek oda.
        final newAlone = LeagueSnapshot.fromRows(
          [_aloneRow(newServer: true)],
          rules: LeagueRules.fromAppConfig(_newRules),
          hasLeagueHistory: false,
        );
        for (final league in [oldAlone, newAlone]) {
          expect(league.awaitingPlacement, isFalse);
          expect(league.isAloneInRoom, isTrue);
          expect(
            promotionDemotionText(tr, league),
            isNot(tr.leagueAwaitingPlacementBody),
          );
        }
      },
    );

    test(
      'kural ve geçmiş bilinmiyorsa bugünkü kural (tek kişi + puansız = ligsiz)',
      () {
        expect(
          LeagueSnapshot.fromRows([
            _aloneRow(newServer: false),
          ]).awaitingPlacement,
          isTrue,
        );
        expect(
          LeagueSnapshot.fromRows([
            _aloneRow(newServer: false, points: 5),
          ]).awaitingPlacement,
          isFalse,
        );
      },
    );

    test('has_league alanı gelirse ona uyulur', () {
      expect(
        LeagueSnapshot.fromRows([
          {..._aloneRow(newServer: true), 'has_league': false},
        ], hasLeagueHistory: true).awaitingPlacement,
        isTrue,
      );
      expect(
        LeagueSnapshot.fromRows([
          {..._unplacedRow(newServer: false), 'has_league': true},
        ]).isAloneInRoom,
        isTrue,
      );
    });

    testWidgets(
      'lig sekmesi: ligsiz → yerleşme metni; odada yalnız → "odanda yalnızsın"',
      (tester) async {
        final l10n = await _pumpStandings(
          tester,
          LeagueSnapshot.fromRows([_unplacedRow(newServer: true)]),
          points: 0,
        );
        expect(find.text(l10n.leagueAwaitingPlacementTitle), findsOneWidget);
        expect(find.text(l10n.leagueAloneInRoomTitle), findsNothing);

        await _pumpStandings(
          tester,
          LeagueSnapshot.fromRows([
            _aloneRow(newServer: false),
          ], hasLeagueHistory: true),
          points: 0,
        );
        expect(find.text(l10n.leagueAwaitingPlacementTitle), findsNothing);
        expect(find.text(l10n.leagueAloneInRoomTitle), findsOneWidget);

        // Odada yalnız ama puanlı: podyum gösterilir; ayrı sıra/terfi bandı yoktur.
        await _pumpStandings(
          tester,
          LeagueSnapshot.fromRows([_aloneRow(newServer: false, points: 12)]),
          points: 12,
        );
        expect(find.text(l10n.leagueAloneInRoomTitle), findsNothing);
        expect(find.text(l10n.rankingMyStatus(1, 12)), findsNothing);
        expect(find.byType(RankingPodium), findsOneWidget);
      },
    );

    test('hasLeagueHistory: ömür boyu puanı olan kullanıcı', () {
      expect(hasLeagueHistory(null), isNull);
      expect(
        hasLeagueHistory(UserModel(id: 'u', name: 'A', email: 'a@b.c')),
        isFalse,
      );
      expect(
        hasLeagueHistory(
          UserModel(id: 'u', name: 'A', email: 'a@b.c', lifetimePoints: 5),
        ),
        isTrue,
      );
    });
  });

  group('4) varsayılan avatar: 22 öncesi kilitli yanıtına istemci çözümü', () {
    setUp(AvatarCharacter.clearCachedAvatars);

    test('22 sonrası: ilk kuşanma başarılı, satın alma çağrılmaz', () async {
      final calls = <String>[];
      final unlocked = await equipAvatarWithDefaultUnlock(
        avatarId: 'avatar_2_glasses',
        equip: () async => calls.add('equip'),
        unlockFree: () async => calls.add('unlock'),
      );
      expect(unlocked, isFalse);
      expect(calls, ['equip']);
    });

    test(
      '22 öncesi: kaydı olmayan varsayılan avatar bedelsiz açılır ve kuşanılır (t4-F9)',
      () async {
        final calls = <String>[];
        var locked = true;
        final unlocked = await equipAvatarWithDefaultUnlock(
          avatarId: 'avatar_2_glasses',
          equip: () async {
            calls.add('equip');
            if (locked) {
              throw ServiceException.wrap(_pg('Bu avatar kilitli.', 'P0001'));
            }
          },
          unlockFree: () async {
            calls.add('unlock');
            locked = false;
          },
        );
        expect(unlocked, isTrue);
        expect(calls, ['equip', 'unlock', 'equip']);
      },
    );

    test(
      'ücretli / Premium / lig ödülü avatarda kum harcanmaz, hata aynen döner',
      () async {
        for (final id in [
          'avatar_1_gamer',
          'avatar_11_doctor',
          'league_gold_weekly',
          'bilinmeyen_avatar',
        ]) {
          final calls = <String>[];
          await expectLater(
            equipAvatarWithDefaultUnlock(
              avatarId: id,
              equip: () async => throw ServiceException.wrap(
                _pg('Bu avatar kilitli.', 'P0001'),
              ),
              unlockFree: () async => calls.add('unlock'),
            ),
            throwsA(
              isA<ServiceException>().having(
                (e) => e.code,
                'code',
                ServiceErrorCode.avatarLocked,
              ),
            ),
          );
          expect(calls, isEmpty, reason: id);
        }
      },
    );

    test('kilitli dışındaki hata (ağ) yeniden denenmez', () async {
      final calls = <String>[];
      await expectLater(
        equipAvatarWithDefaultUnlock(
          avatarId: 'avatar_2_glasses',
          equip: () async =>
              throw const ServiceException(ServiceErrorCode.network),
          unlockFree: () async => calls.add('unlock'),
        ),
        throwsA(isA<ServiceException>()),
      );
      expect(calls, isEmpty);
    });

    test(
      'isFreeDefaultAvatar: yalnızca katalogdaki bedelsiz varsayılanlar',
      () {
        expect(isFreeDefaultAvatar('avatar_16_basic'), isTrue);
        expect(isFreeDefaultAvatar('avatar_9_viking'), isFalse);
        expect(
          isFreeDefaultAvatar('tomato_basic'),
          isFalse,
          reason: 'katalogda yok (canlıda pasif)',
        );
      },
    );
  });

  group('5) arkadaş kodu: eski 6 hex ve yeni Crockford (6–8)', () {
    test('normalizeFriendCode sunucudaki normalize_friend_code ile aynı', () {
      expect(normalizeFriendCode(' ab-12 cd '), 'AB12CD');
      expect(normalizeFriendCode('a1b2.c3_d4'), 'A1B2C3D4');
      expect(normalizeFriendCode('OIL0il'), '011011');
      expect(normalizeFriendCode('7f3a9c'), '7F3A9C', reason: 'eski hex kod');
    });

    test('isValidFriendCode: 6–8 karakter, Crockford alfabesi', () {
      expect(isValidFriendCode('7F3A9C'), isTrue);
      expect(isValidFriendCode('K7M2QX9Z'), isTrue);
      expect(isValidFriendCode('K7M2Q'), isFalse);
      expect(isValidFriendCode('K7M2QX9ZA'), isFalse);
      expect(
        isValidFriendCode('ABCDEU'),
        isFalse,
        reason: 'U Crockford alfabesinde yok',
      );
    });

    test(
      'girdi biçimlendiricisi: yapıştırılan kod temizlenir, 8 karakterde kesilir',
      () {
        const f = FriendCodeInputFormatter();
        TextEditingValue run(String text) => f.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: text),
        );
        expect(run('k7m2-qx9z').text, 'K7M2QX9Z');
        expect(run('k7m2 qx9z 55').text, 'K7M2QX9Z');
        expect(run('ab!c?d').text, 'ABCD');
        expect(run('olu').text, '01', reason: 'O→0, L→1, U atılır');
      },
    );

    testWidgets('8 karakterlik yeni kod kabul edilir ve normalize gönderilir', (
      tester,
    ) async {
      final service = _FriendsFake()
        ..addResult = const {
          'success': true,
          'code': 'request_sent',
          'auto_accepted': false,
          'friend': {'name': 'Zeynep', 'avatar_id': 'avatar_16_basic'},
        };
      final l10n = await _pumpFriends(tester, service);
      await tester.enterText(find.byType(TextField), 'k7m2-qx9z');
      await tester.pump();
      expect(find.text('K7M2QX9Z'), findsOneWidget);
      await tester.tap(find.text(l10n.addBtn));
      await tester.pumpAndSettle();
      expect(service.sentCodes, ['K7M2QX9Z']);
      expect(find.text(l10n.friendsRequestSent('Zeynep')), findsOneWidget);
    });

    testWidgets('eski 6 hex kod çalışır (canlı yanıt: code yok)', (
      tester,
    ) async {
      final service = _FriendsFake()
        ..addResult = const {
          'success': true,
          'auto_accepted': true,
          'friend': {
            'id': 'f-1',
            'name': 'Ali',
            'avatar_id': 'avatar_16_basic',
            'lifetime_points': 5,
            'total_minutes': 25,
          },
        };
      final l10n = await _pumpFriends(tester, service);
      await tester.enterText(find.byType(TextField), '7f3a9c');
      await tester.tap(find.text(l10n.addBtn));
      await tester.pumpAndSettle();
      expect(service.sentCodes, ['7F3A9C']);
      expect(find.text(l10n.friendsAdded('Ali')), findsOneWidget);
    });

    testWidgets(
      'kısa kod sunucuya gönderilmez (13 denemeyi saatlik sınıra sayar)',
      (tester) async {
        final service = _FriendsFake();
        final l10n = await _pumpFriends(tester, service);
        await tester.enterText(find.byType(TextField), 'ab12');
        await tester.tap(find.text(l10n.addBtn));
        await tester.pumpAndSettle();
        expect(service.sentCodes, isEmpty);
        expect(find.text(l10n.friendsErrInvalidCode), findsOneWidget);
      },
    );

    testWidgets('kendi kodu normalize karşılaştırılır', (tester) async {
      final service = _FriendsFake();
      final l10n = await _pumpFriends(tester, service);
      await tester.enterText(find.byType(TextField), 'abc-123');
      await tester.tap(find.text(l10n.addBtn));
      await tester.pumpAndSettle();
      expect(service.sentCodes, isEmpty);
      expect(find.text(l10n.friendsErrSelf), findsOneWidget);
    });

    group('13/14 kodları İngilizcede yerelleştirilir', () {
      final cases = <String, String Function(AppLocalizations)>{
        'rate_limited': (l) => l.friendsErrRateLimited,
        'cooldown': (l) => l.friendsErrCooldown,
        'blocked': (l) => l.friendsErrBlocked,
        'not_found': (l) => l.friendsErrNotFound,
        'self_add': (l) => l.friendsErrSelf,
      };
      for (final MapEntry(key: code, value: expected) in cases.entries) {
        testWidgets(code, (tester) async {
          final service = _FriendsFake()
            ..addResult = {
              'success': false,
              'code': code,
              'message': 'Türkçe mesaj',
            };
          final l10n = await _pumpFriends(
            tester,
            service,
            locale: const Locale('en'),
          );
          await tester.enterText(find.byType(TextField), 'K7M2QX');
          await tester.tap(find.text(l10n.addBtn));
          await tester.pumpAndSettle();
          expect(find.text(expected(l10n)), findsOneWidget);
        });
      }
    });

    testWidgets(
      "respond_friend_request 14 yanıtı ('code': 'not_found') bayat istek sayılır",
      (tester) async {
        final service = _FriendsFake()
          ..respondResult = const {
            'success': false,
            'code': 'not_found',
            'message': 'x',
          };
        final l10n = await _pumpFriends(tester, service);
        await tester.tap(find.byTooltip(l10n.friendsAccept));
        await tester.pumpAndSettle();
        expect(find.text(l10n.friendsRequestGone), findsOneWidget);
      },
    );
  });

  group('6) lig ödül/terfi kuralı (get_app_config; yoksa bugünkü kural)', () {
    test('eski sunucu / anahtar yok → bugünkü kural', () {
      expect(LeagueRules.fromAppConfigResponse(null), LeagueRules.standard);
      final chainOnly = LeagueRules.fromAppConfig(const {
        'config_schema': 1,
        'friend_code_length': 6,
      });
      expect(chainOnly, LeagueRules.standard, reason: '13 var, 20 yok');
      expect(chainOnly.fromServer, isFalse);
    });

    test(
      '20 varsayılanları (1/1/1) = bugünkü kural, sunucudan geldiği bilinir',
      () {
        final rules = LeagueRules.fromAppConfig(_newRules);
        expect(
          [
            rules.awardMinMembers,
            rules.awardMinPoints,
            rules.promotionMinPoints,
          ],
          [1, 1, 1],
        );
        expect(rules.fromServer, isTrue);
      },
    );

    test(
      'sunucunun okuma kuralı: sayı değilse ya da < 1 ise 1, kesir aşağı',
      () {
        final rules = LeagueRules.fromAppConfig(const {
          'league_award_min_members': '3',
          'league_award_min_points': 0,
          'league_promotion_min_points': 25.9,
        });
        expect(
          [
            rules.awardMinMembers,
            rules.awardMinPoints,
            rules.promotionMinPoints,
          ],
          [1, 1, 25],
        );
      },
    );

    const proposed = LeagueRules(
      awardMinMembers: 3,
      awardMinPoints: 25,
      promotionMinPoints: 25,
      fromServer: true,
    );
    LeagueSnapshot room({required LeagueRules rules, int members = 4}) =>
        LeagueSnapshot(
          tier: 2,
          endDate: null,
          promotionZoneEnd: 2,
          demotionZoneStart: 999,
          memberCount: members,
          myPoints: 10,
          rules: rules,
        );

    test('isPromotionRank / zoneOf / earnsAward kurala göre', () {
      final today = room(rules: LeagueRules.standard);
      expect(today.isPromotionRank(1, 1), isTrue);
      expect(today.isPromotionRank(1, 0), isFalse);
      expect(today.earnsAward(3, 1), isTrue);

      final strict = room(rules: proposed);
      expect(strict.isPromotionRank(1, 24), isFalse);
      expect(strict.isPromotionRank(1, 25), isTrue);
      expect(strict.zoneOf(1, 24), LeagueZone.promotionNeedsPoints);
      expect(strict.zoneOf(2, 30), LeagueZone.promotion);
      expect(strict.earnsAward(1, 24), isFalse);
      expect(strict.earnsAward(1, 25), isTrue);
      expect(strict.earnsAward(4, 99), isFalse);
      expect(
        room(rules: proposed, members: 2).earnsAward(1, 99),
        isFalse,
        reason: 'odada en az 3 üye',
      );
    });

    test('metinler: bugünkü kuralda eski metin birebir, eşik varsa sayılı', () {
      expect(
        leagueInfoPromoteText(tr, 3, LeagueRules.standard),
        tr.leagueInfoPromote(3),
      );
      expect(
        leagueInfoPromoteText(tr, 3, proposed),
        tr.leagueInfoPromoteMinPoints(3, 25),
      );
      expect(
        promotionDemotionText(tr, room(rules: proposed)),
        startsWith(tr.leagueInfoPromoteMinPoints(2, 25)),
      );
      expect(
        promotionNeedsPointsText(tr, LeagueRules.standard),
        tr.rankingZoneNeedsPointsMe,
      );
      expect(
        promotionNeedsPointsText(tr, proposed),
        tr.rankingZoneNeedsMinPointsMe(25),
      );

      expect(leagueAwardsSubText(en, LeagueRules.standard), en.leagueAwardsSub);
      expect(
        leagueAwardsSubText(en, proposed),
        '${en.leagueAwardsSubMinPoints(25)} ${en.leagueAwardMinMembersNote(3)}',
      );

      final champion = AvatarCharacter.byId('league_gold_monthly');
      final podium = AvatarCharacter.byId('league_gold_weekly');
      expect(
        leagueAwardLockedText(tr, champion, LeagueRules.standard),
        tr.leagueAwardLockedBodyChampion,
      );
      expect(
        leagueAwardLockedText(tr, podium, LeagueRules.standard),
        tr.leagueAwardLockedBodyPodium,
      );
      expect(
        leagueAwardLockedText(tr, champion, proposed),
        '${tr.leagueAwardLockedBodyChampionMinPoints(25)} ${tr.leagueAwardMinMembersNote(3)}',
      );
      expect(
        leagueAwardLockedText(
          tr,
          podium,
          const LeagueRules(awardMinPoints: 10),
        ),
        tr.leagueAwardLockedBodyPodiumMinPoints(10),
      );
    });

    testWidgets('podyum madalyası kurala uyar, sıra ve terfi bandı gösterilmez', (
      tester,
    ) async {
      final l10n = await _pumpStandings(
        tester,
        room(rules: proposed),
        points: 24,
        others: [30, 20, 5],
      );
      // [30, 24(ben), 20, 5]: 25 puan eşiği → yalnız 1. ödül alır; ben terfi bölgesinde ama puanım yetmiyor.
      expect(find.byKey(const ValueKey('podium-medal-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('podium-medal-2')), findsNothing);
      expect(find.byKey(const ValueKey('podium-medal-3')), findsNothing);
      expect(find.text(l10n.rankingMyStatus(2, 24)), findsNothing);
      expect(find.text(l10n.rankingZoneNeedsMinPointsMe(25)), findsNothing);
      expect(find.text(l10n.rankingZonePromotionChip), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

Future<AppLocalizations> _pumpCategories(
  WidgetTester tester,
  Object serverError,
) async {
  SharedPreferences.setMockInitialValues({});
  await LanguageService.instance.setLanguage(AppLanguage.tr);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final service = FakeSupabaseService()
    ..allCategories = [_cat('a', 'Fizik'), _cat('b', 'Matematik')];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CategoriesManagementScreen(service: service),
    ),
  );
  await tester.pumpAndSettle();
  final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  await tester.tap(find.byIcon(Icons.edit).first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Fizik Lab');
  await tester.pump();
  service.mutationError = serverError;
  await tester.tap(find.text(l10n.save));
  await tester.pumpAndSettle();
  return l10n;
}

Future<AppLocalizations> _pumpStandings(
  WidgetTester tester,
  LeagueSnapshot league, {
  required int points,
  List<int> others = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final entries = [
    for (final (i, p) in ([
      ...others,
      points,
    ]..sort((a, b) => b.compareTo(a))).indexed)
      RankingEntry(name: 'Üye ${i + 1}', points: p, isMe: p == points),
  ];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RankingStandings(entries: entries, league: league),
        ),
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.delegate.load(const Locale('tr'));
}

class _FriendsFake extends FakeSupabaseService {
  Map<String, dynamic> addResult = const {'success': true};
  Map<String, dynamic> respondResult = const {'success': true};
  final List<String> sentCodes = [];

  @override
  Future<String?> getMyFriendCode() async => 'ABC123';

  @override
  Future<List<Map<String, dynamic>>> fetchFriends() async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchPendingFriendRequests() async => [
    {
      'id': 'a-1',
      'name': 'Ali',
      'avatar_id': 'avatar_16_basic',
      'lifetime_points': 0,
      'total_minutes': 0,
    },
  ];

  @override
  Future<Map<String, dynamic>> addFriendByCode(String code) async {
    sentCodes.add(code);
    return addResult;
  }

  @override
  Future<Map<String, dynamic>> respondToFriendRequest(
    String fromUserId,
    bool accept,
  ) async => respondResult;
}

Future<AppLocalizations> _pumpFriends(
  WidgetTester tester,
  _FriendsFake service, {
  Locale locale = const Locale('tr'),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FriendsSheet(service: service)),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(locale);
}

/// Onboarding'in son adımından "Bitir"e basar; completeOnboarding sahte.
class _OnboardingFake extends FakeSupabaseService {
  _OnboardingFake({this.result, this.error})
    : super(
        user: UserModel(id: 'uid-1', name: 'Ayşe', email: 'ayse@example.com'),
      );

  final OnboardingCategoriesResult? result;
  final Object? error;
  int completed = 0;

  @override
  Future<OnboardingCategoriesResult?> completeOnboarding({
    int? birthYear,
    String? userSegment,
    required int dailyGoalMinutes,
    List<Map<String, dynamic>> categories = const [],
    required bool showInSocialFeed,
  }) async {
    completed++;
    final e = error;
    if (e != null) throw ServiceException.wrap(e);
    currentUser.value = currentUser.value!.copyWith(
      onboardingCompletedAt: DateTime.now(),
    );
    return result;
  }
}

Future<AppLocalizations> _finishOnboarding(
  WidgetTester tester,
  _OnboardingFake service,
) async {
  SharedPreferences.setMockInitialValues({
    OnboardingDraftStore.keyFor('uid-1'): jsonEncode(
      const OnboardingDraft(
        step: 6,
        birthYear: 2000,
        segment: 'yks',
        selectedCategories: ['Fizik'],
        showInRankings: false,
        dailyGoalMinutes: 60,
      ).toJson(),
    ),
  });
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PostAuthOnboardingScreen(onCompleted: () {}, service: service),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  expect(
    find.text('7/7'),
    findsOneWidget,
    reason: 'taslak son rehber adımını açtı',
  );
  await tester.tap(find.text(l10n.onboardingFinishBtn));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  // Başarıda ekran kayıt göstergesinde kalır (geçişi AppGate yapar):
  // pumpAndSettle bitmez.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return l10n;
}
