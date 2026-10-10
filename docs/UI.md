# Menus

The menus use the same colors, fonts and pickup icons as the in-run HUD (`docs/HUD.md`), and every prompt shows the key or button for the device the player is using.

## Shared parts (`scene/ui/`)

| File | Class | What it does |
|---|---|---|
| `menu_theme.gd` | `MenuTheme` | Builds the menus' `Theme` in code from `HudTheme`, so menus and HUD can't drift apart. Give a menu's root Control `theme = MenuTheme.theme()`. Also has helpers: `button(text, actions, primary, icon)`, `chip`, `priceChip`, `iconRect`, `box`, `addSounds`. `iconRect` returns a `CrispIcon` (`crisp_icon.gd`): the icon is resampled (Lanczos, cached) to the exact screen pixels it covers, instead of a blurry mipmap, and rebuilt when the window changes. Use it for any small menu icon. |
| `input_glyphs.gd` | `InputGlyphs` | Tracks whether the player last used a controller (`usingPad`) and names an action's binding on that device (`label("ui_accept")` gives "Space" or "A"). Bindings come from `InputMap`, so rebinding shows up. `ensureMenuActions()` adds `ui_upgrade` (F / Y), `ui_buy` (E / A: buys the lit upgrade row in driver focus), `ui_boost` (V / RS), `ui_region_prev`/`ui_region_next` (Z / LT, C / RT: run setup's region tabs), `ui_records` (R / X), `ui_codex` (G / View), and controller A/B on `ui_accept`/`ui_cancel`, which the project didn't bind. Every menu works from the left hand: it puts Space first on `ui_accept` (Enter still works) and WASD before the arrows (`keyFirst`), since a hint shows an action's first key. `digit(event)` reads the number keys (top row or keypad) that pick a road stop or a Goonopedia tab. |
| `key_hint.gd` | `KeyHint` | One chip per action, then a label: `KeyHint.make(["ui_accept"], "Drive")`. It switches as soon as the player changes device, and hides when the action has no binding on that device. A clickable hint (`make(..., true)`, or a whole bottom bar from `KeyHint.bar([[actions, label], ...])`) fires its action on a click through `KeyHint.fire`, which `_input` handlers, the GUI and `is_action_just_pressed` polling all see: one action makes the whole hint a button, several make each chip its own. |
| `juice.gd` | `Juice` | Short feedback tweens: `shake` (a no, with a buzz), `flash` (a fading colour wash over a Control), `pop` (scale up and settle), `rumble` (the shared shake), `dropIn` (an overlay arriving). |
| `transitions/` | `Transition`, `ShutterDoor`, `GameHatch`, `TransitionFx` | Screen changes behind the garage shutter; see "Transitions" below. |

**Theme variations.**

- **Buttons:**
  - `Button`: a list row with a faint fill, and an orange rim with gold text when focused or hovered. `MenuTheme.button` widens the right margin when it carries a key chip, so the text never runs under it.
  - `PrimaryButton`: the one solid orange action per screen, with a gold focus ring.
  - `TabButton`: settings pills.
- **Panels:**
  - `Panel`/`PanelContainer`: smoked glass with an orange rim.
  - `InfoPanel`: blue rim.
  - `QuietPanel`: faint rim.
  - `CardPanel`, `KeyChip`, `PriceChip`, `BandPanel`.
- **Labels:** `TitleLabel`, `GoldLabel`, `MutedLabel`, `BodyLabel`, `HintLabel`, `DarkLabel` (text on orange).

**Rules for a new menu.** One `PrimaryButton`. A `KeyHint` for every key that does something, and make bottom bars clickable (`KeyHint.bar`). Everything must work with the mouse alone: inside a clickable row, set every child that isn't the button to `MOUSE_FILTER_IGNORE` (a plain `Control` defaults to `STOP` and swallows the click). Never write "A" or "Enter" into a label. Build with the theme rather than per-node style overrides.

### Symbols

