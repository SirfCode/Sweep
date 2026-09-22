import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweep/main.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/game/bot.dart';
import 'package:sweep/l10n/catalog.dart';
import 'package:sweep/l10n/strings.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('NotoDevanagari')
      ..addFont(File('assets/fonts/NotoSansDevanagari.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
    await loader.load();
  });

  test('English and Hindi have matching complete message placeholders', () {
    expect(localized('discard', 'en'), 'Throw');
    expect(localized('discard', 'hi'), 'फेंकें');
    final placeholders = RegExp(r'\{p\d+\}');
    for (final entry in messageCatalog.entries) {
      expect(entry.value.keys, containsAll(['en', 'hi']));
      expect(entry.value['hi'], isNotEmpty);
      expect(
          placeholders.allMatches(entry.value['en']!).map((m) => m[0]).toSet(),
          placeholders.allMatches(entry.value['hi']!).map((m) => m[0]).toSet(),
          reason: entry.key);
      expect(entry.value['en']!.toLowerCase(), isNot(contains('sweep')));
    }
  });

  for (final size in [const Size(390, 844), const Size(780, 360)]) {
    testWidgets('Hindi switches in place, persists, and fits $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final game = SweepGame.newGame(seed: 42, dealer: 3);
      game.call(game.position.calls.first);
      SharedPreferences.setMockInitialValues(
          {saveKey: jsonEncode(game.toJson())});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(SweepApp(preferences: prefs));
      expect(find.text('Seep'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('resume')));
      await tester.tap(find.byKey(const Key('resume')));
      await tester.pumpAndSettle();
      final saved = prefs.getString(saveKey);
      await tester.tap(find.byKey(const Key('language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-hi')));
      await tester.pumpAndSettle();
      expect(find.text('सीप'), findsOneWidget);
      expect(prefs.getString('seep.language'), 'hi');
      expect(prefs.getString(saveKey), saved);
      expect(Directionality.of(tester.element(find.byKey(const Key('scores')))),
          TextDirection.ltr);
      await tester.tap(find.byKey(const Key('scores')));
      await tester.pumpAndSettle();
      expect(find.text('अंक · बाज़ी 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('close-scores')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('last-capture-player-0')));
      await tester.pumpAndSettle();
      expect(find.text('आप · पिछली उठान'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('बंद करें'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(SweepApp(preferences: prefs));
      await tester.pumpAndSettle();
      expect(find.text('सीप'), findsOneWidget);
      await tester.tap(find.byKey(const Key('language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-en')));
      await tester.pumpAndSettle();
      expect(find.text('Seep'), findsOneWidget);
      expect(prefs.getString(saveKey), saved);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'device Hindi is selected and unsupported language falls back to English',
      (tester) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('hi')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.pumpAndSettle();
    expect(find.text('सीप'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ar')];
    await tester.pumpWidget(SweepApp(preferences: prefs));
    await tester.pumpAndSettle();
    expect(find.text('Seep'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Seep'))),
        TextDirection.ltr);
  });

  testWidgets(
      'public events translate after reload and old history remains readable',
      (tester) async {
    final g = SweepGame.newGame(seed: 42);
    final bot = SweepBot(1);
    g.call(bot.chooseCall(g.position));
    g.play(bot.tacticalMove(g.position));
    final resumed = SweepGame.fromJson(g.toJson());
    expect(resumed.historyEvents, g.historyEvents);
    SharedPreferences.setMockInitialValues({'seep.language': 'hi'});
    await tester.pumpWidget(
        SweepApp(preferences: await SharedPreferences.getInstance()));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('सीप'));
    expect(historyText(context, resumed.historyEvents[1]), contains('बोली'));
    final old = g.toJson()..remove('historyEvents');
    expect(
        SweepGame.fromJson(old).historyEvents.map((e) => e['text']), g.history);
  });
}
