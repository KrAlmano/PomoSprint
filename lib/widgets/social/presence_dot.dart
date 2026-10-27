import 'package:flutter/material.dart';

import '../../theme.dart';

/// A small, slow pulse beside a friend's server-provided presence label.
class SocialPresenceDot extends StatefulWidget {
  const SocialPresenceDot({super.key, required this.onBreak});

  final bool onBreak;

  @override
  State<SocialPresenceDot> createState() => _SocialPresenceDotState();
}

class _SocialPresenceDotState extends State<SocialPresenceDot>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      value: 0.5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _updateAnimation();
  }

  void _updateAnimation() {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_resumed && !reduced && TickerMode.valuesOf(context).enabled) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      if (reduced) _pulse.value = 0.5;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 12,
      child: Center(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulse,
            child: Container(
              key: const ValueKey('social-presence-dot'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.onBreak
                    ? Colors.green
                    : AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
            ),
            builder: (context, child) {
              final phase = Curves.easeInOut.transform(_pulse.value);
              return Opacity(
                key: const ValueKey('social-presence-opacity'),
                opacity: 0.7 + 0.25 * phase,
                child: Transform.scale(
                  key: const ValueKey('social-presence-scale'),
                  scale: 0.85 + 0.15 * phase,
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
