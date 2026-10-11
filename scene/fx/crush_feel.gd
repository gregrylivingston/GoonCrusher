class_name CrushFeel extends Node
## The weight of a crush (docs/GOONS.md, "Crush feel"). The player's car owns one, and its crushGoon calls
## onCrush; kills it set off (blasts, shells, drownings: SpawnManager.creditCrush) call onIndirect.
##   - the camera: trauma shake (squared, so small crushes barely move it and crowds and giants hit hard),
##     a kick along the car's heading and a zoom punch on giants. Screen Shake and Reduce Motion scale it;
##     it shares Camera2D.offset with Juice.rumble and stands aside while a rumble runs.
##   - hit-stop: Engine.time_scale dips for a few hundredths of a second on giants and the third goon
##     of a crowd (once a crowd, and a crowd's waits HIT_STOP_COOLDOWN after the last stop), and for a longer
##     beat of slow motion on a boss and on the MEGA_CRUSH-th goon of a crowd. A pause or a
##     menu (a pickup event, the slot machine) ends it at once, so nothing that pops up runs slowed.
##     The Hit-Stop setting; never under the harnesses, Transition.instant().
##   - a crush tick that rises in pitch with the Crush Combo, a thud and rumble for giants.
##   - the crush bonuses: a multi-crush, a drift crush, giant slayer and boss crush pay coins here,
##     at once; labels and sounds are only for show. A new best combo for the car is announced once a run.

const TRAUMA_GOON := 0.13
const TRAUMA_GIANT := 0.55
const TRAUMA_BOSS := 0.75
const TRAUMA_INDIRECT := 0.05
const TRAUMA_DECAY := 1.6     #per second
const SHAKE_PX := 46.0        #camera offset (world px) at full trauma: about 20 screen px at the usual zoom
const KICK_PX := 12.0         #a crush shoves the view this far along the heading, then it springs back
const KICK_RETURN := 0.0004   #share of the kick left after a second
const ZOOM_PUNCH := 0.035     #a giant pushes the zoom in this much; updateCameraZoom eases it back
const HIT_STOP_GIANT := [0.045, 0.1] #[real seconds, time scale]
const HIT_STOP_BOSS := [0.3, 0.2]   #a boss gets a real beat of slow motion...
const HIT_STOP_MEGA := [0.18, 0.25] #...and so does the MEGA_CRUSH-th goon of a crowd
const MEGA_CRUSH := 5
const HEAT_TRAUMA := 0.5      #share of extra shake per crush at full heat (Fx.heat: the Crush Combo)
const FLASH_GIANT := 0.25     #screen flash (ScreenFx.flash)
const FLASH_BOSS := 0.45
const HIT_STOP_MULTI := [0.025, 0.3] #a light catch on the third goon of a crowd, once per crowd
const HIT_STOP_COOLDOWN := 0.6 #real seconds after a stop before a crowd may stop time again
const GIANT_SPEED_KEEP := 0.9 #a giant is heavy: the car keeps this much of its speed through it

const MULTI_TICKS := 9        #crushes this close together (physics ticks) make one multi-crush
const MULTI_COINS := 2        #per goon past the first
const DRIFT_ANGLE := 0.4      #rad between heading and travel for a drift crush
const DRIFT_SPEED := 260.0
const DRIFT_COINS := 1
const SLAM_COINS := 2         #a goon swatted by the car's side or tail (OverheadCarBody2D.slamGoons)
const DRIFT_LABEL_TICKS := 30 #drift crushes always pay; the label shows at most this often
const GIANT_COINS := 5
const BOSS_COINS := 10
const RECORD_MIN := 5         #a best combo below this isn't worth announcing when it is beaten
const MULTI_NAMES := ["", "", "DOUBLE CRUSH", "TRIPLE CRUSH", "QUAD CRUSH"]

