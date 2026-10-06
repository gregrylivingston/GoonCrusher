# Pickups

There are 78 pickups in nine kinds and five rarities. Everything you tune lives in `scripts/global/pickups.gd` (`Pickups.DATA`), in the same way as goons in `Goons.DATA`. The design came from the "GoonCrusher Powerup Plan" artifact (October 2026). Curses from that plan are on hold (see "Maybe" in `docs/GAMEPLAY_SUGGESTIONS.md`).

## Files

| File | What it does |
|---|---|
| `scripts/global/pickups.gd` (`Pickups`) | The registry, the drop roll, discovery (`meta.pickups`), lures and the Time Warp flag. |
| `scene/pickups/pickup.gd` + `pickup.tscn` (`GenericPickup`) | One scene for every pickup without its own. It inherits `scene/powerup/powerup.tscn`, takes its icon from the registry, and colours its outline by rarity (one shared material per tier). Rare and better pickups glow at night. |
| `scene/pickups/pickup_effects.gd` (`PickupEffects`) | `collect(car, id, pos)`: what every pickup does. Also the crush hooks (Crush Combo, Coin Frenzy, Golden Ride), the station hooks (Delivery, Barricade Kit), the Lottery and Blueprint payouts, and toasts. |
| `scene/pickups/car_buff_fx.gd` (`CarBuffFx`) | A child of the player's car. It draws the timed power-ups (plow blade, bubble, flames, spikes, the bomb on the roof) and runs the ones that act every tick: Magnet, Fire Trail, Wrecking Ball, Hot Potato and the Shortcut Map's arrows. |
| `scene/pickups/gadgets.gd` (`Gadgets`) | What the Use button does with each gadget, Jump Jets landing, and when the AI driver uses one. |
| `scene/pickups/pickup_nodes.gd` (`PickupNodes`) | Things gadgets leave in the world: Mine, OilSlick, Flare, Bait, Hubcap. |
| `scene/pickups/world_props.gd` (`WorldProps`) | Skill challenges, events and crates: Strongbox, Golden Goon, Loot Truck, bowling lane and pins, Ring Run, Speed Trap, Donut Zone, Bullseye, Prize Wheel, Crate, Supply Drop, Turret. |
| `scene/pickups/pickup_world.gd` (`PickupWorld`) | The level's director: supply drops and events on timers, chunk props, the region-wave chest, beacons and Speed Trap records. |
| `scene/pickups/menus/*` | Pausing menus on one base (`PickupMenu`): `PickupDeal` (The Deal), `ClawCrane`, `PitShop`. |
| `scene/player/hud/hud_items.gd`, `hud_chance.gd` | The HUD: gadget slot and buff rings; toasts, Scratch Card, Double or Nothing, combo, beacons, the Nuke's flash (`docs/HUD.md`). |
| `scene/player/slots/slot_symbols.gd` (`SlotSymbols`) | What the slot reels show, the bets, and paylines. |
| `scripts/art/pickup_icons.js` | Generates the new icons in `texture/icon/`. Change art there and re-run `node scripts/art/pickup_icons.js`; never edit the SVGs by hand. It writes a `.svg.import` with `svg/scale=1.5` for new files. There are no `_flat` twins, because nothing draws these icons through the 3D text shader. |
| `tests/game/test_pickups.gd` | Registry completeness, HUD targets, drop odds, pity, buffs on ticks, nitro in `integrate()`, crush overrides, the shield, the gadget slot, supplies, star fragments, combo, paylines, lottery. |

## The registry

Each entry in `Pickups.DATA` has these keys:
- `name`, `kind` (`Pickups.K`), `rarity` (`Pickups.R`) and `text` (the Goonopedia line; keep the numbers in it true).
- `w`: the weight inside its tier. 0 means goons never drop it; world props and events use 0.
- `icon` (`texture/icon/<icon>.svg`) and `ui`: the HUD group its flyer lands on.
- `ai`: its worth to the AI driver, where a crush is about 12. `AIDriver.pickupValue` reads it.

These keys are optional:
- `modes`: the `Pickups.M` values it drops in.
- `night`: only drops at night.
- `fac`: faction to weight multiplier.
- `scene`: the original 14 keep their scenes.
- `secs`: how long a timed effect lasts.
- `charges`: a gadget's uses.
- The item's own numbers (`fuel`, `repair`, `thrust`, `radius`, and so on).

