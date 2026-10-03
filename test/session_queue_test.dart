import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/server_clock.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _catA = '0f8fad5b-d9cb-469f-a165-70867728950e';
const _catB = '7c9e6679-7425-40de-944b-e07fc1f90ae7';

class SentCall {
  SentCall(this.uuid, this.categoryId, this.startedAt);
  final String uuid;
  final String categoryId;
  final DateTime startedAt;
}

class FakeBackend implements SessionQueueBackend {
  @override
  String? signedInUserId = 'u1';

  final List<SentCall> sent = [];
  List<CategoryRef> categories = const [];
  int createDefaultsCalls = 0;
  int fetchCategoriesCalls = 0;

  /// Her istekte (yanıt dönmeden önce) çağrılır; testler sunucu saatini
  /// ('date' başlığı) buradan besler.
  void Function()? onRequest;

  /// Varsayılan: kabul (5 puan). Testler davranışı değiştirir.
  Future<Object?> Function(PendingSession s, String categoryId, DateTime startedAt) handler =
      (s, c, t) async => {'total_points': 5, 'base_points': 5, 'streak': 1};

  @override
  Future<Object?> completeSession(
    PendingSession session, {
    required String categoryId,
    required DateTime startedAtForServer,
  }) async {
    sent.add(SentCall(session.clientUuid, categoryId, startedAtForServer));
    onRequest?.call();
    return handler(session, categoryId, startedAtForServer);
  }

  @override
  Future<List<CategoryRef>> fetchCategories() async {
    fetchCategoriesCalls++;
    onRequest?.call();
    return categories;
  }

  @override
  Future<void> createDefaultCategories() async {
    createDefaultsCalls++;
    categories = const [
      (id: _catA, name: 'Matematik', isArchived: false),
      (id: _catB, name: 'Fizik', isArchived: false),
    ];
  }
}

