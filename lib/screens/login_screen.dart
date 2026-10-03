import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../l10n/app_localizations.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../utils/auth_error_text.dart';
import '../utils/responsive.dart';
import '../theme.dart';
import '../widgets/auth/account_texts.dart';
import '../widgets/auth/auth_error_banner.dart';
import '../widgets/auth/legal_links.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Giriş (e-posta, Google, Apple ya da kayıt) başarılı olunca çağrılır;
  /// çağıran sonraki ekrana geçmelidir. Ekran bundan sonra yükleme durumunda
  /// kalır, böylece geçiş sürerken ikinci bir giriş denemesi yapılamaz.
  final FutureOr<void> Function(UserModel user) onLoginSuccess;

  /// Kayıttan e-posta onayı beklenerek dönüldüyse o adres: alan dolu gelir,
  /// "yeniden gönder" doğrudan görünür. (Kayıt ekranından dönüşte de aynı
  /// yol kullanılır.)
  final String? pendingVerificationEmail;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.pendingVerificationEmail,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _resendCooldownSeconds = 60;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingReset = false;
  bool _isResending = false;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;
  String? _errorMessage;
  bool _showResendButton = false;
  // Kayıttan onay beklenerek dönüldü: bilgi kutusu ve yeniden gönder.
  String? _pendingVerificationEmail;
  // Oturumun neden kapandığı (hesap silindi, oturum sona erdi, Apple izni).
  SignOutNotice? _notice;

  // Debug yapılandırması, ücretsiz (Personal Team) hesapla cihaza
  // imzalanabilsin diye Sign in with Apple entitlement'ı olmadan derlenir
  // (ios/Runner/RunnerDebug.entitlements); orada Apple girişi 1000 hatası
  // verir. Release/Profile tam entitlement'la derlenir.
  bool get _showAppleSignIn => !kIsWeb && !kDebugMode && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _offerAppleOnAndroidHelp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final service = SupabaseService.instance;
    _notice = service.takeSignOutNotice();
    service.signOutNotice.addListener(_onSignOutNotice);
    final pending = widget.pendingVerificationEmail;
    if (pending != null && pending.trim().isNotEmpty) _applyPendingVerification(pending);
  }

  void _onSignOutNotice() {
    if (SupabaseService.instance.signOutNotice.value == null || !mounted) return;
    final notice = SupabaseService.instance.takeSignOutNotice();
    if (notice != null) setState(() => _notice = notice);
  }

  void _applyPendingVerification(String email) {
    final clean = email.trim();
    _emailController.text = clean;
    _pendingVerificationEmail = clean;
    _showResendButton = true;
    _errorMessage = null;
  }

  @override
  void dispose() {
    SupabaseService.instance.signOutNotice.removeListener(_onSignOutNotice);
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Tüm giriş yollarının ortak akışı. Başarıda yükleme durumu korunur;
  /// üst bileşen bu ekrandan ayrılana kadar yeni deneme yapılamaz.
  /// [attempt] null dönerse [nullResultMessage] gösterilir (Google/Apple'da
  /// null, kullanıcının vazgeçtiği anlamına gelir).
  Future<void> _signIn(
    Future<UserModel?> Function() attempt, {
    String? nullResultMessage,
    bool offerResend = false,
  }) async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showResendButton = false;
      _pendingVerificationEmail = null;
      _notice = null;
    });

    try {
      final user = await attempt();
      // Beklerken (ör. global auth dinleyicisinin tetiklediği navigasyonla)
      // ekran dispose edilmiş olabilir.
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = nullResultMessage;
        });
        return;
      }
      await widget.onLoginSuccess(user);
    } catch (e) {
      if (!mounted) return;
      final code = SupabaseService.instance.parseAuthError(e);
      setState(() {
        _isLoading = false;
        _errorMessage = authErrorText(l10n, code);
        // Supabase, "yanlış şifre" ile "e-posta henüz onaylanmadı"
        // durumlarını hesap keşfini önlemek için aynı genel hatayla
        // döndürebilir; iki durumda da yeniden gönder butonu gösterilir.
        _showResendButton = offerResend &&
            (code == AuthErrorCode.invalidCredentials || code == AuthErrorCode.emailNotConfirmed);
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    // Şifre trim'lenmez: kayıtta olduğu gibi gönderilir.
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = l10n.errFillFields;
        _showResendButton = false;
      });
      return;
    }

    await _signIn(
      () => SupabaseService.instance.loginUser(email, password),
      nullResultMessage: l10n.errInvalidCredentials,
      offerResend: true,
    );
  }

  Future<void> _handleGoogleSignIn() => _signIn(SupabaseService.instance.signInWithGoogle);

  Future<void> _handleAppleSignIn() => _signIn(SupabaseService.instance.signInWithApple);

  Future<void> _openRegister() async {
    final result = await Navigator.push<RegisterResult>(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case RegisterSignedIn(:final user):
        await _signIn(() async => user);
      case RegisterAwaitingConfirmation(:final email):
        // Onaydan dönen kullanıcı adresini yeniden yazmaz; e-posta gelmediyse
        // yeniden gönder doğrudan görünür.
        setState(() {
          _notice = null;
          _applyPendingVerification(email);
        });
    }
  }

  Future<void> _handleResendEmail() async {
    if (_isResending || _resendSecondsLeft > 0) return;
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(l10n.errEnterEmailForResend, isError: true);
      return;
    }
    setState(() => _isResending = true);
    try {
      await SupabaseService.instance.resendConfirmationEmail(email);
      if (!mounted) return;
      _startResendCooldown();
      _showSnack(l10n.verificationResentMsg);
    } catch (e) {
      if (!mounted) return;
      final code = SupabaseService.instance.parseAuthError(e);
      if (code == AuthErrorCode.rateLimited) _startResendCooldown();
      _showSnack('⚠️ ${authErrorText(l10n, code)}', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _showAppleOnAndroidHelp() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: ContentWidth.form),
        title: Text(l10n.appleOnAndroidTitle),
        content: Text(l10n.appleOnAndroidBody, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton(AppLocalizations l10n, {required bool prompt}) {
    return OutlinedButton.icon(
      onPressed: (_isResending || _resendSecondsLeft > 0) ? null : _handleResendEmail,
      icon: _isResending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.mark_email_read_outlined, size: 18),
      label: Text(
        _resendSecondsLeft > 0
            ? l10n.authResendAvailableIn(_resendSecondsLeft)
            : (prompt ? l10n.loginResendPrompt : l10n.resendVerificationLink),
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    if (_isSendingReset) return;
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(l10n.errEnterEmailForReset, isError: true);
      return;
    }
    setState(() => _isSendingReset = true);
    try {
      // Bağlantı pomosprint.app/reset-password sayfasını açar (implicit akış).
      await SupabaseService.instance.resetPassword(email);
      if (mounted) _showSnack(l10n.passwordResetMsg);
    } catch (e) {
      if (mounted) {
        _showSnack('⚠️ ${authErrorText(l10n, SupabaseService.instance.parseAuthError(e))}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final fieldFill = isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHighest;
    final labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    // Form tablette ortalanmış form genişliğinde kalır (kaydırma tüm
    // genişlikte çalışır); yatay telefonda klavye açıkken de kayar.
    final screen = Responsive.of(context);
    final availableWidth = screen.width - MediaQuery.paddingOf(context).horizontal;
    final horizontalPadding = math.max(28.0, (availableWidth - ContentWidth.form) / 2);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: screen.isShortHeight ? 12 : 24),
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.timer_sharp,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    l10n.titleTimer,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeBackTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: labelColor),
                  ),
                  const SizedBox(height: 32),

                  // Oturumun neden kapandığı (bir kez gösterilir).
                  if (_notice != null) ...[
                    AuthInfoBanner(
                      message: signOutNoticeText(l10n, _notice!),
                      icon: _notice!.kind == SignOutNoticeKind.accountDeleted
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      dismissTooltip: l10n.noticeDismissTooltip,
                      onDismiss: () => setState(() => _notice = null),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Kayıttan onay beklenerek dönüldü.
                  if (_pendingVerificationEmail != null && _errorMessage == null) ...[
                    AuthInfoBanner(
                      message: l10n.loginVerificationPendingInfo(_pendingVerificationEmail!),
                      icon: Icons.mark_email_unread_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildResendButton(l10n, prompt: true),
                    const SizedBox(height: 16),
                  ],

                  // Error Banner
                  if (_errorMessage != null) ...[
                    AuthErrorBanner(message: _errorMessage!),
                    if (_showResendButton) ...[
                      const SizedBox(height: 8),
                      _buildResendButton(l10n, prompt: false),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Email Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(l10n.email, style: labelStyle),
                      ),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        decoration: InputDecoration(
                          hintText: l10n.authEmailHint,
                          filled: true,
                          fillColor: fieldFill,
                          border: fieldBorder,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(l10n.password, style: labelStyle),
                      ),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          filled: true,
                          fillColor: fieldFill,
                          border: fieldBorder,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: (_isLoading || _isSendingReset) ? null : _handleForgotPassword,
                      child: _isSendingReset
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              l10n.forgotPassword,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              l10n.loginBtn,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: fieldFill)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          l10n.orDivider,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: labelColor),
                        ),
                      ),
                      Expanded(child: Divider(color: fieldFill)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Apple ile Giriş (yalnızca iOS; App Store 4.8)
                  if (_showAppleSignIn) ...[
                    SizedBox(
                      width: double.infinity,
                      child: SignInWithAppleButton(
                        onPressed: _isLoading ? null : _handleAppleSignIn,
                        text: l10n.authAppleSignInBtn,
                        height: 52,
                        style: isDark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
                        borderRadius: const BorderRadius.all(Radius.circular(26)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Google Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                      label: Text(
                        l10n.googleLogin,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Google/Apple ilk girişte hesap oluşturur; Kullanım Şartları
                  // ve KVKK Aydınlatma Metni burada bildirilir (bağlantılı).
                  SocialSignInNotice(
                    style: TextStyle(fontSize: 12, height: 1.4, color: labelColor),
                  ),

                  // Android'de Apple ile giriş yok: Apple ile açılmış hesaba
                  // e-posta + şifre (Şifremi Unuttum) ile girme yolu.
                  if (_offerAppleOnAndroidHelp)
                    TextButton.icon(
                      onPressed: _showAppleOnAndroidHelp,
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      label: Text(l10n.appleOnAndroidLink, textAlign: TextAlign.center),
                      style: TextButton.styleFrom(foregroundColor: labelColor),
                    ),

                  const SizedBox(height: 32),

                  // Register link (dar ekranda ya da büyük yazıda alt satıra geçer)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.noAccountText,
                        style: TextStyle(fontSize: 14, color: labelColor),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : _openRegister,
                        child: Text(
                          l10n.signUpLink,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
