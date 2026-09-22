import 'package:flutter/services.dart';

/// OS version only; no device identifiers are collected.
Future<String> reportPlatform() async {
  try {
    final value = await const MethodChannel('com.nzkosh.seep/device')
        .invokeMethod<String>('androidVersion')
        .timeout(const Duration(seconds: 3));
    if (value != null && value.startsWith('android ') && value.length <= 32) {
      return value;
    }
  } catch (_) {
    // Older hosts and tests may not provide the native channel.
  }
  return 'android';
}
