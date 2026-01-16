import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentifier {
  static const _prefsKey = 'device_id';

  static Future<String> resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final deviceInfo = DeviceInfoPlugin();
    String? identifier;
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      identifier = info.id;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      identifier = info.identifierForVendor;
    }

    if (identifier == null || identifier.trim().isEmpty) {
      identifier = null;
    }

    identifier ??= _fallbackId();
    await prefs.setString(_prefsKey, identifier);
    return identifier;
  }

  static String _fallbackId() {
    final random = Random.secure();
    final bytes = List<int>.generate(4, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'local-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}
