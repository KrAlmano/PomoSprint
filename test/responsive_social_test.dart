import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/character_collection_screen.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/responsive.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart';
import 'package:pomodoro/widgets/social/countdown_text.dart';
import 'package:pomodoro/widgets/social/league_tiers.dart';
import 'package:pomodoro/widgets/social/load_error_view.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sosyal, sıralama, profil ve koleksiyon parçalarının hedef ekran
// boyutlarında (telefon dikey/yatay, küçük telefon yatay, iPad dikey/yatay,
// büyük tablet) ve büyütülmüş metin ölçeğinde taşmadan çizildiğini doğrular.
// Test yazı tipi her glifi kare çizdiği için metinler gerçek cihazdan geniştir;
// burada sığan düzen cihazda rahatça sığar.
//
// Ekran testleri Supabase başlatılmadan çalışır: servis bulut kapalıyken
// istekleri hatayla döndürür, ekranlar hata/boş durumlarını çizer.

const _sizes = <String, Size>{
  'telefon dikey 390x844': Size(390, 844),
  'telefon yatay 844x390': Size(844, 390),
  'küçük telefon yatay 568x320': Size(568, 320),
  'küçük telefon dikey 320x568': Size(320, 568),
  'iPad Slide Over 320x1000': Size(320, 1000),
  'iPad Split View 507x1024': Size(507, 1024),
  'iPad dikey 820x1180': Size(820, 1180),
  'iPad yatay 1180x820': Size(1180, 820),
  'büyük tablet 1366x1024': Size(1366, 1024),
};

