// Real native UI and local API with a scoped HTTP 503 outage. No date/clock
// changes. This is HTTP retry evidence, not physical Wi-Fi/airplane-mode proof.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/notification_service.dart';

import 'support/e2e.dart';
import 'support/local_proxy.dart';

Future<Map<String, dynamic>> _profile(String owner) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,'
  'coalesce(w.lifetime_points,0) as exam_points,coalesce(w.coins,0) as exam_coins '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(owner)}',
))!;

void main() {
  initE2e();
  testWidgets(
    'u · HTTP outage persists abandon intent and recovery commits it once',
    (tester) async {
      final exams = ExamService.instance;
      ApiAccount? account;
      String? uuid;
      try {
        await setLocalHttpProxyAvailable(true);
        account = await openShellWithNewAccount(
          tester,
          'exam-http-${DateTime.now().microsecondsSinceEpoch}',
          name: 'QA HTTP Deneme',
        );
        final owner = account.id;
        await NotificationService.instance.setEnabled(false);
        final initialEconomy = await _profile(owner);
        expect(initialEconomy, {
          'total_minutes': 0,
          'lifetime_points': 0,
          'coins': 0,
          'exam_points': 0,
          'exam_coins': 0,
        });
        await openTab(tester, 4);
        await pumpUntilTrue(
          tester,
          () => exams.catalog.available,
          reason: 'proxy forwards real catalogue',
        );
        await tapOn(tester, find.byKey(const ValueKey('exam-start-tyt')));
        await pumpUntil(tester, find.text(trL10n.examRulesTitle));
        await tapOn(
          tester,
          find.widgetWithText(FilledButton, trL10n.examReady),
        );
        await pumpUntilTrue(
          tester,
          () => exams.activeRecord?.attempt != null,
          reason: 'real server-started TYT',
        );
        final attempt = exams.activeRecord!.attempt!;
        uuid = attempt.clientUuid;
        expect(attempt.durationSeconds, 9900);
        expect(
          attempt.endsAt.difference(attempt.startedAt),
          const Duration(minutes: 165),
        );

        await setLocalHttpProxyAvailable(false);
        await tapOn(
          tester,
          find.widgetWithText(TextButton, trL10n.examAbandon),
        );
        await pumpUntil(tester, find.text(trL10n.examAbandonTitle));
        await tapOn(
          tester,
          find.widgetWithText(FilledButton, trL10n.examAbandon),
        );
        await pumpUntilTrue(
          tester,
          () =>
              exams.activeRecord?.pendingAction == ExamPendingAction.abandon &&
              !exams.busy,
          reason: 'HTTP503 leaves durable abandon pending',
        );
        await pumpFor(tester, const Duration(seconds: 3));
        final pending = (await ExamPersistence().read(owner)).single;
        expect(pending.clientUuid, uuid);
        expect(pending.pendingAction, ExamPendingAction.abandon);
        expect(pending.attempt!.status, ExamAttemptStatus.active);
        expect(exams.blocksOtherSessions.value, isTrue);
        final remoteBefore = (await E2eHost.rows(
          'select id::text,status,points_earned,exam_coins_earned from public.exam_attempts '
          'where user_id=${sqlText(owner)}',
        )).single;
        expect(remoteBefore, {
          'id': attempt.id,
          'status': 'active',
          'points_earned': 0,
          'exam_coins_earned': 0,
        });
        expect(await _profile(owner), initialEconomy);
        await E2eHost.screenshot(tester, 'e2e-exam-http-abandon-pending');

        await setLocalHttpProxyAvailable(true);
        await exams.sync();
        await exams.refresh();
        await pumpUntilTrue(
          tester,
          () =>
              exams.activeRecord == null &&
              exams.attempts.single.status == ExamAttemptStatus.abandoned,
          reason: 'recovery commits queued abandon',
        );
        final finalRecord = (await ExamPersistence().read(owner)).single;
        expect(finalRecord.pendingAction, isNull);
        expect(finalRecord.attempt!.id, attempt.id);
        expect(finalRecord.attempt!.status, ExamAttemptStatus.abandoned);
        expect(exams.blocksOtherSessions.value, isFalse);
        final duplicate =
            await LocalApi.rpc('abandon_exam_attempt', account, {
                  'p_attempt_id': attempt.id,
                })
                as Map;
        expect(duplicate['duplicate'], isTrue);
        await exams.sync();
        final remoteAfter = await E2eHost.rows(
          'select id::text,status,points_earned,exam_coins_earned from public.exam_attempts '
          'where user_id=${sqlText(owner)}',
        );
        expect(remoteAfter, [
          {
            'id': attempt.id,
            'status': 'abandoned',
            'points_earned': 0,
            'exam_coins_earned': 0,
          },
        ]);
        expect(await _profile(owner), initialEconomy);
        expect(tester.takeException(), isNull);
        await E2eHost.screenshot(tester, 'e2e-exam-http-abandon-recovered');
        debugPrint(
          '[EXAM_HTTP_RECOVERY] PASS durable pending -> one abandoned row; all rewards/time remain zero',
        );
      } finally {
        await setLocalHttpProxyAvailable(true);
        if (account != null &&
            uuid != null &&
            exams.backend.ownerId == account.id &&
            exams.activeRecord?.clientUuid == uuid) {
          await exams.abandon(uuid);
        }
      }
    },
    skip: !kE2eHttpProxy,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
