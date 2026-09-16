import 'dart:math';

import 'cards.dart';
import 'scoring.dart';

int rankOf(int card) => card % 13 + 1;
PlayingCard cardOf(int card) =>
    PlayingCard(Suit.values[card ~/ 13], rankOf(card));
int pointsOf(Iterable<int> cards) =>
    cards.fold(0, (sum, card) => sum + cardOf(card).points);
String rankName(int rank) => switch (rank) {
      1 => 'A',
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      _ => '$rank',
    };
String cardName(int card) =>
    '${rankName(rankOf(card))}${['♣', '♦', '♥', '♠'][card ~/ 13]}';
const seatNames = ['You', 'Mira', 'Ari', 'Dev'];

enum Phase { call, opening, playing, results }

enum MoveKind { capture, build, raise, discard }

class House {
  final int value;
  final List<List<int>> groups;
  final Set<int> owners;
  House(this.value, Iterable<List<int>> groups, Iterable<int> owners)
      : groups =
            List.unmodifiable(groups.map((g) => List<int>.unmodifiable(g))),
        owners = Set.unmodifiable(owners);
  bool get pakka => groups.length > 1;
  List<int> get cards => groups.expand((g) => g).toList();
  Map<String, dynamic> toJson() => {
        'value': value,
        'groups': groups,
        'owners': owners.toList(),
      };
  factory House.fromJson(Map<String, dynamic> json) => House(
        json['value'] as int,
        (json['groups'] as List).map((g) => List<int>.from(g as List)),
        List<int>.from(json['owners'] as List),
      );
}

/// A complete choice, including one of the allowed overlapping outcomes.
class Move {
  final MoveKind kind;
  final int card;
  final int value;
  final List<List<int>> groups;
  final List<int> houseIndexes;
  final int? raisedIndex;
  Move(this.kind, this.card, this.value,
      {Iterable<List<int>> groups = const [],
      Iterable<int> houseIndexes = const [],
      this.raisedIndex})
      : groups =
            List.unmodifiable(groups.map((g) => List<int>.unmodifiable(g))),
        houseIndexes = List.unmodifiable(houseIndexes);
  Set<int> get selectedLoose => groups.expand((g) => g).toSet();
  String get key {
    final loose = selectedLoose.toList()..sort();
    return '${kind.name}/$card/$value/$raisedIndex/${houseIndexes.join(',')}/${loose.join(',')}';
  }

  String get title => switch (kind) {
        MoveKind.capture => 'Capture with ${cardName(card)}',
        MoveKind.build => 'Build / add to $value',
        MoveKind.raise => 'Raise house to $value',
        MoveKind.discard => 'Place ${cardName(card)} on the table',
      };
}

/// Deliberately excludes the deck and every other player's hand.
/// Both the legal-action generator and the bots operate on this information.
class Position {
  final int seat;
  final List<int> hand;
  final List<int> loose;
  final List<House> houses;
  final Phase phase;
  final int? call;
  final int plays;
  Position(
      {required this.seat,
      required Iterable<int> hand,
      required Iterable<int> loose,
      required Iterable<House> houses,
      required this.phase,
      required this.call,
      required this.plays})
      : hand = List.unmodifiable(hand),
        loose = List.unmodifiable(loose),
        houses = List.unmodifiable(houses);

  List<int> get calls =>
      (hand.map(rankOf).where((r) => r >= 9).toSet().toList()..sort());

  Set<int> resultingOwners(Move move) {
    final owners = <int>{};
    for (final i in move.houseIndexes) {
      owners.addAll(houses[i].owners);
    }
    // A contribution under a partner's existing commitment creates no new one.
    if (!owners.contains((seat + 2) % 4)) owners.add(seat);
    return owners;
  }

