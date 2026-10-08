# Radio

The game's music is a car radio (roadmap R-1, package 8). Three stations of in-house tracks play in runs and in the menus; Radio Off is a fourth choice. The player picks a station in the pause menu (in a run) or in Settings → Audio (anywhere). There is no driving key: changing station is rare, and the pause menu is one press away.

This file has two halves: **for the audio author** (what to make, how to name and deliver it) and **for code** (how the `Radio` node plays it). Adding or replacing tracks never needs code: drop files in the right folder, let Godot import them, done.

---

## Part 1: Content (for the audio author)

### The stations

| Station | id (folder) | Feel | Has talk |
|---|---|---|---|
| **GoonCrusher Radio** | `gooncrusher` | Funny vocal tracks; a DJ between songs, call-ins, parody ads, goon traffic and weather. The game's personality. | Yes |
| **Classical Lofi** | `classical_lofi` | Classical themes (public domain melodies, your own arrangements) over lofi beats. Calm, easy to drive to for an hour. | No: idents only |
| **Lofi** | `lofi` | Plain lofi beats. The "I just want to drive" station. | No: idents only |

The default for a new save is **GoonCrusher Radio**. A station with no songs yet is hidden from the pickers, so Classical Lofi and Lofi appear once their first songs go in.

**Songs so far** (lyrics, style prompts and ideas for more: `docs/RADIO_SONGS.md`): GoonCrusher Radio has *Crush Hour*, *Gooncrusher*, *Full Tank, Empty Head* and *My Baby Loves My Truck*. No idents, talk or ads yet, so it plays songs back to back.

### Folder layout

Everything for a station lives in one folder under `sound/radio/`:

```
sound/radio/
  gooncrusher/
    station.json        name, colour, how often segments play (see below)
    logo.svg            original SVG, square, readable at 48 px (optional)
    songs/              full songs
    idents/             3–8 s station IDs ("You're on GoonCrusher Radio!")
    talk/               15–60 s DJ segments
    ads/                20–40 s parody commercials
  classical_lofi/
    station.json
    songs/
    idents/
  lofi/
    station.json
    songs/
    idents/
```

Empty or missing folders are fine; the station just skips that kind of segment. A station with no songs is hidden from the picker.

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

- Songs: **`Title - Artist.ogg`**, e.g. `Crush Hour - DJ Grille.ogg`. With no ` - `, the whole stem is the title and the artist is the station name.
- Everything else: anything readable, e.g. `ident_03.ogg`, `talk_traffic.ogg`. Those names are never shown.

### How much to make

Enough that a 30-minute session doesn't repeat. The playlist is shuffled without repeats until every song has played, and segments shuffle the same way.

| | Minimum to ship | Good |
|---|---|---|
| GoonCrusher Radio songs | 8 (~25 min) | 12–15 |
| GoonCrusher Radio idents | 4 | 8 |
| GoonCrusher Radio talk | 10 | 25 |
| GoonCrusher Radio ads | 4 | 8 |
| Each lofi station songs | 10 (~30 min) | 15–20 |
| Each lofi station idents | 2 | 4 |

### `station.json`

