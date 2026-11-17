extends "res://tests/acceptance/resources_052_case.gd"
## Acceptance tests for specs/052-resources/spec.md, R1 to R8, one or more per requirement
## (R9 to R12 are in test_052_resources_kept.gd). R3 and R8 deliver the simulation's events one
## tick to a frame and many ticks to a frame.

# --- R1 ------------------------------------------------------------------------


func test_r1_each_area_has_a_resource() -> void:
	var expected: Dictionary = {
		MOSSY: [GLOWCAPS, "Glowcap", "glowcaps"],
		CLAYPITS: [CLAY, "Clay", "clay"],
		CRYPT: [BONES, "Old bone", "old bones"],
		EMBER: [EMBERS, "Ember", "embers"],
	}
	for area: StringName in expected:
		var row: Array = expected[area]
		var id: StringName = row[0]
		assert_eq(Content.area(area).resource, id, "%s gives %s" % [area, id])
		var def: ResourceDef = Content.resource_def(id)
		assert_not_null(def, "%s is content" % id)
		if def == null:
			continue
		assert_eq(def.resource_path, "res://data/resources/%s.tres" % id, "under data/resources")
		var called: String = row[1]
		var plural: String = row[2]
		assert_eq(def.display_name, called, "its name")
		assert_eq(def.plural, plural, "its plural")
		assert_eq(def.validate().size(), 0, "it is valid")
		var icon: Texture2D = ResourceIcon.texture(id)
		assert_not_null(icon, "%s has an icon" % id)
		if icon != null:
			assert_eq(icon.get_size(), Vector2(8, 8), "a plain 8x8 icon")
	assert_eq(Content.resource_ids(), [GLOWCAPS, CLAY, BONES, EMBERS], "four, in area order")
	var nameless := ResourceDef.new()
	assert_eq(nameless.validate().size(), 3, "a resource with no id, name or plural is refused")
	var lost: AreaDef = Content.area(MOSSY).duplicate()
	lost.resource = &"gold_dust"
	assert_true(Array(lost.validate()).has("resource: unknown resource 'gold_dust'"), "named")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_party_gathers_it_by_fighting_there() -> void:
	# Small monsters sometimes: Mossy Hollow, whose monsters are all small.
	var mossy := Simulation.new(SEED)
	_level(mossy, STRONG_LEVEL)
	mossy.set_target_depth(3)
	var hollow: Dictionary = _watch(mossy, 9000)
	var small: Vector2i = _drop_share(hollow, MonsterDef.Size.SMALL)
	assert_gt(small.y, 40, "(enough small kills to judge: %d)" % small.y)
	assert_gt(small.x, 0, "small monsters sometimes drop")
	assert_lt(small.x * 2, small.y, "but not usually (%d of %d)" % [small.x, small.y])
	# Large ones usually: the Claypits' golems and ogres.
	var pits: Simulation = _in_claypits(STRONG_LEVEL)
	pits.set_target_depth(3)
	var clay_run: Dictionary = _watch(pits, 9000)
	var large: Vector2i = _drop_share(clay_run, MonsterDef.Size.LARGE)
	assert_gt(large.y, 10, "(enough large kills to judge: %d)" % large.y)
	assert_gt(large.x * 2, large.y, "large monsters usually drop (%d of %d)" % [large.x, large.y])
	var pits_small: Vector2i = _drop_share(clay_run, MonsterDef.Size.SMALL)
	assert_lt(pits_small.x * 2, pits_small.y, "and the small ones there only sometimes")
	# Each drop is the area's own, as much as its size and stage give.
	for watched: Dictionary in [hollow, clay_run]:
		var wanted: int = _index(GLOWCAPS) if watched == hollow else _index(CLAY)
		for kill: Array in watched["kills"]:
			var drop: SimEvent = (watched["drops"] as Dictionary).get(kill[2], null)
			if drop == null:
				continue
			assert_eq(drop.target_id, wanted, "the area's resource")
			var size: MonsterDef.Size = kill[0]
			var stage: int = kill[1]
			assert_eq(drop.amount, ResourceDrops.amount_at(size, stage), "by size and stage")
	assert_eq(ResourceDrops.amount_at(MonsterDef.Size.SMALL, 1), 1, "a small drop on stage 1")
	assert_eq(ResourceDrops.amount_at(MonsterDef.Size.LARGE, 1), 2, "a large one")
	assert_eq(ResourceDrops.amount_at(MonsterDef.Size.BOSS, 1), 6, "a guardian's")
	assert_eq(ResourceDrops.amount_at(MonsterDef.Size.SMALL, 9), 3, "more further in")
	assert_eq(ResourceDrops.amount_at(MonsterDef.Size.BOSS, 5), 12, "a stage-5 guardian's")
	# Many kills through the drop roll itself, each monster rolling its own stream: every
	# guardian drops, most large monsters do and only some small ones.
	var rolls := Simulation.new(SEED)
	var by_size: Dictionary = {
		MonsterDef.Size.BOSS: Content.monster(rolls.expedition.guardian_of(5)),
		MonsterDef.Size.LARGE: Content.monster(&"mud_golem"),
		MonsterDef.Size.SMALL: Content.monster(&"slime"),
	}
	var dropped_by_size: Dictionary = {}
	for size: Variant in by_size:
		var def: MonsterDef = by_size[size]
		var wanted: MonsterDef.Size = size
		assert_eq(def.size, wanted, "(%s is the size wanted)" % def.id)
		var dropped: int = 0
		for i: int in KILLS:
			var dead: Combatant = Combatant.from_monster(def, 5, Expedition.FIRST_MONSTER_ID + i)
			var before: int = rolls.party.resource(GLOWCAPS)
			ResourceDrops.on_kill(rolls.expedition, dead, def)
			if rolls.party.resource(GLOWCAPS) > before:
				dropped += 1
		dropped_by_size[size] = dropped
	var guardians: int = dropped_by_size[MonsterDef.Size.BOSS]
	var larges: int = dropped_by_size[MonsterDef.Size.LARGE]
	var smalls: int = dropped_by_size[MonsterDef.Size.SMALL]
	assert_eq(guardians, KILLS, "every one of %d guardians drops" % KILLS)
	assert_gt(larges * 2, KILLS, "most large monsters (%d of %d)" % [larges, KILLS])
	assert_lt(larges, KILLS, "not every one")
	assert_gt(smalls, 0, "some small ones")
	assert_lt(smalls * 2, KILLS, "but not most (%d of %d)" % [smalls, KILLS])
	# A guardian always, and several.
	var king := Simulation.new(SEED)
	_level(king, STRONG_LEVEL)
	king.expedition.stable_seconds = 2.0
	king.set_target_depth(5)
	king.set_auto_push(false)
	var slain: SimEvent = null
	var guardian_drop: SimEvent = null
	for i: int in 30_000:
		king.step()
		for event: SimEvent in king.drain_events():
			if event.kind == SimEvent.Kind.RESOURCE_GAINED and slain == null:
				guardian_drop = event
			if event.kind == SimEvent.Kind.GUARDIAN_SLAIN:
				slain = event
		if slain != null:
			break
	assert_not_null(slain, "the Slime King falls")
	if slain != null:
		assert_not_null(guardian_drop, "and drops")
		if guardian_drop != null:
			assert_eq(guardian_drop.source_id, slain.source_id, "the guardian's own drop")
			assert_eq(guardian_drop.amount, 12, "several: 12 glowcaps on stage 5")
	# A side quest finished pays some too: the worker gets the area's resource for the party.
	var quests: int = 0
	for watched: Dictionary in [hollow, clay_run]:
		var events: Array[SimEvent] = watched["events"]
		for i: int in events.size():
			if events[i].kind != SimEvent.Kind.SIDE_QUEST_DONE:
				continue
			var paid: SimEvent = null
			# On the same tick, after the reward (and any XP and level-ups it brings).
			for later: int in range(i + 1, events.size()):
				if events[later].tick != events[i].tick:
					break
				if events[later].kind == SimEvent.Kind.RESOURCE_GAINED:
					paid = events[later]
					break
			assert_not_null(paid, "a side quest done pays the resource")
			if paid != null:
				assert_eq(paid.source_id, events[i].source_id, "for the hero who did it")
				var quest_stage: int = 0
				for back: int in range(i, -1, -1):
					if events[back].kind == SimEvent.Kind.DEPTH_CHANGED:
						quest_stage = events[back].amount
						break
				if quest_stage > 0:
					assert_eq(
						paid.amount,
						ResourceDrops.amount_at(MonsterDef.Size.LARGE, quest_stage),
						"as much as a large monster's drop there"
					)
				quests += 1
	assert_gt(quests, 0, "(side quests were done)")
	# The party keeps every drop.
	var total: int = 0
	for event: SimEvent in clay_run["events"]:
		if event.kind == SimEvent.Kind.RESOURCE_GAINED:
			total += event.amount
	assert_eq(pits.party.resource(CLAY), total, "the party holds every clay dropped")
	# Drops come from their own stream: the game is the same as before them.
	var plain := Simulation.new(3)
	for i: int in 9000:
		plain.step()
		plain.drain_events()
	assert_true(plain.party.has_resources(), "(the party gathered something)")
	var recorded: Array = HASHES_BEFORE[3]
	var at_nine_thousand: int = recorded[5]
	assert_eq(_hash_before_resources(plain), at_nine_thousand, "no fight changed")


