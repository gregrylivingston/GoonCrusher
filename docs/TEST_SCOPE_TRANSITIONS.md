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

- Every bottom hint bar is clickable: the main menu (Back included), Goonopedia, pause, Deal, Claw and Pit Shop. Also the Q/E tab chips in Settings and Goonopedia.
- Driver card:
  - Clicking a stat opens the upgrade sheet on that stat.
  - Hover focuses a row, and a click buys.
  - A row you can't afford shakes.
  - Done closes the sheet.
  - Upgrade and unlock flashes.
- The mouse wheel scrolls the carousels (not in upgrade mode).
- Clicking a side poster selects that level.
- The medallions have hover states.
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
