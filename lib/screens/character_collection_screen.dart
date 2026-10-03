import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class CharacterCollectionScreen extends StatefulWidget {
  final String selectedAvatarId;
  final int userCoins;
  final bool isPremium;
  final List<String> unlockedAvatars;
  final ValueChanged<String> onAvatarSelected;
  final ValueChanged<int>? onCoinsChanged;

  const CharacterCollectionScreen({
    super.key,
    required this.selectedAvatarId,
    required this.userCoins,
    required this.isPremium,
    required this.unlockedAvatars,
    required this.onAvatarSelected,
    this.onCoinsChanged,
  });

  @override
  State<CharacterCollectionScreen> createState() =>
      _CharacterCollectionScreenState();
}

class _CharacterCollectionScreenState extends State<CharacterCollectionScreen> {
  late String _currentSelection;
  late int _userCoins;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.selectedAvatarId;
    _userCoins = widget.userCoins;
  }

  List<AvatarCharacter> get _avatars {
    final all = AvatarCharacter.allAvatars().where((a) => !a.isLeagueAward).toList();
    final unlocked = <AvatarCharacter>[];
    final locked = <AvatarCharacter>[];
    for (final avatar in all) {
      if (avatar.isUnlocked(_userCoins, widget.isPremium, widget.unlockedAvatars)) {
        unlocked.add(avatar);
      } else {
        locked.add(avatar);
      }
    }
    return [...unlocked, ...locked];
  }

  List<AvatarCharacter> get _leagueAwardAvatars {
    return AvatarCharacter.allAvatars().where((a) => a.isLeagueAward).toList();
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
        title: Text(
          l10n.selectCharacter,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // Description text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              l10n.selectCharacterSub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),

          // Avatar Grid + Lig Kazanımları
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildAvatarCard(_avatars[index]),
                      childCount: _avatars.length,
                    ),
                  ),
                ),
                if (_leagueAwardAvatars.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.leagueAwardsTitle,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.leagueAwardsSub,
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
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAvatarCard(_leagueAwardAvatars[index]),
                        childCount: _leagueAwardAvatars.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom confirm button
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(

                onPressed: () async {
                  if (_currentSelection != widget.selectedAvatarId) {
                    await SupabaseService.instance.setEquippedAvatar(_currentSelection);
                  }
                  widget.onAvatarSelected(_currentSelection);
                  if (context.mounted) Navigator.pop(context);
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.confirmSelection,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(AvatarCharacter avatar) {
    final isSelected = _currentSelection == avatar.id;
    final isUnlocked = avatar.isUnlocked(_userCoins, widget.isPremium, widget.unlockedAvatars);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(

      onTap: () {
        if (isUnlocked) {
          setState(() => _currentSelection = avatar.id);
        } else if (avatar.isLeagueAward) {
          final l10n = AppLocalizations.of(context)!;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                l10n.leagueAwardLockedTitle,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: avatar.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: AvatarWidget(avatar: avatar, size: 88),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.leagueAwardLockedBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.leagueAwardLockedOk, style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                LanguageService.instance.isTurkish ? 'Satın Al' : 'Purchase',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: avatar.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: AvatarWidget(avatar: avatar, size: 88),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LanguageService.instance.isTurkish
                        ? '${avatar.getName(true)} avatarını ${avatar.requiredCoins} kum tanesine satın almak ister misin?'
                        : 'Do you want to purchase ${avatar.getName(false)} for ${avatar.requiredCoins} coins?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(LanguageService.instance.isTurkish ? 'İptal' : 'Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (_userCoins < avatar.requiredCoins) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(LanguageService.instance.isTurkish ? 'Yetersiz bakiye!' : 'Not enough coins!'),
                      ));
                      return;
                    }

                    final newCoins = await SupabaseService.instance.purchaseAvatar(avatar.id);
                    if (newCoins != null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(LanguageService.instance.isTurkish ? 'Satın alındı!' : 'Purchased!'),
                      ));
                      setState(() {
                        widget.unlockedAvatars.add(avatar.id);
                        _currentSelection = avatar.id;
                        _userCoins = newCoins;
                      });
                      widget.onCoinsChanged?.call(newCoins);
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(LanguageService.instance.isTurkish ? 'Hata oluştu' : 'Error occurred'),
                      ));
                    }
                  },
                  child: Text(LanguageService.instance.isTurkish ? 'Satın Al' : 'Purchase', style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? avatar.backgroundColor
              : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar Image
                  AvatarWidget(
                    avatar: avatar,
                    size: 54,
                    isUnlocked: isUnlocked,
                  ),
                  const SizedBox(height: 6),
                  // Name (Full, no truncation, max 2 lines)
                  Text(
                    avatar.getName(LanguageService.instance.isTurkish),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),

            // Selection checkmark
            if (isSelected)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),

            // Lock overlay if not unlocked
            if (!isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          avatar.isLeagueAward ? Icons.emoji_events_rounded : Icons.lock_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        if (!avatar.isLeagueAward) ...[
                          const SizedBox(height: 4),
                          Text(
                            avatar.isPremiumOnly && !widget.isPremium
                                ? avatar.unlockLabel(widget.isPremium)
                                : '🪙 ${avatar.unlockLabel(widget.isPremium)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
