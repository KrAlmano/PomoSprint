import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/marathon_presence.dart';
import 'package:pomodoro/services/session_queue.dart';

void main() {
  const plan = 'af091f18-1d45-4e82-9377-d55b92753c2c';
  const previous = '765568ce-7d8b-42be-85e8-761b4d5bf32a';
  const next = 'b65568ce-7d8b-42be-85e8-761b4d5bf32a';
  final breakEnd = DateTime.utc(2026, 10, 7, 10, 5);
  final deadline = breakEnd.add(const Duration(minutes: 1));
  final confirmedAt = breakEnd.add(const Duration(seconds: 30));
  late bool current;
  late DateTime now;
  late List<String> calls;
  late Map<String, dynamic> gate;
  late Map<String, dynamic> receipt;
  late Future<Object?> Function(String, Map<String, dynamic>) rpc;

  Future<bool> confirm() => requestMarathonPresence(
    marathonUuid: plan,
    completedSessionIndex: 1,
    previousClientUuid: previous,
    nextClientUuid: next,
    rpc: (name, params) async {
      calls.add(name);
      return rpc(name, params);
    },
    isCurrent: () => current,
    serverNow: () => now,
  );

  setUp(() {
    current = true;
    now = confirmedAt.add(const Duration(seconds: 1));
    calls = [];
    gate = {
      'break_ends_at': breakEnd.toIso8601String(),
      'confirmation_deadline': deadline.toIso8601String(),
    };
    receipt = {
      ...gate,
      'confirmed': true,
      'confirmed_at': confirmedAt.toIso8601String(),
      'next_client_uuid': next,
    };
    rpc = (name, params) async =>
        name == 'start_marathon_break' ? gate : receipt;
  });

  test(
    'old, missing, malformed, and relaxed server policies stay disabled',
    () {
      const config = {
        'available': true,
        'break_seconds': 300,
        'presence_required': true,
        'presence_seconds': 60,
        'presence_start_grace_seconds': 10,
      };
      expect(supportsMarathonPresence(config), isTrue);
      expect(supportsMarathonPresence(null), isFalse);
      for (final key in config.keys) {
        expect(
          supportsMarathonPresence({...config}..remove(key)),
          isFalse,
          reason: key,
        );
      }
      for (final change in [
        {'presence_required': false},
        {'presence_seconds': 600},
        {'presence_seconds': '60'},
        {'presence_start_grace_seconds': 60},
        {'break_seconds': 3},
      ]) {
        expect(supportsMarathonPresence({...config, ...change}), isFalse);
      }
    },
  );

  test(
    'confirmed receipt binds precisely the requested next session UUID',
    () async {
      rpc = (name, params) async {
        if (name == 'start_marathon_break') {
          expect(params, {
            'p_marathon_uuid': plan,
            'p_completed_session_index': 1,
            'p_previous_client_uuid': previous,
          });
          return gate;
        }
        expect(params, {
          'p_marathon_uuid': plan,
          'p_next_session_index': 2,
          'p_next_client_uuid': next,
        });
        return receipt;
      };
      expect(await confirm(), isTrue);
      expect(calls, ['start_marathon_break', 'confirm_marathon_presence']);
    },
  );

  test(
    'account switch during gate read never sends confirmation for new owner',
    () async {
      final response = Completer<Object?>();
      rpc = (_, _) => response.future;
      final pending = confirm();
      current = false;
      response.complete(gate);
      expect(await pending, isFalse);
      expect(calls, ['start_marathon_break']);
    },
  );

  test(
    'account switch during confirmation ignores old successful response',
    () async {
      rpc = (name, _) async {
        if (name == 'start_marathon_break') return gate;
        current = false;
        return receipt;
      };
      expect(await confirm(), isFalse);
    },
  );

  test(
    'server denial never becomes an optimistic successful confirmation',
    () async {
      receipt = {'error': 'marathon_presence_expired'};
      expect(await confirm(), isFalse);
      gate = {'error': 'marathon_missing_previous'};
      calls.clear();
      expect(await confirm(), isFalse);
      expect(calls, ['start_marathon_break']);
    },
  );

  test(
    'malformed, foreign, and window-renewing receipts cannot start study',
    () async {
      final original = {...receipt};
      for (final change in <Map<String, dynamic>>[
        {'confirmed': false},
        {'confirmed': 'true'},
        {'confirmed_at': null},
        {'confirmed_at': 'invalid'},
        {
          'confirmed_at': breakEnd
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        },
        {'confirmed_at': deadline.toIso8601String()},
        {'next_client_uuid': previous},
        {
          'confirmation_deadline': deadline
              .add(const Duration(minutes: 1))
              .toIso8601String(),
        },
        {
          'break_ends_at': breakEnd
              .add(const Duration(seconds: 1))
              .toIso8601String(),
        },
      ]) {
        receipt = {...original, ...change};
        expect(await confirm(), isFalse, reason: '$change');
      }
    },
  );

  test('late receipt or expired window cannot revive a stopped plan', () async {
    now = confirmedAt.add(const Duration(seconds: 11));
    expect(await confirm(), isFalse);
    now = deadline;
    expect(await confirm(), isFalse);
    now = confirmedAt.subtract(const Duration(seconds: 3));
    expect(await confirm(), isFalse);
  });

  test(
    'network errors propagate for UI retry without fabricating a receipt',
    () async {
      rpc = (_, _) => Future.error(TimeoutException('local fixture'));
      await expectLater(confirm(), throwsA(isA<TimeoutException>()));
    },
  );

  test(
    'invalid presence keeps individual study result and disables marathon bonus',
    () {
      final saved = SessionSubmitSuccess.fromResponse({
        'total_points': 5,
        'coins_earned': 20,
        'marathon_presence_invalid': true,
        'marathon_bonus_points': 0,
      }, minutes: 25);
      expect(saved.minutes, 25);
      expect(saved.totalPoints, 5);
      expect(saved.coinsEarned, 20);
      expect(saved.marathonInvalid, isTrue);
      expect(saved.marathonBonusPoints, 0);
      expect(
        SessionSubmitSuccess.fromResponse({}, minutes: 25).marathonInvalid,
        isFalse,
      );
    },
  );

  test('immutable completion window converts server to device clock', () {
    final response = {
      'marathon_break_ends_at': breakEnd.toIso8601String(),
      'marathon_confirmation_deadline': deadline.toIso8601String(),
      'duplicate': true,
    };
    final result = SessionSubmitSuccess.fromResponse(
      response,
      minutes: 25,
      clockOffset: const Duration(seconds: 13),
    );
    expect(result.duplicate, isTrue);
    expect(
      result.marathonBreakEndsAt?.toUtc(),
      breakEnd.subtract(const Duration(seconds: 13)),
    );
    expect(
      result.marathonConfirmationDeadline?.toUtc(),
      deadline.subtract(const Duration(seconds: 13)),
    );
    for (final invalid in ['2026-10-07T10:05:00', 'invalid', 123, null]) {
      final malformed = SessionSubmitSuccess.fromResponse({
        'marathon_break_ends_at': invalid,
      }, minutes: 25);
      expect(malformed.marathonBreakEndsAt, isNull);
    }
  });
}
