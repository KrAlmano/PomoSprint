import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Bağlantı olaylarını kabuğun yeniden deneme adımlarına çevirir.
///
/// connectivity_plus yalnızca bir ipucudur. iOS'ta eklenti dinleme başlarken
/// ve `checkConnectivity` izleyiciyi yeniden kurduğunda yeni başlatılmış
/// NWPathMonitor'ün ilk yolunu okur; bu yol henüz "none" olabilir.
/// Simülatörde ağ geri geldiğinde olay hiç gelmeyebilir. Bu yüzden "none"
/// hiçbir isteği engellemez ve çevrimdışı göstergesi üretmez (istekler kendi
/// hatalarıyla kuyruğa düşer; kuyruk zamanlayıcı ve ön plana dönüşle yeniden
/// denenir). Bağlı görünen her olayda [onOnline] çağrılır; bilinen son durum
/// çevrimdışıysa `cameOnline: true` olur.
class ConnectionWatcher {
  ConnectionWatcher({required this.onOnline});

  final void Function({required bool cameOnline}) onOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool? _offline;
  bool _sawEvent = false;

  /// Bilinen son durum (null: henüz bilinmiyor). Yalnızca ipucu.
  bool? get lastKnownOffline => _offline;

  /// Olayları dinler ve ilk durumu okur. İlk okuma, dinleme başladıktan sonra
  /// gelen olaydan geç dönerse onun üzerine yazmaz (aksi halde bayat "none"
  /// ya da bayat "bağlı" sonraki geri gelişi kaçırtıyordu).
  void start({
    required Stream<List<ConnectivityResult>> changes,
    required Future<List<ConnectivityResult>> Function() check,
  }) {
    _subscription = changes.listen(
      handle,
      onError: (Object e) => debugPrint('[NET] Bağlantı olayı okunamadı: $e'),
    );
    unawaited(_readInitial(check));
  }

  Future<void> _readInitial(Future<List<ConnectivityResult>> Function() check) async {
    try {
      final results = await check();
      if (!_sawEvent) _offline = isOffline(results);
    } catch (e) {
      debugPrint('[NET] Bağlantı durumu okunamadı: $e');
    }
  }

  @visibleForTesting
  void handle(List<ConnectivityResult> results) {
    _sawEvent = true;
    final offline = isOffline(results);
    final cameOnline = !offline && _offline == true;
    _offline = offline;
    if (!offline) onOnline(cameOnline: cameOnline);
  }

  static bool isOffline(List<ConnectivityResult> results) => results.contains(ConnectivityResult.none);

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
