class_name GoonVerbs extends RefCounted
## What each goon does. A verb is a small state machine on top of Walker's helpers, and Goons.DATA picks the
## verb and its numbers. Every threat has a tell (the windup state, drawn by GoonFx) and a punish window
## (recover or stun). States shared by all: move -> windup -> attack -> recover, and stun. docs/GOONS.md.

static func make(name: StringName, g: Walker) -> Verb:
	match name:
		&"lunge": return Lunge.new(g)
		&"dodger": return Dodger.new(g)
		&"lobber": return Lobber.new(g)
		&"shooter": return Shooter.new(g)
		&"trapper": return Trapper.new(g)
		&"bomber": return Bomber.new(g)
		&"hitcher": return Hitcher.new(g)
		&"turtle": return Turtle.new(g)
		&"boss": return Boss.new(g)
		&"burrow": return Burrow.new(g)
		&"pack": return Pack.new(g)
		&"roller": return Roller.new(g)
		&"slammer": return Slammer.new(g)
		&"charger": return Charger.new(g)
		&"hopper": return Hopper.new(g)
		&"thief": return Thief.new(g)
		&"striker": return Striker.new(g)
		&"spiky": return Spiky.new(g)
		&"flyer": return Flyer.new(g)
		&"herd": return Herd.new(g)
		&"rider": return Rider.new(g)
	push_warning("unknown goon verb %s" % name)
	return Lunge.new(g)

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## True while the car is in its headlight beams' reach and angle (night goons react to it).
static func inHeadlights(car: Node2D, point: Vector2) -> bool:
	var to := point - car.global_position
	return to.length() < 560.0 && absf(angle_difference(car.rotation, to.angle())) < 0.42

## True when the car is coming at `point` fast: within `dist`, above `minSpeed`, heading roughly at it.
static func bearingDown(car: Node2D, point: Vector2, dist: float, minSpeed: float) -> bool:
	var to := point - car.global_position
	return to.length() < dist && car.velocity.length() > minSpeed && car.velocity.normalized().dot(to.normalized()) > 0.8

#==================================================================================================
class Verb extends RefCounted:
	var g: Walker
	func _init(goon: Walker) -> void: g = goon
	func setup() -> void: pass
	func onNight(_on: bool) -> void: pass
	func frontArmorActive() -> bool: return true
	func allowCrush(_car: Node2D, _speed: float) -> bool: return true
	func beforeCrush(_car: Node2D, _speed: float) -> void: pass
	func onResist(car: Node2D, speed: float) -> void:
		if speed < g.crushSpeed: g.bounceCar(car, g.attackDamage, g.sys, "TOO HEAVY")
		else: g.bounceCar(car, 2.0, "hull")
		g.global_position += (g.global_position - car.global_position).normalized() * 10.0
	func onDeath(_cause: StringName) -> void: pass
	func telegraphRadius() -> float: return g.bodyRadius * 3.0
	## Walked or drove into the car outside an attack: step back, so contact damage stays a bump.
	func onTouch(car: Node2D) -> void:
		if g.state != &"move": return
		g.global_position += (g.global_position - car.global_position).normalized() * 8.0
		g.recT = 0.5
		g.setState(&"recover")
		g.cooldown = maxf(g.cooldown, 0.6)

	func tick(delta: float, car: Node2D) -> void:
		match g.state:
			&"move": move(delta, car)
			&"windup": windup(delta, car)
			&"attack": attack(delta, car)
			&"recover":
				g.play(&"idle")
				if g.stateTime >= g.recT: g.setState(&"move")
			&"stun": stun(delta, car)
			_: other(delta, car)

	func move(delta: float, car: Node2D) -> void:
		g.chase(car.global_position, g.speedNow(), delta)
		if g.cooldown <= 0.0 && g.distTo(car) < g.windDist: startWindup(car)

	func startWindup(car: Node2D, lead := 0.25) -> void:
		g.lockOn(car, lead)
		g.setState(&"windup")
		g.play(&"windup", g.windT)
		g.telegraph(g.tele, g.windT, telegraphRadius())
		if randi() % 3 == 0 && g.audio_charge.size() > 0: Audio.queueRequest(g.audio_charge)

	func windup(delta: float, _car: Node2D) -> void:
		g.faceTo(g.lockDir.angle(), delta, 12.0)
		if g.stateTime >= g.windT: beginAttack()

	func beginAttack() -> void:
		g.setState(&"attack")
		g.play(&"attack", g.atkT)
		g.hitDone = false

	func attack(delta: float, car: Node2D) -> void:
		g.lungeStep(car, g.speedNow() * g.lunge, delta)
		if g.stateTime >= g.atkT: endAttack()

	func endAttack() -> void:
		g.setState(&"recover")
		g.cooldown = 1.0

	func stun(delta: float, _car: Node2D) -> void:
		g.play(&"stun")
		if g.drift.length() > 5.0:
			g.advance(g.drift, delta)
			g.drift *= pow(0.02, delta)
		if g.stateTime >= g.stunT:
			g.setState(&"move")
			g.cooldown = 0.8

	func other(_delta: float, _car: Node2D) -> void: pass

	func stunFor(t: float, push := Vector2.ZERO) -> void:
		g.stunT = t
		g.drift = push
		g.setState(&"stun")

	## Keeps between range[0] and range[1] of the car, circling at that distance.
	func keepRange(delta: float, car: Node2D, side: float) -> void:
		var r: Array = g.def.get("range", [300, 380])
		var to := car.global_position - g.global_position
		var d := to.length()
		var dir := to.normalized()
		var want := dir if d > r[1] else (-dir if d < r[0] else dir.orthogonal() * side)
		g.chase(g.global_position + want * 60.0, g.speedNow(), delta, 6.0)

