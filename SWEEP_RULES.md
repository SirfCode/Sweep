# Sweep — Agreed Game Rules

Version 1.0. This rulebook records the rules agreed for this mobile game, based on Seep. It is the reference for implementing Sweep.

## 1. Players, teams, and terminology

- Use one standard 52-card deck, without jokers.
- Four players form two teams. Partners sit opposite each other.
- Play always moves to the next player on the right.
- **Game:** A sequence of deals, ending when a team leads by at least 104 cumulative points.
- **Deal:** The full distribution and play of all 52 cards, followed by scoring.
- **Hand:** The cards a player currently holds.
- **Turn / play:** One player plays exactly one card from their hand.
- **Table:** The shared area containing loose face-up cards and houses.
- **Captured pile:** Cards removed from the table, together with the cards used to capture them. These are kept separate from players' hands and scored for their team.
- **Rank value:** Ace = 1; numbered cards = their number; Jack = 11; Queen = 12; King = 13. All suits use these values for moves.
- **Card points:** The scoring value of a captured card, which is distinct from its rank value.

## 2. Objective and card points

Capture cards and earn eligible sweep bonuses to score for your team.

| Cards | Points |
|---|---:|
| Spades, Ace through King | Rank value: 1 through 13 |
| Ace of hearts, diamonds, or clubs | 1 each |
| Ten of diamonds | 6 |
| All other cards | 0 |

Spades total 91 points, the other three Aces total 3, and the ten of diamonds adds 6: **100 card points per deal**. The Ace of spades is counted once, for 1 point.

## 3. Dealer and seating

Randomly choose the first dealer from the four players.

For describing a deal, label the dealer Player 0, the player to their right Player 1, the opposite player Player 2, and the player to their left Player 3. Players 0 and 2 are partners; Players 1 and 3 are partners. These labels describe positions relative to that deal's dealer.

## 4. Initial cards and opening call

1. The dealer gives Player 1 four cards and places four cards face down on the table.
2. Player 1 looks at their own four cards before the table cards are revealed.
3. Player 1 calls a value from **9 to 13** and must hold a card of that rank.
4. If Player 1 holds no rank from 9 to 13, return all eight cards to the deck. The same dealer reshuffles the full deck and repeats the initial deal.
5. After a valid call, reveal the four table cards.

## 5. Opening move and completion of dealing

Player 1 makes the opening move using only their initial four cards. The dealer also distributes four initial cards each to Players 2, 3, and 0. Player 1 must complete the opening move before receiving additional cards.

The opening move must follow the called value:

- **Build:** Use one hand card to build a house of the called value, retaining a matching-rank card.
- **Capture:** Play a card of the called rank and capture all eligible table cards and combinations of that value.
- **Discard:** Only if neither building nor capturing the called value is possible, play the called-rank card as a loose table card.

If both building and capturing are possible, Player 1 may choose either. Capture opportunities at other values do not override the call.

After the opening move, deal two more rounds of four cards per player, in the order Player 1, Player 2, Player 3, Player 0. The deck is now exhausted.

Each player has received 12 cards, with four cards initially placed on the table. Player 1 has already played one card, so has 11 remaining; the other players have 12 each. Player 2 takes the next turn. Continue to the right until all hands are empty.

## 6. Choices on a normal turn

Play exactly one hand card to **capture**, **build or contribute to a house**, or **discard**, subject to house commitments.

- You may choose a legal build instead of a capture, even if the card played could capture loose cards.
- You may discard a card that captures nothing, even if another card in your hand could capture.
- If you are not using the card in a legal building move and it can capture, you must capture; you cannot leave it loose.
- On an empty table, play one card face up as a loose card.
- Having a house commitment does not prevent discarding other cards while retaining the required matching card.

The opening move follows the additional restrictions in Rule 5.

## 7. Capturing

Play a card of rank value V. It captures:

- Loose table cards of rank V.
- Groups of loose table cards whose rank values sum to V.
- Any house with declared value V, whether ordinary or pakka.

Take the played card and all captured cards into the captured pile. They never enter your hand. Captures may use any rank, **1 through 13**.

Capture all eligible, non-overlapping matches. Each table card may be used once. When combinations overlap, freely choose which combination to take; you need not maximize the number of cards or their points. Take any additional matching combinations available among the remaining cards.

Examples when playing a 10:

- Table 10, 6, 4, 7, 3: capture all of them.
- Table 6, 4, 4: choose one 4 to capture with the 6; leave the other 4.
- Table 6, 4, 3, 3: choose either 6 + 4 or 4 + 3 + 3.

Any player can capture any house of matching value, regardless of who built or contributed to it.

## 8. Houses: ordinary and pakka

Houses may have declared values **9, 10, 11, 12, or 13 only**. They stay on the table until captured.

- **Ordinary house:** One combination totaling its declared value, such as 6 + 4 making 10.
- **Pakka house:** Two or more combinations each totaling the same declared value. For example, 6 + 4 and 7 + 3 form a pakka house of 10, not a house of 20.
- A single matching-rank card can be an additional combination. Adding a loose 10 to a house of 10 makes it pakka.
- A pakka house can accept any number of further combinations of its value. Its value and pakka status remain unchanged.

