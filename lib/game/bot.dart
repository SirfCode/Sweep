import 'dart:math';
import 'engine.dart';

/// Receives only its own hand and public information; simulated games are guesses.
class SweepBot {
  final Random random;
  SweepBot(int seed) : random = Random(seed);
  Map<String, dynamic> lastAnalysis = {};

  List<Move> _choices(Position p) {
    final moves = p.legalMoves();
    final bestPoints = <String, int>{};
    String equivalent(Move m) {
      final ranks = m.selectedLoose.map(rankOf).toList()..sort();
      final houses = [...m.houseIndexes]..sort();
      return '${m.card}/${ranks.join(',')}/${houses.join(',')}';
    }

    for (final m in moves.where((m) => m.kind == MoveKind.capture)) {
      final key = equivalent(m);
      final points = pointsOf(p.affectedCards(m));
      bestPoints[key] = max(bestPoints[key] ?? -1, points);
    }
    // Equal-rank substitutions leave the same capture/build possibilities.
    // Secure the higher-value suits now instead of betting on sampled replies.
    // Keep alternatives with different ranks or houses for strategic search.
    return moves
        .where((m) =>
            m.kind != MoveKind.capture ||
            pointsOf(p.affectedCards(m)) == bestPoints[equivalent(m)])
        .toList();
  }

  /// Common sampled worlds let every candidate face the same unseen cards.
  /// Only public information and this player's hand enter these simulations.
  Move chooseMove(Position p) {
    lastAnalysis = {};
    final moves = _choices(p);
    if (moves.length <= 1 || p.handCounts.length != 4) return tacticalMove(p);
    final worlds = <Map<String, dynamic>>[];
    for (var i = 0; i < 4; i++) {
      final world = sampleWorld(p);
      if (world != null) worlds.add(world.toJson());
    }
    if (worlds.isEmpty) return tacticalMove(p);
    final risks = <String, double>{};
    for (final move in moves) {
      final after = SweepGame.fromJson(worlds.first)
        ..play(move, recordDiagnostic: false);
      risks[move.key] = sweepRisk(p, after);
    }
    // Include the tactical favourite and a range of capture/build/discard
    // choices without letting a large combination table explode the search.
    final favourite = tacticalMove(p);
    final ranked = [...moves]
      ..sort((a, b) => _priority(p, b).compareTo(_priority(p, a)));
    final candidates = <Move>[favourite];
    final safest = [...moves]
      ..sort((a, b) => risks[a.key]!.compareTo(risks[b.key]!));
    if (safest.first.key != favourite.key) candidates.add(safest.first);
    for (final kind in MoveKind.values) {
      final options = ranked.where((m) => m.kind == kind);
      if (options.isNotEmpty &&
          !candidates.any((m) => m.key == options.first.key)) {
        candidates.add(options.first);
      }
    }
    for (final move in ranked) {
      if (candidates.length >= 7) break;
      if (!candidates.any((m) => m.key == move.key)) candidates.add(move);
    }
    // Do not trade a safe table for a publicly certain opponent sweep.
    // Uncertain threats still participate in expected-score evaluation.
    final canAvoid = risks.values.any((r) => r == 0);
    if (canAvoid) candidates.removeWhere((m) => risks[m.key] == 1);
    final evaluations = <Map<String, dynamic>>[];
    var best = favourite;
    var bestValue = -double.infinity;
    final team = p.seat % 2;
    for (final move in candidates) {
      final outcomes = <double>[];
      for (final json in worlds) {
        final game = SweepGame.fromJson(json);
        game.play(move, recordDiagnostic: false);
        // Explore endgame replies through scoring and last-capture leftovers.
        if (p.plays >= 38) {
          outcomes.add(
              _endgame(game, team, [160], -double.infinity, double.infinity));
          continue;
        }
        const horizon = 4;
        final policy = SweepBot(0);
        for (var ply = 1; ply < horizon && game.phase != Phase.results; ply++) {
          game.play(policy.tacticalMove(game.position),
              recordDiagnostic: false);
        }
        outcomes.add(_evaluate(game, team));
      }
      final mean = outcomes.reduce((a, b) => a + b) / outcomes.length;
      final worst = outcomes.reduce(min);
      // Protect a substantial match lead; when behind, prefer expected gain.
      final protecting = p.totals[team] - p.totals[1 - team] > 50;
      final value = mean * (protecting ? .8 : .95) +
          worst * (protecting ? .2 : .05) -
          50 * risks[move.key]!;
      evaluations.add({
        'move': move.key,
        'sweepRisk': risks[move.key],
        'expectedMargin': mean,
        'worstMargin': worst,
        'value': value
      });
      if (value > bestValue) {
        bestValue = value;
        best = move;
      }
    }
    lastAnalysis = {
      'knownRanks': p.knownRanks.map((r) => r.toList()).toList(),
      'chosen': best.key,
      'reason': canAvoid && risks.values.any((r) => r == 1)
          ? 'Avoided a certain immediate sweep; a safe alternative exists.'
          : 'Best evaluated team score after opponent and partner replies.',
      'search': p.plays >= 38 ? 'bounded endgame minimax' : 'four-ply rollout',
      'excludedCertainSweeps': canAvoid
          ? moves.where((m) => risks[m.key] == 1).map((m) => m.key).toList()
          : <String>[],
      'candidates': evaluations,
    };
    return best;
  }

