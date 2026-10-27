import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/l10n/app_localizations_en.dart';
import 'package:pomodoro/l10n/app_localizations_tr.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/league_rules.dart';
import 'package:pomodoro/services/league_backend.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart';
import 'package:pomodoro/widgets/social/league_rule_texts.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const policyConfig = {
  'policy_version': 1,
  'league_room_capacity': 25,
  'league_launch_min_active_users': 25,
  'league_promotion_min_active_members': 3,
  'league_qualification_min_days': 3,
  'league_qualification_min_minutes': 300,
  'league_award_min_members': 10,
  'league_award_min_points': 1,
  'league_promotion_min_points': 1,
  'competition_phase': 'active',
};

Map<String, dynamic> row({
  String phase = 'active',
  bool? promotion = false,
  bool? award = false,
  bool? demotion = false,
  bool isMe = true,
  int points = 100,
}) => {
  'id': isMe ? 'me' : 'other',
  'name': 'Üye',
  'tier': 2,
  'is_me': isMe,
  'weekly_points': points,
  'member_count': 25,
  'active_member_count': 12,
  'promotion_zone_end': 4,
  'demotion_zone_start': 22,
  'competition_phase': phase,
  'competition_starts_at': null,
  'room_capacity': 25,
  'has_league': true,
  'promotion_eligible': ?promotion,
  'award_eligible': ?award,
  'demotion_eligible': ?demotion,
};

LeagueSnapshot snapshot(List<Map<String, dynamic>> rows) =>
    LeagueSnapshot.fromRows(
      rows,
      rules: LeagueRules.fromAppConfig(policyConfig),
    );

const _screenshots = bool.fromEnvironment('SCREENSHOTS');
const _captureDir = 'analiz/ekranlar/20261008_league_launch';

