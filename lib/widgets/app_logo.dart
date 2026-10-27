import 'package:flutter/material.dart';

/// Platform simgesiyle aynı marka görseli; başlık yanında dekoratiftir.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .24),
    child: Image.asset(
      'assets/icon/icon_source.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}
