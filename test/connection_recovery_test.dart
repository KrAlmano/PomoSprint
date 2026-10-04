// İnternet bağlantısı ve bulutun kendini toparlaması: açılışta başlatılamayan
// bulut sonradan bağlanır (geçici hata kalıcı çevrimdışı sayılmaz), giriş
// başlatmayı yeniden dener, bağlantı olayları yalnızca ipucudur (iOS'ta
// sahte "none" hiçbir şeyi engellemez) ve bağlantı geri gelince kabuk
// yeniden dener.
//
// Supabase başlatılmadan çalışır; başlatıcı testte sahtesiyle değiştirilir.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/connection_watcher.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = SupabaseService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.debugCloudActive = false;
    service.debugCloudInitializer = null;
  });

  tearDown(() {
    service.debugCloudActive = false;
    service.debugCloudInitializer = null;
  });

  group('Bulut başlatması kalıcı olarak düşmez', () {
    test('test ortamında başlatıcı verilmezse denenmez (canlı projeye bağlanılmaz)', () async {
      expect(await service.ensureCloud(), isFalse);
      expect(service.isCloudActive, isFalse);
    });

    test('açılışta başlatma hata verdi; sonraki deneme bağlanır, bağlıyken yeniden başlatılmaz', () async {
      var attempts = 0;
      service.debugCloudInitializer = () async {
        attempts++;
        if (attempts == 1) throw StateError('yerel depo geçici olarak okunamadı');
        service.debugCloudActive = true;
      };

      expect(await service.ensureCloud(), isFalse, reason: 'açılıştaki deneme');
      expect(await service.ensureCloud(), isTrue, reason: 'ağ/bağlantı geri gelince kabuk yeniden dener');
      expect(await service.ensureCloud(), isTrue);
      expect(attempts, 2);
    });

    test('eşzamanlı çağrılar (splash, kabuk, giriş) tek denemede birleşir', () async {
      final gate = Completer<void>();
      var attempts = 0;
      service.debugCloudInitializer = () async {
        attempts++;
        await gate.future;
        service.debugCloudActive = true;
      };

      final results = [service.ensureCloud(), service.ensureCloud(), service.ensureCloud()];
      gate.complete();
      expect(await Future.wait(results), [true, true, true]);
      expect(attempts, 1);
    });

    test('splash süresi dolunca bekleyen bırakılır, deneme sürer; kabuk aynı denemeye katılır', () async {
      final gate = Completer<void>();
      var attempts = 0;
      service.debugCloudInitializer = () async {
        attempts++;
        await gate.future;
        service.debugCloudActive = true;
      };

      expect(await service.ensureCloud(timeout: const Duration(milliseconds: 10)), isFalse);
      final shell = service.ensureCloud();
      gate.complete();
      expect(await shell, isTrue);
      expect(attempts, 1, reason: 'ikinci Supabase.initialize çağrısı yapılmaz');
    });

    test('giriş, açılışta başlatılamamış bulutu her denemede yeniden dener', () async {
      var attempts = 0;
      service.debugCloudInitializer = () async {
        attempts++;
        throw StateError('başlatılamadı');
      };

      for (var i = 1; i <= 2; i++) {
        await expectLater(
          service.loginUser('ayse@example.com', 'Abcde1'),
          throwsA(isA<AuthFailure>().having((e) => e.code, 'code', AuthErrorCode.cloudUnavailable)),
        );
        expect(attempts, i);
      }
    });

    test('bağlantı geri gelince veri ekranları yenilenir', () {
      var reloads = 0;
      void listener() => reloads++;
      service.addStatsChangedListener(listener);
      addTearDown(() => service.removeStatsChangedListener(listener));
      service.notifyConnectionRestored();
      expect(reloads, 1);
    });
  });

  group('Bağlantı olayları (connectivity_plus yalnızca ipucu)', () {
    late StreamController<List<ConnectivityResult>> changes;
    late List<bool> online;
    late ConnectionWatcher watcher;

    setUp(() {
      changes = StreamController<List<ConnectivityResult>>();
      online = [];
      watcher = ConnectionWatcher(onOnline: ({required bool cameOnline}) => online.add(cameOnline));
    });

    tearDown(() async {
      await watcher.dispose();
      await changes.close();
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('açılışta ağ yok, sonra ağ gelir: geri geldi sayılır ve kabuk yeniden dener', () async {
      watcher.start(changes: changes.stream, check: () async => [ConnectivityResult.none]);
      await settle();
      expect(watcher.lastKnownOffline, isTrue);

      changes.add([ConnectivityResult.wifi]);
      await settle();
      expect(online, [true]);
      expect(watcher.lastKnownOffline, isFalse);
    });

    test('iOS: dinleme başındaki sahte "none" hiçbir şeyi tetiklemez ya da engellemez', () async {
      watcher.start(changes: changes.stream, check: () async => [ConnectivityResult.wifi]);
      changes.add([ConnectivityResult.none]);
      await settle();
      expect(online, isEmpty, reason: '"none" yalnızca not edilir; çevrimdışı göstergesi ya da istek engeli yok');

      changes.add([ConnectivityResult.wifi]);
      await settle();
      expect(online, [true], reason: 'ardından gelen gerçek yol kuyruğu ve profili yeniden dener');
    });

    test('geç dönen ilk okuma, sonra gelen olayın üzerine yazmaz', () async {
      final initial = Completer<List<ConnectivityResult>>();
      watcher.start(changes: changes.stream, check: () => initial.future);
      changes.add([ConnectivityResult.none]);
      await settle();
      initial.complete([ConnectivityResult.wifi]); // bayat: ağ bu arada gitti
      await settle();
      expect(watcher.lastKnownOffline, isTrue);

      changes.add([ConnectivityResult.wifi]);
      await settle();
      expect(online, [true], reason: 'eski kod bayat okumayla geri gelişi kaçırıyordu');
    });

    test('bağlıyken tür değişirse geri geldi sayılmaz ama kuyruk yine denenir', () async {
      watcher.start(changes: changes.stream, check: () async => [ConnectivityResult.wifi]);
      await settle();
      changes.add([ConnectivityResult.wifi]);
      changes.add([ConnectivityResult.mobile]);
      await settle();
      expect(online, [false, false]);
    });

    test('olay akışı ya da ilk okuma hata verirse dinleme sürer', () async {
      watcher.start(changes: changes.stream, check: () async => throw StateError('kanal yok'));
      changes.addError(StateError('geçici'));
      changes.add([ConnectivityResult.none]);
      changes.add([ConnectivityResult.ethernet]);
      await settle();
      expect(online, [true]);
    });
  });
}
