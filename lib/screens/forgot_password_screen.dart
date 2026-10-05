import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/supabase_service.dart';
import '../utils/auth_error_text.dart';
import '../utils/responsive.dart';
import '../widgets/auth/auth_error_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  final Future<void> Function(String email)? sendResetEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.sendResetEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final _form = GlobalKey<FormState>();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;
    final email = _email.text.trim();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await (widget.sendResetEmail ?? SupabaseService.instance.resetPassword)(
        email,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => const PasswordResetSentScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = authErrorText(
          l10n,
          SupabaseService.instance.parseAuthError(e),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _PasswordRecoveryLayout(
      title: l10n.forgotPassword,
      children: [
        const Icon(Icons.lock_reset_rounded, size: 72),
        const SizedBox(height: 24),
        Text(l10n.forgotPasswordDescription, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (_error != null) ...[
          AuthErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: l10n.email,
              border: const OutlineInputBorder(),
            ),
            validator: (value) =>
                RegExp(
                  r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
                ).hasMatch(value?.trim() ?? '')
                ? null
                : l10n.authErrInvalidEmail,
            onFieldSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.sendPasswordResetEmail, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class PasswordResetSentScreen extends StatelessWidget {
  const PasswordResetSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _PasswordRecoveryLayout(
      title: l10n.passwordResetSentTitle,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(l10n.passwordResetSentDescription, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.backToLoginBtn),
        ),
      ],
    );
  }
}

class _PasswordRecoveryLayout extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PasswordRecoveryLayout({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final screen = Responsive.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(screen.isShortHeight ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.form),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
