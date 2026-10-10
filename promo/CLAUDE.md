# Capture kit: instructions for Claude

You are probably helping a **trailer maker who is not a programmer**. Read `promo/README.md` first: it is their manual. `python promo/tools/capture.py <command> --help` lists every option; job fields and events are in the header of `promo/capture/session.gd`, stages in `promo/stages/stage.gd`. How the kit works inside: `docs/PROMO.md`.

## How to help

- **Turn the request into one `capture.py` command and run it,** with defaults for whatever they didn't mention. Level and car ids are `LEVELS` and `CARS` in `capture.py`; mode ids are `Modes.IDS` (`scripts/global/modes.gd`).
- **Run `doctor` first** in a new session or after a setup error (`--fix` installs ffmpeg). If the native library is missing, tell them to ask the author for the two `.dll` files; do not try to build it.
- **Film small first:** `--profile wide1080` to look, then the keeper at `wide4k`. Say so before a long job (`stock`, a shot file at 4K, `seeds`) and run it in the background.
- **Afterwards say in plain words** what was filmed and where it is, and offer `gallery`.
- **A hand drive needs the person:** start `hand <name>`, tell them F9 bookmarks and F10 finishes, then film with `replay`.
- **Isolating a new interface piece:** find its class or the variable that holds it in `scene/player/menu/main/main2.gd`, then copy a `piece_` shot from `elements.json`. Screens open with input actions (`ui_upgrade`, `ui_accept`, `ui_pickups`, `ui_codex`, `ui_records`, `ui_cancel`).

## Words they use

| They say | Use |
|---|---|
| Shorts, Reels, TikTok / feed post / trailer quality | `--profile vertical` / `square` / `wide4k` |
| screenshot, still | `--seconds 0` |
| transparent, overlay, lower third | a `stage`, or `"layer": "hud"` |
| green screen | `--backdrop magenta` (the game is full of green) |
| an overview, a backdrop of the level | `panorama` |
| just the card / the ticket / one panel | a `piece_` shot, or a new one with an `isolate` event |
| the stamp, the tape, the road sign, the garage door | `stage transition --set which=<stamp, banner, sign or shutter>` |
| more goons | a `crowd` event, or `"crowd": {"spawnTimer": 1.0, "progress": 150}` |

## Be honest about

- Modes other than `countdown` are untuned first versions; prices and payouts are placeholders. Avoid shots that linger on numbers.
- A camera far from the car shows unloaded world. Keep `tripod` and `pan` rigs within about a screen of it.
- Steam sizes and safe zones are approximate.

## Don't touch

- **Game code.** If a request needs a change outside `promo/`, say so and stop: that is for the author.
- **The real save** (`%APPDATA%/GoonCrusher/`); the kit uses scratch saves.
- **The repo with footage.** Captures stay in the output folder, never in git.
- **Commits:** shot files, tapes and brief notes only, and only when they ask.
