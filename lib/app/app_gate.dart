import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../screens/post_auth_onboarding_screen.dart';
import '../services/supabase_service.dart';
import 'main_shell.dart';

/// Uygulamanın TEK yönlendirme kapısı. SupabaseService.currentUser'a göre
/// giriş, onboarding ya da ana kabuğu gösterir; giriş, onboarding'in
/// tamamlanması ve çıkış (oturumun düşmesi dahil) buradan akar.
class AppGate extends StatefulWidget {
  /// Açılışta yüklenen kategoriler; yalnızca açılıştaki kullanıcının ilk
  /// kabuğu için kullanılır.
  final List<CourseCategory> initialCategories;

  const AppGate({super.key, required this.initialCategories});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final SupabaseService _service = SupabaseService.instance;
  late List<CourseCategory> _bootCategories;
  late final String? _bootUserEmail;

  @override
  void initState() {
    super.initState();
    _bootCategories = widget.initialCategories;
    _bootUserEmail = _service.currentUser.value?.email;
    _service.currentUser.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    _service.currentUser.removeListener(_onUserChanged);
    super.dispose();
  }

  // Çıkıştan sonra açılıştaki kategoriler artık kullanılmaz; yeni kabuk
  // kategorileri kendisi yükler.
  void _onUserChanged() {
    if (_service.currentUser.value == null) _bootCategories = const [];
  }

  Future<void> _onSignedIn(UserModel user) async {
    // Giriş akışında açılmış ekranlar (ör. kayıt) kapatılır.
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    if (!identical(_service.currentUser.value, user)) await _service.setCurrentUser(user);
  }

  Future<void> _onOnboardingCompleted() async {
    final user = _service.currentUser.value;
    if (user == null || user.onboardingCompletedAt != null) return;
    // Onboarding ekranı servisi güncellemediyse yerel değişiklik servise yazılır.
    await _service.setCurrentUser(user.copyWith(onboardingCompletedAt: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: _service.currentUser,
      builder: (context, user, _) {
        if (user == null) {
          return LoginScreen(onLoginSuccess: _onSignedIn);
        }
        if (user.onboardingCompletedAt == null) {
          return PostAuthOnboardingScreen(onCompleted: _onOnboardingCompleted);
        }
        return MainNavigationShell(
          key: ValueKey(user.email.toLowerCase()),
          user: user,
          initialCategories: user.email == _bootUserEmail ? _bootCategories : const [],
        );
      },
    );
  }
}
