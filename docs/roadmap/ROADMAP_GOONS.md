# Roadmap: goons

How goons work today: `docs/GOONS.md`. Tags and effort: `ROADMAP.md`.

## Planned
- **[0.3 want] The Goonopedia's "Found on <biomes>" line** no longer matches where a goon spawns (line-ups decide that now). Show the levels whose line-up has the goon, or drop the line. S.
- **[0.3 want] Crush feel by hand:** `GoonFx.STYLE_WEIGHTS`, `FLING_SPEED`, trauma, hit-stop. S + play.
- **[later] Giants and a boss:** giants get hp 3; a Warlord at wave 4 with a health bar, minions and charges (start from the Foreman's `Boss` verb). Needs `hp` on goons. M.
- **[later] Giant odds** from the district's `giantism` and the run's wave (the value is rolled today and read by nothing). S.
- **[later] A night spawn table** and ×1.5 coins at night; Blackout needs it (`ROADMAP_MODES.md`). Night length is already per level (`rules.nightShare`). S.
- **[later] Goon death sounds** are one shared set (`ROADMAP_AUDIO.md`).

## Suggestions
- **Elite escort goon** (deferred by the author): line-ups with no rank-1 goon have no fodder between heavies. Add a Grunt to Goon Quarry and the War Machine levels and a Yipper to the Big Game levels (`lineup` in `world/levels/*.tres`, `Goons.CLASSES`). Quarry is in the demo.
- A speed-label tint when the car is too slow for a nearby heavy.
- Goons that leave fire behind or reassemble.
- True swarms.
- Champions (on hold with the region revamps).
