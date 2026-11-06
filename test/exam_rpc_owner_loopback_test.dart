import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LoopbackOnlyOverrides extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) => 'DIRECT';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = '00000000-0000-4000-8000-000000000001';
  const b = '00000000-0000-4000-8000-000000000002';
  const tokenA = 'fake-access-a';
  const tokenB = 'fake-access-b';
  late HttpServer server;
  late SupabaseClient client;
  late HttpOverrides? previous;
  final service = SupabaseService.instance;
  final backend = SupabaseExamBackend();
  final requests = <({String path, String? auth})>[];
  Completer<void>? started;
  Completer<void>? release;
  Map<String, Object> user(String id) => {
    'id': id, 'aud': 'authenticated', 'email': '$id@example.invalid',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': {'provider': 'email', 'providers': ['email']},
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
        request.response.write(jsonEncode({
          'access_token': isB ? tokenB : tokenA,
          'refresh_token': isB ? 'fake-refresh-b' : 'fake-refresh-a',
          'token_type': 'bearer', 'expires_in': 3600,
          'user': user(isB ? b : a),
        }));
      } else if (request.uri.path == '/auth/v1/logout') {
        request.response.statusCode = 204;
      } else if (request.uri.path.startsWith('/rest/v1/rpc/')) {
        requests.add((path: request.uri.path, auth: request.headers.value('authorization')));
        if (started case final signal?) { if (!signal.isCompleted) signal.complete(); }
        if (release case final gate?) await gate.future;
        request.response.write('{}');
      } else {
        request.response.statusCode = 404;
        request.response.write('{}');
      }
      await request.response.close();
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:${server.port}', publishableKey: 'fake-only-public-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false, detectSessionInUri: false, localStorage: EmptyLocalStorage(),
      ),
    );
    client = Supabase.instance.client;
  });
  setUp(() async {
    requests.clear(); started = null; release = null;
    await client.auth.signInWithPassword(email: 'a@example.invalid', password: 'fake');
    service.currentUser.value = UserModel(id: a, name: 'A', email: 'a@example.invalid');
    service.debugCloudActive = true;
  });
  tearDown(() async {
    if (release case final gate?) { if (!gate.isCompleted) gate.complete(); }
    await client.auth.signOut();
    service.currentUser.value = null;
    service.debugCloudActive = false;
  });
  tearDownAll(() async { await server.close(force: true); HttpOverrides.global = previous; });

  for (final name in ['start_exam_attempt', 'save_exam_details', 'get_my_exam_attempts_v2']) {
    test('$name keeps A JWT if account changes while request is in flight', () async {
      started = Completer<void>(); release = Completer<void>();
      final request = backend.rpc(name, {'p_fake': true}, expectedOwnerId: a);
      await started!.future;
      await client.auth.signInWithPassword(email: 'b@example.invalid', password: 'fake');
      service.currentUser.value = UserModel(id: b, name: 'B', email: 'b@example.invalid');
      release!.complete();
      await request;
      expect(requests.single.auth, 'Bearer $tokenA');
      expect(requests.single.path, '/rest/v1/rpc/$name');
    });
  }
  test('owner mismatch fails before any RPC is sent', () async {
    expect(() => backend.rpc('start_exam_attempt', {}, expectedOwnerId: b), throwsA(isA<ExamFailure>()));
    expect(requests, isEmpty);
  });
}
