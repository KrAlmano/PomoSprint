// (e) AYARLAR: Profil > "Gizlilik ve yasal" kartı. "Hesap silme hakkında"
// ve "Verilerimin kopyasını iste" YOK; Kullanım Şartları, Gizlilik, KVKK,
// Gizlenen kullanıcılar, Hesabımı Sil VAR. Hesabımı Sil akışı yerel hesabı
// gerçekten siler (psql).
//
// Çalıştırma: tool/local_supabase/e2e/sim/run_sim_e2e.sh e

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';

import 'support/e2e.dart';

void main() {
  initE2e();
  final l10n = trL10n;

  testWidgets('e · Profil > Gizlilik ve yasal öğeleri; Hesabımı Sil yerel hesabı siler', (tester) async {
    final account = await openShellWithNewAccount(tester, 'silme', name: 'Sim Silme');
    expect(await E2eHost.psql('select count(*) from auth.users where id = ${sqlText(account.id)}'), '1');

    await tapOn(tester, find.descendant(of: find.byType(AppBar), matching: find.byType(AvatarWidget)),
        settle: const Duration(seconds: 1));
    await pumpUntil(tester, find.byType(ProfileScreen));
    final profile = find.byType(ProfileScreen);
    final sectionTitle = l10n.profileLegalSectionTitle.replaceAll('i', 'İ').toUpperCase();
    final section = find.descendant(of: profile, matching: find.text(sectionTitle));
    await tester.scrollUntilVisible(section, 300, scrollable: find.descendant(of: profile, matching: find.byType(Scrollable)).first);
    await pumpFor(tester, const Duration(milliseconds: 500));

    for (final present in [
      l10n.hiddenUsersTitle,
      l10n.termsOfServiceLink,
      l10n.privacyPolicyLink,
      l10n.kvkkNoticeLink,
      l10n.deleteAccount,
    ]) {
      expect(find.descendant(of: profile, matching: find.text(present)), findsOneWidget, reason: 'olmalı: $present');
    }
    for (final absent in ['Hesap silme hakkında', 'Verilerimin kopyasını iste', 'Verilerimin kopyası']) {
      expect(find.textContaining(absent), findsNothing, reason: 'olmamalı: $absent');
    }
    final deleteTile = find.descendant(of: profile, matching: find.text(l10n.deleteAccount));
    // Kart başlığı üstte: kartın tamamı görünür.
    await tester.ensureVisible(section);
    await pumpFor(tester, const Duration(milliseconds: 800));
    await E2eHost.screenshot(tester, 'e2e-profil-ayarlar');

    // Hesabımı Sil → onay → silinir, giriş ekranı.
    await tapOn(tester, deleteTile, settle: const Duration(seconds: 1));
    final dialog = find.byType(AlertDialog);
    await pumpUntil(tester, dialog, reason: 'silme onayı');
    await E2eHost.screenshot(tester, 'e2e-hesap-silme-onay');
    await tapOn(tester, find.descendant(of: dialog, matching: find.widgetWithText(ElevatedButton, l10n.deleteAccount)),
        settle: const Duration(milliseconds: 200));
    await pumpUntil(tester, find.byType(LoginScreen), timeout: const Duration(seconds: 45), reason: 'silmeden sonra giriş ekranı');
    expect(find.text(l10n.profileDeleteError), findsNothing);
    expect(SupabaseService.instance.currentUser.value, isNull);
    await E2eHost.screenshot(tester, 'e2e-hesap-silindi');

    // Sunucu (psql): hesap ve bağlı veriler yok.
    final counts = (await E2eHost.row(
      'select (select count(*) from auth.users where id = ${sqlText(account.id)}) as users, '
      '(select count(*) from public.profiles where id = ${sqlText(account.id)}) as profiles, '
      '(select count(*) from public.categories where user_id = ${sqlText(account.id)}) as categories, '
      '(select count(*) from auth.users where email = ${sqlText(account.email)}) as by_email',
    ))!;
    expect(counts, {'users': 0, 'profiles': 0, 'categories': 0, 'by_email': 0}, reason: 'psql: hesap silindi');
  });
}
