import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  const uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const tokenA = 'fake-access-token-a';
  const tokenB = 'fake-access-token-b';
  late HttpServer server;
  late SupabaseClient client;
  late HttpOverrides? previousOverrides;
  final service = SupabaseService.instance;
  final requests = <({String? authorization, Map<String, dynamic> body})>[];
  Object? reply;
  var status = 200;
  Completer<void>? started;
  Completer<void>? finish;

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
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _LoopbackOnlyOverrides();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      switch (request.uri.path) {
        case '/auth/v1/token':
          final payload = jsonDecode(body) as Map;
          final isB = payload['email'] == 'b@example.invalid';
          request.response.write(
            jsonEncode({
              'access_token': isB ? tokenB : tokenA,
              'refresh_token': isB ? 'fake-refresh-b' : 'fake-refresh-a',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': isB
                  ? user(b, 'b@example.invalid')
                  : user(a, 'a@example.invalid'),
            }),
          );
        case '/auth/v1/logout':
          request.response.statusCode = 204;
        case '/rest/v1/rpc/register_session_start':
          requests.add((
            authorization: request.headers.value('authorization'),
            body: Map<String, dynamic>.from(jsonDecode(body) as Map),
          ));
          if (started case final signal?) {
            if (!signal.isCompleted) signal.complete();
          }
          if (finish case final gate?) await gate.future;
          request.response.statusCode = status;
          request.response.write(jsonEncode(reply));
        default:
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
  });

  setUp(() async {
    requests.clear();
    status = 200;
    reply = {'client_uuid': uuid, 'server_started_at': '2026-11-01T12:00:00Z'};
    started = null;
    finish = null;
    await client.auth.signInWithPassword(
      email: 'a@example.invalid',
      password: 'fake-password',
    );
    service.debugCloudActive = true;
  });
  tearDown(() async {
    if (finish case final gate?) {
      if (!gate.isCompleted) gate.complete();
    }
    await client.auth.signOut();
    service.debugCloudActive = false;
  });
  tearDownAll(() async {
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });

  Future<bool> start({String owner = a, int minutes = 25}) =>
      service.registerFocusSessionStart(
        expectedUserId: owner,
        clientUuid: uuid,
        durationMinutes: minutes,
      );

  for (final minutes in [25, 50]) {
    test(
      '$minutes-minute server registration uses owner JWT, UUID and duration',
      () async {
        expect(await start(minutes: minutes), isTrue);
        expect(requests, hasLength(1));
        expect(requests.single.authorization, 'Bearer $tokenA');
        expect(requests.single.body, {
          'p_client_uuid': uuid,
          'p_duration_minutes': minutes,
        });
      },
    );
  }

  test('foreign owner is never sent to the server', () async {
    expect(await start(owner: b), isFalse);
    expect(requests, isEmpty);
  });

  for (final invalid in [
    null,
    <String, Object>{},
    {
      'client_uuid': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'server_started_at': '2026-11-01T12:00:00Z',
    },
    {'client_uuid': uuid, 'server_started_at': 'invalid'},
    {'client_uuid': uuid, 'server_started_at': 42},
  ]) {
    test(
      'malformed or wrong registration receipt is rejected: $invalid',
      () async {
        reply = invalid;
        expect(await start(), isFalse);
        expect(requests, hasLength(1));
      },
    );
  }

  for (final code in [404, 500]) {
    test(
      'old server or failed RPC returns unverified for HTTP $code',
      () async {
        status = code;
        reply = {
          'code': code == 404 ? 'PGRST202' : 'XX000',
          'message': 'fake error',
        };
        expect(await start(), isFalse);
        expect(requests, hasLength(1));
      },
    );
  }

  test(
    'account switch while A request is pending never sends it as B',
    () async {
      started = Completer<void>();
      finish = Completer<void>();
      final result = start();
      await started!.future.timeout(const Duration(seconds: 3));
      await client.auth.signInWithPassword(
        email: 'b@example.invalid',
        password: 'fake-password',
      );
      expect(client.auth.currentUser?.id, b);
      finish!.complete();
      expect(
        await result,
        isFalse,
        reason: 'an A receipt must not be used in B',
      );
      expect(requests, hasLength(1));
      expect(requests.single.authorization, 'Bearer $tokenA');
      expect(requests.single.body['p_client_uuid'], uuid);
      expect(await start(owner: a), isFalse);
      expect(requests, hasLength(1));
    },
  );
}
