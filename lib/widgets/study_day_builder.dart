import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/stats_calculator.dart' show addDays;
import '../utils/study_day.dart';

/// Yeni çalışma günü (profil diliminde 04:00) başladığında ve uygulamaya
/// dönüldüğünde yeniden çizer; [builder] o anki zamanı alır. Güne bağlı
/// gösterimler (ör. üst çubuktaki seri) sekme değişmeden de tazelenir.
class StudyDayBuilder extends StatefulWidget {
  const StudyDayBuilder({super.key, required this.builder, this.now = DateTime.now});

  final Widget Function(BuildContext context, DateTime now) builder;

  /// Şimdiki zaman (testte sahtesi verilir).
  final DateTime Function() now;

  @override
  State<StudyDayBuilder> createState() => _StudyDayBuilderState();
}

class _StudyDayBuilderState extends State<StudyDayBuilder> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Arka planda gün dönmüş olabilir; zamanlayıcı askıdayken kaymış olabilir.
      setState(() {});
      _schedule();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final now = widget.now();
    var wait = studyDayStart(addDays(studyDayOf(now), 1)).difference(now);
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.now());
}
