import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../models/study_session.dart';
import '../models/category_model.dart';
import 'language_service.dart';

class SupabaseService {

  Future<UserModel> _buildUserModel(Map<String, dynamic> profileData, String email, String userId) async {
    List<String> unlockedAvatars = [];
    try {
      final client = Supabase.instance.client;
      final unlockRes = await client.from('avatar_unlocks').select('avatar_id').eq('user_id', userId);
      unlockedAvatars = (unlockRes as List<dynamic>).map((e) => e['avatar_id'].toString()).toList();
    } catch (_) {}
    
    profileData['unlocked_avatars'] = unlockedAvatars;
    
    return UserModel.fromMap({
      ...profileData,
      'email': profileData['email'] ?? email,
    });
  }

  static final SupabaseService instance = SupabaseService._init();

  bool _isCloudActive = false;

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

  SupabaseService._init();

  /// Kullanıcının profil satırını okur; satır GERÇEKTEN yoksa oluşturur.
  ///
  /// Okuma ağ/sunucu hatasıyla başarısız olursa profil oluşturulmaz, hata
  /// yukarı fırlatılır. Eskiden okuma hatası "profil yok" gibi yorumlanıp
  /// `total_minutes: 0, lifetime_points: 0` içeren bir upsert yapılıyordu;
  /// bu da anlık bir bağlantı kopmasında mevcut kullanıcının tüm
  /// istatistiklerini sıfırlayabiliyordu. Oluşturma artık
  /// `ignoreDuplicates` ile yapılıyor: satır o arada oluşmuşsa dokunulmaz,
  /// istatistik kolonları hiç gönderilmez (veritabanı varsayılanı 0).
  Future<Map<String, dynamic>?> _fetchOrCreateProfile({
    required SupabaseClient client,
    required String userId,
    required String email,
    required String name,
    required String avatarId,
  }) async {
    final existing = await client
        .from('profiles')
        .select(ownProfileColumns)
        .eq('id', userId)
        .maybeSingle();
    if (existing != null) return existing;

    await client.from('profiles').upsert({
      'id': userId,
      'email': email,
      'name': name,
      'avatar_id': avatarId,
    }, onConflict: 'id', ignoreDuplicates: true);

    return await client
        .from('profiles')
        .select(ownProfileColumns)
        .eq('id', userId)
        .maybeSingle();
  }

  bool get isCloudActive => _isCloudActive;

