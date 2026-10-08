# GoonCrusher Radio: idents, talk and ads in the game

The record of every segment that plays between songs on GoonCrusher Radio: its final script, the direction that produced it, and how it went in. Only segments that are in the game are listed here; drafts live outside the repo until one is chosen and recorded. Format and loudness rules are in `docs/RADIO.md`; the songs are in `docs/RADIO_SONGS.md`.

## In the game

| Segment | File | Length | Kind |
|---|---|---|---|
| Goon-B-Gone | `sound/radio/gooncrusher/ads/ad_goon_b_gone.ogg` | 0:57 | ad |
| Grunt, Grunt and Hubcap | `sound/radio/gooncrusher/ads/ad_law_firm.ogg` | 0:33 | ad |
| Pete's Pit Shop | `sound/radio/gooncrusher/ads/ad_pit_shop.ogg` | 0:36 | ad |
| Big Earl's Tire Barn | `sound/radio/gooncrusher/ads/ad_tires.ogg` | 0:42 | ad |
| Gas N Go | `sound/radio/gooncrusher/ads/ad_gas_n_go.ogg` | 0:30 | ad (sung jingle) |
| Fender Bender Mutual | `sound/radio/gooncrusher/ads/ad_insurance.ogg` | 1:02 | ad |
| The Lucky Lug Nut | `sound/radio/gooncrusher/ads/ad_slot_parlour.ogg` | 0:32 | ad (sung) |

**Segment odds:** with seven ads and no idents or talk, `station.json` has `segment_chance` at 0.35: an ad after about one song in three, and any one ad roughly once every 70 minutes. Raise it toward 0.6 as idents and talk arrive.

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

The second batch was written to these rules (each a different format: an auction chant, a sung jingle, a guided meditation, a lounge song; see the entries below). Four of five came out well enough to use. The fifth, a two-voice dialogue skit (SplatMaster 3000, a couple arguing in a car), did not: **dialogue skits don't work in Suno**. Make them with text-to-speech or skip them.

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

The script and direction below are the draft it was made from, used without changes.

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

The script and direction below are the draft it was made from, used without changes.

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

## Big Earl's Tire Barn

A tire sale as a livestock auction.

The script and direction below are the draft it was made from, used without changes.

**Script**

```
(fast rolling cattle auctioneer chant, rhythmic and breathless, words tumbling together)
Hey who'll gimme four, four, four tires now five, now five, mud tires snow tires, who'll gimme four on the floor,
Big Earl's Tire Barn, Big Earl's Tire Barn, tires that been on fire only once, do I hear twice, twice,
buy three get the fourth one rollin round the lot somewhere, you find it you got it, goin once, goin twice,
(gavel bang, then slow, proud and loud) SOLD. To the man with the bald tires.
(slow, satisfied) Big Earl's Tire Barn.
```

**Direction**

| | |
|---|---|
| Format | A livestock auction where the tires are the cattle. Max length 30 seconds. |
| Voice | Big Earl as the auctioneer: male, 60s, Texan, a real cattle-auction chant, rhythmic filler syllables between the words. |
| Tone and pace | Machine-gun fast and musical, riding the beat, never pausing for breath until the gavel. Then dead slow and proud for "SOLD". |
| Music | Bluegrass breakdown: fast fiddle and banjo, upright bass, 160 BPM, stopping dead on the gavel. |
| Suno prompt | `male Texas cattle auctioneer rapid rhythmic chant vocal, bluegrass breakdown, fast fiddle and banjo, upright bass, 160 BPM, music stops on a gavel bang, ends with a slow spoken SOLD` |
| Sound effects | Crowd murmur under the chant; a tire bouncing on "rollin round the lot"; a gavel bang before "SOLD". |

**Processing:** 42 s; −15.7 → −16.1 LUFS, Vorbis q4. Longer than the 30 s asked for: the chant ran on.

## Gas N Go

A fully sung 1970s western-swing jingle for the gas stations at the end of each race.

The script and direction below are the draft it was made from, used without changes.

**Script**

```
[Verse]
When your needle's on E and the road is long
There's a light up ahead and it's singing this song
Gas and snacks and coffee hot
Brewed last Tuesday, still a lot

[Chorus]
Gas N Go, Gas N Go
At the end of the race and the end of the road
Big sign shining, goons out front
Gas N Go
```

