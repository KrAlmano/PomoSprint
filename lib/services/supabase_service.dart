import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/avatar_model.dart';
import '../models/category_model.dart';
import '../models/registration_consent.dart';
import '../models/study_session.dart';
import '../models/user_model.dart';
import '../utils/name_filter.dart';
import '../utils/study_day.dart';
import 'backend_config.dart';
import 'hidden_users.dart';
import 'language_service.dart';
import 'lock_screen_timer.dart';
import 'notification_service.dart';
import 'onboarding_categories.dart';
import 'onboarding_draft.dart';
import 'platform_env.dart' if (dart.library.io) 'platform_env_io.dart';
import 'server_clock.dart';
import 'service_errors.dart';
import 'session_queue.dart';
import 'sign_out_notice.dart';
import 'timer_persistence.dart';

export 'service_errors.dart';
export 'sign_out_notice.dart';
export 'session_queue.dart'
    show
        PendingSession,
        RejectedSession,
        SessionReason,
        SessionSubmitQueued,
        SessionSubmitRejected,
        SessionSubmitResult,
        SessionSubmitSuccess;

/// Uygulamanın tek veri erişim noktası (auth, profil, seans kuyruğu,
/// kategoriler, sosyal, sıralama, avatarlar).
///
/// Hata politikası: kullanıcıya gösterilecek metin ÜRETİLMEZ. Auth hataları
/// [AuthFailure] / [AuthErrorCode], diğerleri [ServiceException] /
/// [ServiceErrorCode] ile ifade edilir; UI ARB ile yerelleştirir.
class SupabaseService {
  SupabaseService._init() {
    _queue = SessionQueue(
      backend: _SupabaseQueueBackend(this),
      clock: _clock,
      onAccepted: _onSessionAccepted,
      onQueueChanged: _onQueueChanged,
    );
    // Çalışma günü hesapları (istatistikler, 'bugün', seri) oturumdaki
    // kullanıcının profil saat dilimini izler; sunucu da onu kullanır.
    currentUser.addListener(() => setStudyTimeZone(currentUser.value?.timezone));
  }

  static final SupabaseService instance = SupabaseService._init();

  bool _isCloudActive = false;
  bool get isCloudActive => _isCloudActive;

  SupabaseClient get _client => Supabase.instance.client;

