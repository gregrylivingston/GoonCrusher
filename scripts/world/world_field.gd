class_name WorldField extends RefCounted
## The pure field functions behind the eight level grammars (docs/WORLD.md).
##
## sample(x, y) gives, for any world point, Vector3(water, wall, surface):
##   water, wall: signed fields in UNIT px, negative inside deep water or a wall and 0 on its edge
##                (BIG where there is none). They are distance-like, so 1.0 is about 640 px.
##   surface:     the Root.terrain id of the ground there, ignoring water and walls.
## The coarse build (WorldGen.buildCoarse) and the chunk rasters (WorldGen.fineRaster) sample these same
## functions, so chunk edges agree and the fine map never disagrees with the coarse one by more than the
## clamp WorldGen applies. Everything is a function of the seed, the level's def snapshot and the point:
## no global RNG, no nodes, no autoloads, so a WorldField can be built and used on a worker thread.
## One instance per job: it caches set-piece lookups in member variables.
##
## Thresholds in LevelDef.features are raw noise values: plain simplex noise spans about -1..1 (half of it
## within +-0.35), 3-octave fbm about -0.8..0.8 (half within +-0.2).

const UNIT := 640.0
const BIG := 4.0
const G_PLAIN := 2.9 #mean |gradient| / frequency of plain simplex noise near 0 (measured), so |n| / (G * f) is a distance in px
const G_FBM := 2.24  #the same for 3-octave fbm

enum Grammar { MEADOW, BAYOU, CANYON, QUARRY, MOUNTAIN, HIGHWAY, CITY, YARD }
const GRAMMARS := {&"meadow": Grammar.MEADOW, &"bayou": Grammar.BAYOU, &"canyon": Grammar.CANYON, &"quarry": Grammar.QUARRY,
	&"mountain": Grammar.MOUNTAIN, &"highway": Grammar.HIGHWAY, &"city": Grammar.CITY, &"yard": Grammar.YARD}

#terrain ids, mirroring Root.terrain (worker code never touches the autoload)
const GRASS := 0
const SAND := 1
const MUD := 2
const WATER := 3
const HILLS := 4
const MOSS := 5
const DIRT := 6
const SNOW := 7
const ASPHALT := 8
const ICE := 9
const OIL := 10
const SHALLOWS := 11
const WASH := 12
const CONVEYOR := 13
const MUDPIT := 14
const DEEPSNOW := 15
const LOT := 16
const BUILDING := 17
const BRIDGE := 18
const WADE := 19
## Surfaces the generic accent noise may sprinkle; the rest (ice, oil, belts, pits...) only come from grammar rules
const PLAIN_SURFACES := [GRASS, SAND, MUD, MOSS, DIRT, SNOW, WASH, DEEPSNOW, LOT]

const CELL := 1280.0
const MAP_HALF := Vector2(245760.0, 122880.0) #48 chunks each way
const EDGE_PX := 2560.0 #the map's outer two coarse cells are ocean
const START_CLEAR := 2500.0 #no barrier this close to the start, and the level's main ground

#hash tags (WorldGen.ihash) for this file's streams
const TAG_NOISE := 101
const TAG_PIECE := 102
const TAG_MUDPIT := 103
const TAG_BRANCH := 104
const TAG_GAS := 105
const TAG_COL := 106
const TAG_ROW := 107
const TAG_CANAL := 108
const TAG_BLOCK := 109
const TAG_SEG := 110
const TAG_PLOT := 111

var worldSeed := 0
var grammar: int = Grammar.MEADOW
var features := {}
var start := Vector2.ZERO
var base := PackedByteArray()
var accents := PackedByteArray()
var main := GRASS
## Deep water gets a band of SHALLOWS (meadow, bayou); elsewhere its bank is the surface
var shallows := true
## Deep water's outer band is wading depth (WADE, WorldGen.WADE_DEPTH) where it has shallows and the landscape
## doesn't opt out (Landscape.wade, passed as the def's "_wade": lava has none); elsewhere its edge is sheer
var wade := true
## The terrain walls are (BUILDING in the city, HILLS elsewhere)
var wallTerrain := HILLS
## What a coarse crossing cut through water becomes: a ford (SHALLOWS) or a bridge (BRIDGE)
var waterCrossing := SHALLOWS
## Half-widths (px, across the way through) the fine raster opens at a crossing
var fordHalf := 600.0
var bridgeHalf := 450.0
var passHalf := 700.0
## Hard barriers may cover at most this share of any 3x3-chunk window
var barrierCap := 0.2

