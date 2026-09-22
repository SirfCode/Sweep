import 'package:sweep/game/engine.dart';

/// Human holds A clubs, 10 diamonds and 10 spades; the table has a loose
/// 10 clubs, 5 diamonds, and Plato's unrelated pakka house of 13.
SweepGame twoTensGame() {
  final game = SweepGame.newGame(seed: 42, dealer: 3);
  game.phase = Phase.playing;
  game.turn = 0;
  game.plays = 39;
  game.calledValue = 13;
  game.deck = [];
  game.hands = [
    [0, 22, 48],
    [38, 3],
    [4, 5],
    [6, 7]
  ];
  game.loose = [9, 17];
  game.houses = [
    House(13, [
      [13, 37],
      [23, 1]
    ], {
      1
    })
  ];
  final inPlay = {
    ...game.hands.expand((h) => h),
    ...game.loose,
    ...game.houses.expand((h) => h.cards)
  };
  game.captured = [
    [
      for (var c = 0; c < 52; c++)
        if (!inPlay.contains(c)) c
    ],
    []
  ];
  game.validate();
  return game;
}
