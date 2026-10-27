// Synthetic payloads and direct SDK callbacks only: no native SDK or network.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/error_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

SentryFlutterOptions _options() {
  final options = SentryFlutterOptions();
  configureSentry(options, dsn: 'https://synthetic@127.0.0.1/1');
  return options;
}

void main() {
  test(
    'nested mixed-case credentials are removed while status and operation survive',
    () async {
      final options = _options();
      final event = SentryEvent(
        message: SentryMessage('Problem for qa@example.invalid'),
        user: SentryUser(id: 'private-user-id', email: 'qa@example.invalid'),
        breadcrumbs: [
          Breadcrumb(
            data: {
              'operation': 'complete_exam_attempt',
              'status_code': 500,
              'nested': [
                {
                  'AUTHORIZATION': 'Bearer SYNTHETIC_BEARER',
                  'refreshToken': 'SYNTHETIC_REFRESH',
                  'api-key': 'SYNTHETIC_API_KEY',
                  'email': 'qa@example.invalid',
                  'safe': 'network retry',
                },
              ],
            },
          ),
        ],
      );
      final clean = await options.beforeSend!(event, Hint());
      final json = jsonEncode(clean!.toJson());
      for (final value in [
        'SYNTHETIC_',
        'qa@example.invalid',
        'private-user-id',
      ]) {
        expect(json, isNot(contains(value)));
      }
      expect(json, contains('complete_exam_attempt'));
      expect(json, contains('500'));
      expect(json, contains('network retry'));
      expect(clean.user, isNull);
    },
  );

  test(
    'request is rebuilt without userinfo, query, fragment, body, cookies or headers',
    () async {
      final options = _options();
      final clean = await options.beforeSend!(
        SentryEvent(
          request: SentryRequest(
            url:
                'https://user:SYNTHETIC_PASSWORD@api.example.invalid/rest/v1/rpc/start?token=SYNTHETIC_QUERY#SYNTHETIC_FRAGMENT',
            method: 'POST',
            queryString: 'token=SYNTHETIC_QUERY',
            cookies: 'session=SYNTHETIC_COOKIE',
            headers: {'Authorization': 'Bearer SYNTHETIC_HEADER'},
            data: {'password': 'SYNTHETIC_BODY'},
          ),
        ),
        Hint(),
      );
      expect(
        clean!.request!.url,
        'https://api.example.invalid/rest/v1/rpc/start',
      );
      expect(clean.request!.method, 'POST');
      expect(clean.request!.headers, isEmpty);
      expect(clean.request!.cookies, isNull);
      expect(clean.request!.data, isNull);
      expect(jsonEncode(clean.toJson()), isNot(contains('SYNTHETIC_')));
    },
  );

  test(
    'free text masks tokens and URLs while retaining stack line information',
    () async {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature123';
      final options = _options();
      final clean = await options.beforeSend!(
        SentryEvent(
          message: SentryMessage(
            'Bearer SYNTHETIC_AUTH access_token=SYNTHETIC_ASSIGN $jwt',
          ),
          exceptions: [
            SentryException.fromJson({
              'type': 'StateError',
              'value':
                  'request https://api.example.invalid/rpc?email=qa%40example.invalid#fragment',
              'stacktrace': {
                'frames': [
                  {
                    'filename': 'timer_screen.dart',
                    'lineno': 42,
                    'function': 'finish',
                  },
                ],
              },
            }),
          ],
        ),
        Hint(),
      );
      final encoded = jsonEncode(clean!.toJson());
      expect(encoded, isNot(contains('SYNTHETIC_')));
      expect(encoded, isNot(contains(jwt)));
      expect(encoded, isNot(contains('qa%40example.invalid')));
      expect(encoded, contains('timer_screen.dart'));
      expect(encoded, contains('42'));
      expect(encoded, contains('finish'));
    },
  );

  test(
    'deep, cyclic and oversized supplemental payloads are bounded',
    () async {
      final cyclic = <String, dynamic>{};
      cyclic['child'] = cyclic;
      final options = _options();
      final clean = await options.beforeSend!(
        SentryEvent(
          // ignore: deprecated_member_use
          extra: {
            'cycle': cyclic,
            'items': List.filled(200, 'item'),
            'long': 'x' * 30000,
          },
        ),
        Hint(),
      );
      final encoded = jsonEncode(clean!.toJson());
      expect(encoded.length, lessThan(6000));
      expect(encoded, contains('[truncated]'));
      // ignore: deprecated_member_use
      expect((clean.extra!['items'] as List).length, 64);
    },
  );

  test('transactions and child spans use the same privacy boundary', () async {
    final options = _options()..tracesSampleRate = 1;
    final hub = Hub(options);
    // SDK returns a real tracer for this enabled local-only Hub; leaving it
    // unfinished avoids transport. The callback is invoked directly below.
    final dynamic tracer = hub.startTransaction(
      'exam?token=SYNTHETIC_NAME',
      'rpc',
    );
    tracer.setData('refresh_token', 'SYNTHETIC_TRACE');
    final child = tracer.startChild(
      'rpc',
      description: 'Bearer SYNTHETIC_CHILD',
    );
    child.setData('nested', {
      'password': 'SYNTHETIC_PASSWORD',
      'status_code': 500,
    });
    final transaction = SentryTransaction(
      tracer,
      user: SentryUser(email: 'qa@example.invalid'),
      request: SentryRequest(
        url: 'https://api.example.invalid/rpc?token=SYNTHETIC_REQUEST',
      ),
    );
    final clean = await options.beforeSendTransaction!(transaction, Hint());
    final encoded = jsonEncode(clean!.toJson());
    expect(clean, isA<SentryTransaction>());
    expect(encoded, isNot(contains('SYNTHETIC_')));
    expect(encoded, isNot(contains('qa@example.invalid')));
    expect(encoded, contains('rpc'));
    expect(encoded, contains('500'));
    await hub.close();
  });

  test('malformed URLs cannot break the error reporting callback', () async {
    final options = _options();
    for (final url in [
      'https://example.invalid:not-a-port/rpc?token=SECRET',
      'https://example.invalid/%xx?token=SECRET',
      'https://[invalid/rpc?token=SECRET',
      'javascript:token=SECRET',
    ]) {
      final clean = await options.beforeSend!(
        SentryEvent(
          request: SentryRequest(url: url, method: 'POST'),
          message: SentryMessage('request failed: $url'),
        ),
        Hint(),
      );
      expect(clean, isNotNull);
      expect(jsonEncode(clean!.toJson()), isNot(contains('SECRET')));
    }
  });
}
