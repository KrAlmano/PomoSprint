// t1 — SEANS / PUAN / KUM / SERİ: istemci kuyruğu ↔ yerel sunucu uçtan uca.
//
// Uygulamanın GERÇEK SessionQueue, ServerClock, ServerClockHttpClient,
// classifySessionError / classifySessionResponse ve SessionSubmitSuccess
// kodları, yerel Supabase kopyasına (http://127.0.0.1:54321) gerçek HTTP ile
// bağlanır. Kuyruk arka ucu, lib/services/supabase_service.dart içindeki
// _SupabaseQueueBackend ile birebir aynı RPC parametrelerini gönderir.
// Ağ kopması ve yanıt kaybı HTTP katmanında taklit edilir.
//
// Çalıştırma (yalnızca yerel kopya açıkken; normal `flutter test` bunu almaz):
//   flutter test tool/local_supabase/e2e/t1_seans_puan/t1_client_queue_e2e_test.dart
//
// Kendi hesabını açar (t1-<zaman>-dart@pomosprint.local); test1/test2'ye dokunmaz.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/services/server_clock.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _url = 'http://127.0.0.1:54321';
const _anon =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9'
    '.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const _password = 'pomosprint-yerel-test';

/// HTTP katmanında ağ kopması / yanıt kaybı taklidi.
class FaultyHttpClient extends http.BaseClient {
  FaultyHttpClient(this._inner);
  final http.Client _inner;

  /// İstek hiç gitmez (bağlantı reddedildi).
  bool offline = false;

  /// Sıradaki complete_study_session isteği sunucuya ulaşır, işlenir; yanıt kaybolur.
  bool dropNextCompleteResponse = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) {
      throw http.ClientException('SocketException: Connection refused (OS Error: Connection refused, errno = 61)', request.url);
    }
    final response = await _inner.send(request);
    if (dropNextCompleteResponse && request.url.path.endsWith('/rpc/complete_study_session')) {
      dropNextCompleteResponse = false;
      await response.stream.drain<void>();
      throw http.ClientException('Connection closed while receiving data', request.url);
    }
    return response;
  }
}

/// lib/services/supabase_service.dart `_SupabaseQueueBackend` ile birebir aynı istekler.
class RealBackend implements SessionQueueBackend {
  RealBackend(this.client);
  final SupabaseClient client;
  final List<Map<String, dynamic>> calls = [];

  @override
  String? get signedInUserId => client.auth.currentUser?.id;

  @override
  Future<Object?> completeSession(PendingSession session, {required String categoryId, required DateTime startedAtForServer}) {
    final params = {
      'p_client_uuid': session.clientUuid,
      'p_category_id': categoryId,
      'p_duration_minutes': session.minutes,
      'p_was_paused': session.wasPaused,
      'p_is_verified': session.foregroundSeconds,
      'p_started_at': startedAtForServer.toUtc().toIso8601String(),
    };
    calls.add(params);
    return client.rpc('complete_study_session', params: params);
  }

  @override
  Future<List<CategoryRef>> fetchCategories() async {
    // SupabaseService.fetchUserCategories(includeArchived: true) ile aynı sorgu.
    final rows = await client
        .from('categories')
        .select('id, name, color_hex, icon_name, sort_order, is_archived')
        .eq('user_id', client.auth.currentUser!.id)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true)
        .order('id', ascending: true);
    return [for (final r in rows) (id: r['id'] as String, name: r['name'] as String, isArchived: r['is_archived'] == true)];
  }

  @override
  Future<void> createDefaultCategories() => client.rpc('setup_onboarding_categories', params: {
        'p_categories': [for (final c in CourseCategory.initialCategories()) c.toServerJson()],
      });
}

PendingSession pending({
  required DateTime startedAt,
  String? categoryId = '1',
  String categoryName = 'Matematik',
  int minutes = 25,
  bool wasPaused = false,
  int? clockOffsetMs,
  String? uuid,
}) =>
    PendingSession(
      clientUuid: uuid ?? const Uuid().v4(),
      categoryId: categoryId,
      categoryName: categoryName,
      minutes: minutes,
      wasPaused: wasPaused,
      foregroundSeconds: minutes * 60,
      startedAt: startedAt.toUtc(),
      queuedAt: DateTime.now().toUtc(),
      clockOffsetMs: clockOffsetMs,
    );

