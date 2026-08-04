import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'theme.dart';
import 'models/category_model.dart';
import 'models/avatar_model.dart';
import 'models/user_model.dart';
import 'widgets/avatar_widget.dart';
import 'screens/timer_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/friends_sheet.dart';
import 'utils/points.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';
import 'services/language_service.dart';

import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.instance.init();
  runApp(const PomodoroApp());
}

class PomodoroApp extends StatefulWidget {
  const PomodoroApp({super.key});

  @override
  State<PomodoroApp> createState() => _PomodoroAppState();
}

class _PomodoroAppState extends State<PomodoroApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleDarkMode(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'PomoSprint - Pomodoro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeMode,
          locale: LanguageService.instance.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SplashScreen(
            onInitialized: (_) {},
            onNavigate: (user, categories) {
              return MainNavigationShell(
                isDarkMode: _themeMode == ThemeMode.dark,
                onDarkModeChanged: _toggleDarkMode,
                initialUser: user,
                initialCategories: categories,
              );
            },
          ),
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final UserModel? initialUser;
  final List<CourseCategory> initialCategories;

  const MainNavigationShell({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    this.initialUser,
    required this.initialCategories,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  late List<CourseCategory> _categories;
  UserModel? _currentUser;
  int _pendingSessionCount = 0;

  StreamSubscription<AuthState>? _authStateSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    _categories = List.from(widget.initialCategories);
    _listenAuthChanges();
    _refreshPendingSessionCount();
    _trySyncPendingSessions();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _trySyncPendingSessions();
      }
    });
  }

  Future<void> _refreshPendingSessionCount() async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) return;
    final pending = await SupabaseService.instance.getPendingSessions(email);
    if (mounted) {
      setState(() => _pendingSessionCount = pending.length);
    }
  }

  Future<void> _trySyncPendingSessions() async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) return;
    if (!SupabaseService.instance.isCloudActive) return;
    final remaining = await SupabaseService.instance.syncPendingSessions(email);
    if (mounted) {
      setState(() => _pendingSessionCount = remaining);
    }
    if (remaining < _pendingSessionCount) {
      // Senkronize edilen seanslar sunucudaki güncel puan/dakikayı yansıtsın diye
      // profili tazeleyelim (basit yaklaşım: mevcut oturum verisini yeniden çek).
      _refreshCurrentUserFromServer();
    }
  }

  Future<void> _refreshCurrentUserFromServer() async {
    if (!SupabaseService.instance.isCloudActive) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await client.from('profiles').select().eq('id', userId).maybeSingle();
      if (profile != null && mounted && _currentUser != null) {
        final updated = _currentUser!.copyWith(
          totalMinutes: profile['total_minutes'] ?? _currentUser!.totalMinutes,
          points: profile['points'] ?? _currentUser!.points,
        );
        setState(() => _currentUser = updated);
        _saveUserToPrefs(updated);
      }
    } catch (_) {}
  }

  void _listenAuthChanges() {
    if (SupabaseService.instance.isCloudActive) {
      _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        final session = data.session;

        if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) && session != null) {
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', session.user.id)
                .maybeSingle();

            final name = profile?['name'] ?? session.user.userMetadata?['name'] ?? session.user.email?.split('@').first ?? 'Kullanıcı';
            final avatarId = profile?['avatar_id'] ?? session.user.userMetadata?['avatar_id'] ?? 'avatar_1_gamer';
            final totalMins = profile?['total_minutes'] ?? 0;
            final points = profile?['points'] ?? 0;

            int streak = profile?['current_streak'] ?? 0;
            final String? lastStudyStr = profile?['last_study_date'];
            if (lastStudyStr != null) {
              final lastStudy = DateTime.parse(lastStudyStr);
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              if (todayDate.difference(lastStudy).inDays > 1) {
                streak = 0; // broken streak
              }
            }

            final loggedInUser = UserModel(
              name: name,
              email: session.user.email ?? '',
              password: '',
              avatarId: avatarId,
              totalMinutes: totalMins,
              points: points,
              streakDays: streak,
              lastStudyDate: lastStudyStr,
            );

            if (mounted) {
              setState(() {
                _currentUser = loggedInUser;
              });
              _saveUserToPrefs(loggedInUser);
              _loadCategoriesForUser(loggedInUser.email);
            }
          } catch (_) {}
        } else if (event == AuthChangeEvent.signedOut) {
          if (mounted) {
            setState(() {
              _currentUser = null;
              _categories = CourseCategory.initialCategories();
            });
            _saveUserToPrefs(null);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _saveCategoriesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_categories.map((c) => c.toJson()).toList());
      final key = _currentUser != null ? 'saved_categories_${_currentUser!.email}' : 'saved_categories';
      await prefs.setString(key, encoded);
    } catch (_) {}
  }

  Future<void> _loadCategoriesForUser(String email) async {
    try {
      // 1. Try Supabase first
      if (SupabaseService.instance.isCloudActive) {
        final cloudCats = await SupabaseService.instance.fetchUserCategories();
        if (cloudCats.isNotEmpty) {
          if (mounted) {
            setState(() {
              _categories = cloudCats;
            });
          }
          await _saveCategoriesToPrefs(); // Update local cache
          return;
        }
      }

      // 2. Fallback to Local Prefs
      final prefs = await SharedPreferences.getInstance();
      final savedCategoriesStr = prefs.getString('saved_categories_$email');
      
      List<CourseCategory> loaded = [];
      if (savedCategoriesStr != null && savedCategoriesStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedCategoriesStr);
        loaded = decoded.map((item) => CourseCategory.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        loaded = CourseCategory.initialCategories();
      }

      if (mounted) {
        setState(() {
          _categories = loaded;
        });
      }
      
      // If we loaded local but cloud is active, upsert to cloud
      if (SupabaseService.instance.isCloudActive && loaded.isNotEmpty) {
        final synced = await SupabaseService.instance.upsertCategories(loaded);
        if (synced.isNotEmpty && mounted) {
          setState(() {
            _categories = synced;
          });
          await _saveCategoriesToPrefs();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveUserToPrefs(UserModel? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user == null) {
        await prefs.remove('saved_user');
      } else {
        await prefs.setString('saved_user', jsonEncode(user.toMap()));
      }
    } catch (_) {}
  }

  AvatarCharacter get _currentAvatar {
    final avatars = AvatarCharacter.allAvatars();
    final avatarId = _currentUser?.avatarId ?? 'avatar_1_gamer';
    return avatars.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => avatars.first,
    );
  }

  void _addCategory(CourseCategory newCategory) async {
    // Add locally first for instant UI
    setState(() {
      _categories.insert(0, newCategory);
    });
    _saveCategoriesToPrefs();

    // Sync to Supabase
    if (SupabaseService.instance.isCloudActive) {
      final syncedCat = await SupabaseService.instance.insertCategory(newCategory);
      if (syncedCat != null && mounted) {
        setState(() {
          // Replace local temp ID with Supabase UUID
          final index = _categories.indexWhere((c) => c.id == newCategory.id);
          if (index != -1) {
            _categories[index] = syncedCat;
          }
        });
        _saveCategoriesToPrefs();
      }
    }
  }

  void _deleteCategory(String id) async {
    // Delete locally first
    setState(() {
      _categories.removeWhere((c) => c.id == id);
    });
    _saveCategoriesToPrefs();

    // Delete from Supabase
    if (SupabaseService.instance.isCloudActive) {
      await SupabaseService.instance.deleteCategory(id);
    }
  }

  void _showPointsInfoDialog() {
    final isTurkish = LanguageService.instance.isTurkish;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 26),
            const SizedBox(width: 8),
            Text(
              isTurkish ? 'Puanlama Nasıl Çalışır?' : 'How Scoring Works',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PointsInfoRow(
              icon: Icons.timer_outlined,
              text: isTurkish ? '25 dk Pomodoro = 20 Puan' : '25 min Pomodoro = 20 Points',
            ),
            const SizedBox(height: 10),
            _PointsInfoRow(
              icon: Icons.timer_outlined,
              text: isTurkish ? '50 dk Pomodoro = 40 Puan' : '50 min Pomodoro = 40 Points',
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            _PointsInfoRow(
              icon: Icons.local_fire_department,
              iconColor: Colors.deepOrange,
              text: isTurkish
                  ? 'Günlük Seri (🔥): Her gün giriş yapıp en az 1 Pomodoro tamamladığında serin devam eder.'
                  : 'Daily Streak (🔥): Log in and complete at least 1 Pomodoro each day to keep your streak going.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isTurkish ? 'Anladım' : 'Got it'),
          ),
        ],
      ),
    );
  }

  void _openFriendsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FriendsSheet(),
    );
  }

  void _openProfile() {
    if (_currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userName: _currentUser!.name,
          userEmail: _currentUser!.email,
          currentAvatarId: _currentUser!.avatarId,
          totalStudyMinutes: _currentUser!.totalMinutes,
          userPoints: _currentUser!.points,
          isDarkMode: widget.isDarkMode,
          categories: _categories,
          onAddCategory: _addCategory,
          onDeleteCategory: _deleteCategory,
          onAvatarChanged: (newAvatarId) async {
            final messenger = ScaffoldMessenger.of(context);
            final userKey = _currentUser?.email ?? _currentUser?.name ?? '';
            final oldAvatarId = _currentUser?.avatarId;
            final updatedUser = _currentUser?.copyWith(avatarId: newAvatarId);
            
            setState(() {
              _currentUser = updatedUser;
            });
            _saveUserToPrefs(updatedUser);

            if (userKey.isNotEmpty) {
              try {
                await SupabaseService.instance.updateUserAvatar(userKey, newAvatarId);
              } catch (e) {
                setState(() {
                  if (oldAvatarId != null) {
                    _currentUser = _currentUser?.copyWith(avatarId: oldAvatarId);
                  }
                });
                _saveUserToPrefs(_currentUser);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('⚠️ Avatar güncellenirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }
          },
          onDarkModeChanged: widget.onDarkModeChanged,
          onLogout: () async {
            setState(() {
              _currentUser = null;
              _currentIndex = 0;
            });
            await _saveUserToPrefs(null);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    // Show Login Screen if no user logged in
    if (_currentUser == null) {
      return LoginScreen(
        onLoginSuccess: (user) {
          setState(() {
            _currentUser = user;
          });
          _saveUserToPrefs(user);
          _saveCategoriesToPrefs();
          _refreshPendingSessionCount();
          _trySyncPendingSessions();
        },
      );
    }

    final screens = [
      TimerScreen(
        categories: _categories,
        onOpenSettings: _openProfile, // Open Profile & Settings
        onSessionCompleted: (catId, minutes) async {
          final addedPoints = pointsForMinutes(minutes);
          final isLoggedIn = _currentUser != null;

          final updatedUser = _currentUser?.copyWith(
            totalMinutes: (_currentUser?.totalMinutes ?? 0) + minutes,
            points: (_currentUser?.points ?? 0) + addedPoints,
          );

          setState(() {
            _currentUser = updatedUser;
            final catIndex = _categories.indexWhere((c) => c.id == catId);
            if (catIndex != -1) {
              _categories[catIndex].sessionsCount += 1;
              _categories[catIndex].totalMinutes += minutes;
            } else {
              debugPrint('⚠️ Hata: catId ($catId) yerel kategorilerde bulunamadı!');
            }
          });

          _saveUserToPrefs(updatedUser);
          _saveCategoriesToPrefs();

          if (isLoggedIn) {
            String catName = 'Bilinmeyen Ders';
            final catIndex = _categories.indexWhere((c) => c.id == catId);
            if (catIndex != -1) {
              catName = _categories[catIndex].name;
            }

            try {
              // study_sessions insert + profiles update TEK transaction'da (atomik).
              await SupabaseService.instance.logPomodoroSession(
                categoryName: catName,
                minutes: minutes,
                addedPoints: addedPoints,
              );
            } catch (e) {
              // Ağ/sunucu hatası: seansı cihazda "bekleyen" olarak sakla,
              // bağlantı gelince otomatik tekrar denenecek (kalıcı kaybolmaz).
              final email = _currentUser?.email;
              if (email != null && email.isNotEmpty) {
                await SupabaseService.instance.addPendingSession(
                  userEmail: email,
                  categoryName: catName,
                  minutes: minutes,
                  addedPoints: addedPoints,
                );
                await _refreshPendingSessionCount();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LanguageService.instance.isTurkish
                          ? '⚠️ Seans şu an buluta kaydedilemedi, bağlantı gelince otomatik gönderilecek.'
                          : '⚠️ Could not save session to the cloud right now — it will sync automatically once you are back online.',
                    ),
                    backgroundColor: Colors.orange.shade800,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }
        },
        userPoints: _currentUser?.points ?? 0,
        streakDays: _currentUser?.streakDays ?? 0,
      ),
      ReportsScreen(
        categories: _categories,

        onStartTimer: () => setState(() => _currentIndex = 0),
      ),
      RankingScreen(currentUser: _currentUser),
    ];

    final titles = [
      'Pomo',
      lang.translate('title_reports'),
      lang.translate('title_ranking'),
    ];

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
            toolbarHeight: 76,
            titleSpacing: 16,
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _currentIndex == 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.deepOrange,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentUser?.streakDays ?? 0}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      titles[_currentIndex],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
            actions: [
              // Puan Rozeti (büyütülmüş + "?" bilgi ikonu)
              InkWell(
                onTap: _showPointsInfoDialog,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.translate('points_caption'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimaryFixed,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${_currentUser?.points ?? 0}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimaryFixed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.onPrimaryFixed.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.question_mark_rounded,
                          size: 10,
                          color: AppColors.onPrimaryFixed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Arkadaş Ekle/Görüntüle Butonu (Dairesel, avatardan biraz büyük)
              InkWell(
                onTap: _openFriendsSheet,
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 63,
                  height: 63,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: AppColors.primaryContainer,
                    size: 33,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // User Profile Avatar (Clickable to open Profile & Settings)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: _openProfile,
                  borderRadius: BorderRadius.circular(32),
                  child: AvatarWidget(
                    avatar: _currentAvatar,
                    size: 60,
                  ),
                ),
              ),
            ],
          ),

          // Current Screen Body
          body: Column(
            children: [
              if (_pendingSessionCount > 0)
                Material(
                  color: Colors.orange.shade800,
                  child: InkWell(
                    onTap: _trySyncPendingSessions,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang.isTurkish
                                  ? '$_pendingSessionCount senkronize edilmemiş seansın var. Tekrar denemek için dokun.'
                                  : 'You have $_pendingSessionCount unsynced session(s). Tap to retry.',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: screens,
                ),
              ),
            ],
          ),

          // 3-Tab Bottom Navigation Bar (Pomo, Raporlar, Sıralama)
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              if (index == _currentIndex) return;
              // Not: Pomodoro çalışırken sekmeler arası geçiş serbesttir.
              // TimerScreen, IndexedStack içinde canlı tutulduğu için sekme
              // değiştirmek sayacı durdurmaz/kesintiye uğratmaz.
              setState(() => _currentIndex = index);
            },
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            indicatorColor: AppColors.primaryFixed,
            elevation: 4,
            height: 68,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer, color: AppColors.onPrimaryFixed),
                label: 'Pomo',
              ),
              NavigationDestination(
                icon: const Icon(Icons.analytics_outlined),
                selectedIcon: const Icon(Icons.analytics, color: AppColors.onPrimaryFixed),
                label: lang.translate('nav_reports'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.leaderboard_outlined),
                selectedIcon: const Icon(Icons.leaderboard, color: AppColors.onPrimaryFixed),
                label: lang.translate('nav_ranking'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PointsInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const _PointsInfoRow({
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor ?? AppColors.primaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
