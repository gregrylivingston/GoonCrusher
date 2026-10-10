extends SceneTree

#The handling lab: drives every car's real integrate() and the controller's steering through set
#manoeuvres, with no level, and prints one row per car (docs/CAR_ART.md, "Handling").
#  Godot_console.exe --headless --path . -s res://scripts/debug/handling_lab.gd [-- --up=0,20 --ground=grass,asphalt --cars=sedan,semi]
#Columns: top speed and the time to 90% of it; ticks from centre to full lock; the turn rate at full
#lock after half a second at 200, 400 and 600 px/s and held at top speed; the radius and slip angle
#and the share of top speed kept on a held full-lock circle; a 90 degree turn from top speed (time,
#speed kept); the stop from top speed; the top speed in reverse.
#--up adds that many levels to engine, steering, traction and armor (20 is maxed).

const CARS := ["sedan", "taxi", "van", "pickup", "semi", "ambulance", "supercar", "police", "racer"]
const GROUNDS := {"grass": 0.13, "asphalt": 0.02}
const DT := 1.0 / 60.0

var CTRL
var INP

func _initialize():
	run.call_deferred()

func run() -> void:
	await process_frame #let the autoloads finish _ready
	CTRL = load("res://scene/player/controller/playerCarController.gd")
	INP = load("res://lib/overhead_car_2d/overhead_car_body_2d.gd").CarInput
	var ups := [0, 20]
	var grounds := ["grass"]
	var cars := CARS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--up="): ups = Array(arg.trim_prefix("--up=").split(",")).map(func(u): return int(u))
		if arg.begins_with("--ground="): grounds = Array(arg.trim_prefix("--ground=").split(","))
		if arg.begins_with("--cars="): cars = Array(arg.trim_prefix("--cars=").split(","))
	for ground in grounds:
		print("\n#### ground=%s friction=%.2f" % [ground, GROUNDS[ground]])
		print("car       up | eng ste tra arm  wt | top   t90  | lock | yaw@200  @400  @600  @top | radius  slip  kept | 90deg  kept | stop px  time | rev")
		for up in ups:
			for id in cars:
				var car = load("res://scene/car/%s/%s.tscn" % [id, id]).instantiate()
				car.engine += up
				car.steering += up
				car.traction += up
				car.armor += up
				car.friction = GROUNDS[ground]
				print(measure(car, id, up))
				car.free()
	quit()

## full lock right from straight at `speed`, throttle on, for `ticks`: [heading, velocity, ticks to full lock]
func turn(car, speed: float, ticks: int) -> Array:
	var input = INP.new()
	input.acceleration = 1.0
	var fwd := Vector2.RIGHT
	var vel := Vector2.RIGHT * speed
	var lock := -1
	for t in ticks:
		input.steering = CTRL.nextSteering(input.steering, false, true, car.steerRate())
		if lock < 0 && input.steering >= 0.999: lock = t + 1
		var next = car.integrate(Vector2.ZERO, fwd, vel, input, DT)
		fwd = next[0]
		vel = next[1]
	return [fwd, vel, lock]

## rad/s over the last quarter second of a full-lock turn from `speed` lasting `seconds`
func yaw(car, speed: float, seconds := 0.5) -> float:
	var n := int(seconds * 60)
	var a = turn(car, speed, n - 15)
	var b = turn(car, speed, n)
	return absf(angle_difference(a[0].angle(), b[0].angle())) / (15 * DT)

func topSpeed(car) -> Array:
	var input = INP.new()
	input.acceleration = 1.0
	var vel := Vector2.ZERO
	var speeds := []
	for t in 60 * 40:
		vel = car.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, DT)[1]
		speeds.push_back(vel.length())
	var top: float = speeds[-1]
	for i in speeds.size():
		if speeds[i] >= top * 0.9: return [top, i * DT]
	return [top, 0.0]

func measure(car, id: String, up: int) -> String:
	var ts := topSpeed(car)
	var top: float = ts[0]
	var circle = turn(car, top, 240)
	var kept: float = circle[1].length()
	var yawTop := yaw(car, top, 4.0)
	var slip := rad_to_deg(absf(angle_difference(circle[0].angle(), circle[1].angle())))
	#a 90 degree turn of the travel from top speed, throttle held
	var input = INP.new()
	var fwd := Vector2.RIGHT
	var vel := Vector2.RIGHT * top
	var t90 := 0
	while absf(vel.angle()) < PI / 2 && t90 < 600:
		input.steering = CTRL.nextSteering(input.steering, false, true, car.steerRate())
		input.acceleration = 1.0
		var next = car.integrate(Vector2.ZERO, fwd, vel, input, DT)
		fwd = next[0]
		vel = next[1]
		t90 += 1
	var kept90 := vel.length()
	#the stop from top speed
	input = INP.new()
	input.braking = true
	vel = Vector2.RIGHT * top
	var dist := 0.0
	var stopTicks := 0
	while vel.length() > 0.0 && stopTicks < 600:
		vel = car.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, DT)[1]
		dist += vel.length() * DT
		stopTicks += 1
	#reverse
	input = INP.new()
	input.acceleration = -1.0
	vel = Vector2.ZERO
	for t in 60 * 20: vel = car.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, DT)[1]
	return "%-9s %2d | %3d %3d %3d %3d %3d | %5.0f %4.1fs | %3d  | %5.2f %5.2f %5.2f %5.2f | %6.0f %4.1f° %4.0f%% | %4.2fs %3.0f%% | %5.0f %4.1fs%s | %4.0f" % [
		id, up, car.engine, car.steering, car.traction, car.armor, car.weight, top, ts[1], turn(car, 300, 60)[2],
		yaw(car, 200), yaw(car, 400), yaw(car, 600), yawTop, kept / maxf(yawTop, 0.001), slip, 100.0 * kept / top,
		t90 * DT, 100.0 * kept90 / top, dist, stopTicks * DT, " NO STOP" if stopTicks >= 600 else "", vel.length()]
