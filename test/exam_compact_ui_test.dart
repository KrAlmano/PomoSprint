import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    for (final layout in [
      (name: '320pt', size: const Size(320, 740), scale: 1.0),
      (name: '320pt large text', size: const Size(320, 740), scale: 2.0),
      (name: 'landscape large text', size: const Size(740, 320), scale: 2.0),
    ]) {
      testWidgets('compact exam catalog $language ${layout.name}', (
        tester,
      ) async {
        final backend = DetailsExamBackend();
        final service = ExamService(backend: backend);
        addTearDown(service.dispose);
        addTearDown(backend.owner.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = layout.size;
        addTearDown(tester.view.reset);
        await service.initialize();
        final l10n = await AppLocalizations.delegate.load(Locale(language));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(layout.scale)),
              child: child!,
            ),
            home: Scaffold(body: ExamScreen(service: service)),
          ),
        );
        await tester.pumpAndSettle();

        final tabs = [
          ('new', l10n.examTabNew),
          ('history', l10n.examTabHistory),
          ('league', l10n.examTabLeague),
        ];
        final tabRects = [
          for (final (id, _) in tabs)
            tester.getRect(find.byKey(ValueKey('exam-tab-$id'))),
        ];
        for (var i = 0; i < tabs.length; i++) {
          final (id, label) = tabs[i];
          final tab = find.byKey(ValueKey('exam-tab-$id'));
          expect(tester.getSize(tab).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(tab).width, greaterThanOrEqualTo(44));
          expect(tabRects[i].width, closeTo(tabRects.first.width, .01));
          expect(tabRects[i].top, tabRects.first.top);
          expect(
            find.descendant(of: tab, matching: find.text(label)),
            findsOneWidget,
          );
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const ValueKey('exam-tab-new')));
        await tester.pumpAndSettle();

        expect(find.text(l10n.examNetInfo), findsOneWidget);
        expect(find.text(l10n.examIntro), findsNothing);
        expect(find.text(l10n.examIntroEarly), findsNothing);
        expect(find.text(l10n.examNetRule(3)), findsNothing);
        expect(find.text(l10n.examNetRule(4)), findsNothing);
        expect(find.byKey(const ValueKey('exam-net-info')), findsOneWidget);

        final filterRects = <Rect>[];
        for (final id in ['all', 'yks', 'lgs', 'tus', 'dus']) {
          final filter = find.byKey(ValueKey('exam-filter-$id'));
          await tester.ensureVisible(filter);
          final size = tester.getSize(filter);
          expect(size.height, greaterThanOrEqualTo(44));
          expect(size.width, greaterThanOrEqualTo(44));
          final rect = tester.getRect(filter);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(layout.size.width));
          final wrap = tester.renderObject<RenderBox>(
            find.ancestor(of: filter, matching: find.byType(Wrap)).first,
          );
          filterRects.add(wrap.globalToLocal(rect.topLeft) & rect.size);
        }
        if (layout.size.width == 320 && layout.scale == 2) {
          expect(
            filterRects.map((r) => r.top).toSet().length,
            greaterThan(1),
            reason: 'Narrow screens wrap filters instead of clipping them',
          );
        }
        for (final id in ['tyt', 'ayt', 'dus']) {
          final exam = offlineExamCatalog.byId(id)!;
          final card = find.byKey(ValueKey('exam-card-$id'));
          expect(card, findsOneWidget);
          expect(
            find.descendant(
              of: card,
              matching: find.text(
                l10n.examSubjectQuestions(exam.totalQuestions),
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text(
                '${exam.durationSeconds ~/ 60} ${l10n.minutesUnit}',
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: card, matching: find.byType(FilledButton)),
            findsOneWidget,
          );
          expect(
            find.text(
              exam.subjects.map((s) => s.name(language == 'tr')).join(' · '),
            ),
            findsNothing,
            reason: 'Subject lists remain in the score form, not every card',
          );
        }
        expect(find.text(l10n.examAytTestCount), findsOneWidget);

        final dusFilter = find.byKey(const ValueKey('exam-filter-dus'));
        await tester.ensureVisible(dusFilter);
        await tester.tap(dusFilter);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('exam-card-tyt')), findsNothing);
        final start = find.byKey(const ValueKey('exam-start-dus'));
        await tester.ensureVisible(start);
        expect(tester.getSize(start).height, greaterThanOrEqualTo(44));
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(find.text(l10n.examRulesTitle), findsOneWidget);
        expect(
          backend.calls.where((c) => c.$1 == 'start_exam_attempt'),
          isEmpty,
          reason: 'Opening the unchanged rules dialog does not start a session',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