  /// Adversarial team search in a guessed world, never the actual hidden hands.
  /// A shared node budget bounds mobile latency; exhausted branches roll out
  /// to deal scoring so last capture, sweep eligibility and leftovers count.
  double _endgame(
      SweepGame game, int team, List<int> budget, double alpha, double beta) {
    if (game.phase == Phase.results) return _evaluate(game, team);
    if (budget[0]-- <= 0) {
      final policy = SweepBot(0);
      while (game.phase != Phase.results) {
        game.play(policy.tacticalMove(game.position), recordDiagnostic: false);
      }
      return _evaluate(game, team);
    }
    final maximizing = game.turn % 2 == team;
    final p = game.position;
    final moves = _choices(p)
      ..sort((a, b) => _priority(p, b).compareTo(_priority(p, a)));
    var value = maximizing ? -double.infinity : double.infinity;
    for (final move in moves) {
      final child = SweepGame.fromJson(game.toJson())
        ..play(move, recordDiagnostic: false);
      final score = _endgame(child, team, budget, alpha, beta);
      value = maximizing ? max(value, score) : min(value, score);
      if (maximizing) {
        alpha = max(alpha, value);
      } else {
        beta = min(beta, value);
      }
      if (beta <= alpha) break;
    }
    return value;
  }

  /// Check every unseen rank, independent of the few rollout samples.
  /// Uses only the resulting public table; never reads a sampled/real hand.
  double sweepRisk(Position before, SweepGame after) {
    if (after.phase == Phase.results ||
        after.plays >= 47 ||
        (after.loose.isEmpty && after.houses.isEmpty)) {
      return 0;
    }
    final seen = {
      ...before.hand,
      ...before.loose,
      ...before.houses.expand((h) => h.cards),
      ...before.captured.expand((c) => c)
    };
    final unseen = [
      for (var c = 0; c < 52; c++)
        if (!seen.contains(c)) c
    ];
    final dangerousRanks = <int>{};
    for (final rank in unseen.map(rankOf).toSet()) {
      final probe = Position(
          seat: after.turn,
          hand: [rank - 1],
          loose: after.loose,
          houses: after.houses,
          phase: Phase.playing,
          call: before.call,
          plays: after.plays);
      if (probe.legalMoves().any((m) =>
          m.kind == MoveKind.capture &&
          m.selectedLoose.length == after.loose.length &&
          m.houseIndexes.length == after.houses.length)) {
        dangerousRanks.add(rank);
      }
    }
    if (dangerousRanks.isEmpty) return 0;
    if (before.knownRanks[after.turn].any(dangerousRanks.contains)) return 1;
    if (after.houses.any((h) =>
        h.owners.contains(after.turn) && dangerousRanks.contains(h.value))) {
      return 1;
    }
    final matches =
        unseen.where((c) => dangerousRanks.contains(rankOf(c))).length;
    final count =
        before.phase == Phase.opening ? 12 : before.handCounts[after.turn];
    var miss = 1.0;
    for (var i = 0; i < count && i < unseen.length; i++) {
      miss *= max(0, unseen.length - matches - i) / (unseen.length - i);
    }
    return 1 - miss;
  }