Future<void> _loadFonts() async {
  final exe = Platform.resolvedExecutable;
  final marker = '${Platform.pathSeparator}bin${Platform.pathSeparator}cache';
  final index = exe.indexOf(marker);
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      (index > 0 ? exe.substring(0, index) : '');
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.view((await File('$fonts/$name').readAsBytes()).buffer);
  final roboto = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
  ]) {
    roboto.addFont(read(name));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String filename,
) async {
  if (!_screenshots) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_captureDir).createSync(recursive: true);
    File(
      '$_captureDir/$filename.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(_loadFonts);
  group('Lig RPC ileri/geri uyumluluğu', () {
    final missing = PostgrestException(
      message: 'RPC missing',
      code: 'PGRST202',
    );
    for (final (label, fetch, primary, legacy) in [
      (
        'sıralama',
        fetchLeagueRankingResponse,
        'get_my_league_ranking_v2',
        'get_my_league_ranking',
      ),
      (
        'kurallar',
        fetchLeagueRulesResponse,
        'get_league_config',
        'get_app_config',
      ),
    ]) {
      test('$label: yeni yanıt kullanılır, eski RPC çağrılmaz', () async {
        final calls = <String>[];
        final result = await fetch((name) async {
          calls.add(name);
          return {'new': true};
        });
        expect(result, {'new': true});
        expect(calls, [primary]);
      });
      test('$label: yalnız PGRST202 eski sunucuya düşer', () async {
        final calls = <String>[];
        final result = await fetch((name) async {
          calls.add(name);
          if (name == primary) throw missing;
          return {'legacy': true};
        });
        expect(result, {'legacy': true});
        expect(calls, [primary, legacy]);
      });
      for (final (name, error) in [
        ('izin', PostgrestException(message: 'denied', code: '42501')),
        ('ağ', StateError('network unavailable')),
      ]) {
        test('$label: $name hatası eski kuralla başarıya çevrilmez', () async {
          final calls = <String>[];
          await expectLater(
            fetch((rpc) async {
              calls.add(rpc);
              throw error;
            }),
            throwsA(same(error)),
          );
          expect(calls, [primary]);
        });
      }
    }
  });

  group('Kurallar ve sıralama anındaki sunucu durumu', () {
    test('eski RPC varsayılanı 30 / aktif ve eski ödül eşiğidir', () {
      final old = LeagueRules.fromAppConfig({'league_award_min_members': 1});
      expect(old.hasLaunchPolicy, isFalse);
      expect(old.roomCapacity, 30);
      expect(old.isCompetitionActive, isTrue);
      expect(old.awardMinMembers, 1);
    });
    test('yeni yapılandırma 25 kişi ve hazırlık kurallarını taşır', () {
      final rules = LeagueRules.fromAppConfig({
        ...policyConfig,
        'competition_phase': 'preparing',
      });
      expect(rules.roomCapacity, 25);
      expect(rules.launchMinActiveUsers, 25);
      expect(rules.awardMinMembers, 10);
      expect(rules.qualificationMinDays, 3);
      expect(rules.qualificationMinMinutes, 300);
      expect(rules.isCompetitionActive, isFalse);
    });
    test('kapasite daha sonra 30 yapılınca istemci yeni değeri okur', () {
      expect(
        LeagueRules.fromAppConfig({
          ...policyConfig,
          'league_room_capacity': 30,
        }).roomCapacity,
        30,
      );
    });
    test('sayı olmayan/sonsuz eşikler ve bilinmeyen aşama güvenli okunur', () {
      final rules = LeagueRules.fromAppConfig({
        ...policyConfig,
        'league_room_capacity': double.infinity,
        'league_award_min_members': -3,
        'competition_phase': 'unrecognized',
      });
      expect(rules.roomCapacity, 25);
      expect(rules.awardMinMembers, 1);
      expect(rules.competitionPhase, 'preparing');
      expect(rules.isCompetitionActive, isFalse);
    });
    test(
      'yeni sıralama aşaması 30 saniyelik eski yapılandırmayı geçersiz kılar',
      () {
        final league = snapshot([
          row(phase: 'preparing', promotion: true, award: true, demotion: true),
        ]);
        expect(league.rules.competitionPhase, 'preparing');
        expect(league.activeMemberCount, 12);
        expect(league.zoneOf(1, 100), LeagueZone.none);
        expect(league.earnsAward(1, 100), isFalse);
        expect(league.demotionCount, 0);
      },
    );
    test(
      'v2 satırı konfigürasyon hatasında eski tek kişilik ödül şartını kullanmaz',
      () {
        final league = LeagueSnapshot.fromRows([
          row(),
        ], rules: LeagueRules.standard);
        expect(league.rules.hasLaunchPolicy, isTrue);
        expect(league.rules.awardMinMembers, 10);
        expect(league.rules.roomCapacity, 25);
        expect(league.earnsAward(1, 100), isFalse);
      },
    );
    test(
      'sıralamanın kendi yapılandırması bayat/okunamayan kurallardan önceliklidir',
      () {
        final league = LeagueSnapshot.fromRows([
          {
            ...row(isMe: false),
            'league_config': {
              ...policyConfig,
              'league_award_min_members': 12,
              'league_qualification_min_days': 4,
              'league_qualification_min_minutes': 400,
              'league_room_capacity': 30,
            },
          },
          {...row(), 'room_capacity': 30},
        ], rules: LeagueRules.standard);
        expect(league.rules.awardMinMembers, 12);
        expect(league.rules.qualificationMinDays, 4);
        expect(league.rules.qualificationMinMinutes, 400);
        expect(league.rules.roomCapacity, 30);
      },
    );
    test('planlama tarihi ve 25→30 kapasite değişimi satırdan alınır', () {
      final league = snapshot([
        {
          ...row(phase: 'scheduled'),
          'room_capacity': 30,
          'competition_starts_at': '2026-10-19T21:00:00Z',
        },
      ]);
      expect(league.rules.roomCapacity, 30);
      expect(league.rules.competitionStartsAt, DateTime.utc(2026, 10, 19, 21));
      expect(league.zoneOf(1, 100), LeagueZone.none);
    });
    test(
      'has_league false geçmiş puanı olsa bile ilk seans yerleşmesini bekler',
      () {
        final league = snapshot([
          {...row(), 'has_league': false, 'member_count': 0},
        ]);
        expect(league.awaitingPlacement, isTrue);
        expect(league.isPromotionRank(1, 100), isFalse);
      },
    );
  });

  group('Uygunluk sunucudan gelir; puan tek başına yeterli değildir', () {
    test(
      'çok puanlı ilk sıranın günü/dakikası eksikse ödül veya terfi gösterilmez',
      () {
        final league = snapshot([
          row(promotion: false, award: false, points: 1000),
        ]);
        expect(league.isPromotionRank(1, 1000), isFalse);
        expect(league.earnsAward(1, 1000), isFalse);
        expect(league.zoneOf(1, 1000), LeagueZone.none);
      },
    );
    test('uygun kişi terfi ve avatar önizlemesi alır', () {
      final league = snapshot([row(promotion: true, award: true)]);
      expect(league.zoneOf(1, 100), LeagueZone.promotion);
      expect(league.earnsAward(1, 100), isTrue);
    });
    test('uygunluk alanı gelmeyen yeni satır puandan hak tahmin etmez', () {
      final league = snapshot([
        row(promotion: null, award: null, demotion: null),
      ]);
      expect(league.zoneOf(1, 100), LeagueZone.none);
      expect(league.earnsAward(1, 100), isFalse);
      expect(league.isDemotionRank(25), isFalse);
    });
    test('son 3 günde katılan yüksek sıra numaralı kişi düşme rengi almaz', () {
      final entry = RankingEntry.fromRow(
        row(demotion: false),
        pointsKey: 'weekly_points',
      );
      expect(snapshot([row()]).zoneOf(25, 0, entry: entry), LeagueZone.none);
    });
    test('sunucunun düşme hakkı verdiği satır düşme rengini taşır', () {
      final entry = RankingEntry.fromRow(
        row(demotion: true),
        pointsKey: 'weekly_points',
      );
      expect(
        snapshot([row()]).zoneOf(25, 0, entry: entry),
        LeagueZone.demotion,
      );
    });
    test('gizleme kimliği siler ama uygunluk ve sıra kaybolmaz', () {
      final hidden = RankingEntry.fromRow(
        row(promotion: true, award: true, demotion: false),
        pointsKey: 'weekly_points',
      ).asHidden();
      expect(hidden.name, isNull);
      expect(hidden.userId, isNull);
      expect(hidden.hidden, isTrue);
      expect(hidden.points, 100);
      expect(hidden.promotionEligible, isTrue);
      expect(hidden.awardEligible, isTrue);
      expect(hidden.demotionEligible, isFalse);
      expect(
        snapshot([row()]).zoneOf(1, hidden.points, entry: hidden),
        LeagueZone.promotion,
      );
      expect(
        snapshot([row()]).earnsAward(1, hidden.points, entry: hidden),
        isTrue,
      );
    });
    test('hazırlıkta bozuk true uygunluk bayrağı bile ödül göstermez', () {
      final entry = RankingEntry.fromRow(
        row(promotion: true, award: true),
        pointsKey: 'weekly_points',
      );
      final league = snapshot([row(phase: 'preparing')]);
      expect(league.zoneOf(1, 100, entry: entry), LeagueZone.none);
      expect(league.earnsAward(1, 100, entry: entry), isFalse);
    });
  });

  for (final (locale, l10n) in [
    ('tr', AppLocalizationsTr()),
    ('en', AppLocalizationsEn()),
  ]) {
    test(
      '$locale: hazırlık, aktif kota ve avatar açıklamaları gün/minut/aktif şartını anlatır',
      () {
        final rules = LeagueRules.fromAppConfig(policyConfig);
        final prep = rules.withRankingStatus(row(phase: 'preparing'));
        expect(leaguePreparationText(l10n, prep), contains('25'));
        expect(
          promotionDemotionText(l10n, snapshot([row(phase: 'preparing')])),
          l10n.leaguePreparationNoChanges,
        );
        expect(promotionDemotionText(l10n, snapshot([row()])), contains('4'));
        final awards = leagueAwardsSubText(l10n, rules);
        expect(awards, contains('10'));
        expect(awards, contains('3'));
        expect(awards, contains('300'));
        final locked = leagueAwardLockedText(
          l10n,
          AvatarCharacter.byId('league_gold_monthly'),
          rules,
        );
        expect(locked, contains('300'));
        expect(locked, contains('10'));
        expect(l10n.onboardingGuideRankingBody, isNot(contains('30')));
      },
    );

    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
      const Size(600, 960),
      const Size(820, 1180),
      const Size(1180, 820),
    ]) {
      testWidgets(
        '$locale: lig rehberi ${size.width}×${size.height} büyük yazıda taşmaz',
        (tester) async {
          SupabaseService.instance.debugCloudActive = false;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                theme: AppTheme.lightTheme,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: LeagueInfoSheet(
                    league: snapshot([row(phase: 'preparing')]),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(l10n.leagueInfoWhatBodyWithCapacity(25)),
            findsOneWidget,
          );
          final captureCase =
              (locale == 'tr' && size == const Size(390, 844)) ||
              (locale == 'en' && size == const Size(844, 390));
          if (captureCase) {
            await _capture(
              tester,
              boundaryKey,
              'league-launch-$locale-${size.width.toInt()}x${size.height.toInt()}-guide-top',
            );
          }
          await tester.scrollUntilVisible(
            find.text(l10n.leagueInfoPromotionTitle),
            400,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          if (captureCase) {
            await _capture(
              tester,
              boundaryKey,
              'league-launch-$locale-${size.width.toInt()}x${size.height.toInt()}-guide-policy',
            );
          }
          await tester.drag(find.byType(ListView), const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'podyum: yeni sunucuda puanlı ancak uygun olmayan ilk 3 madalya almaz',
    (tester) async {
      final rows = [row(isMe: true), row(isMe: false), row(isMe: false)];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RankingStandings(
              league: snapshot(rows),
              entries: [
                for (final r in rows)
                  RankingEntry.fromRow(r, pointsKey: 'weekly_points'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      for (var rank = 1; rank <= 3; rank++) {
        expect(find.byKey(ValueKey('podium-medal-$rank')), findsNothing);
      }
    },
  );
}
