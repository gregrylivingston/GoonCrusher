# GoonCrusher Radio: idents, talk and ads in the game

The record of every segment that plays between songs on GoonCrusher Radio: its final script, the direction that produced it, and how it went in. Only segments that are in the game are listed here; drafts live outside the repo until one is chosen and recorded. Format and loudness rules are in `docs/RADIO.md`; the songs are in `docs/RADIO_SONGS.md`.

## In the game

| Segment | File | Length | Kind |
|---|---|---|---|
| Goon-B-Gone | `sound/radio/gooncrusher/ads/ad_goon_b_gone.ogg` | 0:57 | ad |

**Segment odds:** with a single ad, `station.json` has `segment_chance` at 0.15, so the ad plays after about one song in seven (roughly every 20 minutes) instead of after most songs. Raise it toward 0.6 as idents and talk arrive.

## Writing segments that generate well

Learned on Goon-B-Gone, which took many tries before this format worked:

- **Write for the ear, not the page.** Spell names the way they should be said ("Goon Be Gone", not "Goon-B-Gone"), and drop markdown, bold and speaker labels from the text that gets voiced.
- **One line per beat.** Break the script where the delivery changes (the questions, the pitch, the tagline, the disclaimer).
- **Put delivery cues inline, in parentheses, and make them concrete:** "(very fast infomercial style disclaimer all in one continuous sentence without pauses)" works; "(fast)" doesn't.
- **Write fast reads as one run-on sentence** joined with commas, so nothing pauses.
- **State the maximum length** in the direction ("max length is 30 seconds").
- **Keep the tagline short and in the house voice:** "crush em and clean em" beat the longer original.
- **Keep the direction with the script** as one package: format, length, voice, tone and pace, music bed (with BPM), Suno prompt, sound effects.

## Goon-B-Gone

A 90s infomercial for a windshield cleaner, with a disclaimer that undoes it.

**Script:**

```
Goon on the windshield? Goo in the grille? Little goon footprints on the roof that you just can't explain?
Try Goon Be Gone the spray-on cleaner with the power of a fire hose and the smell of a pine forest that has seen things.
One spray and your car is showroom shiny ready to get dirty all over again. Goon-B-Gone: crush em and clean em.
(very fast informercial style disclaimer all in one continuous sentence without pauses)
Not for use on goons, goon be gone does not remove goons, Do not drink goon be gone.
```

**Direction:**

| | |
|---|---|
| Format | Classic infomercial: problem, miracle product, tagline, disclaimer. Max length 30 seconds. |
| Voice | Announcer: male, 40s, General American, booming late-night-TV pitchman, every product word punched. |
| Tone and pace | Starts grossed-out and sympathetic on the questions, swings to triumphant at "Try Goon-B-Gone". The "pine forest that has seen things" line slows down and goes dead serious for one beat. |
| Music bed | Cheesy 90s infomercial funk: slap bass, bright synth brass stabs, cheap drum machine, 140 BPM. Starts as a single sad bass note on the problem questions, kicks in fully on the product name. |
| Suno prompt | `instrumental, no vocals, cheesy 1990s TV infomercial funk, slap bass, bright synth brass stabs, cheap drum machine, upbeat and corny, 115 BPM, ends with fast informerical style disclaimer` |
| Sound effects | Wet splat on "windshield"; squelch on "goo in the grille"; tiny pitter-patter footsteps on "roof"; spray-can hiss on "One spray"; a glass ding sparkle on "showroom shiny". |

**Processing:** the generated take runs 57 s (the direction asked for 30); it went in whole, ending on its own sting. −16.4 → −16.1 LUFS, Vorbis q4 (a notch above the q3 for plain voice, for the music bed).