  bool _commitmentsAllow(Move move) {
    final remaining = hand.where((c) => c != move.card).map(rankOf).toSet();
    for (var i = 0; i < houses.length; i++) {
      if (move.houseIndexes.contains(i) || move.raisedIndex == i) continue;
      if (houses[i].owners.contains(seat) &&
          !remaining.contains(houses[i].value)) {
        return false;
      }
    }
    if (move.kind == MoveKind.build || move.kind == MoveKind.raise) {
      if (resultingOwners(move).contains(seat) &&
          !remaining.contains(move.value)) {
        return false;
      }
    }
    return true;
  }

  List<Move> legalMoves() {
    if (phase == Phase.call || phase == Phase.results) return [];
    final result = <String, Move>{};
    // Each target shares its subset search across cards in this hand.
    final covers = <int, _Combinations>{};
    _Combinations at(int value) =>
        covers.putIfAbsent(value, () => _Combinations(loose, value));
    void add(Move m) {
      if (_commitmentsAllow(m)) result[m.key] = m;
    }

    for (final card in hand) {
      final rank = rankOf(card);
      final sameHouses = [
        for (var i = 0; i < houses.length; i++)
          if (houses[i].value == rank) i
      ];
      final canCapture = sameHouses.isNotEmpty || at(rank).subsets.isNotEmpty;
      if (canCapture && (phase != Phase.opening || rank == call)) {
        for (final groups in at(rank).maximal()) {
          add(Move(MoveKind.capture, card, rank,
              groups: groups, houseIndexes: sameHouses));
        }
      }
      for (var value = 9; value <= 13; value++) {
        if (phase == Phase.opening && value != call) continue;
        final matches = [
          for (var i = 0; i < houses.length; i++)
            if (houses[i].value == value) i
        ];
        if (rank <= value) {
          // A matching hand card is a complete group by itself. It can join
          // an existing house or matching loose groups to start a pakka house.
          final bases = rank == value
              ? (matches.isNotEmpty || at(value).subsets.isNotEmpty
                  ? [<int>[]]
                  : <List<int>>[])
              : _Combinations(loose, value - rank).cardSubsets;
          for (final base in bases) {
            for (final extra in at(value).maximal(excluding: base)) {
              add(Move(MoveKind.build, card, value,
                  groups: [base, ...extra], houseIndexes: matches));
            }
          }
        }
        if (phase != Phase.opening) {
          for (var i = 0; i < houses.length; i++) {
            final house = houses[i];
            if (house.pakka || house.value + rank != value) continue;
            for (final groups in at(value).maximal()) {
              add(Move(MoveKind.raise, card, value,
                  groups: groups, houseIndexes: matches, raisedIndex: i));
            }
          }
        }
      }
      if (!canCapture && phase != Phase.opening) {
        add(Move(MoveKind.discard, card, rank));
      }
    }
    // The called-rank discard is allowed only if NO called-value capture/build exists.
    if (phase == Phase.opening && result.isEmpty) {
      for (final card in hand.where((c) => rankOf(c) == call)) {
        add(Move(MoveKind.discard, card, call!));
      }
    }
    return result.values.toList();
  }

  List<int> affectedCards(Move m) => [
        ...m.selectedLoose,
        for (final i in m.houseIndexes) ...houses[i].cards,
        if (m.raisedIndex != null) ...houses[m.raisedIndex!].cards,
      ];
}

