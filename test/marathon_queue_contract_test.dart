import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/session_queue.dart';

void main() {
  const planId = 'cf091f18-1d45-4e82-9377-d55b92753c2c';
  final entry = PendingSession(
    clientUuid: '765568ce-7d8b-42be-85e8-761b4d5bf32a',
    categoryId: '2',
    categoryName: 'Matematik',
    minutes: 50,
    wasPaused: false,
    foregroundSeconds: 10,
    startedAt: DateTime.utc(2026, 10, 7, 9),
    queuedAt: DateTime.utc(2026, 10, 7, 9, 50),
    recordAccelerated: true,
    marathonUuid: planId,
    marathonTargetSessions: 4,
    marathonSessionIndex: 3,
  );

  test('outbox disk restore and category remap retain the marathon identity', () {
    final restored = PendingSession.fromJson(entry.toJson())!;
    final remapped = restored.copyWith(categoryId: '6407a27f-78bd-413c-99d9-4f45cec15c7a', categoryRemaps: 1);
    expect(remapped.isMarathon, isTrue);
    expect(remapped.marathonUuid, planId);
    expect(remapped.marathonTargetSessions, 4);
    expect(remapped.marathonSessionIndex, 3);
    expect(remapped.recordAccelerated, isTrue);
    expect(remapped.clientUuid, entry.clientUuid);
    expect(remapped.startedAt, entry.startedAt);
  });

  test('legacy standalone sessions remain standalone', () {
    final json = entry.toJson()
      ..remove('marathon_uuid')
      ..remove('marathon_target_sessions')
      ..remove('marathon_session_index');
    expect(PendingSession.fromJson(json)!.isMarathon, isFalse);
  });

  test('corrupt plan metadata cannot silently lose the bonus', () {
    for (final change in <Map<String, Object?>>[
      {'marathon_uuid': ''},
      {'marathon_uuid': 'not-a-uuid'},
      {'marathon_target_sessions': 5},
      {'marathon_target_sessions': 1},
      {'marathon_session_index': 0},
      {'marathon_session_index': 5},
      {'marathon_session_index': '3'},
      {'marathon_target_sessions': null},
    ]) {
      expect(PendingSession.fromJson({...entry.toJson(), ...change}), isNull, reason: '$change');
    }
    final incomplete = entry.toJson()..remove('marathon_session_index');
    expect(PendingSession.fromJson(incomplete), isNull);
  });

  test('confirmed bonus is read from server without deriving it from duration', () {
    final result = SessionSubmitSuccess.fromResponse({
      'base_points': 12,
      'bonus_points': 10,
      'total_points': 22,
      'marathon_bonus_points': 10,
      'coins_earned': 20,
      'duplicate': false,
    }, minutes: 50);
    expect(result.marathonBonusPoints, 10);
    expect(result.totalPoints, 22);
    expect(result.coinsEarned, 20);
    expect(SessionSubmitSuccess.fromResponse({'total_points': 12}, minutes: 50).marathonBonusPoints, 0);
  });

  test('duplicate completion retains the server bonus while marking no new award', () {
    final result = SessionSubmitSuccess.fromResponse({
      'total_points': 17,
      'marathon_bonus_points': 5,
      'duplicate': true,
      'coins_earned': 0,
    }, minutes: 25);
    expect(result.duplicate, isTrue);
    expect(result.marathonBonusPoints, 5);
    expect(result.coinsEarned, 0);
  });
}