**Direction**

| | |
|---|---|
| Format | A complete sung regional radio jingle, no speaking at all. Max length 30 seconds. |
| Voices | Female country singer, 30s, bright and twangy, with a small mixed choir answering on the chorus. |
| Tone and pace | Sunny, homey, a little old-fashioned; sung completely sincerely, so "goons out front" lands as a normal feature. |
| Music | 1970s western swing jingle: fiddle, pedal steel, walking upright bass, brushed drums, 120 BPM. |
| Suno prompt | `female country singer, bright twangy lead vocal, small mixed choir harmonies on the chorus, 1970s regional radio jingle, western swing, fiddle, pedal steel, upright bass, brushed drums, 120 BPM, short, ends on a big held harmony` |
| Sound effects | None needed; optionally a shop-door chime before the first line. |

**Processing:** 30 s; −15.7 → −16.1 LUFS, Vorbis q4. Right on length: sung jingles keep time better than talk.

## Fender Bender Mutual

An insurance ad as a whispered guided meditation.

The script and direction below are the draft it was made from, used without changes.

**Script**

```
(very soft, slow, whispered guided meditation, long pauses between lines)
Breathe in.
And breathe out.
Picture a wall. A rock. Deep water. That one cactus.
Now let it go.
Whatever you hit, Fender Bender Mutual is here for you.
Unless it was a goon. Or near a goon. Or a goon was looking at it.
Breathe in.
We cover nothing.
Breathe out.
```

**Direction**

| | |
|---|---|
| Format | A guided-meditation app ad. The joke is delivered as calmly as everything else; no fast disclaimer. Max length 30 seconds. |
| Voice | Female, 30s, soft breathy whisper, close to the mic, soothing and slow. |
| Tone and pace | Very slow with long pauses. "That one cactus" gets the faintest hint of a sigh. "We cover nothing" is the gentlest line in the ad. |
| Music | Ambient synth pads, a singing bowl, distant ocean waves, about 60 BPM, no drums. |
| Suno prompt | `soft breathy female whispered spoken word, guided meditation, ambient synth pads, singing bowl, gentle ocean waves, very slow 60 BPM, calm and spacious, no drums, no singing` |
| Sound effects | A singing-bowl ring at the start and on "We cover nothing"; the waves are enough otherwise. |

**Processing:** 62 s; −18.1 → −16.5 LUFS (the whisper is peaky, so the limiter stopped it 0.4 dB short), Vorbis q4. Twice the 30 s asked for: the long pauses in the direction were taken literally. Cut "long pauses" from the direction for a shorter take.

## The Lucky Lug Nut

A smoky lounge song for a "casino" that turns out to be a vending machine.

The script and direction below are the draft it was made from, used without changes.

**Script**

```
[Verse, sung slow and sultry]
Baby, feel that lucky feeling
Spinning reels and stars on the ceiling
Pull the lever, hear it ring
At the Lucky Lug Nut, hubcaps are king

[Chorus]
Lucky, Lucky Lug Nut
Win big
(beat) or at least win medium

(music stops, she speaks plainly, tired, breaking character) It's a vending machine behind the gas station, honey. Stop putting coins in it.
```

**Direction**

| | |
|---|---|
| Format | A smoky late-night lounge song that collapses when the singer drops the act. Max length 30 seconds. |
| Voice | Female, 40s, smoky sultry jazz singer, Rat Pack era; the spoken ending in her own tired, ordinary voice. |
| Tone and pace | Slow and seductive; "or at least win medium" sung with full glamour as if it were the big finish. The spoken line is flat and weary. |
| Music | Late-night jazz combo: brushed drums, upright bass, piano, muted trumpet, slow swing, 80 BPM. Stops dead before she speaks. |
| Suno prompt | `smoky sultry female jazz singer, late night lounge, slow swing, brushed drums, upright bass, piano, muted trumpet, 80 BPM, band stops and she speaks one tired line at the end` |
| Sound effects | A slot-reel whir on "Spinning reels"; a lever clunk and a little bell on "hear it ring"; one sad coin clink after "medium". |

**Processing:** 32 s; −16.8 → −16.0 LUFS, Vorbis q4.