/// Enumerates maximal disjoint matches, not merely the largest capture.
/// Outcomes with the same cards remaining are equivalent and share one partition.
class _Combinations {
  final List<int> cards;
  final int target;
  final List<int> subsets = [];
  final Map<int, List<List<int>>> _memo = {};
  _Combinations(this.cards, this.target) {
    void search(int start, int sum, int mask) {
      if (sum == target) {
        if (mask != 0) subsets.add(mask);
        return;
      }
      for (var i = start; i < cards.length; i++) {
        if (sum + rankOf(cards[i]) <= target) {
          search(i + 1, sum + rankOf(cards[i]), mask | (1 << i));
        }
      }
    }

    if (target > 0) search(0, 0, 0);
  }
  List<int> _decode(int mask) => [
        for (var i = 0; i < cards.length; i++)
          if (mask & (1 << i) != 0) cards[i]
      ];
  List<List<int>> get cardSubsets => subsets.map(_decode).toList();
  List<List<int>> _partitions(int remaining) {
    return _memo.putIfAbsent(remaining, () {
      final outcomes = <int, List<int>>{};
      for (final subset in subsets) {
        if (subset & remaining != subset) continue;
        for (final rest in _partitions(remaining ^ subset)) {
          final masks = [subset, ...rest];
          final union = masks.fold(0, (a, b) => a | b);
          outcomes.putIfAbsent(union, () => masks);
        }
      }
      return outcomes.isEmpty ? [<int>[]] : outcomes.values.toList();
    });
  }

  List<List<List<int>>> maximal({Iterable<int> excluding = const []}) {
    var mask = (1 << cards.length) - 1;
    for (final card in excluding) {
      mask &= ~(1 << cards.indexOf(card));
    }
    return _partitions(mask).map((p) => p.map(_decode).toList()).toList();
  }
}

class SweepGame {
  final int seed;
  int dealer;
  int dealerCount = 0;
  int dealNumber = 0;
  int turn = 0;
  int plays = 0;
  int? calledValue;
  int? lastCaptureTeam;
  int? winner;
  Phase phase = Phase.call;
  List<List<int>> hands = List.generate(4, (_) => []);
  List<int> deck = [];
  List<int> loose = [];
  List<House> houses = [];
  List<List<int>> captured = [[], []];
  List<List<SweepTiming>> sweeps = [[], []];
  List<int> totals = [0, 0];
  List<int> lastScores = [0, 0];
  List<String> history = [];
  SweepGame._(this.seed, this.dealer);
  factory SweepGame.newGame({int? seed, int? dealer}) {
    final actualSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    final game =
        SweepGame._(actualSeed, dealer ?? Random(actualSeed).nextInt(4));
    game._startDeal();
    return game;
  }
  Position get position => Position(
      seat: turn,
      hand: hands[turn],
      loose: phase == Phase.call ? const [] : loose,
      houses: houses,
      phase: phase,
      call: calledValue,
      plays: plays);
  DealScore score(int team) =>
      DealScore(cardPoints: pointsOf(captured[team]), sweeps: sweeps[team]);
  void _log(String message) {
    history.add(message);
    if (history.length > 100) history.removeAt(0);
  }

  List<int> _take(int count) {
    final cards = deck.take(count).toList();
    deck.removeRange(0, count);
    return cards;
  }

  void _startDeal() {
    dealNumber++;
    plays = 0;
    calledValue = null;
    lastCaptureTeam = null;
    houses = [];
    captured = [[], []];
    sweeps = [[], []];
    phase = Phase.call;
    turn = (dealer + 1) % 4;
    final random = Random(seed + dealNumber * 7919);
    var retries = 0;
    do {
      hands = List.generate(4, (_) => []);
      deck = List.generate(52, (i) => i)..shuffle(random);
      hands[turn] = _take(4);
      loose = _take(4);
      retries++;
    } while (!hands[turn].any((c) => rankOf(c) >= 9));
    _log(
        'Deal $dealNumber • ${seatNames[dealer]} deals. ${seatNames[turn]} calls.${retries > 1 ? ' Reshuffled ${retries - 1} time(s).' : ''}');
  }

  void call(int value) {
    if (phase != Phase.call || !position.calls.contains(value)) {
      throw StateError('Call must be a held rank from 9 to 13.');
    }
    calledValue = value;
    for (var offset = 2; offset <= 4; offset++) {
      hands[(dealer + offset) % 4].addAll(_take(4));
    }
    phase = Phase.opening;
    _log('${seatNames[turn]} calls $value. Table revealed.');
  }