#==================================================================================================
## Walks in and lunges. Options: night (sleeps by day, keeps out of the headlights), wander (ignores you
## until you're close), shield (front armour, turns slowly), split (bursts into goonlings).
class Lunge extends Verb:
	var sleeps := false
	var wanderDir := Vector2.RIGHT
	var wanderT := 0.0
	func setup() -> void:
		sleeps = g.def.get("night", false)
		if sleeps && not Root.spawnManager.isNight: g.setState(&"sleep")
		wanderDir = Vector2.from_angle(randf() * TAU)
	func telegraphRadius() -> float: return g.bodyRadius * 3.2
	func onNight(on: bool) -> void:
		if not sleeps: return
		if on && g.state == &"sleep": g.setState(&"move")
		elif not on && g.state == &"move": g.setState(&"sleep")
	func other(_delta: float, _car: Node2D) -> void:
		if g.state == &"sleep":
			g.play(&"idle")
			g.sprite.speed_scale = 0.4
	func move(delta: float, car: Node2D) -> void:
		if g.def.get("wander", false) && g.distTo(car) > g.windDist * 1.6:
			wanderT -= delta
			if wanderT <= 0.0:
				wanderT = randf_range(1.5, 3.0)
				wanderDir = Vector2.from_angle(randf() * TAU)
			g.chase(g.global_position + wanderDir * 100.0, g.speedNow() * 0.6, delta, 2.0)
			return
		if sleeps && GoonVerbs.inHeadlights(car, g.global_position):
			#caught in the beams: slow, and step sideways out of them
			var side := signf(angle_difference(car.rotation, (g.global_position - car.global_position).angle()))
			g.chase(g.global_position + Vector2.from_angle(car.rotation + PI / 2 * (side if side != 0.0 else 1.0)) * 60.0, g.speedNow() * 0.35, delta)
			return
		super.move(delta, car)
	func onResist(car: Node2D, speed: float) -> void:
		if g.def.get("shield", false) && speed >= g.crushSpeed:
			g.bounceCar(car, 3.0, "lights", "BLOCKED")
			stunFor(0.4)
		else: super.onResist(car, speed)
	func onDeath(cause: StringName) -> void:
		var split: StringName = g.def.get("split", &"")
		if split != &"" && cause == &"crush": Root.spawnManager.spawnBurst(split, g.global_position, 3)

#==================================================================================================
## Zig-zags in and sidesteps once when you bear down on it at speed.
class Dodger extends Verb:
	var zig := randf() * TAU
	var dodgeCd := 0.0
	var dodgeDir := Vector2.ZERO
	func move(delta: float, car: Node2D) -> void:
		zig += delta * 5.0
		dodgeCd = maxf(0.0, dodgeCd - delta)
		var to := car.global_position - g.global_position
		g.chase(car.global_position + to.orthogonal().normalized() * sin(zig) * 90.0, g.speedNow(), delta)
		if dodgeCd <= 0.0 && GoonVerbs.bearingDown(car, g.global_position, 160.0, 220.0):
			dodgeCd = 4.0
			if randf() < 0.3: return #fumbles it sometimes, so it isn't uncatchable
			var side := signf(car.transform.y.dot(g.global_position - car.global_position))
			dodgeDir = car.transform.y * (side if side != 0.0 else 1.0)
			g.setState(&"dodge")
			g.play(&"special", 0.32)
			return
		if g.cooldown <= 0.0 && to.length() < g.windDist: startWindup(car)
	func other(delta: float, _car: Node2D) -> void:
		if g.state == &"dodge":
			g.advance(dodgeDir * 360.0, delta)
			if g.stateTime > 0.32:
				g.setState(&"move")
				g.fx().dust(g.global_position)

#==================================================================================================
## Keeps its distance and lobs something where you'll be: fire (Torch), slime (Spitter).
class Lobber extends Verb:
	var side := 1.0 if randf() < 0.5 else -1.0
	func telegraphRadius() -> float: return 58.0
	func move(delta: float, car: Node2D) -> void:
		keepRange(delta, car, side)
		var r: Array = g.def.get("range", [300, 380])
		if g.cooldown <= 0.0 && g.distTo(car) < r[1] + 60.0: startWindup(car, 0.9)
	func windup(delta: float, _car: Node2D) -> void:
		g.faceTo((g.lockPos - g.global_position).angle(), delta, 10.0)
		if g.stateTime >= g.windT:
			g.fx().lob(g.global_position, g.lockPos, 0.9, g.def.get("hazard", "fire"))
			g.setState(&"throw")
			g.play(&"attack", 0.35)
			g.cooldown = g.def.get("cd", 2.4)
	func other(_delta: float, _car: Node2D) -> void:
		if g.state == &"throw" && g.stateTime > 0.35: g.setState(&"move")
	func onDeath(cause: StringName) -> void:
		if g.def.get("deathFire", false) && cause != &"drown": g.fx().addHazard("fire", g.global_position, 34.0, 1.6)

#==================================================================================================
## Keeps its distance and shoots along a dotted aim line (Slinger).
class Shooter extends Verb:
	var side := 1.0 if randf() < 0.5 else -1.0
	func move(delta: float, car: Node2D) -> void:
		keepRange(delta, car, side)
		var r: Array = g.def.get("range", [320, 420])
		if g.cooldown <= 0.0 && g.distTo(car) < r[1] + 60.0: startWindup(car, 0.45)
	func windup(delta: float, _car: Node2D) -> void:
		g.faceTo(g.lockDir.angle(), delta, 10.0)
		if g.stateTime >= g.windT:
			g.fx().shoot(g.global_position + g.lockDir * g.bodyRadius, g.lockDir, 560.0, 1.3, g.attackDamage, g.sys, "bolt")
			g.setState(&"throw")
			g.play(&"attack", 0.3)
			g.cooldown = g.def.get("cd", 1.8)
	func other(_delta: float, _car: Node2D) -> void:
		if g.state == &"throw" && g.stateTime > 0.3: g.setState(&"move")

