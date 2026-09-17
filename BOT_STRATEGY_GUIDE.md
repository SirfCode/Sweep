# How the Seep bots think

Review of v0.7.0, with the improvements made during this review.

The bots try to maximise their **team's score**, not simply collect the most cards. Ari plays for your team; Mira and Dev play for the opposing team. All three use the same decision rules. They have no access to the real opponents' hands.

## 1. What a bot knows

| Information | Available to the bot? |
|---|---|
| Its own cards | Yes |
| Loose table cards and houses | Yes |
| Publicly captured cards and team scores | Yes |
| How many cards each player has left | Yes |
| Ranks promised by calls and houses | Yes, remembered until played |
| Another player's actual hand | No |
| The real undealt deck or shuffle order | No |

**A known rank is a fact; an unseen card is a possibility.** If Dev calls 11, he has at least one jack. If he later plays a jack, that guarantee is consumed. A surviving house can prove that he still holds another. The bot does not assume the original promise means Dev keeps a jack forever.

If somebody else captures Dev's house, Dev's unplayed promised rank remains known. Knowledge survives save/resume and resets at the next deal. Older saves recover public evidence from recorded moves where available; missing history stays unknown.

## 2. How it chooses a move

1. **List the legal moves.** The bot uses the same rules as the human player, including house commitments and mandatory captures.
2. **Keep the better suits in equivalent captures.** If the same rank combination can take either a non-scoring seven or 7♠, prefer the spade. Alternatives involving different ranks or houses remain available for comparison.
3. **Check the next opponent's seep threat.** Examine whether one card could clear the resulting table. Consider public rank promises, cards already played, and remaining hand sizes.
4. **Reject a certain seep giveaway when a safe move exists.** If every available move carries some risk, compare the alternatives instead of refusing to play.
5. **Imagine four possible distributions of unseen cards.** Each must respect known ranks and hand sizes. Every candidate faces the same four distributions, making the comparison fairer.
6. **Try a shortlist of up to seven moves.** Include the immediate tactical favourite, the safest option, and a mix of captures, builds, raises and discards. A strong move can still be missed by this shortlist.
7. **Compare team outcomes.** During most of the deal, follow the move and the next three replies. During the final ten plays, explore alternative replies through final scoring, within a processing budget.
8. **Choose the best evaluated result.** Consider expected team score, a smaller allowance for the worst sampled result, and immediate seep risk. A team leading by more than 50 match points gives more weight to avoiding a bad outcome.

The opening call is simpler: prefer a high rank with duplicate cards, then the higher rank. The table is hidden during the call, so it is not consulted.

## 3. What counts as a good outcome

The evaluation considers captured card points, seep bonuses, whether the team can qualify for those bonuses, house ownership, final leftover cards and winning the match. A build can therefore beat an immediate capture, and a low-value discard can beat a two-point capture that gives away a seep.

Seep bonuses follow the rulebook: 25 for the opening play, 50 for an intermediate play, and zero for the final play. A team needs at least 20 card points to receive its seep bonuses. The final turn and leftover collection are not treated as bonus-earning seeps.

Partner support is partly explicit and partly found through the search. The quick tactical policy gives credit to contributing to a partner's house and modestly discourages collecting a partner's low-value house too early. It does not assume that every partner house must be preserved.

## 4. Three examples

### Ari's avoidable jack seep

Ari holds 6♦, 6♥ and 9♦. The table has 10♦, A♥ and Ari's 9-house containing 7♥ + 2♠. Dev is known to hold the remaining jack.

Capturing the house gives Ari just two card points and leaves 10 + A for Dev to seep. Discarding either six leaves extra cards on the table and prevents that immediate seep. The bot now chooses a six across all 32 regression seeds for this recorded position.

### The last jack belongs to your partner

Suppose the table would be vulnerable to a jack, but the only unplayed jack is publicly known to belong to the bot's partner. The next opponent cannot hold that same card. The reviewed bot now removes that guaranteed card from the opponent's possible pool before estimating risk.

This avoids unnecessary defensive moves against an impossible threat. If another unaccounted-for jack remains, a threat can still exist.

### A clearance cannot earn a bonus

Suppose the opponents are below 20 card points and, even if they collected every point still available outside the bot's hand, they could not reach 20. A possible table clearance should not attract a 50-point seep penalty. The reviewed bot now recognises this case. Ordinary card points and the effects on later play still count in its move evaluation.

This is a conservative test: if qualifying is merely unlikely, rather than impossible under that bound, the bot still considers the seep threat.

