import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import 'user_report.dart';

/// Kullanıcıya ve destek e-postasına yazılan sürüm: "1.0.0 (12)".
String formatAppVersion(String version, String buildNumber) =>
    (buildNumber.isEmpty || buildNumber == version) ? version : '$version ($buildNumber)';

/// Uygulamanın sürümü (pubspec `version`). Okunamazsa null.
Future<String?> loadAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return null;
    return formatAppVersion(info.version, info.buildNumber);
  } catch (e) {
    debugPrint('[APP] Sürüm okunamadı: $e');
    return null;
  }
}

/// Destek e-postasına yazılan cihaz bilgisi (işletim sistemi ve sürümü;
/// kişisel veri içermez).
String deviceDescription() {
  if (kIsWeb) return 'web';
  try {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } catch (_) {
    return defaultTargetPlatform.name;
  }
}

/// "Destek ve geri bildirim" e-postası: destek@ adresine, gövdede uygulama
/// sürümü ve cihaz. Kullanıcının e-postası ya da kimliği URL'ye konmaz
/// (gönderen adresini e-posta uygulaması ekler).
Uri supportEmailUri(AppLocalizations l10n, {required String? version, required String device}) {
  return buildUserReportUri(
    subject: l10n.supportEmailSubject,
    body: l10n.supportEmailBody(version ?? '-', device),
  );
}
