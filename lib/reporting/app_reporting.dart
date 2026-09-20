import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'report_queue.dart';
import '../auth/google_session.dart';

/// Native Google-authenticated completed-game uploads. Guest play stays local.
class AppReporting with WidgetsBindingObserver {
  static const version =
      String.fromEnvironment('SEEP_APP_VERSION', defaultValue: '0.13.0+13');
  final CompletedReportQueue queue;
  final http.Client client;
  Timer? _timer;
  Object? lastError;
  AppReporting._(this.queue, this.client);

  static Future<AppReporting?> open(GoogleSession session) async {
    const base = GoogleSession.apiBase;
    if (kIsWeb || !session.supported) return null;
    final store = await FileReportStore.inAppDirectory();
    final client = http.Client();
    final reporting = AppReporting._(
        CompletedReportQueue(
            store: store,
            client: client,
            endpoint: Uri.parse(base).resolve('/api/seep/reports'),
            authorization: session.headersFor,
            onUnauthorized: session.sessionRejected),
        client);
    WidgetsBinding.instance.addObserver(reporting);
    reporting._resume();
    return reporting;
  }

  Future<void> enqueue(Map<String, dynamic> report) async {
    await queue.enqueue(report);
    unawaited(retry());
  }

  Future<void> retry({bool afterSignIn = false}) async {
    try {
      if (afterSignIn) await queue.retryAfterSignIn();
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
