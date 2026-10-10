# Radio

The game's music is a car radio (roadmap R-1, package 8). One station of in-house tracks, GoonCrusher Radio, plays in runs and in the menus; Radio Off is the other choice (the author's call, 2026-10-10: no other stations). The player turns it on or off and skips a song in the pause menu (in a run) or on the menu's now-playing card (mouse); Settings → Audio has the on/off too. There is no driving key: both are rare, and the pause menu is one press away.

This file has two halves: **for the audio author** (what to make, how to name and deliver it) and **for code** (how the `Radio` node plays it). Adding or replacing tracks never needs code: drop files in the right folder, let Godot import them, done. The songs' lyrics and prompts are in `docs/RADIO_SONGS.md`, the ads, talk and idents in `docs/RADIO_SEGMENTS.md`.

---

## Part 1: Content (for the audio author)

### The station

**GoonCrusher Radio** (folder and id `gooncrusher`), the default on a new save: funny vocal tracks, with a DJ (Dee Jay Crush), parody ads and idents between songs. The game's personality.

The code reads any number of station folders, so a second station would need no code ("Adding a station" below), but none is planned: Classical Lofi and Lofi were tried and dropped.

What it has is listed in one place each: the songs in `docs/RADIO_SONGS.md` ("Songs in the game"), the ads, talk and idents in `docs/RADIO_SEGMENTS.md` ("In the game"). The counts are under "How much to make" below.

### Folder layout

Everything for a station lives in one folder under `sound/radio/`:

```
sound/radio/
  gooncrusher/
    station.json        name, colour, how often segments play (see below)
    logo.svg            original SVG, square, readable at 48 px (optional; there is none yet and nothing draws it)
    songs/              full songs
    idents/             3–8 s station IDs ("You're on GoonCrusher Radio!")
    talk/               15–60 s DJ segments
    ads/                20–40 s parody commercials
```

Empty or missing folders are fine; the station just skips that kind of segment.

### File format

| | Songs | Idents, talk, ads |
|---|---|---|
| Format | **Ogg Vorbis (.ogg)**; .mp3 also works | .ogg (or .mp3) |
| Sample rate | 44.1 or 48 kHz | same |
| Channels | stereo | mono is fine |
| Quality | Vorbis q5 (~160 kbps) | q3 (~110 kbps) |
| Loudness | **−16 LUFS integrated**, true peak ≤ −1 dBTP | **−16 LUFS**, true peak ≤ −1 dBTP |
| Head / tail | ≤ 0.2 s silence at the start; let the end ring out naturally (the game crossfades the last 2.5 s) | ≤ 0.1 s silence at both ends (segments butt-join) |
| Length | 1:30–4:00 | see the folder list above |

Matching loudness is the one rule that matters: the game does no per-track gain, so a hot master will jump out and a quiet one will vanish under the engine. Any loudness meter or `ffmpeg -af loudnorm=I=-16:TP=-1` gets you there.

Don't loop songs or bake fades into the ends; the game does the crossfades. Don't put a station ID inside a song; idents are separate so they can be shuffled.

### Naming

The now-playing card reads the file name, so name files for players:

- Songs: **`Title.ogg`**, e.g. `Crush Hour.ogg`, as every song in the game is named: the stem is the title and the station is the artist. `Title - Artist.ogg` names an artist.
- Everything else: anything readable, e.g. `ident_03.ogg`, `talk_traffic.ogg`. Those names are never shown.

### How much to make

Enough that a 30-minute session doesn't repeat. The playlist is shuffled without repeats until every song has played, and segments shuffle the same way. The shuffle carries over between launches, so short sessions don't keep hearing the same first songs.

| | Minimum to ship | Good | In the game (2026-10-10) |
|---|---|---|---|
| Songs | 8 (~25 min) | 12–15 | 14 (~44 min) |
| Idents | 4 | 8 | 9 |
| Talk | 10 | 25 | 23 |
| Ads | 4 | 8 | 10 |

### `station.json`

```json
{
	"name": "GoonCrusher Radio",
	"short": "GCR",
	"color": "#ff8a1f",
	"order": 0,
	"segment_counts": [1, 1, 1],
	"weights": {"ident": 3, "talk": 4, "ad": 2},
	"crossfade": 2.5
}
```

| Key | Meaning | Default |
|---|---|---|
| `name` | Shown in the picker and the now-playing card | folder name |
| `short` | 3–4 letters for tight spots | first letters of `name` |
| `color` | The card's accent | white |
| `order` | Position in the picker | 99 |
| `segment_counts` | Relative odds of **0, 1 or 2** segments between two songs. Two empty gaps never come in a row, so `[1, 1, 1]` gives an empty gap a quarter of the time and one or two segments 3/8 each | from `segment_chance` |
| `segment_chance` | The simpler form: chance (0–1) of one segment between two songs; ignored when `segment_counts` is set | 0.6 with talk or ads, 0.3 without |
| `weights` | Relative odds of each segment kind (`ident`, `talk`, `ad`) when a segment plays | 1 each |
| `crossfade` | Seconds of song-to-song crossfade | 2.5 |