# --- R3 ------------------------------------------------------------------------


func test_r3_the_party_keeps_a_count() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()
	var purse: ResourcePurse = _hud.resource_purse
	assert_eq(purse.shown_ids(), [] as Array[StringName], "nothing shown with none held")
	var gold_only: float = _hud.gold_panel.size.x
	_sim.party.set_resource(GLOWCAPS, 12)
	_sim.party.set_resource(CLAY, 3)
	_hud.advance(ResourcePurse.CATCH_UP_SECONDS + 0.1)
	_hud.advance(0.0)
	assert_eq(purse.shown_ids(), [GLOWCAPS, CLAY] as Array[StringName], "the two held, in order")
	assert_eq(purse.labels[GLOWCAPS].text, "12", "the glowcaps' count")
	assert_eq(purse.labels[CLAY].text, "3", "the clay's count")
	assert_gt(_hud.gold_panel.size.x, gold_only, "the gold's panel widens to hold them")
	var panel: Rect2 = _hud.gold_panel.get_global_rect()
	var gold: Rect2 = _hud.gold_label.get_global_rect()
	for id: StringName in [GLOWCAPS, CLAY]:
		var icon: Rect2 = purse.icons[id].get_global_rect()
		assert_true(panel.encloses(icon), "%s's icon is beside the gold, in its panel" % id)
		assert_true(panel.encloses(purse.labels[id].get_global_rect()), "and its count")
		assert_gt(icon.position.x, gold.end.x, "after the gold")
	assert_lte(panel.end.y, Hud.TOP_BAND, "in the top band")
	assert_eq(
		_tip(purse.icons[GLOWCAPS]),
		"Glowcaps: 12. Glowcaps come from Mossy Hollow.",
		"the tooltip names the resource and its area"
	)
	assert_eq(
		_tip(purse.labels[CLAY]),
		"Clay: 3. Clay comes from the Claypits: beat the Slime King in Mossy Hollow to open it.",
		"and how a closed area opens"
	)
	# One tick to a frame: the count follows every drop.
	_sim = Simulation.new(SEED)
	_level(_sim, STRONG_LEVEL)
	_build_hud()
	for i: int in 3000:
		_frame()
		if not _heard_of(SimEvent.Kind.RESOURCE_GAINED).is_empty():
			break
	assert_false(_heard_of(SimEvent.Kind.RESOURCE_GAINED).is_empty(), "(a drop happened)")
	assert_lt(
		_hud.resource_purse.shown(GLOWCAPS),
		_sim.party.resource(GLOWCAPS),
		"the count waits for the drop's icons"
	)
	assert_eq(
		_hud.resource_purse.labels[GLOWCAPS].text,
		str(_hud.resource_purse.shown(GLOWCAPS)),
		"and shows what it has counted"
	)
	for i: int in 400:
		_frame(1, STEP)
	_hud.advance(ResourcePurse.CATCH_UP_SECONDS + 0.1)
	assert_gt(_sim.party.resource(GLOWCAPS), 0, "(glowcaps held)")
	assert_eq(_hud.resource_purse.shown(GLOWCAPS), _sim.party.resource(GLOWCAPS), "one a frame")
	# Many ticks to a frame: the count is right at once.
	_sim = Simulation.new(SEED)
	_level(_sim, STRONG_LEVEL)
	_build_hud()
	_frame(3000)
	assert_gt(_sim.party.resource(GLOWCAPS), 0, "(glowcaps held)")
	assert_eq(_hud.resource_purse.shown(GLOWCAPS), _sim.party.resource(GLOWCAPS), "many a frame")
	assert_eq(_hud.resource_purse.labels[GLOWCAPS].text, str(_sim.party.resource(GLOWCAPS)))
	assert_eq(_fx.resource_effects.live_icons().size(), 0, "with no icon for old drops")


