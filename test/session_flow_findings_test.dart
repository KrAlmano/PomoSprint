import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageService.instance.setLanguage(AppLanguage.tr));

  group('UX-15: ön planda biten seansın uyarısı', () {
    Future<List<String>> run({required bool enabled, bool vibrateFails = false}) async {
      final calls = <String>[];
      await runForegroundSessionEndAlert(
        vibrate: () async {
          calls.add('vibrate');
          if (vibrateFails) throw StateError('titreşim yok');
        },
        notificationsEnabled: () async => enabled,
        playSound: () async => calls.add('sound'),
      );
      return calls;
    }

    test('bildirimler açıkken titreşim ve ses', () async {
      expect(await run(enabled: true), ['vibrate', 'sound']);
    });

    test('bildirim tercihi kapalıyken yalnızca titreşim', () async {
      expect(await run(enabled: false), ['vibrate']);
    });

    test('titreşim desteklenmese de ses çalar', () async {
      expect(await run(enabled: true, vibrateFails: true), ['vibrate', 'sound']);
    });
  });

  group('CAT-05: seans kaydı kategori rengini taşır', () {
    final t0 = DateTime(2026, 10, 3, 9);

    test('renk JSON gidiş-dönüşünde korunur, duraklat/devamda kaybolmaz', () {
      final s = ActiveTimerSession.start(
        clientUuid: 'c1',
        categoryId: 'cat-1',
        categoryName: 'Fizik',
        categoryColorHex: '#3B82F6',
        durationMinutes: 25,
        totalSeconds: 25 * 60,
        now: t0,
      );
      final paused = s.pauseAt(t0.add(const Duration(minutes: 3))).withForegroundSeconds(10);
      final resumed = paused.resumeAt(t0.add(const Duration(minutes: 5)));
      for (final x in [s, paused, resumed]) {
        final copy = ActiveTimerSession.fromJson(jsonDecode(jsonEncode(x.toJson())))!;
        expect(copy.categoryColorHex, '#3B82F6');
      }
    });

    test('rengi olmayan eski kayıt okunur', () {
      final json = ActiveTimerSession.start(
        clientUuid: 'c1',
        categoryId: 'cat-1',
        categoryName: 'Fizik',
        durationMinutes: 25,
        totalSeconds: 25 * 60,
        now: t0,
      ).toJson();
      expect(json.containsKey('category_color'), isFalse);
      final copy = ActiveTimerSession.fromJson(json)!;
      expect(copy.categoryColorHex, isNull);
      expect(copy.categoryName, 'Fizik');
    });
  });

  group('CAT-09: canlı çalışanlar satırında kategori adı çevrilir', () {
    test('hazır kategori arayüz dilinde, kullanıcının kendi adı olduğu gibi', () async {
      await LanguageService.instance.setLanguage(AppLanguage.en);
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(SocialScreen.liveStatusText({'category_name': 'Fizik'}, en), en.socialFocusingOn('Physics'));
      expect(
        SocialScreen.liveStatusText({'active_session_category_name': 'Matematik'}, en),
        en.socialFocusingOn('Mathematics'),
      );
      expect(SocialScreen.liveStatusText({'category_name': 'Gitar'}, en), en.socialFocusingOn('Gitar'));
      expect(SocialScreen.liveStatusText({'category_name': '  '}, en), en.socialFocusing);

      await LanguageService.instance.setLanguage(AppLanguage.tr);
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(SocialScreen.liveStatusText({'category_name': 'Physics'}, tr), tr.socialFocusingOn('Fizik'));
    });
  });
}