After each song the radio rolls `segment_counts`: the next song straight away, one segment, or two segments **of different kinds** (an ad then the DJ, say; never two ads), each kind picked by `weights`. Then the next song. A gap is never empty twice in a row (unless nothing else can play), so three songs never play back to back. A kind with no files or a weight of 0 is never picked. Tuning in plays an ident first when the station has one. What these odds come to on the air is in `docs/RADIO_SEGMENTS.md` ("In the game").

### Writing brief: GoonCrusher Radio

**The voice.** One DJ (give them a name; working title "Dee Jay Crush") who is *delighted* that goons get run over and treats it like sports and traffic. Morning-zoo energy, but the joke is that this is a normal, local radio station in a world overrun by goons. Optional: a second voice for call-ins and ads.

**The radio isn't contextual.** Segments play at random between songs and don't know what's happening in the run, so write them to be true at any moment: no "you just crushed a giant", no "it's getting dark", nothing about the player's car, money or score, no promised rewards. Places and goons can be mentioned freely as world flavour.

**Things the world already has**, to make it feel like a real local station:

- Places: Prairie Run, Snapper Bayou, Red Canyon, Goon Quarry, Frostbite Pass, Route Nowhere, Rust City, The Crusher (eight of the 30 levels; the rest are in `docs/WORLD.md`).
- The three goon factions: the **Wild Things** (critters: Jackalopes, Tuskers, Buzzards, Rattlers, Bullmoose, Thunderhoof), the **Goon Tribe** (Grunts, Goonlings, Hubcaps, the Foreman, Yetis, Rat Pack, Nightcrawlers), and the **Scrap Gang** (Spokes, Chainers, Sawbots, Shredders, Karters, Plowboss). All 43 goons: `docs/GOONS.md`.
- Things players see: the station (gas stop) they race to, the slot machine, The Deal, the Pit Shop, nitro, oil slicks, supply drops, night falling every minute or so.

**Segment ideas** (a mix keeps it from feeling samey):

- *Goon traffic report:* "Rat Pack backed up three-deep outside Rust City. Expect delays. Or don't, if you brake for nobody."
- *Goon weather:* "Scattered Buzzards over Red Canyon, clearing to Jackalopes by afternoon."
- *Call-ins:* a goon calling in to complain; a gas-station attendant; a listener who loves the sound of hubcaps.
- *Sports desk:* crush counts read like box scores, the Foreman's season stats.
- *Lost and found:* "Someone lost a tusk on Prairie Run. It's yours if you can catch the Tusker."
- *Parody ads (`ads/`):* tyre shops, "Goon-B-Gone" spray, a law firm for injured goons, the Pit Shop's mechanic, a slot-machine parlour with a too-fast disclaimer.
- *Idents:* short and punchy, with a sting: "GoonCrusher Radio: we don't brake for goons."

**Tone limits:** cartoon violence only (squish, splat, flat), no real people, brands or songs, no slurs, nothing you wouldn't put in a general-audience game. Keep each talk segment to one joke or one bit; long monologues make players switch station.

### Adding a song

1. Make it in Suno from lyrics and a style prompt (`docs/RADIO_SONGS.md` has the house style and template).
2. Run `python scripts/audio/prep_radio_track.py "<Title>.mp3" sound/radio/gooncrusher/songs` (needs ffmpeg). It normalises to −16 LUFS / −1 dBTP in two passes, trims silence at the end and writes 48 kHz Ogg into that folder, named after the source (`--name` renames).
3. Open the project in Godot so it imports (that writes the `.import` file to commit beside it).
4. Add its lyrics and style prompt to `docs/RADIO_SONGS.md` and its row to the table there.

Idents, talk and ads go the same way into their own folders, with `--quality 3`, and are recorded in `docs/RADIO_SEGMENTS.md`.

---

## Part 2: Code

### Where it lives

