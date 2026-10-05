// Simülatörde, yerel Supabase kopyasına bağlı uçtan uca testlerin ortak
// yardımcıları. Ayrıntı: tool/local_supabase/README.md "Simülatörde uçtan uca
// test". Uygulama GERÇEK main() ile açılır; yalnızca cihaz dili Türkçe'ye
// sabitlenir (simülatör İngilizce olabilir).
//
// Güvenlik: SUPABASE_URL yerel değilse (127.0.0.1 / localhost) her test
// başlamadan düşer; canlıya hiçbir istek gitmez.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/main.dart' as app;
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/services/hidden_users.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/auth/legal_links.dart';
import 'package:pomodoro/widgets/shell_stat_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Bilgisayar tarafı yardımcının portu (tool/local_supabase/e2e/sim/e2e_host.py).
const int kE2eHostPort = int.fromEnvironment('E2E_HOST_PORT');
const String _runIdDefine = String.fromEnvironment('E2E_RUN_ID');

/// Koşu kimliği: hesap e-postalarını koşular arasında ayırır.
final String e2eRunId =
    _runIdDefine.isNotEmpty ? _runIdDefine : DateTime.now().millisecondsSinceEpoch.toRadixString(36);

/// YALNIZCA yerel kopyadaki e2e-sim hesaplarının şifresi; uygulamanın şifre
/// kuralına uyar (en az 6 karakter, küçük/büyük harf, rakam). Belge:
/// tool/local_supabase/e2e/ACCOUNTS.md.
const String kE2ePassword = 'SimE2e-Yerel2026';

/// `e2e-sim-<etiket>-<koşu>@pomosprint.local`
String e2eEmail(String tag) => 'e2e-sim-$tag-$e2eRunId@pomosprint.local';

/// Testin binding'i; dosyanın `main()`'inde bir kez çağrılır.
IntegrationTestWidgetsFlutterBinding initE2e() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final host = Uri.tryParse(kSupabaseUrl)?.host ?? '';
  if (kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty) {
    throw StateError('--dart-define=SUPABASE_URL ve SUPABASE_ANON_KEY (yerel kopya) verilmeli.');
  }
  if (!{'127.0.0.1', 'localhost', '::1'}.contains(host) && !host.endsWith('.localhost')) {
    throw StateError('SUPABASE_URL yerel değil ($host): bu testler yalnızca yerel kopyaya bağlanır.');
  }
  return binding;
}

// ---------------------------------------------------------------------------
// Uygulamayı açma / durum temizliği
// ---------------------------------------------------------------------------

bool _appStarted = false;

/// Cihazdaki uygulama durumunu sıfırlar: oturum kapanır (yerel), tüm
/// SharedPreferences silinir, gizlenen kullanıcılar ve servis singleton'ının
/// kullanıcıya bağlı durumu temizlenir. Her testin başında çağrılır.
Future<void> resetAppState(WidgetTester tester) async {
  if (_appStarted) {
    // Ekranlar kapanır (dispose'da yazılan kayıtlar silinmeden önce).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }
  final service = SupabaseService.instance;
  if (service.isCloudActive && Supabase.instance.client.auth.currentSession != null) {
    await service.signOutFully();
  }
  service.currentUser.value = null;
  service.takeSignOutNotice();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await HiddenUsersStore.instance.load(null);
}

/// Uygulamayı GERÇEK `main()` ile açar (Türkçe cihaz dili). Daha önce
/// açıldıysa önce ağaç kapatılır: ekranlar yeniden kurulur (soğuk açılışa
/// en yakın hâl; Supabase.initialize süreçte bir kez çalışır).
Future<void> launchApp(WidgetTester tester) async {
  if (_appStarted) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }
  _appStarted = true;
  LanguageService.deviceLocale = () => const Locale('tr', 'TR');
  // Sentry kendi FlutterError işleyicisini kurar; test çerçevesi işleyicinin
  // test sonunda aynı kalmasını ister (hatalar yine teste düşer).
  final onError = FlutterError.onError;
  await app.main();
  FlutterError.onError = onError;
  await tester.pump();
}

/// [finder] bulunana kadar kare çizer; [timeout] içinde bulunmazsa düşer.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Bulunamadı (${timeout.inSeconds} sn): ${reason ?? finder.describeMatch(Plurality.zero)}');
}

/// [finder] kaybolana kadar kare çizer.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Kaybolmadı (${timeout.inSeconds} sn): ${reason ?? finder.toString()}');
}

/// [condition] doğru olana kadar kare çizer.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  required String reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail('Koşul gerçekleşmedi (${timeout.inSeconds} sn): $reason');
}

