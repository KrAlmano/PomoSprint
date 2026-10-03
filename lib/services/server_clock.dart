// http, supabase_flutter'ın bağımlılığı olarak zaten pakette; Supabase'e
// özel bir HTTP istemcisi verebilmek için doğrudan kullanılıyor.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

/// Sunucu saati ile cihaz saati arasındaki farkı (sunucu - cihaz) HTTP
/// yanıtlarındaki 'date' başlığından tahmin eder.
///
/// Neden: Sunucu (complete_study_session) `started_at <= now()` ve
/// `started_at + süre <= now() + 5 dk` kurallarıyla doğruluyor
/// ('started_at cannot be in the future' / 'session_not_finished'). Saati
/// ileri olan bir cihazın gönderdiği started_at gelecekte kalıyor ve seans
/// reddediliyordu. Fark biliniyorsa started_at sunucu saatine çevrilerek
/// gönderilir.
class ServerClock {
  ServerClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Duration? _offset;

  /// Sunucunun "bitmedi / gelecekte" hatası ancak düzeltilmemiş fark bu
  /// eşikten büyükse saat sapmasıyla açıklanır (bkz. classifySessionError).
  /// Düzeltmenin kendisi eşiksizdir: [correctionFor].
  static const Duration significantSkew = Duration(seconds: 60);

  /// Yeni ölçüm eskisinden bu kadar az farklıysa eski değer korunur. Başlık
  /// saniye çözünürlüklü ve ağ gecikmesi değişken olduğu için her yanıtta
  /// fark ±1 sn oynar; sabit tutulan fark, art arda gelen seansların aynı
  /// düzeltmeyle gönderilmesini sağlar (aksi halde aralarında çakışma
  /// oluşabilir).
  static const Duration noiseBand = Duration(seconds: 2);

  // Gidiş-dönüşü bundan uzun süren ölçümler güvenilmez sayılır.
  static const Duration _maxRoundTrip = Duration(seconds: 10);

  /// Son tahmin (sunucu - cihaz). Henüz ölçüm yoksa null.
  Duration? get offset => _offset;

  /// Bir anı cihaz saatinden sunucu saatine çevirmek için uygulanacak
  /// düzeltme. Fark biliniyorsa EŞİKSİZ uygulanır (eşik, ölçümü eşiğin iki
  /// yanına düşen seanslara tutarsız düzeltme verip çakışma yaratıyordu);
  /// bilinmiyorsa sıfır.
  static Duration correctionFor(Duration? offset) => offset ?? Duration.zero;

  /// Sunucu saatine göre şimdiki an (fark bilinmiyorsa cihaz saati).
  DateTime serverNow() => _now().add(_offset ?? Duration.zero);

  void recordSample({
    required DateTime serverTime,
    required DateTime sentAt,
    required DateTime receivedAt,
  }) {
    final roundTrip = receivedAt.difference(sentAt);
    if (roundTrip.isNegative || roundTrip > _maxRoundTrip) return;
    final localMid = sentAt.add(roundTrip ~/ 2);
    // 'date' başlığı saniyeye aşağı yuvarlanır; ortalama hatayı +500 ms dengeler.
    final measured = serverTime.add(const Duration(milliseconds: 500)).difference(localMid);
    final current = _offset;
    if (current != null && (measured - current).abs() < noiseBand) return;
    _offset = measured;
  }

  void recordDateHeader(String? header, {required DateTime sentAt, required DateTime receivedAt}) {
    final serverTime = parseHttpDate(header);
    if (serverTime != null) {
      recordSample(serverTime: serverTime, sentAt: sentAt, receivedAt: receivedAt);
    }
  }
}

const Map<String, int> _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// RFC 7231 IMF-fixdate ('Sun, 06 Nov 1994 08:49:37 GMT') değerini UTC
/// olarak okur. Okunamazsa null döner.
DateTime? parseHttpDate(String? value) {
  if (value == null) return null;
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.length != 6 || parts[5].toUpperCase() != 'GMT') return null;
  final day = int.tryParse(parts[1]);
  final month = _months[parts[2].toLowerCase()];
  final year = int.tryParse(parts[3]);
  final time = parts[4].split(':');
  if (day == null || month == null || year == null || time.length != 3) return null;
  final h = int.tryParse(time[0]);
  final m = int.tryParse(time[1]);
  final s = int.tryParse(time[2]);
  if (h == null || m == null || s == null) return null;
  return DateTime.utc(year, month, day, h, m, s);
}

/// Her yanıtın 'date' başlığıyla [ServerClock]'u besleyen HTTP istemcisi.
/// Supabase.initialize(httpClient: ...) ile tüm auth/REST/RPC isteklerinde
/// kullanılır.
class ServerClockHttpClient extends http.BaseClient {
  ServerClockHttpClient(this._clock, [http.Client? inner]) : _inner = inner ?? http.Client();

  final ServerClock _clock;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sentAt = DateTime.now();
    final response = await _inner.send(request);
    _clock.recordDateHeader(response.headers['date'], sentAt: sentAt, receivedAt: DateTime.now());
    return response;
  }

  @override
  void close() => _inner.close();
}
