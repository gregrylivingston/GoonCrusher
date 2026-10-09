# Pickups

79 pickups in nine kinds and five rarities. Most start locked: each kind is a small unlock tree ("Unlocks", below). Everything you tune lives in `scripts/global/pickups.gd` (`Pickups.DATA`). Curses are on hold (`docs/GAMEPLAY_SUGGESTIONS.md`, "Maybe").

## Files

| File | What it does |
|---|---|
| `scripts/global/pickups.gd` (`Pickups`) | The registry, the drop roll, discovery (`meta.pickups`), lures and the Time Warp flag. |
| `scripts/global/unlocks.gd` (`Unlocks`) | What is open: pickups, cars, levels and modes, their four states, prices, play conditions and buying (`meta.unlocks`, `meta.lifetime`). |
| `scene/pickups/pickup.gd` + `pickup.tscn` (`GenericPickup`) | One scene for every pickup without its own. It inherits `scene/powerup/powerup.tscn`, takes its icon from the registry, and colours its outline by rarity (one shared material per tier). Rare and better pickups glow at night. |
| `scene/pickups/pickup_effects.gd` (`PickupEffects`) | `collect(car, id, pos)`: what every pickup does. Also the crush hooks (Crush Combo, Coin Frenzy, Golden Ride), the station hooks (Delivery, Barricade Kit), the Lottery and Blueprint payouts, and toasts. |
| `scene/pickups/car_buff_fx.gd` (`CarBuffFx`) | A child of the player's car. It draws the timed power-ups (plow blade, bubble, flames, spikes, the bomb on the roof) and runs the ones that act every tick: Magnet, Fire Trail, Wrecking Ball, Hot Potato and the Shortcut Map's arrows. |
| `scene/pickups/gadgets.gd` (`Gadgets`) | What the Fire and Boost buttons do with each gadget and boost, Jump Jets and Hop landing, and when the AI driver fires one (`aiWantsUse`, `aiWantsMove`). |
| `scene/pickups/pickup_nodes.gd` (`PickupNodes`) | Things gadgets leave in the world: Mine, OilSlick, Flare, Bait, Hubcap. |
| `scene/pickups/world_props.gd` (`WorldProps`) | Skill challenges, events and crates: Strongbox, Golden Goon, Loot Truck, bowling lane and pins, Ring Run, Speed Trap, Donut Zone, Bullseye, Prize Wheel, Crate, Supply Drop, Turret. |
| `scene/pickups/pickup_world.gd` (`PickupWorld`) | The level's director: supply drops and events on timers, chunk props, the wave chest, beacons and Speed Trap records. |
| `scene/pickups/menus/*` | Pausing menus on one base (`PickupMenu`): `PickupDeal` (The Deal), `ClawCrane`, `PitShop`, and the gift box games `PrizeWheelMenu` and `PrizeVault`. |
| `scripts/global/crush_prizes.gd` (`CrushPrizes`), `scene/player/slots/gift_box.gd` (`GiftBox`) | Gift boxes: crush XP, the box curve and tiers, the prize game ladder and its unlocks; the box reveal. |
| `scene/player/hud/hud_items.gd`, `hud_chance.gd` | The HUD: gadget slot and buff rings; toasts, Scratch Card, Double or Nothing, combo, beacons, the Nuke's flash (`docs/HUD.md`). |
| `scene/player/slots/slot_symbols.gd` (`SlotSymbols`) | What the slot reels show, the bets, and paylines. |
| `scripts/art/pickup_icons.js` | Generates the new icons in `texture/icon/`. Change art there and re-run `node scripts/art/pickup_icons.js`; never edit the SVGs by hand. It writes a `.svg.import` with `svg/scale=1.5` for new files. There are no `_flat` twins, because nothing draws these icons through the 3D text shader. |
| `tests/game/test_pickups.gd` | Registry completeness, HUD targets, drop odds, pity, buffs on ticks, nitro in `integrate()`, crush overrides, the shield, the gadget and boost slots, Nitro charges, supplies, star fragments, combo, paylines, lottery. |

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
- `start`, `parent`, `needs`, `price`: its place in its kind's unlock tree ("Unlocks", below).
- The item's own numbers (`fuel`, `repair`, `thrust`, `radius`, and so on).

