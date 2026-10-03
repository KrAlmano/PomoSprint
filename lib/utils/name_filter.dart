import 'package:flutter/foundation.dart';

/// Görünen ad (sıralamada, canlı akışta ve arkadaş listesinde başkalarına
/// görünür) için küçük ve ölçülü bir küfür/hakaret denetimi.
///
/// Amaç bariz küfürleri kayıtta ve ad değiştirmede yakalamak; tam bir
/// moderasyon sistemi değil. Yanlış pozitifi önlemek için eşleşme alt dize
/// değil SÖZCÜK düzeyindedir: her terim ya sözcüğün tamamıyla (exact), ya
/// sözcük başından (prefix, Türkçe ekler için kök) ya da yalnızca hiçbir
/// masum sözcükte geçmeyen birkaç kök için sözcüğün içinde (contains) aranır.
/// Örn. "Şikayet", "Sıkışık", "Adamcık", "Amasya", "Scunthorpe", "Cocktail"
/// engellenmez.
///
/// Normalizasyon: Türkçe büyük/küçük harf (İ/I/ı → i), aksanlar (ç ğ ö ş ü
/// é …) ASCII'ye, basit leet (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, @→a, $→s, !→i),
/// görünmez karakterler silinir, harf harf yazım ("f u c k") birleştirilir,
/// tekrarlanan harfler ("fuuuck") ayrıca tek harfe indirgenmiş haliyle
/// denenir.
///
/// Sunucuda ad içeriği denetimi YOK (yalnızca 1..50 karakter CHECK'i); bu
/// denetim istemci tarafındadır.
class NameFilter {
  NameFilter._();

  /// [name] engellenen bir sözcük içeriyor mu?
  static bool isOffensive(String name) {
    for (final token in tokens(name)) {
      final collapsed = _collapseRepeats(token);
      for (final entry in _terms.entries) {
        final term = entry.key;
        final matched = switch (entry.value) {
          _Match.exact => token == term || collapsed == term,
          _Match.prefix => token.startsWith(term) || collapsed == term,
          _Match.contains => token.contains(term) || collapsed.contains(term),
        };
        if (matched) return true;
      }
    }
    return false;
  }

  /// Normalize edilmiş sözcükler (yalnızca a-z). Harf harf yazılmış diziler
  /// tek sözcükte birleştirilir.
  @visibleForTesting
  static List<String> tokens(String input) {
    final folded = _fold(input);
    final words = <String>[];
    // Önce boşluk/noktalama ile parçalara ayrılır; leet karakterleri
    // yalnızca harf içeren bir parçanın içindeyse harfe çevrilir ("s1k"),
    // yalnızca rakamdan oluşan parçalar ("1453") atılır.
    for (final chunk in folded.split(_chunkSeparator)) {
      if (chunk.isEmpty || !chunk.contains(_letter)) continue;
      final mapped = chunk.split('').map((c) => _leet[c] ?? c).join();
      words.addAll(mapped.split(_nonLetter).where((w) => w.isNotEmpty));
    }
    // "f u c k", "f.u.c.k" → "fuck"
    final merged = <String>[];
    final run = StringBuffer();
    void flush() {
      if (run.isNotEmpty) {
        merged.add(run.toString());
        run.clear();
      }
    }

    for (final w in words) {
      if (w.length == 1) {
        run.write(w);
      } else {
        flush();
        merged.add(w);
      }
    }
    flush();
    return merged;
  }

