class_name CleanFeed

#What the picture shows besides the game: the capture kit's clean feed, and photo mode's (docs/PROMO.md).
#  full:    the HUD as the player sees it
#  minimal: the dials and the visors (no version, mirror with its clock and goal, objective, toasts or key hints)
#  off:     no HUD at all; screens that open later (a prize game, the results) still show
#Applied to a run's HUD once it is ready; `restore` puts back what `apply` hid.

const HIDDEN := &"cleanFeedHidden"
const MINIMAL_HIDES := ["VersionTracker", "Mirror", "TopCenter", "Objective"]

static func apply(ui: CanvasLayer, mode: String) -> void:
	if not is_instance_valid(ui): return
	restore(ui)
	if mode == "full": return
	for child in ui.get_children():
		if mode == "off" || child.name in MINIMAL_HIDES || child is HudChance: conceal(child)
	if mode == "minimal":
		for hint in ui.find_children("*", "KeyHint", true, false): conceal(hint)

static func restore(ui: CanvasLayer) -> void:
	if not is_instance_valid(ui): return
	for node in ui.find_children("*", "", true, false):
		if not node.has_meta(HIDDEN): continue
		if node is CanvasItem: node.visibility_layer = node.get_meta(HIDDEN)
		else: node.visible = true
		node.remove_meta(HIDDEN)

#A widget is taken out of the picture by its visibility layer, not `visible` or `modulate`: HUD widgets show,
#hide and flash themselves as the run goes on, and none of that brings one back. A CanvasLayer (the start
#lamps, the toasts) has only `visible`. Anything else (an AnimationPlayer) has nothing to hide.
static func conceal(node: Node) -> void:
	if node.has_meta(HIDDEN): return
	if node is CanvasItem:
		node.set_meta(HIDDEN, node.visibility_layer)
		node.visibility_layer = 0
	elif node is CanvasLayer && node.visible:
		node.set_meta(HIDDEN, true)
		node.visible = false

static func isConcealed(node: Node) -> bool:
	return node.has_meta(HIDDEN)

#the things round the picture that are never part of it: the F3 overlay and the pointer
static func quiet() -> void:
	Settings.set_value("display/perf_overlay", 0, false)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
