import 'package:flutter/material.dart';

/// Üst çubuktaki Puan / Kum rozeti: küçük başlık, değer ve yardım işareti.
class ShellStatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const ShellStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.question_mark_rounded, size: 10, color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
