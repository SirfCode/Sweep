# Sweep

An offline Flutter card game planned for Android first, then iPhone. One human and a bot partner play against two bots. SWEEP_RULES.md is the authoritative rules reference; MOBILE_GAME_PLAN.md describes the proposed interface and milestones.

## Version 0.5 — free guest play

This release is the free guest version: play without signing in, against three bots. Progress is saved locally on the current device/browser; no account is required.

Playable offline partnership Sweep: one human, a bot partner (Ari), and two opponent bots (Mira and Dev). Includes opening calls, all four move types, ordinary and pakka houses, commitments, sweeps, deal scoring, cumulative games, dealer rotation, and save/resume. The rulebook is available inside the app.

The current development layout gives most of the screen to the felt table and cards. Ari, Mira and Dev use small half-circle markers at the table edges; your hand identifies your own seat. Table cards, house stacks, and the animated played card are enlarged. The wooden border and toolbar are compact, and action controls appear only while choosing a move. The existing card artwork is unchanged.

Tap **Scores** in the toolbar for the deal number, cumulative **Game** totals and **THIS DEAL** points, sweep counts and provisional bonuses. This popup pauses play and reflects completed moves. Sweep bonuses require at least 20 captured card points and are finalized when the deal ends. The **Game menu** contains speed settings, rules and history, and also pauses play while open.

Tap a hand card, then a highlighted table target or a visual move option. The gold outline previews the complete legal move; press Capture, Build, Raise, or Discard to play it. Cancel selection leaves the deal unchanged. The shared table scrolls when crowded. Tap a house without a selection to inspect its component groups and commitments.

Turns animate the played card onto the table, pause, then gather the affected cards into a capture or house. Normal bot turns take about 3.6 seconds; the speed menu offers Slow (about 5.8 seconds) and Fast (about 1.8 seconds), remembered between sessions. Speed changes apply to subsequent moves. Pause freezes the current animation. Opening the rulebook, deal log, or house details also pauses play. Returning home during an animation retains the last completed turn; Resume continues from that saved position. Existing 0.1 saves remain compatible.

After a bot calls 9–13 and the table is revealed, the game gives you 30 seconds to study the cards before the opening move. This viewing pause is independent of the speed setting and restarts when resuming an opening bot turn. Your own opening turn has no time limit: play continues only after you confirm your move.

After the final move resolves, the completed table and live scores remain visible for five seconds before the deal-score screen opens. The completed deal is saved immediately during this pause.

Rules live in `lib/game/engine.dart`; bot decisions in `lib/game/bot.dart` receive an own-hand-only `Position`, without the deck or other players' cards. Legal moves are shared by bots and the human interface. Overlapping capture choices remain selectable; outcomes that capture the same cards share one representative grouping because houses are indivisible.

Validation covers 80 randomized complete deals, 15 games played to a winner, card/commitment invariants, serialized-state round trips, a full deal through the visual controls, results resume without duplicate scoring, four screen sizes, animation pause/resume, backgrounding, modal inspection, and saved speed settings. Run `flutter test` and `flutter analyze`. The web build and browser interaction are checked for 0.2; the earlier Android emulator verification belongs to 0.1. Current UI captures are in `artifacts/v0.2-*.png`.

Version 0.1 is preserved on `master` and the annotated `v0.1.0` tag. The current release is tagged `v0.5.0` on `codex/0.2-table-ui`; the package version is `0.5.0+5`.

## Run on the configured emulator

From the project directory:

```powershell
$env:ANDROID_ADB_SERVER_PORT = '5038'
$env:ADB_SERVER_SOCKET = 'tcp:localhost:5038'
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5556
```

See DEVELOPMENT_SETUP.md for emulator startup commands. The isolated ADB port avoids a conflicting older ADB service on this computer. Build an Android debug APK with `flutter build apk --debug`; it is written to `build/app/outputs/flutter-apk/app-debug.apk`. The application ID and launcher icon remain development defaults and must be finalized before publishing.

## Run in a web browser

From the project directory, run `flutter run -d chrome --web-port 8080` (or use `-d edge`). In Android Studio, select Chrome in the device dropdown and run `lib/main.dart`. For a stable save location in the IDE too, set Additional run args to `--web-port 8080` in the Flutter run configuration.

To use an existing browser window, run `flutter run -d web-server --web-hostname localhost --web-port 8080`, then open `http://localhost:8080`. Keep the terminal running; press Ctrl+C to stop. Browser saves belong to that browser profile and origin, so keep the same hostname and port when resuming. They are separate from Android saves.

`flutter build web` creates the files in `build/web` for later website hosting. Adding web support does not publish the game online.

## Remaining polish

The bots use an initial tactical policy, not advanced search or difficulty levels. The app still needs human playtesting, a guided tutorial, richer animation and audio, accessibility review, final artwork, iPhone packaging, and release preparation. This is a playable development build, not a store release.
