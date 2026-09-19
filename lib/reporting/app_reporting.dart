import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'report_queue.dart';

/// Enabled only in explicitly configured native builds. Temporary dummy identity
/// is for the owner's testing builds, not public account authentication.
class AppReporting with WidgetsBindingObserver {
  static const email = String.fromEnvironment('SEEP_REPORT_EMAIL',
      defaultValue: 'player@example.com');
  static const version =
      String.fromEnvironment('SEEP_APP_VERSION', defaultValue: '0.10.0+10');
  final CompletedReportQueue queue;
  final http.Client client;
  Timer? _timer;
  Object? lastError;
  AppReporting._(this.queue, this.client);

  static Future<AppReporting?> open() async {
    const base = String.fromEnvironment('SEEP_API_URL');
    const key = String.fromEnvironment('SEEP_UPLOAD_API_KEY');
    if (kIsWeb || base.isEmpty || key.isEmpty) return null;
    final store = await FileReportStore.inAppDirectory();
    final client = http.Client();
    final reporting = AppReporting._(
        CompletedReportQueue(
            store: store,
            client: client,
            endpoint: Uri.parse(base).resolve('/api/seep/reports'),
            uploadKey: key),
        client);
    WidgetsBinding.instance.addObserver(reporting);
    reporting._resume();
    return reporting;
  }

  Future<void> enqueue(Map<String, dynamic> report) async {
    await queue.enqueue(report);
    unawaited(retry());
  }

  Future<void> retry() async {
    try {
      await queue.flush();
      lastError = null;
    } catch (error) {
      lastError = error;
    }
  }

  void _resume() {
    _timer?.cancel();
    unawaited(retry());
    _timer =
        Timer.periodic(const Duration(minutes: 1), (_) => unawaited(retry()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _timer?.cancel();
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    client.close();
  }
}
