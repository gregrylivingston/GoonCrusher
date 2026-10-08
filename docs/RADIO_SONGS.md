# GoonCrusher Radio: songs

The song book for GoonCrusher Radio: the house style, every song's lyrics and the prompt that made it, and ideas for the next ones. Songs are made in Suno from the lyrics and style below. Delivery rules (format, loudness, naming, folders) are in `docs/RADIO.md`, part 1.

## House style

Fast, loud, funny songs about driving and crushing goons, sung completely straight. The joke is the commitment: a real band with real chops singing about goon goo on the windshield.

- **Default sound:** 2000s punk rock, 160–180 BPM, distorted guitars, punchy live drums, shout-along gang vocals, a short guitar solo, polished video-game-soundtrack production. Every song should feel good at full throttle.
- **Vary within it:** not every song should be the same punk song. Good neighbours: pop-punk, skate punk, garage rock, surf rock, rockabilly, ska-punk, metal parody, trucker country, 80s arena rock. Keep the energy high; no ballads unless the joke is that it's a ballad.
- **Subject matter:** the car (full tank, dents, busted lights, bald tyres), the road and its goons, splatter and wipers, never braking, the world's places and goons (see the writing brief in `docs/RADIO.md`). First person, the driver as the hero.
- **Shape:** short verses, a chorus with a shoutable hook that names the song, a bridge that builds to a chant. 2:30–3:30.
- **Keep it clean:** cartoon violence only (crush, splat, goo), no swearing, no real brands, people or songs.
- **Suno tips:** ask for a clean ending (no fade; the game crossfades). Keep the style prompt to one paragraph of comma-separated tags, like Crush Hour's below. Generate a few takes and keep the one whose chorus hits hardest.

### Style prompt template

Start from this and change the genre words and one or two details per song:

```
Fast, chaotic 2000s-style punk rock, aggressive distorted electric guitars, punchy live drums, driving bass, over-the-top male vocals, catchy shout-along chorus, comedic rebellious attitude, energetic gang vocals, short explosive guitar solo, 170 BPM, polished video game soundtrack production, ridiculous and fun, no ballad elements
```

## Songs in the game

| Song | File | Length | Style |
|---|---|---|---|
| Crush Hour | `sound/radio/gooncrusher/songs/Crush Hour.ogg` | 2:57 | 2000s punk, 170 BPM |

### Crush Hour

**Style:**

```
Fast, chaotic 2000s-style punk rock, aggressive distorted electric guitars, punchy live drums, driving bass, over-the-top male vocals, catchy shout-along chorus, comedic rebellious attitude, energetic gang vocals, short explosive guitar solo, 170 BPM, polished video game soundtrack production, ridiculous and fun, no ballad elements.
```

**Lyrics:**

```
[Verse 1]
Got a full tank of gas and a dent in the hood
I'm out for a drive and I'm up to no good
Goon didn't crush it went over the top
I never hit the breaks and I never stop

[Chorus]
Wipers on, wipe that splatter away
We gonna crush goons on this glorious day
Pedal down Pedal down, feel the power
Lets take a drive its, crush hour
Goons in the road, Its a goon goo shower
Lets take a drive its, crush hour

[Verse 2]
Got a cracked windshield and a busted-up light
There's goons on the freeway and they're spoilin' my night
Left lane, right lane, don't matter to me
Theres goon on my windshield I can't even see

[Chorus]
Wipers on, wipe that splatter away
We gonna crush goons on this glorious day
Pedal down Pedal down, feel the power
Lets take a drive its, crush hour
Goons in the road, Its a goon goo shower
Lets take a drive its, crush hour

[Verse 3]
Radio's busted but I like it that way
Just the sound of the engine and the splats all day
Fuel light's blinking but I don't mind
I got four good tires and some goons to grind

[Bridge]
Horn goes beep, tires go screech
There's a goon in the way and he's well within reach
CRUSH! CRUSH! CRUSH! Put the hammer down!
CRUSH! CRUSH! CRUSH! Turn that engine loud!

[Chorus]
Wipers on, wipe that splatter away
We gonna crush goons on this glorious day
Pedal down Pedal down, feel the power
Lets take a drive its, crush hour
Goons in the road, Its a goon goo shower
Lets take a drive its, crush hour
```

**Processing:** the Suno mp3 measured −14.7 LUFS; it went in at −16.2 LUFS (true peak −2.9 dBTP), 48 kHz Vorbis q5, with the last half second of silence trimmed.

## Ideas for the next songs

Each needs lyrics, then a style prompt from the template above.

- **Goonling Lullaby (Don't Cross the Road):** the variation song. A slow country waltz with pedal steel, sung deadpan by a goon parent warning their kid about the road ("Your uncle tried it Tuesday / Now he's a puddle on the overpass"). It breaks the tempo on purpose, so play it rarely: one in the set, never two slow songs.
- **Route Nowhere:** surf rock with twangy reverb guitar; a road with no end and no brakes.
- **Hubcap Rodeo:** rockabilly; the Scrap Gang's wheels as rodeo bulls.
- **Pit Stop Romance:** ska-punk; falling for the Pit Shop mechanic between legs of a Marathon.
- **Night Shift:** 80s arena rock; headlights on, Nightcrawlers out.
- **Wild Things:** garage rock chant; the critters (Jackalopes, Tuskers, Buzzards) as a rival gang.
- **Foreman's Lament:** metal parody from the goons' side; the Foreman rallying the Tribe for one more charge.
