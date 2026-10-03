import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/main.dart' show kAppDisplayName;
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/color_hex.dart';

// Üretilen platform dosyalarının (flutter_launcher_icons,
// flutter_native_splash) ve uygulama adının uygulamayla tutarlı kaldığını
// doğrular. Dosyalar yeniden üretilince ya da tema rengi değişince kırılır.

const _res = 'android/app/src/main/res';

String _read(String path) => File(path).readAsStringSync();

/// 1x1 PNG zeminin rengini '#RRGGBB' olarak okur (flutter_native_splash
/// zemin rengini böyle yazar). Tek pikselde tüm PNG filtreleri ham değeri
/// verir; yalnızca IDAT'ın zlib'i açılır.
String _onePixelColor(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var offset = 8; // PNG imzası
  final idat = BytesBuilder();
  int? width, height, colorType;
  while (offset < bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    final start = offset + 8;
    if (type == 'IHDR') {
      width = data.getUint32(start);
      height = data.getUint32(start + 4);
      colorType = bytes[start + 9];
    } else if (type == 'IDAT') {
      idat.add(bytes.sublist(start, start + length));
    } else if (type == 'IEND') {
      break;
    }
    offset = start + length + 4; // + CRC
  }
  expect((width, height), (1, 1), reason: '$path 1x1 değil');
  expect(colorType, anyOf(2, 6), reason: '$path RGB/RGBA değil');
  final raw = zlib.decode(idat.takeBytes());
  final rgb = raw.sublist(1, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '#${rgb.toUpperCase()}';
}

String? _splashBackground(String stylesPath) =>
    RegExp(r'windowSplashScreenBackground">(#[0-9A-Fa-f]{6})<').firstMatch(_read(stylesPath))?.group(1)?.toUpperCase();

void main() {
  test('uygulama adı son uygulamalar ekranında ve başlatıcıda aynı', () {
    expect(kAppDisplayName, 'PomoSprint');
    expect(_read('android/app/src/main/AndroidManifest.xml'), contains('android:label="$kAppDisplayName"'));
    final plist = _read('ios/Runner/Info.plist');
    expect(
      RegExp(r'<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>').firstMatch(plist)?.group(1),
      kAppDisplayName,
    );
  });

  group('Yerel açılış ekranı Flutter açılış ekranıyla aynı renkte', () {
    final light = colorToHex(AppColors.surface);
    final dark = colorToHex(AppColors.darkSurface);

    test('Android 12+ (açık ve koyu tema)', () {
      expect(_splashBackground('$_res/values-v31/styles.xml'), light);
      expect(_splashBackground('$_res/values-night-v31/styles.xml'), dark);
      for (final folder in ['values-v31', 'values-night-v31']) {
        expect(_read('$_res/$folder/styles.xml'), contains('@drawable/android12splash'), reason: folder);
      }
    });

    test('Android 11 ve altı (açık ve koyu tema)', () {
      expect(_onePixelColor('$_res/drawable/background.png'), light);
      expect(_onePixelColor('$_res/drawable-v21/background.png'), light);
      expect(_onePixelColor('$_res/drawable-night/background.png'), dark);
      expect(_onePixelColor('$_res/drawable-night-v21/background.png'), dark);
      expect(File('$_res/drawable-night/launch_background.xml').existsSync(), isTrue);
      expect(File('$_res/drawable-night-v21/launch_background.xml').existsSync(), isTrue);
    });

    test('iOS (açık ve koyu görünüm)', () {
      const set = 'ios/Runner/Assets.xcassets/LaunchBackground.imageset';
      expect(_onePixelColor('$set/background.png'), light);
      expect(_onePixelColor('$set/darkbackground.png'), dark);
      final contents = _read('$set/Contents.json');
      expect(contents, contains('"darkbackground.png"'));
      expect(contents, contains('"dark"'));
    });
  });

  test('Android 13+ temalı simge için monochrome katmanı var', () {
    expect(_read('$_res/mipmap-anydpi-v26/ic_launcher.xml'), contains('@drawable/ic_launcher_monochrome'));
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('$_res/drawable-$density/ic_launcher_monochrome.png').existsSync(), isTrue, reason: density);
    }
  });
}
