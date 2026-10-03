import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../theme.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import '../widgets/auth/category_name_dialog.dart';
import '../widgets/game_rules.dart';

/// Yıl tekerleğinde [index] satırının doğum yılı. 0. satır "Doğum yılını
/// seç" yer tutucusudur (null); sonrakiler [currentYear]'dan geriye doğru.
@visibleForTesting
int? birthYearForPickerIndex(int currentYear, int index) => index <= 0 ? null : currentYear - (index - 1);

class PostAuthOnboardingScreen extends StatefulWidget {
  /// Onboarding sunucuya kaydedildikten sonra çağrılır. Güncel kullanıcı
  /// (doğum yılı, segment, günlük hedef ve onboardingCompletedAt dahil)
  /// `SupabaseService.instance.currentUser.value`'dadır; çağıran eski
  /// kullanıcı nesnesi yerine onu kullanmalıdır.
  final VoidCallback onCompleted;

  /// Kullanıcı onboarding'den çıkış yaptığında, hesabını sildiğinde ya da
  /// oturumu düştüğünde, oturum kapatıldıktan sonra çağrılır. AppGate
  /// yönlendirmeyi zaten currentUser=null ile yaptığı için isteğe bağlıdır;
  /// çıkış düğmesi her durumda gösterilir.
  final VoidCallback? onSignedOut;

  const PostAuthOnboardingScreen({
    super.key,
    required this.onCompleted,
    this.onSignedOut,
  });

  @override
  State<PostAuthOnboardingScreen> createState() => _PostAuthOnboardingScreenState();
}

class _PostAuthOnboardingScreenState extends State<PostAuthOnboardingScreen> {
  // Adımlar: yaş, segment, kategoriler, sıralamalarda görünürlük, kurallar, hedef.
  static const int _ageStep = 0;
  static const int _segmentStep = 1;
  static const int _categoryStep = 2;
  static const int _visibilityStep = 3;
  static const int _rulesStep = 4;
  static const int _goalStep = 5; // son adım: "Bitir"
  static const int _totalSteps = _goalStep + 1;
  static const int _minimumAge = 13; // Kullanım Şartları ve Gizlilik Politikası
  static const int _birthYearCount = 87;

  /// "Diğer / belirtmek istemiyorum": sunucuya segment yazılmaz (null).
  static const String _otherSegment = 'other';

  // Hazır öneriler Türkçe anahtarlarla tutulur; ekranda ve kayıtta
  // kullanıcının diline çevrilir (LanguageService.translateCatName).
  static const Map<String, List<String>> _recommendedBySegment = {
    'lgs': ['Matematik', 'Fen Bilimleri', 'Türkçe', 'T.C. İnkılap Tarihi', 'İngilizce', 'Din Kültürü'],
    'yks': ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe', 'İngilizce'],
    'university': ['Ders Çalışma', 'Ödev', 'Proje', 'Sınav Hazırlık'],
    'work': ['Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje'],
  };
  // Segment seçilmediğinde ya da "Diğer" seçildiğinde genel öneriler.
  static const List<String> _generalRecommendations = ['Ders Çalışma', 'Okuma', 'Öğrenme', 'Proje'];

  final PageController _pageController = PageController();
  final int _currentYear = DateTime.now().year;
  // Yaş sorusu nötrdür: tekerlek bir yaşa önceden ayarlı değildir (ilk satır
  // "Doğum yılını seç"); yıl seçilmeden ilerlenemez.
  int? _birthYear;
  final FixedExtentScrollController _yearController = FixedExtentScrollController();

  int _currentPage = 0;
  String? _userSegment;
  // Seçim sırası korunur; sunucudaki sıralama bu sırayla oluşur.
  final Set<String> _selectedCategoryNames = {};
  final List<String> _customCategoryNames = [];
  // Sıralamalarda görünürlük açıkça sorulur; varsayılan seçim yoktur.
  bool? _showInRankings;
  int _dailyGoalMinutes = 60;
  bool _isSaving = false;
  // Yaş "Devam"da değerlendirilir (tekerlek çevrilirken uyarı çıkmaz, eşik
  // yaş belli olmaz). 13 yaş altı yanıt verilince yıl bu ekranda bir daha
  // değiştirilemez; kullanıcı çıkış yapabilir ya da hesabını silebilir.
  bool _ageRejected = false;

