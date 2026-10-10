# Marketing kit

What you need to write a devlog, a Steam update or a social post about a feature, without digging through the code.

| Here | What it is |
|---|---|
| `../../CHANGELOG.md` | What changed for players, per version. The source for everything below. |
| `features/` | One fact sheet per headline feature: pitch, what it is, numbers you can quote, demo vs full game, what to film. |
| `templates/` | `devlog.md`, `steam_update.md`, `social.md`: bracketed placeholders, where each part comes from, and one draft for 0.3. |

Footage and stills come from the capture kit next door: `promo/README.md`.

## From changelog to post

1. **Changelog.** When a feature lands, add its lines to `CHANGELOG.md` in player words.
2. **Fact sheet.** Add or update `features/<slug>.md`. Check every number against the game; note where it came from.
3. **Footage.** Film what the sheet's "What to show" names: `python promo/tools/capture.py shot <file> <id>`, `quick`, or `hand` / `replay` for anything that has to look played. If it says "needs a shot", add one to `promo/shots/` or a line to `promo/brief/shot_requests.md`.
4. **Post.** Copy a template, fill the brackets from the sheet and the changelog, rewrite it in your own voice.

Two rules: quote only what a sheet lists under Numbers, and say "(full game)" when a clip shows something the demo doesn't have.

## 0.3 headline features

Post order is a suggested devlog series, broadest first, ending on the release post.

| # | Feature | Fact sheet | Best shot today |
|---|---|---|---|
| 1 | The road atlas and regions | `road-atlas.md` | `elements piece_road_map`, `lineup_posters`; `trailer_launch world_pullback` |
| 2 | Cars, handling and traits | `cars-and-handling.md` | `elements lineup_cars`, `piece_driver_card`; a slide and drift boost needs a hand drive |
| 3 | The goons | `goons.md` | `elements lineup_goons`, `page_goonopedia`; `social_loops crush_prairie` |
| 4 | The Wilds' living world | `wilds-living-world.md` | `trailer_launch cold_open` for the place; props and events need a shot |
| 5 | Game modes | `game-modes.md` | needs a shot (every shot file films Countdown) |
| 6 | The Goon Cup and AI rivals | `goon-cup.md` | needs a shot |
| 7 | Prize games and gift boxes | `prize-games.md` | `elements prize_claw`; Hubcap Shuffle and the box need shots |
| 8 | Pickups and unlock trees | `pickups-and-unlocks.md` | `elements lineup_pickups`, `page_pickups` |
| 9 | The HUD and dashboards | `hud-dashboards.md` | `elements hud_alone` (racer: copy it with a demo car) |
| 10 | GoonCrusher Radio | `radio.md` | `capture.py song <name>` for audio; the now-playing card needs a shot |
| 11 | Settings and low-end PCs | `settings-and-performance.md` | needs a shot |
| 12 | Release: "0.3 is out" | all of them | `steam_screens`, `trailer_launch`, refilmed on demo levels and cars |

Demo check before filming: the demo has ten levels (The Wilds, Tribe Country) and three cars (sedan, van, taxi). Many existing shots use other cars or later levels; those are full-game footage.

## Voice

- Dry roadside-America deadpan: state the absurd thing flatly: "We have never won a case. But we have never stopped trying."
- Blue-collar and local: gas stations, tire barns, pit shops, truck stops. No fantasy or tech words.
- Short taglines: "We don't brake for goons." "Crush em and clean em."
- Cartoon violence only (squish, splat, flat), never mean, no swearing.
- Numbers over adjectives: "44 goons", not "tons of enemies".
