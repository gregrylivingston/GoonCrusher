class_name Tiremark extends Line2D

#One tire mark segment on one surface. Points are at least MIN_SPACING apart and a segment holds at most
#MAX_POINTS, after which the car starts a new one, so a long skid stays cheap. A segment takes its color and
#width from the surface it began on (LOOK), so the car starts a new one when the ground changes, and fades
#out over the last FADE_SHARE of its lifetime. Show only.

const MIN_SPACING = 12.0
const MAX_POINTS = 64
const FADE_SHARE := 0.35
const SLIP := 0.3        #rad between the nose and the travel that marks the ground without the brakes
const SLIP_SPEED := 150.0
const RUT_SPEED := 120.0 #px/s before the tires leave ruts in soft ground
## Per surface name (World.TERRAIN): [color, width, soft]. Soft ground takes ruts from just driving over it;
## the rest only marks in a skid. An empty entry never marks (water). Surfaces not listed take DEFAULT.
const DEFAULT := [Color(0.3, 0.24, 0.14, 0.5), 10.0, false]
const RUBBER := [Color(0.04, 0.04, 0.05, 0.6), 11.0, false]
const LOOK := {
	"ASPHALT": RUBBER, "LOT": RUBBER, "BRIDGE": RUBBER, "CONVEYOR": RUBBER,
	"GRASS": [Color(0.27, 0.21, 0.11, 0.5), 10.0, false],
	"MOSS": [Color(0.2, 0.2, 0.1, 0.5), 10.0, false],
	"DIRT": [Color(0.3, 0.21, 0.13, 0.5), 11.0, false],
	"WASH": [Color(0.42, 0.33, 0.22, 0.45), 11.0, false],
	"SAND": [Color(0.5, 0.4, 0.25, 0.45), 13.0, true],
	"MUD": [Color(0.15, 0.1, 0.05, 0.6), 14.0, true],
	"MUDPIT": [Color(0.12, 0.08, 0.04, 0.7), 15.0, true],
	"SNOW": [Color(0.58, 0.65, 0.76, 0.55), 13.0, true],
	"DEEPSNOW": [Color(0.5, 0.58, 0.72, 0.65), 15.0, true],
	"ICE": [Color(1.0, 1.0, 1.0, 0.35), 5.0, false],
	"OIL": [Color(0.02, 0.02, 0.03, 0.6), 11.0, false],
	"SHALLOWS": [], "WADE": [], "WATER": [],
}

var lifetime: float = 20.0
var surface := World.UNKNOWN

static var lookBySurface := {} #World surface index -> LOOK entry, built once

func _ready():
	var look := lookOf(surface)
	default_color = look[0]
	width = look[1]
	var fade := create_tween()
	fade.tween_interval(lifetime * (1.0 - FADE_SHARE))
	fade.tween_property(self, "modulate:a", 0.0, lifetime * FADE_SHARE)
	fade.tween_callback(queue_free)

static func lookOf(s: int) -> Array:
	if lookBySurface.is_empty():
		for i in World.count(): lookBySurface[i] = LOOK.get(World.def(i).name, DEFAULT)
	return lookBySurface.get(s, DEFAULT)

## Whether a tire on surface `s` leaves a mark: in a skid anywhere but water, and at speed on soft ground
static func marks(s: int, skidding: bool, speed: float) -> bool:
	var look := lookOf(s)
	if look.is_empty(): return false
	return skidding || (look[2] && speed > RUT_SPEED)

#returns false once the segment is full
func update(gposition: Vector2) -> bool:
	var local = gposition - position
	if local.distance_to(points[points.size() - 1]) < MIN_SPACING: return true
	add_point(local)
	return points.size() < MAX_POINTS

func lastGlobalPoint() -> Vector2:
	return position + points[points.size() - 1]