## The top bar with counts too long to write out: they are shortened, and nothing overlaps.
func test_r3_large_counts_fit_the_top_bar() -> void:
	assert_eq(Hud.short_count(9_999), "9,999", "written out below 10,000")
	assert_eq(Hud.short_count(12_345), "12.3k", "then shortened")
	assert_eq(Hud.short_count(99_999), "99.9k", "rounded down, never more than it is")
	assert_eq(Hud.short_count(123_456), "123k")
	assert_eq(Hud.short_count(9_999_999), "9.9M")
	assert_eq(Hud.short_count(123_456_789), "123M")
	_sim = Simulation.new(SEED)
	_sim.party.gold = 9_999_999
	for id: StringName in Content.resource_ids():
		_sim.party.set_resource(id, 99_999)
	_build_hud()
	for i: int in 2:
		_hud.advance(10.0)  # past every catch-up
	assert_eq(_hud.gold_label.text, "9.9M", "the gold, shortened")
	var parts: Array[Control] = [_hud.coin_icon, _hud.gold_label]
	for id: StringName in Content.resource_ids():
		assert_eq(_hud.resource_purse.labels[id].text, "99.9k", "%s, shortened" % id)
		parts.append(_hud.resource_purse.icons[id])
		parts.append(_hud.resource_purse.labels[id])
	var panel: Rect2 = _hud.gold_panel.get_global_rect()
	var screen := Rect2(Vector2.ZERO, Hud.SCREEN)
	assert_true(screen.encloses(panel), "the gold's panel is on the screen: %s" % panel)
	for i: int in parts.size():
		var rect: Rect2 = parts[i].get_global_rect()
		assert_true(panel.encloses(rect), "%s is in the panel" % parts[i].name)
		for j: int in range(i + 1, parts.size()):
			var other: Rect2 = parts[j].get_global_rect()
			assert_false(
				rect.intersects(other), "%s and %s do not overlap" % [parts[i].name, parts[j].name]
			)
	var tab: Rect2 = _hud.shop_tab.get_global_rect()
	assert_false(tab.intersects(panel), "the Shop tab is clear of the gold")
	var depth: Rect2 = _hud.depth_panel.get_global_rect()
	assert_false(tab.intersects(depth), "and of the stage panel on the left")
	assert_lte(depth.end.x, tab.position.x, "the stage panel ends before the Shop tab")


