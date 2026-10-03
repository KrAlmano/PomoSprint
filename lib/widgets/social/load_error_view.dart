import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Sosyal ekranlarda veri hiç yüklenemediğinde gösterilen hata kartı.
class LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LoadErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, color: muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.socialRetry),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Veri daha önce yüklenmiş ama son yenileme başarısız olduğunda listenin
/// üstünde gösterilen ince uyarı satırı.
class StaleDataNotice extends StatelessWidget {
  final VoidCallback onRetry;

  const StaleDataNotice({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l10n.socialRefreshFailed, style: TextStyle(fontSize: 12, color: muted)),
        ),
        IconButton(
          onPressed: onRetry,
          tooltip: l10n.socialRetry,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
        ),
      ],
    );
  }
}
