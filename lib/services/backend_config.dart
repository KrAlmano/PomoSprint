/// Supabase ve Sentry bağlantı ayarlarının kaynağı.
///
/// Varsayılan kaynak kök `.env` dosyasıdır. Derlemede `--dart-define` ile
/// `SUPABASE_URL` ve `SUPABASE_ANON_KEY` İKİSİ birden verilirse `.env`'in
/// yerine bunlar kullanılır; uygulama örneğin canlının yerel kopyasına
/// bağlanır (`tool/local_supabase/README.md`). Bu durumda Sentry DSN'i de
/// yalnızca `--dart-define=SENTRY_DSN` ile gelir; verilmezse Sentry kapalıdır,
/// yerel denemelerin hataları canlı Sentry projesine gitmez.
///
/// İkisinden yalnızca biri verilirse yerel adresle canlı anahtarın (ya da
/// tersinin) karışmaması için bulut bağlantısı kapalı kalır.
class BackendConfig {
  const BackendConfig._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.sentryDsn,
    required this.source,
  });

  static const String _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _defineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _defineSentryDsn = String.fromEnvironment('SENTRY_DSN');

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Boşsa Sentry SDK kendini devre dışı bırakır.
  final String sentryDsn;
  final BackendConfigSource source;

  bool get usesDartDefine => source == BackendConfigSource.dartDefine;

  /// [env]: yüklenen `.env` değerleri (okunamadıysa boş harita). `define*`
  /// parametreleri testler içindir; uygulamada derleme sabitleri kullanılır.
  static BackendConfig resolve(
    Map<String, String> env, {
    String defineUrl = _defineUrl,
    String defineAnonKey = _defineAnonKey,
    String defineSentryDsn = _defineSentryDsn,
  }) {
    final url = defineUrl.trim();
    final anonKey = defineAnonKey.trim();
    final sentryDsn = defineSentryDsn.trim();
    if (url.isNotEmpty && anonKey.isNotEmpty) {
      return BackendConfig._(
        supabaseUrl: url,
        supabaseAnonKey: anonKey,
        sentryDsn: sentryDsn,
        source: BackendConfigSource.dartDefine,
      );
    }
    if (url.isNotEmpty || anonKey.isNotEmpty) {
      return BackendConfig._(
        supabaseUrl: '',
        supabaseAnonKey: '',
        sentryDsn: sentryDsn,
        source: BackendConfigSource.incompleteDartDefine,
      );
    }
    return BackendConfig._(
      supabaseUrl: env['SUPABASE_URL'] ?? '',
      supabaseAnonKey: env['SUPABASE_ANON_KEY'] ?? '',
      sentryDsn: sentryDsn.isNotEmpty ? sentryDsn : (env['SENTRY_DSN'] ?? ''),
      source: BackendConfigSource.dotEnv,
    );
  }
}

enum BackendConfigSource {
  /// Kök `.env` (mağaza derlemeleri dahil varsayılan).
  dotEnv,

  /// `--dart-define=SUPABASE_URL=…` ve `--dart-define=SUPABASE_ANON_KEY=…`.
  dartDefine,

  /// Yalnızca biri verildi: bulut kapalı.
  incompleteDartDefine,
}
