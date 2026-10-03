import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/category_cache.dart';
import '../theme.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';

/// Açılış ekranı: önce cihazdaki veriyi, sonra (sınırlı sürede) buluttaki
/// oturumu yükler. Kullanıcı SupabaseService.currentUser'a konur;
/// [onNavigate] yalnızca ilk kategori listesini alır.
class SplashScreen extends StatefulWidget {
  final Widget Function(List<CourseCategory> categories) onNavigate;

  const SplashScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const Duration _networkTimeout = Duration(seconds: 5);

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
    final service = SupabaseService.instance;

    // 1. ÖNCE cihazdaki oturumu/kategorileri/avatar kataloğunu yükle (tamamen
    // yerel, ağ GEREKTİRMEZ). Böylece internet yokken/uçak modunda bile
    // kullanıcı ana ekrana ulaşabilir — bu adım asla askıda kalamaz.
    final user = await service.restoreCachedUser();
    await service.loadCachedAvatarCatalog();
    var categories = await CategoryCache.read(user?.email, uid: user?.id) ?? CourseCategory.initialCategories();

    // 2. Supabase'i başlat ve (varsa) bulut verisiyle tazele — ama bu SINIRLI
    // bir süre beklenir; internet yoksa/timeout olursa yukarıdaki yerel
    // veriyle devam edilir, açılış ASLA bloklanmaz.
    try {
      await service.initialize().timeout(_networkTimeout);

      if (service.isCloudActive) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          debugPrint('[AUTH] Splash: currentSession NULL — kayıtlı oturum yok, giriş ekranına düşülecek');
          // KRİTİK: currentSession null ise (oturum hiç yok ya da geçersiz
          // hale geldi), yereldeki eski 'saved_user' önbelleğine ASLA
          // güvenilmez — aksi halde tamamen kimliksiz bir cihaz, eski
          // önbellek sayesinde onboarding/ana ekrana düşebilir.
          await service.setCurrentUser(null);
        } else {
          final expiresAt = session.expiresAt;
          final expiryStr = expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000).toIso8601String()
              : 'bilinmiyor';
          debugPrint('[AUTH] Splash: currentSession VAR (expiresAt=$expiryStr)');

          // Önbellekteki kullanıcı bu oturumdan FARKLI bir hesaba aitse
          // (cihazda daha önce başka bir hesap kullanılmış olabilir) ona ve
          // kategorilerine güvenilmez; taze profil alınamazsa null kalır.
          if (user != null && !_belongsTo(user, session.user)) {
            categories = CourseCategory.initialCategories();
            await service.setCurrentUser(null);
          }

          // Profil (sahip olunan avatarlar ve seri dahil, tek yerden; servis
          // kullanıcısını günceller) ve kategoriler paralel çekilir; her biri
          // sınırlı süre beklenir. Profil alınamazsa önbellekle devam edilir.
          final profile = _orNull(service.fetchCurrentUserModel(), 'profil');
          final cloudCategories = _orNull(service.fetchUserCategories(), 'kategoriler');
          // Bulut boşsa liste boş geçilir; eksik kategorileri sunucuda
          // oluşturmak tek yerden, ana kabukta yapılır.
          categories = await cloudCategories ?? categories;
          await profile;
          // Avatar kataloğu arka planda tazelenir; açılışı bekletmez
          // (gömülü/önbellekteki katalog zaten kullanılabilir).
          unawaited(service.refreshAvatarCatalog());
        }
      }
    } catch (e) {
      // Ağ yok / timeout: yukarıda yüklenen yerel veriyle devam edilir.
      debugPrint('[AUTH] Splash: SupabaseService.initialize() başarısız (ağ/timeout) — oturum tazelenemedi: $e');
    }

    // Ensure minimum 1.8 seconds display for smooth logo animation
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 1800) {
      await Future.delayed(Duration(milliseconds: 1800 - elapsed.inMilliseconds));
    }

    if (mounted) {
      final initialCategories = categories;
      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: widget.onNavigate(initialCategories),
            );
          },
        ),
      );
    }
  }

  static bool _belongsTo(UserModel cached, User authUser) => cached.id != null
      ? cached.id == authUser.id
      : cached.email.toLowerCase() == (authUser.email ?? '').toLowerCase();

  static Future<T?> _orNull<T>(Future<T> future, String label) {
    return future.timeout(_networkTimeout).then<T?>((value) => value, onError: (Object e) {
      debugPrint('[SPLASH] $label alınamadı: $e');
      return null;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Hareketi Azalt açıkken logo büyüyüp belirmez, doğrudan görünür.
  @override
  Widget build(BuildContext context) => (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? const SplashView()
      : SplashView(fade: _fadeAnim, scale: _scaleAnim);
}

/// Açılış ekranının görünümü (logo, başlık, yükleniyor göstergesi). Her
/// ekran boyutunda ortalı ve taşmasızdır; yatay telefonda ölçüler küçülür.
class SplashView extends StatelessWidget {
  final Animation<double> fade;
  final Animation<double> scale;

  const SplashView({
    super.key,
    this.fade = kAlwaysCompleteAnimation,
    this.scale = kAlwaysCompleteAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Yatay telefonda logo ve alttaki yükleniyor göstergesi üst üste
    // binmesin diye ölçüler küçülür; dikey telefonda ve tablette aynıdır.
    final short = Responsive.of(context).isShortHeight;
    final logoSize = short ? 72.0 : 100.0;
    final glowSize = short ? 200.0 : 260.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: Stack(
        children: [
          // Background subtle gradient glow
          Center(
            child: Container(
              width: glowSize,
              height: glowSize,
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

          // Center Logo & Title (sığmazsa orantılı küçülür)
          Center(
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    // Alttaki marka bloğunun payı: logo onunla çakışmaz.
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: short ? 64 : 96),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: logoSize,
                          height: logoSize,
                          padding: EdgeInsets.all(logoSize * 0.2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(logoSize * 0.28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.hourglass_bottom_rounded,
                            size: logoSize * 0.56,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: short ? 16 : 24),
                        Text(
                          'PomoSprint',
                          style: TextStyle(
                            fontSize: short ? 28 : 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.8,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Branding
          Positioned(
            bottom: short ? 12 : 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  SizedBox(height: short ? 10 : 16),
                  Text(
                    'POMOSPRINT',
                    maxLines: 1,
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
