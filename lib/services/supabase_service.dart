import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/study_session.dart';
import '../models/category_model.dart';
import 'language_service.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();

  bool _isCloudActive = false;

  SupabaseService._init();

  bool get isCloudActive => _isCloudActive;

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
        emailRedirectTo: 'https://pomosprint-verify.vercel.app',
        data: {
          'name': displayName,
          'avatar_id': avatarId,
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
        profileData = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
      } catch (e) {
        if (e is PostgrestException && e.code == 'PGRST116') {
          // Sadece 'satır bulunamadı' ise yeni kayıt oluştur.
          final name = user.userMetadata?['name'] ?? cleanEmail.split('@').first;
          final avatarId = user.userMetadata?['avatar_id'] ?? 'avatar_1_gamer';

          try {
            await client.from('profiles').upsert({
              'id': user.id,
              'email': user.email ?? cleanEmail,
              'name': name,
              'avatar_id': avatarId,
              'total_minutes': 0,
              'points': 0,
            });

            profileData = await client
                .from('profiles')
                .select()
                .eq('id', user.id)
                .single();
          } catch (upsertError) {
            if (kDebugMode) print('Profile upsert error in login: $upsertError');
            throw AuthException('Profil oluşturulurken bir hata oluştu: $upsertError');
          }
        } else {
          if (kDebugMode) print('Profile fetch error in login: $e');
          throw AuthException('Profil bilgileri alınırken bir hata oluştu (Ağ, RLS veya Timeout olabilir): $e');
        }
      }

      return UserModel(
        name: profileData?['name'] ?? 'Google User',
        email: profileData?['email'] ?? user.email ?? cleanEmail,
        password: password,
        avatarId: profileData?['avatar_id'] ?? 'avatar_1_gamer',
        totalMinutes: profileData?['total_minutes'] ?? 0,
        points: profileData?['points'] ?? 0,
      );
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
      final webClientId = '722417205043-d7t27n7usp9nrfeuh8o97fald6a5v9ku.apps.googleusercontent.com';
      final iosClientId = '722417205043-luq0knjdncu1aitpg9udbfgmo2qdtced.apps.googleusercontent.com';
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        clientId: iosClientId,
      );

      final googleUser = await googleSignIn.signIn();
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
      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user != null) {
        // BUG FIX: aynı e-postayla önce email/şifreyle kayıt olup hesabını
        // ONAYLAMAMIŞ kullanıcılar için Supabase'in "Automatic Linking"
        // mekanizması devreye giremez (hedef hesap onaysız) ve GoTrue bu
        // Google girişi için AYRI bir kullanıcı oluşturur. Google girişi
        // gerçek/onaylı bir e-postayı doğruladığına göre, aynı e-postaya ait
        // TERK EDİLMİŞ (hiç onaylanmamış, dolayısıyla gerçek veri barındırmayan)
        // diğer hesapları güvenle temizleriz — onaylı hesaplara asla dokunulmaz.
        final loginEmail = user.email ?? googleUser.email;
        try {
          await client.rpc('cleanup_unconfirmed_duplicate_identity', params: {
            'p_email': loginEmail,
          });
        } catch (e) {
          if (kDebugMode) print('cleanup_unconfirmed_duplicate_identity error: $e');
        }

        Map<String, dynamic>? profileData;
        try {
          profileData = await client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();
        } catch (e) {
          if (e is PostgrestException && e.code == 'PGRST116') {
            // Profil tablosunda kaydı yoksa (örneğin sadece profile tablosundan silinmişse veya trigger çalışmamışsa),
            // client tarafında GARANTİ bir satır oluşturuyoruz.
            final name = user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Google User';
            final avatarId = user.userMetadata?['avatar_id'] ?? 'avatar_1_gamer';
            
            try {
              await client.from('profiles').upsert({
                'id': user.id,
                'email': user.email ?? googleUser.email,
                'name': name,
                'avatar_id': avatarId,
                'total_minutes': 0,
                'points': 0,
              });
              
              profileData = await client
                  .from('profiles')
                  .select()
                  .eq('id', user.id)
                  .single();
            } catch (upsertError) {
              if (kDebugMode) print('Profile upsert error: $upsertError');
              throw AuthException('Profil oluşturulurken bir hata oluştu: $upsertError');
            }
          } else {
            if (kDebugMode) print('Profile fetch error: $e');
            // SESSİZCE yutmak yerine hatayı fırlatıyoruz ki kullanıcı uyarı görsün
            throw AuthException('Profil bilgileri alınırken bir hata oluştu (Ağ, RLS veya Timeout olabilir): $e');
          }
        }

        return UserModel(
          name: profileData?['name'] ?? 'Google User',
          email: profileData?['email'] ?? user.email ?? googleUser.email,
          password: '',
          avatarId: profileData?['avatar_id'] ?? 'avatar_1_gamer',
          totalMinutes: profileData?['total_minutes'] ?? 0,
          points: profileData?['points'] ?? 0,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Google Sign-In Error: $e');
      throw AuthException(e.toString());
    }
  }

  // Get Leaderboard Ranking Users
  Future<List<Map<String, dynamic>>> getRankingUsers() async {
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        final List<dynamic> response = await client
            .from('profiles')
            .select('name, email, avatar_id, total_minutes, points')
            .order('points', ascending: false)
            .limit(50);
        return response.cast<Map<String, dynamic>>();
      } catch (e) {
        if (kDebugMode) print('Supabase getRankingUsers Error: $e');
      }
    }
    return [];
  }

  // Resend Email Confirmation Link
  Future<void> resendConfirmationEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (_isCloudActive) {
      final client = Supabase.instance.client;
      await client.auth.resend(
        type: OtpType.signup,
        email: cleanEmail,
      );
      if (kDebugMode) {
        print('📬 Onay e-postası tekrar gönderildi: $cleanEmail');
      }
    }
  }

  // Update Avatar
  Future<void> updateUserAvatar(String userEmailOrId, String avatarId) async {
    final clean = userEmailOrId.trim().toLowerCase();
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('profiles')
            .update({'avatar_id': avatarId})
            .or('email.eq.$clean,name.eq.$clean');
        if (kDebugMode) {
          print('✅ Avatar Supabase veritabanında başarıyla güncellendi ($clean -> $avatarId)');
        }
      } catch (e) {
        if (kDebugMode) print('Supabase Update Avatar Error: $e');
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

  // Insert Study Session
  Future<void> insertStudySession({
    required String categoryName,
    required int minutes,
  }) async {
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;

        if (userId == null) {
          throw Exception('Kullanıcı oturumu bulunamadı.');
        }

        await client.from('study_sessions').insert({
          'user_id': userId,
          'category': categoryName,
          'duration_minutes': minutes,
        });

        if (kDebugMode) {
          print('✅ Supabase Study Session eklendi: $categoryName ($minutes dk)');
        }
      } catch (e) {
        if (kDebugMode) print('❌ Supabase insertStudySession hatası: $e');
        rethrow;
      }
    }
  }

  // Log Pomodoro Session (ATOMIC: study_sessions insert + profiles update
  // tek bir RPC/transaction içinde yapılır — biri yazılıp diğeri yazılmama
  // riski ortadan kalkar).
  Future<void> logPomodoroSession({
    required String categoryName,
    required int minutes,
    required int addedPoints,
  }) async {
    if (!_isCloudActive) return;
    final client = Supabase.instance.client;
    final localDateStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
    await client.rpc('log_pomodoro_session', params: {
      'p_category': categoryName,
      'p_minutes': minutes,
      'p_points': addedPoints,
      'p_local_date_str': localDateStr,
    });
    if (kDebugMode) {
      print('✅ log_pomodoro_session tamamlandı: $categoryName (+$minutes dk, +$addedPoints puan)');
    }
    await _broadcastStatsUpdated();
  }

  // ---- BEKLEYEN (SENKRONİZE EDİLMEMİŞ) SEANSLAR — Offline Dayanıklılık ----
  // Ağ yokken tamamlanan seanslar cihazda saklanır, bağlantı gelince otomatik gönderilir.

  String _pendingSessionsKey(String userEmail) => 'pending_sessions_${userEmail.trim().toLowerCase()}';

  Future<List<Map<String, dynamic>>> getPendingSessions(String userEmail) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingSessionsKey(userEmail));
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingSessions(String userEmail, List<Map<String, dynamic>> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingSessionsKey(userEmail), jsonEncode(sessions));
  }

  Future<void> addPendingSession({
    required String userEmail,
    required String categoryName,
    required int minutes,
    required int addedPoints,
  }) async {
    final sessions = await getPendingSessions(userEmail);
    sessions.add({
      'category': categoryName,
      'minutes': minutes,
      'points': addedPoints,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _savePendingSessions(userEmail, sessions);
  }

  // syncPendingSessions birden fazla yerden (initState, connectivity listener,
  // login sonrası) eşzamanlı tetiklenebiliyor. Bu kilit olmadan iki çağrı aynı
  // bekleyen seansı okuyup İKİSİ DE başarıyla gönderebilir (çift kayıt riski).
  bool _isSyncingPending = false;

  /// Bekleyen tüm seansları buluta göndermeyi dener.
  /// Başarılı olanları listeden çıkarır. Kalan (hâlâ senkronize edilememiş)
  /// seans sayısını döndürür.
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

      final remaining = <Map<String, dynamic>>[];
      for (final session in sessions) {
        try {
          await logPomodoroSession(
            categoryName: session['category'] as String,
            minutes: session['minutes'] as int,
            addedPoints: session['points'] as int,
          );
        } catch (e) {
          if (kDebugMode) print('⏳ Bekleyen seans senkronize edilemedi (ağ hâlâ yok olabilir): $e');
          remaining.add(session);
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
            .select()
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

  // Increment User Stats (Atomic RPC strictly via Supabase Cloud)
  // Güvenlik: hedef kullanıcı client'tan ALINMAZ; RPC sunucuda auth.uid()
  // oturumuna göre çalışır, yani yalnızca giriş yapan kullanıcının kaydını günceller.
  Future<void> updateUserStats({
    required int addedMinutes,
    required int addedPoints,
  }) async {
    if (_isCloudActive) {
      try {
        final client = Supabase.instance.client;
        final localDateStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
        await client.rpc('increment_user_stats', params: {
          'added_minutes': addedMinutes,
          'added_points': addedPoints,
          'local_date_str': localDateStr,
        });
        if (kDebugMode) {
          print('✅ Supabase RPC increment_user_stats tamamlandı (+ $addedMinutes dk, + $addedPoints puan)');
        }
        await _broadcastStatsUpdated();
      } catch (e) {
        if (kDebugMode) print('❌ Supabase updateUserStats hatası: $e');
        rethrow;
      }
    }
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


  // --- KATEGORI YONETIMI (Supabase user_categories tablosu) ---

  /// Kullanıcının tüm kategorilerini Supabase'den çeker.
  /// Eğer Supabase aktif değilse boş liste döndürür.
  Future<List<CourseCategory>> fetchUserCategories() async {
    if (!_isCloudActive) return [];
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('user_categories')
          .select()
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);

      return (response as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return CourseCategory(
          id: map['id'] as String,
          name: map['name'] as String,
          color: Color(map['color_value'] as int),
          icon: IconData(map['icon_code'] as int, fontFamily: 'MaterialIcons'),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('❌ fetchUserCategories error: $e');
      return [];
    }
  }

  /// Yeni bir kategori ekler ve oluşturulan Supabase kaydının UUID'sini döndürür.
  Future<CourseCategory?> insertCategory(CourseCategory cat) async {
    if (!_isCloudActive) return null;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await client.from('user_categories').insert({
        'user_id': userId,
        'name': cat.name,
        'color_value': cat.color.toARGB32(),
        'icon_code': cat.icon.codePoint,
      }).select().single();

      return CourseCategory(
        id: response['id'] as String,
        name: response['name'] as String,
        color: Color(response['color_value'] as int),
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(response['icon_code'] as int, fontFamily: 'MaterialIcons'),
      );
    } catch (e) {
      if (kDebugMode) print('❌ insertCategory error: $e');
      return null;
    }
  }

  /// Bir kategoriyi Supabase'den siler.
  Future<void> deleteCategory(String categoryId) async {
    if (!_isCloudActive) return;
    try {
      final client = Supabase.instance.client;
      await client.from('user_categories').delete().eq('id', categoryId);
    } catch (e) {
      if (kDebugMode) print('❌ deleteCategory error: $e');
    }
  }

  /// Mevcut kategori listesini Supabase'e toplu yazar (migration için).
  /// Mevcut tüm kategorileri siler, sonra yeniden ekler.
  Future<List<CourseCategory>> upsertCategories(List<CourseCategory> cats) async {
    if (!_isCloudActive) return cats;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return cats;

      // Var olanları sil
      await client.from('user_categories').delete().eq('user_id', userId);

      if (cats.isEmpty) return [];

      // Yeniden ekle
      final rows = cats.asMap().entries.map((entry) => {
        'user_id': userId,
        'name': entry.value.name,
        'color_value': entry.value.color.toARGB32(),
        'icon_code': entry.value.icon.codePoint,
        'sort_order': entry.key,
      }).toList();

      final response = await client
          .from('user_categories')
          .insert(rows)
          .select();

      return (response as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return CourseCategory(
          id: map['id'] as String,
          name: map['name'] as String,
          color: Color(map['color_value'] as int),
          icon: IconData(map['icon_code'] as int, fontFamily: 'MaterialIcons'),
        );
      }).toList();
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
          .select('id, name, email, avatar_id, points, total_minutes')
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
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid_grant')) {
      return isTurkish
          ? 'E-posta adresi veya şifre hatalı. Lütfen kontrol edip tekrar deneyin.'
          : 'Invalid email or password. Please check your credentials and try again.';
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
}
