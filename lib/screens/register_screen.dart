import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  final ValueChanged<UserModel> onRegisterSuccess;

  const RegisterScreen({
    super.key,
    required this.onRegisterSuccess,
  });

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
  String? _errorMessage;

  String _selectedAvatarId = 'avatar_16_basic';
  // Lig ödülü avatarları (cost_coins=0 olduğu için bu filtreden normalde
  // geçerdi) kayıt ekranında ASLA seçilebilir olmamalı — yalnızca lig
  // sıralamasında ilk 3'e girerek kazanılırlar.
  final List<AvatarCharacter> _allAvatars = AvatarCharacter.allAvatars()
      .where((a) => !a.isPremiumOnly && a.requiredCoins == 0 && !a.isLeagueAward)
      .toList();

  // Not: _allAvatars sunucudan (avatars tablosu) gelen listeye bağlı.
  // Ağ sorunu ya da geçici bir gecikme yüzünden boş kalırsa .first çağrısı
  // çökmesin diye null döndürüp seçici bölümünü UI'da tamamen gizliyoruz —
  // kayıt olma akışı avatar seçmeden de sorunsuz devam edebilmeli.
  AvatarCharacter? get _selectedAvatar {
    if (_allAvatars.isEmpty) return null;
    return _allAvatars.firstWhere(
      (a) => a.id == _selectedAvatarId,
      orElse: () => _allAvatars.first,
    );
  }


  bool _isVerificationSent = false;

  Future<void> _openLegalUrl(String path) async {
    final uri = Uri.parse('https://pomosprint.app/$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleRegister() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = l10n.errFillEmailPassword;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = l10n.errShortPassword;
      });
      return;
    }

    if (!_termsAccepted) {
      setState(() {
        final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
        _errorMessage = isTurkish 
            ? 'Lütfen Kullanım Şartları ve Gizlilik Politikasını kabul edin.' 
            : 'Please accept the Terms of Service and Privacy Policy.';
      });
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

      // registerUser() beklenirken bu ekran dispose edilmiş olabilir
      // (örn. global auth-state listener'ın tetiklediği navigasyon) —
      // setState() öncesi mounted kontrolü şart.
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response?.session != null) {
        // Confirm Email is OFF (or auto-confirmed): Direct login!
        final displayName = name.isNotEmpty ? name : email.split('@').first;
        final user = UserModel(
          name: displayName,
          email: email,
          avatarId: _selectedAvatarId,
        );
        if (mounted) {
          Navigator.pop(context);
          widget.onRegisterSuccess(user);
        }
      } else {
        // Confirm Email is ON: Show verification email sent screen
        setState(() {
          _isVerificationSent = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = SupabaseService.instance.parseAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _isVerificationSent
                  ? _buildVerificationSentView()
                  : Column(
                      children: [
                        // Seçili karakteri gösteren avatar başlığı (avatar
                        // listesi boşsa — örn. ağ sorunu — genel kum saati
                        // ikonuna düşer).
                        _selectedAvatar != null
                            ? AvatarWidget(avatar: _selectedAvatar!, size: 80)
                            : Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.hourglass_bottom_rounded,
                                    size: 40,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
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

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.red.shade900.withValues(alpha: 0.25) : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: isDark ? Colors.red.shade300 : Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.red.shade200 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Avatar Picker Section (Set of 9 avatars)
                        // Sunucudan avatar listesi gelmediyse (ör. geçici ağ sorunu)
                        // bu bölüm tamamen atlanır — kayıt olma avatar seçmeden de devam eder.
                        if (_allAvatars.isNotEmpty)
                        Container(
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
                                  AvatarWidget(
                                    avatar: _selectedAvatar!,
                                    size: 40,
                                  ),
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
                                          _selectedAvatar!.getName(LanguageService.instance.isTurkish),
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

                              // 3x3 Avatar Choice Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: _allAvatars.length,
                                itemBuilder: (context, index) {
                                  final avatar = _allAvatars[index];
                                  final isSelected = avatar.id == _selectedAvatarId;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedAvatarId = avatar.id);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? avatar.backgroundColor
                                            : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          AvatarWidget(
                                            avatar: avatar,
                                            size: 38,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            avatar.getName(LanguageService.instance.isTurkish),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            softWrap: true,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
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
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Full Name Input
                        _buildInputGroup(
                          label: l10n.nameSurname,
                          hint: l10n.fullNameHint,
                          icon: Icons.person_outline,
                          controller: _nameController,
                        ),
                        const SizedBox(height: 14),

                        // Email Input
                        _buildInputGroup(
                          label: l10n.email,
                          hint: 'ornek@posta.com',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                        ),
                        const SizedBox(height: 14),

                        // Password Input
                        _buildInputGroup(
                          label: l10n.password,
                          hint: '•••••••••',
                          icon: Icons.lock_outline,
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
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
                                  onChanged: (val) =>
                                      setState(() => _termsAccepted = val ?? false),
                                  activeColor: AppColors.primary,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                      ),
                                      children: [
                                        TextSpan(text: l10n.termsAgreePrefix),
                                        TextSpan(
                                          text: l10n.termsLinkTerms,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _openLegalUrl('terms.html'),
                                        ),
                                        TextSpan(text: l10n.termsAgreeConnector),
                                        TextSpan(
                                          text: l10n.termsLinkPrivacy,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _openLegalUrl('privacy.html'),
                                        ),
                                        TextSpan(text: l10n.termsAgreeSuffix),
                                      ],
                                    ),
                                  ),
                                ),
                                CheckboxListTile(
                                  value: _newsletterAccepted,
                                  onChanged: (val) => setState(
                                      () => _newsletterAccepted = val ?? false),
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
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        l10n.registerBtn,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
