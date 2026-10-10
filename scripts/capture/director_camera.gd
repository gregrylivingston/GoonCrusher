class_name DirectorCamera extends Camera2D

#A camera that takes the picture over from the car's own, for the capture kit's shots and photo mode
#(docs/PROMO.md). It never touches the car or its camera: `release` hands the picture back.
#A rig is a Dictionary:
#  rig     "follow" (stays on the car), "tripod" (stands still while the car drives through),
#          "pan" (travels in a straight line), "free" (moved by whoever owns it: photo mode)
#  zoom    the zoom held, or [from, to] for a push in or pull back over `seconds`
#  seconds how long a zoom change or a pan takes (default 4)
#  lead    follow: how far ahead of the car the camera looks, as seconds of the car's speed (default 0)
#  offset  [x, y] in screen px (at 900 px on the frame's short side): where the car sits off center, e.g.
#          [0, 200] keeps it low in a vertical frame
#  ahead   tripod and pan: where the camera stands, px ahead of the car when the rig starts (default 900)
#  side    tripod and pan: px to the car's right (default 0)
#  travel  pan: [x, y] px the camera covers over `seconds`, along and across the car's heading
#  smooth  follow: how quickly it catches the car, 1 = at once (default 0.2)

const DEFAULT_ZOOM := 0.45 #the car camera's own (OverheadCarBody2D.defaultZoomLevel)

var car: Node2D
var rig := "follow"
var zoomFrom := DEFAULT_ZOOM
var zoomTo := DEFAULT_ZOOM
var seconds := 4.0
var lead := 0.0
var screenOffset := Vector2.ZERO
var smooth := 0.2
var anchor := Vector2.ZERO
var travel := Vector2.ZERO
var age := 0.0
var previous: Camera2D

static func attach(target: Node2D, cfg: Dictionary) -> DirectorCamera:
	var camera := DirectorCamera.new()
	camera.name = "DirectorCamera"
	camera.car = target
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	target.get_parent().add_child(camera)
	camera.global_position = target.global_position
	camera.previous = target.get_viewport().get_camera_2d()
	camera.setRig(cfg)
	camera.make_current()
	return camera

func setRig(cfg: Dictionary) -> void:
	rig = str(cfg.get("rig", rig))
	var from := zoom.x if age > 0.0 else DEFAULT_ZOOM
	var wanted = cfg.get("zoom", zoomTo if age > 0.0 else DEFAULT_ZOOM)
	if wanted is Array && wanted.size() == 2:
		zoomFrom = float(wanted[0])
		zoomTo = float(wanted[1])
	else:
		zoomFrom = from if cfg.has("seconds") && age > 0.0 else float(wanted)
		zoomTo = float(wanted)
	seconds = maxf(float(cfg.get("seconds", 4.0)), 0.01)
	lead = float(cfg.get("lead", 0.0))
	smooth = clampf(float(cfg.get("smooth", 0.2)), 0.01, 1.0)
	screenOffset = pair(cfg.get("offset", [0, 0]))
	age = 0.0
	zoom = Vector2(zoomFrom, zoomFrom)
	if not is_instance_valid(car): return
	var heading := Vector2.from_angle(car.global_rotation)
	if rig == "tripod" || rig == "pan":
		anchor = car.global_position + heading * float(cfg.get("ahead", 900.0)) + heading.orthogonal() * float(cfg.get("side", 0.0))
		var along := pair(cfg.get("travel", [0, 0]))
		travel = heading * along.x + heading.orthogonal() * along.y
		global_position = anchor - screenOffset / zoom.x

static func pair(value) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array && value.size() == 2 else Vector2.ZERO

func _process(delta: float) -> void:
	age += delta
	var share := smoothstep(0.0, 1.0, clampf(age / seconds, 0.0, 1.0))
	var z := lerpf(zoomFrom, zoomTo, share)
	zoom = Vector2(z, z)
	var shift := screenOffset / z #screen px to world px: the car sits `screenOffset` from the center
	match rig:
		"follow":
			if not is_instance_valid(car): return
			var target: Vector2 = car.global_position - shift
			if lead > 0.0 && "velocity" in car: target += car.velocity * lead
			#per second, so the catch-up is the same at any frame rate
			global_position = global_position.lerp(target, 1.0 - pow(1.0 - smooth, delta * 60.0))
		"tripod":
			global_position = anchor - shift
		"pan":
			global_position = anchor + travel * share - shift

#the picture goes back to the camera that had it
func release() -> void:
	if is_instance_valid(previous): previous.make_current()
	queue_free()
