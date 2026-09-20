import 'bot.dart';
import 'guest_bot.dart';
import 'engine.dart';

enum BotDifficulty {
  guest,
  low,
  medium,
  hard;

  bool get enabled => this == guest || this == low;
  static BotDifficulty forAccount(bool signedIn) => signedIn ? low : guest;
  static BotDifficulty restore(Object? saved, {required bool signedIn}) =>
      switch (saved) {
        'guest' => guest,
        'low' => low,
        _ => forAccount(signedIn),
      };
}

/// All three seats use the policy saved with the game.
class GameBot {
  final BotDifficulty difficulty;
  final GuestBot? _guest;
  final SweepBot? _low;
  GameBot(this.difficulty, int seed)
      : _guest = difficulty == BotDifficulty.guest ? GuestBot(seed) : null,
        _low = difficulty == BotDifficulty.low ? SweepBot(seed) : null {
    if (!difficulty.enabled) throw ArgumentError('Difficulty not implemented');
  }
  int chooseCall(Position p) => _guest?.chooseCall(p) ?? _low!.chooseCall(p);
  Move chooseMove(Position p) => _guest?.chooseMove(p) ?? _low!.chooseMove(p);
  Map<String, dynamic> get lastAnalysis => {
        if (_low != null) ..._low.lastAnalysis,
        'difficulty': difficulty.name,
        'strategy': _guest != null ? 'v0.5.0' : 'current',
      };
}
