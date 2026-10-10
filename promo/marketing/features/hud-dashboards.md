# The HUD: a dashboard per car

**Pitch:** The HUD is the inside of the car you picked.

## What it is
- Two dials sunk into the bottom corners: revs, gear and fuel on the left; speed and hull on the right.
- One signature instrument per car: the sedan's odometer, the van's tilt gauge, the taxi's fare meter.
- A rear-view mirror at the top holds the clock and the goal, with dice (luck) and a clover hanging from it.
- Two sun visors: the gift box and the radio on the left; the star, coins and payout on the right.
- Five lamps on the dials show which system is damaged. Green, amber and red mean the same on every dash.

## Numbers
- 9 car dashboards plus a plain one (Classic Dashboard, in Accessibility) (`scene/player/hud/hud_skin.gd`).
- 8 instrument kinds (`hud_instrument.gd`, `KINDS`).
- A HUD Scale setting; flashes and swings obey Reduce Flashing and Reduce Motion.

## Demo vs full game
- Demo: the sedan's, the van's and the taxi's dashboards.
- Full game: the other six.

## What to show
- `elements hud_alone` and `trailer_launch hud_showcase` both use the racer (full game): copy the shot with `"car": "taxi"` for demo posts.
- Three dashboards side by side: **needs a shot**.
- `elements piece_results` for the results ticket.

Details: docs/HUD.md.