# --- R4 ------------------------------------------------------------------------


func test_r4_upgrades_cost_resources() -> void:
	var table: Dictionary = {
		&"field_medicine": GLOWCAPS,
		&"quick_march": GLOWCAPS,
		&"stout_armor": CLAY,
		&"sharp_blades": BONES,
		&"fat_purse": EMBERS,
	}
	for id: StringName in table:
		var def: UpgradeDef = Content.upgrade(id)
		var takes: StringName = table[id]
		assert_eq(def.resource, takes, "%s takes %s" % [id, takes])
		assert_eq(def.resource_from_rank, 3, "from rank 3, counting from 0")
		for rank: int in 3:
			assert_eq(def.resource_cost_at(rank), 0, "%s rank %d costs gold alone" % [id, rank])
		assert_eq(def.resource_cost_at(3), def.resource_base, "the fourth rank costs the resource")
		assert_gt(def.resource_cost_at(5), def.resource_cost_at(4), "more each rank")
		assert_eq(def.resource_cost_at(def.max_rank), -1, "none past the top")
	# The opening is unchanged: three ranks of gold alone.
	var sim := Simulation.new(SEED)
	sim.party.gold = 100_000
	for i: int in 3:
		sim.buy_upgrade(&"stout_armor")
		sim.step()
	assert_eq(sim.upgrades.rank(&"stout_armor"), 3, "three ranks with gold alone")
	var armor: UpgradeDef = Content.upgrade(&"stout_armor")
	var spent: int = armor.cost_at(0) + armor.cost_at(1) + armor.cost_at(2)
	assert_eq(sim.party.gold, 100_000 - spent, "for exactly their gold")
	# The fourth needs the clay too.
	var gold_before: int = sim.party.gold
	sim.buy_upgrade(&"stout_armor")
	sim.step()
	assert_eq(sim.upgrades.rank(&"stout_armor"), 3, "no fourth rank without clay")
	assert_eq(sim.party.gold, gold_before, "and no gold taken")
	sim.party.set_resource(CLAY, armor.resource_base + 2)
	sim.buy_upgrade(&"stout_armor")
	sim.step()
	assert_eq(sim.upgrades.rank(&"stout_armor"), 4, "with the clay it is bought")
	assert_eq(sim.party.gold, gold_before - armor.cost_at(3), "for its gold")
	assert_eq(sim.party.resource(CLAY), 2, "and its clay")


