extends Node

#How often the Claw Crane pays, by the claw's strength: `Godot --headless --path . res://tests/prize_lab/claw_odds.tscn`.
#Each grab is dropped as the patrolling claw passes over a random prize on a fresh heap (no allowance for the
#stop or the swing) and played out at 60 frames a second; it prints the share of grabs that won something and
#the prizes per grab, for weak to strong claws. `--strength=<0..1>` runs one; `--trace` prints a few grabs.

var junkWon := 0
var GRABS := 50 if not OS.get_cmdline_user_args().has("--trace") else 6

func _ready() -> void:
	Unlocks.allOpen = true
	var only := Array(OS.get_cmdline_user_args()).filter(func(a): return a.begins_with("--strength="))
	for strength in ([float(only[0].get_slice("=", 1))] if not only.is_empty() else [0.2, 0.45, 0.7, 1.0]):
		var wins := 0
		var prizes := 0
		for g in GRABS:
			var n := grab(strength)
			if n > 0: wins += 1
			prizes += n
		print("CLAW_ODDS strength=%.2f won=%d%% prizes/grab=%.2f junk/grab=%.2f" % [strength, wins * 100 / GRABS, float(prizes) / GRABS, float(junkWon) / GRABS])
		junkWon = 0
	get_tree().quit()

## Prizes the claw holds (between its prongs, below its head)
func inClaw(claw: ClawCrane) -> int:
	var x := claw.clawXform()
	var n := 0
	for p in claw.prizes:
		var local: Vector2 = x.affine_inverse() * p.pos
		if absf(local.x) < 45.0 && local.y > 0.0 && local.y < 80.0: n += 1
	return n

func grab(strength: float) -> int:
	var claw := ClawCrane.new()
	for i in ClawCrane.PRIZES + ClawCrane.JUNK_COUNT:
		var id := "junk:bomb" if i < ClawCrane.JUNK_COUNT else ("coinstack" if i % 3 == 0 else ("jerry" if i % 3 == 1 else "nitro"))
		claw.addPrize(id, claw.freeSpot(ClawCrane.radiusOf(id)))
	claw.settle(1.5)
	claw.grabs = 99
	var target: float = claw.prizes.filter(func(p): return not ClawCrane.isJunk(p.id) && p.pos.x > ClawCrane.MIN_X && p.pos.x < ClawCrane.MAX_X).pick_random().pos.x
	var dt := 1.0 / 60.0
	claw.clawX = randf_range(ClawCrane.MIN_X, ClawCrane.MAX_X)
	for frame in 60 * 8:
		claw.tick(dt)
		if frame > 30 && absf(claw.tipX() - target) < 8.0: break
	claw.startDrop()
	var won := 0
	var last := ""
	for frame in 60 * 12:
		claw.tick(dt)
		if claw.phase != last:
			last = claw.phase
			if OS.get_cmdline_user_args().has("--trace"): print("  %s inClaw=%d tipY=%.0f x=%.0f prizes=%d won=%d" % [last, inClaw(claw), claw.tipY(), claw.tipX(), claw.prizes.size(), claw.won.size()])
		if claw.phase == "lift" && claw.t < dt * 1.5: #the grab's strength, fixed for the test
			claw.strength = strength
			claw.holdAngle = lerpf(ClawCrane.WEAK_ANGLE, ClawCrane.SHUT_ANGLE, strength)
		if claw.phase == "patrol": break
	won = claw.won.size()
	junkWon += claw.winnings.filter(func(w): return ClawCrane.isJunk(w.key)).size()
	for node in [claw.root, claw.card, claw.body, claw.stage, claw.info, claw.board]: node.free()
	claw.free()
	return won
