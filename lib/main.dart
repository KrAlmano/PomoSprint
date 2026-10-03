import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'theme.dart';
import 'models/category_model.dart';
import 'models/user_model.dart';
import 'models/avatar_model.dart';
import 'screens/timer_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/social_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/friends_sheet.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/post_auth_onboarding_screen.dart';
import 'services/supabase_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'widgets/avatar_widget.dart';
import 'widgets/league_info_sheet.dart';

import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env burada erkenden yükleniyor ki Sentry DSN'ine erişebilelim;
  // SupabaseService.initialize() aynı dosyayı kendi ihtiyacı için tekrar
  // yükler, bu zararsızdır. DSN boşsa Sentry SDK kendini otomatik devre
  // dışı bırakır — .env'de SENTRY_DSN olmaması uygulamayı bozmaz.
  String sentryDsn = '';
  try {
    await dotenv.load(fileName: ".env");
    sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  } catch (_) {
    // .env okunamazsa (ör. asset eksik) Sentry'siz devam et.
  }

  await NotificationService.instance.initialize();
  await LanguageService.instance.init();

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 0.2;
      options.environment = kReleaseMode ? 'production' : 'debug';
    },
    appRunner: () => runApp(const PomodoroApp()),
  );
}

class PomodoroApp extends StatefulWidget {
  const PomodoroApp({super.key});

  @override
  State<PomodoroApp> createState() => _PomodoroAppState();
}

