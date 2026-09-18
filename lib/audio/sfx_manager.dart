import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sfx_backend.dart';
import 'sfx_native.dart' if (dart.library.js_interop) 'sfx_web.dart';

enum Sfx {
  button,
  deal,
  play,
  capture,
  sweep,
  invalid,
  turn,
  score,
  roundWin,
  roundLose,
  gameWin
}

class SfxSpec {
  final List<String> files;
  final double gain;
  final int cooldownMs;
  const SfxSpec(this.files, this.gain, this.cooldownMs);
}

const sfxCatalog = <Sfx, SfxSpec>{
  Sfx.button: SfxSpec(['button_1.wav', 'button_2.wav'], .25, 100),
  Sfx.deal: SfxSpec(['deal_1.wav', 'deal_2.wav', 'deal_3.wav'], .45, 120),
  Sfx.play: SfxSpec(['play_1.wav', 'play_2.wav', 'play_3.wav'], .55, 150),
  Sfx.capture: SfxSpec(['capture_1.wav', 'capture_2.wav'], .55, 250),
  Sfx.sweep: SfxSpec(['sweep.wav'], .65, 1000),
  Sfx.invalid: SfxSpec(['invalid.wav'], .35, 500),
  Sfx.turn: SfxSpec(['turn.wav'], .4, 900),
  Sfx.score: SfxSpec(['score.wav'], .3, 500),
  Sfx.roundWin: SfxSpec(['round_win.wav'], .6, 2000),
  Sfx.roundLose: SfxSpec(['round_lose.wav'], .45, 2000),
  Sfx.gameWin: SfxSpec(['game_win.wav'], .7, 3000),
};

class SfxManager extends ChangeNotifier {
  final SharedPreferences preferences;
  final SfxBackend _backend;
  final Future<ByteData> Function(String) _load;
  final DateTime Function() _now;
  final Random _random;
  final _ready = <String>{};
  final _last = <Sfx, DateTime>{};
  final _previous = <Sfx, String>{};
  final _active = <Object>{};
  Future<void>? _preloading;
  Future<void>? _settingsQueue;
  bool _unlocked = false, _foreground = true, _disposed = false;
  late bool enabled;
  late double volume;
  SfxManager(this.preferences,
      {SfxBackend? backend,
      Future<ByteData> Function(String)? load,
      DateTime Function()? now,
      Random? random})
      : _backend = backend ?? createBackend(),
        _load = load ?? rootBundle.load,
        _now = now ?? DateTime.now,
        _random = random ?? Random() {
    enabled = preferences.getBool('seep.sfx.enabled') ?? true;
    final saved = preferences.getDouble('seep.sfx.volume') ?? .65;
    volume = saved.isFinite ? saved.clamp(0.0, 1.0) : .65;
    _backend.setVolume(volume);
  }

  Future<void> preload() => _preloading ??= _preload();
  Future<void> _preload() async {
    for (final file in sfxCatalog.values.expand((s) => s.files).toSet()) {
      if (_disposed) return;
      try {
        final data = await _load('assets/audio/sfx/$file');
        if (_disposed) return;
        await _backend.preload(file,
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        if (!_disposed) _ready.add(file);
      } catch (_) {
        // Optional files: no retries, UI errors, or network fallback.
      }
    }
  }

  void unlock() {
    if (_disposed) return;
    try {
      _backend.unlock();
      _unlocked = true;
    } catch (_) {}
  }

  Future<void> playByName(String name) async {
    for (final event in Sfx.values) {
      if (event.name == name) {
        await play(event);
        return;
      }
    }
  }

  Future<void> play(Sfx event) async {
    if (_disposed || !_unlocked || !_foreground || !enabled || volume == 0) {
      return;
    }
    final spec = sfxCatalog[event]!;
    final now = _now();
    if (_active.length >= 3 ||
        (_last[event] != null &&
            now.difference(_last[event]!).inMilliseconds < spec.cooldownMs)) {
      return;
    }
    var choices = spec.files.where(_ready.contains).toList();
    if (choices.isEmpty) return;
    if (choices.length > 1) choices.remove(_previous[event]);
    final file = choices[_random.nextInt(choices.length)];
    _previous[event] = file;
    _last[event] = now;
    final token = Object();
    _active.add(token);
    try {
      await _backend.play(file, spec.gain);
    } catch (_) {
      // Device/browser refusal must never interrupt a game or be replayed later.
    } finally {
      _active.remove(token);
    }
  }

  Future<void> setEnabled(bool value) {
    enabled = value;
    if (!value) stop();
    notifyListeners();
    return _persist();
  }

  Future<void> setVolume(double value) {
    volume = value.isFinite ? value.clamp(0.0, 1.0) : volume;
    _backend.setVolume(volume);
    if (volume == 0) stop();
    notifyListeners();
    return _persist();
  }

  Future<void> _persist() {
    final currentEnabled = enabled;
    final currentVolume = volume;
    return _settingsQueue =
        (_settingsQueue ?? Future<void>.value()).then((_) async {
      try {
        await preferences.setBool('seep.sfx.enabled', currentEnabled);
        await preferences.setDouble('seep.sfx.volume', currentVolume);
      } catch (_) {}
    });
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) stop();
  }

  void stop() {
    _backend.stop().catchError((Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    _ready.clear();
    _backend.dispose().catchError((Object _) {});
    super.dispose();
  }
}
