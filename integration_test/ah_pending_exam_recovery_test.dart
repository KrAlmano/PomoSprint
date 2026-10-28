// Exact-owner, no-reset recovery of an already persisted local short exam.
// This never changes clocks/catalogues/dates or completes an exam via SQL.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

const _owner = String.fromEnvironment('E2E_RECOVERY_OWNER');
const _attemptId = String.fromEnvironment('E2E_RECOVERY_ATTEMPT');
const _email = String.fromEnvironment('E2E_RECOVERY_EMAIL');

Future<Map<String, dynamic>> _wallet() async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,p.current_streak,'
  'coalesce(w.lifetime_points,0) as exam_points,coalesce(w.coins,0) as exam_coins '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(_owner)}',
))!;

Future<String> _otherHistoryDigest() async =>
    (await E2eHost.row(
          'select md5(coalesce(jsonb_agg(to_jsonb(a) order by a.id)::text,\'[]\')) as digest '
          'from public.exam_attempts a where user_id=${sqlText(_owner)} '
          'and id<>${sqlText(_attemptId)}',
        ))!['digest']
        as String;

void main() {
  initE2e();
  testWidgets(
    'ah · exact persisted short YDT naturally recovers without reset',
    (tester) async {
      final uuid = RegExp(r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$');
      expect(uuid.hasMatch(_owner), isTrue);
      expect(uuid.hasMatch(_attemptId), isTrue);
      expect(
        RegExp(
          r'^e2e-sim-verify-short-[a-z0-9-]+@pomosprint\.local$',
        ).hasMatch(_email),
        isTrue,
      );
      final identity = (await E2eHost.row(
        'select email=${sqlText(_email)} as exact_owner,'
        "created_at>now()-interval '2 hours' as recent "
        'from auth.users where id=${sqlText(_owner)}',
      ))!;
      expect(identity, {'exact_owner': true, 'recent': true});
      final disk = await ExamPersistence().read(_owner);
      final original = disk.singleWhere((r) => r.attempt?.id == _attemptId);
      expect(original.pendingAction, ExamPendingAction.complete);
      expect(original.errorCode, 'exam_not_elapsed');
      expect(original.attempt!.examId, 'ydt');
      expect(original.attempt!.durationSeconds, 60);
      expect(original.attempt!.status, ExamAttemptStatus.active);
      expect(original.attempt!.endsAt.isBefore(DateTime.now()), isTrue);
      final started = original.attempt!.startedAt;
      final end = original.attempt!.endsAt;
      final row = (await E2eHost.row(
        'select status,started_at,ends_at,definition->>\'duration_seconds\' as seconds,'
        'definition->>\'reward_points\' as points,definition->>\'reward_coins\' as coins '
        'from public.exam_attempts where id=${sqlText(_attemptId)} and user_id=${sqlText(_owner)}',
      ))!;
      expect(row['status'], 'active');
      expect(row['seconds'], '60');
      expect(row['points'], '0');
      expect(row['coins'], '0');
      expect(DateTime.parse(row['started_at'] as String), started);
      expect(DateTime.parse(row['ends_at'] as String), end);
      final baseline = await _wallet();
      final others = await _otherHistoryDigest();
      expect(
        (await E2eHost.row(
          'select count(*)::integer as n from public.competition_events '
          'where kind=\'exam\' and source_id=${sqlText(_attemptId)}',
        ))!['n'],
        0,
      );
      // Restore the actual application and its existing SDK session/journal.
      // No sign-in replacement, resetAppState, preference write, forced RPC or
      // client clock adjustment occurs before the app accepts the pending row.
      await launchApp(tester);
      await pumpUntil(tester, find.byType(MainNavigationShell));
      expect(SupabaseService.instance.currentUser.value?.id, _owner);
      expect(Supabase.instance.client.auth.currentUser?.id, _owner);
      await openTab(tester, 4);
      await pumpUntil(tester, find.byType(ExamScreen));
      final service = ExamService.instance;
      await pumpUntilTrue(
        tester,
        () => service.attempts.any((a) => a.id == _attemptId && a.isCompleted),
        timeout: const Duration(seconds: 90),
        reason:
            'App refresh/sync retries the original pending natural60 attempt',
      );
      final accepted = service.attempts.singleWhere((a) => a.id == _attemptId);
      expect(accepted.clientUuid, original.clientUuid);
      expect(accepted.startedAt, started);
      expect(accepted.endsAt, end);
      expect(accepted.completedAt, end);
      expect(accepted.durationSeconds, 60);
      expect(accepted.pointsEarned, 0);
      expect(accepted.examCoinsEarned, 0);
      final persisted = (await ExamPersistence().read(
        _owner,
      )).singleWhere((r) => r.clientUuid == original.clientUuid);
      expect(persisted.pendingAction, isNull);
      expect(persisted.attempt!.isCompleted, isTrue);
      final after = await _wallet();
      expect(after, {
        ...baseline,
        'total_minutes': (baseline['total_minutes'] as int) + 1,
      });
      expect(await _otherHistoryDigest(), others);
      final acceptedRow = (await E2eHost.row(
        'select status,elapsed_seconds,points_earned,exam_coins_earned,'
        '(select count(*)::integer from public.competition_events where kind=\'exam\' '
        'and source_id=a.id) as events '
        'from public.exam_attempts a where a.id=${sqlText(_attemptId)} and user_id=${sqlText(_owner)}',
      ))!;
      expect(acceptedRow, {
        'status': 'completed',
        'elapsed_seconds': 60,
        'points_earned': 0,
        'exam_coins_earned': 0,
        'events': 1,
      });
      final account = ApiAccount(
        _owner,
        _email,
        Supabase.instance.client.auth.currentSession!.accessToken,
      );
      final duplicate =
          await LocalApi.rpc('complete_exam_attempt', account, {
                'p_attempt_id': _attemptId,
              })
              as Map;
      expect(duplicate['duplicate'], isTrue);
      expect(await _wallet(), after);
      await E2eHost.screenshot(tester, 'e2e-ah-android-ydt-recovered');
      expect(tester.takeException(), isNull);
      debugPrint(
        '[AD_PENDING_RECOVERY] ${jsonEncode({'owner': _owner, 'attempt_id': _attemptId, 'client_uuid': original.clientUuid, 'started_at': started.toIso8601String(), 'ends_at': end.toIso8601String(), 'completed': true, 'pending_action': null, 'new_events': 1, 'other_history_unchanged': true, 'reset': false, 'economy': after})}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
