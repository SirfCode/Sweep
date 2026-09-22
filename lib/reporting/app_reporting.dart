import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'report_queue.dart';
import '../auth/google_session.dart';

/// Native Google-authenticated completed-game uploads. Guest play stays local.
class AppReporting with WidgetsBindingObserver {
  static const version =
      String.fromEnvironment('SEEP_APP_VERSION', defaultValue: '0.14.0+14');
  final CompletedReportQueue queue;
  final CompletedReportQueue snapshots;
  final http.Client client;
  Timer? _timer;
  Object? lastError;
  AppReporting._(this.queue, this.client, this.snapshots);

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
        client,
        CompletedReportQueue(
            store: FileReportStore(
                File('${store.file.parent.path}/seep_analysis_snapshots.json')),
            client: client,
            endpoint: Uri.parse(base).resolve('/api/seep/analysis-snapshots'),
            analysisSnapshots: true,
            authorization: session.headersFor,
            onUnauthorized: session.sessionRejected));
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
      if (afterSignIn) await snapshots.retryAfterSignIn();
      await snapshots.flush();
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
