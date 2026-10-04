/// Hazır kategori adlarının Türkçe/İngilizce eşleri. Ad DB'de çoğunlukla
/// Türkçe saklanır; İngilizce arayüzle onboarding yapan kullanıcıda
/// İngilizce de olabilir. Gösterim [localizedKnownCategoryName], dilden
/// bağımsız eşleme [categoryMatchKey] ile yapılır.
const List<(String tr, String en)> kKnownCategoryNames = [
  ('Matematik', 'Mathematics'),
  ('Fizik', 'Physics'),
  ('Tarih', 'History'),
  ('Kimya', 'Chemistry'),
  ('Biyoloji', 'Biology'),
  ('Edebiyat', 'Literature'),
  ('İngilizce', 'English'),
  ('Türkçe', 'Turkish'),
  // Onboarding'de önerilen ek kategoriler (segment bazlı öneriler).
  ('Fen Bilimleri', 'Science'),
  ('Din Kültürü', 'Religious Culture'),
  ('Coğrafya', 'Geography'),
  ('Felsefe', 'Philosophy'),
  ('Ders Çalışma', 'Studying'),
  ('Ödev', 'Homework'),
  ('Proje', 'Project'),
  ('Sınav Hazırlık', 'Exam Prep'),
  ('Derin Çalışma', 'Deep Work'),
  ('Okuma', 'Reading'),
  ('Öğrenme', 'Learning'),
  ('T.C. İnkılap Tarihi', 'Turkish Revolution History'),
  // KPSS ve dil sınavı önerileri.
  ('Vatandaşlık', 'Citizenship'),
  ('Güncel Bilgiler', 'Current Affairs'),
  ('Eğitim Bilimleri', 'Educational Sciences'),
  ('Kelime', 'Vocabulary'),
  ('Dilbilgisi', 'Grammar'),
  ('Dinleme', 'Listening'),
  ('Yazma', 'Writing'),
  ('Konuşma', 'Speaking'),
];

// Dart'ın toLowerCase()'i Türkçeye özgü değil: 'İ' → 'i' + U+0307 (birleşik
// nokta). Nokta atılır; böylece 'İngilizce' ile 'ingilizce' eşleşir.
String _normalize(String name) => name.trim().toLowerCase().replaceAll('̇', '');

(String, String)? _knownPair(String name) {
  final n = _normalize(name);
  for (final pair in kKnownCategoryNames) {
    if (n == _normalize(pair.$1) || n == _normalize(pair.$2)) return pair;
  }
  return null;
}

/// Bilinen bir kategori adının arayüz dilindeki karşılığı; bilinmeyen ad
/// olduğu gibi döner.
String localizedKnownCategoryName(String name, {required bool turkish}) {
  final pair = _knownPair(name);
  if (pair == null) return name;
  return turkish ? pair.$1 : pair.$2;
}

/// Dilden bağımsız eşleme anahtarı: büyük/küçük harf ve baş/son boşluk
/// duyarsız; 'Fizik', 'fizik' ve 'Physics' aynı anahtara düşer.
String categoryMatchKey(String name) {
  final pair = _knownPair(name);
  return pair == null ? _normalize(name) : _normalize(pair.$1);
}
