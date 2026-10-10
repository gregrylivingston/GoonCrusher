# GoonCrusher Radio

**Pitch:** The soundtrack is a local radio station that covers goon-crushing like sports, traffic and weather.

## What it is
- One station plays through the menus and every run: songs, a DJ, ads and station idents, shuffled.
- The host is Dee Jay Crush: morning-zoo energy, loud, warm, never mean.
- Ads for businesses that would exist here: Goon-B-Gone, the law firm of Grunt, Grunt and Hubcap, Pete's Pit Shop.
- Skip a song or switch the radio off from the pause menu or the menu's now-playing card.
- It plays straight through: no jingles on top, and it ducks under voices.

## Numbers
- 14 songs (`sound/radio/gooncrusher/songs/`).
- 42 segments: 23 DJ talk, 10 ads, 9 idents (`talk/`, `ads/`, `idents/`).
- 0.1 had one music track (old `sound/music/`).

## Demo vs full game
- The whole station is in the demo.

## What to show
- Audio first: `capture.py song` lists the songs and `capture.py song <name>` copies one out as WAV. The studio owns them, so any can go under a trailer.
- `--music` keeps the radio in a clip's sound.
- The now-playing card and the radio on the visor: **need shots**.
- Song titles carry a post: "There's a Goon on My Hood", "Cheap Beer, Premium Gas", "She Left Me at the Truck Stop".

Details: docs/RADIO.md; lyrics and scripts in `sound/radio/gooncrusher/writing/`.
