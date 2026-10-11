extends GameTest

#The run setup's loadout (main2, docs/UI.md): a gadget for the Fire slot and a boost for the Boost slot,
#free once unlocked. SaveManager.playerData is swapped for a test copy and restored.

const Main = preload("res://scene/player/menu/main/main2.gd")

var original: PlayerData

func before_each():
	original = SaveManager.playerData
	SaveManager.playerData = PlayerData.new()

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false
	Pickups.loadout = ""
	Pickups.boostLoadout = ""

func choose(gadget: String, boost: String) -> void:
	SaveManager.playerData.meta.records["loadout"] = gadget
	SaveManager.playerData.meta.records["boostLoadout"] = boost

func test_each_slot_sells_its_own_kind():
	for id in Pickups.LOADOUT: assert_eq(Pickups.DATA[id].kind, Pickups.K.GADGET, "%s goes in the Fire slot" % id)
	for id in Pickups.BOOST_LOADOUT: assert_eq(Pickups.DATA[id].kind, Pickups.K.MOVE, "%s goes in the Boost slot" % id)

func test_the_loadout_is_free():
	for id in ["horn", "jets"]: Unlocks.grant("pickup:" + id)
	choose("horn", "jets")
	SaveManager.playerData.gem = 0
	RunLauncher.takeLoadout()
	assert_eq(Pickups.loadout, "horn", "no gems needed")
	assert_eq(Pickups.boostLoadout, "jets")
	assert_eq(SaveManager.playerData.gem, 0, "and none taken")

func test_an_old_choice_of_a_boost_in_the_gadget_slot_is_dropped():
	choose("jets", "") #saves from before the Boost slot kept Jump Jets as the gadget
	assert_eq(Main.slotChoice("loadout"), "")

func test_the_car_starts_with_both():
	Pickups.loadout = "horn"
	Pickups.boostLoadout = "hop"
	var car = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	assert_eq(car.heldItem, "horn", "Fire slot")
	assert_eq(car.moveItem, "hop", "Boost slot")
	assert_eq(Pickups.loadout, "", "taken once")
	assert_eq(Pickups.boostLoadout, "")
