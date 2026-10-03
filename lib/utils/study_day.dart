/// Çalışma günü (study day) kuralı — sunucudaki complete_study_session ile
/// aynı: `((started_at AT TIME ZONE profil_tz) - interval '4 hours')::date`.
/// Yerel saatle 04:00'dan önce yapılan çalışma bir önceki güne sayılır.
///
/// Not: Sunucu profildeki saat dilimini (varsayılan Europe/Istanbul),
/// istemci cihazın yerel saatini kullanır. İkisi farklıysa gün ataması
/// sapabilir; tüm istemci hesapları bu dosyadaki yardımcılardan geçmelidir.
library;

/// Yeni çalışma gününün başladığı yerel saat.
const int kStudyDayStartHour = 4;

/// [localTime]'ın ait olduğu çalışma gününü (yerel gece yarısı) döndürür.
///
/// Takvim aritmetiğiyle hesaplanır (Duration çıkarılmaz), bu yüzden yaz
/// saati geçişlerinde gün kayması olmaz. UTC bir değer verilirse önce
/// yerel saate çevrilir.
DateTime studyDayOf(DateTime localTime) {
  final t = localTime.isUtc ? localTime.toLocal() : localTime;
  return DateTime(t.year, t.month, t.day - (t.hour < kStudyDayStartHour ? 1 : 0));
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
/// (çalışma günü olarak) değilse seri kırılmıştır ve 0 görünür.
int effectiveStreak({
  required int storedStreak,
  required String? lastStudyDate,
  required DateTime now,
}) {
  if (storedStreak <= 0) return 0;
  final last = parseStudyDayKey(lastStudyDate);
  if (last == null) return 0;
  final gap = studyDaysBetween(last, studyDayOf(now));
  return gap <= 1 ? storedStreak : 0;
}
