import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import '../widgets/auth/category_name_dialog.dart';

/// Kategorilerim: ekleme, düzenleme, arşivleme ve sıralama. Tüm değişiklikler
/// SupabaseService üzerinden yapılır; servis başarıdan sonra
/// categoriesRevision'ı artırır, bu ekran da (Timer gibi) onu dinleyerek
/// listeyi yeniler.
class CategoriesManagementScreen extends StatefulWidget {
  final bool isPremium;

  const CategoriesManagementScreen({super.key, this.isPremium = false});

  @override
  State<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> {
  final _service = SupabaseService.instance;
  List<CourseCategory> _activeCategories = [];
  List<CourseCategory> _archivedCategories = [];
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _loadFailed = false;
  bool _isBusy = false;
  int _loadGeneration = 0;

  int get _limit => categoryLimitFor(isPremium: widget.isPremium);

  @override
  void initState() {
    super.initState();
    _service.categoriesRevision.addListener(_onCategoriesChanged);
    _loadCategories(showSpinner: false); // _isLoading zaten true
  }

  @override
  void dispose() {
    _service.categoriesRevision.removeListener(_onCategoriesChanged);
    super.dispose();
  }

  void _onCategoriesChanged() => _loadCategories(showSpinner: false);

  Future<void> _loadCategories({bool showSpinner = true}) async {
    // Üst üste gelen yüklemelerde yalnızca en sonuncunun sonucu uygulanır.
    final generation = ++_loadGeneration;
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final allCats = await _service.fetchUserCategories(includeArchived: true);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _activeCategories = allCats.where((c) => !c.isArchived).toList();
        _archivedCategories = allCats.where((c) => c.isArchived).toList();
        _isLoading = false;
        _hasLoaded = true;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
      if (_hasLoaded) _showSnack(AppLocalizations.of(context)!.categoriesLoadError);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(AppLocalizations l10n, Object error) {
    return switch (serviceErrorCodeOf(error)) {
      ServiceErrorCode.categoryLimitReached => l10n.categoryLimitReachedMsg(_limit),
      ServiceErrorCode.categoryNameExists => l10n.categoryNameExistsMsg,
      _ => l10n.categorySaveError,
    };
  }

  /// Bir kategori değişikliğini çalıştırır. Başarıda liste, servisin
  /// categoriesRevision bildirimiyle yenilenir; hatada mesaj gösterilir ve
  /// (iyimser değişiklikleri geri almak için) liste sunucudan tekrar okunur.
  Future<void> _mutate(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('Kategori işlemi başarısız: $e');
      if (!mounted) return;
      _showSnack(_errorText(AppLocalizations.of(context)!, e));
      await _loadCategories(showSpinner: false);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showCategoryDialog({CourseCategory? cat}) async {
    final l10n = AppLocalizations.of(context)!;
    if (cat == null && _activeCategories.length >= _limit) {
      _showSnack(l10n.categoryLimitReachedMsg(_limit));
      return;
    }

    final result = await CategoryNameDialog.show(
      context,
      title: cat == null ? l10n.newCategoryDialogTitle : l10n.editCategoryDialogTitle,
      confirmLabel: cat == null ? l10n.addBtn : l10n.save,
      hintText: l10n.categoryNameHint,
      initialName: cat == null ? null : LanguageService.instance.translateCatName(cat.name),
      initialColorHex: cat?.colorHex,
      // Sunucu kuralıyla aynı: ad yalnızca aktif kategoriler arasında benzersiz.
      takenNames: _activeCategories.where((c) => c.id != cat?.id).map((c) => c.name),
    );
    if (result == null || !mounted) return;

    await _mutate(() async {
      if (cat == null) {
        await _service.createCategory(result.name, result.colorHex, 'book');
      } else {
        // Ad değişmediyse (yalnızca çeviri gösterildiyse) sunucudaki ad korunur.
        final unchanged = categoryNameKey(result.name) == categoryNameKey(cat.name);
        await _service.updateCategory(cat.id, unchanged ? cat.name : result.name, result.colorHex, cat.iconName);
      }
    });
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      final item = _activeCategories.removeAt(oldIndex);
      _activeCategories.insert(newIndex, item);
    });
    final orderedIds = _activeCategories.map((e) => e.id).toList();
    await _mutate(() => _service.updateCategoryOrders(orderedIds));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = LanguageService.instance;
    // Liste tüm genişlikte kayar; içerik geniş ekranda okuma genişliğinde ortalanır.
    final horizontalPadding = math.max(16.0, (MediaQuery.sizeOf(context).width - ContentWidth.reading) / 2);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesManagementTitle),
        bottom: _isBusy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (!_hasLoaded && _loadFailed)
              ? _buildLoadError(l10n)
              : AbsorbPointer(
                  absorbing: _isBusy,
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(l10n.activeCategoryCountLabel,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            Text('${_activeCategories.length} / $_limit',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorderItem: _reorder,
                        children: _activeCategories.map((c) {
                          return ListTile(
                            key: ValueKey(c.id),
                            title: Text(lang.translateCatName(c.name)),
                            leading: CircleAvatar(backgroundColor: c.color, radius: 12),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCategoryDialog(cat: c)),
                                IconButton(
                                  icon: const Icon(Icons.archive),
                                  onPressed: () => _mutate(() => _service.archiveCategory(c.id)),
                                  tooltip: l10n.archiveCategoryTooltip,
                                ),
                                const Icon(Icons.drag_handle, color: Colors.grey),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showCategoryDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addCategoryTitle),
                      ),
                      const Divider(height: 40),
                      Text(l10n.archivedCategoriesHeader,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(l10n.archivedCategoriesDesc, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 10),
                      _buildArchivedGrid(l10n, lang),
                    ],
                  ),
                ),
    );
  }

  /// Arşivdeki kategoriler: telefonda tek sütun liste, geniş ekranda iki
  /// sütun. Hücre yüksekliği içeriğe göre (büyük yazı ölçeğinde taşmaz).
  Widget _buildArchivedGrid(AppLocalizations l10n, LanguageService lang) {
    final columns = Responsive.of(context).columns(compact: 1, medium: 2, expanded: 2);
    Widget tile(CourseCategory c) => ListTile(
          title: Text(lang.translateCatName(c.name)),
          trailing: IconButton(
            icon: const Icon(Icons.unarchive),
            // Limit sunucudaki trigger ile zorunlu; aşılırsa hata mesajı gösterilir.
            onPressed: () => _mutate(() => _service.unarchiveCategory(c.id)),
            tooltip: l10n.unarchiveTooltip,
          ),
        );
    if (columns == 1) {
      return Column(children: [for (final c in _archivedCategories) tile(c)]);
    }
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          children: [
            for (final c in _archivedCategories) SizedBox(width: itemWidth, child: tile(c)),
          ],
        );
      },
    );
  }

  Widget _buildLoadError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.categoriesLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCategories,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.categoriesRetryBtn),
            ),
          ],
        ),
      ),
    );
  }
}
