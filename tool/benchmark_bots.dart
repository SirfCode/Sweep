import 'dart:math';
import 'dart:io';
import 'package:sweep/game/engine.dart';
import 'package:sweep/game/bot.dart';
import '../test/support/legacy_bot.dart';

void main(List<String> args) {
  final seeds = args.isEmpty ? 20 : int.parse(args.first);
  var wins = 0, losses = 0, margin = 0, sweepsFor = 0, sweepsAgainst = 0;
  final timings = <int>[];
  for (var seed = 0; seed < seeds; seed++) {
    for (var team = 0; team < 2; team++) {
      final g = SweepGame.newGame(seed: seed + 700, dealer: seed % 4);
      final smart = SweepBot(seed), old = LegacySweepBot(seed);
      while (g.phase != Phase.results) {
        final isSmart = g.turn % 2 == team;
        if (g.phase == Phase.call) {
          g.call(isSmart
              ? smart.chooseCall(g.position)
              : old.chooseCall(g.position));
        } else {
          final watch = Stopwatch()..start();
          final move = isSmart
              ? smart.chooseMove(g.position)
              : old.chooseMove(g.position);
          if (isSmart) timings.add(watch.elapsedMicroseconds);
          g.play(move);
          g.validate();
        }
      }
      final difference = g.lastScores[team] - g.lastScores[1 - team];
      margin += difference;
      if (difference > 0) wins++;
      if (difference < 0) losses++;
      sweepsFor += g.sweeps[team].length;
      sweepsAgainst += g.sweeps[1 - team].length;
    }
  }
  timings.sort();
  stdout.writeln(
      'Deals: ${seeds * 2}; wins: $wins; losses: $losses; ties: ${seeds * 2 - wins - losses}');
  stdout.writeln(
      'Mean score margin: ${margin / (seeds * 2)}; sweeps: $sweepsFor vs $sweepsAgainst');
  stdout.writeln(
      'Decision ms p95: ${timings[(timings.length * .95).floor()] / 1000}; max: ${timings.reduce(max) / 1000}');
}
