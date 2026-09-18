# Changelog

## 0.10.0

- Rename Mira to Nishu, Ari to Shak, and Dev to JLo across player labels, team scores, translations, and saved-history display.
- Merge the completed table UI, bot improvements, localization, and sound effects release into master.

## 0.9.0

- Replace the homepage team line with “GuruBox presentation”.

- Exclude final-turn table clearances from seep counters and label their history correctly; repair old zero-bonus seep entries when loading saves.

- Add a centralized, gesture-unlocked SFX system with variants, cooldowns, voice limits, persistent English/Hindi controls and graceful missing-file handling. Bundle 17 prepared CC0 Kenney effects; see SFX.md for sources and integration details.

## 0.8.0

- Lock Android phones to portrait, fit crowded table cards and houses without scrolling, and give Ari's seat badge enough height for its name and card count.

- Set the opening viewing pause to 20 seconds and label the discard action Throw / फेंकें.
- Rename visible game branding and terminology to Seep/सीप while preserving legacy save and package identifiers.
- Add offline English/Hindi selection, translated controls and scores, complete Hindi rules, bundled Devanagari font, and language-independent public history events.
- Refine seep-risk estimates by reserving other players' publicly guaranteed ranks and accounting for the next opponent's already-known cards.
- Avoid the extra seep-risk penalty when the opponents cannot reach bonus eligibility even under a conservative maximum-points bound.
- Explain forced and fallback bot decisions; add focused regression tests and a plain-language bot strategy review guide.

## 0.7.0

- Animate leftover cards to the last capturer for three seconds, show the recipient and points, then pause before scores; respect pause and inspection during collection.
- Tap a player icon (or the human's You/card-count control) to inspect only their latest capture, with visual cards, card points and a separate provisional seep bonus. Pause during inspection; save per-player captures and reset each deal.
- Show a normal capture animation and message for a final-turn table clearance, without the seep celebration.

## 0.6.0

- Retain public rank evidence from calls and houses until played; constrain sampled hands with that evidence and migrate older diagnostic saves without reading hidden hands.
- Avoid certain immediate seep giveaways when a safe move exists; search opponent and partner replies through scoring in the last ten plays with a bounded minimax budget.
- Include decision reasons, known ranks, candidate evaluations and excluded seep giveaways in completed-deal diagnostics; add Ari's reported position and public-memory regression tests.
- Save per-move decision diagnostics (actor hand, public table/captures, legal alternatives and bot seed), with copyable review after a deal ends; retain two deals and support older saves.
- Evaluate immediate seep exposure across all unseen ranks, and include the safest legal option in the search shortlist.
- Hide the played card in the human hand during flight, preserving its layout space until the move completes.
- Prefer higher-scoring suits in otherwise identical rank captures; prevent speculative look-ahead from choosing a non-scoring seven over 7-spade.
- Strengthen all bots with sampled hidden-card look-ahead, public capture memory, house-commitment constraints, partnership evaluation, seep eligibility and endgame scoring.
- Add reproducible old-versus-new bot comparisons and fairness/save-resume tests.

## 0.5.0

- Free guest play without login, with local save/resume.
- Remove the empty-table message and decorative placeholder.

- Show small remaining-card counters for all four players and the original caller's name on the call card.
- Distinguish clubs with wide, separated round lobes from narrow, pointed spades, and enlarge corner suit symbols.
- Add ornamental Aces and illustrated Jack, Queen and King portraits; use card and broom icons for the live score counters.
- Keep the opening call visible as a rank card on the table, with live current-deal card points and seep counts at each team's side.
- Simplify playing cards to one large suit symbol and one bold top-left rank with a small suit beneath it.
- Increase corner readability, deepen suit colours, and show face-card building values beneath a restrained royal emblem.

## 0.4.0

- Expand the table nearly edge to edge, thin the wooden border, and replace player panels with compact half-circle edge markers.
- Enlarge table cards, houses and the animated played card; retain existing card artwork.
- Move deal and game scores into a pausing popup; consolidate speed, rules and history into a pausing menu.
- Remove the human avatar and use a compact action strip only while choosing a move.

## 0.3.0

- Keep the completed table visible for five seconds after the final move resolves before opening deal scores.
- Show both teams' current-deal card points, seep counts, and pending seep bonuses alongside completed-deal game totals.
- Hold the revealed opening table for 30 seconds before a bot's first move, independently of turn speed. Human opening turns wait for confirmation.
- Fix missing Build option when a matching hand card and loose table card or combination can form a new pakka house, while retaining a matching card.

## 0.2.0

- Traditional felt table, wooden rim, four player seats and active-turn indicators.
- Drawn playing cards, fanned hand, visual house stacks and ownership markers.
- On-table target selection and move previews with explicit action buttons.
- Animated plays, captures, house assembly and seep celebration.
- Slower bot turns, saved Slow/Normal/Fast settings, and pause/resume.
- Pause while inspecting rules, history or houses; preserve completed turns when leaving the table.
- Responsive desktop, portrait and landscape layouts. Existing saves remain compatible.

## 0.1.0

- Complete offline partnership Seep with one human and three bots.
- Opening call, captures, houses, commitments, seeps and cumulative scoring.
- Dealer rotation, game completion and local save/resume.
- Android development build and playable Flutter web support.
- Tagged `v0.1.0` at commit `1205ec9`.