var car: Node2D
var camera: Camera2D
var trauma := 0.0
var kick := Vector2.ZERO
var applied := Vector2.ZERO   #what this node last added to camera.offset
var noiseT := 0.0
var multi := 0
var multiTick := -1000
var multiPos := Vector2.ZERO
var driftLabelTick := -1000
var comboRecord := 0          #the car's saved best combo when the run began
var recordShown := false
var stopUntil := 0            #Time.get_ticks_msec() when the current hit-stop ends

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS #to end a hit-stop the moment the game pauses
	car = get_parent()
	camera = car.get_node_or_null("Camera2D")
	for saved in SaveManager.playerData.cars:
		if saved.name == car.carId: comboRecord = saved.records.get("combo", 0)

func _exit_tree() -> void:
	if stopUntil > 0: Engine.time_scale = 1.0

#--- crushes --------------------------------------------------------------------------------------

## The car crushed `goon` at `speed` (px/s). Called after the crush is credited and the combo counted.
func onCrush(goon: Node2D, speed: float) -> void:
	var giant: bool = goon.get("isGiant") == true
	var goonDef = goon.get("def")
	var boss: bool = goonDef is Dictionary && goonDef.get("verb", &"") == &"boss"
	var pos := goon.global_position
	var heading := Vector2.from_angle(car.rotation)
	countMulti(pos)
	Transition.sound("pop", -15.0, 0.85 + 0.05 * mini(car.comboCount, 16)) #rises with the combo
	var slam: Vector2 = car.crushHitVel
	if slam != Vector2.ZERO:
		kick += slam.normalized() * KICK_PX * 1.5
		addTrauma(TRAUMA_GOON)
		car.reward("coin", SLAM_COINS)
		var tail: bool = car.to_local(pos).x < car.bodyRect.get_center().x - 20.0
		label(pos, ("TAIL SLAM  +%d" if tail else "SIDE SLAM  +%d") % SLAM_COINS, 22, HudTheme.GOLD)
	if giant || boss:
		addTrauma(TRAUMA_BOSS if boss else TRAUMA_GIANT)
		kick += heading * KICK_PX * 2.5
		hitStop(HIT_STOP_BOSS if boss else HIT_STOP_GIANT, false)
		if shakeAmount() > 0.0 && is_instance_valid(camera): camera.zoom *= 1.0 + ZOOM_PUNCH
		car.velocity *= GIANT_SPEED_KEEP
		Transition.sound("thud", -3.0, 0.65 if boss else 0.8)
		Settings.vibrate(0.8, 1.0, 0.25)
		var fx := Fx.current()
		if fx: fx.screen.flash(FLASH_BOSS if boss else FLASH_GIANT)
		var coins := BOSS_COINS if boss else GIANT_COINS
		car.reward("coin", coins)
		label(pos, ("BOSS CRUSHED  +%d" if boss else "GIANT SLAIN  +%d") % coins, 30, HudTheme.GOLD)
	else:
		addTrauma(TRAUMA_GOON * clampf(speed / 500.0, 0.6, 1.3) * (1.0 + HEAT_TRAUMA * Fx.heatNow()))
		kick += heading * KICK_PX
	var slip := absf(angle_difference(car.velocity.angle(), car.rotation))
	if slam == Vector2.ZERO && speed >= DRIFT_SPEED && slip > DRIFT_ANGLE && slip < PI - 0.6: #sliding, not reversing
		car.reward("coin", DRIFT_COINS)
		var now := Engine.get_physics_frames()
		if now - driftLabelTick >= DRIFT_LABEL_TICKS:
			driftLabelTick = now
			label(pos + Vector2(0, -26), "DRIFT CRUSH  +%d" % DRIFT_COINS, 20, HudTheme.GOLD)
	if not recordShown && comboRecord >= RECORD_MIN && car.comboCount > comboRecord:
		recordShown = true
		if is_instance_valid(HudChance.current): HudChance.current.toast("NEW BEST COMBO", HudTheme.GOLD)

## A goon the car's doing killed some other way (a blast, a kicked shell, a drowning)
func onIndirect(pos: Vector2) -> void:
	addTrauma(TRAUMA_INDIRECT)
	countMulti(pos)

