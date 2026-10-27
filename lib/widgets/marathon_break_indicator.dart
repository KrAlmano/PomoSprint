import 'package:flutter/material.dart';

/// A still coffee cup with slow, low-amplitude steam during a marathon break.
/// The owning timer supplies all break state and accessible countdown text.
class MarathonBreakIndicator extends StatefulWidget {
  const MarathonBreakIndicator({
    super.key,
    this.size = 140,
    this.color = Colors.teal,
  }) : assert(size > 0);

  final double size;
  final Color color;

  @override
  State<MarathonBreakIndicator> createState() => _MarathonBreakIndicatorState();
}

class _MarathonBreakIndicatorState extends State<MarathonBreakIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _steam;

  @override
  void initState() {
    super.initState();
    _steam = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      value: 0.5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduced && TickerMode.valuesOf(context).enabled) {
      if (!_steam.isAnimating) _steam.repeat(reverse: true);
    } else {
      _steam.stop();
      if (reduced) _steam.value = 0.5;
    }
  }

  @override
  void dispose() {
    _steam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: Stack(
        children: [
          Positioned(
            left: widget.size * 0.27,
            top: widget.size * 0.01,
            width: widget.size * 0.4,
            height: widget.size * 0.25,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _steam,
                child: CustomPaint(
                  key: const ValueKey('marathon-break-steam'),
                  painter: _CoffeeSteamPainter(color: widget.color),
                ),
                builder: (context, child) {
                  final phase = Curves.easeInOut.transform(_steam.value);
                  return Transform.translate(
                    key: const ValueKey('marathon-break-steam-drift'),
                    offset: Offset(0, -widget.size * 0.015 * phase),
                    child: Opacity(
                      key: const ValueKey('marathon-break-steam-opacity'),
                      opacity: 0.35 + 0.15 * phase,
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: widget.size * 0.23,
            left: 0,
            right: 0,
            height: widget.size * 0.77,
            child: Icon(
              Icons.free_breakfast_rounded,
              key: const ValueKey('marathon-break-cup'),
              size: widget.size * 0.77,
              color: widget.color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoffeeSteamPainter extends CustomPainter {
  const _CoffeeSteamPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    for (final center in [0.2, 0.5, 0.8]) {
      final x = size.width * center;
      final path = Path()
        ..moveTo(x, size.height * 0.93)
        ..cubicTo(
          x - size.width * 0.12,
          size.height * 0.65,
          x + size.width * 0.12,
          size.height * 0.4,
          x,
          size.height * 0.12,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CoffeeSteamPainter oldDelegate) =>
      color != oldDelegate.color;
}
