import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../app/session_feedback.dart';
import '../l10n/app_localizations.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../widgets/stats/stats_text.dart';

/// Kaydedilemeyen seanslar sayfası.
Route<void> rejectedSessionsRoute() => MaterialPageRoute<void>(builder: (_) => const RejectedSessionsScreen());

/// Kaydedilemeyen seanslar listesini açar.
Future<void> openRejectedSessions(BuildContext context) => Navigator.of(context).push(rejectedSessionsRoute());

/// Sunucunun kalıcı olarak reddettiği seanslar (cihazda tutulan son 50
/// kayıt), en yeni üstte. Salt okunur: seans buradan silinmez ya da
/// yeniden gönderilmez; kullanıcı neyin neden sayılmadığını görür.
class RejectedSessionsScreen extends StatefulWidget {
  const RejectedSessionsScreen({super.key, this.service});

  /// Testte sahte servis verilir; uygulamada [SupabaseService.instance].
  @visibleForTesting
  final SupabaseService? service;

  @override
  State<RejectedSessionsScreen> createState() => _RejectedSessionsScreenState();
}

class _RejectedSessionsScreenState extends State<RejectedSessionsScreen> {
  late final Future<List<RejectedSession>> _sessions = _load();

  Future<List<RejectedSession>> _load() async {
    await initializeDateFormatting(StatsText.dateLocale, null);
    final list = await (widget.service ?? SupabaseService.instance).getRejectedSessions();
    return [...list]..sort((a, b) => b.rejectedAt.compareTo(a.rejectedAt));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rejectedSessionsTitle)),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<RejectedSession>>(
          future: _sessions,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = snapshot.data ?? const <RejectedSession>[];
            return ContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.rejectedSessionsInfo, style: TextStyle(fontSize: 13, color: muted, height: 1.4)),
                  const SizedBox(height: 16),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(l10n.rejectedSessionsEmpty, textAlign: TextAlign.center, style: TextStyle(color: muted)),
                    )
                  else
                    for (final s in sessions) _RejectedSessionTile(session: s, muted: muted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RejectedSessionTile extends StatelessWidget {
  const _RejectedSessionTile({required this.session, required this.muted});

  final RejectedSession session;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final when = DateFormat('d MMM y, HH:mm', StatsText.dateLocale).format(session.startedAt.toLocal());
    final title = [
      StatsText.categoryName(context, session.categoryName),
      if (session.minutes > 0) '${session.minutes} ${l10n.minutesUnit}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(Icons.cloud_off_rounded, color: muted),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$when\n${sessionRejectionMessage(l10n, session.reasonCode)}'),
        isThreeLine: true,
      ),
    );
  }
}
