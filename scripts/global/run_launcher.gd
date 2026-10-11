class_name RunLauncher

#Starts a run from wherever the player is: the menu's START (main2.startLevel) and the results ticket's Retry
#and Next (gameSummary). A run reads its level, mode and tier from the save (Level.readRun), so the caller
#selects them first (select), hands over the loadout (takeLoadout), then loads the level behind the shutter (start).

#---------- the loadout ----------
#Each of the car's two slots can start a run with a consumable, free once it is unlocked: a gadget for the
#Fire slot (Pickups.LOADOUT, kept in meta.records.loadout) and a boost for the Boost slot
#(Pickups.BOOST_LOADOUT, meta.records.boostLoadout).
const SLOTS := ["loadout", "boostLoadout"]

static func slotOptions(slot: String) -> Array:
	return Pickups.openLoadout(Pickups.LOADOUT if slot == "loadout" else Pickups.BOOST_LOADOUT) #only unlocked ones are offered

static func slotChoice(slot: String) -> String:
	var id: String = SaveManager.playerData.meta.get("records", {}).get(slot, "")
	return id if id in slotOptions(slot) else ""

## Hands the chosen gadget and boost to the run (the car takes both in _ready)
static func takeLoadout() -> void:
	Pickups.loadout = slotChoice("loadout")
	Pickups.boostLoadout = slotChoice("boostLoadout")

#---------- the run ----------

## The save's selection: what the next run plays, and what run setup shows
static func select(level: int, mode: int, tier: int) -> void:
	var data = SaveManager.playerData
	data.selectedLevel = clampi(level, 0, data.levels.size() - 1)
	data.gameMode = mode
	data.gameTier = ModeTiers.clampTier(tier)
	SaveManager.save_character_data()

static func levelName(index: int) -> String:
	var def := Levels.defAt(index)
	return def.displayName if def else str(SaveManager.playerData.levels[index].get("name", ""))

static func levelScene(index: int) -> String:
	var def := Levels.defAt(index)
	return def.scenePath() if def else str(SaveManager.playerData.levels[index].get("scene", ""))

static var loading := false

## Loads the level at `path` on a worker thread behind the shutter, which shows `label` and lights its lamps
## with load progress; the level rolls it up once its world is built (Level.revealRun). `host` is any node in
## the tree. The tree may be paused (the results ticket pauses the run it follows).
static func start(host: Node, path: String, label: String) -> void:
	if loading: return
	loading = true
	var tree := host.get_tree()
	Region.resetRegions()
	SaveManager.flush()
	var door = Transition.close(label, "LOADING", 0.0)
	ResourceLoader.load_threaded_request(path)
	var carScene = Root.selectedCar.scene #the menu only loaded the car's CarInfo; levelRoot instantiates the scene
	if not ResourceLoader.has_cached(carScene): ResourceLoader.load_threaded_request(carScene)
	var progress = []
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			|| ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty() && is_instance_valid(door): door.progress = maxf(door.progress, progress[0] * 0.5)
		await tree.process_frame
	if ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_LOADED:
		Root.selectedCarScene = ResourceLoader.load_threaded_get(carScene) #held so the cache keeps it
	if is_instance_valid(door):
		door.progress = 0.5
		if not door.isShut: await door.shut #change scenes only once the slam has landed
	var scene = ResourceLoader.load_threaded_get(path)
	loading = false
	tree.paused = false #the new level pauses itself again while it waits behind the door (Level.holdUnderShutter)
	if scene: tree.change_scene_to_node(RunView.wrap(scene.instantiate()))
	else: tree.change_scene_to_file(path)