Every house is indivisible. Its component cards cannot be separately captured or rearranged.

A house can only be captured with a card matching its declared value. It cannot be combined with loose cards to make a different capture value: a Queen cannot capture a house of 10 plus a loose 2, although it can capture a loose 10 plus a loose 2.

## 9. Building and adding to houses

Every building move must include the one card played from your hand as part of the resulting house. You cannot build using only table cards and discard a separate hand card.

For a new house, combine the played hand card with loose table cards to total a legal house value, and retain a matching-rank card.

A matching-rank hand card can also form its own combination alongside matching loose table cards or combinations to create a new pakka house. For example, with two 10s in hand and a loose 10 on the table, play one 10 to build a pakka house of 10 (two separate groups of 10), retaining the other 10 for capture. This is an alternative to capturing the loose 10.

When building or contributing at a value, include all available matching table cards and non-overlapping combinations, including matching houses. Do not deliberately leave a separate matching combination behind. Where combinations overlap, cards cannot be reused.

You may add a matching-rank hand card directly to a house instead of capturing it, provided the commitment requirement is satisfied. For example, with two 10s, add one to a house of 10 and retain the other. If your teammate is already committed to that house, you may add your only 10 under their commitment.

## 10. House commitments and teamwork

- A player creating a house must retain a card matching its declared value.
- That player cannot spend their last required matching card on another purpose while the commitment remains. They may use it to capture the house.
- A teammate may contribute under the existing commitment without holding a matching card.
- Such a teammate does not become personally committed even if they happen to hold a matching card.
- An opponent contributing must retain their own matching card unless their teammate is already committed to that house.
- The commitment ends when anyone captures the house or its value changes.
- A player may be committed to multiple different house values simultaneously and must retain a matching card for each.
- Commitments ensure that every house is captured before the deal ends.

## 11. Raising an ordinary house

Any player may raise an ordinary house, regardless of who built it, by adding **one card from their hand**. The new value must remain within 9–13, and the new matching-card commitment must be satisfied.

Loose table cards cannot be included to calculate the increase. For example, a house of 9 plus a played 2 becomes 11; a loose Ace cannot also be used to make it 12.

After raising the house, all other matching table cards, combinations, and houses must join it. For example, raising a house of 9 with a 2 while a loose Jack is on the table produces a pakka house of 11.

If the raised house merges with a house to which your teammate is already committed, you may rely on their matching card. Example: add an Ace to an ordinary house of 10 and merge it with your teammate's house of 11; you need not hold a Jack yourself.

Previous commitments to the old value end. Raising is sometimes described as breaking an ordinary house, but the house is never split into its component cards.

**A pakka house cannot be raised or changed to a different value.**

## 12. Sweeps

A sweep occurs when a capture clears the entire table.

| Timing of capture | Bonus |
|---|---:|
| First individual play of the entire deal | 25 |
| Any intermediate play | 50 |
| Final individual play of the entire deal | 0 |

Sweep bonuses belong to the capturing team. A team receives its sweep bonuses only if it finishes the deal with **at least 20 card points**, excluding bonuses. It need not have reached 20 when the sweep occurs. If it finishes below 20, discard all its sweep bonuses for that deal.

Examples:

- 15 card points and two normal sweeps: 15 total points.
- 20 card points and one normal sweep: 70 total points.
- 35 card points and two normal sweeps: 135 total points.

After a sweep, the next player places a loose card on the empty table and play continues.

## 13. End of deal and scoring

After the final card is played:

1. Award remaining loose table cards to the team that made the last capture. This automatic collection earns no sweep bonus.
2. No houses may remain; house commitments require their capture before play ends.
3. Count each team's captured-card points, including the awarded leftovers.
4. If a team has at least 20 card points, add its sweep bonuses; otherwise award it no sweep bonuses.
5. Add each team's deal score to its cumulative game score.

**Deal score = card points + eligible sweep bonuses.**

The winner or loser of this particular deal is determined by its deal scores, not cumulative scores.

## 14. Winning the game

Start both cumulative scores at zero. After scoring each complete deal, compare them.

- If one team leads by **104 or more points**, that team wins the game.
- Otherwise, play another deal.

Do not check the winning margin during a deal. Include all eligible sweep bonuses before checking it.

## 15. Choosing the next dealer

Use the latest deal's scores:

- **Current dealer's team loses:** The same dealer continues, subject to the three-count rule below.
- **Opposing team loses:** The player immediately to the current dealer's right becomes the dealer and starts a fresh count.
- **Tie:** The current dealer continues, subject to the same three-count rule.

For the current dealer, each loss or tie counts toward a limit of three. A tie counts as one loss for this dealer-rotation purpose; it does not reset the count or change the score result.

After the third counted deal, the dealer's partner takes over and begins a fresh count. This also applies if the third counted deal was a tie. If the game has ended, no further deal is needed.
