import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final RegExp _emailPattern = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

/// Metindeki e-posta adreslerini maskeler.
String maskEmails(String text) => text.replaceAll(_emailPattern, '[email]');

/// Sentry ayarları. Kişisel veri (IP, e-posta) gönderilmez: debugPrint
/// çıktıları breadcrumb olarak toplanmaz, kalan breadcrumb ve olay
/// metinlerindeki e-posta adresleri maskelenir.
void configureSentry(SentryFlutterOptions options, {required String dsn}) {
  options.dsn = dsn;
  options.tracesSampleRate = 0.2;
  options.environment = kReleaseMode ? 'production' : 'debug';
  options.sendDefaultPii = false;
  options.enablePrintBreadcrumbs = false;
  options.beforeBreadcrumb = (breadcrumb, hint) {
    if (breadcrumb != null) _scrubBreadcrumb(breadcrumb);
    return breadcrumb;
  };
  options.beforeSend = (event, hint) {
    final message = event.message;
    if (message != null) message.formatted = maskEmails(message.formatted);
    for (final exception in event.exceptions ?? const <SentryException>[]) {
      final value = exception.value;
      if (value != null) exception.value = maskEmails(value);
    }
    for (final breadcrumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
      _scrubBreadcrumb(breadcrumb);
    }
    return event;
  };
}

void _scrubBreadcrumb(Breadcrumb breadcrumb) {
  final message = breadcrumb.message;
  if (message != null) breadcrumb.message = maskEmails(message);
  final data = breadcrumb.data;
  if (data != null) {
    breadcrumb.data = {
      for (final entry in data.entries) entry.key: entry.value is String ? maskEmails(entry.value as String) : entry.value,
    };
  }
}