Amounts read as numbers followed by the game's symbols, not words: "1,500 (coin)  3 (gem)", not "1,500 coins and 3 gems". The helpers are in `MenuTheme`:
- `symbolRow(parts, fontSize, color)`: a row of parts that ignores the mouse. A part is a String (a label), a Texture2D (an icon at the text's height) or a cost Dictionary `{"coin": n, "gem": n}`.
- `costParts(cost, short)`: a cost as [amount, icon...]; `short` writes 10,000 and up as "10k" for tile corners.
- `setButtonParts(button, parts)`: parts centered on a button in place of its text, in the button's own font colour (dark on a primary button); the key hint stays at the right end.
- `priceChip` puts the number before the coin as well.

Use words only where there is no symbol (UNLOCK, NEED ... MORE, PLAY, MAX).

## Transitions (`scene/ui/transitions/`)

One language for every screen change: a corrugated **garage shutter** for screens, with **tire smoke and skid marks** wherever the car (or a panel acting like one) moves. Chosen from two rounds of concepts (Option 1, "shutter for screens, tires for the car", with the games a cross of 1 and 3).

| Moment | What happens | Where |
|---|---|---|
| Garage <-> Run setup | Full slam: the door drops (240 ms, gravity), lands with a thud, an 8 px shake, dust and chips, bounces, the screen swaps behind it, then it rolls up (450 ms, rattle). | `main2.goToSetup/goToGarage` -> `Transition.play` |
| Start a run | The door slams over run setup with the level's name stencilled on it; 12 lamps light with load progress. The scene changes behind it; the run waits paused while the world builds (the TileManager keeps streaming), then the door rolls up with smoke pouring from under the rail on the car revving (`Level.burnout`: a rev and a squeal; the cloud it used to throw off the car's tail hid the car and the semi's trailer), and the usual 3-2-1 starts the run. The player's camera keeps following while the run is paused (`process_mode` Always), so the car is centred from the moment the door rises. | `main2.startLevel`, `Level.holdUnderShutter/revealRun`, `playerRoot.addCountdown` |
| Pause | A half shutter drops from the top with the card hanging from its rail on two straps; the card swings once. Continue rolls the door up and takes the card with it. | `pauseMenu.intro/outro` |
| Prize games (Claw Crane, Hubcap Shuffle, Goon Press, The Deal, Pachinko Drop, Slot Machine, Coin Pusher, Pit Shop) | The panel skids in from the right and brakes (rubber marks, brake puffs), then a hatch shutter over it rolls up to reveal the game. Leaving the winnings board: the hatch slams and the panel peels out left in smoke, then the quick countdown. The Pit Shop's hand-off to the free slot machine (`close(false)`) stays instant. | `GameHatch`, `PickupMenu.close` |
| Results | WRECKED: a wall of tire smoke, the ticket skids in from the left. Every other ending: the shutter slams over the run and the ticket prints up out of its rail in six pushes. | `gameSummary.intro` |
| Back to the menu | The ticket pulls back into the rail, a door carries across the scene change (`Transition.carry`), and the garage rolls it up before counting the payout in. | `gameSummary.outro`, `main2._ready` |
| Overlays | Goonopedia, Settings and the records ticket drop in a little and settle with a clank. | `Juice.dropIn`, `gameSummary.intro` |
| Countdown (start lamps) | A drag-strip lamp rack: three ambers a second apart with a relay clunk, green on GO with a tire chirp and a puff off the car. At run start it drops in on its rail (`dropIn`); on resumes it is simply there. Same 3 s pause as before; back from a prize game the lamps step every 0.25 s (`QUICK_STEP`, `PickupMenu.resumeRun`). | `countdown.gd/.tscn`, `playerRoot.addCountdown` |
| Slot prizes (payout chute) | After Collect the hatch slams, the won symbols drop out of a chute under its rail (4 / 8 / 16 by Slot Celebration), bounce once and fly to the payout, then the panel peels out. Paid before it starts. | `PayoutChute`, `GameHatch.leave(whileShut)` |
| Gift box | A gold flash on the pill; the box drops in, rattles, pops its lid on the prize game (name and tier) and opens it after 1 s (Accelerate or a click skips). | `playerRoot.checkGiftBox`, `GiftBox` |
| Wave survived / district | Waves (one clock for the run): the region chip flashes and its star flies to the counter. New districts: a road sign swings in with the name and faction. | `playerRoot.waveSurvived/districtEntered`, `RoadSign` |
| Milestones | Goonpocalypse target: a TARGET SMASHED stamp. Marathon station: a LEG n OF 3 banner. First crush of a goon: a NEW GOON banner. Lottery match: a MATCH! stamp on the ticket. Nightfall: a NIGHT FALLS banner and a headlight clunk. | `Stamp`, `TapeBanner` |
| HUD | Toasts drop in with an overshoot and a rim flash, legendary ones get a stamp; the Nuke is an orange shockwave (no white-out); the station is an edge pill; blinks hold steady under Reduce Flashing; world labels use the HUD font; results rows slide in and the stamp lands like `Stamp`; reels settle with a clank; the wreck rolls smoke and shakes the camera. | `HudChance`, `HudTheme.blinkOn`, `GoonFx`, `gameSummary`, `SlotMachine` |

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

**Garage.** A carousel of `DriverCard`s (`driver_card.gd`): the selected card is in the middle, with two on each side, scaled down and dimmed. Side cards show their back, only the background art and the portrait standing at its foot; selecting a card flips it over to its front (it squeezes to an edge with a little tilt, swaps faces, then opens out with a flash and an overshoot; `DriverCard.flip`, a crossfade with Reduce Motion), and the card it left flips back. The focused card's Upgrades, Drive and Pickups sit in a tray at the bottom centre, under the card (`main2.actionDock`, which holds every card's `actions`; see "The dock"). Every card, locked or not, lists its car's two signature features under the name band (`DriverCard.traitLine`): the icon, the name, the kind in its colour (sky for physics, gold for mechanics, orange for abilities, with the Ability key) and the one-line `short` text; hovering one shows its full text.

