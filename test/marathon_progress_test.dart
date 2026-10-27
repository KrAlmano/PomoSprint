import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _marathonUuid = 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  final start = DateTime(2026, 10, 7, 10);

  ActiveTimerSession focus({
    String uuid = 'marathon-focus-1',
    int minutes = 25,
    bool quick = false,
  }) => ActiveTimerSession.start(
    clientUuid: uuid,
    categoryId: 'category-1',
    categoryName: 'Matematik',
    categoryColorHex: '#FF4040',
    durationMinutes: minutes,
    totalSeconds: timerDurationSeconds(minutes, quick: quick),
    now: start,
    marathon: const MarathonProgress(
      totalSessions: 3,
      marathonUuid: _marathonUuid,
    ),
  );

  test('2, 3 ve 4 odaklık planlar yalnız son odaktan sonra biter', () {
    for (final count in [2, 3, 4]) {
      var progress = MarathonProgress(
        totalSessions: count,
        marathonUuid: _marathonUuid,
      );
      expect(progress.currentSession, 1);
      for (var completed = 1; completed <= count; completed++) {
        final saving = progress.beginCompletion();
        expect(
          saving.completedSessions,
          completed - 1,
          reason: 'Gönderim başlarken çalışma sayısı artmaz',
        );
        expect(saving.phase, MarathonPhase.completing);
        progress = saving.finishFocus(start);
        expect(progress.completedSessions, completed);
        expect(progress.marathonUuid, _marathonUuid);
        if (completed < count) {
          expect(progress.isOnBreak, isTrue);
          expect(progress.isFinished, isFalse);
          expect(progress.breakEndsAt, start.add(const Duration(minutes: 5)));
          progress = progress.nextFocus();
          expect(progress.currentSession, completed + 1);
          expect(
            progress.completedSessions,
            completed,
            reason: 'Mola ilerlemeyi değiştirmez',
          );
          expect(progress.phase, MarathonPhase.focus);
          expect(progress.breakEndsAt, isNull);
        } else {
          expect(progress.isFinished, isTrue);
          expect(progress.isOnBreak, isFalse);
          expect(
            progress.breakEndsAt,
            isNull,
            reason: 'Son odaktan sonra gereksiz mola başlamaz',
          );
        }
      }
    }
  });

  test(
    'mola bitiş zamanı tek kaynaktır; sınır ve yeniden açılışta negatif süre gösterilmez',
    () {
      final progress = const MarathonProgress(
        totalSessions: 2,
        marathonUuid: _marathonUuid,
      ).beginCompletion().finishFocus(start);
      expect(progress.breakRemainingAt(start), 300);
      expect(
        progress.breakRemainingAt(start.add(const Duration(milliseconds: 500))),
        300,
      );
      expect(
        progress.breakRemainingAt(start.add(const Duration(seconds: 299))),
        1,
      );
      expect(
        progress.breakRemainingAt(start.add(const Duration(minutes: 5))),
        0,
      );
      expect(progress.breakRemainingAt(start.add(const Duration(days: 2))), 0);
      expect(
        progress.breakRemainingAt(start.subtract(const Duration(minutes: 1))),
        300,
      );
      expect(
        const MarathonProgress(
          totalSessions: 2,
          marathonUuid: _marathonUuid,
        ).breakRemainingAt(start),
        0,
      );
    },
  );

  test(
    'mola sonrası onay penceresi bitiş çıpasından 60 saniyedir; erken/geç onay yoktur',
    () {
      final resting = const MarathonProgress(
        totalSessions: 4,
        marathonUuid: _marathonUuid,
      ).beginCompletion().finishFocus(start);
      final waiting = resting.beginPresenceCheck();
      final breakEnd = start.add(const Duration(minutes: 5));
      expect(waiting.completedSessions, 1);
      expect(waiting.isOnBreak, isFalse);
      expect(waiting.isAwaitingPresence, isTrue);
      expect(waiting.isResting, isTrue);
      expect(waiting.presenceDeadline, start.add(const Duration(minutes: 6)));
      expect(
        waiting.canConfirmPresenceAt(
          breakEnd.subtract(const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
      expect(waiting.canConfirmPresenceAt(breakEnd), isTrue);
      expect(waiting.presenceRemainingAt(breakEnd), 60);
      expect(
        waiting.presenceRemainingAt(
          breakEnd.add(const Duration(seconds: 59, milliseconds: 999)),
        ),
        1,
      );
      expect(
        waiting.canConfirmPresenceAt(
          breakEnd.add(const Duration(seconds: 59, milliseconds: 999)),
        ),
        isTrue,
      );
      expect(
        waiting.canConfirmPresenceAt(breakEnd.add(const Duration(minutes: 1))),
        isFalse,
      );
      expect(
        waiting.isPresenceExpiredAt(breakEnd.add(const Duration(minutes: 1))),
        isTrue,
      );
      expect(
        waiting.presenceRemainingAt(breakEnd.add(const Duration(days: 1))),
        0,
      );
      expect(
        waiting.withStopRequested().canConfirmPresenceAt(breakEnd),
        isFalse,
      );
      final restored = MarathonProgress.fromJson(
        jsonDecode(jsonEncode(waiting.toJson())),
      )!;
      expect(restored.presenceDeadline, waiting.presenceDeadline);
      expect(
        restored.beginPresenceCheck().presenceDeadline,
        waiting.presenceDeadline,
      );
      expect(
        restored.canConfirmPresenceAt(
          breakEnd.add(const Duration(seconds: 30)),
        ),
        isTrue,
      );
      expect(
        restored.completedSessions,
        1,
        reason: 'Onay beklemek çalışma/seans sayısını artırmaz',
      );
      final session = focus().withMarathon(restored);
      expect(
        session.isRunning,
        isFalse,
        reason: 'Eski odak endsAt bilgisi onay süresini çalışan seans yapmaz',
      );
      const nextUuid = 'ccccccc1-cccc-4ccc-8ccc-cccccccccccc';
      final candidate = restored.withPresenceCandidate(nextUuid);
      final reloadedCandidate = MarathonProgress.fromJson(candidate.toJson())!;
      expect(reloadedCandidate.presenceClientUuid, nextUuid);
      expect(
        reloadedCandidate.withStopRequested().presenceClientUuid,
        nextUuid,
      );
      expect(
        reloadedCandidate.beginPresenceCheck().presenceClientUuid,
        nextUuid,
      );
      expect(reloadedCandidate.presenceDeadline, waiting.presenceDeadline);
      expect(reloadedCandidate.nextFocus().presenceClientUuid, isNull);
    },
  );

  test(
    'odak, gönderiliyor, mola ve bitmiş plan JSON ile kayıpsız geri yüklenir',
    () {
      const first = MarathonProgress(
        totalSessions: 2,
        marathonUuid: _marathonUuid,
      );
      final saving = first.beginCompletion();
      final resting = saving.finishFocus(start);
      final finished = resting.nextFocus().beginCompletion().finishFocus(start);
      for (final expected in [
        first,
        saving,
        resting,
        resting.beginPresenceCheck(),
        finished,
      ]) {
        final restored = MarathonProgress.fromJson(
          jsonDecode(jsonEncode(expected.toJson())),
        )!;
        expect(restored.totalSessions, expected.totalSessions);
        expect(restored.marathonUuid, _marathonUuid);
        expect(restored.sessionIndex, expected.currentSession);
        expect(restored.completedSessions, expected.completedSessions);
        expect(restored.phase, expected.phase);
        expect(restored.breakEndsAt, expected.breakEndsAt);
        expect(restored.breakSeconds, 300);
      }
    },
  );

  test(
    'duraklatma/devam ve ön plan kaydı planı, kimliği ve 25/50 dk süreyi korur',
    () {
      for (final minutes in [25, 50]) {
        final active = focus(minutes: minutes);
        final paused = active
            .pauseAt(start.add(const Duration(minutes: 1)))
            .withForegroundSeconds(42);
        final resumed = paused.resumeAt(start.add(const Duration(minutes: 10)));
        final restored = ActiveTimerSession.fromJson(
          jsonDecode(jsonEncode(resumed.toJson())),
        )!;
        expect(restored.clientUuid, active.clientUuid);
        expect(restored.startedAt, active.startedAt);
        expect(restored.durationMinutes, minutes);
        expect(restored.pauseUsedCount, 1);
        expect(restored.foregroundSeconds, 42);
        expect(restored.marathon?.totalSessions, 3);
        expect(restored.marathon?.completedSessions, 0);
        expect(restored.categoryColorHex, '#FF4040');
      }
    },
  );

  test(
    'gönderiliyor kaydı aynı odak UUID ile yeniden denenebilir; mola kaydı ödül kimliği üretmez',
    () {
      final active = focus();
      final saving = active.withMarathon(active.marathon!.beginCompletion());
      final restored = ActiveTimerSession.fromJson(saving.toJson())!;
      expect(restored.clientUuid, 'marathon-focus-1');
      expect(restored.marathon?.phase, MarathonPhase.completing);
      expect(restored.marathon?.completedSessions, 0);

      final resting = restored.withMarathon(
        restored.marathon!.finishFocus(start),
      );
      final reopened = ActiveTimerSession.fromJson(resting.toJson())!;
      expect(reopened.clientUuid, active.clientUuid);
      expect(reopened.marathon?.phase, MarathonPhase.breakTime);
      expect(reopened.marathon?.completedSessions, 1);
    },
  );

  test(
    'hızlı Maraton odakları normal hızlı sayaçla aynı kaydetmeme sınırını korur',
    () {
      for (final minutes in [25, 50]) {
        final shortened = focus(minutes: minutes, quick: true);
        expect(shortened.isQuickTest, isTrue);
        expect(shortened.recordAccelerated, isFalse);
        expect(shortened.durationMinutes, minutes);
        expect(shortened.totalSeconds, minutes == 25 ? 5 : 10);
        expect(
          ActiveTimerSession.fromJson(shortened.toJson())?.recordAccelerated,
          isFalse,
        );
      }
    },
  );

  test(
    'sunucudan gelen bonus sonucu ve bekleyen durum plan yeniden açılınca korunur',
    () {
      final base =
          const MarathonProgress(totalSessions: 2, marathonUuid: _marathonUuid)
              .beginCompletion()
              .finishFocus(start)
              .nextFocus()
              .beginCompletion()
              .finishFocus(start);
      for (final expected in [
        base.withBonusResult(points: 7, pending: false),
        base.withBonusResult(points: 0, pending: true),
      ]) {
        final reopened = MarathonProgress.fromJson(
          jsonDecode(jsonEncode(expected.toJson())),
        )!;
        expect(reopened.marathonUuid, _marathonUuid);
        expect(reopened.completedSessions, 2);
        expect(reopened.isFinished, isTrue);
        expect(reopened.awardedBonusPoints, expected.awardedBonusPoints);
        expect(reopened.bonusPending, expected.bonusPending);
      }
    },
  );

  test(
    'kayıt beklerken durdurma isteği JSON ve tekrar gönderim boyunca korunur',
    () {
      final stopped = const MarathonProgress(
        totalSessions: 3,
        marathonUuid: _marathonUuid,
      ).beginCompletion().withStopRequested();
      final reopened = MarathonProgress.fromJson(
        jsonDecode(jsonEncode(stopped.toJson())),
      )!;
      expect(reopened.stopRequested, isTrue);
      expect(reopened.beginCompletion().stopRequested, isTrue);
      expect(reopened.finishFocus(start).stopRequested, isTrue);
      expect(
        reopened.withBonusResult(points: 0, pending: true).stopRequested,
        isTrue,
      );
      expect(
        reopened.completedSessions,
        0,
        reason: 'Stop intent does not fabricate a saved focus',
      );
      expect(reopened.marathonUuid, _marathonUuid);
    },
  );

  test(
    'bozuk, tanınmayan veya olanaksız plan JSON kayıtları güvenle reddedilir',
    () {
      final valid = const MarathonProgress(
        totalSessions: 3,
        marathonUuid: _marathonUuid,
      ).toJson();
      final invalid = <Object?>[
        null,
        'broken',
        <String, Object?>{},
        {...valid, 'total_sessions': 1},
        {...valid, 'total_sessions': 5},
        {...valid, 'total_sessions': '3'},
        {...valid, 'completed_sessions': -1},
        {...valid, 'completed_sessions': 4},
        {...valid, 'completed_sessions': 3},
        {...valid, 'phase': 'unknown'},
        {...valid, 'presence_client_uuid': 'invalid'},
        {...valid, 'presence_client_uuid': 1},
        {...valid, 'marathon_uuid': ''},
        {...valid, 'marathon_uuid': 'invalid'},
        {...valid, 'marathon_uuid': null},
        {...valid, 'phase': 'finished'},
        {...valid, 'phase': 'completing', 'completed_sessions': 3},
        {...valid, 'phase': 'breakTime', 'completed_sessions': 1},
        {...valid, 'phase': 'awaitingPresence', 'completed_sessions': 1},
        {
          ...valid,
          'phase': 'breakTime',
          'completed_sessions': 1,
          'break_ends_at': 'invalid',
        },
        {
          ...valid,
          'phase': 'breakTime',
          'completed_sessions': 0,
          'break_ends_at': start.toIso8601String(),
        },
        {
          ...valid,
          'phase': 'breakTime',
          'completed_sessions': 3,
          'break_ends_at': start.toIso8601String(),
        },
        {...valid, 'break_seconds': 0},
        {...valid, 'break_seconds': 301},
        {...valid, 'break_seconds': '300'},
      ];
      for (final payload in invalid) {
        expect(MarathonProgress.fromJson(payload), isNull, reason: '$payload');
      }
      // Eski tek-seans kayıtları ve geçerli odak bilgisi bozulmuş bir plan
      // yüzünden kaybolmaz; yalnız plan uzantısı kullanılamaz olur.
      final oldRecord = focus().toJson()..remove('marathon');
      expect(ActiveTimerSession.fromJson(oldRecord)?.marathon, isNull);
      final damagedPlan = focus().toJson()
        ..['marathon'] = {'total_sessions': 999};
      expect(
        ActiveTimerSession.fromJson(damagedPlan)?.clientUuid,
        'marathon-focus-1',
      );
      expect(ActiveTimerSession.fromJson(damagedPlan)?.marathon, isNull);
    },
  );

  test(
    'plan aynı kullanıcı kaydındadır; silinen hesap geri yazamaz ve başka hesabın planı korunur',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = TimerPersistence.instance;
      const firstOwner = 'marathon-retired-owner';
      const otherOwner = 'marathon-other-owner';
      await store.save(firstOwner, focus());
      await store.save(otherOwner, focus(uuid: 'other-focus'));
      expect((await store.load(firstOwner))?.marathon?.totalSessions, 3);
      expect(await store.load('unrelated-owner'), isNull);
      await store.retireOwner(firstOwner);
      await store.save(firstOwner, focus(uuid: 'late-dispose-write'));
      expect(
        await store.load(firstOwner),
        isNull,
        reason: 'Dispose silinen hesabın planını geri yazamaz',
      );
      expect((await store.load(otherOwner))?.clientUuid, 'other-focus');
      expect((await store.load(otherOwner))?.marathon?.totalSessions, 3);
    },
  );
}
