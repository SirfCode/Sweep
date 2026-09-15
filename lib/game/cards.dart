enum Suit { clubs, diamonds, hearts, spades }

/// Rank controls moves; points control deal scoring.
class PlayingCard {
  final Suit suit;
  final int rank;

  PlayingCard(this.suit, this.rank) {
    if (rank < 1 || rank > 13) {
      throw RangeError.range(rank, 1, 13, 'rank');
    }
  }

  String get id => '${suit.name}-$rank';

  int get points {
    if (suit == Suit.spades) return rank;
    if (rank == 1) return 1;
    if (suit == Suit.diamonds && rank == 10) return 6;
    return 0;
  }

  static List<PlayingCard> standardDeck() => [
        for (final suit in Suit.values)
          for (var rank = 1; rank <= 13; rank++) PlayingCard(suit, rank),
      ];
}
