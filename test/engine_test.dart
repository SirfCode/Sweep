import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/game/bot.dart';
import 'fixtures.dart';

int c(int rank, [int suit = 0]) => suit * 13 + rank - 1;
Position position(List<int> hand, List<int> loose,
        {List<House> houses = const [],
        int seat = 0,
        Phase phase = Phase.playing,
        int? call}) =>
    Position(
        seat: seat,
        hand: hand,
        loose: loose,
        houses: houses,
        phase: phase,
        call: call,
        plays: 5);

void main() {
  test('two held tens can build a new pakka ten with a loose ten', () {
    for (final played in [22, 48]) {
      final game = twoTensGame();
      final moves =
          game.position.legalMoves().where((m) => m.card == played).toList();
      expect(moves.any((m) => m.kind == MoveKind.capture), isTrue);
      final build =
          moves.singleWhere((m) => m.kind == MoveKind.build && m.value == 10);
      game.play(build);
      game.validate();
      final house = game.houses.singleWhere((h) => h.value == 10);
      expect(house.pakka, isTrue);
      expect(house.groups, [
        [played],
        [9]
      ]);
      expect(house.owners, {0});
      expect(game.hands[0], contains(played == 22 ? 48 : 22));
      expect(game.loose, [17]);
      expect(game.houses.any((h) => h.value == 13 && h.owners.contains(1)),
          isTrue);
    }
  });
  test(
      'matching-rank new house absorbs loose combinations and obeys commitments',
      () {
    final p = position([c(10, 1), c(10, 3)], [c(10), c(6), c(4), c(5)]);
    final build = p.legalMoves().firstWhere((m) => m.kind == MoveKind.build);
    expect(build.selectedLoose, {c(10), c(6), c(4)});
    expect(
        position([c(10, 3)], [c(10)])
            .legalMoves()
            .any((m) => m.kind == MoveKind.build),
        isFalse);
    expect(
        position([c(10, 1), c(10, 3)], [])
            .legalMoves()
            .any((m) => m.kind == MoveKind.build),
        isFalse);
    expect(
        position([c(10, 1), c(10, 3)], [c(10)], phase: Phase.opening, call: 10)
            .legalMoves()
            .any((m) => m.kind == MoveKind.build),
        isTrue);
  });
  test('illegal moves cannot mutate a game', () {
    final g = SweepGame.newGame(seed: 9);
    final before = jsonEncode(g.toJson());
    expect(() => g.play(Move(MoveKind.discard, c(1), 1)), throwsStateError);
    expect(jsonEncode(g.toJson()), before);
  });
  test('opening sweep receives 25 and dealing completes afterwards', () {
    final g = SweepGame.newGame(seed: 11, dealer: 3);
    final hand = [c(9, 3), c(2), c(3), c(4)];
    final table = [c(9, 1), c(8), c(1, 2), c(9, 2)];
    final rest = [
      for (var i = 0; i < 52; i++)
        if (!hand.contains(i) && !table.contains(i)) i
    ];
    g.phase = Phase.opening;
    g.calledValue = 9;
    g.loose = table;
    g.hands = [
      hand,
      rest.sublist(0, 4),
      rest.sublist(4, 8),
      rest.sublist(8, 12)
    ];
    g.deck = rest.sublist(12);
    g.play(
        g.position.legalMoves().firstWhere((m) => m.kind == MoveKind.capture));
    g.validate();
    expect(g.score(0).earnedSweepPoints, 25);
    expect(g.loose, isEmpty);
    expect(g.plays, 1);
    expect(g.phase, Phase.playing);
    expect(g.hands.map((h) => h.length), [11, 12, 12, 12]);
  });
  test('intermediate sweep is provisional until card points reach 20', () {
    final g = SweepGame.newGame(seed: 11);
    final played = c(10, 3);
    final table = [c(6), c(4)];
    final rest = [
      for (var i = 0; i < 52; i++)
        if (i != played && !table.contains(i)) i
    ];
    g.turn = 0;
    g.phase = Phase.playing;
    g.plays = 20;
    g.hands = [
      [played],
      rest.sublist(0, 9),
      rest.sublist(9, 18),
      rest.sublist(18, 27)
    ];
    g.deck = [];
    g.loose = table;
    g.captured = [[], rest.sublist(27)];
    g.play(
        g.position.legalMoves().firstWhere((m) => m.kind == MoveKind.capture));
    g.validate();
    expect(g.score(0).cardPoints, 10);
    expect(g.score(0).earnedSweepPoints, 50);
    expect(g.score(0).eligibleSweepPoints, 0);
  });
  test('last capture receives leftovers without creating a sweep', () {
    final g = SweepGame.newGame(seed: 9);
    final played = c(13, 3);
    final left = c(2);
    g.phase = Phase.playing;
    g.turn = 0;
    g.plays = 47;
    g.deck = [];
    g.hands = [
      [played],
      [],
      [],
      []
    ];
    g.loose = [left];
    g.houses = [];
    g.lastCaptureTeam = 1;
    g.captured = [
      [],
      [
        for (var i = 0; i < 52; i++)
          if (i != played && i != left) i
      ]
    ];
    g.play(g.position.legalMoves().single);
    g.validate();
    expect(g.captured[1].length, 52);
    expect(g.score(1).cardPoints, 100);
    expect(g.score(1).earnedSweepPoints, 0);
  });
  test('final individual capture clears houses but gives no sweep bonus', () {
    final g = SweepGame.newGame(seed: 9);
    final played = c(10, 3);
    final table = [c(6), c(4)];
    g.phase = Phase.playing;
    g.turn = 0;
    g.plays = 47;
    g.deck = [];
    g.hands = [
      [played],
      [],
      [],
      []
    ];
    g.loose = [];
    g.houses = [
      House(10, [table], [0])
    ];
    g.captured = [
      [],
      [
        for (var i = 0; i < 52; i++)
          if (i != played && !table.contains(i)) i
      ]
    ];
    g.play(g.position.legalMoves().single);
    g.validate();
    expect(g.houses, isEmpty);
    expect(g.score(0).earnedSweepPoints, 0);
    expect(g.captured[0].toSet(), {played, ...table});
  });
  test('multiple complete games reach the winning margin only after scoring',
      () {
    for (var seed = 0; seed < 15; seed++) {
      var g = SweepGame.newGame(seed: seed);
      final bot = SweepBot(seed);
      var oldTotals = [0, 0];
      while (g.winner == null && g.dealNumber < 100) {
        while (g.phase != Phase.results) {
          if (g.phase == Phase.call) {
            g.call(bot.chooseCall(g.position));
          } else {
            g.play(bot.chooseMove(g.position));
          }
        }
        g.validate();
        expect(g.totals,
            [oldTotals[0] + g.lastScores[0], oldTotals[1] + g.lastScores[1]]);
        oldTotals = g.totals.toList();
        g = SweepGame.fromJson(
            jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
        if (g.winner == null) g.continueGame();
      }
      expect(g.winner, isNotNull);
      expect((g.totals[0] - g.totals[1]).abs(), greaterThanOrEqualTo(104));
      expect(g.phase, Phase.results);
    }
  });
  test('overlapping captures allow fewer cards and include remaining matches',
      () {
    final p = position([c(10, 3)], [c(6), c(4), c(3), c(3, 1), c(10)]);
    final moves =
        p.legalMoves().where((m) => m.kind == MoveKind.capture).toList();
    expect(moves.length, 2);
    expect(moves.map((m) => m.selectedLoose.length).toSet(), {3, 4});
    expect(moves.every((m) => m.selectedLoose.contains(c(10))), isTrue);
  });
  test(
      'all disjoint captures are mandatory; overlapping equal ranks are choices',
      () {
    final p = position([c(10, 3)], [c(10), c(6), c(4), c(7), c(3)]);
    final captures = p.legalMoves().where((m) => m.kind == MoveKind.capture);
    expect(captures.length, 1);
    expect(captures.single.selectedLoose.length, 5);
    final overlap = position([c(10, 3)], [c(6), c(4), c(4, 1)])
        .legalMoves()
        .where((m) => m.kind == MoveKind.capture)
        .toList();
    expect(overlap.length, 2);
    expect(overlap.every((m) => m.selectedLoose.length == 2), isTrue);
  });
  test('house is indivisible and cannot supplement a capture', () {
    final h = House(10, [
      [c(6), c(4)]
    ], [
      1
    ]);
    final p = position([c(12), c(10, 3)], [c(2)], houses: [h]);
    expect(
        p
            .legalMoves()
            .where((m) => m.card == c(12) && m.kind == MoveKind.capture),
        isEmpty);
    expect(
        p.legalMoves().any((m) =>
            m.card == c(10, 3) &&
            m.kind == MoveKind.capture &&
            m.houseIndexes.length == 1),
        isTrue);
  });
  test('a discard is card-specific, and legal builds can replace captures', () {
    final p = position([c(4), c(9), c(13)], [c(4, 1), c(5)]);
    final moves = p.legalMoves();
    expect(
        moves.any((m) => m.card == c(4) && m.kind == MoveKind.capture), isTrue);
    expect(
        moves.any(
            (m) => m.card == c(4) && m.kind == MoveKind.build && m.value == 9),
        isTrue);
    expect(moves.any((m) => m.card == c(4) && m.kind == MoveKind.discard),
        isFalse);
    expect(moves.any((m) => m.card == c(13) && m.kind == MoveKind.discard),
        isTrue);
  });
  test('opening move follows call and discards only as fallback', () {
    final p = position(
        [c(9), c(4), c(2), c(1)], [c(5), c(4, 1), c(2, 1), c(13)],
        phase: Phase.opening, call: 9);
    final moves = p.legalMoves();
    expect(
        moves.every((m) => m.value == 9 && m.kind != MoveKind.discard), isTrue);
    expect(moves.any((m) => m.kind == MoveKind.build), isTrue);
    expect(moves.any((m) => m.kind == MoveKind.capture), isTrue);
    final fallback = position(
        [c(9), c(4), c(2), c(1)], [c(13), c(13, 1), c(12), c(11)],
        phase: Phase.opening, call: 9);
    expect(fallback.legalMoves().single.kind, MoveKind.discard);
    expect(fallback.legalMoves().single.card, c(9));
  });
  test('partner can add their only matching card without a new commitment', () {
    final p = position([
      c(10, 3)
    ], [], houses: [
      House(10, [
        [c(6), c(4)]
      ], [
        2
      ])
    ]);
    final move = p.legalMoves().firstWhere((m) => m.kind == MoveKind.build);
    expect(p.resultingOwners(move), {2});
    final opponent = position([
      c(10, 3)
    ], [], houses: [
      House(10, [
        [c(6), c(4)]
      ], [
        1
      ])
    ]);
    expect(
        opponent.legalMoves().where((m) => m.kind == MoveKind.build), isEmpty);
  });
  test('own commitment cannot be passed off or spent on another purpose', () {
    final p = position([
      c(10, 3),
      c(13, 3)
    ], [
      c(3)
    ], houses: [
      House(10, [
        [c(6), c(4)]
      ], [
        0,
        2
      ])
    ]);
    final moves = p.legalMoves().where((m) => m.card == c(10, 3));
    expect(moves.every((m) => m.kind == MoveKind.capture), isTrue);
  });
  test(
      'raise uses only hand card, absorbs matches and inherits teammate commitment',
      () {
    final p = position([
      c(1)
    ], [
      c(11, 3),
      c(2)
    ], houses: [
      House(10, [
        [c(6), c(4)]
      ], [
        1
      ]),
      House(11, [
        [c(8), c(3)]
      ], [
        2
      ]),
    ]);
    final move = p.legalMoves().firstWhere((m) => m.kind == MoveKind.raise);
    expect(move.value, 11);
    expect(move.selectedLoose, {c(11, 3)});
    expect(p.resultingOwners(move), {2});
    expect(move.houseIndexes, [1]);
  });
  test('pakka cannot be raised and multiple commitments remain protected', () {
    final p = position([
      c(1),
      c(11),
      c(12)
    ], [], houses: [
      House(10, [
        [c(6), c(4)],
        [c(10, 1)]
      ], [
        1
      ]),
      House(11, [
        [c(8), c(3)]
      ], [
        0
      ]),
      House(12, [
        [c(7), c(5)]
      ], [
        0
      ]),
    ]);
    final moves = p.legalMoves();
    expect(moves.any((m) => m.kind == MoveKind.raise && m.raisedIndex == 0),
        isFalse);
    expect(
        moves
            .where((m) => m.card == c(11) || m.card == c(12))
            .every((m) => m.kind == MoveKind.capture),
        isTrue);
  });
  test('call hides table; initial and remaining dealing follow correct counts',
      () {
    final g = SweepGame.newGame(seed: 42, dealer: 3);
    expect(g.turn, 0);
    expect(g.hands.map((h) => h.length), [4, 0, 0, 0]);
    expect(g.position.loose, isEmpty);
    g.call(g.position.calls.first);
    expect(g.hands.map((h) => h.length), [4, 4, 4, 4]);
    g.play(g.position.legalMoves().first);
    expect(g.hands.map((h) => h.length), [11, 12, 12, 12]);
    expect(g.turn, 1);
    expect(g.deck, isEmpty);
    g.validate();
  });
  test('dealer rotation counts ties and swaps to partner on third loss', () {
    final g = SweepGame.newGame(seed: 42, dealer: 0);
    g.lastScores = [50, 50];
    g.dealerCount = 1;
    expect(g.nextDealer, (0, 2));
    g.dealerCount = 2;
    expect(g.nextDealer, (2, 0));
    g.lastScores = [80, 20];
    expect(g.nextDealer, (1, 0));
    g.lastScores = [20, 80];
    g.dealerCount = 0;
    expect(g.nextDealer, (0, 1));
  });
  test('randomized full deals conserve cards and all commitments', () {
    for (var seed = 0; seed < 80; seed++) {
      var game = SweepGame.newGame(seed: seed);
      final random = Random(seed);
      final bot = SweepBot(seed);
      while (game.phase != Phase.results) {
        game.validate();
        // Exercise saving and resuming at every phase and turn.
        if (game.plays % 7 == 0) {
          final encoded = jsonEncode(game.toJson());
          game =
              SweepGame.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
          expect(jsonEncode(game.toJson()), encoded);
        }
        if (game.phase == Phase.call) {
          game.call(bot.chooseCall(game.position));
        } else {
          final p = game.position;
          final moves = p.legalMoves();
          expect(moves, isNotEmpty, reason: 'seed $seed, play ${game.plays}');
          game.play(seed.isEven
              ? bot.chooseMove(p)
              : moves[random.nextInt(moves.length)]);
        }
      }
      game.validate();
      expect(game.plays, 48);
      expect(pointsOf(game.captured.expand((p) => p)), 100);
      expect(game.captured.expand((p) => p).length, 52);
      expect(game.totals, game.lastScores);
      if (game.winner == null) {
        final expectedDealer = game.nextDealer;
        game.continueGame();
        expect((game.dealer, game.dealerCount), expectedDealer);
        expect(game.dealNumber, 2);
        game.validate();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
