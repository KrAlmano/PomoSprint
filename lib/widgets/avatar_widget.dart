import 'package:flutter/material.dart';
import '../models/avatar_model.dart';

class AvatarWidget extends StatelessWidget {
  final AvatarCharacter avatar;
  final double size;
  final bool isUnlocked;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.size = 48,
    this.isUnlocked = true,
  });

  static const ColorFilter _lockedFilter = ColorFilter.mode(Colors.grey, BlendMode.saturation);

  @override
  Widget build(BuildContext context) {
    // Görsel gösterildiği boyutta çözülür; listelerde tam boy PNG çözmek
    // gereksiz bellek tüketiyordu.
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final Widget image = Image.asset(
      avatar.imagePath,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Text(
          avatar.emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatar.backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: isUnlocked ? image : ColorFiltered(colorFilter: _lockedFilter, child: image),
      ),
    );
  }
}
