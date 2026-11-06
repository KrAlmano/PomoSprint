import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/rejected_sessions_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';

import 'support/fake_supabase_service.dart';

class _BrokenRecords extends FakeSupabaseService {
  @override
  Future<List<PendingSession>> getPendingSessions() async => throw const FormatException('session_queue_invalid');
  @override
  Future<List<RejectedSession>> getRejectedSessions() async => throw const FormatException('session_queue_invalid');
}

void main() {
  testWidgets('unreadable local records are reported in both languages instead of showing an empty archive', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final locale in [const Locale('tr'), const Locale('en')]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final service = _BrokenRecords();
      Widget app(Widget child) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );
      await tester.pumpWidget(app(ReportsScreen(categories: const [], service: service)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionRecordsUnreadable), findsOneWidget);
      await tester.pumpWidget(app(RejectedSessionsScreen(service: service)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionRecordsUnreadable), findsOneWidget);
      expect(find.text(l10n.rejectedSessionsEmpty), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(tester.takeException(), isNull);
  });
}