- **Choosing a driver:** LB/RB, Q/E, Left/Right or the mouse wheel picks a driver; clicking a side card selects it.
- **Accept:** drives an owned car, or unlocks a locked one for its price (a gold flash; a shake if it can't be afforded). Entry cars cost coins; advanced ones coins and gems, and the button says what is short ("NEED 3 MORE GEMS"; docs/PICKUPS.md, "Unlocks").
- **Upgrades (F / Y, or the Upgrades button):** opens the driver focus (below), where upgrades are bought. The same key closes it.
- **Pickups (G / View, or the Pickups button):** opens the Pickups screen (below).
- **Goonopedia (B / L3, or the book button in the top bar):** opens the Goonopedia.
- **Records (R / X):** opens the driver's records ticket.
- **Esc / Menu:** opens Settings. The top-left buttons are quit, settings, Discord and Steam.
- **Radio:** under the top-left buttons, a `NowPlaying` card shows the song and station; a click changes station (right click goes back). Mouse only; with keys or a pad it's in Settings → Audio (docs/RADIO.md).

**The dock.** One tray (`DOCK_SIZE`), in the same place in the list and in driver focus: **Upgrades** on the left, the one primary button **Drive** (or UNLOCK / NEED ... MORE) in the middle, **Pickups** on the right, each with its key chip. Upgrades and Pickups are worked by their keys or a click and never take the focus. Each carries a `CountBadge` (`scene/ui/count_badge.gd`) on its top right corner:
- **Upgrades:** the stats on this car whose next level the coins cover now, 0 to 8 (`DriverCard.affordableUpgrades`).
- **Pickups:** the pickups and prize games that are ready and that the bank covers (`Unlocks.buyableCount`).
- Each is counted on its own, so one purchase can lower a count by more than one. A badge is hidden at 0. It hops every 2.2 s (the two are offset), swells and settles when its number changes, and sits still with Reduce Motion. It is tween-driven.
- On a locked car Upgrades reads DETAILS and has no badge. In driver focus it reads DRIVERS and has no badge.

**Driver focus** (`main2.toggleFocus`, `setFocusOpen`; `driver_bench.gd`, `DriverBench`). Upgrades clears the other drivers off the screen (they flip to their backs and slide off both edges), moves the focused card to the left (`FOCUS_CARD_POS`) and slides its bench in from the right (`BENCH_POS`; a fade with Reduce Motion, at once in the harnesses). The bench, top to bottom:
- **Head:** UPGRADES, the car's strong and weak stats against the other cars' averages (`DriverBench.strongWeak`), and "N / 160 bought".
- **Eight stat rows:** icon, name and what the stat does (`DriverCard.STAT_TEXT`), a bar against 100 (cream for the base stat, gold for upgrades bought), the value with a gold +N, the level out of 20, and a buy button with the next level's price in symbols: solid orange when the coins cover it, dim when they don't, MAX at the cap.
- **Signature:** both features with their full text (`signatureBlock`), and the car's best run.

Up/Down move between the buy buttons (only the button shows the focus; the row is remembered from driver to driver), Buy (E / A, `ui_buy`) or a click buys (`DriverBench.buyUpgrade`, `SaveManager.requestStatUpgrade`: the buy sound, a gold wash over the row, the bar's new part glows and the number pops; a shake when the coins are short), and Accept on the keyboard (Space) drives from any row; Down from the last row reaches Drive, which is how a pad gets there, since its A buys on a row. Left/Right and the wheel change driver (E buys on a row, so the hint shows A/D; Q/E and LB/RB still work elsewhere). Upgrades, Back or Esc returns to the drivers; going to run setup closes it. A locked car's bench is read only (STATS, no buttons) and the dock's UNLOCK has the focus.

**Driver card.** A 380 x 560 card. Its front, top to bottom: the driver's portrait over the car's background art, against the card's right edge (the drivers stand at the right of their pictures, and the sedan's, van's and racer's are cut off there), a "6-SPEED MANUAL" chip in its top right corner on a manual car (docs/CAR_ART.md, "Gearbox"), and the eight stats in a black rail against the card's left edge that runs down into the name band and ends in a cut corner, edged in orange (`DriverCard.StatRail`; one row each: icon and value over a 3 px bar against 100, cream for the car's base stat, gold for upgrades bought; display only, with no hover or click); the name band, with the name right of the rail and the car type and weight class at its right end; and the two features. Its buttons are in the dock. Under the focused card, outside its frame, a pill shows the car's progress (`SaveManager.carProgress`, from `meta.carClears`): a bronze, silver and gold star with how many level-and-mode wins it has on Easy, Medium and Hard or harder, and "N / 30 levels won" (levels it has won any mode on; the demo counts all 30), or "Not raced yet". Locked drivers are silhouettes that still show their features, with no stats and a lock and the price in symbols (or "Not in the demo") on a smoked strip over the foot of the art (`priceLine`: "10,000 (coin)  5 (gem)", gold when the bank covers it). The focused locked card's button says UNLOCK, or "NEED 7,000 (coin) 1 (gem) MORE" (disabled) when short; Upgrades reads DETAILS.