void main() {
  late SupabaseClient client;
  late FaultyHttpClient faulty;
  late ServerClock clock;
  late RealBackend backend;
  late SessionQueue queue;
  late String uid;
  final accepted = <(String, SessionSubmitSuccess)>[];
  late DateTime t0; // sunucu saatine göre "şimdi" (testin başı)

  Future<Map<String, dynamic>> profile() =>
      client.from('profiles').select('lifetime_points, coins, total_minutes, current_streak, last_study_date').eq('id', uid).single();

  Future<List<Map<String, dynamic>>> serverSessions() =>
      client.from('study_sessions').select('client_uuid, started_at, base_points, bonus_points, category, duration_minutes').eq('user_id', uid);

  setUpAll(() async {
    // Dosya test/ dışında olduğu için analizör test sayamıyor.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    clock = ServerClock();
    faulty = FaultyHttpClient(http.Client());
    // Uygulamadaki gibi implicit akış (SupabaseService.initialize).
    client = SupabaseClient(_url, _anon,
        httpClient: ServerClockHttpClient(clock, faulty),
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));
    final email = 't1-${DateTime.now().millisecondsSinceEpoch}-dart@pomosprint.local';
    final res = await client.auth.signUp(email: email, password: _password, data: {
      'name': 'T1 Dart',
      'avatar_id': 'avatar_16_basic',
      'newsletter': false,
      'marketing_consent': false,
      'terms_version': '2026-10-03',
      'privacy_version': '2026-10-03',
      'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
    });
    uid = res.user!.id;
    expect(client.auth.currentUser?.id, uid, reason: 'yerelde e-posta onayı kapalı: kayıt oturum açmalı');
    expect(clock.offset, isNotNull, reason: "Kong yanıtında 'date' başlığı var; saat farkı ölçülmeli");
    t0 = clock.serverNow();
    backend = RealBackend(client);
    queue = SessionQueue(
      backend: backend,
      clock: clock,
      onAccepted: (u, s, r) => accepted.add((s.clientUuid, r)),
    );
  });

  setUp(() {
    faulty.offline = false;
    faulty.dropNextCompleteResponse = false;
  });

  test('Q0 sözleşme: uygulamanın _SupabaseQueueBackend yükü bu testteki RealBackend ile ve canlı imzayla aynı', () {
    // Canlı imza (pg_get_functiondef, yerel = canlı md5):
    // complete_study_session(p_client_uuid uuid, p_category_id uuid, p_duration_minutes integer,
    //                        p_was_paused boolean, p_is_verified integer, p_started_at timestamptz)
    final src = File('lib/services/supabase_service.dart').readAsStringSync();
    final start = src.indexOf("rpc('complete_study_session'");
    expect(start, isNonNegative);
    final block = src.substring(start, src.indexOf('});', start));
    for (final line in [
      "'p_client_uuid': session.clientUuid",
      "'p_category_id': categoryId",
      "'p_duration_minutes': session.minutes",
      "'p_was_paused': session.wasPaused",
      "'p_is_verified': session.foregroundSeconds",
      "'p_started_at': startedAtForServer.toUtc().toIso8601String()",
    ]) {
      expect(block, contains(line));
    }
    expect(RegExp(r"'p_[a-z_]+'").allMatches(block).length, 6, reason: 'fazladan/eksik parametre yok');
    expect(src, contains("rpc('start_study_session', params: {\n        'p_duration_minutes': durationMinutes,\n        'p_category_name': categoryName,"));
    expect(src, contains("rpc('cancel_study_session')"));
  });

  test('Q1 çevrimdışı kuyruk: ağ yokken bekler, gelince started_at sırasıyla gönderir; yer tutucu kategori isimle eşlenir', () async {
    faulty.offline = true;
    final s3 = pending(startedAt: t0.subtract(const Duration(minutes: 60)));
    final r3 = await queue.submit(uid, s3);
    expect(r3, isA<SessionSubmitQueued>());
    expect((r3 as SessionSubmitQueued).reasonCode, SessionReason.network);
    final s1 = pending(startedAt: t0.subtract(const Duration(minutes: 200)), categoryId: '2', categoryName: 'Fizik');
    final s2 = pending(startedAt: t0.subtract(const Duration(minutes: 120)));
    await queue.enqueue(uid, s1);
    await queue.enqueue(uid, s2);
    expect((await queue.pending(uid)).map((e) => e.clientUuid), [s1.clientUuid, s2.clientUuid, s3.clientUuid]);
    expect(backend.calls, isEmpty);
    faulty.offline = false;
    expect(await serverSessions(), isEmpty);

    final report = await queue.sync(uid);
    expect(report.sent, 3);
    expect(report.remaining, 0);
    expect(backend.calls.map((c) => c['p_client_uuid']), [s1.clientUuid, s2.clientUuid, s3.clientUuid]);
    expect(accepted.map((a) => a.$1), [s1.clientUuid, s2.clientUuid, s3.clientUuid]);
    for (final (_, r) in accepted) {
      expect((r.basePoints, r.bonusPoints, r.totalPoints, r.coinsEarned, r.bonusPct, r.duplicate, r.dailyLimitReached),
          (5, 0, 5, 20, 0, false, false));
      expect(r.streak, isNotNull);
    }
    final rows = {for (final r in await serverSessions()) r['client_uuid']: r};
    expect(rows[s1.clientUuid]!['category'], 'Fizik');
    expect(rows[s2.clientUuid]!['category'], 'Matematik');
    // Sunucuya giden started_at, cihaz saati + ölçülen fark (≈ 0 sn).
    final sent = DateTime.parse(rows[s1.clientUuid]!['started_at'] as String);
    expect(sent.difference(s1.startedAt).inSeconds.abs(), lessThan(5));
    final p = await profile();
    expect((p['lifetime_points'], p['coins'], p['total_minutes']), (15, 60, 75));
  });

  test('Q2 yanıtı kaybolan seans: kuyrukta kalır, yeniden gönderimde duplicate → başarı, puan bir kez', () async {
    accepted.clear();
    final s4 = pending(startedAt: t0.subtract(const Duration(minutes: 260)));
    faulty.dropNextCompleteResponse = true;
    final r = await queue.submit(uid, s4);
    expect(r, isA<SessionSubmitQueued>(), reason: 'yanıt kayboldu → çevrimdışı/ağ');
    expect((r as SessionSubmitQueued).reasonCode, SessionReason.network);
    expect((await queue.pending(uid)).map((e) => e.clientUuid), [s4.clientUuid]);
    expect((await serverSessions()).where((x) => x['client_uuid'] == s4.clientUuid), hasLength(1), reason: 'sunucu kaydetmişti');

    final report = await queue.sync(uid);
    expect(report.sent, 1);
    expect(await queue.pending(uid), isEmpty);
    final dup = accepted.single.$2;
    expect(dup.duplicate, isTrue);
    expect(dup.coinsEarned, 0);
    // Sunucu duplicate'te ilk kaydın puanını döndürüyor (AGENTS.md "puan 0" diyor);
    // SupabaseService._onSessionAccepted duplicate'te delta eklemiyor, diyalog "zaten kayıtlı" diyor.
    expect(dup.totalPoints, 5);
    final p = await profile();
    expect((p['lifetime_points'], p['coins'], p['total_minutes']), (20, 80, 100));
  });

  test("Q3 çakışan seans: {error:'overlap'} → kuyrukta kalır, yeniden denenmeye değer sayılmaz, sonrakileri engellemez", () async {
    accepted.clear();
    final s5 = pending(startedAt: t0.subtract(const Duration(minutes: 130))); // s2 [T-120, T-95] ile çakışır
    final r = await queue.submit(uid, s5);
    expect(r, isA<SessionSubmitQueued>());
    expect((r as SessionSubmitQueued).reasonCode, SessionReason.overlap);
    final q = await queue.pending(uid);
    expect(q.single.lastError, SessionReason.overlap);
    final again = await queue.sync(uid);
    expect(again.hasRetryableFailure, isFalse);
    expect(again.remaining, 1);
    // Kuyruktaki çakışan seans sonraki seansı engellemez.
    final s6 = pending(startedAt: t0.subtract(const Duration(minutes: 35)));
    final r6 = await queue.submit(uid, s6);
    expect(r6, isA<SessionSubmitSuccess>());
    expect((await queue.pending(uid)).single.clientUuid, s5.clientUuid);
  });

  test('Q4 süresi dolmamış seans (saat doğru): session_not_finished → kalıcı not_elapsed, reddedilenlere', () async {
    final s = pending(startedAt: t0.subtract(const Duration(minutes: 10)));
    final r = await queue.submit(uid, s);
    expect(r, isA<SessionSubmitRejected>());
    expect((r as SessionSubmitRejected).reasonCode, SessionReason.notElapsed);
    final rej = await queue.rejectedSessions(uid);
    expect(rej.map((e) => (e.clientUuid, e.reasonCode)), contains((s.clientUuid, SessionReason.notElapsed)));
  });

  test('Q5 cihaz saati 10 dk ileri, fark kuyruğa yazılırken biliniyor: started_at düzeltilir, kabul', () async {
    final real = t0.subtract(const Duration(minutes: 330));
    final s = pending(startedAt: real.add(const Duration(minutes: 10)), clockOffsetMs: -600000);
    final r = await queue.submit(uid, s);
    expect(r, isA<SessionSubmitSuccess>());
    final row = (await serverSessions()).firstWhere((x) => x['client_uuid'] == s.clientUuid);
    expect(DateTime.parse(row['started_at'] as String).difference(real).inSeconds.abs(), lessThan(2));
  });

  test('Q6 eski seanslar: 25 sa → sunucu too_old (kalıcı); 49 sa → hiç gönderilmeden too_old', () async {
    final before = backend.calls.length;
    final s25 = pending(startedAt: t0.subtract(const Duration(hours: 25)));
    final r25 = await queue.submit(uid, s25);
    expect(r25, isA<SessionSubmitRejected>());
    expect((r25 as SessionSubmitRejected).reasonCode, SessionReason.tooOld);
    final s49 = pending(startedAt: t0.subtract(const Duration(hours: 49)));
    final callsBefore49 = backend.calls.length;
    final r49 = await queue.submit(uid, s49);
    expect((r49 as SessionSubmitRejected).reasonCode, SessionReason.tooOld);
    expect(backend.calls.skip(callsBefore49).where((c) => c['p_client_uuid'] == s49.clientUuid), isEmpty);
    expect(backend.calls.length, greaterThan(before));
  });

  test('Q7 başkasının / bilinmeyen kategori kimliği: category does not belong → isimle yeniden eşlenir, aynı turda kabul', () async {
    final s = pending(startedAt: t0.subtract(const Duration(minutes: 400)), categoryId: const Uuid().v4(), categoryName: 'Fizik');
    final r = await queue.submit(uid, s);
    expect(r, isA<SessionSubmitSuccess>());
    final row = (await serverSessions()).firstWhere((x) => x['client_uuid'] == s.clientUuid);
    expect(row['category'], 'Fizik');
  });

  test('Q8 günlük sınır: 17. seans daily_limit_reached=true, 0 puan 0 kum olarak okunur', () async {
    final rows = await serverSessions();
    // Bugünkü (İstanbul 04:00) çalışma gününde kaç seans var?
    DateTime studyDay(DateTime t) {
      final ist = t.toUtc().add(const Duration(hours: 3)).subtract(const Duration(hours: 4));
      return DateTime.utc(ist.year, ist.month, ist.day);
    }

    final today = studyDay(t0);
    final used = rows.map((r) => DateTime.parse(r['started_at'] as String)).toList();
    final todayCount = used.where((t) => studyDay(t) == today).length;
    final need = 17 - todayCount;
    // Boş aralıklar: en eski kayıttan geriye 26 dk adımlarla.
    var cursor = used.reduce((a, b) => a.isBefore(b) ? a : b).subtract(const Duration(minutes: 30));
    final dayStart = DateTime.utc(today.year, today.month, today.day, 1); // 04:00 IST = 01:00 UTC
    if (cursor.subtract(Duration(minutes: 26 * need)).isBefore(dayStart)) {
      markTestSkipped('bugünkü çalışma gününde 17 seanslık boş aralık yok (çalışma saatine bağlı)');
      return;
    }
    SessionSubmitResult? last;
    for (var i = 0; i < need; i++) {
      last = await queue.submit(uid, pending(startedAt: cursor));
      cursor = cursor.subtract(const Duration(minutes: 26));
      if (i < need - 1) {
        expect((last as SessionSubmitSuccess).dailyLimitReached, isFalse, reason: '${todayCount + i + 1}. seans');
      }
    }
    final r = last as SessionSubmitSuccess;
    expect((r.dailyLimitReached, r.totalPoints, r.basePoints, r.coinsEarned, r.duplicate), (true, 0, 0, 0, false));
    expect(r.streak, isNotNull);
  });

  test('Q9 gerçek sunucu hataları istemcide doğru sınıflanır (anon 42501 → auth, 22P02 → kategori)', () async {
    final anon = SupabaseClient(_url, _anon);
    Object? err;
    try {
      await anon.rpc('complete_study_session', params: {
        'p_client_uuid': const Uuid().v4(),
        'p_category_id': const Uuid().v4(),
        'p_duration_minutes': 25,
        'p_was_paused': false,
        'p_is_verified': 0,
        'p_started_at': t0.subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
      });
    } catch (e) {
      err = e;
    }
    expect(err, isA<PostgrestException>());
    final f = classifySessionError(err!);
    expect((f.kind, f.reasonCode), (SessionFailureKind.offline, SessionReason.auth));

    Object? err2;
    try {
      await client.rpc('complete_study_session', params: {
        'p_client_uuid': const Uuid().v4(),
        'p_category_id': '1',
        'p_duration_minutes': 25,
        'p_was_paused': false,
        'p_is_verified': 0,
        'p_started_at': t0.subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
      });
    } catch (e) {
      err2 = e;
    }
    expect((err2 as PostgrestException).code, '22P02');
    expect(classifySessionError(err2).kind, SessionFailureKind.categoryInvalid);

    // invalid duration (P0001) → kalıcı invalid_duration
    Object? err3;
    try {
      await client.rpc('complete_study_session', params: {
        'p_client_uuid': const Uuid().v4(),
        'p_category_id': const Uuid().v4(),
        'p_duration_minutes': 30,
        'p_was_paused': false,
        'p_is_verified': 0,
        'p_started_at': t0.subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
      });
    } catch (e) {
      err3 = e;
    }
    expect((err3 as PostgrestException).code, 'P0001');
    expect(classifySessionError(err3).reasonCode, SessionReason.invalidDuration);
  });

  test('Q10 oturum kapalıyken: seans kuyruğa yazılır, gönderilmez (başka hesaba gitmez)', () async {
    final callsBefore = backend.calls.length;
    final pendingBefore = (await queue.pending(uid)).length;
    await client.auth.signOut();
    final s = pending(startedAt: t0.subtract(const Duration(minutes: 20)));
    final r = await queue.submit(uid, s);
    expect(r, isA<SessionSubmitQueued>());
    expect((r as SessionSubmitQueued).reasonCode, SessionReason.offline);
    expect(backend.calls.length, callsBefore);
    expect((await queue.pending(uid)).length, pendingBefore + 1);
  });

  test('Q11 çok günlük çevrimdışı kuyruk: dün (03:10 İstanbul) ve bugün (04:05) seansları ters sırayla kuyruğa girse de sırayla gider, seri 1 → 2', () async {
    final clock2 = ServerClock();
    final client2 = SupabaseClient(_url, _anon,
        httpClient: ServerClockHttpClient(clock2),
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));
    final res = await client2.auth.signUp(
        email: 't1-${DateTime.now().millisecondsSinceEpoch}-dart2@pomosprint.local',
        password: _password,
        data: {'name': 'T1 Dart 2', 'avatar_id': 'avatar_16_basic'});
    final uid2 = res.user!.id;
    final now = clock2.serverNow().toUtc();
    final ist = now.add(const Duration(hours: 3));
    var b4 = DateTime.utc(ist.year, ist.month, ist.day, 1); // 04:00 İstanbul
    while (now.difference(b4) < const Duration(minutes: 35)) {
      b4 = b4.subtract(const Duration(days: 1));
    }
    final yesterday = b4.subtract(const Duration(minutes: 50));
    if (yesterday.isBefore(now.subtract(const Duration(hours: 23, minutes: 50)))) {
      markTestSkipped('04:00 sınırı 24 saat penceresinde değil');
      return;
    }
    final today = b4.add(const Duration(minutes: 5));
    final got = <(String, int?)>[];
    final q2 = SessionQueue(backend: RealBackend(client2), clock: clock2, onAccepted: (_, s, r) => got.add((s.clientUuid, r.streak)));
    final sToday = pending(startedAt: today);
    final sYesterday = pending(startedAt: yesterday);
    await q2.enqueue(uid2, sToday);
    await q2.enqueue(uid2, sYesterday);
    final report = await q2.sync(uid2);
    expect(report.sent, 2);
    expect(got, [(sYesterday.clientUuid, 1), (sToday.clientUuid, 2)]);
    final p = await client2.from('profiles').select('current_streak, last_study_date').eq('id', uid2).single();
    expect(p['current_streak'], 2);
  });

  test('Q12 duraklatılmış seans: açılışta 24 saat denetimini geçer, sonra devam ettirilince sunucu too_old ile reddeder (devamda denetim yok)', () async {
    final clock3 = ServerClock();
    final client3 = SupabaseClient(_url, _anon,
        httpClient: ServerClockHttpClient(clock3),
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));
    final res = await client3.auth.signUp(
        email: 't1-${DateTime.now().millisecondsSinceEpoch}-dart3@pomosprint.local',
        password: _password,
        data: {'name': 'T1 Dart 3', 'avatar_id': 'avatar_16_basic'});
    final uid3 = res.user!.id;
    final now = clock3.serverNow();
    // Başlat → 1 dk sonra duraklat (kalan 24 dk).
    final start = now.subtract(const Duration(hours: 24, minutes: 4));
    var s = ActiveTimerSession.start(
      clientUuid: const Uuid().v4(),
      categoryId: '1',
      categoryName: 'Matematik',
      durationMinutes: 25,
      totalSeconds: 1500,
      now: start,
    ).pauseAt(start.add(const Duration(minutes: 1)));
    // Uygulama 1 saat önce açıldı: TimerScreen._restoreSession isAbandonedAt'e bakar → geçer.
    final restoreAt = now.subtract(const Duration(hours: 1));
    expect(s.isAbandonedAt(restoreAt), isFalse);
    // Kullanıcı 24 dk önce DEVAM'a bastı: TimerScreen._startOrResume yaş denetimi yapmaz.
    s = s.resumeAt(now.subtract(const Duration(minutes: 24)));
    expect(s.isFinishedAt(now), isTrue);
    final q3 = SessionQueue(backend: RealBackend(client3), clock: clock3);
    final r = await q3.submit(
      uid3,
      PendingSession(
        clientUuid: s.clientUuid,
        categoryId: s.categoryId,
        categoryName: s.categoryName,
        minutes: s.durationMinutes,
        wasPaused: s.wasPaused,
        foregroundSeconds: 1500,
        startedAt: s.startedAt.toUtc(),
        queuedAt: now.toUtc(),
        clockOffsetMs: clock3.offset?.inMilliseconds,
      ),
    );
    expect(r, isA<SessionSubmitRejected>());
    expect((r as SessionSubmitRejected).reasonCode, SessionReason.tooOld,
        reason: 'tam 25 dk çalışılmış seans, devamda uyarı olmadan kalıcı reddedildi');
  });

  test('Q13 kimliksiz (e-posta anahtarlı) kuyruk: uid öğrenilince taşınır, aynı client_uuid iki kez gitmez, gönderilir', () async {
    final clock4 = ServerClock();
    final client4 = SupabaseClient(_url, _anon,
        httpClient: ServerClockHttpClient(clock4),
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));
    final email = 't1-${DateTime.now().millisecondsSinceEpoch}-dart4@pomosprint.local';
    final res = await client4.auth.signUp(email: email, password: _password, data: {'name': 'T1 Dart 4', 'avatar_id': 'avatar_16_basic'});
    final uid4 = res.user!.id;
    final q4 = SessionQueue(backend: RealBackend(client4), clock: clock4);
    final now = clock4.serverNow();
    final a = pending(startedAt: now.subtract(const Duration(minutes: 90)));
    final b = pending(startedAt: now.subtract(const Duration(minutes: 40)));
    await q4.enqueueLegacy(email.toUpperCase(), a); // anahtar küçük harfe indirgenir
    await q4.enqueueLegacy(email, b);
    await q4.enqueue(uid4, b); // aynı seans iki kuyrukta
    await q4.adoptLegacyQueue(userId: uid4, email: email);
    expect((await q4.pending(uid4)).map((e) => e.clientUuid), [a.clientUuid, b.clientUuid]);
    expect(await q4.legacyPendingCount(email), 0);
    final report = await q4.sync(uid4);
    expect((report.sent, report.remaining), (2, 0));
    final rows = await client4.from('study_sessions').select('client_uuid').eq('user_id', uid4);
    expect(rows, hasLength(2));
  });

  tearDownAll(() async {
    // Kalan hiçbir şey sunucuda değil; hesap yerelde kalır (t1- önekli).
    // ignore: avoid_print
    print('t1 Dart E2E kullanıcı: ${client.auth.currentUser?.id}');
  });
}
