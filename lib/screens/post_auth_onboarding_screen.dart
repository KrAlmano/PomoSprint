import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';

class PostAuthOnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const PostAuthOnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  State<PostAuthOnboardingScreen> createState() => _PostAuthOnboardingScreenState();
}

class _PostAuthOnboardingScreenState extends State<PostAuthOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0; // 0..3 → 4 steps (Age, Segment, Categories, Goal)

  int _birthYear = DateTime.now().year - 17; // default
  String? _userSegment;
  final Set<String> _selectedCategoryNames = {};
  int _dailyGoalMinutes = 60;
  final List<Map<String, dynamic>> _customCategories = [];

  static const int _totalSteps = 4;
  bool _isSaving = false;

  void _nextPage() {
    if (_currentPage == 1 && _userSegment == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingSelectOptionError)),
      );
      return;
    }
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  Future<void> _finishOnboarding() async {
    try {
      setState(() => _isSaving = true);
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isSaving = false);
        return;
      }

      // 1. Profil güncelle
      // Not: Ağ takılırsa bu çağrının süresiz beklemede kalmaması için
      // (önceden zaman aşımı yoktu — "Bitir" butonu sonsuza kadar dönerdi)
      // bir zaman aşımı ekliyoruz; süre dolarsa aşağıdaki catch bloğu
      // devreye girip kullanıcıya tekrar deneme imkanı verir.
      final nowStr = DateTime.now().toUtc().toIso8601String();
      await client.from('profiles').update({
        'birth_year': _birthYear,
        'user_segment': _userSegment,
        'daily_goal_minutes': _dailyGoalMinutes,
        'onboarding_completed_at': nowStr,
      }).eq('id', userId).timeout(const Duration(seconds: 12));

      // 1b. SharedPreferences yerel önbelleğini güncelle (Splash tekrar çalıştığında eski veriyi okumasın)
      final prefs = await SharedPreferences.getInstance();
      final savedUserStr = prefs.getString('saved_user');
      if (savedUserStr != null && savedUserStr.isNotEmpty) {
        try {
          final Map<String, dynamic> userMap = jsonDecode(savedUserStr);
          userMap['birth_year'] = _birthYear;
          userMap['user_segment'] = _userSegment;
          userMap['daily_goal_minutes'] = _dailyGoalMinutes;
          userMap['onboarding_completed_at'] = nowStr;
          await prefs.setString('saved_user', jsonEncode(userMap));
        } catch (_) {}
      }

      // 2. Kategorileri hazırla
      final List<Map<String, dynamic>> finalCategories = [];
      final predefined = _getRecommendedCategories();
      final defaultColors = [
        '#EF4444', '#3B82F6', '#10B981', '#F59E0B',
        '#8B5CF6', '#EC4899', '#14B8A6', '#F97316',
        '#64FFDA', '#69F0AE', '#7C4DFF', '#FFAB40',
      ];
      int colorIdx = 0;
      for (var p in predefined) {
        if (_selectedCategoryNames.contains(p['name'])) {
          finalCategories.add({
            'name': p['name'],
            'color_hex': defaultColors[colorIdx % defaultColors.length],
            'icon_name': 'book',
          });
          colorIdx++;
        }
      }
      for (var c in _customCategories) {
        if (_selectedCategoryNames.contains(c['name'])) {
          finalCategories.add(c);
        }
      }

      // 3. Kategorileri kaydet
      if (finalCategories.isNotEmpty) {
        await SupabaseService.instance.setupOnboardingCategories(finalCategories);
      }

      if (mounted) widget.onCompleted();
    } catch (e) {
      debugPrint('PostAuth onboarding error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        final isTimeout = e is TimeoutException;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTimeout
                  ? l10n.onboardingTimeoutError
                  : l10n.onboardingGenericError(e.toString()),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getRecommendedCategories() {
    if (_userSegment == 'lgs') {
      return [
        {'name': 'Matematik'}, {'name': 'Fen Bilimleri'}, {'name': 'Türkçe'},
        {'name': 'T.C. İnkılap Tarihi'}, {'name': 'İngilizce'}, {'name': 'Din Kültürü'},
      ];
    } else if (_userSegment == 'yks') {
      return [
        {'name': 'Matematik'}, {'name': 'Fizik'}, {'name': 'Kimya'}, {'name': 'Biyoloji'},
        {'name': 'Türkçe'}, {'name': 'Tarih'}, {'name': 'Coğrafya'}, {'name': 'Felsefe'},
        {'name': 'İngilizce'},
      ];
    } else if (_userSegment == 'university') {
      return [
        {'name': 'Ders Çalışma'}, {'name': 'Ödev'}, {'name': 'Proje'}, {'name': 'Sınav Hazırlık'},
      ];
    } else if (_userSegment == 'work') {
      return [
        {'name': 'Derin Çalışma'}, {'name': 'Okuma'}, {'name': 'Öğrenme'}, {'name': 'Proje'},
      ];
    }
    return [];
  }

  void _showAddCategoryDialog() {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.onboardingAddCategoryTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.onboardingCategoryHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                if (_selectedCategoryNames.length >= 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.onboardingMaxCategoriesMsg)),
                  );
                  Navigator.pop(ctx);
                  return;
                }
                setState(() {
                  _customCategories.add({'name': name, 'color_hex': '#3B82F6', 'icon_name': 'star'});
                  _selectedCategoryNames.add(name);
                });
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.addBtn),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;

    return Scaffold(
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
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / _totalSteps,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                        _currentPage == _totalSteps - 1
                            ? AppLocalizations.of(context)!.onboardingFinishBtn
                            : AppLocalizations.of(context)!.continueBtn,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
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
            scrollController: FixedExtentScrollController(
              initialItem: DateTime.now().year - _birthYear,
            ),
            onSelectedItemChanged: (i) {
              setState(() => _birthYear = DateTime.now().year - i);
            },
            children: List.generate(87, (i) {
              final year = DateTime.now().year - i;
              return Center(
                child: Text(
                  year.toString(),
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
          _segmentBtn(l10n.onboardingSegmentLgs, 'lgs', isDark, textColor),
          _segmentBtn(l10n.onboardingSegmentYks, 'yks', isDark, textColor),
          _segmentBtn(l10n.onboardingSegmentUniversity, 'university', isDark, textColor),
          _segmentBtn(l10n.onboardingSegmentWork, 'work', isDark, textColor),
        ],
      ),
    );
  }

  Widget _segmentBtn(String label, String value, bool isDark, Color textColor) {
    final isSelected = _userSegment == value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => setState(() {
          _userSegment = value;
          _selectedCategoryNames.clear();
        }),
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
    final recs = _getRecommendedCategories();
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
            l10n.onboardingCategoryStepBody,
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
              '${_selectedCategoryNames.length} / 8',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ...recs.map((e) {
                final name = e['name'] as String;
                final isSel = _selectedCategoryNames.contains(name);
                return ChoiceChip(
                  label: Text(LanguageService.instance.translateCatName(name)),
                  selected: isSel,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (val) => setState(() {
                    if (val) {
                      if (_selectedCategoryNames.length >= 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.onboardingMaxCategoriesMsg)),
                        );
                        return;
                      }
                      _selectedCategoryNames.add(name);
                    } else {
                      _selectedCategoryNames.remove(name);
                    }
                  }),
                );
              }),
              ..._customCategories.map((e) {
                final name = e['name'] as String;
                final isSel = _selectedCategoryNames.contains(name);
                return ChoiceChip(
                  label: Text(name),
                  selected: isSel,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (val) => setState(() {
                    if (val) {
                      if (_selectedCategoryNames.length >= 8) return;
                      _selectedCategoryNames.add(name);
                    } else {
                      _selectedCategoryNames.remove(name);
                    }
                  }),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.onboardingCreateOwnCategory),
            onPressed: _showAddCategoryDialog,
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
          _goalBtn(l10n.onboardingGoal1h, 60, isDark, textColor),
          _goalBtn(l10n.onboardingGoal2h, 120, isDark, textColor),
          _goalBtn(l10n.onboardingGoal3h, 180, isDark, textColor),
          _goalBtn(l10n.onboardingGoal4hPlus, 240, isDark, textColor),
        ],
      ),
    );
  }

  Widget _goalBtn(String label, int mins, bool isDark, Color textColor) {
    final isSelected = _dailyGoalMinutes == mins;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => setState(() => _dailyGoalMinutes = mins),
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
}