  double _priority(Position p, Move m) {
    final points = pointsOf([m.card, ...p.affectedCards(m)]);
    return switch (m.kind) {
      MoveKind.capture => 15 +
          points * 4 +
          (m.selectedLoose.length == p.loose.length &&
                  m.houseIndexes.length == p.houses.length
              ? 200
              : 0),
      MoveKind.build || MoveKind.raise => 8 + points * 2,
      MoveKind.discard => -cardOf(m.card).points.toDouble(),
    };
  }

  double _evaluate(SweepGame g, int team) {
    double value(int t) {
      final score = g.score(t);
      if (g.phase == Phase.results) return score.total.toDouble();
      final eligibility = score.cardPoints >= 20
          ? 1.0
          : (.2 + .8 * score.cardPoints / 20) * min(1.0, (48 - g.plays) / 8);
      var result = score.cardPoints + score.earnedSweepPoints * eligibility;
      for (final house in g.houses) {
        if (house.owners.any((s) => s % 2 == t)) {
          result += pointsOf(house.cards) * .45 + 1;
        }
      }
      return result;
    }

    final margin = value(team) - value(1 - team);
    if (g.phase == Phase.results && g.winner != null) {
      return margin + (g.winner == team ? 200 : -200);
    }
    return margin;
  }

  /// Samples only cards not already seen. Public house commitments constrain
  /// possible hands. No real shuffle seed, deck or other player's hand is used.
  SweepGame? sampleWorld(Position p) {
    if (p.handCounts.length != 4 || p.phase == Phase.call) return null;
    final seen = {
      ...p.hand,
      ...p.loose,
      ...p.houses.expand((h) => h.cards),
      ...p.captured.expand((c) => c)
    };
    for (var attempt = 0; attempt < 24; attempt++) {
      final unseen = [
        for (var c = 0; c < 52; c++)
          if (!seen.contains(c)) c
      ]..shuffle(random);
      final hands =
          List.generate(4, (s) => s == p.seat ? [...p.hand] : <int>[]);
      var valid = true;
      final seats = [
        for (var s = 0; s < 4; s++)
          if (s != p.seat) s
      ]..shuffle(random);
      for (final s in seats) {
        final ranks = {
          ...p.knownRanks[s],
          ...p.houses
              .where((h) => h.owners.contains(s))
              .map((h) => h.value)
              .toSet()
        };
        for (final rank in ranks) {
          final index = unseen.indexWhere((c) => rankOf(c) == rank);
          if (index < 0) {
            valid = false;
            break;
          }
          hands[s].add(unseen.removeAt(index));
        }
        if (hands[s].length > p.handCounts[s]) valid = false;
      }
      if (!valid) continue;
      for (final s in seats) {
        while (hands[s].length < p.handCounts[s] && unseen.isNotEmpty) {
          hands[s].add(unseen.removeLast());
        }
        if (hands[s].length != p.handCounts[s]) valid = false;
      }
      if (!valid) continue;
      return SweepGame.fromJson({
        'version': 1,
        'seed': 0,
        'dealer': p.dealer,
        'dealerCount': 0,
        'dealNumber': 1,
        'turn': p.seat,
        'plays': p.plays,
        'call': p.call,
        'lastCapture': p.lastCaptureTeam,
        'winner': null,
        'phase': p.phase.name,
        'hands': hands,
        'deck': unseen,
        'loose': p.loose,
        'houses': p.houses.map((h) => h.toJson()).toList(),
        'captured': p.captured,
        'sweeps': p.sweeps.map((s) => s.map((t) => t.name).toList()).toList(),
        'totals': p.totals,
        'lastScores': [0, 0],
        'history': <String>[],
        'knownRanks': p.knownRanks.map((r) => r.toList()).toList(),
      });
    }
    return null;
  }

  int chooseCall(Position p) {
    final calls = p.calls;
    calls.sort((a, b) {
      int weight(int v) => p.hand.where((c) => rankOf(c) == v).length * 10 + v;
      return weight(b).compareTo(weight(a));
    });
    return calls.first;
  }

  Move tacticalMove(Position p) {
    final moves = _choices(p);
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
            final points = pointsOf(p.captured[p.seat % 2]) +
                pointsOf([m.card, ...affected]);
            value += (p.plays == 0 ? 25 : 50) *
                4 *
                (points >= 20 ? 1 : .35 + .65 * points / 20);
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
