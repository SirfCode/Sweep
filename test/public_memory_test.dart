import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/bot.dart';
import 'package:sweep/game/engine.dart';

SweepGame ariPosition() {
  final g = SweepGame.newGame(seed: 1).toJson();
  g.addAll({
    'dealer': 2,
    'turn': 2,
    'plays': 39,
    'call': 11,
    'phase': 'playing',
    'lastCapture': 0,
    'hands': [
      [24, 42],
      [2, 44],
      [18, 31, 21],
      [49, 47]
    ],
    'deck': <int>[],
    'loose': [22, 26],
    'houses': [
      House(9, [
        [32, 40]
      ], [
        2
      ]).toJson()
    ],
    'captured': [
      [
        10,
        23,
        17,
        5,
        41,
        16,
        3,
        25,
        12,
        45,
        6,
        46,
        33,
        7,
        20,
        37,
        19,
        30,
        29,
        14,
        28,
        1,
        0,
        11,
        8,
        15,
        36,
        13,
        34,
        39
      ],
      [51, 38, 50, 43, 4, 27, 48, 35, 9]
    ],
    'knownRanks': [
      <int>[],
      <int>[],
      [9],
      [11]
    ],
    'totals': [372, 378],
    'decisions': <Map<String, dynamic>>[],
  });
  return SweepGame.fromJson(g);
}

void main() {
  test('Ari avoids the known jack sweep across seeds and logs the reason', () {
    final g = ariPosition();
    for (var seed = 0; seed < 32; seed++) {
      final bot = SweepBot(seed);
      final move = bot.chooseMove(g.position);
      expect(move.kind, MoveKind.discard, reason: 'seed $seed');
      expect(rankOf(move.card), 6);
      expect(bot.lastAnalysis['reason'], contains('certain immediate sweep'));
      expect(bot.lastAnalysis['search'], 'bounded endgame minimax');
      final after = SweepGame.fromJson(g.toJson())
        ..play(move, botAnalysis: bot.lastAnalysis);
      expect(bot.sweepRisk(g.position, after), 0);
      expect(after.decisions.last['analysis'], bot.lastAnalysis);
      for (final reply in after.position.legalMoves()) {
        final next = SweepGame.fromJson(after.toJson())..play(reply);
        expect(next.sweeps[1], isEmpty);
      }
    }
  });

  test('every sampled Dev hand contains the publicly proved last jack', () {
    final g = ariPosition();
    for (var seed = 0; seed < 64; seed++) {
      final sampled = SweepBot(seed).sampleWorld(g.position)!;
      sampled.validate();
      expect(sampled.hands[3], contains(49));
      expect(sampled.knownRanks, g.knownRanks);
    }
  });

  test(
      'capturing a house retains its owners evidence until that rank is played',
      () {
    final g = ariPosition();
    g.play(
        g.position.legalMoves().firstWhere((m) => m.kind == MoveKind.discard));
    // Dev takes Ari's house. Ari still has the nine he publicly promised.
    g.play(g.position.legalMoves().firstWhere((m) => m.card == 47));
    expect(g.houses, isEmpty);
    expect(g.knownRanks[2], contains(9));
    expect(g.knownRanks[3], contains(11));
    final resumed = SweepGame.fromJson(g.toJson());
    expect(resumed.knownRanks, g.knownRanks);
    final bot = SweepBot(8);
    while (resumed.turn != 2) {
      resumed.play(bot.tacticalMove(resumed.position));
    }
    resumed.play(resumed.position.legalMoves().firstWhere((m) => m.card == 21));
    expect(resumed.knownRanks[2], isNot(contains(9)));
  });

  test('call evidence is consumed, not blindly retained for the whole deal',
      () {
    final g = ariPosition();
    g.play(
        g.position.legalMoves().firstWhere((m) => m.kind == MoveKind.capture));
    expect(SweepBot(1).sweepRisk(ariPosition().position, g), 1);
    g.play(g.position.legalMoves().firstWhere((m) => m.card == 49));
    expect(g.knownRanks[3], isEmpty);
    expect(g.score(1).earnedSweepPoints, 50);
  });

  test(
      'public memory is immutable and never asserts ranks absent from real hands',
      () {
    for (var seed = 0; seed < 12; seed++) {
      final g = SweepGame.newGame(seed: seed);
      final bot = SweepBot(seed);
      final caller = g.turn;
      final call = bot.chooseCall(g.position);
      g.call(call);
      expect(g.knownRanks[caller], contains(call));
      expect(
          () => g.position.knownRanks[caller].add(1), throwsUnsupportedError);
      while (g.phase != Phase.results) {
        for (var seat = 0; seat < 4; seat++) {
          expect(g.hands[seat].map(rankOf).toSet(),
              containsAll(g.knownRanks[seat]));
        }
        g.play(bot.tacticalMove(g.position));
      }
      expect(g.knownRanks.every((r) => r.isEmpty), isTrue);
      g.winner = null;
      g.continueGame();
      expect(g.knownRanks.every((r) => r.isEmpty), isTrue);
    }
  });

  test(
      'older saves recover only public action evidence, never diagnostic hands',
      () {
    final g = SweepGame.newGame(seed: 25);
    final bot = SweepBot(1);
    g.call(bot.chooseCall(g.position));
    for (var i = 0; i < 35; i++) {
      g.play(bot.tacticalMove(g.position));
    }
    final json = g.toJson()..remove('knownRanks');
    final restored = SweepGame.fromJson(json);
    expect(restored.knownRanks, g.knownRanks);
    for (final d in g.decisions) {
      d['hand'] = ['invented hidden information'];
    }
    expect(SweepGame.fromJson(json).knownRanks, restored.knownRanks);
    json.remove('decisions');
    expect(() => SweepGame.fromJson(json), returnsNormally);
  });
}
