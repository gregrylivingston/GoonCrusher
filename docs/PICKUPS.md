# Pickups

Pickups, the prize games, gift boxes and unlocks. The data is the source of truth: `Pickups.DATA` holds every pickup (kind, rarity, weight, text, tuning, its place in its unlock tree) and the comment above it explains the keys. This doc is the map, the rules that are easy to break, and the recipes.

## Files

| File | Owns |
|---|---|
| `scripts/global/pickups.gd` (`Pickups`) | The registry, the drop roll, offers (`rollOffer`, `openOr`), discovery, lures, the Time Warp flag, the run setup loadout tables. **Tune pickups here.** |
| `scripts/global/unlocks.gd` (`Unlocks`) | What is open (pickups, cars, levels, modes), the four states, prices, play conditions, buying. |
| `scripts/global/crush_prizes.gd` (`CrushPrizes`) | Gift boxes: crush XP, the box curve and tiers, which game a box holds. |
| `scene/pickups/pickup_effects.gd` (`PickupEffects`) | `collect(car, id, pos)`: what every pickup does. Also the crush hooks (combo, Coin Frenzy, Golden Ride), station hooks, Lottery and Blueprint payouts, toasts. |
| `scene/pickups/car_buff_fx.gd` (`CarBuffFx`) | A child of the player's car: draws timed power-ups and runs the ones that act every tick. |
| `scene/pickups/gadgets.gd` (`Gadgets`) | What Fire and Boost do with each gadget and boost, and when the AI driver fires one (`aiWantsUse`, `aiWantsMove`). |
| `scene/pickups/pickup_world.gd` (`PickupWorld`), `world_props.gd` (`WorldProps`), `pickup_nodes.gd` (`PickupNodes`) | The level's director (supply drops, events, chunk props, the wave chest); the challenges, events and props it places; what gadgets leave in the world. |
| `scene/pickups/menus/*` | The prize games on one frame, `PickupMenu`; `PrizePhysics` (loose objects) and `CardArt` (The Deal's card backs). Each script's header says how its game plays. |
| `scene/player/slots/` | `SlotMachine`, `SlotSymbols` (reels, bets, paylines), `GiftBox` (the box reveal). |
| `scene/player/menu/pickups/pickup_shop.gd` (`PickupShop`) | The Pickups screen (docs/UI.md, "Pickups"). |
| `scripts/art/pickup_icons.js` | Generates the pickup icons (no `_flat` twins: nothing draws them through the 3D text shader). |
| `tests/game/test_pickups.gd`, `test_unlocks.gd`, `test_crush_prizes.gd`, `test_prize_games.gd`; `tests/prize_lab/` | The tests; the prize lab ("Prize games"). |

## Rules

- **Collecting credits at once.** The flying icon, a menu's animation and a transition are visual only: never credit a reward from one.
- **Locked pickups never drop and are never offered.** `Pickups.candidates()` skips them; menus pick with `Pickups.rollOffer`; any code that hands out a fixed id goes through `Pickups.openOr(id)` (the nearest open pickup above it in its tree, else the Coin). `PickupEffects.collect`, `dropAndCollect` and `spawnPickup` already call it; the console's `pickup` passes `exact` to skip it.
- **Unlocks open only on the results ticket and on the Pickups screen**, never in a run, so a run's drop pool doesn't change under it.
- **Timed power-ups** are `car.addBuff(id)`, counted in physics ticks. One that changes handling is read inside `integrate()`, which stays pure and only reads `car.buffs`.
- **Time Warp** makes goons skip physics ticks (`Pickups.goonTickSkipped`). It never touches `physics_ticks_per_second`.
- **Crush overrides:** `car.crushOverride(goon)` is asked by `Walker.tryCrush` before any resist rule.
- **Two held slots:** a gadget (`heldItem`, Fire, action `UseItem`) and a boost (`moveItem`, Boost, action `UseMove`), both through `car.giveItem(id)`. The same one adds charges; a different one replaces it only if it is as rare or rarer, otherwise it is sold for coins.
- **Deferred spawns:** pickups, props and gadget nodes are added deferred (`PickupWorld.addToLevel`, `PickupEffects.spawnPickup`, `Gadgets.addNode`), because most spawns start in a physics callback.

## Drops

A crushed goon drops by a Clover roll in `Walker.destroy`. `Walker.dropTable()` hands `GoonFx` a table holding `Pickups.ROLL`, and when the drop lands `Root.getPowerupFromWeights` calls `Pickups.rollForCar(faction, bump)`:

1. **Ordinary drop:** a share of plain drops is a single Coin, shrinking as more pickups are unlocked (`ordinaryShare`) but always over a half, and Dice doesn't change it: the Coin drops more often than everything else put together. Giants and bosses skip it.
2. **Tier:** by `TIER_WEIGHTS`, raised by Dice, with a pity counter (`PITY`). Giants and bosses bump it a tier.
3. **Item:** a weighted pick among the tier's open pickups, filtered by mode and night, scaled by the goon's faction (`fac`). An empty tier falls back a tier.

- **Modes:** `modes` in `DATA` lists `Pickups.M` values. A variant mode drops what its base does (`Modes.plays`), and a mode can shut out whole kinds (`Modes.allowsKind`); both are in `Pickups.allowedIn`. A Trial drops nothing.
- `Walker.powerupDropDict` and `Root.LUCK_WEIGHT_BONUS` are the table from before rarities. Only a crushed Bandit's bonus drop still rolls from it (`Thief.onDeath`).

**Lures.** `Pickups.lures` holds what goons walk to instead of the car (`addLure`, `removeLure(key)`, `lureFor`): Goon Bait, the Flare, and two world props registered by `Spill`, the Dinner Bell and the Salt Lick. A goon in `move` goes to the newest lure in reach (state `lured`), so Bait pulls Defense goons off the station. A lure can take only one verb (`only`), only goons of a rank or more (`rank`), and let go while the car is near (`loose`). `lureFor` is asked by every goon, so it must not allocate.

**Critter Chain.** The Crush Combo counts every kill the player sets up near the car, so combo coins, Coin Frenzy and Golden Ride pay for those too. The rule lives in docs/GOONS.md, "Critter Chain". A gadget's kills must be credited with source `gadget` (`GoonFx.blast(..., &"gadget")`, `CarBuffFx.kill`), so they count at any distance.

## The world

`PickupWorld` (added by `Level._ready`; its header has the timings):

- **Supply drops and events** run on timers, one event at a time, each with a toast and an edge beacon. A level's `rules.events` weighs the events (`pickEvent`; docs/WORLD.md).
- **World events** (`WORLD_EVENTS`: the stampede, the flash flood, the Loot Truck's re-skins) start only where a level weighs them and aren't gated by pickup unlocks (`openEvents`). Their tells are unshaded.
- **Chunk props:** `ChunkView`'s last stage calls `PickupWorld.decorateChunk` with the chunk's own seed (`CHUNK_PROPS`), never in a station or start chunk. Props are children of the chunk's object node, so they unload with it and come back the same.
- **One-shot props:** a prop without a taken-set bit is remembered by position (`BreakableProp.makeOneShot`, `Spill.markUsed`), so a reloaded chunk leaves it out.
- **`WorldProps.RamTarget`** (Strongbox, Golden Goon, Loot Truck, pins) is a `CharacterBody2D` on the goon layer with `isDying` and `tryCrush`, so the car's crush code treats it like a goon.

## Gift boxes

Crushing earns crush XP toward the next gift box; each box holds one prize game. `CrushPrizes` holds the rules and numbers, `GameUI.checkGiftBox` (`playerRoot.gd`) counts and opens boxes, `GiftBox` is the reveal, and the left visor shows progress (docs/HUD.md).

- **XP and the curve:** XP is credited at the crush (`car.addCrushXp`, `CrushPrizes.crushXp`), also for indirect kills, and kept per run. Each box needs more than the last (`boxXp`), and its tier (`tierFor`) picks the game and the version it plays.
- **Which game:** `pickGame` rolls among the unlocked games, weakest for a low tier and strongest for a high one. A game is in the boxes once its Casino pickup is open.
- **The box credits nothing.** Boxes pay no star; waves do.
- **A box never opens over another screen:** one earned under a paused tree opens once it unpauses, and nothing pausing opens after the run has ended (`PickupMenu.runOver`), so nothing covers the results ticket.
- **Try it:** `-- --prize=<game id>` puts that game in every box.

## Prize games

Every game that pauses the run extends `PickupMenu` (`pickup_menu.gd`): one card of one size with a stage the game draws on, a status line and clickable key hints. It skids in under `GameHatch` and pauses the tree. The Scratch Card and Double or Nothing are not on it: they run in the HUD without pausing. The Pit Shop is on it but not in the boxes.

- **Same keys in every game:** `PickupMenu.ACT` (`UseItem`) does the main thing, the driving keys move or pick, `PickupMenu.REJECT` (`Horn`) turns down or retries. Never hard-code a key name.
- **Mouse alone must work:** stage clicks go to `onStageMouse`.
- **Credit as it is won** (`award`, `awardAll`, `awardCoins`, `awardGems`, `awardJunk`; `note` for what the game credited itself) and end on `showWinnings`. `awardAll` pays the rarest first, so a lesser gadget never takes the slot from a better one won with it.
- **No game pays another:** games never pay a Casino pickup (`Pickups.NOT_IN_GAMES`).
- **One at a time:** a game waits while another game, a gift box or the 3-2-1 is up (`otherScreenUp`).
- **Leaving** resumes through the quick 3-2-1 (`resumeRun`); `close(false)` is for when another pausing screen follows at once.
- **Harnesses:** every game joins group `slotMachine`, and tapping the action key alone must always get through it.

**The slot machine.** `SlotMachine` with `SlotSymbols`. The reels step in `_physics_process`, and the symbol on the pay line is exactly what pays (`SlotMachine.line`, `SlotSymbols.payouts`).

**Name tags.** Wherever an icon stands for something held or offered, its short name sits beside it (`Pickups.shortName`, `SHORT_NAMES`, `TAG_SIZE`, `TAG_MAX_PX`). A new long name needs a `SHORT_NAMES` entry: `test_crush_prizes.gd` measures every tag.

**The prize lab.** `tests/prize_lab/<game>.tscn`: open one and press F6, or `Godot --path . res://tests/prize_lab/claw.tscn`. It plays one game again and again on a scratch save with every pickup open, with no level or HUD (`PickupMenu.lab`), and its panel lists what each play really credited, to check against the winnings board. Keys and `-- --lab-shots` are in `prize_lab.gd`'s header.

## Unlocks

`Unlocks` is a class, not an autoload. Each owner keeps its own data: a pickup's place in its tree is in `Pickups.DATA` (`start`, `parent`, `after`, `needs`, `price`), a level's and a mode's gates are in `Root` (CLAUDE.md, "Flow"), a car's price is in `PlayerData.cars`. Ids are `pickup:<id>`, `car:<name>`, `level:<id>` and `mode:<level>:<mode>`.

- **Four states** (`Unlocks.state`): HIDDEN (its parent is locked), SHOWN (visible, but a condition or an `after` pickup is missing), READY (can be bought, or opens at the next results ticket), OPEN (saved in `meta.unlocks`). An unlock never closes again, even when its rule is retuned.
- **Trees:** one per kind. A root has no `parent`; only the `start` ones are open on a new save and the other roots are bought. Supplies has two roots so survival never depends on unlocks. Until a root is bought, nothing in its tree drops.
- **Prices** are placeholders: without a `price`, a pickup's cost comes from its rarity and depth, so no two of a rarity cost the same (`buildPrices`).
- **Play unlocks:** a pickup with `needs` has no price and opens on the results ticket once its conditions are met (`refresh`). The condition strings are listed above `needsMet`; `test_unlocks.gd` checks every one parses (`isValidNeed`). Their counters are `meta.lifetime`, added once per run by `countRun`.
- **Casino and the gift box games.** Casino is one tree rooted at the Claw Crane. Each gift box game names its Casino pickup (`CrushPrizes.GAMES`' `pickup`), and that one unlock opens both the drop and the game in the boxes; the games goons don't drop are `w` 0 pickups.
- **The demo** opens up to `DEMO_MAX_RARITY`, every root, and the Casino games straight under the root (`inDemo`).
- **Harnesses:** `Unlocks.allOpen` opens every pickup. Playtests and benchmarks default to it (`--unlocks=all`) so numbers compare with older runs; `--unlocks=save`, career playtests and `--play-start` use the save. The test runner sets it before every test.

## Save data

- `meta.pickups`: discovered pickups (`Pickups.discover`). Written in memory only; the run's save at the results ticket writes it.
- `meta.unlocks`: opened ids. `meta.lifetime`: the counters play unlocks read.
- `meta.records.loadout`, `boostLoadout`: the run setup's starting gadget and boost (`Pickups.LOADOUT`, `BOOST_LOADOUT`). Gems are spent at Start and the car takes both in `_ready`.
- `meta` sections are created on use (`get_or_add`), so a new one needs no `SAVE_VERSION` bump.

## Hooks in shared files

All that pickups add to files other systems own. Keep them when those files are rewritten.

| File | Hook |
|---|---|
| `lib/overhead_car_2d/overhead_car_body_2d.gd` | The pickup section at the end (`buffs`, `heldItem`, `moveItem`, `addBuff`, `giveItem`, `useItem`, `useMove`, `crushOverride`, `blockedByPickup`, `loseHealth`, `tickPickups`). `_ready` adds `CarBuffFx` and the loadout. `integrate()` reads Nitro. Also the fuel burn, `reward`, `damage`, `wearSystem`, `setHeadlightStrength` and `crushGoon` (`PickupEffects.onCrush`). |
| `scene/enemy/walker/walker.gd` | `_physics_process`: Time Warp skip and lures. `tryCrush`: `crushOverride`. `destroy`: `dropTable()`. |
| `scripts/global/root.gd` | `getPowerupFromWeights`: the `Pickups.ROLL` branch. |
| `scene/level/levelRoot.gd` | `_ready`: `Pickups.resetRun()` and `PickupWorld`. `stationReached`: `openPitShop`. `nightsSeen`. |
| `scripts/world/chunk_view.gd` | The EXTRAS stage: `PickupWorld.decorateChunk`. |
| `scripts/world/world_skin.gd` | `pickupIds()`: chunk floor pickups through `openOr`. |
| `scene/level/station.gd` | `_on_driveway_body_entered`: `PickupEffects.onStationReached`. `repairBarrier`. |
| `scripts/global/Region.gd` | `_process` wave: `PickupWorld.waveChest()`. |
| `scene/enemy/spawnManager.gd` | `increaseGiantOdds`: the Panic Button. `creditCrush`: `PickupEffects.onCrush`. |
| `scene/player/playerRoot.gd` | `addPickupWidgets`, `HudChance`, `checkGiftBox`. |
| `scene/player/menu/gameSummary.gd` | The Lottery row, Blueprints, `Unlocks.countRun` and `refresh`. |
| `scene/player/menu/main/main2.gd` | The loadout in run setup. |
| `scripts/ai/ai_driver.gd` | `pickupValue` reads `ai` from the registry. |
| `scene/powerup/powerup.gd`, `purse.gd`, `slotMachine.gd` | Discovery for the original pickups; the slot machine pickup opens `SlotMachine`. |

## Recipes

**Add a pickup**
1. Add the entry to `Pickups.DATA` with a `parent` of its kind (and `needs` for a play unlock).
2. Add its icon to `scripts/art/pickup_icons.js` (`ICONS`) and run `node scripts/art/pickup_icons.js`.
3. Add what it does to `PickupEffects.collect`. A gadget's or boost's use goes in `Gadgets.use` and `Gadgets.aiWantsUse` / `aiWantsMove`.
4. A long name needs a `SHORT_NAMES` entry. The Pickups screen, HUD flyers and tests read the rest from the registry.

**Add a prize game**
1. Extend `PickupMenu` in `scene/pickups/menus/`, with a static `open(tier)` and a header comment that says how it plays.
2. Credit through `award*` as prizes are won; roll prizes with `Pickups.rollOffer(minTier, Pickups.NOT_IN_GAMES, taken)`.
3. Add a `w` 0 Casino pickup for it in `Pickups.DATA` (with a `parent` in the Casino tree) and add that id to `NOT_IN_GAMES`.
4. Add it to `CrushPrizes.GAMES` (weakest first) and `CrushPrizes.openGame`.
5. Add a lab scene in `tests/prize_lab/` and make sure tapping the action key alone finishes it.

**Try things**
- Console: `pickup <id> [count]` collects any pickup, locked or not; `unlock pickups [id...]`, `lock pickups`, `unlocks`.
- `-- --pickups=a,b,c` collects these at the start; `-- --event=<event id>|supply` starts an event; `-- --prize=<game id>`; `-- --pickup-shots=...` with a bench run saves screenshots to `user://bench/` (`PickupWorld.giveFromCommandLine`, `screenshots`).

## Known gaps

- Nothing is tuned by hand: weights, prices, the box curve, the newer prize games.
- Monster Tires only scale the car's art; its collision stays the same size.
