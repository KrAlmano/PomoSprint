import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    testWidgets(
      'start rate rejection stops retries and is explained ($language)',
      (tester) async {
        final backend = FakeExamBackend();
        final service = ExamService(
          backend: backend,
          createUuid: () => 'rate-limit-attempt',
        );
        await service.initialize();
        backend.handler = (name, params) async {
          if (name == 'start_exam_attempt') {
            throw const PostgrestException(
              message: 'exam_start_rate_limited',
              code: 'P0001',
            );
          }
          return backend.defaultRpc(name, params);
        };
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExamScreen(service: service)),
          ),
        );
        await tester.pumpAndSettle();
        await service.start(service.catalog.exams.first);
        await tester.pumpAndSettle();
        expect(service.errorCode, 'exam_start_rate_limited');
        expect(service.activeRecord, isNull);
        expect(service.records.single.pendingAction, isNull);
        expect(
          find.text(
            lookupAppLocalizations(Locale(language)).examStartRateLimited,
          ),
          findsWidgets,
        );
        final count = backend.calls
            .where((c) => c.$1 == 'start_exam_attempt')
            .length;
        await service.sync();
        expect(
          backend.calls.where((c) => c.$1 == 'start_exam_attempt').length,
          count,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        backend.owner.dispose();
      },
    );
  }
}
