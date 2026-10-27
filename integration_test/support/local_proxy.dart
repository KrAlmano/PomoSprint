// Explicit local HTTP 503 simulation. This does not turn Wi-Fi/airplane mode on.
import 'dart:convert';
import 'dart:io';

import 'e2e.dart' show kSupabaseUrl;

const kE2eHttpProxy = bool.fromEnvironment('E2E_HTTP_PROXY');
const _adminPort = int.fromEnvironment(
  'E2E_PROXY_ADMIN_PORT',
  defaultValue: 54326,
);

Uri _adminUri() {
  final api = Uri.parse(kSupabaseUrl);
  if (!kE2eHttpProxy ||
      api.scheme != 'http' ||
      !{'127.0.0.1', '10.0.2.2'}.contains(api.host) ||
      api.port != 54325 ||
      api.userInfo.isNotEmpty ||
      api.path.isNotEmpty ||
      api.hasQuery ||
      api.hasFragment ||
      _adminPort != 54326) {
    throw StateError(
      'HTTP proxy QA requires explicit loopback ports 54325/54326',
    );
  }
  return Uri(
    scheme: 'http',
    host: api.host,
    port: _adminPort,
    path: '/availability',
  );
}

Future<void> setLocalHttpProxyAvailable(bool available) async {
  final uri = _adminUri();
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .postUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.contentType = ContentType.json;
    final payload = utf8.encode(jsonEncode({'available': available}));
    request.contentLength = payload.length;
    request.add(payload);
    final response = await request.close().timeout(const Duration(seconds: 5));
    final text = await utf8
        .decodeStream(response)
        .timeout(const Duration(seconds: 5));
    final result = jsonDecode(text);
    if (response.statusCode != 200 ||
        result is! Map ||
        result['available'] != available) {
      throw StateError('Local HTTP proxy did not acknowledge availability');
    }
  } finally {
    client.close(force: true);
  }
}
