import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'branch_exam_prototype_screen.dart';

/// Standalone preview entry point. It deliberately does not initialize the
/// production application or any service and has no account or backend.
void main() => runApp(const BranchPreviewApp());

class BranchPreviewApp extends StatelessWidget {
  const BranchPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'PomoSprint',
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    home: const BranchExamPrototypeScreen(),
  );
}
