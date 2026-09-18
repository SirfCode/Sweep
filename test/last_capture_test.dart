import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/bot.dart';
import 'package:sweep/game/engine.dart';

void main() {
  test('latest captures replace per player, survive saves, and reset each deal',
      () {
    final game = SweepGame.newGame(seed: 42);
    final bot = SweepBot(42);
    game.call(bot.chooseCall(game.position));
    var captures = 0;
    while (game.phase != Phase.results) {
      final actor = game.turn;
      final before = game.lastCaptures.map((c) => c?.toJson()).toList();
      final move = bot.tacticalMove(game.position);
      final expectedCards = [move.card, ...game.position.affectedCards(move)];
      final turn = game.plays + 1;
      game.play(move);
      if (move.kind == MoveKind.capture) {
        captures++;
        expect(game.lastCaptures[actor]!.cards, expectedCards);
        expect(game.lastCaptures[actor]!.turn, turn);
        if (turn == 48) expect(game.lastCaptures[actor]!.sweepPoints, 0);
      } else {
        expect(game.lastCaptures[actor]?.toJson(), before[actor]);
      }
      for (var seat = 0; seat < 4; seat++) {
        if (seat != actor) {
          expect(game.lastCaptures[seat]?.toJson(), before[seat]);
        }
      }
      final json = game.toJson();
      expect(SweepGame.fromJson(json).lastCaptures.map((c) => c?.toJson()),
          game.lastCaptures.map((c) => c?.toJson()));
      // The migration uses public targets only and produces the same snapshot.
      json.remove('lastCaptures');
      expect(SweepGame.fromJson(json).lastCaptures.map((c) => c?.toJson()),
          game.lastCaptures.map((c) => c?.toJson()));
    }
    expect(captures, greaterThan(4));
    game.winner = null;
    game.continueGame();
    expect(game.lastCaptures, everyElement(isNull));
    final old = game.toJson()
      ..remove('lastCaptures')
      ..remove('decisions');
    expect(SweepGame.fromJson(old).lastCaptures, everyElement(isNull));
  });
}