**Adding a pickup:**
1. Add the entry to `Pickups.DATA`, with a `parent` of its kind (or `needs` too, for a play unlock).
2. Add its icon to `scripts/art/pickup_icons.js` (`ICONS`) and run the script.
3. Add what it does to `PickupEffects.collect`. A gadget's use goes in `Gadgets.use` and `Gadgets.aiWantsUse`.
4. A timed power-up that changes handling goes in `integrate()`, which only reads `car.buffs`.

The Goonopedia, the HUD flyers and the tests pick the new pickup up from the registry.

## Drops

- **How often:** a crushed goon drops about 5% of the time, plus about 0.5% per Clover point (`walker.gd`).
- **What drops:** `Walker.dropTable()` hands GoonFx a table holding `Pickups.ROLL`. When the drop lands, `Root.getPowerupFromWeights` sees that key and calls `Pickups.rollForCar(faction, bump)`.
  1. **Tier:** `TIER_WEIGHTS` = 64 / 26 / 8 / 1.6 / 0.4 for Common to Legendary. Each tier above Common is scaled by `1 + Dice / DICE_DIVISOR[tier]` (40, 25, 18, 12). Giants and bosses (Foreman) drop one tier up. After `PITY` (25) drops without a Rare or better, the next drop is a Rare.
  2. **Item:** a weighted pick inside the tier, filtered by mode and night and scaled by the goon's faction (`fac`). Scrap Gang drops more Nitro, Jerry Cans, Spark Plugs and EMPs; Wild Things drop more Repair Kits, Bait and Spare Tyres; the Goon Tribe drops more Wrenches, Toolboxes, Mines and Air Horns.
- **The old table:** `Walker.powerupDropDict` and `Root.LUCK_WEIGHT_BONUS` serve only `getPowerupFromWeights` with a plain table; goons don't use them.
- **Goonopedia shares:** `Goonopedia.dropShare(id, mode)` is a pickup's share of drops in a mode, before Dice and faction. The shares sum to 100 in every mode (tested).

## The kinds

| Kind | How it works | HUD |
|---|---|---|
| Supplies | Instant: fuel, hull, systems. The Wrench fixes the worst system by 35, a part (Spare Tyre, Bulb, Spark Plug, Tie Rod, Tank Patch) sets its system to 100, the Toolbox gives +40 to all, and Full Service fills everything. | Fuel/hull dials, system lamps |
| Tune-ups | The original +1 stat pickups. The Tune-up Crate gives +3 to one of the car's three weakest stats, the Overhaul +2 to all, and the Turbo Kit +12 Engine (plus flames). The Blueprint gives a free garage upgrade, credited at the results ticket. | Systems strip |
| Power-ups | `car.addBuff(id)`: physics ticks from `secs`, at most `MAX_BUFFS` (4); a fifth replaces the one with the least time left. The same one again adds its time. | Rings above the strip |
| Gadgets | `car.giveItem(id)`: the Fire slot (`heldItem`). The same gadget adds charges; a different one replaces it if it is as rare or rarer, otherwise it is sold for 10 × (rarity + 1) coins. **Fire** (E; X on a controller; rebindable as "Fire Gadget", action `UseItem`) fires one charge (`Gadgets.use`). | Slot left of the rings |
| Boosts | Nitro (2 burns of 3 s), Hop (3 short hops, no landing blast) and Jump Jets (2 hops that crush on landing). `car.giveItem(id)` puts them in the Boost slot (`moveItem`), with the Fire slot's rules. **Boost** (Shift; LB on a controller; rebindable as "Boost / Hop", action `UseMove`) fires one charge (`car.useMove`, `Gadgets.use`). Nitro's burn is the timed buff `integrate()` reads. | Slot beside the gadget |
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

**Lures.** Goon Bait (all goons within 1200 px) and the Flare (Buzzards only) add an entry to `Pickups.lures`. A goon in `move` or `siege` walks to the lure instead (state `lured`), so Bait pulls a Defense siege off the walls. `Pickups.lureFor` walks the list backwards and drops spent lures as it goes, without copying it (every goon asks every tick), so the newest lure in reach wins; long-lived world lures (the Dinner Bell, the Salt Lick) can use the same list.

