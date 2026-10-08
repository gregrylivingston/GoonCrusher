# Menus

The menus use the same colors, fonts and pickup icons as the in-run HUD (`docs/HUD.md`), and every prompt shows the key or button for the device the player is using.

## Shared parts (`scene/ui/`)

| File | Class | What it does |
|---|---|---|
| `menu_theme.gd` | `MenuTheme` | Builds the menus' `Theme` in code from `HudTheme`, so menus and HUD can't drift apart. Give a menu's root Control `theme = MenuTheme.theme()`. Also has helpers: `button(text, actions, primary, icon)`, `chip`, `priceChip`, `iconRect`, `box`, `addSounds`. `iconRect` returns a `CrispIcon` (`crisp_icon.gd`): the icon is resampled (Lanczos, cached) to the exact screen pixels it covers, instead of a blurry mipmap, and rebuilt when the window changes. Use it for any small menu icon. |
| `input_glyphs.gd` | `InputGlyphs` | Tracks whether the player last used a controller (`usingPad`) and names an action's binding on that device (`label("ui_accept")` gives "Space" or "A"). Bindings come from `InputMap`, so rebinding shows up. `ensureMenuActions()` adds `ui_upgrade` (F / Y), `ui_boost` (V / RS), `ui_records` (R / X), `ui_codex` (G / View), and controller A/B on `ui_accept`/`ui_cancel`, which the project didn't bind. Every menu works from the left hand: it puts Space first on `ui_accept` (Enter still works) and WASD before the arrows (`keyFirst`), since a hint shows an action's first key. `digit(event)` reads the number keys (top row or keypad) that pick a level poster or a Goonopedia tab. |
| `key_hint.gd` | `KeyHint` | One chip per action, then a label: `KeyHint.make(["ui_accept"], "Drive")`. It switches as soon as the player changes device, and hides when the action has no binding on that device. A clickable hint (`make(..., true)`, or a whole bottom bar from `KeyHint.bar([[actions, label], ...])`) fires its action on a click through `KeyHint.fire`, which `_input` handlers, the GUI and `is_action_just_pressed` polling all see: one action makes the whole hint a button, several make each chip its own. |
| `juice.gd` | `Juice` | Short feedback tweens: `shake` (a no, with a buzz), `flash` (a fading colour wash over a Control), `pop` (scale up and settle), `rumble` (the shared shake), `dropIn` (an overlay arriving). |
| `transitions/` | `Transition`, `ShutterDoor`, `GameHatch`, `TransitionFx` | Screen changes behind the garage shutter; see "Transitions" below. |

**Theme variations.**

- **Buttons:**
  - `Button`: a list row with a faint fill, and an orange rim with gold text when focused or hovered. `MenuTheme.button` widens the right margin when it carries a key chip, so the text never runs under it.
  - `StatRow`: the driver card's stat rows; the highlight is the row's own rect.
  - `PrimaryButton`: the one solid orange action per screen, with a gold focus ring.
  - `TabButton`: settings pills.
- **Panels:**
  - `Panel`/`PanelContainer`: smoked glass with an orange rim.
  - `InfoPanel`: blue rim.
  - `QuietPanel`: faint rim.
  - `CardPanel`, `KeyChip`, `PriceChip`, `BandPanel`.
- **Labels:** `TitleLabel`, `GoldLabel`, `MutedLabel`, `BodyLabel`, `HintLabel`, `DarkLabel` (text on orange).

**Rules for a new menu.** One `PrimaryButton`. A `KeyHint` for every key that does something, and make bottom bars clickable (`KeyHint.bar`). Everything must work with the mouse alone: inside a clickable row, set every child that isn't the button to `MOUSE_FILTER_IGNORE` (a plain `Control` defaults to `STOP` and swallows the click). Never write "A" or "Enter" into a label. Build with the theme rather than per-node style overrides.

## Transitions (`scene/ui/transitions/`)

One language for every screen change: a corrugated **garage shutter** for screens, with **tire smoke and skid marks** wherever the car (or a panel acting like one) moves. Chosen from two rounds of concepts (Option 1, "shutter for screens, tires for the car", with the games a cross of 1 and 3).