#==================================================================================================
## Runs ahead of your line and unrolls a spike strip across it (Spiker).
class Trapper extends Verb:
	func move(delta: float, car: Node2D) -> void:
		var ahead := car.global_position + car.transform.x * maxf(150.0, car.velocity.length() * 1.1)
		g.chase(ahead, g.speedNow() * 1.1, delta, 7.0)
		if g.cooldown <= 0.0 && g.global_position.distance_to(ahead) < 70.0 && g.distTo(car) > 150.0:
			g.lockDir = car.transform.y
			g.setState(&"lay")
			g.play(&"special", 0.8)
	func other(_delta: float, car: Node2D) -> void:
		if g.state == &"lay" && g.stateTime >= 0.8:
			g.fx().addHazard("spikes", g.global_position + Vector2.from_angle(g.rotation) * 30.0, 80.0, 9.0, car.rotation + PI / 2)
			g.setState(&"move")
			g.cooldown = 5.0

#==================================================================================================
## Lights a fuse near you and rushes in; the blast hurts the car and flattens goons (Doomcart).
class Bomber extends Verb:
	func move(delta: float, car: Node2D) -> void:
		g.chase(car.global_position, g.speedNow(), delta)
		if g.distTo(car) < g.def.get("fuseDist", 260.0):
			g.setState(&"fuse")
			g.play(&"special")
			g.telegraph("ring", g.def.get("fuseT", 2.2), g.def.get("blast", 130.0))
	func other(delta: float, car: Node2D) -> void:
		if g.state != &"fuse": return
		g.chase(car.global_position, g.speedNow() * 1.3, delta, 6.0)
		g.play(&"special")
		if g.stateTime >= g.def.get("fuseT", 2.2) || g.distTo(car) < g.bodyRadius + 46.0:
			g.fx().blast(g.global_position, g.def.get("blast", 130.0), g.attackDamage)
			g.destroy(&"self")
	func onDeath(cause: StringName) -> void:
		if cause == &"crush": g.fx().blastLater(g.global_position, 0.25, g.def.get("blast", 130.0), g.attackDamage)
		elif cause == &"boom": g.fx().blastLater(g.global_position, 0.15, g.def.get("blast", 130.0), g.attackDamage)

#==================================================================================================
## Leaps onto the car and sabotages it until a hard swerve throws it off (Gremlin).
class Hitcher extends Verb:
	var from := Vector2.ZERO
	var offset := Vector2.ZERO
	var offAngle := 0.0
	var tickT := 0.0
	var shake := 0.0
	func telegraphRadius() -> float: return 22.0
	func windup(delta: float, car: Node2D) -> void:
		g.faceTo((car.global_position - g.global_position).angle(), delta, 12.0)
		if g.stateTime >= g.windT:
			from = g.global_position
			g.lockOn(car, 0.45)
			g.setState(&"leap")
			g.play(&"special", 0.45)
			g.setSolid(false)
			g.invulnerable = true
	func other(delta: float, car: Node2D) -> void:
		match g.state:
			&"leap":
				var u := minf(1.0, g.stateTime / 0.45)
				g.global_position = from.lerp(g.lockPos, u)
				g.sprite.scale = Vector2.ONE * g.sprite.get_meta("baseScale", g.sprite.scale.x) * (1.0 + 0.5 * sin(PI * u))
				if u >= 1.0:
					g.sprite.scale = Vector2.ONE * g.sprite.get_meta("baseScale", g.sprite.scale.x)
					if g.distTo(car) < 80.0:
						offset = car.to_local(g.global_position).clamp(Vector2(-60, -26), Vector2(60, 26))
						offAngle = g.rotation - car.rotation
						g.setState(&"riding")
						g.z_index = 3
						g.fx().label(g.global_position, "HITCHED")
					else:
						g.setSolid(true)
						g.invulnerable = false
						g.setState(&"recover")
			&"riding":
				g.play(&"idle")
				g.global_position = car.to_global(offset)
				g.rotation = car.rotation + offAngle + sin(g.stateTime * 20.0) * 0.1
				tickT += delta
				if tickT >= 1.5:
					tickT = 0.0
					g.hitCar(car, 1.0, "engine" if randf() < 0.5 else "lights")
				shake = shake + delta if absf(g.carSpin) > 1.7 else maxf(0.0, shake - delta * 0.5)
				if shake > 0.45:
					shake = 0.0
					g.z_index = 0
					g.setSolid(true)
					g.invulnerable = false
					g.fx().label(g.global_position, "THROWN OFF")
					stunFor(1.4, car.transform.y * (1.0 if g.carSpin < 0.0 else -1.0) * 320.0)
	func setup() -> void: g.sprite.set_meta("baseScale", g.sprite.scale.x)

