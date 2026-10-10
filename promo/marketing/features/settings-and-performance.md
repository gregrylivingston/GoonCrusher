# Settings and low-end PCs

**Pitch:** Built on a laptop with integrated graphics, with a settings menu that says what each option costs.

## What it is
- Four presets: Potato, Low, Medium, High. The game picks one on first run, measures, and may step down one.
- Every option says what it does and what it costs.
- Render Resolution down to 540p, a frame rate limit, effect levels, and a simple headlight option.
- Safe mode: two failed starts in a row and the game opens on the lightest settings, then asks whether to keep them.
- Effect levels never change rewards or results. Only the lowest lighting level changes what you can see at night.
- Rebindable keys and an Accessibility tab.

## Numbers
- 6 tabs: Graphics, Display, Audio, Controls, Accessibility, Gameplay (`settings_menu.gd`, `buildSchema`).
- 10 Accessibility options.
- Reference machine: Intel HD 620, 4 threads (docs/PERFORMANCE.md).
- 0.1's graphics settings were fullscreen and V-Sync (old `graphics.gd`).

## Demo vs full game
- The same in both.

## What to show
- The settings menu: **needs a shot** (a `menu` stage with `press` events).
- F3 cycles a performance overlay, for a side-by-side of presets.

Not ready to quote: frame rates. Everything measured predates the road atlas and the new modes, and night crowds still miss the target on Low and Potato.

Details: docs/PERFORMANCE.md.
