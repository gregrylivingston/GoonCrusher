# Test scope: menus, transitions and effects (Oct 2026)

Things to cover when the comprehensive test pass runs: the shutter and tire-smoke transitions, the effects, the mouse pass over the menus, and the HUD's mirror, visors and dashboards. Design and code are described in docs/UI.md ("Transitions", "Main menu") and docs/HUD.md.

## What has been checked already

- The unit tests pass.
- A 3-run AI playtest (Countdown, Sprint, Marathon) finished with no script errors or softlocks.
- Screenshots in the real build, taken before the road map, Level Options, the Pickups screen, the driver focus and the HUD's mirror and visors existed: garage, run setup, loading, start lamps, pause, slot machine, The Deal, results, wreck, nightfall, toasts, Nuke, station pill. None of the newer screens has had a pass by hand.

Most effect timings are first-pass values. None has been tuned by hand.

## Flows to play end to end

1. **Garage ↔ run setup.**
   - The shutter slams and rolls up, and input is blocked while it moves.
   - Mash Accept or Back during the slam; nothing should double-switch.
   - Road map → Level Options drops in with no shutter; Back returns to the road map, then (with the shutter) to the garage.
2. **Starting a run.**
   - The loading door shows the level name and lamps.
   - The run holds paused until the world and nearby chunks are in, then the door rolls up on the car, then the start lamps play, then GO.
   - Check on the HD 620, at 540p and 720p Render Resolution (RunView), and with a slow first load.
3. **Pause.**
   - The half shutter drops and the card swings.
   - Continue, Settings from pause, Abandon (shutter slam into results) and Quit.
   - Spam Esc during the drop and the lift.
4. **Gift box and slot machine.**
   - Gift box: the left visor flashes gold, then the drop-in and rattle, the lid pop (no shake under Reduce Motion), then the game's skid in and hatch; the slot's reels settle. Try `-- --prize=<game>` for each game.
   - Bet, stop the reels, then Collect: the chute, the peel-out, then the quick lamps.
5. **The other prize games and the Pit Shop** (Claw Crane, Hubcap Shuffle, Goon Press, The Deal, Pachinko Drop, Coin Pusher; the Pit Shop at a Marathon station). Each skids in, the hatch rolls up, it ends on the winnings board, then on leaving the hatch slams, the panel peels out and the quick lamps start.
6. **Results.**
   - Every ending: WRECKED is smoke with a skid-in; Out of gas, Time's up, Cleared, Survived, Overrun and Abandoned are shutter slams with the ticket feeding up.
   - Row slide-ins, the stamp landing and NEW BEST pops.
   - The lottery MATCH! stamp.
   - The newer rows: win bonus, first clear, new car clear, Full Garage, Road open, Unlocked (docs/UI.md, "In-run menus"); amounts are symbols.
   - Continue: the ticket pulls in and the door carries over to the garage, which rolls up, then the coins count.
7. **Milestones.**
   - TARGET SMASHED (Goonpocalypse), STATION - LEG n OF m (Marathon; the leg count goes by tier), NEW GOON (first crush of a kind; it must not repeat for goons already in the save).
   - The briefing banner at GO, and the second one on a mode's first 3 runs.
   - A wave survived: the right visor flashes and the star flies to its ring. NIGHT FALLS. Entering a district shows nothing.
   - The newer modes' banners (checkpoints and gates, laps, marks, rivals out).
   - Banners queue and never overlap.
8. **Driving and crush feel** (added with the handbrake and crush-feel work).
   - Handbrake slides on each of the 9 cars; the drift boost charges (blue, then orange sparks) and fires on release; side and tail slams crush.
   - Fire (E / X) and Boost (Shift / LB): Nitro's 2 burns, Hop, Jump Jets; the run-setup loadout toast names each key.
   - Horn (Q / Y) on every car; the semi's Drop the Load (F / B).
   - The manual cars (racer, supercar, semi): R / C (D-pad Up / Down) shift, down past N is R, the gear number goes green in the shift window and white on a kick, the toast names the keys; Automatic Gearbox on shifts for you.
   - Death styles, hood rides, hit-stop on giants and bosses: a pause or a slot machine during a hit-stop must never run slowed.
   - Old saved bindings move Space from Fire to the Handbrake (settings v2).