| Piece | File |
|---|---|
| Station data (scanning folders, `station.json`, picking segments) | `scripts/global/radio_station.gd` (class `RadioStation`) |
| Shuffle bag | `scripts/global/radio_bag.gd` (class `RadioBag`) |
| Playback, scheduling, crossfade, loading | `scripts/global/radio.gd` (class `Radio`), a child the `Audio` autoload makes: `Audio.radio` |
| On/Off and Skip | An `OptionRow` on `audio/station` (GoonCrusher Radio or Radio Off): in the pause menu (`pauseMenu.gd` `radioRow()`, with a **Skip song** button beside it and the song under it) and in Settings → Audio |
| Now-playing card (menu) | `scene/ui/radio/now_playing.gd` (class `NowPlaying`): pinned beside the main menu's top-left buttons (`main2.gd` `radioBar`), where a click skips to the next song (or tunes in when off) and a right click turns the radio on or off. Mouse only (docs/UI.md) |
| In a run | The left sun visor (`scene/player/hud/hud_visor.gd`, `HudVisor`; docs/HUD.md): an equaliser while the radio plays, and the song for 5 s at each new song or station change |
| Setting | `audio/station` in `Settings.DEFAULTS` (`"gooncrusher"`; `"off"` is Radio Off) |
| Ducking and pause muffle | `sound/new_audio_bus_layout.tres`, Music bus effects 0 (compressor) and 1 (low-pass) |
| Shuffle memory | `user://radio.json` (per machine, not in the save): each bag's place in its cycle, saved at every song and on exit, restored at startup (`Radio.saveState`, `loadState`; `RadioBag.state`, `restore`). Songs added since are shuffled into the cycle; songs removed are dropped. Never written headless. |
| Tests | `tests/game/test_radio.gd`, on a private `Radio` over `tests/game/radio_fixture/` (three tiny stations), plus a check that every shipped file is imported |

### Playback

- Two `AudioStreamPlayer`s on the **Music** bus. A song crossfades into the next song over the station's `crossfade` (equal-power curve); a segment starts as the song ends and the next song as the segment ends, with a 0.1 s overlap.
- **Lazy loading:** only the next item is loaded, with `ResourceLoader.load_threaded_request`, as soon as the current one starts. If it isn't ready in time the radio waits for it; it never blocks the main thread. Headless runs (tests, playtests, benches) scan and schedule but never load or play audio.
- **Folders are scanned once** at startup with `ResourceLoader.list_directory`, which sees imported files in exported builds too (plain `DirAccess` would list `.import` files there). `station.json` is not a resource, so the export preset's include filter (`sound/radio/*.json`) ships it. A station with no songs is left out.
- **Skip** (`Radio.skip`) fades out what plays and starts the next song, dropping any segments queued before it.
- **Switching station** fades out over 0.4 s, then plays the station's ident (if it has any) and a fresh song. Each station keeps its own bags, so coming back doesn't restart its playlist.
- **Pause:** the radio keeps playing under the pause menu (`process_mode = ALWAYS`); the Music bus's low-pass turns on while the pause menu is open (not under the slot machine, which also pauses the tree).
- **Ducking:** the Music bus has a compressor with its sidechain on the Voice bus, so the drivers' lines (the garage intros and the in-run warnings, `AudioStream-Voice` in `car.tscn`; and the VoiceDirector, T1-13, when it lands) pull the music down gently (threshold -22 dB, ratio 3) with no code.
- **Mix:** the radio plays at `MUSIC_DB` (0 dB; the Music slider defaults to 1.0, above Effects at 0.8, so music sits over the effects). Every sound effect is on the FX or UI bus (none on Master), so the Effects slider reaches the engine, tyres, crashes and results sounds too. The goon crush is two pool sounds at -8 to -2 dB against `Audio.POOL_VOLUME_DB` (0), played only for crushes and blasts within `Walker.DEATH_SOUND_RANGE` (1,400 px) of the car: the pool isn't positional, so goons drowning or blowing themselves up elsewhere stay quiet. There is no level-start bell, no win jingle and no slot machine spin, lever or win sound (only each reel's soft clank): the radio plays straight through a run's start, its prize games and its results. Talk segments are on the Music bus, so they duck too.
- **Menus and runs** share the radio: it is an autoload child, so it plays straight through scene changes.

### Signals and API

```gdscript
Audio.radio.setStation(&"gooncrusher")         # saves audio/station; the radio follows Settings.changed
Audio.radio.skip()                      # straight to the next song, dropping queued segments
Audio.radio.toggle()                    # Radio Off and back
Audio.radio.cycleStation(1)             # next station, wrapping through Radio Off
Audio.radio.stationIds()                # stations with songs, in order, then &"off"
Audio.radio.stationOptions()            # [[id, name]] for an OptionRow
Audio.radio.nowPlaying()                # {station, stationName, color, kind, title, artist}
signal trackStarted(info: Dictionary)   # each new song (not segments)
signal stationChanged(id: StringName)
```

### Adding a station

Make a folder under `sound/radio/` with `station.json` and `songs/`, and let Godot import it. It appears in both pickers (pause menu and Settings), in `order`, before Radio Off. Nothing else.

### Hooks for later

- **Unlocks (package 12):** `Radio.isStationOpen(id)` returns true for now; the unlock registry will answer it.