```json
{
	"name": "GoonCrusher Radio",
	"short": "GCR",
	"color": "#ff8a1f",
	"order": 0,
	"segment_chance": 0.6,
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
| `segment_chance` | Chance (0–1) that something plays between two songs | 0.6 talk stations, 0.3 music-only |
| `weights` | Relative odds of each segment kind when one plays (`ident`, `talk`, `ad`) | 1 each |
| `crossfade` | Seconds of song-to-song crossfade | 2.5 |

A segment always sits between two songs: never two segments in a row. Switching to a station plays an ident first when it has one.

### Writing brief: GoonCrusher Radio

**The voice.** One DJ (give them a name; working title "Dee Jay Crush") who is *delighted* that goons get run over and treats it like sports and traffic. Morning-zoo energy, but the joke is that this is a normal, local radio station in a world overrun by goons. Optional: a second voice for call-ins and ads.

**The radio isn't contextual.** Segments play at random between songs and don't know what's happening in the run, so write them to be true at any moment: no "you just crushed a giant", no "it's getting dark", nothing about the player's car, money or score, no promised rewards. Places and goons can be mentioned freely as world flavour.

**Things the world already has**, to make it feel like a real local station:

- Places: Prairie Run, Snapper Bayou, Red Canyon, Goon Quarry, Frostbite Pass, Route Nowhere, Rust City, The Crusher.
- The three goon factions: the **Wild Things** (critters: Jackalopes, Tuskers, Buzzards, Rattlers, Bullmoose, Thunderhoof), the **Goon Tribe** (Grunts, Goonlings, Hubcaps, the Foreman, Yetis, Rat Pack, Nightcrawlers), and the **Scrap Gang** (Spokes, Chainers, Sawbots, Shredders, Karters, Plowboss).
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

### Classical Lofi and Lofi

Music only. Idents are optional and gentle: a soft voice ("Classical Lofi") or a short chime, under 4 s. Classical Lofi should use melodies that are in the public domain (composers who died over 100 years ago, e.g. Bach, Mozart, Beethoven, Chopin, Satie, Debussy), in your own arrangement and recording; never sample someone else's recording.

### Adding a song

1. Make it in Suno from lyrics and a style prompt (`docs/RADIO_SONGS.md` has the house style and template).
2. Run `python scripts/audio/prep_radio_track.py "<Title>.mp3" sound/radio/<station>/songs` (needs ffmpeg). It normalises to −16 LUFS / −1 dBTP in two passes, trims silence at the end and writes 48 kHz Ogg named after the source (`Title.ogg`, or `Title - Artist.ogg`; `--name` renames). Use `--quality 3` for idents, talk and ads.
3. Drop it in the station's `songs/` folder and open the project in Godot so it imports (that writes the `.import` file to commit beside it).
4. Add its lyrics and style prompt to `docs/RADIO_SONGS.md`.

---

## Part 2: Code

### Where it lives

| Piece | File |
|---|---|
| Station data (scanning folders, `station.json`, picking segments) | `scripts/global/radio_station.gd` (class `RadioStation`) |
| Shuffle bag | `scripts/global/radio_bag.gd` (class `RadioBag`) |
| Playback, scheduling, crossfade, loading | `scripts/global/radio.gd` (class `Radio`), a child the `Audio` autoload makes: `Audio.radio` |
| Station picker | An `OptionRow` on `audio/station`: in the pause menu (`pauseMenu.gd` `radioRow()`, with the song under it) and in Settings → Audio |
| Now-playing card | `scene/ui/radio/now_playing.gd` (class `NowPlaying`): in the HUD above the tachometer, shown for 5 s at each song or station change; pinned under the icon bar in the main menu, where a click changes station (right click goes back) |
| Setting | `audio/station` in `Settings.DEFAULTS` (`"gooncrusher"`; `"off"` is Radio Off) |
| Ducking and pause muffle | `sound/new_audio_bus_layout.tres`, Music bus effects 0 (compressor) and 1 (low-pass) |
| Tests | `tests/game/test_radio.gd` |

There is no driving key for the radio: changing station is rare, so it lives in the pause menu.

### Playback

- Two `AudioStreamPlayer`s on the **Music** bus. A song crossfades into the next song over the station's `crossfade` (equal-power curve); a segment starts as the song ends and the next song as the segment ends, with a 0.1 s overlap.
- **Lazy loading:** only the next item is loaded, with `ResourceLoader.load_threaded_request`, as soon as the current one starts. If it isn't ready in time the radio waits for it; it never blocks the main thread. Headless runs (tests, playtests, benches) scan and schedule but never load or play audio.
- **Folders are scanned once** at startup with `ResourceLoader.list_directory`, which sees imported files in exported builds too (plain `DirAccess` would list `.import` files there). `station.json` is not a resource, so the export preset's include filter (`sound/radio/*.json`) ships it.
- **Switching station** fades out over 0.4 s, then plays the station's ident (if it has any) and a fresh song. Each station keeps its own bags, so coming back doesn't restart its playlist.
- **Pause:** the radio keeps playing under the pause menu (`process_mode = ALWAYS`); the Music bus's low-pass turns on while the pause menu is open (not under the slot machine, which also pauses the tree).
- **Ducking:** the Music bus has a compressor with its sidechain on the Voice bus, so the drivers' lines (the garage intros and the in-run warnings, `AudioStream-Voice` in `car.tscn`; and the VoiceDirector, T1-13, when it lands) pull the music down gently (threshold -22 dB, ratio 3) with no code.
- **Mix:** the radio plays at `MUSIC_DB` (-2 dB). Every sound effect is on the FX or UI bus (none on Master), so the Effects slider reaches the engine, tyres, crashes and results sounds too. The goon crush is two pool sounds at +1 to +9 dB over `Audio.POOL_VOLUME_DB` (0). There is no level-start bell and no win jingle: the radio plays straight through a run's start and its results. Talk segments are on the Music bus, so they duck too.
- **Menus and runs** share the radio: it is an autoload child, so it plays straight through scene changes.

### Signals and API

```gdscript
Audio.radio.setStation(&"lofi")         # saves audio/station; the radio follows Settings.changed
Audio.radio.cycleStation(1)             # next station, wrapping through Radio Off
Audio.radio.stationIds()                # stations with songs, in order, then &"off"
Audio.radio.stationOptions()            # [[id, name]] for an OptionRow
Audio.radio.nowPlaying()                # {station, stationName, color, kind, title, artist}
signal trackStarted(info: Dictionary)   # each new song (not segments)
signal stationChanged(id: StringName)
```

### Adding a station

Make a folder under `sound/radio/` with `station.json` and `songs/`, and let Godot import it. It appears in both pickers. Nothing else.

### Hooks for later

- **Unlocks (package 12):** `Radio.isStationOpen(id)` returns true for now; the unlock registry will answer it.
