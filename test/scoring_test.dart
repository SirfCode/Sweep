import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/cards.dart';
import 'package:sweep/game/scoring.dart';

void main() {
  test('standard deck has 52 unique cards worth 100 points', () {
    final deck = PlayingCard.standardDeck();
    expect(deck.length, 52);
    expect(deck.map((card) => card.id).toSet().length, 52);
    expect(deck.fold<int>(0, (sum, card) => sum + card.points), 100);
    expect(PlayingCard(Suit.spades, 1).points, 1);
    expect(PlayingCard(Suit.diamonds, 10).points, 6);
  });

  test('sweep eligibility begins at exactly 20 card points', () {
    expect(DealScore(cardPoints: 19, sweeps: [SweepTiming.intermediate]).total,
        19);
    expect(DealScore(cardPoints: 20, sweeps: [SweepTiming.intermediate]).total,
        70);
    expect(
        DealScore(
            cardPoints: 15,
            sweeps: [SweepTiming.intermediate, SweepTiming.intermediate]).total,
        15);
  });

  test('opening and final captures use their special sweep bonuses', () {
    expect(
        DealScore(cardPoints: 35, sweeps: [
          SweepTiming.opening,
          SweepTiming.intermediate,
          SweepTiming.finalPlay,
        ]).total,
        110);
  });

  test('game requires a completed-deal lead of at least 104', () {
    expect(winningTeamAfterDeal(203, 100), isNull);
    expect(winningTeamAfterDeal(204, 100), 0);
    expect(winningTeamAfterDeal(100, 204), 1);
    expect(winningTeamAfterDeal(204, 204), isNull);
  });
}
