import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// [target] anına kalan süreyi gösterir. Yalnızca kendini yeniden çizer;
/// görünmeyen sekmede (TickerMode kapalı) zamanlayıcı durur. Bir günden uzun
/// sürede saniye gösterilmediği için dakikada bir güncellenir.
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  final String prefix;

  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.prefix = '',
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  bool _enabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled != _enabled) {
      _enabled = enabled;
      _schedule();
    }
  }

  @override
  void didUpdateWidget(covariant CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_enabled) return;
    final remaining = widget.target.difference(DateTime.now());
    if (remaining.isNegative) return;
    final delay = remaining.inDays > 0
        ? Duration(seconds: remaining.inSeconds % 60 + 1)
        : const Duration(seconds: 1);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = formatRemainingTime(l10n, widget.target.difference(DateTime.now()));
    return Text('${widget.prefix}$text', style: widget.style);
  }
}

String formatRemainingTime(AppLocalizations l10n, Duration diff) {
  if (diff.isNegative) return l10n.rankingCountdownResetting;
  final hours = diff.inHours % 24;
  final minutes = diff.inMinutes % 60;
  if (diff.inDays > 0) return l10n.rankingCountdownDays(diff.inDays, hours, minutes);
  return l10n.rankingCountdownHours(hours, minutes, diff.inSeconds % 60);
}