9. **The HUD** (docs/HUD.md).
   - Each of the 9 cars' dashboards: both dials, the signature instrument, the lamps' style, the mirror's dressing; the semi's console in place of the mirror. Classic Dashboard gives every car the house look.
   - The ignition sweep at run start, the night backlight, the horn lamp, a cracked speedometer under 40% hull.
   - Mirror: clock left, goal right in each mode; the dice and clover swing in corners and jump when their stat rises; the frame pulses red in a race clock's last 15 s.
   - Left visor: the gift box ring fills with crush XP; it opens for 5 s with the song at each new song or station change.
   - Right visor: the star ring fills with the wave, the payout follows coins and stars, the gem tab slides out for 3 s on a gem.
   - Pickups fly to their own icon (lamps, fuel, hull, coin, star, gem, dice, clover, gift box, the held slots).
   - Esc / Start pauses; there is no pause button on the HUD.

## Settings matrix

Run flows 1 to 6 and 9 under each of these:

- **Reduce Motion:** fades only, with no shake, smoke, skids or swing; the mirror's charms hang still and there is no ignition sweep.
- **Crush Effects Minimal / Reduced / Full, Screen Shake Off / Low / Full, Hit-Stop off.**
- **Reduce Flashing:** HUD warnings hold steady, no toast rim flash, no visor flash, the lightbar repeater and shift lights hold steady, the Nuke shockwave isn't a flash.
- **Exhaust Smoke Off / Low / Full and Tire Marks off:** smoke and marks scale or vanish, and cuts still hide behind the shutter.
- **Slot Celebration Minimal / Reduced / Full:** 4, 8 or 16 chute icons.
- **HUD Scale extremes:** banners, the station pill and toasts stay clear of the mirror, the visors, the dials and the instrument.
- **Window aspects other than 16:9, and ultrawide:** door and banner widths; the visors stay in their corners.
- **Controller only, keyboard only, and mouse only** (every menu must work fully on each; check with reassigned keys too).

## Mouse pass

- Every bottom hint bar is clickable: the main menu, Goonopedia, Pickups, pause, the prize games and the Pit Shop. Also the Q/E tab chips in Settings, Goonopedia and Pickups.
- Driver card:
  - Upgrades (F, or its button) opens the driver focus: the other drivers slide off, the card moves left and the bench slides in with the Engine row focused. The stat rail ignores the mouse.
  - In driver focus: Up/Down move between rows, E (pad A) buys (gold wash, the number pops, the coins count down), a stat the coins don't cover shakes, Space drives from any row, Down from the last row reaches Drive (how a pad drives from here), A/D change driver and keep the row, and Upgrades, Back or Esc returns to the drivers. A locked driver's bench has no buy buttons and UNLOCK has the focus.
  - The Upgrades and Pickups badges show how many the bank covers, hop every couple of seconds, pop when the number changes, hide at 0 and sit still with Reduce Motion. Pickups opens the Pickups screen on the first tab with something the bank covers, on that tile, and each tab wears its own badge; neither dock badge shows through it. G / View (and Back) closes it; B / L3 opens the Goonopedia.
  - Hovering a feature shows its full text. A manual car has its "N-SPEED MANUAL" chip. The pill under the focused card counts its wins by tier and its levels won.
  - Side cards show only their art; selecting one flips it to its front (a crossfade with Reduce Motion), and the old one flips back.
  - Upgrades, Drive and Pickups sit in a tray at the bottom centre and follow the selected card.
  - Unlock flashes.
- The mouse wheel steps the garage's drivers and the road map's stops. The radio card (top left): a click skips the song, a right click turns the radio on or off.
- Run setup's road map:
  - The buttons at the road's ends (and Z/C, LT/RT) open the region before and after at its furthest open stop; a held trigger steps once. A locked region's button shows a lock and shakes; the first region has no button before it, the last none after. Each button shows its key for the device in use.
  - Clicking another stop selects it; Q/E (LB/RB) and A/D walk the road and cross into the next region at either end when it is open; 1-5 pick a stop.
  - Each stop shows five mode glyphs: grey when open, faint when locked, bronze, silver or gold for the best medal by any car. The bar under a glyph is the current driver's own medal; change driver in the garage and the bars change.
  - SELECT is the round button at the bottom right, where START is in Level Options; on a locked stop it reads LOCKED, with what opens it beside it.
  - SELECT, Accept or a click on the selected stop opens Level Options; Back (Esc / B, or the BACK button at the bottom left, beside Discord and Wishlist) returns to the road map, and Back again to the garage. Esc never opens Settings in run setup; the gear button and Start on a pad do.
