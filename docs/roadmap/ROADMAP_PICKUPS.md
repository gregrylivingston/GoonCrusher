# Roadmap: pickups, unlocks and prize games

How they work today: `docs/PICKUPS.md`. Tags and effort: `ROADMAP.md`. Prices and odds are fitted in `ROADMAP_BALANCE.md`.

## Planned
- **[0.3 want] Prize game values.** The eight games' value per play has not been measured since they were reworked (`CrushPrizes.GAMES` orders them weakest first on old numbers). Measure, then reorder. S.
- **[0.3 want] A "+XP" tag** flying to the gift box on the visor when a crush earns crush XP. S.
- **[later] Gems to spend,** cheapest first: a gem pouch (carry up to 3 into a run), a gem-paid continue (50 health and fuel, hooked in before `endLevel`, not in Goonpocalypse), respec. Waits on the author's answer about gems (`ROADMAP.md`, question 3). `PickupMenu.runGems` and `awardGems` exist and nothing calls them. M.
- **[later] Completion-count unlocks** (`clears:<tier>:<n>`): the rule exists, none is assigned.

## Suggestions
- **An "XP Boost" pickup or perk** (`car.crushXpMult`: nothing sets it yet).
- **Curses** (on hold: they add ways to lose a run): a `K.CURSE` kind in `Pickups.DATA`; five icons exist in `scripts/art/pickup_icons.js`, skipped by the generator.
- **`Modes.fillsBoxes`** and the `"boxes"` key in `Modes.DATA` are read only by a test: enforce the rule or drop the key.
