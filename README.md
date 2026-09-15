# Sweep

An offline Flutter card game planned for Android first, then iPhone. One human and a bot partner play against two bots. SWEEP_RULES.md is the authoritative rules reference; MOBILE_GAME_PLAN.md describes the proposed interface and milestones.

## Current state

Playable offline partnership Sweep: one human, a bot partner (Ari), and two opponent bots (Mira and Dev). Includes opening calls, all four move types, ordinary and pakka houses, commitments, sweeps, deal scoring, cumulative games, dealer rotation, and save/resume. The rulebook is available inside the app.

Tap a hand card to see legal moves. Select a move to preview it, then confirm. Scroll the hand horizontally to see all cards, and scroll the shared table when it fills. Tap a house for its component groups and commitments. The Home button pauses the game; Resume continues from the saved turn.

Rules live in `lib/game/engine.dart`; bot decisions in `lib/game/bot.dart` receive an own-hand-only `Position`, without the deck or other players' cards. Legal moves are shared by bots and the human interface. Overlapping capture choices remain selectable; outcomes that capture the same cards share one representative grouping because houses are indivisible.

Validation: 24 passing tests, including 80 randomized complete deals, 15 games played to a winner, card/commitment invariants, serialized-state round trips, a full deal through player UI controls, results resume without duplicate scoring, and small landscape layout. `flutter analyze` reports no issues. The Android debug APK was built, installed, and exercised on the emulator: house-raising preview/confirmation, bot responses, exact saved-state preservation across a force-stop/relaunch, and portrait/landscape rendering. Screenshots are in `artifacts/sweep-table.png`, `artifacts/sweep-preview.png`, and `artifacts/sweep-landscape.png`.

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

## Remaining polish

The bots use an initial tactical policy, not advanced search or difficulty levels. The app still needs human playtesting, a guided tutorial, richer animation and audio, accessibility review, final artwork, iPhone packaging, and release preparation. This is a playable development build, not a store release.
