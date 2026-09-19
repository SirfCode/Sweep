import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

abstract interface class ReportStore {
  Future<List<Map<String, dynamic>>> read();
  Future<void> write(List<Map<String, dynamic>> entries);
}

/// Android/native storage: flush to a temporary file, then atomically replace.
/// A corrupted file is reported to the caller, never silently discarded.
class FileReportStore implements ReportStore {
  final File file;
  FileReportStore(this.file);
  static Future<FileReportStore> inAppDirectory() async {
    final directory = await getApplicationSupportDirectory();
    return FileReportStore(
        File('${directory.path}/seep_completed_reports.json'));
  }

  @override
  Future<List<Map<String, dynamic>>> read() async {
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> write(List<Map<String, dynamic>> entries) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(entries), flush: true);
    await temporary.rename(file.path);
  }
}

class ReportFlushResult {
  final int sent, pending, blocked;
  const ReportFlushResult(this.sent, this.pending, this.blocked);
}

/// One instance per application/isolate. No background service or live sync.
/// Persist enqueue() before resetting the finished game. Call flush() on launch,
/// resume, and periodically while foregrounded. No connectivity plugin needed:
/// an actual HTTP request determines whether the server is reachable.
class CompletedReportQueue {
  final ReportStore store;
  final http.Client client;
  final Uri endpoint;
  final String uploadKey;
  final void Function()? onUnauthorized;
  final Future<Map<String, String>?> Function(Map<String, dynamic>)?
      authorization;
  final DateTime Function() now;
  final Random random;
  final Duration timeout;
  Future<void>? _storageTail;
  Future<ReportFlushResult>? _inFlight;

  CompletedReportQueue(
      {required this.store,
      required this.client,
      required this.endpoint,
      this.uploadKey = '',
      this.onUnauthorized,
      this.authorization,
      DateTime Function()? now,
      Random? random,
      this.timeout = const Duration(seconds: 60)})
      : now = now ?? DateTime.now,
        random = random ?? Random() {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw ArgumentError(
          'Use an HTTPS API endpoint without credentials or query parameters');
    }
    if (uploadKey.isEmpty && authorization == null) {
      throw ArgumentError('Authorization is required');
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = (_storageTail ?? Future<void>.value()).then((_) => action());
    _storageTail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// The same email/game ID is stored only once; retain this ID across retries.
  Future<void> enqueue(Map<String, dynamic> report) => _serial(() async {
        final user = report['user'];
        final email = user is Map ? user['email'] : null;
        if (email is! String ||
            !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email.trim()) ||
            report['clientGameId'] is! String ||
            (report['clientGameId'] as String).trim().isEmpty ||
            ![0, 1].contains(report['winnerTeam']) ||
            report['dealCount'] is! int ||
            (report['dealCount'] as int) < 1) {
          throw ArgumentError(
              'A completed-game report, stable game ID and email are required');
        }
        final encoded = jsonEncode(report);
        if (utf8.encode(encoded).length > 2 * 1024 * 1024) {
          throw ArgumentError(
              'Report exceeds 2 MiB; omit or compact the optional game log');
        }
        final snapshot = jsonDecode(encoded) as Map<String, dynamic>;
        (snapshot['user'] as Map)['email'] = email.trim().toLowerCase();
        final key = '${email.trim().toLowerCase()}\n${report['clientGameId']}';
        final entries = await store.read();
        if (entries.any((e) => e['key'] == key)) return;
        // Bounded storage without silently deleting old unsent reports.
        if (entries.length >= 50) {
          throw StateError(
              'Report outbox is full; retain the completed game and retry later');
        }
        entries.add({
          'key': key,
          'report': snapshot,
          'attempts': 0,
          'nextAttemptAt': now().toUtc().toIso8601String(),
          'blocked': false
        });
        await store.write(entries);
      });

  Future<ReportFlushResult> flush() =>
      _inFlight ??= _flush().whenComplete(() => _inFlight = null);

  Future<void> retryAfterSignIn() => _serial(() async {
        final entries = await store.read();
        for (final entry in entries) {
          if (entry['lastStatus'] == 401 || entry['lastStatus'] == 403) {
            entry['nextAttemptAt'] = now().toUtc().toIso8601String();
          }
        }
        await store.write(entries);
      });

  Future<ReportFlushResult> _flush() async {
    var sent = 0;
    final batch = await _serial(store.read);
    for (final item in batch) {
      if (item['blocked'] == true ||
          DateTime.parse(item['nextAttemptAt'] as String).isAfter(now())) {
        continue;
      }
      int? status;
      int? retryAfterSeconds;
      var acknowledged = false;
      try {
        final headers = authorization != null
            ? await authorization!(
                Map<String, dynamic>.from(item['report'] as Map))
            : <String, String>{'X-API-Key': uploadKey};
        // Signed out, expired session, or another user's queued report: retain it.
        if (headers == null) continue;
        final response = await client
            .post(endpoint,
                headers: {'Content-Type': 'application/json', ...headers},
                body: jsonEncode(item['report']))
            .timeout(timeout);
        status = response.statusCode;
        if (status == 401) onUnauthorized?.call();
        retryAfterSeconds = int.tryParse(response.headers['retry-after'] ?? '');
        if (status == 200 || status == 201) {
          final body = jsonDecode(response.body);
          acknowledged = body is Map &&
              body['reportId'] is String &&
              body['userId'] is String;
        }
      } catch (_) {
        /* Offline/timeout/malformed response: keep report for retry. */
      }
      await _serial(() async {
        final entries =
            await store.read(); // Preserve reports added during HTTP.
        final index = entries.indexWhere((e) => e['key'] == item['key']);
        if (index == -1) return;
        if (acknowledged) {
          entries.removeAt(index);
          sent++;
        } else {
          final entry = entries[index];
          final attempts = (entry['attempts'] as int) + 1;
          final delay = retryAfterSeconds?.clamp(5, 21600) ??
              (min(21600, 5 * pow(2, min(attempts - 1, 13))) *
                      (.8 + random.nextDouble() * .4))
                  .round()
                  .clamp(5, 21600);
          entry['attempts'] = attempts;
          entry['lastStatus'] = status;
          // Invalid/oversized reports need inspection, not endless retries.
          entry['blocked'] = [400, 404, 413, 415, 422].contains(status);
          entry['nextAttemptAt'] = now()
              .add(Duration(
                  seconds: status == 401 || status == 403 ? 3600 : delay))
              .toUtc()
              .toIso8601String();
        }
        await store.write(entries);
      });
      if (status == 401 ||
          status == 403 ||
          status == 429 ||
          status == null ||
          status >= 500) {
        break;
      }
    }
    final remaining = await _serial(store.read);
    return ReportFlushResult(sent, remaining.length,
        remaining.where((e) => e['blocked'] == true).length);
  }
}
