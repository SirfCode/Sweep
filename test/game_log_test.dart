import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/game/guest_bot.dart';
import 'package:sweep/reporting/game_log.dart';
import 'package:sweep/reporting/completed_report.dart';

void main() {
  test('journal replays all deals and survives save/resume', () {
    var sawMultipleDeals = false;
    for (var seed = 1; seed <= 10; seed++) {
      var game = SweepGame.newGame(seed: seed, dealer: 3);
      var log = GameLog.start(game);
      final bot = GuestBot(42);
      var resumed = false;
      while (game.winner == null) {
        if (game.phase == Phase.results) {
          game.continueGame();
          log.record(game);
        }
        if (game.phase == Phase.call) {
          game.call(bot.chooseCall(game.position));
          log.record(game);
        }
        final move = bot.chooseMove(game.position);
        game.play(move);
        log.record(game, move: move);
        if (!resumed && game.plays == 20) {
          game = SweepGame.fromJson(jsonDecode(jsonEncode(game.toJson())));
          log = GameLog.restore(jsonDecode(jsonEncode(log.toJson())));
          resumed = true;
        }
      }
      final data = log.toJson();
      expect(data['complete'], true);
      expect(data['deals'].length, game.dealNumber);
      sawMultipleDeals |= game.dealNumber > 1;
      for (final deal in data['deals']) {
        final replay =
            SweepGame.fromJson(Map<String, dynamic>.from(deal['start']));
        var plays = 0;
        for (final event in deal['events']) {
          if (event[0] == 'call') replay.call(event[2] as int);
          if (event[0] == 'play') {
            expect(replay.turn, event[1]);
            replay.play(Move(
                MoveKind.values.byName(event[2]), event[3], event[4],
                groups: (event[5] as List).map((g) => List<int>.from(g)),
                houseIndexes: List<int>.from(event[6]),
                raisedIndex: event[7]));
            plays++;
          }
        }
        expect(plays, 48);
        expect(replay.phase, Phase.results);
        expect(replay.lastScores, deal['scores']);
        expect(replay.totals, deal['totals']);
      }
      expect(data['totals'], game.totals);
      expect(data['winnerTeam'], game.winner);
    }
    expect(sawMultipleDeals, true);
  });

  test('legacy saves explicitly mark unavailable earlier history', () {
    final game = SweepGame.newGame(seed: 4);
    game.call(game.position.calls.first);
    final log = GameLog.start(game);
    expect(log.toJson()['complete'], false);
  });

  test('only full human wins include detailed logs', () {
    final game = SweepGame.newGame(seed: 4)..phase = Phase.results;
    Map<String, dynamic> report() => completedGameReport(
        game: game,
        clientGameId: 'test',
        email: 'p@example.com',
        appVersion: 'test',
        fullGameLog: {'complete': true});
    expect(report, throwsStateError);
    game.winner = 0;
    expect(report()['gameLog'], {'complete': true});
    game.winner = 1;
    expect(report().containsKey('gameLog'), false);
  });
}
