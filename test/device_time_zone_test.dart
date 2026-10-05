import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/device_time_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(DeviceTimeZone.channel, null),
  );
  test(
    'IANA adı döner; UTC farkı, bilinmeyen dilim ve platform hatası gönderilmez',
    () async {
      for (final zone in [
        'Europe/Istanbul',
        'America/New_York',
        'Asia/Tokyo',
      ]) {
        messenger.setMockMethodCallHandler(
          DeviceTimeZone.channel,
          (_) async => zone,
        );
        expect(await DeviceTimeZone.read(), zone);
      }
      for (final zone in ['bad/zone', 'GMT+03:00', '']) {
        messenger.setMockMethodCallHandler(
          DeviceTimeZone.channel,
          (_) async => zone,
        );
        expect(await DeviceTimeZone.read(), isNull);
      }
      messenger.setMockMethodCallHandler(
        DeviceTimeZone.channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(await DeviceTimeZone.read(), isNull);
    },
  );
}
