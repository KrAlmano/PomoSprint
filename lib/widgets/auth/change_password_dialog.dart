import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../utils/auth_error_text.dart';
import '../../utils/responsive.dart';
import 'auth_error_banner.dart';
import 'password_rules.dart';

/// Şifre değiştirme hata metni: yanlış mevcut şifre ayrı söylenir.
String changePasswordErrorText(AppLocalizations l10n, Object error) {
  final code = authErrorCodeOf(error);
  if (code == AuthErrorCode.invalidCredentials) return l10n.changePasswordWrongCurrent;
  return authErrorText(l10n, code);
}

/// E-posta/şifre hesabı için uygulama içi şifre değiştirme. Başarıda true.
/// [changePassword] testte değiştirilebilir (varsayılan: servis).
Future<bool> showChangePasswordDialog(
  BuildContext context, {
  Future<void> Function({required String currentPassword, required String newPassword})? changePassword,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ChangePasswordDialog(changePassword: changePassword ?? SupabaseService.instance.changePassword),
  );
  if (changed == true && context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.changePasswordSuccess), behavior: SnackBarBehavior.floating));
  }
  return changed == true;
}

class _ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function({required String currentPassword, required String newPassword}) changePassword;

  const _ChangePasswordDialog({required this.changePassword});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _submitted = false;
  String Function(AppLocalizations)? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await widget.changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Provider error messages may contain request data or credentials.
      debugPrint('[PROFILE] Şifre değiştirilemedi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = (current) => changePasswordErrorText(current, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          errorMaxLines: 3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            tooltip: _obscure ? l10n.registerShowPassword : l10n.registerHidePassword,
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        );

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
      scrollable: true,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: ContentWidth.form),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.changePasswordTile, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                AuthErrorBanner(message: _error!(l10n)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                enabled: !_busy,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                decoration: decoration(l10n.changePasswordCurrent),
                validator: (v) => (v ?? '').isEmpty ? l10n.registerErrPasswordRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: decoration(l10n.changePasswordNew),
                validator: (v) {
                  final value = v ?? '';
                  final ruleError = passwordRuleError(l10n, value);
                  if (ruleError != null) return ruleError;
                  return value == _current.text ? l10n.changePasswordSame : null;
                },
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _next,
                builder: (context, value, _) => PasswordRuleChecklist(password: value.text),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repeat,
                obscureText: _obscure,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: decoration(l10n.changePasswordRepeat),
                validator: (v) => (v ?? '') == _next.text ? null : l10n.changePasswordMismatch,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.changePasswordSave),
        ),
      ],
      ),
    );
  }
}
