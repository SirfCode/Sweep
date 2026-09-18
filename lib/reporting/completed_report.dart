import '../game/engine.dart';

/// Called only when a complete multi-deal game has a winner, never per turn/deal.
Map<String, dynamic> completedGameReport({
  required SweepGame game,
  required String clientGameId,
  required String email,
  required String appVersion,
  String? displayName,
  String platform = 'android',
  Map<String, dynamic>? fullGameLog,
}) {
  if (game.winner == null || game.phase != Phase.results) {
    throw StateError('Only a completed full game can be reported');
  }
  return {
    'user': {'email': email.trim().toLowerCase(), 'displayName': displayName},
    'clientGameId': clientGameId,
    'appVersion': appVersion,
    'platform': platform,
    'dealCount': game.dealNumber,
    'humanTeam': 0,
    'winnerTeam': game.winner,
    'userWon': game.winner == 0,
    'team0Total': game.totals[0],
    'team1Total': game.totals[1],
    'summary': {
      'deals': game.dealNumber,
      'winnerTeam': game.winner,
      'userWon': game.winner == 0,
      'totals': List<int>.of(game.totals),
    },
    if (fullGameLog != null) 'gameLog': fullGameLog,
  };
}
