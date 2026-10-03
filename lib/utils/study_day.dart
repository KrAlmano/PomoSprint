/// Çalışma günü (study day) kuralı — sunucudaki complete_study_session ile
/// aynı: `((started_at AT TIME ZONE profil_tz) - interval '4 hours')::date`.
/// Profil saat diliminde 04:00'dan önce yapılan çalışma bir önceki güne
/// sayılır.
///
/// Sunucu gün sınırını cihazın değil PROFİLİN saat diliminde (profiles.timezone,
/// varsayılan Europe/Istanbul) hesaplar. İstemci de aynı dilimi kullanır;
/// aksi halde cihazı başka dilimdeki kullanıcıya sunucunun kırdığı seri
/// gösteriliyor, seans yanlış güne yazılıyordu. Tüm istemci hesapları bu
/// dosyadaki yardımcılardan geçmelidir. Etkin dilim oturumdaki kullanıcının
/// profilinden [setStudyTimeZone] ile ayarlanır.
library;

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Yeni çalışma gününün başladığı saat (profil saat diliminde).
const int kStudyDayStartHour = 4;

/// Sunucunun varsayılan profil saat dilimi (profiles.timezone boşsa).
const String kDefaultStudyTimeZone = 'Europe/Istanbul';

String _activeTimeZone = kDefaultStudyTimeZone;
final Map<String, tz.Location?> _locations = {};

/// Etkin çalışma günü saat dilimi (oturumdaki kullanıcının profili).
String get activeStudyTimeZone => _activeTimeZone;

/// Oturumdaki kullanıcının profil saat dilimini etkin yapar. Boş ya da
/// bilinmeyen değerde sunucunun varsayılanı ([kDefaultStudyTimeZone]).
void setStudyTimeZone(String? name) {
  final clean = name?.trim() ?? '';
  _activeTimeZone = clean.isNotEmpty && _location(clean) != null ? clean : kDefaultStudyTimeZone;
}

/// IANA adına karşılık gelen konum; bilinmiyorsa null. Saat dilimi verisi
/// ilk kullanımda (bir kez) yüklenir.
tz.Location? _location(String name) {
  return _locations.putIfAbsent(name, () {
    try {
      if (!tz.timeZoneDatabase.isInitialized) tz_data.initializeTimeZones();
      return tz.getLocation(name);
    } catch (_) {
      return null;
    }
  });
}

tz.Location? _resolve(String? timeZone) =>
    _location(timeZone ?? _activeTimeZone) ?? _location(kDefaultStudyTimeZone);

/// [time] anının ait olduğu çalışma gününü (yerel gece yarısı olarak bir
/// takvim günü) döndürür. Gün, [timeZone]'da (verilmezse etkin profil
/// diliminde) hesaplanır; [time] yerel ya da UTC olabilir, yalnızca anı
/// önemlidir.
///
/// Takvim aritmetiğiyle hesaplanır (Duration çıkarılmaz), bu yüzden yaz
/// saati geçişlerinde gün kayması olmaz.
DateTime studyDayOf(DateTime time, {String? timeZone}) {
  final location = _resolve(timeZone);
  if (location == null) {
    // Saat dilimi verisi yüklenemedi: cihaz saatine düşülür.
    final t = time.isUtc ? time.toLocal() : time;
    return DateTime(t.year, t.month, t.day - (t.hour < kStudyDayStartHour ? 1 : 0));
  }
  final t = tz.TZDateTime.from(time, location);
  return DateTime(t.year, t.month, t.day - (t.hour < kStudyDayStartHour ? 1 : 0));
}

/// [day] çalışma gününün başladığı an (profil diliminde 04:00).
DateTime studyDayStart(DateTime day, {String? timeZone}) {
  final location = _resolve(timeZone);
  if (location == null) return DateTime(day.year, day.month, day.day, kStudyDayStartHour);
  return tz.TZDateTime(location, day.year, day.month, day.day, kStudyDayStartHour).toLocal();
}

/// Bir çalışma gününü sunucunun `date` biçiminde ('YYYY-MM-DD') yazar.
String studyDayKey(DateTime day) {
  final y = day.year.toString().padLeft(4, '0');
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 'YYYY-MM-DD' (veya bununla başlayan ISO metni) değerini yerel gece
/// yarısı olarak okur. Okunamazsa null döner.
DateTime? parseStudyDayKey(String? value) {
  if (value == null || value.length < 10) return null;
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// İki tarih arasındaki takvim günü farkı (`to - from`). Saat bilgisi yok
/// sayılır; yaz saati geçişlerinden etkilenmez.
int studyDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Gösterilecek seri. Sunucu kuralı: son çalışma günü bugün ya da dün
/// (profil diliminde, çalışma günü olarak) değilse seri kırılmıştır ve 0
/// görünür.
int effectiveStreak({
  required int storedStreak,
  required String? lastStudyDate,
  required DateTime now,
  String? timeZone,
}) {
  if (storedStreak <= 0) return 0;
  final last = parseStudyDayKey(lastStudyDate);
  if (last == null) return 0;
  final gap = studyDaysBetween(last, studyDayOf(now, timeZone: timeZone));
  return gap <= 1 ? storedStreak : 0;
}
