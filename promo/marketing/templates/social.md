# Social post templates

Three short formats. The clip does the work: the text is one idea and one link. Fill the brackets from a fact sheet, then rewrite in your own voice.

## Length by platform

Platform limits change: check them before a campaign. Working guidance:

| Where | Text | Clip |
|---|---|---|
| X / Bluesky / Threads | 1 to 2 sentences, well under the character limit; link at the end | 6 to 20 s, wide or square, readable with no sound |
| TikTok / Reels / Shorts | a caption of one line; the hook is on screen in the first second | 8 to 20 s, vertical (`--profile vertical`), car low in the frame |
| Reddit / Discord | a plain title that says what it is; 2 to 4 sentences in the body or a first comment | 15 to 40 s, wide |
| Steam screenshot or community post | one caption line | a still (`steam_screens`) |

Vertical and square clips: `promo/shots/social_loops.json`, or `capture.py reframe <take> --to vertical`.

## 1. Single feature clip

One feature, one clip, one line.

```
[What happens in the clip, stated flatly. Fact sheet: one bullet from What it is.]
[Optional second line: the dry aside.]
[Demo on Steam / Wishlist: link]
```
Clip: the sheet's "What to show". If it says "needs a shot", film one first.

## 2. Before / after

0.1 beside 0.3. Use only the "0.1 had ..." lines under Numbers: they are the only before facts that were checked.

```
[0.1: the old number or state.]
[0.3: the new one.]
[One line on what that means for a player.]
[link]
```
Clip: a split screen or a hard cut. Old footage has to come from the old build or the live Steam page; the capture kit films only the current game.

## 3. Number drop

One number, big, over footage. `capture.py stage title --set text="..." --set sub="..."` makes the card.

```
[NUMBER] [THING].
[One line that makes the number concrete. Fact sheet: Numbers, with its Demo vs full game line.]
[link]
```
Say whose number it is: a full-game number in a demo post needs "in the full game" beside it.

## Examples for 0.3 (DRAFTS: rewrite in your own voice)

Each uses only facts from the sheet named.

**Single feature clip** (`features/wilds-living-world.md`; needs a shot of a log pile)
> Hit the log pile fast enough and the logs do the rest. The goons they flatten count as yours.
> GoonCrusher demo 0.3: https://store.steampowered.com/app/1941650

**Single feature clip** (`features/radio.md`; audio from `capture.py song`)
> Now playing on GoonCrusher Radio: "There's a Goon on My Hood." 14 songs, one DJ, and ads for businesses you should not trust.

**Before / after** (`features/goons.md`, `features/game-modes.md`)
> 0.1: 18 goons. Two modes in the demo.
> 0.3: 44 goons, 28 of them in the demo. All 19 modes in the demo.
> We rebuilt it.

**Number drop** (`features/goon-cup.md`)
> 5 RIVALS. 1 STATION. NO SET ROUTE.
> Cannonball is one of six Goon Cup modes in the 0.3 demo.

**Number drop** (`features/road-atlas.md`)
> 30 LEVELS. 6 REGIONS.
> The first two regions, ten levels, are in the demo. The rest are in the full game.
