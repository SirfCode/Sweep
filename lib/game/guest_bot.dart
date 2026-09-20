// Guest strategy preserved from tag v0.5.0; uses the current rules engine.
import 'dart:math';
import 'engine.dart';

/// The policy cannot inspect a SweepGame: it receives an own-hand-only Position.
class GuestBot {
  final Random random;
  GuestBot(int seed) : random = Random(seed);
  int chooseCall(Position p) {
    final calls = p.calls;
    calls.sort((a, b) {
      int weight(int v) => p.hand.where((c) => rankOf(c) == v).length * 10 + v;
      return weight(b).compareTo(weight(a));
    });
    return calls.first;
  }

  Move chooseMove(Position p) {
    final moves = p.legalMoves();
    if (moves.isEmpty) {
      throw StateError('No legal moves for ${seatNames[p.seat]}.');
    }
    double weight(Move m) {
      final affected = p.affectedCards(m);
      final heldAfter = p.hand.where((c) => c != m.card).toList();
      var value = random.nextDouble() * 0.15;
      switch (m.kind) {
        case MoveKind.capture:
          value += pointsOf([m.card, ...affected]) * 4 + affected.length * 0.3;
          if (m.selectedLoose.length == p.loose.length &&
              m.houseIndexes.length == p.houses.length &&
              p.plays < 47) {
            value += p.plays == 0 ? 65 : 125;
          }
          // Prefer not to collect a partner's safe house for no points too early.
          if (p.hand.length > 4 &&
              m.houseIndexes
                  .any((i) => p.houses[i].owners.contains((p.seat + 2) % 4))) {
            value -= 3;
          }
        case MoveKind.build:
        case MoveKind.raise:
          value += 5 + pointsOf([m.card, ...affected]) * 1.5;
          if (p.resultingOwners(m).contains((p.seat + 2) % 4)) value += 5;
          if (m.raisedIndex != null &&
              p.houses[m.raisedIndex!].owners.any((s) => s % 2 != p.seat % 2)) {
            value += 6;
          }
          value += heldAfter.where((c) => rankOf(c) == m.value).length * 2;
        case MoveKind.discard:
          value -= cardOf(m.card).points * 3;
          if (heldAfter.any((c) => rankOf(c) == rankOf(m.card))) value += 1;
      }
      // Keeping the last high-value rank offers future capture/build flexibility.
      if (rankOf(m.card) >= 9 &&
          !heldAfter.any((c) => rankOf(c) == rankOf(m.card))) {
        value -= 1;
      }
      return value;
    }

    final ranked = moves.map((m) => (m, weight(m))).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked.first.$1;
  }
}