  // Tek bir GoogleSignIn örneği: her çağrıda yeniden oluşturmak,
  // paketin sessiz oturum önbelleğini (signInSilently) sıfırlıyordu.
  static const String _googleWebClientId = '722417205043-d7t27n7usp9nrfeuh8o97fald6a5v9ku.apps.googleusercontent.com';
  static const String _googleIosClientId = '722417205043-luq0knjdncu1aitpg9udbfgmo2qdtced.apps.googleusercontent.com';
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleWebClientId,
    clientId: _googleIosClientId,
  );

  // Hem Supabase oturumunu hem de Google'ın cihazdaki native oturum
  // önbelleğini kapatır. Apple ile giriş yapmış bir kullanıcıda
  // GoogleSignIn().signOut() hata verebilir (hiç Google oturumu yok) —
  // bu beklenen bir durum, try/catch ile yutulur.
  Future<void> signOutFully() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AUTH] GoogleSignIn signOut hatası (Apple kullanıcısı için normal): $e');
    }
    try {
      await Supabase.instance.client.auth.signOut();
      debugPrint('[AUTH] Supabase signOut başarılı');
    } catch (e) {
      debugPrint('[AUTH] Supabase signOut hatası: $e');
    }
  }

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
      if (kDebugMode) {
        print('ℹ️ .env okuma notu: $e. Yerel SQLite aktif.');
      }
    }

    if (url.isEmpty ||
        anonKey.isEmpty ||
        url.contains('YOUR_PROJECT_ID') ||
        anonKey.contains('YOUR_SUPABASE_ANON_KEY')) {
      if (kDebugMode) {
        print('ℹ️ Supabase Cloud bilgileri henüz ayarlanmadı. Yerel SQLite veritabanı aktif.');
      }
      _isCloudActive = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
      );
      _isCloudActive = true;
      if (kDebugMode) {
        print('⚡ Supabase Cloud Veritabanı başarıyla bağlandı! ($url)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Supabase bağlantı hatası: $e. SQLite aktif.');
      }
      _isCloudActive = false;
    }
  }

  // Register User (Strictly Supabase Cloud Auth)
  Future<AuthResponse?> registerUser({
    required String email,
    required String password,
    required String avatarId,
    String? name,
    bool wantsNewsletter = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final displayName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : cleanEmail.split('@').first;

    if (!_isCloudActive) {
      throw AuthException(LanguageService.instance.isTurkish
          ? 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.'
          : 'Unable to connect to the cloud server. Please check your internet connection.');
    }

    final client = Supabase.instance.client;

    try {
      final response = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        emailRedirectTo: 'https://pomosprint.app/confirmed.html',
        data: {
          'name': displayName,
          'avatar_id': avatarId,
          'newsletter': wantsNewsletter,
        },
      );

      // Check if user already exists (GoTrue returns empty identities for security instead of throwing)
      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        throw AuthException(LanguageService.instance.isTurkish
            ? 'Bu e-posta adresi ile zaten kayıtlı bir hesap var. Google ile giriş yapmayı deneyebilir veya şifrenizi sıfırlayabilirsiniz.'
            : 'An account is already registered with this email address. You can try signing in with Google or reset your password.');
      }

      if (kDebugMode) {
        print('✅ Supabase Auth SignUp tamamlandı (User: ${response.user?.id}, Session: ${response.session != null})');
      }

      return response;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final code = (e.code ?? '').toLowerCase();

      if (msg.contains('already registered') ||
          msg.contains('already in use') ||
          code == 'user_already_exists') {
        throw AuthException(LanguageService.instance.isTurkish
            ? 'Bu e-posta adresi ile zaten kayıtlı bir hesap var. Lütfen giriş yapın.'
            : 'An account is already registered with this email address. Please sign in.');
      }
      rethrow;
    }
  }

  // Login User (Strictly Supabase Cloud Auth)
  Future<UserModel?> loginUser(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!_isCloudActive) {
      throw AuthException(LanguageService.instance.isTurkish
          ? 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.'
          : 'Unable to connect to the cloud server. Please check your internet connection.');
    }

    final client = Supabase.instance.client;

    final response = await client.auth.signInWithPassword(
      email: cleanEmail,
      password: password,
    );

    final user = response.user;
    if (user != null) {
      Map<String, dynamic>? profileData;
      try {
        profileData = await _fetchOrCreateProfile(
          client: client,
          userId: user.id,
          email: user.email ?? cleanEmail,
          name: user.userMetadata?['name'] ?? cleanEmail.split('@').first,
          avatarId: user.userMetadata?['avatar_id'] ?? 'avatar_1_gamer',
        );
      } catch (e) {
        if (kDebugMode) print('Profile fetch/create error in login: $e');
        throw AuthException('Profil yüklenirken bir hata oluştu: $e');
      }

      return await _buildUserModel(profileData ?? {}, user.email ?? cleanEmail, user.id);
    }
    return null;
  }



  // Google Sign-In
  Future<UserModel?> signInWithGoogle() async {
    if (!_isCloudActive) {
      throw AuthException(LanguageService.instance.isTurkish
          ? 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.'
          : 'Unable to connect to the cloud server. Please check your internet connection.');
    }

    try {
      // Önce sessiz oturum denenir (kullanıcı daha önce izin verdiyse
      // Google hesap seçici/onay ekranı hiç gösterilmez, yeni bir "erişim
      // verildi" bildirimi de gitmez). Sadece null dönerse interaktif
      // signIn()'e düşülür.
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        debugPrint('[AUTH] GoogleSignIn: signInSilently başarılı (${googleUser.email})');
      } else {
        debugPrint('[AUTH] GoogleSignIn: signInSilently null döndü, interaktif signIn deneniyor');
        googleUser = await _googleSignIn.signIn();
      }
      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw AuthException('No ID Token found.');
      }

      final client = Supabase.instance.client;
      debugPrint('[AUTH] signInWithIdToken çağrılıyor (google, email=${googleUser.email})');
      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) {
        debugPrint('[AUTH] signInWithIdToken(google): response.user null döndü (auth başarısız)');
        return null;
      }

      debugPrint('[AUTH] signInWithIdToken(google) BAŞARILI (uid=${user.id}). Profil sağlama adımına geçiliyor — buradan sonraki hatalar artık girişi engellemeyecek.');

      // NOT: Buradan itibaren Supabase oturumu ZATEN kurulmuş ve kalıcı
      // durumda. Aşağıdaki profil sağlama adımlarından biri başarısız
      // olursa bile fırlatmıyoruz — aksi halde kullanıcı ekranda "takılı"
      // kalıyor, oysa oturumu aslında geçerli (uygulamayı kapatıp açınca
      // giriş yapmış görünmesinin sebebi buydu).
      final loginEmail = user.email ?? googleUser.email;
      try {
        await client.rpc('cleanup_unconfirmed_duplicate_identity', params: {
          'p_email': loginEmail,
        });
      } catch (e) {
        debugPrint('[AUTH] cleanup_unconfirmed_duplicate_identity hatası (yok sayılıyor): $e');
      }

      Map<String, dynamic>? profileData;
      try {
        profileData = await _fetchOrCreateProfile(
          client: client,
          userId: user.id,
          email: user.email ?? googleUser.email,
          name: user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Google User',
          avatarId: user.userMetadata?['avatar_id'] ?? 'avatar_1_gamer',
        );
      } catch (e) {
        debugPrint('[AUTH] Profil çekme/oluşturma hatası (yok sayılıyor, minimal profille devam edilecek): $e');
      }

      // profileData hâlâ null olabilir (upsert de başarısız olduysa) — bu
      // durumda dahi auth.users'daki bilgilerden minimal bir UserModel
      // döndürülür, kullanıcı asla "giriş yapıldı ama ekranda takılı kaldı"
      // durumuna düşmez. Eksik profil verisi bir sonraki splash/senkronda
      // tamamlanır.
      return await _buildUserModel(
        profileData ?? {'id': user.id, 'email': user.email ?? googleUser.email, 'name': user.userMetadata?['full_name'] ?? googleUser.email},
        user.email ?? googleUser.email,
        user.id,
      );
    } catch (e) {
      debugPrint('[AUTH] Google Sign-In hatası (auth adımından ÖNCE, gerçek bir hata): $e');
      throw AuthException(e.toString());
    }
  }

  // Apple Sign-In
  Future<UserModel?> signInWithApple() async {
    if (!_isCloudActive) {
      throw AuthException(LanguageService.instance.isTurkish
          ? 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.'
          : 'Unable to connect to the cloud server. Please check your internet connection.');
    }

    try {
      final client = Supabase.instance.client;
      final rawNonce = client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw AuthException('No ID Token found.');
      }

      debugPrint('[AUTH] signInWithIdToken çağrılıyor (apple)');
      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final user = response.user;
      if (user != null) {
        final loginEmail = user.email ?? 'apple_user_${user.id}@hidden.apple.com';
        try {
          await client.rpc('cleanup_unconfirmed_duplicate_identity', params: {
            'p_email': loginEmail,
          });
        } catch (e) {
          if (kDebugMode) print('cleanup_unconfirmed_duplicate_identity error: $e');
        }

        final firstName = credential.givenName ?? '';
        final lastName = credential.familyName ?? '';
        final fullName = (firstName.isEmpty && lastName.isEmpty)
            ? (user.email?.split('@').first ?? 'Apple User')
            : '$firstName $lastName'.trim();

        Map<String, dynamic>? profileData;
        try {
          profileData = await _fetchOrCreateProfile(
            client: client,
            userId: user.id,
            email: loginEmail,
            name: fullName,
            avatarId: user.userMetadata?['avatar_id'] ?? 'avatar_1_gamer',
          );
        } catch (e) {
          if (kDebugMode) print('Profile fetch/create error: $e');
          throw AuthException('Profil yüklenirken bir hata oluştu: $e');
        }

        return await _buildUserModel(profileData ?? {}, user.email ?? loginEmail, user.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Apple Sign-In Error: $e');
      throw AuthException(e.toString());
    }
  }

  // Get Leaderboard Ranking Users
  // Güvenlik: profiles tablosuna doğrudan erişim yerine SECURITY DEFINER
  // RPC kullanılır — böylece client'lar diğer kullanıcıların email/
  // birth_year gibi hassas sütunlarına asla erişemez, sadece güvenli
  // alt küme (isim, avatar, süre, puan, premium) döner.
  Future<List<Map<String, dynamic>>> getRankingUsers() async {
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        final List<dynamic> response = await client.rpc(
          'get_public_alltime_leaderboard',
          params: {'p_limit': 50},
        );
        return response.cast<Map<String, dynamic>>();
      } catch (e) {
        if (kDebugMode) print('Supabase getRankingUsers Error: $e');
      }
    }
    return [];
  }

  // Get Duolingo-style League Ranking
  Future<List<Map<String, dynamic>>> getLeagueRanking() async {
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid == null) return [];

        // get_my_league_ranking: oturum sahibinin ligini e-posta kolonları
        // olmadan döndürür. Sunucuya henüz uygulanmamışsa (PGRST202:
        // fonksiyon bulunamadı) eski uç noktaya düşülür.
        List<dynamic> response;
        try {
          response = await client.rpc('get_my_league_ranking');
        } on PostgrestException catch (e) {
          if (e.code != 'PGRST202') rethrow;
          response = await client.rpc(
            'get_league_ranking',
            params: {'p_user_id': uid},
          );
          for (final row in response) {
            (row as Map).remove('email');
          }
        }
        return response.cast<Map<String, dynamic>>();
      } catch (e) {
        if (kDebugMode) print('Supabase getLeagueRanking Error: $e');
      }
    }
    return [];
  }

  // Aylık sıralama listesi bir "lig odası" değildir (gerçek terfi/düşüş
  // taşıması yapılmaz), ama listedeki kişi sayısına göre aynı sunucu
  // kuralıyla (get_league_zones) hangi sıraların görsel olarak terfi/düşüş
  // bölgesinde sayılacağını hesaplar. Sayılar burada da hardcode edilmez.
  Future<Map<String, int>> getLeagueZones(int memberCount) async {
    if (_isCloudActive && memberCount > 0) {
      try {
        final client = Supabase.instance.client;
        final List<dynamic> response = await client.rpc(
          'get_league_zones',
          params: {'p_member_count': memberCount},
        );
        if (response.isNotEmpty) {
          final row = response.first as Map<String, dynamic>;
          return {
            'promotion_zone_end': row['promotion_zone_end'] as int? ?? 3,
            'demotion_zone_start': row['demotion_zone_start'] as int? ?? 999,
          };
        }
      } catch (e) {
        if (kDebugMode) print('Supabase getLeagueZones Error: $e');
      }
    }
    return {'promotion_zone_end': 3, 'demotion_zone_start': 999};
  }

  // Puan hesabında kullanılan sabitleri sunucudan okur (bkz. get_points_config
  // RPC'si). Bu değerler complete_study_session RPC'sinin gövdesindeki
  // sabitlerle aynı tutulmalıdır; UI tarafında asla hardcode edilmez.
  Future<Map<String, dynamic>> getPointsConfig() async {
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        final response = await client.rpc('get_points_config');
        return Map<String, dynamic>.from(response as Map);
      } catch (e) {
        if (kDebugMode) print('Supabase getPointsConfig Error: $e');
      }
    }
    return {};
  }

  // Resend Email Confirmation Link
  Future<void> resendConfirmationEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (_isCloudActive) {
      final client = Supabase.instance.client;
      await client.auth.resend(
        type: OtpType.signup,
        email: cleanEmail,
        emailRedirectTo: 'https://pomosprint.app/confirmed.html',
      );
      if (kDebugMode) {
        print('📬 Onay e-postası tekrar gönderildi: $cleanEmail');
      }
    }
  }

  // Şifre sıfırlama e-postası gönderir. Supabase, hesap keşfini (enumeration)
  // önlemek için e-posta kayıtlı olsun ya da olmasın aynı şekilde davranır —
  // yani bu çağrı "başarılı" dönse bile e-postanın gerçekten var olduğu
  // anlamına gelmez, bu Supabase'in kasıtlı güvenlik tasarımıdır.
  Future<void> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (_isCloudActive) {
      final client = Supabase.instance.client;
      await client.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: 'https://pomosprint.app/reset-password.html',
      );
      if (kDebugMode) {
        print('🔑 Şifre sıfırlama e-postası gönderildi: $cleanEmail');
      }
    }
  }



  // Update User Profile Name
  Future<void> updateUserName(String email, String newName) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = newName.trim();

    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('profiles')
            .update({'name': cleanName})
            .eq('email', cleanEmail);
        if (kDebugMode) {
          print('✅ Kullanıcı adı Supabase veritabanında başarıyla güncellendi ($cleanEmail -> $cleanName)');
        }
      } catch (e) {
        if (kDebugMode) print('Supabase Update Name Error: $e');
      }
    }
  }

  // Delete User Account
  Future<bool> deleteUserAccount(String userEmailOrId) async {
    final clean = userEmailOrId.trim().toLowerCase();

    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        
        // Call the secure RPC to delete the account from auth.users (which will cascade to profiles, study_sessions, etc.)
        await client.rpc('delete_own_account');
        
        await client.auth.signOut();
        if (kDebugMode) {
          print('✅ Kullanıcı hesabı Supabase veritabanından başarıyla silindi ($clean)');
        }
      } catch (e) {
        if (kDebugMode) print('Supabase Delete User Error: $e');
        // Let the UI know if there was an error
        rethrow;
      }
    }

    return true;
  }

  /// NEW: Server-side point calculation. Returns a result map with
  /// base_points, bonus_points, total_points, streak, bonus_pct, duplicate.
  Future<Map<String, dynamic>?> completeStudySession({
    required String clientUuid,
    required String categoryId,
    required int durationMinutes,
    required bool wasPaused,
    required int isVerified,
    required DateTime startedAt,
  }) async {
    if (!_isCloudActive) return null;
    final client = Supabase.instance.client;
    try {
      final result = await client.rpc('complete_study_session', params: {
        'p_client_uuid': clientUuid,
        'p_category_id': categoryId,
        'p_duration_minutes': durationMinutes,
        'p_was_paused': wasPaused,
        'p_is_verified': isVerified,
        'p_started_at': startedAt.toUtc().toIso8601String(),
      });
      if (kDebugMode) {
        print('✅ complete_study_session: $result');
      }
      await _broadcastStatsUpdated();
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ complete_study_session error: $e');
      rethrow;
    }
  }

  // ---- BEKLEYEN (SENKRONİZE EDİLMEMİŞ) SEANSLAR — Offline Dayanıklılık ----
  // Ağ yokken tamamlanan seanslar cihazda saklanır, bağlantı gelince otomatik gönderilir.

  // Kuyruk kullanıcı ID'sine göre saklanır (e-posta değişebilir). Eski
  // sürümler e-postaya göre sakladığı için, eski anahtardaki kayıtlar ilk
  // erişimde yeni anahtara taşınır.
  String _legacyPendingSessionsKey(String userEmail) => 'pending_sessions_${userEmail.trim().toLowerCase()}';

  Future<String> _pendingSessionsKey(SharedPreferences prefs, String userEmail) async {
    final uid = _isCloudActive ? Supabase.instance.client.auth.currentUser?.id : null;
    final legacyKey = _legacyPendingSessionsKey(userEmail);
    if (uid == null) return legacyKey;

    final key = 'pending_sessions_uid_$uid';
    final legacyRaw = prefs.getString(legacyKey);
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      final merged = [..._decodeSessions(prefs.getString(key)), ..._decodeSessions(legacyRaw)];
      await prefs.setString(key, jsonEncode(merged));
      await prefs.remove(legacyKey);
    }
    return key;
  }

  List<Map<String, dynamic>> _decodeSessions(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSessions(String userEmail) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeSessions(prefs.getString(await _pendingSessionsKey(prefs, userEmail)));
  }

  Future<void> _savePendingSessions(String userEmail, List<Map<String, dynamic>> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _pendingSessionsKey(prefs, userEmail), jsonEncode(sessions));
  }

  /// Sunucunun seansı KALICI olarak reddettiğini (tekrar denemenin anlamı
  /// olmadığını) gösteren hatalar: RPC içindeki RAISE EXCEPTION (P0001),
  /// veri/kısıt hataları (22xxx, 23xxx). Ağ hataları, zaman aşımları ve
  /// süresi dolmuş oturum (JWT) gibi durumlar geçicidir; seans kuyrukta
  /// kalıp sonra yeniden denenir.
  static bool isPermanentSessionError(Object e) {
    if (e is! PostgrestException) return false;
    final code = e.code ?? '';
    return code == 'P0001' || code.startsWith('22') || code.startsWith('23');
  }

  Future<void> addPendingSession({
    required String userEmail,
    required String categoryId,
    required String categoryName,
    required int minutes,
    required bool wasPaused,
    required int isVerified,
    required String startedAt,
    required String clientUuid,
  }) async {
    final sessions = await getPendingSessions(userEmail);
    sessions.add({
      'category_id': categoryId,
      'category_name': categoryName,
      'minutes': minutes,
      'was_paused': wasPaused,
      'is_verified': isVerified,
      'started_at': startedAt,
      'client_uuid': clientUuid,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _savePendingSessions(userEmail, sessions);
  }

  // syncPendingSessions birden fazla yerden (initState, connectivity listener,
  // login sonrası) eşzamanlı tetiklenebiliyor. Bu kilit olmadan iki çağrı aynı
  // bekleyen seansı okuyup İKİSİ DE başarıyla gönderebilir (çift kayıt riski).
  bool _isSyncingPending = false;

  /// Bekleyen tüm seansları buluta göndermeyi dener.
  /// Başarılı olanları ve sunucunun kalıcı olarak reddettiklerini listeden
  /// çıkarır; yalnızca geçici hatayla gönderilemeyenler kalır. Kalan seans
  /// sayısını döndürür.
  Future<int> syncPendingSessions(String userEmail) async {
    if (!_isCloudActive) return (await getPendingSessions(userEmail)).length;
    if (_isSyncingPending) {
      // Zaten devam eden bir senkron var; onun sonucunu beklemek yerine
      // güncel (o an diskteki) bekleyen sayıyı döndür.
      return (await getPendingSessions(userEmail)).length;
    }
    _isSyncingPending = true;
    try {
      final sessions = await getPendingSessions(userEmail);
      if (sessions.isEmpty) return 0;

      // Eski sürümlerden kalan, kategori ID'si veya başlangıç zamanı
      // olmayan kayıtlar sunucu tarafından asla kabul edilemez (eskiden
      // sahte bir kategori ID'siyle sonsuza kadar yeniden deneniyordu).
      // Sıralı gönderim, sunucudaki çakışma kontrolünün doğru çalışması
      // için önemli.
      final valid = sessions
          .where((s) => s['category_id'] is String && s['started_at'] is String && s['minutes'] is int)
          .toList()
        ..sort((a, b) => (a['started_at'] as String).compareTo(b['started_at'] as String));

      // Yer tutucu (UUID olmayan) kategoriyle tamamlanmış seansları, aynı
      // isimli bulut kategorisine eşle; eşleşme yoksa sunucu zaten
      // reddedeceği için bırak.
      if (valid.any((s) => !isServerCategoryId(s['category_id'] as String))) {
        try {
          final cloudCats = await fetchUserCategories(includeArchived: true);
          final byName = {for (final c in cloudCats) c.name.trim().toLowerCase(): c.id};
          for (final s in valid) {
            if (isServerCategoryId(s['category_id'] as String)) continue;
            final name = (s['category_name'] as String? ?? '').trim().toLowerCase();
            final mapped = byName[name];
            if (mapped != null) s['category_id'] = mapped;
          }
        } catch (e) {
          // Kategoriler alınamadıysa ağ hâlâ yok demektir; hepsini beklet.
          if (kDebugMode) print('⏳ Kategoriler alınamadı, senkron ertelendi: $e');
          return sessions.length;
        }
        valid.removeWhere((s) => !isServerCategoryId(s['category_id'] as String));
      }

      final remaining = <Map<String, dynamic>>[];
      for (final session in valid) {
        try {
          final result = await completeStudySession(
            clientUuid: session['client_uuid'] as String? ?? const Uuid().v4(),
            categoryId: session['category_id'] as String,
            durationMinutes: session['minutes'] as int,
            wasPaused: session['was_paused'] as bool? ?? false,
            isVerified: session['is_verified'] as int? ?? 0,
            startedAt: DateTime.parse(session['started_at'] as String),
          );
          if (result?['error'] != null) {
            debugPrint('⚠️ Bekleyen seans sunucu tarafından reddedildi: ${result?['error']}');
          }
        } catch (e) {
          if (isPermanentSessionError(e)) {
            if (kDebugMode) print('⚠️ Bekleyen seans kalıcı olarak reddedildi, kuyruktan çıkarılıyor: $e');
          } else {
            if (kDebugMode) print('⏳ Bekleyen seans senkronize edilemedi (ağ hâlâ yok olabilir): $e');
            remaining.add(session);
          }
        }
      }
      await _savePendingSessions(userEmail, remaining);
      return remaining.length;
    } finally {
      _isSyncingPending = false;
    }
  }

  // Fetch Study Sessions
  Future<List<StudySession>> fetchStudySessions() async {
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        final response = await client
            .from('study_sessions')
            .select('*, categories(name, color_hex)')
            .order('completed_at', ascending: false);
            
        return (response as List<dynamic>)
            .map((e) => StudySession.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        if (kDebugMode) print('❌ Supabase fetchStudySessions hatası: $e');
      }
    }
    return [];
  }

  // ---- SIRALAMA GERÇEK ZAMANLI GÜNCELLEME (Broadcast) ----
  RealtimeChannel? _rankingChannel;
  final List<void Function()> _rankingListeners = [];

  void _ensureRankingChannel() {
    if (!_isCloudActive || _rankingChannel != null) return;
    final client = Supabase.instance.client;
    _rankingChannel = client.channel('ranking_updates');
    _rankingChannel!.onBroadcast(event: 'stats_updated', callback: (_) {
      for (final listener in List.of(_rankingListeners)) {
        listener();
      }
    }).subscribe();
  }

  void addRankingListener(void Function() listener) {
    _ensureRankingChannel();
    _rankingListeners.add(listener);
  }

  void removeRankingListener(void Function() listener) {
    _rankingListeners.remove(listener);
  }

  void _notifyLocalListeners() {
    for (final listener in List.of(_rankingListeners)) {
      listener();
    }
  }

  Future<void> _broadcastStatsUpdated() async {
    // 1. Önce cihaz içindeki (yerel) sayfaları anında güncelle
    _notifyLocalListeners();

    // 2. Ardından diğer cihazlardaki kullanıcılar için buluta sinyal gönder
    if (!_isCloudActive) return;
    try {
      _ensureRankingChannel();
      await _rankingChannel!.sendBroadcastMessage(
        event: 'stats_updated',
        payload: {'at': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      if (kDebugMode) print('Ranking broadcast error: $e');
    }
  }

// ---- CANLI ODAKLANMA VE SOSYAL AKIŞ ----
  
  bool? _socialVisibleCache;

  /// Kullanıcının "sosyal listede görün" tercihini döndürür.
  Future<bool> getSocialVisibility() async {
    if (!_isCloudActive) return true;
    if (_socialVisibleCache != null) return _socialVisibleCache!;
    
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return true;

      // 1) Sunucudan değeri al
      final response = await client.from('profiles').select('show_in_social_feed').eq('id', userId).maybeSingle();
      
      // 2) Yereldeki eski ayar ile taşıma (Migration)
      final prefs = await SharedPreferences.getInstance();
      final hasMigrated = prefs.getBool('social_visibility_migrated') ?? false;

      if (!hasMigrated) {
        final localPref = prefs.getBool('social_visible');
        if (localPref != null && response != null && response['show_in_social_feed'] != localPref) {
           // Yereldeki ayar farklıysa sunucuya yaz
           await client.from('profiles').update({'show_in_social_feed': localPref}).eq('id', userId);
           _socialVisibleCache = localPref;
        } else {
           _socialVisibleCache = response != null ? response['show_in_social_feed'] as bool : true;
        }
        await prefs.setBool('social_visibility_migrated', true);
      } else {
        _socialVisibleCache = response != null ? response['show_in_social_feed'] as bool : true;
      }
      
      return _socialVisibleCache!;
    } catch (e) {
      if (kDebugMode) print('❌ getSocialVisibility error: $e');
      return true;
    }
  }

  Future<void> setSocialVisibility(bool value) async {
    _socialVisibleCache = value;
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('profiles').update({'show_in_social_feed': value}).eq('id', userId);
    } catch (e) {
      if (kDebugMode) print('❌ setSocialVisibility error: $e');
    }
  }

  Future<void> startStudySession({
    required int durationMinutes,
    required String categoryName,
  }) async {
    if (!_isCloudActive) return;
    if (!await getSocialVisibility()) return;
    try {
      await Supabase.instance.client.rpc('start_study_session', params: {
        'p_duration_minutes': durationMinutes,
        'p_category_name': categoryName,
      });
    } catch (e) {
      if (kDebugMode) print('❌ startStudySession error: $e');
    }
  }

  Future<void> cancelStudySession() async {
    if (!_isCloudActive) return;
    try {
      await Supabase.instance.client.rpc('cancel_study_session');
    } catch (e) {
      if (kDebugMode) print('❌ cancelStudySession error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLiveFriends() async {
    if (!_isCloudActive) return [];
    try {
      final response = await Supabase.instance.client.rpc('get_live_friends');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      if (kDebugMode) print('❌ getLiveFriends error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFriendsFeed({int limit = 50}) async {
    if (!_isCloudActive) return [];
    try {
      final response = await Supabase.instance.client.rpc('get_friends_feed', params: {
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      if (kDebugMode) print('❌ getFriendsFeed error: $e');
      return [];
    }
  }

// --- KATEGORI YONETIMI (Supabase public.categories) ---

  /// Kullanıcının tüm kategorilerini Supabase'den çeker.
  static final RegExp _uuidPattern =
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  /// Sunucuda gerçekten var olabilecek (UUID biçiminde) bir kategori ID'si mi?
  /// Yerel yer tutucu kategorilerin ID'leri ('1', '2', ...) bu kontrolü geçmez.
  static bool isServerCategoryId(String id) => _uuidPattern.hasMatch(id);

  /// Kullanıcının buluttaki kategorilerini döndürür.
  ///
  /// Ağ/sunucu hatasında hata FIRLATILIR; çağıran taraf yerel önbelleğe
  /// düşmelidir. (Eskiden hata durumunda sahte ID'li "başlangıç"
  /// kategorileri döndürülüyordu; bunlarla tamamlanan seanslar sunucuda
  /// asla kabul edilmiyordu.) Bulutta hiç kategori yoksa boş liste döner.
  Future<List<CourseCategory>> fetchUserCategories({bool includeArchived = false}) async {
    if (!_isCloudActive) return [];
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    var query = client
        .from('categories')
        .select('id, name, color_hex, icon_name, sort_order, is_archived')
        .eq('user_id', userId);
    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }
    final List<dynamic> rows = await query.order('sort_order', ascending: true);

    return rows.map((row) {
      String colorHex = (row['color_hex'] as String? ?? '#000000').toUpperCase();
      String hexStr = colorHex.startsWith('#') ? colorHex.substring(1) : colorHex;
      if (hexStr.length == 6) hexStr = 'FF$hexStr';
      final colorValue = int.tryParse(hexStr, radix: 16) ?? 0xFF000000;
      // Diyaloglar 6 haneli (#RRGGBB) renk bekliyor.
      final displayHex = '#${hexStr.substring(hexStr.length - 6)}';

      return CourseCategory(
        id: row['id'] as String,
        name: row['name'] as String,
        color: Color(colorValue),
        icon: const IconData(0xe112, fontFamily: 'MaterialIcons'),
        isArchived: row['is_archived'] as bool? ?? false,
        colorHex: displayHex,
        iconName: row['icon_name'] as String? ?? 'book',
      );
    }).toList();
  }

  static String _colorToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  /// Yeni bir kategori ekler. Sunucudaki `create_category` RPC'si
  /// kullanılır: kategori limiti (ücretsiz 8 / Premium 15) ve aynı isim
  /// kontrolü sunucuda uygulanır, ID'yi sunucu üretir. Limit gibi bir
  /// nedenle reddedilirse hata fırlatılır.
  Future<CourseCategory?> insertCategory(CourseCategory cat) async {
    if (!_isCloudActive) return null;
    final newId = await createCategory(cat.name, _colorToHex(cat.color), cat.iconName);
    if (newId == null) return null;
    return CourseCategory(
      id: newId,
      name: cat.name,
      color: cat.color,
      icon: cat.icon,
      colorHex: _colorToHex(cat.color),
      iconName: cat.iconName,
    );
  }

  /// Bir kategoriyi siler (archived)
  Future<void> deleteCategory(String categoryId) async {
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('categories').update({
        'is_archived': true,
      }).eq('id', categoryId).eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) print('❌ deleteCategory error: $e');
    }
  }

  /// Yerel kategori listesini buluta tek istekte yazar. Yalnızca sunucuda
  /// geçerli olabilecek (UUID) ID'ler gönderilir; yer tutucular atlanır.
  /// Yalnızca bulutta hiç aktif kategori yokken çağrılmalıdır; aksi halde
  /// başka bir cihazda yapılan değişiklikleri eski yerel veriyle ezer.
  Future<List<CourseCategory>> upsertCategories(List<CourseCategory> cats) async {
    if (!_isCloudActive) return cats;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return cats;

      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < cats.length; i++) {
        final cat = cats[i];
        if (!isServerCategoryId(cat.id)) continue;
        rows.add({
          'id': cat.id,
          'user_id': userId,
          'name': cat.name,
          'color_hex': _colorToHex(cat.color),
          'icon_name': cat.iconName,
          'sort_order': i,
        });
      }
      if (rows.isNotEmpty) {
        await client.from('categories').upsert(rows);
      }
      return cats;
    } catch (e) {
      if (kDebugMode) print('❌ upsertCategories error: $e');
      return cats;
    }
  }

  // ---- ARKADAŞLAR ----

  /// Kullanıcının kendi arkadaşlık kodunu döndürür (profilde her zaman dolu olmalı).
  Future<String?> getMyFriendCode() async {
    if (!_isCloudActive) return null;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      final row = await client.from('profiles').select('friend_code').eq('id', userId).maybeSingle();
      return row?['friend_code'] as String?;
    } catch (e) {
      if (kDebugMode) print('❌ getMyFriendCode error: $e');
      return null;
    }
  }

  /// Girilen kodla bir kullanıcıyı arkadaş olarak ekler.
  Future<Map<String, dynamic>> addFriendByCode(String code) async {
    if (!_isCloudActive) {
      return {'success': false, 'message': 'İnternet bağlantısı yok.'};
    }
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('add_friend_by_code', params: {'p_code': code.trim()});
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': false, 'message': 'Beklenmeyen bir yanıt alındı.'};
    } catch (e) {
      if (kDebugMode) print('❌ addFriendByCode error: $e');
      return {'success': false, 'message': 'Arkadaş eklenirken bir hata oluştu: $e'};
    }
  }

  /// Kullanıcının arkadaş listesini (isim, avatar, puan, dakika) döndürür.
  Future<List<Map<String, dynamic>>> fetchFriends() async {
    if (!_isCloudActive) return [];
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final links = await client
          .from('friendships')
          .select('friend_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');
      final friendIds = (links as List<dynamic>).map((r) => r['friend_id'] as String).toList();
      if (friendIds.isEmpty) return [];

      final profiles = await client
          .from('profiles')
          .select('id, name, avatar_id, lifetime_points, total_minutes, is_premium')
          .inFilter('id', friendIds);
      return (profiles as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) print('❌ fetchFriends error: $e');
      return [];
    }
  }

  /// Kullanıcıya gelen, henüz onaylanmamış arkadaşlık isteklerini döndürür.
  Future<List<Map<String, dynamic>>> fetchPendingFriendRequests() async {
    if (!_isCloudActive) return [];
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final links = await client
          .from('friendships')
          .select('user_id')
          .eq('friend_id', userId)
          .eq('status', 'pending');
      final requesterIds = (links as List<dynamic>).map((r) => r['user_id'] as String).toList();
      if (requesterIds.isEmpty) return [];

      final profiles = await client
          .from('profiles')
          .select('id, name, avatar_id')
          .inFilter('id', requesterIds);
      return (profiles as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) print('❌ fetchPendingFriendRequests error: $e');
      return [];
    }
  }

  /// Gelen bir arkadaşlık isteğini kabul eder veya reddeder.
  Future<Map<String, dynamic>> respondToFriendRequest(String fromUserId, bool accept) async {
    if (!_isCloudActive) {
      return {'success': false, 'message': 'İnternet bağlantısı yok.'};
    }
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('respond_friend_request', params: {
        'p_from_user_id': fromUserId,
        'p_accept': accept,
      });
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': false, 'message': 'Beklenmeyen bir yanıt alındı.'};
    } catch (e) {
      if (kDebugMode) print('❌ respondToFriendRequest error: $e');
      return {'success': false, 'message': 'İstek yanıtlanırken bir hata oluştu: $e'};
    }
  }

  String parseAuthError(dynamic error) {
    final isTurkish = LanguageService.instance.isTurkish;
    final errStr = error.toString();
    final lower = errStr.toLowerCase();

    // 1. Weak password (AuthWeakPasswordException, password policy, characters, min length)
    if (error is AuthWeakPasswordException ||
        lower.contains('weakpassword') ||
        lower.contains('weak_password') ||
        lower.contains('password should contain') ||
        lower.contains('password is too weak') ||
        lower.contains('reasons: [characters]')) {
      return isTurkish
          ? 'Şifreniz çok zayıf. Şifreniz en az 1 küçük harf (a-z), 1 büyük harf (A-Z) ve 1 rakam (0-9) içermelidir.'
          : 'Password is too weak. It must contain at least 1 lowercase letter (a-z), 1 uppercase letter (A-Z), and 1 digit (0-9).';
    }

    if (lower.contains('at least 6 characters') || lower.contains('password should be at least')) {
      return isTurkish
          ? 'Şifreniz en az 6 karakter uzunluğunda olmalıdır.'
          : 'Password must be at least 6 characters long.';
    }

    // 2. Email Already Registered / In Use
    if (lower.contains('already_registered_resent')) {
      return isTurkish
          ? 'Bu e-posta adresi zaten kayıtlı! Doğrulama bağlantısı e-postanıza tekrar gönderildi.'
          : 'This email is already registered! A verification link has been resent to your inbox.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already in use') ||
        lower.contains('user_already_exists') ||
        lower.contains('user already registered')) {
      return isTurkish
          ? 'Bu e-posta adresi ile zaten kayıtlı bir hesap var. Lütfen giriş yapın.'
          : 'An account is already registered with this email address. Please sign in.';
    }

    // 3. Invalid Login Credentials
    // Not: Supabase, "şifre yanlış" ile "e-posta henüz onaylanmadı"
    // durumlarını hesap keşfini önlemek için AYNI genel hatayla döndürür,
    // bu yüzden mesaj her iki ihtimali de belirtiyor.
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid_grant')) {
      return isTurkish
          ? 'E-posta adresi veya şifre hatalı — ya da hesabınız henüz onaylanmamış olabilir. Şifrenizi kontrol edin; sorun devam ederse aşağıdan onay mailini tekrar gönderebilirsiniz.'
          : 'Invalid email or password — or your account may not be confirmed yet. Double-check your password; if the problem continues, you can resend the confirmation email below.';
    }

    // 4. Email Not Confirmed
    if (lower.contains('email not confirmed') || lower.contains('email_not_confirmed')) {
      return isTurkish
          ? 'E-posta adresiniz henüz doğrulanmamış. Lütfen gelen kutunuzdaki onay bağlantısına tıklayın.'
          : 'Your email address has not been confirmed yet. Please check your inbox for the confirmation link.';
    }

    // 5. Rate Limit / Too Many Requests
    if (lower.contains('rate limit') ||
        lower.contains('rate_limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('too many requests')) {
      return isTurkish
          ? 'Çok fazla deneme yapıldı. Lütfen birkaç dakika bekleyip tekrar deneyin.'
          : 'Too many requests. Please wait a few minutes before trying again.';
    }

    // 6. Network / Fetch / Server Failure
    if (lower.contains('authretryablefetchexception') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('nodename nor servname') ||
        lower.contains('network error')) {
      return isTurkish
          ? 'İnternet veya sunucu bağlantısı kurulamadı. Lütfen ağ bağlantınızı kontrol edin.'
          : 'Unable to connect to the server. Please check your internet connection.';
    }

    // 7. Invalid Email Format
    if (lower.contains('invalid email') || lower.contains('unable to validate email address')) {
      return isTurkish
          ? 'Lütfen geçerli bir e-posta adresi girin.'
          : 'Please enter a valid email address.';
    }

    // Fallback: Clean up any technical prefixes if unknown error occurs
    if (error is AuthException) {
      return error.message;
    }

    return errStr
        .replaceAll(RegExp(r'Auth[A-Za-z]+Exception:?\s*'), '')
        .replaceAll(RegExp(r'Exception:?\s*'), '')
        .replaceAll(RegExp(r'statusCode:?\s*\d+,\s*'), '')
        .trim();
  }

  // --- Avatar Economy ---
  Future<List<AvatarCharacter>> getAvatars() async {
    try {
      final client = Supabase.instance.client;
      final response = await client.from('avatars').select().eq('is_active', true).order('sort_order', ascending: true);
      
      final avatars = (response as List<dynamic>)
          .map((item) => AvatarCharacter.fromMap(item as Map<String, dynamic>))
          .toList();
      return avatars;
    } catch (e) {
      if (kDebugMode) print('❌ getAvatars error: $e');
      return [];
    }
  }

  Future<int?> purchaseAvatar(String avatarId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('purchase_avatar', params: {'p_avatar_id': avatarId});
      return response as int; // Returns new coins balance
    } catch (e) {
      if (kDebugMode) print('❌ purchaseAvatar error: $e');
      return null;
    }
  }

  Future<bool> setEquippedAvatar(String avatarId) async {
    try {
      final client = Supabase.instance.client;
      await client.rpc('set_equipped_avatar', params: {'p_avatar_id': avatarId});
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ setEquippedAvatar error: $e');
      return false;
    }
  }

  // ---- ONBOARDING VE KATEGORİ YÖNETİMİ ----

  Future<void> updateOnboardingCompleted() async {
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('profiles').update({
        'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      if (kDebugMode) print('❌ updateOnboardingCompleted hatası: $e');
    }
  }

  Future<String?> createCategory(String name, String colorHex, String iconName) async {
    if (!_isCloudActive) return null;
    try {
      final client = Supabase.instance.client;
      final result = await client.rpc('create_category', params: {
        'p_name': name,
        'p_color_hex': colorHex,
        'p_icon_name': iconName,
      });
      return result as String?;
    } catch (e) {
      if (kDebugMode) print('❌ createCategory hatası: $e');
      rethrow;
    }
  }

  Future<void> setupOnboardingCategories(List<Map<String, dynamic>> categories) async {
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      await client.rpc('setup_onboarding_categories', params: {
        'p_categories': categories,
      }).timeout(const Duration(seconds: 12));
    } catch (e) {
      if (kDebugMode) print('❌ setupOnboardingCategories hatası: $e');
      rethrow;
    }
  }

  Future<void> archiveCategory(String categoryId) async {
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      await client.from('categories').update({
        'is_archived': true,
      }).eq('id', categoryId);
    } catch (e) {
      if (kDebugMode) print('❌ archiveCategory hatası: $e');
      rethrow;
    }
  }
  
  Future<void> unarchiveCategory(String categoryId) async {
    if (!_isCloudActive) return;
    try {
      // Bu kontrol yalnızca kullanıcıya anlaşılır bir mesaj göstermek için;
      // asıl limit veritabanındaki categories trigger'ı ile zorunlu kılınır.
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      
      final activeCountResp = await client.from('categories').select('id').eq('user_id', userId).eq('is_archived', false);
      final activeCount = (activeCountResp as List).length;
      
      final profile = await client.from('profiles').select('is_premium').eq('id', userId).maybeSingle();
      final isPremium = profile != null ? (profile['is_premium'] as bool? ?? false) : false;
      
      if (activeCount >= (isPremium ? 15 : 8)) {
        throw Exception(isPremium ? 'Premium planda en fazla 15 kategori aktif olabilir.' : 'Ücretsiz planda en fazla 8 kategori aktif olabilir.');
      }
      
      await client.from('categories').update({
        'is_archived': false,
      }).eq('id', categoryId);
    } catch (e) {
      if (kDebugMode) print('❌ unarchiveCategory hatası: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(String categoryId, String name, String colorHex, String iconName) async {
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      await client.from('categories').update({
        'name': name,
        'color_hex': colorHex,
        'icon_name': iconName,
      }).eq('id', categoryId);
    } catch (e) {
      if (kDebugMode) print('❌ updateCategory hatası: $e');
      rethrow;
    }
  }

  Future<void> updateCategoryOrders(List<String> orderedIds) async {
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      await Future.wait([
        for (int i = 0; i < orderedIds.length; i++)
          client.from('categories').update({'sort_order': i}).eq('id', orderedIds[i]),
      ]);
    } catch (e) {
      if (kDebugMode) print('❌ updateCategoryOrders hatası: $e');
      rethrow;
    }
  }

  // ---- END ONBOARDING ----
}