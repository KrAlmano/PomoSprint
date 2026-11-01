import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// SDK transport types are deliberately exercised without adding a runtime dependency.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
// This regression deliberately verifies the installed SDK's header behavior.
// ignore: implementation_imports, depend_on_referenced_packages
import 'package:supabase/src/auth_http_client.dart';

void main() {
  test('pinned owner survives account switch while SDK resolves token', () async {
    for (final rpc in ['start_study_session', 'start_marathon_break', 'confirm_marathon_presence']) {
    final lookup = Completer<String?>();
    final seen = <String?>[];
    final inner = MockClient((request) async {
      seen.add(request.headers['authorization']);
      return http.Response('{}', 200);
    });
    final client = AuthHttpClient('public-key', inner, () => lookup.future);
    final request = http.Request('POST', Uri.parse('https://example.invalid/rest/v1/rpc/$rpc'))
      ..headers['Authorization'] = 'Bearer token-for-owner-a';

    final response = client.send(request);
    // Simulate switching to B before the SDK's asynchronous token lookup ends.
    lookup.complete('token-for-owner-b');
    await response;
    expect(seen, ['Bearer token-for-owner-a']);
    client.close();
    }
  });
}
