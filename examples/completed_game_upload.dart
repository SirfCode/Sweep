// Native Android example. Nothing here is invoked by the game's current UI.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/reporting/completed_report.dart';
import 'package:sweep/reporting/report_queue.dart';

/// Instantiate only after the player opts in and supplies their email.
/// The upload key is NOT a user credential. Never put ADMIN_API_KEY or
/// DATABASE_URL in Flutter. See backend/README.md for the shared-key limits.
class ReportingExample with WidgetsBindingObserver {
  final CompletedReportQueue queue;
  final http.Client client;
  Timer? _timer;
  bool _stopped = false;
  Object? lastError;
  ReportFlushResult? lastResult;
  ReportingExample._(this.queue, this.client);

  static Future<ReportingExample> open() async {
    const base = String.fromEnvironment('SEEP_API_URL');
    const uploadKey = String.fromEnvironment('SEEP_UPLOAD_API_KEY');
    if (base.isEmpty || uploadKey.isEmpty) {
      throw StateError('Configure the API URL and upload key');
    }
    final client = http.Client();
    final queue = CompletedReportQueue(
        store: await FileReportStore.inAppDirectory(),
        client: client,
        endpoint: Uri.parse(base).resolve('/api/seep/reports'),
        uploadKey: uploadKey);
    final example = ReportingExample._(queue, client);
    WidgetsBinding.instance.addObserver(example);
    example._resume();
    return example;
  }

  /// Generate ONCE per full game. Persist alongside that game's saved state
  /// in the SAME save envelope, before play. Restore it when resuming.
  static String newGameId() => const Uuid().v4();

  /// Call after scoring produces game.winner != null, before clearing that save.
  /// If enqueue fails, retain the finished game so this call can be retried.
  Future<void> gameFinished(SweepGame game,
      {required String clientGameId,
      required String email,
      required String appVersion,
      String? displayName,
      Map<String, dynamic>? fullGameLog}) async {
    await queue.enqueue(completedGameReport(
        game: game,
        clientGameId: clientGameId,
        email: email,
        displayName: displayName,
        appVersion: appVersion,
        fullGameLog: fullGameLog));
    unawaited(retry());
  }

  Future<void> retry() async {
    if (_stopped) return;
    try {
      lastResult = await queue.flush();
      lastError = null;
    } catch (error) {
      lastError = error;
    } // Surface storage/config issues in settings.
  }

  void _resume() {
    if (_stopped) return;
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
    _stopped = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    client.close();
  }
}