**Run setup** has two steps: the road map picks the level, then Level Options picks the mode and tier (`main2.optionsOpen`, `openOptions`, `closeOptions`).

*The road map.* Six region tabs along the top (`Territories`, in each region's colour, with its blurb under them; Z/C or LT/RT, or a click, which opens the region at its furthest open stop; a lock on a region the demo doesn't offer), and the region's five stops as posters on a road (Q/E or LB/RB, which walk on into the next region at either end; A/D, the number keys 1-5, the mouse wheel, or a click on a stop; the selected stop is bigger). Each poster has its art, its name band and a **glyph per mode** in `Root.MODE_PATH` order: the mode's icon (`HudTheme.MODE_ICONS`) drawn in one colour by a small shader (`GLYPH_SHADER`, shared `glyphMaterials`), in the colour of the best medal any driver has won there (grey when open, faint when locked), over a **bar** in the colour of the current driver's own medal (`SaveManager.carClearTier`). A chip at the top right names the current driver, and a legend under the panel explains the glyph and the bar. The panel under the road describes the highlighted stop: its name (and FINALE), the def's blurb, WHO LIVES HERE (the region's class, the line-up with undiscovered goons as "???", an elite region's strength step; `main2.fillFacts`, `Goonopedia.regionRows`) and, when it is locked, what opens it. **SELECT** (Accept, or a click on the selected stop) opens Level Options; on a locked level it reads LOCKED. Back returns to the garage.