**Critter Chain.** The Crush Combo counts every kill the player sets up within 900 px of the car (`SpawnManager.CRITTER_CREDIT_PX`), not only bumper crushes: logs, bees, floods, falls, blasts, trampling, quills and drownings (docs/GOONS.md, "Wild instincts"). So combo coins, Coin Frenzy and Golden Ride pay for those too. A kill farther off credits nothing, except the player's own gadgets (blasts with source `gadget`: the Airstrike, Land Mine, Goon Bait, Hot Potato, and `CarBuffFx.kill`: the Nuke, Hubcap, Jets) and a drowning the car pushed, which count anywhere but join the chain only near the car. A chain that mixes sources shows in gold as "CRITTER CHAIN x9: LOGS + BEES + SPLASH" and pays more crush XP (below).

**Air Horn and herds.** The horn stuns goons in its radius, but a Thunderhoof herd stampedes away from it instead (`GoonVerbs.Herd.spook`).

## The slot machine

- **Reels:** `SlotSymbols.pick()` rolls a tier with the reels' own odds (`TIER_WEIGHTS` 50/30/14/5/1), tilted up by Dice and the bet. It then picks a drop-eligible pickup of that tier, or STAR (6%, plus 2% per bet level). Pickups that pause the run (slot, Deal, Claw, Mystery Box) never show.
- **Bet:** before the first spin, Steer Left and Right choose 0, 25, 100 or 250 run coins. The bet is paid when the spin starts.
- **Paylines** (`SlotSymbols.payouts`): a pair pays its symbol twice and a triple five times, capped by rarity (`MAX_REPEAT`; a triple of Blueprints pays one). One or two stars pay Star Fragments; three are the jackpot, +1 star and five purses.
- **Dice:** a `luck / 500` chance that reel 3 copies reel 2.
- **Gems:** rerolling still costs 1 gem.
- **From a gift box** (below) the machine is a free spin, and the box's tier adds free bet levels on top of the bet (`SlotSymbols.bonus`).
- **Name tags:** each reel symbol has its short name under it (`slot_award_icon.gd`).

## Gift boxes

Crushing earns **crush XP** toward the next **gift box**; each box holds one prize game. `CrushPrizes` (`scripts/global/crush_prizes.gd`) holds the rules, `GameUI` (`playerRoot.gd`) counts and opens the boxes, `GiftBox` (`scene/player/slots/gift_box.gd`) is the reveal and `HudCrush` the HUD pill. Roadmap package 16.

- **Crush XP** (`CrushPrizes.crushXp`, credited by `car.addCrushXp` at the crush, also for blasts and drownings): by goon rank, 1 / 3 / 8 (fodder, special, heavy), ×4 for a giant, ×10 for a boss. On top: +5% per crush in the combo chain (up to +100%), +50% for a slam or drift crush, +50% at night, times `car.crushXpMult` (for pickups and perks), times the Critter Chain's variety bonus: +10% per distinct kill source in the live chain past the first, at most +40% (`CrushPrizes.varietyBonus`, `VARIETY_STEP`, `VARIETY_MAX`). XP is kept per run in `car.crushXp`.
- **The curve:** box *n* needs `50 × n²` XP on its own (50, 200, 450, 800, 1250...), and leftover XP carries on (`boxXp`, `boxAt`). AI playtests of 3-4 minutes made 150-1300 XP (2-7.5 per crush as giants and combos pile up): 1-3 boxes, fewer than the old crush goals (12, 39, 79, 131 crushes) gave the same runs. Boxes no longer pay a star; waves do.
- **Tiers:** box 1 is Cardboard, then Bronze, Silver, Gold, and Diamond from box 5. The tier picks the game and its version.
- **The games, weakest first**, measured with each game's own rolls (no bet, no Dice, every pickup open; rarity points per play, Common 1 to Legendary 16):

  | Game | Value per play | Box versions |
  |---|---|---|
  | Claw Crane | 1.05 for an average grab, 2.67 aimed at the best prize | 1 free grab, 2 from Silver, 3 at Diamond; slips 3% less per tier; a Rare-or-better heap from Gold |
  | Scratch Card | 2.12 | matches 7% more often per tier; a pair pays 1 + tier / 2, a triple 3 + tier |
  | Prize Wheel (`PrizeWheelMenu`, a pausing version of the world wheel) | 2.78, and it can bust | Bronze: no busts; Silver: coin wedges doubled; Gold: the Wrench is a Gem; Diamond: the Nitro is a second Jackpot |
  | The Deal | 2.77, one card but your pick | Rare or better from Silver, Epic or better at Diamond |
  | Slot Machine | 6.95, three reels pay three things | free bet levels = tier |
  | The Vault (`PrizeVault`, new) | highest: 2 of 5 sealed boxes of Rare or better | Epic or better from Gold; 3 picks at Diamond |

