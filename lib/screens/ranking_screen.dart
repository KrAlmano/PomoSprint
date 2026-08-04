import 'dart:async';
import 'package:flutter/material.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../theme.dart';
import '../models/user_model.dart';

class RankingScreen extends StatefulWidget {
  final UserModel? currentUser;

  const RankingScreen({
    super.key,
    this.currentUser,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  // 0: Haftalık (Weekly), 1: Aylık (Monthly)
  int _selectedTab = 0;
  List<Map<String, dynamic>> _realUsers = [];
  bool _isLoading = true;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadRankingData();
    SupabaseService.instance.addRankingListener(_onRankingUpdate);
    _startLiveCountdownTimer();
  }

  void _startLiveCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onRankingUpdate() {
    _loadRankingData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    SupabaseService.instance.removeRankingListener(_onRankingUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RankingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.totalMinutes != widget.currentUser?.totalMinutes ||
        oldWidget.currentUser?.points != widget.currentUser?.points ||
        oldWidget.currentUser?.avatarId != widget.currentUser?.avatarId) {
      _loadRankingData();
    }
  }

  DateTime get _nextWeeklyReset {
    final now = DateTime.now();
    // Monday is 1, Sunday is 7.
    // Days until next Monday 00:00:00:
    int daysUntilNextMonday = 8 - now.weekday;
    final nextMonday = DateTime(now.year, now.month, now.day + daysUntilNextMonday, 0, 0, 0);
    return nextMonday;
  }

  DateTime get _nextMonthlyReset {
    final now = DateTime.now();
    final nextMonth = now.month == 12 ? 1 : now.month + 1;
    final nextYear = now.month == 12 ? now.year + 1 : now.year;
    return DateTime(nextYear, nextMonth, 1, 0, 0, 0);
  }

  String _getRemainingTimeString(DateTime targetDate, bool isTurkish) {
    final now = DateTime.now();
    final diff = targetDate.difference(now);

    if (diff.isNegative) {
      return isTurkish ? 'Sıfırlanıyor...' : 'Resetting...';
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    if (days > 0) {
      return isTurkish
          ? '$days gün $hours saat $minutes dk'
          : '$days d $hours h $minutes m';
    } else {
      return isTurkish
          ? '$hours saat $minutes dk $seconds sn'
          : '$hours h $minutes m $seconds s';
    }
  }

  Future<void> _loadRankingData() async {
    if (mounted) setState(() => _isLoading = true);
    List<Map<String, dynamic>> users = [];
    try {
      users = _selectedTab == 2
          ? await SupabaseService.instance.fetchFriends()
          : await SupabaseService.instance.getRankingUsers();
    } catch (_) {}

    // Active currentUser verisini birleştir / güncelle (Arkadaşlar sekmesinde
    // kendini de listeye ekleriz ki arkadaşlarınla kendi sıranı görebilesin)
    if (widget.currentUser != null) {
      final cur = widget.currentUser!;
      final index = users.indexWhere(
        (u) => (u['email']?.toString().toLowerCase() == cur.email.toLowerCase() ||
                u['name']?.toString().toLowerCase() == cur.name.toLowerCase()),
      );

      final userMap = {
        'name': cur.name,
        'email': cur.email,
        'total_minutes': cur.totalMinutes,
        'points': cur.points,
        'avatar_id': cur.avatarId,
        'is_friend': true,
      };

      if (index != -1) {
        users[index] = userMap;
      } else {
        users.add(userMap);
      }
    }

    // Puana göre azalan sıralama (eşitlikte toplam çalışma süresi)
    users.sort((a, b) {
      final byPoints = (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0);
      if (byPoints != 0) return byPoints;
      return (b['total_minutes'] as int? ?? 0).compareTo(a['total_minutes'] as int? ?? 0);
    });

    if (mounted) {
      setState(() {
        _realUsers = users;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> list;
    list = List.from(_realUsers);
    // Limit to max 50 users
    return list.take(50).toList();
  }

  AvatarCharacter _getAvatar(String avatarId) {
    final avatars = AvatarCharacter.allAvatars();
    return avatars.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => avatars.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentList = _filteredUsers;

    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadRankingData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3-Tab Navigation Segmented Pill (Haftalık | Aylık | Arkadaşlar)
                    Container(
                      width: double.infinity,
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainerHigh
                            : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          _buildTabItem(0, lang.translate('weekly')),
                          _buildTabItem(1, lang.translate('monthly')),
                          _buildTabItem(2, lang.isTurkish ? 'Arkadaşlar' : 'Friends'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Countdown Timer Banner (Haftalık / Aylık reset timer)
                    _buildCountdownBanner(isDark, lang),

                    const SizedBox(height: 12),

                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (currentList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainerLowest
                              : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.leaderboard_outlined,
                                size: 48, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'Henüz bu kategoride kayıtlı kullanıcı bulunmuyor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Top 3 Podium Widget (1st place center largest circle, 2nd medium left, 3rd small right)
                      _buildTop3Podium(currentList, isDark, lang),

                      const SizedBox(height: 20),

                      // List starting from 4th place downwards (Max 50 users)
                      if (currentList.length > 3)
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainerLowest
                                : AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentList.length - 3,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLow
                                  : AppColors.surfaceContainerLow,
                            ),
                            itemBuilder: (context, index) {
                              final userIndex = index + 3; // Starts from 4th place (index 3)
                              final u = currentList[userIndex];
                              final avatar = _getAvatar(u['avatar_id']?.toString() ?? '');
                              final points = u['points'] as int? ?? 0;
                              final minutes = u['total_minutes'] as int? ?? 0;
                              final rankNumber = userIndex + 1;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Rank Number Badge (4, 5, 6...)
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkSurfaceContainerLow
                                            : AppColors.surfaceContainerLow,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$rankNumber',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    AvatarWidget(
                                      avatar: avatar,
                                      size: 40,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u['name']?.toString() ?? 'Kullanıcı',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$minutes ${lang.translate('study_duration')}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryFixed,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$points ${lang.translate('points_unit')}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onPrimaryFixed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownBanner(bool isDark, LanguageService lang) {
    if (_selectedTab == 2) return const SizedBox.shrink(); // Friends tab: no countdown

    final targetDate = _selectedTab == 0 ? _nextWeeklyReset : _nextMonthlyReset;
    final timeString = _getRemainingTimeString(targetDate, lang.isTurkish);
    final titleText = _selectedTab == 0
        ? (lang.isTurkish ? 'Haftalık Sıfırlanmaya Kalan Süre' : 'Weekly Reset Counter')
        : (lang.isTurkish ? 'Aylık Sıfırlanmaya Kalan Süre' : 'Monthly Reset Counter');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.primaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '⏱️ $timeString',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _loadRankingData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTop3Podium(List<Map<String, dynamic>> users, bool isDark, LanguageService lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Left, Medium Circle - 76px)
          if (users.length >= 2)
            _buildPodiumSeat(
              rank: 2,
              userMap: users[1],
              avatarSize: 76,
              badgeColor: const Color(0xFFC0C0C0), // Silver
              badgeTextColor: Colors.black87,
              icon: Icons.looks_two_rounded,
              lang: lang,
            )
          else
            const SizedBox(width: 80),

          // 1st Place (Center, Largest Circle - 96px, Gold Crown)
          if (users.isNotEmpty)
            _buildPodiumSeat(
              rank: 1,
              userMap: users[0],
              avatarSize: 96,
              badgeColor: const Color(0xFFFFD700), // Gold
              badgeTextColor: Colors.black,
              hasCrown: true,
              icon: Icons.workspace_premium,
              lang: lang,
            ),

          // 3rd Place (Right, Smallest Circle - 60px)
          if (users.length >= 3)
            _buildPodiumSeat(
              rank: 3,
              userMap: users[2],
              avatarSize: 60,
              badgeColor: const Color(0xFFCD7F32), // Bronze
              badgeTextColor: Colors.white,
              icon: Icons.looks_3_rounded,
              lang: lang,
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPodiumSeat({
    required int rank,
    required Map<String, dynamic> userMap,
    required double avatarSize,
    required Color badgeColor,
    required Color badgeTextColor,
    required IconData icon,
    required LanguageService lang,
    bool hasCrown = false,
  }) {
    final avatar = _getAvatar(userMap['avatar_id']?.toString() ?? '');
    final name = userMap['name']?.toString() ?? 'Kullanıcı';
    final points = userMap['points'] as int? ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medal / Crown icon above avatar for Top 3 (Gold, Silver, Bronze)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Icon(
            Icons.workspace_premium,
            color: rank == 1
                ? const Color(0xFFFFD700)
                : rank == 2
                    ? const Color(0xFFC0C0C0)
                    : const Color(0xFFCD7F32),
            size: rank == 1 ? 36 : (rank == 2 ? 30 : 26),
          ),
        ),

        // Avatar Circle with Rank Badge Overlay
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(rank == 1 ? 4 : 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: rank == 1
                      ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                      : rank == 2
                          ? [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)]
                          : [const Color(0xFFD7CCC8), const Color(0xFF8D6E63)],
                ),
              ),
              child: AvatarWidget(
                avatar: avatar,
                size: avatarSize,
              ),
            ),

            // Rank Badge Overlay Pill
            Positioned(
              bottom: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: badgeTextColor),
                      const SizedBox(width: 2),
                      Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Name
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: rank == 1 ? 15 : 13,
              fontWeight: rank == 1 ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 2),

        // Points Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$points ${lang.translate('points_unit')}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.onPrimaryFixed,
            ),
          ),
        ),
      ],
    );
  }
}
