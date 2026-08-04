import 'package:flutter/material.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../models/category_model.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import 'character_collection_screen.dart';
import 'categories_screen.dart';
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String currentAvatarId;
  final int totalStudyMinutes;
  final int userPoints;
  final bool isDarkMode;
  final ValueChanged<String> onAvatarChanged;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onLogout;
  final List<CourseCategory> categories;
  final Function(CourseCategory) onAddCategory;
  final Function(String) onDeleteCategory;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.currentAvatarId,
    required this.totalStudyMinutes,
    required this.userPoints,
    required this.isDarkMode,
    required this.onAvatarChanged,
    this.onNameChanged,
    required this.onDarkModeChanged,
    required this.onLogout,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _avatarId;
  bool _notificationsEnabled = true;
  late bool _darkModeEnabled;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSavingName = false;
  bool _isNameEditing = false;

  @override
  void initState() {
    super.initState();
    _avatarId = widget.currentAvatarId;
    _darkModeEnabled = widget.isDarkMode;
    _nameController = TextEditingController(text: widget.userName);
    _emailController = TextEditingController(text: widget.userEmail);
  }

  void _openCategoryManagementSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: CategoriesScreen(
                  categories: widget.categories,
                  onAddCategory: widget.onAddCategory,
                  onDeleteCategory: widget.onDeleteCategory,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  AvatarCharacter get _currentAvatar {
    final avatars = AvatarCharacter.allAvatars();
    return avatars.firstWhere(
      (a) => a.id == _avatarId,
      orElse: () => avatars.first,
    );
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSavingName = true);
    final messenger = ScaffoldMessenger.of(context);
    final lang = LanguageService.instance;

    try {
      await SupabaseService.instance.updateUserName(widget.userEmail, newName);
      if (widget.onNameChanged != null) {
        widget.onNameChanged!(newName);
      }
      setState(() {
        _isNameEditing = false;
      });
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ ${lang.translate('name_updated_success')}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('⚠️ $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingName = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Avatar & Name Card Header
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainerLowest
                            : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Avatar with Edit Badge
                          GestureDetector(
                            onTap: _openCharacterCollection,
                            child: Stack(
                              children: [
                                AvatarWidget(
                                  avatar: _currentAvatar,
                                  size: 96,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text
                                : 'Kullanıcı',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentAvatar.getName(lang.isTurkish),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Points / Streak Badge (Hanging top-right)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 16,
                              color: AppColors.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.userPoints} ${lang.translate('points_unit')}',
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
                ),

                const SizedBox(height: 20),

                // Category Management Banner Button
                InkWell(
                  onTap: _openCategoryManagementSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerLow
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.category_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.translate('manage_categories'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lang.translate('manage_categories_sub'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),



                const SizedBox(height: 20),

                // Profile Information Form Card (Editable Name with Pencil Icon)
                _buildSectionCard(
                  title: lang.translate('edit_profile').toUpperCase(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Label + Pencil Icon Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang.translate('name_surname'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isNameEditing = !_isNameEditing;
                              });
                            },
                            icon: Icon(
                              _isNameEditing ? Icons.close : Icons.mode_edit_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            tooltip: lang.translate('edit_profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _nameController,
                        readOnly: !_isNameEditing,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          suffixIcon: _isNameEditing
                              ? IconButton(
                                  icon: _isSavingName
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.check_circle, color: Colors.green),
                                  onPressed: _saveName,
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurfaceContainerLow
                              : AppColors.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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
                            label: Text(lang.translate('save')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Email Field (Read-only with Lock Icon)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang.translate('email'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                          Icon(Icons.lock_outline, size: 16, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        readOnly: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.mail_outline, size: 20),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurfaceContainerLow.withValues(alpha: 0.6)
                              : AppColors.surfaceContainerLow.withValues(alpha: 0.6),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.translate('email_readonly_hint'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Language Selection Card with Flags 🇹🇷 / 🇬🇧
                _buildSectionCard(
                  title: lang.translate('app_language').toUpperCase(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildLanguageTile(
                              flag: '🇹🇷',
                              label: 'Türkçe',
                              isSelected: lang.isTurkish,
                              onTap: () => lang.setLanguage(AppLanguage.tr),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLanguageTile(
                              flag: '🇬🇧',
                              label: 'English',
                              isSelected: !lang.isTurkish,
                              onTap: () => lang.setLanguage(AppLanguage.en),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Preferences Card (with Dark Mode toggle!)
                _buildSectionCard(
                  title: lang.translate('preferences').toUpperCase(),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _notificationsEnabled,
                          onChanged: (val) =>
                              setState(() => _notificationsEnabled = val),
                          title: Text(
                            lang.translate('notifications'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          secondary: Icon(Icons.notifications_outlined,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                          activeThumbColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(height: 16),
                        SwitchListTile(
                          value: _darkModeEnabled,
                          onChanged: (val) {
                            setState(() => _darkModeEnabled = val);
                            widget.onDarkModeChanged(val);
                          },
                          title: Text(
                            lang.translate('dark_mode'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          secondary: Icon(Icons.dark_mode_outlined,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                          activeThumbColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    },
                    icon: const Icon(Icons.logout, color: AppColors.primary),
                    label: Text(
                      lang.translate('logout'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Delete Account Button (Red Warning)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmDeleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    label: Text(
                      lang.translate('delete_account'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageTile({
    required String flag,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.onPrimaryContainer
                    : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  void _openCharacterCollection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterCollectionScreen(
          selectedAvatarId: _avatarId,
          totalStudyMinutes: widget.totalStudyMinutes,
          onAvatarSelected: (newId) {
            setState(() => _avatarId = newId);
            widget.onAvatarChanged(newId);
          },
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(lang.translate('delete_account'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Hesabınızı ve tüm verilerinizi kalıcı olarak silmek istediğinizden emin misiniz?\n\nBu işlem veritabanından profilinizi ve çalışma geçmişinizi tamamen siler ve geri alınamaz.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('cancel'), style: TextStyle(color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              nav.pop(); // Close dialog
              try {
                await SupabaseService.instance.deleteUserAccount(widget.userEmail);
                if (mounted) {
                  nav.pop(); // Close profile screen
                  widget.onLogout(); // Return to login
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('⚠️ Hesabınız silinirken bir hata oluştu: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(lang.translate('delete_account'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLow
                  : AppColors.surfaceContainerLow,
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
