extends GutTest
## Acceptance tests for specs/052-resources/spec.md, one per requirement.
##
## The view tests (R3, R5, R7, R8) build a World on a seeded simulation with the CombatEffects and
## the Hud on it, every _process turned off, on a canvas layer above GUT's (as Main has it), and
## drive them a frame at a time. R3 and R8 deliver the simulation's events one tick to a frame and
## many ticks to a frame.

const SEED: int = 42
const STEP: float = 1.0 / 60.0
const MOSSY: StringName = &"mossy_hollow"
const CLAYPITS: StringName = &"claypits"
const CRYPT: StringName = &"old_crypt"
const EMBER: StringName = &"ember_deep"
const GLOWCAPS: StringName = &"glowcaps"
const CLAY: StringName = &"clay"
const BONES: StringName = &"old_bones"
const EMBERS: StringName = &"embers"
## Strong enough to win every fight in the first two areas.
const STRONG_LEVEL: int = 25
## Where the mouse is when it is over nothing of the HUD's.
const AWAY: Vector2 = Vector2(320, 200)
## Spec 016's recorded hashes (an untouched simulation, every 1500 ticks up to 20 minutes) as they
## were on dev before this spec: R11 shows the game is the same once the resources are left out.
const HASHES_BEFORE: Dictionary = {
	3:
	[
		3793668176,
		1214036140,
		3894860287,
		816719926,
		637789871,
		3221476330,
		3183358185,
		3928131485,
	],
	11:
	[
		3372118570,
		622540149,
		1375365754,
		1948124930,
		1885808759,
		1752451346,
		2263356909,
		2125969758,
	],
}
## R10: minutes the Mossy-only party plays, and the most it may then take to hold clay.
const MOSSY_MINUTES: float = 30.0
const CLAY_MINUTES: float = 5.0

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
var _heard: Array[SimEvent] = []


func after_each() -> void:
	_mouse(AWAY)
	_heard.clear()


# --- Helpers -------------------------------------------------------------------