- **Which game:** `pickGame` rolls among the **unlocked** games: a Cardboard box favours the weakest, a Diamond box the strongest, the others less the further they are from that. A new save opens only the Claw Crane. The rest are unlocks `prize:<id>` in `meta.unlocks` (prices in `CrushPrizes.GAMES`: Scratch Card 3,000, Prize Wheel 8,000, The Deal 18,000, Slot Machine 40,000, The Vault 80,000 and 10 gems; opened in ladder order: `CrushPrizes.state`, `grant`); harnesses open every game (`Unlocks.allOpen`). The Goonopedia sells them: a PRIZE GAMES ladder at the top of the Pickups tab (docs/UI.md), bought through `Unlocks.buy("prize:<id>")` (`Unlocks.state` and `price` hand "prize:" ids to `CrushPrizes`). The career personas buy them like pickups.
- **The box:** it pauses the run, drops in, rattles, pops its lid on the game (name and tier) and opens it after 1.9 s; Accelerate or a click skips ahead. It credits nothing. Headless runs and harnesses skip it (`Transition.instant()`), Reduce Motion drops the shake. The Scratch Card runs in the HUD corner, so the box resumes the run through the 3-2-1 before it starts. A box earned under a paused tree opens once it unpauses (`GameUI.checkGiftBox`, every frame).
- **After the run:** no pausing screen opens once the run has ended (`PickupMenu.runOver`, also checked by the slot machine and the box): a pickup or box landing in the same frame as the end never covers the results ticket.
- **Testing:** `-- --prize=<game id>` puts that game in every box. `-- --pickup-shots=giftbox:<tier>:<game>,prizewheel:<tier>,vault:<tier>` (with a bench run) screenshots them. The run log and playtest results carry `crush_xp` and `boxes`.

## Name tags

Wherever an icon stands for something held or offered, its short name is printed beside it in small type (`Pickups.shortName`: the name, or `Pickups.SHORT_NAMES` for the 11 that are too long; `TAG_SIZE` 12, at most `TAG_MAX_PX` 84 px wide, checked by `test_crush_prizes.gd`):

- the held gadget (E / X) and boost (Shift / LB) boxes, above each (`hud_items.gd`);
- a power-up's ring, for its first 3 s (staggered so neighbours don't touch);
- slot reels, under each symbol; the Scratch Card's cells; the prize the Claw Crane is over; the Vault's opened boxes.

The Deal's cards and the Pit Shop already show full names, and the Mystery Box names its prize in a toast.

## Menus that pause

- **Base:** `PickupMenu` dims the screen, shows one CardPanel in the menu theme, and ignores keys for 0.6 s so a held Accelerate can't pick something. It closes through the 3-2-1 countdown. Every pausing menu joins group `slotMachine`, so the playtest and bench harnesses tap Accelerate through it.
- **The Deal:** three cards of Uncommon or better. Steer to choose, Accelerate to take. Brake deals a new hand for 1 gem, and Use raises the hand one tier for 100 run coins, doubling each time.
- **Claw Crane:** steer, then Accelerate to drop. Off-centre grabs slip more and Dice slips less. Brake buys another grab for 150 run coins.
- **Prize Wheel** and **The Vault:** gift box games only ("Gift boxes" above). The wheel: Accelerate spins, the wedge pays the moment it stops, Accelerate leaves. The Vault: steer to a sealed box, Accelerate opens it (credited at once, and the focus moves to the next sealed one); when the picks are spent the rest are shown and Accelerate leaves.
- **Pit Shop** (Marathon, each station but the last): three offers of Uncommon or better for 60 / 150 / 400 / 900 run coins. Spent coins don't reach the payout. Leaving opens the station's free slot machine.

## The world

`PickupWorld` (added by `Level._ready`) runs these:

