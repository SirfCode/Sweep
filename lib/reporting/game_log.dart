import 'dart:convert';
import '../game/engine.dart';

/// Local full-game journal, separate from bot simulations and UI diagnostics.
/// No network calls; the completed report decides whether to upload it.
class GameLog {
  final Map<String, dynamic> _data;
  GameLog.start(SweepGame game)
      : _data = {
          'v': 1,
          'seed': game.seed,
          'humanSeat': 0,
          'humanTeam': 0,
          'initialDealer': game.dealNumber == 1 ? game.dealer : null,
          'complete': game.dealNumber == 1 &&
              game.plays == 0 &&
              game.phase == Phase.call,
          'deals': <Map<String, dynamic>>[],
        } {
    _startDeal(game);
    record(game);
  }
  GameLog.restore(Map<String, dynamic> json)
      : _data = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  void _startDeal(SweepGame game) {
    // Includes remaining deck order because cards are dealt in stages.
    final state = Map<String, dynamic>.from(game.toJson())
      ..remove('decisions')
      ..['history'] = <String>[]
      ..remove('historyEvents');
    (_data['deals'] as List).add({
      'n': game.dealNumber,
      'dealer': game.dealer,
      'caller': (game.dealer + 1) % 4,
      'start': jsonDecode(jsonEncode(state)),
      'events': <dynamic>[],
      'lastPlay': game.plays,
      'call': game.calledValue,
    });
  }

  void record(SweepGame game, {Move? move}) {
    final deals = _data['deals'] as List;
    if ((deals.last as Map)['n'] != game.dealNumber) _startDeal(game);
    final deal = deals.last as Map;
    final events = deal['events'] as List;
    if (deal['call'] == null && game.calledValue != null) {
      deal['call'] = game.calledValue;
      events.add(['call', (game.dealer + 1) % 4, game.calledValue]);
    }
    if (game.plays > (deal['lastPlay'] as int)) {
      if (move == null || game.plays != (deal['lastPlay'] as int) + 1) {
        _data['complete'] = false;
      } else {
        events.add([
          'play',
          (game.turn + 3) % 4,
          move.kind.name,
          move.card,
          move.value,
          move.groups.map((g) => List<int>.of(g)).toList(),
          List<int>.of(move.houseIndexes),
          move.raisedIndex,
        ]);
      }
      deal['lastPlay'] = game.plays;
    }
    if (game.phase == Phase.results && deal['scores'] == null) {
      deal['scores'] = List<int>.of(game.lastScores);
      deal['totals'] = List<int>.of(game.totals);
      deal['cardPoints'] = [game.score(0).cardPoints, game.score(1).cardPoints];
      deal['seeps'] =
          game.sweeps.map((s) => s.map((v) => v.name).toList()).toList();
      events.add(['score', List<int>.of(game.lastScores)]);
    }
    _data['winnerTeam'] = game.winner;
    _data['totals'] = List<int>.of(game.totals);
  }

  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
}
