import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/game/bot.dart';
import 'package:sweep/main.dart';
import 'package:sweep/table_art.dart';
import 'fixtures.dart';
import 'package:sweep/game/scoring.dart';

SweepGame saved(SharedPreferences prefs) => SweepGame.fromJson(
    jsonDecode(prefs.getString(saveKey)!) as Map<String, dynamic>);

void main() {
  testWidgets('leftovers visibly reach the last capturer before scores',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = SweepGame.newGame(seed: 42, dealer: 3)
      ..phase = Phase.playing
      ..turn = 0
      ..plays = 47
      ..deck = []
      ..hands = [
        [50],
        [],
        [],
        []
      ]
      ..loose = [9, 0]
      ..houses = []
      ..lastCaptureTeam = 1
      ..lastCaptures = [
        null,
        null,
        null,
        LastCapture([1, 14], 45, 0)
      ]
      ..captured = [
        [],
        [
          for (var c = 0; c < 52; c++)
            if (![50, 9, 0].contains(c)) c
        ]
      ];
    game.validate();
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hand-50')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump();
    expect(find.byKey(const Key('leftover-flight')), findsOneWidget);
    expect(
        find.text('Leftover cards → JLo\n13 points · No seep'), findsOneWidget);
    final totals = saved(prefs).totals.toList();
    expect(saved(prefs).captured[1], containsAll([50, 9, 0]));
    await tester.tap(find.byKey(const Key('last-capture-player-2')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const Key('leftover-flight')), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const Key('leftover-flight')), findsNothing);
    expect(find.text('Captured card points'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Captured card points'), findsNWidgets(2));
    expect(saved(prefs).totals, totals);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each player opens only their latest capture on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = SweepGame.newGame(seed: 42, dealer: 3);
    game.call(game.position.calls.first);
    game.lastCaptures = [
      LastCapture([0, 13], 4, 25),
      LastCapture([39, 26], 5, 0),
      LastCapture(List.generate(20, (c) => c), 6, 50),
      null,
    ];
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    for (var seat = 0; seat < 4; seat++) {
      await tester.tap(find.byKey(Key('last-capture-player-$seat')));
      await tester.pumpAndSettle();
      expect(find.text('${seatNames[seat]} · Latest capture'), findsOneWidget);
      final capture = game.lastCaptures[seat];
      if (capture == null) {
        expect(
            find.text('No capture recorded in this deal yet.'), findsOneWidget);
      } else {
        expect(find.text('${pointsOf(capture.cards)} card points'),
            findsOneWidget);
        for (final card in capture.cards) {
          expect(find.byKey(Key('last-capture-card-$card')), findsOneWidget);
        }
      }
      final state = prefs.getString(saveKey);
      await tester.pump(const Duration(seconds: 35));
      expect(prefs.getString(saveKey), state);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('final move stays visible for five seconds before scores',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = SweepGame.newGame(seed: 42, dealer: 3);
    game.phase = Phase.playing;
    game.turn = 0;
    game.plays = 47;
    game.deck = [];
    game.hands = [
      [48],
      [],
      [],
      []
    ];
    game.loose = [9];
    game.houses = [];
    game.captured = [
      [
        for (var c = 0; c < 52; c++)
          if (c != 48 && c != 9) c
      ],
      []
    ];
    game.validate();
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hand-48')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(const Key('sweep-celebration')), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(saved(prefs).phase, Phase.results);
    expect(find.textContaining('Seep!'), findsNothing);
    expect(saved(prefs).score(0).earnedSweepPoints, 0);
    expect(saved(prefs).sweeps[0], isEmpty);
    expect(
        tester.widget<Text>(find.byKey(const Key('live-sweeps-0'))).data, '0');
    final totals = saved(prefs).totals.toList();
    expect(find.text('Scores in a moment…'), findsOneWidget);
    expect(find.text('Captured card points'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Captured card points'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Captured card points'), findsNWidgets(2));
    expect(saved(prefs).totals, totals);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'both teams show live deal points and sweeps separately from game totals',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = twoTensGame();
    game.totals = [145, 155];
    game.sweeps = [
      [SweepTiming.opening, SweepTiming.intermediate],
      [SweepTiming.intermediate]
    ];
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('score-card-points-0')), findsNothing);
    String live(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(live('live-points-0'), '${game.score(0).cardPoints}');
    expect(live('live-points-1'), '0');
    expect(live('live-sweeps-0'), '2');
    expect(live('live-sweeps-1'), '1');
    await tester.tap(find.byKey(const Key('scores')));
    await tester.pumpAndSettle();
    String label(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(label('score-game-total-0'), 'Game 145');
    expect(label('score-game-total-1'), 'Game 155');
    expect(
        label('score-card-points-0'), '${game.score(0).cardPoints} card pts');
    expect(label('score-card-points-1'), '0 card pts');
    expect(label('score-sweeps-0'), '2 seeps');
    expect(label('score-sweeps-1'), '1 seeps');
    expect(label('score-sweep-points-0'), contains('+75 seep pts'));
    expect(label('score-sweep-points-1'), contains('need 20 card pts'));
    await tester.tap(find.byKey(const Key('close-scores')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hand-48')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump();
    expect(live('live-points-0'), '${game.score(0).cardPoints + 10}');
    await tester.tap(find.byKey(const Key('scores')));
    await tester.pumpAndSettle();
    expect(label('score-card-points-0'),
        '${game.score(0).cardPoints + 10} card pts');
    expect(label('score-game-total-0'), 'Game 145');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('bot reveals the call then waits 20 seconds even on Fast',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = SweepGame.newGame(seed: 42, dealer: 0);
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson()), 'sweep.pace': .5});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    expect(saved(prefs).phase, Phase.opening);
    expect(find.byKey(const Key('hidden-0')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('table-call')),
            matching: find.text(rankName(saved(prefs).calledValue!))),
        findsOneWidget);
    expect(find.textContaining('20s to study the table'), findsOneWidget);
    await tester.pump(const Duration(seconds: 19));
    expect(saved(prefs).plays, 0);
    expect(find.textContaining('20s to study the table'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('20s to study the table'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(saved(prefs).plays, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('human opening waits beyond 30 seconds for confirmation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = SweepGame.newGame(seed: 42, dealer: 3);
    game.call(game.position.calls.first);
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(saved(prefs).phase, Phase.opening);
    expect(saved(prefs).turn, 0);
    expect(saved(prefs).plays, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('loose ten offers Capture and Build 10 and creates a pakka house',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = twoTensGame();
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hand-48')));
    await tester.pumpAndSettle();
    expect(find.text('Capture'), findsWidgets);
    expect(find.text('Build 10'), findsOneWidget);
    final options =
        game.position.legalMoves().where((m) => m.card == 48).toList();
    final index = options.indexWhere((m) => m.kind == MoveKind.build);
    await tester.tap(find.byKey(Key('move-$index')));
    await tester.pumpAndSettle();
    expect(saved(prefs).plays, 39);
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump();
    final result = saved(prefs);
    expect(result.houses.singleWhere((h) => h.value == 10).pakka, isTrue);
    expect(result.hands[0], [0, 22]);
    result.validate();
    await tester.pumpWidget(const SizedBox());
  });
  setUpAll(() async {
    if (!const bool.fromEnvironment('UPDATE_SCREENSHOTS') ||
        !Platform.isWindows) {
      return;
    }
    final windows = Platform.environment['WINDIR'] ?? 'C:/Windows';
    final artifacts =
        File(Platform.resolvedExecutable).parent.parent.parent.path;
    for (final entry in {
      'Roboto': '$windows/Fonts/segoeui.ttf',
      'Georgia': '$windows/Fonts/georgia.ttf',
      'MaterialIcons': '$artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value)
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });
  Future<SharedPreferences> launch(WidgetTester tester, Size size,
      {bool dealt = false}) async {
    await tester.binding.setSurfaceSize(size);
    final game = SweepGame.newGame(seed: 42, dealer: 3);
    game.call(game.position.calls.first);
    if (dealt) {
      final bot = SweepBot(42);
      do {
        game.play(bot.chooseMove(game.position));
      } while (game.turn != 0);
    }
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(RepaintBoundary(
        key: const Key('capture'), child: SweepApp(preferences: prefs)));
    await tester.ensureVisible(find.byKey(const Key('resume')));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> select(WidgetTester tester, SharedPreferences prefs) async {
    final card = saved(prefs).position.legalMoves().first.card;
    await tester.tapAt(
        tester.getTopLeft(find.byKey(Key('hand-$card'))) + const Offset(9, 12));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UPDATE_SCREENSHOTS')) return;
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const Key('capture')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('artifacts/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final entry in {
    'desktop': const Size(1280, 850),
    'portrait': const Size(390, 844),
    'landscape': const Size(780, 360),
    'small': const Size(360, 640)
  }.entries) {
    testWidgets('table and visual selection fit ${entry.key}', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final prefs = await launch(tester, entry.value, dealt: true);
      expect(find.byType(PlayerSeat), findsNWidgets(3));
      await capture(tester, 'v0.2-${entry.key}');
      await select(tester, prefs);
      expect(find.byKey(const Key('confirm-move')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final before = prefs.getString(saveKey);
      await capture(tester, 'v0.2-${entry.key}-selection');
      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();
      expect(prefs.getString(saveKey), before);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('inspection and backgrounding freeze an in-flight turn',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await launch(tester, const Size(1000, 800));
    await select(tester, prefs);
    final selected = tester
        .widgetList<CardFace>(find.byType(CardFace))
        .firstWhere(
            (card) => card.highlighted && card.key.toString().contains('hand-'))
        .card;
    final visibility = find.byKey(Key('hand-visibility-$selected'));
    expect(tester.widget<Visibility>(visibility).visible, isTrue);
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    expect(tester.widget<Visibility>(visibility).visible, isFalse);
    expect(tester.widget<Visibility>(visibility).maintainSize, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Game menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deal log'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(saved(prefs).plays, 0);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(saved(prefs).plays, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(saved(prefs).plays, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('slow speed is saved and gives the move more time',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await launch(tester, const Size(1000, 800));
    await tester.tap(find.byTooltip('Game menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<String>, 'Slow'));
    await tester.pumpAndSettle();
    expect(prefs.getDouble('sweep.pace'), 1.6);
    await select(tester, prefs);
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    expect(saved(prefs).plays, 0);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(saved(prefs).plays, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'pause freezes a move; resume commits once; home cancels an uncommitted animation',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await launch(tester, const Size(1000, 800));
    await select(tester, prefs);
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(saved(prefs).plays, 0);
    await tester.tap(find.byKey(const Key('pause')));
    await tester.pump(const Duration(seconds: 20));
    expect(saved(prefs).plays, 0);
    await tester.tap(find.byKey(const Key('pause')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(saved(prefs).plays, 1);
    // Next bot begins, but returning home must preserve the last completed turn.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.tap(find.byKey(const Key('home')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(saved(prefs).plays, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
