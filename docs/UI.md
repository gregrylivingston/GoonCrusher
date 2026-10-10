# Menus

Every menu is built in code from one theme, shows each prompt's key or button for the device in use, and works with the mouse alone, a pad alone or the keyboard alone. Layouts, sizes and wording are in the scripts.

## Shared parts (`scene/ui/`)

| File | Class | Use it for |
|---|---|---|
| `menu_theme.gd` | `MenuTheme` | The menus' `Theme`, built from `HudTheme` so menus and HUD can't drift apart. Helpers: `button`, `chip`, `iconRect`, `box`, `addSounds`, and the symbol helpers below. |
| `crisp_icon.gd` | `CrispIcon` | What `iconRect` returns: an icon resampled to the exact pixels it covers. Use it for any small menu icon. |
| `input_glyphs.gd` | `InputGlyphs` | Which device was used last (`usingPad`) and an action's name on it (`label("ui_accept")`). Reads `InputMap`, so rebinding shows up. `ensureMenuActions()` adds the menu's own actions and pad A / B on accept and cancel. |
| `key_hint.gd` | `KeyHint` | A key chip and a label per action: `KeyHint.make(["ui_accept"], "Drive")`. It switches with the device and hides when the action has no binding there. `KeyHint.bar([[actions, label], ...])` makes a clickable bottom bar. |
| `juice.gd` | `Juice` | Short feedback tweens: `shake` (a no), `flash`, `pop`, `rumble` (the shared shake), `dropIn` (an overlay arriving). |
| `count_badge.gd` | `CountBadge` | A count on a button's corner ("how many the bank covers"); hidden at 0. |
| `transitions/` | `Transition` and friends | "Transitions" below. |

The theme's variations (`PrimaryButton`, `TabButton`, the panels and labels) are in `MenuTheme.theme()`.

## Rules for a new menu

1. `theme = MenuTheme.theme()` on the root Control. Build with the theme, not per-node style overrides.
2. One `PrimaryButton` per screen.
3. A `KeyHint` for every key that does something. **Never write "A" or "Enter" into a label.**
4. A hint shows an action's first key, and the left hand comes first: Space on `ui_accept`, WASD before the arrows (`keyFirst`).
5. **Mouse:** everything must work with the mouse alone. Bottom bars are clickable (`KeyHint.bar`). Inside a clickable row, set every child that isn't the button to `MOUSE_FILTER_IGNORE` (`main2.setMouseIgnore`): a plain `Control` defaults to `STOP` and swallows the click. A clickable hint fires its action through `KeyHint.fire`, which must never leave the action stuck pressed.
6. **Pad:** everything must work on a pad alone, including with reassigned keys. Triggers and sticks are axes that send events while held: count only the first press (`main2.triggerEdge`).
7. Honor Reduce Motion (fade instead of move) and Reduce Flashing.
8. A full-screen overlay joins group `menuOverlay`, so the main menu ignores input under it. A pausing in-run menu joins `slotMachine`, so the harnesses tap through it.

### Symbols

Amounts read as numbers followed by the game's symbols, not words: "1,500 (coin)  3 (gem)". Use words only where there is no symbol (UNLOCK, NEED ... MORE, PLAY, MAX).

- `MenuTheme.symbolRow(parts, fontSize, color)`: a row that ignores the mouse. A part is a String, a Texture2D or a cost Dictionary `{"coin": n, "gem": n}`.
- `costParts(cost, short)`: a cost as parts; `short` abbreviates large amounts for tile corners.
- `setButtonParts(button, parts)`: parts on a button in place of its text.

## Transitions

One language for every screen change (`scene/ui/transitions/`): a corrugated garage shutter for screens, tire smoke and skid marks wherever the car, or a panel acting like one, moves.

| Moment | Use | Example |
|---|---|---|
| A real scene or screen change | `await Transition.play(swap)`: slam, run `swap` behind the door, roll up | `main2.goToSetup` |
| Loading | `Transition.close(title, sub)` stays down with progress lamps; `Transition.carry()` picks a door up across `change_scene` | `RunLauncher.start` (the menu's START, the results' Retry and Next), `Level.holdUnderShutter/revealRun`, `gameSummary.outro` |
| An overlay | `Juice.dropIn`; pause uses a half shutter | Goonopedia, Settings, `pauseMenu.intro` |
| An in-run game | `GameHatch`: the panel skids in under a hatch | `PickupMenu` |
| Run start and resume | The start lamps; quick after a prize game | `countdown.gd`, `PickupMenu.resumeRun` |
| A milestone in a run | `TapeBanner.post(text)` (they queue), `Stamp.slam(...)` | `Level`, `SpawnManager` |

