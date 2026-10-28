import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_details.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DetailsExamBackend backend;
  late ExamService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = DetailsExamBackend();
    service = ExamService(backend: backend, createUuid: () => 'active-uuid');
  });
  tearDown(() {
    service.dispose();
    backend.owner.dispose();
  });

  test(
    'actual/planned timing, details and terminal clock survive DTO and disk roundtrip',
    () async {
      final attempt = detailsCompletedAttempt(
        title: 'Deneme 1',
        note: 'Bir not\nİkinci satır',
        modules: ['science'],
      );
      expect(attempt.plannedSeconds, 10800);
      expect(attempt.actualSeconds, 5400);
      expect(attempt.reportMinutes, 90);
      expect(attempt.remainingSecondsAt(attempt.startedAt), 0);
      expect(attempt.selectedQuestionCount, 40);
      expect(
        ExamAttempt.fromJson(attempt.toJson())!.toJson(),
        attempt.toJson(),
      );
      final row = ExamLocalRecord(
        clientUuid: attempt.clientUuid,
        definition: attempt.definition!,
        createdAt: attempt.startedAt,
        attempt: attempt,
      );
      await service.persistence.write('owner-1', [row]);
      expect(
        (await service.persistence.read('owner-1')).single.attempt!.toJson(),
        attempt.toJson(),
      );
      expect(StatSession.fromExamAttempt(attempt)!.minutes, 90);
    },
  );
  test(
    'one real second is one completed attempt with zero report minutes, not a fake minute',
    () {
      final attempt = detailsCompletedAttempt(seconds: 1);
      final stat = StatSession.fromExamAttempt(attempt)!;
      expect(stat.minutes, 0);
      expect(attempt.actualSeconds, 1);
      expect(
        ExamAttempt.fromJson({
          ...attempt.toJson(),
          'duration_seconds': 0,
          'elapsed_seconds': 0,
        }),
        isNull,
      );
      expect(
        ExamAttempt.fromJson({...attempt.toJson(), 'credited_minutes': 1}),
        isNull,
      );
    },
  );
  test(
    'legacy AYT modules require exact IDs and quotas; capability absence remains closed',
    () {
      final ayt = offlineExamCatalog.byId('ayt')!;
      expect(ayt.effectiveModules.map((m) => m.id), [
        'turkish_social_1',
        'social_2',
        'mathematics',
        'science',
      ]);
      expect(
        ayt.effectiveModules.map(
          (m) => ayt.subjects
              .where((s) => m.subjectIds.contains(s.id))
              .fold<int>(0, (n, s) => n + s.questionCount),
        ),
        everyElement(40),
      );
      final bad = ayt.toJson();
      final subjects = (bad['subjects'] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
      subjects[0]['id'] = 'different';
      bad['subjects'] = subjects;
      expect(ExamDefinition.fromJson(bad)!.effectiveModules, isEmpty);
      final catalog = ExamCatalog.fromJson({
        'schema_version': 1,
        'available': true,
        'exams': [ayt.toJson()],
      })!;
      expect(catalog.capabilities.aytEarlyFinish, isFalse);
      expect(catalog.capabilities.details, isFalse);
    },
  );
  test(
    'Unicode scalar title/note limits and controls agree with server rules',
    () {
      expect(validExamText('🧠' * 120, title: true), isTrue);
      expect(validExamText('🧠' * 121, title: true), isFalse);
      expect(validExamText('line\nnext', title: true), isFalse);
      expect(validExamText('line\n\tnext', title: false), isTrue);
      for (final code in [0, 13, 127, 133, 159]) {
        expect(
          validExamText('a${String.fromCharCode(code)}b', title: false),
          isFalse,
        );
      }
      expect(validExamText('a\u2028b', title: true), isFalse);
      expect(ExamDetailsPatch({'note': null}).isValid, isTrue);
      expect(ExamDetailsPatch({'selected_module_ids': null}).isValid, isFalse);
    },
  );
  test(
    'early ACK uses server time/reward and releases planned overlap; legacy is gated',
    () async {
      await service.initialize();
      await service.start(service.catalog.byId('ayt')!);
      backend.clock = backend.clock.add(const Duration(minutes: 90));
      await service.finishEarly('active-uuid');
      final result = service.attempts.single;
      expect(result.actualSeconds, 5400);
      expect(result.plannedSeconds, 10800);
      expect(result.pointsEarned, 18);
      expect(result.examCoinsEarned, 72);
      expect(service.blocksOtherSessions.value, isFalse);
      expect(backend.calls.singleWhere((c) => c.$1 == 'finish_ayt_early').$2, {
        'p_attempt_id': result.id,
      });
    },
  );
  test(
    'pending early is immutable, survives cold restart and accepts a later full receipt',
    () async {
      await service.initialize();
      await service.start(service.catalog.byId('ayt')!);
      backend.clock = backend.clock.add(const Duration(minutes: 45));
      backend.isAvailable = false;
      await service.finishEarly('active-uuid');
      expect(
        service.activeRecord!.pendingAction,
        ExamPendingAction.completeEarly,
      );
      expect(service.blocksOtherSessions.value, isTrue);
      await service.abandon('active-uuid');
      expect(
        service.activeRecord!.pendingAction,
        ExamPendingAction.completeEarly,
      );
      service.dispose();
      service = ExamService(backend: backend);
      await service.initialize();
      expect(
        service.activeRecord!.pendingAction,
        ExamPendingAction.completeEarly,
      );
      backend.clock = backend.clock.add(const Duration(hours: 4));
      backend.isAvailable = true;
      await service.refresh();
      expect(service.attempts.single.completionKind, ExamCompletionKind.full);
      expect(service.attempts.single.durationSeconds, 10800);
      expect(
        backend.calls.where((c) => c.$1 == 'complete_exam_attempt'),
        isEmpty,
      );
    },
  );
  test(
    'lost early ACK replays same request once; server definition takes precedence',
    () async {
      await service.initialize();
      await service.start(service.catalog.byId('ayt')!);
      backend.clock = backend.clock.add(const Duration(minutes: 90));
      var lost = true;
      backend.handler = (name, params) async {
        final response = backend.defaultRpc(name, params);
        if (name == 'finish_ayt_early' && lost) {
          lost = false;
          throw TimeoutException('lost ACK');
        }
        return response;
      };
      await service.finishEarly('active-uuid');
      expect(
        service.activeRecord!.pendingAction,
        ExamPendingAction.completeEarly,
      );
      await service.retry('active-uuid');
      expect(backend.acceptedEarly, 1);
      expect(service.activeRecord, isNull);
      expect(service.attempts.single.actualSeconds, 5400);
    },
  );
  test(
    'metadata-only save sends null results; omitted fields and earned values are preserved',
    () async {
      final a = detailsCompletedAttempt(note: 'preserve');
      backend.rows[a.clientUuid] = a;
      await service.initialize();
      await service.saveDetails(
        a,
        patch: ExamDetailsPatch({'title': 'My attempt'}),
        expectedRevision: 0,
      );
      final request = backend.calls
          .singleWhere((c) => c.$1 == 'save_exam_details')
          .$2;
      expect(request['p_subject_results'], isNull);
      expect(request['p_details'], {'title': 'My attempt'});
      expect(service.attempts.single.note, 'preserve');
      expect(service.attempts.single.detailsRevision, 1);
      expect(service.attempts.single.examCoinsEarned, a.examCoinsEarned);
      expect(backend.profileRefreshes, 0);
    },
  );
  test(
    'offline details payload cannot be mutated or replaced; clear null survives cold restore',
    () async {
      final a = detailsCompletedAttempt(note: 'clear');
      backend.rows[a.clientUuid] = a;
      await service.initialize();
      final modules = ['science'];
      final source = <String, Object?>{
        'note': null,
        'selected_module_ids': modules,
      };
      final patch = ExamDetailsPatch(source);
      backend.isAvailable = false;
      await service.saveDetails(a, patch: patch, expectedRevision: 0);
      source['note'] = 'changed';
      modules.add('mathematics');
      await expectLater(
        service.saveDetails(
          a,
          patch: ExamDetailsPatch({'title': 'second'}),
          expectedRevision: 0,
        ),
        throwsA(isA<ExamFailure>()),
      );
      service.dispose();
      service = ExamService(backend: backend);
      await service.initialize();
      expect(service.records.single.pendingDetails!.patch.toJson(), {
        'note': null,
        'selected_module_ids': ['science'],
      });
      backend.isAvailable = true;
      await service.refresh();
      expect(service.attempts.single.note, isNull);
      expect(service.attempts.single.selectedModuleIds, ['science']);
    },
  );
  test(
    'stale expected revision is not silently replaced; conflict waits for explicit review',
    () async {
      final old = detailsCompletedAttempt();
      backend.rows[old.clientUuid] = old;
      await service.initialize();
      backend.rows[old.clientUuid] = detailsCompletedAttempt(
        title: 'Other device',
        revision: 1,
      );
      await expectLater(
        service.saveDetails(
          old,
          patch: ExamDetailsPatch({'note': 'local'}),
          expectedRevision: 0,
        ),
        throwsA(isA<ExamFailure>()),
      );
      expect(service.records.single.errorCode, 'exam_details_conflict');
      final count = backend.calls
          .where((c) => c.$1 == 'save_exam_details')
          .length;
      await service.sync();
      expect(
        backend.calls.where((c) => c.$1 == 'save_exam_details').length,
        count,
      );
      final latest = await service.reloadDetailsForReview(old);
      expect(latest.detailsRevision, 1);
      expect(service.records.single.pendingDetails, isNull);
      await service.saveDetails(
        latest,
        patch: ExamDetailsPatch({'note': 'local'}),
        expectedRevision: 1,
      );
      expect(service.attempts.single.title, 'Other device');
      expect(service.attempts.single.note, 'local');
    },
  );
  test(
    'older history cannot roll metadata revision or subject results back',
    () async {
      final old = detailsCompletedAttempt();
      backend.rows[old.clientUuid] = old;
      await service.initialize();
      final entered = Completer<void>(), release = Completer<void>();
      var hold = true;
      backend.handler = (name, params) async {
        if (name == 'get_my_exam_attempts' && hold) {
          hold = false;
          entered.complete();
          await release.future;
          return {
            'attempts': [old.toJson()],
          };
        }
        return backend.defaultRpc(name, params);
      };
      final refresh = service.refresh();
      await entered.future;
      await service.saveDetails(
        old,
        patch: ExamDetailsPatch({'title': 'New'}),
        expectedRevision: 0,
      );
      release.complete();
      await refresh;
      expect(service.attempts.single.title, 'New');
      expect(service.attempts.single.detailsRevision, 1);
      expect(
        (await service.persistence.read('owner-1')).single.attempt!.title,
        'New',
      );
    },
  );
  test('owner switch cannot commit another owner response or draft', () async {
    final a = detailsCompletedAttempt();
    backend.rows[a.clientUuid] = a;
    await service.initialize();
    final entered = Completer<void>(), release = Completer<void>();
    backend.handler = (name, params) async {
      if (name == 'save_exam_details') {
        entered.complete();
        await release.future;
      }
      return backend.defaultRpc(name, params);
    };
    final save = service.saveDetails(
      a,
      patch: ExamDetailsPatch({'note': 'Private'}),
      expectedRevision: 0,
    );
    await entered.future;
    backend.rows.clear();
    backend.owner.value = 'owner-2';
    final switched = service.initialize();
    release.complete();
    await save;
    await switched;
    expect(service.attempts, isEmpty);
    expect(
      (await service.persistence.read('owner-1')).single.pendingDetails,
      isNotNull,
    );
    expect(await service.persistence.read('owner-2'), isEmpty);
  });
  test(
    'unknown journal version/action is preserved rather than overwritten',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final a = detailsCompletedAttempt();
      final raw = jsonEncode([
        {
          'schema_version': 99,
          'client_uuid': a.clientUuid,
          'created_at': a.startedAt.toIso8601String(),
          'definition': a.definition!.toJson(),
        },
      ]);
      await prefs.setString(ExamPersistence.keyFor('owner-1'), raw);
      await service.initialize();
      expect(service.errorCode, 'journal_invalid');
      expect(prefs.getString(ExamPersistence.keyFor('owner-1')), raw);
    },
  );
  test(
    'capabilities gate new requests but keep ordinary AYT completion available',
    () async {
      backend.earlyAvailable = false;
      backend.detailsAvailable = false;
      await service.initialize();
      await service.start(service.catalog.byId('ayt')!);
      await expectLater(
        service.finishEarly('active-uuid'),
        throwsA(isA<ExamFailure>()),
      );
      expect(backend.calls.where((c) => c.$1 == 'finish_ayt_early'), isEmpty);
      backend.clock = backend.clock.add(const Duration(hours: 3));
      await service.complete('active-uuid');
      expect(service.attempts.single.isCompleted, isTrue);
      expect(
        backend.calls.where((c) => c.$1 == 'complete_exam_attempt'),
        hasLength(1),
      );
    },
  );
  test(
    'journal rejects impossible module scope and unknown action without deleting it',
    () async {
      final a = detailsCompletedAttempt(modules: ['mathematics']);
      final row = ExamLocalRecord(
        clientUuid: a.clientUuid,
        definition: a.definition!,
        createdAt: a.startedAt,
        attempt: a,
      );
      expect(
        ExamLocalRecord.fromJson({
          ...row.toJson(),
          'pending_action': 'futureAction',
        }),
        isNull,
      );
      final mutation = ExamDetailsMutation(
        patch: ExamDetailsPatch({
          'selected_module_ids': ['science'],
        }),
        expectedRevision: 0,
        results: const [
          ExamSubjectResult(
            subjectId: 'mathematics',
            correct: 1,
            wrong: 0,
            blank: 39,
          ),
        ],
      );
      expect(
        ExamLocalRecord.fromJson({
          ...row.toJson(),
          'pending_action': 'details',
          'pending_details': mutation.toJson(),
        }),
        isNull,
      );
      expect(ExamAttempt.fromJson({...a.toJson(), 'exam_id': 'tyt'}), isNull);
    },
  );
  test(
    'draft may change while offline envelope stays immutable and owner retirement removes both',
    () async {
      final a = detailsCompletedAttempt();
      backend.rows[a.clientUuid] = a;
      await service.initialize();
      backend.isAvailable = false;
      await service.saveDetails(
        a,
        patch: ExamDetailsPatch({'note': 'Sent'}),
        expectedRevision: 0,
      );
      await service.updateDetailsDraft(
        a,
        ExamDetailsDraft(
          revision: 0,
          title: '',
          note: 'Later draft',
          dirtyKeys: {'note'},
          fields: {},
          dirtySubjects: {},
        ),
        owner: 'owner-1',
      );
      final row = (await service.persistence.read('owner-1')).single;
      expect(row.pendingDetails!.patch.values['note'], 'Sent');
      expect(row.detailsDraft!.note, 'Later draft');
      await service.persistence.retireOwner('owner-1');
      expect(await service.persistence.read('owner-1'), isEmpty);
    },
  );
  test(
    'oversized direct writes are rejected before changing a readable owner journal',
    () async {
      final a = detailsCompletedAttempt();
      final valid = ExamLocalRecord(
        clientUuid: a.clientUuid,
        definition: a.definition!,
        createdAt: a.startedAt,
        attempt: a,
      );
      await service.persistence.write('owner-1', [valid]);
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(ExamPersistence.keyFor('owner-1'));
      for (final values in [('x' * 5001, ''), ('', 'x' * 20001)]) {
        final bad = valid.copy(
          draft: ExamDetailsDraft(
            revision: 0,
            title: values.$1,
            note: values.$2,
            dirtyKeys: {'title', 'note'},
            fields: {},
            dirtySubjects: {},
          ),
        );
        await expectLater(
          service.persistence.write('owner-1', [valid, bad]),
          throwsA(isA<FormatException>()),
        );
        expect(prefs.getString(ExamPersistence.keyFor('owner-1')), before);
        expect(
          (await service.persistence.read('owner-1')).single.attempt!.id,
          a.id,
        );
      }
    },
  );
  test(
    'draft service enforces Unicode scalar boundaries and preserves all other records',
    () async {
      final a = detailsCompletedAttempt();
      final other = detailsCompletedAttempt(id: 'tyt');
      backend.rows[a.clientUuid] = a;
      backend.rows[other.clientUuid] = other;
      await service.initialize();
      ExamDetailsDraft draft(int title, int note) => ExamDetailsDraft(
        revision: 0,
        title: '🧠' * title,
        note: '🧠' * note,
        dirtyKeys: {'title', 'note'},
        fields: {},
        dirtySubjects: {},
      );
      await service.updateDetailsDraft(a, draft(120, 2000), owner: 'owner-1');
      for (final invalid in [
        draft(121, 2000),
        draft(120, 2001),
        draft(5001, 0),
        draft(0, 20001),
      ]) {
        await expectLater(
          service.updateDetailsDraft(a, invalid, owner: 'owner-1'),
          throwsA(isA<ExamFailure>()),
        );
      }
      service.dispose();
      service = ExamService(backend: backend);
      await service.initialize();
      expect(service.errorCode, isNull);
      expect(service.attempts, hasLength(2));
      final kept = service.recordFor(a.clientUuid)!.detailsDraft!;
      expect(kept.title.runes.length, 120);
      expect(kept.note.runes.length, 2000);
      expect(service.recordFor(other.clientUuid)!.detailsDraft, isNull);
    },
  );
  test(
    'already invalid persisted draft stays intact for explicit recovery',
    () async {
      final a = detailsCompletedAttempt();
      final row = ExamLocalRecord(
        clientUuid: a.clientUuid,
        definition: a.definition!,
        createdAt: a.startedAt,
        attempt: a,
        detailsDraft: ExamDetailsDraft(
          revision: 0,
          title: 'x' * 5001,
          note: '',
          dirtyKeys: {'title'},
          fields: {},
          dirtySubjects: {},
        ),
      );
      final raw = jsonEncode([row.toJson()]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ExamPersistence.keyFor('owner-1'), raw);
      await service.initialize();
      await service.refresh();
      expect(service.errorCode, 'journal_invalid');
      expect(prefs.getString(ExamPersistence.keyFor('owner-1')), raw);
    },
  );
}
