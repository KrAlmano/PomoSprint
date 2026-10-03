import 'package:intl/intl.dart';

/// İstatistik ekranlarındaki tek süre biçimi: '50dk', '1sa', '1sa 5dk'.
String formatStudyMinutes(int minutes, {required String hourAbbr, required String minAbbr}) {
  final safe = minutes < 0 ? 0 : minutes;
  final h = safe ~/ 60;
  final m = safe % 60;
  if (h == 0) return '$m$minAbbr';
  if (m == 0) return '$h$hourAbbr';
  return '$h$hourAbbr $m$minAbbr';
}

/// Yerel ayara uygun yüzde biçimi (TR '%50', EN '50%').
String formatPercent(int percent, String locale) =>
    NumberFormat.percentPattern(locale).format(percent / 100);