# --- R5 ------------------------------------------------------------------------


func test_r5_the_shop_says_what_is_missing() -> void:
	_sim = Simulation.new(SEED)
	_sim.party.gold = 10_000
	_sim.upgrades.set_rank(&"stout_armor", 3)  # can pay: clay held, the Claypits open
	_sim.upgrades.set_rank(&"field_medicine", 3)  # missing its glowcaps
	_sim.upgrades.set_rank(&"sharp_blades", 3)  # its area closed
	_sim.party.set_resource(CLAY, 10)
	_sim.expedition.travel.open[CLAYPITS] = true
	_build_hud()
	_hud.shop.open()
	_hud.advance(0.0)
	var rows: Dictionary = {}
	for row: ShopRow in _hud.shop.rows:
		rows[row.id] = row
	var armor: ShopRow = rows[&"stout_armor"]
	assert_true(armor.resource_label.visible and armor.resource_icon.visible, "both prices")
	assert_eq(armor.buy_button.text, "91", "the gold")
	assert_eq(armor.resource_label.text, "4", "and the clay")
	assert_eq(armor.resource_icon.texture, ResourceIcon.texture(CLAY), "beside its icon")
	assert_eq(armor.price_colour(), ShopRow.PRICE_AFFORDABLE, "the gold paid")
	assert_eq(armor.resource_colour(), ShopRow.RESOURCE_AFFORDABLE, "the clay paid")
	assert_true(armor.affordable() and not armor.buy_button.disabled, "it can be bought")
	assert_eq(
		_tip(armor),
		"Rank 4: 91 gold and 4 clay. Clay comes from the Claypits.",
		"its tooltip says where the clay comes from"
	)
	var medicine: ShopRow = rows[&"field_medicine"]
	assert_eq(medicine.price_colour(), ShopRow.PRICE_AFFORDABLE, "the gold is there")
	assert_eq(medicine.resource_colour(), ShopRow.RESOURCE_TOO_FEW, "the glowcaps greyed")
	assert_ne(ShopRow.RESOURCE_TOO_FEW, ShopRow.RESOURCE_AFFORDABLE)
	assert_eq(ShopRow.RESOURCE_TOO_FEW, &"slate", "grey")
	assert_true(medicine.buy_button.disabled and not medicine.affordable(), "it cannot be bought")
	assert_eq(
		_tip(medicine),
		"Rank 4: 84 gold and 5 glowcaps. Glowcaps come from Mossy Hollow.",
		"its tooltip says where to find them"
	)
	var blades: ShopRow = rows[&"sharp_blades"]
	assert_eq(blades.resource_colour(), ShopRow.RESOURCE_TOO_FEW, "no old bones")
	assert_eq(
		_tip(blades),
		(
			"Rank 4: 91 gold and 4 old bones. Old bones come from the Old Crypt: beat the Clay"
			+ " Colossus in the Claypits to open it."
		),
		"a closed area's row says how it is opened"
	)
	var purse: ShopRow = rows[&"fat_purse"]
	assert_false(purse.resource_label.visible, "a rank of gold alone shows one price")
	assert_string_contains(_tip(purse), "From rank 4 it costs embers too.")
	_sim.party.gold = 0
	_hud.advance(0.0)
	assert_eq(armor.price_colour(), ShopRow.PRICE_TOO_DEAR, "gold missing is dimmed as before")
	assert_eq(armor.resource_colour(), ShopRow.RESOURCE_AFFORDABLE, "the clay still there")
	assert_true(armor.buy_button.disabled, "and it cannot be bought")
	assert_true(_hud.shop.get_global_rect().end.x <= Hud.SCREEN.x, "the shop fits the screen")


