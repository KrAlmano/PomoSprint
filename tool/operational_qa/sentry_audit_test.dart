// Operational audit only: synthetic values, in-memory transport, no live DSN.
// Acceptance regressions for the scrubbed SDK transport; no live delivery.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Supabase already depends on http; used only by this audit harness.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:pomodoro/app/error_reporting.dart';
import 'package:pomodoro/services/server_clock.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _syntheticDsn = 'https://auditpublic@127.0.0.1/1';
const _email = 'qa.person@example.invalid';
const _secret = 'SYNTHETIC_SECRET_NO_REAL_CREDENTIAL';
final _findings = <String, Object?>{};

class _MemoryTransport extends Transport {
  final events = <Map<String, dynamic>>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    for (final item in envelope.items) {
      if (item.originalObject is SentryEvent) {
        events.add(
          Map<String, dynamic>.from(
            jsonDecode(utf8.decode(await item.dataFactory())) as Map,
          ),
        );
      }
    }
    return envelope.header.eventId;
  }
}

SentryFlutterOptions _options() {
  final options = SentryFlutterOptions();
  configureSentry(options, dsn: _syntheticDsn);
  return options;
}

void _throwSyntheticFailure() =>
    throw StateError('Operational audit only: $_email');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() async {
    await Sentry.close();
    final output = File(
      'analiz/qa_evidence_20261028/operational_controls/error_tracking/findings.json',
    );
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'scope': 'Existing application configuration only; synthetic local SDK probes', 'network_destination': 'none; SDK transport is in memory', 'live_event_or_alert_sent': false, 'findings': _findings})}\n',
    );
  });

  test('configured privacy and sampling defaults', () {
    final options = _options();
    expect(options.sendDefaultPii, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.attachScreenshot, isFalse);
    // SDK marks this read-only privacy assertion experimental.
    // ignore: experimental_member_use
    expect(options.attachViewHierarchy, isFalse);
    expect(options.tracesSampleRate, .2);
    expect(options.beforeSend, isNotNull);
    expect(options.beforeBreadcrumb, isNotNull);
    expect(options.beforeSendTransaction, isNotNull);
    _findings['privacy_defaults'] = 'pass';
  });

  test(
    'existing email mask handles message, exception, shallow breadcrumb',
    () async {
      final options = _options();
      final event = SentryEvent(
        message: SentryMessage('Failure for $_email'),
        exceptions: [SentryException(type: 'StateError', value: _email)],
        breadcrumbs: [
          Breadcrumb(message: _email, data: {'email': _email}),
        ],
      );
      final processed = await options.beforeSend!(event, Hint());
      expect(jsonEncode(processed!.toJson()), isNot(contains(_email)));
      expect(jsonEncode(processed.toJson()), contains('[email]'));
      _findings['shallow_email_mask'] = 'pass';
    },
  );

  test('probe nested breadcrumb and request privacy boundary', () async {
    final options = _options();
    final event = SentryEvent(
      breadcrumbs: [
        Breadcrumb(
          data: {
            'nested': {'email': _email, 'access_token': _secret},
          },
        ),
      ],
      request: SentryRequest(
        url: 'https://api.example.invalid/rpc/sample?access_token=$_secret',
        headers: {'Authorization': 'Bearer $_secret'},
        data: {'email': _email, 'password': _secret},
      ),
    );
    final processed = await options.beforeSend!(event, Hint());
    final encoded = jsonEncode(processed!.toJson());
    expect(encoded, isNot(contains(_email)));
    expect(encoded, isNot(contains(_secret)));
    _findings['nested_and_request_scrub'] = {
      'acceptance': 'pass: nested and request payload scrubbed',
      'synthetic_email_survived': encoded.contains(_email),
      'synthetic_token_survived': encoded.contains(_secret),
      'real_user_data_observed': false,
    };
  });

  test(
    'SDK capture keeps stack and safe breadcrumb while masking top-level email',
    () async {
      final options = _options();
      final transport = _MemoryTransport();
      options.transport = transport;
      for (final integration in options.integrations) {
        options.removeIntegration(integration);
      }
      options.tracesSampleRate = 0;
      // Internal SDK options injection avoids native initialization in this test.
      // ignore: invalid_use_of_internal_member
      await Sentry.init((_) {}, options: options);
      await Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'audit.operation',
          message: 'session_submission_probe',
          data: {'operation': 'complete_study_session', 'status_code': 500},
        ),
      );
      try {
        _throwSyntheticFailure();
      } catch (error, stack) {
        await Sentry.captureException(error, stackTrace: stack);
      }
      expect(transport.events, hasLength(1));
      final event = transport.events.single;
      final values = (event['exception'] as Map)['values'] as List;
      final frames =
          ((values.first as Map)['stacktrace'] as Map)['frames'] as List;
      expect(frames, isNotEmpty);
      expect(frames.any((dynamic f) => (f as Map)['lineno'] != null), isTrue);
      expect(jsonEncode(frames), contains('sentry_audit_test.dart'));
      final encoded = jsonEncode(event);
      expect(encoded, isNot(contains(_email)));
      expect(encoded, contains('session_submission_probe'));
      expect(encoded, contains('complete_study_session'));
      _findings['sdk_capture'] = {
        'acceptance': 'pass',
        'events': transport.events.length,
        'stack_frames': frames.length,
        'source_filename_preserved': true,
        'line_number_preserved': true,
        'breadcrumb_preserved': true,
        'top_level_email_masked': true,
        'environment': event['environment'],
        'native_crash_or_dashboard_alert_tested': false,
      };
      final saved = File(
        'analiz/qa_evidence_20261028/operational_controls/error_tracking/synthetic_event.json',
      );
      saved.parent.createSync(recursive: true);
      saved.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(event)}\n',
      );
      await Sentry.close();
    },
  );

  test(
    'existing Supabase HTTP wrapper preserves clock but does not report 500',
    () async {
      final options = _options();
      final transport = _MemoryTransport();
      options.transport = transport;
      for (final integration in options.integrations) {
        options.removeIntegration(integration);
      }
      options.tracesSampleRate = 0;
      // ignore: invalid_use_of_internal_member
      await Sentry.init((_) {}, options: options);
      final clock = ServerClock();
      final client = ServerClockHttpClient(
        clock,
        MockClient((request) async {
          return http.Response(
            '{}',
            500,
            headers: {'date': 'Thu, 08 Oct 2026 14:00:00 GMT'},
          );
        }),
      );
      final response = await client.get(
        Uri.parse('https://api.example.invalid/rest/v1/rpc/audit_operation'),
      );
      expect(response.statusCode, 500);
      expect(clock.offset, isNotNull);
      expect(transport.events, isEmpty);
      _findings['automatic_http_failure_capture'] = {
        'acceptance': 'not instrumented in existing Dart HTTP wrapper',
        'synthetic_response_code': 500,
        'captured_events': transport.events.length,
        'server_clock_still_updated': true,
        'native_platform_network_capture_tested': false,
      };
      client.close();
      await Sentry.close();
    },
  );
}
