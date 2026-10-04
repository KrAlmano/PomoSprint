import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/backend_config.dart';

// BackendConfig: .env ile --dart-define arasındaki öncelik (yerel Supabase
// kopyası, tool/local_supabase/README.md) ve iOS'un yerel ağa http izni.

const _env = {
  'SUPABASE_URL': 'https://canli.supabase.co',
  'SUPABASE_ANON_KEY': 'canli-anon',
  'SENTRY_DSN': 'https://canli@sentry.example/1',
};

void main() {
  test('dart-define yoksa .env kullanılır (mağaza derlemesi)', () {
    final c = BackendConfig.resolve(_env, defineUrl: '', defineAnonKey: '', defineSentryDsn: '');
    expect(c.source, BackendConfigSource.dotEnv);
    expect(c.usesDartDefine, isFalse);
    expect(c.supabaseUrl, 'https://canli.supabase.co');
    expect(c.supabaseAnonKey, 'canli-anon');
    expect(c.sentryDsn, 'https://canli@sentry.example/1');
  });

  test('.env okunamadıysa ve dart-define yoksa bulut kapalı kalır', () {
    final c = BackendConfig.resolve(const {}, defineUrl: '', defineAnonKey: '', defineSentryDsn: '');
    expect(c.supabaseUrl, isEmpty);
    expect(c.supabaseAnonKey, isEmpty);
    expect(c.sentryDsn, isEmpty);
  });

  test('URL ve anahtar birlikte verilince .env yerine kullanılır, Sentry kapanır', () {
    final c = BackendConfig.resolve(
      _env,
      defineUrl: ' http://127.0.0.1:54321 ',
      defineAnonKey: 'yerel-anon',
      defineSentryDsn: '',
    );
    expect(c.source, BackendConfigSource.dartDefine);
    expect(c.usesDartDefine, isTrue);
    expect(c.supabaseUrl, 'http://127.0.0.1:54321');
    expect(c.supabaseAnonKey, 'yerel-anon');
    // Yerel denemelerin hataları canlı Sentry projesine gitmez.
    expect(c.sentryDsn, isEmpty);
  });

  test('dart-define ile Sentry DSN verilirse o kullanılır', () {
    final local = BackendConfig.resolve(
      _env,
      defineUrl: 'http://127.0.0.1:54321',
      defineAnonKey: 'yerel-anon',
      defineSentryDsn: 'https://test@sentry.example/2',
    );
    expect(local.sentryDsn, 'https://test@sentry.example/2');
    final live = BackendConfig.resolve(_env, defineUrl: '', defineAnonKey: '', defineSentryDsn: 'https://test@sentry.example/2');
    expect(live.source, BackendConfigSource.dotEnv);
    expect(live.sentryDsn, 'https://test@sentry.example/2');
  });

  test('yalnızca biri verilirse canlı ve yerel değerler karışmaz: bulut kapalı', () {
    for (final (url, key) in [('http://127.0.0.1:54321', ''), ('', 'yerel-anon'), ('  ', 'yerel-anon')]) {
      final c = BackendConfig.resolve(_env, defineUrl: url, defineAnonKey: key, defineSentryDsn: '');
      expect(c.source, BackendConfigSource.incompleteDartDefine, reason: '($url, $key)');
      expect(c.supabaseUrl, isEmpty);
      expect(c.supabaseAnonKey, isEmpty);
      expect(c.sentryDsn, isEmpty);
    }
  });

  test('iOS: yalnızca yerel ağa http izni (NSAllowsLocalNetworking), genel istisna yok', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final ats = RegExp(r'<key>NSAppTransportSecurity</key>\s*<dict>(.*?)</dict>', dotAll: true).firstMatch(plist)?.group(1);
    expect(ats, isNotNull);
    expect(ats, matches(RegExp(r'<key>NSAllowsLocalNetworking</key>\s*<true/>')));
    expect(ats, isNot(contains('NSAllowsArbitraryLoads')));
    expect(ats, isNot(contains('NSExceptionDomains')));
  });
}
