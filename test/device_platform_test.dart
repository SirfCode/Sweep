import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/reporting/device_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nzkosh.seep/device');
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  test('reads Android release and API level', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'androidVersion');
      return 'android 16 (API 36)';
    });
    expect(await reportPlatform(), 'android 16 (API 36)');
  });
  test('missing native channel does not prevent reporting', () async {
    expect(await reportPlatform(), 'android');
  });
}