**Adding a pickup:**
1. Add the entry to `Pickups.DATA`.
2. Add its icon to `scripts/art/pickup_icons.js` (`ICONS`) and run the script.
3. Add what it does to `PickupEffects.collect`. A gadget's use goes in `Gadgets.use` and `Gadgets.aiWantsUse`.
4. A timed power-up that changes handling goes in `integrate()`, which only reads `car.buffs`.

The Goonopedia, the HUD flyers and the tests pick the new pickup up from the registry.

## Drops

- **How often:** unchanged. A crushed goon drops about 5% of the time, plus about 0.5% per Clover point (`walker.gd`).
- **What drops:** `Walker.dropTable()` hands GoonFx a table holding `Pickups.ROLL`. When the drop lands, `Root.getPowerupFromWeights` sees that key and calls `Pickups.rollForCar(faction, bump)`.
  1. **Tier:** `TIER_WEIGHTS` = 64 / 26 / 8 / 1.6 / 0.4 for Common to Legendary. Each tier above Common is scaled by `1 + Dice / DICE_DIVISOR[tier]` (40, 25, 18, 12). Giants and bosses (Foreman) drop one tier up. After `PITY` (25) drops without a Rare or better, the next drop is a Rare.
  2. **Item:** a weighted pick inside the tier, filtered by mode and night and scaled by the goon's faction (`fac`). Scrap Gang drops more Nitro, Jerry Cans, Spark Plugs and EMPs; Wild Things drop more Repair Kits, Bait and Spare Tyres; the Goon Tribe drops more Wrenches, Toolboxes, Mines and Air Horns.
- **The old table:** `Walker.powerupDropDict` and `Root.LUCK_WEIGHT_BONUS` remain for reference and for `getPowerupFromWeights` with a plain table. Goons no longer use them.
- **Goonopedia shares:** `Goonopedia.dropShare(id, mode)` is a pickup's share of drops in a mode, before Dice and faction. The shares sum to 100 in every mode (tested).

## The kinds

| Kind | How it works | HUD |
|---|---|---|
| Supplies | Instant: fuel, hull, systems. The Wrench fixes the worst system by 35, a part (Spare Tyre, Bulb, Spark Plug, Tie Rod, Tank Patch) sets its system to 100, the Toolbox gives +40 to all, and Full Service fills everything. | Fuel/hull dials, system lamps |
| Tune-ups | The original +1 stat pickups. The Tune-up Crate gives +3 to one of the car's three weakest stats, the Overhaul +2 to all, and the Turbo Kit +12 Engine (plus flames). The Blueprint gives a free garage upgrade, credited at the results ticket. | Systems strip |
| Power-ups | `car.addBuff(id)`: physics ticks from `secs`, at most `MAX_BUFFS` (4); a fifth replaces the one with the least time left. The same one again adds its time. | Rings above the strip |
| Gadgets | `car.giveItem(id)`: one slot. The same gadget adds charges; a different one replaces it if it is as rare or rarer, otherwise it is sold for 10 × (rarity + 1) coins. **Use** (E or Space; X on a controller; rebindable as "Use Gadget") fires one charge (`Gadgets.use`). | Slot left of the rings |
| Loot | Coins, gems, Star Fragments (three make a star, `PickupEffects.addStarFragment`), the Strongbox (ram it three times above 300 px/s), the Golden Goon event. | Payout |
| Casino & Chance | The slot machine (paylines and bets, below); the Scratch Card and Double or Nothing in the HUD corner (no pause); the Mystery Box (any pickup, rarity re-rolled); the Lottery Ticket (paid on the results ticket); the Prize Wheel (a world prop); The Deal and the Claw Crane (pausing menus). | Corner card |
| Skill Challenges | World props and events (below), Hot Potato (blow up 5+ goons within 10 s or lose 25 hull), Delivery (reach the station above 30 hull for a star), Crush Combo. | Labels, toasts |
| Mode Specials | Stopwatch (+10 s, Sprint/Marathon), Fast Forward (-10 s, Countdown/Defense), Barricade Kit (+150 barrier when brought into the lot, Defense), Sentry Turret (Defense), Shortcut Map (route arrows from `AIRoute`, Sprint/Marathon), Panic Button (escalation holds 30 s, Goonpocalypse). | Clock, rings |

**Crush overrides.** `car.crushOverride(goon)` is true for:
- a Golden Ride or Monster Tires, against any goon;
- a Ram Plow, against a goon in the front arc;
- Spiked Rims, against a goon on the side.

`Walker.tryCrush` asks the car before any resist rule, and while one of these buffs runs the car crushes at any speed.