| Moment | What happens | Where |
|---|---|---|
| Garage <-> Run setup | Full slam: the door drops (240 ms, gravity), lands with a thud, an 8 px shake, dust and chips, bounces, the screen swaps behind it, then it rolls up (450 ms, rattle). | `main2.goToSetup/goToGarage` -> `Transition.play` |
| Start a run | The door slams over run setup with the level's name stencilled on it; 12 lamps light with load progress. The scene changes behind it; the run waits paused while the world builds (the TileManager keeps streaming), then the door rolls up with smoke pouring from under the rail on the car mid-burnout, and the usual 3-2-1 starts the run. | `main2.startLevel`, `Level.holdUnderShutter/revealRun`, `playerRoot.addCountdown` |
| Pause | A half shutter drops from the top with the card hanging from its rail on two straps; the card swings once. Continue rolls the door up and takes the card with it. | `pauseMenu.intro/outro` |
| Slot machine, The Deal, Claw Crane, Pit Shop | The panel skids in from the right and brakes (rubber marks, brake puffs), then a hatch shutter over it rolls up to reveal the game. Collect / leave: the hatch slams and the panel peels out left in smoke, then the countdown. The Pit Shop's hand-off to the free slot machine (`close(false)`) stays instant. | `GameHatch`, `slotMachine.gd`, `PickupMenu.close` |
| Results | WRECKED: a wall of tire smoke, the ticket skids in from the left. Every other ending: the shutter slams over the run and the ticket prints up out of its rail in six pushes. | `gameSummary.intro` |
| Back to the menu | The ticket pulls back into the rail, a door carries across the scene change (`Transition.carry`), and the garage rolls it up before counting the payout in. | `gameSummary.outro`, `main2._ready` |
| Overlays | Goonopedia, Settings and the records ticket drop in a little and settle with a clank. | `Juice.dropIn`, `gameSummary.intro` |
| Countdown (start lamps) | A drag-strip lamp rack: three ambers a second apart with a relay clunk, green on GO with a tire chirp and a puff off the car. At run start it drops in on its rail (`dropIn`); on resumes it is simply there. Same 3 s pause as before. | `countdown.gd/.tscn`, `playerRoot.addCountdown` |
| Slot prizes (payout chute) | After Collect the hatch slams, the won symbols drop out of a chute under its rail (4 / 8 / 16 by Slot Celebration), bounce once and fly to the payout, then the panel peels out. Paid before it starts. | `PayoutChute`, `GameHatch.leave(whileShut)` |
| Gift box | A gold flash on the pill; the box drops in, rattles, pops its lid on the prize game (name and tier) and opens it after 1.9 s (Accelerate or a click skips). | `playerRoot.checkGiftBox`, `GiftBox` |
| Wave survived / district | Waves (one clock for the run): the region chip flashes and its star flies to the counter. New districts: a road sign swings in with the name and faction. | `playerRoot.waveSurvived/districtEntered`, `RoadSign` |
| Milestones | Goonpocalypse target: a TARGET SMASHED stamp. Marathon station: a LEG n OF 3 banner. First crush of a goon: a NEW GOON banner. Lottery match: a MATCH! stamp on the ticket. Nightfall: a NIGHT FALLS banner and a headlight clunk. | `Stamp`, `TapeBanner` |
| HUD | Toasts drop in with an overshoot and a rim flash, legendary ones get a stamp; the Nuke is an orange shockwave (no white-out); the station is an edge pill; blinks hold steady under Reduce Flashing; world labels use the HUD font; results rows slide in and the stamp lands like `Stamp`; reels settle with a clank; the wreck rolls smoke and shakes the camera. | `HudChance`, `HudTheme.blinkOn`, `GoonFx`, `gameSummary`, `slot_row.gd` |

**Rules.**

- **One sound family:** thud, clank, rattle, screech, skid, hiss, whoosh, pop, rev. They are synthesised by `scripts/art/transition_sounds.py` into `sound/ui/transition/`: change the script and re-run it, never edit the WAVs. Play one with `Transition.sound(name, db)`.
- **One shake strength:** `Juice.rumble`, 8 px for a full slam, 4 for a half door or a brake, 2 for a landing; it decays in under 0.25 s and never touches the HUD.
- **Full slams only for real scene changes.** Overlays get a half door, a hatch or a drop.
- **Rewards are never credited by a transition:** the slot machine pays its reels before its outro starts.
- **Settings:** puff counts scale with Exhaust Smoke (`gfx/smoke`: off, x0.4, full) and marks with Tire Marks; Reduce Motion fades a still door in and out (150 ms each) with no shake, smoke or skids.
- **Harnesses:** headless runs, `--bench` and `--playtest` skip every transition (`Transition.instant()`): nothing is drawn, swaps run at once and timings are unchanged.
- `Transition.busy()` is true while a door is moving or down; the main menu ignores input then. The door lives on the tree root at layer 90, above RunView, so it survives `change_scene`. In-run doors (pause, hatch, results) live in their own CanvasLayer instead, because a run may render inside RunView's SubViewport.

