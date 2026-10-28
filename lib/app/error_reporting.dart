import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final RegExp _emailPattern = RegExp(
  r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
);
final RegExp _urlPattern = RegExp(r'''https?://[^\s<>"']+''');
final RegExp _authorizationPattern = RegExp(
  r'''\b(Bearer|Basic)\s+[^\s,;"']+''',
  caseSensitive: false,
);
final RegExp _jwtPattern = RegExp(
  r'\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b',
);
final RegExp _credentialAssignment = RegExp(
  r'''\b(password|passwd|access[_-]?token|refresh[_-]?token|id[_-]?token|api[_-]?key|client[_-]?secret|secret|token)\s*[=:]\s*["']?[^\s,;"'}]+''',
  caseSensitive: false,
);
final RegExp _privateKey = RegExp(
  r'-----BEGIN [^-]*PRIVATE KEY-----[\s\S]*?(?:-----END [^-]*PRIVATE KEY-----|$)',
);
const _maxDepth = 8;
const _maxEntries = 64;
const _maxStringLength = 2048;

/// Kept public for existing callers; the event boundary additionally removes
/// credentials, request payloads and nested personal data.
String maskEmails(String text) => text.replaceAll(_emailPattern, '[email]');

String _safeUrl(String value) {
  if (value.length > 8192) return '[redacted-url]';
  final uri = Uri.tryParse(value);
  if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
    return '[redacted-url]';
  }
  // Rebuild instead of replace(query: null): null would retain the old query.
  String path;
  try {
    path = maskEmails(Uri.decodeFull(uri.path));
  } on FormatException {
    return '[redacted-url]';
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}

String _cleanText(String value) {
  var text = value.length > 8192
      ? '${value.substring(0, 8192)}[truncated]'
      : value;
  text = text.replaceAll(_privateKey, '[redacted]');
  text = text.replaceAllMapped(_urlPattern, (match) => _safeUrl(match[0]!));
  text = maskEmails(text);
  text = text.replaceAllMapped(
    _authorizationPattern,
    (match) => '${match[1]} [redacted]',
  );
  text = text.replaceAll(_jwtPattern, '[redacted]');
  text = text.replaceAllMapped(
    _credentialAssignment,
    (match) => '${match[1]}=[redacted]',
  );
  return text.length > _maxStringLength
      ? '${text.substring(0, _maxStringLength)}[truncated]'
      : text;
}

bool _privateField(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  if (const {
    'user',
    'userid',
    'username',
    'fullname',
    'email',
    'phone',
    'phonenumber',
    'ip',
    'ipaddress',
    'query',
    'querystring',
    'httpquery',
    'fragment',
    'httpfragment',
    'body',
    'requestbody',
    'responsebody',
    'headers',
    'requestheaders',
    'responseheaders',
    'jwt',
    'otp',
    'credentials',
    'credential',
    'session',
    'sessionid',
    'codeverifier',
    'codechallenge',
    // Owner-only exam details may contain arbitrary personal text. Removing
    // the whole patch also protects future nested fields before RPC transport.
    'title',
    'note',
    'examtitle',
    'examnote',
    'details',
    'pdetails',
    'detailspatch',
  }.contains(normalized)) {
    return true;
  }
  return const [
    'password',
    'passwd',
    'authorization',
    'cookie',
    'token',
    'secret',
    'apikey',
    'privatekey',
    'sessionkey',
    'accesskey',
  ].any(normalized.contains);
}

Object? _cleanData(Object? value, [int depth = 0]) {
  if (depth >= _maxDepth) return null;
  if (value == null || value is bool) return value;
  if (value is num) return value.isFinite ? value : null;
  if (value is String) return _cleanText(value);
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries.take(_maxEntries)) {
      if (entry.key is! String ||
          (entry.key as String).length > 128 ||
          _privateField(entry.key as String)) {
        continue;
      }
      result[_cleanText(entry.key as String)] = _cleanData(
        entry.value,
        depth + 1,
      );
    }
    return result;
  }
  if (value is List) {
    return value
        .take(_maxEntries)
        .map((item) => _cleanData(item, depth + 1))
        .toList();
  }
  // Do not invoke arbitrary toString() on application objects at the boundary.
  return null;
}

Map<String, dynamic> _cleanMap(Map<String, dynamic> data) =>
    _cleanData(data)! as Map<String, dynamic>;

Breadcrumb _cleanBreadcrumb(Breadcrumb value) =>
    Breadcrumb.fromJson(_cleanMap(value.toJson()));

SentryRequest? _cleanRequest(SentryRequest? request) => request == null
    ? null
    : SentryRequest(
        url: request.url == null ? null : _safeUrl(request.url!),
        method: request.method == null ? null : _cleanText(request.method!),
      );

SentryEvent _cleanEvent(SentryEvent event) {
  final data = event.toJson();
  // These typed fields are rebuilt separately; no body/header/user payload is
  // handed to a protocol decoder, even when it contains unexpected shapes.
  data.remove('user');
  data.remove('request');
  final clean = SentryEvent.fromJson(_cleanMap(data));
  clean.user = null;
  clean.serverName = null;
  clean.request = _cleanRequest(event.request);
  return clean;
}

SentryTransaction _cleanTransaction(SentryTransaction event) {
  final clean = _cleanEvent(event);
  event.user = null;
  event.serverName = null;
  event.request = clean.request;
  event.message = clean.message;
  event.exceptions = clean.exceptions;
  event.threads = clean.threads;
  event.breadcrumbs = clean.breadcrumbs;
  event.contexts = clean.contexts;
  event.tags = clean.tags;
  // SDK 9.26 still serializes extra; sanitize it as well as structured contexts.
  // ignore: deprecated_member_use
  event.extra = clean.extra;
  event.transaction = clean.transaction;
  event.culprit = clean.culprit;
  event.fingerprint = clean.fingerprint;
  if (event.spans.length > _maxEntries) {
    event.spans.removeRange(_maxEntries, event.spans.length);
  }
  for (final span in event.spans) {
    final data = _cleanMap(span.data);
    final tags = _cleanMap(span.tags);
    span.data
      ..clear()
      ..addAll(data);
    span.tags
      ..clear()
      ..addAll(tags.cast<String, String>());
    final description = span.context.description;
    span.context.description = description == null
        ? null
        : _cleanText(description);
    span.context.operation = _cleanText(span.context.operation);
  }
  return event;
}

/// Scrubs error, transaction and breadcrumb payloads before SDK transport.
/// This does not configure a remote alert or automatically capture HTTP 500s.
void configureSentry(SentryFlutterOptions options, {required String dsn}) {
  options.dsn = dsn;
  options.tracesSampleRate = 0.2;
  options.environment = kReleaseMode ? 'production' : 'debug';
  options.sendDefaultPii = false;
  options.enablePrintBreadcrumbs = false;
  options.beforeBreadcrumb = (breadcrumb, hint) =>
      breadcrumb == null ? null : _cleanBreadcrumb(breadcrumb);
  options.beforeSend = (event, hint) => _cleanEvent(event);
  options.beforeSendTransaction = (event, hint) => _cleanTransaction(event);
}