var nBase: FastNoiseLite
var nAcc: FastNoiseLite
var nPick: FastNoiseLite
#grammar noises and their frequencies (what each is depends on the grammar; see the sample functions)
var n1: FastNoiseLite
var n2: FastNoiseLite
var n3: FastNoiseLite
var n4: FastNoiseLite
var n5: FastNoiseLite
var n6: FastNoiseLite
var f1 := 0.0
var f2 := 0.0
var f3 := 0.0
var f4 := 0.0
var f5 := 0.0
var f6 := 0.0
#grammar parameters
var halfA := 0.0 #creek / channel / wall / range / road half-width
var halfB := 0.0 #pool / track / wash / branch half-width
var halfC := 0.0
var threshA := 0.0
var threshB := 0.0
var threshC := 0.0
var spacingA := 0.0
var spacingB := 0.0
var spacingC := 0.0
var chance := PackedFloat32Array()
#G_PLAIN * f1.. (lineDistance's divisor), the same doubles lineDistance computes, made once
var g1 := 1.0
var g2 := 1.0
var g4 := 1.0
#lattice grammars: street / fence flags per global coarse column and row
var colFlag := PackedByteArray()
var rowFlag := PackedByteArray()
const LATTICE_OFFSET := 200 #index = coarse cell + LATTICE_OFFSET; the map spans -192..191 and -96..95

#cached set piece (quarry): the macro cell last looked up and what is there
var _pieceCell := Vector2i(1 << 30, 0)
var _pieceType := 0
var _pieceCentre := Vector2.ZERO
var _pieceRot := 0.0
const PIECE_NONE := 0
const PIECE_PIT := 1
const PIECE_FORT := 2
const PIECE_CAMP := 3

static func make(mapSeed: int, def: Dictionary) -> WorldField:
	var f := WorldField.new()
	f.setup(mapSeed, def)
	return f