## Main menu (`scene/player/menu/main/`)

`main2.tscn` holds only the voice player and the version label; `main2.gd` builds the rest in code. It has two screens.

**Garage.** A carousel of `DriverCard`s (`driver_card.gd`): the selected card is in the middle, with two on each side, scaled down and dimmed.

- **Choosing a driver:** LB/RB, Q/E, Left/Right or the mouse wheel picks a driver; clicking a side card selects it.
- **Accept:** drives an owned car, or unlocks a locked one for its price (a gold flash; a shake if it can't be afforded). Entry cars cost coins; advanced ones coins and gems, and the button says what is short ("NEED 3 MORE GEMS"; docs/PICKUPS.md, "Unlocks").
- **Upgrade (F / Y, the Upgrade button, or a click on any stat):** opens the upgrade sheet: the art folds up and each stat gets a full row with its name, value, bar and next price. W/S or hovering picks a row, and the focused row's price becomes a solid BUY button. Accept (Space) or a click buys on the press (the row flashes, the value pops, the coin counter ticks down), and a row you can't afford shakes; holding Accept keeps buying after 0.4 s, every 0.12 s, until the stat maxes or the coins run out (`DriverCard.HOLD_DELAY`, `HOLD_REPEAT`). Back, F or Done closes it.
- **Records (R / X):** opens the driver's records ticket.
- **Esc / Menu:** opens Settings. The top-left buttons are quit, settings, Discord and Steam.

**Driver card.** Each card shows the driver's portrait over the car's background art and a name band. Locked drivers are silhouettes with their price. The focused card shows every stat in a compact 2 x 4 grid: the value and an underline against 100 (cream for the car's base stat, gold for upgrades bought). The upgrade sheet adds the stat's name, a tooltip saying what it does, and the next upgrade's price, dimmed when you can't afford it.

**Run setup.** Level posters (Q/E or LB/RB, the number on the poster (1-8), the mouse wheel, or a click on a side poster) with the five mode medallions under them (A/D, or click one). Accept starts the run, Back returns to the garage. Two loadout buttons buy a consumable to start with for each of the car's slots: **Gadget (F / Y)**, left of Start, cycles a gadget for the Fire slot (`Pickups.LOADOUT`, 1 to 4 gems), and **Boost (V / RS)**, right of Start, a boost for the Boost slot (`Pickups.BOOST_LOADOUT`: Hop 1, Nitro 2, Jump Jets 4). Only unlocked gadgets and boosts are offered (`Pickups.openLoadout`). Each skips what the gems can't cover alongside the other slot's choice, and says which key fires it in the run (a tooltip gives the pickup's text). The choices are kept in `meta.records.loadout` and `meta.records.boostLoadout` and paid at Start, the gadget first (`slotPurchase`). A second into the run a toast names each one and its key ("AIR HORN x3 - PRESS E"). Under the buttons a **Next unlock** line names the nearest pickup to unlock, with its price or play condition and progress, and says when it can be bought in the Goonopedia (`main2.nextUnlockText`, `Unlocks.nextUnlock`). Closing the Goonopedia refreshes the setup and the bank.

- **Posters:** each shows a star per mode beaten on that level, and a lock for locked levels.
- **Medallions:** a gold star when the mode is beaten, a dim star when it's playable, a lock when it isn't. The reason a mode is locked shows under its description, and Start reads LOCKED or COMING SOON.

**Loading.** Cards load their `CarInfo` (portrait, background, intro lines) on a worker thread only when they come into view; level posters do the same. This keeps the menu light on the HD 620.

**Mouse.** Every hint in the bottom bar is a button (Back included), the medallions and side cards and posters have hover states and click, and the wheel scrolls the carousel outside upgrade mode.

**Input handling.** Navigation runs in `_input`, before the GUI, so Left/Right switch cards instead of moving focus. In upgrade mode the arrows go to the GUI. The menu ignores input while `Settings.menu_open` is set or a node in group `menuOverlay` (the records ticket) is open.

**Other scripts call these:** `startLevel(path)` (bench), `animateCoins(from, to)` and `statUpdatesUiUpdate()` (SaveManager), and `add_child(menu)` (settings, dialogs).

## Goonopedia (`scene/player/menu/goonopedia/goonopedia.gd`)

A reference to the game's content, opened from the main menu with G / View or the book button in the top bar. It's a full-screen overlay (group `menuOverlay`), built in code like the main menu. Six pill tabs (LB/RB, Q/E): **Goons, Cars, Levels, Pickups, Modes, Systems**. Each tab is a grid of tiles on the left and a detail card for the focused tile on the right. Back closes it and emits `closed`.

**Where the content comes from.** Nothing is listed by hand, so new content shows up by itself:

| Tab | Entries | Numbers |
|---|---|---|
| Goons | `Goons.DATA`, grouped by faction | speed, damage, crush speed, head-on armour, the system it wears, pack size, biomes, and the player's crush count |
| Cars | the save's `cars` and their `CarInfo` | base stats plus upgrades bought (the driver card's bar), price, best run; one line of "strong / weak" against the other cars' averages |
| Levels | the save's `levels`, named and described by the registry (`Levels`, `LevelDef`; docs/WORLD.md) | the act, the def's blurb, its grammar's line (`Levels.GRAMMAR_TEXT`), BARRIER and SURFACES chips (`LevelDef.barrier`, `surfaces`), modes beaten, the clock, starting spawn rate and giant odds from the def (`levelStats`), a strip showing which faction holds the land along the road out (the level's `factionBand`), and each faction's roster (`LevelRoster.rosterFor`, undiscovered goons as "???") |
| Pickups | `Pickups.DATA`, grouped by kind, in unlock-tree order (`Unlocks.treeOrder`; docs/PICKUPS.md, "Unlocks") | rarity and kind chips, the registry's text, what it unlocks next, share of goon drops in the selected mode (`dropShare(id, mode)`), duration, uses, modes, night-only, factions that drop more of it; for a locked pickup its price and BUY button or its play condition and progress |
| Modes | `Root.gameModeDescription` | availability, unlock rule, levels beaten |
| Systems | the car's systems | `CONDITION_FLOOR` and the goons whose attack wears each one |