- **Supply drops:** first after 60 to 90 s, then every 90 to 120 s, 1500 px ahead of the car. A crate parachutes in for 2.5 s and becomes a Rare-or-better pickup.
- **Events:** the Golden Goon, the Loot Truck, Goon Bowling and a Ring Run, one at a time. The first comes after 70 to 100 s, then one every 80 to 120 s. Each gets a toast and an edge-of-screen beacon.
- **Chunk props:** `ChunkView`'s last stage calls `PickupWorld.decorateChunk` with the chunk's own seed and moves each group onto one of the recipe's open `spots` (docs/WORLD.md). Never in a station or start chunk. Chances per chunk: crates 10%, Speed Trap 3%, Donut Zone 2.5%, Bullseye 2.5%, Prize Wheel 2%, Ring Run start 2%, bowling lane 1%. Props are children of the chunk's object node, so they unload with it and come back the same.
- **The wave chest:** each wave survived (`Region._process`, one clock for the whole run) also drops an Uncommon-or-better pickup ahead of the car.
- **Records:** the Speed Trap keeps a record per level in `meta.records.speedtrap`.

`WorldProps.RamTarget` (Strongbox, Golden Goon, Loot Truck, pins) is a `CharacterBody2D` on the goon layer with `isDying` and `tryCrush`, so the car's crush code treats it like a goon. The Strongbox and the Loot Truck always resist (the car scuffs and keeps the contact bump); the Golden Goon and pins crush and count. Crates are `Area2D`s that break above 200 px/s.

## Unlocks

`scripts/global/unlocks.gd` (`Unlocks`, a class, not an autoload) answers what is open for pickups, cars, levels and modes. Each owner keeps its own data: a pickup's place in its tree is in `Pickups.DATA`, a level's gate is `LevelDef.unlockModes` modes beaten on the level before, of which `Root.MEDIUM_TO_OPEN` by act (0, 1, 2) on Medium or harder (`Root.opensNextLevel`; the mode chain is `Root.isModeUnlocked`), and a car's price is `cost` and `gems` in `PlayerData.cars`. Ids are `pickup:<id>`, `car:<name>`, `level:<id>` and `mode:<level>:<mode>` (`prize:<game>` for the gift box games, `CrushPrizes`).

**Four states** (`Unlocks.state(uid)`):
- **HIDDEN:** its parent is still locked. The Goonopedia shows "???".
- **SHOWN:** its parent is open but its play condition isn't met. It shows a dimmed preview, the condition and a progress bar.
- **READY:** it can be bought, or opens at the next results ticket.
- **OPEN:** saved in `meta.unlocks`. An unlock never closes again, even when its rule is retuned.

**The trees.** Each kind is its own tree. A root (`start`) is open on a new save: Fuel Can and Repair Kit (Supplies has two roots, so survival never depends on unlocks), Engine, Magnet, Air Horn, Nitro, Coin, Slot Machine, Speed Trap and Fast Forward. Every other pickup names its `parent`, a pickup of its kind that must be open first. Crush Combo (`R.SYSTEM`) is always on and outside the trees. `Unlocks.treeOrder(kind)` lists a kind root first, depth first, and the Goonopedia shows them in that order.

**Prices** are a first fit to the career playtests (package 1, B-4), by rarity in `Unlocks.PICKUP_PRICE`: Common 1,000 coins, Uncommon 3,000, Rare 8,000, Epic 20,000 and 5 gems, Legendary 15 gems. A `price` in the entry overrides it.

**Play unlocks.** A pickup with `needs` has no price: it opens on the results ticket once its parent is open and every condition is met (`Unlocks.refresh`). There are ten: Headlights and Flare (drive through a night), Floodlights (3 nights), Monster Tires (crush 10 giants), EMP (crush 150 Scrap goons), Delivery (win a Sprint), Blueprint (open Quarry), Stopwatch (Sprint open anywhere), Barricade Kit (Defense open anywhere) and Panic Button (survive 3:00 of Goonpocalypse). The conditions are strings: `nights:<n>`, `giants:<n>`, `crushes:<n>`, `crushed:<faction>:<n>`, `wins:<mode>:<n>`, `mode:<mode>`, `open:<level>`, `survive:<seconds>`, `clears:<tier>:<n>` (mode-and-level completions on that tier or harder: `clears:medium:5` is five silver or gold medals; `ModeTiers.clears`), `boxes:<n>` (gift boxes opened over every run). Their counters are `meta.lifetime` (`runs`, `nights`, `giants`, `wins_<mode>`, `boxes` and `bestBox`, added once per run by `Unlocks.countRun` on the results ticket), `goonsCrushed` and the Goonpocalypse records. `test_unlocks.gd` checks that every condition parses (`isValidNeed`).

