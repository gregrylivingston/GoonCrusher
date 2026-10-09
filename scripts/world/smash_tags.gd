class_name SmashTags extends Node2D
## Readable speed (R-12, docs/HUD.md "Smash tags"): a small tag over an interactive prop the car is heading at
## within SHOW_PX, giving the speed that smashes it in the player's units (Settings.speed_text: 100 px/s is
## 10 MPH). White, gold once the car is fast enough. The first time a save meets each kind, a one-line hint
## toasts (HudChance.toast, flag "smash_<id>" in meta.hints). Walls never get a tag: only HEROES do.
## PropReactions owns one; ChunkView registers props as they stream in (PropReactions.addHero) and they are
## forgotten with their chunk (PropReactions.forget). Unshaded, like goon telegraphs, so night never hides it.

## The interactive props that get a tag, and their first-meeting hint (%s is the smash speed)
const HEROES := {
	&"logpile": "Smash log piles at %s: the logs roll on",
	&"watertower": "Ram water towers at %s: the flood flattens goons",
	&"beehive": "Smash hives at %s: the bees hunt goons",
	&"crate": "Crates smash open at %s",
	&"barrel": "Barrels blow up at %s: mind the blast",
	&"billboard": "Billboards topple at %s onto the goons behind",
	&"crane": "Ram cranes at %s: the container drops",
	&"fence": "Fences smash at %s",
	&"haybale": "Hay bales smash at %s",
	&"hedge": "Hedges smash at %s",
	&"den": "Smash Bandit dens at %s: the stolen loot bursts out",
	&"burrow": "Burrows cave in at %s: flush the Jackalopes out",
}
const SHOW_PX := 700.0
const HEADING_DOT := 0.82  #the car's travel within about 35 degrees of the prop
const MIN_CAR_SPEED := 40.0
const MAX_SHOWN := 3       #the nearest ones, so a paddock of fences doesn't fill the screen
const FADE_RATE := 6.0     #alpha per second
const LIFT := Vector2(0.0, -78.0)
const SIZE := 17

var heroes: Array[Node2D] = []
var shownProps: Array[Node2D] = [] #tags on screen or fading
var shownAlpha := PackedFloat32Array()
var want: Array[Node2D] = []        #this frame's picks, reused
var wantD := PackedFloat32Array()

func _init() -> void:
	name = "SmashTags"
	top_level = true
	z_as_relative = false
	z_index = PropReactions.BITS_Z + 1 #over canopies and leaves
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded

func add(prop: Node2D) -> void:
	if HEROES.has(BreakableProp.propId(prop)) && not prop in heroes: heroes.push_back(prop)

func forget(prop: Node2D) -> void:
	heroes.erase(prop)
	var i := shownProps.find(prop)
	if i >= 0:
		shownProps.remove_at(i)
		shownAlpha.remove_at(i)

## The speed that smashes it now (a crane: the ram that drops its container), INF when spent
static func smashSpeed(prop: Node2D) -> float:
	if BreakableProp.propId(prop) == &"crane": return INF if prop.get_meta(&"spilled", false) else Spill.DROP_SPEED
	return BreakableProp.speedOf(prop)

## Whether the car at `carPos` moving at `vel` is heading at `at` within SHOW_PX
static func headingAt(carPos: Vector2, vel: Vector2, at: Vector2) -> bool:
	var to := at - carPos
	var d := to.length()
	if d > SHOW_PX || d < 1.0 || vel.length() < MIN_CAR_SPEED: return false
	return vel.normalized().dot(to / d) > HEADING_DOT

func _process(delta: float) -> void:
	var car = Root.playerCar
	want.clear()
	wantD.clear()
	if is_instance_valid(car) && car.is_inside_tree():
		var carPos: Vector2 = car.global_position
		var vel: Vector2 = car.velocity
		for i in range(heroes.size() - 1, -1, -1):
			var prop := heroes[i]
			if not is_instance_valid(prop) || not prop.is_inside_tree():
				heroes.remove_at(i)
				continue
			if not headingAt(carPos, vel, prop.global_position) || smashSpeed(prop) == INF: continue
			pick(prop, carPos.distance_squared_to(prop.global_position))
	for prop in want:
		if not prop in shownProps:
			shownProps.push_back(prop)
			shownAlpha.push_back(0.0)
			firstMeeting(prop)
	var busy := false
	for i in range(shownProps.size() - 1, -1, -1):
		var prop := shownProps[i]
		var target := 1.0 if prop in want && is_instance_valid(prop) else 0.0
		shownAlpha[i] = move_toward(shownAlpha[i], target, FADE_RATE * delta)
		if shownAlpha[i] <= 0.0 && target == 0.0:
			shownProps.remove_at(i)
			shownAlpha.remove_at(i)
		else: busy = true
	if busy || visible: queue_redraw()
	visible = busy

## Keeps the MAX_SHOWN nearest
func pick(prop: Node2D, d2: float) -> void:
	var at := want.size()
	while at > 0 && wantD[at - 1] > d2: at -= 1
	if at >= MAX_SHOWN: return
	want.insert(at, prop)
	wantD.insert(at, d2)
	if want.size() > MAX_SHOWN:
		want.resize(MAX_SHOWN)
		wantD.resize(MAX_SHOWN)

## The first tag of a kind this save has ever shown: a one-line hint
func firstMeeting(prop: Node2D) -> void:
	var id := BreakableProp.propId(prop)
	var data = SaveManager.playerData if SaveManager else null
	if data == null || not is_instance_valid(HudChance.current): return
	var hints: Dictionary = data.meta.get("hints", {})
	var key := "smash_" + String(id)
	if hints.get(key, false): return
	hints[key] = true
	data.meta["hints"] = hints
	SaveManager.save_character_data()
	HudChance.current.toast(HEROES[id] % Settings.speed_text(smashSpeed(prop)), HudTheme.TEXT)

func _draw() -> void:
	var car = Root.playerCar
	var speed: float = car.velocity.length() if is_instance_valid(car) else 0.0
	var font: Font = HudTheme.BOLD
	for i in shownProps.size():
		var prop := shownProps[i]
		if not is_instance_valid(prop): continue
		var smash := smashSpeed(prop)
		if smash == INF: continue
		var a := shownAlpha[i]
		var col: Color = HudTheme.GOLD if speed >= smash else Color.WHITE
		var at := prop.global_position + LIFT + Vector2(-90.0, 0.0)
		var text := Settings.speed_text(smash)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, SIZE, 6, Color(HudTheme.OUTLINE, 0.85 * a))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, SIZE, Color(col, a))