#==================================================================================================
## Pulls into its car-roof shell when you rush it. Kick the shell above 460 px/s and it flattens goons.
class Turtle extends Verb:
	const KICK_SPEED := 350.0
	const HIDE_COOLDOWN := 3.0 #after coming out it can't hide again for a while: that's the window
	var hideCd := 0.0
	func move(delta: float, car: Node2D) -> void:
		hideCd = maxf(0.0, hideCd - delta)
		if hideCd <= 0.0 && GoonVerbs.bearingDown(car, g.global_position, 180.0, 300.0):
			g.setState(&"hide")
			g.play(&"special", 0.25)
			g.invulnerable = true
			return
		super.move(delta, car)
	func other(delta: float, car: Node2D) -> void:
		match g.state:
			&"hide":
				if g.stateTime >= 0.25: g.setState(&"hidden")
			&"hidden":
				g.sprite.pause()
				if g.stateTime > 2.5 || (g.stateTime > 1.6 && not GoonVerbs.bearingDown(car, g.global_position, 230.0, 250.0)):
					g.invulnerable = false
					hideCd = HIDE_COOLDOWN
					g.setState(&"move")
			&"slide":
				g.rotation += delta * 9.0
				g.global_position += g.drift * delta
				g.drift *= pow(0.25, delta)
				for o in Root.spawnManager.goonsNear(g.global_position, g.bodyRadius * 2.2):
					if o != g && not o.dead:
						o.destroy(&"crush")
						Root.spawnManager.creditCrush(o.global_position)
				if g.drift.length() < 40.0:
					g.invulnerable = false
					stunFor(1.4)
	func onResist(car: Node2D, speed: float) -> void:
		if g.state == &"hidden" || g.state == &"hide":
			if speed > KICK_SPEED:
				g.drift = car.velocity * 1.1
				g.setState(&"slide")
				g.fx().label(g.global_position, "SHELL KICK")
				car.velocity *= 0.85
			else: g.bounceCar(car, 4.0, "hull", "SHELL")
		else: super.onResist(car, speed)

#==================================================================================================
## Hangs back with a megaphone; goons near it move faster (Foreman).
class Boss extends Verb:
	var side := 1.0 if randf() < 0.5 else -1.0
	var auraT := 0.0
	func move(delta: float, car: Node2D) -> void:
		keepRange(delta, car, side)
		auraT -= delta
		if auraT <= 0.0:
			auraT = 0.25
			var until := GoonVerbs.now() + 0.35
			for o in Root.spawnManager.goonsNear(g.global_position, g.def.get("aura", 260.0)):
				if o != g: o.buffUntil = until
		if g.cooldown <= 0.0:
			g.setState(&"shout")
			g.play(&"special", 0.6)
			g.telegraph("aura", 0.7, g.def.get("aura", 260.0))
			g.cooldown = 2.6
	func other(_delta: float, _car: Node2D) -> void:
		if g.state == &"shout" && g.stateTime >= 0.6: g.setState(&"move")

#==================================================================================================
## Moves under the ground (Skink) or lies still as a log (Snapper), then surfaces for a bite.
class Burrow extends Verb:
	var isLog := false
	var crumbT := 0.0
	func setup() -> void:
		isLog = g.def.get("log", false)
		bury()
	func bury() -> void:
		g.setState(&"buried")
		g.invulnerable = true
		g.setSolid(false)
		g.sprite.play(&"special")
		g.sprite.frame = 0
		g.sprite.pause()
	func telegraphRadius() -> float: return g.bodyRadius * 2.0
	func other(delta: float, car: Node2D) -> void:
		match g.state:
			&"buried":
				if not isLog:
					g.faceTo((car.global_position - g.global_position).angle(), delta, 4.0)
					g.advance(Vector2.from_angle(g.rotation) * g.speedNow(), delta)
					crumbT -= delta
					if crumbT <= 0.0:
						crumbT = 0.08
						g.fx().crumb(g.global_position - Vector2.from_angle(g.rotation) * 16.0)
				if g.distTo(car) < (210.0 if isLog else 175.0):
					g.setState(&"emerge")
					g.play(&"special", 0.35)
					g.telegraph("ring", 0.35, telegraphRadius())
					g.setSolid(true)
					g.invulnerable = false
			&"emerge":
				if g.stateTime >= 0.35:
					g.lockOn(car, 0.1)
					beginAttack()
			&"rebury":
				if g.stateTime >= 0.5: bury()
	func endAttack() -> void:
		g.setState(&"recover")
		g.recT = 1.0
	func tick(delta: float, car: Node2D) -> void:
		if g.state == &"recover":
			g.play(&"idle")
			if g.stateTime >= g.recT:
				g.setState(&"rebury")
				g.sprite.play_backwards(&"special")
				g.sprite.speed_scale = 8.0 / 10.0 / 0.5
			return
		super.tick(delta, car)

#==================================================================================================
## Packs: stay together, scatter when you come in fast, then close in (Rat Pack). Yippers flank.
class Pack extends Verb:
	var slot := 0
	func setup() -> void: slot = Root.spawnManager.joinPack(g)
	func move(delta: float, car: Node2D) -> void:
		if GoonVerbs.bearingDown(car, g.global_position, 230.0, 280.0):
			g.setState(&"flee")
			return
		var target := car.global_position
		if g.def.get("flank", false):
			var s := 1.0 if slot % 2 == 0 else -1.0
			target += car.transform.y * s * 150.0 - car.transform.x * (60.0 if slot < 2 else 180.0)
		var mates: Array = Root.spawnManager.packMates(g)
		if mates.size() > 1:
			var c := Vector2.ZERO
			var sep := Vector2.ZERO
			for o in mates:
				c += o.global_position
				var d: Vector2 = g.global_position - o.global_position
				if o != g && d.length() < 22.0 && d.length() > 0.01: sep += d.normalized()
			target = target.lerp(c / mates.size(), 0.35) + sep * 40.0
		g.chase(target, g.speedNow(), delta, 10.0)
		if g.cooldown <= 0.0 && g.distTo(car) < g.windDist: startWindup(car, 0.1)
	func other(delta: float, car: Node2D) -> void:
		if g.state == &"flee":
			var away := (g.global_position - car.global_position).normalized()
			g.chase(g.global_position + away * 60.0, g.speedNow() * 1.6, delta, 14.0)
			if g.stateTime > 0.8: g.setState(&"move")