**Locked pickups never turn up:**
- `Pickups.candidates()` skips them, which covers goon drops, the Mystery Box, slot reels, The Deal, the Claw, the Pit Shop, supply drops, the wave chest, the Loot Truck, the Ring Run, the wheel's jackpot and crates.
- Menus pick with `Pickups.rollOffer(minTier, never, taken)`, which settles for lower tiers or a repeat when few pickups are open.
- Fixed rewards go through `Pickups.openOr(id)`, the nearest open pickup above it in its tree: the wheel's wedges, the Donut Zone's crate, Coin Stack padding, the slot jackpot's purse and the chunk floor pickups (`WorldSkin.pickupIds()`). `PickupEffects.collect`, `dropAndCollect` and `spawnPickup` call it, so a fixed id elsewhere is covered too. The console's `pickup` passes `exact` to skip it.
- The Scratch Card's pool, world events (`PickupWorld.EVENTS`) and chunk challenges (`CHUNK_PROPS`) leave locked ones out.
- Run setup sells only open gadgets and boosts (`Pickups.openLoadout`).

Unlocks open only on the results ticket and in the Goonopedia, never in a run, so a run's drop pool doesn't change under it.

**Buying.** The Goonopedia's Pickups tab (docs/UI.md) shows each locked tile's price or PLAY in its corner (gold when the bank covers it). Accept on a focused tile, a second click on it, or the card's BUY button calls `Unlocks.buy(uid)`, which spends the bank, opens it and runs `refresh`. Run setup's "Next unlock" line names the nearest one (`Unlocks.nextUnlock`), and the results ticket lists what play opened ("Unlocked", NEW PICKUP).

**Cars.** Entry cars (sedan, van, taxi, pickup) cost coins. Advanced ones also cost gems: semi 3, audi and racer 5, police 10, ambulance 15 (`gems` in `PlayerData.cars`). `SaveManager.unlockCar` goes through `Unlocks.buy("car:<name>")`.

**The demo** opens Commons and Uncommons only (`Unlocks.DEMO_MAX_RARITY`); rarer tiles say FULL GAME. Its roots stay open, the Slot Machine included.

**Harnesses.** `Unlocks.allOpen` opens every pickup. Playtests and benchmarks set it by default (`--unlocks=all`), so their numbers compare with older runs; `--unlocks=save` uses the save. Career playtests and `--play-start` use the save, and career tiers open pickups down each tree up to a rarity (`CareerStart.TIERS`, `pickups`). The test runner sets it before every test; `test_unlocks.gd` turns it off.

## Save data

- `meta.pickups` holds the pickups the player has found (`Pickups.discover`). It is only written in memory; the run's save at the results ticket writes it.
- `meta.unlocks` holds the unlocked ids (`pickup:<id>` = true); `meta.lifetime` the counters play unlocks read. Save version 6 added them; older saves start over (CLAUDE.md, "Save data").
- Run setup sells a starting consumable for each slot (docs/UI.md, "Run setup"): `meta.records.loadout` holds the gadget (the **Gadget** button, F / Y, cycles `Pickups.LOADOUT`, 1 to 4 gems) and `meta.records.boostLoadout` the boost (**Boost**, V / RS, `Pickups.BOOST_LOADOUT`). The gems are spent at Start, the car takes both in `_ready` (`Pickups.loadout`, `Pickups.boostLoadout`), and `announceLoadout` toasts each with its key once the run is under way.
- Blueprints add to the car's `upgrades` in `gameSummary` (`PickupEffects.creditBlueprints`), on the lowest stat that isn't maxed.

`meta.pickups` needed no `SAVE_VERSION` bump: `meta` sections are created on use (`get_or_add`).

## Hooks in shared files

These lines are all that pickups add to files other systems own. They are marked with comments; keep them when those files are rewritten.

