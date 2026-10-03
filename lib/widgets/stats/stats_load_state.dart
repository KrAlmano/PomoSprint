import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/service_errors.dart';
import '../../theme.dart';
import '../../utils/responsive.dart';

String statsLoadErrorText(AppLocalizations l10n, ServiceErrorCode code) => switch (code) {
      ServiceErrorCode.cloudUnavailable || ServiceErrorCode.network || ServiceErrorCode.timeout =>
        l10n.statsLoadErrorOffline,
      ServiceErrorCode.notSignedIn => l10n.statsLoadErrorSignedOut,
      _ => l10n.statsLoadErrorGeneric,
    };

/// Hiç veri yüklenemediğinde tam ekran hata durumu ('Tekrar Dene' ile).
class StatsErrorView extends StatelessWidget {
  const StatsErrorView({super.key, required this.code, required this.onRetry});

  final ServiceErrorCode code;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    final isOffline = code == ServiceErrorCode.cloudUnavailable ||
        code == ServiceErrorCode.network ||
        code == ServiceErrorCode.timeout;

    // Yatay telefonda kısa ekranda kaydırılır; geniş ekranda metin
    // okunabilir genişlikte ortalanır.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentWidth.form),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOffline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                  size: 44,
                  color: accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.statsLoadErrorTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                statsLoadErrorText(l10n, code),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.statsRetry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yenileme başarısız olduğunda, eski veriler gösterilirken üstte çıkan uyarı.
class StatsStaleBanner extends StatelessWidget {
  const StatsStaleBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      // Büyük yazı boyutunda düğme satırın yarısını aşmaz (metni kaydırır).
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.statsStaleNotice,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: TextButton(
                onPressed: onRetry,
                child: Text(l10n.statsRetry, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
