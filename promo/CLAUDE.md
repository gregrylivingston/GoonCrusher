# Capture kit: instructions for Claude

You are probably helping a **trailer maker who is not a programmer**. They have this repo and want footage, stills or interface pieces out of the game. Read `promo/README.md` first: it is the full manual, and everything they can ask for is in it. This page is how to act on their requests.

## How to help

- **Turn the request into one `capture.py` command and run it.** "A taxi at night in the city, vertical, 15 seconds" is `python promo/tools/capture.py quick --level city --car taxi --time night --profile vertical --seconds 15`. Don't ask them to pick options they didn't mention; use the defaults.
- **Run `python promo/tools/capture.py doctor` first** in a new session, or whenever a command fails with a setup message. Fix what you can (`doctor --fix` installs ffmpeg). If the native library is missing, tell them to ask the author for the two `.dll` files for their commit; do not try to build it.
- **Film small first.** A 4K take is slow (minutes for a few seconds). Unless they asked for 4K, film `--profile wide1080` so they can look, then film the keeper at `wide4k`.
- **Long jobs** (`stock`, a whole shot file at 4K, `seeds`) can take hours. Say so before starting and run them in the background.
- **After filming, tell them where the file is** (the command prints the path) and offer `gallery` to look at it. You can check a result yourself by pulling one frame with ffmpeg and reading the image.
- **A shot they will want again goes in a shot file.** Add it to the right file in `promo/shots/` (or a new one) with a clear `id`, then film it with `shot <file> <id>`. One-offs can stay `quick` commands.
- **A hand drive needs the person.** `hand <name> ...` opens the game for them to play; you can't drive it. Start it, tell them the keys (F9 bookmark, F10 finish), then film their bookmarks with `replay`.
- **Isolating a new interface piece** means finding its node: look in `scene/player/menu/main/main2.gd` (the menu is built in code) for the class or the variable that holds it, then copy a `piece_` shot. The keys that open screens are input actions: `ui_upgrade` (the driver's bench), `ui_accept` (Drive, into run setup), `ui_pickups`, `ui_codex`, `ui_records`, `ui_cancel`. Reading the game's code for this is fine; changing it is not.
- **Report in plain words.** They don't need the command's internals: what was filmed, where it is, and anything that went wrong.

## Words they use, and what they mean

| They say | Use |
|---|---|
| vertical, portrait, Shorts, Reels, TikTok | `--profile vertical` |
| square, feed post | `--profile square` |
| 4K, trailer quality | `--profile wide4k` |
| screenshot, still | `--seconds 0` |
| no HUD, clean | `--hud off` |
| closer / further out | `--zoom` above / below 0.45 |
| transparent, alpha, overlay, lower third | a `stage` or `"layer": "hud"`: it comes out as ProRes 4444 |
| green screen | `--backdrop magenta` (explain: the game is full of green, magenta keys cleanly) |
| slow motion | `slowmo`, on a short stretch |
| a different map | another `--seed` |
| a map, an overview, a backdrop of the level | `panorama --level <id>` |
| just the card / the ticket / one panel | a `piece_` shot in `promo/shots/elements.json`, or a new one with an `isolate` event |
| the "CRUSHED" stamp, the tape, the road sign, the garage door | `stage transition --set which=<stamp, banner, sign or shutter> --set label=...` |
| more goons | `"crowd": {"spawnTimer": 1.0, "progress": 150}` or a `crowd` event |

Level ids, in game order (`LEVELS` in `capture.py`): prairie, orchard, bayou, canyon, moosewoods (The Wilds); mudlick, stilttown, lantern, sawmill, quarry (Tribe Country); highway, ghosttown, saltflats, raiderpass, thunderroad (Raider Road); frostbite, frozenlake, timberline, tarpits, summit (Hunting Grounds); city, manhole, culdesac, gridlock, blockparty (The Sprawl); blastpits, tankfarm, slagfields, theline, crusher (The Works). Cars: sedan, taxi, pickup, police, ambulance, van, racer, supercar, semi.

## Limits to be honest about

- All 19 game modes start, but as untuned first versions. Film `countdown` unless they ask for another (`--mode`, the ids in `scripts/global/modes.gd`, `Modes.IDS`).
- A camera far from the car shows only the part of the world that is loaded round the car. Keep `tripod` and `pan` rigs within about a screen of it.
- `"layer": "hud"` can leave a stray world marker or two in frame. If it matters, they can mask it in the edit.
- Slow motion invents the in-between frames, so fast, busy shots can smear.
- Steam sizes and the social safe-zone guides are approximate. Check Steamworks and a real upload before a final export.
- Prices, payouts and other numbers in the game are placeholders. Avoid shots that linger on them.

## What not to touch

- **Game code.** Everything a trailer maker needs is in `promo/` (shot files, tapes, the brief). If a request needs a change outside `promo/`, say so and stop: that is for the author.
- **The real save.** The kit uses scratch saves by itself. Never copy, edit or delete anything in `%APPDATA%/GoonCrusher/`.
- **The output folder's location.** Footage must stay outside the repo. Never write captures into the repo or add them to git.
- **Commits.** Commit shot files, tapes and brief notes only when they ask.

Maintaining the tools themselves (not the footage): `docs/PROMO.md`.
