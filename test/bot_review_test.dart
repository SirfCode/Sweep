import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/bot.dart';
import 'package:sweep/game/engine.dart';
import 'public_memory_test.dart' show ariPosition;

void main() {
  Position withKnowledge(Position p, List<List<int>> ranks) => Position(
      seat: p.seat,
      hand: p.hand,
      loose: p.loose,
      houses: p.houses,
      phase: p.phase,
      call: p.call,
      plays: p.plays,
      captured: p.captured,
      handCounts: p.handCounts,
      knownRanks: ranks);

  test('a partner owns the last jack: opponent sweep risk is zero', () {
    final g = ariPosition();
    final before = g.position;
    g.play(before.legalMoves().firstWhere((m) => m.kind == MoveKind.capture));
    final bot = SweepBot(1);
    expect(
        bot.sweepRisk(
            withKnowledge(before, [
              [],
              [],
              [9],
              []
            ]),
            g),
        closeTo(1 / 3, .000001));
    expect(
        bot.sweepRisk(
            withKnowledge(before, [
              [11],
              [],
              [9],
              []
            ]),
            g),
        0);
    expect(bot.sweepRisk(before, g), 1);
  });

  test(
      'a known safe rank fills an opponent slot instead of another random draw',
      () {
    final g = ariPosition();
    final before = g.position;
    g.play(before.legalMoves().firstWhere((m) => m.kind == MoveKind.capture));
    expect(
        SweepBot(1).sweepRisk(
            withKnowledge(before, [
              [],
              [],
              [9],
              [9]
            ]),
            g),
        closeTo(1 / 5, .000001));
  });

  test('no sweep penalty when even all available points cannot reach twenty',
      () {
    // Opponents can clear 10+A with a known jack, but all remaining points
    // outside our hand and our capture pile total just one.
    final before = Position(
        seat: 0,
        hand: [18],
        loose: [9, 0],
        houses: [],
        phase: Phase.playing,
        call: 11,
        plays: 43,
        handCounts: [1, 1, 1, 1],
        knownRanks: [
          [],
          [11],
          [],
          []
        ],
        captured: [
          [
            for (var c = 0; c < 52; c++)
              if (![18, 9, 0, 10, 2, 3].contains(c)) c
          ],
          []
        ]);
    final after = SweepGame.newGame(seed: 1)
      ..phase = Phase.playing
      ..plays = 44
      ..turn = 1
      ..loose = [9, 0]
      ..houses = []
      ..captured = before.captured.map((c) => c.toList()).toList();
    expect(SweepBot(1).sweepRisk(before, after), 0);
    // At 20 captured card points the same known jack is a real bonus threat.
    after.captured[1] = [51, 45];
    expect(SweepBot(1).sweepRisk(before, after), 1);
  });

  test('forced choices still produce an explanation', () {
    final p = Position(
        seat: 0,
        hand: [0],
        loose: [13],
        houses: [],
        phase: Phase.playing,
        call: 9,
        plays: 47);
    final bot = SweepBot(1);
    final move = bot.chooseMove(p);
    expect(move.kind, MoveKind.capture);
    expect(bot.lastAnalysis['chosen'], move.key);
    expect(bot.lastAnalysis['reason'], contains('Only one'));
  });
}
