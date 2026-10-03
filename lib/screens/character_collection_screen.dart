import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/social/social_error_text.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';

/// Avatar koleksiyonu: sahip olunan avatar kuşanılır, sahip olunmayan
/// satın alınır (bakiyenin yetmesi sahiplik sayılmaz). Satın alma ve kuşanma
/// sunucu onayından sonra uygulanır; sonuç servisteki currentUser üzerinden
/// profile ve ana ekrana yansır.
class CharacterCollectionScreen extends StatefulWidget {
  final UserModel user;

  const CharacterCollectionScreen({super.key, required this.user});

  @override
  State<CharacterCollectionScreen> createState() => _CharacterCollectionScreenState();
}

class _CharacterCollectionScreenState extends State<CharacterCollectionScreen> {
  late final String _equippedId = widget.user.avatarId;
  late String _selection = widget.user.avatarId;
  late int _coins = widget.user.coins;
  // Üst bileşenin listesi değiştirilemez; satın alınanlar yerel kopyaya eklenir.
  late final List<String> _unlocked = List.of(widget.user.unlockedAvatars);
  late List<AvatarCharacter> _shopAvatars;
  late final List<AvatarCharacter> _leagueAwards =
      AvatarCharacter.allAvatars().where((a) => a.isLeagueAward).toList();
  bool _isSaving = false;
  String? _purchasingId;

  // Izgara ~120 px hücrelerle kurulur: dikey telefonda bugünkü gibi 3 sütun,
  // yatay telefonda ve tablette genişliğe göre daha fazla sütun.
  static const double _maxTileExtent = 120;
  static const double _tileSpacing = 12;
  static const double _tileAspectRatio = 0.82;

  // Diyaloglar tablette ekran boyunca genişlemez (Material 3 en dar 280).
  static const BoxConstraints _dialogConstraints = BoxConstraints(minWidth: 280, maxWidth: ContentWidth.form);

  @override
  void initState() {
    super.initState();
    _sortShop();
    SupabaseService.instance.currentUser.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    SupabaseService.instance.currentUser.removeListener(_onUserChanged);
    super.dispose();
  }

  // Ekran açıkken biten bir seans bakiyeyi değiştirebilir.
  void _onUserChanged() {
    final user = SupabaseService.instance.currentUser.value;
    if (user == null || !mounted) return;
    setState(() {
      _coins = user.coins;
      for (final id in user.unlockedAvatars) {
        if (!_unlocked.contains(id)) _unlocked.add(id);
      }
      _sortShop();
    });
  }

  // Sahip olunanlar önce; liste yalnızca sahiplik değişince yeniden kurulur.
  // Edinme yolu olmayan (sahip olunmayan) Premium avatarlar listelenmez.
  void _sortShop() {
    final shop = AvatarCharacter.allAvatars()
        .where((a) => a.isListedInShop(unlockedAvatars: _unlocked, isPremium: widget.user.isPremium))
        .toList();
    _shopAvatars = [
      ...shop.where((a) => a.isOwned(_unlocked)),
      ...shop.where((a) => !a.isOwned(_unlocked)),
    ];
  }

  bool get _isTurkish => AppLocalizations.of(context)!.localeName == 'tr';

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _onAvatarTap(AvatarCharacter avatar) {
    if (_purchasingId != null || _isSaving) return;
    if (avatar.isOwned(_unlocked)) {
      setState(() => _selection = avatar.id);
    } else if (avatar.isLeagueAward) {
      final l10n = AppLocalizations.of(context)!;
      // Canlı ödül kuralı: 1. → *_monthly (Şampiyonluk), 2.-3. → *_weekly (Podyum).
      final body = avatar.isChampionAward
          ? l10n.leagueAwardLockedBodyChampion
          : (avatar.isPodiumAward ? l10n.leagueAwardLockedBodyPodium : l10n.leagueAwardLockedBody);
      unawaited(_showInfoDialog(avatar, l10n.leagueAwardLockedTitle, body));
    } else if (avatar.isPremiumOnly && !widget.user.isPremium) {
      final l10n = AppLocalizations.of(context)!;
      unawaited(_showInfoDialog(avatar, l10n.avatarPremiumTitle, l10n.avatarPremiumBody));
    } else {
      unawaited(_confirmPurchase(avatar));
    }
  }

