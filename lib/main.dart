import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'audio/sfx_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/strings.dart';
import 'l10n/play_guide.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/difficulty.dart';
import 'game/engine.dart';
import 'table_art.dart';
import 'package:uuid/uuid.dart';
import 'reporting/app_reporting.dart';
import 'reporting/completed_report.dart';
import 'reporting/game_log.dart';
import 'reporting/device_platform.dart';
import 'auth/google_session.dart';
export 'table_art.dart' show CardFace, CardBack;
part 'table_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SweepApp(preferences: await SharedPreferences.getInstance()));
}

const saveKey = 'sweep.game.v1';

class SweepApp extends StatefulWidget {
  final GoogleSession? session;

  /// Optional externally-owned manager for tests or embedding.
  final SfxManager? sfxManager;
  final SharedPreferences preferences;
  final Duration botDelay;
  final Duration openingDelay;
  const SweepApp(
      {super.key,
      this.session,
      this.sfxManager,
      required this.preferences,
      this.botDelay = const Duration(milliseconds: 1500),
      this.openingDelay = const Duration(seconds: 20)});
  @override
  State<SweepApp> createState() => _AppState();
}

class _AppState extends State<SweepApp> {
  late final SfxManager _sfx;
  Offset? _soundPointer;
  String? _language;
  @override
  void initState() {
    super.initState();
    _sfx = widget.sfxManager ?? SfxManager(widget.preferences);
    unawaited(_sfx.preload());
    _language = widget.preferences.getString('seep.language');
  }

  void _changeLanguage(String language) {
    setState(() => _language = language);
    widget.preferences.setString('seep.language', language);
  }

  @override
  void dispose() {
    if (widget.sfxManager == null) _sfx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LanguageScope(
      change: _changeLanguage,
      child: MaterialApp(
          builder: (context, child) => Listener(
              onPointerDown: (event) {
                _soundPointer = event.position;
                _sfx.unlock();
              },
              onPointerCancel: (_) => _soundPointer = null,
              onPointerUp: (event) {
                if (_soundPointer != null &&
                    (event.position - _soundPointer!).distance < 10) {
                  unawaited(_sfx.play(Sfx.button));
                }
                _soundPointer = null;
              },
              child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent) {
                      _sfx.unlock();
                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.space) {
                        unawaited(_sfx.play(Sfx.button));
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: child!)),
          title: 'Seep',
          locale: _language == null ? null : Locale(_language!),
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          debugShowCheckedModeBanner: false,
          scrollBehavior: MaterialScrollBehavior().copyWith(dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
            PointerDeviceKind.trackpad,
          }),
          theme: ThemeData(
              fontFamilyFallback: const ['NotoDevanagari'],
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: ink,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: gold,
                  brightness: Brightness.dark,
                  primary: gold,
                  surface: ink),
              appBarTheme:
                  AppBarTheme(backgroundColor: ink, foregroundColor: cream),
              filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                      minimumSize: Size(48, 48),
                      backgroundColor: gold,
                      foregroundColor: ink))),
          home: SweepScreen(
              session: widget.session,
              sfx: _sfx,
              preferences: widget.preferences,
              botDelay: widget.botDelay,
              openingDelay: widget.openingDelay)));
}

class SweepScreen extends StatefulWidget {
  final GoogleSession? session;
  final SfxManager sfx;
  final SharedPreferences preferences;
  final Duration botDelay;
  final Duration openingDelay;
  const SweepScreen(
      {super.key,
      this.session,
      required this.sfx,
      required this.preferences,
      required this.botDelay,
      required this.openingDelay});
  @override
  State<SweepScreen> createState() => _SweepScreenState();
}

