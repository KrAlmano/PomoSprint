import 'dart:async';
import 'package:flutter/material.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../theme.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  List<Map<String, dynamic>> _activeUsers = [];
  Timer? _pollingTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final live = await SupabaseService.instance.getLiveFriends();
    if (mounted) {
      setState(() {
        _activeUsers = live;
        _isLoading = false;
      });
    }
  }

  AvatarCharacter _getAvatar(String? avatarId) {
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

    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) {
        final isTurkish = lang.isTurkish;

        if (_isLoading) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        isTurkish ? 'Arkadaşların' : 'Your Friends',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _activeUsers.isEmpty
                      ? _buildEmptyState(isDark, isTurkish)
                      : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isTurkish ? 'Şu An Çalışanlar' : 'Focusing Right Now',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildActiveUserItem(
                                _activeUsers[index],
                                isDark,
                                isTurkish,
                              ),
                            ),
                            childCount: _activeUsers.length,
                          ),
                        ),
                      ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveUserItem(Map<String, dynamic> user, bool isDark, bool isTurkish) {
    final avatar = _getAvatar(user['avatar_id']?.toString());
    final name = user['name']?.toString() ?? (isTurkish ? 'Kullanıcı' : 'User');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AvatarWidget(avatar: avatar, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isTurkish ? 'Odaklanıyor' : 'Focusing',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_fire_department_rounded,
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isTurkish) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 48,
                color: isDark ? AppColors.darkPrimary : AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTurkish
                  ? 'Şu an çalışan arkadaşın yok. Biri odaklanmaya başladığında burada görünecek.'
                  : 'No friends studying right now. They\'ll show up here once someone starts focusing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
