enum SweepTiming { opening, intermediate, finalPlay }

int sweepBonus(SweepTiming timing) => switch (timing) {
      SweepTiming.opening => 25,
      SweepTiming.intermediate => 50,
      SweepTiming.finalPlay => 0,
    };

class DealScore {
  final int cardPoints;
  final List<SweepTiming> sweeps;

  DealScore({required this.cardPoints, required List<SweepTiming> sweeps})
      : sweeps = List.unmodifiable(sweeps) {
    if (cardPoints < 0 || cardPoints > 100) {
      throw RangeError.range(cardPoints, 0, 100, 'cardPoints');
    }
  }

  int get earnedSweepPoints =>
      sweeps.fold(0, (total, timing) => total + sweepBonus(timing));
  int get eligibleSweepPoints => cardPoints >= 20 ? earnedSweepPoints : 0;
  int get total => cardPoints + eligibleSweepPoints;
}

/// Call only after the entire deal has been scored.
int? winningTeamAfterDeal(int teamZeroTotal, int teamOneTotal) {
  final margin = teamZeroTotal - teamOneTotal;
  if (margin >= 104) return 0;
  if (margin <= -104) return 1;
  return null;
}