class _SweepScreenState extends State<SweepScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  SweepGame? _game;
  BotDifficulty _gameDifficulty = BotDifficulty.guest;
  BotDifficulty get _newDifficulty =>
      BotDifficulty.forAccount(_session.subject != null);
  SfxManager get _sfx => widget.sfx;
  bool get _turnVibration =>
      widget.preferences.getBool('seep.turnVibration') ?? true;

  Future<void> _soundDialog() => _overlay(() => showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) => ListenableBuilder(
              listenable: _sfx,
              builder: (context, child) => AlertDialog(
                      title: Text(textFor('sound_effects')),
                      content:
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        SwitchListTile(
                            key: const Key('turn-vibration'),
                            title: Text(textFor('turn_vibration')),
                            value: _turnVibration,
                            onChanged: (value) async {
                              await widget.preferences
                                  .setBool('seep.turnVibration', value);
                              if (context.mounted) refresh(() {});
                            }),
                        SwitchListTile(
                            key: const Key('sfx-enabled'),
                            title: Text(textFor('sound_effects')),
                            value: _sfx.enabled,
                            onChanged: _sfx.setEnabled),
                        Text(
                            '${textFor('sfx_volume')} · ${(_sfx.volume * 100).round()}%'),
                        Slider(
                            key: const Key('sfx-volume'),
                            value: _sfx.volume,
                            label: '${(_sfx.volume * 100).round()}%',
                            onChanged: _sfx.setVolume),
                      ]),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(textFor('close')))
                      ])))));
  String textFor(String key, [Map<String, Object?> args = const {}]) =>
      tr(context, key, args);

  Future<void> _languageDialog() => _overlay(() => showDialog<void>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Language / भाषा'),
          children: [
            for (final entry in {'en': 'English', 'hi': 'हिन्दी'}.entries)
              SimpleDialogOption(
                key: Key('language-${entry.key}'),
                onPressed: () {
                  LanguageScope.of(context).change(entry.key);
                  setState(() => _lastAction = null);
                  Navigator.pop(dialogContext);
                },
                child: Text(entry.value),
              )
          ],
        ),
      ));
  bool _atHome = true;
  bool _foreground = true;
  String? _error;
  String? _saveError;
  Timer? _botTimer;
  Timer? _openingCountdown;
  int _openingSeconds = 0;
  Future<void> _saveQueue = Future.value();
  late final Future<AppReporting?> _reporting;
  late final GoogleSession _session;
  Map<String, dynamic>? _completedReport;
  GameLog? _gameLog;
  late final Future<String> _reportPlatform = reportPlatform();
  String _clientGameId = const Uuid().v4();
  late final AnimationController _motion;
  Move? _moving;
  bool _showingFinalMove = false;
  List<int> _leftoverCards = [];
  int _leftoverSeat = 0;
  int? _selectedCard;
  Move? _preview;
  bool _paused = false;
  bool _menuWasPaused = false;
  double _pace = 1;
  String? _lastAction;
  void _update(VoidCallback action) => setState(action);

  Duration _duration(double factor) => Duration(
      milliseconds: (widget.botDelay.inMilliseconds * factor * _pace).round());

  bool get _canPlay =>
      !_paused &&
      _error == null &&
      _moving == null &&
      _game!.phase != Phase.results &&
      _game!.turn == 0;

  Future<void> _overlay(Future<void> Function() open) async {
    final wasPaused = _paused;
    _botTimer?.cancel();
    _openingCountdown?.cancel();
    _motion.stop();
    setState(() => _paused = true);
    try {
      await open();
    } finally {
      if (mounted) {
        setState(() => _paused = wasPaused);
        if ((_moving != null || _leftoverCards.isNotEmpty) &&
            !_paused &&
            _foreground &&
            !_atHome) {
          _motion.forward();
        } else {
          _scheduleBot();
        }
      }
    }
  }

  Map<String, dynamic>? _movingAnalysis;

  void _play(Move move, {Map<String, dynamic>? analysis}) {
    if (_paused || _moving != null) return;
    _dismissCardHint();
    unawaited(_sfx.play(Sfx.play));
    _botTimer?.cancel();
    _openingCountdown?.cancel();
    setState(() {
      _moving = move;
      _movingAnalysis = analysis;
      _selectedCard = null;
      _preview = null;
      _lastAction = null;
    });
    _motion.duration = _duration(1.4);
    _motion.forward(from: 0);
  }

  void _finishMove(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _moving == null &&
        _leftoverCards.isNotEmpty) {
      setState(() => _leftoverCards = []);
      unawaited(_sfx.play(Sfx.capture));
      _scheduleBot();
      return;
    }
    if (status != AnimationStatus.completed || _moving == null) return;
    final move = _moving!;
    final g = _game!;
    final leftovers = g.plays == 47
        ? [
            ...g.loose.where((c) => !move.selectedLoose.contains(c)),
            if (move.kind == MoveKind.discard) move.card
          ]
        : <int>[];
    final clear = move.kind == MoveKind.capture &&
        g.plays < 47 &&
        move.selectedLoose.length == g.loose.length &&
        move.houseIndexes.length == g.houses.length;
    _act(() {
      _lastAction = clear
          ? textFor('seep_pending',
              {'p0': playerName(context, g.turn), 'p1': g.plays == 0 ? 25 : 50})
          : '${playerName(context, g.turn)} · ${_moveLabel(move)}';
      g.play(move, botAnalysis: _movingAnalysis);
      if (move.kind == MoveKind.capture) {
        unawaited(_sfx.play(clear ? Sfx.sweep : Sfx.capture));
      }
      _movingAnalysis = null;
      _moving = null;
      _showingFinalMove = g.phase == Phase.results;
      if (leftovers.isNotEmpty) {
        _leftoverCards = leftovers;
        final recipients = [
          for (var s = 0; s < 4; s++)
            if (s % 2 == g.lastCaptureTeam) s
        ]..sort((a, b) => (g.lastCaptures[b]?.turn ?? -1)
            .compareTo(g.lastCaptures[a]?.turn ?? -1));
        _leftoverSeat = recipients.first;
        _lastAction = textFor('collects_leftover_cards_points_no_seep', {
          'p0': playerName(context, _leftoverSeat),
          'p1': leftovers.length,
          'p2': pointsOf(leftovers)
        });
      }
    });
    if (_leftoverCards.isNotEmpty) {
      _motion.duration = Duration(seconds: 3);
      _motion.forward(from: 0);
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _botTimer?.cancel();
      _openingCountdown?.cancel();
      _motion.stop();
    } else if (_moving != null || _leftoverCards.isNotEmpty) {
      _motion.forward();
    } else {
      _scheduleBot();
    }
  }

  void _openMenu() {
    _menuWasPaused = _paused;
    if (!_paused) _togglePause();
  }

  Future<void> _saveAnalysisSnapshot() async {
    final game = _game;
    if (game == null ||
        _gameLog == null ||
        _session.subject == null ||
        _session.user?['analysisEnabled'] != true) {
      return;
    }
    // Copy before any await: animations or bot turns must not alter this point.
    final log = _gameLog!.toJson();
    final payload = jsonDecode(jsonEncode({
      'user': {'email': _session.email, 'googleSubject': _session.subject},
      'clientGameId': _clientGameId,
      'clientSnapshotId': const Uuid().v4(),
      'dealNumber': game.dealNumber,
      'moveNumber': game.plays,
      'dealStatus': game.phase == Phase.results ? 'completed' : 'in_progress',
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': AppReporting.version,
      'botStrategy':
          _gameDifficulty == BotDifficulty.guest ? 'v0.5.0' : 'current',
      'snapshot': {
        'complete': log['complete'],
        'deal': (log['deals'] as List).last,
        'state': game.toJson()..remove('decisions'),
        'decisions':
            game.decisions.where((d) => d['deal'] == game.dealNumber).toList(),
      },
    })) as Map<String, dynamic>;
    try {
      final reporting = await _reporting;
      if (reporting == null) throw StateError('Reporting unavailable');
      await reporting.snapshots.enqueue(payload);
      unawaited(reporting.retry());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(textFor('analysis_queued'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(textFor('analysis_failed'))));
      }
    }
  }

  void _closeMenu() {
    if (!_menuWasPaused && _paused) _togglePause();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pace = widget.preferences.getDouble('sweep.pace') ?? 1;
    _motion = AnimationController(vsync: this)..addStatusListener(_finishMove);
    _session = widget.session ?? GoogleSession(widget.preferences);
    _session.addListener(_sessionChanged);
    unawaited(_session.initialize());
    _reporting = AppReporting.open(_session);
    // Save operations surface initialization errors without an unhandled future.
    unawaited(_reporting.then<void>((_) {}, onError: (Object _) {}));
    final saved = widget.preferences.getString(saveKey);
    if (saved != null) {
      try {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        _game = SweepGame.fromJson(data);
        _gameLog = data['fullGameLog'] is Map
            ? GameLog.restore(
                Map<String, dynamic>.from(data['fullGameLog'] as Map))
            : GameLog.start(_game!);
        _gameDifficulty = BotDifficulty.restore(data['botDifficulty'],
            signedIn: _session.subject != null);
        _clientGameId = data['clientGameId'] as String? ?? const Uuid().v4();
        _completedReport =
            (data['completedReport'] as Map?)?.cast<String, dynamic>();
      } catch (_) {
        _saveError = localized('the_saved_game_could_not_be_loaded',
            widget.preferences.getString('seep.language') ?? 'en');
      }
    }
    if (_game != null) _save();
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    if (widget.session == null) _session.dispose();
    unawaited(
        _reporting.then<void>((r) => r?.dispose(), onError: (Object _) {}));
    _botTimer?.cancel();
    _openingCountdown?.cancel();
    _motion.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sfx.setForeground(_foreground);
    if (_foreground) {
      if ((_moving != null || _leftoverCards.isNotEmpty) &&
          !_paused &&
          !_atHome) {
        _motion.forward();
      } else {
        _scheduleBot();
      }
    } else {
      _botTimer?.cancel();
      _openingCountdown?.cancel();
      _motion.stop();
      _save();
    }
  }

  void _save() {
    if (_game == null) return;
    if (_completedReport == null &&
        _gameDifficulty == BotDifficulty.low &&
        _game!.winner != null &&
        _game!.phase == Phase.results &&
        _session.subject != null) {
      _completedReport = completedGameReport(
          game: _game!,
          clientGameId: _clientGameId,
          email: _session.email!,
          googleSubject: _session.subject,
          displayName: _session.user?['displayName'] as String?,
          appVersion: AppReporting.version,
          fullGameLog: _gameLog?.toJson());
    }
    final report = _completedReport;
    final encoded = jsonEncode({
      ..._game!.toJson(),
      'clientGameId': _clientGameId,
      'botDifficulty': _gameDifficulty.name,
      if (_gameLog != null) 'fullGameLog': _gameLog!.toJson(),
      if (report != null) 'completedReport': report
    });
    _saveQueue = _saveQueue.then((_) async {
      try {
        var savedJson = encoded;
        if (report != null) {
          report['platform'] = await _reportPlatform;
          final envelope = jsonDecode(encoded) as Map<String, dynamic>;
          envelope['completedReport'] = report;
          savedJson = jsonEncode(envelope);
        }
        if (!await widget.preferences.setString(saveKey, savedJson)) {
          throw StateError('Save failed');
        }
        if (report != null) await (await _reporting)?.enqueue(report);
        if (mounted && _saveError != null) setState(() => _saveError = null);
      } catch (_) {
        if (mounted) {
          setState(
              () => _saveError = textFor('could_not_save_this_turn_keep_the'));
        }
      }
    });
  }

  void _scheduleBot() {
    _botTimer?.cancel();
    _openingCountdown?.cancel();
    if (_leftoverCards.isNotEmpty) return;
    final g = _game;
    if (mounted &&
        _foreground &&
        !_atHome &&
        !_paused &&
        _error == null &&
        _showingFinalMove &&
        g?.phase == Phase.results) {
      _botTimer = Timer(Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showingFinalMove = false);
          unawaited(_sfx.play(Sfx.score));
          if (g!.winner == 0) {
            unawaited(_sfx.play(Sfx.gameWin));
          } else if (g.winner == 1 || g.lastScores[0] < g.lastScores[1]) {
            unawaited(_sfx.play(Sfx.roundLose));
          } else if (g.lastScores[0] > g.lastScores[1]) {
            unawaited(_sfx.play(Sfx.roundWin));
          }
        }
      });
      return;
    }
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
    // Keep the revealed opening table visible before a bot acts. Speed settings
    // affect subsequent turns, not this time reserved for understanding the deal.
    final delay = g.phase == Phase.opening ? widget.openingDelay : _duration(1);
    if (g.phase == Phase.opening) {
      _openingSeconds = (delay.inMilliseconds / 1000).ceil();
      _openingCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _openingSeconds =
            ((delay.inMilliseconds / 1000).ceil() - timer.tick).clamp(0, 999));
        if (_openingSeconds == 0) timer.cancel();
      });
    }
    _botTimer = Timer(delay, () {
      if (!mounted || _atHome || !_foreground) return;
      final bot =
          GameBot(_gameDifficulty, g.seed + g.dealNumber * 53 + g.plays);
      if (g.phase == Phase.call) {
        _act(() {
          g.call(bot.chooseCall(g.position));
          _lastAction = textFor('calls',
              {'p0': playerName(context, g.turn), 'p1': g.calledValue});
        });
      } else {
        final move = bot.chooseMove(g.position);
        _play(move, analysis: bot.lastAnalysis);
      }
    });
  }

  void _act(void Function() action) {
    final oldGame = _game;
    final oldDeal = _game?.dealNumber;
    final oldPhase = _game?.phase;
    final oldTurn = _game?.turn;
    final committedMove = _moving;
    try {
      setState(action);
      if (_game != null) {
        if (_game != oldGame) _gameLog = GameLog.start(_game!);
        _gameLog?.record(_game!, move: committedMove);
      }
      if (_game != oldGame ||
          _game?.dealNumber != oldDeal ||
          (oldPhase == Phase.opening && _game?.phase == Phase.playing)) {
        unawaited(_sfx.play(Sfx.deal));
      }
      if (_game?.turn == 0 &&
          _game?.phase != Phase.results &&
          (oldTurn != 0 || oldDeal != _game?.dealNumber)) {
        unawaited(_sfx.play(Sfx.turn));
        if (_turnVibration && _foreground && !_atHome) {
          unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
        }
      }
      _save();
      _scheduleBot();
    } catch (e) {
      unawaited(_sfx.play(Sfx.invalid));
      setState(() => _error = textFor('play_paused', {'p0': e}));
      _botTimer?.cancel();
      _openingCountdown?.cancel();
    }
  }

  Future<void> _newGame() async {
    // Keep a completed save until its report has been durably queued.
    if (_game?.winner != null) {
      _save();
      await _saveQueue;
      if (!mounted || _saveError != null) return;
    }
    if (_game != null && _game!.winner == null) {
      final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(textFor('start_a_new_game')),
                  content: Text(textFor('this_replaces_your_saved_game')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(textFor('keep_game'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(textFor('new_game')))
                  ]));
      if (replace != true || !mounted) return;
    }
    _startFreshGame();
  }

  void _startFreshGame() {
    _botTimer?.cancel();
    _openingCountdown?.cancel();
    _motion.stop();
    _moving = null;
    _movingAnalysis = null;
    _leftoverCards = [];
    _showingFinalMove = false;
    _act(() {
      _gameDifficulty = _newDifficulty;
      _game = SweepGame.newGame();
      _clientGameId = const Uuid().v4();
      _completedReport = null;
      _atHome = false;
      _error = null;
      _paused = false;
      _selectedCard = null;
      _preview = null;
      _lastAction = null;
    });
  }

  void _home() {
    _sfx.stop();
    _botTimer?.cancel();
    _openingCountdown?.cancel();
    _motion.stop();
    _moving = null;
    _showingFinalMove = false;
    _leftoverCards = [];
    _selectedCard = null;
    _preview = null;
    _save();
    setState(() => _atHome = true);
  }

  Future<void> _rules() async {
    final rules = await rootBundle.loadString(
        playerGuideAsset(Localizations.localeOf(context).languageCode));
    if (!mounted) return;
    await _overlay(() => showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
            child: Scaffold(
                appBar: AppBar(
                    title: Text(textFor('how_to_play')),
                    leading: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close))),
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(rules,
                        style: TextStyle(fontSize: 16, height: 1.5)))))));
  }

  Future<void> _history() => _overlay(() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(children: [
                Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(textFor('deal_log'),
                        style: TextStyle(fontSize: 22))),
                if (_game!.reviewableDecisions.isNotEmpty)
                  TextButton.icon(
                    icon: Icon(Icons.analytics_outlined),
                    label: Text(textFor('review_completed_deal_decisions')),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) {
                          final report = const JsonEncoder.withIndent('  ')
                              .convert(_game!.reviewableDecisions);
                          return AlertDialog(
                            title: Text(textFor('decision_diagnostics')),
                            content: SizedBox(
                                width: 640,
                                child: SingleChildScrollView(
                                    child: SelectableText(report))),
                            actions: [
                              TextButton(
                                  onPressed: () => Clipboard.setData(
                                      ClipboardData(text: report)),
                                  child: Text(textFor('copy_diagnostics'))),
                              TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(textFor('close'))),
                            ],
                          );
                        }),
                  ),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                        textFor(
                            'hands_and_decision_details_become_available_after'),
                        style: TextStyle(fontSize: 12))),
                Expanded(
                    child: ListView(
                        children: _game!.historyEvents.reversed
                            .map((s) =>
                                ListTile(title: Text(historyText(context, s))))
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
              toolbarHeight: 48,
              title: Text(textFor('seep'),
                  style: TextStyle(fontSize: 18, letterSpacing: 2)),
              leading: _atHome
                  ? null
                  : IconButton(
                      key: Key('home'),
                      tooltip: textFor('save_and_return_home'),
                      onPressed: _home,
                      icon: Icon(Icons.home_outlined)),
              actions: [
                IconButton(
                    key: const Key('language'),
                    tooltip: 'Language / भाषा',
                    onPressed: _languageDialog,
                    icon: const Icon(Icons.language)),
                if (!_atHome && _game!.phase != Phase.results) ...[
                  IconButton(
                      key: Key('pause'),
                      onPressed: _togglePause,
                      tooltip: _paused
                          ? textFor('resume_play')
                          : textFor('pause_play'),
                      icon: Icon(_paused ? Icons.play_arrow : Icons.pause)),
                ],
                if (!_atHome)
                  IconButton(
                      key: Key('scores'),
                      tooltip: textFor('scores'),
                      onPressed: _showScores,
                      icon: Icon(Icons.scoreboard_outlined)),
                PopupMenuButton<String>(
                    tooltip: textFor('game_menu'),
                    onOpened: _openMenu,
                    onCanceled: _closeMenu,
                    icon: Icon(Icons.more_horiz),
                    onSelected: (value) {
                      _closeMenu();
                      if (value == 'analysis') {
                        _saveAnalysisSnapshot();
                      } else if (value == 'rules') {
                        _rules();
                      } else if (value == 'history') {
                        _history();
                      } else if (value == 'sound') {
                        _soundDialog();
                      } else {
                        setState(() => _pace =
                            {'slow': 1.6, 'normal': 1.0, 'fast': .5}[value]!);
                        widget.preferences.setDouble('sweep.pace', _pace);
                        _scheduleBot();
                      }
                    },
                    itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'sound',
                              child: Text(textFor('sound_effects'))),
                          PopupMenuItem<String>(
                              enabled: false,
                              child: Text(textFor('turn_speed'))),
                          for (final entry in {
                            'slow': textFor('slow'),
                            'normal': textFor('normal'),
                            'fast': textFor('fast')
                          }.entries)
                            CheckedPopupMenuItem<String>(
                                value: entry.key,
                                checked: _pace ==
                                    {
                                      'slow': 1.6,
                                      'normal': 1.0,
                                      'fast': .5
                                    }[entry.key],
                                child: Text(entry.value)),
                          PopupMenuDivider(),
                          if (!_atHome &&
                              _game != null &&
                              _session.subject != null &&
                              _session.user?['analysisEnabled'] == true)
                            PopupMenuItem(
                                value: 'analysis',
                                child: Text(textFor('save_analysis'))),
                          if (!_atHome)
                            PopupMenuItem(
                                value: 'history',
                                child: Text(textFor('deal_log'))),
                          PopupMenuItem(
                              value: 'rules',
                              child: Text(textFor('how_to_play'))),
                        ]),
              ]),
          body: SafeArea(
              child: Column(children: [
            if (_saveError != null)
              MaterialBanner(content: Text(_saveError!), actions: [
                TextButton(onPressed: _save, child: Text(textFor('retry')))
              ]),
            if (_error != null && !_atHome)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.orangeAccent))),
            Expanded(
                child: _atHome
                    ? _homeBody()
                    : _game!.phase == Phase.results && !_showingFinalMove
                        ? _results()
                        : _table())
          ]))));

  void _sessionChanged() {
    if (!mounted) return;
    if (_session.verified &&
        _game != null &&
        _game!.winner == null &&
        _gameDifficulty == BotDifficulty.guest) {
      _startFreshGame();
    } else {
      setState(() {});
    }
  }

  Future<void> _signIn() async {
    await _session.signIn();
    if (!mounted) return;
    if (_session.verified && _game == null) _startFreshGame();
    _save();
    try {
      await (await _reporting)?.retry(afterSignIn: true);
    } catch (_) {}
  }

  Widget _homeBody() => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(textFor('a_good_hand_a_better_partnership'),
                        style: TextStyle(
                            fontSize: 36, height: 1.15, color: cream)),
                    SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final card in [48, 22, 51])
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: CardFace(card: card, large: true))
                    ]),
                    SizedBox(height: 24),
                    Text(textFor('gurubox_presentation'),
                        style: TextStyle(fontSize: 20, color: gold)),
                    SizedBox(height: 12),
                    Text(textFor('build_houses_capture_points_and_clear_the'),
                        style: TextStyle(height: 1.6, fontSize: 16)),
                    SizedBox(height: 28),
                    if (_game != null) ...[
                      FilledButton(
                          key: Key('resume'),
                          onPressed: () {
                            setState(() => _atHome = false);
                            _scheduleBot();
                          },
                          child: Text(_game!.winner != null
                              ? textFor('view_game_result')
                              : textFor(
                                  'resume_deal', {'p0': _game!.dealNumber}))),
                      SizedBox(height: 12)
                    ],
                    OutlinedButton(
                        key: Key('new-game'),
                        onPressed: _newGame,
                        child: Text(textFor('new_game'))),
                    if (_session.supported) ...[
                      if (_session.email != null)
                        Text(_session.email!, textAlign: TextAlign.center),
                      if (_session.email != null && !_session.verified)
                        Text(textFor('login_offline'),
                            textAlign: TextAlign.center),
                      if (_session.email == null || !_session.verified)
                        OutlinedButton.icon(
                            key: const Key('google-sign-in'),
                            onPressed: _session.busy ? null : _signIn,
                            icon: const Icon(Icons.account_circle_outlined),
                            label: Text(textFor(_session.busy
                                ? 'login_wait'
                                : 'login_google'))),
                      if (_session.email != null)
                        TextButton(
                            onPressed: _session.busy ? null : _session.signOut,
                            child: Text(textFor('login_sign_out'))),
                      if (_session.errorKey != null)
                        Text(textFor(_session.errorKey!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.orangeAccent)),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(height: 16),
                    Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                              label: Text(textFor('difficulty_easy')),
                              selected: true,
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) {}),
                          for (final level in ['medium', 'hard'])
                            ChoiceChip(
                                label:
                                    Text(textFor('difficulty_${level}_short')),
                                visualDensity: VisualDensity.compact,
                                selected: false,
                                onSelected: null),
                        ]),
                    const SizedBox(height: 16),
                    Text(
                        textFor('choose_a_card_light_up_the_table',
                            {'version': AppReporting.version.split('+').first}),
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
                constraints: BoxConstraints(maxWidth: 620),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          g.winner == null
                              ? textFor('deal_complete_2')
                              : g.winner == 0
                                  ? textFor('you_and_ari_win')
                                  : textFor('mira_and_dev_win'),
                          style: TextStyle(fontSize: 32, color: gold)),
                      SizedBox(height: 12),
                      Text(g.winner == null
                          ? textFor('a_lead_of_after_a_completed_deal')
                          : textFor('final_lead_points',
                              {'p0': (g.totals[0] - g.totals[1]).abs()})),
                      SizedBox(height: 24),
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
                                  Text(
                                      team == 0
                                          ? textFor('you_ari_2')
                                          : textFor('mira_dev_2'),
                                      style: TextStyle(
                                          fontSize: 22, color: cream)),
                                  SizedBox(height: 12),
                                  _scoreLine(textFor('captured_card_points'),
                                      g.score(team).cardPoints),
                                  _scoreLine(textFor('eligible_seep_bonus'),
                                      g.score(team).eligibleSweepPoints),
                                  if (g.score(team).earnedSweepPoints >
                                      g.score(team).eligibleSweepPoints)
                                    Text(
                                        textFor(
                                            'seep_points_discarded_fewer_than_card_points',
                                            {
                                              'p0': g
                                                  .score(team)
                                                  .earnedSweepPoints
                                            }),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orangeAccent)),
                                  Divider(),
                                  _scoreLine(textFor('this_deal_2'),
                                      g.lastScores[team]),
                                  _scoreLine(
                                      textFor('game_total'), g.totals[team])
                                ])),
                      if (g.winner == null) ...[
                        Text(
                            textFor('next_dealer_counted_losses_ties', {
                              'p0': playerName(context, g.nextDealer.$1),
                              'p1': g.nextDealer.$2
                            }),
                            textAlign: TextAlign.center),
                        SizedBox(height: 18),
                        FilledButton(
                            key: Key('next-deal'),
                            onPressed: () => _act(() {
                                  _lastAction = null;
                                  g.continueGame();
                                }),
                            child: Text(textFor('next_deal')))
                      ] else
                        FilledButton(
                            onPressed: _newGame,
                            child: Text(textFor('play_again'))),
                      SizedBox(height: 12),
                      TextButton(
                          onPressed: _home,
                          child: Text(textFor('save_and_return_home')))
                    ]))));
  }

  Widget _scoreLine(String title, int points) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(title)),
        Text('$points', style: TextStyle(fontWeight: FontWeight.bold))
      ]));
}
