import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/responsive.dart';
import 'social_error_text.dart';

enum UserReportPlace {
  league,
  monthly,
  friendsRanking,
  liveFeed,
  friendsList,
  friendRequest,
}

/// submit_user_report ile aynı yer kodları. Gösterilen çeviri RPC'ye gitmez.
String userReportPlaceCode(UserReportPlace place) => switch (place) {
  UserReportPlace.league => 'league',
  UserReportPlace.monthly => 'monthly',
  UserReportPlace.friendsRanking => 'friends_ranking',
  UserReportPlace.liveFeed => 'live_feed',
  UserReportPlace.friendsList => 'friends_list',
  UserReportPlace.friendRequest => 'friend_request',
};

const userReportReasons = [
  'offensive_name',
  'offensive_content',
  'harassment',
  'spam',
  'impersonation',
  'other',
];

String _reasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
  'offensive_name' => l10n.reportReasonOffensiveName,
  'offensive_content' => l10n.reportReasonOffensiveContent,
  'harassment' => l10n.reportReasonHarassment,
  'spam' => l10n.reportReasonSpam,
  'impersonation' => l10n.reportReasonImpersonation,
  _ => l10n.reportReasonOther,
};

/// null: vazgeçildi, false: yeni bildirim, true: açık bildirim zaten var.
Future<bool?> showUserReportDialog(
  BuildContext context, {
  required String targetName,
  required Future<Map<String, dynamic>> Function(String reason, String? details)
  submit,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _UserReportDialog(targetName: targetName, submit: submit),
);

class _UserReportDialog extends StatefulWidget {
  final String targetName;
  final Future<Map<String, dynamic>> Function(String reason, String? details)
  submit;
  const _UserReportDialog({required this.targetName, required this.submit});
  @override
  State<_UserReportDialog> createState() => _UserReportDialogState();
}

class _UserReportDialogState extends State<_UserReportDialog> {
  final _form = GlobalKey<FormState>();
  final _details = TextEditingController();
  String? _reason;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    final details = _details.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.submit(
        _reason!,
        details.isEmpty ? null : details,
      );
      if (!mounted) return;
      if (response['success'] == true) {
        Navigator.pop(context, response['duplicate'] == true);
        return;
      }
      setState(
        () => _error = switch (response['code']) {
          'rate_limited' => l10n.reportRateLimited,
          'not_found' || 'self' => l10n.reportUserUnavailable,
          _ => l10n.reportSendFailed,
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = socialErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(maxWidth: ContentWidth.form),
        title: Text(l10n.reportUserAction),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.targetName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.reportReasonLabel),
                items: [
                  for (final reason in userReportReasons)
                    DropdownMenuItem(
                      value: reason,
                      child: Text(_reasonLabel(l10n, reason)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _reason = value),
                validator: (value) =>
                    value == null ? l10n.reportChooseReason : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _details,
                enabled: !_busy,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.reportDetailsLabel,
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.reportSendButton),
          ),
        ],
      ),
    );
  }
}
