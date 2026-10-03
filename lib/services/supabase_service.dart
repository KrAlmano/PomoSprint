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
import '../models/study_session.dart';
import '../models/user_model.dart';
import '../utils/study_day.dart';
import 'server_clock.dart';
import 'service_errors.dart';
import 'session_queue.dart';

export 'service_errors.dart';
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

  static const String _studySessionColumns =
      'id, user_id, category, category_id, duration_minutes, started_at, completed_at, '
      'categories(name, color_hex)';

  static const String _savedUserKey = 'saved_user';
  static const String _avatarCatalogKey = 'avatar_catalog_v1';
  static const String _legacyDailyGoalKey = 'daily_pomo_goal';
  static const Duration _requestTimeout = Duration(seconds: 15);
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

  void _requireCloudForAuth() {
    if (!_isCloudActive) throw const AuthFailure(AuthErrorCode.cloudUnavailable);
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
      if (dotenv.isInitialized) {
        url = dotenv.env['SUPABASE_URL'] ?? '';
        anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      }
    } catch (e) {
      debugPrint('[INIT] .env okunamadı: $e');
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
        (data) {
          // Kullanıcı eylemi ya da başarısız token yenilemesi: kullanıcıya
          // özel durumu temizle (bekleyen seans kuyruğu korunur).
          if (data.event == AuthChangeEvent.signedOut) unawaited(_clearUserScopedState());
        },
        onError: (Object e) => debugPrint('[AUTH] onAuthStateChange hatası: $e'),
      );
      debugPrint('[INIT] Supabase bağlandı.');
    } catch (e) {
      debugPrint('[INIT] Supabase bağlantı hatası: $e');
      _isCloudActive = false;
    }
  }

  // ---- Kimlik doğrulama ----

  // Tek bir GoogleSignIn örneği: her çağrıda yeniden oluşturmak,
  // paketin sessiz oturum önbelleğini (signInSilently) sıfırlıyordu.
  static const String _googleWebClientId = '722417205043-d7t27n7usp9nrfeuh8o97fald6a5v9ku.apps.googleusercontent.com';
  static const String _googleIosClientId = '722417205043-luq0knjdncu1aitpg9udbfgmo2qdtced.apps.googleusercontent.com';
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleWebClientId,
    clientId: _googleIosClientId,
  );

  /// Supabase oturumunu ve Google'ın native oturumunu kapatır, kullanıcıya
  /// özel önbellekleri ve singleton durumlarını temizler. Bekleyen seans
  /// kuyruğu kullanıcı kimliğine bağlı olarak diskte kalır; başka bir
  /// hesaba gönderilmez.
  Future<void> signOutFully() async {
    final email = currentUser.value?.email;
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Apple/e-posta kullanıcısında Google oturumu yoktur; beklenen durum.
      debugPrint('[AUTH] GoogleSignIn signOut: $e');
    }
    if (_isCloudActive) {
      try {
        await _client.auth.signOut();
      } catch (e) {
        debugPrint('[AUTH] Supabase signOut hatası: $e');
      }
    }
    await _clearUserScopedState(email: email);
  }

  Future<void> _clearUserScopedState({String? email}) async {
    final mail = email ?? currentUser.value?.email;
    _statsRefreshTimer?.cancel();
    currentUser.value = null;
    pendingSessionCount.value = 0;
    _socialVisibleCache = null;
    _socialVisibleCacheUid = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedUserKey);
      await prefs.remove('saved_categories');
      if (mail != null && mail.isNotEmpty) await prefs.remove('saved_categories_$mail');
    } catch (e) {
      debugPrint('[AUTH] Yerel kullanıcı önbelleği temizlenemedi: $e');
    }
  }

  Future<AuthResponse?> registerUser({
    required String email,
    required String password,
    required String avatarId,
    String? name,
    bool wantsNewsletter = false,
  }) async {
    _requireCloudForAuth();
    final cleanEmail = email.trim().toLowerCase();
    final displayName = (name != null && name.trim().isNotEmpty) ? name.trim() : cleanEmail.split('@').first;

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        emailRedirectTo: 'https://pomosprint.app/confirmed.html',
        data: {
          'name': displayName,
          // Yalnızca varsayılan (ücretsiz) avatarlar kayıtta seçilebilir;
          // sunucu (handle_new_user) diğerlerini avatar_16_basic'e çeker.
          'avatar_id': AvatarCharacter.isFreeAvatarId(avatarId) ? avatarId : kDefaultAvatarId,
          'newsletter': wantsNewsletter,
        },
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
    _requireCloudForAuth();
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (response.user == null) return null;
    return _loadUserAfterSignIn();
  }

  /// Google ile giriş. Kullanıcı vazgeçerse null döner.
  Future<UserModel?> signInWithGoogle() async {
    _requireCloudForAuth();

    GoogleSignInAccount? googleUser;
    String? idToken;
    String? accessToken;
    try {
      // Önce sessiz oturum: kullanıcı daha önce izin verdiyse hesap seçici
      // gösterilmez. Yalnızca null dönerse interaktif signIn'e düşülür.
      googleUser = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      idToken = googleAuth.idToken;
      accessToken = googleAuth.accessToken;
    } on PlatformException catch (e) {
      if (e.code == GoogleSignIn.kSignInCanceledError) return null;
      if (e.code == GoogleSignIn.kNetworkError) throw AuthFailure(AuthErrorCode.network, e);
      throw AuthFailure(AuthErrorCode.googleSignInFailed, e);
    }
    if (idToken == null) throw const AuthFailure(AuthErrorCode.googleSignInFailed);

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    if (response.user == null) throw const AuthFailure(AuthErrorCode.googleSignInFailed);

    await _cleanupDuplicateIdentity();
    return _loadUserAfterSignIn();
  }

  /// Apple ile giriş. Kullanıcı vazgeçerse null döner.
  Future<UserModel?> signInWithApple() async {
    _requireCloudForAuth();

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

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    if (response.user == null) throw const AuthFailure(AuthErrorCode.appleSignInFailed);

    await _cleanupDuplicateIdentity();
    // Apple adı yalnızca ilk girişte verir; profil oluşturulurken kullanılır.
    return _loadUserAfterSignIn(nameHint: credential.givenName);
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
    _requireCloudForAuth();
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
      emailRedirectTo: 'https://pomosprint.app/confirmed.html',
    );
  }

  // Supabase, hesap keşfini önlemek için e-posta kayıtlı olsun ya da olmasın
  // aynı şekilde davranır; başarılı dönüş e-postanın var olduğunu göstermez.
  Future<void> resetPassword(String email) async {
    _requireCloudForAuth();
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: 'https://pomosprint.app/reset-password.html',
    );
  }

  /// Hesabı sunucudan siler; ardından bu kullanıcıya ait tüm yerel veriyi
  /// (bekleyen seanslar dahil) temizler ve oturumu kapatır.
  Future<void> deleteUserAccount() async {
    final authUser = _requireAuthUser();
    final email = authUser.email ?? currentUser.value?.email;
    await _guard(() => _client.rpc('delete_own_account'));
    await _queue.clearUser(authUser.id, email: email);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dailyGoalMigratedKey(authUser.id));
      if (email != null && email.isNotEmpty) {
        await prefs.remove('league_info_shown_$email');
      }
    } catch (e) {
      debugPrint('[AUTH] Silinen hesabın yerel verisi temizlenemedi: $e');
    }
    await signOutFully();
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

    final results = await Future.wait<Object?>([
      _ensureOwnProfile(authUser, nameHint: nameHint),
      _fetchUnlockedAvatars(authUser.id),
    ]).timeout(_requestTimeout);
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
  static String _initialProfileName(User authUser, String? nameHint) {
    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final provider = authUser.appMetadata['provider']?.toString() ?? 'email';
    String? candidate;
    if (provider == 'email') {
      candidate = metadata['name']?.toString();
    } else {
      final full = (metadata['full_name'] ?? metadata['name'])?.toString().trim();
      candidate = (nameHint != null && nameHint.trim().isNotEmpty)
          ? nameHint
          : (metadata['given_name']?.toString() ?? full?.split(RegExp(r'\s+')).first);
    }
    var name = candidate?.trim() ?? '';
    if (name.isEmpty) name = (authUser.email ?? '').split('@').first;
    if (name.isEmpty) name = 'Pomo';
    return name.length > _nameMaxLength ? name.substring(0, _nameMaxLength) : name;
  }

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
    await _persistUser(user);
  }

  void _publishUser(UserModel? user) {
    currentUser.value = user;
    unawaited(_persistUser(user));
  }

  Future<void> _persistUser(UserModel? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
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

  /// Profil adını günceller (2..30 karakter). Başarıda [currentUser] güncellenir.
  Future<void> updateUserName(String newName) async {
    final cleanName = newName.trim();
    if (cleanName.length < _nameMinLength) throw const ServiceException(ServiceErrorCode.nameTooShort);
    if (cleanName.length > _nameMaxLength) throw const ServiceException(ServiceErrorCode.nameTooLong);
    final uid = _requireUserId();
    final rows = await _guard(
      () => _client.from('profiles').update({'name': cleanName}).eq('id', uid).select('name'),
    );
    if (rows.isEmpty) throw const ServiceException(ServiceErrorCode.notFound);
    final user = currentUser.value;
    if (user != null) _publishUser(user.copyWith(name: rows.first['name']?.toString() ?? cleanName));
  }

  /// Günlük hedefi (dakika) profile yazar; tek kaynak profiles.daily_goal_minutes.
  /// Aralık sunucudaki CHECK ile aynı: 5..1440.
  Future<void> updateDailyGoalMinutes(int minutes) async {
    if (minutes < _dailyGoalMin || minutes > _dailyGoalMax) throw const ServiceException(ServiceErrorCode.invalidInput);
    final uid = _requireUserId();
    final rows = await _guard(
      () => _client.from('profiles').update({'daily_goal_minutes': minutes}).eq('id', uid).select('daily_goal_minutes'),
    );
    if (rows.isEmpty) throw const ServiceException(ServiceErrorCode.notFound);
    final user = currentUser.value;
    if (user != null) _publishUser(user.copyWith(dailyGoalMinutes: minutes));
  }

  static String _dailyGoalMigratedKey(String userId) => 'daily_goal_migrated_$userId';

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

  /// Onboarding'i tek adımda tamamlar: profil satırını garanti eder,
  /// kategorileri oluşturur, ardından profil alanlarını yazar (kategoriler
  /// profile yabancı anahtarla bağlı olduğu için sıra önemli). Güncelleme
  /// hiçbir satıra uymazsa hata fırlatır.
  Future<void> completeOnboarding({
    int? birthYear,
    String? userSegment,
    required int dailyGoalMinutes,
    List<Map<String, dynamic>> categories = const [],
  }) async {
    if (dailyGoalMinutes < _dailyGoalMin || dailyGoalMinutes > _dailyGoalMax) {
      throw const ServiceException(ServiceErrorCode.invalidInput);
    }
    // İsteğe bağlı alan: sunucunun CHECK aralığı dışındaysa yazılmaz.
    final validBirthYear =
        (birthYear != null && birthYear >= _birthYearMin && birthYear <= _birthYearMax) ? birthYear : null;
    final authUser = _requireAuthUser();
    await _guard(() => _ensureOwnProfile(authUser));
    if (categories.isNotEmpty) await setupOnboardingCategories(categories);
    final completedAt = DateTime.now();
    final rows = await _guard(() => _client
        .from('profiles')
        .update({
          'birth_year': validBirthYear,
          'user_segment': userSegment,
          'daily_goal_minutes': dailyGoalMinutes,
          'onboarding_completed_at': completedAt.toUtc().toIso8601String(),
        })
        .eq('id', authUser.id)
        .select('id'));
    if (rows.isEmpty) throw const ServiceException(ServiceErrorCode.notFound);
    final user = currentUser.value;
    if (user != null) {
      _publishUser(user.copyWith(
        birthYear: validBirthYear,
        userSegment: userSegment,
        dailyGoalMinutes: dailyGoalMinutes,
        onboardingCompletedAt: completedAt,
      ));
    }
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
    try {
      final row = await _client
          .from('profiles')
          .select('total_minutes, lifetime_points, coins, current_streak, longest_streak, last_study_date')
          .eq('id', uid)
          .maybeSingle()
          .timeout(_requestTimeout);
      final latest = currentUser.value;
      if (row == null || latest == null) return;
      final fresh = UserModel.fromMap({...latest.toMap(), ...row});
      _publishUser(fresh);
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

  /// Bekleyen seansları göndermeyi dener; kalan seans sayısını döndürür.
  Future<int> syncPendingSessions() async {
    final owner = _queueOwner();
    final uid = owner.userId;
    if (uid == null) return 0;
    if (owner.email != null) await _queue.adoptLegacyQueue(userId: uid, email: owner.email!);
    if (!_isCloudActive || _client.auth.currentUser?.id != uid) return _queue.pendingCount(uid);
    final report = await _queue.sync(uid);
    if (report.sent > 0) _notifyStatsChanged();
    return report.remaining;
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
      final day = studyDayKey(studyDayOf(session.startedAt.toLocal()));
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

  // Puan hesabında kullanılan sabitleri sunucudan okur (bkz. get_points_config
  // RPC'si). Bu değerler complete_study_session RPC'sinin gövdesindeki
  // sabitlerle aynı tutulmalıdır; UI tarafında asla hardcode edilmez.
  Future<Map<String, dynamic>> getPointsConfig() async {
    if (_isCloudActive) {
      try {
        final response = await _client.rpc('get_points_config').timeout(_requestTimeout);
        if (response is Map) return Map<String, dynamic>.from(response);
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
    _requireUserId();
    final response = await _guard(() => _client.rpc('purchase_avatar', params: {'p_avatar_id': avatarId}));
    if (response is! num) throw const ServiceException(ServiceErrorCode.server);
    final newCoins = response.toInt();
    final user = currentUser.value;
    if (user != null) {
      _publishUser(user.copyWith(
        coins: newCoins,
        unlockedAvatars: {...user.unlockedAvatars, avatarId}.toList(),
      ));
    }
    return newCoins;
  }

  /// Avatarı kuşanır; [currentUser] güncellenir. Sahip olunmayan avatar için
  /// sunucu reddeder ve [ServiceException] (avatarLocked) fırlatılır.
  Future<void> setEquippedAvatar(String avatarId) async {
    _requireUserId();
    await _guard(() => _client.rpc('set_equipped_avatar', params: {'p_avatar_id': avatarId}));
    final user = currentUser.value;
    if (user != null) _publishUser(user.copyWith(avatarId: avatarId));
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
      return query.order('sort_order', ascending: true);
    });
    return rows.map(CourseCategory.fromServerRow).toList();
  }

  /// Bulutta hiç aktif kategori yoksa yerel listeyi (yoksa varsayılanları)
  /// sunucuda oluşturur; kimlikleri sunucu üretir. Güncel bulut listesini
  /// döndürür. Yer tutucu kategorilerden kurtulmanın tek yolu budur.
  Future<List<CourseCategory>> ensureServerCategories(List<CourseCategory> localFallback) async {
    final active = await fetchUserCategories();
    if (active.isNotEmpty) return active;
    final source = localFallback.where((c) => !c.isArchived).toList();
    final seed = (source.isNotEmpty ? source : CourseCategory.initialCategories()).map((c) => c.toServerJson()).toList();
    await setupOnboardingCategories(seed);
    return fetchUserCategories();
  }

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
  Future<void> createDefaultCategories() => _service.setupOnboardingCategories(
        [for (final c in CourseCategory.initialCategories()) c.toServerJson()],
      );
}
