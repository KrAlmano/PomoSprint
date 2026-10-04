import 'package:flutter/services.dart';

/// Arkadaş kodu biçimi. Canlıdaki kodlar 6 hex karakter (0-9, A-F);
/// proposed/13 yeni kodları Crockford base32 ile üretir (I, L, O, U yok) ve
/// uzunluğu app_config.friend_code_length ile 8'e çıkarılabilir. Hex kodlar
/// Crockford alfabesinin alt kümesidir: ikisi de aynı kuralla kabul edilir.
const int kFriendCodeMinLength = 6;
const int kFriendCodeMaxLength = 8;

const String _crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Kullanıcının yazdığı / yapıştırdığı kodu sunucunun karşılaştırdığı
/// biçime getirir; sunucudaki normalize_friend_code (proposed/13) ile aynı
/// kural: boşluk, tire, alt çizgi ve nokta atılır, büyük harfe çevrilir,
/// O → 0, I ve L → 1 eşlenir. Canlı sunucu yalnızca upper(trim()) yaptığı
/// için bu adım istemcide de yapılır (eski 6 hex kodda bu harfler yok).
String normalizeFriendCode(String raw) {
  final upper = raw.replaceAll(RegExp(r'[\s_.\-]+'), '').toUpperCase();
  final out = StringBuffer();
  for (final rune in upper.runes) {
    final ch = String.fromCharCode(rune);
    out.write(switch (ch) {
      'O' => '0',
      'I' || 'L' => '1',
      _ => ch,
    });
  }
  return out.toString();
}

/// Normalize edilmiş kod biçimce geçerli mi (6–8 karakter, Crockford
/// alfabesi)? Geçersiz kod sunucuya gönderilmez: proposed/13 her denemeyi
/// saatlik sınıra sayar.
bool isValidFriendCode(String normalized) =>
    normalized.length >= kFriendCodeMinLength &&
    normalized.length <= kFriendCodeMaxLength &&
    normalized.split('').every(_crockfordAlphabet.contains);

/// Kod alanının girdi biçimlendiricisi: yazılan ya da yapıştırılan metni
/// [normalizeFriendCode] ile normalize eder, alfabe dışı karakterleri atar
/// ve [kFriendCodeMaxLength] karakterde keser. İmleç her zaman sona alınır.
class FriendCodeInputFormatter extends TextInputFormatter {
  const FriendCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final filtered = normalizeFriendCode(newValue.text).split('').where(_crockfordAlphabet.contains).join();
    final text = filtered.length > kFriendCodeMaxLength ? filtered.substring(0, kFriendCodeMaxLength) : filtered;
    if (text == newValue.text) return newValue;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
