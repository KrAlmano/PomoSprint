import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../services/language_service.dart';
import '../theme.dart';

class CharacterCollectionScreen extends StatefulWidget {
  final String selectedAvatarId;
  final int totalStudyMinutes;
  final ValueChanged<String> onAvatarSelected;

  const CharacterCollectionScreen({
    super.key,
    required this.selectedAvatarId,
    required this.totalStudyMinutes,
    required this.onAvatarSelected,
  });

  @override
  State<CharacterCollectionScreen> createState() =>
      _CharacterCollectionScreenState();
}

class _CharacterCollectionScreenState extends State<CharacterCollectionScreen> {
  late String _currentSelection;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.selectedAvatarId;
  }

  List<AvatarCharacter> get _avatars => AvatarCharacter.allAvatars();

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

          // Avatar Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: _avatars.length,
                itemBuilder: (context, index) =>
                    _buildAvatarCard(_avatars[index]),
              ),
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
                onPressed: () {
                  widget.onAvatarSelected(_currentSelection);
                  Navigator.pop(context);
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
    final isUnlocked = avatar.isUnlocked(widget.totalStudyMinutes);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: isUnlocked
          ? () {
              setState(() => _currentSelection = avatar.id);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isUnlocked
              ? (isSelected
                  ? avatar.backgroundColor
                  : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest))
              : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
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
                      color: isUnlocked
                          ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),

            // Lock overlay
            if (!isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lock,
                      color: (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                      size: 24,
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }
}