## Crushes within MULTI_TICKS of each other add up; the third one onwards stops time for a moment.
## The bonus is paid when the chain ends (_physics_process), with one label for the whole crowd.
func countMulti(pos: Vector2) -> void:
	var now := Engine.get_physics_frames()
	if now - multiTick > MULTI_TICKS: payMulti()
	multi += 1
	multiTick = now
	multiPos = pos
	if multi == 3:
		hitStop(HIT_STOP_MULTI, true)
		addTrauma(0.08)
	elif multi == MEGA_CRUSH:
		hitStop(HIT_STOP_MEGA, false)
		addTrauma(0.2)

func payMulti() -> void:
	if multi >= 2:
		var coins := (multi - 1) * MULTI_COINS
		car.reward("coin", coins)
		var text: String = MULTI_NAMES[multi] if multi < MULTI_NAMES.size() else "MEGA CRUSH x%d" % multi
		label(multiPos, "%s  +%d" % [text, coins], mini(22 + 3 * multi, 40), HudTheme.GOLD)
		if multi >= 3: Transition.sound("clank", -8.0, 1.2)
	multi = 0

func _physics_process(_delta: float) -> void:
	if get_tree().paused: return #this node runs while paused only to end a hit-stop
	if multi > 0 && Engine.get_physics_frames() - multiTick > MULTI_TICKS: payMulti()

func label(pos: Vector2, text: String, size: int, col: Color) -> void:
	if is_instance_valid(Root.spawnManager) && Root.spawnManager.fx: Root.spawnManager.fx.label(pos, text, size, col)

#--- the camera -----------------------------------------------------------------------------------

## 0 with Reduce Motion, Screen Shake Off or under the harnesses; 0.5 for Low; 1 for Full
func shakeAmount() -> float:
	if Settings.reduce_motion() || Transition.instant(): return 0.0
	return [0.0, 0.5, 1.0][Settings.get_value("access/screen_shake")]

func addTrauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func _process(delta: float) -> void:
	#the timer that ends a stop runs on the (smoothed) frame delta and can fire a few ms early, when
	#endHitStop leaves it; without this the game stayed in slow motion for good
	if Engine.time_scale != 1.0 && stopUntil > 0 && Time.get_ticks_msec() >= stopUntil: endHitStop(true)
	if get_tree().paused || Settings.menu_open:
		if stopUntil > Time.get_ticks_msec(): endHitStop(true)
		return
	if not is_instance_valid(camera): return
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	kick *= pow(KICK_RETURN, delta)
	if kick.length_squared() < 0.04: kick = Vector2.ZERO
	var want := Vector2.ZERO
	var amount := shakeAmount()
	if amount > 0.0 && (trauma > 0.0 || kick != Vector2.ZERO):
		noiseT += delta
		var t := noiseT
		var wobble := Vector2(sin(t * 61.0) + sin(t * 23.0 + 1.3), cos(t * 57.0) + sin(t * 31.0 + 0.4)) * 0.5
		want = (wobble * trauma * trauma * SHAKE_PX + kick) * amount
	#Juice.rumble (a wreck, the Goon Nuke) owns the offset while it runs and puts back what it found
	if want == applied || camera.has_meta("juiceRumbleHome"): return
	camera.offset += want - applied
	applied = want

## A few hundredths of a second of slow motion: `stop` is [real seconds, time scale]. Never stacks: one
## already running wins. A crowd's (`crowd`) also waits HIT_STOP_COOLDOWN after the last stop ended.
func hitStop(stop: Array, crowd: bool) -> void:
	if not Settings.get_value("access/hit_stop") || Transition.instant() || get_tree().paused || Settings.menu_open: return
	var now := Time.get_ticks_msec()
	if now < stopUntil: return
	if crowd && now < stopUntil + int(HIT_STOP_COOLDOWN * 1000.0): return
	stopUntil = now + int(stop[0] * 1000.0)
	Engine.time_scale = stop[1]
	get_tree().create_timer(stop[0], true, false, true).timeout.connect(endHitStop) #real time: ignores the time scale

## `now`: cut it short (a pause or a menu), recording the end so the cooldown counts from here
func endHitStop(now := false) -> void:
	if not now && Time.get_ticks_msec() + 2 < stopUntil: return
	if now: stopUntil = Time.get_ticks_msec()
	Engine.time_scale = 1.0
