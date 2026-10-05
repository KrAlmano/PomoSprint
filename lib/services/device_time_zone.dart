import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

/// iOS/Android'in IANA adı; sabit UTC farkı DST için yeterli değildir.
class DeviceTimeZone {
  static const channel = MethodChannel('com.pomosprint.app/device_timezone');

  static Future<String?> read() async {
    try {
      final name = await channel
          .invokeMethod<String>('getTimeZone')
          .timeout(const Duration(seconds: 2));
      if (name == null || name.isEmpty) return null;
      if (!tz.timeZoneDatabase.isInitialized) data.initializeTimeZones();
      tz.getLocation(name); // Geçersiz/özel GMT offset'i profile gönderilmez.
      return name;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
