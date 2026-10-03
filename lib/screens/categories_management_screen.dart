import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';

class CategoriesManagementScreen extends StatefulWidget {
  final bool isPremium;
  
  const CategoriesManagementScreen({super.key, this.isPremium = false});

  @override
  State<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> {
  List<CourseCategory> _activeCategories = [];
  List<CourseCategory> _archivedCategories = [];
  bool _isLoading = true;

  final List<String> _availableColors = [
    '#EF4444', '#3B82F6', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899', '#14B8A6', '#F97316'
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final allCats = await SupabaseService.instance.fetchUserCategories(includeArchived: true);
      setState(() {
        _activeCategories = allCats.where((c) => !c.isArchived).toList();
        _archivedCategories = allCats.where((c) => c.isArchived).toList();
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCategoryDialog({CourseCategory? cat}) {
    final l10n = AppLocalizations.of(context)!;
    final limit = widget.isPremium ? 15 : 8;
    if (cat == null && _activeCategories.length >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.categoryLimitReachedMsg(limit))));
      return;
    }

    final nameCtrl = TextEditingController(text: cat?.name);
    String selectedColor = cat?.colorHex ?? _availableColors[0];
    // if cat?.colorHex is not in the list, just add it for this dialog instance
    if (!selectedColor.startsWith('#')) selectedColor = '#$selectedColor';
    selectedColor = selectedColor.toUpperCase();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(cat == null ? l10n.newCategoryDialogTitle : l10n.editCategoryDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(hintText: l10n.categoryNameHint),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.chooseColor, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((hex) {
                      final cValue = int.tryParse(hex.substring(1), radix: 16) ?? 0xFF0000;
                      final isSelected = hex == selectedColor;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Color(cValue).withValues(alpha: 1.0),
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 2),
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        if (cat == null) {
                          await SupabaseService.instance.createCategory(nameCtrl.text.trim(), selectedColor, 'book');
                        } else {
                          await SupabaseService.instance.updateCategory(cat.id, nameCtrl.text.trim(), selectedColor, cat.iconName);
                        }
                        await _loadCategories();
                      } catch (e) {
                        setState(() => _isLoading = false);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: Text(cat == null ? l10n.addBtn : l10n.save),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _archiveCategory(CourseCategory cat) async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.archiveCategory(cat.id);
      await _loadCategories();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _unarchiveCategory(CourseCategory cat) async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.unarchiveCategory(cat.id);
      await _loadCategories();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = LanguageService.instance;
    final limit = widget.isPremium ? 15 : 8;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesManagementTitle)),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
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
                    Text(l10n.activeCategoryCountLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${_activeCategories.length} / $limit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorderItem: (oldIndex, newIndex) async {
                  final item = _activeCategories.removeAt(oldIndex);
                  _activeCategories.insert(newIndex, item);
                  setState(() {});
                  await SupabaseService.instance.updateCategoryOrders(_activeCategories.map((e) => e.id).toList());
                },
                children: _activeCategories.map((c) {
                  final hex = c.colorHex.startsWith('#') ? c.colorHex.substring(1) : c.colorHex;
                  final colorVal = int.tryParse(hex, radix: 16) ?? 0xFF0000;
                  return ListTile(
                    key: ValueKey(c.id),
                    title: Text(lang.translateCatName(c.name)),
                    leading: CircleAvatar(
                      backgroundColor: Color(colorVal).withValues(alpha: 1.0),
                      radius: 12,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCategoryDialog(cat: c)),
                        IconButton(
                          icon: const Icon(Icons.archive),
                          onPressed: () => _archiveCategory(c),
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
                label: Text(l10n.addCategoryTitle)
              ),
              const Divider(height: 40),
              Text(l10n.archivedCategoriesHeader, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(l10n.archivedCategoriesDesc, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              ..._archivedCategories.map((c) => ListTile(
                title: Text(lang.translateCatName(c.name)),
                trailing: IconButton(
                  icon: const Icon(Icons.unarchive),
                  onPressed: () => _unarchiveCategory(c),
                  tooltip: l10n.unarchiveTooltip,
                ),
              )),
            ],
          ),
    );
  }
}
