class_name CarTrailer extends CharacterBody2D

#A trailer on a fifth wheel (the semi; docs/CAR_ART.md, "Trailer"). The car is the tractor; this is a
#separate body, top_level, that follows the kingpin every physics tick after the car moves (follow()).
#Its origin is the middle of its rear axles and it faces +x. It is not part of integrate(), so the AI's
#predictions drive the tractor alone.
#
#It pivots on the kingpin with its own turn rate, which its tyres pull toward the rate at which they
#wouldn't slide sideways (CarHandling.trailerGrip a tick, less on ice and oil). So the trailer cuts inside
#a corner, lags into a flick and swings past it after, and pushed backwards it folds (jackknifes) unless
#the driver steers it straight. The fold stops at trailerJackknife degrees, where it drags the tractor.
#Walls stop it (and damage the truck through the car, like a bumper hit); a snagged trailer holds the
#tractor back. Its sides and tail swat goons like the car's flanks (slamGoons).
#
#The trailer has its own baked art (semi_trailer_*: car_gen.js's semiTrailer, baked with the semi), drawn
#under the cab's shadow and over the cab itself, so a folded trailer's nose covers the tractor's frame.

@export var art: CarArtSet                  #the trailer's sheets, mask and shadow
@export var kingpin := Vector2(-59.0, 0.0)  #the fifth wheel, in the tractor's space
@export var length := 248.0                 #kingpin to the middle of the rear axles (8 of nose ahead of it)
@export var axleY := 101.0                  #the axles' place on the trailer's sheet (sheet units back from its middle)
@export var tailLamps := Vector2(55.0, 0.0) #where the car's taillamps node sits, in trailer space

var car: OverheadCarBody2D
var sprite := Node2D.new()  #like the car's `sprite`: turned so the sheet's up is the trailer's front
var body := Sprite2D.new()
var shadow := Sprite2D.new()
var highlight: PointLight2D #the night silhouette, kept under the car's headlamps so it shows when they do
var axleVel := Vector2.ZERO
var spin := 0.0             #rad/s the trailer is turning
var lastHitch := Vector2.ZERO
var folded := false         #at the jackknife stop this tick
var pushed := Vector2.ZERO #this tick's push toward its place behind the kingpin
const MAX_SPIN := 5.0 #rad/s: the most the trailer swings
var snap := true            #place it straight behind the tractor on the next tick (spawn, teleports)
var bodyRect := Rect2()     #the footprint in trailer space, for slams

## Called from the car's _ready: builds the trailer's sprites and lights and hitches it
func attach(owner: OverheadCarBody2D) -> void:
	car = owner
	top_level = true
	#top_level also leaves the car's z ordering, so set it outright: the box over the tractor's frame and
	#fifth wheel (and over the cab when it folds), its shadow under the tractor
	z_as_relative = false
	z_index = car.z_index + 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_collision_exception_with(car)
	car.add_collision_exception_with(self)
	var cab: Sprite2D = car.get_node("sprite/body")
	sprite.rotation = PI / 2.0
	add_child(sprite)
	for s in [shadow, body]:
		s.texture_filter = cab.texture_filter
		s.scale = cab.scale
		s.position = Vector2(0.0, -axleY)
		sprite.add_child(s)
	shadow.self_modulate = car.get_node("sprite/shadow").self_modulate
	shadow.z_index = -2 #one under the tractor
	body.material = cab.material.duplicate()
	var shape := get_node_or_null("shape") as CollisionPolygon2D
	if shape:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in shape.polygon:
			lo = lo.min(p)
			hi = hi.max(p)
		bodyRect = Rect2(lo, hi - lo)
	var lamp: PointLight2D = car.get_node("headlamps/carhighlight")
	highlight = lamp.duplicate()
	car.get_node("headlamps").add_child(highlight)
	placeBehind.call_deferred() #the car is placed after it is made, and doesn't tick before the start lights

## Straight behind the tractor (spawn, teleports)
func placeBehind() -> void:
	if not is_instance_valid(car): return
	var tractor := car.global_transform.x
	global_rotation = tractor.angle()
	lastHitch = car.to_global(kingpin)
	global_position = lastHitch - tractor * length
	axleVel = car.velocity
	spin = 0.0
	snap = false
	syncLights()

## The car's applyArt: the paint the player picked, on the trailer
func applyArt(paint: String) -> void:
	if art == null: return
	var sheets := art.sheets(paint)
	body.texture = sheets[0]
	body.material.set_shader_parameter("dented_tex", sheets[1])
	body.material.set_shader_parameter("wrecked_tex", sheets[2])
	body.material.set_shader_parameter("zone_mask", art.zoneMask)
	shadow.texture = art.shadow
	highlight.texture = sheets[0]

func setDamage(look: PackedFloat32Array) -> void:
	body.material.set_shader_parameter("damage", look)

