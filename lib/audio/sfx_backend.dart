import 'dart:typed_data';

abstract interface class SfxBackend {
  Future<void> preload(String name, Uint8List bytes);

  /// Called directly in the user gesture, never during preload.
  void unlock();
  Future<void> play(String name, double gain);
  void setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}
