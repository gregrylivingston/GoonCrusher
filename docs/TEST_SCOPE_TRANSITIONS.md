# Manual test checklist: menus, transitions, HUD

What a person must look at, because the automated tests and harnesses skip transitions and can't judge a screen. Design: docs/UI.md, docs/HUD.md. Back up the save first, or use `-- --play-start=<tier>`.

## Flows

1. **Garage and run setup.** The shutter slams and rolls up between them; mash Accept and Back during the slam and nothing double-switches. Level Options drops in; Back steps to the road map, then the garage. Esc never opens Settings in run setup.
2. **Garage.** Cards flip when selected. Upgrades opens the driver focus; buy a stat, fail to buy one (shake), drive from a row, change driver and keep the row. The launch bar's badges match what the bank covers. Unlock a car.
3. **Road map.** Walk stops and regions with keys, pad triggers (a held trigger steps once), wheel and clicks. A locked region and a locked stop say what opens them.
4. **Level Options.** Change mode, tier, level (1-5), driver, gadget and boost; walk the level's tiles; START keeps the focus throughout. Upgrades from here and from the road map opens the driver focus, and Back returns to the same step. A locked mode or tier says why. The car strip and records follow the mode, tier and driver.
5. **Pickups and Goonopedia.** Open from the garage and run setup. Buy with Accept, with two clicks and with the card's button; the bank, the badges and the tab update.
6. **Starting a run.** The loading door shows the level and its lamps; the run stays paused until the world is in, then the door rolls up on the car, then the start lamps, then GO and the briefing banner. Try a slow first load and 540p / 720p Render Resolution.
7. **Pause.** Half shutter and card; Continue, Settings, radio, Restart (pays the run, then straight into a new one), Abandon (into results), Quit. Spam Esc during the drop and the lift.
8. **Gift box and prize games.** `-- --prize=<game>` for each: skid in, hatch, play, winnings board, hatch slam, quick lamps. The slot's payout chute. The Pit Shop at a Marathon station.
9. **Results.** Every ending (wrecked, out of gas, time's up, cleared, survived, overrun, abandoned): the run freezes and the camera pulls back, the stamp lands, the ticket comes in from the right; rows, badges, the bank counting up, the rank rolling up. Accept or a click shows it all at once; Accelerate and Brake do nothing. Retry and Next load a run behind the shutter (with a gadget chosen, the gems go again); Level Options opens run setup on the same level, mode and tier; Garage carries the door to the garage, then the coins count up. Each by mouse alone and by pad alone.
10. **In-run banners.** Milestones, nightfall, a wave survived, a mode's own banners: they queue and never overlap, and stay clear of the HUD.
11. **HUD on each of the 9 cars.** Dials, instrument, lamps, mirror (the semi's console), visors. Pickups land on their own icon. Classic Dashboard gives the house look. Night backlight; the hurry pulse in a race's last seconds; the pointers in station, course, bounty and cup modes.
12. **Driving feel.** Handbrake slides and the drift boost on each car; horn; the semi's ability and trailer; manual shifting on the racer, supercar and semi, and Automatic Gearbox. A pause or prize game during a hit-stop must never run slowed.

## Run the flows under each of these

- **Mouse only, pad only, keyboard only,** and with reassigned keys. Every hint bar is clickable; no click leaves an action stuck pressed.
- **Reduce Motion:** fades only; no shake, smoke, skids, swing or ignition sweep.
- **Reduce Flashing:** warnings and lights hold steady; no rim or visor flash.
- **Crush Effects, Screen Shake, Hit-Stop, Exhaust Smoke, Tire Marks** at each level: effects scale or vanish, and cuts still hide behind the shutter.
- **HUD Scale extremes; window aspects other than 16:9, and ultrawide:** nothing overlaps, doors and banners cover the width.

## Harnesses and performance

- `--bench` and `--playtest` wait on no transition (`Transition.instant()`); watch a longer playtest for softlocks around the start lamps.
- Frame times on the low-end box: the shutter slam, the reveal smoke, the wreck smoke wall, a jackpot chute, the Nuke ring.
- Leak warnings at exit: check whether the cached transition textures add to them.
