import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../models/category_model.dart';
import '../services/language_service.dart';

class CategoriesScreen extends StatefulWidget {
  final List<CourseCategory> categories;
  final Function(CourseCategory) onAddCategory;
  final Function(String) onDeleteCategory;

  const CategoriesScreen({
    super.key,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _nameController = TextEditingController();
  Color _selectedColor = const Color(0xFF3B82F6);
  bool _isAdding = false;

  final List<Color> _presetColors = const [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  void _handleAdd() {
    if (_isAdding) return; // çift tıklama koruması
    final l10n = AppLocalizations.of(context)!;
    final text = _nameController.text.trim();
    if (text.isEmpty) return;
    final clamped = text.length > 40 ? text.substring(0, 40) : text;

    setState(() => _isAdding = true);
    widget.onAddCategory(
      CourseCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: clamped,
        color: _selectedColor,
        icon: Icons.book_outlined,
      ),
    );
    _nameController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.addedToast(clamped)),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Kısa bir süre sonra tekrar eklemeye izin ver (aynı anda çift kayıt önlenir).
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isAdding = false);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final lang = LanguageService.instance;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // New Category Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.translate('add_new_category'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang.translate('add_category_sub'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Input Field
                        TextField(
                          controller: _nameController,
                          maxLength: 40,
                          decoration: InputDecoration(
                            hintText: lang.translate('category_name_hint'),
                            hintStyle: TextStyle(
                              color: (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant).withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Color Picker Preset Row
                        Text(
                          lang.translate('color_selection'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _presetColors.map((color) {
                            final isSelected = _selectedColor == color;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColor = color),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: isDark ? AppColors.darkSurface : AppColors.surface, width: 3)
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 20,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isAdding ? null : _handleAdd,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: const Color(0x40FF5C4D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(
                              lang.translate('add_category_btn'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Existing Categories Section
                  Text(
                    lang.translate('existing_categories'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final cat = widget.categories[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Left Color Accent Pill
                            Container(
                              width: 6,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cat.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Category Title
                            Expanded(
                              child: Text(
                                lang.translateCatName(cat.name),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ),
                              ),
                            ),

                        // Action Icons
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                          onPressed: () => widget.onDeleteCategory(cat.id),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}
