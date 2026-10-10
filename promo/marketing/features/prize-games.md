# Prize games and gift boxes

**Pitch:** Crush enough goons and a gift box drops in, with an arcade machine inside.

## What it is
- Crushing earns crush XP; each full bar is a gift box, and each box holds one prize game.
- The run pauses, the game skids in under a hatch, and prizes are credited the moment they are won.
- Every game plays with the same inputs: act, move, turn down.
- Each ends on a winnings board that says what every prize did.
- Boxes come in tiers; a better box plays a better version of the game.

## Numbers
- 8 gift box games: Claw Crane, Hubcap Shuffle, Scratch Card, Goon Press, The Deal, Pachinko Drop, Slot Machine, Coin Pusher (`scripts/global/crush_prizes.gd`).
- 5 box tiers: Cardboard, Bronze, Silver, Gold, Diamond.
- A new save has one game open: the Claw Crane.
- 0.1 had the slot machine only, as a pickup.

## Demo vs full game
- Demo: Claw Crane, Hubcap Shuffle, Scratch Card.
- Full game: Goon Press, The Deal, Pachinko Drop, Slot Machine, Coin Pusher.

## What to show
- `elements prize_claw` (demo). `prize_slot`, `prize_slot_hatch` and `prize_pachinko` show full-game games.
- Hubcap Shuffle and the box reveal: **need shots** (`tests/prize_lab/` has a scene per game).

Prices and the box curve are placeholders: don't quote them.

Details: docs/PICKUPS.md ("Gift boxes", "Prize games").
