import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'sfx_backend.dart';

SfxBackend createBackend() => _NativeSfx();

class _NativeSfx implements SfxBackend {
  final _assets = <String, Uint8List>{};
  final _players = <AudioPlayer, double>{};
  final _done = <AudioPlayer, Completer<void>>{};
  double _volume = 1;
  @override
  Future<void> preload(String name, Uint8List bytes) async =>
      _assets[name] = bytes;
  @override
  void unlock() {}
  @override
  Future<void> play(String name, double gain) async {
    final bytes = _assets[name];
    if (bytes == null) return;
    final player = AudioPlayer();
    final done = Completer<void>();
    final completion = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    _done[player] = done;
    _players[player] = gain;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      if (!_players.containsKey(player)) return;
      await player.play(BytesSource(bytes), volume: _volume * gain);
      if (!_players.containsKey(player)) return;
      await done.future.timeout(const Duration(seconds: 4));
    } finally {
      _players.remove(player);
      _done.remove(player);
      await completion.cancel();
      await player.dispose();
    }
  }

  @override
  void setVolume(double volume) {
    _volume = volume;
    for (final entry in _players.entries) {
      entry.key.setVolume(volume * entry.value).catchError((Object _) {});
    }
  }

  @override
  Future<void> stop() async {
    final players = _players.keys.toList();
    _players.clear();
    for (final player in players) {
      final done = _done[player];
      if (done != null && !done.isCompleted) done.complete();
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    _assets.clear();
  }
}
