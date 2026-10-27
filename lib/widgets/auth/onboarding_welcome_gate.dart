import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/language_service.dart';
import '../../utils/responsive.dart';
import '../app_logo.dart';

/// Kayıt sonrası, yaş adımının önünde bir kez açık dil seçimi sunar.
/// Tercih hesaba bağlıdır; başarısız disk yazısı yaş doğrulamasını atlatmaz.
class OnboardingWelcomeGate extends StatefulWidget {
  const OnboardingWelcomeGate({
    super.key,
    required this.ownerId,
    required this.child,
    required this.onSignOut,
  });

  final String ownerId;
  final Widget child;
  final Future<void> Function() onSignOut;

  static String keyFor(String uid) => 'onboarding_welcome_uid_$uid';

  @override
  State<OnboardingWelcomeGate> createState() => _OnboardingWelcomeGateState();
}

class _OnboardingWelcomeGateState extends State<OnboardingWelcomeGate> {
  bool? _completed;
  bool _saving = false;
  AppLanguage? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var completed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      completed =
          prefs.getBool(OnboardingWelcomeGate.keyFor(widget.ownerId)) ?? false;
    } catch (_) {
      // Okunamayan tercih, kullanıcıya yeniden seçim sunar.
    }
    if (mounted) setState(() => _completed = completed);
  }

  Future<void> _continue() async {
    final language = _selected;
    if (_saving || language == null) return;
    setState(() => _saving = true);
    try {
      await LanguageService.instance.setLanguage(language);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingWelcomeGate.keyFor(widget.ownerId), true);
    } catch (_) {
      // Kullanıcı dilini seçti; kalıcı tercih yazılamasa da onboarding sürer.
    }
    if (mounted) {
      setState(() {
        _completed = true;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == true) return widget.child;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: _completed == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ContentWidth(
                    maxWidth: ContentWidth.form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: IconButton(
                            tooltip: l10n.logout,
                            onPressed: _saving ? null : widget.onSignOut,
                            icon: const Icon(Icons.logout),
                          ),
                        ),
                        const AppLogo(size: 88),
                        const SizedBox(height: 24),
                        Text(
                          l10n.onboardingWelcomeTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.onboardingWelcomeBody,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          l10n.onboardingLanguageTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.onboardingLanguageBody,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        for (final (language, label) in [
                          (AppLanguage.tr, l10n.languageNativeTr),
                          (AppLanguage.en, l10n.languageNativeEn),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: ValueKey(
                                  'onboarding-language-${language.name}',
                                ),
                                onPressed: _saving
                                    ? null
                                    : () =>
                                          setState(() => _selected = language),
                                icon: Icon(
                                  _selected == language
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                ),
                                label: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Text(label),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const ValueKey('onboarding-language-continue'),
                            onPressed: _selected == null || _saving
                                ? null
                                : _continue,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(l10n.continueBtn),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