  static String _fold(String input) {
    final buffer = StringBuffer();
    // Türkçe: İ ve I önce i'ye çevrilir (Dart'ın toLowerCase'i İ'yi
    // "i + birleşik nokta" yapar); ı da aşağıda i'ye katlanır.
    final lower = input.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
    for (final rune in lower.runes) {
      if (_isInvisible(rune)) continue;
      final char = String.fromCharCode(rune);
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString();
  }

  static bool _isInvisible(int rune) =>
      (rune >= 0x0300 && rune <= 0x036F) || // birleşik aksan işaretleri
      (rune >= 0x200B && rune <= 0x200D) || // sıfır genişlikli karakterler
      rune == 0x00AD || // yumuşak tire
      rune == 0xFEFF;

  static String _collapseRepeats(String token) {
    final buffer = StringBuffer();
    for (var i = 0; i < token.length; i++) {
      if (i == 0 || token[i] != token[i - 1]) buffer.write(token[i]);
    }
    return buffer.toString();
  }

  static final RegExp _letter = RegExp('[a-z]');
  static final RegExp _nonLetter = RegExp('[^a-z]+');
  // Harf, rakam ve leet simgeleri dışındaki her şey parça ayırıcıdır.
  static final RegExp _chunkSeparator = RegExp(r'[^a-z0-9@$!|€]+');

  static const Map<String, String> _accents = {
    'ı': 'i', 'ç': 'c', 'ğ': 'g', 'ö': 'o', 'ş': 's', 'ü': 'u',
    'â': 'a', 'à': 'a', 'á': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ê': 'e', 'è': 'e', 'é': 'e', 'ë': 'e',
    'î': 'i', 'ì': 'i', 'í': 'i', 'ï': 'i',
    'ô': 'o', 'ò': 'o', 'ó': 'o', 'õ': 'o',
    'û': 'u', 'ù': 'u', 'ú': 'u',
    'ñ': 'n', 'ß': 'ss', 'ÿ': 'y',
  };

  static const Map<String, String> _leet = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
    '@': 'a', r'$': 's', '!': 'i', '|': 'i', '€': 'e',
  };

  // Normalize edilmiş biçimde. Kısa, ölçülü liste: başka bir anlamı olan ya da
  // Türkçe/İngilizce bir sözcüğün parçası olan ifadeler (ör. "göt"→got,
  // "sık"→sik, "amına"→Amina adı, "ass", "dick", "cock") bilinçli olarak yok.
  static const Map<String, _Match> _terms = {
    // Türkçe
    'orospu': _Match.contains,
    'siktir': _Match.contains,
    'sikeyim': _Match.prefix,
    'sikerim': _Match.prefix,
    'sikik': _Match.prefix,
    'amcik': _Match.prefix,
    'aminako': _Match.prefix,
    'yarrak': _Match.prefix,
    'yarrag': _Match.prefix,
    'yarram': _Match.prefix,
    'yarak': _Match.exact,
    'dalyarak': _Match.prefix,
    'pezevenk': _Match.prefix,
    'kahpe': _Match.prefix,
    'kaltak': _Match.prefix,
    'kancik': _Match.prefix,
    'serefsiz': _Match.prefix,
    'gavat': _Match.prefix,
    'yavsak': _Match.prefix,
    'ibne': _Match.prefix,
    'gerizekali': _Match.prefix,
    'gotveren': _Match.prefix,
    'gotlek': _Match.prefix,
    'tasak': _Match.prefix,
    'tassak': _Match.prefix,
    'pust': _Match.exact,
    'pic': _Match.exact,
    'amk': _Match.exact,
    // İngilizce
    'fuck': _Match.contains,
    'bitch': _Match.prefix,
    'cunt': _Match.prefix,
    'asshole': _Match.prefix,
    'bastard': _Match.prefix,
    'whore': _Match.prefix,
    'wanker': _Match.prefix,
    'nigger': _Match.prefix,
    'faggot': _Match.prefix,
    'dickhead': _Match.prefix,
    'cocksucker': _Match.prefix,
    'nigga': _Match.exact,
    'niggas': _Match.exact,
    'shit': _Match.exact,
    'shitty': _Match.exact,
    'shithead': _Match.exact,
    'bullshit': _Match.exact,
    'slut': _Match.exact,
    'sluts': _Match.exact,
    'slutty': _Match.exact,
    'retard': _Match.exact,
    'retarded': _Match.exact,
    'retards': _Match.exact,
    'twat': _Match.exact,
    'pussy': _Match.exact,
    'jackass': _Match.exact,
    'dumbass': _Match.exact,
    'hitler': _Match.exact,
  };
}

enum _Match { exact, prefix, contains }
