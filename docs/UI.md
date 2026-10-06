# Menus

The menus were rebuilt in October 2026 from the "Marquee Cards" direction (concept report: the "GoonCrusher Menu Redesign" artifact). They use the same colors, fonts and pickup icons as the in-run HUD (`docs/HUD.md`), and every on-screen prompt shows the keyboard key or controller button the player is using.

## Shared parts (`scene/ui/`)

| File | Class | What it does |
|---|---|---|
| `menu_theme.gd` | `MenuTheme` | Builds the menus' `Theme` in code from `HudTheme`, so menus and HUD can't drift apart. Give a menu's root Control `theme = MenuTheme.theme()`. Also has helpers: `button(text, actions, primary, icon)`, `chip`, `priceChip`, `iconRect`, `box`, `addSounds`. |
| `input_glyphs.gd` | `InputGlyphs` | Tracks whether the player last used a controller (`usingPad`) and names an action's binding on that device (`label("ui_accept")` gives "Enter" or "A"). Bindings come from `InputMap`, so rebinding shows up. `ensureMenuActions()` adds `ui_upgrade` (U / Y), `ui_records` (R / X), and controller A/B on `ui_accept`/`ui_cancel`, which the project didn't bind. |
| `key_hint.gd` | `KeyHint` | One chip per action, then a label: `KeyHint.make(["ui_accept"], "Drive")`. It switches as soon as the player changes device, and hides when the action has no binding on that device. |

**Theme variations.**

- **Buttons:**
  - `Button`: a list row with a faint fill, and an orange rim with gold text when focused or hovered.
  - `PrimaryButton`: the one solid orange action per screen, with a gold focus ring.
  - `TabButton`: settings pills.
- **Panels:**
  - `Panel`/`PanelContainer`: smoked glass with an orange rim.
  - `InfoPanel`: blue rim.
  - `QuietPanel`: faint rim.
  - `CardPanel`, `KeyChip`, `PriceChip`, `BandPanel`.
- **Labels:** `TitleLabel`, `GoldLabel`, `MutedLabel`, `BodyLabel`, `HintLabel`, `DarkLabel` (text on orange).

**Rules for a new menu.** One `PrimaryButton`. A `KeyHint` for every key that does something. Never write "A" or "Enter" into a label. Build with the theme rather than per-node style overrides.

## Main menu (`scene/player/menu/main/`)

`main2.tscn` holds only the voice player and the version label; `main2.gd` builds the rest in code. It has two screens.

**Garage.** A carousel of `DriverCard`s (`driver_card.gd`): the selected card is in the middle, with two on each side, scaled down and dimmed.

- **Choosing a driver:** LB/RB, Q/E or Left/Right picks a driver; clicking a side card selects it.
- **Accept:** drives an owned car, or unlocks a locked one for its price.
- **Upgrade (U / Y):** hands focus to the card's stat rows, where Accept buys and Back finishes. A mouse click on any stat row buys it directly.
- **Records (R / X):** opens the driver's records ticket.
- **Esc / Menu:** opens Settings. The top-left buttons are quit, settings, Discord and Steam.

**Driver card.** Each card shows the driver's portrait over the car's background art and a name band. Locked drivers are silhouettes with their price. The focused card shows every stat:

- the value
- an underline against 100: cream for the car's base stat, gold for upgrades bought
- the next upgrade's price, always shown and dimmed when you can't afford it

**Run setup.** Level posters (LB/RB) with the five mode medallions under them (Left/Right). Accept starts the run, Back returns to the garage.

- **Posters:** each shows a star per mode beaten on that level, and a lock for locked levels.
- **Medallions:** a gold star when the mode is beaten, a dim star when it's playable, a lock when it isn't. The reason a mode is locked shows under its description, and Start reads LOCKED or COMING SOON.

**Loading.** Cards load their `CarInfo` (portrait, background, intro lines) on a worker thread only when they come into view; level posters do the same. This keeps the menu light on the HD 620.

**Input handling.** Navigation runs in `_input`, before the GUI, so Left/Right switch cards instead of moving focus. In upgrade mode the arrows go to the GUI. The menu ignores input while `Settings.menu_open` is set or a node in group `menuOverlay` (the records ticket) is open.

**Other scripts call these:** `startLevel(path)` (bench), `animateCoins(from, to)` and `statUpdatesUiUpdate()` (SaveManager), and `add_child(menu)` (settings, dialogs).

## In-run menus

- **Pause** (`pauseMenu.gd`). A center card: Continue (Esc / Menu), Settings, Abandon run (it says how many coins the run keeps), and Quit game. These are separate buttons, and with Confirm Abandon / Quit on, each asks for a second press. Under them are the mode, clock and crush count, and the car's stats with a gold +N for what pickups added. It replaces the old paused stat list (`car_panel`, removed).
- **Results** (`gameSummary.gd`). A torn paper ticket.
  - **Reveal:** rows appear one at a time (time, top speed, crushes, coins, powerups, gems, slot machines). The first fresh press speeds the reveal up and the next one continues; `isFreshPress` is covered by `test_progression.gd`.
  - **Payout:** coins × stars = paid, from `Root.computePayout`.
  - **Badges:** a beaten record gets a NEW BEST badge, then a stamp lands (WRECKED, OUT OF GAS, TIME'S UP, ABANDONED, CLEARED).
  - **Saving:** the payout and records are saved when the ticket opens.
- **Records.** The same ticket with `isGameSummary = false`, showing the selected driver's bests.
- **Countdown** (`scene/player/countdown.tscn`). A gold numeral matching the HUD clock. A green "GO!" shows for half a second after the run unpauses, so the pause length (and the AI driver's harness) is unchanged.
- **Slot machine** (`slotMachine.gd`). `restyle()` gives it the smoked panel, gold-framed reels and a row of themed Spin / Reroll / Collect buttons with key hints. The original buttons stay hidden because the logic reads their state; `syncButtons()` mirrors it every frame. Accelerate and Brake work as before.
- **Settings** (`settings/*`). Same layout and rows. It uses `MenuTheme`, pill tabs with LB/RB (Q/E) chips, an orange-rimmed focused row, orange slider fills, and footer buttons with their keys.

## Tests

`tests/game/test_menus.gd` covers:

- prompt labels on both devices and switching between them
- driver cards (silhouette and Unlock for locked cars, stats and Drive for owned ones)
- coin formatting
- pause having separate Abandon and Quit buttons
- the records ticket

None of these tests write the save.

## Not done yet

- **Per-car skins:** a `HudSkin` on `CarInfo` could tint a driver's card and the HUD.
- **Car Paint:** the car-art session suggested putting the toggle (`gameplay/car_paint`) on the driver card.
- **Region faction:** the goon session is adding a faction per region; the HUD region chip can show it once `Region.currentRegion.faction` exists.
- **Leftover style resources:** `style/roadRogue.tres` is still referenced by `car.tscn`, `countdown.tscn` and `slotMachine.tscn` (whose hidden original buttons are `roadButton`s).