## With gold to spare and none of the resource, nothing points at an upgrade: no shop marker, no
## goal to buy one, and no such suggestion after a defeat. With the resource, they come back.
func test_r5_nothing_offers_an_upgrade_the_party_cannot_pay() -> void:
	_sim = Simulation.new(SEED)
	for id: StringName in Content.upgrade_ids():
		_sim.upgrades.set_rank(id, 3)  # every next rank costs a resource
	_sim.party.gold = 1_000_000
	_build_hud()
	_hunting_on(7, 4)
	_frame(0)
	assert_eq(_hud.shop.affordable_count(), 0, "none can be paid")
	assert_eq(_hud.shop_marker.count, 0, "the shop's marker counts none")
	assert_false(_hud.shop_marker.visible, "and is not shown")
	assert_false(_offers_upgrade_goal(), "no goal to buy an upgrade")
	assert_true(_lose_a_fight(), "(the party loses a fight)")
	assert_true(_hud.defeat_note.visible, "(the defeat note is up)")
	assert_false(_hud.defeat_note.suggestions().has("Buy an upgrade"), "and it suggests no upgrade")
	# Clay for Stout Armor: that one can be paid now.
	_sim.party.set_resource(CLAY, 1000)
	_hud.advance(STEP)
	assert_eq(_hud.shop.affordable_count(), 1, "Stout Armor can be paid")
	assert_eq(_hud.shop_marker.count, 1, "the marker counts it")
	assert_true(_offers_upgrade_goal(), "the goal to buy one is back")
	assert_true(_hud.defeat_note.suggestions().has("Buy an upgrade"), "and the suggestion")


# --- R6 ------------------------------------------------------------------------


func test_r6_auto_buy_pays_both_prices() -> void:
	var sim := Simulation.new(SEED)
	for id: StringName in Content.upgrade_ids():
		sim.upgrades.set_rank(id, 3)
	sim.party.gold = 1_000_000
	sim.set_auto_buy(true)
	for i: int in 100:
		sim.step()
	for id: StringName in Content.upgrade_ids():
		assert_eq(sim.upgrades.rank(id), 3, "%s not bought without its resource" % id)
	assert_eq(sim.upgrades.cheapest_affordable(sim.party), &"", "nothing can be paid in full")
	sim.party.set_resource(GLOWCAPS, 5)
	var bought: bool = false
	for i: int in 30:
		var gold_before: int = sim.party.gold
		var glowcaps_before: int = sim.party.resource(GLOWCAPS)
		sim.step()
		var gold_gained: int = 0
		var glowcaps_gained: int = 0
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.GOLD_GAINED:
				gold_gained += event.amount
			elif (
				event.kind == SimEvent.Kind.RESOURCE_GAINED and event.target_id == _index(GLOWCAPS)
			):
				glowcaps_gained += event.amount
			elif event.kind == SimEvent.Kind.UPGRADE_BOUGHT:
				bought = true
		if not bought:
			continue
		assert_eq(sim.upgrades.rank(&"field_medicine"), 4, "the cheapest it can pay in full")
		assert_eq(sim.upgrades.rank(&"quick_march"), 3, "and no more: the glowcaps are spent")
		var glowcaps_now: int = sim.party.resource(GLOWCAPS)
		assert_eq(glowcaps_now, glowcaps_before + glowcaps_gained - 5, "both paid: the glowcaps")
		assert_eq(sim.party.gold, gold_before + gold_gained - 84, "and the gold")
		break
	assert_true(bought, "it bought")
	var poor := Simulation.new(SEED)
	poor.upgrades.set_rank(&"field_medicine", 3)
	poor.party.set_resource(GLOWCAPS, 100)
	poor.party.gold = 83
	for id: StringName in Content.upgrade_ids():
		if id != &"field_medicine":
			poor.upgrades.set_rank(id, Content.upgrade(id).max_rank)
	poor.set_auto_buy(true)
	for i: int in 30:
		poor.step()
	assert_eq(poor.upgrades.rank(&"field_medicine"), 3, "nor with the resource but not the gold")
	assert_eq(poor.party.resource(GLOWCAPS), 100, "nothing taken")


# --- R7 ------------------------------------------------------------------------


