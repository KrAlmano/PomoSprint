import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../models/registration_consent.dart';
import '../widgets/avatar_widget.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../utils/auth_error_text.dart';
import '../utils/name_filter.dart';
import '../utils/responsive.dart';
import '../theme.dart';
import '../widgets/auth/auth_error_banner.dart';
import '../widgets/auth/legal_links.dart';
import '../widgets/auth/password_rules.dart';

/// Görünen ad sınırları: sunucudaki profiles_name_length_check (1..50).
const int kRegisterNameMaxLength = 50;
const int kRegisterPasswordMinLength = PasswordRules.minLength;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Kayıt formu alan doğrulamaları (null: geçerli).
@visibleForTesting
String? registerNameError(AppLocalizations l10n, String value) {
  final name = value.trim();
  if (name.isEmpty) return l10n.registerErrNameRequired;
  if (name.length > kRegisterNameMaxLength) return l10n.registerErrNameTooLong;
  if (NameFilter.isOffensive(name)) return l10n.nameNotAllowed;
  return null;
}

@visibleForTesting
String? registerEmailError(AppLocalizations l10n, String value) {
  final email = value.trim();
  if (email.isEmpty) return l10n.registerErrEmailRequired;
  if (!_emailPattern.hasMatch(email)) return l10n.authErrInvalidEmail;
  return null;
}

/// Sunucunun şifre kuralı (bkz. [PasswordRules]): en az 8 karakter, küçük
/// harf, büyük harf ve rakam. Kural yazarken alanın altında canlı gösterilir.
@visibleForTesting
String? registerPasswordError(AppLocalizations l10n, String value) => passwordRuleError(l10n, value);

/// Kayıt ekranının sonucu (Navigator.pop): oturum hemen açıldı ya da e-posta
/// onayı bekleniyor (giriş ekranı adresi doldurur, yeniden göndermeyi sunar).
sealed class RegisterResult {
  const RegisterResult();
}

class RegisterSignedIn extends RegisterResult {
  final UserModel user;
  const RegisterSignedIn(this.user);
}

class RegisterAwaitingConfirmation extends RegisterResult {
  final String email;
  const RegisterAwaitingConfirmation(this.email);
}

