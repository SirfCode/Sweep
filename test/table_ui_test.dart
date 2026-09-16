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

void main() {
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

  SweepGame saved(SharedPreferences prefs) => SweepGame.fromJson(
      jsonDecode(prefs.getString(saveKey)!) as Map<String, dynamic>);

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
      expect(find.byType(PlayerSeat), findsNWidgets(4));
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
    await tester.tap(find.byKey(const Key('confirm-move')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Deal log'));
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
    await tester.tap(find.byTooltip('Turn speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<double>, 'Slow'));
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
