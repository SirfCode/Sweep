import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/game/bot.dart';

void main() {
  test('decision records persist and unlock only after the deal', () {
    final g = SweepGame.newGame(seed: 25);
    final bot = SweepBot(1);
    g.call(bot.chooseCall(g.position));
    final original = [...g.position.hand];
    g.play(bot.tacticalMove(g.position));
    expect(g.decisions.length, 2);
    expect(g.decisions.last['hand'], original.map(cardName).toList());
    expect(g.reviewableDecisions, isEmpty);
    final resumed = SweepGame.fromJson(g.toJson());
    expect(resumed.decisions, g.decisions);
    while (resumed.phase != Phase.results) {
      resumed.play(bot.tacticalMove(resumed.position));
    }
    expect(resumed.reviewableDecisions.length, 49);
    final oldSave = g.toJson()..remove('decisions');
    expect(SweepGame.fromJson(oldSave).decisions, isEmpty);
    final sample = bot.sampleWorld(g.position)!;
    sample.play(bot.tacticalMove(sample.position), recordDiagnostic: false);
    expect(sample.decisions, isEmpty);
  });
  test('an exposed eleven house is a sweep threat even outside sampled hands',
      () {
    final house = House(11, [
      [26, 21, 0]
    ], [
      0
    ]);
    final before = Position(
        seat: 1,
        hand: [38, 3],
        loose: [],
        houses: [house],
        phase: Phase.playing,
        call: 13,
        plays: 8,
        handCounts: [10, 10, 10, 10]);
    final after = SweepGame.newGame(seed: 3)
      ..phase = Phase.playing
      ..turn = 2
      ..plays = 9
      ..loose = []
      ..houses = [house];
    final bot = SweepBot(0);
    expect(bot.sweepRisk(before, after), greaterThan(.5));
    // A loose king alongside an eleven house prevents a one-card clearance.
    after.loose = [12];
    expect(bot.sweepRisk(before, after), 0);
    after.loose = [];
    after.plays = 47;
    expect(bot.sweepRisk(before, after), 0); // Final clear earns no bonus.
  });
  test('king capture takes seven of spades instead of a non-scoring seven', () {
    // K-spade + 6-spade + 7-club gives 19 points; choosing 7-spade gives 26.
    // Both choices leave exactly the same table ranks, but different points.
    final p = Position(
        seat: 1,
        hand: [51, 0, 1, 2],
        loose: [44, 6, 45, 8],
        houses: [],
        phase: Phase.opening,
        call: 13,
        plays: 0,
        dealer: 0,
        handCounts: [4, 4, 4, 4]);
    expect(p.legalMoves().where((m) => m.kind == MoveKind.capture).length, 2);
    for (var seed = 0; seed < 64; seed++) {
      final move = SweepBot(seed).chooseMove(p);
      expect(move.kind, MoveKind.capture);
      expect(move.selectedLoose, contains(45), reason: 'seed $seed');
      expect(pointsOf([move.card, ...p.affectedCards(move)]), 26);
    }
  });
  test('sampled worlds conserve cards and public commitments throughout a deal',
      () {
    final g = SweepGame.newGame(seed: 127, dealer: 3);
    final bot = SweepBot(12);
    g.call(bot.chooseCall(g.position));
    while (g.phase != Phase.results) {
      final p = g.position;
      final sample = bot.sampleWorld(p)!;
      sample.validate();
      expect(sample.hands[p.seat], p.hand);
      expect(sample.captured, p.captured);
      expect(sample.hands.map((h) => h.length), p.handCounts);
      final move = bot.chooseMove(p);
      expect(p.legalMoves().any((m) => m.key == move.key), isTrue);
      g.play(move);
    }
  });
  test('hidden hand swaps do not change a seeded bot decision', () {
    final g = SweepGame.newGame(seed: 63, dealer: 3);
    final bot = SweepBot(4);
    g.call(bot.chooseCall(g.position));
    g.play(bot.tacticalMove(g.position));
    final p = g.position;
    final other = [
      for (var s = 0; s < 4; s++)
        if (s != g.turn) s
    ];
    final card = g.hands[other[0]][0];
    g.hands[other[0]][0] = g.hands[other[1]][0];
    g.hands[other[1]][0] = card;
    expect(SweepBot(77).chooseMove(p).key,
        SweepBot(77).chooseMove(g.position).key);
  });
  test('public memory survives save and resume', () {
    final g = SweepGame.newGame(seed: 21);
    final bot = SweepBot(9);
    g.call(bot.chooseCall(g.position));
    for (var i = 0; i < 12; i++) {
      g.play(bot.tacticalMove(g.position));
    }
    final resumed = SweepGame.fromJson(g.toJson());
    expect(resumed.position.captured, g.position.captured);
    expect(SweepBot(99).chooseMove(resumed.position).key,
        SweepBot(99).chooseMove(g.position).key);
  });
}