/// Gerçek zamanda [duration] boyunca kare çizer (animasyonlar biter).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Görünür yapıp dokunur, ardından kısa süre kare çizer.
Future<void> tapOn(WidgetTester tester, Finder finder, {Duration settle = const Duration(milliseconds: 600)}) async {
  expect(finder, findsWidgets, reason: 'dokunulacak öğe yok: $finder');
  await tester.ensureVisible(finder.first);
  await pumpFor(tester, const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await pumpFor(tester, settle);
}

/// [scope] altındaki tüm Text / RichText metinleri (hata açıklamaları için).
List<String> visibleTexts(Finder scope) => [
      for (final element in find.descendant(of: scope, matching: find.byType(RichText)).evaluate())
        (element.widget as RichText).text.toPlainText(),
    ];

/// Türkçe metinler (testler arayüzü Türkçe'ye sabitler).
final AppLocalizations trL10n = lookupAppLocalizations(const Locale('tr'));

String tr(String key) => LanguageService.instance.translate(key);

/// Splash biter; giriş ekranı, onboarding ya da kabuk görünür.
Future<void> waitPastSplash(WidgetTester tester) async {
  await pumpUntil(
    tester,
    find.byWidgetPredicate((w) => w is LoginScreen || w is MainNavigationShell || w.runtimeType.toString() == 'PostAuthOnboardingScreen'),
    timeout: const Duration(seconds: 40),
    reason: 'açılış ekranından sonra giriş/onboarding/kabuk',
  );
}

/// Giriş ekranında e-posta + şifre ile girer.
Future<void> loginViaUi(WidgetTester tester, String email, {String password = kE2ePassword}) async {
  await pumpUntil(tester, find.byType(LoginScreen), reason: 'giriş ekranı');
  final fields = find.descendant(of: find.byType(LoginScreen), matching: find.byType(TextField));
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  await pumpFor(tester, const Duration(milliseconds: 300));
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(tester, const Duration(milliseconds: 400));
  await tapOn(tester, find.widgetWithText(ElevatedButton, trL10n.loginBtn));
}

// ---------------------------------------------------------------------------
// Bilgisayar tarafı yardımcı: ekran görüntüsü ve psql
// ---------------------------------------------------------------------------

class E2eHost {
  static bool get available => kE2eHostPort > 0;

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: kE2eHostPort, path: path, queryParameters: query);

  static Future<String> _send(String method, Uri uri, {String? body}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.openUrl(method, uri);
      if (body != null) {
        final bytes = utf8.encode(body);
        req.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final res = await req.close().timeout(const Duration(seconds: 90));
      final text = await utf8.decodeStream(res);
      if (res.statusCode != 200) throw HttpException('e2e_host ${res.statusCode}: $text', uri: uri);
      return text;
    } finally {
      client.close(force: true);
    }
  }

  /// `analiz/ekranlar/<name>.png` (xcrun simctl io screenshot). Yardımcı
  /// yoksa atlanır.
  static Future<void> screenshot(WidgetTester tester, String name) async {
    await pumpFor(tester, const Duration(milliseconds: 700));
    if (!available) {
      debugPrint('[E2E] ekran görüntüsü atlandı (E2E_HOST_PORT yok): $name');
      return;
    }
    final path = await _send('GET', _uri('/shot', {'name': name}));
    debugPrint('[E2E] ekran görüntüsü: $path');
    await tester.pump();
  }

  /// Yerel veritabanında salt okuma psql. [sql] tek satır döndürmeli.
  static Future<String> psql(String sql) {
    if (!available) {
      throw StateError('psql doğrulaması için E2E_HOST_PORT gerekir (tool/local_supabase/e2e/sim/run_sim_e2e.sh).');
    }
    return _send('POST', _uri('/psql'), body: sql);
  }

  /// [select] sorgusunun satırları (json_agg ile).
  static Future<List<Map<String, dynamic>>> rows(String select) async {
    final out = await psql("select coalesce(json_agg(t), '[]'::json) from ($select) t");
    return [for (final row in jsonDecode(out) as List) Map<String, dynamic>.from(row as Map)];
  }

  /// [select]'i oturumu [userId] olan kullanıcı gibi çalıştırır
  /// (`auth.uid()` = [userId]; SECURITY DEFINER RPC'ler için).
  static Future<List<Map<String, dynamic>>> rowsAsUser(String userId, String select) async {
    final out = await psql(
      "select set_config('request.jwt.claims', json_build_object('sub', ${sqlText(userId)}, 'role', 'authenticated')::text, true); "
      "select coalesce(json_agg(t), '[]'::json) from ($select) t",
    );
    final json = out.substring(out.indexOf('\n') + 1);
    return [for (final row in jsonDecode(json) as List) Map<String, dynamic>.from(row as Map)];
  }

  static Future<Map<String, dynamic>?> row(String select) async {
    final all = await rows(select);
    return all.isEmpty ? null : all.single;
  }
}

/// psql için metin sabiti ('...' kaçışlı).
String sqlText(String value) => "'${value.replaceAll("'", "''")}'";

// ---------------------------------------------------------------------------
// Yerel API (GoTrue + PostgREST), test kurulumları için
// ---------------------------------------------------------------------------