  bool get _isUnderMinimumAge {
    final year = _birthYear;
    return year != null && _currentYear - year < _minimumAge;
  }

  List<String> get _recommendedCategoryNames => _recommendedBySegment[_userSegment] ?? _generalRecommendations;

  int get _categoryLimit =>
      categoryLimitFor(isPremium: SupabaseService.instance.currentUser.value?.isPremium ?? false);

  @override
  void dispose() {
    _pageController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _nextPage() {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    if (_currentPage == _ageStep && _isUnderMinimumAge && !_ageRejected) {
      setState(() => _ageRejected = true);
    }
    // Segment isteğe bağlıdır: seçilmezse genel öneriler gösterilir.
    final error = switch (_currentPage) {
      _ageStep when _birthYear == null => l10n.onboardingBirthYearRequired,
      _ageStep when _isUnderMinimumAge => l10n.onboardingUnder13Error,
      _categoryStep when _selectedCategoryNames.isEmpty => l10n.onboardingSelectCategoryError,
      _visibilityStep when _showInRankings == null => l10n.onboardingSelectOptionError,
      _ => null,
    };
    if (error != null) {
      _showSnack(error);
      return;
    }
    if (_currentPage < _totalSteps - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0 && !_isSaving) _goToPage(_currentPage - 1);
  }

  // Hareketi Azalt açıkken adımlar canlandırılmadan değişir.
  void _goToPage(int page) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  /// Seçilen kategoriler kullanıcının dilinde ve paletten renk alarak
  /// gönderilir. Seçim boşsa (doğrulama atlanmışsa) segment önerilerinin
  /// ilk üçü kullanılır; kullanıcı asla kategorisiz kalmaz.
  List<Map<String, dynamic>> _categoryPayload() {
    final lang = LanguageService.instance;
    final names = _selectedCategoryNames.isNotEmpty
        ? _selectedCategoryNames.toList()
        : _recommendedCategoryNames.take(3).toList();
    return [
      for (var i = 0; i < names.length; i++)
        {
          'name': lang.translateCatName(names[i]),
          'color_hex': kCategoryPalette[i % kCategoryPalette.length],
          'icon_name': 'book',
        },
    ];
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);
    final service = SupabaseService.instance;
    try {
      // Servis önce profili garanti eder, sonra kategorileri kurar, en son
      // onboarding_completed_at'i yazar; yarıda kalırsa onboarding tekrar
      // gösterilir ve kategori kurulumu tekrar güvenle çalışır.
      await service.completeOnboarding(
        birthYear: _birthYear,
        // "Diğer" sunucuda saklanmaz (CHECK yalnızca dört segmenti kabul eder).
        userSegment: _userSegment == _otherSegment ? null : _userSegment,
        dailyGoalMinutes: _dailyGoalMinutes,
        categories: _categoryPayload(),
        showInSocialFeed: _showInRankings,
      );
    } catch (e) {
      debugPrint('PostAuth onboarding error: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      final l10n = AppLocalizations.of(context)!;
      switch (serviceErrorCodeOf(e)) {
        case ServiceErrorCode.notSignedIn:
          await _signOut(message: l10n.onboardingSessionExpired);
        case ServiceErrorCode.timeout || ServiceErrorCode.network || ServiceErrorCode.cloudUnavailable:
          _showSnack(l10n.onboardingTimeoutError, isError: true);
        default:
          _showSnack(l10n.onboardingSaveError, isError: true);
      }
      return;
    }

    // completeOnboarding kullanıcıyı yalnızca önceden yüklenmişse günceller.
    if (service.currentUser.value?.onboardingCompletedAt == null) {
      try {
        await service.fetchCurrentUserModel();
      } catch (e) {
        debugPrint('PostAuth onboarding: kullanıcı tazelenemedi: $e');
      }
    }
    if (mounted) widget.onCompleted();
  }

  Future<void> _signOut({String? message}) async {
    if (message != null) _showSnack(message, isError: true);
    setState(() => _isSaving = true);
    await SupabaseService.instance.signOutFully();
    if (!mounted) return;
    setState(() => _isSaving = false);
    widget.onSignedOut?.call();
  }

  /// Yaş sınırına takılan (ya da yanlış hesapla giren) kullanıcı onboarding'i
  /// bitirmeden hesabını silebilir; Profil ekranına buradan ulaşılamıyor.
  Future<void> _confirmDeleteAccount() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.deleteAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(l10n.profileDeleteConfirm, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      // Servis yerel veriyi temizleyip oturumu kapatır; AppGate girişe döner.
      await SupabaseService.instance.deleteUserAccount();
      if (!mounted) return;
      widget.onSignedOut?.call();
    } catch (e) {
      debugPrint('PostAuth onboarding: hesap silinemedi: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(l10n.profileDeleteError, isError: true);
    }
  }

  void _selectSegment(String value) {
    if (_userSegment == value) return;
    setState(() {
      _userSegment = value;
      _selectedCategoryNames.clear();
    });
  }

  void _toggleCategory(String name, bool select) {
    if (!select) {
      setState(() => _selectedCategoryNames.remove(name));
      return;
    }
    if (_selectedCategoryNames.length >= _categoryLimit) {
      _showSnack(AppLocalizations.of(context)!.categoryLimitReachedMsg(_categoryLimit));
      return;
    }
    setState(() => _selectedCategoryNames.add(name));
  }

  Future<void> _showAddCategoryDialog() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedCategoryNames.length >= _categoryLimit) {
      _showSnack(l10n.categoryLimitReachedMsg(_categoryLimit));
      return;
    }
    final result = await CategoryNameDialog.show(
      context,
      title: l10n.onboardingAddCategoryTitle,
      hintText: l10n.onboardingCategoryHint,
      confirmLabel: l10n.addBtn,
      showColorPicker: false,
      takenNames: [..._recommendedCategoryNames, ..._customCategoryNames],
    );
    if (result == null || !mounted) return;
    setState(() {
      _customCategoryNames.add(result.name);
      _selectedCategoryNames.add(result.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final l10n = AppLocalizations.of(context)!;
    // Yatay telefonda adımlar iki sütuna bölünür (solda maskot ve başlık,
    // sağda seçim); dikeyde bugünkü tek sütun korunur.
    final r = Responsive.of(context);
    final sideBySide = r.isShortHeight && r.isLandscape;

    // Android geri tuşu önce önceki adıma döner; ilk adımda uygulamayı kapatır.
    return PopScope(
      canPop: _currentPage == 0 && !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prevPage();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        body: SafeArea(
          // Tablette içerik ortalanmış okuma genişliğinde kalır.
          child: ContentWidth(
            maxWidth: ContentWidth.reading,
            child: Column(
              children: [
                // Progress bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: sideBySide ? 2 : 10),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          // Ekran okuyucuda "Geri" diye okunur.
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          onPressed: _isSaving ? null : _prevPage,
                        )
                      else
                        // Yanlış hesapla giren kullanıcı onboarding'i bitirmeden çıkabilir.
                        IconButton(
                          icon: Icon(Icons.logout, color: textColor),
                          tooltip: l10n.logout,
                          onPressed: _isSaving ? null : () => _signOut(),
                        ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_currentPage + 1) / _totalSteps,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${_currentPage + 1}/$_totalSteps',
                          textAlign: TextAlign.center,
                          // Küçük metin: en az 4,5:1 kontrast için %70 opaklık.
                          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      for (var step = 0; step < _totalSteps; step++)
                        switch (step) {
                          _ageStep => _buildAgeStep(isDark, textColor, sideBySide),
                          _segmentStep => _buildSegmentStep(isDark, textColor, sideBySide),
                          _categoryStep => _buildCategoryStep(isDark, textColor, sideBySide),
                          _visibilityStep => _buildVisibilityStep(isDark, textColor, sideBySide),
                          _rulesStep => _buildRulesStep(textColor, sideBySide),
                          _ => _buildGoalStep(isDark, textColor, sideBySide),
                        },
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(20, sideBySide ? 4 : 0, 20, sideBySide ? 8 : 30),
                  child: ContentWidth(
                    maxWidth: ContentWidth.form,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, sideBySide ? 46 : 54),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _currentPage == _totalSteps - 1 ? l10n.onboardingFinishBtn : l10n.continueBtn,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Yatay telefondaki adım düzeni: solda [header] (maskot, başlık, açıklama),
  /// sağda [content] (seçim). İki sütun da kendi içinde dikeyde ortalanır ve
  /// sığmazsa kayar. [content], sağ sütunun yüksekliğini alır (ör. yıl
  /// seçicisini sığdırmak için).
  Widget _sideBySideStep({
    required List<Widget> header,
    required List<Widget> Function(double columnHeight) content,
  }) {
    Widget column(List<Widget> children, double height) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: math.max(0, height - 16)),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: column(header, constraints.maxHeight)),
          Expanded(flex: 6, child: column(content(constraints.maxHeight), constraints.maxHeight)),
        ],
      ),
    );
  }

  /// Seçenek düğmeleri ve çipler tablette form genişliğini aşmaz.
  Widget _formWidth(Widget child) => ContentWidth(maxWidth: ContentWidth.form, child: child);

  Widget _buildMascotAvatar({double size = 92}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/avatars/onboarding_avatar.png',
          fit: BoxFit.cover,
          // Görsel ekrandaki boyutunda çözülür (tam çözünürlükte değil).
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      ),
    );
  }

