# Radio

The game's music is a car radio: one station of in-house tracks, GoonCrusher Radio, playing through runs and menus, or Radio Off. No other stations are planned (the author's call, 2026-10-10), though a second folder under `sound/radio/` with a `station.json` and songs would appear in the pickers without code. There is no driving key: on/off and Skip song are in the pause menu and on the menu's now-playing card, on/off also in Settings → Audio.

Adding or replacing audio never needs code: files in the station's folders are scanned at startup. What is in the game is what is in the folders. Lyrics and prompts: `sound/radio/gooncrusher/writing/songs.md`. Ad, talk and ident scripts: `sound/radio/gooncrusher/writing/segments.md`.

## Part 1: Content (for the audio author)

### Folders and naming

```
sound/radio/gooncrusher/
  station.json   name, color, segment odds, crossfade
  songs/         full songs, 1:30–4:00
  idents/        3–8 s station IDs
  talk/          15–60 s DJ segments
  ads/           20–40 s parody commercials
```

- Songs: **`Title.ogg`**; the file name is the title players see, and the station is the artist. `Title - Artist.ogg` names an artist.
- Segments: `ident_03.ogg`, `talk_traffic.ogg`, `ad_tires.ogg`. Never shown.
- An empty or missing segment folder is fine.

### File format

| | Songs | Idents, talk, ads |
|---|---|---|
| Format | Ogg Vorbis (.mp3 also works), 44.1 or 48 kHz, stereo | same; mono is fine |
| Quality | Vorbis q5 | q3 for plain voice, q4 with music |
| Loudness | **−16 LUFS integrated, true peak ≤ −1 dBTP** | same |
| Head / tail | ≤ 0.2 s silence at the start; let the end ring out | ≤ 0.1 s silence at both ends |

Matching loudness is the one rule that matters: the game applies no per-track gain. Don't loop songs, bake in fades or put a station ID inside a song: the game crossfades songs and shuffles idents itself.

### Adding a song or segment

1. Make it (songs and sung ads in Suno, the DJ in ElevenLabs; the two docs above have the house style, voice settings and lessons learned).
2. `python scripts/audio/prep_radio_track.py "<source>.mp3" sound/radio/gooncrusher/<folder>` (needs ffmpeg): normalises to the loudness above, trims tail silence, writes 48 kHz Ogg named after the source. `--name` renames, `--quality 3` or `4` for segments.
3. Open the project in Godot so it imports, and commit the `.import` file with the audio.
4. Add its lyrics or script and its prompt to `sound/radio/gooncrusher/writing/songs.md` or `sound/radio/gooncrusher/writing/segments.md`.

### Writing brief: GoonCrusher Radio

- **The voice:** one DJ, Dee Jay Crush, *delighted* that goons get run over and covering it like sports, traffic and weather. Morning-zoo energy; the joke is that this is a normal local station in a world overrun by goons.
- **Not contextual:** segments play at random between songs and know nothing about the run. Write them to be true at any moment: no "you just crushed a giant", no "it's getting dark", nothing about the player's car, money or score, no promised rewards.
- **World flavour:** use the game's own places, goons and things (`docs/WORLD.md`, `docs/GOONS.md`, `docs/PICKUPS.md`), not real ones.
- **Tone limits** (songs too): cartoon violence only (squish, splat, flat), no real people, brands or songs, no swearing or slurs, nothing unfit for a general-audience game. One joke or one bit per talk segment.

## Part 2: Code

| Piece | Where |
|---|---|
| Playback, scheduling, crossfade, lazy threaded loading, Skip | `scripts/global/radio.gd` (`Radio`), a child of the `Audio` autoload: `Audio.radio` |
| A station: folder scan, `station.json` keys and their defaults, segment picking | `scripts/global/radio_station.gd` (`RadioStation`) |
| Shuffle without repeats | `scripts/global/radio_bag.gd` (`RadioBag`); its place is kept across launches in `user://radio.json` (per machine, not in the save) |
| Setting | `audio/station`: a station folder's name or `"off"` |
| Pause menu row and Skip song | `pauseMenu.gd` `radioRow()` |
| Menu now-playing card (mouse: click skips, right click on/off) | `scene/ui/radio/now_playing.gd` (`NowPlaying`) |
| In-run display | the left sun visor, `hud_visor.gd` (docs/HUD.md) |
| Ducking and pause muffle | Music bus effects in `sound/new_audio_bus_layout.tres` |
| Tests | `tests/game/test_radio.gd`, over `tests/game/radio_fixture/` |

Rules:

- **Never add another music player.** Music is the radio, on the **Music** bus.
- **Ducking is the bus's job:** anything that should pull the music down plays on the **Voice** bus (the Music bus compressor is keyed from it). No code.
- **Spoken lines in a run go through `Audio.voice.say(kind, lines)`** (`scripts/global/voice_director.gd`, `VoiceDirector`): it ranks the kinds, spaces the lines, avoids repeats and sends the subtitle to the HUD (`HudChance.onSpoke`, setting `access/subtitles`). Never give a scene a voice player of its own. Tests: `tests/game/test_voice_director.gd`.
- **Segment odds are data:** `segment_counts` (odds of 0, 1 or 2 segments between songs) and `weights` (ident, talk, ad) in `station.json`.
- **`station.json` is not a resource:** the export preset's include filter (`sound/radio/*.json`) ships it.
- **Headless runs** (tests, playtests, benches) scan and schedule but never load or play audio, and never write `user://radio.json`.
- **Mix:** no jingles or stingers over the radio. It plays straight through a run's start, prize games, results and scene changes, so there is no level-start bell, win jingle or slot-machine tune, and any new cue should be short and not tonal. Every sound effect is on the FX or UI bus, none on Master. The goon crush sound plays only near the car (`Walker.DEATH_SOUND_RANGE`).