#==================================================================================================
## Tucks into a ball and rolls straight at you. Rolling it's a rock; afterwards it's dizzy (Boulder).
class Roller extends Verb:
	const ROLL_SPEED := 470.0
	const ROLL_TIME := 1.3
	func windup(delta: float, car: Node2D) -> void:
		g.faceTo(g.lockDir.angle(), delta, 12.0)
		if g.stateTime >= g.windT:
			g.setState(&"roll")
			g.play(&"special")
			g.invulnerable = true
	func startWindup(car: Node2D, lead := 0.15) -> void:
		super.startWindup(car, lead)
	func telegraphRadius() -> float: return ROLL_SPEED * ROLL_TIME
	func other(_delta: float, car: Node2D) -> void:
		if g.state != &"roll": return
		g.velocity = g.lockDir * ROLL_SPEED
		g.move_and_slide()
		var hit := false
		for i in g.get_slide_collision_count():
			var c = g.get_slide_collision(i).get_collider()
			if c == car:
				g.bounceCar(car, g.attackDamage, "hull", "ROCK")
				hit = true
			elif c is StaticBody2D || c is TileMap: hit = true
		if hit || g.stateTime > ROLL_TIME:
			g.invulnerable = false
			stunFor(1.6)
	func onResist(car: Node2D, speed: float) -> void:
		if g.state == &"roll": g.bounceCar(car, g.attackDamage, "hull", "ROCK")
		else: super.onResist(car, speed)

#==================================================================================================
## Raises a sledgehammer and slams the ground ahead; the hammer sticks afterwards (Wrecker).
class Slammer extends Verb:
	const RING := 85.0
	func startWindup(car: Node2D, _lead := 0.0) -> void:
		g.lockDir = (car.global_position - g.global_position).normalized()
		g.lockPos = g.global_position + g.lockDir * 70.0
		g.setState(&"windup")
		g.play(&"windup", g.windT)
		g.telegraph("crack", g.windT, RING)
	func beginAttack() -> void:
		g.setState(&"slam")
		g.play(&"attack", 0.25)
		g.hitDone = false
	func other(_delta: float, car: Node2D) -> void:
		match g.state:
			&"slam":
				if g.stateTime >= 0.25 && not g.hitDone:
					g.hitDone = true
					g.fx().ring(g.lockPos, RING)
					if car.global_position.distance_to(g.lockPos) < RING + 40.0: g.hitCar(car, g.attackDamage, g.sys)
				if g.stateTime >= 0.25: g.sprite.pause()
				if g.stateTime >= 1.35:
					g.setState(&"move")
					g.cooldown = 1.6

#==================================================================================================
## Charges in a long straight line it can't turn out of; head-on it's armoured. Stunned after (Rammer, Tusker).
class Charger extends Verb:
	func frontArmorActive() -> bool: return g.state == &"attack"
	func startWindup(car: Node2D, lead := 0.15) -> void:
		super.startWindup(car, lead)
	func telegraphRadius() -> float: return g.speed * g.lunge * g.atkT
	func attack(delta: float, car: Node2D) -> void:
		g.velocity = g.lockDir * g.speedNow() * g.lunge
		g.move_and_slide()
		g.walkAnim(g.speedNow() * g.lunge)
		for i in g.get_slide_collision_count():
			if g.get_slide_collision(i).get_collider() == car && not g.hitDone:
				g.hitDone = true
				g.hitCar(car, g.attackDamage, g.sys)
		if g.stateTime >= g.atkT: stunFor(g.recT)
	func onResist(car: Node2D, speed: float) -> void:
		if g.state == &"attack":
			g.bounceCar(car, g.attackDamage, g.sys, "HEAD-ON")
			stunFor(1.2)
		else: super.onResist(car, speed)

#==================================================================================================
## Moves in hops; in the air it can't be hit, so time it for the landing (Jackalope).
class Hopper extends Verb:
	var hopDir := Vector2.RIGHT
	func move(delta: float, car: Node2D) -> void:
		g.play(&"idle")
		if g.stateTime < 0.25: return
		if g.cooldown <= 0.0 && g.distTo(car) < g.windDist:
			startWindup(car, 0.1)
			return
		var to := (car.global_position - g.global_position).angle() + randf_range(-0.7, 0.7)
		hopDir = Vector2.from_angle(to)
		g.rotation = to
		g.setState(&"hop")
		g.play(&"special", 0.45)
		g.setSolid(false)
		g.invulnerable = true
	func other(delta: float, _car: Node2D) -> void:
		if g.state == &"hop":
			g.global_position += hopDir * g.speedNow() * 1.6 * delta
			if g.stateTime >= 0.45:
				g.setSolid(true)
				g.invulnerable = false
				g.setState(&"move")