  void play(Move proposed) {
    final before = position;
    final move =
        before.legalMoves().where((m) => m.key == proposed.key).firstOrNull;
    if (move == null) {
      throw StateError('That move is not legal in this position.');
    }
    final actor = turn;
    final affected = before.affectedCards(move);
    hands[actor].remove(move.card);
    loose.removeWhere(move.selectedLoose.contains);
    final remainingHouses = [
      for (var i = 0; i < houses.length; i++)
        if (!move.houseIndexes.contains(i) && move.raisedIndex != i) houses[i]
    ];
    switch (move.kind) {
      case MoveKind.discard:
        loose.add(move.card);
        _log('${seatNames[actor]} places ${cardName(move.card)}.');
      case MoveKind.capture:
        captured[actor % 2].addAll([move.card, ...affected]);
        lastCaptureTeam = actor % 2;
        _log(
            '${seatNames[actor]} captures ${affected.map(cardName).join(' ')} with ${cardName(move.card)} (${pointsOf([
              move.card,
              ...affected
            ])} card points).');
        if (loose.isEmpty && remainingHouses.isEmpty) {
          final timing = plays == 0
              ? SweepTiming.opening
              : plays == 47
                  ? SweepTiming.finalPlay
                  : SweepTiming.intermediate;
          sweeps[actor % 2].add(timing);
          _log(
              '${seatNames[actor]} clears the table • ${sweepBonus(timing)} provisional sweep points.');
        }
      case MoveKind.build:
      case MoveKind.raise:
        final groups = <List<int>>[];
        if (move.kind == MoveKind.raise) {
          groups.add([...houses[move.raisedIndex!].cards, move.card]);
          groups.addAll(move.groups);
        } else {
          groups.add([move.card, ...move.groups.first]);
          groups.addAll(move.groups.skip(1));
        }
        for (final i in move.houseIndexes) {
          groups.addAll(houses[i].groups);
        }
        final house = House(move.value, groups, before.resultingOwners(move));
        remainingHouses.add(house);
        _log(
            '${seatNames[actor]} ${move.kind == MoveKind.raise ? 'raises to' : 'builds / adds to'} ${move.value} with ${cardName(move.card)}${house.pakka ? ' • pakka' : ''}.');
    }
    houses = remainingHouses;
    plays++;
    if (phase == Phase.opening) {
      for (var round = 0; round < 2; round++) {
        for (var offset = 1; offset <= 4; offset++) {
          hands[(dealer + offset) % 4].addAll(_take(4));
        }
      }
      phase = Phase.playing;
      _log('Remaining cards dealt.');
    }
    turn = (turn + 1) % 4;
    if (plays == 48) _finishDeal();
  }

  void _finishDeal() {
    if (houses.isNotEmpty) throw StateError('Uncaptured house at deal end.');
    if (loose.isNotEmpty) {
      if (lastCaptureTeam == null) {
        throw StateError('No last capture for leftovers.');
      }
      captured[lastCaptureTeam!].addAll(loose);
      _log(
          'Remaining table cards go to ${lastCaptureTeam == 0 ? 'your team' : 'opponents'}; no sweep bonus.');
      loose = [];
    }
    lastScores = [score(0).total, score(1).total];
    for (var team = 0; team < 2; team++) {
      totals[team] += lastScores[team];
    }
    winner = winningTeamAfterDeal(totals[0], totals[1]);
    phase = Phase.results;
    _log('Deal $dealNumber scored: ${lastScores[0]} – ${lastScores[1]}.');
  }

  (int, int) get nextDealer {
    final team = dealer % 2;
    if (lastScores[team] > lastScores[1 - team]) return ((dealer + 1) % 4, 0);
    if (dealerCount + 1 == 3) return ((dealer + 2) % 4, 0);
    return (dealer, dealerCount + 1);
  }

  void continueGame() {
    if (phase != Phase.results || winner != null) {
      throw StateError('Cannot start another deal.');
    }
    final next = nextDealer;
    dealer = next.$1;
    dealerCount = next.$2;
    _startDeal();
  }

  /// Useful for saved-game validation and randomized full-deal tests.
  void validate() {
    final all = [
      ...deck,
      ...loose,
      ...hands.expand((h) => h),
      ...houses.expand((h) => h.cards),
      ...captured.expand((p) => p)
    ];
    if (all.length != 52 ||
        all.toSet().length != 52 ||
        all.any((c) => c < 0 || c >= 52)) {
      throw StateError('Cards are missing or duplicated.');
    }
    if (hands.length != 4 ||
        captured.length != 2 ||
        sweeps.length != 2 ||
        totals.length != 2 ||
        dealer < 0 ||
        dealer > 3 ||
        turn < 0 ||
        turn > 3 ||
        dealerCount < 0 ||
        dealerCount > 2 ||
        plays < 0 ||
        plays > 48 ||
        dealNumber < 1) {
      throw StateError('Invalid game state.');
    }
    for (final h in houses) {
      if (h.value < 9 ||
          h.value > 13 ||
          h.groups.isEmpty ||
          h.owners.isEmpty ||
          h.groups.any((g) =>
              g.isEmpty || g.fold(0, (s, c) => s + rankOf(c)) != h.value)) {
        throw StateError('Invalid house.');
      }
      for (final owner in h.owners) {
        if (owner < 0 ||
            owner > 3 ||
            !hands[owner].any((c) => rankOf(c) == h.value)) {
          throw StateError('House commitment was broken.');
        }
      }
    }
    if (phase == Phase.results &&
        (plays != 48 ||
            hands.any((h) => h.isNotEmpty) ||
            deck.isNotEmpty ||
            houses.isNotEmpty ||
            loose.isNotEmpty)) {
      throw StateError('Incomplete deal results.');
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'seed': seed,
        'dealer': dealer,
        'dealerCount': dealerCount,
        'dealNumber': dealNumber,
        'turn': turn,
        'plays': plays,
        'call': calledValue,
        'lastCapture': lastCaptureTeam,
        'winner': winner,
        'phase': phase.name,
        'hands': hands,
        'deck': deck,
        'loose': loose,
        'houses': houses.map((h) => h.toJson()).toList(),
        'captured': captured,
        'sweeps': sweeps.map((s) => s.map((t) => t.name).toList()).toList(),
        'totals': totals,
        'lastScores': lastScores,
        'history': history,
      };
  factory SweepGame.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported save version.');
    }
    final g = SweepGame._(j['seed'] as int, j['dealer'] as int);
    g.dealerCount = j['dealerCount'] as int;
    g.dealNumber = j['dealNumber'] as int;
    g.turn = j['turn'] as int;
    g.plays = j['plays'] as int;
    g.calledValue = j['call'] as int?;
    g.lastCaptureTeam = j['lastCapture'] as int?;
    g.winner = j['winner'] as int?;
    g.phase = Phase.values.byName(j['phase'] as String);
    g.hands =
        (j['hands'] as List).map((h) => List<int>.from(h as List)).toList();
    g.deck = List<int>.from(j['deck'] as List);
    g.loose = List<int>.from(j['loose'] as List);
    g.houses = (j['houses'] as List)
        .map((h) => House.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList();
    g.captured =
        (j['captured'] as List).map((h) => List<int>.from(h as List)).toList();
    g.sweeps = (j['sweeps'] as List)
        .map((s) => (s as List)
            .map((t) => SweepTiming.values.byName(t as String))
            .toList())
        .toList();
    g.totals = List<int>.from(j['totals'] as List);
    g.lastScores = List<int>.from(j['lastScores'] as List);
    g.history = List<String>.from(j['history'] as List);
    g.validate();
    return g;
  }
}
