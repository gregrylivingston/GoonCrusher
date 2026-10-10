# Test scope: menus, transitions and effects (Oct 2026)

Things to cover when the comprehensive test pass runs. They come from the mouse pass, the shutter and tire-smoke transitions, and the effects refresh. Design and code are described in docs/UI.md, "Transitions".

## What has been checked already

- The unit tests pass (299 as of the handbrake and crush-feel work).
- A 3-run AI playtest (Countdown, Sprint, Marathon) finished with no script errors or softlocks.
- Screenshots in the real build: garage, run setup, loading, start lamps, pause, slot machine, The Deal, results, wreck, nightfall, toasts, Nuke, station pill.

Most effect timings are first-pass values. None has been tuned by hand.

## Flows to play end to end

1. **Garage ↔ run setup.**
   - The shutter slams and rolls up, and input is blocked while it moves.
   - Mash Accept or Back during the slam; nothing should double-switch.
2. **Starting a run.**
   - The loading door shows the level name and lamps.
   - The run holds paused until the world and nearby chunks are in, then the door rolls up on the car, then the start lamps play, then GO.
   - Check on the HD 620, at 540p and 720p Render Resolution (RunView), and with a slow first load.
3. **Pause.**
   - The half shutter drops and the card swings.
   - Continue, Settings from pause, Abandon (shutter slam into results) and Quit.
   - Spam Esc during the drop and the lift.
4. **Slot machine.**
   - Gift box: the drop-in and rattle, the lid pop (no shake under Reduce Motion), then the game's skid in and hatch; the slot's reels settle. Try `-- --prize=<game>` for each game.
   - Bet, stop the reels, then Collect: the chute, the peel-out, then the compact lamps.
   - Also check the Marathon free slot after the Pit Shop: the Pit Shop closes instantly into it.
5. **The Deal, Claw Crane and Pit Shop.** Each skids in, the hatch rolls up, then on leaving the hatch slams, the panel peels out and the lamps start.
6. **Results.**
   - Every ending: WRECKED is smoke with a skid-in; Out of gas, Time's up, Cleared, Survived, Overrun and Abandoned are shutter slams with the ticket feeding up.
   - Row slide-ins, the stamp landing and NEW BEST pops.
   - The lottery MATCH! stamp.
   - Continue: the ticket pulls in and the door carries over to the garage, which rolls up, then the coins count.
7. **Milestones.**
   - TARGET SMASHED (Goonpocalypse), LEG n OF 3 (Marathon), NEW GOON (first crush of a kind; it must not repeat for goons already in the save).
   - The district road sign (not at run start), wave star flyers and NIGHT FALLS.
   - Banners queue and never overlap.
8. **Driving and crush feel** (added with the handbrake and crush-feel work).
   - Handbrake slides on each of the 9 cars; the drift boost charges (blue, then orange sparks) and fires on release; side and tail slams crush.
   - Fire (E / X) and Boost (Shift / LB): Nitro's 2 burns, Hop, Jump Jets; the run-setup loadout toast names each key.
   - Death styles, hood rides, hit-stop on giants and bosses: a pause or a slot machine during a hit-stop must never run slowed.
   - Old saved bindings move Space from Fire to the Handbrake (settings v2).

## Settings matrix

Run flows 1 to 6 under each of these:

- **Reduce Motion:** fades only, with no shake, smoke, skids or swing.
- **Crush Effects Minimal / Reduced / Full, Screen Shake Off / Low / Full, Hit-Stop off.**
- **Reduce Flashing:** HUD warnings hold steady, no toast rim flash, the Nuke shockwave isn't a flash.
- **Exhaust Smoke Off / Low / Full and Tire Marks off:** smoke and marks scale or vanish, and cuts still hide behind the shutter.
- **Slot Celebration Minimal / Reduced / Full:** 4, 8 or 16 chute icons.
- **HUD Scale extremes:** the road sign, banners, station pill and toasts stay clear of the HUD.
- **Window aspects other than 16:9, and ultrawide:** door, banner and sign widths.
- **Controller only, keyboard only, and mouse only.**

## Mouse pass

- Every bottom hint bar is clickable: the main menu (Back included), Goonopedia, Pickups, pause, Deal, Claw and Pit Shop. Also the Q/E tab chips in Settings, Goonopedia and Pickups.
- Driver card:
  - Upgrades (F, or its button) opens the driver focus: the other drivers slide off, the card moves left and the bench slides in with the Engine row focused. The stat rail ignores the mouse.
  - In driver focus: Up/Down move between rows, E buys (gold wash, the number pops, the coins count down), a stat the coins don't cover shakes, Space drives from any row, Down from Dice reaches Drive, A/D change driver and keep the row, and Upgrades, Back or Esc returns to the drivers. A locked driver's bench has no buy buttons and UNLOCK has the focus.
  - The Upgrades and Pickups badges show how many the bank covers, hop every couple of seconds, pop when the number changes, hide at 0 and sit still with Reduce Motion. Pickups opens the Pickups screen on the first tab with something the bank covers, on that tile, and each tab wears its own badge; neither dock badge shows through it. G / View (and Back) closes it; B / L3 opens the Goonopedia.
  - Hovering a feature shows its full text.
  - Side cards show only their art; selecting one flips it to its front (a crossfade with Reduce Motion), and the old one flips back.
  - Upgrades, Drive and Pickups sit in a tray at the bottom centre and follow the selected card.
  - Unlock flashes.
