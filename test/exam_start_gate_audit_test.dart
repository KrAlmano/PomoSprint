import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

void main() {
  testWidgets(
    'exam start revalidates the owner after an asynchronous local gate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final backend = FakeExamBackend(), gate = Completer<bool>();
      final service = ExamService(backend: backend);
      var checks = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExamScreen(
              service: service,
              canStartAsync: () {
                checks++;
                return gate.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('exam-start-tyt')));
      await tester.tap(find.byKey(const ValueKey('exam-start-tyt')));
      await tester.pump();
      expect(checks, 1);
      backend.owner.value = 'owner-2';
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(backend.calls.where((c) => c.$1 == 'start_exam_attempt'), isEmpty);
      expect(service.records, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      backend.owner.dispose();
    },
  );
}