#==================================================================================================
## Steals pickups and runs; crush it to get them back with interest (Bandit).
class Thief extends Verb:
	var target: Node2D = null
	var stolen: Array = []
	var lookT := 0.0
	func move(delta: float, car: Node2D) -> void:
		lookT -= delta
		if lookT <= 0.0:
			lookT = 0.5
			target = null
			var best := 600.0
			for p in g.get_tree().get_nodes_in_group("pickup"):
				var d: float = g.global_position.distance_to(p.global_position)
				if d < best && not p.is_queued_for_deletion():
					best = d
					target = p
		if is_instance_valid(target):
			g.chase(target.global_position, g.speedNow(), delta)
			if g.global_position.distance_to(target.global_position) < 24.0:
				stolen.push_back({"scene": target.scene_file_path})
				target.queue_free()
				target = null
				g.fx().label(g.global_position, "STOLEN")
				g.setState(&"flee")
			return
		#nothing to steal: hang about at a cheeky distance
		var to := car.global_position - g.global_position
		var want := to.normalized() * (1.0 if to.length() > 260.0 else -1.0)
		g.chase(g.global_position + want * 60.0, g.speedNow() * 0.8, delta)
	func other(delta: float, car: Node2D) -> void:
		if g.state == &"flee":
			var away := (g.global_position - car.global_position).normalized()
			g.chase(g.global_position + away * 60.0, g.speedNow() * 1.25, delta, 8.0)
			if g.stateTime > 6.0: g.setState(&"move")
	func onDeath(cause: StringName) -> void:
		if cause == &"drown" || stolen.is_empty(): return
		for i in stolen.size():
			var s: String = stolen[i].scene
			if s != "": g.fx().dropAt(g.global_position + Vector2.from_angle(i * 2.1) * 30.0, s)
		g.fx().dropLater(g.global_position, g.powerupDropDict) #interest
		g.fx().label(g.global_position, "RECOVERED")

#==================================================================================================
## Stops at its reach and strikes; a ring shows the reach (Stinger, Rattler).
class Striker extends Verb:
	func telegraphRadius() -> float: return g.windDist
	func move(delta: float, car: Node2D) -> void:
		if g.distTo(car) > g.windDist * 0.9: g.chase(car.global_position, g.speedNow(), delta)
		else: g.faceTo((car.global_position - g.global_position).angle(), delta)
		if g.cooldown <= 0.0 && g.distTo(car) < g.windDist: startWindup(car, 0.0)
	func attack(_delta: float, car: Node2D) -> void:
		if not g.hitDone && g.stateTime >= g.atkT * 0.5:
			g.hitDone = true
			if g.distTo(car) < g.windDist + 30.0: g.hitCar(car, g.attackDamage, g.sys)
		if g.stateTime >= g.atkT: endAttack()

#==================================================================================================
## Bristles and fires a ring of quills; crushing it slowly costs your tyres (Quill).
class Spiky extends Verb:
	func telegraphRadius() -> float: return 200.0
	func windup(_delta: float, _car: Node2D) -> void:
		if g.stateTime >= g.windT:
			for i in 8:
				var dir := Vector2.from_angle(i * TAU / 8.0 + g.rotation)
				g.fx().shoot(g.global_position + dir * g.bodyRadius, dir, 420.0, 0.6, g.attackDamage, g.sys, "quill")
			g.setState(&"recover")
			g.cooldown = 3.0
	func beforeCrush(car: Node2D, speed: float) -> void:
		if speed < 300.0 && car.has_method("wearSystem"):
			car.wearSystem("tires", 12.0)
			g.fx().label(g.global_position, "OUCH")

#==================================================================================================
## Circles overhead, out of reach; swoops at your lights, and lands to feed on crushed goons (Buzzard).
class Flyer extends Verb:
	var orbit := randf() * TAU
	var shadow: Sprite2D
	func setup() -> void:
		g.setSolid(false)
		g.invulnerable = true
		shadow = Sprite2D.new()
		shadow.texture = Walker.EYE_TEXTURE
		shadow.modulate = Color(0, 0, 0, 0.35)
		shadow.scale = Vector2(3.4, 2.2)
		shadow.top_level = true
		shadow.z_index = -1
		g.add_child(shadow)
	func flying() -> bool: return g.state != &"feed" && g.state != &"dive"
	func tick(delta: float, car: Node2D) -> void:
		super.tick(delta, car)
		if is_instance_valid(shadow): shadow.global_position = g.global_position + (Vector2(16, 24) if flying() else Vector2(3, 4))
	func move(delta: float, car: Node2D) -> void:
		var decal = g.fx().nearestDecal(g.global_position, 500.0) if g.cooldown <= 0.0 else null
		if decal != null && g.distTo(car) > 260.0:
			g.chase(decal, g.speedNow(), delta, 4.0)
			if g.global_position.distance_to(decal) < 12.0:
				g.setState(&"feed")
				g.setSolid(true)
				g.invulnerable = false
			return
		orbit += delta * 0.8
		g.chase(car.global_position + Vector2.from_angle(orbit) * 260.0, g.speedNow(), delta, 3.0)
		g.play(&"walk")
		if g.cooldown <= 0.0 && g.distTo(car) < g.windDist: startWindup(car, 0.5)
	func telegraphRadius() -> float: return 40.0
	func beginAttack() -> void:
		g.setState(&"dive")
		g.play(&"attack", g.atkT)
		g.hitDone = false
		g.setSolid(true)
		g.invulnerable = false
	func other(delta: float, car: Node2D) -> void:
		match g.state:
			&"dive":
				g.lungeStep(car, g.speedNow() * g.lunge, delta)
				if g.stateTime >= g.atkT:
					g.setSolid(false)
					g.invulnerable = true
					g.setState(&"move")
					g.cooldown = 3.0
			&"feed":
				g.play(&"special")
				if g.stateTime > 3.5 || GoonVerbs.bearingDown(car, g.global_position, 160.0, 200.0):
					g.setSolid(false)
					g.invulnerable = true
					g.setState(&"move")
					g.cooldown = 2.0