*Level Options* drops in over the road map (`Juice.dropIn`) for that level. Down the left: its poster, blurb, WHO LIVES HERE, BARRIER and SURFACES (`LevelDef.barrier`, `surfaces`), which is what the Goonopedia's level page used to show. On the right, the five mode medallions (A/D, or click one), each with three medal stars for the best tier beaten and the driver's own bar, then the mode's description and win rule (`Root.gameModeDescription`, `Root.MODE_RULES`). Under them a **card per tier**, Easy, Medium and Hard (W/S, or click one; `ModeTiers`, Hard locked until Medium is beaten; `main2.refreshTiers`): the tier's goal, its win bonus, the first-clear bonus still to earn (or "paid"), whether the current driver has won it and how many cars have. Under the cards, the **car strip** shows the 9 cars' side views (`CarInfo.sidePic`) for the selected level, mode and tier (`main2.refreshCarStrip`). A car in colour has won there on that tier or harder. A dark car is owned but hasn't won. An outline (a small edge shader) is a car not owned yet. The current driver is bigger, over an orange bar. The label counts the cars cleared (`carsCleared`) and reads FULL GARAGE in gold once all 9 have (`isFullGarage`). A click on an owned car makes it the driver. Accept starts the run, Back returns to the road map. It opens on the mode and tier last used, so a repeat run is Accept, Accept. Two loadout buttons buy a consumable to start with for each of the car's slots: **Gadget (F / Y)**, left of Start, cycles a gadget for the Fire slot (`Pickups.LOADOUT`, 1 to 4 gems), and **Boost (V / RS)**, right of Start, a boost for the Boost slot (`Pickups.BOOST_LOADOUT`: Hop 1, Nitro 2, Jump Jets 4). Only unlocked gadgets and boosts are offered (`Pickups.openLoadout`). Each skips what the gems can't cover alongside the other slot's choice, and says which key fires it in the run (a tooltip gives the pickup's text). The choices are kept in `meta.records.loadout` and `meta.records.boostLoadout` and paid at Start, the gadget first (`slotPurchase`). A second into the run a toast names each one and its key ("AIR HORN x3 - PRESS E"). Under the buttons a **Next unlock** line names the nearest pickup to unlock, with its price or play condition and progress, and says when it can be bought in Pickups (`main2.nextUnlockParts`, `Unlocks.nextUnlock`). G / View opens Pickups from here too; closing it refreshes the setup and the bank.

- **Medallions:** a gold star when the mode is beaten, a dim star when it's playable, a lock when it isn't. The reason a mode or tier is locked shows under the car strip (Goonpocalypse and Defense: "Win Marathon Here To Unlock"), and Start reads LOCKED or COMING SOON.
- **Focus:** SELECT on the road map and START in Level Options hold the focus (`main2.focusSetup`), so Accept always goes on.

**Loading.** Cards load their `CarInfo` (portrait, background, intro lines) on a worker thread only when they come into view; level posters do the same. This keeps the menu light on the HD 620.

**Mouse.** Every hint in the bottom bar is a button (Back included), the region tabs, stops, SELECT, medallions, tier cards and car strip click, and the wheel scrolls the carousel outside upgrade mode.

**Input handling.** Navigation runs in `_input`, before the GUI, so Left/Right switch cards instead of moving focus. Up/Down go to the GUI, which is how the bench's rows are chosen in driver focus. The menu ignores input while `Settings.menu_open` is set or a node in group `menuOverlay` (the records ticket) is open.

**Other scripts call these:** `startLevel(path)` (bench), `animateCoins(from, to)` and `statUpdatesUiUpdate()` (SaveManager), and `add_child(menu)` (settings, dialogs).

## Pickups (`scene/player/menu/pickups/pickup_shop.gd`, `PickupShop`)

Where pickups and prize games are unlocked, opened with G / View or the dock's Pickups button from the garage or run setup. A full-screen overlay on the same frame as the Goonopedia (`CodexPage`, below): tiles on the left, a card for the focused tile on the right, the bank in the header.

