# Roadmap: menus, HUD and Steam features

How they work today: `docs/UI.md`, `docs/HUD.md`. Tags and effort: `ROADMAP.md`.

## Planned
- **[0.3 need] The manual test checklist** (`docs/TEST_SCOPE_TRANSITIONS.md`), start to finish, three times: keyboard, mouse alone, pad alone. Include reassigned keys. M + play.
- **[0.3 need] The end of the demo:** check what a player sees at level 11, at car 4 and at a "FULL GAME" pickup, and that the Wishlist button opens the store page. S.
- **[0.3 need] The loading door racing the menu** has no automated test: try it by hand on a slow machine (`docs/UI.md`, "Transitions"). S.
- **[0.3 want] First-run hints** (one-time toasts, flags in `meta.hints`): crush speed, the prize games' keys, where stars come from, gadget Use, deep water and wading, what smashes and what doesn't. Interactive props and modes already have theirs. S to M.
- **[0.3 want] Effect timings** in transitions are first-pass values; transition sounds are synthesized placeholders. Look and listen in context. S + play.
- **[0.3 need] Run rank par:** bake `world/run_par.json` for every level, mode and tier once the modes are balanced (`docs/MODES.md`, "Run rank"), then play and tune the ladder: the shares, the loss cap, the tier scale and the rank names in `RunRank`. M + play.
- **[0.3 want] The results screen by hand:** every ending on keyboard, mouse and pad; a long win (first clear, new car, Full Garage, unlocks) still fits; 720p and 540p Render Resolution. S + play.
- **[later] Results extras:** the car's route drawn on a small map on the ticket; a Pickups shortcut on the "Ready to unlock" chip. S to M.
- **[later] Records:** per-level records for the modes without a course record; a "Next up" panel. M.
- **[later] Steam:** a `SteamService` autoload guarded by `Engine.has_singleton("Steam")`; mirror the game's achievements (`Achievements.steamId`; not every goon tier needs a Steam entry); `steam_appid.txt` only in dev builds. The addon loads; no game code calls it. M.

## Suggestions
- **Contracts:** three date-seeded contracts, reroll for a gem (needs Steam or a clock rule). M.
- **Leaderboards** (needs Steam).
- The unused "PriceChip" theme variation in `menu_theme.gd` can go.
