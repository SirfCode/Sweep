import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/bot.dart';
import 'game/engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SweepApp(preferences: await SharedPreferences.getInstance()));
}

const gold = Color(0xFFE8C889);
const ink = Color(0xFF102D27);
const felt = Color(0xFF194C40);
const cream = Color(0xFFF7F0DE);
const saveKey = 'sweep.game.v1';

class SweepApp extends StatelessWidget {
  final SharedPreferences preferences;
  final Duration botDelay;
  const SweepApp(
      {super.key,
      required this.preferences,
      this.botDelay = const Duration(milliseconds: 1100)});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Sweep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: ColorScheme.fromSeed(
              seedColor: gold,
              brightness: Brightness.dark,
              primary: gold,
              surface: ink),
          appBarTheme:
              const AppBarTheme(backgroundColor: ink, foregroundColor: cream),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: gold,
                  foregroundColor: ink))),
      home: SweepScreen(preferences: preferences, botDelay: botDelay));
}

class SweepScreen extends StatefulWidget {
  final SharedPreferences preferences;
  final Duration botDelay;
  const SweepScreen(
      {super.key, required this.preferences, required this.botDelay});
  @override
  State<SweepScreen> createState() => _SweepScreenState();
}

class _SweepScreenState extends State<SweepScreen> with WidgetsBindingObserver {
  SweepGame? _game;
  bool _atHome = true;
  bool _foreground = true;
  String? _error;
  String? _saveError;
  Timer? _botTimer;
  Future<void> _saveQueue = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final saved = widget.preferences.getString(saveKey);
    if (saved != null) {
      try {
        _game = SweepGame.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {
        _saveError =
            'The saved game could not be loaded. Start a new game to continue.';
      }
    }
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _scheduleBot();
    } else {
      _botTimer?.cancel();
      _save();
    }
  }

  void _save() {
    if (_game == null) return;
    final encoded = jsonEncode(_game!.toJson());
    _saveQueue = _saveQueue.then((_) async {
      try {
        if (!await widget.preferences.setString(saveKey, encoded)) {
          throw StateError('Save failed');
        }
        if (mounted && _saveError != null) setState(() => _saveError = null);
      } catch (_) {
        if (mounted) {
          setState(() => _saveError =
              'Could not save this turn. Keep the app open and try again.');
        }
      }
    });
  }

  void _scheduleBot() {
    _botTimer?.cancel();
    final g = _game;
    if (!mounted ||
        !_foreground ||
        _atHome ||
        _error != null ||
        g == null ||
        g.turn == 0 ||
        g.phase == Phase.results) {
      return;
    }
    _botTimer = Timer(widget.botDelay, () {
      if (!mounted || _atHome || !_foreground) return;
      final bot = SweepBot(g.seed + g.dealNumber * 53 + g.plays);
      _act(() {
        if (g.phase == Phase.call) {
          g.call(bot.chooseCall(g.position));
        } else {
          g.play(bot.chooseMove(g.position));
        }
      });
    });
  }

  void _act(void Function() action) {
    try {
      setState(action);
      _save();
      _scheduleBot();
    } catch (e) {
      setState(() => _error = 'Play paused: $e');
      _botTimer?.cancel();
    }
  }

  Future<void> _newGame() async {
    if (_game != null && _game!.winner == null) {
      final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Start a new game?'),
                  content: const Text('This replaces your saved game.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep game')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('New game'))
                  ]));
      if (replace != true || !mounted) return;
    }
    _act(() {
      _game = SweepGame.newGame();
      _atHome = false;
      _error = null;
    });
  }

  void _home() {
    _botTimer?.cancel();
    _save();
    setState(() => _atHome = true);
  }

  Future<void> _rules() async {
    final rules = await rootBundle.loadString('SWEEP_RULES.md');
    if (!mounted) return;
    showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
            child: Scaffold(
                appBar: AppBar(
                    title: const Text('Rulebook'),
                    leading: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close))),
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(rules,
                        style: const TextStyle(fontSize: 16, height: 1.5))))));
  }

  void _history() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(children: [
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Deal log', style: TextStyle(fontSize: 22))),
                Expanded(
                    child: ListView(
                        children: _game!.history.reversed
                            .map((s) => ListTile(title: Text(s)))
                            .toList()))
              ]))));
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _atHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _home();
      },
      child: Scaffold(
          appBar: AppBar(
              title: Text(
                  _atHome ? 'SWEEP' : 'SWEEP  /  Deal ${_game!.dealNumber}',
                  style: const TextStyle(fontSize: 18, letterSpacing: 2)),
              leading: _atHome
                  ? null
                  : IconButton(
                      key: const Key('home'),
                      tooltip: 'Save and return home',
                      onPressed: _home,
                      icon: const Icon(Icons.home_outlined)),
              actions: [
                if (!_atHome)
                  IconButton(
                      onPressed: _history,
                      tooltip: 'Deal log',
                      icon: const Icon(Icons.history)),
                IconButton(
                    onPressed: _rules,
                    tooltip: 'Rulebook',
                    icon: const Icon(Icons.menu_book_outlined))
              ]),
          body: SafeArea(
              child: Column(children: [
            if (_saveError != null)
              MaterialBanner(content: Text(_saveError!), actions: [
                TextButton(onPressed: _save, child: const Text('Retry'))
              ]),
            if (_error != null && !_atHome)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.orangeAccent))),
            Expanded(
                child: _atHome
                    ? _homeBody()
                    : _game!.phase == Phase.results
                        ? _results()
                        : _table())
          ]))));

  Widget _homeBody() => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('A good hand.\nA better partnership.',
                        style: TextStyle(
                            fontSize: 36, height: 1.15, color: cream)),
                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final card in [48, 22, 51])
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: CardFace(card: card, large: true))
                    ]),
                    const SizedBox(height: 24),
                    const Text('You + Ari  vs  Mira + Dev',
                        style: TextStyle(fontSize: 20, color: gold)),
                    const SizedBox(height: 12),
                    const Text(
                        'Build houses, capture points, and clear the table. Play offline with three bots. First team to lead by 104 after a deal wins.',
                        style: TextStyle(height: 1.6, fontSize: 16)),
                    const SizedBox(height: 28),
                    if (_game != null) ...[
                      FilledButton(
                          key: const Key('resume'),
                          onPressed: () {
                            setState(() => _atHome = false);
                            _scheduleBot();
                          },
                          child: Text(_game!.winner != null
                              ? 'View game result'
                              : 'Resume • Deal ${_game!.dealNumber}')),
                      const SizedBox(height: 12)
                    ],
                    OutlinedButton(
                        key: const Key('new-game'),
                        onPressed: _newGame,
                        child: const Text('New game')),
                    const SizedBox(height: 16),
                    const Text(
                        'Tap a card, preview a move, then confirm.\nYour progress saves after every turn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: Colors.white60))
                  ]))));

  Widget _scores() {
    final g = _game!;
    return Row(children: [
      for (var team = 0; team < 2; team++)
        Expanded(
            child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: team == 0
                        ? const Color(0xFF295C4D)
                        : Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${team == 0 ? 'YOU + ARI' : 'MIRA + DEV'}     ${g.totals[team]}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: cream)),
                      const SizedBox(height: 4),
                      Text(
                          '${g.score(team).cardPoints} card pts · +${g.score(team).earnedSweepPoints} pending',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70))
                    ])))
    ]);
  }

  Widget _seat(int seat) {
    final g = _game!;
    final active = g.turn == seat;
    return Expanded(
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
                color: active ? gold : Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(
                  '${active ? '● ' : ''}${seatNames[seat]}${g.dealer == seat ? '  D' : ''}',
                  style: TextStyle(
                      color: active ? ink : cream,
                      fontWeight: FontWeight.bold)),
              Text(
                  '${seat == 2 ? 'Partner' : 'Opponent'} · ${g.hands[seat].length} cards',
                  style: TextStyle(
                      fontSize: 10, color: active ? ink : Colors.white60))
            ])));
  }

  Widget _table() {
    final g = _game!;
    final human = g.turn == 0;
    final hand = g.hands[0].toList()
      ..sort((a, b) {
        final rank = rankOf(a).compareTo(rankOf(b));
        return rank != 0 ? rank : a.compareTo(b);
      });
    final legal = human ? g.position.legalMoves() : <Move>[];
    final sections = <Widget>[
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8), child: _scores()),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [_seat(3), _seat(2), _seat(1)])),
      Expanded(
          child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              decoration: BoxDecoration(
                  color: felt,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: gold.withValues(alpha: .2))),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('THE TABLE',
                                  style: TextStyle(
                                      letterSpacing: 2,
                                      fontSize: 11,
                                      color: gold))),
                          Text(
                              g.phase == Phase.call
                                  ? 'Hidden until call'
                                  : '${g.plays}/48 plays',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white60))
                        ]),
                        const SizedBox(height: 16),
                        if (g.phase == Phase.call)
                          Center(
                              child: Wrap(
                                  spacing: 8,
                                  children: List.generate(
                                      4, (_) => const CardBack())))
                        else ...[
                          if (g.loose.isEmpty && g.houses.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                    'The table is clear.\nNext player places a loose card.',
                                    style: TextStyle(
                                        height: 1.6, color: Colors.white70))),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: g.loose
                                  .map((c) => CardFace(card: c))
                                  .toList()),
                          if (g.houses.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: g.houses.map(_house).toList())
                          ]
                        ],
                        const SizedBox(height: 20),
                        if (g.history.isNotEmpty)
                          Text(g.history.last,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  height: 1.5))
                      ])))),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  g.phase == Phase.call
                      ? human
                          ? 'Your call • choose a rank you hold'
                          : '${seatNames[g.turn]} is choosing the opening call…'
                      : human
                          ? g.phase == Phase.opening
                              ? 'Your opening move • called ${g.calledValue}'
                              : 'Your turn • tap a card to see its moves'
                          : '${seatNames[g.turn]} is thinking…',
                  style: const TextStyle(
                      color: gold, fontWeight: FontWeight.w600)))),
      if (g.phase == Phase.call && human)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
                spacing: 8,
                children: g.position.calls
                    .map((v) => FilledButton(
                        key: Key('call-$v'),
                        onPressed: () => _act(() => g.call(v)),
                        child: Text('Call $v')))
                    .toList())),
      SizedBox(
          height: 108,
          child: hand.isEmpty
              ? const Center(
                  child: Text('Your cards arrive after the opening call.',
                      style: TextStyle(color: Colors.white60)))
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: hand.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final card = hand[index];
                    final available =
                        legal.where((m) => m.card == card).toList();
                    return CardFace(
                        key: Key('hand-$card'),
                        card: card,
                        large: true,
                        highlighted: human && available.isNotEmpty,
                        onTap: human && g.phase != Phase.call
                            ? () => _chooseCard(card, available)
                            : null);
                  })),
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              'YOU${g.dealer == 0 ? ' · Dealer' : ''} · ${hand.length} cards · Play passes to your right → Mira',
              style: const TextStyle(fontSize: 10, color: Colors.white60)))
    ];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 650 && constraints.maxHeight < 500) {
        return Row(children: [
          Expanded(child: Column(children: sections.take(3).toList())),
          SizedBox(
              width: 280,
              child: SingleChildScrollView(
                  child: Column(children: sections.skip(3).toList()))),
        ]);
      }
      return Column(children: sections);
    });
  }

  Widget _house(House h) => InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(
                      '${h.pakka ? 'Pakka' : 'Ordinary'} house · ${h.value}'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        for (final group in h.groups)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                  '${group.map(cardName).join(' + ')} = ${h.value}')),
                        Text(
                            'Committed: ${h.owners.map((s) => seatNames[s]).join(', ')}'),
                        const SizedBox(height: 12),
                        Text(h.pakka
                            ? 'Only a matching card can capture this house. It cannot be raised.'
                            : 'Capture with a matching card, or raise with one hand card while meeting the new commitment.')
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ])),
      child: Container(
          width: 146,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gold)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${h.value}  ${h.pakka ? 'PAKKA' : 'HOUSE'}',
                style:
                    const TextStyle(color: gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${h.cards.length} cards · ${pointsOf(h.cards)} pts',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(h.owners.map((s) => seatNames[s]).join(' + '),
                style: const TextStyle(fontSize: 11, color: Colors.white60))
          ])));

  Future<void> _chooseCard(int card, List<Move> moves) async {
    if (moves.isEmpty) {
      final committed = _game!.houses
          .any((h) => h.owners.contains(0) && h.value == rankOf(card));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(committed
              ? 'Keep ${cardName(card)} for your house commitment. Capture the house or wait for its value to change.'
              : 'This card has no legal move. The opening must follow the called value.')));
      return;
    }
    final g = _game!;
    final p = g.position;
    final chosen = await showModalBottomSheet<Move>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .68,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                          '${cardName(card)} · ${moves.length} legal ${moves.length == 1 ? 'move' : 'moves'}',
                          style: const TextStyle(fontSize: 22))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                          'Choose a move to preview. Nothing is played yet.',
                          style: TextStyle(color: Colors.white60))),
                  const SizedBox(height: 10),
                  Expanded(
                      child: ListView.separated(
                          itemCount: moves.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = moves[index];
                            final cards = p.affectedCards(m);
                            return ListTile(
                                key: Key('move-$index'),
                                leading: Icon(
                                    switch (m.kind) {
                                      MoveKind.capture =>
                                        Icons.download_rounded,
                                      MoveKind.build =>
                                        Icons.home_work_outlined,
                                      MoveKind.raise => Icons.upgrade,
                                      MoveKind.discard => Icons.add_card
                                    },
                                    color: gold),
                                title: Text(m.title),
                                subtitle: Text(cards.isEmpty
                                    ? 'Leave this card face up.'
                                    : cards.map(cardName).join('  ')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(context, m));
                          }))
                ]))));
    if (chosen == null || !mounted) return;
    final m = chosen;
    final affected = p.affectedCards(m);
    final remains = p.loose.where((c) => !m.selectedLoose.contains(c)).toList();
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(m.title),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Play ${cardName(m.card)}'),
                      const SizedBox(height: 12),
                      if (affected.isNotEmpty) ...[
                        const Text('Table cards included',
                            style: TextStyle(color: gold)),
                        const SizedBox(height: 8),
                        Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: affected
                                .map((c) => Chip(label: Text(cardName(c))))
                                .toList()),
                        const SizedBox(height: 12)
                      ],
                      if (m.kind == MoveKind.capture)
                        Text('Your team takes ${pointsOf([
                              m.card,
                              ...affected
                            ])} card points.'),
                      if (m.kind == MoveKind.build ||
                          m.kind == MoveKind.raise) ...[
                        Text('Result: house of ${m.value}'),
                        Text(
                            'Committed: ${p.resultingOwners(m).map((s) => seatNames[s]).join(', ')}')
                      ],
                      const SizedBox(height: 12),
                      Text(
                          'Loose cards left: ${remains.isEmpty ? 'none' : remains.map(cardName).join(' ')}${m.kind == MoveKind.discard ? ' + ${cardName(m.card)}' : ''}'),
                      if (m.kind == MoveKind.capture &&
                          remains.isEmpty &&
                          m.houseIndexes.length == p.houses.length)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                                'This clears the table. Sweep bonuses require 20 card points at the end of the deal.',
                                style: TextStyle(color: gold)))
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      key: const Key('confirm-move'),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirm move'))
                ]));
    if (confirm == true && mounted && !_atHome && identical(g, _game)) {
      _act(() => g.play(m));
    }
  }

  Widget _results() {
    final g = _game!;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          g.winner == null
                              ? 'Deal complete'
                              : g.winner == 0
                                  ? 'You and Ari win!'
                                  : 'Mira and Dev win',
                          style: const TextStyle(fontSize: 32, color: gold)),
                      const SizedBox(height: 12),
                      Text(g.winner == null
                          ? 'A lead of 104 after a completed deal wins the game.'
                          : 'Final lead: ${(g.totals[0] - g.totals[1]).abs()} points.'),
                      const SizedBox(height: 24),
                      for (var team = 0; team < 2; team++)
                        Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: felt,
                                borderRadius: BorderRadius.circular(18)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(team == 0 ? 'You + Ari' : 'Mira + Dev',
                                      style: const TextStyle(
                                          fontSize: 22, color: cream)),
                                  const SizedBox(height: 12),
                                  _scoreLine('Captured card points',
                                      g.score(team).cardPoints),
                                  _scoreLine('Eligible sweep bonus',
                                      g.score(team).eligibleSweepPoints),
                                  if (g.score(team).earnedSweepPoints >
                                      g.score(team).eligibleSweepPoints)
                                    Text(
                                        '${g.score(team).earnedSweepPoints} sweep points discarded: fewer than 20 card points.',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.orangeAccent)),
                                  const Divider(),
                                  _scoreLine('This deal', g.lastScores[team]),
                                  _scoreLine('Game total', g.totals[team])
                                ])),
                      if (g.winner == null) ...[
                        Text(
                            'Next dealer: ${seatNames[g.nextDealer.$1]} · ${g.nextDealer.$2} counted losses/ties',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        FilledButton(
                            key: const Key('next-deal'),
                            onPressed: () => _act(g.continueGame),
                            child: const Text('Next deal'))
                      ] else
                        FilledButton(
                            onPressed: _newGame,
                            child: const Text('Play again')),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _home,
                          child: const Text('Save and return home'))
                    ]))));
  }

  Widget _scoreLine(String title, int points) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(title)),
        Text('$points', style: const TextStyle(fontWeight: FontWeight.bold))
      ]));
}

class CardFace extends StatelessWidget {
  final int card;
  final bool large;
  final bool highlighted;
  final VoidCallback? onTap;
  const CardFace(
      {super.key,
      required this.card,
      this.large = false,
      this.highlighted = false,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final color =
        card ~/ 13 == 1 || card ~/ 13 == 2 ? const Color(0xFFAC3734) : ink;
    return Semantics(
        label: '${cardName(card)}, ${cardOf(card).points} card points',
        button: onTap != null,
        child: Material(
            color: cream,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                    width: large ? 62 : 50,
                    height: large ? 86 : 72,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: highlighted ? gold : Colors.transparent,
                            width: 3)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(cardName(card),
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: large ? 22 : 18,
                                      fontWeight: FontWeight.w800))),
                          const Spacer(),
                          Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                  cardOf(card).points > 0
                                      ? '${cardOf(card).points} pt'
                                      : '—',
                                  style: TextStyle(
                                      color: color.withValues(alpha: .7),
                                      fontSize: 10)))
                        ])))));
  }
}

class CardBack extends StatelessWidget {
  const CardBack({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: 50,
      height: 72,
      decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: gold)),
      child: const Center(
          child: Icon(Icons.diamond_outlined, color: gold, size: 24)));
}
