// Hesap ve oturum akışları: oturum kapanış kancası ve açıklaması, hesap
// silme yardımcıları (Apple iptali, Edge Function yedeği, kayıp yanıt),
// auth zaman aşımı, çıkış/silme onay metinleri, şifre kuralı ve değiştirme,
// kayıttan onay bekleyerek dönüş, onboarding taslağı, gizlilik kartı.
//
// Supabase başlatılmadan çalışır (bulut kapalı).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/auth_error_text.dart';
import 'package:pomodoro/widgets/auth/account_texts.dart';
import 'package:pomodoro/widgets/auth/change_password_dialog.dart';
import 'package:pomodoro/widgets/auth/password_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _user = UserModel(id: 'uid-1', name: 'Ayşe', email: 'ayse@example.com');

User _authUser({Map<String, dynamic> appMetadata = const {}, List<String> identityProviders = const []}) => User(
      id: 'uid-1',
      appMetadata: appMetadata,
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-01T00:00:00Z',
      identities: [
        for (final p in identityProviders)
          UserIdentity(
            id: 'sub-$p',
            userId: 'uid-1',
            identityData: const {},
            identityId: 'iid-$p',
            provider: p,
            createdAt: null,
            lastSignInAt: null,
          ),
      ],
    );

Future<AppLocalizations> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byWidget(home)))!;
}