#==================================================================================================
## A herd that stampedes across your path, ignoring you; heavy, so hit it fast (Thunderhoof).
class Herd extends Verb:
	var dir := Vector2.RIGHT
	var hitT := 0.0
	func setup() -> void:
		Root.spawnManager.joinPack(g)
		var car = Root.playerCar
		if is_instance_valid(car): dir = herdDirection(car)
	func herdDirection(car: Node2D) -> Vector2:
		#the first of a herd picks the line; the rest follow it
		for o in Root.spawnManager.packMates(g):
			if o != g && o.verb is Herd: return o.verb.dir
		var cross: Vector2 = car.global_position + car.velocity * 1.5 - g.global_position
		return cross.normalized() if cross.length() > 1.0 else Vector2.RIGHT
	func move(delta: float, car: Node2D) -> void:
		hitT = maxf(0.0, hitT - delta)
		g.faceTo(dir.angle(), delta, 3.0)
		g.advance(Vector2.from_angle(g.rotation) * g.speedNow() + dir.orthogonal() * sin(g.stateTime * 3.0 + g.packId) * 20.0, delta)
		g.walkAnim(g.speedNow())
		for i in g.get_slide_collision_count():
			if g.get_slide_collision(i).get_collider() == car && hitT <= 0.0:
				hitT = 0.6
				g.hitCar(car, g.attackDamage, g.sys)
		if g.distTo(car) > 1600.0 && dir.dot(car.global_position - g.global_position) < 0.0:
			dir = (car.global_position + car.velocity * 1.5 - g.global_position).normalized()
	func onResist(car: Node2D, _speed: float) -> void:
		g.bounceCar(car, g.attackDamage, g.sys, "STAMPEDE")
	func onTouch(_car: Node2D) -> void: pass #a stampede doesn't stop for you

