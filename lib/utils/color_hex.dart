import 'dart:ui' show Color;

/// '#RRGGBB' / 'RRGGBB' / '#AARRGGBB' biçimindeki rengi okur. Geçersiz ya da
/// boş değerde [fallback] döner. Projedeki tüm hex → Color dönüşümleri bu
/// yardımcıdan geçmelidir.
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF9E9E9E)}) {
  if (hex == null) return fallback;
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return fallback;
  final value = int.tryParse(s, radix: 16);
  return value == null ? fallback : Color(value);
}

/// Rengi sunucunun beklediği 6 haneli '#RRGGBB' biçimine çevirir (alfa atılır).
String colorToHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
