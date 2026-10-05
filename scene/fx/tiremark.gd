class_name Tiremark extends Line2D

#One skid segment. Points are at least MIN_SPACING apart and a segment holds at most
#MAX_POINTS, after which the car starts a new one, so a long skid stays cheap.

const MIN_SPACING = 12.0
const MAX_POINTS = 64
var lifetime: float = 20.0

func _ready():
	await get_tree().create_timer(lifetime).timeout
	queue_free()

#returns false once the segment is full
func update(gposition: Vector2) -> bool:
	var local = gposition - position
	if local.distance_to(points[points.size() - 1]) < MIN_SPACING: return true
	add_point(local)
	return points.size() < MAX_POINTS

func lastGlobalPoint() -> Vector2:
	return position + points[points.size() - 1]
