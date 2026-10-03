import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../utils/auth_error_text.dart';
import '../utils/responsive.dart';
import '../theme.dart';
import '../widgets/auth/auth_error_banner.dart';
import '../widgets/auth/legal_links.dart';

/// Kayıt ekranı. Kayıt anında oturum açılırsa (e-posta onayı kapalı)
/// kullanıcı modeliyle `Navigator.pop` edilir; çağıran (LoginScreen) girişi
/// tamamlar. Onay e-postası gerekiyorsa bilgilendirme gösterilir ve null
/// ile kapanır.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _termsAccepted = false;
  bool _newsletterAccepted = false;
  bool _isLoading = false;
  bool _isVerificationSent = false;
  String? _errorMessage;

  String _selectedAvatarId = kDefaultAvatarId;

  // Kayıtta yalnızca varsayılan (is_default) avatarlar seçilebilir; sunucu
  // (handle_new_user) başka bir değeri avatar_16_basic'e çeker. Kum
  // tanesiyle alınan, Premium ve lig ödülü avatarlar listede yok. Katalog
  // boşsa gömülü katalog kullanılır; liste hiçbir zaman boş kalmaz.
  List<AvatarCharacter> get _freeAvatars {
    final free = AvatarCharacter.allAvatars().where((a) => a.isFree).toList();
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
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    String? validationError;
    if (email.isEmpty || password.isEmpty) {
      validationError = l10n.errFillEmailPassword;
    } else if (password.length < 6) {
      validationError = l10n.errShortPassword;
    } else if (!_termsAccepted) {
      validationError = l10n.errAcceptTerms;
    }
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService.instance.registerUser(
        email: email,
        password: password,
        avatarId: _selectedAvatarId,
        name: name.isNotEmpty ? name : null,
        wantsNewsletter: _newsletterAccepted,
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
        name: name.isNotEmpty ? name : email.split('@').first,
        email: authUser.email ?? email,
        avatarId: AvatarCharacter.isFreeAvatarId(_selectedAvatarId) ? _selectedAvatarId : kDefaultAvatarId,
      );
      if (mounted) Navigator.pop<UserModel>(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = authErrorText(l10n, SupabaseService.instance.parseAuthError(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatars = _freeAvatars;
    final selectedAvatar = _selectedAvatarIn(avatars);
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppColors.darkOnSurface : AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            // Tablette ortalanmış form genişliği; kaydırma tüm genişlikte çalışır.
            child: ContentWidth(
              maxWidth: ContentWidth.form,
              child: _isVerificationSent
                  ? _buildVerificationSentView()
                  : AutofillGroup(
                      child: Column(
                        children: [
                          AvatarWidget(avatar: selectedAvatar, size: 80),
                          const SizedBox(height: 16),

                          Text(
                            l10n.createAccountTitle,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.createAccountSub,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_errorMessage != null) ...[
                            AuthErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 16),
                          ],

                          _buildAvatarPicker(l10n, isDark, avatars, selectedAvatar),

                          const SizedBox(height: 16),

                          // Full Name Input
                          _buildInputGroup(
                            label: l10n.nameSurname,
                            hint: l10n.fullNameHint,
                            icon: Icons.person_outline,
                            controller: _nameController,
                            autofillHints: const [AutofillHints.name],
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 14),

                          // Email Input
                          _buildInputGroup(
                            label: l10n.email,
                            hint: l10n.authEmailHint,
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            controller: _emailController,
                            autofillHints: const [AutofillHints.email],
                          ),
                          const SizedBox(height: 14),

                          // Password Input
                          _buildInputGroup(
                            label: l10n.password,
                            hint: '•••••••••',
                            icon: Icons.lock_outline,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Checkboxes Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    value: _termsAccepted,
                                    onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                                    activeColor: AppColors.primary,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: LegalConsentText(
                                      prefix: l10n.termsAgreePrefix,
                                      suffix: l10n.termsAgreeSuffix,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  CheckboxListTile(
                                    value: _newsletterAccepted,
                                    onChanged: (val) => setState(() => _newsletterAccepted = val ?? false),
                                    activeColor: AppColors.primary,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: Text(
                                      l10n.updatesAgree,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Register Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
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
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            l10n.registerBtn,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward, size: 18),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Login Link (dar ekranda ya da büyük yazıda alt satıra geçer)
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l10n.alreadyHaveAccount,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  l10n.loginBtn,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker(
    AppLocalizations l10n,
    bool isDark,
    List<AvatarCharacter> avatars,
    AvatarCharacter selectedAvatar,
  ) {
    final isTurkish = LanguageService.instance.isTurkish;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(avatar: selectedAvatar, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.selectCharacter,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                    Text(
                      selectedAvatar.getName(isTurkish),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Telefonda 3 sütun (bugünkü); tablette form genişliğinde 4 sütun.
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth >= 420 ? 4 : 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final avatar = avatars[index];
                final isSelected = avatar.id == selectedAvatar.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatarId = avatar.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? avatar.backgroundColor
                          : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AvatarWidget(avatar: avatar, size: 38),
                        const SizedBox(height: 2),
                        Text(
                          avatar.getName(isTurkish),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    Iterable<String>? autofillHints,
    TextInputAction textInputAction = TextInputAction.next,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autocorrect: !obscureText && keyboardType != TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationSentView() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
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
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(l10n.backToLoginBtn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
