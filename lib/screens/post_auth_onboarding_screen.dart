import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../theme.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';
import '../widgets/auth/category_name_dialog.dart';

class PostAuthOnboardingScreen extends StatefulWidget {
  /// Onboarding sunucuya kaydedildikten sonra çağrılır. Güncel kullanıcı
  /// (doğum yılı, segment, günlük hedef ve onboardingCompletedAt dahil)
  /// `SupabaseService.instance.currentUser.value`'dadır; çağıran eski
  /// kullanıcı nesnesi yerine onu kullanmalıdır.
  final VoidCallback onCompleted;

  /// Kullanıcı onboarding'den çıkış yaptığında ya da oturumu düştüğünde,
  /// oturum kapatıldıktan sonra çağrılır; çağıran giriş ekranına dönmelidir.
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
  static const int _totalSteps = 4; // Yaş, Segment, Kategoriler, Hedef
  static const int _minimumAge = 13; // Kullanım Şartları ve Gizlilik Politikası
  static const int _birthYearCount = 87;
  static const int _defaultAge = 17;

  // Hazır öneriler Türkçe anahtarlarla tutulur; ekranda ve kayıtta
  // kullanıcının diline çevrilir (LanguageService.translateCatName).
  static const Map<String, List<String>> _recommendedBySegment = {
    'lgs': ['Matematik', 'Fen Bilimleri', 'Türkçe', 'T.C. İnkılap Tarihi', 'İngilizce', 'Din Kültürü'],
    'yks': ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe', 'İngilizce'],
    'university': ['Ders Çalışma', 'Ödev', 'Proje', 'Sınav Hazırlık'],
    'work': ['Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje'],
  };

  final PageController _pageController = PageController();
  final int _currentYear = DateTime.now().year;
  late int _birthYear = _currentYear - _defaultAge;
  late final FixedExtentScrollController _yearController =
      FixedExtentScrollController(initialItem: _currentYear - _birthYear);

  int _currentPage = 0;
  String? _userSegment;
  // Seçim sırası korunur; sunucudaki sıralama bu sırayla oluşur.
  final Set<String> _selectedCategoryNames = {};
  final List<String> _customCategoryNames = [];
  int _dailyGoalMinutes = 60;
  bool _isSaving = false;

  bool get _isUnderMinimumAge => _currentYear - _birthYear < _minimumAge;

  List<String> get _recommendedCategoryNames => _recommendedBySegment[_userSegment] ?? const [];

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
    final error = switch (_currentPage) {
      0 when _isUnderMinimumAge => l10n.onboardingUnder13Error,
      1 when _userSegment == null => l10n.onboardingSelectOptionError,
      2 when _selectedCategoryNames.isEmpty => l10n.onboardingSelectCategoryError,
      _ => null,
    };
    if (error != null) {
      _showSnack(error);
      return;
    }
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0 && !_isSaving) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
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
        userSegment: _userSegment,
        dailyGoalMinutes: _dailyGoalMinutes,
        categories: _categoryPayload(),
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

    // Android geri tuşu önce önceki adıma döner; ilk adımda uygulamayı kapatır.
    return PopScope(
      canPop: _currentPage == 0 && !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prevPage();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor),
                        onPressed: _isSaving ? null : _prevPage,
                      )
                    else if (widget.onSignedOut != null)
                      // Yanlış hesapla giren kullanıcı onboarding'i bitirmeden çıkabilir.
                      IconButton(
                        icon: Icon(Icons.logout, color: textColor),
                        tooltip: l10n.logout,
                        onPressed: _isSaving ? null : () => _signOut(),
                      )
                    else
                      const SizedBox(width: 48),
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
                        style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
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
                    _buildAgeStep(isDark, textColor),
                    _buildSegmentStep(isDark, textColor),
                    _buildCategoryStep(isDark, textColor),
                    _buildGoalStep(isDark, textColor),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
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
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildAgeStep(bool isDark, Color textColor) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMascotAvatar(),
          const SizedBox(height: 20),
          Text(
            l10n.onboardingWelcomeTitle,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.onboardingWelcomeBody,
              style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 52,
              scrollController: _yearController,
              onSelectedItemChanged: (i) {
                setState(() => _birthYear = _currentYear - i);
              },
              children: List.generate(_birthYearCount, (i) {
                return Center(
                  child: Text(
                    (_currentYear - i).toString(),
                    style: TextStyle(
                      fontSize: 22,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }),
            ),
          ),
          if (_isUnderMinimumAge)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
              child: Text(
                l10n.onboardingUnder13Error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentStep(bool isDark, Color textColor) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMascotAvatar(),
          const SizedBox(height: 20),
          Text(l10n.onboardingSegmentTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(l10n.onboardingSegmentBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6))),
          const SizedBox(height: 32),
          _optionButton(l10n.onboardingSegmentLgs, _userSegment == 'lgs', () => _selectSegment('lgs'), isDark, textColor),
          _optionButton(l10n.onboardingSegmentYks, _userSegment == 'yks', () => _selectSegment('yks'), isDark, textColor),
          _optionButton(l10n.onboardingSegmentUniversity, _userSegment == 'university',
              () => _selectSegment('university'), isDark, textColor),
          _optionButton(l10n.onboardingSegmentWork, _userSegment == 'work', () => _selectSegment('work'), isDark, textColor),
        ],
      ),
    );
  }

  Widget _optionButton(String label, bool isSelected, VoidCallback onTap, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryStep(bool isDark, Color textColor) {
    final l10n = AppLocalizations.of(context)!;
    final lang = LanguageService.instance;
    final limit = _categoryLimit;
    Widget chip(String name) => ChoiceChip(
          label: Text(lang.translateCatName(name)),
          selected: _selectedCategoryNames.contains(name),
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          onSelected: (val) => _toggleCategory(name, val),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildMascotAvatar(size: 76),
          const SizedBox(height: 16),
          Text(l10n.onboardingCategoryStepTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text(
            l10n.onboardingCategoryStepBodyLimit(limit),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedCategoryNames.length} / $limit',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final name in [..._recommendedCategoryNames, ..._customCategoryNames]) chip(name),
            ],
          ),
          const SizedBox(height: 16),
          // Metin '+' içerdiği için ayrıca ikon kullanılmaz.
          TextButton(
            onPressed: _showAddCategoryDialog,
            child: Text(l10n.onboardingCreateOwnCategory),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGoalStep(bool isDark, Color textColor) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMascotAvatar(),
          const SizedBox(height: 20),
          Text(
            l10n.onboardingGoalStepTitle,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingGoalStepBody,
            style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          for (final (label, minutes) in [
            (l10n.onboardingGoal1h, 60),
            (l10n.onboardingGoal2h, 120),
            (l10n.onboardingGoal3h, 180),
            (l10n.onboardingGoal4hPlus, 240),
          ])
            _optionButton(label, _dailyGoalMinutes == minutes, () => setState(() => _dailyGoalMinutes = minutes),
                isDark, textColor),
        ],
      ),
    );
  }
}
