import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../theme.dart'; 
import 'package:flutter/cupertino.dart'; // For cupertino picker
import '../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Data
  int _birthYear = DateTime.now().year - 20;
  String? _userSegment;
  final Set<String> _selectedCategoryNames = {};
  int _dailyGoalMinutes = 60;
  bool _isUnder13 = false;
  
  // Custom categories
  final List<Map<String, dynamic>> _customCategories = [];

  void _nextPage() {
    if (_currentPage == 0) {
      final age = DateTime.now().year - _birthYear;
      if (age < 13) {
        setState(() => _isUnder13 = true);
        return;
      }
    }
    
    if (_currentPage == 1 && _userSegment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir kitle seçin.')));
      return;
    }
    
    if (_currentPage < 4) {
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
      // İstek gönder
      await NotificationService.instance.requestPermission();

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('profiles').update({
          'birth_year': _birthYear,
          'user_segment': _userSegment,
          'daily_goal_minutes': _dailyGoalMinutes,
          'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
      }

      List<Map<String, dynamic>> finalCategories = [];
      final predefined = _getRecommendedCategories();
      final defaultColors = [
        '#FF5252', '#FF4081', '#E040FB', '#7C4DFF', 
        '#536DFE', '#448AFF', '#40C4FF', '#18FFFF',
        '#64FFDA', '#69F0AE', '#B2FF59', '#EEFF41',
        '#FFFF00', '#FFD740', '#FFAB40', '#FF6E40'
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

      if (finalCategories.isNotEmpty) {
        await SupabaseService.instance.setupOnboardingCategories(finalCategories);
      } else {
        await SupabaseService.instance.updateOnboardingCompleted();
      }

      if (mounted) {
        widget.onCompleted();
      }
    } catch (e) {
      debugPrint('Onboarding error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _getRecommendedCategories() {
    if (_userSegment == 'lgs') {
      return [
        {'name': 'Matematik'}, {'name': 'Fen Bilimleri'}, {'name': 'Türkçe'},
        {'name': 'T.C. İnkılap Tarihi'}, {'name': 'İngilizce'}, {'name': 'Din Kültürü'}
      ];
    } else if (_userSegment == 'yks') {
      return [
        {'name': 'Matematik'}, {'name': 'Fizik'}, {'name': 'Kimya'}, {'name': 'Biyoloji'},
        {'name': 'Türkçe'}, {'name': 'Tarih'}, {'name': 'Coğrafya'}, {'name': 'Felsefe'}, {'name': 'İngilizce'}
      ];
    } else if (_userSegment == 'university') {
      return [
        {'name': 'Ders Çalışma'}, {'name': 'Ödev'}, {'name': 'Proje'}, {'name': 'Sınav Hazırlık'}
      ];
    } else if (_userSegment == 'work') {
      return [
        {'name': 'Derin Çalışma'}, {'name': 'Okuma'}, {'name': 'Öğrenme'}, {'name': 'Proje'}
      ];
    }
    return [];
  }

  void _showAddCategoryDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Kategori Ekle'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(hintText: 'Kategori Adı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  if (_selectedCategoryNames.length >= 8) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En fazla 8 kategori seçebilirsin.')));
                    Navigator.pop(ctx);
                    return;
                  }
                  setState(() {
                    _customCategories.add({
                      'name': name,
                      'color_hex': '#448AFF', // default
                      'icon_name': 'star',
                    });
                    _selectedCategoryNames.add(name);
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnder13) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Bu uygulamayı kullanmak için veli onayı gerekiyor.', style: TextStyle(fontSize: 18), textAlign: TextAlign.center,),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _isUnder13 = false),
                child: const Text('Geri'),
              )
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / 5,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildAgeStep(),
                  _buildSegmentStep(isDark),
                  _buildCategoryStep(),
                  _buildGoalStep(isDark),
                  _buildNotificationStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(_currentPage == 4 ? 'Bitir' : 'Devam Et'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAgeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/avatars/avatar_16_basic.png', height: 120, errorBuilder: (c,e,s) => const Icon(Icons.person, size: 100)),
        const SizedBox(height: 20),
        const Text('Doğum yılın?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        SizedBox(
          height: 200,
          child: CupertinoPicker(
            itemExtent: 50,
            scrollController: FixedExtentScrollController(initialItem: 30), // Around 2006 if start is 1976
            onSelectedItemChanged: (i) => setState(() => _birthYear = DateTime.now().year - 50 + i),
            children: List.generate(51, (i) {
              final year = DateTime.now().year - 50 + i;
              return Center(child: Text(year.toString(), style: const TextStyle(fontSize: 22)));
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentStep(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Neye çalışıyorsun?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        _segmentBtn('LGS', 'lgs', isDark),
        _segmentBtn('YKS', 'yks', isDark),
        _segmentBtn('Üniversite', 'university', isDark),
        _segmentBtn('İş & Kişisel Gelişim', 'work', isDark),
      ],
    );
  }

  Widget _segmentBtn(String label, String value, bool isDark) {
    final isSelected = _userSegment == value;
    final color = isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _userSegment = value;
            _selectedCategoryNames.clear(); // Reset selections
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey),
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: color)),
        ),
      ),
    );
  }

  Widget _buildCategoryStep() {
    final recs = _getRecommendedCategories();
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text('Kategori Seçimi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Ücretsiz planda en fazla 8 kategori seçebilirsin.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Text('${_selectedCategoryNames.length} / 8', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: recs.map((e) {
                final name = e['name'] as String;
                final isSel = _selectedCategoryNames.contains(name);
                return ChoiceChip(
                  label: Text(name),
                  selected: isSel,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (_selectedCategoryNames.length >= 8) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En fazla 8 kategori seçebilirsin.')));
                          return;
                        }
                        _selectedCategoryNames.add(name);
                      } else {
                        _selectedCategoryNames.remove(name);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // Custom categories
          if (_customCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: _customCategories.map((e) {
                  final name = e['name'] as String;
                  final isSel = _selectedCategoryNames.contains(name);
                  return ChoiceChip(
                    label: Text(name),
                    selected: isSel,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          if (_selectedCategoryNames.length >= 8) return;
                          _selectedCategoryNames.add(name);
                        } else {
                          _selectedCategoryNames.remove(name);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('+ Kendi kategorimi oluştur'),
            onPressed: _showAddCategoryDialog,
          )
        ],
      ),
    );
  }

  Widget _buildGoalStep(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Günde ne kadar çalışmayı hedefliyorsun?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 40),
        _goalBtn('1 Saat', 60, isDark),
        _goalBtn('2 Saat', 120, isDark),
        _goalBtn('3 Saat', 180, isDark),
        _goalBtn('4 Saat+', 240, isDark),
      ],
    );
  }

  Widget _goalBtn(String label, int mins, bool isDark) {
    final isSelected = _dailyGoalMinutes == mins;
    final color = isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: InkWell(
        onTap: () => setState(() => _dailyGoalMinutes = mins),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey),
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: color)),
        ),
      ),
    );
  }

  Widget _buildNotificationStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.notifications_active, size: 80, color: AppColors.primary),
        const SizedBox(height: 20),
        const Text('Bildirimlere İzin Ver', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Çalışma zamanlarını hatırlatmak ve hedeflerine ulaşmana yardımcı olmak için sana bildirim göndermek istiyoruz.', textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
