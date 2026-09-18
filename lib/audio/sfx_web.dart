import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'sfx_backend.dart';

SfxBackend createBackend() => _WebSfx();

class _WebSfx implements SfxBackend {
  final _context = web.AudioContext();
  late final _master = _context.createGain()..connect(_context.destination);
  final _buffers = <String, web.AudioBuffer>{};
  final _voices = <web.AudioBufferSourceNode, Completer<void>>{};
  @override
  Future<void> preload(String name, Uint8List bytes) async {
    _buffers[name] = await _context
        .decodeAudioData(Uint8List.fromList(bytes).buffer.toJS)
        .toDart;
  }

  @override
  void unlock() {
    // resume must be invoked synchronously from a pointer/keyboard gesture.
    _context.resume().toDart.catchError((Object _) => null);
  }

  @override
  Future<void> play(String name, double gain) async {
    if (_context.state != 'running' || !_buffers.containsKey(name)) return;
    final source = _context.createBufferSource()..buffer = _buffers[name];
    final level = _context.createGain()..gain.value = gain;
    source.connect(level);
    level.connect(_master);
    final done = Completer<void>();
    _voices[source] = done;
    source.onended = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    try {
      source.start();
      await done.future.timeout(const Duration(seconds: 4));
    } finally {
      _voices.remove(source);
      try {
        source.stop();
      } catch (_) {}
      source.disconnect();
      level.disconnect();
    }
  }

  @override
  void setVolume(double volume) => _master.gain.value = volume;
  @override
  Future<void> stop() async {
    for (final entry in _voices.entries.toList()) {
      try {
        entry.key.stop();
      } catch (_) {}
      if (!entry.value.isCompleted) entry.value.complete();
    }
    _voices.clear();
  }

  @override
  Future<void> dispose() async {
    await stop();
    _buffers.clear();
    await _context.close().toDart;
  }
}
