# Sweep

An offline Flutter card game planned for Android first, then iPhone. One human and a bot partner play against two bots. SWEEP_RULES.md is the authoritative rules reference; MOBILE_GAME_PLAN.md describes the proposed interface and milestones.

## Bot strategy (development)

The deal log offers **Review completed-deal decisions** after recorded deals finish. Each record includes the acting player's hand, public table and captured cards, legal moves with capture points, the chosen action, and the bot seed. **Copy diagnostics** copies the report for analysis. Records stay local with the save; the current and previous deal are retained. Current-deal hands stay hidden in the UI, and simulated moves produce no records. Older moves made before this feature cannot be reconstructed from the short textual log.

All three bots use the same policy. They remember public captured cards, table cards, calls, house commitments, hand counts and scores, and see only their own hand. A called or promised rank remains known after a house disappears, until its owner plays that rank. A surviving house can prove another copy remains. This evidence persists in saves and constrains every sampled hand; bots never receive the real deck or another player's hand. Older saves recover evidence from recorded public actions where available, never from diagnostic hands; missing history stays unknown.

Each decision compares up to seven candidate moves across four plausible unseen-card distributions. A certain immediate opponent sweep is excluded when a zero-risk move exists. Simulations follow both opponents and the partner for one round; in the final ten plays, team minimax explores alternative replies with a budget of 160 expanded nodes per candidate/world, then uses tactical rollouts to final scoring. Evaluation considers team points, sweep eligibility, house ownership, leftovers and match victory; a substantial match lead increases caution. Search is approximate and uses guessed hands, not exhaustive hidden-information solving. The opening-call policy still favours duplicate high ranks. Completed-deal diagnostics also record the decision reason, public rank evidence, candidate scores, sweep risks and excluded giveaways.

Run `dart run tool/benchmark_bots.dart 100` to reproduce 200 paired deals against the preserved original policy, using seeds 700–799 and alternating teams/dealers. Public-memory policy measurement: 180 wins, 19 losses, 1 tie, mean score margin +156.01; sweeps 753 versus 41. The previous sampled policy measured 179 wins, 21 losses, margin +146.51 and sweeps 750 versus 59 against the same baseline. Decision latency was 18.2 ms at the 95th percentile and 147.7 ms maximum on the development machine; browser and device performance may differ. These measure strength against the original policy, not against human players or a direct match between policy revisions.

## Version 0.7 — capture review and clearer animations

This release is the free guest version: play without signing in, against three bots. Progress is saved locally on the current device/browser; no account is required.

Playable offline partnership Sweep: one human, a bot partner (Ari), and two opponent bots (Mira and Dev). Includes opening calls, all four move types, ordinary and pakka houses, commitments, sweeps, deal scoring, cumulative games, dealer rotation, and save/resume. The rulebook is available inside the app.

The current development layout gives most of the screen to the felt table and cards. Ari, Mira and Dev use small half-circle markers at the table edges; your hand identifies your own seat. Table cards, house stacks, and the animated played card are enlarged. The wooden border and toolbar are compact, and action controls appear only while choosing a move. The existing card artwork is unchanged.

Tap **Scores** in the toolbar for the deal number, cumulative **Game** totals and **THIS DEAL** points, sweep counts and provisional bonuses. This popup pauses play and reflects completed moves. Sweep bonuses require at least 20 captured card points and are finalized when the deal ends. The **Game menu** contains speed settings, rules and history, and also pauses play while open.

Tap a hand card, then a highlighted table target or a visual move option. The gold outline previews the complete legal move; press Capture, Build, Raise, or Discard to play it. Cancel selection leaves the deal unchanged. The shared table scrolls when crowded. Tap a house without a selection to inspect its component groups and commitments.

Tap any bot's player icon, or **You** beside your remaining-card count, to view that player's latest capture. The popup shows the captured cards including their played card, card points and any provisional sweep bonus. It pauses play, retains only the latest capture per player, survives save/resume and resets each deal. Discards and builds do not replace it; end-of-deal leftover awards are not a capturing turn. Older saves recover captures from public decision records when available.

Turns animate the played card onto the table, pause, then gather the affected cards into a capture or house. Normal bot turns take about 3.6 seconds; the speed menu offers Slow (about 5.8 seconds) and Fast (about 1.8 seconds), remembered between sessions. Speed changes apply to subsequent moves. Pause freezes the current animation. Opening the rulebook, deal log, or house details also pauses play. Returning home during an animation retains the last completed turn; Resume continues from that saved position. Existing 0.1 saves remain compatible.

After a bot calls 9–13 and the table is revealed, the game gives you 30 seconds to study the cards before the opening move. This viewing pause is independent of the speed setting and restarts when resuming an opening bot turn. Your own opening turn has no time limit: play continues only after you confirm your move.

After the final move resolves, any leftover cards stay visible briefly and travel to the last capturer in a three-second collection animation, labelled with the recipient and card points. The table then remains visible for five seconds before the deal-score screen opens. The completed deal is saved immediately; pausing or inspecting a player also pauses the collection animation.

Rules live in `lib/game/engine.dart`; bot decisions in `lib/game/bot.dart` receive an own-hand-only `Position`, without the deck or other players' cards. Legal moves are shared by bots and the human interface. Overlapping capture choices remain selectable; outcomes that capture the same cards share one representative grouping because houses are indivisible.

Validation covers 80 randomized complete deals, 15 games played to a winner, card/commitment invariants, serialized-state round trips, a full deal through the visual controls, results resume without duplicate scoring, four screen sizes, animation pause/resume, backgrounding, modal inspection, and saved speed settings. Run `flutter test` and `flutter analyze`. The web build and browser interaction are checked for 0.2; the earlier Android emulator verification belongs to 0.1. Current UI captures are in `artifacts/v0.2-*.png`.

Version 0.1 is preserved on `master` and the annotated `v0.1.0` tag. The current release is tagged `v0.7.0` on `codex/0.2-table-ui`; the package version is `0.7.0+7`.

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

The bots use bounded sampled search; difficulty levels are not yet implemented. The app still needs human playtesting, a guided tutorial, richer animation and audio, accessibility review, final artwork, iPhone packaging, and release preparation. This is a playable development build, not a store release.