**Card layout.** Wide pictures (cars, levels) get a full-width banner (`hero`). Objects (goons, pickups, modes, systems) get a `showcase`: a square art panel with a soft glow in the faction or rarity colour, and the name, chips, text and tip in a column beside it; `endShowcase()` sends the rest (the stat table) back to full width. The card helpers (`titleRow`, `paragraph`, `tipRow`, `factRow`, `statTable`) add to `into`, which is the showcase's column or the card. Goon tiles are cropped to the goon's visible pixels (`artBounds`, `Image.get_used_rect`, cached), and the animated preview zooms to the idle frame's bounds, capped at 2× the baked pixels so small goons stay sharp. Pickup and icon art stays near its 96 px import size.

Only the plain-language text lives in the script: `VERB_TEXT` (behaviour and tip per verb), `ACT_TEXT` (Scrap Gang acts), `TRAIT_TEXT` (DATA flags), `PICKUP_TEXT` (stat names for the Cars tab; pickup text lives in `Pickups.DATA`), `MODE_RULES`, `SYSTEMS`. A goon's DATA can carry `"blurb"` and `"tip"` strings to override its verb's text. `test_goonopedia.gd` fails if a goon uses a verb or act with no text.

**Discovery.** Goons show as silhouettes named "???" until the player crushes one; the card then shows their faction, rank and habitat. Every crush the car makes is counted per goon id (`crushedById`), and `gameSummary` adds the run's counts to `PlayerData.goonsCrushed` (save version 3) and names first-time goons on the ticket ("New in the Goonopedia: ..."). Goons the car kills another way count too: blasts, a kicked shell, and a drowning within 3 s of the car touching the goon (`SpawnManager.creditCrush`). Set `REVEAL_ALL` to show everything. Pickups follow their unlock trees instead (`Unlocks.state`): an open pickup shows in full; one whose parent is open shows dimmed, with its price (or PLAY, or FULL GAME in the demo) in the tile's corner, gold when the bank covers it; the rest are "???". The header shows pickups open and the bank.

**Buying pickups.** Accept on a focused pickup tile buys it (the garage's sound, gold flash and pop; a shake when it can't be bought). With the mouse, the click that focuses a tile only shows it (`mouseDownOn`, the tile focused when the button went down); a second click, or the card's BUY button, buys. After a purchase the tab rebuilds in place, so children that came into view show at once.

## In-run menus