func setup(mapSeed: int, def: Dictionary) -> void:
	worldSeed = mapSeed
	grammar = GRAMMARS.get(StringName(def.get("grammar", &"meadow")), Grammar.MEADOW)
	features = def.get("features", {})
	start = def.get("startPosition", Vector2.ZERO)
	for t in def.get("baseTerrain", []): base.push_back(int(t))
	if base.is_empty(): base.push_back(GRASS)
	for t in def.get("accents", []):
		if int(t) in PLAIN_SURFACES: accents.push_back(int(t))
	main = int(def.get("_main", base[0])) #WorldMap.jobFor works it out on the main thread (mainTerrain reads World)
	nBase = noise(1, 1.0 / 9000.0, 3)
	nAcc = noise(2, 1.0 / 2600.0)
	nPick = noise(3, 1.0 / 7000.0)
	barrierCap = float(features.get("barrierCap", 0.2))
	match grammar:
		Grammar.MEADOW:
			f1 = feat("creekFrequency", 6e-5); n1 = noise(10, f1)
			f2 = f1 / 3.0; n2 = noise(11, f2) #where creeks run at all
			f3 = 1.0 / 3500.0; n3 = noise(12, f3) #pools
			f4 = 5e-5; n4 = noise(13, f4) #dirt tracks
			halfA = feat("creekWidth", 640.0) / 2.0
			halfB = feat("trackWidth", 420.0) / 2.0
			halfC = feat("poolWidth", 520.0)
			threshA = feat("poolThreshold", 0.45)
			fordHalf = feat("fordWidth", 1200.0) / 2.0
			waterCrossing = SHALLOWS
		Grammar.BAYOU:
			f1 = feat("lakeFrequency", 1.0 / 12000.0); n1 = noise(20, f1, 3)
			f2 = feat("channelFrequency", 1.1e-4); n2 = noise(21, f2)
			f3 = f2 / 3.0; n3 = noise(22, f3); n4 = noise(23, f3) #the two strands' masks
			threshA = feat("lakeThreshold", 0.3)
			halfA = feat("channelWidth", 560.0) / 2.0
			threshB = feat("channelGap", 0.2)
			bridgeHalf = feat("bridgeWidth", 900.0) / 2.0
			waterCrossing = BRIDGE
		Grammar.CANYON:
			f1 = feat("ridgeFrequency", 7e-5); n1 = noise(30, f1)
			f2 = f1 / 2.8; n2 = noise(31, f2) #where walls run
			f3 = feat("mesaFrequency", 1.0 / 9000.0); n3 = noise(32, f3, 3)
			f4 = feat("washFrequency", 4e-5); n4 = noise(33, f4)
			f5 = 1.0 / 3000.0; n5 = noise(34, f5) #dunes
			halfA = feat("wallWidth", 900.0) / 2.0
			threshA = feat("mesaAbove", 0.38)
			halfB = feat("washWidth", 700.0) / 2.0
			threshB = feat("duneAbove", 0.35)
			passHalf = feat("passWidth", 1400.0) / 2.0
			barrierCap = float(features.get("barrierCap", 0.35))
		Grammar.QUARRY:
			f1 = feat("haulFrequency", 4.5e-5); n1 = noise(40, f1)
			halfA = feat("haulRoadWidth", 900.0) / 2.0
			spacingA = feat("pieceCells", 10.0) * CELL #one set piece slot per this many px
			threshA = feat("pitRadius", 3200.0)
			threshB = feat("fortRadius", 2200.0)
			threshC = feat("campRadius", 1500.0)
			halfB = feat("rampWidth", 1000.0) / 2.0
			chance = PackedFloat32Array([feat("pitChance", 0.3), feat("fortChance", 0.25), feat("tyreCamps", 0.25)])
			spacingB = 2560.0 #mud pit lattice
			halfC = feat("mudPitRadius", 200.0)
			passHalf = feat("passWidth", 1300.0) / 2.0
		Grammar.MOUNTAIN:
			f1 = feat("ridgeFrequency", 6e-5); n1 = noise(50, f1)
			f2 = f1 / 3.0; n2 = noise(51, f2) #where ranges run
			f3 = feat("peakFrequency", 1.0 / 8000.0); n3 = noise(52, f3, 3)
			f4 = feat("iceFrequency", 1.0 / 7000.0); n4 = noise(53, f4, 3)
			f5 = 1.0 / 3000.0; n5 = noise(54, f5) #deep snow
			halfA = feat("rangeWidth", 1800.0) / 2.0
			threshA = feat("peakAbove", 0.42)
			threshB = feat("iceLakeThreshold", 0.3)
			threshC = feat("deepSnowAbove", 0.3)
			passHalf = feat("passWidth", 1500.0) / 2.0
		Grammar.HIGHWAY:
			f1 = feat("warpFrequency", 4e-5); n1 = noise(60, f1) #highway warp (sampled along x, one row per highway)
			n2 = noise(61, f1) #branch warp
			f3 = 1.0 / 1800.0; n3 = noise(62, f3) #oil
			f4 = 1.0 / 7000.0; n4 = noise(63, f4, 3) #rock outcrops
			halfA = feat("roadWidth", 1600.0) / 2.0
			halfB = feat("branchWidth", 1000.0) / 2.0
			halfC = feat("warpAmplitude", 3000.0)
			spacingA = feat("highwaySpacing", 23040.0)
			spacingB = feat("branchEvery", 3.0) * 5120.0
			spacingC = feat("gasStationEvery", 6.0) * 5120.0
			threshA = feat("oilAbove", 0.6)
			threshB = feat("rockAbove", 0.4)
			threshC = feat("branchChance", 0.7)
		Grammar.CITY:
			wallTerrain = BUILDING
			waterCrossing = BRIDGE
			bridgeHalf = 640.0 #the full street
			chance = PackedFloat32Array([feat("buildingShare", 0.45), feat("parkShare", 0.2), feat("lotShare", 0.25), feat("canalShare", 0.1)])
			halfA = feat("canalWidth", 1040.0) / 2.0
			halfB = feat("sidewalk", 110.0)
			if def.has("_lattice"): useLattice(def["_lattice"])
			else: buildLattice(TAG_COL, TAG_ROW)
			barrierCap = float(features.get("barrierCap", 0.35))
		Grammar.YARD:
			f1 = 1.0 / 900.0; n1 = noise(70, f1) #scrap pile lumps
			f2 = 1.0 / 2200.0; n2 = noise(71, f2) #oil
			spacingA = feat("plotSize", 3.0) + 1.0 #cells per plot including its fence line
			chance = PackedFloat32Array([feat("scrapMountainShare", 0.25) + 0.35, feat("containerRows", 0.3) * 0.5, feat("tankFarmChance", 0.15), feat("gapChance", 0.6)])
			spacingB = feat("conveyorEvery", 4.0)
			threshA = feat("oilAbove", 0.55)
			halfA = feat("scrapWidth", 860.0) / 2.0
			halfB = feat("containerWidth", 600.0) / 2.0
			halfC = feat("conveyorWidth", 640.0) / 2.0
			passHalf = 640.0
			barrierCap = float(features.get("barrierCap", 0.35))

	shallows = hasShallows(grammar)
	wade = shallows && bool(def.get("_wade", true))
	g1 = G_PLAIN * f1
	g2 = G_PLAIN * f2
	g4 = G_PLAIN * f4

## Does deep water get a shallows band (every grammar but the city's sheer canals)
static func hasShallows(g: int) -> bool:
	return g != Grammar.CITY

## Does a level's deep water get a wading band (WADE): its grammar has shallows and its landscape doesn't opt
## out (Landscape.wade). The raster (WorldGen.fineRaster, via the def's "_wade") and the ground shader (WorldSkin) ask this.
static func hasWade(grammarName: StringName, landscapeWade: bool) -> bool:
	return landscapeWade && hasShallows(GRAMMARS.get(grammarName, Grammar.MEADOW))

func feat(key: String, fallback: float) -> float:
	return float(features.get(key, fallback))

