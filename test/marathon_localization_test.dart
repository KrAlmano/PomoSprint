import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';

void main() {
  test(
    'TR and EN guides keep server bonus values with their duration and count',
    () async {
      // Deliberately different from today's policy: localized help must display
      // the server config, rather than a fixed reward matrix embedded in prose.
      const shortRewards = [17, 23, 31];
      const longRewards = [43, 59, 71];
      for (final locale in const [Locale('tr'), Locale('en')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        final table = l10n.marathonInfoBonusMatrix(
          shortRewards[0],
          shortRewards[1],
          shortRewards[2],
          longRewards[0],
          longRewards[1],
          longRewards[2],
        );
        final lines = table.split('\n');
        final shortLine = lines.firstWhere((line) => line.startsWith('25 '));
        final longLine = lines.firstWhere((line) => line.startsWith('50 '));
        for (var index = 0; index < 3; index++) {
          expect(shortLine, contains('${index + 2} '));
          expect(shortLine, contains('+${shortRewards[index]}'));
          expect(longLine, contains('${index + 2} '));
          expect(longLine, contains('+${longRewards[index]}'));
          expect(shortLine, isNot(contains('+${longRewards[index]}')));
          expect(longLine, isNot(contains('+${shortRewards[index]}')));
        }
        expect(table, isNot(contains('{')));
        expect(table, isNot(contains('}')));
        expect(
          l10n.marathonAutomaticHint,
          contains(l10n.marathonPresenceConfirm),
          reason:
              '${locale.languageCode} instructions use the visible button name',
        );
        expect(
          l10n.marathonPresenceHint,
          contains(l10n.marathonPresenceConfirm),
        );
        expect(l10n.marathonBreakHint, contains(l10n.marathonPresenceConfirm));
        expect(
          l10n.notifMarathonBreakDoneBody(2, 4),
          contains(l10n.marathonPresenceConfirm),
        );
      }
    },
  );
}
