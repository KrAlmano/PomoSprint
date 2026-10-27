import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/l10n/app_localizations_en.dart';
import 'package:pomodoro/l10n/app_localizations_tr.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart';

void main() {
  // Fresh process: neither config nor ranking has been read successfully.
  // The always-available points help must not promise the old 30-person rule.
  for (final locale in ['tr', 'en']) {
    testWidgets('cold offline league help uses current capacity: $locale', (
      tester,
    ) async {
      SupabaseService.instance.debugCloudActive = false;
      final l10n = locale == 'tr'
          ? AppLocalizationsTr()
          : AppLocalizationsEn();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: LeagueInfoSheet()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.leagueInfoWhatBodyWithCapacity(25)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.leagueInfoWhatBodyWithCapacity(30)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