  /// Oturumdaki kullanıcının tek doğruluk kaynağı. Giriş, profil okuma,
  /// seans sonucu, isim/avatar/hedef değişikliği ve çıkış bunu günceller;
  /// her güncelleme 'saved_user' önbelleğine de yazılır.
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);

  /// Her başarılı kategori değişikliğinden sonra artar; dinleyenler
  /// kategorileri yeniden yükler.
  final ValueNotifier<int> categoriesRevision = ValueNotifier<int>(0);

  /// Oturumdaki kullanıcının senkronize edilmemiş seans sayısı.
  final ValueNotifier<int> pendingSessionCount = ValueNotifier<int>(0);

  final ServerClock _clock = ServerClock();
  late final SessionQueue _queue;
  StreamSubscription<AuthState>? _authSubscription;

  // Kullanıcıya özel durum her temizlendiğinde (çıkış, oturumun düşmesi)
  // artar. Uçuştaki bir profil okuması ya da güncellemesi yanıtı farklı bir
  // dönemde gelirse kullanıcıyı yayınlamaz ve 'saved_user'a yazmaz; aksi
  // halde çıkış yapmış hesap geri geliyor ya da hesaplar karışıyordu.
  int _userEpoch = 0;

  /// Oturumun neden kapandığı (hesap silindi, oturum uzaktan düştü, Apple
  /// izni kaldırıldı). Giriş ekranı [takeSignOutNotice] ile bir kez okur.
  /// Kullanıcının kendi çıkışında ayarlanmaz.
  final ValueNotifier<SignOutNotice?> signOutNotice = ValueNotifier<SignOutNotice?>(null);

  /// Bekleyen açıklamayı döndürür ve temizler.
  SignOutNotice? takeSignOutNotice() {
    final notice = signOutNotice.value;
    if (notice != null) signOutNotice.value = null;
    return notice;
  }

  // Uygulamanın kendi başlattığı çıkış/silme sürerken > 0. Bu sırada gelen
  // signedOut olayları (ör. silinen hesabın token yenilemesi) "oturum
  // uzaktan düştü" sayılmaz.
  int _localSignOutDepth = 0;

  /// Oturum kapanınca (çıkış, silme, uzaktan düşme) cihazda kalan seans
  /// göstergelerini kapatır: zamanlanmış bitiş bildirimi (Android exact
  /// alarm dahil), Android kalıcı bildirimi, iOS Canlı Etkinlik. Testte
  /// değiştirilebilir.
  @visibleForTesting
  static Future<void> Function() sessionEndedCleanup = _defaultSessionEndedCleanup;

  static Future<void> _defaultSessionEndedCleanup() async {
    if (isFlutterTestEnvironment) return;
    await NotificationService.instance.cancelSessionEndNotification();
    await LockScreenTimer.instance.clear();
  }

  /// Sunucu ile cihaz saati arasındaki tahmini fark (sunucu - cihaz).
  Duration? get serverClockOffset => _clock.offset;

  // 'email' kasıtlı olarak dışarıda bırakıldı: e-posta değeri her zaman
  // Supabase Auth oturumundan (session.user.email) geliyor, profiles
  // tablosundan hiç okunmasına gerek yok. Bu sayede 'email' kolonunun
  // authenticated rolünden REVOKE edilmesi (bkz. ilgili migration) bu
  // "kendi profilini oku" çağrılarını bozmuyor.
  static const String ownProfileColumns =
      'id, name, avatar_id, total_minutes, created_at, friend_code, '
      'current_streak, last_study_date, is_premium, league_tier, '
      'lifetime_points, coins, longest_streak, timezone, '
      'active_session_ends_at, active_session_category_name, '
      'show_in_social_feed, user_segment, daily_goal_minutes, birth_year, '
      'onboarding_completed_at';

  // client_uuid: kuyrukta kalmış ama sunucuya ulaşmış seans istatistikte iki
  // kez sayılmasın diye. icon_name: arşivlenmiş kategorinin ikonu için.
  static const String _studySessionColumns =
      'id, user_id, category, category_id, duration_minutes, started_at, completed_at, client_uuid, '
      'categories(name, color_hex, icon_name)';

  static const String _savedUserKey = 'saved_user';
  static const String _avatarCatalogKey = 'avatar_catalog_v1';
  static const String _legacyDailyGoalKey = 'daily_pomo_goal';
  static const Duration _requestTimeout = Duration(seconds: 15);
  // Giriş, kayıt, sıfırlama ve sosyal giriş istekleri (captive portal'da
  // buton sonsuza dek dönmesin).
  static const Duration _authTimeout = Duration(seconds: 25);
  // Hesap silme: Apple token iptali + silme tek istekte.
  static const Duration _deleteAccountTimeout = Duration(seconds: 30);
  static const String _appleIdentityKey = 'apple_sign_in_identity';
  // İstemci kuralları sunucudaki CHECK'lerin (name 1..50, daily_goal_minutes
  // 5..1440, birth_year 1900..2100) içinde kalır.
  static const int _nameMinLength = 2;
  static const int _nameMaxLength = 30;
  static const int _dailyGoalMin = 5;
  static const int _dailyGoalMax = 24 * 60;
  static const int _birthYearMin = 1900;
  static const int _birthYearMax = 2100;
  static const int _sessionsPageSize = 1000; // Supabase varsayılan max_rows

  // ---- Ortak yardımcılar ----

  void _requireCloud() {
    if (!_isCloudActive) throw const ServiceException(ServiceErrorCode.cloudUnavailable);
  }

  User _requireAuthUser() {
    _requireCloud();
    final user = _client.auth.currentUser;
    if (user == null) throw const ServiceException(ServiceErrorCode.notSignedIn);
    return user;
  }

  String _requireUserId() => _requireAuthUser().id;

  // Açılışta başlatılamamış bulut giriş anında yeniden denenir; aksi halde
  // giriş ekranı uygulama yeniden açılana dek "Sunucuya bağlanılamadı" diyordu.
  Future<void> _ensureCloudForAuth() async {
    if (!await ensureCloud()) throw const AuthFailure(AuthErrorCode.cloudUnavailable);
  }

  /// Auth isteğini zaman aşımıyla çalıştırır. Zaman aşımı
  /// [AuthFailure]([onTimeout]) olur (varsayılan: bağlantı hatası); diğer
  /// hatalar olduğu gibi geçer.
  @visibleForTesting
  static Future<T> runAuthRequest<T>(
    Future<T> Function() body, {
    Duration timeout = _authTimeout,
    AuthErrorCode onTimeout = AuthErrorCode.network,
  }) async {
    try {
      return await body().timeout(timeout);
    } on TimeoutException catch (e) {
      throw AuthFailure(onTimeout, e);
    }
  }

  /// İsteği zaman aşımıyla çalıştırır, hatayı [ServiceException]'a çevirir.
  Future<T> _guard<T>(Future<T> Function() body, {Duration timeout = _requestTimeout}) async {
    try {
      return await body().timeout(timeout);
    } catch (e, st) {
      Error.throwWithStackTrace(ServiceException.wrap(e), st);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? response) => response is List
      ? response.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  // ---- Başlatma ----

  Future<void> initialize() async {
    String url = '';
    String anonKey = '';

    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('[INIT] .env okunamadı: $e');
    }
    // --dart-define SUPABASE_URL + SUPABASE_ANON_KEY (ör. yerel Supabase
    // kopyası) verilmişse .env'in önüne geçer (BackendConfig).
    final backend = BackendConfig.resolve(dotenv.isInitialized ? dotenv.env : const {});
    url = backend.supabaseUrl;
    anonKey = backend.supabaseAnonKey;
    if (backend.source == BackendConfigSource.incompleteDartDefine) {
      debugPrint('[INIT] SUPABASE_URL ve SUPABASE_ANON_KEY birlikte verilmeli; bulut kapalı.');
    }

    if (url.isEmpty ||
        anonKey.isEmpty ||
        url.contains('YOUR_PROJECT_ID') ||
        anonKey.contains('YOUR_SUPABASE_ANON_KEY')) {
      debugPrint('[INIT] Supabase bilgileri ayarlanmamış, bulut devre dışı.');
      _isCloudActive = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
        // Yanıtlardaki 'date' başlığından sunucu saati farkı ölçülür.
        httpClient: ServerClockHttpClient(_clock),
        // Şifre sıfırlama ve e-posta onay bağlantıları pomosprint.app'te,
        // çoğu zaman başka bir cihazın tarayıcısında açılıyor. PKCE'de
        // doğrulayıcı (verifier) telefonda kaldığı için web sayfası kodu
        // takas edemiyordu. Uygulama yönlendirmeli OAuth kullanmıyor
        // (Google/Apple native idToken), bu yüzden implicit akış ve
        // bağlantıdan oturum yakalamanın kapatılması güvenli.
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          detectSessionInUri: false,
        ),
      );
      _isCloudActive = true;
      _authSubscription ??= _client.auth.onAuthStateChange.listen(
        handleAuthStateChange,
        onError: (Object e) => debugPrint('[AUTH] onAuthStateChange hatası: $e'),
      );
      debugPrint('[INIT] Supabase bağlandı.');
    } catch (e) {
      debugPrint('[INIT] Supabase bağlantı hatası: $e');
      _isCloudActive = false;
    }
  }

  Future<bool>? _cloudAttempt;

  /// Testte bulut başlatmasının yerine geçer. Test ortamında verilmezse
  /// [ensureCloud] başlatmayı denemez (gerçek .env ile canlı projeye
  /// bağlanılmasın).
  @visibleForTesting
  Future<void> Function()? debugCloudInitializer;

  /// Bulut kullanılabilir mi? Değilse başlatmayı (yeniden) dener. Açılıştaki
  /// başlatma hata verdiyse ya da splash'in süresi içinde bitmediyse uygulama
  /// süreç boyunca çevrimdışı kalıyordu: giriş "Sunucuya bağlanılamadı"
  /// diyor, kabuk kuyruğu hiç göndermiyordu. Eşzamanlı çağrılar tek denemede
  /// birleşir; [timeout] yalnızca bekleyeni bırakır, deneme sürer. Supabase
  /// bilgisi yoksa (.env boş) false.
  Future<bool> ensureCloud({Duration timeout = _requestTimeout}) async {
    if (_isCloudActive) return true;
    final attempt = _cloudAttempt ??= _attemptCloud().whenComplete(() => _cloudAttempt = null);
    try {
      return await attempt.timeout(timeout);
    } on TimeoutException {
      return _isCloudActive;
    }
  }

  Future<bool> _attemptCloud() async {
    final init = debugCloudInitializer ?? (isFlutterTestEnvironment ? null : initialize);
    if (init == null) return _isCloudActive;
    try {
      await init();
    } catch (e) {
      debugPrint('[INIT] Bulut başlatılamadı: $e');
    }
    return _isCloudActive;
  }

  /// Testte bulutun durumunu ayarlar ([ensureCloud] senaryoları).
  @visibleForTesting
  set debugCloudActive(bool value) => _isCloudActive = value;

  // ---- Kimlik doğrulama ----

  // Tek bir GoogleSignIn örneği: her çağrıda yeniden oluşturmak,
  // paketin sessiz oturum önbelleğini (signInSilently) sıfırlıyordu.
  static const String _googleWebClientId = '722417205043-d7t27n7usp9nrfeuh8o97fald6a5v9ku.apps.googleusercontent.com';
  static const String _googleIosClientId = '722417205043-luq0knjdncu1aitpg9udbfgmo2qdtced.apps.googleusercontent.com';
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleWebClientId,
    clientId: _googleIosClientId,
  );

  /// Supabase oturumunu ve Google'ın native oturumunu kapatır, cihazdaki
  /// seans göstergelerini ([sessionEndedCleanup]) kaldırır, kullanıcıya
  /// özel önbellekleri ve singleton durumlarını temizler. Bekleyen seans
  /// kuyruğu kullanıcı kimliğine bağlı olarak diskte kalır; başka bir
  /// hesaba gönderilmez. [notice] verilirse giriş ekranı onu açıklar.
  Future<void> signOutFully({SignOutNotice? notice}) async {
    final email = currentUser.value?.email;
    final uid = currentUser.value?.id;
    _localSignOutDepth++;
    try {
      if (notice != null) signOutNotice.value = notice;
      await _endDeviceSession();
      if (_isCloudActive) {
        try {
          await _client.auth.signOut();
        } catch (e) {
          debugPrint('[AUTH] Supabase signOut hatası: $e');
        }
      }
      await _clearUserScopedState(email: email, uid: uid);
    } finally {
      _localSignOutDepth--;
    }
  }

  /// Supabase auth olayları. Tek "oturum kapandı" kancası: kullanıcı
  /// çıkışı ve silme [signOutFully]'den, uzaktan düşme (token yenilenemedi:
  /// şifre değişti, hesap başka cihazda kapatıldı/silindi) buradan geçer;
  /// uzaktan düşmede Google oturumu ve seans göstergeleri de kapatılır ve
  /// giriş ekranı nedenini açıklar.
  @visibleForTesting
  void handleAuthStateChange(AuthState data) {
    if (data.event != AuthChangeEvent.signedOut) return;
    final remote = data.signOutReason == SignOutReason.sessionExpired &&
        _localSignOutDepth == 0 &&
        currentUser.value != null;
    if (!remote) {
      // Kullanıcı eylemi: kullanıcıya özel durumu temizle (kuyruk korunur).
      unawaited(_clearUserScopedState());
      return;
    }
    signOutNotice.value = SignOutNotice.sessionExpired;
    unawaited(() async {
      await _endDeviceSession();
      await _clearUserScopedState();
    }());
  }

  /// Cihazdaki seans göstergelerini ve Google native oturumunu kapatır;
  /// hiçbir adım hata fırlatmaz ya da çıkışı süresiz bekletmez.
  Future<void> _endDeviceSession() async {
    try {
      await sessionEndedCleanup();
    } catch (e) {
      debugPrint('[AUTH] Seans göstergeleri kapatılamadı: $e');
    }
    // Testte Google eklentisi yok; kanal çağrı zinciri test zone'unda asılı kalır.
    if (isFlutterTestEnvironment) return;
    try {
      await _googleSignIn.signOut().timeout(_requestTimeout);
    } catch (e) {
      // Apple/e-posta kullanıcısında Google oturumu yoktur; beklenen durum.
      debugPrint('[AUTH] GoogleSignIn signOut: $e');
    }
  }

  Future<void> _clearUserScopedState({String? email, String? uid}) async {
    final mail = email ?? currentUser.value?.email;
    final id = uid ?? currentUser.value?.id;
    _userEpoch++;
    _statsRefreshTimer?.cancel();
    currentUser.value = null;
    pendingSessionCount.value = 0;
    _socialVisibleCache = null;
    _socialVisibleCacheUid = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedUserKey);
      await prefs.remove('saved_categories');
      // Apple ile girişin cihazdaki kaydı yalnızca o oturum için geçerli.
      await prefs.remove(_appleIdentityKey);
      if (mail != null && mail.isNotEmpty) await prefs.remove('saved_categories_$mail');
      if (id != null && id.isNotEmpty) await prefs.remove('saved_categories_uid_$id');
    } catch (e) {
      debugPrint('[AUTH] Yerel kullanıcı önbelleği temizlenemedi: $e');
    }
  }

  /// signUp `data` (auth.users.raw_user_meta_data). handle_new_user yalnızca
  /// name / full_name / avatar_id okur; handle_newsletter_subscription
  /// 'newsletter' = true ise e-posta onaylanınca aboneliği açar. Onay kaydı
  /// (terms_version, privacy_version, terms_accepted_at, marketing_consent)
  /// [RegistrationConsent.toMetadata]'dan gelir; zorunlu onaylar yoksa
  /// [StateError] fırlatılır.
  @visibleForTesting
  static Map<String, dynamic> signUpMetadata({
    required String email,
    required String avatarId,
    required RegistrationConsent consent,
    String? name,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final displayName = (name != null && name.trim().isNotEmpty) ? name.trim() : cleanEmail.split('@').first;
    return {
      'name': displayName,
      // Yalnızca varsayılan (ücretsiz) avatarlar kayıtta seçilebilir;
      // sunucu (handle_new_user) diğerlerini avatar_16_basic'e çeker.
      'avatar_id': AvatarCharacter.isFreeAvatarId(avatarId) ? avatarId : kDefaultAvatarId,
      ...consent.toMetadata(),
    };
  }

  Future<AuthResponse?> registerUser({
    required String email,
    required String password,
    required String avatarId,
    required RegistrationConsent consent,
    String? name,
  }) async {
    // Zorunlu onaylar olmadan istek hiç gönderilmez (UI da engeller).
    final data = signUpMetadata(email: email, avatarId: avatarId, consent: consent, name: name);
    await _ensureCloudForAuth();
    final cleanEmail = email.trim().toLowerCase();

    try {
      // Zaman aşımında kayıt sunucuda tamamlanmış olabilir; ayrı metin gösterilir.
      final response = await runAuthRequest(
        () => _client.auth.signUp(
          email: cleanEmail,
          password: password,
          emailRedirectTo: 'https://pomosprint.app/confirmed.html',
          data: data,
        ),
        onTimeout: AuthErrorCode.signUpTimedOut,
      );
      // GoTrue, kayıtlı e-posta için hata yerine boş identities döndürür.
      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        throw const AuthFailure(AuthErrorCode.emailAlreadyRegistered);
      }
      return response;
    } on AuthException catch (e) {
      if (authErrorCodeOf(e) == AuthErrorCode.emailAlreadyRegistered) {
        throw AuthFailure(AuthErrorCode.emailAlreadyRegistered, e);
      }
      rethrow;
    }
  }

  Future<UserModel?> loginUser(String email, String password) async {
    await _ensureCloudForAuth();
    final response = await runAuthRequest(() => _client.auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        ));
    if (response.user == null) return null;
    return _loadUserAfterSignIn();
  }

  /// Google ile giriş. Kullanıcı vazgeçerse null döner.
  Future<UserModel?> signInWithGoogle() async {
    await _ensureCloudForAuth();

    GoogleSignInAccount? googleUser;
    String? idToken;
    String? accessToken;
    try {
      // Önce sessiz oturum: kullanıcı daha önce izin verdiyse hesap seçici
      // gösterilmez. Yalnızca null dönerse interaktif signIn'e düşülür.
      googleUser = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await runAuthRequest(() => googleUser!.authentication);
      idToken = googleAuth.idToken;
      accessToken = googleAuth.accessToken;
    } on PlatformException catch (e) {
      if (e.code == GoogleSignIn.kSignInCanceledError) return null;
      if (e.code == GoogleSignIn.kNetworkError) throw AuthFailure(AuthErrorCode.network, e);
      throw AuthFailure(AuthErrorCode.googleSignInFailed, e);
    }
    if (idToken == null) throw const AuthFailure(AuthErrorCode.googleSignInFailed);

    final response = await runAuthRequest(() => _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken!,
          accessToken: accessToken,
        ));
    if (response.user == null) throw const AuthFailure(AuthErrorCode.googleSignInFailed);

    await _cleanupDuplicateIdentity();
    return _applyProviderFirstName(await _loadUserAfterSignIn());
  }

  /// Apple ile giriş. Kullanıcı vazgeçerse null döner.
  Future<UserModel?> signInWithApple() async {
    await _ensureCloudForAuth();

    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw AuthFailure(AuthErrorCode.appleSignInFailed, e);
    } on SignInWithAppleException catch (e) {
      throw AuthFailure(AuthErrorCode.appleSignInFailed, e);
    } on PlatformException catch (e) {
      throw AuthFailure(AuthErrorCode.appleSignInFailed, e);
    }

    final idToken = credential.identityToken;
    if (idToken == null) throw const AuthFailure(AuthErrorCode.appleSignInFailed);

    final response = await runAuthRequest(() => _client.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        ));
    if (response.user == null) throw const AuthFailure(AuthErrorCode.appleSignInFailed);
    // Bu cihazda Apple ile girildi: açılışta/ön plana dönüşte izin durumu
    // bu kimlikle denetlenir (verifyAppleCredential).
    await _rememberAppleIdentity(response.user!.id, credential.userIdentifier);

    await _cleanupDuplicateIdentity();
    // Apple adı yalnızca ilk girişte verir; profil oluşturulurken kullanılır.
    final user = await _loadUserAfterSignIn(nameHint: credential.givenName);
    return _applyProviderFirstName(user, givenName: credential.givenName);
  }

  /// Google/Apple girişinde profil adını sağlayıcının verdiği İLK ada çeker.
  ///
  /// Profil satırını signInWithIdToken anında handle_new_user trigger'ı
  /// yazıyor: Apple id_token'ında ad olmadığı için ad e-postanın yerel kısmı
  /// (gizli rölede anlamsız bir dizi), Google'da tam ad oluyordu ve bu ad
  /// arkadaş listesinde, lig odasında, aylık sıralamada başkalarına
  /// görünüyordu. Yalnızca ad hâlâ trigger'ın varsayılanıysa (e-posta yerel
  /// kısmı; ya da onboarding bitmemişken sağlayıcının tam adı) değiştirilir;
  /// kullanıcının kendi seçtiği ada dokunulmaz. Hata girişi bozmaz.
  Future<UserModel> _applyProviderFirstName(UserModel user, {String? givenName}) async {
    final authUser = _isCloudActive ? _client.auth.currentUser : null;
    if (authUser == null || user.id != authUser.id) return user;
    final desired = providerFirstNameUpdate(
      currentName: user.name,
      email: authUser.email,
      provider: authUser.appMetadata['provider']?.toString(),
      metadata: authUser.userMetadata ?? const <String, dynamic>{},
      onboardingCompleted: user.onboardingCompletedAt != null,
      givenName: givenName,
      userId: authUser.id,
    );
    if (desired == null) return user;
    try {
      await updateUserName(desired);
    } catch (e) {
      debugPrint('[AUTH] Profil adı sağlayıcının ilk adına çekilemedi (yok sayılıyor): $e');
    }
    return currentUser.value ?? user;
  }

  /// E-postadan türetilmeyen, herkese açık listelerde güvenle görünebilecek
  /// varsayılan ad: 'Pomo ' + kullanıcı kimliğinin ilk 4 karakteri
  /// (proposed: handle_new_user'ın e-posta yedeği yerine aynı biçim).
  static String neutralProfileName(String? userId) {
    final suffix = (userId ?? '').replaceAll('-', '').toLowerCase();
    return suffix.length < 4 ? 'Pomo' : 'Pomo ${suffix.substring(0, 4)}';
  }

  /// [_applyProviderFirstName]'in kararı: profil adı hâlâ handle_new_user'ın
  /// varsayılanıysa (e-postanın yerel kısmı; ya da onboarding bitmemişken
  /// sağlayıcının boşluk içeren tam adı) yazılacak ilk ad, aksi halde null.
  @visibleForTesting
  static String? providerFirstNameUpdate({
    required String currentName,
    required String? email,
    required String? provider,
    required Map<String, dynamic> metadata,
    required bool onboardingCompleted,
    String? givenName,
    String? userId,
  }) {
    const triggerNameMax = 50; // handle_new_user: left(..., 50)
    String clip(String v) => v.length > triggerNameMax ? v.substring(0, triggerNameMax) : v;
    final current = currentName.trim();
    final emailLocal = (email ?? '').split('@').first.trim();
    final fullName = (metadata['full_name'] ?? metadata['name'])?.toString().trim() ?? '';
    final neutral = neutralProfileName(userId);
    final isEmailDefault = emailLocal.isNotEmpty && current == clip(emailLocal);
    final isNeutralDefault = userId != null && current == neutral;
    final isFullNameDefault = !onboardingCompleted && fullName.contains(RegExp(r'\s')) && current == clip(fullName);
    if (!isEmailDefault && !isNeutralDefault && !isFullNameDefault) return null;
    final providerName = _providerGivenName(provider: provider, metadata: metadata, nameHint: givenName);
    final desired = providerName == null ? '' : _clipName(providerName);
    // Sağlayıcıdaki ad başkalarına görünecek; küfür içeriyorsa yazılmaz.
    final usable = desired.length >= _nameMinLength && !NameFilter.isOffensive(desired);
    if (usable) return desired == current ? null : desired;
    // Kullanılabilir ad yok (Apple adı yalnızca ilk yetkilendirmede verir):
    // e-postanın yerel kısmı herkese açık listelerde (anon dahil, tek parça
    // olduğu için maskelenmeden) görünmesin; nötr ad yazılır.
    return isEmailDefault && current != neutral ? neutral : null;
  }

  // Aynı e-postayla onaylanmamış e-posta/şifre kaydı varsa temizler.
  // p_email yalnızca oturumdaki kullanıcının KENDİ e-postasıdır; başka bir
  // değer asla gönderilmez (sunucu tarafı ayrıca auth.jwt() ile doğrulamalı).
  Future<void> _cleanupDuplicateIdentity() async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) return;
    try {
      await _client
          .rpc('cleanup_unconfirmed_duplicate_identity', params: {'p_email': email})
          .timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[AUTH] cleanup_unconfirmed_duplicate_identity hatası (yok sayılıyor): $e');
    }
  }

  /// Oturum açıldıktan sonra kullanıcı modelini kurar. Okuma bir kez
  /// yeniden denenir. Yine başarısız olursa aynı kullanıcıya ait önbellek
  /// varsa onunla devam edilir; yoksa oturum kapatılıp
  /// [AuthErrorCode.profileLoadFailed] fırlatılır. Böylece anlık bir okuma
  /// hatası mevcut kullanıcıyı onboarding'e sokmaz ve "hata gösterildi ama
  /// aslında giriş yapılmış" durumu oluşmaz.
  Future<UserModel> _loadUserAfterSignIn({String? nameHint}) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final user = await _fetchCurrentUserModel(nameHint: nameHint);
        if (user != null) return user;
      } catch (e) {
        lastError = e;
        debugPrint('[AUTH] Giriş sonrası profil okunamadı (deneme ${attempt + 1}): $e');
      }
    }
    final uid = _client.auth.currentUser?.id;
    final cached = await _readCachedUser();
    if (uid != null && cached != null && cached.id == uid) {
      _publishUser(cached);
      return cached;
    }
    await signOutFully();
    throw AuthFailure(AuthErrorCode.profileLoadFailed, lastError);
  }

  Future<void> resendConfirmationEmail(String email) async {
    await _ensureCloudForAuth();
    await runAuthRequest(() => _client.auth.resend(
          type: OtpType.signup,
          email: email.trim().toLowerCase(),
          emailRedirectTo: 'https://pomosprint.app/confirmed.html',
        ));
  }

  // Supabase, hesap keşfini önlemek için e-posta kayıtlı olsun ya da olmasın
  // aynı şekilde davranır; başarılı dönüş e-postanın var olduğunu göstermez.
  Future<void> resetPassword(String email) async {
    await _ensureCloudForAuth();
    await runAuthRequest(() => _client.auth.resetPasswordForEmail(
          email.trim().toLowerCase(),
          redirectTo: 'https://pomosprint.app/reset-password.html',
        ));
  }

  // ---- Şifre ve sağlayıcılar ----

  /// [user]'ın bağlı giriş sağlayıcılarından biri [provider] mı
  /// (app_metadata.provider/providers ya da identities)?
  @visibleForTesting
  static bool userHasProvider(User user, String provider) {
    final meta = user.appMetadata;
    final providers = meta['providers'];
    if (providers is List && providers.map((e) => e.toString()).contains(provider)) return true;
    if (meta['provider']?.toString() == provider) return true;
    return user.identities?.any((i) => i.provider == provider) ?? false;
  }

  User? get _authUserOrNull => _isCloudActive ? _client.auth.currentUser : null;

  /// Hesabın e-posta/şifre girişi var mı? (Google/Apple ile açılmış hesapta
  /// şifre yoktur; "Şifremi unuttum" ile şifre belirlenebilir.)
  bool get canChangePassword {
    final user = _authUserOrNull;
    return user != null && (user.email ?? '').isNotEmpty && userHasProvider(user, 'email');
  }

  /// Uygulama içi şifre değiştirme: önce mevcut şifreyle yeniden doğrulanır
  /// (yanlışsa [AuthErrorCode.invalidCredentials]), sonra yeni şifre
  /// yazılır. GoTrue şifre değişince hesabın diğer oturumlarını kapatır.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _ensureCloudForAuth();
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) throw const AuthFailure(AuthErrorCode.unknown);
    if (newPassword == currentPassword) throw const AuthFailure(AuthErrorCode.samePassword);
    await runAuthRequest(() => _client.auth.signInWithPassword(email: email, password: currentPassword));
    await runAuthRequest(() => _client.auth.updateUser(UserAttributes(password: newPassword)));
  }

  // ---- Sign in with Apple ----

  // Debug yapılandırması Sign in with Apple entitlement'ı olmadan derlenir
  // (bkz. LoginScreen); Apple yalnızca iOS release/profile'da kullanılabilir.
  static bool get _appleSignInSupported => !kIsWeb && !kDebugMode && defaultTargetPlatform == TargetPlatform.iOS;

  /// Oturumdaki hesapta Apple kimliği var mı?
  bool get hasAppleIdentity {
    final user = _authUserOrNull;
    return user != null && userHasProvider(user, 'apple');
  }

  /// Hesap silmeden önce Apple'dan taze yetkilendirme kodu istenebilir mi
  /// (Apple kimliği var ve cihaz iOS)?
  bool get canReauthorizeWithApple => _appleSignInSupported && hasAppleIdentity;

  /// Hesap silme için Apple'dan taze bir authorizationCode ister (Face ID /
  /// parola). Kullanıcı vazgeçerse ya da alınamazsa null; silme yine yapılır,
  /// kullanıcıya Ayarlar talimatı gösterilir.
  Future<String?> requestAppleAuthorizationCode() async {
    if (!_appleSignInSupported) return null;
    try {
      final credential = await SignInWithApple.getAppleIDCredential(scopes: const []);
      final code = credential.authorizationCode.trim();
      return code.isEmpty ? null : code;
    } catch (e) {
      debugPrint('[AUTH] Apple yeniden doğrulaması alınamadı: $e');
      return null;
    }
  }

  Future<void> _rememberAppleIdentity(String uid, String? appleUserId) async {
    if (appleUserId == null || appleUserId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appleIdentityKey, jsonEncode({'uid': uid, 'apple_user': appleUserId}));
    } catch (e) {
      debugPrint('[AUTH] Apple kimliği kaydedilemedi: $e');
    }
  }

  /// Bu cihazda Apple ile girilmiş oturumun Apple kullanıcı kimliği (yoksa null).
  @visibleForTesting
  static Future<String?> rememberedAppleUserId(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appleIdentityKey);
      if (raw == null) return null;
      final map = jsonDecode(raw);
      if (map is! Map || map['uid'] != uid) return null;
      final appleUser = map['apple_user']?.toString();
      return (appleUser == null || appleUser.isEmpty) ? null : appleUser;
    } catch (_) {
      return null;
    }
  }

  /// Apple izin durumu bu oturumu kapatmayı gerektiriyor mu?
  @visibleForTesting
  static bool appleCredentialRequiresSignOut(CredentialState state) =>
      state == CredentialState.revoked || state == CredentialState.notFound;

  /// Bu cihazda Apple ile girilmiş oturum için Apple izin durumunu denetler
  /// (açılışta ve ön plana dönüşte). Kullanıcı Ayarlar'dan "Kullanmayı
  /// Durdur" dediyse (revoked) ya da kimlik bulunamazsa (notFound) tam çıkış
  /// yapılır ve giriş ekranı nedenini açıklar. Hata durumunda dokunulmaz.
  Future<void> verifyAppleCredential() async {
    if (!_appleSignInSupported) return;
    final uid = _authUserOrNull?.id;
    if (uid == null) return;
    final appleUserId = await rememberedAppleUserId(uid);
    if (appleUserId == null) return;
    final CredentialState state;
    try {
      state = await SignInWithApple.getCredentialState(appleUserId);
    } catch (e) {
      debugPrint('[AUTH] Apple izin durumu okunamadı: $e');
      return;
    }
    if (!appleCredentialRequiresSignOut(state) || _authUserOrNull?.id != uid) return;
    await signOutFully(notice: SignOutNotice.appleCredentialRevoked);
  }

  // ---- Hesap silme ----

  /// Hesabı sunucudan siler, sonra bu kullanıcıya ait tüm yerel veriyi
  /// temizler ve oturumu kapatır (giriş ekranı "hesabın silindi" der).
  ///
  /// Önce `delete-account` Edge Function'ı denenir: [appleAuthorizationCode]
  /// varsa Apple token'ını iptal eder, e-postaya bağlı bekleme listesi ve
  /// abonelik kayıtlarını siler, kullanıcıyı siler (auth.users; profil,
  /// seanslar, kategoriler, arkadaşlıklar, lig üyeliği, akış, avatarlar ve
  /// abonelik yabancı anahtarla birlikte). Fonksiyon canlıda yoksa (404) ya
  /// da çalışamadıysa (5xx) `delete_own_account` RPC'sine düşülür. Yanıt kaybolursa (zaman aşımı,
  /// bağlantı) hesabın gerçekten silinip silinmediğine bakılır.
  ///
  /// Yerel veri: bekleyen ve reddedilen seanslar, süren sayaç kaydı,
  /// gizlenen kullanıcılar, onboarding taslağı, lig bilgisi ve hedef taşıma
  /// bayrakları, kullanıcı/kategori önbelleği. Google ile bağlı hesapta
  /// Google erişimi de kaldırılır (disconnect).
  Future<AppleRevocation> deleteUserAccount({String? appleAuthorizationCode}) async {
    final authUser = _requireAuthUser();
    final uid = authUser.id;
    final email = authUser.email ?? currentUser.value?.email;
    final hasApple = userHasProvider(authUser, 'apple');
    final hasGoogle = userHasProvider(authUser, 'google');
    _localSignOutDepth++;
    try {
      var apple = hasApple ? AppleRevocation.notRevoked : AppleRevocation.notApplicable;
      try {
        try {
          final response = await _client.functions
              .invoke('delete-account', body: {
                if (appleAuthorizationCode != null && appleAuthorizationCode.isNotEmpty)
                  'apple_authorization_code': appleAuthorizationCode,
              })
              .timeout(_deleteAccountTimeout);
          apple = appleRevocationFromResponse(response.data, hasAppleIdentity: hasApple);
        } on FunctionException catch (e) {
          if (!shouldFallBackToDeleteRpc(e)) rethrow;
          // Edge Function deploy edilmemiş ya da çalışamadı: canlıdaki RPC.
          // 5xx gövdesi Apple iptalinin yapılıp yapılmadığını söyleyebilir.
          debugPrint('[AUTH] delete-account kullanılamadı (${e.status}); delete_own_account RPC.');
          apple = appleRevocationFromResponse(e.details, hasAppleIdentity: hasApple);
          await _client.rpc('delete_own_account').timeout(_requestTimeout);
        }
      } catch (e, st) {
        if (!await _accountNoLongerExists()) Error.throwWithStackTrace(ServiceException.wrap(e), st);
        debugPrint('[AUTH] Silme yanıtı alınamadı ama hesap artık yok; temizliğe devam ediliyor.');
      }
      await clearDeletedAccountLocalData(uid, email: email);
      if (hasGoogle) await _disconnectGoogle(email);
      await signOutFully(notice: SignOutNotice.accountDeleted(apple: apple));
      return apple;
    } finally {
      _localSignOutDepth--;
    }
  }

  /// `delete-account` çağrısı RPC yedeğine mi düşmeli? Fonksiyon canlıda
  /// yok (gateway 404; fonksiyon kendisi 404 döndürmez) ya da çalışamadı
  /// (5xx: açılış hatası, kaynak sınırı, silme hatası). 401/4xx (oturum,
  /// istek) yedeğe düşmez.
  @visibleForTesting
  static bool shouldFallBackToDeleteRpc(FunctionException e) => e.status == 404 || e.status >= 500;

  /// Silme yanıtı kaybolduğunda hesabın sunucuda artık olmadığını doğrular.
  Future<bool> _accountNoLongerExists() async {
    try {
      await _client.auth.getUser().timeout(_requestTimeout);
      return false;
    } on AuthException catch (e) {
      return authErrorMeansUserGone(e);
    } catch (_) {
      return false;
    }
  }

  /// GoTrue `GET /user` hatası kullanıcının silindiğini mi gösteriyor?
  /// (Süresi dolmuş JWT'nin 401'i silinme sayılmaz.)
  @visibleForTesting
  static bool authErrorMeansUserGone(AuthException e) => e.code == 'user_not_found' || e.statusCode == '404';

  /// Silinen hesabın Google erişimini kaldırır (yalnızca cihazdaki Google
  /// hesabı silinen hesabın e-postasıysa). Hata yutulur.
  Future<void> _disconnectGoogle(String? email) async {
    final mail = email?.trim().toLowerCase();
    if (mail == null || mail.isEmpty || isFlutterTestEnvironment) return;
    try {
      final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently().timeout(_requestTimeout);
      if (account == null || account.email.trim().toLowerCase() != mail) return;
      await _googleSignIn.disconnect().timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[AUTH] Google erişimi kaldırılamadı (yok sayılıyor): $e');
    }
  }

  /// Silinen hesabın cihazdaki verisi. Kuyruk dahil hiçbir adım diğerini
  /// engellemez; hata yalnızca günlüğe yazılır.
  @visibleForTesting
  Future<void> clearDeletedAccountLocalData(String uid, {String? email}) async {
    final mail = email?.trim().toLowerCase();
    Future<void> step(String what, Future<void> Function() body) async {
      try {
        await body();
      } catch (e) {
        debugPrint('[AUTH] Silinen hesabın yerel verisi temizlenemedi ($what): $e');
      }
    }

    await step('kuyruk', () => _queue.clearUser(uid, email: email));
    // Sayaç ekranı kapanırken seansı yeniden yazmasın diye sahip emekliye ayrılır.
    await step('sayaç', () => TimerPersistence.instance.retireOwner(uid));
    if (mail != null && mail.isNotEmpty) await step('sayaç (e-posta)', () => TimerPersistence.instance.clear(mail));
    await step('gizlenenler', () => HiddenUsersStore.instance.forget(uid));
    await step('onboarding taslağı', () => OnboardingDraftStore.clear(uid));
    await step('tercihler', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dailyGoalMigratedKey(uid));
      await prefs.remove('league_info_shown_$uid');
      await prefs.remove('saved_categories_uid_$uid');
      if (email != null && email.isNotEmpty) {
        await prefs.remove('league_info_shown_$email');
        await prefs.remove('saved_categories_$email');
      }
      if (mail != null && mail.isNotEmpty && mail != email) await prefs.remove('saved_categories_$mail');
    });
  }

  /// Herhangi bir auth hatasını koda çevirir; UI metni ARB'den üretir.
  AuthErrorCode parseAuthError(Object error) => authErrorCodeOf(error);

  // ---- Kullanıcı modeli (tek kaynak) ----

  /// Oturumdaki kullanıcının profilini (ownProfileColumns), sahip olduğu
  /// avatarları ve seriyi TEK yerden kurar; [currentUser]'ı ve önbelleği
  /// günceller. Oturum yoksa null döner. Okuma hatasında fırlatır (çağıran
  /// önbellekteki kullanıcıyla devam edebilir). Profil satırı yoksa
  /// oluşturulur.
  Future<UserModel?> fetchCurrentUserModel() => _fetchCurrentUserModel();

  Future<UserModel?> _fetchCurrentUserModel({String? nameHint}) async {
    _requireCloud();
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    final epoch = _userEpoch;

    final results = await Future.wait<Object?>([
      _ensureOwnProfile(authUser, nameHint: nameHint),
      _fetchUnlockedAvatars(authUser.id),
    ]).timeout(_requestTimeout);
    // Yanıt gelene kadar çıkış yapıldıysa ya da oturum başka hesaba
    // geçtiyse eski kullanıcı yayınlanmaz.
    if (!_isCurrentSession(authUser.id, epoch)) return null;
    final profile = results[0] as Map<String, dynamic>;
    final unlocked = results[1] as List<String>;

    final user = UserModel.fromMap({
      ...profile,
      'id': authUser.id,
      'email': authUser.email ?? '',
      'unlocked_avatars': unlocked,
    });
    _publishUser(user);

    // Katalog oturumsuz istekte (RLS) boş dönebildiği için oturum açılınca tazelenir.
    if (!_avatarCatalogFresh) unawaited(refreshAvatarCatalog());
    unawaited(_afterUserLoaded(user));
    return user;
  }

  Future<void> _afterUserLoaded(UserModel user) async {
    try {
      await _queue.adoptLegacyQueue(userId: user.id!, email: user.email);
      await getPendingSessionCount();
      await _migrateLegacyDailyGoal(user);
      await migrateLegacyEmailKeys(user);
    } catch (e) {
      debugPrint('[DATA] Kullanıcı yükleme sonrası adımlar: $e');
    }
  }

  Future<List<String>> _fetchUnlockedAvatars(String userId) async {
    final rows = await _client.from('avatar_unlocks').select('avatar_id').eq('user_id', userId);
    return _rows(rows).map((e) => e['avatar_id'].toString()).toList();
  }

  /// Kullanıcının profil satırını okur; satır GERÇEKTEN yoksa oluşturur.
  /// Okuma hatası "profil yok" sayılmaz, yukarı fırlatılır (aksi halde anlık
  /// bir kopmada mevcut kullanıcının istatistikleri sıfırlanabilirdi).
  /// Oluşturma `ignoreDuplicates` ile yapılır; yalnızca istemcinin INSERT
  /// yetkisi olan kolonlar (id, email, name, avatar_id) gönderilir.
  Future<Map<String, dynamic>> _ensureOwnProfile(User authUser, {String? nameHint}) async {
    final existing = await _client.from('profiles').select(ownProfileColumns).eq('id', authUser.id).maybeSingle();
    if (existing != null) return existing;

    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final requestedAvatar = metadata['avatar_id']?.toString();
    await _client.from('profiles').upsert({
      'id': authUser.id,
      'email': authUser.email ?? '',
      'name': _initialProfileName(authUser, nameHint),
      // Yalnızca varsayılan (ücretsiz) bir avatar kabul edilir; Google/Apple'da
      // kDefaultAvatarId. Sunucu (sanitize_profile_insert) de aynısını zorlar.
      'avatar_id': AvatarCharacter.isFreeAvatarId(requestedAvatar) ? requestedAvatar : kDefaultAvatarId,
    }, onConflict: 'id', ignoreDuplicates: true);

    final created = await _client.from('profiles').select(ownProfileColumns).eq('id', authUser.id).maybeSingle();
    if (created == null) throw const ServiceException(ServiceErrorCode.notFound);
    return created;
  }

  /// Yeni profilin adı. E-posta kaydında kullanıcının yazdığı ad; Google/Apple
  /// girişinde (herkese açık sıralamada görüneceği için) yalnızca ilk ad.
  static String _initialProfileName(User authUser, String? nameHint) => _initialProfileNameFrom(
        provider: authUser.appMetadata['provider']?.toString(),
        metadata: authUser.userMetadata ?? const <String, dynamic>{},
        userId: authUser.id,
        nameHint: nameHint,
      );

  static String _initialProfileNameFrom({
    required String? provider,
    required Map<String, dynamic> metadata,
    required String? userId,
    String? nameHint,
  }) {
    final String? candidate;
    if ((provider ?? 'email') == 'email') {
      candidate = metadata['name']?.toString().trim();
    } else {
      candidate = _providerGivenName(provider: provider, metadata: metadata, nameHint: nameHint);
    }
    // Ad yoksa e-postanın yerel kısmı değil nötr ad: profil adı herkese
    // açık sıralamalarda görünür.
    return (candidate == null || candidate.isEmpty) ? neutralProfileName(userId) : _clipName(candidate);
  }

  /// Google/Apple'ın verdiği ilk ad (Apple'da yalnızca ilk yetkilendirmede
  /// gelen [nameHint]); yoksa null.
  static String? _providerGivenName({
    required String? provider,
    required Map<String, dynamic> metadata,
    String? nameHint,
  }) {
    final full = (metadata['full_name'] ?? metadata['name'])?.toString().trim();
    final candidate = (nameHint != null && nameHint.trim().isNotEmpty)
        ? nameHint
        : (metadata['given_name']?.toString() ?? full?.split(RegExp(r'\s+')).first);
    final name = candidate?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  static String _clipName(String name) => name.length > _nameMaxLength ? name.substring(0, _nameMaxLength) : name;

  /// Önbellekteki ('saved_user') kullanıcıyı ağsız okur ve [currentUser]'a
  /// koyar. Çevrimdışı açılış için.
  Future<UserModel?> restoreCachedUser() async {
    final user = await _readCachedUser();
    currentUser.value = user;
    return user;
  }

  /// Kullanıcıyı (ör. onboarding tamamlandıktan sonra yereldeki değişiklikle)
  /// günceller ve önbelleğe yazar. null verilirse önbellek silinir.
  Future<void> setCurrentUser(UserModel? user) async {
    currentUser.value = user;
    await _persistUser(user, epoch: _userEpoch);
  }

  void _publishUser(UserModel? user) {
    currentUser.value = user;
    unawaited(_persistUser(user, epoch: _userEpoch));
  }

  /// [uid] hâlâ oturumdaki kullanıcı mı ve [epoch]'tan beri çıkış olmadı mı?
  bool _isCurrentSession(String uid, int epoch) =>
      epoch == _userEpoch && _isCloudActive && _client.auth.currentUser?.id == uid;

  /// Bir istek yanıtından sonra kullanıcı modelini günceller; ancak istek
  /// başladığından beri ([epoch]) çıkış olmadıysa ve [uid] hâlâ oturumdaysa.
  /// Aksi halde (uçuştaki yanıt çıkıştan/hesap değişiminden sonra geldi)
  /// hiçbir şey yayınlanmaz.
  void _updateUserIfCurrent(String uid, int epoch, UserModel Function(UserModel user) change) {
    final user = currentUser.value;
    if (user == null || !_isCurrentSession(uid, epoch)) return;
    if (user.id != null && user.id != uid) return;
    _publishUser(change(user));
  }

  Future<void> _persistUser(UserModel? user, {required int epoch}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Bu arada çıkış yapıldıysa ('saved_user' silindi) eski kullanıcı geri yazılmaz.
      if (user != null && epoch != _userEpoch) return;
      if (user == null) {
        await prefs.remove(_savedUserKey);
      } else {
        await prefs.setString(_savedUserKey, jsonEncode(user.toMap()));
      }
    } catch (e) {
      debugPrint('[DATA] saved_user yazılamadı: $e');
    }
  }

  Future<UserModel?> _readCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedUserKey);
      if (raw == null || raw.isEmpty) return null;
      return UserModel.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('[DATA] saved_user okunamadı: $e');
      return null;
    }
  }

  /// Profil adını günceller (2..30 karakter, küfür/hakaret içermez; bkz.
  /// [NameFilter]). Başarıda [currentUser] güncellenir.
  Future<void> updateUserName(String newName) async {
    final cleanName = newName.trim();
    if (cleanName.length < _nameMinLength) throw const ServiceException(ServiceErrorCode.nameTooShort);
    if (cleanName.length > _nameMaxLength) throw const ServiceException(ServiceErrorCode.nameTooLong);
    if (NameFilter.isOffensive(cleanName)) throw const ServiceException(ServiceErrorCode.nameNotAllowed);
    final uid = _requireUserId();
    final epoch = _userEpoch;
    final rows = await _guard(
      () => _client.from('profiles').update({'name': cleanName}).eq('id', uid).select('name'),
    );
    if (rows.isEmpty) throw const ServiceException(ServiceErrorCode.notFound);
    _updateUserIfCurrent(uid, epoch, (user) => user.copyWith(name: rows.first['name']?.toString() ?? cleanName));
  }

  /// Günlük hedefi (dakika) profile yazar; tek kaynak profiles.daily_goal_minutes.
  /// Aralık sunucudaki CHECK ile aynı: 5..1440.
  Future<void> updateDailyGoalMinutes(int minutes) async {
    if (minutes < _dailyGoalMin || minutes > _dailyGoalMax) throw const ServiceException(ServiceErrorCode.invalidInput);
    final uid = _requireUserId();
    final epoch = _userEpoch;
    final rows = await _guard(
      () => _client.from('profiles').update({'daily_goal_minutes': minutes}).eq('id', uid).select('daily_goal_minutes'),
    );
    if (rows.isEmpty) throw const ServiceException(ServiceErrorCode.notFound);
    _updateUserIfCurrent(uid, epoch, (user) => user.copyWith(dailyGoalMinutes: minutes));
  }

  static String _dailyGoalMigratedKey(String userId) => 'daily_goal_migrated_$userId';

  // Eski sürümler bazı anahtar adlarında e-postayı kullanıyordu (iOS'ta düz
  // plist, yedeğe girer). Kimlik bilinince uid anahtarına taşınır. Kategori
  // önbelleği CategoryCache.read'de, bekleyen kuyruk adoptLegacyQueue'da,
  // süren seans TimerPersistence.load'da taşınır.
  @visibleForTesting
  Future<void> migrateLegacyEmailKeys(UserModel user) async {
    final uid = user.id;
    final email = user.email.trim();
    if (uid == null || uid.isEmpty || email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    for (final mail in {email, email.toLowerCase()}) {
      final legacyLeagueKey = 'league_info_shown_$mail';
      if (!prefs.containsKey(legacyLeagueKey)) continue;
      if (prefs.getBool(legacyLeagueKey) ?? false) await prefs.setBool('league_info_shown_$uid', true);
      await prefs.remove(legacyLeagueKey);
    }
  }

  // Raporlar eskiden hedefi cihazda ('daily_pomo_goal', pomodoro adedi)
  // tutuyordu. Kullanıcının orada seçtiği değer bir kez profile taşınır.
  Future<void> _migrateLegacyDailyGoal(UserModel user) async {
    final uid = user.id;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dailyGoalMigratedKey(uid)) ?? false) return;
    final pomodoros = prefs.getInt(_legacyDailyGoalKey);
    if (pomodoros != null && pomodoros > 0) {
      await updateDailyGoalMinutes(math.min(pomodoros * 25, 24 * 60));
    }
    await prefs.setBool(_dailyGoalMigratedKey(uid), true);
  }

  /// Onboarding'in yazdığı hedefler; dışındaki değer (ör. "Diğer") null
  /// yazılır. Canlıdaki profiles_user_segment_check yalnızca 'lgs', 'yks',
  /// 'university', 'work'ü kabul eder; 'kpss' ve 'language' supabase/proposed/26
  /// ile eklenir. 26 uygulanmadan reddedilirse [completeOnboarding] segmentsiz
  /// tamamlar ([writeOnboardingProfileWithSegmentFallback]).
  static const Set<String> validUserSegments = {'lgs', 'yks', 'kpss', 'language', 'university', 'work'};

  /// Onboarding'in profiles satırına yazdığı alanlar. Doğum yılı CHECK
  /// aralığı (1900..2100) dışındaysa, segment bilinen kümede değilse null
  /// yazılır. Kullanıcının onboarding'de açıkça verdiği "sıralamalarda
  /// görün" yanıtı ([showInSocialFeed]) her zaman aynı güncellemeyle yazılır
  /// (authenticated rolün bu kolonda UPDATE yetkisi var): kolon
  /// gönderilmezse sunucu varsayılanı TRUE kalır ve "Hayır" diyen kullanıcı
  /// herkese açık sıralamaya girer.
  @visibleForTesting
  static Map<String, dynamic> onboardingProfileUpdate({
    int? birthYear,
    String? userSegment,
    required int dailyGoalMinutes,
    required bool showInSocialFeed,
    required DateTime completedAt,
  }) {
    final validBirthYear =
        (birthYear != null && birthYear >= _birthYearMin && birthYear <= _birthYearMax) ? birthYear : null;
    return {
      'birth_year': validBirthYear,
      'user_segment': validUserSegments.contains(userSegment) ? userSegment : null,
      'daily_goal_minutes': dailyGoalMinutes,
      'show_in_social_feed': showInSocialFeed,
      'onboarding_completed_at': completedAt.toUtc().toIso8601String(),
    };
  }

  /// Hata, profiles_user_segment_check ihlali mi (23514)? Sunucu yeni hedefi
  /// ('kpss', 'language'; proposed/26) henüz tanımıyor demektir.
  @visibleForTesting
  static bool isUserSegmentCheckViolation(Object error) {
    final cause = error is ServiceException ? error.cause : error;
    if (cause is! PostgrestException || cause.code != '23514') return false;
    return '${cause.message} ${cause.details ?? ''}'.toLowerCase().contains('user_segment');
  }

  /// Onboarding profil güncellemesini [write] ile yazar ve yazılan değerleri
  /// döndürür. Sunucu segmenti CHECK ile reddederse (proposed/26 canlıda
  /// değil) güncelleme segment null olarak bir kez daha yazılır: onboarding
  /// tamamlanır, kullanıcı hata görmez (kategoriler bundan önce kuruldu).
  /// Diğer hatalar olduğu gibi fırlatılır.
  @visibleForTesting
  static Future<Map<String, dynamic>> writeOnboardingProfileWithSegmentFallback(
    Map<String, dynamic> update,
    Future<void> Function(Map<String, dynamic> values) write,
  ) async {
    try {
      await write(update);
      return update;
    } catch (e) {
      if (update['user_segment'] == null || !isUserSegmentCheckViolation(e)) rethrow;
      debugPrint('[DATA] Sunucu segmenti tanımıyor (proposed/26 yok); onboarding segmentsiz tamamlanıyor.');
      final fallback = {...update, 'user_segment': null};
      await write(fallback);
      return fallback;
    }
  }

  /// Onboarding'i tek adımda tamamlar: profil satırını garanti eder,
  /// kategorileri oluşturur, ardından profil alanlarını yazar (kategoriler
  /// profile yabancı anahtarla bağlı olduğu için sıra önemli). Güncelleme
  /// hiçbir satıra uymazsa hata fırlatır. Segment sunucuda tanınmıyorsa
  /// segmentsiz yazılır ([writeOnboardingProfileWithSegmentFallback]).
  Future<void> completeOnboarding({
    int? birthYear,
    String? userSegment,
    required int dailyGoalMinutes,
    List<Map<String, dynamic>> categories = const [],
    required bool showInSocialFeed,
  }) async {
    if (dailyGoalMinutes < _dailyGoalMin || dailyGoalMinutes > _dailyGoalMax) {
      throw const ServiceException(ServiceErrorCode.invalidInput);
    }
    final authUser = _requireAuthUser();
    final epoch = _userEpoch;
    await _guard(() => _ensureOwnProfile(authUser));
    if (categories.isNotEmpty) await _setupOnboardingCategoriesReconciled(authUser.id, categories);
    final completedAt = DateTime.now();
    final update = onboardingProfileUpdate(
      birthYear: birthYear,
      userSegment: userSegment,
      dailyGoalMinutes: dailyGoalMinutes,
      showInSocialFeed: showInSocialFeed,
      completedAt: completedAt,
    );
    final written = await writeOnboardingProfileWithSegmentFallback(update, (values) async {
      final rows = await _guard(() => _client.from('profiles').update(values).eq('id', authUser.id).select('id'));
      if (rows.isEmpty) throw const ServiceException(ServiceErrorCode.notFound);
    });
    _socialVisibleCache = showInSocialFeed;
    _socialVisibleCacheUid = authUser.id;
    _updateUserIfCurrent(
      authUser.id,
      epoch,
      (user) => user.copyWith(
        birthYear: written['birth_year'] as int?,
        userSegment: written['user_segment'] as String?,
        dailyGoalMinutes: dailyGoalMinutes,
        onboardingCompletedAt: completedAt,
      ),
    );
  }

  /// Onboarding kategorilerini sunucudaki mevcut kategorilerle uzlaştırarak
  /// kurar (bkz. [planOnboardingCategories]). Önceki deneme kategorileri
  /// kurup profil yazılamadan yarıda kaldıysa yeni seçim artık limite
  /// takılmaz ve dil değişince aynı kategorinin TR/EN çifti oluşmaz.
  /// Arşivleme yalnızca onboarding'i bitmemiş, hiç seansı (sunucuda ya da
  /// kuyrukta) olmayan hesapta yapılır. Adımlar idempotent: yarıda kalırsa
  /// bir sonraki "Bitir" kaldığı yerden tamamlar.
  Future<void> _setupOnboardingCategoriesReconciled(String uid, List<Map<String, dynamic>> categories) async {
    final existing = await fetchUserCategories(includeArchived: true);
    if (existing.isEmpty) return setupOnboardingCategories(categories);
    final canArchive = currentUser.value?.onboardingCompletedAt == null &&
        pendingSessionCount.value == 0 &&
        !await _hasAnyStudySession(uid);
    final plan = planOnboardingCategories(requested: categories, existing: existing, canArchive: canArchive);
    for (final id in plan.archiveIds) {
      await archiveCategory(id);
    }
    for (final id in plan.unarchiveIds) {
      await unarchiveCategory(id);
    }
    if (plan.payload.isNotEmpty) await setupOnboardingCategories(plan.payload);
  }

  Future<bool> _hasAnyStudySession(String uid) async {
    final rows = await _guard(() => _client.from('study_sessions').select('id').eq('user_id', uid).limit(1));
    return rows.isNotEmpty;
  }

  // Seans sonrası profildeki sayaçları sunucudan tazeler (deltaların doğruluğu).
  Timer? _statsRefreshTimer;

  void _scheduleUserStatsRefresh() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = Timer(const Duration(seconds: 2), () => unawaited(_refreshUserStats()));
  }

  Future<void> _refreshUserStats() async {
    final user = currentUser.value;
    final uid = _isCloudActive ? _client.auth.currentUser?.id : null;
    if (user == null || uid == null || (user.id != null && user.id != uid)) return;
    final epoch = _userEpoch;
    try {
      final row = await _client
          .from('profiles')
          .select('total_minutes, lifetime_points, coins, current_streak, longest_streak, last_study_date')
          .eq('id', uid)
          .maybeSingle()
          .timeout(_requestTimeout);
      // A için okunan sayaçlar, bu arada oturuma giren B'nin modeline yazılmaz.
      if (row == null) return;
      _updateUserIfCurrent(uid, epoch, (latest) => UserModel.fromMap({...latest.toMap(), ...row}));
    } catch (e) {
      debugPrint('[DATA] Profil sayaçları tazelenemedi: $e');
    }
  }

  // ---- Seanslar ----

  /// Sunucuda gerçekten var olabilecek (UUID biçiminde) bir kategori kimliği mi?
  static bool isServerCategoryId(String id) => isUuidCategoryId(id);

  ({String? userId, String? email}) _queueOwner() {
    final authUid = _isCloudActive ? _client.auth.currentUser?.id : null;
    final user = currentUser.value;
    final email = user?.email;
    return (
      userId: authUid ?? user?.id,
      email: (email == null || email.isEmpty) ? null : email,
    );
  }

  /// Tamamlanan seansı gönderir. Seans önce kalıcı kuyruğa yazılır, sonra
  /// kuyruk (bu seans dahil) started_at sırasıyla gönderilir.
  /// - [SessionSubmitSuccess]: kaydedildi; [currentUser] güncellendi.
  /// - [SessionSubmitQueued]: geçici sorun; seans kuyrukta, sonra denenecek.
  /// - [SessionSubmitRejected]: sunucu kalıcı olarak reddetti.
  Future<SessionSubmitResult> submitCompletedSession({
    required String clientUuid,
    required String categoryId,
    required String categoryName,
    required int durationMinutes,
    required bool wasPaused,
    required int foregroundSeconds,
    required DateTime startedAt,
  }) async {
    final session = PendingSession(
      clientUuid: clientUuid,
      categoryId: categoryId.isEmpty ? null : categoryId,
      categoryName: categoryName,
      minutes: durationMinutes,
      wasPaused: wasPaused,
      foregroundSeconds: foregroundSeconds,
      startedAt: startedAt.toUtc(),
      queuedAt: DateTime.now().toUtc(),
      clockOffsetMs: _clock.offset?.inMilliseconds,
    );
    final owner = _queueOwner();
    SessionSubmitResult result;
    if (owner.userId != null) {
      result = await _queue.submit(owner.userId!, session);
    } else if (owner.email != null) {
      // Kimlik henüz bilinmiyor (eski önbellek, çevrimdışı): e-posta
      // anahtarlı kuyruğa yazılır, kimlik öğrenilince taşınır.
      await _queue.enqueueLegacy(owner.email!, session);
      final pending = await _queue.legacyPendingCount(owner.email!);
      pendingSessionCount.value = pending;
      result = SessionSubmitQueued(reasonCode: SessionReason.offline, pendingCount: pending);
    } else {
      result = const SessionSubmitRejected(SessionReason.auth);
    }
    _notifyStatsChanged();
    return result;
  }

  /// Bekleyen seansları göndermeyi dener. Kalan seans sayısını ve kalanların
  /// kendiliğinden yeniden denenmeye değer olup olmadığını ([retryable]: ağ,
  /// zaman aşımı, sunucu ya da oturum hatası; yalnızca çakışma değil)
  /// döndürür.
  Future<({int remaining, bool retryable})> syncPendingSessions() async {
    final owner = _queueOwner();
    final uid = owner.userId;
    if (uid == null) return (remaining: 0, retryable: false);
    if (owner.email != null) await _queue.adoptLegacyQueue(userId: uid, email: owner.email!);
    if (!_isCloudActive || _client.auth.currentUser?.id != uid) {
      // Oturum henüz yok/başka hesap: oturum olayı (giriş, token yenileme) tetikler.
      return (remaining: await _queue.pendingCount(uid), retryable: false);
    }
    final report = await _queue.sync(uid);
    if (report.sent > 0) _notifyStatsChanged();
    return (remaining: report.remaining, retryable: report.hasRetryableFailure);
  }

  /// Oturumdaki kullanıcının bekleyen seansları (started_at sırasıyla).
  Future<List<PendingSession>> getPendingSessions() async {
    final uid = _queueOwner().userId;
    return uid == null ? const [] : _queue.pending(uid);
  }

  /// Bekleyen seans sayısını okur ve [pendingSessionCount]'u günceller.
  Future<int> getPendingSessionCount() async {
    final owner = _queueOwner();
    final count = owner.userId != null
        ? await _queue.pendingCount(owner.userId!)
        : (owner.email != null ? await _queue.legacyPendingCount(owner.email!) : 0);
    pendingSessionCount.value = count;
    return count;
  }

  /// Arka planda reddedilmiş ve henüz bildirilmemiş seans sayısı. Bir kez
  /// okunur, sonra sıfırlanır (UI bir kez bildirim gösterir).
  Future<int> takeRejectedSessionNoticeCount() async {
    final uid = _queueOwner().userId;
    return uid == null ? 0 : _queue.takeRejectedNoticeCount(uid);
  }

  /// Kalıcı olarak reddedilmiş son seanslar (en fazla 50).
  Future<List<RejectedSession>> getRejectedSessions() async {
    final uid = _queueOwner().userId;
    return uid == null ? const [] : _queue.rejectedSessions(uid);
  }

  void _onQueueChanged(String userId, int count) {
    if (_queueOwner().userId == userId) pendingSessionCount.value = count;
  }

  void _onSessionAccepted(String userId, PendingSession session, SessionSubmitSuccess result) {
    final user = currentUser.value;
    if (user == null || (user.id != null && user.id != userId)) return;
    if (!result.duplicate) {
      final day = studyDayKey(studyDayOf(session.startedAt, timeZone: user.timezone));
      final last = user.lastStudyDate;
      _publishUser(user.copyWith(
        id: userId,
        totalMinutes: user.totalMinutes + result.minutes,
        lifetimePoints: user.lifetimePoints + result.totalPoints,
        coins: user.coins + result.coinsEarned,
        currentStreak: result.streak,
        longestStreak: math.max(user.longestStreak, result.streak ?? 0),
        lastStudyDate: (last == null || day.compareTo(last) > 0) ? day : last,
      ));
    }
    _scheduleUserStatsRefresh();
  }

  /// Kullanıcının TÜM seanslarını (yalnızca kendi user_id'si) sayfalayarak
  /// çeker. [since] verilirse yalnızca o andan sonra başlayanlar. Hata
  /// durumunda [ServiceException] fırlatır; boş liste "hiç seans yok" demektir.
  Future<List<StudySession>> fetchStudySessions({DateTime? since}) async {
    final uid = _requireUserId();
    final sessions = <StudySession>[];
    for (var from = 0;; from += _sessionsPageSize) {
      final page = await _guard(() {
        var query = _client.from('study_sessions').select(_studySessionColumns).eq('user_id', uid);
        if (since != null) query = query.gte('started_at', since.toUtc().toIso8601String());
        return query
            .order('started_at', ascending: false)
            .order('id', ascending: true)
            .range(from, from + _sessionsPageSize - 1);
      });
      try {
        sessions.addAll(page.map(StudySession.fromJson));
      } catch (e, st) {
        Error.throwWithStackTrace(ServiceException(ServiceErrorCode.server, e), st);
      }
      if (page.length < _sessionsPageSize) break;
    }
    return sessions;
  }

  // ---- İstatistik değişim bildirimi (yalnızca bu cihaz) ----

  final List<VoidCallback> _statsListeners = [];

  /// Bu cihazda seans tamamlandığında ya da kuyruk senkronu en az bir seansı
  /// gönderdiğinde çağrılır. (Eski herkese açık 'ranking_updates' yayını,
  /// her kullanıcının seansında tüm istemcilere tam geçmiş çektirdiği ve
  /// anon anahtarla kötüye kullanılabildiği için kaldırıldı.)
  void addStatsChangedListener(VoidCallback listener) => _statsListeners.add(listener);

  void removeStatsChangedListener(VoidCallback listener) => _statsListeners.remove(listener);

  /// Bağlantı geri geldi ya da bulut sonradan başlatıldı: bağlantısızken
  /// yüklenemeyen veri ekranları (Raporlar, Sıralama) aynı dinleyicilerle
  /// yenilenir; görünmeyen ekran görünür olunca yeniler.
  void notifyConnectionRestored() => _notifyStatsChanged();

  void _notifyStatsChanged() {
    for (final listener in List.of(_statsListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('[DATA] İstatistik dinleyicisi hatası: $e');
      }
    }
  }

  // ---- Canlı odaklanma ve sosyal görünürlük ----

  // Önbellek kullanıcı kimliğine bağlı: hesap değişince taşınmaz.
  bool? _socialVisibleCache;
  String? _socialVisibleCacheUid;

  /// "Sosyal listede görün" tercihi. Okunamazsa varsayılan true.
  Future<bool> getSocialVisibility() async {
    if (!_isCloudActive) return true;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return true;
    if (_socialVisibleCacheUid == uid && _socialVisibleCache != null) return _socialVisibleCache!;
    try {
      final row = await _client
          .from('profiles')
          .select('show_in_social_feed')
          .eq('id', uid)
          .maybeSingle()
          .timeout(_requestTimeout);
      final value = row?['show_in_social_feed'] as bool? ?? true;
      _socialVisibleCache = value;
      _socialVisibleCacheUid = uid;
      return value;
    } catch (e) {
      debugPrint('[SOCIAL] getSocialVisibility hatası: $e');
      return true;
    }
  }

  /// Tercihi sunucuya yazar; hata durumunda fırlatır (UI eski değere dönmeli).
  Future<void> setSocialVisibility(bool value) async {
    final uid = _requireUserId();
    await _guard(() => _client.from('profiles').update({'show_in_social_feed': value}).eq('id', uid));
    _socialVisibleCache = value;
    _socialVisibleCacheUid = uid;
  }

  Future<void> startStudySession({
    required int durationMinutes,
    required String categoryName,
  }) async {
    if (!_isCloudActive || _client.auth.currentUser == null) return;
    if (!await getSocialVisibility()) return;
    try {
      await _client.rpc('start_study_session', params: {
        'p_duration_minutes': durationMinutes,
        'p_category_name': categoryName,
      }).timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[SOCIAL] startStudySession hatası: $e');
    }
  }

  Future<void> cancelStudySession() async {
    if (!_isCloudActive || _client.auth.currentUser == null) return;
    try {
      await _client.rpc('cancel_study_session').timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[SOCIAL] cancelStudySession hatası: $e');
    }
  }

  /// Şu an odaklanan arkadaşlar. Hata durumunda fırlatır.
  Future<List<Map<String, dynamic>>> getLiveFriends() async {
    _requireUserId();
    return _rows(await _guard(() => _client.rpc('get_live_friends')));
  }

  // ---- Arkadaşlar ----

  /// Kullanıcının kendi arkadaşlık kodu.
  Future<String?> getMyFriendCode() async {
    if (!_isCloudActive) return null;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client.from('profiles').select('friend_code').eq('id', uid).maybeSingle().timeout(_requestTimeout);
      return row?['friend_code'] as String?;
    } catch (e) {
      debugPrint('[SOCIAL] getMyFriendCode hatası: $e');
      return null;
    }
  }

  /// Kodla arkadaş ekler. Sunucunun yanıtını (success, friend, auto_accepted,
  /// …) döndürür; istemci tarafı hatalarda [ServiceException] fırlatır.
  Future<Map<String, dynamic>> addFriendByCode(String code) async {
    _requireUserId();
    final normalized = code.replaceAll(RegExp(r'\s+'), '');
    final response = await _guard(() => _client.rpc('add_friend_by_code', params: {'p_code': normalized}));
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const ServiceException(ServiceErrorCode.server);
  }

  /// Kabul edilmiş arkadaşlar: get_my_friends → (id, name, avatar_id,
  /// lifetime_points, total_minutes), puana göre azalan. Başkalarının
  /// profiles satırı RLS yüzünden okunamadığı için tek yol bu SECURITY
  /// DEFINER RPC'dir. Hata durumunda fırlatır.
  Future<List<Map<String, dynamic>>> fetchFriends() async {
    _requireUserId();
    return _rows(await _guard(() => _client.rpc('get_my_friends')));
  }

  /// Gelen, onaylanmamış arkadaşlık istekleri: get_incoming_friend_requests
  /// → (id, name, avatar_id, lifetime_points, total_minutes, created_at),
  /// en yeni önce. 'id' isteği gönderenin kimliğidir (respond_friend_request
  /// p_from_user_id). Hata durumunda fırlatır.
  Future<List<Map<String, dynamic>>> fetchPendingFriendRequests() async {
    _requireUserId();
    return _rows(await _guard(() => _client.rpc('get_incoming_friend_requests')));
  }

  /// Gelen isteği kabul eder ya da reddeder; sunucunun yanıtını döndürür.
  Future<Map<String, dynamic>> respondToFriendRequest(String fromUserId, bool accept) async {
    _requireUserId();
    final response = await _guard(() => _client.rpc('respond_friend_request', params: {
          'p_from_user_id': fromUserId,
          'p_accept': accept,
        }));
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const ServiceException(ServiceErrorCode.server);
  }

  // ---- Sıralama ----

  // Herkese açık sıralama RPC'lerinin sunucu tarafı üst sınırı.
  static const int _publicLeaderboardMaxLimit = 100;

  /// Bu ayın (Europe/Istanbul ay sınırı) herkese açık sıralaması:
  /// get_public_monthly_leaderboard → (name, avatar_id, total_points,
  /// total_minutes, is_me). Oturum açıkken tam ad döner; kullanıcının kendi
  /// satırı YALNIZCA is_me ile bilinir (isimle eşleme yapılmaz).
  Future<List<Map<String, dynamic>>> getMonthlyRanking({int limit = 50}) async {
    _requireCloud();
    final pLimit = limit.clamp(1, _publicLeaderboardMaxLimit);
    return _rows(await _guard(() => _client.rpc('get_public_monthly_leaderboard', params: {'p_limit': pLimit})));
  }

  /// Tüm zamanlar sıralaması: get_public_alltime_leaderboard → (name,
  /// avatar_id, total_minutes, lifetime_points, is_premium, is_me). Kendi
  /// satırı yalnızca is_me ile bilinir.
  Future<List<Map<String, dynamic>>> getAllTimeRanking({int limit = 50}) async {
    _requireCloud();
    final pLimit = limit.clamp(1, _publicLeaderboardMaxLimit);
    return _rows(await _guard(() => _client.rpc('get_public_alltime_leaderboard', params: {'p_limit': pLimit})));
  }

  /// Oturum sahibinin lig odası (14 günlük dönem): get_my_league_ranking →
  /// (name, avatar_id, weekly_points, tier, end_date, is_me,
  /// promotion_zone_end, demotion_zone_start, member_count). Kullanıcı henüz
  /// bir odada değilse sunucu tek satır döndürür (is_me, 0 puan, member_count
  /// 1); bkz. `LeagueSnapshot.awaitingPlacement`. Hata durumunda fırlatır.
  Future<List<Map<String, dynamic>>> getLeagueRanking() async {
    _requireUserId();
    return _rows(await _guard(() => _client.rpc('get_my_league_ranking')));
  }

  // Son okunan puan kuralları; seans sonucu bildirimi gibi eşzamanlı
  // yerlerde kullanılır.
  Map<String, dynamic> _pointsConfigCache = const {};

  // Sunucunun günlük tavanı (complete_study_session); config okunamadıysa.
  static const int _defaultDailySessionLimit = 16;

  /// Günde puan ve kum kazandıran en fazla seans sayısı
  /// (get_points_config.daily_league_session_limit). Sonraki seanslar 0 puan
  /// ve 0 kum alır; yalnızca dakika ve seri sayılır.
  int get dailySessionLimit {
    final value = _pointsConfigCache['daily_league_session_limit'];
    return value is num && value > 0 ? value.toInt() : _defaultDailySessionLimit;
  }

  // Puan hesabında kullanılan sabitleri sunucudan okur (bkz. get_points_config
  // RPC'si). Bu değerler complete_study_session RPC'sinin gövdesindeki
  // sabitlerle aynı tutulmalıdır; UI tarafında asla hardcode edilmez.
  Future<Map<String, dynamic>> getPointsConfig() async {
    if (_isCloudActive) {
      try {
        final response = await _client.rpc('get_points_config').timeout(_requestTimeout);
        if (response is Map) return _pointsConfigCache = Map<String, dynamic>.from(response);
      } catch (e) {
        debugPrint('[RANKING] getPointsConfig hatası: $e');
      }
    }
    return {};
  }

  // ---- Avatar ekonomisi ----

  bool _avatarCatalogFresh = false;

  /// Son başarılı kataloğu cihazdan (ağsız) yükler. Hiç yoksa gömülü katalog
  /// kullanılmaya devam edilir.
  Future<void> loadCachedAvatarCatalog() async {
    if (AvatarCharacter.hasServerCatalog) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_avatarCatalogKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => AvatarCharacter.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      AvatarCharacter.setCachedAvatars(list);
    } catch (e) {
      debugPrint('[AVATAR] Önbellekteki katalog okunamadı: $e');
    }
  }

  Future<void>? _catalogRefresh;

  /// Kataloğu sunucudan çeker, önbelleğe ve cihaza yazar. Hata ya da boş
  /// yanıtta (oturumsuz istekte RLS boş döndürebilir) mevcut katalog korunur.
  /// Aynı anda tek istek yapılır.
  Future<void> refreshAvatarCatalog() {
    return _catalogRefresh ??= _refreshAvatarCatalog().whenComplete(() => _catalogRefresh = null);
  }

  Future<void> _refreshAvatarCatalog() async {
    if (!_isCloudActive) return;
    try {
      final rows = _rows(await _client
          .from('avatars')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .timeout(const Duration(seconds: 8)));
      final avatars = rows.map(AvatarCharacter.fromMap).toList();
      if (avatars.isEmpty) return;
      AvatarCharacter.setCachedAvatars(avatars);
      _avatarCatalogFresh = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarCatalogKey, jsonEncode(avatars.map((a) => a.toMap()).toList()));
    } catch (e) {
      debugPrint('[AVATAR] Katalog çekilemedi: $e');
    }
  }

  /// Avatarı satın alır (Premium avatarı Premium kullanıcı için ücretsiz
  /// açar). Yeni bakiyeyi döndürür; [currentUser] güncellenir. Hata
  /// durumunda [ServiceException] (insufficientCoins, premiumRequired, …).
  Future<int> purchaseAvatar(String avatarId) async {
    final uid = _requireUserId();
    final epoch = _userEpoch;
    final response = await _guard(() => _client.rpc('purchase_avatar', params: {'p_avatar_id': avatarId}));
    if (response is! num) throw const ServiceException(ServiceErrorCode.server);
    final newCoins = response.toInt();
    _updateUserIfCurrent(
      uid,
      epoch,
      (user) => user.copyWith(coins: newCoins, unlockedAvatars: {...user.unlockedAvatars, avatarId}.toList()),
    );
    return newCoins;
  }

  /// Avatarı kuşanır; [currentUser] güncellenir. Sahip olunmayan avatar için
  /// sunucu reddeder ve [ServiceException] (avatarLocked) fırlatılır.
  Future<void> setEquippedAvatar(String avatarId) async {
    final uid = _requireUserId();
    final epoch = _userEpoch;
    await _guard(() => _client.rpc('set_equipped_avatar', params: {'p_avatar_id': avatarId}));
    _updateUserIfCurrent(uid, epoch, (user) => user.copyWith(avatarId: avatarId));
  }

  // ---- Kategoriler ----

  void _bumpCategories() => categoriesRevision.value++;

  /// Kullanıcının buluttaki kategorileri. Ağ/sunucu hatasında ya da bulut
  /// kapalıyken fırlatır; çağıran yerel önbelleğe düşmelidir. Bulutta hiç
  /// kategori yoksa boş liste döner.
  Future<List<CourseCategory>> fetchUserCategories({bool includeArchived = false}) async {
    final uid = _requireUserId();
    final rows = await _guard(() {
      var query = _client
          .from('categories')
          .select('id, name, color_hex, icon_name, sort_order, is_archived')
          .eq('user_id', uid);
      if (!includeArchived) query = query.eq('is_archived', false);
      // sort_order canlıda çakışabiliyor (create_category aktif sayısını
      // yazıyor); eşitlikte sıra deterministik olsun diye ek anahtarlar.
      return query
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true)
          .order('id', ascending: true);
    });
    return rows.map(CourseCategory.fromServerRow).toList();
  }

  /// Bulutta hiç aktif kategori yoksa yerel listeyi (önbellekteki sunucu
  /// kategorileri; yoksa kullanıcının segmentine ve diline göre
  /// varsayılanları, [defaultCategorySeedForCurrentUser]) sunucuda
  /// oluşturur; kimlikleri sunucu üretir. Güncel bulut listesini döndürür.
  /// Yer tutucu kategorilerden kurtulmanın tek yolu budur.
  Future<List<CourseCategory>> ensureServerCategories(List<CourseCategory> localFallback) async {
    final active = await fetchUserCategories();
    if (active.isNotEmpty) return active;
    // Yer tutucular ('1'..'5') yalnızca cihazdaki varsayılan listedir; tohum olmaz.
    final source = localFallback.where((c) => !c.isArchived && isUuidCategoryId(c.id)).toList();
    final seed = source.isNotEmpty ? source.map((c) => c.toServerJson()).toList() : defaultCategorySeedForCurrentUser();
    await setupOnboardingCategories(seed);
    return fetchUserCategories();
  }

  /// Kategorisiz hesabın varsayılanları: profildeki segmentin önerileri,
  /// arayüz dilinde ('work' kullanıcısına okul dersleri açılmaz).
  List<Map<String, dynamic>> defaultCategorySeedForCurrentUser() => defaultCategorySeed(
        segment: currentUser.value?.userSegment,
        turkish: LanguageService.instance.isTurkish,
      );

  /// Yeni kategori (create_category RPC). Limit ve aynı isim kontrolü
  /// sunucuda; reddedilirse ham hata fırlatılır (bkz. [serviceErrorCodeOf]).
  Future<String?> createCategory(String name, String colorHex, String iconName) async {
    _requireUserId();
    final result = await _client.rpc('create_category', params: {
      'p_name': name,
      'p_color_hex': colorHex,
      'p_icon_name': iconName,
    }).timeout(_requestTimeout);
    _bumpCategories();
    return result as String?;
  }

  Future<void> setupOnboardingCategories(List<Map<String, dynamic>> categories) async {
    _requireUserId();
    await _client.rpc('setup_onboarding_categories', params: {
      'p_categories': categories,
    }).timeout(_requestTimeout);
    _bumpCategories();
  }

  Future<void> archiveCategory(String categoryId) async {
    final uid = _requireUserId();
    await _client
        .from('categories')
        .update({'is_archived': true})
        .eq('id', categoryId)
        .eq('user_id', uid)
        .timeout(_requestTimeout);
    _bumpCategories();
  }

  /// Arşivden çıkarır. Aktif kategori limiti sunucudaki trigger ile
  /// zorunlu; limit aşılırsa ham hata fırlatılır (categoryLimitReached).
  Future<void> unarchiveCategory(String categoryId) async {
    final uid = _requireUserId();
    await _client
        .from('categories')
        .update({'is_archived': false})
        .eq('id', categoryId)
        .eq('user_id', uid)
        .timeout(_requestTimeout);
    _bumpCategories();
  }

  Future<void> updateCategory(String categoryId, String name, String colorHex, String iconName) async {
    final uid = _requireUserId();
    await _client
        .from('categories')
        .update({'name': name, 'color_hex': colorHex, 'icon_name': iconName})
        .eq('id', categoryId)
        .eq('user_id', uid)
        .timeout(_requestTimeout);
    _bumpCategories();
  }

  /// Aktif kategorilerin sırasını yazar: her kategori için yalnızca
  /// sort_order güncellenir (istekler paralel). Canlıda 'reorder_categories'
  /// RPC'si yok; upsert de kullanılmaz, çünkü INSERT yolu kategori limiti
  /// trigger'ını (BEFORE INSERT) tetikler. sort_order güncellemesi hiçbir
  /// trigger'a takılmaz. Bir istek başarısız olursa fırlatır; çağıran listeyi
  /// sunucudan yeniden okur.
  Future<void> updateCategoryOrders(List<String> orderedIds) async {
    final uid = _requireUserId();
    if (orderedIds.isEmpty) return;
    await Future.wait([
      for (var i = 0; i < orderedIds.length; i++)
        _client
            .from('categories')
            .update({'sort_order': i})
            .eq('id', orderedIds[i])
            .eq('user_id', uid)
            .timeout(_requestTimeout),
    ]);
    _bumpCategories();
  }
}

/// Seans kuyruğunun Supabase bağlantısı.
class _SupabaseQueueBackend implements SessionQueueBackend {
  _SupabaseQueueBackend(this._service);

  final SupabaseService _service;

  @override
  String? get signedInUserId => _service._isCloudActive ? _service._client.auth.currentUser?.id : null;

  @override
  Future<Object?> completeSession(
    PendingSession session, {
    required String categoryId,
    required DateTime startedAtForServer,
  }) {
    return _service._client.rpc('complete_study_session', params: {
      'p_client_uuid': session.clientUuid,
      'p_category_id': categoryId,
      'p_duration_minutes': session.minutes,
      'p_was_paused': session.wasPaused,
      'p_is_verified': session.foregroundSeconds,
      'p_started_at': startedAtForServer.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<CategoryRef>> fetchCategories() async => [
        for (final c in await _service.fetchUserCategories(includeArchived: true))
          (id: c.id, name: c.name, isArchived: c.isArchived),
      ];

  @override
  Future<void> createDefaultCategories() =>
      _service.setupOnboardingCategories(_service.defaultCategorySeedForCurrentUser());
}
