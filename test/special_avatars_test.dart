import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/league_rules.dart';
import 'package:pomodoro/models/registration_consent.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/character_collection_screen.dart';
import 'package:pomodoro/screens/register_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/auth/legal_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = {
  'small phone': Size(320, 568),
  'phone': Size(390, 844),
  'landscape phone': Size(844, 390),
  'tablet portrait': Size(820, 1180),
  'tablet landscape': Size(1180, 820),
  'wide tablet': Size(1366, 1024),
};

const _defaultIds = {
  'avatar_16_basic',
  'avatar_2_glasses',
  'avatar_3_gentleman',
  'avatar_5_flower',
  'avatar_6_cool',
  'avatar_7_scholar',
  'avatar_8_striped',
};

List<AvatarCharacter> get _specials =>
    AvatarCharacter.fallbackCatalog.where((a) => a.isSpecial).toList();

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  expect(tester.takeException(), isNull);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

UserModel _user({int coins = 499, List<String> unlocked = const []}) =>
    UserModel(
      id: 'special-qa-user',
      name: 'Avatar Denemesi',
      email: 'avatar@example.invalid',
      coins: coins,
      unlockedAvatars: unlocked,
    );

class _DelayedAvatarService implements SupabaseService {
  _DelayedAvatarService(UserModel user)
    : currentUser = ValueNotifier<UserModel?>(user);

  @override
  final ValueNotifier<UserModel?> currentUser;
  final catalogGate = Completer<void>();
  int catalogRequests = 0;

  @override
  LeagueRules get leagueRules => LeagueRules.standard;

  @override
  Future<LeagueRules> getLeagueRules() async => leagueRules;

