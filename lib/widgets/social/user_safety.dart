import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/avatar_model.dart';
import '../../services/hidden_users.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';
import '../../utils/responsive.dart';
import '../../utils/user_report.dart';
import 'social_error_text.dart';
import '../avatar_widget.dart';

/// Başka bir kullanıcının görünen adının geçtiği yer (bildirim e-postasında
/// yazılır).
enum UserReportPlace { league, monthly, friendsRanking, liveFeed, friendsList, friendRequest }

/// Bildirilen / gizlenen kullanıcı.
@immutable
class UserSafetyTarget {
  final String name;
  final String? userId;
  final String? avatarId;

  const UserSafetyTarget({required this.name, this.userId, this.avatarId});
}

String _placeText(AppLocalizations l10n, UserReportPlace place) => switch (place) {
      UserReportPlace.league => l10n.reportPlaceLeague,
      UserReportPlace.monthly => l10n.reportPlaceMonthly,
      UserReportPlace.friendsRanking => l10n.reportPlaceFriendsRanking,
      UserReportPlace.liveFeed => l10n.reportPlaceLiveFeed,
      UserReportPlace.friendsList => l10n.reportPlaceFriendsList,
      UserReportPlace.friendRequest => l10n.reportPlaceFriendRequest,
    };

/// Bildirim e-postasının adresi (konu + gövde yerelleştirilmiş).
Uri userReportUri(AppLocalizations l10n, UserSafetyTarget target, UserReportPlace place) {
  final id = target.userId;
  return buildUserReportUri(
    subject: l10n.reportEmailSubject(target.name),
    body: l10n.reportEmailBody(
      target.name,
      (id == null || id.isEmpty) ? l10n.reportUserIdUnknown : id,
      _placeText(l10n, place),
    ),
  );
}

/// Başka kullanıcı satırının güvenlik menüsü: "Kullanıcıyı bildir" ve
/// (izin verilirse) gizleme, kimlik varsa engelleme / arkadaşlıktan çıkarma.
/// Kendi satırında açılmamalı.
Future<void> showUserSafetySheet(
  BuildContext context, {
  required UserSafetyTarget target,
  required UserReportPlace place,
  bool allowHide = true,
  bool allowRemoveFriend = false,
  SupabaseService? service,
  Future<void> Function()? onChanged,
}) async {
  final data = service ?? SupabaseService.instance;
  final action = await showModalBottomSheet<_SafetyAction>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: ContentWidth.form),
    builder: (sheetContext) =>
        _UserSafetySheet(target: target, allowHide: allowHide, allowRemoveFriend: allowRemoveFriend, service: data),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _SafetyAction.report:
      await _report(context, target, place);
    case _SafetyAction.hide:
      await _hide(context, target);
    case _SafetyAction.block:
    case _SafetyAction.remove:
      final l10n = AppLocalizations.of(context)!;
      final block = action == _SafetyAction.block;
      await confirmFriendAction(
        context,
        title: block ? l10n.blockUserAction : l10n.friendsRemoveAction,
        body: block ? l10n.blockUserConfirm : l10n.friendsRemoveConfirm,
        operation: () => block ? data.blockUser(target.userId!) : data.removeFriend(target.userId!),
      );
      if (onChanged != null) await onChanged();
  }
}

enum _SafetyAction { report, hide, block, remove }

Future<void> _report(BuildContext context, UserSafetyTarget target, UserReportPlace place) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final uri = userReportUri(l10n, target, place);
  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (e) {
    debugPrint('[SAFETY] E-posta uygulaması açılamadı: $e');
  }
  if (opened) return;
  // E-posta uygulaması yoksa adres gösterilir ve kopyalanabilir.
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.reportMailFailed(kSupportEmail)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l10n.reportCopyAddress,
        onPressed: () => unawaited(Clipboard.setData(const ClipboardData(text: kSupportEmail))),
      ),
    ),
  );
}

Future<void> _hide(BuildContext context, UserSafetyTarget target) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final ownerId = SupabaseService.instance.currentUser.value?.id;
  if (ownerId == null || ownerId.isEmpty) return;
  final user = HiddenUser(id: target.userId, name: target.name);
  final store = HiddenUsersStore.instance;
  try {
    await store.hide(ownerId, user);
  } catch (e) {
    debugPrint('[SAFETY] Kullanıcı gizlenemedi: $e');
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileSettingSaveError), behavior: SnackBarBehavior.floating));
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.userHiddenMsg(target.name)),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: l10n.undoAction, onPressed: () => unawaited(store.unhide(ownerId, user))),
    ),
  );
}

class _UserSafetySheet extends StatelessWidget {
  final UserSafetyTarget target;
  final bool allowHide;
  final bool allowRemoveFriend;
  final SupabaseService service;

  const _UserSafetySheet({
    required this.target,
    required this.allowHide,
    required this.allowRemoveFriend,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final canBlock =
        target.userId?.isNotEmpty == true &&
        service.currentUser.value?.id != null &&
        target.userId != service.currentUser.value?.id;
    final canHide = allowHide && (SupabaseService.instance.currentUser.value?.id?.isNotEmpty ?? false);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  AvatarWidget(avatar: AvatarCharacter.byId(target.avatarId), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      target.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: Text(l10n.reportUserAction, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(l10n.reportUserActionSub, style: TextStyle(fontSize: 12, color: muted)),
              onTap: () => Navigator.pop(context, _SafetyAction.report),
            ),
            if (canBlock)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text(l10n.blockUserAction),
                onTap: () => Navigator.pop(context, _SafetyAction.block),
              ),
            if (canBlock && allowRemoveFriend)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: Text(l10n.friendsRemoveAction),
                onTap: () => Navigator.pop(context, _SafetyAction.remove),
              ),
            if (canHide)
              ListTile(
                leading: Icon(Icons.visibility_off_outlined, color: muted),
                title: Text(l10n.hideUserAction, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(l10n.hideUserActionSub, style: TextStyle(fontSize: 12, color: muted)),
                onTap: () => Navigator.pop(context, _SafetyAction.hide),
              ),
          ],
        ),
      ),
    );
  }
}

/// Satır sonundaki "kullanıcı seçenekleri" düğmesi (uzun basmanın görünür
/// karşılığı).
class UserActionsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color? color;

  const UserActionsButton({super.key, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onPressed,
      tooltip: AppLocalizations.of(context)!.userActionsTooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: color ?? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
      ),
    );
  }
}

/// İşlem sunucu yanıtını beklerken ikinci dokunuş ve geri çıkış engellenir.
Future<bool?> confirmFriendAction(
  BuildContext context, {
  required String title,
  required String body,
  required Future<Map<String, dynamic>> Function() operation,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _FriendActionDialog(title: title, body: body, operation: operation),
);

class _FriendActionDialog extends StatefulWidget {
  final String title;
  final String body;
  final Future<Map<String, dynamic>> Function() operation;
  const _FriendActionDialog({required this.title, required this.body, required this.operation});
  @override
  State<_FriendActionDialog> createState() => _FriendActionDialogState();
}

class _FriendActionDialogState extends State<_FriendActionDialog> {
  bool _busy = false;
  String? _error;
  Future<void> _confirm() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.operation();
      if (!mounted) return;
      if (response['success'] == true) {
        Navigator.pop(context, true);
        return;
      }
      setState(
        () => _error = response['code'] == 'limit_reached' || response['code'] == 'rate_limited'
            ? l10n.friendsErrRateLimited
            : l10n.friendActionFailed,
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
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(l10n.friendActionCancel),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.friendActionConfirm),
          ),
        ],
      ),
    );
  }
}
