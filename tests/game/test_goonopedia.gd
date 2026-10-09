extends GameTest

#The Goonopedia (docs/UI.md): every goon in Goons.DATA gets a tile and stays a silhouette until crushed,
#every tab and detail card builds, and a run's crushes are credited to the save. The save's
#goonsCrushed is swapped for a scratch dictionary and put back, so the save is never written.

var savedCrushes: Dictionary

func before_each():
	savedCrushes = SaveManager.playerData.goonsCrushed
	SaveManager.playerData.goonsCrushed = {}

func after_each():
	SaveManager.playerData.goonsCrushed = savedCrushes

func test_every_goon_has_a_tile_and_is_hidden_until_crushed():
	var first: StringName = Goons.DATA.keys()[0]
	SaveManager.playerData.goonsCrushed[String(first)] = 3
	var page = add_child_autofree(Goonopedia.new())
	page.setTab(Goonopedia.Tab.GOONS)
	assert_eq(page.tiles.size(), Goons.DATA.size(), "one tile per goon")
	var names = page.tiles.map(func(t): return t.get_node("caption").text)
	assert_true(Goons.DATA[first].name in names, "a crushed goon shows its name")
	assert_eq(names.count("???"), Goons.DATA.size() - 1, "the rest are unknown")
	assert_true(page.progressLabel.text.contains("1 / %d" % Goons.DATA.size()))

func test_every_tab_and_card_builds():
	SaveManager.playerData.goonsCrushed[String(Goons.DATA.keys()[0])] = 1
	var page = add_child_autofree(Goonopedia.new())
	for i in Goonopedia.TAB_NAMES.size():
		page.setTab(i)
		assert_true(page.tiles.size() > 0, Goonopedia.TAB_NAMES[i] + " has entries")
		for t in page.tiles:
			t.focus_entered.emit()
			assert_true(page.detail.get_child_count() > 0, "%s card for %s" % [Goonopedia.TAB_NAMES[i], t.get_node("caption").text])

func test_every_verb_and_act_has_words():
	for id in Goons.DATA:
		var d: Dictionary = Goons.DATA[id]
		if d.has("blurb"): continue
		assert_true(Goonopedia.VERB_TEXT.has(d.get("verb", &"lunge")), "%s: add its verb to Goonopedia.VERB_TEXT" % id)
		if d.get("verb") == &"rider": assert_true(Goonopedia.ACT_TEXT.has(d.get("act", "ram")), "%s: add its act to Goonopedia.ACT_TEXT" % id)

func test_crushes_are_credited_and_first_ones_named():
	var ids = Goons.DATA.keys()
	var found = Goonopedia.creditCrushes({ids[0]: 2, ids[1]: 1})
	assert_eq(found.size(), 2)
	assert_true(Goons.DATA[ids[0]].name in found)
	found = Goonopedia.creditCrushes({ids[0]: 5})
	assert_eq(found.size(), 0, "already known")
	assert_eq(SaveManager.playerData.goonsCrushed[String(ids[0])], 7)

func test_level_numbers_come_from_the_def():
	var def := Levels.get_def(&"prairie")
	var stats = Goonopedia.levelStats(def)
	assert_eq(int(stats.seconds), def.seconds)
	assert_eq(stats.spawn, def.spawnTimer)
	assert_eq(stats.giants, def.giantOdds)
	assert_eq(Goonopedia.levelName(0), def.displayName, "names come from the registry")

func test_level_tab_names_the_region_class_and_line_up():
	var rows: Array = Goonopedia.regionRows(Levels.get_def(&"prairie"))
	assert_eq(rows[0][1], "The Wilds  (1 of 5)")
	assert_eq(rows[1][1], "Wild Things")
	assert_eq(rows.size(), 3, "no elite step in the factions' regions")
	var crusher: Array = Goonopedia.regionRows(Levels.get_def(&"crusher"))
	assert_eq(crusher[1][1], "War Machine")
	assert_true(crusher[3][1].contains("+20% harder hits"), "the elite step: %s" % crusher[3][1])

func test_drop_shares_add_up_in_every_mode():
	for mode in Root.gameModes.values():
		var total := 0.0
		for id in Pickups.DATA: total += Goonopedia.dropShare(id, mode)
		assert_true(absf(total - 100.0) < 0.01, "mode %d: shares sum to 100%%, got %f" % [mode, total])

func test_every_level_card_names_its_region_barrier_and_surfaces():
	var page = add_child_autofree(Goonopedia.new())
	page.setTab(Goonopedia.Tab.LEVELS)
	for i in Levels.count():
		var def := Levels.defAt(i)
		assert_true(def.barrier != "" && def.surfaces != "", "%s: barrier and surfaces text" % def.id)
		page.showDetail({"kind": "level", "key": i})
		var texts := PackedStringArray()
		for node in page.detail.find_children("*", "Label", true, false): texts.push_back(node.text)
		var all := "\n".join(texts)
		for want in [Territories.displayName(def.region).to_upper(), "WHO LIVES HERE", "BARRIER", "SURFACES", def.barrier, def.surfaces]:
			assert_true(all.contains(want), "%s card shows %s" % [def.id, want])
