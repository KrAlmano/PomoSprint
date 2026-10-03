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

/// Giriş ekranındaki bilgi kutusu (hesap silindi, oturum sona erdi, onay
/// e-postası gönderildi). [onDismiss] verilirse kapatma düğmesi gösterilir.
class AuthInfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onDismiss;
  final String? dismissTooltip;

  const AuthInfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.onDismiss,
    this.dismissTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 12, onDismiss == null ? 12 : 4, 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface)),
            ),
            if (onDismiss != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: dismissTooltip,
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