- Level Options:
  - It opens with the focus on START, on the mode and tier last used, and START keeps the focus: Accept always starts the run.
  - W/S change mode (the rows wrap), A/D change tier, and both work by clicking a mode row or a tier of the switch.
  - Z/C (LT/RT; a held trigger steps once) walk the level's tiles: a white ring marks the tile and the card beside them describes it; one step past the last tile shows the level's blurb again. Opening another level starts with no tile.
  - Each tier of the switch shows its medal, its goal and its win bonus; a locked Hard reads "Beat Medium first". The line under the switch shows why the run can't start (red) or what a win opens (green: Countdown, the featured modes, the next level, "on Medium" at a finale), then the first-clear bonus or "First clear paid".
  - The stop buttons under the title and the keys 1-5 open another level of the region in place; a locked stop is dim and does nothing. The mode falls back to one the new level can start.
  - Shift+Z/C jump a group of tiles at a time. Unknown goons are question marks; the RULES tiles show the night's share and the level's events.
  - Mode rows: five (Sprint, Countdown and the level's three featured modes), medals fill bronze, silver, gold; each row is one line (its name); a locked mode shows a lock with the reason as its tooltip; a mode that isn't built is a slim "Coming soon" row.
  - F / Y cycles the Gadget slot and V / RS the Boost slot, skipping what the gems can't cover; each shows its pickup's name, uses and price beside it.
  - The records panel (bottom left) follows the mode and Q/E: the driver's medal here beside the best by any car and who holds it; a fixed-course mode and Goonpocalypse add their time or score.
  - START's badge shows the gems the gadget and boost will take, and goes away with none chosen. The three sections line up on both edges with even gaps, and the mode rows end level with the pane.
  - The radio card is clear of the logo in the garage and wider in run setup.
  - Q/E (LB/RB) or a click on the driver pill change the driver among the cars owned; the car strip, the mode rows' bars and the pill follow. The road map's driver chip is hidden here and back on the road map.
  - The level's tiles: goons (silhouettes until crushed), ground swatches, props. The mouse on one fills the card beside them; leaving brings back the card of the tile Z/C walked to, or the level's blurb. A click on a goon's tile opens the Goonopedia.
  - The car strip: cleared cars in colour, owned-but-not-cleared dim, unowned as outlines, the driver bigger over an orange bar. It updates with the mode and tier. "FULL GARAGE" shows in gold when all 9 have won. Clicking an owned car makes it the driver; clicking an unowned one does nothing.
- The mode rows and the tier switch have hover states.
- Pickups screen: 1-7, Q/E (LB/RB) or a click change tab; the first click on a tile shows it, the second (or the card's UNLOCK, or Accept) buys; the tab rebuilds with the bought tile still focused; G / View or Back closes it.
- Goonopedia: two tabs (Goons, Systems); B / L3 or Back closes it.
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
- **Editor-open scenes.** `car.tscn`, the 9 car scenes, `slotMachine.tscn`, `countdown.tscn` and `playerRoot.tscn` were changed on disk. An editor saving stale copies would bring back the deleted indicator, the old HUD panels or `roadRogue` references.
- **Deleted files:** `scene/player/ui/roadButton.*`, the splash scenes (`scene/player/menu/splash/*`, `splashScreen.*`, `scene/splash_text.tscn`) and `scene/fx/lotto/*`. Check that the export and the editor show no missing-resource errors. `style/roadRogue.tres` is deleted too. `RoadSign` (`scene/ui/transitions/road_sign.gd`) is only used by the capture kit's stages.
- **Car scenes after the indicator removal.** The `ShaderMaterial` sub-resources used only by the old indicator remain in the 9 car scenes, unused. Godot drops them on the next save.
- **Test runner gap.** A script error inside a test counts as a pass. Worth fixing in `tests/game/run_tests.gd` before relying on the suite.
- **Placeholder sounds.** Transition sounds are synthesised (`scripts/art/transition_sounds.py`). Listen to them in context; they may need recorded replacements.
- **Not built:** Option 3's parked-car garage bay on the return to the menu.
