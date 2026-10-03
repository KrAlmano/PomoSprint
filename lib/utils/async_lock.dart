import 'dart:async';

/// Asenkron işlemleri geliş sırasıyla ve tek tek (biri bitmeden sıradaki
/// başlamadan) çalıştıran basit bir kilit (Future zinciri). Aynı kilit
/// [synchronized] içinden yeniden alınmamalıdır; aksi halde işlem kendini
/// bekler.
class AsyncLock {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  /// Kilidi tutan ya da bekleyen işlem var mı?
  bool get isLocked => _pending > 0;

  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    _pending++;
    return previous.then((_) => action()).whenComplete(() {
      _pending--;
      done.complete();
    });
  }
}
