import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  final ValueChanged<UserModel?> onInitialized;
  final Widget Function(UserModel? user, List<CourseCategory> categories) onNavigate;

  const SplashScreen({
    super.key,
    required this.onInitialized,
    required this.onNavigate,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
    _initializeAppAndNavigate();
  }

  Future<void> _initializeAppAndNavigate() async {
    final startTime = DateTime.now();

    UserModel? initialUser;
    List<CourseCategory> loadedCategories = CourseCategory.initialCategories();

    final prefs = await SharedPreferences.getInstance();

    // 1. ÖNCE cihazdaki oturumu/kategorileri yükle (tamamen yerel, ağ
    // GEREKTİRMEZ). Böylece internet yokken/uçak modunda bile kullanıcı
    // ana ekrana ulaşabilir — bu adım asla askıda kalamaz.
    final savedUserStr = prefs.getString('saved_user');
    if (savedUserStr != null && savedUserStr.isNotEmpty) {
      try {
        initialUser = UserModel.fromMap(jsonDecode(savedUserStr));
      } catch (_) {}
    }

    final localCatKey = initialUser != null ? 'saved_categories_${initialUser.email}' : 'saved_categories';
    final savedCategoriesStr = prefs.getString(localCatKey);
    if (savedCategoriesStr != null && savedCategoriesStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedCategoriesStr);
        loadedCategories = decoded
            .map((item) => CourseCategory.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // 2. Supabase'i başlat ve (varsa) bulut verisiyle tazele — ama bu SINIRLI
    // bir süre (5 sn) beklenir; internet yoksa/timeout olursa yukarıdaki
    // yerel veriyle devam edilir, açılış ASLA bloklanmaz.
    try {
      await SupabaseService.instance.initialize().timeout(const Duration(seconds: 5));

      if (SupabaseService.instance.isCloudActive) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', session.user.id)
                .maybeSingle()
                .timeout(const Duration(seconds: 5));

            if (profile != null) {
              int streak = profile['current_streak'] ?? 0;
              final String? lastStudyStr = profile['last_study_date'];
              if (lastStudyStr != null) {
                final lastStudy = DateTime.parse(lastStudyStr);
                final today = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);
                if (todayDate.difference(lastStudy).inDays > 1) {
                  streak = 0; // broken streak
                }
              }

              initialUser = UserModel(
                name: profile['name'] ?? session.user.email?.split('@').first ?? 'Kullanıcı',
                email: session.user.email ?? '',
                password: '',
                avatarId: profile['avatar_id'] ?? 'avatar_1_gamer',
                totalMinutes: profile['total_minutes'] ?? 0,
                points: profile['points'] ?? 0,
                streakDays: streak,
                lastStudyDate: lastStudyStr,
              );
              // Save fresh profile to prefs
              await prefs.setString('saved_user', jsonEncode(initialUser.toMap()));
            }
          } catch (_) {}
        }

        // Kategorileri buluttan tazele (yine timeout korumalı)
        if (initialUser != null) {
          try {
            final cloudCats = await SupabaseService.instance
                .fetchUserCategories()
                .timeout(const Duration(seconds: 5));
            if (cloudCats.isNotEmpty) {
              loadedCategories = cloudCats;
            } else if (loadedCategories.isNotEmpty) {
              // Bulut boş ama yerelde kategori var: buluta senkronize et (arka planda, beklemeden)
              SupabaseService.instance.upsertCategories(loadedCategories);
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // Ağ yok / timeout: yukarıda yüklenen yerel veriyle devam edilir.
    }

    // Ensure minimum 1.8 seconds display for smooth logo animation
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 1800) {
      await Future.delayed(Duration(milliseconds: 1800 - elapsed.inMilliseconds));
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: widget.onNavigate(initialUser, loadedCategories),
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: Stack(
        children: [
          // Background subtle gradient glow
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Center Logo & Title
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hourglass_bottom_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'PomoSprint',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.8,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sprint into deep focus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Branding
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'POMOSPRINT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