  Widget _buildAgeStep(bool isDark, Color textColor, bool sideBySide) {
    final l10n = AppLocalizations.of(context)!;
    Widget title(double fontSize) => Text(
          l10n.onboardingWelcomeTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor),
        );
    final body = Text(
      l10n.onboardingWelcomeBody,
      style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
      textAlign: TextAlign.center,
    );
    // İlk satır seçim değildir ("Doğum yılını seç"); yıllar ondan sonra
    // bugünden geriye doğru sıralanır. Tekerlek hiçbir yaşa önceden ayarlı
    // değildir; metin sorunun amacını söyler ama eşik yaşı söylemez (nötr
    // yaş sorusu).
    Widget picker(double height) => SizedBox(
          height: height,
          // 13 yaş altı yanıttan sonra kilitli (bkz. _ageRejected).
          child: IgnorePointer(
            ignoring: _ageRejected,
            child: Opacity(
              opacity: _ageRejected ? 0.4 : 1,
              child: CupertinoPicker(
                itemExtent: 52,
                scrollController: _yearController,
                onSelectedItemChanged: (i) {
                  setState(() => _birthYear = birthYearForPickerIndex(_currentYear, i));
                },
                children: [
                  Center(
                    child: Text(
                      l10n.onboardingBirthYearPlaceholder,
                      style: TextStyle(
                          fontSize: 18, color: textColor.withValues(alpha: 0.55), fontWeight: FontWeight.w500),
                    ),
                  ),
                  for (var i = 0; i < _birthYearCount; i++)
                    Center(
                      child: Text(
                        (_currentYear - i).toString(),
                        style: TextStyle(
                          fontSize: 22,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
    final underAge = [
      if (_ageRejected) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(sideBySide ? 8 : 32, 12, sideBySide ? 8 : 32, 0),
          child: Text(
            l10n.onboardingUnder13Error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.w600),
          ),
        ),
        // Yaş sınırına takılan kullanıcı burada kalmaz: çıkabilir ya da
        // hesabını silebilir (geri tuşu uygulamayı kapatıyordu).
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _isSaving ? null : () => _signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(l10n.logout),
            ),
            TextButton.icon(
              onPressed: _isSaving ? null : _confirmDeleteAccount,
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade700),
              label: Text(l10n.deleteAccount, style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        ),
      ],
    ];

    if (sideBySide) {
      return _sideBySideStep(
        header: [
          _buildMascotAvatar(size: 64),
          const SizedBox(height: 12),
          title(24),
          const SizedBox(height: 6),
          body,
        ],
        // Yıl seçicisi sağ sütuna sığacak kadar kısalır (en fazla bugünkü 220).
        content: (height) => [
          picker((height - 24).clamp(120.0, 220.0)),
          ...underAge,
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: _formWidth(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMascotAvatar(),
            const SizedBox(height: 20),
            title(28),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: body,
            ),
            const SizedBox(height: 32),
            picker(220),
            ...underAge,
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentStep(bool isDark, Color textColor, bool sideBySide) {
    final l10n = AppLocalizations.of(context)!;
    final title = Text(l10n.onboardingSegmentTitle,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: sideBySide ? 22 : 26, fontWeight: FontWeight.bold, color: textColor));
    final body = Text(l10n.onboardingSegmentBody,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)));
    final options = [
      _optionButton(l10n.onboardingSegmentLgs, _userSegment == 'lgs', () => _selectSegment('lgs'), isDark, textColor),
      _optionButton(l10n.onboardingSegmentYks, _userSegment == 'yks', () => _selectSegment('yks'), isDark, textColor),
      _optionButton(l10n.onboardingSegmentUniversity, _userSegment == 'university',
          () => _selectSegment('university'), isDark, textColor),
      _optionButton(l10n.onboardingSegmentWork, _userSegment == 'work', () => _selectSegment('work'), isDark, textColor),
      // Segment isteğe bağlı: "Diğer" ile (ya da seçmeden) genel öneriler gelir.
      _optionButton(l10n.onboardingSegmentOther, _userSegment == _otherSegment, () => _selectSegment(_otherSegment),
          isDark, textColor),
    ];

    if (sideBySide) {
      return _sideBySideStep(
        header: [_buildMascotAvatar(size: 64), const SizedBox(height: 12), title, const SizedBox(height: 6), body],
        content: (_) => options,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: _formWidth(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMascotAvatar(),
            const SizedBox(height: 20),
            title,
            const SizedBox(height: 8),
            body,
            const SizedBox(height: 32),
            ...options,
          ],
        ),
      ),
    );
  }

  Widget _optionButton(String label, bool isSelected, VoidCallback onTap, bool isDark, Color textColor) {
    // Koyu temada darkPrimary: seçili metin koyu zeminde okunur kalır.
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      // Ekran okuyucu seçeneği düğme olarak ve seçili durumuyla duyurur.
      child: Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? accent : (isDark ? Colors.white24 : Colors.black12),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
              color: isSelected ? accent.withValues(alpha: 0.1) : Colors.transparent,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? accent : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryStep(bool isDark, Color textColor, bool sideBySide) {
    final l10n = AppLocalizations.of(context)!;
    final lang = LanguageService.instance;
    final limit = _categoryLimit;
    Widget chip(String name) {
      final selected = _selectedCategoryNames.contains(name);
      return ChoiceChip(
        label: Text(lang.translateCatName(name)),
        selected: selected,
        selectedColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primary.withValues(alpha: 0.2),
        // Koyu temada temanın seçili çip metni (siyah) koyu kırmızı zeminde
        // okunmuyordu (1,2:1); açık ton kullanılır.
        labelStyle: selected && isDark ? const TextStyle(color: AppColors.darkOnPrimaryContainer) : null,
        checkmarkColor: isDark ? AppColors.darkOnPrimaryContainer : null,
        onSelected: (val) => _toggleCategory(name, val),
      );
    }
    final title = Text(l10n.onboardingCategoryStepTitle,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: sideBySide ? 22 : 26, fontWeight: FontWeight.bold, color: textColor));
    final body = Text(
      l10n.onboardingCategoryStepBodyLimit(limit),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7)),
    );
    final counter = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_selectedCategoryNames.length} / $limit',
        // Koyu temada darkPrimary (okunur kontrast).
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
      ),
    );
    // Çipler satırlara sarılır; geniş ekranda satır başına daha çok çip düşer.
    final chips = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final name in [..._recommendedCategoryNames, ..._customCategoryNames]) chip(name),
      ],
    );
    // Metin '+' içerdiği için ayrıca ikon kullanılmaz.
    final addButton = TextButton(
      onPressed: _showAddCategoryDialog,
      child: Text(l10n.onboardingCreateOwnCategory),
    );

    if (sideBySide) {
      return _sideBySideStep(
        header: [
          _buildMascotAvatar(size: 56),
          const SizedBox(height: 10),
          title,
          const SizedBox(height: 4),
          body,
          const SizedBox(height: 8),
          counter,
        ],
        content: (_) => [chips, const SizedBox(height: 8), addButton],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildMascotAvatar(size: 76),
          const SizedBox(height: 16),
          title,
          const SizedBox(height: 4),
          body,
          const SizedBox(height: 8),
          counter,
          const SizedBox(height: 20),
          chips,
          const SizedBox(height: 16),
          addButton,
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Seçenekli adımların ortak düzeni (segment adımındakiyle aynı).
  Widget _optionsStep({
    required String titleText,
    required String bodyText,
    required List<Widget> options,
    required Color textColor,
    required bool sideBySide,
  }) {
    final title = Text(titleText,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: sideBySide ? 22 : 24, fontWeight: FontWeight.bold, color: textColor));
    final body = Text(bodyText,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.4, color: textColor.withValues(alpha: 0.7)));
    if (sideBySide) {
      return _sideBySideStep(
        header: [_buildMascotAvatar(size: 56), const SizedBox(height: 10), title, const SizedBox(height: 6), body],
        content: (_) => options,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: _formWidth(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMascotAvatar(size: 76),
            const SizedBox(height: 16),
            title,
            const SizedBox(height: 8),
            body,
            const SizedBox(height: 24),
            ...options,
          ],
        ),
      ),
    );
  }

  /// Sıralamalarda görünürlük (show_in_social_feed) açıkça sorulur; iki
  /// seçenekten biri seçilmeden ilerlenemez, varsayılan seçim yoktur.
  Widget _buildVisibilityStep(bool isDark, Color textColor, bool sideBySide) {
    final l10n = AppLocalizations.of(context)!;
    return _optionsStep(
      titleText: l10n.onboardingVisibilityTitle,
      bodyText: l10n.onboardingVisibilityBody,
      textColor: textColor,
      sideBySide: sideBySide,
      options: [
        _optionButton(l10n.onboardingVisibilityYes, _showInRankings == true,
            () => setState(() => _showInRankings = true), isDark, textColor),
        _optionButton(l10n.onboardingVisibilityNo, _showInRankings == false,
            () => setState(() => _showInRankings = false), isDark, textColor),
      ],
    );
  }

  /// İlk kullanımda oyun kuralları: tek duraklatma, günlük sınır, puan ve kum.
  Widget _buildRulesStep(Color textColor, bool sideBySide) {
    final l10n = AppLocalizations.of(context)!;
    return _optionsStep(
      titleText: l10n.gameRulesTitle,
      bodyText: l10n.onboardingRulesBody,
      textColor: textColor,
      sideBySide: sideBySide,
      options: const [GameRulesList()],
    );
  }

  Widget _buildGoalStep(bool isDark, Color textColor, bool sideBySide) {
    final l10n = AppLocalizations.of(context)!;
    final title = Text(
      l10n.onboardingGoalStepTitle,
      style: TextStyle(fontSize: sideBySide ? 22 : 24, fontWeight: FontWeight.bold, color: textColor),
      textAlign: TextAlign.center,
    );
    final body = Text(
      l10n.onboardingGoalStepBody,
      style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
      textAlign: TextAlign.center,
    );
    final options = [
      for (final (label, minutes) in [
        (l10n.onboardingGoal1h, 60),
        (l10n.onboardingGoal2h, 120),
        (l10n.onboardingGoal3h, 180),
        (l10n.onboardingGoal4hPlus, 240),
      ])
        _optionButton(label, _dailyGoalMinutes == minutes, () => setState(() => _dailyGoalMinutes = minutes),
            isDark, textColor),
    ];

    if (sideBySide) {
      return _sideBySideStep(
        header: [_buildMascotAvatar(size: 64), const SizedBox(height: 12), title, const SizedBox(height: 6), body],
        content: (_) => options,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: _formWidth(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMascotAvatar(),
            const SizedBox(height: 20),
            title,
            const SizedBox(height: 8),
            body,
            const SizedBox(height: 32),
            ...options,
          ],
        ),
      ),
    );
  }
}