## One physics tick, after the tractor has moved. The trailer pivots on the kingpin with its own turn
## rate, `spin`. The rate at which its axles wouldn't slide sideways is the kingpin's sideways speed over
## `length`; the tyres pull `spin` toward that by trailerGrip (times the ground's grip) each tick. Full
## grip is a trailer on rails; less keeps some of its swing, so it lags into a turn and overshoots out of it.
func follow(delta: float) -> void:
	var h := CarHandling.tune
	var hitch := car.to_global(kingpin)
	var tractor := car.global_transform.x
	if snap || global_position.distance_to(hitch) > length * 2.0:
		placeBehind()
		return
	var heading := global_transform.x
	var side := Vector2(-heading.y, heading.x) #where the heading moves as the trailer turns
	var hitchVel := (hitch - lastHitch) / delta
	var grip := clampf(h.trailerGrip * World.grip(World.surfaceAt(global_position)), 0.0, 1.0)
	spin = clampf(lerpf(spin, hitchVel.dot(side) / length, grip), -MAX_SPIN, MAX_SPIN)
	var angle := global_rotation + spin * delta
	#the fold stops at the jackknife angle, where the trailer turns with the tractor and drags it
	var fold := angle_difference(tractor.angle(), angle)
	var stop := deg_to_rad(h.trailerJackknife)
	folded = absf(fold) > stop
	if folded:
		angle = tractor.angle() + signf(fold) * stop
		spin = car.spinRate
		car.velocity *= 1.0 - h.trailerFoldDrag
	var before := global_position
	var was := axleVel #the axles' real speed coming into this tick: what a wall hit is judged by
	global_rotation = angle
	pushed = (hitch - Vector2.from_angle(angle) * length - before) / delta
	#move_and_slide steps by the engine's delta: the physics one in a physics frame, else the frame's (tests)
	velocity = pushed * delta / (get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time())
	move_and_slide()
	axleVel = (global_position - before) / delta
	if get_slide_collision_count() > 0:
		spin = 0.0 #blocked: it stops swinging into whatever it met
		hitThings(was.limit_length(car.velocity.length() + 100.0))
	hold()
	lastHitch = car.to_global(kingpin) #after the tug, so the trailer never reads its own pull as the tractor moving
	syncLights()

## The hitch is rigid. Where the trailer ended up (a wall, a log or a rock may have stopped it), the kingpin
## has to be `length` ahead of its axles; the tractor is moved there, as a body, so it can't be pushed into
## anything either, and loses the speed that would pull it away again. If even that is blocked, the trailer
## goes to the kingpin. Either way the two never come apart, so nothing can get between them.
func hold() -> void:
	var want := global_position + Vector2.from_angle(global_rotation) * length
	var off := want - car.to_global(kingpin)
	if off.length() < 0.5: return
	var u := off.normalized()
	var away := car.velocity.dot(-u)
	if away > 0.0: car.velocity += u * away
	car.move_and_collide(off)
	var still := car.to_global(kingpin) - want
	if still.length() > 0.5: global_position += still

## What the trailer ran into this tick, met at `moving` (its real speed, never the correction it was pushed by)
func hitThings(moving: Vector2) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null: continue
		if (collider.has_method("smash") || BreakableProp.isBreakable(collider)) && moving.length() >= car.smashThreshold(collider):
			if collider.has_method("smash"): collider.smash(car)
			else: BreakableProp.smashNode(collider, car)
		elif PropReactions.knocks(collider, moving):
			pass
		elif moving.length() > 0.01 && World.isWall(collider):
			car.collideWithFixedObject(collision, moving, false, "tires")

## The car's taillamps ride on the trailer's tail, and its silhouette light on the trailer
func syncLights() -> void:
	var lamps: Node2D = car.get_node("headlamps/taillamps")
	lamps.global_transform = global_transform * Transform2D(0.0, tailLamps)
	if highlight: highlight.global_transform = sprite.global_transform * Transform2D(0.0, body.scale, 0.0, body.position)
	sprite.modulate = car.get_node("sprite").modulate

## Goons touching the trailer's sides or tail, that it moves into at SLAM_MIN_SPEED or more, counting
## the swing, are crushed like the car's flanks (OverheadCarBody2D.slamGoons)
func slamGoons() -> void:
	if not is_instance_valid(Root.spawnManager) || bodyRect.size == Vector2.ZERO: return
	var centre := bodyRect.get_center()
	var half := bodyRect.size / 2.0
	for goon in Root.spawnManager.goonsNear(to_global(centre), half.x + 80.0):
		if goon.dead || goon.collision_layer == 0: continue
		var r: float = goon.bodyRadius * goon.scale.x
		var local := to_local(goon.global_position) - centre
		var inX := half.x + r - absf(local.x)
		var inY := half.y + r - absf(local.y)
		if inX <= 0.0 || inY <= 0.0: continue
		var normal := Vector2(0.0, signf(local.y)) if inY < inX else Vector2(signf(local.x), 0.0)
		if normal.x > 0.0: continue #the front is under the cab
		var arm: Vector2 = goon.global_position - global_position
		var pointVel := axleVel + Vector2(-arm.y, arm.x) * spin
		if pointVel.dot(normal.rotated(global_rotation)) < OverheadCarBody2D.SLAM_MIN_SPEED: continue
		if car.goonBumpReady(goon): car.damage(OverheadCarBody2D.GOON_CONTACT_DAMAGE)
		car.crushHitVel = pointVel
		car.crushGoon(goon, pointVel.length())
		car.crushHitVel = Vector2.ZERO
