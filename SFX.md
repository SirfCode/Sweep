# Sound effects

The app bundles **17 short effects derived from Kenney's Casino Audio 1.1**, covering every event below. They work offline; no music, runtime downloads, or placeholder beeps are used.

Source: https://kenney.nl/assets/casino-audio — Kenney Vleugels, CC0. The original license is retained in `assets/audio/sfx/LICENSE-Kenney.txt`. `manifest.json` in that folder maps each output to the original recordings. Clips are trimmed, converted to mono PCM WAV, level-balanced and faded at the edges; result cues combine quiet chip taps. Total WAV size is about 367 KiB. Reproduce them with `tool/prepare_sfx.py <extracted-pack-directory>` using numpy and soundfile.

Place licensed recordings in `assets/audio/sfx/`. That directory is already registered in `pubspec.yaml`; rebuild the app after adding files. Use short PCM WAV files (mono, 16-bit, 44.1 or 48 kHz), trimmed closely with gentle fades to prevent clicks. Keep peaks below clipping and avoid long reverbs. Every clip must finish within four seconds.

| Event / `playByName` name | Files | Suggested recording |
| --- | --- | --- |
| button | button_1.wav, button_2.wav | Soft fingertip on wood, 40–80 ms |
| deal | deal_1.wav, deal_2.wav, deal_3.wav | Single card sliding off a deck, 100–200 ms |
| play | play_1.wav, play_2.wav, play_3.wav | Light card landing on felt, 120–250 ms |
| capture | capture_1.wav, capture_2.wav | Small pile brushed together, 200–400 ms |
| sweep | sweep.wav | Broader clean card gather, 400–650 ms |
| invalid | invalid.wav | Muted double wood tap, 150–250 ms |
| turn | turn.wav | Gentle single table knock, 100–200 ms |
| score | score.wav | Quiet scoring-token click, 100–200 ms |
| roundWin | round_win.wav | Two light ascending wood taps, 300–500 ms |
| roundLose | round_lose.wav | Soft low tap, 200–350 ms |
| gameWin | game_win.wav | Restrained three-tap table flourish, 500–900 ms |

Replacement recordings should have comparable perceived loudness across variants. Avoid synthesized arcade tones, voices, or melodic celebrations. Document their source, author, license and any required attribution here.

## Controls

Open **Game menu → Sound effects** (ध्वनि प्रभाव). Effects default to enabled at 65% volume. Enable/disable and volume (0–1) persist through the existing SharedPreferences system, which uses browser storage on web. Muting immediately stops active voices; volume changes also affect playing sounds. Preference write failures do not interrupt gameplay.

## Architecture and extension

`lib/audio/sfx_manager.dart` owns the catalog, availability, random variant selection, per-event cooldowns, a three-voice cap, foreground gating and settings. Use `play(Sfx.capture)` or `playByName('capture')`; never construct audio players in game widgets. Unknown names, missing/corrupt files and playback refusal are harmless. Preload is idempotent. Events before readiness or unlock are dropped, never queued for a noisy catch-up burst. Variant selection avoids the last variant where alternatives exist.

The app preloads once on startup without starting playback. Pointer-down or keyboard input invokes unlock directly in the user gesture. The web backend resumes a Web Audio context synchronously in that gesture, decodes assets ahead of playback, and routes voices through a master gain node. Mobile uses audioplayers with cached asset bytes. Playback is stopped when backgrounded or returning home; disposal releases the backend. Browser policy may require another gesture after backgrounding; every interaction retries unlock.

Tap feedback is handled once at the app boundary (including dialogs), excluding drag releases. Gameplay hooks emit named events: initial/remainder dealing; card flight start; committed capture or seep; invalid card selection; transition to the human's turn; score/result reveal. Result sounds occur after the final animation and pause, not on screen rebuild or loading old results. Final-turn clearance uses capture, not seep. Opening seep uses the seep cue. Ties use score only; a game win replaces the round-win cue, and an opponent game win uses round-lose. Score sound accompanies the deal-results reveal, not every incremental card point.

To add an effect, add an enum/catalog entry and its filenames, then call the manager from the relevant transition. Keep common sounds quieter than infrequent signals. There are no background-music controls or playback paths.

## Validation

Run `flutter test test/sfx_manager_test.dart test/table_ui_test.dart test/localization_test.dart` and `flutter analyze`. Build both `flutter build web` and `flutter build apk --debug`.

Listening checklist for a real phone and web browser: verify silence before interaction; variants during successive turns; muted and zero-volume silence; saved settings after restart; no burst after background/resume; opening seep versus final capture; and win/lose cues only at the result reveal. Automated asset checks verify complete coverage, PCM format, non-silence, duration and clipping; subjective loudness still needs device listening.
