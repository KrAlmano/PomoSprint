import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/rejected_sessions_screen.dart';
import '../services/supabase_service.dart';

/// Kalıcı ret nedeninin kullanıcı metni. "Cihazının saati ileri" yalnızca
/// ölçülen saat farkı eşiği aşınca ('clock_skew') söylenir; 'not_elapsed' ve
/// 'future_start' kalıcı reddi, farkın ölçülüp küçük bulunduğu anlamına gelir
/// (bkz. classifySessionError).
String sessionRejectionMessage(AppLocalizations l10n, String reasonCode) => switch (reasonCode) {
      SessionReason.tooOld => l10n.sessionRejectedTooOld,
      SessionReason.clockSkew => l10n.sessionRejectedClock,
      SessionReason.notElapsed => l10n.sessionRejectedNotElapsed,
      SessionReason.futureStart => l10n.sessionRejectedFutureStart,
      SessionReason.overlap => l10n.sessionRejectedOverlap,
      _ => l10n.sessionRejectedGeneric,
    };

/// Kuyrukta bekletilen seansın kullanıcı metni (ağ, zaman aşımı, oturum ve
/// sunucu hatasında "cihazda kayıtlı, bağlantı gelince gönderilecek").
/// Saat farkı ölçülemeden gelen zaman hatası saat suçlamadan bekletilir.
String sessionQueuedMessage(AppLocalizations l10n, String reasonCode) => switch (reasonCode) {
      SessionReason.clockSkew => l10n.sessionQueuedClockSkew,
      SessionReason.notElapsed || SessionReason.futureStart => l10n.sessionQueuedTimingUnverified,
      SessionReason.overlap => l10n.sessionQueuedOverlap,
      _ => l10n.sessionQueuedOffline,
    };

/// Günde puan ve kum kazandıran en fazla seans sayısı (sunucu config'i).
int sessionDailyLimit() => SupabaseService.instance.dailySessionLimit;

/// Arka planda (kuyruk senkronunda) reddedilen seansları bir kez bildirir;
/// "Göster" kaydedilemeyen seanslar listesini açar.
void showRejectedSessionsNotice(BuildContext context, int count) {
  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(l10n.rejectedSessionsNotice(count)),
    backgroundColor: Colors.orange.shade800,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: l10n.rejectedSessionsView,
      textColor: Colors.white,
      onPressed: () => navigator.push(rejectedSessionsRoute()),
    ),
  ));
}
