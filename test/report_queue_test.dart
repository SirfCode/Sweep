import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/reporting/completed_report.dart';
import 'package:sweep/reporting/report_queue.dart';

class MemoryReportStore implements ReportStore {
  List<Map<String, dynamic>> entries = [];
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> read() async =>
      (jsonDecode(jsonEncode(entries)) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  @override
  Future<void> write(List<Map<String, dynamic>> value) async {
    if (fail) throw FileSystemException('Storage unavailable');
    entries = value;
  }
}

Map<String, dynamic> report([String id = 'game-one']) => {
      'user': {'email': 'player@example.com'},
      'clientGameId': id,
      'dealCount': 3,
      'humanTeam': 0,
      'winnerTeam': 0,
      'userWon': true,
      'team0Total': 152,
      'team1Total': 91,
      'summary': {
        'totals': [152, 91]
      },
    };
http.Response ack(int status) => http.Response(
    jsonEncode({'reportId': 'report-id', 'userId': 'user-id'}), status);

void main() {
  late MemoryReportStore store;
  var time = DateTime.utc(2026, 9, 19);
  CompletedReportQueue queue(
          FutureOr<http.Response> Function(http.Request) handler,
          {ReportStore? disk,
          Duration timeout = const Duration(seconds: 60)}) =>
      CompletedReportQueue(
          store: disk ?? store,
          client: MockClient((request) async => await handler(request)),
          endpoint: Uri.parse('https://seep.example.com/api/seep/reports'),
          uploadKey: 'upload-only-key',
          now: () => time,
          random: Random(42),
          timeout: timeout);
  setUp(() {
    store = MemoryReportStore();
    time = DateTime.utc(2026, 9, 19);
  });

  test('completed report rejects unfinished game, including a completed deal',
      () {
    final game = SweepGame.newGame(seed: 42)..phase = Phase.results;
    expect(
        () => completedGameReport(
            game: game,
            clientGameId: 'stable-id',
            email: 'p@example.com',
            appVersion: '0.10.0+10'),
        throwsStateError);
    game.winner = 0;
    game.totals = [152, 40];
    final payload = completedGameReport(
        game: game,
        clientGameId: 'stable-id',
        email: ' P@Example.com ',
        appVersion: '0.10.0+10');
    expect(payload['winnerTeam'], 0);
    expect(payload['userWon'], true);
    expect((payload['user'] as Map)['email'], 'p@example.com');
    expect(payload.containsKey('gameLog'), false);
  });

  test('Google uploads wait for the owning account and never persist tokens',
      () async {
    String? signedInSubject;
    final sent = <String>[];
    final uploader = CompletedReportQueue(
        store: store,
        client: MockClient((request) async {
          expect(request.headers.containsKey('X-API-Key'), false);
          expect(request.headers['Authorization'], 'Bearer fresh-token');
          sent.add((jsonDecode(request.body) as Map)['clientGameId'] as String);
          return ack(201);
        }),
        endpoint: Uri.parse('https://seep.example.com/api/seep/reports'),
        authorization: (payload) async =>
            (payload['user'] as Map)['googleSubject'] == signedInSubject &&
                    signedInSubject != null
                ? {'Authorization': 'Bearer fresh-token'}
                : null);
    await uploader.enqueue({
      ...report('a'),
      'user': {'email': 'a@gmail.com', 'googleSubject': 'a'}
    });
    await uploader.enqueue({
      ...report('b'),
      'user': {'email': 'b@gmail.com', 'googleSubject': 'b'}
    });
    expect((await uploader.flush()).sent, 0);
    signedInSubject = 'b';
    expect((await uploader.flush()).sent, 1);
    expect(sent, ['b']);
    expect(store.entries.single['report']['clientGameId'], 'a');
    expect(jsonEncode(store.entries).contains('fresh-token'), false);
    signedInSubject = 'a';
    expect((await uploader.flush()).sent, 1);
    expect(sent, ['b', 'a']);
  });

  test('expired authorization retains report and sign-in releases auth backoff',
      () async {
    var authorized = false;
    var rejected = false;
    final uploader = CompletedReportQueue(
        store: store,
        client: MockClient(
            (_) async => authorized ? ack(200) : http.Response('{}', 401)),
        endpoint: Uri.parse('https://seep.example.com/api/seep/reports'),
        authorization: (_) async => {'Authorization': 'Bearer token'},
        onUnauthorized: () => rejected = true);
    await uploader.enqueue(report());
    expect((await uploader.flush()).sent, 0);
    expect(rejected, true);
    authorized = true;
    expect((await uploader.flush()).sent, 0);
    await uploader.retryAfterSignIn();
    expect((await uploader.flush()).sent, 1);
  });

  test('enqueue is immutable, durable first, and deduplicated before network',
      () async {
    var calls = 0;
    final uploader = queue((request) {
      calls++;
      return ack(201);
    });
    final payload = report();
    await uploader.enqueue(payload);
    (payload['summary'] as Map)['totals'] = [999, 999];
    await uploader.enqueue(report());
    expect(calls, 0);
    expect(store.entries.length, 1);
    expect(store.entries.single['report']['summary']['totals'], [152, 91]);
    expect((await uploader.flush()).sent, 1);
    expect(store.entries, isEmpty);
  });

  test('offline retry survives queue recreation and duplicate 200 clears it',
      () async {
    final offline = queue((_) => throw const SocketException('offline'));
    await offline.enqueue(report());
    expect((await offline.flush()).pending, 1);
    final due = DateTime.parse(store.entries.single['nextAttemptAt']);
    expect(due.isAfter(time), true);
    var calls = 0;
    final restored = queue((request) {
      calls++;
      expect(request.headers['X-API-Key'] ?? request.headers['x-api-key'],
          'upload-only-key');
      expect(jsonDecode(request.body)['clientGameId'], 'game-one');
      return ack(200);
    });
    await restored.flush();
    expect(calls, 0);
    time = due.add(const Duration(seconds: 1));
    expect((await restored.flush()).sent, 1);
    expect(calls, 1);
  });

  test('overlapping flushes send once and preserve concurrent enqueues',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final uploader = queue((_) {
      calls++;
      started.complete();
      return response.future;
    });
    await uploader.enqueue(report('one'));
    final first = uploader.flush();
    final second = uploader.flush();
    await started.future;
    await uploader.enqueue(report('two'));
    response.complete(ack(201));
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(store.entries.single['report']['clientGameId'], 'two');
  });

