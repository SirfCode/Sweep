import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweep/audio/sfx_backend.dart';
import 'package:sweep/audio/sfx_manager.dart';
import 'package:sweep/main.dart';
import 'package:sweep/game/engine.dart';

class FakeAudio implements SfxBackend {
  final loaded = <String>[];
  final played = <String>[];
  final pending = <Completer<void>>[];
  var unlocks = 0, stops = 0;
  double volume = 1;
  bool hold = false, fail = false;
  @override
  Future<void> preload(String name, Uint8List bytes) async {
    loaded.add(name);
  }

  @override
  void unlock() {
    unlocks++;
  }

  @override
  Future<void> play(String name, double gain) async {
    if (fail) throw StateError('Device unavailable');
    played.add(name);
    if (hold) {
      final c = Completer<void>();
      pending.add(c);
      await c.future;
    }
  }

  @override
  void setVolume(double value) {
    volume = value;
  }

  @override
  Future<void> stop() async {
    stops++;
    for (final c in pending) {
      if (!c.isCompleted) c.complete();
    }
    pending.clear();
  }

  @override
  Future<void> dispose() => stop();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late FakeAudio backend;
  late SfxManager manager;
  var time = DateTime(2026);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = FakeAudio();
    time = DateTime(2026);
    manager = SfxManager(prefs,
        backend: backend,
        random: Random(7),
        now: () => time,
        load: (_) async => ByteData(1));
  });
  tearDown(() => manager.dispose());

  testWidgets(
      'sound controls persist mute and volume without leaving the home screen',
      (tester) async {
    await manager.preload();
    await tester.pumpWidget(SweepApp(preferences: prefs, sfxManager: manager));
    expect(backend.played, isEmpty);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sound effects'));
    await tester.pumpAndSettle();
    expect(backend.unlocks, greaterThan(0));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(manager.enabled, false);
    expect(prefs.getBool('seep.sfx.enabled'), false);
    final slider = find.byKey(const Key('sfx-volume'));
    await tester.tapAt(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(prefs.getDouble('seep.sfx.volume'), closeTo(.5, .06));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final opening in [true, false]) {
    testWidgets(
        opening
            ? 'opening clearance emits seep'
            : 'final clearance emits capture and delayed result, never seep',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final g = SweepGame.newGame(seed: 11, dealer: 3);
      if (opening) {
        final hand = [47, 1, 2, 3];
        final table = [21, 7, 26, 34];
        final rest = [
          for (var c = 0; c < 52; c++)
            if (!hand.contains(c) && !table.contains(c)) c
        ];
        g.phase = Phase.opening;
        g.calledValue = 9;
        g.loose = table;
        g.hands = [
          hand,
          rest.sublist(0, 4),
          rest.sublist(4, 8),
          rest.sublist(8, 12)
        ];
        g.deck = rest.sublist(12);
      } else {
        g.phase = Phase.playing;
        g.plays = 47;
        g.deck = [];
        g.hands = [
          [12],
          [],
          [],
          []
        ];
        g.loose = [25];
        g.captured = [
          [
            for (var c = 0; c < 52; c++)
              if (c != 12 && c != 25) c
          ],
          []
        ];
      }
      g.validate();
      await prefs.setString(saveKey, jsonEncode(g.toJson()));
      await manager.preload();
      await tester
          .pumpWidget(SweepApp(preferences: prefs, sfxManager: manager));
      await tester.tap(find.byKey(const Key('resume')));
      await tester.pumpAndSettle();
      final card = find.byKey(Key('hand-${opening ? 47 : 12}'));
      await tester.tapAt(tester.getTopLeft(card) + const Offset(9, 12));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-move')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump();
      if (opening) {
        expect(backend.played, contains('sweep.wav'));
      } else {
        expect(backend.played.any((name) => name.startsWith('capture_')), true);
        expect(backend.played, isNot(contains('sweep.wav')));
        expect(backend.played, isNot(contains('round_win.wav')));
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(backend.played, containsAll(['score.wav', 'round_win.wav']));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('preload is idempotent and never plays or unlocks', () async {
    await Future.wait([manager.preload(), manager.preload()]);
    expect(
        backend.loaded.length, sfxCatalog.values.expand((s) => s.files).length);
    await manager.play(Sfx.deal);
    expect(backend.played, isEmpty);
    expect(backend.unlocks, 0);
    manager.unlock();
    await manager.playByName('deal');
    expect(backend.played.length, 1);
    await manager.playByName('unknown');
    expect(backend.played.length, 1);
  });

  test('rapid repeats are dropped and variants do not repeat consecutively',
      () async {
    await manager.preload();
    manager.unlock();
    await manager.play(Sfx.play);
    final first = backend.played.single;
    await manager.play(Sfx.play);
    expect(backend.played.length, 1);
    time = time.add(const Duration(milliseconds: 151));
    await manager.play(Sfx.play);
    expect(backend.played.last, isNot(first));
  });

  test('voice limit releases slots on completion and mute stops active voices',
      () async {
    await manager.preload();
    manager.unlock();
    backend.hold = true;
    final playing = [
      manager.play(Sfx.play),
      manager.play(Sfx.capture),
      manager.play(Sfx.turn)
    ];
    await manager.play(Sfx.score);
    expect(backend.played.length, 3);
    await manager.setEnabled(false);
    await Future.wait(playing);
    await manager.play(Sfx.deal);
    expect(backend.played.length, 3);
    backend.hold = false;
    await manager.setEnabled(true);
    await manager.play(Sfx.score);
    expect(backend.played.length, 4);
  });

  test('volume clamps, updates backend, and settings survive recreation',
      () async {
    await manager.setVolume(2);
    expect(backend.volume, 1);
    await manager.setVolume(-1);
    expect(backend.volume, 0);
    await manager.setVolume(.35);
    await manager.setEnabled(false);
    final restored = SfxManager(prefs, backend: FakeAudio());
    expect(restored.volume, .35);
    expect(restored.enabled, false);
    restored.dispose();
  });

  test(
      'missing assets and playback failures are silent and do not block later effects',
      () async {
    final missing = SfxManager(prefs,
        backend: FakeAudio(), load: (_) async => throw StateError('missing'));
    await missing.preload();
    missing.unlock();
    await missing.play(Sfx.sweep);
    missing.dispose();
    await manager.preload();
    manager.unlock();
    backend.fail = true;
    await manager.play(Sfx.sweep);
    backend.fail = false;
    await manager.play(Sfx.deal);
    expect(backend.played.length, 1);
  });

  test('background and zero volume suppress events without replay on resume',
      () async {
    await manager.preload();
    manager.unlock();
    manager.setForeground(false);
    await manager.play(Sfx.turn);
    manager.setForeground(true);
    expect(backend.played, isEmpty);
    await manager.setVolume(0);
    await manager.play(Sfx.turn);
    expect(backend.played, isEmpty);
    await manager.setVolume(.5);
    await manager.play(Sfx.turn);
    expect(backend.played.length, 1);
  });
}