#==================================================================================================
## The Scrap Gang: anything with wheels. Drives like a car (turn rate, acceleration) and does its act:
## ram, swipe, tailgate, burn, oil, harpoon, bomb, boost, saw, shoot or magnet. Head-on it's armoured
## (front); T-bone it. docs/GOONS.md lists what each act does.
class Rider extends Verb:
	const ACCEL := 320.0
	var act := "ram"
	var v := 0.0
	var side := 1.0 if randf() < 0.5 else -1.0
	var dropT := 0.0
	var stuckT := 0.0
	var tetherT := 0.0
	func setup() -> void:
		act = g.def.get("act", "ram")
		v = g.speed * 0.6

	func drive(target: Vector2, topSpeed: float, delta: float) -> void:
		v = move_toward(v, topSpeed, ACCEL * delta)
		var rate := 2.6 * clampf(v / 150.0, 0.3, 1.0)
		g.faceTo((target - g.global_position).angle(), delta, rate)
		g.advance(Vector2.from_angle(g.rotation) * v, delta)
		g.walkAnim(v)
		#wedged against a wall: back off at an angle
		if v > 100.0 && g.get_real_velocity().length() < 30.0 && Root.spawnManager.needsFullPhysics(g.global_position):
			stuckT += delta
			if stuckT > 0.5:
				stuckT = 0.0
				g.rotation += PI * 0.66
				v = 60.0
		else: stuckT = 0.0

	func telegraphRadius() -> float: return 600.0 * 1.2 if act == "boost" else g.speed * 1.35 * 0.8

	func move(delta: float, car: Node2D) -> void:
		var cpos := car.global_position
		var fwd: Vector2 = car.transform.x
		var lat: Vector2 = car.transform.y
		var d := g.distTo(car)
		match act:
			"ram", "saw":
				var target := g.predict(car, 0.35)
				if act == "saw": target += (target - g.global_position).orthogonal().normalized() * sin(g.stateTime * 4.0) * 60.0
				drive(target, g.speedNow(), delta)
				var aligned := absf(angle_difference(g.rotation, (cpos - g.global_position).angle())) < 0.35
				if g.cooldown <= 0.0 && d < (260.0 if act == "ram" else 70.0) && (aligned || act == "saw"):
					if act == "ram": startWindup(car, 0.2)
					else: beginAttack()
			"swipe":
				side = signf(lat.dot(g.global_position - cpos)) if absf(lat.dot(g.global_position - cpos)) > 20.0 else side
				drive(cpos + lat * side * 75.0 + fwd * car.velocity.length() * 0.25, g.speedNow(), delta)
				if g.cooldown <= 0.0 && d < 130.0: beginAttack()
			"tailgate":
				drive(cpos - fwd * 110.0, g.speedNow(), delta)
				if g.cooldown <= 0.0 && d < 130.0 && fwd.dot(g.global_position - cpos) < 0.0: beginAttack()
			"burn", "oil":
				drive(cpos + fwd * 360.0 + lat * side * 30.0, g.speedNow() * 1.1, delta)
				if g.cooldown <= 0.0 && fwd.dot(g.global_position - cpos) > 150.0 && d < 450.0:
					g.setState(&"drop")
					g.play(&"special")
			"harpoon", "shoot", "bomb":
				var r: Array = g.def.get("range", [280, 360])
				var want := (cpos - g.global_position).normalized()
				var orbitDir := want.orthogonal() * side
				var target := g.global_position + (want if d > r[1] else (-want if d < r[0] else orbitDir)) * 120.0
				drive(target, g.speedNow() * (0.3 if act == "shoot" && d < r[1] else 1.0), delta)
				if g.cooldown <= 0.0 && d < r[1] + 80.0: startWindup(car, 0.8 if act == "bomb" else 0.4)
			"boost":
				drive(cpos, g.speedNow(), delta)
				if g.cooldown <= 0.0 && d < 380.0: startWindup(car, 0.3)
			"magnet":
				drive(cpos - fwd * 300.0 + lat * side * 150.0, g.speedNow(), delta)
				if g.cooldown <= 0.0 && d < 420.0:
					g.setState(&"windup")
					g.play(&"windup", 0.8)
					g.telegraph("beam", 0.8, 0.0)

	func startWindup(car: Node2D, lead := 0.25) -> void:
		g.lockOn(car, lead)
		g.setState(&"windup")
		g.play(&"windup", g.windT)
		match act:
			"harpoon", "shoot": g.telegraph("aim", g.windT, 0.0)
			"bomb": g.telegraph("land", g.windT, 90.0)
			_: g.telegraph("arrow", g.windT, telegraphRadius())

	func windup(delta: float, car: Node2D) -> void:
		v = move_toward(v, 0.0, ACCEL * 2.0 * delta)
		g.faceTo((g.lockPos - g.global_position).angle() if act != "magnet" else (car.global_position - g.global_position).angle(), delta, 3.0)
		var t := 0.8 if act == "magnet" else g.windT
		if g.stateTime < t: return
		match act:
			"harpoon": g.fx().harpoon(g, Vector2.from_angle(g.rotation))
			"shoot": g.fx().shoot(g.global_position + Vector2.from_angle(g.rotation) * g.bodyRadius * 1.6, Vector2.from_angle(g.rotation), 650.0, 1.4, g.attackDamage, g.sys, "bolt")
			"bomb": g.fx().lob(g.global_position, g.lockPos, 0.8, "bomb")
			"magnet":
				g.setState(&"pull")
				g.play(&"special")
				g.fx().tether(g, 2.5, "magnet")
				return
			_:
				beginAttack()
				if act == "boost": g.play(&"special")
				return
		g.setState(&"recover")
		g.recT = 0.3
		g.cooldown = g.def.get("cd", 2.4)

	func beginAttack() -> void:
		super.beginAttack()
		g.play(&"attack", 0.5)

	func attack(delta: float, car: Node2D) -> void:
		match act:
			"ram", "boost":
				var spd := 600.0 if act == "boost" else g.speedNow() * 1.35
				g.velocity = g.lockDir * spd
				g.move_and_slide()
				for i in g.get_slide_collision_count():
					var c = g.get_slide_collision(i).get_collider()
					if act == "boost" && (c == car || c is StaticBody2D || c is TileMap):
						boom()
						return
					if c == car && not g.hitDone:
						g.hitDone = true
						g.hitCar(car, g.attackDamage, g.sys)
						peelOff() #a ram is one hit, not a shove
						return
				if g.stateTime >= (1.2 if act == "boost" else 0.8):
					if act == "boost": boom()
					else: peelOff()
			"swipe", "saw", "tailgate":
				drive(car.global_position, g.speedNow(), delta)
				if not g.hitDone && g.distTo(car) < 125.0:
					g.hitDone = true
					g.hitCar(car, g.attackDamage, g.sys)
					if act == "tailgate": car.velocity += car.transform.x * 60.0
				if g.stateTime >= 0.5: peelOff()

	func boom() -> void:
		g.fx().blast(g.global_position, g.def.get("blast", 110.0), g.attackDamage)
		g.destroy(&"self")

	func peelOff() -> void:
		g.setState(&"recover")
		g.recT = 1.2 if act == "swipe" || act == "tailgate" else 1.0
		g.cooldown = 2.0
		side = -side

	func tick(delta: float, car: Node2D) -> void:
		if g.state == &"recover":
			#drives away rather than standing still
			#swipers and tailgaters coast after their hit: that's the window to T-bone them
			var coast := 0.5 if act == "swipe" || act == "tailgate" else 0.8
			drive(g.global_position + Vector2.from_angle(g.rotation + 0.6 * side) * 200.0, g.speedNow() * coast, delta)
			if g.stateTime >= g.recT: g.setState(&"move")
			return
		super.tick(delta, car)

	func other(delta: float, car: Node2D) -> void:
		match g.state:
			&"drop":
				var fwd: Vector2 = car.transform.x
				drive(car.global_position + fwd * 360.0, g.speedNow() * 1.1, delta)
				dropT -= delta
				if dropT <= 0.0:
					dropT = 0.12 if act == "burn" else 0.25
					var behind := g.global_position - Vector2.from_angle(g.rotation) * g.bodyRadius * 1.6
					if act == "burn": g.fx().addHazard("fire", behind, 34.0, 3.0)
					else: g.fx().addHazard("oil", behind, 44.0, 8.0)
				if g.stateTime > (1.2 if act == "burn" else 1.5):
					g.setState(&"move")
					g.cooldown = 4.0
			&"pull":
				drive(g.global_position + Vector2.from_angle(g.rotation + PI) * 100.0, g.speedNow() * 0.4, delta)
				if g.stateTime > 2.5 || g.distTo(car) > 600.0:
					g.setState(&"move")
					g.cooldown = 4.0

	func onResist(car: Node2D, speed: float) -> void:
		g.bounceCar(car, g.attackDamage * 0.5 + 2.0, "engine", "PLOW" if g.frontArmor > 9000.0 else "HEAD-ON")
		v *= 0.3
		peelOff() #back away, or the car keeps taking contact damage every tick
	func onTouch(_car: Node2D) -> void:
		if g.state == &"move" || g.state == &"drop" || g.state == &"pull": peelOff()
	func onDeath(cause: StringName) -> void:
		if act == "boost" && cause == &"crush": g.fx().blastLater(g.global_position, 0.25, g.def.get("blast", 110.0), g.attackDamage)