**Damage.** A Golden Ride and Jump Jets ignore damage. A Bubble Shield soaks all damage, and each hit over 5 (more than a crush's contact bump) uses one of its 3 charges. The shield and the Golden Ride also stop system wear, and Spiked Rims stop tyre wear.

**Time Warp** makes goons act on 2 physics ticks of every 5 (`Pickups.goonTickSkipped`, checked at the top of `Walker._physics_process`). It never touches `physics_ticks_per_second`.

**Lures.** Goon Bait (all goons within 1200 px) and the Flare (Buzzards only) add an entry to `Pickups.lures`. A goon in `move` or `siege` walks to the lure instead (state `lured`), so Bait pulls a Defense siege off the walls.

## The slot machine

- **Reels:** `SlotSymbols.pick()` rolls a tier with the reels' own odds (`TIER_WEIGHTS` 50/30/14/5/1), tilted up by Dice and the bet. It then picks a drop-eligible pickup of that tier, or STAR (6%, plus 2% per bet level). Pickups that pause the run (slot, Deal, Claw, Mystery Box) never show.
- **Bet:** before the first spin, Steer Left and Right choose 0, 25, 100 or 250 run coins. The bet is paid when the spin starts.
- **Paylines** (`SlotSymbols.payouts`): a pair pays its symbol twice and a triple five times, capped by rarity (`MAX_REPEAT`; a triple of Blueprints pays one). One or two stars pay Star Fragments; three are the jackpot, +1 star and five purses.
- **Dice:** a `luck / 500` chance that reel 3 copies reel 2.
- **Gems:** rerolling still costs 1 gem.
- **Crush goals** alternate between this machine and The Deal (`playerRoot.updateGoonsCrushed`).

## Menus that pause

- **Base:** `PickupMenu` dims the screen, shows one CardPanel in the menu theme, and ignores keys for 0.6 s so a held Accelerate can't pick something. It closes through the 3-2-1 countdown. Every pausing menu joins group `slotMachine`, so the playtest and bench harnesses tap Accelerate through it.
- **The Deal:** three cards of Uncommon or better. Steer to choose, Accelerate to take. Brake deals a new hand for 1 gem, and Use raises the hand one tier for 100 run coins, doubling each time.
- **Claw Crane:** steer, then Accelerate to drop. Off-centre grabs slip more and Dice slips less. Brake buys another grab for 150 run coins.
- **Pit Shop** (Marathon, each station but the last): three offers of Uncommon or better for 60 / 150 / 400 / 900 run coins. Spent coins don't reach the payout. Leaving opens the station's free slot machine.

## The world

`PickupWorld` (added by `Level._ready`) runs these:

- **Supply drops:** first after 60 to 90 s, then every 90 to 120 s, 1500 px ahead of the car. A crate parachutes in for 2.5 s and becomes a Rare-or-better pickup.
- **Events:** the Golden Goon, the Loot Truck, Goon Bowling and a Ring Run, one at a time. The first comes after 70 to 100 s, then one every 80 to 120 s. Each gets a toast and an edge-of-screen beacon.
- **Chunk props:** `TileManager.loadChunk` calls `PickupWorld.decorateChunk` with the chunk's own seed. Never in a station or start chunk. Chances per chunk: crates 10%, Speed Trap 3%, Donut Zone 2.5%, Bullseye 2.5%, Prize Wheel 2%, Ring Run start 2%, bowling lane 1%. Props are children of the chunk's object node, so they unload with it and come back the same.
- **The region-wave chest:** surviving a region wave (`Region._process`) also drops an Uncommon-or-better pickup ahead of the car.
- **Records:** the Speed Trap keeps a record per level in `meta.records.speedtrap`.

`WorldProps.RamTarget` (Strongbox, Golden Goon, Loot Truck, pins) is a `CharacterBody2D` on the goon layer with `isDying` and `tryCrush`, so the car's crush code treats it like a goon. The Strongbox and the Loot Truck always resist (the car scuffs and keeps the contact bump); the Golden Goon and pins crush and count. Crates are `Area2D`s that break above 200 px/s.

## Save data

- `meta.pickups` holds the pickups the player has found (`Pickups.discover`). It is only written in memory; the run's save at the results ticket writes it. The original 14 always show in the Goonopedia.
- `meta.records.loadout` holds the gadget chosen in run setup. The **Gadget** button (U / Y) cycles `Pickups.LOADOUT`, priced 1, 2 or 4 gems. The gems are spent at Start, and the car takes the gadget in `_ready` (`Pickups.loadout`).
- Blueprints add to the car's `upgrades` in `gameSummary` (`PickupEffects.creditBlueprints`), on the lowest stat that isn't maxed.

None of this needed a `SAVE_VERSION` bump: `meta` sections are created on use (`get_or_add`).

## Hooks in shared files

These lines are all that pickups add to files other systems own. They are marked with comments; keep them when those files are rewritten.

| File | Hook |
|---|---|
| `lib/overhead_car_2d/overhead_car_body_2d.gd` | The pickup section at the end (`buffs`, `heldItem`, `addBuff`, `giveItem`, `useItem`, `crushOverride`, `blockedByPickup`, `loseHealth`, `tickPickups`). `_ready` adds `CarBuffFx` and the loadout. `_physics_process` calls `tickPickups` and uses `crushBuffActive` for the crush speed. `integrate()` reads Nitro. Also: the fuel burn (Free Tank), `reward` (Coin Frenzy, `coinsSinceBet`), `damage` (`blockedByPickup`), `wearSystem`, `setHeadlightStrength` (Floodlights), and `crushGoon` (`PickupEffects.onCrush`). |
| `scene/enemy/walker/walker.gd` | `_physics_process`: Time Warp skip and lures. `tryCrush`: `crushOverride`. `destroy`: `dropTable()`. |
| `scripts/global/root.gd` | `getPowerupFromWeights`: the `Pickups.ROLL` branch. |
| `scene/level/levelRoot.gd` | `_ready`: `Pickups.resetRun()` and `PickupWorld`. `stationReached` opens the Pit Shop (`openPitShop`). |
| `scene/level/tileManager.gd` | `loadChunk`: `PickupWorld.decorateChunk`. |
| `scene/level/station.gd` | `_on_driveway_body_entered`: `PickupEffects.onStationReached`. `repairBarrier`. |
| `scripts/global/Region.gd` | `_process` wave: `PickupWorld.waveChest()`. |
| `scene/enemy/spawnManager.gd` | `increaseGiantOdds`: the Panic Button. |
| `scene/player/playerRoot.gd` | `addPickupWidgets`, `HudChance`, and The Deal on every other crush goal. |
| `scene/player/slots/*` | Reels from `SlotSymbols`; `slotMachine.payReels`, the bet. |
| `scene/player/menu/gameSummary.gd` | The Lottery row, best combo, Blueprints. |
| `scene/player/menu/main/main2.gd` | The gadget loadout in run setup. |
| `scene/player/menu/goonopedia/goonopedia.gd` | The Pickups tab from the registry, `dropShare(id, mode)`. |
| `scripts/ai/ai_driver.gd` | `pickupValue` reads `ai` from the registry. |
| `scripts/global/settings.gd`, `project.godot` | The `UseItem` action, rebindable as "Use Gadget". |
| `scene/powerup/powerup.gd`, `purse.gd`, `slotMachine.gd` | Discovery for the original pickups. |

## Known gaps and tuning

- Nothing is tuned by hand yet. The tier odds, weights, prices and event timers are first guesses for package 1's playtests. The run log doesn't count the new pickups by kind yet (the playtest's `goals` column shows what the AI chased).
- The AI driver values pickups by `ai` but has no plan for events (it ignores the Golden Goon, the Loot Truck, rings, the wheel), and its gadget use is a few simple rules (`Gadgets.aiWantsUse`).
- Monster Tires only scale the car's art; its collision stays the same size.
- The Bandit can steal new pickups like any other.
- The demo has every pickup. Decide whether `Root.IS_DEMO` should hold some back.
- The playtest harness hit a goon-list type error at the start of the second run of a multi-level playtest (`playtest.gd` `startNext` sets `basicGoons` from ints). It isn't pickup code; it belongs to the playtest owner.

## Testing

- **Dev console:** `pickup <id> [count]` collects any pickup in a run (`help` lists them).
- **Launch options** (`PickupWorld.giveFromCommandLine`):
  - `-- --pickups=nitro,plow,mine` collects these when the run starts.
  - `-- --event=goldgoon|truck|bowling|rings|supply` starts an event at once.
  - `-- --pickup-shots=deal,claw,pitshop,scratch,double,wheel,bowling,...` (with a bench run, for example `--bench=S2`) opens or places each one in turn and saves `user://bench/pickup_<id>.png`.
- **Rare glow:** a Rare-or-better pickup's light only shows at night (`GenericPickup._process`).
- **Deferred spawns:** pickups, props and gadget nodes are added deferred (`PickupWorld.addToLevel`, `PickupEffects.spawnPickup`, `dropAndCollect`, `Gadgets.addNode`), because most spawns start in a physics callback.
- **Beacons:** they keep clear of the top panels and the dials.
