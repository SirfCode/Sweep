import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweep/auth/google_session.dart';
import 'package:sweep/game/bot.dart';
import 'package:sweep/game/difficulty.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/game/guest_bot.dart';
import 'package:sweep/main.dart';

class TestSession extends GoogleSession {
  bool succeed = false;
  TestSession(super.preferences);
  @override
  bool get supported => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> signIn() async {
    if (succeed) {
      user = {'email': 'test@example.com', 'googleSubject': 'test-sub'};
      verified = true;
    } else {
      errorKey = 'login_verify_failed';
    }
    notifyListeners();
  }
}

void main() {
  test(
      'guest policy matches v0.5 decisions throughout a legal current-engine deal',
      () {
    final game = SweepGame.newGame(seed: 29, dealer: 3);
    final guest = GameBot(BotDifficulty.guest, 41);
    final original = GuestBot(41);
    expect(guest.chooseCall(game.position), original.chooseCall(game.position));
    game.call(guest.chooseCall(game.position));
    while (game.phase != Phase.results) {
      final move = guest.chooseMove(game.position);
      expect(move.key, original.chooseMove(game.position).key);
      game.play(move);
      game.validate();
    }
    expect(guest.lastAnalysis['strategy'], 'v0.5.0');
  });

  test('Low uses current strategy and future levels cannot run', () {
    final game = SweepGame.newGame(seed: 42, dealer: 3);
    final bot = GameBot(BotDifficulty.low, 18);
    final current = SweepBot(18);
    expect(bot.chooseCall(game.position), current.chooseCall(game.position));
    game.call(game.position.calls.first);
    expect(bot.chooseMove(game.position).key,
        current.chooseMove(game.position).key);
    for (final difficulty in [BotDifficulty.medium, BotDifficulty.hard]) {
      expect(() => GameBot(difficulty, 1), throwsArgumentError);
    }
    expect(BotDifficulty.restore('low', signedIn: false), BotDifficulty.low);
    expect(BotDifficulty.restore(null, signedIn: true), BotDifficulty.low);
    expect(BotDifficulty.restore(null, signedIn: false), BotDifficulty.guest);
  });

  testWidgets(
      'failed login preserves guest game; successful login starts Low once',
      (tester) async {
    final game = SweepGame.newGame(seed: 42, dealer: 3);
    game.call(game.position.calls.first);
    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        ...game.toJson(),
        'clientGameId': 'guest-game',
        'botDifficulty': 'guest'
      })
    });
    final prefs = await SharedPreferences.getInstance();
    final session = TestSession(prefs);
    await tester.pumpWidget(SweepApp(
        preferences: prefs,
        session: session,
        botDelay: const Duration(days: 1)));
    await tester.pumpAndSettle();
    final before = prefs.getString(saveKey);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      if (!chip.selected) expect(chip.onSelected, isNull);
    }
    await tester.ensureVisible(find.byKey(const Key('google-sign-in')));
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    expect(prefs.getString(saveKey), before);
    session.succeed = true;
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    final after = jsonDecode(prefs.getString(saveKey)!) as Map;
    expect(after['botDifficulty'], 'low');
    expect(after['clientGameId'], isNot('guest-game'));
    expect(after['completedReport'], isNull);
    final fresh = SweepGame.fromJson(Map<String, dynamic>.from(after));
    expect(fresh.phase, Phase.call);
    expect(fresh.plays, 0);
    final id = after['clientGameId'];
    session.notifyListeners();
    await tester.pump();
    expect((jsonDecode(prefs.getString(saveKey)!) as Map)['clientGameId'], id);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