- **Pause** (`pauseMenu.gd`). A card hanging from a half shutter ("Transitions"): Continue (Esc / Menu), Settings, Abandon run (it says how many coins the run keeps), and Quit game. These are separate buttons, and with Confirm Abandon / Quit on, each asks for a second press. Under them are the mode, clock and crush count, and the car's stats with a gold +N for what pickups added.
- **Results** (`gameSummary.gd`). A torn paper ticket.
  - **Reveal:** rows appear one at a time (time, then the mode's own row: Goonpocalypse score, Marathon stations reached or Defense barrier, then top speed, crushes, coins, powerups, gems, slot machines). The first fresh press speeds the reveal up and the next one continues; `isFreshPress` is covered by `test_progression.gd`.
  - **Payout:** coins × the star multiplier (1 + 0.1 a star; the label gives the star count) = paid, from `Root.computePayout`.
  - **What opens next:** after a win, a footer note says how many more modes on this level open the next one, or that it just opened (`nextLevelNote`).
  - **Unlocks:** pickups that play opened this run get an "Unlocked" row with a NEW PICKUP badge (`Unlocks.refresh`, after `Unlocks.countRun` adds the run to `meta.lifetime`). With nothing new, the footer says when the next unlock can be bought in the Goonopedia.
  - **Badges:** a beaten record gets a NEW BEST badge (in Goonpocalypse the time and score rows too, from `SaveManager.recordGoonpocalypse`), then a stamp lands (WRECKED, OUT OF GAS, TIME'S UP, ABANDONED, OVERRUN, CLEARED, or SURVIVED for a Goonpocalypse run past its target). The stamp moves down by a row when the mode adds one.
  - **Saving:** the payout and records are saved when the ticket opens.
- **Records.** The same ticket with `isGameSummary = false`, showing the selected driver's bests, plus the longest Goonpocalypse and its best score once there is one. The run setup card adds "Best here" for Goonpocalypse on the selected level and car.
- **Countdown** (`scene/player/countdown.tscn`). A gold numeral matching the HUD clock. A green "GO!" shows for half a second after the run unpauses, so the pause length (and the AI driver's harness) is unchanged.
- **Slot machine** (`slotMachine.gd`). It skids in under a hatch shutter and peels out after Collect ("Transitions"). `restyle()` gives it the smoked panel, gold-framed reels and a row of themed Spin / Reroll / Collect buttons with key hints. The original buttons stay hidden because the logic reads their state; `syncButtons()` mirrors it every frame. Accelerate and Brake work as before.
- **Pickup menus** (`scene/pickups/menus/`, docs/PICKUPS.md). The Deal (three cards: Steer to choose, Accelerate to take, Brake for a new hand at 1 gem, Use to raise the hand for run coins), the Claw Crane, and Marathon's Pit Shop share `PickupMenu`: a dimmed screen, one `CardPanel`, key hints, and 0.6 s before keys count. They pause the run, close through the countdown, and join group `slotMachine` so the harnesses tap through them.
- **Slot machine bet.** Before the first spin, Steer Left and Right set a bet of 0, 25, 100 or 250 run coins (the BET button); it tilts the reels rarer. Paylines are in docs/PICKUPS.md.
- **Settings** (`settings/*`). Same layout and rows. It uses `MenuTheme`, pill tabs with LB/RB (Q/E) chips, an orange-rimmed focused row, orange slider fills, and footer buttons with their keys.

## Tests

`tests/game/test_menus.gd` covers:

- prompt labels on both devices and switching between them
- driver cards (silhouette and Unlock for locked cars, stats and Drive for owned ones)
- coin formatting
- pause having separate Abandon and Quit buttons
- the records ticket

`tests/game/test_goonopedia.gd` covers the Goonopedia: one tile per goon, silhouettes until crushed, every tab and card building, crush crediting, level numbers and names read from the def, the factions a level's band reaches, every level card's act, barrier and surfaces, and drop shares adding up to 100%.

None of these tests write the save.

## Not done yet

- **Per-car skins:** a `HudSkin` on `CarInfo` could tint a driver's card and the HUD.
- **Car Paint** (`gameplay/car_paint`) could also be a toggle on the driver card.
- **Region faction:** the HUD region chip doesn't show the district's faction yet.
- **Unused HUD animations:** `playerRoot.tscn`'s AnimationPlayer and AnimationPlayer2 (the old crush-pill and region-chip pops) are no longer played and can be deleted in the editor.