- The mouse wheel scrolls the carousels.
- Run setup's road map:
  - The buttons at the road's ends (and Z/C, LT/RT) open the region before and after at its furthest open stop; a held trigger steps once. A locked region's button shows a lock and shakes; the first region has no button before it, the last none after. Each button shows its key for the device in use.
  - Clicking another stop selects it; Q/E (LB/RB) and A/D walk the road and cross into the next region at either end when it is open; 1-5 pick a stop.
  - Each stop shows five mode glyphs: grey when open, faint when locked, bronze, silver or gold for the best medal by any car. The bar under a glyph is the current driver's own medal; change driver in the garage and the bars change.
  - On a locked stop SELECT reads LOCKED, with what opens it underneath.
  - SELECT, Accept or a click on the selected stop opens Level Options; Back (Esc / B, or the BACK button at the bottom left, beside Discord and Wishlist) returns to the road map, and Back again to the garage. Esc never opens Settings in run setup; the gear button and Start on a pad do.
- Level Options:
  - It opens with the focus on START, on the mode and tier last used, and START keeps the focus: Accept always starts the run.
  - W/S change mode (the rows wrap), A/D change tier, and both work by clicking a mode row or a tier of the switch.
  - Z/C (LT/RT; a held trigger steps once) walk the level's tiles: a white ring marks the tile and the card beside them describes it; one step past the last tile shows the level's blurb again. Opening another level starts with no tile.
  - Each tier of the switch shows its medal, its goal and its win bonus; a locked Hard reads "Beat Medium first". The line under the switch shows why the run can't start (red) or what a win opens (green: Countdown, the featured modes, the next level, "on Medium" at a finale), then the first-clear bonus or "First clear paid".
  - The stop buttons under the title and the keys 1-5 open another level of the region in place; a locked stop is dim and does nothing. The mode falls back to one the new level can start.
  - Shift+Z/C jump a group of tiles at a time. Unknown goons are question marks; the RULES tiles show the night's share and the level's events.
  - Mode rows: medals fill bronze, silver, gold; each row is one line (its name); a mode that isn't built is a slim "Coming soon" row.
  - The records panel (bottom left) follows the mode and Q/E: the driver's medal here beside the best by any car and who holds it; a fixed-course mode and Goonpocalypse add their time or score.
  - START's badge shows the gems the gadget and boost will take, and goes away with none chosen. The three sections line up on both edges with even gaps, and the mode rows end level with the pane.
  - Road map: SELECT is the round button at the bottom right; on a locked stop it reads LOCKED with what opens it beside it. The radio is beside the top-left buttons in the garage too and clear of the logo.
  - Q/E (LB/RB) or a click on the driver pill change the driver among the cars owned; the car strip, the mode rows' bars and the pill follow. The road map's driver chip is hidden here and back on the road map.
  - The level's tiles: goons (silhouettes until crushed), ground swatches, props. The mouse on one fills the card beside them; leaving brings back the card of the tile Z/C walked to, or the level's blurb. A click on a goon's tile opens the Goonopedia.
  - The car strip: cleared cars in colour, owned-but-not-cleared dim, unowned as outlines, the driver bigger over an orange bar. It updates with the mode and tier. "FULL GARAGE" shows in gold when all 9 have won. Clicking an owned car makes it the driver; clicking an unowned one does nothing.
- The mode rows and the tier switch have hover states.
- Check that a synthetic action fired by a click never leaves an action stuck "pressed" (`KeyHint.fire`).

## Harnesses and performance

- **Bench:** run S1–S5. Check that nothing waits on transitions in `--bench` (`Transition.instant()`), and compare menu-to-run times with the old numbers.
- **Playtest:** a longer multi-mode set, including Defense and Goonpocalypse. Watch for softlocks around the lamps (paused about 3 s, plus the reveal hold of up to 3 s).
- **HD 620 frame times:**
  - the shutter slam on the menu
  - the reveal smoke
  - the wreck smoke wall
  - a jackpot chute with 16 icons
  - the Nuke ring
- **Leak warnings at exit:** the playtest prints ObjectDB and RID leaks. Check whether the cached textures (`ShutterDoor.ribTexture`, `TransitionFx.puffTexture`) add to them.

## Known risks and loose ends

- **The menu door race (fixed, keep an eye on it).** `main2._ready` used to open a loading door that `startLevel` had just created, so runs started unheld over an unbuilt world. A door can no longer be freed or re-opened mid-load, and the level always starts the lamps however the door goes. Add an automated test for it if possible.
- **Editor-open scenes.** `car.tscn`, the 9 car scenes, `slotMachine.tscn`, `countdown.tscn` and `playerRoot.tscn` were changed on disk. An editor saving stale copies would bring back the deleted indicator or `roadRogue` references.
- **Deleted files:**
  - `style/roadRogue.tres`
  - `scene/player/ui/roadButton.*`
  - the splash scenes (`scene/player/menu/splash/*`, `splashScreen.*`, `scene/splash_text.tscn`)
  - `scene/fx/lotto/*`

  Check that the export and the editor show no missing-resource errors.
- **Car scenes after the indicator removal.** The `ShaderMaterial` sub-resources used only by the old indicator remain in the 9 car scenes, unused. Godot drops them on the next save.
- **Test runner gap.** A script error inside a test counts as a pass. Worth fixing in `tests/game/run_tests.gd` before relying on the suite.
- **Placeholder sounds.** Transition sounds are synthesised (`scripts/art/transition_sounds.py`). Listen to them in context; they may need recorded replacements.
- **Not built:** Option 3's parked-car garage bay on the return to the menu.