  Future<void> _confirmPurchase(AvatarCharacter avatar) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = avatar.getName(_isTurkish);
    final premiumUnlock = avatar.canUnlockWithPremium(widget.user.isPremium);
    final affordable = premiumUnlock || avatar.canAfford(_coins);
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final shortHeight = Responsive.of(context).isShortHeight;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Kısa ekranda (yatay telefon) içerik kaydırılır; tablette diyalog
        // uzun metinle ekran boyunca genişlemez.
        scrollable: true,
        constraints: _dialogConstraints,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          premiumUnlock ? l10n.avatarPremiumTitle : l10n.avatarPurchaseTitle,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogAvatar(avatar, small: shortHeight),
            const SizedBox(height: 16),
            Text(
              premiumUnlock
                  ? l10n.avatarPremiumUnlockBody(name)
                  : l10n.avatarPurchaseBody(name, avatar.requiredCoins),
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
            if (!premiumUnlock) ...[
              const SizedBox(height: 10),
              Text(
                l10n.avatarBalance(_coins),
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              if (!affordable) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.avatarNotEnoughCoins(avatar.requiredCoins - _coins),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: affordable ? () => Navigator.pop(ctx, true) : null,
            child: Text(premiumUnlock ? l10n.avatarUnlockBtn : l10n.avatarPurchaseTitle),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _purchase(avatar);
  }

  Future<void> _purchase(AvatarCharacter avatar) async {
    if (_purchasingId != null) return;
    final l10n = AppLocalizations.of(context)!;
    final name = avatar.getName(_isTurkish);
    setState(() => _purchasingId = avatar.id);
    try {
      final newCoins = await SupabaseService.instance.purchaseAvatar(avatar.id);
      if (!mounted) return;
      setState(() {
        _coins = newCoins;
        if (!_unlocked.contains(avatar.id)) _unlocked.add(avatar.id);
        _selection = avatar.id;
        _sortShop();
      });
      _showSnack(l10n.avatarPurchased(name), color: Colors.green);
    } catch (e) {
      debugPrint('[AVATAR] Satın alma başarısız: $e');
      if (mounted) _showSnack(socialErrorText(l10n, e), color: Colors.red);
    } finally {
      if (mounted) setState(() => _purchasingId = null);
    }
  }

  // Kuşanma yalnızca sunucu onaylarsa uygulanır; hata olursa ekran açık
  // kalır ve önceki avatar kuşanılı kalır.
  Future<void> _confirmSelection() async {
    if (_isSaving || _purchasingId != null) return;
    if (_selection == _equippedId) {
      Navigator.pop(context);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.setEquippedAvatar(_selection);
      if (mounted) Navigator.pop(context, _selection);
    } catch (e) {
      debugPrint('[AVATAR] Kuşanma başarısız: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(socialErrorText(l10n, e), color: Colors.red);
    }
  }

  Future<void> _showInfoDialog(AvatarCharacter avatar, String title, String body) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shortHeight = Responsive.of(context).isShortHeight;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        constraints: _dialogConstraints,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogAvatar(avatar, small: shortHeight),
            const SizedBox(height: 16),
            Text(
              body,
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
  }

  // Yatay telefonda diyalog avatarı küçülür; metin ve eylemlere yer kalır.
  Widget _dialogAvatar(AvatarCharacter avatar, {bool small = false}) {
    return Container(
      padding: EdgeInsets.all(small ? 8 : 12),
      decoration: BoxDecoration(color: avatar.backgroundColor, shape: BoxShape.circle),
      child: AvatarWidget(avatar: avatar, size: small ? 56 : 88),
    );
  }

  /// [width] genişliğindeki ızgara için ~[_maxTileExtent] px hücreli düzen
  /// (SliverGridDelegateWithMaxCrossAxisExtent ile aynı sütun hesabı).
  /// Hücre yüksekliği en-boy oranından gelir; büyük metin ölçeğinde iki
  /// satırlık ismin sığacağı yüksekliğin altına inmez.
  SliverGridDelegate _gridDelegate(double width, TextScaler textScaler) {
    final count = math.max(1, (width / (_maxTileExtent + _tileSpacing)).ceil());
    final tileWidth = (width - _tileSpacing * (count - 1)) / count;
    // Kart: 8 px kenar + 54 px avatar + 6 px boşluk + iki satır isim + pay.
    final contentHeight = 2 * 8 + 54 + 6 + 2 * textScaler.scale(12) * 1.15 + 12;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      crossAxisSpacing: _tileSpacing,
      mainAxisSpacing: _tileSpacing,
      mainAxisExtent: math.max(tileWidth / _tileAspectRatio, contentHeight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final shortHeight = Responsive.of(context).isShortHeight;
    final textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.selectCharacter,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: l10n.avatarBalance(_coins),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '🪙 $_coins',
                  semanticsLabel: l10n.avatarBalance(_coins),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimaryFixed,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Yatay telefonda çentik tarafı korunur; tablette ızgara pano
      // genişliğinde ortalanır ve sütun sayısı genişliğe göre artar.
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(24.0, (constraints.maxWidth - ContentWidth.dashboard) / 2);
            final gridDelegate = _gridDelegate(constraints.maxWidth - 2 * side, textScaler);
            final subtitle = ContentWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  l10n.selectCharacterSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: muted, height: 1.5),
                ),
              ),
            );
            return Column(
              children: [
                // Kısa ekranda açıklama ızgarayla birlikte kayar; sabit
                // kalınca ızgaraya birkaç satır kalıyordu.
                if (!shortHeight) subtitle,
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      if (shortHeight) SliverToBoxAdapter(child: subtitle),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: side),
                        sliver: SliverGrid.builder(
                          gridDelegate: gridDelegate,
                          itemCount: _shopAvatars.length,
                          itemBuilder: (context, index) => _buildAvatarCard(_shopAvatars[index]),
                        ),
                      ),
                      if (_leagueAwards.isNotEmpty) ...[
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(side, 28, side, 4),
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
                                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(l10n.leagueAwardsSub, style: TextStyle(fontSize: 12, color: muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(side, 8, side, 24),
                          sliver: SliverGrid.builder(
                            gridDelegate: gridDelegate,
                            itemCount: _leagueAwards.length,
                            itemBuilder: (context, index) => _buildAvatarCard(_leagueAwards[index]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildConfirmBar(l10n, isDark, shortHeight),
              ],
            );
          },
        ),
      ),
    );
  }

  // Alt onay çubuğu. Tablette düğme form genişliğinde ortalanır; yatay
  // telefonda daha ince tutulur (ızgaraya yer kalır).
  Widget _buildConfirmBar(AppLocalizations l10n, bool isDark, bool shortHeight) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, shortHeight ? 8 : 16, 24, shortHeight ? math.max(8.0, bottomInset) : 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
            width: 1,
          ),
        ),
      ),
      child: ContentWidth(
        maxWidth: ContentWidth.form,
        child: SizedBox(
          width: double.infinity,
          height: shortHeight ? 48 : 56,
          child: ElevatedButton(
            onPressed: _isSaving || _purchasingId != null ? null : _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.confirmSelection,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard(AvatarCharacter avatar) {
    final isSelected = _selection == avatar.id;
    final isOwned = avatar.isOwned(_unlocked);
    final isPurchasing = _purchasingId == avatar.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onAvatarTap(avatar),
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
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 12 : 4,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AvatarWidget(avatar: avatar, size: 54, isUnlocked: isOwned),
                  const SizedBox(height: 6),
                  Text(
                    avatar.getName(_isTurkish),
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
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            if (!isOwned) Positioned.fill(child: _buildLockOverlay(avatar, isPurchasing)),
          ],
        ),
      ),
    );
  }

  Widget _buildLockOverlay(AvatarCharacter avatar, bool isPurchasing) {
    final IconData icon;
    String? label;
    if (avatar.isLeagueAward) {
      icon = Icons.emoji_events_rounded;
    } else if (avatar.isPremiumOnly) {
      icon = Icons.workspace_premium_rounded;
      label = 'Premium';
    } else {
      // Bakiye yetiyorsa "satın alınabilir" ikonu; yine de sahiplik değildir.
      icon = avatar.canAfford(_coins) ? Icons.shopping_bag_outlined : Icons.lock_rounded;
      label = '🪙 ${avatar.requiredCoins}';
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: isPurchasing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  if (label != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