- **Tabs:** seven (`PickupShop.TABS`): Loot, Supplies, Tune-ups, Power-ups (with the Mode Specials), Gadgets (with the Boosts), Casino (which includes the gift box games) and Skill. LB/RB or Q/E step through them, 1-7 pick one, and they click. Each shows its starter's icon, its name over "open / all", and a `CountBadge` for what the bank covers there (`isBuyable`, the same rule as `Unlocks.buyableCount`, so the tabs' badges add up to the dock's). The kinds themselves (`Pickups.K`) are unchanged: a gadget and a boost still have a slot each, and mode specials still drop only in their mode.
- **Where it opens:** on the first tab with something the bank can buy, else the first with something to work toward (`startTab`), with the focus on that tile (`firstFocus`); every tab change does the same. So Pickups, then Accept, buys the first thing on offer.
- **A tab:** the kinds' names and a note, then their trees side by side (two kinds get a name each over their columns, and the tiles narrow to fit; `buildPickupTree(kinds)`): starters on the top row, each pickup's children on the row below, lines from parent to child (gold to an unlocked pickup, pale to one that is next, dashed to a "???" or from a prerequisite that is still locked). A pickup that needs several others (`after`: the Toolbox) sits under the middle of them with a line from each. A tree deeper than the panel closes its rows up to fit (`TREE_HEIGHT`). The stick, D-pad or WASD move between tiles.
- **Buying:** Accept on a focused tile, a second click on it, or the card's UNLOCK button (`buyPickup`, `buyPrize`, `Unlocks.buy`). The tab is rebuilt in place and the bought tile keeps the focus, so its children come into view.
- **The card:** rarity and kind chips, the registry's text, what it leads to, share of goon drops in the selected mode (`PickupShop.dropShare(id, mode)`), duration, uses, modes, night-only and the factions that drop more of it; for a locked pickup its price and UNLOCK button, or its play condition and progress.

## Goonopedia (`scene/player/menu/goonopedia/goonopedia.gd`)

A reference to the game's content, opened from the main menu with B / L3 or the book button in the top bar. It's a full-screen overlay (group `menuOverlay`), built in code like the main menu. Two pill tabs (LB/RB, Q/E, or 1-2): **Goons, Systems**. Pickups are on their own screen (above), cars in the garage's driver focus, and levels and modes in run setup (the road map's level panel and Level Options). Each tab is a grid of tiles on the left and a detail card for the focused tile on the right. Back closes it and emits `closed`.

**The shared frame** (`codex_page.gd`, `CodexPage`). The Goonopedia and the Pickups screen both extend it. It builds the header, the tab row, the tile panel and the detail card, handles the tab keys, Back and the page's own key (`closeAction`), and holds the helpers both use (`section`, `grid`, `tile`, `showcase`, `titleRow`, `paragraph`, `tipRow`, `factRow`, `statTable`). A page sets `title`, `icon`, `listWidth`, `hints` and `sellsThings` (the bank in the header) in `_init`, and supplies `tabNames()`, `buildTab(index)`, `drawDetail(entry)`, and `startTab()` and `firstFocus()` if the defaults (the first tab, the first tile) won't do.

**Where the content comes from.** Nothing is listed by hand, so new content shows up by itself:

| Tab | Entries | Numbers |
|---|---|---|
| Goons | `Goons.DATA`, grouped by faction | speed, damage, crush speed, head-on armour, the system it wears, pack size, the classes it plays in (`Goons.classesOf`), biomes, and the player's crush count |
| Systems | the car's systems | `CONDITION_FLOOR` and the goons whose attack wears each one |

**Card layout.** Objects (goons, pickups, systems) get a `showcase`: a square art panel with a soft glow in the faction or rarity colour, and the name, chips, text and tip in a column beside it; `endShowcase()` sends the rest (the stat table) back to full width. The card helpers (`titleRow`, `paragraph`, `tipRow`, `factRow`, `statTable`) add to `into`, which is the showcase's column or the card. Goon tiles are cropped to the goon's visible pixels (`artBounds`, `Image.get_used_rect`, cached), and the animated preview zooms to the idle frame's bounds, capped at 2× the baked pixels so small goons stay sharp. Pickup and icon art stays near its 96 px import size.