func test_r7_the_map_shows_it() -> void:
	_sim = Simulation.new(SEED)
	_sim.party.set_resource(GLOWCAPS, 12)
	_build_hud()
	_hud.area_map.open()
	_hud.advance(0.0)
	var expected: Dictionary = {
		MOSSY: [GLOWCAPS, "12 glowcaps"],
		CLAYPITS: [CLAY, "Gives clay"],
		CRYPT: [BONES, "Gives old bones"],
		EMBER: [EMBERS, "Gives embers"],
	}
	for row: AreaMapRow in _hud.area_map.rows:
		var shown: Array = expected[row.area_id]
		assert_true(row.resource_icon.is_visible_in_tree(), "%s shows its resource" % row.area_id)
		var gives: StringName = shown[0]
		var says: String = shown[1]
		assert_eq(row.resource_icon.texture, ResourceIcon.texture(gives), "its icon")
		assert_eq(row.resource_label.text, says, "and how many, or what opening it gives")
		var text_end: float = row.thumbs[0].position.x
		assert_lte(row.resource_label.position.x + row.resource_label.size.x, text_end, "clear")
		assert_true(
			Rect2(Vector2.ZERO, row.size).encloses(row.resource_label.get_rect()), "in the row"
		)
	_sim.expedition.travel.open[CLAYPITS] = true
	_sim.party.set_resource(CLAY, 1234)
	_hud.advance(0.0)
	assert_eq(_hud.area_map.rows[1].resource_label.text, "1,234 clay", "an open area: held")
	_sim.party.set_resource(GLOWCAPS, 0)
	_hud.advance(0.0)
	assert_eq(_hud.area_map.rows[0].resource_label.text, "0 glowcaps", "none held, open")


# --- R8 ------------------------------------------------------------------------


func test_r8_told_like_gold() -> void:
	# One tick to a frame: an icon rises from the monster and flies to the purse; the count
	# ticks up as it lands.
	_sim = Simulation.new(SEED)
	_level(_sim, STRONG_LEVEL)
	_build_hud()
	var fallen: Dictionary = {}
	_world.sim_event.connect(
		func(event: SimEvent) -> void:
			if event.kind == SimEvent.Kind.DIED:
				fallen[event.source_id] = _world.feet_position(event.source_id)
	)
	var drop: SimEvent = null
	for i: int in 3000:
		_frame()
		var drops: Array[SimEvent] = _heard_of(SimEvent.Kind.RESOURCE_GAINED)
		if not drops.is_empty():
			drop = drops[0]
			break
	assert_not_null(drop, "(a drop happened)")
	if drop == null:
		return
	var icons: Array[FxResource] = _fx.resource_effects.live_icons()
	assert_eq(icons.size(), ResourceEffects.icon_count(drop.amount), "its icons appear")
	var feet: Vector2 = fallen.get(drop.source_id, Vector2.ZERO)
	assert_ne(feet, Vector2.ZERO, "(the monster fell on screen)")
	for icon: FxResource in icons:
		assert_lt(icon.start_position.distance_to(feet), 24.0, "from where the monster fell")
	assert_lt(_hud.resource_purse.shown(GLOWCAPS), _sim.party.resource(GLOWCAPS), "not counted yet")
	var first: FxResource = icons[0]
	var start: Vector2 = first.position
	_fx.resource_effects.advance(0.2)
	assert_lt(first.position.y, start.y, "it rises")
	var rose_on_screen: bool = false
	for i: int in 300:
		_frame(0)
		if _fx.resource_effects.live_icons().is_empty():
			rose_on_screen = true
			break
	assert_true(rose_on_screen, "and lands within five seconds")
	assert_eq(_hud.resource_purse.shown(GLOWCAPS), _sim.party.resource(GLOWCAPS), "then counted")
	assert_eq(_journal_count("First glowcaps, from Mossy Hollow"), 1, "the journal notes it")
	for i: int in 3000:
		_frame()
	assert_gt(_heard_of(SimEvent.Kind.RESOURCE_GAINED).size(), 1, "(more drops)")
	assert_eq(_journal_count("First glowcaps, from Mossy Hollow"), 1, "the first, once")
	# Many ticks to a frame: no icon, the count is right, the journal notes the first once.
	_heard.clear()
	_sim = Simulation.new(SEED)
	_level(_sim, STRONG_LEVEL)
	_build_hud()
	_frame(6000)
	assert_gt(_heard_of(SimEvent.Kind.RESOURCE_GAINED).size(), 1, "(drops in the frame)")
	assert_eq(_fx.resource_effects.live_icons().size(), 0, "none rise from an old drop")
	assert_eq(_hud.resource_purse.shown(GLOWCAPS), _sim.party.resource(GLOWCAPS), "counted")
	assert_eq(_journal_count("First glowcaps, from Mossy Hollow"), 1, "noted once")
	# A game that already holds glowcaps notes no first.
	_heard.clear()
	_sim = Simulation.new(SEED)
	_level(_sim, STRONG_LEVEL)
	_sim.party.set_resource(GLOWCAPS, 1)
	_build_hud()
	_frame(6000)
	assert_eq(_journal_count("First glowcaps, from Mossy Hollow"), 0, "not the first")
	# The away report lists the resources gathered.
	var away := Simulation.new(SEED)
	_level(away, STRONG_LEVEL)
	var replay := AwayReplay.new(away, 1200.0)
	var gathered: int = 0
	var before: int = away.party.resource(GLOWCAPS)
	while not replay.is_done():
		replay.run(1_000_000)
	gathered = away.party.resource(GLOWCAPS) - before
	assert_gt(gathered, 0, "(glowcaps gathered away)")
	var counted: int = replay.report.resources_gained.get(GLOWCAPS, 0)
	assert_eq(counted, gathered, "all counted")
	var panel := AwayPanel.new(replay.report, away.party)
	add_child_autofree(panel)
	assert_string_contains(panel.text(), "Gathered %d glowcaps" % gathered, "and listed")
	var quiet := AwayPanel.new(AwayReport.new(), away.party)
	add_child_autofree(quiet)
	assert_false(quiet.text().contains("Gathered"), "no line when nothing was gathered")
	# The tally of a fight is unchanged by drops.
	var with_drops := Tally.new()
	var without := Tally.new()
	var fights := Simulation.new(SEED)
	_level(fights, STRONG_LEVEL)
	var drops_seen: int = 0
	for i: int in 3000:
		fights.step()
		for event: SimEvent in fights.drain_events():
			with_drops.observe(event)
			if event.kind == SimEvent.Kind.RESOURCE_GAINED:
				drops_seen += 1
			else:
				without.observe(event)
	assert_gt(drops_seen, 0, "(drops seen)")
	assert_eq(with_drops.fights(), without.fights(), "the same fights")
	for hero: Hero in fights.party.heroes:
		assert_eq(with_drops.side_quests(hero.id), without.side_quests(hero.id), "quests")
		for measure: int in Tally.Measure.values():
			for span: int in Tally.Span.values():
				assert_eq(
					with_drops.value(hero.id, measure as Tally.Measure, span as Tally.Span),
					without.value(hero.id, measure as Tally.Measure, span as Tally.Span),
					"the same tally"
				)