func _build_hud() -> void:
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	var layer := CanvasLayer.new()
	layer.layer = 129
	add_child_autofree(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_world.sim_event.connect(func(event: SimEvent) -> void: _heard.append(event))


## One frame of the view, after [param ticks] steps of the simulation.
func _frame(ticks: int = 1, delta: float = STEP) -> void:
	for i: int in ticks:
		_sim.step()
	_world.sync(delta)
	_fx.advance(delta)
	_hud.advance(delta)


func _level(sim: Simulation, level: int) -> void:
	for hero: Hero in sim.party.heroes:
		hero.level = level
		hero.xp = Hero.xp_for_level(level)
		hero.health = hero.max_health()


func _index(id: StringName) -> int:
	return Content.resource_ids().find(id)


func _mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


## The tooltip shown after resting the mouse on [param control].
func _tip(control: Control) -> String:
	_hud.tooltip.point_at(control.get_global_rect().get_center())
	_hud.tooltip.advance(HudTooltip.DELAY + 0.01)
	var text: String = _hud.tooltip.shown_text()
	_hud.tooltip.point_at(HudTooltip.NOWHERE)
	_hud.tooltip.advance(0.0)
	return text


func _heard_of(kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in _heard:
		if event.kind == kind:
			found.append(event)
	return found


## What [param sim] did over [param ticks] ticks: every kill as [size, stage, monster id, def id],
## the drops by monster (or worker) id, the side quests done, and all the events.
func _watch(sim: Simulation, ticks: int) -> Dictionary:
	var kills: Array = []
	var drops: Dictionary = {}
	var events: Array[SimEvent] = []
	for i: int in ticks:
		var fight: Battle = sim.expedition.battle
		var stage: int = sim.expedition.depth
		sim.step()
		for event: SimEvent in sim.drain_events():
			events.append(event)
			if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
				var dead: Combatant = fight.combatant(event.source_id) if fight != null else null
				if dead != null:
					var def: MonsterDef = Content.monster(dead.def_id)
					kills.append([def.size, stage, dead.id, dead.def_id])
			elif event.kind == SimEvent.Kind.RESOURCE_GAINED:
				drops[event.source_id] = event
	return {"kills": kills, "drops": drops, "events": events}


## Of [param watched]'s kills of size [param size], the share that dropped something.
func _drop_share(watched: Dictionary, size: MonsterDef.Size) -> Vector2i:
	var dropped: int = 0
	var killed: int = 0
	for kill: Array in watched["kills"]:
		if kill[0] != size:
			continue
		killed += 1
		if (watched["drops"] as Dictionary).has(kill[2]):
			dropped += 1
	return Vector2i(dropped, killed)


## A party at [param level] sent to the Claypits (opened by hand), arrived and standing there.
func _in_claypits(level: int) -> Simulation:
	var sim := Simulation.new(SEED)
	_level(sim, level)
	sim.expedition.travel.open[CLAYPITS] = true
	sim.set_destination(CLAYPITS, 1)
	for i: int in 400:
		sim.step()
		if sim.expedition.area == CLAYPITS and sim.expedition.state != Expedition.State.JOURNEYING:
			break
	sim.drain_events()
	return sim


## [param sim]'s state hash as it was before this spec: without the resources held and the
## guardians beaten (spec 016 R5's recorded hashes are of this).
func _hash_before_resources(sim: Simulation) -> int:
	var party_parts: Array = sim.party.hash_parts()
	if sim.party.has_resources():
		party_parts.pop_back()
	var run_parts: Array = sim.expedition.hash_parts()
	for part: Variant in run_parts:
		if part is Array and (part as Array).size() == 4 and (part as Array)[0] == "areas":
			var travel_parts: Array = (part as Array)[3]
			var last: Variant = travel_parts.back()
			if last is Array and (last as Array).size() == 2 and (last as Array)[0] == "beaten":
				travel_parts.pop_back()
	var parts: Array = [sim._seed, sim.tick, party_parts, run_parts]
	if sim.upgrades.any():
		parts.append(sim.upgrades.hash_parts())
	if sim.auto_buy:
		parts.append("auto_buy")
	return hash(parts)


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


func _journal_count(sentence: String) -> int:
	var count: int = 0
	for line: String in _hud.journal.lines():
		if line.ends_with(sentence):
			count += 1
	return count


# --- R9 ------------------------------------------------------------------------


func test_r9_saves_carry_it() -> void:
	var sim := Simulation.new(SEED)
	sim.party.set_resource(GLOWCAPS, 12)
	sim.party.set_resource(EMBERS, 3)
	var saved: Dictionary = sim.to_save()
	assert_eq(Simulation.SAVE_VERSION, 8, "the next save version")
	var version: int = saved["version"]
	assert_eq(version, 8)
	var held: Dictionary = saved["resources"]
	assert_eq(held, {"glowcaps": 12, "embers": 3}, "each resource's count")
	var through_json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var loaded: Simulation = Simulation.from_save(through_json)
	assert_not_null(loaded, "it loads through JSON")
	if loaded != null:
		for id: StringName in Content.resource_ids():
			assert_eq(loaded.party.resource(id), sim.party.resource(id), "%s kept" % id)
	# A version 7 save loads with none, its upgrade ranks kept.
	var old: Dictionary = saved.duplicate(true)
	old["version"] = 7
	old.erase("resources")
	old.erase("guardians_beaten")
	old["upgrades"] = {"sharp_blades": 6, "field_medicine": 4}
	assert_eq(Simulation.save_problems(old), PackedStringArray(), "an old save is fine")
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "and loads")
	if from_old != null:
		assert_false(from_old.party.has_resources(), "with no resources")
		assert_eq(from_old.upgrades.rank(&"sharp_blades"), 6, "ranks it held stay")
		assert_eq(from_old.upgrades.rank(&"field_medicine"), 4, "every one")
	# Refused by name.
	var bad: Dictionary = saved.duplicate(true)
	bad["resources"] = {"glowcaps": -1, "gold_dust": 4, "clay": 1.5}
	var problems: PackedStringArray = Simulation.save_problems(bad)
	assert_true(problems.has("resources.glowcaps: below 0"), "a negative count")
	assert_true(problems.has("resources.gold_dust: unknown resource"), "an unknown resource")
	assert_true(problems.has("resources.clay: missing or not a whole number"), "not whole")
	assert_null(Simulation.from_save(bad), "and not loaded")
	var none: Dictionary = saved.duplicate(true)
	none.erase("resources")
	assert_true(
		Simulation.save_problems(none).has("resources: missing or not a dictionary of counts"),
		"a version 8 save without resources is refused"
	)


# --- R10 -----------------------------------------------------------------------


func test_r10_worth_the_trip() -> void:
	var lines: PackedStringArray = []
	for seed_value: int in [1, 2, 3]:
		var sim := Simulation.new(seed_value)
		sim.set_auto_buy(true)
		var held_back: bool = false
		for i: int in roundi(MOSSY_MINUTES * 60.0 * Simulation.TICKS_PER_SECOND):
			sim.step()
			sim.drain_events()
			var blades: int = sim.upgrades.rank(&"sharp_blades")
			if blades == 3 and sim.party.gold >= sim.upgrades.cost(&"sharp_blades"):
				held_back = true
		assert_eq(sim.expedition.place, MOSSY, "seed %d: (only ever in Mossy Hollow)" % seed_value)
		for id: StringName in [&"stout_armor", &"sharp_blades", &"fat_purse"]:
			assert_eq(sim.upgrades.rank(id), 3, "seed %d: %s stops at rank 3" % [seed_value, id])
		assert_true(held_back, "seed %d: held back by the resource, not the gold" % seed_value)
		for id: StringName in [CLAY, BONES, EMBERS]:
			assert_eq(
				sim.party.resource(id), 0, "seed %d: no %s in Mossy Hollow" % [seed_value, id]
			)
		var glowcaps: int = sim.party.resource(GLOWCAPS)
		var medicine: int = sim.upgrades.rank(&"field_medicine")
		var march: int = sim.upgrades.rank(&"quick_march")
		assert_gt(medicine + march, 6, "seed %d: glowcaps buy past rank 3" % seed_value)
		assert_true(sim.is_area_open(CLAYPITS), "seed %d: the Claypits open" % seed_value)
		if not sim.is_area_open(CLAYPITS):
			continue
		sim.set_destination(CLAYPITS, 1)
		var arrived: int = -1
		var first_clay: int = -1
		var limit: int = roundi((CLAY_MINUTES * 60.0 + 30.0) * Simulation.TICKS_PER_SECOND)
		for i: int in limit:
			sim.step()
			for event: SimEvent in sim.drain_events():
				if event.kind == SimEvent.Kind.AREA_CHANGED and arrived < 0:
					arrived = sim.tick
				if event.kind == SimEvent.Kind.RESOURCE_GAINED and arrived >= 0 and first_clay < 0:
					first_clay = sim.tick
			if (
				arrived >= 0
				and sim.tick - arrived >= CLAY_MINUTES * 60 * Simulation.TICKS_PER_SECOND
			):
				break
		assert_gt(arrived, 0, "seed %d: the party arrives" % seed_value)
		assert_gt(sim.party.resource(CLAY), 0, "seed %d: clay within five minutes" % seed_value)
		(
			lines
			. append(
				(
					(
						"seed %d: at %d min in Mossy Hollow ranks %s, %d glowcaps; first clay %.0f s after"
						+ " arriving, %d clay at 5 min"
					)
					% [
						seed_value,
						MOSSY_MINUTES,
						str(sim.upgrades.hash_parts()),
						glowcaps,
						float(first_clay - arrived) / Simulation.TICKS_PER_SECOND,
						sim.party.resource(CLAY),
					]
				)
			)
		)
	gut.p("\n".join(lines))


# --- R11 -----------------------------------------------------------------------


func test_r11_still_deterministic() -> void:
	var a := Simulation.new(5)
	var b := Simulation.new(5)
	for sim: Simulation in [a, b]:
		_level(sim, STRONG_LEVEL)
		sim.set_auto_buy(true)
	for i: int in 9000:
		a.step()
		b.step()
		a.drain_events()
		b.drain_events()
	assert_true(a.party.has_resources(), "(resources gathered)")
	assert_eq(a.state_hash(), b.state_hash(), "the same seed, the same game")
	for id: StringName in Content.resource_ids():
		assert_eq(a.party.resource(id), b.party.resource(id), "the same %s" % id)
	var c := Simulation.new(5)
	c.party.set_resource(CLAY, 1)
	assert_ne(c.state_hash(), Simulation.new(5).state_hash(), "the hash includes resources")
	# Leave the resources out and the recorded game is unchanged: the hash changes only where it
	# now includes them.
	for seed_value: int in HASHES_BEFORE:
		var sim := Simulation.new(seed_value)
		var samples: int = 0
		var changed: int = 0
		for i: int in 12_000:
			sim.step()
			sim.drain_events()
			if sim.tick % 1500 != 0:
				continue
			var before: int = HASHES_BEFORE[seed_value][samples]
			assert_eq(
				_hash_before_resources(sim), before, "seed %d sample %d" % [seed_value, samples]
			)
			var includes: bool = sim.party.has_resources() or sim.is_guardian_beaten(MOSSY)
			assert_eq(sim.state_hash() != before, includes, "changed only with resources in it")
			if includes:
				changed += 1
			samples += 1
		assert_eq(samples, 8, "every sample")
		assert_gt(changed, 0, "(seed %d gathered within 20 minutes)" % seed_value)


# --- R12 -----------------------------------------------------------------------


func test_r12_beaten_guardians_are_remembered() -> void:
	var sim := Simulation.new(SEED)
	_level(sim, STRONG_LEVEL)
	sim.expedition.stable_seconds = 2.0
	sim.set_target_depth(5)
	sim.set_auto_push(false)
	assert_false(sim.is_guardian_beaten(MOSSY), "not beaten at the start")
	var slain: bool = false
	for i: int in 30_000:
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.GUARDIAN_SLAIN:
				slain = true
		if slain:
			break
	assert_true(slain, "(the Slime King falls)")
	assert_true(sim.is_guardian_beaten(MOSSY), "beaten, and kept")
	assert_false(sim.is_guardian_beaten(CLAYPITS), "only that one")
	var saved: Dictionary = sim.to_save()
	var beaten: Array = saved["guardians_beaten"]
	assert_eq(beaten, ["mossy_hollow"], "the save holds it")
	var through_json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var loaded: Simulation = Simulation.from_save(through_json)
	assert_true(loaded != null and loaded.is_guardian_beaten(MOSSY), "and a load keeps it")
	# The last area's guardian, beaten, after a reload: the map reads the simulation.
	var last: Dictionary = Simulation.new(SEED).to_save()
	last["open_areas"] = ["mossy_hollow", "claypits", "old_crypt", "ember_deep"]
	last["area"] = "ember_deep"
	last["guardians_beaten"] = ["mossy_hollow", "claypits", "old_crypt", "ember_deep"]
	_sim = Simulation.from_save(last)
	assert_not_null(_sim, "(an Ember Deep save loads)")
	if _sim == null:
		return
	_build_hud()
	_hud.area_map.open()
	_hud.advance(0.0)
	for row: AreaMapRow in _hud.area_map.rows:
		assert_true(row.guardian_thumb.beaten, "%s's guardian shows beaten" % row.area_id)
	# Older saves: beaten when the area it opens is open or the furthest stage is past it.
	var old: Dictionary = Simulation.new(SEED).to_save()
	old["version"] = 7
	old.erase("resources")
	old.erase("guardians_beaten")
	old["open_areas"] = ["mossy_hollow", "claypits", "old_crypt", "ember_deep"]
	old["area"] = "ember_deep"
	old["last_stable_depth"] = 6
	old["deepest_depth"] = 6
	old["target_depth"] = 6
	old["areas"] = {"claypits": {"safe": 4, "furthest": 4}, "old_crypt": {"safe": 5, "furthest": 5}}
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "(a version 7 save loads)")
	if from_old == null:
		return
	assert_true(from_old.is_guardian_beaten(MOSSY), "the Claypits are open: the Slime King")
	assert_true(from_old.is_guardian_beaten(CLAYPITS), "the Old Crypt is open: the Colossus")
	assert_true(from_old.is_guardian_beaten(CRYPT), "Ember Deep is open: the Bone Lord")
	assert_true(from_old.is_guardian_beaten(EMBER), "furthest 6, past stage 5: the Deep Maw")
	var shallow: Dictionary = old.duplicate(true)
	shallow["open_areas"] = ["mossy_hollow"]
	shallow["area"] = "mossy_hollow"
	shallow["deepest_depth"] = 5
	shallow["last_stable_depth"] = 5
	shallow["target_depth"] = 5
	shallow["areas"] = {}
	var from_shallow: Simulation = Simulation.from_save(shallow)
	assert_not_null(from_shallow, "(a version 7 save at stage 5 loads)")
	if from_shallow != null:
		for id: StringName in Content.area_ids():
			assert_false(from_shallow.is_guardian_beaten(id), "%s not beaten at stage 5" % id)