PendingSession _session(
  String uuid, {
  required DateTime startedAt,
  String? categoryId = _catA,
  String categoryName = 'Matematik',
  int? clockOffsetMs,
}) =>
    PendingSession(
      clientUuid: uuid,
      categoryId: categoryId,
      categoryName: categoryName,
      minutes: 25,
      wasPaused: false,
      foregroundSeconds: 1500,
      startedAt: startedAt.toUtc(),
      queuedAt: DateTime.now().toUtc(),
      clockOffsetMs: clockOffsetMs,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;
  late ServerClock clock;
  late SessionQueue queue;
  late List<String> accepted;
  final now = DateTime.now();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    clock = ServerClock();
    accepted = [];
    queue = SessionQueue(
      backend: backend,
      clock: clock,
      rpcTimeout: const Duration(seconds: 2),
      onAccepted: (uid, s, r) => accepted.add(s.clientUuid),
    );
  });

  test('kuyruk started_at sırasıyla gönderilir ve başarılılar silinir', () async {
    await queue.enqueue('u1', _session('late', startedAt: now.subtract(const Duration(minutes: 40))));
    await queue.enqueue('u1', _session('early', startedAt: now.subtract(const Duration(hours: 3))));
    await queue.enqueue('u1', _session('mid', startedAt: now.subtract(const Duration(hours: 1))));

    final report = await queue.sync('u1');

    expect(backend.sent.map((e) => e.uuid), ['early', 'mid', 'late']);
    expect(report.sent, 3);
    expect(report.remaining, 0);
    expect(accepted, ['early', 'mid', 'late']);
    expect(await queue.pending('u1'), isEmpty);
  });

  test('submit önce diske yazar (write-ahead), sonra bu seans dahil gönderir', () async {
    await queue.enqueue('u1', _session('old', startedAt: now.subtract(const Duration(hours: 2))));
    final result = await queue.submit('u1', _session('new', startedAt: now.subtract(const Duration(minutes: 30))));

    expect(result, isA<SessionSubmitSuccess>());
    expect(backend.sent.map((e) => e.uuid), ['old', 'new']);
    expect(await queue.pendingCount('u1'), 0);
  });

  test('senkron sürerken eklenen seans kaybolmaz (kilit)', () async {
    final gate = Completer<void>();
    var first = true;
    backend.handler = (s, c, t) async {
      if (first) {
        first = false;
        await gate.future;
      }
      return {'total_points': 5};
    };
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 2))));

    final syncFuture = queue.sync('u1');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Gönderim askıdayken yeni seans tamamlanıyor.
    await queue.enqueue('u1', _session('b', startedAt: now.subtract(const Duration(minutes: 30))));
    expect((await queue.pending('u1')).map((e) => e.clientUuid), containsAll(['a', 'b']));

    gate.complete();
    final report = await syncFuture;
    expect(report.sent, 1);
    // 'b' bu turun anlık görüntüsünde yoktu ama silinmedi.
    expect((await queue.pending('u1')).map((e) => e.clientUuid), ['b']);
  });

  test('senkron sürerken yapılan submit yeni turda gönderilir', () async {
    final gate = Completer<void>();
    var first = true;
    backend.handler = (s, c, t) async {
      if (first) {
        first = false;
        await gate.future;
      }
      return {'total_points': 5};
    };
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 2))));
    final syncFuture = queue.sync('u1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final submitFuture = queue.submit('u1', _session('b', startedAt: now.subtract(const Duration(minutes: 30))));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Ağ askıdayken bile seans diskte.
    expect((await queue.pending('u1')).map((e) => e.clientUuid), contains('b'));

    gate.complete();
    await syncFuture;
    final result = await submitFuture;
    expect(result, isA<SessionSubmitSuccess>());
    expect(backend.sent.map((e) => e.uuid), ['a', 'b']);
    expect(await queue.pendingCount('u1'), 0);
  });

  test('eşzamanlı sync çağrıları tek turda birleşir (çift gönderim yok)', () async {
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1))));
    final results = await Future.wait([queue.sync('u1'), queue.sync('u1'), queue.sync('u1')]);
    expect(backend.sent.length, 1);
    expect(results.every((r) => r.remaining == 0), isTrue);
  });

  test('ağ hatasında seans kuyrukta kalır ve tur durur', () async {
    backend.handler = (s, c, t) async => throw Exception('SocketException: Failed host lookup');
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 2))));
    await queue.enqueue('u1', _session('b', startedAt: now.subtract(const Duration(hours: 1))));

    final report = await queue.sync('u1');
    expect(report.stopReason, SessionReason.network);
    expect(backend.sent.length, 1, reason: 'ilk ağ hatasından sonra tur durmalı');
    expect(await queue.pendingCount('u1'), 2);
  });

  test('zaman aşımı geçicidir', () async {
    backend.handler = (s, c, t) => Completer<Object?>().future; // hiç dönmez
    final result = await queue.submit('u1', _session('a', startedAt: now.subtract(const Duration(minutes: 30))));
    expect(result, isA<SessionSubmitQueued>());
    expect((result as SessionSubmitQueued).reasonCode, SessionReason.timeout);
    expect(await queue.pendingCount('u1'), 1);
  });

  test('kalıcı red: reddedilenlere taşınır, arka plandakiler bir kez bildirilir', () async {
    backend.handler = (s, c, t) async =>
        throw const PostgrestException(message: 'started_at is older than 24 hours', code: 'P0001');
    await queue.enqueue('u1', _session('bg', startedAt: now.subtract(const Duration(hours: 2))));
    final result = await queue.submit('u1', _session('fg', startedAt: now.subtract(const Duration(minutes: 30))));

    expect(result, isA<SessionSubmitRejected>());
    expect((result as SessionSubmitRejected).reasonCode, SessionReason.tooOld);
    expect(await queue.pendingCount('u1'), 0);
    final rejected = await queue.rejectedSessions('u1');
    expect(rejected.map((r) => r.clientUuid), ['bg', 'fg']);
    // Ön plandaki seansı çağıran zaten gösteriyor; yalnızca arka plandaki sayılır.
    expect(await queue.takeRejectedNoticeCount('u1'), 1);
    expect(await queue.takeRejectedNoticeCount('u1'), 0);
  });

  test("{'error':'overlap'} 24 saat dolana kadar kuyrukta kalır, sonra reddedilir", () async {
    backend.handler = (s, c, t) async => {'error': 'overlap'};
    await queue.enqueue('u1', _session('young', startedAt: now.subtract(const Duration(hours: 1))));
    await queue.enqueue('u1', _session('old', startedAt: now.subtract(const Duration(hours: 25))));

    final report = await queue.sync('u1');
    final pending = await queue.pending('u1');
    expect(pending.map((e) => e.clientUuid), ['young']);
    expect(pending.single.lastError, SessionReason.overlap);
    expect(report.rejected, 1);
    expect((await queue.rejectedSessions('u1')).single.reasonCode, SessionReason.overlap);
  });

  test('48 saatten eski seans gönderilmeden reddedilir', () async {
    await queue.enqueue('u1', _session('ancient', startedAt: now.subtract(const Duration(hours: 50))));
    await queue.sync('u1');
    expect(backend.sent, isEmpty);
    expect((await queue.rejectedSessions('u1')).single.reasonCode, SessionReason.tooOld);
  });

  test('yer tutucu kategori isimle sunucu kategorisine eşlenir', () async {
    backend.categories = const [
      (id: _catA, name: 'Matematik', isArchived: false),
      (id: _catB, name: 'Fizik', isArchived: false),
    ];
    await queue.enqueue(
        'u1', _session('a', startedAt: now.subtract(const Duration(hours: 1)), categoryId: '2', categoryName: 'Fizik'));
    await queue.sync('u1');
    expect(backend.sent.single.categoryId, _catB);
  });

  test('eşleşme yoksa ilk aktif kategoriye atanır', () async {
    backend.categories = const [(id: _catA, name: 'Matematik', isArchived: false)];
    await queue.enqueue(
        'u1', _session('a', startedAt: now.subtract(const Duration(hours: 1)), categoryId: '9', categoryName: 'Tarih'));
    await queue.sync('u1');
    expect(backend.sent.single.categoryId, _catA);
  });

  test('hiç sunucu kategorisi yoksa varsayılanlar oluşturulur; seans kaybolmaz', () async {
    await queue.enqueue(
        'u1', _session('a', startedAt: now.subtract(const Duration(hours: 1)), categoryId: '2', categoryName: 'Fizik'));
    final report = await queue.sync('u1');
    expect(backend.createDefaultsCalls, 1);
    expect(backend.sent.single.categoryId, _catB);
    expect(report.sent, 1);
  });

  test('kategori sunucuda reddedilirse yeniden eşlenip aynı senkronda tekrar denenir', () async {
    backend.categories = const [(id: _catB, name: 'Fizik', isArchived: false)];
    backend.handler = (s, c, t) async {
      if (c == _catA) throw const PostgrestException(message: 'category does not belong to this user', code: 'P0001');
      return {'total_points': 5};
    };
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1)), categoryName: 'Fizik'));
    final report = await queue.sync('u1');
    expect(backend.sent.map((e) => e.categoryId), [_catA, _catB]);
    expect(report.sent, 1);
    expect(await queue.pendingCount('u1'), 0);
  });

  test('kategoriler alınamazsa (ağ yok) yer tutuculu seans bekler', () async {
    final failing = _FailingCategoriesBackend();
    final q = SessionQueue(backend: failing, clock: clock, rpcTimeout: const Duration(seconds: 2));
    await q.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1)), categoryId: '1'));
    final report = await q.sync('u1');
    expect(report.stopReason, SessionReason.network);
    expect(await q.pendingCount('u1'), 1);
  });

  test('oturumdaki hesap farklıysa bekleyen seans gönderilmez', () async {
    backend.signedInUserId = 'u2';
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1))));
    final report = await queue.sync('u1');
    expect(backend.sent, isEmpty);
    expect(report.remaining, 1);
    final result = await queue.submit('u1', _session('b', startedAt: now.subtract(const Duration(minutes: 30))));
    expect(result, isA<SessionSubmitQueued>());
    expect(backend.sent, isEmpty);
  });

  test('client_uuid olmayan eski kayda bir kez kimlik üretilir ve korunur', () async {
    SharedPreferences.setMockInitialValues({
      SessionQueue.queueKey('u1'): jsonEncode([
        {
          'category_id': _catA,
          'category_name': 'Matematik',
          'minutes': 25,
          'was_paused': false,
          'is_verified': 1500,
          'started_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        }
      ]),
    });
    backend.handler = (s, c, t) async => throw Exception('SocketException');
    await queue.sync('u1');
    final firstUuid = (await queue.pending('u1')).single.clientUuid;
    await queue.sync('u1');
    expect((await queue.pending('u1')).single.clientUuid, firstUuid);
    expect(backend.sent.map((e) => e.uuid).toSet(), {firstUuid});
  });

  test('bozuk kayıt reddedilenlere taşınır', () async {
    SharedPreferences.setMockInitialValues({
      SessionQueue.queueKey('u1'): jsonEncode([
        {'client_uuid': 'x', 'minutes': 'yirmi beş'},
      ]),
    });
    final report = await queue.sync('u1');
    expect(report.rejected, 1);
    expect((await queue.rejectedSessions('u1')).single.reasonCode, SessionReason.corrupt);
    expect(await queue.pendingCount('u1'), 0);
  });

  test('e-posta anahtarlı eski kuyruk kullanıcı kimliğine taşınır', () async {
    await queue.enqueueLegacy('Ali@Example.com', _session('legacy', startedAt: now.subtract(const Duration(hours: 1))));
    await queue.enqueue('u1', _session('own', startedAt: now.subtract(const Duration(minutes: 30))));
    await queue.adoptLegacyQueue(userId: 'u1', email: 'ali@example.com');
    expect((await queue.pending('u1')).map((e) => e.clientUuid), ['legacy', 'own']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SessionQueue.legacyQueueKey('ali@example.com')), isNull);
  });

  // Saati [deviceAhead] kadar ileri bir cihaza yanıt veren sahte sunucu; fark
  // ilk yanıtta öğrenilir. Canlı complete_study_session'ın zaman kuralları
  // (sunucu saatiyle):
  // started_at > now() → 'started_at cannot be in the future';
  // started_at + süre > now() + 5 dk → 'session_not_finished'.
  Future<Object?> Function(PendingSession, String, DateTime) liveServer({required Duration deviceAhead}) {
    return (s, c, t) async {
      final serverNow = DateTime.now().subtract(deviceAhead);
      clock.recordSample(serverTime: serverNow.toUtc(), sentAt: DateTime.now(), receivedAt: DateTime.now());
      if (t.isAfter(serverNow)) {
        throw const PostgrestException(message: 'started_at cannot be in the future', code: 'P0001');
      }
      if (t.add(Duration(minutes: s.minutes)).isAfter(serverNow.add(const Duration(minutes: 5)))) {
        throw const PostgrestException(message: 'session_not_finished', code: 'P0001');
      }
      return {'total_points': 5, 'coins_earned': 20, 'duplicate': false};
    };
  }

  // Cihaz saati 10 dk ileri (sunucu - cihaz = -10 dk).
  final skewedServer = liveServer(deviceAhead: const Duration(minutes: 10));

  test("cihaz saati çok ileriyse ('started_at cannot be in the future') düzeltilip kabul edilir", () async {
    backend.handler = liveServer(deviceAhead: const Duration(minutes: 40));
    final result =
        await queue.submit('u1', _session('a', startedAt: DateTime.now().subtract(const Duration(minutes: 26))));
    expect(result, isA<SessionSubmitSuccess>());
    expect(backend.sent.length, 2);
    expect(backend.sent[0].startedAt.difference(backend.sent[1].startedAt).inMinutes, inInclusiveRange(39, 40));
  });

  test('cihaz saati ileriyse started_at sunucu saatine çevrilip yeniden denenir', () async {
    backend.handler = skewedServer;
    // Gerçekte 26 dk önce başladı; cihaz bunu 10 dk ileri kaydetti.
    final result =
        await queue.submit('u1', _session('a', startedAt: DateTime.now().subtract(const Duration(minutes: 26))));
    expect(result, isA<SessionSubmitSuccess>());
    expect(backend.sent.length, 2);
    expect(backend.sent[0].startedAt.difference(backend.sent[1].startedAt).inMinutes, inInclusiveRange(9, 10));
  });

  test('düzeltmeye rağmen süre dolmamışsa (debug kısa seans) kalıcı reddedilir', () async {
    backend.handler = skewedServer;
    final result =
        await queue.submit('u1', _session('a', startedAt: DateTime.now().subtract(const Duration(minutes: 1))));
    expect(result, isA<SessionSubmitRejected>());
    expect((result as SessionSubmitRejected).reasonCode, SessionReason.notElapsed);
    expect(backend.sent.length, 2);
  });

  test('saat doğruyken süre dolmamış seans tek denemede kalıcı reddedilir', () async {
    clock.recordSample(serverTime: DateTime.now().toUtc(), sentAt: DateTime.now(), receivedAt: DateTime.now());
    backend.handler = (s, c, t) async => throw const PostgrestException(message: 'session_not_finished', code: 'P0001');
    final result = await queue.submit(
      'u1',
      _session('a', startedAt: DateTime.now().subtract(const Duration(seconds: 5)), clockOffsetMs: clock.offset!.inMilliseconds),
    );
    expect(result, isA<SessionSubmitRejected>());
    expect(backend.sent.length, 1);
  });

  test('saat farkı biliniyorsa gönderilen started_at baştan düzeltilir', () async {
    clock.recordSample(
      serverTime: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      sentAt: DateTime.now(),
      receivedAt: DateTime.now(),
    );
    final started = DateTime.now().subtract(const Duration(minutes: 40));
    await queue.submit(
      'u1',
      _session('a', startedAt: started, clockOffsetMs: clock.offset!.inMilliseconds),
    );
    final diff = started.toUtc().difference(backend.sent.single.startedAt);
    expect(diff.inMinutes, inInclusiveRange(9, 10));
  });

  // Canlı complete_study_session'ın zaman kuralları ve gerçek aralık
  // çakışması ({'error': 'overlap'}) ile, cihaz saatinden [deviceAhead] kadar
  // geride çalışan sahte sunucu. Her yanıt (kategoriler dahil) 'date'
  // başlığıyla saat farkını öğretir. Kaydedilen aralıklar sunucu saatiyle.
  ({List<(DateTime, DateTime)> recorded, Duration deviceAhead}) installClockedServer(
    Duration deviceAhead, {
    List<(DateTime, DateTime)>? existing,
  }) {
    final recorded = existing ?? <(DateTime, DateTime)>[];
    DateTime serverNow() => DateTime.now().toUtc().subtract(deviceAhead);
    backend.onRequest = () => clock.recordSample(serverTime: serverNow(), sentAt: DateTime.now(), receivedAt: DateTime.now());
    backend.handler = (s, c, t) async {
      final start = t.toUtc();
      final end = start.add(Duration(minutes: s.minutes));
      if (start.isAfter(serverNow())) {
        throw const PostgrestException(message: 'started_at cannot be in the future', code: 'P0001');
      }
      if (end.isAfter(serverNow().add(const Duration(minutes: 5)))) {
        throw const PostgrestException(message: 'session_not_finished', code: 'P0001');
      }
      if (recorded.any((r) => r.$1.isBefore(end) && r.$2.isAfter(start))) return {'error': 'overlap'};
      recorded.add((start, end));
      return {'total_points': 5, 'coins_earned': 20, 'duplicate': false};
    };
    return (recorded: recorded, deviceAhead: deviceAhead);
  }

  test('fark bilinmeden kuyruğa giren art arda seanslar çakışmadan kaydedilir (cihaz ileri)', () async {
    // Cihaz saati 3 dk ileri; uygulama çevrimdışı açıldı (fark bilinmiyor).
    const ahead = Duration(minutes: 3);
    final server = installClockedServer(ahead);
    final realA = DateTime.now().toUtc().subtract(const Duration(minutes: 60));
    final realB = realA.add(const Duration(minutes: 25, seconds: 10));
    await queue.enqueue('u1', _session('A', startedAt: realA.add(ahead)));
    await queue.enqueue('u1', _session('B', startedAt: realB.add(ahead)));

    final report = await queue.sync('u1');

    expect(report.outcomes['A'], isA<SessionSubmitSuccess>());
    expect(report.outcomes['B'], isA<SessionSubmitSuccess>());
    expect(await queue.pendingCount('u1'), 0);
    expect(backend.fetchCategoriesCalls, 1, reason: 'göndermeden önce fark öğrenilir');
    // İki seans da gerçek zamanlarıyla (±1 sn) kaydedildi.
    expect(server.recorded[0].$1.difference(realA).inSeconds.abs(), lessThanOrEqualTo(1));
    expect(server.recorded[1].$1.difference(realB).inSeconds.abs(), lessThanOrEqualTo(1));
  });

  test('fark bilinmeden kuyruğa giren seans, önceden doğru kaydedilmiş seansla çakışmaz (cihaz geri)', () async {
    // Cihaz saati 10 dk geri. X önceki açılışta fark bilinerek doğru kaydedildi.
    const ahead = Duration(minutes: -10);
    final realX = DateTime.now().toUtc().subtract(const Duration(minutes: 90));
    final server = installClockedServer(ahead, existing: [(realX, realX.add(const Duration(minutes: 25)))]);
    final realY = realX.add(const Duration(minutes: 25, seconds: 10));
    final result = await queue.submit('u1', _session('Y', startedAt: realY.add(ahead)));

    expect(result, isA<SessionSubmitSuccess>());
    expect(server.recorded.last.$1.difference(realY).inSeconds.abs(), lessThanOrEqualTo(1));
  });

  test('fark öğrenilemezse (ağ yok) fark kaydı olmayan seans gönderilmez', () async {
    final failing = _FailingCategoriesBackend();
    final q = SessionQueue(backend: failing, clock: clock, rpcTimeout: const Duration(seconds: 2));
    final result = await q.submit('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1))));
    expect(failing.sent, isEmpty);
    expect(result, isA<SessionSubmitQueued>());
    expect((result as SessionSubmitQueued).reasonCode, SessionReason.network);
    expect(await q.pendingCount('u1'), 1);
  });

  test('fark zaten biliniyorsa ek istek atılmaz', () async {
    clock.recordSample(serverTime: DateTime.now().toUtc(), sentAt: DateTime.now(), receivedAt: DateTime.now());
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1))));
    await queue.sync('u1');
    expect(backend.fetchCategoriesCalls, 0);
    expect(backend.sent.single.uuid, 'a');
  });

  test('yalnızca çakışmayla bekleyen kuyruk kendiliğinden yeniden denenmez', () async {
    backend.handler = (s, c, t) async => {'error': 'overlap'};
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1))));
    final overlapOnly = await queue.sync('u1');
    expect(overlapOnly.remaining, 1);
    expect(overlapOnly.hasRetryableFailure, isFalse);

    backend.handler = (s, c, t) async => throw Exception('SocketException: Failed host lookup');
    final offline = await queue.sync('u1');
    expect(offline.hasRetryableFailure, isTrue);
  });

  test('clearUser kuyruğu ve red kayıtlarını siler', () async {
    await queue.enqueue('u1', _session('a', startedAt: now.subtract(const Duration(hours: 1))));
    await queue.clearUser('u1');
    expect(await queue.pendingCount('u1'), 0);
  });
}

class _FailingCategoriesBackend extends FakeBackend {
  @override
  Future<List<CategoryRef>> fetchCategories() async => throw Exception('SocketException: Failed host lookup');
}
