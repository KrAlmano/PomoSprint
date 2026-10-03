// X11: üst çubuktaki seri 04:00 gün dönümünde yeniden hesaplanmalı.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:pomodoro/widgets/study_day_builder.dart';

void main() {
  testWidgets('X11: seri, sekme değişmeden 04:00\'te kırılır', (tester) async {
    // last_study_date = 2 Ekim; 4 Ekim 03:50 (İstanbul) hâlâ 3 Ekim çalışma günü.
    final user = UserModel(id: 'u', name: 'U', email: 'u@example.com', currentStreak: 5, lastStudyDate: '2026-10-02');
    var now = studyDayStart(DateTime(2026, 10, 4)).subtract(const Duration(minutes: 10));
    var builds = 0;

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: StudyDayBuilder(
        now: () => now,
        builder: (context, at) {
          builds++;
          return Text('${user.streakOn(at)}');
        },
      ),
    ));
    expect(find.text('5'), findsOneWidget);

    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(minutes: 11));
    expect(find.text('0'), findsOneWidget);
    expect(builds, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('X11: uygulamaya dönüşte gün yeniden değerlendirilir', (tester) async {
    var now = DateTime.utc(2026, 10, 3, 10);
    final days = <DateTime>[];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: StudyDayBuilder(
        now: () => now,
        builder: (context, at) {
          days.add(studyDayOf(at));
          return const SizedBox.shrink();
        },
      ),
    ));
    now = DateTime.utc(2026, 10, 5, 10);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(days.last, DateTime(2026, 10, 5));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