  @override
  Future<void> refreshAvatarCatalog() async {
    catalogRequests++;
    await catalogGate.future;
    AvatarCharacter.setCachedAvatars(AvatarCharacter.fallbackCatalog);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarCharacter.clearCachedAvatars();
    SupabaseService.instance.currentUser.value = null;
  });
  tearDown(() {
    AvatarCharacter.clearCachedAvatars();
    SupabaseService.instance.currentUser.value = null;
  });

  test(
    '21 special avatars match the bilingual asset manifest and cost 500',
    () {
      final manifest =
          jsonDecode(
                File('assets/avatars/special_catalog.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final rows = (manifest['avatars'] as List).cast<Map<String, dynamic>>();
      expect(_specials, hasLength(21));
      expect(_specials.map((a) => a.id).toSet(), hasLength(21));
      expect(
        rows.map((r) => r['id']).toSet(),
        _specials.map((a) => a.id).toSet(),
      );
      for (final row in rows) {
        final avatar = AvatarCharacter.byId(row['id'] as String);
        expect(
          avatar.toMap(),
          AvatarCharacter.fromMap(row).toMap(),
          reason: avatar.id,
        );
        expect(avatar.requiredCoins, 500, reason: avatar.id);
        expect(avatar.isDefault, isFalse, reason: avatar.id);
        expect(avatar.isPremiumOnly, isFalse, reason: avatar.id);
        expect(avatar.isLeagueAward, isFalse, reason: avatar.id);
        expect(avatar.getName(true), row['name_tr']);
        expect(avatar.getName(false), row['name_en']);
        expect(
          File(avatar.imagePath).existsSync(),
          isTrue,
          reason: avatar.imagePath,
        );
      }
    },
  );

  test(
    'special ownership is independent of balance and existing categories',
    () {
      for (final avatar in _specials) {
        expect(avatar.isFree, isFalse);
        expect(AvatarCharacter.isFreeAvatarId(avatar.id), isFalse);
        expect(avatar.isOwned(const []), isFalse);
        expect(avatar.canAfford(499), isFalse);
        expect(avatar.canAfford(500), isTrue);
        expect(avatar.isOwned([avatar.id]), isTrue);
        expect(avatar.canUnlockWithPremium(true), isFalse);
        expect(
          avatar.isListedInShop(unlockedAvatars: const [], isPremium: false),
          isTrue,
        );
      }
      expect(
        AvatarCharacter.fallbackCatalog
            .where((a) => a.isFree)
            .map((a) => a.id)
            .toSet(),
        _defaultIds,
      );
      expect(AvatarCharacter.byId('avatar_1_gamer').requiredCoins, 200);
      expect(
        AvatarCharacter.byId('league_gold_weekly').canAfford(100000),
        isFalse,
      );
    },
  );

  test('old server catalog keeps priority over the new fallback', () {
    final old = AvatarCharacter.fallbackCatalog
        .where((a) => !a.isSpecial)
        .toList();
    AvatarCharacter.setCachedAvatars(old);
    expect(AvatarCharacter.allAvatars().any((a) => a.isSpecial), isFalse);
    // A profile with a known special ID can still render offline, without
    // advertising an avatar missing from the server shop catalog.
    expect(AvatarCharacter.byId('special_gold_miner').isSpecial, isTrue);
  });

  test('signup metadata never accepts a special avatar', () {
    final consent = RegistrationConsent(
      termsAccepted: true,
      privacyAcknowledged: true,
      legalVersion: kLegalDocumentsVersion,
      acceptedAt: DateTime.utc(2026, 10, 9),
    );
    for (final avatar in _specials) {
      final metadata = SupabaseService.signUpMetadata(
        email: 'avatar@example.invalid',
        avatarId: avatar.id,
        consent: consent,
      );
      expect(metadata['avatar_id'], kDefaultAvatarId, reason: avatar.id);
    }
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets(
      'signup shows only the same seven defaults · ${locale.languageCode}',
      (tester) async {
        await _pump(
          tester,
          const RegisterScreen(),
          locale: locale,
          size: const Size(1366, 1024),
        );
        final rendered = tester
            .widgetList<AvatarWidget>(find.byType(AvatarWidget))
            .map((w) => w.avatar.id)
            .toSet();
        expect(rendered, _defaultIds);
        expect(rendered.any((id) => id.startsWith('special_')), isFalse);
        expect(
          find.text(
            locale.languageCode == 'tr'
                ? 'Klasik Kum Saati'
                : 'Classic Hourglass',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            locale.languageCode == 'tr' ? 'Özel Avatarlar' : 'Special Avatars',
          ),
          findsNothing,
        );
      },
    );

    for (final size in _sizes.entries) {
      testWidgets(
        'separate special category and localized purchase · ${locale.languageCode} · ${size.key}',
        (tester) async {
          await _pump(
            tester,
            CharacterCollectionScreen(user: _user()),
            locale: locale,
            size: size.value,
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CharacterCollectionScreen)),
          )!;
          await _scrollTo(tester, find.text(l10n.specialAvatarsTitle));
          expect(find.text(l10n.specialAvatarsTitle), findsOneWidget);
          final first = _specials.first;
          final card = find.byKey(ValueKey('avatar-card-${first.id}'));
          await _scrollTo(tester, card);
          expect(
            find.descendant(
              of: card,
              matching: find.text(first.getName(locale.languageCode == 'tr')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: card, matching: find.text('🪙 500')),
            findsOneWidget,
          );
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              l10n.avatarPurchaseBody(
                first.getName(locale.languageCode == 'tr'),
                500,
              ),
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.avatarNotEnoughCoins(1)), findsOneWidget);
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, l10n.avatarPurchaseTitle),
                )
                .onPressed,
            isNull,
          );
        },
      );
    }

    testWidgets(
      '500 sand enables confirmation but does not give ownership · ${locale.languageCode}',
      (tester) async {
        await _pump(
          tester,
          CharacterCollectionScreen(user: _user(coins: 500)),
          locale: locale,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CharacterCollectionScreen)),
        )!;
        final card = find.byKey(ValueKey('avatar-card-${_specials.first.id}'));
        await _scrollTo(tester, card);
        expect(
          find.descendant(
            of: card,
            matching: find.byIcon(Icons.shopping_bag_outlined),
          ),
          findsOneWidget,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, l10n.avatarPurchaseTitle),
              )
              .onPressed,
          isNotNull,
        );
        // Do not send a purchase: the server transaction is covered separately.
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: card, matching: find.byIcon(Icons.check)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'owned special selects without another purchase · ${locale.languageCode}',
      (tester) async {
        final avatar = _specials.last;
        await _pump(
          tester,
          CharacterCollectionScreen(user: _user(unlocked: [avatar.id])),
          locale: locale,
        );
        final card = find.byKey(ValueKey('avatar-card-${avatar.id}'));
        await _scrollTo(tester, card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.descendant(of: card, matching: find.byIcon(Icons.check)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'large text category and purchase remain scrollable · ${locale.languageCode}',
      (tester) async {
        await _pump(
          tester,
          CharacterCollectionScreen(user: _user()),
          locale: locale,
          size: const Size(320, 568),
          textScale: 2,
        );
        final card = find.byKey(ValueKey('avatar-card-${_specials.first.id}'));
        await _scrollTo(tester, card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'old server catalog does not show an unavailable special section',
    (tester) async {
      AvatarCharacter.setCachedAvatars(
        AvatarCharacter.fallbackCatalog.where((a) => !a.isSpecial).toList(),
      );
      await _pump(
        tester,
        CharacterCollectionScreen(user: _user()),
        size: const Size(1366, 4000),
      );
      expect(find.text('Özel Avatarlar'), findsNothing);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CharacterCollectionScreen)),
      )!;
      expect(find.text(l10n.leagueAwardsTitle), findsOneWidget);
    },
  );

  testWidgets(
    'delayed catalog updates the open collection with all 21 specials',
    (tester) async {
      AvatarCharacter.setCachedAvatars(
        AvatarCharacter.fallbackCatalog.where((a) => !a.isSpecial).toList(),
      );
      final service = _DelayedAvatarService(_user());
      await _pump(
        tester,
        CharacterCollectionScreen(
          user: service.currentUser.value!,
          service: service,
        ),
        size: const Size(1366, 4000),
      );
      expect(service.catalogRequests, 1);
      expect(find.text('Özel Avatarlar'), findsNothing);
      service.catalogGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Özel Avatarlar'), findsOneWidget);
      final rendered = tester
          .widgetList<AvatarWidget>(find.byType(AvatarWidget))
          .map((w) => w.avatar)
          .toList();
      expect(rendered.where((a) => a.isSpecial), hasLength(21));
      expect(rendered.where((a) => a.isLeagueAward), hasLength(10));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.currentUser.dispose();
    },
  );

  testWidgets(
    'late catalog after disposal causes no setState or listener error',
    (tester) async {
      AvatarCharacter.setCachedAvatars(
        AvatarCharacter.fallbackCatalog.where((a) => !a.isSpecial).toList(),
      );
      final service = _DelayedAvatarService(_user());
      await _pump(
        tester,
        CharacterCollectionScreen(
          user: service.currentUser.value!,
          service: service,
        ),
      );
      await tester.pumpWidget(const SizedBox());
      service.catalogGate.complete();
      service.currentUser.value = _user(coins: 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      service.currentUser.dispose();
    },
  );

  testWidgets(
    'account switch rejects another owner balance, unlocks and delayed catalog',
    (tester) async {
      AvatarCharacter.setCachedAvatars(
        AvatarCharacter.fallbackCatalog.where((a) => !a.isSpecial).toList(),
      );
      final owner = _user(coins: 499);
      final service = _DelayedAvatarService(owner);
      await _pump(
        tester,
        CharacterCollectionScreen(user: owner, service: service),
        size: const Size(1366, 4000),
      );
      service.currentUser.value = UserModel(
        id: 'another-account',
        name: 'Other owner',
        email: 'other@example.invalid',
        coins: 9000,
        unlockedAvatars: const ['avatar_1_gamer'],
      );
      service.catalogGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('🪙 499'), findsOneWidget);
      expect(find.text('🪙 9000'), findsNothing);
      expect(find.text('Özel Avatarlar'), findsNothing);
      final gamer = find.byKey(const ValueKey('avatar-card-avatar_1_gamer'));
      expect(
        find.descendant(
          of: gamer,
          matching: find.byIcon(Icons.shopping_bag_outlined),
        ),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CharacterCollectionScreen)),
      )!;
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, l10n.confirmSelection),
            )
            .onPressed,
        isNull,
      );
      // A return to the same ID is a new session, not the original epoch.
      service.currentUser.value = owner.copyWith(coins: 700);
      await tester.pumpAndSettle();
      expect(find.text('🪙 499'), findsOneWidget);
      expect(find.text('🪙 700'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.currentUser.dispose();
    },
  );

  testWidgets('same owner updates keep special ownership and balance live', (
    tester,
  ) async {
    final owner = _user(coins: 500);
    final service = _DelayedAvatarService(owner);
    service.catalogGate.complete();
    await _pump(
      tester,
      CharacterCollectionScreen(user: owner, service: service),
      size: const Size(1366, 4000),
    );
    final avatar = _specials.first;
    service.currentUser.value = owner.copyWith(
      coins: 0,
      unlockedAvatars: [avatar.id],
    );
    await tester.pumpAndSettle();
    expect(find.text('🪙 0'), findsOneWidget);
    final card = find.byKey(ValueKey('avatar-card-${avatar.id}'));
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.lock_rounded)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.shopping_bag_outlined),
      ),
      findsNothing,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.currentUser.dispose();
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    for (final size in const [Size(320, 568), Size(844, 390)]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets(
          'all special prices stay above names · ${locale.languageCode} · $size · x$scale',
          (tester) async {
            await _pump(
              tester,
              CharacterCollectionScreen(user: _user()),
              locale: locale,
              size: size,
              textScale: scale,
            );
            for (final avatar in _specials) {
              final card = find.byKey(ValueKey('avatar-card-${avatar.id}'));
              await _scrollTo(tester, card);
              final name = find.descendant(
                of: card,
                matching: find.text(
                  avatar.getName(locale.languageCode == 'tr'),
                ),
              );
              final price = find.descendant(
                of: card,
                matching: find.text('🪙 500'),
              );
              final image = find.descendant(
                of: card,
                matching: find.byType(AvatarWidget),
              );
              final nameRect = tester.getRect(name);
              final priceRect = tester.getRect(price);
              final imageRect = tester.getRect(image);
              final cardRect = tester.getRect(card);
              expect(imageRect.center.dx, closeTo(cardRect.center.dx, 0.1),
                  reason: '${avatar.id} image must be centered in the full card');
              expect(nameRect.center.dx, closeTo(cardRect.center.dx, 0.1),
                  reason: '${avatar.id} name must share the image center');
              expect(
                priceRect.bottom,
                lessThan(nameRect.top),
                reason: '${avatar.id} price must stay above its name',
              );
              expect(priceRect.overlaps(nameRect), isFalse, reason: avatar.id);
              expect(
                priceRect.top,
                greaterThanOrEqualTo(imageRect.top),
                reason: avatar.id,
              );
              expect(
                priceRect.bottom,
                lessThanOrEqualTo(imageRect.bottom),
                reason: avatar.id,
              );
              expect(
                priceRect.left,
                greaterThanOrEqualTo(imageRect.left),
                reason: avatar.id,
              );
              expect(
                priceRect.right,
                lessThanOrEqualTo(imageRect.right),
                reason: avatar.id,
              );
              expect(tester.widget<Text>(price).style!.color, Colors.white);
              expect(
                tester.widget<Text>(price).style!.fontWeight,
                FontWeight.bold,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('retired Ronin renders the safe default and stays out of the collection', (tester) async {
    const ronin = AvatarCharacter(
      id: 'special_ronin',
      nameTr: 'Ronin',
      nameEn: 'Ronin',
      imagePath: 'assets/avatars/special_ronin.png',
      requiredCoins: 500,
    );
    AvatarCharacter.setCachedAvatars([...AvatarCharacter.fallbackCatalog, ronin]);
    final owner = UserModel(
      id: 'legacy-ronin-owner',
      name: 'Legacy owner',
      email: 'legacy@example.invalid',
      avatarId: ronin.id,
      coins: 700,
      unlockedAvatars: const ['special_ronin'],
    );
    await _pump(tester, CharacterCollectionScreen(user: owner), size: const Size(1366, 4000));
    expect(find.byKey(const ValueKey('avatar-card-special_ronin')), findsNothing);
    final defaultCard = find.byKey(const ValueKey('avatar-card-avatar_16_basic'));
    expect(find.descendant(of: defaultCard, matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(owner.avatarId, 'special_ronin', reason: 'Rendering must not mutate stored profile or ownership');
    expect(owner.unlockedAvatars, const ['special_ronin']);
    expect(owner.coins, 700);
    await _pump(tester, const Scaffold(body: Center(child: AvatarWidget(avatar: ronin))));
    final provider = tester.widget<Image>(find.byType(Image)).image;
    final asset = provider is ResizeImage ? provider.imageProvider : provider;
    expect((asset as AssetImage).assetName, AvatarCharacter.byId(kDefaultAvatarId).imagePath);
    expect(tester.takeException(), isNull);
  });
}
