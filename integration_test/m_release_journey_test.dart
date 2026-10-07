// Gerçek yerel API ve UI: kategori yaşam döngüsü, raporda arşivli geçmiş,
// tema/dil kalıcılığı, avatar bakiye kontrolü ve açık route'ta tam çıkış.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/screens/categories_management_screen.dart';
import 'package:pomodoro/screens/character_collection_screen.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/auth/category_name_dialog.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/e2e.dart';

void main() {
  initE2e();
  testWidgets('m · kategori, arşivli rapor, dil/tema, avatar ve açık route çıkışı', (
    tester,
  ) async {
    final account = await openShellWithNewAccount(
      tester,
      'release',
      name: 'QA Release',
    );
    final service = SupabaseService.instance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('league_info_shown_${account.id}', true);
    await NotificationService.instance.setEnabled(false);

    Future<void> openProfile() async {
      await tapOn(
        tester,
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(AvatarWidget),
        ),
      );
      await pumpUntil(tester, find.byType(ProfileScreen));
    }

    Future<void> openCategories() async {
      await tapOn(tester, find.text(tr('manage_categories_tile_title')));
      await pumpUntil(tester, find.byType(CategoriesManagementScreen));
      await pumpUntil(tester, find.text('8 / 8'));
    }

    Finder categoryTile(String name) => find
        .ancestor(of: find.text(name), matching: find.byType(ListTile))
        .first;
    Future<void> waitIdleCategories() async {
      await pumpUntilGone(tester, find.byType(LinearProgressIndicator));
      await pumpFor(tester, const Duration(milliseconds: 300));
    }

    await openProfile();
    await openCategories();
    await tapOn(tester, find.byIcon(Icons.archive).first);
    await pumpUntil(tester, find.text('7 / 8'));
    await tapOn(tester, find.text(trL10n.addCategoryTitle));
    await pumpUntil(tester, find.byType(CategoryNameDialog));
    await tester.enterText(find.byType(TextField), 'QA Sprint');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapOn(tester, find.widgetWithText(ElevatedButton, trL10n.addBtn));
    await pumpUntilGone(tester, find.byType(CategoryNameDialog));
    await pumpUntil(tester, find.text('8 / 8'));
    await waitIdleCategories();
    await tapOn(tester, find.text(trL10n.addCategoryTitle));
    await pumpUntil(tester, find.text(trL10n.categoryLimitReachedMsg(8)));
    expect(find.byType(CategoryNameDialog), findsNothing);
    await tapOn(
      tester,
      find.descendant(
        of: categoryTile('QA Sprint'),
        matching: find.byIcon(Icons.edit),
      ),
    );
    await pumpUntil(tester, find.byType(CategoryNameDialog));
    await tester.enterText(find.byType(TextField), 'QA Odak');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapOn(tester, find.widgetWithText(ElevatedButton, trL10n.save));
    await pumpUntil(tester, find.text('QA Odak'));
    await waitIdleCategories();
    final category = (await categoriesViaApi(
      account,
    )).singleWhere((c) => c['name'] == 'QA Odak');
    await E2eHost.screenshot(tester, 'e2e-release-kategoriler');
    Navigator.of(tester.element(find.byType(CategoriesManagementScreen))).pop();
    await pumpUntilGone(tester, find.byType(CategoriesManagementScreen));
    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await pumpUntilGone(tester, find.byType(ProfileScreen));
    await pumpUntil(tester, find.text('QA Odak'));
    await tapOn(tester, find.text('QA Odak'));
    await tapOn(tester, find.text(tr('btn_start')));
    await pumpUntil(
      tester,
      find.byType(SessionCompletedDialog),
      timeout: const Duration(seconds: 25),
    );
    await pumpUntil(tester, find.text(trL10n.sessionResultPoints(5)));
    await tapOn(
      tester,
      find.widgetWithText(ElevatedButton, trL10n.sessionCompletedOk),
    );
    final saved = await E2eHost.row(
      'select category_id::text, duration_minutes from study_sessions where user_id=${sqlText(account.id)}',
    );
    expect(saved, {'category_id': category['id'], 'duration_minutes': 25});

    // Geçmişi olan kategoriyi arşivle: sayaçtan çıkar, raporda kalır.
    await openProfile();
    await openCategories();
    await tapOn(
      tester,
      find.descendant(
        of: categoryTile('QA Odak'),
        matching: find.byIcon(Icons.archive),
      ),
    );
    await pumpUntil(tester, find.text('7 / 8'));
    await waitIdleCategories();
    Navigator.of(tester.element(find.byType(CategoriesManagementScreen))).pop();
    await pumpUntilGone(tester, find.byType(CategoriesManagementScreen));
    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await pumpUntilGone(tester, find.byType(ProfileScreen));
    expect(
      find.text('QA Odak'),
      findsNothing,
      reason: 'arşivli kategori timer çipi olmaz',
    );
    await openTab(tester, 1);
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.text('QA Odak'),
      ),
    );
    expect(shellStats(tester), (points: 5, coins: 20));
    await E2eHost.screenshot(tester, 'e2e-release-arsivli-rapor');

    // Profil etkileşimleri: kalıcı koyu tema ve İngilizce; bütün sekmeler açılır.
    await openProfile();
    await tapOn(tester, find.widgetWithText(SwitchListTile, tr('dark_mode')));
    await pumpUntilTrue(
      tester,
      () =>
          Theme.of(tester.element(find.byType(ProfileScreen))).brightness ==
          Brightness.dark,
      reason: 'koyu tema uygulanır',
    );
    expect(prefs.getString('theme_mode'), 'dark');
    await tapOn(tester, find.text('English'));
    await pumpUntilTrue(
      tester,
      () => !LanguageService.instance.isTurkish,
      reason: 'İngilizce uygulanır',
    );
    await E2eHost.screenshot(tester, 'e2e-release-english-dark');
    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await pumpUntilGone(tester, find.byType(ProfileScreen));
    for (final index in [0, 1, 2, 3]) {
      await openTab(tester, index);
      expect(
        tester.takeException(),
        isNull,
        reason: 'İngilizce koyu sekme $index',
      );
    }
    await openProfile();
    await tapOn(tester, find.text('Türkçe'));
    await pumpUntilTrue(
      tester,
      () => LanguageService.instance.isTurkish,
      reason: 'Türkçe uygulanır',
    );
    // Avatar mağazası: yetersiz bakiye satın almayı engeller.
    final profileAvatar = find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(AvatarWidget),
        )
        .first;
    await tapOn(tester, profileAvatar);
    await pumpUntil(tester, find.byType(CharacterCollectionScreen));
    final user = service.currentUser.value!;
    final locked = AvatarCharacter.allAvatars().firstWhere(
      (a) =>
          !a.isOwned(user.unlockedAvatars) &&
          !a.isLeagueAward &&
          !a.isPremiumOnly &&
          a.requiredCoins > user.coins,
    );
    final avatarFinder = find.byWidgetPredicate(
      (w) => w is AvatarWidget && w.avatar.id == locked.id,
    );
    await tester.scrollUntilVisible(
      avatarFinder,
      180,
      scrollable: find
          .descendant(
            of: find.byType(CharacterCollectionScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapOn(
      tester,
      find
          .ancestor(of: avatarFinder, matching: find.byType(GestureDetector))
          .first,
    );
    await pumpUntil(tester, find.byType(AlertDialog));
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, trL10n.avatarPurchaseTitle),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text(trL10n.avatarNotEnoughCoins(locked.requiredCoins - user.coins)),
      findsOneWidget,
    );
    await tapOn(tester, find.widgetWithText(TextButton, trL10n.cancel));
    await pumpUntilGone(tester, find.byType(AlertDialog));
    await E2eHost.screenshot(tester, 'e2e-release-avatar');
    // Tam çıkış en üstteki eski hesap ekranlarını da kapatmalı.
    await service.signOutFully();
    await pumpUntil(tester, find.byType(LoginScreen));
    await pumpUntilGone(tester, find.byType(CharacterCollectionScreen));
    expect(find.byType(ProfileScreen), findsNothing);
    expect(service.currentUser.value, isNull);
    expect(tester.takeException(), isNull);
    await E2eHost.screenshot(tester, 'e2e-release-overlay-cikis');
    debugPrint(
      '[QA] Kategori UI CRUD/limit, arşivli rapor, tema/dil, avatar bakiye ve eski route çıkışı: PASS',
    );
  });
}