Only the plain-language text lives in the script: `VERB_TEXT` (behaviour and tip per verb), `ACT_TEXT` (Scrap Gang acts), `TRAIT_TEXT` (DATA flags), `MODE_RULES`, `SYSTEMS`. A goon's DATA can carry `"blurb"` and `"tip"` strings to override its verb's text. `test_goonopedia.gd` fails if a goon uses a verb or act with no text.

**Discovery.** Goons show as silhouettes named "???" until the player crushes one; the card then shows their faction, rank and habitat. Every crush the car makes is counted per goon id (`crushedById`), and `gameSummary` adds the run's counts to `PlayerData.goonsCrushed` (save version 3) and names first-time goons on the ticket ("New in the Goonopedia: ..."). Goons the car kills another way count too: blasts, a kicked shell, and a drowning within 3 s of the car touching the goon (`SpawnManager.creditCrush`). Set `REVEAL_ALL` to show everything. On the Pickups screen, pickups follow their unlock trees instead (`Unlocks.state`): an open pickup shows in full; one whose parent is open shows dimmed, with its price (or PLAY, or FULL GAME in the demo) in the tile's corner, gold when the bank covers it; the rest are "???". Its header shows pickups open and the bank.

**Prize games.** The gift box games are pickups in the Casino tree (docs/PICKUPS.md, "Casino and the gift box games"): their cards carry a PRIZE GAME chip and a tip about gift boxes, and the four that goons don't drop say so.

**Header bank.** On Pickups the header shows the bank in a pill, in symbols (`refreshBank`).

**Pickup trees.** Each kind is drawn as its unlock tree (`buildPickupTree`): the roots (starters) on the top row, each pickup's children on the row below, spread over the columns their leaves take (`placeTreeNode`), and elbow lines from parent to child (`drawTreeEdges`). A gold line leads to an unlocked pickup, a cream one to a pickup you can unlock or work toward now, a dashed one to a "???" behind a locked pickup. A pickup with no line below it ends its branch. A legend line at the top of the tab says so.

**Buying.** Accept on a focused pickup tile buys it (the garage's sound, gold flash and pop; a shake when it can't be bought). With the mouse, the click that focuses a tile only shows it (`isPickingClick`: the tile focused when the button went down); a second click, or the card's gold UNLOCK button (under the picture; NEED ... MORE when short), buys. After a purchase the tab rebuilds in place, so children that came into view show at once.

## In-run menus

