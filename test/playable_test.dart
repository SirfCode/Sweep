import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweep/main.dart';
import 'package:sweep/game/engine.dart';

void main() {
  Future<SharedPreferences> preferences(SweepGame game) async {
    SharedPreferences.setMockInitialValues(
        {saveKey: jsonEncode(game.toJson())});
    return SharedPreferences.getInstance();
  }

  SweepGame saved(SharedPreferences prefs) => SweepGame.fromJson(
      jsonDecode(prefs.getString(saveKey)!) as Map<String, dynamic>);

  testWidgets('human can complete a deal through previews, then resume results',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await preferences(SweepGame.newGame(seed: 42, dealer: 3));
    await tester.pumpWidget(SweepApp(
        preferences: prefs, botDelay: const Duration(milliseconds: 100)));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    for (var step = 0; step < 100; step++) {
      final g = saved(prefs);
      if (g.phase == Phase.results) break;
      if (g.turn != 0) {
        await tester.pump(const Duration(milliseconds: 200));
        continue;
      }
      if (g.phase == Phase.call) {
        await tester.tap(find.byKey(Key('call-${g.position.calls.first}')));
      } else {
        final legal = g.position.legalMoves()
          ..sort((a, b) => rankOf(a.card).compareTo(rankOf(b.card)));
        final target = find.byKey(Key('hand-${legal.first.card}'));
        await tester.tapAt(tester.getTopLeft(target) + const Offset(9, 12));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('move-0')));
        await tester.pumpAndSettle();
        expect(saved(prefs).plays, g.plays,
            reason: 'Preview must not commit a turn');
        await tester.tap(find.byKey(const Key('confirm-move')));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    final result = saved(prefs);
    expect(result.phase, Phase.results);
    expect(result.plays, 48);
    result.validate();
    final totals = result.totals.toList();
    await tester.tap(find.byKey(const Key('home')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    expect(saved(prefs).totals, totals);
    expect(find.text('Captured card points'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opening call fits a small landscape phone and home pauses bots',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(780, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await preferences(SweepGame.newGame(seed: 42, dealer: 3));
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.ensureVisible(find.byKey(const Key('resume')));
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('hidden-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home')));
    await tester.pumpAndSettle();
    final before = prefs.getString(saveKey);
    await tester.pump(const Duration(seconds: 5));
    expect(prefs.getString(saveKey), before);
    await tester.pumpWidget(const SizedBox());
  });
}