## A noise layer seeded from the world seed and `slot`
func noise(slot: int, freq: float, octaves: int = 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = WorldGen.ihash(worldSeed, TAG_NOISE, slot, 0)
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = maxi(octaves, 1)
	return n

## The level's main ground: the commonest base terrain, the faster one on a tie
static func mainTerrain(bands: PackedByteArray) -> int:
	var counts := {}
	for t in bands: counts[t] = counts.get(t, 0) + 1
	var best := int(bands[0])
	for t in bands:
		if counts[t] > counts[best] || (counts[t] == counts[best] && World.TERRAIN[t].friction < World.TERRAIN[best].friction): best = t
	return best

#--- sampling ------------------------------------------------------------------------------------

## Vector3(water, wall, surface) at a world point; see the class comment
func sample(x: float, y: float) -> Vector3:
	var v: Vector3
	match grammar:
		Grammar.MEADOW: v = meadow(x, y)
		Grammar.BAYOU: v = bayou(x, y)
		Grammar.CANYON: v = canyon(x, y)
		Grammar.QUARRY: v = quarry(x, y)
		Grammar.MOUNTAIN: v = mountain(x, y)
		Grammar.HIGHWAY: v = highway(x, y)
		Grammar.CITY: v = city(x, y)
		_: v = yard(x, y)
	#the ocean round the map
	var edge := minf(MAP_HALF.x - absf(x), MAP_HALF.y - absf(y))
	if edge < EDGE_PX + BIG * UNIT: v.x = minf(v.x, (edge - EDGE_PX) / UNIT)
	#the start bubble: no barrier, and the level's main ground (roads and streets stay, without oil)
	var dx := x - start.x
	var dy := y - start.y
	var d2 := dx * dx + dy * dy
	if d2 < START_CLEAR * START_CLEAR:
		v.x = maxf(v.x, 1.0)
		v.y = maxf(v.y, 1.0)
		if v.z == OIL: v.z = ASPHALT #a slick road stays road (it used to become the main ground: a sand hole in the highway)
		elif v.z != ASPHALT: v.z = main
	return v

## The plain ground: baseTerrain by a broad noise band, with accent patches
func surfaceBase(x: float, y: float) -> int:
	#an accent patch replaces the band, so the band's (3-octave) noise is only read outside one
	if not accents.is_empty() && nAcc.get_noise_2d(x, y) > 0.5:
		var pick := clampf(0.5 + nPick.get_noise_2d(x, y) * 0.9, 0.0, 0.9999)
		return accents[int(pick * accents.size())]
	var b := clampf(0.5 + nBase.get_noise_2d(x, y) * 1.15, 0.0, 0.9999)
	return base[int(b * base.size())]

## px from the zero line of a plain noise layer of frequency f
static func lineDistance(n: FastNoiseLite, f: float, x: float, y: float, shift := 0.0) -> float:
	return absf(n.get_noise_2d(x, y) - shift) / (G_PLAIN * f)

#Prairie: creeks along the zero lines of n1 (where the n2 mask lets them run), widening into pools where
#n3 is high; dirt tracks along n4's zero lines. Creeks are deep water with a shallows band; the coarse map
#cuts fords through them.
func meadow(x: float, y: float) -> Vector3:
	var s := DIRT if absf(n4.get_noise_2d(x, y)) / g4 < halfB else surfaceBase(x, y)
	var fw := BIG
	var strength := smoothstep(-0.45, -0.15, n2.get_noise_2d(x, y))
	if strength > 0.05:
		var hw := halfA * strength + halfC * smoothstep(threshA, threshA + 0.15, n3.get_noise_2d(x, y)) * strength
		fw = (absf(n1.get_noise_2d(x, y)) / g1 - hw) / UNIT
	return Vector3(fw, BIG, s)

#Snapper Bayou: lakes where the fbm n1 rises above threshA, plus two braided channels either side of n2's
#zero line (each strand masked by its own noise). The coarse map bridges them.
func bayou(x: float, y: float) -> Vector3:
	var s := surfaceBase(x, y)
	var fw := (threshA - n1.get_noise_2d(x, y)) / (G_FBM * f1) / UNIT
	var c := n2.get_noise_2d(x, y)
	var a := smoothstep(-0.5, -0.2, n3.get_noise_2d(x, y))
	if a > 0.05: fw = minf(fw, (absf(c - threshB) / g2 - halfA * a) / UNIT)
	var b := smoothstep(-0.2, 0.1, n4.get_noise_2d(x, y))
	if b > 0.05: fw = minf(fw, (absf(c + threshB) / g2 - halfA * b) / UNIT)
	return Vector3(fw, BIG, s)

#Red Canyon: canyon walls along the ridged zero lines of n1 (masked by n2), mesas where the fbm n3 rises
#above threshA, wash lanes along n4's zero lines, dunes where n5 is high. The coarse map cuts passes.
func canyon(x: float, y: float) -> Vector3:
	var s := WASH
	if absf(n4.get_noise_2d(x, y)) / g4 >= halfB: s = SAND if n5.get_noise_2d(x, y) > threshB else surfaceBase(x, y)
	var fh := (threshA - n3.get_noise_2d(x, y)) / (G_FBM * f3) / UNIT
	var strength := smoothstep(-0.55, -0.25, n2.get_noise_2d(x, y))
	if strength > 0.05: fh = minf(fh, (absf(n1.get_noise_2d(x, y)) / g1 - halfA * strength) / UNIT)
	return Vector3(BIG, fh, s)

#Frostbite Pass: mountain ranges along n1's zero lines (masked by n2) and massifs where the fbm n3 peaks;
#frozen lakes (ICE) where the fbm n4 is high and deep-snow drifts where n5 is. The coarse map cuts passes.
func mountain(x: float, y: float) -> Vector3:
	var s := ICE
	if n4.get_noise_2d(x, y) <= threshB: s = DEEPSNOW if n5.get_noise_2d(x, y) > threshC else surfaceBase(x, y)
	var fh := (threshA - n3.get_noise_2d(x, y)) / (G_FBM * f3) / UNIT
	var strength := smoothstep(-0.6, -0.3, n2.get_noise_2d(x, y))
	if strength > 0.05: fh = minf(fh, (absf(n1.get_noise_2d(x, y)) / g1 - halfA * strength) / UNIT)
	return Vector3(BIG, fh, s)

#Goon Quarry: noise ground and haul roads (n1's zero lines), with one set piece slot per spacingA-px macro
#cell: a terraced pit (a ring wall with ramps), a junk fort (a ring wall with gates) or a tyre camp (open,
#reserved for props). Small mud pits sit on a 2560 px lattice.
func quarry(x: float, y: float) -> Vector3:
	var s := -1 #the plain ground (a haul road's dirt or the base), worked out last unless something covers it
	var haul := absf(n1.get_noise_2d(x, y)) / g1 < halfA
	var fh := BIG
	lookupPiece(floori(x / spacingA), floori(y / spacingA))
	if _pieceType != PIECE_NONE:
		var dx := x - _pieceCentre.x
		var dy := y - _pieceCentre.y
		var r := sqrt(dx * dx + dy * dy)
		match _pieceType:
			PIECE_PIT:
				if r < threshA - 350.0: s = MUD if r < threshA * 0.45 else DIRT
				fh = ringWall(r, dx, dy, threshA, 350.0, int(feat("pitRamps", 2)))
			PIECE_FORT:
				if r < threshB - 250.0: s = LOT
				fh = ringWall(r, dx, dy, threshB, 250.0, int(feat("fortGates", 3)))
			PIECE_CAMP:
				if r < threshC: s = DIRT
	#mud pits: at most one per lattice cell, small (always avoidable), never on a haul road or a set piece
	if fh >= BIG:
		var pit := mudPit(floori(x / spacingB), floori(y / spacingB))
		if pit != Vector2.INF && (x - pit.x) * (x - pit.x) + (y - pit.y) * (y - pit.y) < halfC * halfC: s = MUDPIT
	if s < 0: s = DIRT if haul else surfaceBase(x, y)
	return Vector3(BIG, fh, s)

var _mudPits := {} #lattice cell -> its mud pit's centre, or INF for none

## The mud pit of a lattice cell (at most one, never on a haul road), cached
func mudPit(gx: int, gy: int) -> Vector2:
	var key := Vector2i(gx, gy)
	var known = _mudPits.get(key)
	if known != null: return known
	var pit := Vector2.INF
	if WorldGen.hashf(worldSeed, TAG_MUDPIT, gx, gy) < 0.14:
		var cx := (gx + 0.2 + 0.6 * WorldGen.hashf(worldSeed, TAG_MUDPIT + 1000, gx, gy)) * spacingB
		var cy := (gy + 0.2 + 0.6 * WorldGen.hashf(worldSeed, TAG_MUDPIT + 2000, gx, gy)) * spacingB
		if absf(n1.get_noise_2d(cx, cy)) / g1 > halfA + 300.0: pit = Vector2(cx, cy)
	_mudPits[key] = pit
	return pit

## A ring wall of radius r0 and half-thickness t with `gates` gaps (rampWidth wide) at the piece's rotation
func ringWall(r: float, dx: float, dy: float, r0: float, t: float, gates: int) -> float:
	var fh := (absf(r - r0) - t) / UNIT
	if fh >= BIG || gates <= 0: return minf(fh, BIG)
	var a := atan2(dy, dx)
	for k in gates:
		var da := absf(wrapf(a - _pieceRot - k * TAU / gates, -PI, PI))
		if da * r0 < halfB: return BIG
	return fh

## The set piece of quarry macro cell (mx, my), cached in _piece*: its type, centre and rotation
func lookupPiece(mx: int, my: int) -> void:
	var cell := Vector2i(mx, my)
	if cell == _pieceCell: return
	_pieceCell = cell
	_pieceType = PIECE_NONE
	var u := WorldGen.hashf(worldSeed, TAG_PIECE, mx, my)
	var type := PIECE_NONE
	if u < chance[0]: type = PIECE_PIT
	elif u < chance[0] + chance[1]: type = PIECE_FORT
	elif u < chance[0] + chance[1] + chance[2]: type = PIECE_CAMP
	if type == PIECE_NONE: return
	var radius: float = [0.0, threshA, threshB, threshC][type]
	var room := maxf(spacingA * 0.5 - radius - 900.0, 0.0)
	var centre := Vector2((mx + 0.5) * spacingA, (my + 0.5) * spacingA)
	centre += Vector2(WorldGen.hashf(worldSeed, TAG_PIECE + 1000, mx, my) * 2.0 - 1.0, WorldGen.hashf(worldSeed, TAG_PIECE + 2000, mx, my) * 2.0 - 1.0) * room
	if centre.distance_to(start) < radius + START_CLEAR + 1500.0: return #never on the start
	_pieceType = type
	_pieceCentre = centre
	_pieceRot = WorldGen.hashf(worldSeed, TAG_PIECE + 3000, mx, my) * TAU

## Every quarry set piece whose reservation touches the rect: Array of [type, centre, radius, rotation, gates]
func piecesIn(rect: Rect2) -> Array:
	var out := []
	if grammar != Grammar.QUARRY: return out
	for my in range(floori(rect.position.y / spacingA) - 1, floori(rect.end.y / spacingA) + 2):
		for mx in range(floori(rect.position.x / spacingA) - 1, floori(rect.end.x / spacingA) + 2):
			lookupPiece(mx, my)
			if _pieceType != PIECE_NONE:
				var gates: int = [0, int(feat("pitRamps", 2)), int(feat("fortGates", 3)), 0][_pieceType]
				out.push_back([_pieceType, _pieceCentre, [0.0, threshA, threshB, threshC][_pieceType], _pieceRot, gates])
	return out

#Route Nowhere: highways run along +x every spacingA px of y, each warped by n1 and passing its row's
#y at the start's x (so highway 0 runs through the start); branch roads run along y every spacingB px of
#x; oil on the asphalt; rock outcrops (the only walls) keep 1600 px off the roads; gas station lots sit
#beside the highways every spacingC px.
func highway(x: float, y: float) -> Vector3:
	var s := -1 #the base ground, worked out last unless a road or lot covers it
	#the nearest highway row, and its neighbour only when the point is near the halfway line (the warp is
	#under halfC px)
	var rowF := (y - start.y) / spacingA
	var k0 := roundi(rowF)
	var road := absf(y - highwayY(x, k0)) - halfA
	var nearestK := k0
	if absf(rowF - k0) * spacingA > spacingA * 0.5 - 2.0 * halfC:
		var k1 := k0 + (1 if rowF > k0 else -1)
		var d := absf(y - highwayY(x, k1)) - halfA
		if d < road:
			road = d
			nearestK = k1
	var colF := (x - start.x) / spacingB - 0.5
	var j0 := roundi(colF)
	if hasBranch(j0): road = minf(road, absf(x - branchX(y, j0)) - halfB)
	if absf(colF - j0) * spacingB > spacingB * 0.5 - halfC:
		var j1 := j0 + (1 if colF > j0 else -1)
		if hasBranch(j1): road = minf(road, absf(x - branchX(y, j1)) - halfB)
	if road < 0.0: s = OIL if n3.get_noise_2d(x, y) > threshA else ASPHALT
	elif road < 260.0: s = DIRT
	elif road < halfA + 2200.0:
		var gas := gasStation(roundi((x - start.x) / spacingC - 0.5), nearestK)
		if (x - gas.x) * (x - gas.x) + (y - gas.y) * (y - gas.y) < 900.0 * 900.0: s = LOT
	var fh := BIG
	if road > 1600.0: fh = minf(maxf((threshB - n4.get_noise_2d(x, y)) / (G_FBM * f4) / UNIT, (1600.0 - road) / UNIT), BIG)
	if s < 0: s = surfaceBase(x, y)
	return Vector3(BIG, fh, s)

var _highwayBase := {} #highway k -> its warp at the start's x (so it passes the start's row there)
var _branches := {}    #branch j -> whether it exists

func highwayY(x: float, k: int) -> float:
	var at: float = _highwayBase.get(k, INF)
	if at == INF:
		at = n1.get_noise_2d(start.x, k * 7919.0)
		_highwayBase[k] = at
	return start.y + k * spacingA + halfC * (n1.get_noise_2d(x, k * 7919.0) - at)

func hasBranch(j: int) -> bool:
	var known = _branches.get(j)
	if known == null:
		known = WorldGen.hashf(worldSeed, TAG_BRANCH, j, 0) < threshC
		_branches[j] = known
	return known

func branchX(y: float, j: int) -> float:
	return start.x + (j + 0.5) * spacingB + halfC * 0.5 * n2.get_noise_2d(j * 7919.0, y)

## The centre of gas station lot i beside highway k
func gasStation(i: int, k: int) -> Vector2:
	var gx := start.x + (i + 0.5) * spacingC
	var side := 1.0 if WorldGen.hashf(worldSeed, TAG_GAS, i, k) < 0.5 else -1.0
	return Vector2(gx, highwayY(gx, k) + side * (halfA + 1100.0))

#--- lattices (city, yard) -----------------------------------------------------------------------

## Rust City: street columns and rows on the coarse grid, 2 or 3 cells apart (a hashed pattern per group
## of 5); the rest are blocks typed BUILDING, park or LOT. Some street rows are canals, bridged at every
## street column.
func buildLattice(colTag: int, rowTag: int) -> void:
	colFlag.resize(2 * LATTICE_OFFSET)
	rowFlag.resize(2 * LATTICE_OFFSET)
	for i in 2 * LATTICE_OFFSET:
		var c := i - LATTICE_OFFSET
		colFlag[i] = 1 if latticeLine(c, colTag) else 0
		var row := latticeLine(c, rowTag)
		rowFlag[i] = 0
		if row:
			var centreY := (c + 0.5) * CELL
			var canal := WorldGen.hashf(worldSeed, TAG_CANAL, c, 0) < chance[3] && absf(centreY - start.y) > 6000.0
			rowFlag[i] = 2 if canal else 1
	buildNearest()

func latticeLine(c: int, tag: int) -> bool:
	var off := posmod(c, 5)
	var pattern := WorldGen.ihash(worldSeed, tag, floori(c / 5.0), 0) & 1
	return off == 0 || off == (2 if pattern == 0 else 3)

## The lattice as the coarse build made it (WorldGen.run puts it in the def snapshot), so the chunk rasters
## don't hash it again: [colFlag, rowFlag, leftStreet, rightStreet, rowAbove, rowBelow]
func useLattice(l: Array) -> void:
	colFlag = l[0]
	rowFlag = l[1]
	leftStreet = l[2]
	rightStreet = l[3]
	rowAbove = l[4]
	rowBelow = l[5]

func lattice() -> Array:
	return [colFlag, rowFlag, leftStreet, rightStreet, rowAbove, rowBelow]

#per lattice index: the nearest street column left and right of a column, the nearest street or canal row
#above and below a row (city() used to walk these one cell at a time)
var leftStreet := PackedInt32Array()
var rightStreet := PackedInt32Array()
var rowAbove := PackedInt32Array()
var rowBelow := PackedInt32Array()

func buildNearest() -> void:
	var n := 2 * LATTICE_OFFSET
	leftStreet.resize(n)
	rightStreet.resize(n)
	rowAbove.resize(n)
	rowBelow.resize(n)
	var col := -1 - LATTICE_OFFSET #outside the lattice counts as a street
	var row := -1 - LATTICE_OFFSET
	for i in n:
		leftStreet[i] = col
		rowAbove[i] = row
		if colFlag[i] != 0: col = i - LATTICE_OFFSET
		if rowFlag[i] != 0: row = i - LATTICE_OFFSET
	col = n - LATTICE_OFFSET
	row = n - LATTICE_OFFSET
	for i in range(n - 1, -1, -1):
		rightStreet[i] = col
		rowBelow[i] = row
		if colFlag[i] != 0: col = i - LATTICE_OFFSET
		if rowFlag[i] != 0: row = i - LATTICE_OFFSET

func isStreetCol(cx: int) -> bool:
	var i := cx + LATTICE_OFFSET
	return i < 0 || i >= colFlag.size() || colFlag[i] != 0

## 0 a block row, 1 a street row, 2 a canal row
func streetRow(cy: int) -> int:
	var i := cy + LATTICE_OFFSET
	if i < 0 || i >= rowFlag.size(): return 1
	return rowFlag[i]

const BLOCK_BUILDING := 0
const BLOCK_PARK := 1
const BLOCK_LOT := 2
func blockType(bx: int, by: int) -> int:
	var total := chance[0] + chance[1] + chance[2]
	var u := WorldGen.hashf(worldSeed, TAG_BLOCK, bx, by) * total
	if u < chance[0]: return BLOCK_BUILDING
	if u < chance[0] + chance[1]: return BLOCK_PARK
	return BLOCK_LOT

func city(x: float, y: float) -> Vector3:
	var cx := floori(x / CELL)
	var cy := floori(y / CELL)
	var col := isStreetCol(cx)
	var row := streetRow(cy)
	if row == 2:
		var fw := (absf(y - (cy + 0.5) * CELL) - halfA) / UNIT
		return Vector3(fw, BIG, ASPHALT if col else LOT)
	if col || row == 1: return Vector3(BIG, BIG, ASPHALT)
	var ix := cx + LATTICE_OFFSET
	var iy := cy + LATTICE_OFFSET
	var lx := 0
	var rx := 0
	var ty := 0
	var by := 0
	if ix >= 0 && ix < leftStreet.size() && iy >= 0 && iy < rowAbove.size():
		lx = leftStreet[ix]
		rx = rightStreet[ix]
		ty = rowAbove[iy]
		by = rowBelow[iy]
	else:
		lx = cx - 1
		while not isStreetCol(lx): lx -= 1
		rx = cx + 1
		while not isStreetCol(rx): rx += 1
		ty = cy - 1
		while streetRow(ty) == 0: ty -= 1
		by = cy + 1
		while streetRow(by) == 0: by += 1
	var edge := minf(minf(x - (lx + 1) * CELL, rx * CELL - x), minf(y - (ty + 1) * CELL, by * CELL - y))
	match blockType(lx, ty):
		BLOCK_BUILDING: return Vector3(BIG, (halfB - edge) / UNIT, LOT)
		BLOCK_PARK: return Vector3(BIG, BIG, MOSS if nAcc.get_noise_2d(x, y) > 0.55 else GRASS)
	return Vector3(BIG, BIG, LOT)

## The Crusher: plots of spacingA coarse cells, the last row and column of each being its fence line. Each
## fence segment (between corners) is a scrap mountain, a container row or open, and a walled one usually
## has a gap; corners are always open. Some plots are tank farms (LOT, reserved for props); every
## spacingB-th plot row has a conveyor belt along its middle; oil spills here and there.
const SEG_OPEN := 0
const SEG_SCRAP := 1
const SEG_CONTAINER := 2
var _segments := {} #Vector3i(vertical, line, index) -> type * 16 + gap

func segment(vertical: bool, line: int, index: int) -> int:
	return segmentInfo(vertical, line, index) >> 4

func segmentInfo(vertical: bool, line: int, index: int) -> int:
	var key := Vector3i(1 if vertical else 0, line, index)
	var known = _segments.get(key)
	if known != null: return known
	var tag := TAG_SEG + (500 if vertical else 0)
	var u := WorldGen.hashf(worldSeed, tag, line, index)
	var type := SEG_OPEN
	if u < chance[0]: type = SEG_SCRAP
	elif u < chance[0] + chance[1]: type = SEG_CONTAINER
	var info := type * 16 + segmentGap(vertical, line, index)
	_segments[key] = info
	return info

## The gap cell (1..P-1 within the segment) of a walled fence segment, or 0 for none
func segmentGap(vertical: bool, line: int, index: int) -> int:
	var tag := TAG_SEG + (1500 if vertical else 1000)
	if WorldGen.hashf(worldSeed, tag, line, index) >= chance[3]: return 0
	var p := int(spacingA)
	return 1 + WorldGen.ihash(worldSeed, tag + 7, line, index) % maxi(p - 1, 1)

func yard(x: float, y: float) -> Vector3:
	var p := int(spacingA)
	var cx := floori(x / CELL)
	var cy := floori(y / CELL)
	var ox := posmod(cx, p)
	var oy := posmod(cy, p)
	if ox == 0 && oy == 0: return Vector3(BIG, BIG, LOT)
	if ox == 0 || oy == 0:
		var vertical := ox == 0
		var line := cx if vertical else cy
		var index := floori(float(cy if vertical else cx) / p)
		var along := oy if vertical else ox
		var info := segmentInfo(vertical, line, index)
		var type := info >> 4
		if type == SEG_OPEN || (info & 15) == along: return Vector3(BIG, BIG, DIRT)
		var across := absf((x if vertical else y) - (line + 0.5) * CELL)
		var half := halfA + 160.0 * n1.get_noise_2d(x, y) if type == SEG_SCRAP else halfB
		return Vector3(BIG, (across - half) / UNIT, DIRT)
	var px := floori(float(cx) / p)
	var py := floori(float(cy) / p)
	if WorldGen.hashf(worldSeed, TAG_PLOT, px, py) < chance[2]: return Vector3(BIG, BIG, LOT) #tank farm
	if spacingB > 0.0 && posmod(py, int(spacingB)) == 0 && oy == p / 2 && absf(y - (cy + 0.5) * CELL) < halfC:
		return Vector3(BIG, BIG, CONVEYOR)
	return Vector3(BIG, BIG, OIL if n2.get_noise_2d(x, y) > threshA else surfaceBase(x, y))

## The belt direction code (WorldMap.beltDirAt) of the conveyor in plot row py: 1 = +x, 2 = -x
func beltCode(cy: int) -> int:
	var py := floori(float(cy) / maxf(spacingA, 1.0))
	return 1 if WorldGen.ihash(worldSeed, TAG_PLOT + 77, py, 0) & 1 == 0 else 2

## Whether a yard plot is a tank farm (reserved for props)
func isTankFarm(cx: int, cy: int) -> bool:
	if grammar != Grammar.YARD: return false
	var p := int(spacingA)
	if posmod(cx, p) == 0 || posmod(cy, p) == 0: return false
	return WorldGen.hashf(worldSeed, TAG_PLOT, floori(float(cx) / p), floori(float(cy) / p)) < chance[2]
