# Seep mobile game — first playable specification

Status: Proposed scope, based on SEEP_RULES.md version 1.0.

## Experience

One human and three bots play in two teams. The human sits at the bottom, their bot partner at the top, and opponent bots on either side. Seat identities stay fixed while the dealer changes. Turns pass to the next player on the right, as specified in the rulebook.

The first version runs offline, without accounts or a server. It supports complete games across multiple deals, automatic saving, resuming, and an in-game rulebook. Target mobile operating systems and implementation framework remain to be selected.

## Screen flow

1. Home: New game, Resume when a save exists, How to play, and Settings.
2. Table: Deal and opening call, normal turns, captures, houses, and seep feedback.
3. Deal results: Card points, earned and disallowed seep bonuses, deal totals, cumulative scores, and the next dealer with their rotation count.
4. Game results: Winning team once the completed-deal margin reaches 104, with Play again and Home actions.

Settings initially cover sound and reduced motion. A short optional tutorial explains card points versus rank values, houses, commitments, and team play.

## Table and controls

Use a landscape-first prototype to give the shared table and hand space; validate readability and touch comfort before locking orientation for release.

- Keep the human hand visible and selectable, with an enlarged card preview when needed.
- Show bot hand counts, team labels, dealer, and active turn without exposing bot cards.
- Show loose cards separately from houses. Each house displays its declared value, ordinary or pakka status, and the players committed to it. Tapping reveals its component combinations.
- Display cumulative team scores and the current deal's captured card points. Mark seep bonuses as provisional until scoring confirms the 20-card-point requirement.
- Selecting a hand card exposes legal Capture, Build/Contribute, Raise, or Discard actions. Present the selected result before a confirm tap commits the turn.
- Where capture combinations overlap, let the player choose among legal outcomes and preview exactly what will remain. Include every additional non-overlapping match required by the rules; do not silently force the outcome with the most cards or points.
- For a build or raise, offer valid target values and preview the resulting house, absorbed combinations, and commitments.
- Explain blocked actions briefly, such as: “Keep this Jack until the house of 11 is captured or raised.”
- When the human makes the opening call, offer only ranks 9–13 held in their initial four cards. Keep the table hidden until the call is made and restrict the opening move to the called value.

## Rules engine

Keep game rules independent of graphics and animation. Represent cards, fixed seats and teams, dealer, deal phase, hands, loose cards, indivisible houses and their groups, commitments, captures, seep events, cumulative scores, and dealer loss/tie count explicitly.

Implement a legal-action generator and one validated action application path shared by human controls and bots. Capture and building choices must enumerate maximal non-overlapping outcomes, not merely maximum-size outcomes: no further valid match may remain, but overlapping alternatives are freely selectable.

Use explicit phases for initial dealing, opening call, reveal, opening action, remaining dealing, normal turns, deal scoring, and game completion. Save after each completed state transition and resume without replaying an action or scoring a deal twice.

Support seeded shuffles and action logs for reproducible debugging. Keep random initial-deal retries separate from dealer loss/tie counts.

## Bots

All three bots use the same legal-action engine. Their decision input contains only their own cards, public table and commitment information, and observable play history. Hidden hands and the future deck order are unavailable to the decision policy, including the partner's hand.

Start with a baseline bot that always completes legal games. Then add a standard strategy that weighs captured points, seep opportunities and exposure, retaining useful capture cards, house commitments, and partner support. Partnership coordination uses public information only.

Difficulty selection and more advanced search follow after the standard bot is reliable. Any future simulation must sample plausible unseen cards rather than inspect actual hidden hands.

## Build milestones and acceptance

### 1. Rules foundation

Implement and verify dealing, opening restrictions, capture alternatives, ordinary and pakka houses, commitment transfers/releases, raising, seeps, scoring, and dealer rotation.

Acceptance: automated full bot games terminate legally; every card exists in exactly one location; each deal accounts for all 52 cards and exactly 100 card points; no house survives deal completion. Focused rule examples verify overlapping captures, teammate contributions without a matching card, multiple commitments, first/final-play seep timing, the 20-point eligibility threshold, 104-point winning margin, and third loss/tie dealer changes.

### 2. First playable interface

Connect one human and three baseline bots to the table interface. Include opening calls, previews for ambiguous moves, house details, deal results, multi-deal games, and save/resume.

Acceptance: a human can finish a complete game without developer intervention; legal alternatives remain selectable; interrupted games resume at the correct turn and phase.

### 3. Strategy and usability

Improve bot choices, add the optional tutorial, refine card spacing and touch targets, and add animation, sound, and reduced motion.

Acceptance: test on intended phone sizes and conduct human play sessions to assess clarity, pacing, and partner behavior. Check that bot decisions cannot access private opponent or partner state.

### 4. Mobile release preparation

Package for the selected platforms, verify app suspension and restart behavior on devices, prepare icons and store materials, and test a release build. Store distribution is a later milestone after the playable game is approved.

## Next decisions

- Android first, iPhone first, or both; this informs framework and device testing.
- Validate the proposed landscape layout with a playable table mockup.
- Choose visual style after the basic table interactions work.

No changes to the agreed rulebook are proposed here. Resolve any implementation ambiguity against the rulebook before adding a house rule.