const _textScales = [1.0, 2.0];

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget home, {
  double textScale = 1,
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

// Zamanlayıcılı parçalar (geri sayım, canlı liste yoklaması) test bitmeden
// kaldırılır.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void _expectNoOverflow(WidgetTester tester) =>
    expect(tester.takeException(), isNull);

List<RankingEntry> _entries(int count, {int meIndex = 5}) => [
  for (var i = 0; i < count; i++)
    RankingEntry(
      name: i == 1
          ? 'Çok uzun isimli bir çalışkan kum saati kullanıcısı'
          : 'Kullanıcı ${i + 1}',
      avatarId:
          AvatarCharacter.allAvatars()[i % AvatarCharacter.allAvatars().length]
              .id,
      points: 12000 - i * 700,
      minutes: 9000 - i * 300,
      isMe: i == meIndex,
    ),
];

LeagueSnapshot _league({int memberCount = 12, int myPoints = 500}) =>
    LeagueSnapshot(
      tier: 3,
      endDate: DateTime.now().add(const Duration(days: 5, hours: 3)),
      promotionZoneEnd: 3,
      demotionZoneStart: memberCount - 2,
      memberCount: memberCount,
      myPoints: myPoints,
    );

/// Sıralama ekranının gövde düzeni (sekme çubuğu hariç): okunabilir
/// genişlikte başlık kartları, altında RankingStandings.
class _RankingBodyHost extends StatelessWidget {
  final List<RankingEntry> entries;
  final LeagueSnapshot? league;

  const _RankingBodyHost({required this.entries, this.league});

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.of(context).isShortHeight;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: compact ? 12 : 20,
          ),
          child: ContentWidth(
            maxWidth: ContentWidth.dashboard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RankingCountdownBanner(
                        title: leagueTitle(l10n, league?.tier ?? 1),
                        target: DateTime.now().add(
                          const Duration(days: 3, hours: 4),
                        ),
                        onHelp: () {},
                      ),
                      const SizedBox(height: 12),
                      StaleDataNotice(onRetry: () {}),
                    ],
                  ),
                ),
                RankingStandings(
                  entries: entries,
                  league: league,
                  compact: compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Sıralama parçaları', () {
    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('lig listesi (podyum + liste) · $name · metin x$scale', (
          tester,
        ) async {
          await _pump(
            tester,
            size,
            _RankingBodyHost(entries: _entries(12), league: _league()),
            textScale: scale,
          );
          _expectNoOverflow(tester);
          expect(find.byType(RankingPodium), findsOneWidget);
          expect(find.byType(RankingRow), findsNWidgets(9));
          final l10n = AppLocalizations.of(
            tester.element(find.byType(RankingPodium)),
          )!;
          expect(find.text(l10n.rankingMyStatus(6, 8500)), findsNothing);
          expect(find.text(l10n.rankingZonePromotionChip), findsNothing);
          await _unmount(tester);
        });

        testWidgets(
          'az kişi, yerleşim bekleniyor, boş · $name · metin x$scale',
          (tester) async {
            // Arkadaşlar sekmesi: iki kişi, podyumda boş koltuk.
            await _pump(
              tester,
              size,
              _RankingBodyHost(entries: _entries(2, meIndex: 0)),
              textScale: scale,
            );
            _expectNoOverflow(tester);
            expect(find.byType(RankingRow), findsNothing);

            await _pump(
              tester,
              size,
              _RankingBodyHost(
                entries: _entries(1, meIndex: 0),
                league: _league(memberCount: 1, myPoints: 0),
              ),
              textScale: scale,
            );
            _expectNoOverflow(tester);
            expect(find.byType(LeaguePlacementView), findsOneWidget);

            await _pump(
              tester,
              size,
              const _RankingBodyHost(entries: []),
              textScale: scale,
            );
            _expectNoOverflow(tester);
            expect(find.byType(RankingEmptyView), findsOneWidget);
            await _unmount(tester);
          },
        );
      }

      testWidgets('hata kartı ve geri sayım · $name', (tester) async {
        for (final scale in _textScales) {
          await _pump(
            tester,
            size,
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ContentWidth(
                  child: Column(
                    children: [
                      LoadErrorView(
                        message:
                            'Sıralama yüklenemedi. Bağlantını kontrol edip tekrar dene.',
                        onRetry: () {},
                      ),
                      const SizedBox(height: 12),
                      CountdownText(
                        target: DateTime.now().add(
                          const Duration(hours: 5, minutes: 7),
                        ),
                        prefix: '⏱️ ',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            textScale: scale,
          );
          _expectNoOverflow(tester);
        }
        await _unmount(tester);
      });
    }

    testWidgets(
      'geniş ekranda podyum solda, liste sağda; dikey telefonda alt alta',
      (tester) async {
        await _pump(
          tester,
          const Size(1180, 820),
          _RankingBodyHost(entries: _entries(12), league: _league()),
        );
        final podium = tester.getRect(find.byType(RankingPodium));
        final firstRow = tester.getRect(find.byType(RankingRow).first);
        expect(podium.right, lessThan(firstRow.left));
        expect(firstRow.width, lessThanOrEqualTo(ContentWidth.dashboard));

        await _pump(
          tester,
          const Size(390, 844),
          _RankingBodyHost(entries: _entries(12), league: _league()),
        );
        final podiumPortrait = tester.getRect(find.byType(RankingPodium));
        final firstRowPortrait = tester.getRect(find.byType(RankingRow).first);
        expect(podiumPortrait.bottom, lessThan(firstRowPortrait.top));
        // Dikey telefonda podyum tam boy (altın avatar 96 px).
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(RankingPodium),
                      matching: find.byType(AvatarWidget),
                    )
                    .at(1),
              )
              .width,
          96,
        );
        await _unmount(tester);
      },
    );

    testWidgets('yatay telefonda podyum küçülür', (tester) async {
      await _pump(
        tester,
        const Size(568, 320),
        _RankingBodyHost(entries: _entries(12), league: _league()),
      );
      final gold = find
          .descendant(
            of: find.byType(RankingPodium),
            matching: find.byType(AvatarWidget),
          )
          .at(1);
      expect(tester.getSize(gold).width, lessThan(96));
      await _unmount(tester);
    });
  });

  group('Avatar', () {
    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      testWidgets('avatar boyutları ve kilitli avatar · $name', (tester) async {
        final avatars = AvatarCharacter.allAvatars();
        await _pump(
          tester,
          size,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in const [
                    36.0,
                    40.0,
                    44.0,
                    54.0,
                    60.0,
                    76.0,
                    96.0,
                  ])
                    for (var i = 0; i < 3; i++)
                      AvatarWidget(
                        avatar: avatars[i % avatars.length],
                        size: s,
                        isUnlocked: i != 2,
                      ),
                ],
              ),
            ),
          ),
        );
        _expectNoOverflow(tester);
        expect(tester.getSize(find.byType(AvatarWidget).last).width, 96);
      });
    }
  });

  group('Lig bilgi sheet', () {
    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('LeagueInfoSheet · $name · metin x$scale', (tester) async {
          await _pump(
            tester,
            size,
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () =>
                        showLeagueInfoSheet(context, league: _league()),
                    child: const Text('aç'),
                  ),
                ),
              ),
            ),
            textScale: scale,
          );
          await tester.tap(find.text('aç'));
          await tester.pumpAndSettle();
          _expectNoOverflow(tester);
          expect(find.byType(LeagueInfoSheet), findsOneWidget);
          expect(
            tester.getSize(find.byType(LeagueInfoSheet)).width,
            lessThanOrEqualTo(640),
          );

          // Sheet'in sonuna kadar kaydırılır (SSS bölümü).
          await tester.drag(find.byType(ListView), const Offset(0, -3000));
          await tester.pumpAndSettle();
          _expectNoOverflow(tester);
        });
      }
    }
  });

  group('Ekranlar (bulut kapalı)', () {
    tearDown(() => SupabaseService.instance.currentUser.value = null);

    final user = UserModel(
      id: 'u1',
      name: 'Uzun İsimli Deneme Kullanıcısı',
      email: 'deneme.kullanicisi@example.com',
      coins: 150,
      lifetimePoints: 12345,
      unlockedAvatars: const ['avatar_2_glasses'],
    );

    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets(
          'RankingScreen hata durumu ve aylık sekme · $name · metin x$scale',
          (tester) async {
            await _pump(
              tester,
              size,
              RankingScreen(currentUser: user),
              textScale: scale,
            );
            _expectNoOverflow(tester);
            expect(find.byType(LoadErrorView), findsOneWidget);

            final l10n = await AppLocalizations.delegate.load(
              const Locale('tr'),
            );
            await tester.tap(find.text(l10n.rankingTabMonthly));
            await tester.pumpAndSettle();
            _expectNoOverflow(tester);
            expect(find.byType(RankingCountdownBanner), findsOneWidget);
            await _unmount(tester);
          },
        );

        testWidgets('SocialScreen hata durumu · $name · metin x$scale', (
          tester,
        ) async {
          await _pump(tester, size, const SocialScreen(), textScale: scale);
          _expectNoOverflow(tester);
          expect(find.byType(LoadErrorView), findsOneWidget);
          final card = tester.getRect(find.byType(LoadErrorView));
          expect(card.width, lessThanOrEqualTo(ContentWidth.reading));
          await _unmount(tester);
        });

        testWidgets('FriendsSheet · $name · metin x$scale', (tester) async {
          await _pump(
            tester,
            size,
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showFriendsSheet(context),
                    child: const Text('aç'),
                  ),
                ),
              ),
            ),
            textScale: scale,
          );
          await tester.tap(find.text('aç'));
          await tester.pumpAndSettle();
          _expectNoOverflow(tester);
          expect(find.byType(FriendsSheet), findsOneWidget);
          expect(
            tester.getSize(find.byType(FriendsSheet)).width,
            lessThanOrEqualTo(640),
          );

          // Klavye açıkken (yatay telefonda sheet klavyenin üstüne alınır).
          tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.45);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          _expectNoOverflow(tester);
          await tester.drag(find.byType(ListView), const Offset(0, -2000));
          await tester.pumpAndSettle();
          _expectNoOverflow(tester);
        });

        testWidgets('ProfileScreen · $name · metin x$scale', (tester) async {
          SupabaseService.instance.currentUser.value = user;
          await _pump(
            tester,
            size,
            ProfileScreen(onDarkModeChanged: (_) {}, onLogout: () {}),
            textScale: scale,
          );
          _expectNoOverflow(tester);
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          _expectNoOverflow(tester);
          // Kartlar okunabilir genişliği aşmaz.
          expect(
            tester.getSize(find.byType(SwitchListTile).first).width,
            lessThanOrEqualTo(ContentWidth.reading),
          );
        });

        testWidgets(
          'CharacterCollectionScreen ve satın alma diyaloğu · $name · metin x$scale',
          (tester) async {
            await _pump(
              tester,
              size,
              CharacterCollectionScreen(user: user),
              textScale: scale,
            );
            _expectNoOverflow(tester);

            // Bakiye yetmeyen bir avatar: satın alma diyaloğu.
            final locked = find.byIcon(Icons.lock_rounded);
            for (var i = 0; i < 20 && locked.evaluate().isEmpty; i++) {
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, -200),
              );
              await tester.pumpAndSettle();
            }
            await tester.ensureVisible(locked.first);
            await tester.pumpAndSettle();
            await tester.tap(locked.first);
            await tester.pumpAndSettle();
            _expectNoOverflow(tester);
            expect(find.byType(AlertDialog), findsOneWidget);
            final dialogSurface = find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Material),
                )
                .first;
            expect(
              tester.getSize(dialogSurface).width,
              lessThanOrEqualTo(ContentWidth.form),
            );
          },
        );
      }
    }

    testWidgets('çentikli yatay telefon (yan güvenli alan) taşmaz', (
      tester,
    ) async {
      const size = Size(844, 390);
      const notch = FakeViewPadding(left: 47, right: 47, bottom: 21);
      await _pump(
        tester,
        size,
        _RankingBodyHost(entries: _entries(12), league: _league()),
        padding: notch,
      );
      _expectNoOverflow(tester);
      // İçerik çentik tarafındaki güvenli alanın içinde kalır.
      expect(
        tester.getRect(find.byType(RankingPodium)).left,
        greaterThanOrEqualTo(47),
      );

      await _pump(
        tester,
        size,
        RankingScreen(currentUser: user),
        padding: notch,
      );
      _expectNoOverflow(tester);

      SupabaseService.instance.currentUser.value = user;
      await _pump(
        tester,
        size,
        ProfileScreen(onDarkModeChanged: (_) {}, onLogout: () {}),
        padding: notch,
      );
      _expectNoOverflow(tester);
      expect(
        tester.getRect(find.byType(SwitchListTile).first).left,
        greaterThanOrEqualTo(47),
      );

      await _pump(
        tester,
        size,
        CharacterCollectionScreen(user: user),
        padding: notch,
      );
      _expectNoOverflow(tester);
      expect(
        tester.getRect(find.byType(AvatarWidget).first).left,
        greaterThanOrEqualTo(47),
      );
      await _unmount(tester);
    });

    testWidgets('koleksiyon ızgarası genişliğe göre sütun sayısını artırır', (
      tester,
    ) async {
      double firstRowCount() {
        final cards = find.byType(AvatarWidget);
        final top = tester.getRect(cards.first).top;
        var count = 0;
        for (var i = 0; i < cards.evaluate().length; i++) {
          if ((tester.getRect(cards.at(i)).top - top).abs() < 1) count++;
        }
        return count.toDouble();
      }

      await _pump(
        tester,
        const Size(390, 844),
        CharacterCollectionScreen(user: user),
      );
      // AppBar bakiyesi avatar değil; ilk satır ızgaranın ilk satırıdır.
      expect(firstRowCount(), 3);

      await _pump(
        tester,
        const Size(1180, 820),
        CharacterCollectionScreen(user: user),
      );
      expect(firstRowCount(), greaterThan(6));
    });
  });
}