- **Pause** (`pauseMenu.gd`). A card hanging from a half shutter ("Transitions"): Continue (Esc / Menu), Settings, a Radio row (left/right change station, the song shows under it; docs/RADIO.md), Abandon run (it says how many coins the run keeps), and Quit game. These are separate buttons, and with Confirm Abandon / Quit on, each asks for a second press. Under them are the mode, clock and crush count, and the car's stats with a gold +N for what pickups added.
- **Results** (`gameSummary.gd`). A torn paper ticket.
  - **Reveal:** rows appear one at a time (time, then the mode's own row: Goonpocalypse score, Marathon stations reached or Defense barrier, then top speed, crushes, coins, powerups, gems, slot machines). The first fresh press speeds the reveal up and the next one continues; `isFreshPress` is covered by `test_progression.gd`.
  - **Payout:** a won run first gets a "Win bonus (tier)" row (`ModeTiers.winBonus`), then (coins + bonus) × the star multiplier (1 + 0.1 a star, at most ×3; the label gives the star count) = paid, from `Level.runPayout`. The first win of a tier adds a "First clear (medal)" row with its coins and gems (`ModeTiers.firstClear`), paid outside the multiplier. The header names the tier ("MEDIUM SPRINT - ...").
  - **Car clears:** a win credits the run's car on that tier and the tiers below (`SaveManager.creditCarClear`, `meta.carClears`). A car's first clear of a tier adds a "New car clear (driver)" row with a NEW CAR badge and its coins (10% of the tier's first-clear coins × the level step), and the ninth car to clear a mode, level and tier adds a "Full Garage (tier)" row with a FULL GARAGE badge and its gems (1 / 2 / 4). Both are paid with the first-clear bonus, outside the multiplier. Amounts in these rows are symbols (`addSymbolRow`, `MenuTheme.symbolRow`).
  - **What opens next:** a Marathon win that opened the next level adds a "Road open" row naming it (and its region after a finale: "Mudlick Marsh, Tribe Country"; `roadText`). After any win a footer note says what is left here to open the next level ("Win the Marathon here", "... on Medium here" at a finale) or that it just opened (`nextLevelNote`, `Root.openLeftText`). The ticket credits the run's own level, mode and tier, not the menu's selection.
  - **Unlocks:** pickups that play opened this run get an "Unlocked" row with a NEW PICKUP badge and their count, and the names wrap on a line under it (`addWrapped`, at most 8 then "and N more"; `Unlocks.refresh`, after `Unlocks.countRun` adds the run to `meta.lifetime`). The footer note wraps to two lines under the button and shortens its lists (`listed`). With nothing new, the footer says when the next unlock can be bought in Pickups.
  - **Badges:** a beaten record gets a NEW BEST badge (in Goonpocalypse the time and score rows too, from `SaveManager.recordGoonpocalypse`), then a stamp lands (WRECKED, OUT OF GAS, TIME'S UP, ABANDONED, OVERRUN, CLEARED, or SURVIVED for a Goonpocalypse run past its target). The stamp moves down by a row when the mode adds one.
  - **Saving:** the payout and records are saved when the ticket opens.
- **Records.** The same ticket with `isGameSummary = false`, showing the selected driver's bests, plus the longest Goonpocalypse and its best score once there is one. The run setup card adds "Best here" for Goonpocalypse on the selected level and car.
- **Countdown** (`scene/player/countdown.tscn`). A gold numeral matching the HUD clock. A green "GO!" shows for half a second after the run unpauses, so the pause length (and the AI driver's harness) is unchanged.
- **Prize games** (`PickupMenu`, docs/PICKUPS.md "Prize games"). Every prize game (the Claw Crane, Hubcap Shuffle, Goon Press, The Deal, Pachinko Drop, the Slot Machine, Coin Pusher) and Marathon's Pit Shop share one frame: a dimmed screen and one `CardPanel` of the same size for every game (title, subtitle, a 640 x 420 stage, a status line, clickable key hints). The keys are the same in every game: E (X) acts, WASD moves or picks, Q (Y) rejects, redraws or retries; the action key held as a game opens counts only once released. Each ends on the winnings board, which lists every prize and what it did; The action key or a click leaves through the quick countdown. They pause the run and join group `slotMachine` so the harnesses tap through them. New prize games extend `PickupMenu` and draw on its stage.
- **Settings** (`settings/*`). Same layout and rows. It uses `MenuTheme`, pill tabs with LB/RB (Q/E) chips, an orange-rimmed focused row, orange slider fills, and footer buttons with their keys.

## Tests

`tests/game/test_menus.gd` covers:

- prompt labels on both devices and switching between them
- driver cards (silhouette and Unlock for locked cars, stats and Drive for owned ones), the dock's buttons and count badges, and the bench's rows
- coin formatting
- pause having separate Abandon and Quit buttons
- the records ticket

`tests/game/test_goonopedia.gd` covers the Goonopedia: one tile per goon, silhouettes until crushed, every tab and card building, crush crediting, level numbers and names read from the def, a level's region, class and line-up rows, every level card's region, barrier and surfaces, and drop shares adding up to 100%.

None of these tests write the save.

## Not done yet

- **Per-car skins:** a `HudSkin` on `CarInfo` could tint a driver's card and the HUD.
- **Car Paint** (`gameplay/car_paint`) could also be a toggle on the driver card.
- **Region faction:** the HUD region chip doesn't show the district's faction yet.
- **Unused HUD animations:** `playerRoot.tscn`'s AnimationPlayer and AnimationPlayer2 (the old crush-pill and region-chip pops) are no longer played and can be deleted in the editor.