## 5. What this review changed

| Finding | Change |
|---|---|
| Seep risk did not reserve other players' publicly guaranteed cards | Reserve those cards before estimating the next opponent's possible hand |
| A guaranteed non-threatening card still left the opponent with too many assumed unknown slots | Reduce their unknown slots by their known rank commitments |
| The extra seep-risk penalty could apply even when bonus eligibility was impossible | Check a conservative maximum of obtainable opponent card points |
| Forced choices and fallback decisions had no explanation | Record why the bot used that choice or fallback |

The legality engine, scoring rules and public-memory rules remain unchanged by this review. Focused regression tests cover each correction, alongside the previous jack-seep and high-value-suit examples.

## 6. How to review a questionable move

Finish the deal, then open **Game menu → Deal log → Review completed-deal decisions**. The report includes the player's hand at that turn, public table, legal alternatives, chosen move and decision analysis. Current-deal hidden hands remain unavailable in that review UI until the deal is complete.

| Report field | Meaning |
|---|---|
| `reason` | Why the bot selected the move or used a fallback |
| `knownRanks` | At least one card of each listed rank is publicly guaranteed; seats are You, Mira, Ari, Dev |
| `sweepRisk` | Approximate next-opponent seep threat: 0 means none detected; 1 means certain under the available information |
| `expectedMargin` | Average evaluated team advantage across the imagined hands; not necessarily the final score |
| `worstMargin` | Worst result among those four samples, not the worst possible result in the real game |
| `excludedCertainSweeps` | Moves removed because they exposed a certain seep and a safe alternative existed |

When reporting a move, identify the player and turn, their cards, the table, any publicly known opponent rank, and the alternative you expected. We can reproduce that situation and make it a regression test.

## 7. Limits to keep in mind

- Four imagined hands are a small sample. A good decision can still lose to a hand that was not sampled.
- Risk estimates are approximations. They reserve minimum guaranteed ranks, not an exact probability model of every possible deal.
- Endgame search explores at most 160 expanded positions per candidate and imagined hand, then finishes with quicker tactical replies. It is not exhaustive perfect play.
- Most earlier replies use a simpler tactical policy. They may miss multi-turn traps or sophisticated human plans.
- The bot remembers positive evidence such as a promised rank. It does not yet infer everything a player probably lacks from past discards or missed opportunities.
- The seep guard is deliberately conservative. It may reject a risky line that a stronger, longer search could justify.
- There are no separate difficulty levels, opponent-specific learning or player-style adaptation yet.

Useful future work would be stronger reply selection, broader testing against skilled people, and more samples when a decision is close. Those are future improvements, not features claimed by this version.

## 8. Validation and code map

The review adds `test/bot_review_test.dart`. Existing tests cover legal play, card conservation, public memory, save/resume, hidden-hand independence, Ari's reported mistake and choosing a scoring spade over a non-scoring equivalent.

Verification: all 57 tests passed, including the four new review regressions.

Run the repeatable benchmark with `dart run tool/benchmark_bots.dart 100`. It plays 200 deals using seeds 700–799 with both team assignments, against the preserved original bot. This is a useful comparison with a basic opponent, not proof of expert-level play.

| Result against the original bot | Previously recorded policy | Reviewed policy |
|---|---:|---:|
| Deal wins | 180 | 177 |
| Deal losses | 19 | 22 |
| Ties | 1 | 1 |
| Average score advantage | +156.01 | +159.46 |

**Interpretation:** the reviewed bot scored better on average but won three fewer deals. This is mixed evidence, not proof of an overall strength increase. The corrections are retained because the tests establish that they use public knowledge more accurately and avoid charging for an impossible bonus. No weights were tuned against these benchmark results.

The benchmark's raw seep counts include recorded final clearances, even though those earn no bonus. They should not be read as a count of 50-point bonuses. Native decision times in this review were 29.9 ms at the 95th percentile and 383.8 ms maximum while other validation work was running; these are not controlled speed comparisons or phone/browser timings.

| File | Purpose |
|---|---|
| `lib/game/bot.dart` | Move selection, imagined hands, seep risk and search |
| `lib/game/engine.dart` | Legal moves, public memory, save data and decision records |
| `lib/game/scoring.dart` | Seep eligibility and final scores |
| `test/bot_review_test.dart` | Regression tests added by this review |
| `test/public_memory_test.dart` | Ari's example and rank-memory guarantees |
| `tool/benchmark_bots.dart` | Repeatable strength and timing comparison |
