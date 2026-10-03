import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Senkronize edilmemiş seans uyarısı; dokununca yeniden denenir.
class ShellPendingBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const ShellPendingBanner({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade800,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.pendingSessionsBanner(count),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
