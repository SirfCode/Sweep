import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/bot.dart';
import 'game/engine.dart';
import 'table_art.dart';
export 'table_art.dart' show CardFace, CardBack;
part 'table_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SweepApp(preferences: await SharedPreferences.getInstance()));
}

const saveKey = 'sweep.game.v1';

class SweepApp extends StatelessWidget {
  final SharedPreferences preferences;
  final Duration botDelay;
  const SweepApp(
      {super.key,
      required this.preferences,
      this.botDelay = const Duration(milliseconds: 1500)});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Sweep',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      }),
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

class _SweepScreenState extends State<SweepScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  SweepGame? _game;
  bool _atHome = true;
  bool _foreground = true;
  String? _error;
  String? _saveError;
  Timer? _botTimer;
  Future<void> _saveQueue = Future.value();
  late final AnimationController _motion;
  Move? _moving;
  int? _selectedCard;
  Move? _preview;
  bool _paused = false;
  double _pace = 1;
  String? _lastAction;
  void _update(VoidCallback action) => setState(action);

  Duration _duration(double factor) => Duration(
      milliseconds: (widget.botDelay.inMilliseconds * factor * _pace).round());

  bool get _canPlay =>
      !_paused && _error == null && _moving == null && _game!.turn == 0;

  Future<void> _overlay(Future<void> Function() open) async {
    final wasPaused = _paused;
    _botTimer?.cancel();
    _motion.stop();
    setState(() => _paused = true);
    try {
      await open();
    } finally {
      if (mounted) {
        setState(() => _paused = wasPaused);
        if (_moving != null && !_paused && _foreground && !_atHome) {
          _motion.forward();
        } else {
          _scheduleBot();
        }
      }
    }
  }

  void _play(Move move) {
    if (_paused || _moving != null) return;
    _botTimer?.cancel();
    setState(() {
      _moving = move;
      _selectedCard = null;
      _preview = null;
      _lastAction = null;
    });
    _motion.duration = _duration(1.4);
    _motion.forward(from: 0);
  }

  void _finishMove(AnimationStatus status) {
    if (status != AnimationStatus.completed || _moving == null) return;
    final move = _moving!;
    final g = _game!;
    final clear = move.kind == MoveKind.capture &&
        move.selectedLoose.length == g.loose.length &&
        move.houseIndexes.length == g.houses.length;
    _act(() {
      _lastAction = clear
          ? '${seatNames[g.turn]} · Sweep!${g.plays == 47 ? '' : ' +${g.plays == 0 ? 25 : 50} pending'}'
          : '${seatNames[g.turn]} · ${_moveLabel(move)}';
      g.play(move);
      _moving = null;
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _botTimer?.cancel();
      _motion.stop();
    } else if (_moving != null) {
      _motion.forward();
    } else {
      _scheduleBot();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pace = widget.preferences.getDouble('sweep.pace') ?? 1;
    _motion = AnimationController(vsync: this)..addStatusListener(_finishMove);
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
    _motion.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      if (_moving != null && !_paused && !_atHome) {
        _motion.forward();
      } else {
        _scheduleBot();
      }
    } else {
      _botTimer?.cancel();
      _motion.stop();
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
        _paused ||
        _moving != null ||
        _error != null ||
        g == null ||
        g.turn == 0 ||
        g.phase == Phase.results) {
      return;
    }
    _botTimer = Timer(_duration(1), () {
      if (!mounted || _atHome || !_foreground) return;
      final bot = SweepBot(g.seed + g.dealNumber * 53 + g.plays);
      if (g.phase == Phase.call) {
        _act(() {
          g.call(bot.chooseCall(g.position));
          _lastAction = '${seatNames[g.turn]} calls ${g.calledValue}';
        });
      } else {
        _play(bot.chooseMove(g.position));
      }
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
      _paused = false;
      _selectedCard = null;
      _preview = null;
      _lastAction = null;
    });
  }

  void _home() {
    _botTimer?.cancel();
    _motion.stop();
    _moving = null;
    _selectedCard = null;
    _preview = null;
    _save();
    setState(() => _atHome = true);
  }

  Future<void> _rules() async {
    final rules = await rootBundle.loadString('SWEEP_RULES.md');
    if (!mounted) return;
    await _overlay(() => showDialog<void>(
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
                        style: const TextStyle(fontSize: 16, height: 1.5)))))));
  }

  Future<void> _history() => _overlay(() => showModalBottomSheet<void>(
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
              ])))));
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
                if (!_atHome && _game!.phase != Phase.results) ...[
                  IconButton(
                      key: const Key('pause'),
                      onPressed: _togglePause,
                      tooltip: _paused ? 'Resume play' : 'Pause play',
                      icon: Icon(_paused ? Icons.play_arrow : Icons.pause)),
                  PopupMenuButton<double>(
                      tooltip: 'Turn speed',
                      initialValue: _pace,
                      onSelected: (value) {
                        setState(() => _pace = value);
                        widget.preferences.setDouble('sweep.pace', value);
                        _scheduleBot();
                      },
                      itemBuilder: (_) => [
                            for (final entry in {
                              1.6: 'Slow',
                              1.0: 'Normal',
                              .5: 'Fast'
                            }.entries)
                              CheckedPopupMenuItem(
                                  value: entry.key,
                                  checked: _pace == entry.key,
                                  child: Text(entry.value))
                          ],
                      icon: const Icon(Icons.speed)),
                ],
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
                        'Choose a card. Light up the table.\nYour seat is waiting. • v0.2',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: Colors.white60))
                  ]))));

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
                            onPressed: () => _act(() {
                                  _lastAction = null;
                                  g.continueGame();
                                }),
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
