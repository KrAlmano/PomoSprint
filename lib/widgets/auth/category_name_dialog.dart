import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/language_service.dart';
import '../../utils/color_hex.dart';

/// Kategori renk paleti; onboarding ve Kategorilerim aynı listeyi kullanır.
const List<String> kCategoryPalette = [
  '#EF4444', '#3B82F6', '#10B981', '#F59E0B',
  '#8B5CF6', '#EC4899', '#14B8A6', '#F97316',
  '#64FFDA', '#69F0AE', '#7C4DFF', '#FFAB40',
];

const int kCategoryNameMaxLength = 40;

/// Ad karşılaştırma anahtarı: büyük-küçük harf ve baş/son boşluk duyarsız.
/// Hazır kategorilerin çevirileri aynı ada eşlenir ('Mathematics' ile
/// 'Matematik' ekranda aynı göründüğü için aynı kategori sayılır).
String categoryNameKey(String name) =>
    LanguageService.instance.translateCatName(name.trim()).trim().toLowerCase();

bool isCategoryNameTaken(String name, Iterable<String> existingNames) {
  final key = categoryNameKey(name);
  return existingNames.any((e) => categoryNameKey(e) == key);
}

typedef CategoryDialogResult = ({String name, String colorHex});

/// Kategori adı (ve isteğe bağlı renk) soran diyalog. Ad 1..40 karakter
/// olmalı ve [takenNames] içinde (büyük-küçük harf duyarsız) bulunmamalı.
/// Vazgeçilirse null döner.
class CategoryNameDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String? hintText;
  final String? initialName;
  final String? initialColorHex;
  final bool showColorPicker;
  final Iterable<String> takenNames;

  const CategoryNameDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.hintText,
    this.initialName,
    this.initialColorHex,
    this.showColorPicker = true,
    this.takenNames = const [],
  });

  static Future<CategoryDialogResult?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? hintText,
    String? initialName,
    String? initialColorHex,
    bool showColorPicker = true,
    Iterable<String> takenNames = const [],
  }) {
    return showDialog<CategoryDialogResult>(
      context: context,
      builder: (_) => CategoryNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        hintText: hintText,
        initialName: initialName,
        initialColorHex: initialColorHex,
        showColorPicker: showColorPicker,
        takenNames: takenNames,
      ),
    );
  }

  @override
  State<CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<CategoryNameDialog> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.initialName);
  late String _colorHex = _normalizeHex(widget.initialColorHex ?? kCategoryPalette.first);
  String? _error;

  static String _normalizeHex(String hex) => colorToHex(colorFromHex(hex));

  // Mevcut renk paletin dışındaysa (ör. eski sürümlerden) seçili görünsün diye eklenir.
  late final List<String> _swatches = [
    ...kCategoryPalette,
    if (!kCategoryPalette.contains(_colorHex)) _colorHex,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (isCategoryNameTaken(name, widget.takenNames)) {
      setState(() => _error = AppLocalizations.of(context)!.categoryNameExistsMsg);
      return;
    }
    Navigator.pop<CategoryDialogResult>(context, (name: name, colorHex: _colorHex));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              maxLength: kCategoryNameMaxLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(hintText: widget.hintText, errorText: _error),
            ),
            if (widget.showColorPicker) ...[
              const SizedBox(height: 12),
              Text(l10n.chooseColor, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _swatches.map((hex) {
                  final color = colorFromHex(hex);
                  final isSelected = hex == _colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? onSurface : Colors.transparent, width: 2),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameCtrl,
          builder: (context, value, _) => ElevatedButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
