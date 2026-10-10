class_name CarTraits extends RefCounted

#Each car's signature features (docs/CAR_ART.md, "Traits"). A car lists its trait ids in its CarInfo
#(`traits`); the car reads them once in _ready (OverheadCarBody2D.hasTrait and the flags it caches for
#integrate()), the garage card shows them as badges and the driver focus (DriverBench) explains them.
#
#kind: PHYSICS changes how the car drives, inside integrate(), so the AI driver's predictions follow it;
#MECHANIC is a rule on top; ABILITY has its own button (the Ability action).

enum Kind { PHYSICS, MECHANIC, ABILITY }
const KIND_NAMES := ["PHYSICS", "MECHANIC", "ABILITY"]
const KIND_COLORS := [Color(0.498, 0.816, 1.0), Color(1.0, 0.827, 0.42), Color(0.941, 0.627, 0.188)] #HudTheme SKY, GOLD, RIM

const DATA := {
	&"second_wind": {"name":"Second Wind", "kind":Kind.MECHANIC,
		"short":"Restarts once when the tank runs dry",
		"text":"Once a run, when the tank runs dry, it coughs, sputters and starts again with 10% fuel. It always starts on the third try."},
	&"duct_tape": {"name":"Duct Tape", "kind":Kind.MECHANIC,
		"short":"Damaged systems patch themselves up",
		"text":"Drive clean for a few seconds, with no walls and no goon bumps, and damaged systems slowly patch themselves back up to 60%."},
	&"cargo_bay": {"name":"Cargo Bay", "kind":Kind.MECHANIC,
		"short":"Carries two gadgets",
		"text":"Carries two gadgets instead of one. Fire Gadget uses the first; when it runs out, the second moves up."},
	&"top_heavy": {"name":"Top-Heavy", "kind":Kind.PHYSICS,
		"short":"Hard corners tip it onto two wheels",
		"text":"Hard cornering at speed lifts it onto two wheels, where it grips less and steers lighter. Hold it up too long, or hit something while up, and it rolls."},
	&"meter": {"name":"The Meter", "kind":Kind.MECHANIC,
		"short":"Fast, clean driving earns fares",
		"text":"Above 300 px/s with no wall hits, the meter runs and pays coins as you go, faster the longer it runs. Stop or hit a wall and it resets."},
	&"city_tyres": {"name":"City Tyres", "kind":Kind.PHYSICS,
		"short":"Grips on pavement, slips on dirt",
		"text":"More grip on asphalt, lots, bridges and wash; less on dirt, sand, mud, snow and shallows."},
	&"offroad": {"name":"Off-Road Suspension", "kind":Kind.PHYSICS,
		"short":"Sand, mud and snow barely slow it",
		"text":"Sand, mud, snow and shallows cost it far less speed and grip than any other car."},
	&"loaded_bed": {"name":"Loaded Bed", "kind":Kind.MECHANIC,
		"short":"Pickups load crates worth bonus pay",
		"text":"Every pickup you collect drops a crate in the bed, up to five, each adding 5% to the run's payout. Hard wall hits spill a crate out the back."},
	&"downforce": {"name":"Downforce", "kind":Kind.PHYSICS,
		"short":"Grips harder the faster it goes",
		"text":"The wing pushes it down: loose below 400 px/s, glued at 1,000. Every other car loses grip as it speeds up; this one gains it."},
	&"low_clearance": {"name":"Low Clearance", "kind":Kind.PHYSICS,
		"short":"Hates rough ground",
		"text":"The splitter scrapes on rough ground: sand, mud and deep snow slow it hard and wear its engine. Asphalt and lots are home."},
	&"drift_king": {"name":"Drift King", "kind":Kind.PHYSICS,
		"short":"Looser slides and a third drift boost",
		"text":"A looser rear and a wider catch on the handbrake, a drift charge that builds 40% faster, and a third, purple boost tier no other car reaches."},
	&"featherweight": {"name":"Featherweight", "kind":Kind.PHYSICS,
		"short":"Big goons knock it around",
		"text":"So light that a goon it fails to crush bounces it off instead of stopping it."},
	&"pit": {"name":"PIT Maneuver", "kind":Kind.MECHANIC,
		"short":"Side-swipes cost nothing and fling harder",
		"text":"Goons swatted with the flanks or tail cost it no health and fly further."},
	&"lightbar": {"name":"Lightbar", "kind":Kind.MECHANIC,
		"short":"Lights up all around at night",
		"text":"At night the red and blue lightbar washes a circle round the car, so it sees goons beside and behind it, not only in the beams."},
	&"defib": {"name":"Defibrillator", "kind":Kind.MECHANIC,
		"short":"Comes back once from 0 health",
		"text":"Once a run, when its health hits 0, it shocks itself back to 30%, even in deep water."},
	&"box_sway": {"name":"Box Sway", "kind":Kind.PHYSICS,
		"short":"Brake into turns, power out of them",
		"text":"The tall box shifts its weight: braking dips the nose for more bite turning in, and power through a hard corner swings the tail out."},
	&"unstoppable": {"name":"Unstoppable", "kind":Kind.PHYSICS,
		"short":"Smashes through props at any speed",
		"text":"Its mass smashes crates, fences, hay and every other breakable at any speed, where other cars need a run-up. Explosives still need a hit."},
	&"drop_load": {"name":"Drop the Load", "kind":Kind.ABILITY,
		"short":"Dumps crates behind as a barrier",
		"text":"Press Ability to dump the trailer's cargo out the back: a wall of crates that flattens goons under it and blocks the rest. Running empty, the rig is lighter and quicker until it restocks."},
}

static func has(id: StringName) -> bool:
	return DATA.has(id)

static func displayName(id: StringName) -> String:
	return DATA[id].name if DATA.has(id) else str(id)

static func kind(id: StringName) -> int:
	return DATA[id].kind if DATA.has(id) else Kind.MECHANIC

static func color(id: StringName) -> Color:
	return KIND_COLORS[kind(id)]

static var textures := {} #id -> Texture2D, kept: the HUD draws them in _draw, where nothing else holds the texture

## texture/icon/trait_<id>.svg (scripts/art/pickup_icons.js draws them)
static func texture(id: StringName) -> Texture2D:
	if not textures.has(id):
		var path := "res://texture/icon/trait_%s.svg" % id
		textures[id] = load(path) if ResourceLoader.exists(path) else null
	return textures[id]