/// Kayıt ekranı. Kayıt anında oturum açılırsa (e-posta onayı kapalı)
/// [RegisterSignedIn] ile `Navigator.pop` edilir; çağıran (LoginScreen)
/// girişi tamamlar. Onay e-postası gerekiyorsa bilgilendirme gösterilir ve
/// ekran (geri tuşu dahil) [RegisterAwaitingConfirmation] ile kapanır.
///
/// İki zorunlu onay (Kullanım Şartları; KVKK Aydınlatma Metni ve Gizlilik
/// Politikası okundu) işaretlenmeden kayıt isteği gönderilmez. Ticari
/// elektronik ileti onayı isteğe bağlıdır ve varsayılan olarak kapalıdır.
/// Onaylar sürümüyle birlikte auth metadata'sına yazılır
/// ([RegistrationConsent.toMetadata]).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _consentsKey = GlobalKey();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _termsAccepted = false;
  bool _privacyAcknowledged = false;
  bool _marketingConsent = false;
  bool _submitAttempted = false;
  bool _isLoading = false;
  bool _isVerificationSent = false;
  String? _errorMessage;

  String _selectedAvatarId = kDefaultAvatarId;

  // Kayıtta yalnızca varsayılan (is_default) avatarlar seçilebilir; sunucu
  // (handle_new_user) başka bir değeri avatar_16_basic'e çeker. Kum
  // tanesiyle alınan, Premium ve lig ödülü avatarlar listede yok. Katalog
  // boşsa gömülü katalog kullanılır; liste hiçbir zaman boş kalmaz.
  // Varsayılan (başta seçili) karakter şeridin başında durur.
  List<AvatarCharacter> get _freeAvatars {
    final free = AvatarCharacter.allAvatars().where((a) => a.isFree).toList()
      ..sort((a, b) => (a.id == kDefaultAvatarId ? 0 : 1).compareTo(b.id == kDefaultAvatarId ? 0 : 1));
    return free.isNotEmpty ? free : [AvatarCharacter.byId(kDefaultAvatarId)];
  }

  AvatarCharacter _selectedAvatarIn(List<AvatarCharacter> avatars) =>
      avatars.firstWhere((a) => a.id == _selectedAvatarId, orElse: () => avatars.first);

  @override
  void initState() {
    super.initState();
    // Katalog önbellekte yoksa sunucudan tazelenir; gelince seçici güncellenir.
    SupabaseService.instance.refreshAvatarCatalog().then((_) {
      if (mounted) setState(() {});
    }, onError: (Object e) => debugPrint('[REGISTER] Avatar kataloğu tazelenemedi: $e'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _showTermsError => _submitAttempted && !_termsAccepted;
  bool get _showPrivacyError => _submitAttempted && !_privacyAcknowledged;

  Future<void> _handleRegister() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitAttempted = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Alan hataları alanların altında, eksik onaylar kendi satırında
    // gösterilir; ilk sorunlu yere gidilir.
    final fieldsValid = _formKey.currentState?.validate() ?? false;
    if (!fieldsValid) {
      if (registerNameError(l10n, name) != null) {
        _nameFocus.requestFocus();
      } else if (registerEmailError(l10n, email) != null) {
        _emailFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
      }
      return;
    }

    final consent = RegistrationConsent(
      termsAccepted: _termsAccepted,
      privacyAcknowledged: _privacyAcknowledged,
      marketingConsent: _marketingConsent,
      legalVersion: kLegalDocumentsVersion,
      acceptedAt: DateTime.now(),
    );
    if (!consent.hasRequired) {
      final consentsContext = _consentsKey.currentContext;
      if (consentsContext != null) {
        await Scrollable.ensureVisible(
          consentsContext,
          duration: const Duration(milliseconds: 250),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.instance.registerUser(
        email: email,
        password: password,
        avatarId: _selectedAvatarId,
        name: name,
        consent: consent,
      );

      // registerUser() beklenirken bu ekran dispose edilmiş olabilir.
      if (!mounted) return;

      final authUser = response?.session != null ? response?.user : null;
      if (authUser == null) {
        // E-posta onayı gerekiyor: bilgilendirme ekranı.
        setState(() {
          _isLoading = false;
          _isVerificationSent = true;
        });
        return;
      }

      // Oturum hemen açıldı: profil tek yerden kurulur. Okunamazsa en az
      // bilgiyle devam edilir; profil sonraki okumada oluşturulur.
      UserModel? user;
      try {
        user = await SupabaseService.instance.fetchCurrentUserModel();
      } catch (e) {
        debugPrint('[REGISTER] Kayıt sonrası profil okunamadı: $e');
      }
      user ??= UserModel(
        id: authUser.id,
        name: name,
        email: authUser.email ?? email,
        avatarId: AvatarCharacter.isFreeAvatarId(_selectedAvatarId) ? _selectedAvatarId : kDefaultAvatarId,
      );
      if (mounted) Navigator.pop<RegisterResult>(context, RegisterSignedIn(user));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = authErrorText(l10n, SupabaseService.instance.parseAuthError(e));
      });
    }
  }

  // Onay bekleniyorsa ekran her yoldan (geri, buton) adresle kapanır.
  void _leave() {
    if (_isLoading) return;
    if (_isVerificationSent) {
      Navigator.pop<RegisterResult>(context, RegisterAwaitingConfirmation(_emailController.text.trim()));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screen = Responsive.of(context);
    // Form tablette ortalanmış form genişliğinde kalır; kaydırma (ve
    // klavyeyi kaydırarak kapatma) tüm genişlikte çalışır.
    final availableWidth = screen.width - MediaQuery.paddingOf(context).horizontal;
    final horizontalPadding = math.max(24.0, (availableWidth - ContentWidth.form) / 2);
    final background = isDark ? AppColors.darkSurface : AppColors.surface;

    return PopScope(
      canPop: !_isLoading && !_isVerificationSent,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _isLoading ? null : _leave,
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 24),
            child: _isVerificationSent
                ? _buildVerificationSentView()
                : Form(
                    key: _formKey,
                    autovalidateMode: _submitAttempted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                    child: AutofillGroup(child: _buildForm(screen, isDark)),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(Responsive screen, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final avatars = _freeAvatars;
    final selectedAvatar = _selectedAvatarIn(avatars);
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final short = screen.isShortHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Başlık: seçilen karakter, başlık ve alt başlık. Üst boşluk halkanın
        // gölgesinin kaydırma alanında kesilmemesi için.
        const SizedBox(height: 12),
        Center(child: _AvatarHalo(avatar: selectedAvatar, size: short ? 60 : 84)),
        SizedBox(height: short ? 10 : 16),
        Text(
          l10n.createAccountTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: short ? 22 : 26, fontWeight: FontWeight.bold, color: onSurface, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.createAccountSub,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: muted),
        ),
        SizedBox(height: short ? 16 : 24),

        if (_errorMessage != null) ...[
          AuthErrorBanner(message: _errorMessage!),
          const SizedBox(height: 16),
        ],

        _buildAvatarPicker(l10n, isDark, avatars, selectedAvatar),
        const SizedBox(height: 20),

        _FieldLabel(text: l10n.registerNameLabel),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [LengthLimitingTextInputFormatter(kRegisterNameMaxLength)],
          validator: (v) => registerNameError(l10n, v ?? ''),
          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
          decoration: _decoration(
            isDark,
            hint: l10n.fullNameHint,
            icon: Icons.person_outline,
            helper: l10n.registerNameHelper,
          ),
        ),
        const SizedBox(height: 14),

        _FieldLabel(text: l10n.email),
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.email],
          validator: (v) => registerEmailError(l10n, v ?? ''),
          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: _decoration(isDark, hint: l10n.authEmailHint, icon: Icons.mail_outline),
        ),
        const SizedBox(height: 14),

        _FieldLabel(text: l10n.password),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          validator: (v) => registerPasswordError(l10n, v ?? ''),
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: _decoration(
            isDark,
            hint: '••••••••',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: muted,
              ),
              tooltip: _obscurePassword ? l10n.registerShowPassword : l10n.registerHidePassword,
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        // Sunucu kuralı yazarken işaretlenir (sunucu reddetmeden önce).
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _passwordController,
          builder: (context, value, _) => PasswordRuleChecklist(password: value.text),
        ),
        const SizedBox(height: 20),

        _buildConsents(l10n, isDark),
        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.registerBtn,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Giriş bağlantısı (dar ekranda ya da büyük yazıda alt satıra geçer).
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.alreadyHaveAccount, style: TextStyle(fontSize: 14, color: muted)),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 40),
              ),
              child: Text(l10n.loginBtn, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _decoration(
    bool isDark, {
    required String hint,
    required IconData icon,
    String? helper,
    Widget? suffix,
  }) {
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final error = isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      // Örnek metin girilmiş değerle karışmasın diye soluk.
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.5)),
      helperText: helper,
      helperMaxLines: 2,
      errorMaxLines: 3,
      helperStyle: TextStyle(fontSize: 12, color: muted),
      errorStyle: TextStyle(fontSize: 12, color: error),
      prefixIcon: Icon(icon, color: muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHighest,
      contentPadding: const EdgeInsets.all(16),
      border: border(Colors.transparent, 0),
      enabledBorder: border(Colors.transparent, 0),
      focusedBorder: border(isDark ? AppColors.darkPrimary : AppColors.primary, 1.5),
      errorBorder: border(error, 1.2),
      focusedErrorBorder: border(error, 1.6),
    );
  }

  Widget _buildAvatarPicker(
    AppLocalizations l10n,
    bool isDark,
    List<AvatarCharacter> avatars,
    AvatarCharacter selectedAvatar,
  ) {
    final isTurkish = LanguageService.instance.isTurkish;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    Widget item(AvatarCharacter avatar) {
      final isSelected = avatar.id == selectedAvatar.id;
      return Semantics(
        button: true,
        selected: isSelected,
        label: avatar.getName(isTurkish),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => setState(() => _selectedAvatarId = avatar.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _avatarItemSize,
            height: _avatarItemSize,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? (isDark ? AppColors.darkPrimary : AppColors.primary) : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: AvatarWidget(avatar: avatar, size: _avatarItemSize - 11),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: _FieldLabel(text: l10n.selectCharacter, bottom: 0)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedAvatar.getName(isTurkish),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Sığarsa (tablet) tek satır; sığmazsa yatay kaydırılan şerit
        // (telefonda kısmen görünen son karakter kaydırılabildiğini gösterir).
        SizedBox(
          height: _avatarItemSize,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final needed = avatars.length * _avatarItemSize + (avatars.length - 1) * gap;
              if (needed <= constraints.maxWidth) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [for (final a in avatars) item(a)],
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: avatars.length,
                separatorBuilder: (_, _) => const SizedBox(width: gap),
                itemBuilder: (context, index) => item(avatars[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  static const double _avatarItemSize = 54;

  Widget _buildConsents(AppLocalizations l10n, bool isDark) {
    final missingRequired = _showTermsError || _showPrivacyError;
    final error = isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
    return Container(
      key: _consentsKey,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: missingRequired
              ? error.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.6),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.registerConsentsTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _ConsentTile(
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v),
              isRequired: true,
              errorText: _showTermsError ? l10n.errAcceptTerms : null,
              parts: [
                LegalTextPart(l10n.registerConsentTermsPrefix),
                LegalTextPart.link(l10n.registerConsentTermsLink, LegalPage.terms),
                LegalTextPart(l10n.registerConsentTermsSuffix),
              ],
            ),
            _ConsentTile(
              value: _privacyAcknowledged,
              onChanged: (v) => setState(() => _privacyAcknowledged = v),
              isRequired: true,
              errorText: _showPrivacyError ? l10n.errAcknowledgePrivacy : null,
              parts: [
                LegalTextPart(l10n.registerConsentPrivacyPrefix),
                LegalTextPart.link(l10n.registerConsentKvkkLink, LegalPage.kvkk),
                LegalTextPart(l10n.registerConsentPrivacyConnector),
                LegalTextPart.link(l10n.registerConsentPrivacyLink, LegalPage.privacy),
                LegalTextPart(l10n.registerConsentPrivacySuffix),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Divider(height: 1, color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.5)),
            ),
            _ConsentTile(
              value: _marketingConsent,
              onChanged: (v) => setState(() => _marketingConsent = v),
              isRequired: false,
              hint: l10n.registerConsentMarketingHint,
              parts: [LegalTextPart(l10n.registerConsentMarketing)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationSentView() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ContentWidth(
      maxWidth: ContentWidth.form,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.verificationSentTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.verificationSentDesc(_emailController.text.trim()),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _leave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: Text(l10n.backToLoginBtn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçilen karakter, marka renginde yumuşak bir halkayla.
class _AvatarHalo extends StatelessWidget {
  final AvatarCharacter avatar;
  final double size;

  const _AvatarHalo({required this.avatar, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.primary.withValues(alpha: 0.85)],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: AvatarWidget(avatar: avatar, size: size),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final double bottom;

  const _FieldLabel({required this.text, this.bottom = 6});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: bottom),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        ),
      ),
    );
  }
}

/// Onay satırı: onay kutusu, bağlantılı metin, Zorunlu/İsteğe bağlı etiketi
/// ve (eksik zorunlu onayda) satır içi hata. Satırın tamamına dokunmak
/// kutuyu değiştirir; bağlantılara dokunmak yalnızca sayfayı açar.
class _ConsentTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<LegalTextPart> parts;
  final bool isRequired;
  final String? hint;
  final String? errorText;

  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.parts,
    required this.isRequired,
    this.hint,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    final error = isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
    final tag = isRequired ? l10n.registerConsentRequiredTag : l10n.registerConsentOptionalTag;
    final errorText = this.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  isError: errorText != null,
                  activeColor: accent,
                  semanticLabel: '${LegalRichText.plainText(parts)} ($tag)',
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LegalRichText(
                          parts: parts,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRequired
                                  ? accent.withValues(alpha: 0.12)
                                  : (isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isRequired ? accent : muted,
                              ),
                            ),
                          ),
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: 6),
                          Text(hint!, style: TextStyle(fontSize: 12, height: 1.3, color: muted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      errorText,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
