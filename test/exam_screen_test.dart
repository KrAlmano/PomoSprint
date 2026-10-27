import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

Widget _app(
  ExamService service, {
  String language = 'tr',
  double scale = 1,
  bool dark = false,
}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: ExamScreen(service: service)),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('catalog fits TR/EN, large text, portrait landscape and tablet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(430, 932),
      Size(844, 390),
      Size(768, 1024),
      Size(1024, 768),
    ]) {
      for (final language in ['tr', 'en']) {
        final backend = FakeExamBackend();
        final service = ExamService(backend: backend);
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _app(service, language: language, scale: 2, dark: language == 'en'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size $language');
        expect(find.byKey(const ValueKey('exam-start-tyt')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        backend.owner.dispose();
      }
    }
  });
  testWidgets('unavailable server shows catalog but cannot start', (
    tester,
  ) async {
    final backend = FakeExamBackend()..featureAvailable = false;
    final service = ExamService(backend: backend);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Deneme modu yakında'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('exam-start-tyt')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    backend.owner.dispose();
  });
  testWidgets(
    'completion exposes score entry and abandoned attempt stays in history',
    (tester) async {
      final backend = FakeExamBackend();
      final service = ExamService(
        backend: backend,
        createUuid: () => 'widget-attempt',
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await service.start(service.catalog.exams.first);
      await tester.pump();
      expect(find.byKey(const ValueKey('exam-countdown')), findsOneWidget);
      expect(find.text('Duraklat'), findsNothing);
      backend.clock = backend.clock.add(const Duration(minutes: 165));
      await service.complete(service.activeRecord!.clientUuid);
      await tester.pumpAndSettle();
      expect(find.text('Netlerini gir'), findsOneWidget);
      expect(find.text('Deneme tamamlandı'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      backend.owner.dispose();
    },
  );
}
