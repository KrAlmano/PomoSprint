import 'package:flutter/material.dart';

/// Giriş ve kayıt ekranlarındaki kırmızı hata kutusu.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.shade900.withValues(alpha: 0.25) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: isDark ? Colors.red.shade300 : Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.red.shade200 : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