**Rules.**

- **Rewards are never credited by a transition or an animation.** Pay first, then play it.
- **Full slams only for real scene changes.** Overlays get a half door, a hatch or a drop.
- **One sound family** (`Transition.sound(name, db)`) and one shake (`Juice.rumble`). The sounds are synthesised by `scripts/art/transition_sounds.py` into `sound/ui/transition/`: change the script and re-run it, never edit the WAVs.
- **Settings:** smoke follows Exhaust Smoke, marks Tire Marks; Reduce Motion fades a still door.
- **Harnesses:** headless runs, `--bench` and `--playtest` skip every transition (`Transition.instant()`): swaps run at once. Code must not depend on a transition's timing.
- `Transition.busy()` is true while a door is moving or down; menus ignore input then.
- The menu's door lives on the tree root above RunView, so it survives `change_scene`. In-run doors live in their own CanvasLayer, because a run may render inside RunView's SubViewport.
- The run waits paused behind the loading door until the world is built. A door must not be freed or re-opened mid-load, and the level always starts the lamps however the door goes.

**To add a transition:** use a row above. For a new effect, add it to `transitions/` with a `Transition.instant()` path and a Reduce Motion path, take sounds from the family, and cover it in `tests/game/test_transitions.gd`.

## Main menu (`scene/player/menu/main/`)

`main2.tscn` holds only the voice player and the version label; `main2.gd` builds the rest. The save holds every selection; the menu only draws it. Its header comment lists the keys.

| Screen | Built by | Notes |
|---|---|---|
| Garage | `main2.buildGarage`, `driver_card.gd` (`DriverCard`) | Driver cards |
| Driver focus | `main2.setFocusOpen`, `driver_bench.gd` (`DriverBench`) | The bench beside the card, where upgrades are bought |
| Run setup: road map | `main2.buildMap`, `makePoster` | One region at a time, five stops |
| Run setup: Level Options | `main2.buildOptions`, `refreshSetup` | Mode, tier, the level's facts, records |
| Launch bar | `launch_bar.gd` (`LaunchBar`), `main2.buildLaunch`, `refreshLaunch` | On all three screens: driver, loadout, Upgrades, Pickups, the primary button |
| Pickups | `pickups/pickup_shop.gd` (`PickupShop`) | A `CodexPage` |
| Goonopedia | `goonopedia/goonopedia.gd` | A `CodexPage` |

- **Input** runs in `main2._input`, before the GUI, so Left/Right switch cards instead of moving focus. It returns early while `Settings.menu_open`, a `menuOverlay` or `Transition.busy()`.
- Cards and posters load their art on a worker thread only when they come into view.
- **Other scripts call:** `startLevel(path)` (bench), `animateCoins` and `statUpdatesUiUpdate()` (SaveManager), `add_child(menu)`; the career harness reads `lockReason` and presses `goButton`, `upgradeButton`, `loadoutButton` and `boostButton`.

### Driver card

`STATS` and `STAT_TEXT` are the one list of stats, which the bench and the pause menu reuse. A card has no buttons: Drive, Unlock and Upgrades are on the launch bar.

### Launch bar

One bar, the same in the garage, on the road map and in Level Options, so a key means one thing everywhere: every slot has its own action (`LaunchBar.SLOT_ACTIONS`) and `test_menus.gd` fails if two of the menu's actions share a key or a pad button.

- It sits in one place on every screen (`LAUNCH_POS`) and closes the bottom row: beside the records in Level Options and beside the bench's signature panel in the driver focus. Anything new at the bottom right must leave that rectangle free.
- Only the primary button takes the focus (`goButton`: Drive or Unlock, Select, Start; `onGoPressed`). The slots work by key or click.
- The pad has no spare button, so the triggers are the gadget and boost and the regions and fact tiles are a flick of the right stick. A new menu action needs a free button on both devices first.
- Upgrades from run setup changes screen to the driver focus and remembers the step it left (`focusReturn`); Back, Upgrades again or Drive returns there.
- The badges count what the bank covers (`DriverCard.affordableUpgrades`, `Unlocks.buyableCount`). The gem badge on the primary button shows only in Level Options, where Start spends them.
- Why the primary button is locked is written beside the bar (`setGoNote`), in symbols.

### Driver focus

