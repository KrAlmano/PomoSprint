import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LoopbackTestOverrides extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) =>
      'DIRECT';
}

/// A loopback-only fake: no real auth account, provider or Supabase project.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late SupabaseClient client;
  late HttpOverrides? previousOverrides;
  final service = SupabaseService.instance;
  final user = {
    'id': '00000000-0000-4000-8000-000000000001',
    'aud': 'authenticated',
    'email': 'deletion-test@example.invalid',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': {
      'provider': 'email',
      'providers': ['email'],
    },
    'user_metadata': <String, dynamic>{},
  };
  Object? responseBody;
  var edgeStatus = 200;
  var authUserStatus = 200;
  var fallbackCalls = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _LoopbackTestOverrides();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      if (path == '/auth/v1/token') {
        request.response.write(
          jsonEncode({
            'access_token': 'test-only-access-token',
            'refresh_token': 'test-only-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          }),
        );
      } else if (path == '/functions/v1/delete-account') {
        request.response.statusCode = edgeStatus;
        request.response.write(jsonEncode(responseBody));
      } else if (path == '/auth/v1/user') {
        request.response.statusCode = authUserStatus;
        request.response.write(
          jsonEncode(
            authUserStatus == 200
                ? user
                : {
                    'code': authUserStatus,
                    'msg': 'route not found',
                    'error_code': 'not_found',
                  },
          ),
        );
      } else if (path == '/rest/v1/rpc/delete_own_account') {
        fallbackCalls++;
        request.response.statusCode = 204;
      } else if (path == '/auth/v1/logout') {
        request.response.statusCode = 204;
      } else {
        request.response.statusCode = 404;
        request.response.write('{}');
      }
      await request.response.close();
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:${server.port}',
      publishableKey: 'test-only-anon-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    client = Supabase.instance.client;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'saved_user': 'keep-until-confirmed',
    });
    responseBody = null;
    edgeStatus = 200;
    authUserStatus = 200;
    fallbackCalls = 0;
    await client.auth.signInWithPassword(
      email: 'deletion-test@example.invalid',
      password: 'test-only-password',
    );
    service.debugCloudActive = true;
    service.currentUser.value = UserModel(
      id: user['id'] as String,
      name: 'Test',
      email: user['email'] as String,
    );
  });

  tearDown(() async {
    await client.auth.signOut();
    service.debugCloudActive = false;
    service.currentUser.value = null;
    service.signOutNotice.value = null;
  });
  tearDownAll(() async {
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });

  for (final body in [
    null,
    <String, Object>{},
    {'deleted': false},
    {'deleted': 'true'},
  ]) {
    test(
      'unconfirmed 200 response preserves account and local data: $body',
      () async {
        responseBody = body;
        await expectLater(
          service.deleteUserAccount(),
          throwsA(isA<ServiceException>()),
        );
        expect(client.auth.currentUser?.id, user['id']);
        expect(service.currentUser.value?.id, user['id']);
        expect(
          (await SharedPreferences.getInstance()).getString('saved_user'),
          'keep-until-confirmed',
        );
        expect(
          fallbackCalls,
          0,
          reason: 'unconfirmed 2xx must not start a second deletion',
        );
        expect(service.signOutNotice.value, isNull);
      },
    );
  }

  test('generic auth 404 does not prove that an account was deleted', () async {
    responseBody = {'deleted': false};
    authUserStatus = 404;
    await expectLater(
      service.deleteUserAccount(),
      throwsA(isA<ServiceException>()),
    );
    expect(service.currentUser.value?.id, user['id']);
    expect(
      (await SharedPreferences.getInstance()).getString('saved_user'),
      'keep-until-confirmed',
    );
    expect(service.signOutNotice.value, isNull);
  });

  test('explicit receipt completes local cleanup', () async {
    responseBody = {
      'deleted': true,
      'apple': {'status': 'not_applicable'},
    };
    final result = await service.deleteUserAccount();
    expect(result, AppleRevocation.notApplicable);
    expect(service.currentUser.value, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('saved_user'),
      isNull,
    );
    expect(service.signOutNotice.value?.kind, SignOutNoticeKind.accountDeleted);
  });

  test('missing Edge endpoint still falls back to the deletion RPC', () async {
    edgeStatus = 404;
    responseBody = {'error': 'not_found'};
    final result = await service.deleteUserAccount();
    expect(result, AppleRevocation.notApplicable);
    expect(fallbackCalls, 1);
    expect(service.currentUser.value, isNull);
    expect(service.signOutNotice.value?.kind, SignOutNoticeKind.accountDeleted);
  });
}