  test('429 obeys Retry-After and permanent errors retain blocked reports',
      () async {
    final busy =
        queue((_) => http.Response('{}', 429, headers: {'retry-after': '120'}));
    await busy.enqueue(report());
    await busy.flush();
    expect(DateTime.parse(store.entries.single['nextAttemptAt']),
        time.add(const Duration(seconds: 120)));
    time = time.add(const Duration(seconds: 121));
    final invalid = queue((_) => http.Response('{}', 400));
    expect((await invalid.flush()).blocked, 1);
    expect(store.entries.length, 1);
  });

  test('unauthorized and malformed successes never discard reports', () async {
    var calls = 0;
    final unauthorized = queue((_) {
      calls++;
      return http.Response('{}', 401);
    });
    await unauthorized.enqueue(report('one'));
    await unauthorized.enqueue(report('two'));
    expect((await unauthorized.flush()).pending, 2);
    expect(calls, 1);
    time = time.add(const Duration(hours: 2));
    final malformed = queue((_) => http.Response('not-json', 200));
    expect((await malformed.flush()).pending, 2);
  });

  test('timeout retains the exact report for a later attempt', () async {
    final uploader = queue(
        (_) => Future.delayed(const Duration(milliseconds: 30), () => ack(201)),
        timeout: const Duration(milliseconds: 1));
    await uploader.enqueue(report());
    expect((await uploader.flush()).pending, 1);
    expect(store.entries.single['report']['clientGameId'], 'game-one');
  });

  test('offline retry preserves the winning game log across queue restart',
      () async {
    final payload = report()
      ..['gameLog'] = {
        'v': 1,
        'deals': [
          {
            'events': [
              ['call', 0, 11]
            ]
          }
        ]
      };
    final offline = queue((_) => throw const SocketException('Offline'));
    await offline.enqueue(payload);
    await offline.flush();
    time = time.add(const Duration(hours: 7));
    final restored = queue((request) {
      expect(jsonDecode(request.body), payload);
      return ack(201);
    });
    expect((await restored.flush()).sent, 1);
    expect(store.entries, isEmpty);
  });

  test('storage failure surfaces to caller without attempting upload',
      () async {
    store.fail = true;
    final uploader = queue((_) => throw StateError('Must not send'));
    await expectLater(
        uploader.enqueue(report()), throwsA(isA<FileSystemException>()));
    expect(store.entries, isEmpty);
  });

  test('native outbox survives a store restart and replacement writes',
      () async {
    final dir = await Directory.systemTemp.createTemp('seep-report-test-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/reports.json');
    final disk = FileReportStore(file);
    await disk.write([
      {'saved': 1}
    ]);
    await disk.write([
      {'saved': 2}
    ]);
    expect(await FileReportStore(file).read(), [
      {'saved': 2}
    ]);
    await file.writeAsString('broken');
    await expectLater(disk.read(), throwsFormatException);
    expect(await file.readAsString(), 'broken');
  });
}