## The journal notes a first once in a game's life: a count spent back to 0 and reloaded is not a
## first again. A first gathered while the game was closed is in the away report.
func test_r8_firsts_are_remembered() -> void:
	var fresh := Simulation.new(SEED)
	assert_false(fresh.has_gathered(GLOWCAPS), "a new game has gathered nothing")
	fresh.upgrades.set_rank(&"field_medicine", 3)
	assert_false(fresh.has_gathered(GLOWCAPS), "ranks of gold alone say nothing")
	# Glowcaps gathered and spent down to none, then saved and loaded.
	var spent := Simulation.new(SEED)
	spent.upgrades.set_rank(&"field_medicine", 4)
	spent.party.set_resource(GLOWCAPS, 0)
	var through_json: Dictionary = JSON.parse_string(JSON.stringify(spent.to_save()))
	_sim = Simulation.from_save(through_json)
	assert_not_null(_sim, "(it loads)")
	if _sim == null:
		return
	assert_true(_sim.has_gathered(GLOWCAPS), "a rank that cost glowcaps: they were held")
	assert_false(_sim.has_gathered(CLAY), "but not clay")
	_level(_sim, STRONG_LEVEL)
	_build_hud()
	for i: int in 3000:
		_frame()
		if _sim.party.resource(GLOWCAPS) > 0:
			break
	assert_gt(_sim.party.resource(GLOWCAPS), 0, "(glowcaps gathered again)")
	assert_eq(_journal_count("First glowcaps, from Mossy Hollow"), 0, "not a first again")
	# Away: the first glowcaps are in the report, as the journal would have put them.
	var away := Simulation.new(SEED)
	_level(away, STRONG_LEVEL)
	var replay := AwayReplay.new(away, 600.0)
	while not replay.is_done():
		replay.run(1_000_000)
	assert_eq(replay.report.resources_first, [GLOWCAPS] as Array[StringName], "the first, once")
	var panel := AwayPanel.new(replay.report, away.party)
	add_child_autofree(panel)
	assert_string_contains(panel.text(), "First glowcaps, from Mossy Hollow", "in the report")
	_build_hud_on(away)
	for i: int in 3000:
		_frame()
	assert_eq(_journal_count("First glowcaps, from Mossy Hollow"), 0, "and not again after")
	# Already held before going away: no first.
	var again := AwayReplay.new(away, 600.0)
	while not again.is_done():
		again.run(1_000_000)
	assert_eq(again.report.resources_first, [] as Array[StringName], "nothing new: no first")