On a bench row Buy (`ui_buy`, E / pad A) buys and Accept still drives, so `main2._input` reads Buy first. Because pad A buys on a row, Down from the last row reaches Drive: keep that path when changing the bench's focus (`linkFocus`). E is also next-driver elsewhere, so the launch bar's driver shows A/D here. The buy buttons are never `PrimaryButton`: the row in focus is lit instead.

### Run setup

- Mode order, unlocks and what a win opens are not the menu's rules: it asks `Root.modePath`, `Root.isModePlayable`, `ModeTiers` and `SaveManager` (CLAUDE.md "Flow", docs/MODES.md).
- The launch bar's primary button holds the focus on both steps (`focusSetup`), so Accept always goes on; nothing else there takes it.
- Esc is both `ui_cancel` and `ui_menu`: in run setup Back is read first, so Esc never opens Settings there (the gear button and Start on a pad do).
- The level's fact tiles are generated from the `LevelDef`, `props.json` and `World.TERRAIN` (`fillFacts`); only `EVENT_FACTS` holds words.
- The loadout slots sell only unlocked gadgets and boosts (`Pickups.openLoadout`) and are paid at Start, the gadget first (`slotPurchase`); choices are kept in `meta.records.loadout` and `boostLoadout`.

## Pickups

`PickupShop` is where pickups and prize games are unlocked (rules: docs/PICKUPS.md, "Unlocks"). Tabs are `PickupShop.TABS`, each drawing its kinds' unlock trees from `Pickups.DATA`. It opens on the first tile the bank can buy, so Pickups then Accept buys. With the mouse, the click that focuses a tile only shows it (`isPickingClick`); a second click or the card's button buys.

## Goonopedia

Two tabs, Goons and Systems, generated from `Goons.DATA` and the car's systems. Only plain-language text lives in the script (`VERB_TEXT`, `ACT_TEXT`, `TRAIT_TEXT`, `SYSTEMS`); a goon's DATA may override it with `"blurb"` and `"tip"`. `test_goonopedia.gd` fails if a goon uses a verb or act with no text. Goons are silhouettes until crushed (`PlayerData.goonsCrushed`; `REVEAL_ALL` shows everything).

**`CodexPage`** (`goonopedia/codex_page.gd`) is the frame both pages extend: header, tab row, tile panel, detail card, the tab keys and Back. A page sets `title`, `icon`, `listWidth`, `hints` and `sellsThings` in `_init` and supplies `tabNames()`, `buildTab(index)`, `drawDetail(entry)`, and `startTab()` / `firstFocus()` if the defaults won't do. Use it for any new reference or shop page.

## In-run menus

| Menu | Script | Notes |
|---|---|---|
| Pause | `scene/player/menu/pauseMenu.gd` | Abandon and Quit are separate buttons; with Confirm Abandon / Quit on, each needs a second press |
| Results and Records | `scene/player/menu/gameSummary.gd` | One ticket; `isGameSummary = false` shows a driver's records from the menu. Results put it on the right and leave the world in view |
| Prize games, Pit Shop | `PickupMenu` (`scene/pickups/menus/`) | docs/PICKUPS.md, "Prize games". A key held as a game opens counts only once released |
| Settings | `scene/player/menu/settings/` | docs/PERFORMANCE.md |

- **Results:** the payout and records are saved when the ticket opens, before any row animates. It credits the run's own level, mode and tier (`Level.runLevel`, `runMode`, `tier`), not the menu's selection. The run pauses where it ended: the camera pulls back, the stamp lands on the world, then the ticket comes in and its rows print (`reveal`). Accept, Back or a click shows the rest at once; driving keys do nothing, so a foot on the gas can't pick an action.
- **Results' buttons** (`gameSummary.act`): Retry and Next (`nextRun`) start a run straight from the ticket through `RunLauncher`, which also charges the gadget and boost again; Level Options sets `Root.menuReturn` so the menu opens on run setup for the run's level, mode and tier; Garage is the old Continue. The first button is the primary one and takes Accept; the others have a key each (`ACTION_KEYS`). The pause card's Restart ends the run as abandoned and retries with no ticket (`Level.endLevel`'s `then`).
- **Run rank** (docs/MODES.md): the score and its place on the ladder sit over the world, and roll up when the rows are done.

## Tests

`tests/game/test_menus.gd`, `test_goonopedia.gd`, `test_transitions.gd`, `test_loadout.gd`. None writes the save. What they can't see is in docs/TEST_SCOPE_TRANSITIONS.md.
