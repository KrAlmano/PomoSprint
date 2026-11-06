import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/services/backend_config.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LoopbackOnlyOverrides extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) =>
      'DIRECT';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = '00000000-0000-4000-8000-000000000001';
  const b = '00000000-0000-4000-8000-000000000002';
  const tokenA = 'fake-access-a';
  const tokenReauthA = 'fake-reauth-a';
  const tokenB = 'fake-access-b';
  final service = SupabaseService.instance;
  late HttpServer server;
  late SupabaseClient client;
  late HttpOverrides? previous;
  bool delayA = false;
  bool delayUpdate = false;
  bool rejectA = false;
  bool requireNonce = false;
  bool requireCurrentPassword = false;
  int? updateFailureStatus;
  bool dropUpdateResponse = false;
  String? rejectedToken;
  int aSignins = 0;
  Completer<void>? reached;
  Completer<void>? release;
  final updates = <String?>[];
  String? sentCurrentPassword;
  final logouts = <({String? authorization, String? scope})>[];

  Map<String, Object> user(String id, String email) => {
    'id': id,
    'aud': 'authenticated',
    'email': email,
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': {
      'provider': 'email',
      'providers': ['email'],
    },
    'user_metadata': <String, dynamic>{},
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    previous = HttpOverrides.current;
    HttpOverrides.global = _LoopbackOnlyOverrides();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/auth/v1/token') {
        final isB = (jsonDecode(body) as Map)['email'] == 'b@example.invalid';
        if (!isB) aSignins++;
        if (!isB && delayA) {
          reached!.complete();
          await release!.future;
        }
        if (!isB && rejectA) {
          request.response.statusCode = 400;
          request.response.write(
            jsonEncode({
              'error_code': 'invalid_credentials',
              'msg': 'invalid credentials',
            }),
          );
          await request.response.close();
          return;
        }
        request.response.write(
          jsonEncode({
            'access_token': isB
                ? tokenB
                : (aSignins == 1 ? tokenA : tokenReauthA),
            'refresh_token': isB ? 'fake-refresh-b' : 'fake-refresh-a',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user(
              isB ? b : a,
              isB ? 'b@example.invalid' : 'a@example.invalid',
            ),
          }),
        );
      } else if (request.uri.path == '/auth/v1/user' &&
          request.method == 'PUT') {
        updates.add(request.headers.value('authorization'));
        sentCurrentPassword =
            (jsonDecode(body) as Map)['current_password'] as String?;
        if (delayUpdate) {
          reached!.complete();
          await release!.future;
        }
        if (dropUpdateResponse) {
          final socket = await request.response.detachSocket();
          socket.destroy();
          return;
        }
        final status =
            request.headers.value('authorization') == 'Bearer $rejectedToken'
            ? 401
            : updateFailureStatus;
        if (status != null) {
          request.response.statusCode = status;
          request.response.write(
            jsonEncode({
              'error_code': 'invalid_credentials',
              'msg': 'synthetic error',
            }),
          );
          await request.response.close();
          return;
        }
        if (requireNonce) {
          request.response.statusCode = 400;
          request.response.write(
            jsonEncode({
              'error_code': 'reauthentication_needed',
              'msg': 'nonce required',
            }),
          );
          await request.response.close();
          return;
        }
        if (requireCurrentPassword && sentCurrentPassword != 'old') {
          request.response.statusCode = 400;
          request.response.write(
            jsonEncode({
              'error_code': 'current_password_required',
              'msg': 'current password required',
            }),
          );
          await request.response.close();
          return;
        }
        request.response.write(jsonEncode(user(a, 'a@example.invalid')));
      } else if (request.uri.path == '/auth/v1/logout') {
        logouts.add((
          authorization: request.headers.value('authorization'),
          scope: request.uri.queryParameters['scope'],
        ));
        request.response.statusCode = 204;
      } else {
        request.response.statusCode = 404;
        request.response.write('{}');
      }
      await request.response.close();
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:${server.port}',
      publishableKey: 'fake-only-public-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    client = Supabase.instance.client;
    service.debugBackendConfig = BackendConfig.resolve(
      {
        'SUPABASE_URL': 'http://127.0.0.1:${server.port}',
        'SUPABASE_ANON_KEY': 'fake-only-public-key',
      },
      defineUrl: '',
      defineAnonKey: '',
    );
  });
  setUp(() async {
    delayA = false;
    delayUpdate = false;
    rejectA = false;
    requireNonce = false;
    requireCurrentPassword = false;
    updateFailureStatus = null;
    dropUpdateResponse = false;
    rejectedToken = null;
    sentCurrentPassword = null;
    aSignins = 0;
    updates.clear();
    logouts.clear();
    reached = Completer<void>();
    release = Completer<void>();
    await client.auth.signInWithPassword(
      email: 'a@example.invalid',
      password: 'fake',
    );
    service.currentUser.value = UserModel(
      id: a,
      name: 'A',
      email: 'a@example.invalid',
    );
    service.debugCloudActive = true;
  });
  tearDown(() async {
    if (release case final gate?) {
      if (!gate.isCompleted) gate.complete();
    }
    await client.auth.signOut();
    service.currentUser.value = null;
    service.debugCloudActive = false;
  });
  tearDownAll(() async {
    service.debugBackendConfig = null;
    await server.close(force: true);
    HttpOverrides.global = previous;
  });

  Future<void> switchToB() async {
    await client.auth.signInWithPassword(
      email: 'b@example.invalid',
      password: 'fake',
    );
    service.currentUser.value = UserModel(
      id: b,
      name: 'B',
      email: 'b@example.invalid',
    );
  }

  String tokenFor(String sessionId, int version) {
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${encode({'alg': 'none'})}.${encode({'sub': a, 'session_id': sessionId, 'version': version})}.signature';
  }

  Future<void> setMainToken(String token) async {
    final updated = client.auth.currentSession!.copyWith(accessToken: token);
    await client.auth.setInitialSession(jsonEncode(updated.toJson()));
  }

  test(
    'late reauthentication cannot restore A over B or update a password',
    () async {
      delayA = true;
      final pending = service
          .changePassword(currentPassword: 'old', newPassword: 'new')
          .then<Object?>((_) => null, onError: (Object e) => e);
      await reached!.future;
      await switchToB();
      release!.complete();
      final outcome = await pending;
      expect(outcome, isA<AuthFailure>());
      expect(client.auth.currentUser?.id, b);
      expect(client.auth.currentSession?.accessToken, tokenB);
      expect(updates, isEmpty);
    },
  );

  test('late password update cannot replace B user in B session', () async {
    delayUpdate = true;
    final pending = service
        .changePassword(currentPassword: 'old', newPassword: 'new')
        .then<Object?>((_) => null, onError: (Object e) => e);
    await reached!.future;
    await switchToB();
    release!.complete();
    final outcome = await pending;
    expect(outcome, isA<AuthFailure>());
    expect(
      (outcome as AuthFailure).code,
      AuthErrorCode.passwordChangeOutcomeUnknown,
    );
    expect(updates, ['Bearer $tokenA']);
    expect(client.auth.currentUser?.id, b);
    expect(client.auth.currentSession?.accessToken, tokenB);
  });

  test('late rejected reauthentication does not show A error for B', () async {
    delayA = true;
    rejectA = true;
    final pending = service
        .changePassword(currentPassword: 'wrong', newPassword: 'new')
        .then<Object?>((_) => null, onError: (Object e) => e);
    await reached!.future;
    await switchToB();
    release!.complete();
    final outcome = await pending;
    expect(outcome, isA<AuthFailure>());
    expect((outcome as AuthFailure).code, AuthErrorCode.unknown);
    expect(updates, isEmpty);
    expect(client.auth.currentUser?.id, b);
    expect(client.auth.currentSession?.accessToken, tokenB);
  });

  test('late rejected update does not show A error for B', () async {
    delayUpdate = true;
    updateFailureStatus = 400;
    final pending = service
        .changePassword(currentPassword: 'old', newPassword: 'new')
        .then<Object?>((_) => null, onError: (Object e) => e);
    await reached!.future;
    await switchToB();
    release!.complete();
    final outcome = await pending;
    expect(outcome, isA<AuthFailure>());
    expect((outcome as AuthFailure).code, AuthErrorCode.unknown);
    expect(updates, ['Bearer $tokenA']);
    expect(client.auth.currentUser?.id, b);
    expect(client.auth.currentSession?.accessToken, tokenB);
  });

  test(
    'successful password update uses original token and keeps current session',
    () async {
      requireCurrentPassword = true;
      await service.changePassword(currentPassword: 'old', newPassword: 'new');
      expect(updates, ['Bearer $tokenA']);
      expect(sentCurrentPassword, 'old');
      expect(client.auth.currentUser?.id, a);
      expect(client.auth.currentSession?.accessToken, tokenA);
      expect(logouts.single.authorization, 'Bearer $tokenReauthA');
      expect(logouts.single.scope, 'local');
    },
  );

  test(
    'failed reauthentication does not change the password or session',
    () async {
      rejectA = true;
      await expectLater(
        service.changePassword(currentPassword: 'wrong', newPassword: 'new'),
        throwsA(isA<AuthException>()),
      );
      expect(updates, isEmpty);
      expect(logouts, isEmpty);
      expect(client.auth.currentUser?.id, a);
      expect(client.auth.currentSession?.accessToken, tokenA);
    },
  );

  test('server nonce requirement does not report success', () async {
    requireNonce = true;
    await expectLater(
      service.changePassword(currentPassword: 'old', newPassword: 'new'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          'reauthentication_needed',
        ),
      ),
    );
    expect(updates, ['Bearer $tokenA']);
    expect(client.auth.currentUser?.id, a);
    expect(client.auth.currentSession?.accessToken, tokenA);
    expect(logouts.single.authorization, 'Bearer $tokenReauthA');
    expect(logouts.single.scope, 'local');
  });

  test(
    'same session token rotation does not produce a false failure',
    () async {
      final original = tokenFor('same-session', 1);
      final rotated = tokenFor('same-session', 2);
      rejectedToken = original;
      await setMainToken(original);
      delayA = true;
      final pending = service
          .changePassword(currentPassword: 'old', newPassword: 'new')
          .then<Object?>((_) => null, onError: (Object e) => e);
      await reached!.future;
      await setMainToken(rotated);
      release!.complete();
      expect(await pending, isNull);
      expect(updates, ['Bearer $rotated']);
      expect(client.auth.currentSession?.accessToken, rotated);
    },
  );

  test(
    'same user with a new session does not receive a stale password change',
    () async {
      await setMainToken(tokenFor('old-session', 1));
      delayA = true;
      final pending = service
          .changePassword(currentPassword: 'old', newPassword: 'new')
          .then<Object?>((_) => null, onError: (Object e) => e);
      await reached!.future;
      final newToken = tokenFor('new-session', 1);
      await setMainToken(newToken);
      release!.complete();
      expect(await pending, isA<AuthFailure>());
      expect(updates, isEmpty);
      expect(client.auth.currentSession?.accessToken, newToken);
    },
  );

  for (final status in [408, 429, 500]) {
    test('HTTP $status after update reports an unknown outcome', () async {
      updateFailureStatus = status;
      await expectLater(
        service.changePassword(currentPassword: 'old', newPassword: 'new'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.passwordChangeOutcomeUnknown,
          ),
        ),
      );
      expect(updates, ['Bearer $tokenA']);
      expect(client.auth.currentUser?.id, a);
    });
  }

  test('lost update response reports an unknown outcome', () async {
    dropUpdateResponse = true;
    await expectLater(
      service.changePassword(currentPassword: 'old', newPassword: 'new'),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.passwordChangeOutcomeUnknown,
        ),
      ),
    );
    expect(updates, ['Bearer $tokenA']);
    expect(client.auth.currentUser?.id, a);
  });

  test(
    'explicit HTTP 400 update rejection retains the provider error',
    () async {
      updateFailureStatus = 400;
      await expectLater(
        service.changePassword(currentPassword: 'old', newPassword: 'new'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
    },
  );
}
