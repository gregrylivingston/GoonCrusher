# GoonCrusher Radio: idents, talk and ads in the game

The record of every segment that plays between songs on GoonCrusher Radio: its final script, the direction that produced it, and how it went in. Only segments that are in the game are listed here; drafts live outside the repo until one is chosen and recorded. Format and loudness rules are in `docs/RADIO.md`; the songs are in `docs/RADIO_SONGS.md`.

## In the game

| Segment | File | Length | Kind |
|---|---|---|---|
| Goon-B-Gone | `sound/radio/gooncrusher/ads/ad_goon_b_gone.ogg` | 0:57 | ad |
| Grunt, Grunt and Hubcap | `sound/radio/gooncrusher/ads/ad_law_firm.ogg` | 0:33 | ad |
| Pete's Pit Shop | `sound/radio/gooncrusher/ads/ad_pit_shop.ogg` | 0:36 | ad |

**Segment odds:** with only three ads, `station.json` has `segment_chance` at 0.25: an ad after about one song in four, and the same ad roughly once an hour. Raise it toward 0.6 as idents and talk arrive.

## Writing segments that generate well

Learned on Goon-B-Gone, which took many tries before this format worked:

- **Write for the ear, not the page.** Spell names the way they should be said ("Goon Be Gone", not "Goon-B-Gone"), and drop markdown, bold and speaker labels from the text that gets voiced.
- **One line per beat.** Break the script where the delivery changes (the questions, the pitch, the tagline, the disclaimer).
- **Put delivery cues inline, in parentheses, and make them concrete:** "(very fast infomercial style disclaimer all in one continuous sentence without pauses)" works; "(fast)" doesn't.
- **Write fast reads as one run-on sentence** joined with commas, so nothing pauses.
- **State the maximum length** in the direction ("max length is 30 seconds").
- **Keep the tagline short and in the house voice:** "crush em and clean em" beat the longer original.
- **Keep the direction with the script** as one package: format, length, voice, tone and pace, music bed (with BPM), Suno prompt, sound effects.

### Keeping ads from sounding alike

The first three ads (Goon-B-Gone, Grunt, Grunt and Hubcap, Pete's Pit Shop) came out sounding very similar. They share a shape as much as a sound: a male pitchman, opening questions ("Goon on the windshield?", "Have you been flattened?", "Engine knocking?"), a music bed under talk, and a punchline or fast disclaimer at the end. Every new ad should differ from the ones in the game on most of these:

- **Format:** infomercial, legal ad and local-shop spot are taken. Others: a fully sung jingle, a dialogue skit, an auctioneer, a guided meditation, a lounge song, a testimonial, a game show, a newsreel.
- **Voice:** vary gender, age and accent, and use more than one speaker. Lead with the voice in the Suno prompt (it's the first thing it weighs), and avoid the word "announcer", which pulls toward the same pitchman.
- **Sung or spoken:** Suno is strongest when it sings. A fully sung ad comes out far more distinct than a spoken one over a bed.
- **Opening and ending:** no more opening question lists, and no more fast disclaimers for a while.
- **Music:** a different genre and tempo each time, and sometimes none (a skit with room sound, an a cappella jingle).
- **Tool:** if spoken ads still converge, a text-to-speech tool with picked voices (and the music bed from Suno, mixed under) gives full control of who speaks.

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

## Grunt, Grunt and Hubcap

A daytime-TV injury-lawyer ad for the goons' law firm.

The script and direction below are the draft it was made from; the final take may differ slightly.

**Script**

```
(slow, grave, compassionate) Have you been flattened, squished, or splatted by a speeding sedan?
Grunt, Grunt and Hubcap, Attorneys at Law. We fight for the little guy, and the very large guy with tusks.
(second voice: gravelly goon, proud and earnest) We have never won a case. But we have never stopped trying.
(very fast cheerful legal disclaimer all in one continuous sentence without pauses) we are not responsible for road crossings made against legal advice, which is all of them.
```

**Direction**

| | |
|---|---|
| Format | Daytime-TV injury-lawyer ad, played completely straight until the disclaimer. Max length 30 seconds. |
| Voices | Announcer: male, 50s, deep and grave, the serious-legal-ad voice. Goon lawyer: male, low, throaty and a little nasal, trying hard to sound dignified. |
| Tone and pace | Slow and heavy; "flattened, squished, splatted" read with total gravity. Hopeful lift on "we fight for the little guy". The disclaimer snaps to fast and cheerful. |
| Music bed | Solemn corporate strings and slow piano, 70 BPM, swelling hopefully under the goon lawyer. |
| Suno prompt | `instrumental, no vocals, solemn corporate TV commercial music, slow piano and warm strings, serious then hopeful swell, 70 BPM, ends with a fast cheerful legal disclaimer` |
| Sound effects | Distant tire screech and a soft thud on "run over by a speeding sedan"; a gavel bang on "Attorneys at Law". |

**Processing:** 33 s; −17.2 → −16.1 LUFS, Vorbis q4.

## Pete's Pit Shop

A local car-shop spot with the owner's one-line cameo.

The script and direction below are the draft it was made from; the final take may differ slightly.

**Script**

```
Engine knocking? Steering wobbly? Oil light been on since you bought the car?
Come on down to Pete's Pit Shop, open twenty four hours, right between every leg of the race!
Dents, dings, tires, and whatever that noise is.
No appointment needed, no questions asked.
(dropping to a whisper) Seriously. Pete doesn't want to know.
(second voice: tired old Southern man, flat and slow, after a pause) I don't wanna know.
```

**Direction**

| | |
|---|---|
| Format | Local car-shop radio spot with the owner's one-line cameo at the end. Max length 30 seconds. |
| Voices | Announcer: male, 40s, General American, fast friendly used-car-lot pitchman. Pete: male, 60s, Southern, gravelly, tired, mumbles. |
| Tone and pace | Quick and pushy through the list, a confidential whisper on "Seriously", then a full beat of silence before Pete's flat line. |
| Music bed | Old local TV jingle: honky-tonk boogie-woogie piano, twangy guitar, brushed snare, 130 BPM. Cuts out for Pete's line. |
| Suno prompt | `instrumental, no vocals, old local TV commercial jingle, honky-tonk boogie-woogie piano, twangy electric guitar, brushed snare, cheerful and cheap, 130 BPM, music stops dead before a short flat spoken ending` |
| Sound effects | Engine knock and sputter on "Engine knocking"; ratchet-wrench zips under "Dents, dings, tires"; a weird boing-clunk on "whatever that noise is"; an air-wrench burst before Pete speaks. |

**Processing:** 36 s; −17.0 → −16.1 LUFS, Vorbis q4.