class _PomodoroAppState extends State<PomodoroApp> {
  ThemeMode _themeMode = ThemeMode.light;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _toggleDarkMode(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  // Giriş başarılı olduktan veya onboarding bittikten sonra bir sonraki
  // ekrana geçer. BİLİNÇLİ OLARAK SplashScreen'i yeniden TETİKLEMEZ:
  // eskiden bu iki durumda da SplashScreen key'i değiştirilip tamamen
  // yeniden mount ediliyordu, bu da SplashScreen.initState() içindeki
  // SupabaseService.instance.initialize() (yani Supabase.initialize())
  // çağrısının aynı process içinde İKİNCİ kez tetiklenmesine yol
  // açıyordu. Bu ikinci çağrı, az önce tamamlanan girişin oturumunun
  // henüz diske tam yazılmamış olabileceği bir anda currentSession'ı
  // yeniden okuyup ara sıra "oturum yokmuş gibi" davranıyordu — kullanıcı
  // "Giriş Yap"a bassa da ekran geçmiyor, onboarding'de "Bitir" sonsuza
  // kadar dönüyor, ama uygulamayı kapatıp açınca (gerçek bir soğuk
  // başlangıçta Supabase.initialize() sadece BİR kez ve oturum diske
  // tam yazıldıktan sonra çalıştığı için) düzeliyordu. Artık elimizdeki
  // güncel UserModel ile doğrudan ilerliyoruz, Supabase'i yeniden
  // başlatmaya hiç gerek yok.
  void _goToPostAuthScreen(UserModel user, List<CourseCategory> categories) {
    _navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (_) => user.onboardingCompletedAt == null
            ? PostAuthOnboardingScreen(
                onCompleted: () {
                  _goToPostAuthScreen(
                    user.copyWith(onboardingCompletedAt: DateTime.now()),
                    categories,
                  );
                },
              )
            : MainNavigationShell(
                isDarkMode: _themeMode == ThemeMode.dark,
                onDarkModeChanged: _toggleDarkMode,
                initialUser: user,
                initialCategories: categories,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
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
              // ── Kullanıcı YOK → Doğrudan Login (veya Register) ──
              if (user == null) {
                return LoginScreen(
                  onLoginSuccess: (loggedUser) async {
                    // loginUser() zaten profili sunucudan taze çekip
                    // döndürdü; burada sadece kategorileri tazeliyoruz.
                    List<CourseCategory> freshCategories;
                    try {
                      freshCategories = await SupabaseService.instance
                          .fetchUserCategories()
                          .timeout(const Duration(seconds: 5));
                    } catch (_) {
                      freshCategories = CourseCategory.initialCategories();
                    }
                    _goToPostAuthScreen(loggedUser, freshCategories);
                  },
                );
              }

              // ── Kullanıcı VAR + onboarding bitmemiş → Post-Auth 4 adım ──
              if (user.onboardingCompletedAt == null) {
                return PostAuthOnboardingScreen(
                  onCompleted: () {
                    _goToPostAuthScreen(
                      user.copyWith(onboardingCompletedAt: DateTime.now()),
                      categories,
                    );
                  },
                );
              }

              // ── Kullanıcı VAR + onboarding tamamlandı → Ana ekran ──
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
  bool _isTimerRunning = false;
  bool _isRankingLeagueTabActive = true;

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
    // Açılışta bulut erişilemediyse yer tutucu kategorilerle başlamış
    // olabiliriz; gerçek kategorileri tekrar çekmeyi dene.
    if (_currentUser != null && _hasPlaceholderCategories) {
      _loadCategoriesForUser(_currentUser!.email);
    }
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        if (_currentUser != null && _hasPlaceholderCategories) {
          _loadCategoriesForUser(_currentUser!.email);
        }
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
    final previousCount = _pendingSessionCount;
    final remaining = await SupabaseService.instance.syncPendingSessions(email);
    if (mounted) {
      setState(() => _pendingSessionCount = remaining);
    }
    if (remaining < previousCount) {
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
      final profile = await client.from('profiles').select('total_minutes, lifetime_points, coins').eq('id', userId).maybeSingle();
      if (profile != null && mounted && _currentUser != null) {
        final updated = _currentUser!.copyWith(
          totalMinutes: profile['total_minutes'] ?? _currentUser!.totalMinutes,
          lifetimePoints: profile['lifetime_points'] ?? _currentUser!.lifetimePoints,
          coins: profile['coins'] ?? _currentUser!.coins,
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
        debugPrint('[AUTH] onAuthStateChange: $event (${DateTime.now().toIso8601String()}, session=${session != null ? "var" : "yok"})');

        if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) && session != null) {
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select(SupabaseService.ownProfileColumns)
                .eq('id', session.user.id)
                .maybeSingle();

            int streak = profile?['current_streak'] ?? 0;
            final String? lastStudyStr = profile?['last_study_date'];
            if (lastStudyStr != null) {
              final lastStudy = DateTime.parse(lastStudyStr);
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              if (todayDate.difference(lastStudy).inDays > 1) {
                streak = 0;
              }
            }

            // UserModel.fromMap kullan → onboarding_completed_at okunur
            final loggedInUser = profile != null
                ? UserModel.fromMap({
                    ...profile,
                    'email': session.user.email ?? '',
                    'current_streak': streak,
                  })
                : UserModel(
                    name: session.user.userMetadata?['name'] ?? session.user.email?.split('@').first ?? 'Kullanıcı',
                    email: session.user.email ?? '',
                  );

            if (mounted) {
              setState(() => _currentUser = loggedInUser);
              _saveUserToPrefs(loggedInUser);
              _loadCategoriesForUser(loggedInUser.email);
            }
          } catch (e) {
            debugPrint('[AUTH] onAuthStateChange($event): profil çekme hatası: $e');
          }
        } else if (event == AuthChangeEvent.signedOut) {
          // GoTrue, arka planda token yenileme (refresh) başarısız olduğunda
          // da bu olayı üretir — yani bu dal aynı zamanda "yenileme başarısız
          // oldu" durumunu da kapsar.
          debugPrint('[AUTH] signedOut olayı alındı — oturum kapandı (kullanıcı eylemi veya başarısız token yenileme)');
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

  bool get _hasPlaceholderCategories =>
      _categories.any((c) => !SupabaseService.isServerCategoryId(c.id));

  Future<void> _loadCategoriesForUser(String email) async {
    try {
      // 1. Bulut asıl kaynaktır. Hata olursa (ağ yok) yerel önbelleğe düş,
      // ama buluta hiçbir şey YAZMA: eski yerel veri başka bir cihazda
      // yapılmış değişiklikleri ezebilir.
      List<CourseCategory>? cloudCats;
      if (SupabaseService.instance.isCloudActive) {
        try {
          cloudCats = await SupabaseService.instance.fetchUserCategories();
        } catch (e) {
          debugPrint('fetchUserCategories hatası, yerel önbelleğe düşülüyor: $e');
        }
      }
      if (cloudCats != null && cloudCats.isNotEmpty) {
        if (mounted) {
          setState(() {
            _categories = cloudCats!;
          });
        }
        await _saveCategoriesToPrefs(); // Update local cache
        return;
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

      // 3. Bulut erişilebilir ama kullanıcının hiç aktif kategorisi yoksa
      // (eski sürümden gelen hesap), yerel kategorileri buluta taşı.
      if (cloudCats != null && cloudCats.isEmpty && loaded.isNotEmpty) {
        await SupabaseService.instance.upsertCategories(loaded);
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

    // Sync to Supabase (limit ve isim kontrolü sunucuda yapılır)
    if (SupabaseService.instance.isCloudActive) {
      try {
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
      } catch (e) {
        // Sunucu reddetti (ör. kategori limiti): yerel eklemeyi geri al.
        if (!mounted) return;
        setState(() {
          _categories.removeWhere((c) => c.id == newCategory.id);
        });
        _saveCategoriesToPrefs();
        final message = e is PostgrestException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
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
          userPoints: _currentUser!.lifetimePoints,
          userCoins: _currentUser!.coins,
          isPremium: _currentUser!.isPremium,
          unlockedAvatars: _currentUser!.unlockedAvatars,
          isDarkMode: widget.isDarkMode,
          categories: _categories,
          onAddCategory: _addCategory,
          onDeleteCategory: _deleteCategory,
          onCoinsChanged: (newCoins) {
            setState(() {
              _currentUser = _currentUser?.copyWith(coins: newCoins);
            });
            _saveUserToPrefs(_currentUser);
          },
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
                await SupabaseService.instance.setEquippedAvatar(newAvatarId);
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
            // Sırayla: Google native oturumu + Supabase oturumu kapat,
            // sonra yerel state/önbelleği temizle. Eskiden sadece yerel
            // state temizleniyordu, gerçek oturum canlı kalıyordu.
            await SupabaseService.instance.signOutFully();
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final hideUI = isLandscape && _isTimerRunning && _currentIndex == 0;

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

    // Kullanıcı var ama onboarding'i tamamlamamış (ör. logout sonrası bu
    // ekrandan çıkmadan yeni bir hesapla giriş/kayıt yapıldıysa) — Splash'in
    // ilk açılıştaki yönlendirmesiyle AYNI kapıyı burada da uygula.
    if (_currentUser!.onboardingCompletedAt == null) {
      return PostAuthOnboardingScreen(
        onCompleted: () {
          setState(() {
            _currentUser = _currentUser!.copyWith(onboardingCompletedAt: DateTime.now());
          });
          _saveUserToPrefs(_currentUser);
          // Onboarding sırasında seçilen kategoriler sunucuya kaydedildi;
          // _categories hâlâ eski/varsayılan listeyi tutuyor olabilir —
          // taze kategorileri çek ki kullanıcı kendi seçtiklerini görsün.
          _loadCategoriesForUser(_currentUser!.email);
        },
      );
    }

    final screens = [
      TimerScreen(
        categories: _categories,
        onOpenSettings: _openProfile, // Open Profile & Settings
        onTimerStateChanged: (isRunning, categoryName, loggedMinutes) {
          if (mounted) {
            setState(() {
              _isTimerRunning = isRunning;
            });
          }
          if (_currentUser == null) return; // Yerel/misafir kullanıcı: sosyal listeye katılmaz
          if (isRunning) {
            SupabaseService.instance.startStudySession(
              durationMinutes: loggedMinutes,
              categoryName: categoryName,
            );
          } else {
            SupabaseService.instance.cancelStudySession();
          }
        },
        onSessionCompleted: (catId, minutes, wasPaused, isVerified, startedAt, clientUuid) async {
          final isLoggedIn = _currentUser != null;

          // Optimistically update local state (will be corrected by server response)
          setState(() {
            final catIndex = _categories.indexWhere((c) => c.id == catId);
            if (catIndex != -1) {
              _categories[catIndex].sessionsCount += 1;
              _categories[catIndex].totalMinutes += minutes;
            }
          });

          _saveCategoriesToPrefs();

          if (isLoggedIn) {
            try {
              final result = await SupabaseService.instance.completeStudySession(
                clientUuid: clientUuid,
                categoryId: catId,
                durationMinutes: minutes,
                wasPaused: wasPaused,
                isVerified: isVerified,
                startedAt: startedAt,
              );

              if (result != null && result['error'] != null) {
                // Sunucu seansı reddetti (örn. 'overlap' / 'hourly_limit') —
                // hiçbir profil güncellemesi/kayıt yapılmadı. Yerel state'i
                // yanlışlıkla ilerletmeyelim, kullanıcıyı bilgilendirelim.
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService.instance.isTurkish
                            ? '⚠️ Bu seans kaydedilemedi (sunucu reddetti: ${result['error']}).'
                            : '⚠️ This session could not be saved (server rejected: ${result['error']}).',
                      ),
                      backgroundColor: Colors.orange.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else if (result != null) {
                final totalPts = result['total_points'] as int? ?? 0;
                final basePts = result['base_points'] as int? ?? 0;
                final bonusPts = result['bonus_points'] as int? ?? 0;
                final streak = result['streak'] as int? ?? 0;
                final bonusPct = result['bonus_pct'] as int? ?? 0;
                // Sunucu artık kum tanesini puandan bağımsız, sabit bir
                // oranla veriyor (complete_study_session'daki v_coins_earned);
                // yerel önbelleği totalPts değil, sunucunun döndürdüğü gerçek
                // coins_earned değeriyle eşitliyoruz.
                final coinsEarned = result['coins_earned'] as int? ?? totalPts;

                final updatedUser = _currentUser?.copyWith(
                  totalMinutes: (_currentUser?.totalMinutes ?? 0) + minutes,
                  lifetimePoints: (_currentUser?.lifetimePoints ?? 0) + totalPts,
                  coins: (_currentUser?.coins ?? 0) + coinsEarned,
                  streakDays: streak,
                );
                setState(() => _currentUser = updatedUser);
                _saveUserToPrefs(updatedUser);

                // Show point breakdown snackbar
                if (context.mounted && bonusPts > 0) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService.instance.isTurkish
                            ? '🔥 $basePts puan + $bonusPts seri bonusu (%$bonusPct) = $totalPts puan!'
                            : '🔥 $basePts pts + $bonusPts streak bonus ($bonusPct%) = $totalPts pts!',
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }

                final isDailyLimitReached = result['daily_limit_reached'] as bool? ?? false;

                // Show daily limit reached message
                if (context.mounted && isDailyLimitReached) {
                  Future.delayed(const Duration(seconds: 1), () {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageService.instance.isTurkish
                              ? 'Bugünlük lig puanı sınırına ulaştın (16 pomodoro). Çalışman kaydedilmeye devam ediyor.'
                              : 'You have reached today\'s league points limit (16 pomodoros). Your work continues to be saved.',
                        ),
                        backgroundColor: AppColors.primaryContainer,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  });
                }
              }
            } catch (e) {
              if (SupabaseService.isPermanentSessionError(e)) {
                // Sunucu seansı doğrulamadan geçirmedi (ör. süre dolmadan
                // gönderildi, başka bir seansla çakışıyor). Tekrar denemenin
                // anlamı yok; kuyruğa almak yerine kullanıcıyı bilgilendir.
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService.instance.isTurkish
                            ? '⚠️ Bu seans kaydedilemedi: sunucu doğrulamasından geçmedi.'
                            : '⚠️ This session could not be saved: it failed server validation.',
                      ),
                      backgroundColor: Colors.orange.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
              // Offline: save pending session for later sync
              final email = _currentUser?.email;
              if (email != null && email.isNotEmpty) {
                await SupabaseService.instance.addPendingSession(
                  userEmail: email,
                  categoryId: catId,
                  categoryName: _categories.firstWhere((c) => c.id == catId, orElse: () => _categories.first).name,
                  minutes: minutes,
                  wasPaused: wasPaused,
                  isVerified: isVerified,
                  startedAt: startedAt.toIso8601String(),
                  clientUuid: clientUuid,
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
        userPoints: _currentUser?.lifetimePoints ?? 0,
        streakDays: _currentUser?.streakDays ?? 0,
        userSegment: _currentUser?.userSegment,
      ),
      ReportsScreen(
        categories: _categories,

        onStartTimer: () => setState(() => _currentIndex = 0),
      ),
      RankingScreen(
        currentUser: _currentUser,
        onLeagueTabActive: (active) {
          if (_isRankingLeagueTabActive != active) {
            setState(() => _isRankingLeagueTabActive = active);
          }
        },
      ),
      const SocialScreen(),
    ];

    final titles = [
      'Pomo',
      lang.translate('title_reports'),
      lang.translate('title_ranking'),
      lang.translate('title_social'),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: hideUI ? null : AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 76,
            titleSpacing: 16,
            title: (_currentIndex == 1 || _currentIndex == 2 || _currentIndex == 3)
                ? const SizedBox.shrink()
                : FittedBox(
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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titles[_currentIndex],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (_currentIndex == 2 && _isRankingLeagueTabActive) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => showLeagueInfoSheet(context),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                Icons.question_mark_rounded,
                                size: 13,
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            actions: [
              // Puan + Kum Tanesi rozetleri: yan yana, ayrı kutular. Taşma
              // riskine karşı (ekran genişliği dar olduğunda) bu ikili
              // kendi içinde yatay kaydırılabilir; geri kalan actions
              // öğeleri (arkadaş/profil) etkilenmez.
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => showLeagueInfoSheet(context),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                    '${_currentUser?.lifetimePoints ?? 0}',
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
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => showLeagueInfoSheet(context),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7A8),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🪙 KUM',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7A5A00),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '${_currentUser?.coins ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7A5A00),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7A5A00).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.question_mark_rounded,
                                  size: 10,
                                  color: Color(0xFF7A5A00),
                                ),
                              ),
                            ],
                          ),
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
                child: GestureDetector(
                  onTap: _openProfile,
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
          bottomNavigationBar: hideUI ? null : NavigationBar(
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
              NavigationDestination(
                icon: const Icon(Icons.groups_outlined),
                selectedIcon: const Icon(Icons.groups, color: AppColors.onPrimaryFixed),
                label: lang.translate('nav_social'),
              ),
            ],
          ),
        );
      },
    );
  }
}

