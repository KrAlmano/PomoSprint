import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/friends_sheet.dart';

import 'support/fake_supabase_service.dart';

class _FriendsService extends FakeSupabaseService {
  final delayed = Completer<List<Map<String, dynamic>>>();
  int fetches = 0;
  @override
  Future<String?> getMyFriendCode() async => 'DEF456';
  @override
  Future<List<Map<String, dynamic>>> fetchFriends() async {
    fetches++;
    if (fetches == 2) return delayed.future;
    return [
      {'id': 'friend', 'name': fetches == 1 ? 'Eski liste' : 'Yeni liste'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingFriendRequests() async => [];
  @override
  Future<Map<String, dynamic>> addFriendByCode(String code) async => {
    'success': true,
    'code': 'request_sent',
  };
}

void main() {
  testWidgets('geç gelen eski arkadaş yenilemesi son işlem sonucunu ezmez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FriendsService();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FriendsSheet(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text('Eski liste'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.tap(find.text(l10n.addBtn));
    await tester.pumpAndSettle();
    expect(service.fetches, 2);
    await tester.enterText(find.byType(TextField), 'BCD234');
    await tester.tap(find.text(l10n.addBtn));
    await tester.pumpAndSettle();
    expect(find.text('Yeni liste'), findsOneWidget);

    service.delayed.complete([
      {'id': 'old', 'name': 'Gecikmiş eski liste'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Yeni liste'), findsOneWidget);
    expect(find.text('Gecikmiş eski liste'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