class LocalApiError implements Exception {
  LocalApiError(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'LocalApiError($status): $body';
}

class LocalApi {
  static Future<Object?> request(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.openUrl(method, Uri.parse('$kSupabaseUrl$path'));
      req.headers.set('apikey', kSupabaseAnonKey);
      req.headers.set('Authorization', 'Bearer ${token ?? kSupabaseAnonKey}');
      req.headers.contentType = ContentType.json;
      headers.forEach(req.headers.set);
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await utf8.decodeStream(res);
      if (res.statusCode >= 300) throw LocalApiError(res.statusCode, text);
      return text.isEmpty ? null : jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Object?> rpc(String name, ApiAccount account, [Map<String, Object?> args = const {}]) =>
      request('POST', '/rest/v1/rpc/$name', body: args, token: account.token);
}

/// API ile açılmış hesap.
class ApiAccount {
  ApiAccount(this.id, this.email, this.token);
  final String id;
  final String email;
  final String token;
}

/// Uygulamadaki kayıtla aynı metadata ile hesap açar (yerelde e-posta onayı
/// kapalı: oturum hemen açılır).
Future<ApiAccount> signUpViaApi(String email, String name) async {
  final res = await LocalApi.request('POST', '/auth/v1/signup', body: {
    'email': email,
    'password': kE2ePassword,
    'data': {
      'name': name,
      'avatar_id': 'avatar_16_basic',
      'newsletter': false,
      'marketing_consent': false,
      'terms_version': kLegalDocumentsVersion,
      'privacy_version': kLegalDocumentsVersion,
      'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
    },
  }) as Map;
  final token = res['access_token'] as String?;
  final user = (res['user'] ?? res) as Map;
  if (token == null) throw StateError('yerelde e-posta onayı kapalı olmalı (oturum dönmedi)');
  return ApiAccount(user['id'] as String, email, token);
}

/// Onboarding'i uygulamanın yaptığı gibi API ile bitirir: hedefin
/// önerilen kategorileri (setup_onboarding_categories) + profil alanları.
Future<void> completeOnboardingViaApi(
  ApiAccount account, {
  String segment = 'yks',
  bool showInSocialFeed = true,
  int birthYear = 2007,
  int dailyGoalMinutes = 120,
}) async {
  final names = autoSelectedCategoryNames(segment, kept: const [], limit: 8);
  await LocalApi.rpc('setup_onboarding_categories', account, {
    'p_categories': categorySeedPayload(names, turkish: true),
  });
  await LocalApi.request('PATCH', '/rest/v1/profiles?id=eq.${account.id}', token: account.token, body: {
    'birth_year': birthYear,
    'user_segment': segment,
    'daily_goal_minutes': dailyGoalMinutes,
    'show_in_social_feed': showInSocialFeed,
    'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
  });
}

/// Hesabın aktif kategorileri (id, name), sıralı.
Future<List<Map<String, dynamic>>> categoriesViaApi(ApiAccount account) async {
  final res = await LocalApi.request(
    'GET',
    '/rest/v1/categories?select=id,name&is_archived=eq.false&order=sort_order,created_at',
    token: account.token,
  );
  return [for (final r in res as List) Map<String, dynamic>.from(r as Map)];
}

/// Hazır hesap (API ile kayıt + onboarding) açar, uygulamayı başlatıp
/// giriş ekranından girer ve kabuğu bekler.
Future<ApiAccount> openShellWithNewAccount(
  WidgetTester tester,
  String tag, {
  String name = 'Sim Kullanıcı',
  String segment = 'yks',
  bool showInSocialFeed = true,
}) async {
  await resetAppState(tester);
  final account = await signUpViaApi(e2eEmail(tag), name);
  await completeOnboardingViaApi(account, segment: segment, showInSocialFeed: showInSocialFeed);
  await launchApp(tester);
  await waitPastSplash(tester);
  await loginViaUi(tester, account.email);
  await pumpUntil(tester, find.byType(MainNavigationShell), timeout: const Duration(seconds: 40), reason: 'kabuk');
  return account;
}

/// Üst çubuktaki PUAN / KUM rozetlerinin değerleri.
({int points, int coins}) shellStats(WidgetTester tester) {
  final pills = tester.widgetList<ShellStatPill>(find.byType(ShellStatPill)).toList();
  int valueOf(String label) => pills.firstWhere((p) => p.label == label).value;
  return (points: valueOf(trL10n.pointsCaption), coins: valueOf(trL10n.coinsCaption));
}

/// Alt gezinme çubuğundaki sekmeye geçer (0 Pomo, 1 Raporlar, 2 Sıralama, 3 Sosyal).
Future<void> openTab(WidgetTester tester, int index) async {
  final destinations = find.descendant(of: find.byType(NavigationBar), matching: find.byType(NavigationDestination));
  await tapOn(tester, destinations.at(index), settle: const Duration(milliseconds: 800));
}
