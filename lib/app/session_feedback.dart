import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

/// Kalıcı ret nedeninin kullanıcı metni.
String sessionRejectionMessage(AppLocalizations l10n, String reasonCode) => switch (reasonCode) {
      SessionReason.tooOld => l10n.sessionRejectedTooOld,
      SessionReason.notElapsed || SessionReason.futureStart || SessionReason.clockSkew => l10n.sessionRejectedClock,
      SessionReason.overlap => l10n.sessionRejectedOverlap,
      _ => l10n.sessionRejectedGeneric,
    };

/// Kuyrukta bekletilen seansın kullanıcı metni.
String sessionQueuedMessage(AppLocalizations l10n, String reasonCode) => switch (reasonCode) {
      SessionReason.clockSkew => l10n.sessionQueuedClockSkew,
      SessionReason.overlap => l10n.sessionQueuedOverlap,
      _ => l10n.sessionQueuedOffline,
    };

/// Seans gönderiminin sonucunu SnackBar ile bildirir.
void showSessionResult(BuildContext context, SessionSubmitResult result) {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case SessionSubmitSuccess(
        :final basePoints,
        :final bonusPoints,
        :final totalPoints,
        :final bonusPct,
        :final dailyLimitReached,
      ):
      if (bonusPoints > 0) {
        messenger.clearSnackBars();
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.sessionPointsBreakdown(basePoints, bonusPoints, bonusPct, totalPoints)),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      }
      if (dailyLimitReached) {
        Future.delayed(const Duration(seconds: 1), () {
          if (!messenger.mounted) return;
          messenger.showSnackBar(SnackBar(
            content: Text(l10n.sessionDailyLimitReached),
            backgroundColor: AppColors.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
        });
      }
    case SessionSubmitQueued(:final reasonCode):
      _showWarning(messenger, sessionQueuedMessage(l10n, reasonCode));
    case SessionSubmitRejected(:final reasonCode):
      _showWarning(messenger, sessionRejectionMessage(l10n, reasonCode));
  }
}

/// Arka planda (kuyruk senkronunda) reddedilen seansları bir kez bildirir.
void showRejectedSessionsNotice(BuildContext context, int count) {
  _showWarning(ScaffoldMessenger.of(context), AppLocalizations.of(context)!.rejectedSessionsNotice(count));
}

void _showWarning(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: Colors.orange.shade800,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 5),
  ));
}