| File | Hook |
|---|---|
| `lib/overhead_car_2d/overhead_car_body_2d.gd` | The pickup section at the end (`buffs`, `heldItem`, `moveItem`, `addBuff`, `giveItem`, `useItem`, `useMove`, `crushOverride`, `blockedByPickup`, `loseHealth`, `tickPickups`). `_ready` adds `CarBuffFx` and the loadout. `_physics_process` calls `tickPickups` and uses `crushBuffActive` for the crush speed. `integrate()` reads Nitro. Also: the fuel burn (Free Tank), `reward` (Coin Frenzy, `coinsSinceBet`), `damage` (`blockedByPickup`), `wearSystem`, `setHeadlightStrength` (Floodlights), and `crushGoon` (`PickupEffects.onCrush`). |
| `scene/enemy/walker/walker.gd` | `_physics_process`: Time Warp skip and lures. `tryCrush`: `crushOverride`. `destroy`: `dropTable()`. |
| `scripts/global/root.gd` | `getPowerupFromWeights`: the `Pickups.ROLL` branch. |
| `scene/level/levelRoot.gd` | `_ready`: `Pickups.resetRun()` and `PickupWorld`. `stationReached` opens the Pit Shop (`openPitShop`). |
| `scripts/world/chunk_view.gd` | The EXTRAS stage: `PickupWorld.decorateChunk`. |
| `scene/level/station.gd` | `_on_driveway_body_entered`: `PickupEffects.onStationReached`. `repairBarrier`. |
| `scripts/global/Region.gd` | `_process` wave: `PickupWorld.waveChest()`. |
| `scene/enemy/spawnManager.gd` | `increaseGiantOdds`: the Panic Button. |
| `scene/player/playerRoot.gd` | `addPickupWidgets`, `HudChance`, and the gift boxes (`checkGiftBox`). |
| `scene/player/slots/*` | Reels from `SlotSymbols`; `slotMachine.payReels`, the bet. |
| `scene/player/menu/gameSummary.gd` | The Lottery row, best combo, Blueprints; `Unlocks.countRun` and `refresh` (the Unlocked row). |
| `scene/player/menu/main/main2.gd` | The loadout in run setup (a gadget and a boost, open ones only), the Next unlock line. |
| `scene/player/menu/goonopedia/goonopedia.gd` | The Pickups tab from the registry in tree order, unlock states and buying, `dropShare(id, mode)`. |
| `scripts/world/world_skin.gd` | `pickupIds()`: the chunk floor pickups through `openOr`. |
| `scene/level/levelRoot.gd` | `nightsSeen` (for the night unlocks). |
| `scripts/ai/ai_driver.gd` | `pickupValue` reads `ai` from the registry. |
| `scripts/global/settings.gd`, `project.godot` | The `UseItem` and `UseMove` actions, rebindable as "Fire Gadget" and "Boost / Hop" (settings v2 moved Space from Fire to the Handbrake: `migrateDrivingKeys`). |
| `scene/powerup/powerup.gd`, `purse.gd`, `slotMachine.gd` | Discovery for the original pickups. |

## Known gaps and tuning

- Nothing is tuned by hand yet (package 1); the run log counts pickups by kind (`pk_<kind>`).
- The AI driver values pickups by `ai` but has no plan for events (it ignores the Golden Goon, the Loot Truck, rings, the wheel), and its gadget and boost use is a few simple rules (`Gadgets.aiWantsUse`, `aiWantsMove`).
- Monster Tires only scale the car's art; its collision stays the same size.
- The Bandit can steal new pickups like any other.

## Testing

- **Dev console:** `pickup <id> [count]` collects any pickup in a run, locked or not (`help` lists them). `unlock pickups [id...]` opens every pickup (or the named ones and those above them), `lock pickups` closes all but the roots, and `unlocks` lists what is waiting, nearest first.
- **Launch options** (`PickupWorld.giveFromCommandLine`):
  - `-- --pickups=nitro,plow,mine` collects these when the run starts.
  - `-- --event=goldgoon|truck|bowling|rings|supply` starts an event at once.
  - `-- --pickup-shots=deal,claw,pitshop,scratch,double,wheel,bowling,...` (with a bench run, for example `--bench=S2`) opens or places each one in turn and saves `user://bench/pickup_<id>.png`.
- **Rare glow:** a Rare-or-better pickup's light only shows at night (`GenericPickup._process`).
- **Deferred spawns:** pickups, props and gadget nodes are added deferred (`PickupWorld.addToLevel`, `PickupEffects.spawnPickup`, `dropAndCollect`, `Gadgets.addNode`), because most spawns start in a physics callback.
- **Beacons:** they keep clear of the top panels and the dials.
