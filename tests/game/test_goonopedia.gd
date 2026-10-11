extends GameTest

#The Goonopedia (docs/UI.md): every goon in Goons.DATA gets a tile on its faction's tab and stays a silhouette
#until crushed, every tab and detail card builds, a run's crushes are credited to the save, and each goon's
#achievement tiers (Achievements) are earned by crushes and claimed on the page. SaveManager.playerData is
#swapped for a new save and restored, so nothing is written.

var original: PlayerData

func before_each():
	original = SaveManager.playerData
	SaveManager.playerData = PlayerData.new()
	SaveManager.migrate()

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

func test_every_goon_has_a_tile_and_is_hidden_until_crushed():
	var first: StringName = Goons.DATA.keys()[0]
	SaveManager.playerData.goonsCrushed[String(first)] = 3
	var page = add_child_autofree(Goonopedia.new())
	var names := []
	for i in Goonopedia.tabTitles().size():
		page.setTab(i)
		assert_eq(page.tiles.size(), Goonopedia.tabGoons(i).size(), "one tile per goon of the faction")
		names.append_array(page.tiles.map(func(t): return t.get_node("caption").text))
	assert_eq(names.size(), Goons.DATA.size(), "every goon is on one tab")
	assert_true(Goons.DATA[first].name in names, "a crushed goon shows its name")
	assert_eq(names.count("???"), Goons.DATA.size() - 1, "the rest are unknown")
	assert_true(page.progressLabel.text.contains("1 / %d" % Goons.DATA.size()))

func test_every_tab_and_card_builds():
	for id in Goons.DATA: SaveManager.playerData.goonsCrushed[String(id)] = 1 if Goons.DATA[id].rank < 2 else 0
	var page = add_child_autofree(Goonopedia.new())
	var titles: Array = Goonopedia.tabTitles()
	assert_eq(titles.size(), Goons.FACTION_NAMES.size(), "a tab per faction, and no Systems tab")
	for i in titles.size():
		page.setTab(i)
		assert_true(page.tiles.size() > 0, titles[i] + " has entries")
		for t in page.tiles:
			t.focus_entered.emit()
			assert_true(page.detail.get_child_count() > 0, "%s card for %s" % [titles[i], t.get_node("caption").text])

func test_tiers_are_earned_by_crushes_and_scale_by_rank():
	for id in Goons.DATA:
		var goals: Array = Achievements.goals(Achievements.forGoon(id))
		assert_eq(goals.size(), Achievements.TIER_NAMES.size(), "%s: a goal per tier" % id)
		assert_eq(goals[0], 1, "%s: the first crush earns the first tier" % id)
		assert_true(goals[1] > goals[0] && goals[2] > goals[1], "%s: goals rise" % id)
	assert_true(Achievements.goals("goon:bullmoose")[2] < Achievements.goals("goon:grunt")[2], "a heavy asks for fewer than fodder")
	var id := "goon:grunt"
	assert_eq(Achievements.earned(id), 0)
	SaveManager.playerData.goonsCrushed["grunt"] = Achievements.goals(id)[1]
	assert_eq(Achievements.earned(id), 2)
	assert_eq(Achievements.claimable(id), 2)
	assert_eq(Achievements.claimableCount(), 2)
	assert_eq(Achievements.steamId(id, 1), "GOON_GRUNT_2")

func test_claiming_pays_once():
	var id := "goon:grunt"
	var data := SaveManager.playerData
	data.goonsCrushed["grunt"] = Achievements.goals(id)[1]
	var coins: int = data.coin
	var pay := Achievements.claim(id)
	assert_eq(pay.coin, Achievements.GOON_REWARDS[0].coin + Achievements.GOON_REWARDS[1].coin, "both earned tiers")
	assert_eq(data.coin, coins + pay.coin)
	assert_eq(Achievements.claimable(id), 0)
	assert_true(Achievements.claim(id).is_empty(), "nothing left to claim")
	assert_eq(data.coin, coins + pay.coin, "and nothing more paid")
	var gems: int = data.gem
	data.goonsCrushed["grunt"] = Achievements.goals(id)[2]
	data.goonsCrushed["tusker"] = 1
	var all := Achievements.claimAll()
	assert_eq(data.gem, gems + int(all.gem), "the top tier's reward")
	assert_eq(Achievements.claimableCount(), 0, "claim all leaves nothing waiting")

func test_the_page_shows_and_claims_rewards():
	SaveManager.playerData.goonsCrushed["tusker"] = 1
	var page = add_child_autofree(Goonopedia.new())
	assert_eq(page.tab, int(Goons.faction.WILD), "it opens on the tab with a reward")
	assert_eq(page.badges[Goons.faction.WILD].count, 1)
	assert_eq(page.badges[Goons.faction.TRIBE].count, 0)
	assert_true(page.tileFor(&"tusker").has_node("tag"), "the tile is marked")
	var coins: int = SaveManager.playerData.coin
	page.claimGoon(&"tusker")
	assert_true(SaveManager.playerData.coin > coins, "claimed from the page")
	assert_eq(page.badges[Goons.faction.WILD].count, 0)
	assert_false(page.tileFor(&"tusker").has_node("tag"))
	assert_true(page.claimAllButton.disabled, "nothing left for Claim all")

func test_every_goon_lives_somewhere():
	for id in Goons.DATA:
		assert_true(Goonopedia.isMeetable(id), "%s can be met" % id)
		assert_false(Goonopedia.levelsOf(id).is_empty() && Goonopedia.parentsOf(id).is_empty(), "%s: no level fields it and nothing bursts into it" % id)
	assert_true(Goonopedia.habitat(&"jackalope").begins_with("Found in " + Levels.get_def(&"prairie").displayName))
	assert_true(Goonopedia.habitat(&"goonling").contains("Splitter"))

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

func test_region_rows_name_the_region_class_and_line_up():
	var rows: Array = Goonopedia.regionRows(Levels.get_def(&"prairie"))
	assert_eq(rows[0][1], "The Wilds  (1 of 5)")
	assert_eq(rows[1][1], "Wild Things")
	assert_eq(rows.size(), 3, "no elite step in the factions' regions")
	var crusher: Array = Goonopedia.regionRows(Levels.get_def(&"crusher"))
	assert_eq(crusher[1][1], "War Machine")
	assert_true(crusher[3][1].contains("+20% harder hits"), "the elite step: %s" % crusher[3][1])

func test_drop_shares_add_up_in_every_mode():
	for mode in Root.gameModes.values().filter(func(m): return Modes.drops(m) == Modes.Drops.ALL): #the modes that roll drops
		var total := 0.0
		for id in Pickups.DATA: total += PickupShop.dropShare(id, mode)
		assert_true(absf(total - 100.0) < 0.01, "mode %d: shares sum to 100%%, got %f" % [mode, total])

func test_levels_and_modes_are_described_in_run_setup_not_here():
	for i in Levels.count():
		var def := Levels.defAt(i)
		assert_true(def.barrier != "" && def.surfaces != "", "%s: barrier and surfaces text for Level Options" % def.id)
	for mode in Root.gameModes.values(): assert_true(Root.MODE_RULES.get(mode, "") != "", "mode %d: a win rule for Level Options" % mode)
