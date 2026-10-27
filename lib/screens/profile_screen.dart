import 'dart:async';

import 'categories_management_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../widgets/auth/account_texts.dart';
import '../widgets/auth/change_password_dialog.dart';
import '../widgets/auth/legal_links.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/game_rules.dart';
import '../widgets/social/social_error_text.dart';
import '../theme.dart';
import '../utils/app_info.dart';
import '../utils/name_filter.dart';
import '../utils/responsive.dart';
import '../utils/user_report.dart';
import '../services/hidden_users.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/timer_persistence.dart';
import 'character_collection_screen.dart';

/// Profil ve ayarlar. Kullanıcı bilgisi tek kaynaktan
/// (SupabaseService.currentUser) okunur; isim, avatar ve satın alma
/// değişiklikleri servis tarafından oraya yazılır ve shell'e de yansır.
class ProfileScreen extends StatefulWidget {
  final SupabaseService? service;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onLogout;

  /// Çıkış onayındaki "süren seans" kontrolü (testte değiştirilir; varsayılan:
  /// cihazdaki sayaç kaydı, TimerPersistence).
  @visibleForTesting
  final Future<bool> Function(String ownerKey)? activeTimerSessionCheck;

  const ProfileScreen({
    super.key,
    required this.onDarkModeChanged,
    required this.onLogout,
    this.activeTimerSessionCheck,
    this.service,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  static const int _nameMinLength = 2;
  static const int _nameMaxLength = 30;

  SupabaseService get _service => widget.service ?? SupabaseService.instance;
  UserModel? _user;
  // Anahtar "tercih açık VE sistem izni var" durumunu gösterir.
  bool _notificationsEnabled = true;
  // Tercih açık ama sistem izni yok (ör. ilk BAŞLAT'ta reddedildi).
  bool _notificationsBlocked = false;
  bool _isUpdatingNotifications = false;
  String? _appVersion;
  bool _socialVisibilityEnabled = true;
  bool _isLoadingSocialVisibility = true;
  bool _isUpdatingSocialVisibility = false;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _isSavingName = false;
  bool _isNameEditing = false;
  String? _nameError;
  bool _isDeleting = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _user = _service.currentUser.value;
    _nameController = TextEditingController(text: _user?.name ?? '');
    _emailController = TextEditingController(text: _user?.email ?? '');
    _service.currentUser.addListener(_onUserChanged);
    HiddenUsersStore.instance.hidden.addListener(_onHiddenUsersChanged);
    unawaited(HiddenUsersStore.instance.load(_user?.id));
    unawaited(_loadSocialVisibility());
    unawaited(_loadNotificationPreference());
    unawaited(_loadAppVersion());
    WidgetsBinding.instance.addObserver(this);
  }

  // Kullanıcı sistem ayarlarından dönünce bildirim izni yeniden okunur.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isUpdatingNotifications) {
      unawaited(_loadNotificationPreference());
    }
  }

  Future<void> _loadAppVersion() async {
    final version = await loadAppVersion();
    if (mounted && version != null) setState(() => _appVersion = version);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.currentUser.removeListener(_onUserChanged);
    HiddenUsersStore.instance.hidden.removeListener(_onHiddenUsersChanged);
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  HiddenUserList get _hiddenUsers => HiddenUsersStore.instance.hidden.value;

  void _onHiddenUsersChanged() {
    if (mounted) setState(() {});
  }

  // Bölüm başlıkları büyük harfle yazılır; Türkçede i → İ (Dart'ın
  // toUpperCase'i "TERCIHLER" üretiyordu).
  String _sectionTitle(String text) =>
      (LanguageService.instance.isTurkish ? text.replaceAll('i', 'İ') : text).toUpperCase();

  // Çıkış/hesap silme sırasında kullanıcı null olur; ekran kapanana kadar
  // son bilinen kullanıcı gösterilir.
  void _onUserChanged() {
    final user = _service.currentUser.value;
    if (user == null || !mounted) return;
    setState(() {
      _user = user;
      if (!_isNameEditing) _nameController.text = user.name;
      _emailController.text = user.email;
    });
  }

  Future<void> _loadSocialVisibility() async {
    final ownerId = _user?.id;
    final value = await _service.getSocialVisibility();
    if (!mounted || _service.currentUser.value?.id != ownerId) return;
    setState(() {
      _socialVisibilityEnabled = value;
      _isLoadingSocialVisibility = false;
    });
  }

  // Yalnızca kayıtlı tercihe değil sistem iznine de bakılır: izin
  // reddedildiyse anahtar kapalı görünür ve ayarları açan yol gösterilir;
  // hiç sorulmadıysa anahtar kapalıdır ama açınca sistem penceresi çıkar.
  Future<void> _loadNotificationPreference() async {
    final notifications = NotificationService.instance;
    final preference = await notifications.isEnabled();
    final permission = await notifications.permissionStatus();
    // Anahtar bu arada değiştirildiyse sonucu o akış yazar.
    if (!mounted || _isUpdatingNotifications) return;
    setState(() => _applyNotificationState(preference, permission));
  }

  void _applyNotificationState(bool preference, NotificationPermissionStatus permission) {
    _notificationsEnabled = NotificationService.effectiveEnabled(preference: preference, permission: permission);
    _notificationsBlocked = NotificationService.isBlockedBySystem(preference: preference, permission: permission);
  }

  Future<void> _openNotificationSettings() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final opened = await NotificationService.instance.openSystemSettings();
    if (!opened && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileNotificationsDenied), behavior: SnackBarBehavior.floating),
      );
    }
  }

  AvatarCharacter get _currentAvatar => AvatarCharacter.byId(_user?.avatarId);

  String? _validateName(AppLocalizations l10n, String name) {
    if (name.length < _nameMinLength) return l10n.profileNameTooShort;
    if (name.length > _nameMaxLength) return l10n.profileNameTooLong;
    if (NameFilter.isOffensive(name)) return l10n.nameNotAllowed;
    return null;
  }

  void _toggleNameEditing() {
    setState(() {
      _isNameEditing = !_isNameEditing;
      _nameError = null;
      // Vazgeçilince yazılan metin atılır.
      if (!_isNameEditing) _nameController.text = _user?.name ?? '';
    });
  }

  Future<void> _saveName() async {
    if (_isSavingName) return;
    final l10n = AppLocalizations.of(context)!;
    final newName = _nameController.text.trim();
    final validationError = _validateName(l10n, newName);
    if (validationError != null) {
      setState(() => _nameError = validationError);
      return;
    }
    if (newName == _user?.name) {
      _toggleNameEditing();
      return;
    }

    setState(() {
      _isSavingName = true;
      _nameError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.updateUserName(newName);
      if (!mounted) return;
      setState(() {
        _isNameEditing = false;
        _nameController.text = _service.currentUser.value?.name ?? newName;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ ${l10n.nameUpdatedSuccess}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[PROFILE] İsim kaydedilemedi: $e');
      if (mounted) setState(() => _nameError = socialErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    if (_isUpdatingNotifications) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final notifications = NotificationService.instance;
    setState(() {
      _notificationsEnabled = value;
      _isUpdatingNotifications = true;
    });
    var failed = false;
    try {
      // Açınca izin istenir (hiç sorulmadıysa sistem penceresi çıkar). İzin
      // verilmezse tercih açık kalır: anahtar kapalı görünür, "Ayarları aç"
      // çıkar ve izin ayarlardan verilip dönülünce anahtar kendiliğinden açılır.
      await notifications.setEnabled(value);
    } catch (e) {
      debugPrint('[PROFILE] Bildirim tercihi kaydedilemedi: $e');
      failed = true;
    }
    final preference = await notifications.isEnabled();
    final permission = await notifications.permissionStatus();
    if (!mounted) return;
    final blocked = NotificationService.isBlockedBySystem(preference: preference, permission: permission);
    final permissionDenied = !failed &&
        value &&
        !NotificationService.effectiveEnabled(preference: preference, permission: permission);
    setState(() {
      _applyNotificationState(preference, permission);
      _isUpdatingNotifications = false;
    });
    if (permissionDenied || failed) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(permissionDenied ? l10n.profileNotificationsDenied : l10n.profileSettingSaveError),
          behavior: SnackBarBehavior.floating,
          // İzin bir kez reddedilince sistem penceresi bir daha çıkmaz;
          // izin yalnızca sistem ayarlarından verilebilir.
          action: permissionDenied && blocked
              ? SnackBarAction(label: l10n.profileOpenSettings, onPressed: () => unawaited(_openNotificationSettings()))
              : null,
        ),
      );
    }
  }

  Future<void> _setSocialVisibility(bool value) async {
    if (_isLoadingSocialVisibility || _isUpdatingSocialVisibility) return;
    final previous = _socialVisibilityEnabled;
    final ownerId = _user?.id;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _socialVisibilityEnabled = value;
      _isUpdatingSocialVisibility = true;
    });
    try {
      await _service.setSocialVisibility(value);
    } catch (e) {
      debugPrint('[PROFILE] Sosyal görünürlük kaydedilemedi: $e');
      if (!mounted || _service.currentUser.value?.id != ownerId) return;
      setState(() => _socialVisibilityEnabled = previous);
      messenger.showSnackBar(
        SnackBar(
          content: Text(socialErrorText(l10n, e)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted && _service.currentUser.value?.id == ownerId) {
        setState(() => _isUpdatingSocialVisibility = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final user = _user;

    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              // Ekran okuyucuda "Geri" diye okunur.
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              lang.translate('profile_title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AvatarWidget(
                  avatar: _currentAvatar,
                  size: 36,
                ),
              ),
            ],
          ),
          // Yatay telefonda çentik tarafındaki içerik kenar boşluğuyla
          // korunur; tablette kartlar okunabilir genişlikte ortalanır.
          body: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ContentWidth(
                child: Column(
                  children: [
                    _buildHeader(lang, l10n, isDark, muted),
                    const SizedBox(height: 20),

                    // Kategori yönetimi: değişiklikler servisteki categoriesRevision
                    // ile ana ekrana yansır; dönüşte ayrıca bir şey yapılmaz.
                    _buildSectionCard(
                      title: lang.translate('categories_section_title'),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            lang.translate('manage_categories_tile_title'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            lang.translate('manage_categories_tile_sub'),
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                          trailing: Icon(Icons.chevron_right, color: muted),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CategoriesManagementScreen(isPremium: user?.isPremium ?? false),
                          )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildProfileForm(lang, l10n, isDark, muted),
                    const SizedBox(height: 20),

                    // Language Selection Card with Flags 🇹🇷 / 🇬🇧
                    _buildSectionCard(
                      title: _sectionTitle(lang.translate('app_language')),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildLanguageTile(
                              flag: '🇹🇷',
                              label: l10n.languageNativeTr,
                              isSelected: lang.isTurkish,
                              onTap: () => lang.setLanguage(AppLanguage.tr),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLanguageTile(
                              flag: '🇬🇧',
                              label: l10n.languageNativeEn,
                              isSelected: !lang.isTurkish,
                              onTap: () => lang.setLanguage(AppLanguage.en),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildPreferences(lang, isDark, muted),
                    const SizedBox(height: 20),

                    // Gizlilik ve yasal: gizlenen kullanıcılar, yasal metinler
                    // (İngilizce arayüzde /en/ sürümleri) ve hesap silme.
                    _buildPrivacyAndLegal(l10n, isDark, muted),
                    const SizedBox(height: 20),

                    // Yardım: oyun kuralları, destek e-postası ve sürüm.
                    _buildHelp(l10n, muted),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: (_isDeleting || _isLoggingOut) ? null : _confirmLogout,
                        icon: _isLoggingOut
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                              )
                            // Koyu temada darkPrimary (okunur kontrast).
                            : Icon(Icons.logout, color: Theme.of(context).colorScheme.primary),
                        label: Text(
                          lang.translate('logout'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(LanguageService lang, AppLocalizations l10n, bool isDark, Color muted) {
    final user = _user;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              // Ekran okuyucuda "Avatarı Değiştir" düğmesi.
              Semantics(
                button: true,
                enabled: user != null,
                label: lang.translate('change_avatar'),
                excludeSemantics: true,
                onTap: user == null ? null : () => _openCharacterCollection(user),
                child: GestureDetector(
                  onTap: user == null ? null : () => _openCharacterCollection(user),
                  child: Stack(
                    children: [
                      AvatarWidget(avatar: _currentAvatar, size: 96),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                (user?.name.isNotEmpty ?? false) ? user!.name : l10n.userDefault,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _currentAvatar.getName(lang.isTurkish),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: muted),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, size: 16, color: AppColors.onPrimaryContainer),
                const SizedBox(width: 4),
                Text(
                  l10n.rankingPoints(user?.lifetimePoints ?? 0),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm(LanguageService lang, AppLocalizations l10n, bool isDark, Color muted) {
    final fieldFill = isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow;
    return _buildSectionCard(
      title: _sectionTitle(lang.translate('edit_profile')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  lang.translate('name_surname'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                ),
              ),
              IconButton(
                onPressed: _isSavingName ? null : _toggleNameEditing,
                icon: Icon(
                  _isNameEditing ? Icons.close : Icons.mode_edit_outline_rounded,
                  size: 18,
                  // Koyu temada darkPrimary (okunur kontrast).
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: _isNameEditing ? l10n.cancel : lang.translate('edit_profile'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            readOnly: !_isNameEditing,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _saveName(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              errorText: _nameError,
              suffixIcon: _isNameEditing
                  ? IconButton(
                      icon: _isSavingName
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: l10n.save,
                      onPressed: _isSavingName ? null : _saveName,
                    )
                  : null,
              filled: true,
              fillColor: fieldFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: _isNameEditing
                    ? const BorderSide(color: AppColors.primary, width: 1.5)
                    : BorderSide.none,
              ),
            ),
          ),
          if (_isNameEditing) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isSavingName ? null : _saveName,
                icon: const Icon(Icons.save, size: 16),
                label: Text(l10n.save),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  lang.translate('email'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: muted),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            readOnly: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.mail_outline, size: 20),
              filled: true,
              fillColor: fieldFill.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.translate('email_readonly_hint'),
            style: TextStyle(fontSize: 11, color: muted),
          ),
          // Yalnızca e-posta/şifre hesabı (Google/Apple hesabında şifre yok).
          if (_service.canChangePassword) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.password_rounded, color: muted),
                title: Text(l10n.changePasswordTile, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                subtitle: Text(l10n.changePasswordTileSub, style: TextStyle(fontSize: 12, color: muted)),
                trailing: Icon(Icons.chevron_right, color: muted),
                onTap: () => showChangePasswordDialog(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferences(LanguageService lang, bool isDark, Color muted) {
    const titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    final l10n = AppLocalizations.of(context)!;
    return _buildSectionCard(
      title: _sectionTitle(lang.translate('preferences')),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Anahtar seans bitiş bildirimini ve kilit ekranı sayacını yönetir.
            // Sistem izni yoksa kapalı görünür ve ayarları açan düğme çıkar.
            SwitchListTile(
              value: _notificationsEnabled,
              onChanged: _isUpdatingNotifications ? null : _setNotificationsEnabled,
              title: Text(lang.translate('notifications'), style: titleStyle),
              subtitle: Text(
                _notificationsBlocked ? l10n.profileNotificationsBlockedSub : l10n.profileNotificationsLabelSub,
                style: TextStyle(
                  fontSize: 12,
                  color: _notificationsBlocked ? Theme.of(context).colorScheme.error : muted,
                ),
              ),
              secondary: Icon(
                _notificationsBlocked ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                color: muted,
              ),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (_notificationsBlocked)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _openNotificationSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(l10n.profileOpenSettings),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                ),
              ),
            const Divider(height: 16),
            // Anahtar her zaman o an uygulanan temayı gösterir.
            SwitchListTile(
              value: isDark,
              onChanged: widget.onDarkModeChanged,
              title: Text(lang.translate('dark_mode'), style: titleStyle),
              secondary: Icon(Icons.dark_mode_outlined, color: muted),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 16),
            // show_in_social_feed: aylık sıralama, sitedeki herkese açık liste
            // ve arkadaşların canlı listesi (lig grubu ve arkadaş listesi değil).
            SwitchListTile(
              value: _socialVisibilityEnabled,
              onChanged: (_isLoadingSocialVisibility || _isUpdatingSocialVisibility) ? null : _setSocialVisibility,
              title: Text(l10n.profileSocialVisibilityTitle, style: titleStyle),
              subtitle: Text(
                l10n.profileSocialVisibilitySub,
                style: TextStyle(fontSize: 12, color: muted),
              ),
              secondary: Icon(Icons.groups_outlined, color: muted),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required String flag,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.4),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          // Büyük metin ölçeğinde içerik küçültülmez; sığmazsa alt satıra geçer.
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              ExcludeSemantics(child: Text(flag, style: const TextStyle(fontSize: 22))),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.onPrimaryContainer
                      : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                ),
              ),
              if (isSelected) const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  void _openCharacterCollection(UserModel user) {
    unawaited(Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CharacterCollectionScreen(user: user)),
    ));
  }

  Widget _buildPrivacyAndLegal(AppLocalizations l10n, bool isDark, Color muted) {
    const titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    final subtitleStyle = TextStyle(fontSize: 12, color: muted);
    final hiddenCount = _hiddenUsers.length;

    Widget legalLink(IconData icon, String title, LegalPage page) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: muted),
          title: Text(title, style: titleStyle),
          trailing: Icon(Icons.open_in_new_rounded, size: 18, color: muted),
          onTap: () => openLegalPage(context, page),
        );

    return _buildSectionCard(
      title: _sectionTitle(l10n.profileLegalSectionTitle),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: hiddenCount > 0,
              leading: Icon(Icons.visibility_outlined, color: muted),
              title: Text(l10n.hiddenUsersTitle, style: titleStyle),
              subtitle: Text(l10n.hiddenUsersCount(hiddenCount), style: subtitleStyle),
              onTap: _showHiddenUsers,
            ),
            const Divider(height: 16),
            legalLink(Icons.description_outlined, l10n.termsOfServiceLink, LegalPage.terms),
            legalLink(Icons.privacy_tip_outlined, l10n.privacyPolicyLink, LegalPage.privacy),
            legalLink(Icons.gavel_rounded, l10n.kvkkNoticeLink, LegalPage.kvkk),
            const Divider(height: 16),
            // Uygulama içi hesap silme (App Store 5.1.1(v), Google Play).
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !_isDeleting,
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: Text(
                l10n.deleteAccount,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              subtitle: Text(l10n.deleteAccountSub, style: subtitleStyle),
              onTap: _confirmDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  // Yardım: oyun kuralları, destek e-postası (sürüm ve cihaz bilgisiyle) ve
  // görünür sürüm numarası.
  Widget _buildHelp(AppLocalizations l10n, Color muted) {
    const titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    final subtitleStyle = TextStyle(fontSize: 12, color: muted);
    final version = _appVersion;
    return _buildSectionCard(
      title: _sectionTitle(l10n.profileHelpSectionTitle),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lightbulb_outline_rounded, color: muted),
              title: Text(l10n.gameRulesTitle, style: titleStyle),
              subtitle: Text(l10n.gameRulesProfileSub, style: subtitleStyle),
              trailing: Icon(Icons.chevron_right, color: muted),
              onTap: () => showGameRulesSheet(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.mail_outline_rounded, color: muted),
              title: Text(l10n.profileSupportTitle, style: titleStyle),
              subtitle: Text(l10n.profileSupportSub, style: subtitleStyle),
              trailing: Icon(Icons.open_in_new_rounded, size: 18, color: muted),
              onTap: _contactSupport,
            ),
            if (version != null) ...[
              const Divider(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SelectableText(l10n.profileAppVersion(version), style: subtitleStyle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _contactSupport() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final uri = supportEmailUri(l10n, version: _appVersion, device: deviceDescription());
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (e) {
      debugPrint('[PROFILE] E-posta uygulaması açılamadı: $e');
    }
    if (opened || !mounted) return;
    // E-posta uygulaması yoksa adres gösterilir ve kopyalanabilir.
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.supportMailFailed(kSupportEmail)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l10n.reportCopyAddress,
        onPressed: () => unawaited(Clipboard.setData(const ClipboardData(text: kSupportEmail))),
      ),
    ));
  }

  // "Gizlenen kullanıcıları göster": hesabın gizleme listesi sıfırlanır.
  Future<void> _showHiddenUsers() async {
    final uid = _user?.id;
    if (uid == null || uid.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await HiddenUsersStore.instance.clear(uid);
    } catch (e) {
      debugPrint('[PROFILE] Gizlenen kullanıcılar sıfırlanamadı: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSettingSaveError), behavior: SnackBarBehavior.floating));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.hiddenUsersCleared), behavior: SnackBarBehavior.floating));
  }

  Future<int> _pendingCount() async {
    try {
      return await _service.getPendingSessionCount();
    } catch (e) {
      debugPrint('[PROFILE] Bekleyen seans sayısı okunamadı: $e');
      return _service.pendingSessionCount.value;
    }
  }

  /// Bekleyen seansları zaman aşımıyla göndermeyi dener; kalan sayıyı döndürür.
  Future<int> _trySendPending() async {
    try {
      final result = await _service.syncPendingSessions().timeout(const Duration(seconds: 12));
      return result.remaining;
    } catch (e) {
      debugPrint('[PROFILE] Bekleyen seanslar gönderilemedi: $e');
      return _pendingCount();
    }
  }

  // Süren ya da duraklatılmış seans (kabuk sahibi: uid, yoksa e-posta).
  Future<bool> _hasActiveTimerSession() async {
    final owner = _user?.id ?? _user?.email.toLowerCase();
    if (owner == null || owner.isEmpty) return false;
    final check = widget.activeTimerSessionCheck;
    if (check != null) return check(owner);
    return await TimerPersistence.instance.load(owner) != null;
  }

  /// Çıkış onayı. Önce bekleyen seanslar gönderilmeye çalışılır; hâlâ
  /// bekleyen varsa (24 saat içinde aynı hesapla girilmezse puanı kaybolur)
  /// ya da sayaç sürüyorsa bu söylenir.
  Future<void> _confirmLogout() async {
    if (_isLoggingOut || _isDeleting) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoggingOut = true);
    var pending = await _pendingCount();
    if (pending > 0) pending = await _trySendPending();
    final hasActiveSession = await _hasActiveTimerSession();
    if (!mounted) return;
    setState(() => _isLoggingOut = false);

    final choice = await showDialog<_LogoutChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: ContentWidth.form),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.logoutConfirmTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          logoutConfirmText(l10n, pendingCount: pending, hasActiveSession: hasActiveSession),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          if (pending > 0) ...[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, _LogoutChoice.sendThenLogout),
              child: Text(l10n.logoutSendAndExit),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, _LogoutChoice.logout),
              child: Text(l10n.logoutAnyway, style: const TextStyle(color: Colors.red)),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, _LogoutChoice.logout),
              child: Text(LanguageService.instance.translate('logout')),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _LogoutChoice.sendThenLogout) {
      setState(() => _isLoggingOut = true);
      final remaining = await _trySendPending();
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      if (remaining > 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.logoutSendFailed), behavior: SnackBarBehavior.floating));
        return;
      }
    }
    Navigator.pop(context);
    widget.onLogout();
  }

  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = await _pendingCount();
    if (!mounted) return;
    final confirmText = deleteAccountConfirmText(
      l10n,
      pendingCount: pending,
      appleReauthorization: _service.canReauthorizeWithApple,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // Kısa ekranda (yatay telefon) başlık ve metin kaydırılır; tablette
        // diyalog uzun metinle ekran boyunca genişlemez.
        scrollable: true,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: ContentWidth.form),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.deleteAccount, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          confirmText,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _deleteAccount();
  }

  // Apple kimliği olan hesapta (iOS) önce Apple'dan taze yetkilendirme kodu
  // istenir; servis token'ı iptal eder. Kullanıcı vazgeçerse silme yine
  // yapılır, giriş ekranı Ayarlar talimatını gösterir. Silme sürerken
  // kapatılamayan bir ilerleme diyaloğu gösterilir; bu sırada çıkış gibi
  // diğer eylemler yapılamaz. Yerel verinin temizliği, oturum kapatma ve
  // "hesabın silindi" açıklaması servis tarafından yapılır.
  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    final appleCode = _service.canReauthorizeWithApple ? await _service.requestAppleAuthorizationCode() : null;
    if (!mounted) return;
    final progressRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.profileDeleting)),
            ],
          ),
        ),
      ),
    );
    unawaited(navigator.push(progressRoute));

    try {
      await _service.deleteUserAccount(appleAuthorizationCode: appleCode);
      // Servis oturumu kapatır; AppGate tüm hesap route'larını kapatır.
      // Buradan pop yapmak aynı diyaloğu/profili ikinci kez kapatıyordu.
    } catch (e) {
      debugPrint('[PROFILE] Hesap silinemedi: $e');
      if (!mounted) return;
      if (progressRoute.isActive) navigator.removeRoute(progressRoute);
      setState(() => _isDeleting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.profileDeleteError),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

enum _LogoutChoice { logout, sendThenLogout }
