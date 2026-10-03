import 'package:flutter/material.dart';

/// Üst çubuktaki Puan / Kum rozeti: küçük başlık, değer ve yardım işareti.
///
/// Rozet hiçbir zaman üst çubuğu taşırmaz: alçak çubukta ([dense]) daha
/// sıkışık çizilir; yine de sığmazsa (ör. büyütülmüş yazı ölçeği) orantılı
/// olarak küçülür.
class ShellStatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  /// Yatay telefondaki alçak üst çubuk için daha az dikey boşluk.
  final bool dense;

  const ShellStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 8),
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
                      fontSize: dense ? 16 : 18,
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
      ),
    );
  }
}