void main() {
  late AppLocalizations l10n;
  final service = SupabaseService.instance;
  var cleanupCalls = 0;

  // Tekil servisler (AsyncLock zincirleri) gerçek zone'da kurulmalı.
  setUpAll(() async {
    expect(SupabaseService.instance, isNotNull);
    expect(TimerPersistence.instance, isNotNull);
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cleanupCalls = 0;
    SupabaseService.sessionEndedCleanup = () async => cleanupCalls++;
    service.signOutNotice.value = null;
  });

  tearDown(() {
    service.currentUser.value = null;
    service.signOutNotice.value = null;
    service.pendingSessionCount.value = 0;
  });

  group('Bekleyen seans sayısı: geç okuma hesap izolasyonu', () {
    void seedPending() {
      SharedPreferences.setMockInitialValues({
        'pending_sessions_uid_uid-1': jsonEncode([
          PendingSessionFixture.json(DateTime.utc(2026, 10, 8, 8)),
        ]),
        'pending_sessions_ayse@example.com': jsonEncode([
          PendingSessionFixture.json(DateTime.utc(2026, 10, 8, 8)),
        ]),
      });
    }

    test('A okuması geç tamamlanınca B göstergesini değiştirmez', () async {
      seedPending();
      service.currentUser.value = _user;
      final readA = service.getPendingSessionCount();
      service.currentUser.value = UserModel(id: 'uid-2', name: 'Ali', email: 'ali@example.com');
      service.pendingSessionCount.value = 2;

      expect(await readA, 1, reason: 'okuma başlangıçtaki A kuyruğuna aittir');
      expect(service.pendingSessionCount.value, 2, reason: 'B göstergesi A yanıtıyla ezilmez');
    });

    test('kullanıcı çıkınca geç okuma bekleyen göstergesini geri açmaz', () async {
      seedPending();
      service.currentUser.value = _user;
      final readA = service.getPendingSessionCount();
      service.handleAuthStateChange(AuthState(AuthChangeEvent.signedOut, null, signOutReason: SignOutReason.userInitiated));

      expect(await readA, 1);
      expect(service.pendingSessionCount.value, 0);
    });

    test('aynı UID ile yeni oturumda eski dönem okuması göstergeyi değiştirmez', () async {
      seedPending();
      service.currentUser.value = _user;
      final readA = service.getPendingSessionCount();
      service.handleAuthStateChange(AuthState(AuthChangeEvent.signedOut, null, signOutReason: SignOutReason.userInitiated));
      service.currentUser.value = _user;
      service.pendingSessionCount.value = 2;

      expect(await readA, 1);
      expect(service.pendingSessionCount.value, 2, reason: 'UID aynı olsa da önceki oturumun yanıtı bayattır');
    });

    test('UID bilinmeyen eski e-posta kuyruğu yeni hesabın göstergesini değiştirmez', () async {
      seedPending();
      service.currentUser.value = UserModel(name: 'Ayşe', email: _user.email);
      final readA = service.getPendingSessionCount();
      service.currentUser.value = UserModel(name: 'Ali', email: 'ali@example.com');
      service.pendingSessionCount.value = 0;

      expect(await readA, 1);
      expect(service.pendingSessionCount.value, 0);
    });

    test('sahip değişmediyse güncel sayıyı göstergeye yazar', () async {
      seedPending();
      service.currentUser.value = _user;
      service.pendingSessionCount.value = 0;

      expect(await service.getPendingSessionCount(), 1);
      expect(service.pendingSessionCount.value, 1);
    });
  });

  group('Oturum kapanış kancası', () {
    // Kanca, servis tekillerine (kilit zincirleri) dokunduğu için gerçek zone'da çağrılır.
    Future<void> emit(WidgetTester tester, SignOutReason reason) => tester.runAsync(() async {
          service.handleAuthStateChange(AuthState(AuthChangeEvent.signedOut, null, signOutReason: reason));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

    testWidgets('uzaktan düşme (sessionExpired): açıklama, gösterge temizliği, kullanıcı null', (tester) async {
      service.currentUser.value = _user;
      await emit(tester, SignOutReason.sessionExpired);
      expect(service.signOutNotice.value, SignOutNotice.sessionExpired);
      expect(cleanupCalls, 1, reason: 'bitiş bildirimi ve kilit ekranı sayacı kapatılır');
      expect(service.currentUser.value, isNull);
      expect(signOutNoticeText(l10n, service.takeSignOutNotice()!), l10n.sessionExpiredNotice);
      expect(service.signOutNotice.value, isNull, reason: 'bir kez gösterilir');
    });

    testWidgets('kullanıcının kendi çıkışı ve zaten çıkmış oturum açıklama üretmez', (tester) async {
      service.currentUser.value = _user;
      await emit(tester, SignOutReason.userInitiated);
      expect(service.signOutNotice.value, isNull);
      expect(service.currentUser.value, isNull);

      await emit(tester, SignOutReason.sessionExpired);
      expect(service.signOutNotice.value, isNull, reason: 'kullanıcı yoktu');
      expect(cleanupCalls, 0);
    });

    testWidgets('signOutFully: açıklama, gösterge temizliği ve Apple kaydının silinmesi', (tester) async {
      SharedPreferences.setMockInitialValues({
        'apple_sign_in_identity': jsonEncode({'uid': 'uid-1', 'apple_user': 'apple.001'}),
        'saved_user': '{}',
      });
      service.currentUser.value = _user;
      await tester.runAsync(
        () => service.signOutFully(notice: const SignOutNotice.accountDeleted(apple: AppleRevocation.notRevoked)),
      );
      expect(cleanupCalls, 1);
      expect(service.currentUser.value, isNull);
      final notice = service.signOutNotice.value!;
      expect(notice.needsAppleSettingsHint, isTrue);
      expect(signOutNoticeText(l10n, notice), contains(l10n.accountDeletedAppleNotice));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('apple_sign_in_identity'), isNull);
      expect(prefs.getString('saved_user'), isNull);

      // Açıklamasız ikinci çıkış (ör. silme sonrası kabuğun çıkışı) açıklamayı silmez.
      await tester.runAsync(() => service.signOutFully());
      expect(service.signOutNotice.value, notice);
    });

    for (final remote in [false, true]) {
      testWidgets('${remote ? 'uzaktan düşme' : 'çıkış'}: native temizlik beklerken yeni odak kapalı', (tester) async {
        final cleanup = Completer<void>();
        SupabaseService.sessionEndedCleanup = () => cleanup.future;
        service.currentUser.value = _user;
        expect(service.isDeviceSessionEnding, isFalse);
        await tester.runAsync(() async {
          Future<void>? signOut;
          if (remote) {
            service.handleAuthStateChange(AuthState(AuthChangeEvent.signedOut, null, signOutReason: SignOutReason.sessionExpired));
          } else {
            signOut = service.signOutFully();
          }
          expect(service.isDeviceSessionEnding, isTrue);
          expect(service.currentUser.value, _user, reason: 'native temizlik henüz bitmedi');
          cleanup.complete();
          if (signOut != null) await signOut;
          for (var i = 0; i < 100 && service.isDeviceSessionEnding; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
          expect(service.currentUser.value, isNull);
          expect(service.isDeviceSessionEnding, isFalse);
        });
      });
    }
  });

  group('Hesap silme yardımcıları', () {
    test('yalnız deleted:true Edge yanıtı kesin silme makbuzudur', () {
      expect(SupabaseService.deleteEdgeResponseConfirmed({'deleted': true}), isTrue);
      expect(SupabaseService.deleteEdgeResponseConfirmed({'deleted': false}), isFalse);
      expect(SupabaseService.deleteEdgeResponseConfirmed({'deleted': 'true'}), isFalse);
      expect(SupabaseService.deleteEdgeResponseConfirmed({'ok': true}), isFalse);
      expect(SupabaseService.deleteEdgeResponseConfirmed(null), isFalse);
      expect(SupabaseService.deleteEdgeResponseConfirmed(''), isFalse);
    });

    test('Apple iptal durumu Edge Function yanıtından okunur', () {
      expect(appleRevocationFromResponse({'apple': {'status': 'revoked'}}, hasAppleIdentity: true), AppleRevocation.revoked);
      expect(
        appleRevocationFromResponse({'apple': {'status': 'skipped', 'reason': 'not_configured'}}, hasAppleIdentity: true),
        AppleRevocation.notRevoked,
      );
      expect(appleRevocationFromResponse(null, hasAppleIdentity: true), AppleRevocation.notRevoked);
      expect(appleRevocationFromResponse({'apple': {'status': 'revoked'}}, hasAppleIdentity: false),
          AppleRevocation.notApplicable);
      expect(const SignOutNotice.accountDeleted(apple: AppleRevocation.revoked).needsAppleSettingsHint, isFalse);
      expect(signOutNoticeText(l10n, const SignOutNotice.accountDeleted()), l10n.accountDeletedNotice);
    });

    test('fonksiyon yoksa (404) ya da çalışamadıysa (5xx) RPC yedeğine düşülür; 4xx düşmez', () {
      expect(SupabaseService.shouldFallBackToDeleteRpc(const FunctionException(status: 404)), isTrue);
      expect(SupabaseService.shouldFallBackToDeleteRpc(const FunctionException(status: 500)), isTrue);
      expect(SupabaseService.shouldFallBackToDeleteRpc(const FunctionException(status: 503)), isTrue);
      expect(SupabaseService.shouldFallBackToDeleteRpc(const FunctionException(status: 401)), isFalse);
      expect(SupabaseService.shouldFallBackToDeleteRpc(const FunctionException(status: 405)), isFalse);
      // 5xx gövdesindeki Apple durumu korunur.
      expect(
        appleRevocationFromResponse(
          const FunctionException(status: 500, details: {'error': 'delete_failed', 'apple': {'status': 'revoked'}})
              .details,
          hasAppleIdentity: true,
        ),
        AppleRevocation.revoked,
      );
    });

    test('kayıp silme yanıtında yalnızca "kullanıcı yok" hesabı silinmiş sayar', () {
      expect(
        SupabaseService.authErrorMeansUserGone(
          const AuthException('User from sub claim in JWT does not exist', statusCode: '403', code: 'user_not_found'),
        ),
        isTrue,
      );
      expect(
        SupabaseService.authErrorMeansUserGone(const AuthException('route not found', statusCode: '404')),
        isFalse,
        reason: 'genel 404 hesap kaybının kanıtı değildir',
      );
      expect(
        SupabaseService.authErrorMeansUserGone(const AuthException('user not found', statusCode: '404', code: 'user_not_found')),
        isTrue,
      );
      expect(
        SupabaseService.authErrorMeansUserGone(const AuthException('expired', statusCode: '401', code: 'bad_jwt')),
        isFalse,
        reason: 'süresi dolmuş JWT silinme değildir',
      );
      expect(
        SupabaseService.authErrorMeansUserGone(
          const AuthException('Session not found', statusCode: '403', code: 'session_not_found'),
        ),
        isFalse,
      );
    });

    test('sağlayıcılar app_metadata ya da identities üzerinden bulunur', () {
      expect(SupabaseService.userHasProvider(_authUser(appMetadata: {'provider': 'apple'}), 'apple'), isTrue);
      expect(
        SupabaseService.userHasProvider(_authUser(appMetadata: {'providers': ['email', 'google']}), 'google'),
        isTrue,
      );
      expect(SupabaseService.userHasProvider(_authUser(identityProviders: ['apple']), 'apple'), isTrue);
      expect(SupabaseService.userHasProvider(_authUser(appMetadata: {'provider': 'google'}), 'email'), isFalse);
    });

    test('Apple izni kaldırıldıysa ya da kimlik yoksa oturum kapatılır', () {
      expect(SupabaseService.appleCredentialRequiresSignOut(CredentialState.revoked), isTrue);
      expect(SupabaseService.appleCredentialRequiresSignOut(CredentialState.notFound), isTrue);
      expect(SupabaseService.appleCredentialRequiresSignOut(CredentialState.authorized), isFalse);
    });

    test('Apple kimliği yalnızca aynı oturum (uid) için okunur', () async {
      SharedPreferences.setMockInitialValues({
        'apple_sign_in_identity': jsonEncode({'uid': 'uid-1', 'apple_user': 'apple.001'}),
      });
      expect(await SupabaseService.rememberedAppleUserId('uid-1'), 'apple.001');
      expect(await SupabaseService.rememberedAppleUserId('uid-2'), isNull);
      SharedPreferences.setMockInitialValues({'apple_sign_in_identity': 'bozuk{'});
      expect(await SupabaseService.rememberedAppleUserId('uid-1'), isNull);
    });

    test('silme onayı neyin kaybolacağını, bekleyen seansları ve Apple adımını söyler', () {
      final plain = deleteAccountConfirmText(l10n, pendingCount: 0, appleReauthorization: false);
      expect(plain, contains(l10n.profileDeleteConfirm));
      expect(plain, contains('arkadaşların'));
      expect(plain, isNot(contains(l10n.profileDeleteConfirmApple)));
      final full = deleteAccountConfirmText(l10n, pendingCount: 3, appleReauthorization: true);
      expect(full, contains(l10n.profileDeleteConfirmPending(3)));
      expect(full, contains('3 seansın'));
      expect(full, contains(l10n.profileDeleteConfirmApple));
      // Veri kopyası uygulama içinden değil, Aydınlatma Metni'ndeki e-posta
      // yoluyla istenir; ipucu Profil'de de onboarding'de de geçerli.
      expect(plain, contains(l10n.profileDeleteConfirmCopyHint('destek@pomosprint.app')));
      expect(full, contains('destek@pomosprint.app'));
      expect(plain, isNot(contains('Verilerimin kopyasını iste')));
    });
  });

  group('Auth zaman aşımı ve hata metinleri', () {
    test('zaman aşımı bağlantı hatası olur; kayıtta ayrı kod', () async {
      final never = Completer<void>();
      await expectLater(
        SupabaseService.runAuthRequest(() => never.future, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', AuthErrorCode.network)),
      );
      await expectLater(
        SupabaseService.runAuthRequest(
          () => never.future,
          timeout: const Duration(milliseconds: 10),
          onTimeout: AuthErrorCode.signUpTimedOut,
        ),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', AuthErrorCode.signUpTimedOut)),
      );
      // Diğer hatalar olduğu gibi geçer; sonuç döner.
      await expectLater(
        SupabaseService.runAuthRequest<void>(() async => throw const AuthException('Invalid login credentials')),
        throwsA(isA<AuthException>()),
      );
      expect(await SupabaseService.runAuthRequest(() async => 7), 7);
      expect(authErrorText(l10n, AuthErrorCode.signUpTimedOut), l10n.authErrSignUpTimeout);
    });

    test('aynı şifre ve Google/Apple ile kayıtlı e-posta metinleri', () {
      const same = AuthException('New password should be different from the old password.', code: 'same_password');
      expect(authErrorCodeOf(same), AuthErrorCode.samePassword);
      expect(authErrorText(l10n, AuthErrorCode.samePassword), l10n.changePasswordSame);
      expect(l10n.errEmailExists, contains('Google'));
      expect(l10n.errEmailExists, contains('Şifremi Unuttum'));
    });
  });

  group('Çıkış onayı', () {
    test('metin: bekleyen seans ve süren sayaç uyarıları', () {
      expect(logoutConfirmText(l10n, pendingCount: 0, hasActiveSession: false), l10n.logoutConfirmBody);
      final both = logoutConfirmText(l10n, pendingCount: 2, hasActiveSession: true);
      expect(both, contains(l10n.logoutPendingWarning(2)));
      expect(both, contains('24 saat'));
      expect(both, contains(l10n.logoutRunningWarning));
    });

    // Süren sayaç kaydı sahte kontrolle verilir: TimerPersistence'ın kilit
    // zinciri sahte (fake async) ve gerçek zone arasında paylaşılınca asılı kalır.
    final checkedOwners = <String>[];
    Widget host(VoidCallback onLogout, {bool timerRunning = false}) => Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    onDarkModeChanged: (_) {},
                    onLogout: onLogout,
                    activeTimerSessionCheck: (owner) async {
                      checkedOwners.add(owner);
                      return timerRunning;
                    },
                  ),
                )),
                child: const Text('profil'),
              ),
            ),
          ),
        );

    Future<void> tapLogout(WidgetTester tester) async {
      final logout = find.widgetWithText(TextButton, 'Çıkış Yap');
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
    }

    testWidgets('onay olmadan çıkılmaz; onayla çıkılır', (tester) async {
      var loggedOut = 0;
      service.currentUser.value = _user;
      await _pump(tester, host(() => loggedOut++));
      await tester.tap(find.text('profil'));
      await tester.pumpAndSettle();

      await tapLogout(tester);
      expect(find.text(l10n.logoutConfirmTitle), findsOneWidget);
      expect(find.text(l10n.logoutConfirmBody), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(loggedOut, 0);

      await tapLogout(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Çıkış Yap')));
      await tester.pumpAndSettle();
      expect(loggedOut, 1);
      expect(find.byType(ProfileScreen), findsNothing);
    });

    testWidgets('gönderilmemiş seans ve süren sayaç uyarısı; "Yine de çık"', (tester) async {
      final now = DateTime.now().toUtc();
      final session = PendingSessionFixture.json(now.subtract(const Duration(hours: 1)));
      SharedPreferences.setMockInitialValues({
        'pending_sessions_uid_uid-1': jsonEncode([session]),
      });
      checkedOwners.clear();
      var loggedOut = 0;
      service.currentUser.value = _user;
      await _pump(tester, host(() => loggedOut++, timerRunning: true));
      await tester.tap(find.text('profil'));
      await tester.pumpAndSettle();

      await tapLogout(tester);
      expect(checkedOwners.last, 'uid-1', reason: 'sayaç kaydı kullanıcı kimliğiyle aranır');
      expect(find.textContaining('1 seansın henüz sunucuya gönderilmedi'), findsOneWidget);
      expect(find.textContaining(l10n.logoutRunningWarning), findsOneWidget);
      expect(find.text(l10n.logoutSendAndExit), findsOneWidget);

      // Gönderilemiyor (bulut kapalı): çıkılmaz, söylenir.
      await tester.tap(find.text(l10n.logoutSendAndExit));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(loggedOut, 0);
      expect(find.text(l10n.logoutSendFailed), findsOneWidget);
      // Alttaki çıkış düğmesini örten bildirim kapatılır.
      ScaffoldMessenger.of(tester.element(find.byType(ProfileScreen))).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await tapLogout(tester);
      await tester.tap(find.text(l10n.logoutAnyway));
      await tester.pumpAndSettle();
      expect(loggedOut, 1);
    });
  });

  group('Profil: gizlilik kartı ve şifre', () {
    testWidgets('"Gizlilik ve yasal" yalın: gizlenenler, üç yasal metin, Hesabımı Sil', (tester) async {
      service.currentUser.value = _user;
      await _pump(tester, ProfileScreen(onDarkModeChanged: (_) {}, onLogout: () {}));
      for (final title in [
        l10n.hiddenUsersTitle,
        l10n.termsOfServiceLink,
        l10n.privacyPolicyLink,
        l10n.kvkkNoticeLink,
        l10n.deleteAccount,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      // Hesap silme bilgisi Play Console'daki web adresinde, veri kopyası
      // Aydınlatma Metni'ndeki e-posta yolunda; uygulamada ayrı madde yok.
      expect(find.text('Hesap silme hakkında'), findsNothing);
      expect(find.text('Verilerimin kopyasını iste'), findsNothing);
      // Bulut kapalı: şifre değiştirme yalnızca e-posta hesabında görünür.
      expect(find.text(l10n.changePasswordTile), findsNothing);
    });

    test('şifre kuralı sunucuyla aynı', () {
      expect(PasswordRules.isSatisfied('Abcdefg1'), isTrue);
      expect(PasswordRules.isSatisfied('Abcde1'), isFalse);
      expect(PasswordRules.isSatisfied('Abcdef1'), isFalse);
      expect(PasswordRules.isSatisfied('abcdefg1'), isFalse);
      expect(PasswordRules.isSatisfied('ABCDEFG1'), isFalse);
      expect(PasswordRules.isSatisfied('Abcdefgh'), isFalse);
      expect(PasswordRules.isSatisfied('Abc1'), isFalse);
    });

    testWidgets('şifre değiştirme: doğrulama, yanlış mevcut şifre, başarı', (tester) async {
      final calls = <(String, String)>[];
      Object? failWith = const AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials');
      Future<void> fake({required String currentPassword, required String newPassword}) async {
        calls.add((currentPassword, newPassword));
        final error = failWith;
        if (error != null) throw error;
      }

      bool? result;
      final home = Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showChangePasswordDialog(context, changePassword: fake),
            child: const Text('aç'),
          ),
        ),
      );
      await _pump(tester, home);
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);

      // Zayıf ve uyuşmayan yeni şifre: istek gönderilmez.
      await tester.enterText(fields.at(0), 'Eski1abc');
      await tester.enterText(fields.at(1), 'zayif');
      await tester.enterText(fields.at(2), 'baska');
      await tester.tap(find.text(l10n.changePasswordSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.errShortPassword), findsOneWidget);
      expect(find.text(l10n.changePasswordMismatch), findsOneWidget);
      expect(calls, isEmpty);

      // Mevcut şifreyle aynı.
      await tester.enterText(fields.at(1), 'Eski1abc');
      await tester.enterText(fields.at(2), 'Eski1abc');
      await tester.tap(find.text(l10n.changePasswordSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.changePasswordSame), findsOneWidget);
      expect(calls, isEmpty);

      // Yanlış mevcut şifre.
      await tester.enterText(fields.at(1), 'Yeni1abc');
      await tester.enterText(fields.at(2), 'Yeni1abc');
      await tester.tap(find.text(l10n.changePasswordSave));
      await tester.pumpAndSettle();
      expect(calls.single, ('Eski1abc', 'Yeni1abc'));
      expect(find.text(l10n.changePasswordWrongCurrent), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Başarı.
      failWith = null;
      await tester.tap(find.text(l10n.changePasswordSave));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.changePasswordSuccess), findsOneWidget);
    });
  });

  group('Giriş ekranı', () {
    testWidgets('oturumun neden kapandığı bir kez gösterilir ve kapatılabilir', (tester) async {
      service.signOutNotice.value = const SignOutNotice.accountDeleted(apple: AppleRevocation.notRevoked);
      final screen = LoginScreen(onLoginSuccess: (_) {});
      await _pump(tester, screen);
      expect(find.textContaining(l10n.accountDeletedNotice), findsOneWidget);
      expect(find.textContaining('Kullanmayı Durdur'), findsOneWidget);
      expect(service.signOutNotice.value, isNull, reason: 'tüketildi');
      await tester.tap(find.byTooltip(l10n.noticeDismissTooltip));
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.accountDeletedNotice), findsNothing);

      // Ekran açıkken gelen açıklama da gösterilir.
      service.signOutNotice.value = SignOutNotice.sessionExpired;
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionExpiredNotice), findsOneWidget);
    });

    testWidgets('kayıttan onay bekleyerek dönüş: e-posta dolu, yeniden gönder görünür', (tester) async {
      final screen = LoginScreen(onLoginSuccess: (_) {}, pendingVerificationEmail: 'ayse@example.com');
      await _pump(tester, screen);
      final email = tester.widget<TextField>(find.byType(TextField).first);
      expect(email.controller!.text, 'ayse@example.com');
      expect(find.text(l10n.loginVerificationPendingInfo('ayse@example.com')), findsOneWidget);
      expect(find.text(l10n.loginResendPrompt), findsOneWidget);

      // Bulut kapalı: yeniden gönderme hata verir ama ekran bozulmaz.
      await tester.tap(find.text(l10n.loginResendPrompt));
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.authErrCloudUnavailable), findsOneWidget);
    });

    testWidgets('e-posta boşken yeniden gönder sessiz kalmaz', (tester) async {
      final screen = LoginScreen(onLoginSuccess: (_) {}, pendingVerificationEmail: 'ayse@example.com');
      await _pump(tester, screen);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.text(l10n.loginResendPrompt));
      await tester.pumpAndSettle();
      expect(find.text(l10n.errEnterEmailForResend), findsOneWidget);
    });

    testWidgets('Android: Apple ile açılmış hesap için yol gösterilir', (tester) async {
      final screen = LoginScreen(onLoginSuccess: (_) {});
      await _pump(tester, screen);
      final link = find.text(l10n.appleOnAndroidLink);
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text(l10n.appleOnAndroidTitle), findsOneWidget);
      expect(find.textContaining('privaterelay.appleid.com'), findsOneWidget);
    });
  });

  group('Onboarding taslağı', () {
    test('JSON gidiş-dönüş ve bozuk kayıt', () {
      const draft = OnboardingDraft(
        step: 2,
        birthYear: 2008,
        segment: 'yks',
        selectedCategories: ['Fizik', 'Kendi'],
        customCategories: ['Kendi'],
        autoCategories: ['Fizik'],
        dailyGoalMinutes: 120,
      );
      final back = OnboardingDraft.fromJson(jsonDecode(jsonEncode(draft.toJson())))!;
      expect(back.step, 2);
      expect(back.segment, 'yks');
      expect(back.selectedCategories, ['Fizik', 'Kendi']);
      expect(back.autoCategories, ['Fizik']);
      expect(back.dailyGoalMinutes, 120);
      // Otomatik seçimden önceki sürümün taslağı: 'auto' yok (null), boş liste değil.
      expect(OnboardingDraft.fromJson({'step': 2, 'segment': 'yks'})!.autoCategories, isNull);
      expect(OnboardingDraft.fromJson({'step': 2, 'auto': <String>[]})!.autoCategories, isEmpty);
      expect(OnboardingDraft.fromJson('x'), isNull);
      expect(OnboardingDraft.fromJson({'step': 'iki'}), isNull);
      expect(OnboardingDraft.fromJson({'step': 1, 'selected': [1, 'Fizik', '']})!.selectedCategories, ['Fizik']);
    });

    testWidgets('süreç ölse de seçimler ve adım geri gelir; tamamlanmamış adım atlanmaz', (tester) async {
      service.currentUser.value = _user;
      SharedPreferences.setMockInitialValues({
        OnboardingDraftStore.keyFor('uid-1'): jsonEncode(const OnboardingDraft(
          step: 3,
          birthYear: 2008,
          segment: 'yks',
          // Önerilerde olmayan, özel de olmayan ad atılır; kategori kalmayınca
          // segmentin önerileri seçilir ve adım 3'e (kategoriler) geri çekilir.
          selectedCategories: ['Yok Böyle'],
          dailyGoalMinutes: 180,
        ).toJson()),
      });
      final screen = PostAuthOnboardingScreen(onCompleted: () {});
      await _pump(tester, screen);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('3/7'), findsOneWidget);

      // Ekranın son hâli taslağa yazılır.
      final prefs = await SharedPreferences.getInstance();
      final saved = OnboardingDraft.fromJson(jsonDecode(prefs.getString(OnboardingDraftStore.keyFor('uid-1'))!))!;
      expect(saved.step, 2);
      expect(saved.segment, 'yks');
      expect(saved.birthYear, 2008);
      expect(saved.dailyGoalMinutes, 180);
      const yksFirst8 = ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe'];
      expect(saved.selectedCategories, yksFirst8);
      expect(saved.autoCategories, yksFirst8);
    });

    // Taslağı yazıp onboarding ekranını açar; ekranın kaydettiği son taslağı döndürür.
    Future<OnboardingDraft> restore(WidgetTester tester, OnboardingDraft draft) async {
      service.currentUser.value = _user;
      SharedPreferences.setMockInitialValues({OnboardingDraftStore.keyFor('uid-1'): jsonEncode(draft.toJson())});
      await _pump(tester, PostAuthOnboardingScreen(onCompleted: () {}));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      return OnboardingDraft.fromJson(jsonDecode(prefs.getString(OnboardingDraftStore.keyFor('uid-1'))!))!;
    }

    // t2-02: "Diğer" ve segmentsiz (segment isteğe bağlı) taslaklar
    // seçimleri ve adımı kaybetmeden geri gelir.
    testWidgets('"Diğer" segmentli taslak: genel önerilerden seçim ve adım korunur', (tester) async {
      final saved = await restore(
        tester,
        const OnboardingDraft(
          step: 4,
          birthYear: 1990,
          segment: 'other',
          selectedCategories: ['Okuma', 'Proje'],
          showInRankings: false,
          dailyGoalMinutes: 120,
        ),
      );
      expect(find.text('5/7'), findsOneWidget);
      expect(saved.segment, 'other');
      expect(saved.selectedCategories, ['Okuma', 'Proje']);
      expect(saved.showInRankings, isFalse);
    });

    testWidgets('segment seçilmemiş taslak: genel önerilerden seçim ve adım korunur', (tester) async {
      final saved = await restore(
        tester,
        const OnboardingDraft(
          step: 3,
          birthYear: 2000,
          selectedCategories: ['Ders Çalışma'],
          dailyGoalMinutes: 60,
        ),
      );
      expect(find.text('4/7'), findsOneWidget);
      expect(saved.segment, isNull);
      expect(saved.selectedCategories, ['Ders Çalışma']);
    });

    // Hedefe göre otomatik seçim: hangi kategorilerin otomatik geldiği
    // taslakta tutulur; geri dönülüp segment değişince yalnızca onlar değişir.
    testWidgets('otomatik seçim taslakla geri gelir; segment değişince elle seçilen korunur', (tester) async {
      final restored = await restore(
        tester,
        const OnboardingDraft(
          step: 2,
          birthYear: 2000,
          segment: 'yks',
          selectedCategories: ['Matematik', 'Fizik', 'Felsefe'],
          autoCategories: ['Matematik', 'Fizik'],
          dailyGoalMinutes: 60,
        ),
      );
      expect(find.text('3/7'), findsOneWidget);
      expect(restored.autoCategories, ['Matematik', 'Fizik']);

      await tester.tap(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(Scaffold))).backButtonTooltip));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.onboardingSegmentKpss));
      await tester.tap(find.text(l10n.onboardingSegmentKpss));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved = OnboardingDraft.fromJson(jsonDecode(prefs.getString(OnboardingDraftStore.keyFor('uid-1'))!))!;
      const kpss = ['Türkçe', 'Matematik', 'Tarih', 'Coğrafya', 'Vatandaşlık', 'Güncel Bilgiler'];
      expect(saved.segment, 'kpss');
      expect(saved.selectedCategories, ['Felsefe', ...kpss], reason: "'Fizik' otomatikti, 'Felsefe' elle seçilmişti");
      expect(saved.autoCategories, kpss);
    });

    testWidgets('eski sürüm taslağı: segment seçili ama kategori yoksa öneriler seçili gelir', (tester) async {
      final saved = await restore(
        tester,
        const OnboardingDraft(step: 1, birthYear: 2000, segment: 'kpss', dailyGoalMinutes: 60),
      );
      expect(find.text('2/7'), findsOneWidget, reason: 'adım korunur');
      expect(saved.selectedCategories, saved.autoCategories);
      expect(saved.autoCategories, ['Türkçe', 'Matematik', 'Tarih', 'Coğrafya', 'Vatandaşlık', 'Güncel Bilgiler']);
    });

    testWidgets('eski KPSS Eğitim Bilimleri seçimi taslakta korunur', (tester) async {
      final saved = await restore(
        tester,
        const OnboardingDraft(
          step: 2,
          birthYear: 2000,
          segment: 'kpss',
          selectedCategories: ['Türkçe', 'Eğitim Bilimleri'],
          autoCategories: ['Türkçe', 'Eğitim Bilimleri'],
          dailyGoalMinutes: 60,
        ),
      );
      expect(saved.selectedCategories, ['Türkçe', 'Eğitim Bilimleri']);
      expect(saved.autoCategories, ['Türkçe', 'Eğitim Bilimleri']);
    });

    testWidgets('kullanıcının boşalttığı seçim (yeni sürüm taslağı) yeniden doldurulmaz', (tester) async {
      final saved = await restore(
        tester,
        const OnboardingDraft(step: 4, birthYear: 2000, segment: 'yks', autoCategories: [], showInRankings: true),
      );
      expect(find.text('3/7'), findsOneWidget, reason: 'kategorisiz taslak kategori adımına döner');
      expect(saved.selectedCategories, isEmpty);
      expect(saved.autoCategories, isEmpty);
    });

    // t2-01: görünürlük yanıtı taslakta tutulur; yanıtsız taslak görünürlük
    // adımının ilerisine dönmez ve "Bitir" yanıt olmadan kayda gitmez
    // (sunucu show_in_social_feed'i varsayılan TRUE bırakırdı).
    testWidgets('görünürlük yanıtı yoksa taslak görünürlük adımına döner', (tester) async {
      final saved = await restore(
        tester,
        const OnboardingDraft(
          step: 5,
          birthYear: 2008,
          segment: 'yks',
          selectedCategories: ['Fizik'],
          dailyGoalMinutes: 60,
        ),
      );
      expect(find.text('4/7'), findsOneWidget);
      expect(find.text(l10n.onboardingVisibilityYes), findsOneWidget);
      expect(saved.step, 3);
      expect(saved.showInRankings, isNull);
    });

    testWidgets('"Hayır" yanıtı eski hedef taslağıyla geri gelir; rehberden bitirilebilir', (tester) async {
      final saved = await restore(
        tester,
        const OnboardingDraft(
          step: 5,
          birthYear: 2008,
          segment: 'yks',
          selectedCategories: ['Fizik'],
          showInRankings: false,
          dailyGoalMinutes: 60,
        ),
      );
      expect(find.text('6/7'), findsOneWidget, reason: 'eski taslağın hedef adımı korunur');
      expect(saved.showInRankings, isFalse);
      expect(find.text(l10n.onboardingFinishBtn), findsNothing);
      await tester.tap(find.text(l10n.continueBtn));
      await tester.pumpAndSettle();
      expect(find.text('7/7'), findsOneWidget);
      expect(find.text(l10n.onboardingGuideTitle), findsOneWidget);
      // Bulut kapalı: kayıt denenir (doğrulama engellemez) ve hata gösterilir.
      await tester.tap(find.text(l10n.onboardingFinishBtn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.onboardingSelectOptionError), findsNothing);
    });
  });
}

/// Kuyruktaki bir seansın disk biçimi (PendingSession.toJson ile aynı).
class PendingSessionFixture {
  static Map<String, dynamic> json(DateTime startedAt) => {
        'client_uuid': 'c-pending-1',
        'category_id': null,
        'category_name': 'Matematik',
        'minutes': 25,
        'was_paused': false,
        'is_verified': 1500,
        'started_at': startedAt.toIso8601String(),
        'queued_at': startedAt.add(const Duration(minutes: 25)).toIso8601String(),
        'category_remaps': 0,
      };
}
