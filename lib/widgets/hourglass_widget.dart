import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Kompozisyonun kare hızını kullanan, duraklatılabilir Lottie kum saati.
class HourglassWidget extends StatefulWidget {
  final bool isRunning;
  final double size;
  final int totalSeconds;
  final int remainingSeconds;
  final Color? sandColor;

  const HourglassWidget({
    super.key,
    required this.isRunning,
    this.size = 210,
    this.totalSeconds = 25 * 60,
    this.remainingSeconds = 25 * 60,
    this.sandColor,
  });

  @override
  State<HourglassWidget> createState() => _HourglassWidgetState();
}

class _HourglassWidgetState extends State<HourglassWidget>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Simple shake sequence (left, right, left, right, center)
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  /// Sistemde "Hareketi Azalt" (iOS) / "Animasyonları kaldır" (Android)
  /// açıksa kum akmaz ve kum saati sallanmaz; durağan kare gösterilir.
  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ayar uygulama açıkken açıldıysa süren animasyon durdurulur; kapatıldıysa
    // (animasyon yüklendikten sonra) sayaç çalışıyorsa kum yeniden akar.
    if (_reduceMotion) {
      _lottieController.stop();
      _shakeController.reset();
    } else if (!_reduceMotion &&
        widget.isRunning &&
        !_lottieController.isAnimating &&
        _lottieController.duration != null) {
      _lottieController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant HourglassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.sandColor != widget.sandColor && !_reduceMotion) {
      // Trigger shake animation when color (category) changes
      _shakeController.forward(from: 0.0);
    }

    if (widget.isRunning && !_reduceMotion) {
      if (!_lottieController.isAnimating &&
          _lottieController.duration != null) {
        // Asset henüz yüklenmediyse onLoaded güvenli biçimde başlatır.
        _lottieController.repeat();
      }
    } else {
      if (_lottieController.isAnimating) {
        _lottieController.stop(); // Duraklatıldığında kum akışını dondur
      }
      // Seans sıfırlandıysa animasyonu en başa al
      if (widget.remainingSeconds >= widget.totalSeconds) {
        _lottieController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.05,
      child: Center(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _shakeAnimation.value,
              child: child,
            );
          },
          child: Lottie.asset(
          'assets/sand_timer.json',
          controller: _lottieController,
          width: widget.size,
          height: widget.size * 1.05,
          fit: BoxFit.contain,
          onLoaded: (composition) {
            // Lottie kum saati animasyon hızı 1.0x orijinal hızında
            _lottieController.duration = composition.duration * 1.0;
            if (widget.isRunning && !_reduceMotion) {
              _lottieController.repeat();
            } else if (widget.remainingSeconds >= widget.totalSeconds) {
              _lottieController.value = 0.0;
            }
          },
          delegates: LottieDelegates(
            values: [
              if (widget.sandColor != null)
                ValueDelegate.colorFilter(
                  ['**'],
                  value: ColorFilter.mode(
                    widget.sandColor!,
                    BlendMode.srcATop,
                  ),
                ),
            ],
          ),
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.hourglass_bottom_rounded,
              size: widget.size * 0.7,
              color: Theme.of(context).primaryColor,
            );
          },
        ),
        ),
      ),
    );
  }
}
