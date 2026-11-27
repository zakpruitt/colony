extends "res://tests/acceptance/hero_windows_test_base.gd"
## What the acceptance tests of spec 064 (the talent tree as a tree) share: their constants and
## helpers, on top of hero_windows_test_base.gd's. Kept apart so the tests' own file stays under
## gdlint's length.

const SEED_TICKS: int = 5
## Ticks the simulation runs on before the world hears of it: what it reported is long past.
const STALE_TICKS: int = 400
## A level with every talent point earned and three paragon points.
const PARAGON_LEVEL: int = 33

## The fighters and battles of spec 050's tests, built by its kit.
const Kit = preload("res://tests/unit/ability_kit_test_base.gd")
## "The new abilities" of the spec.
const NEW_ABILITIES: Array[StringName] = [
	&"earthshaker",
	&"war_banner",
	&"challenge",
	&"charge",
	&"toxic_cloud",
	&"envenom",
	&"plague",
	&"shadowstep",
	&"lightning_bolt",
	&"static_field",
	&"overload",
	&"thunderstorm",
	&"radiance",
	&"aegis",
	&"hallowed_ground",
	&"resurrection",
]

var _kit: Kit


func before_each() -> void:
	super()
	_kit = Kit.new()


func after_each() -> void:
	if _kit != null:
		_kit.free()
		_kit = null
	super()


# --- Helpers -------------------------------------------------------------------


## The main scene for [param room], the world synced a few times so its next sync is an ordinary
## frame (the first one catches up).
func _game(room: Vector2i = ROOM_LARGE) -> Main:
	var main: Main = _main(room)
	for i: int in SEED_TICKS:
		_frame(main)
	return main


func _view(shown: HeroWindow) -> TalentTreeView:
	return shown.talents.tree_view()


## Moves the mouse onto [param control], a control on the UI layer, and lets a tooltip rest.
func _point(main: Main, control: Control) -> void:
	mouse_move(main.ui.ui_to_world(control.get_global_rect().get_center()))
	main.ui.tip.advance(UiTip.DELAY + 0.1)


func _point_away(main: Main) -> void:
	mouse_move(Vector2(-1000, -1000))
	main.ui.tip.advance(0.1)
	main.hud.advance(STEP)


## The first sentence of [param text]: up to the first full stop followed by a space, or all.
func _first_sentence(text: String) -> String:
	var at: int = text.find(". ")
	return text if at < 0 else text.left(at + 1)


## The banner [param main]'s moment shows next, once it has moved on a little.
func _banner(main: Main) -> String:
	main.ui.moment.advance(0.01)
	return main.ui.moment.shown_headline()


## Lets every banner showing or waiting go.
func _clear_banners(main: Main) -> void:
	for i: int in 8:
		main.ui.moment.advance(UiMoment.BANNER_SECONDS)


## Every Label under [param node] whose text is not empty.
func _texts(node: Node) -> Array[String]:
	var all: Array[Control] = []
	_controls(node, all)
	var found: Array[String] = []
	for control: Control in all:
		var label: Label = control as Label
		if label != null and not label.text.is_empty():
			found.append(label.text.replace("\n", " "))
	return found


func _rect_text(node: TalentNode) -> String:
	return "%s %s" % [node.ability_id, node.get_global_rect()]


## Checks that [param view] joins each node to each node that needs it, with an arrowhead into it
## that points at it.
func _check_joins(view: TalentTreeView, tree: TalentTreeDef, class_id: StringName) -> void:
	var joined: Dictionary[String, bool] = {}
	for join: Array in view.joins():
		var ends: Array = join[1]
		var a: StringName = (ends[0] as TalentNode).ability_id
		joined["%s>%s" % [a, (ends[1] as TalentNode).ability_id]] = true
	var headed: Dictionary[StringName, Rect2] = {}
	for arrow: Array in view.arrows():
		headed[(arrow[1] as TalentNode).ability_id] = arrow[0]
	for path: int in tree.paths.size():
		for node: StringName in tree.path(path).nodes:
			for before: StringName in tree.needs(node):
				var key: String = "%s>%s" % [before, node]
				assert_true(joined.has(key), "%s: %s joined" % [class_id, key])
			if tree.tier_of(node) == 1:
				assert_false(headed.has(node), "%s: no arrowhead into tier 1" % node)
				continue
			assert_true(headed.has(node), "%s: an arrowhead into %s" % [class_id, node])
			if headed.has(node):
				var into: Rect2 = view.node(node).get_global_rect()
				var head: Rect2 = headed[node]
				head.position += view.global_position
				assert_lte(head.end.y, into.position.y + 0.5, "%s: the head points in" % node)
				assert_gt(head.end.y, into.position.y - 4.0, "%s: right at it" % node)


## Checks [param tab]'s paragon medallions with three points waiting and none spent: each
## large, with its picture, its rank, its name and total under it, under the tree, and the points
## waiting beside them.
func _check_medallions(tab: HeroTalentsTab) -> void:
	var bottom: float = tab.strip.get_global_rect().end.y
	var names: Array[String] = []
	for cell: ParagonCell in tab.paragon_cells:
		var def: TrainingDef = Content.training(cell.id)
		assert_true(cell.is_visible_in_tree(), "%s: a medallion" % cell.id)
		var medal: UiIcon = cell.medallion
		assert_eq(medal.size, Vector2(36, 36), "%s: large" % cell.id)
		assert_eq(medal.picture_rect.texture, UiIcon.picture(cell.id), "%s: its picture" % cell.id)
		assert_eq(medal.count_label.text, "0", "%s: its rank as the count" % cell.id)
		assert_gte(medal.get_global_rect().position.y, bottom, "%s: under the tree" % cell.id)
		assert_eq(cell.name_label.text, def.display_name, "%s: its name" % cell.id)
		assert_gt(
			cell.name_label.get_global_rect().position.y,
			medal.get_global_rect().end.y - 0.5,
			"under"
		)
		assert_gt(
			cell.total_label.get_global_rect().position.y,
			cell.name_label.get_global_rect().position.y
		)
		names.append(cell.name_label.text)
		# Beside them, the points waiting.
		var label: Rect2 = tab.paragon_label.get_global_rect()
		assert_false(label.intersects(cell.get_global_rect()), "beside, not over")
		assert_lt(label.position.y, medal.get_global_rect().end.y, "on the same band")
	assert_eq(names, ["Power", "Toughness", "Quickness"] as Array[String])


## Steps until no fight is under way, at most [constant LIMIT_TICKS] ticks.
func _fight_over(main: Main) -> void:
	var ticks: int = 0
	while main.simulation.expedition.battle != null and ticks < LIMIT_TICKS:
		_frame(main)
		ticks += 1


func _scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found


## Checks that no node's picture or name of [param shown]'s tree overlaps another's, or a banner.
func _check_tree(shown: HeroWindow, what: String) -> void:
	var view: TalentTreeView = _view(shown)
	var boxes: Array[Rect2] = []
	var names: Array[String] = []
	for node: TalentNode in view.nodes():
		boxes.append(node.slot.get_global_rect())
		names.append("%s's picture" % node.ability_id)
		boxes.append(_text_rect(node.name_label))
		names.append("%s's name" % node.ability_id)
	for banner: PathBanner in view.banners:
		boxes.append(banner.get_global_rect())
		names.append("banner %s" % banner.name_label.text)
	for a: int in boxes.size():
		for b: int in range(a + 1, boxes.size()):
			assert_false(
				boxes[a].intersects(boxes[b]), "%s: %s over %s" % [what, names[a], names[b]]
			)


## Turns the mouse wheel over [param shown]'s scrolled part until [param control] is wholly in view
## (as a player scrolls down to the medallions), at most twenty notches.
func _into_view(main: Main, shown: HeroWindow, control: Control) -> void:
	await _frames()  # the scroll learns how tall its content has grown
	for i: int in 20:
		var seen: Rect2 = shown.scroll.get_global_rect()
		if seen.encloses(control.get_global_rect()):
			return
		var at: Vector2 = main.ui.ui_to_world(seen.get_center())
		mouse_move(at)
		mouse_button(at, true, MOUSE_BUTTON_WHEEL_DOWN)
		mouse_button(at, false, MOUSE_BUTTON_WHEEL_DOWN)
		main.hud.advance(STEP)
		await _frames()


## Opens [param hero]'s window on Talents with a point to spend, has it take its first path's
## tier-1 node now and checks the line into it lights; returns the window.
func _take_now(main: Main, hero: Hero) -> HeroWindow:
	var first: StringName = _tree(hero.class_id).path(0).nodes[0]
	set_level_keeping_health(hero, 8)
	hero.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
	main.simulation.take_talent(hero.id, first)
	_frame(main)
	assert_true(_view(shown).is_lit(first), "%s: the line lit" % hero.class_id)
	return shown


## Fails when palette colour [param colour] is one a state uses: the frames' gold, yellow, white and
## greys, the green of what is learned and of the paragon totals, and sand.
func _check_not_a_state(colour: StringName) -> void:
	var states: Array[StringName] = [
		&"amber",
		&"yellow",
		&"white",
		&"silver",
		&"steel",
		&"slate",
		&"dusk",
		&"night",
		&"ink",
		&"green",
		&"sand"
	]
	for state: StringName in states:
		assert_ne(
			Palette.color(colour), Palette.color(state), "%s is %s, a state's" % [colour, state]
		)


## Loses the party's next fight and clicks the defeat note's button reading [param text]; false
## when no fight came, the party did not fall, or the note has no such button.
func _answer_defeat(main: Main, text: String) -> bool:
	var battle: Battle = _fight(main)
	if battle == null:
		return false
	for fighter: Combatant in battle.heroes:
		fighter.health = 0
	var ticks: int = 0
	while main.simulation.expedition.state != Expedition.State.REVIVING and ticks < LIMIT_TICKS:
		_frame(main)
		ticks += 1
	var at: int = main.hud.defeat_note.suggestions().find(text)
	if at < 0:
		return false
	_click(main, main.hud.defeat_note.buttons[at])
	return true


## The last line of the card of [param view]'s node [param id]: how it stands.
func _stands(main: Main, view: TalentTreeView, id: StringName) -> String:
	_point(main, view.node(id).slot)
	var said: String = main.ui.tip.card_stand.text
	_point_away(main)
	return said


# --- Spec 109 R7 ---------------------------------------------------------------


## The events of the tick [param id] was first used, from its ABILITY_USED on.
func _at_use(events: Array[SimEvent], id: StringName) -> Array[SimEvent]:
	return _kit._landing(events, id)


## Who [param events] put [param status] on.
func _given(events: Array[SimEvent], status: AbilityEffect.Status) -> Array[int]:
	var found: Array[int] = []
	for e: SimEvent in _kit._of(events, SimEvent.Kind.STATUS_BEGAN):
		if e.status == status:
			found.append(e.target_id)
	return found


## A hero of [param overrides] holding the real ability [param id].
func _holding(id: StringName, overrides: Dictionary = {}) -> Combatant:
	var hero: Combatant = _kit._hero(1, overrides)
	return _kit._give(hero, [Content.ability(id)])


## Dummies of ids 10 on, standing at [param places].
func _dummies(battle_monsters: Array[Combatant], places: Array) -> void:
	for i: int in places.size():
		battle_monsters[i].x = places[i]


## Spec 109 R7: one built battle per new ability, its events checked.
func _check_new_abilities() -> void:
	for id: StringName in NEW_ABILITIES:
		assert_eq(Content.ability(id).validate(), PackedStringArray(), "%s is valid" % id)
		assert_true(Content.ability(id).description.ends_with("."), "%s: one plain line" % id)
	var hit: SimEvent.Kind = SimEvent.Kind.HIT
	# Damage from healing power is a DAMAGE effect's alone.
	var mend: AbilityEffect = _kit._fx("HEAL", "SELF", {"damage_from_healing": true})
	assert_true(" ".join(mend.validate()).contains("damage_from_healing"), "refused on a heal")
	for id: StringName in [&"smite", &"holy_fire", &"radiance", &"wrath"]:
		assert_true(Content.ability(id).effects[0].damage_from_healing, "%s: from healing" % id)

	# Earthshaker: every enemy takes 2x damage and is stunned.
	var monsters: Array[Combatant] = _kit._typed(
		[_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)]
	)
	var battle: Battle = _kit._battle([_holding(&"earthshaker")], monsters, 16.0)
	_dummies(monsters, [3.0, 7.0, 14.0])
	var landing: Array[SimEvent] = _at_use(_kit._run(battle, 60), &"earthshaker")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [10, 11, 12], "Earthshaker: every enemy")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [20, 20, 20], "for 2x")
	assert_eq(_given(landing, AbilityEffect.Status.STUNNED), [10, 11, 12], "all stunned")

	# War Banner: as the fight starts, every ally is hasted.
	var ally: Combatant = _kit._hero(2)
	battle = _kit._battle([_holding(&"war_banner"), ally], [_kit._dummy(10)])
	var events: Array[SimEvent] = _kit._run(battle, 3)
	assert_eq(_given(events, AbilityEffect.Status.HASTED), [1, 2], "War Banner: every ally")

	# Challenge: the nearest enemy is marked.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11)])
	battle = _kit._battle([_holding(&"challenge")], monsters)
	_dummies(monsters, [3.0, 9.0])
	landing = _at_use(_kit._run(battle, 20), &"challenge")
	assert_eq(_given(landing, AbilityEffect.Status.MARKED), [10], "Challenge: the nearest")

	# Charge: 2.5x on the furthest; it and the one beside it pushed and stunned, not the near one.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)])
	battle = _kit._battle([_holding(&"charge")], monsters)
	_dummies(monsters, [3.0, 9.0, 10.0])
	landing = _at_use(_kit._run(battle, 120), &"charge")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [12], "Charge: the furthest")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [25], "for 2.5x")
	var stunned: Array[int] = _given(landing, AbilityEffect.Status.STUNNED)
	stunned.sort()
	assert_eq(stunned, [11, 12], "stuns the target and the enemy beside it")
	assert_almost_eq(monsters[0].x, 3.0, 0.001, "the far one stays")
	assert_gt(monsters[1].x, 9.0, "pushed back")
	assert_gt(monsters[2].x, 10.0, "pushed back")

	# Toxic Cloud: the nearest and the one beside it bleed and are weakened; not the far one.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)])
	battle = _kit._battle([_holding(&"toxic_cloud")], monsters)
	_dummies(monsters, [3.0, 4.0, 12.0])
	landing = _at_use(_kit._run(battle, 20), &"toxic_cloud")
	assert_eq(_given(landing, AbilityEffect.Status.BLEEDING), [10, 11], "Toxic Cloud: bleeding")
	assert_eq(_given(landing, AbilityEffect.Status.WEAKENED), [10, 11], "and weakened")

	# Envenom: 2x through armor, and it bleeds.
	monsters = _kit._typed([_kit._dummy(10, {"armor": 6})])
	battle = _kit._battle([_holding(&"envenom")], monsters, 4.0)
	landing = _at_use(_kit._run(battle, 40), &"envenom")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [20], "Envenom: 2x, armor or not")
	assert_eq(_given(landing, AbilityEffect.Status.BLEEDING), [10], "and it bleeds")

	# Plague: on a kill, every living enemy starts bleeding.
	monsters = _kit._typed([_kit._dummy(10, {"max_health": 1}), _kit._dummy(11), _kit._dummy(12)])
	battle = _kit._battle([_holding(&"plague")], monsters)
	_dummies(monsters, [2.0, 8.0, 12.0])
	landing = _at_use(_kit._run(battle, 60), &"plague")
	assert_eq(_given(landing, AbilityEffect.Status.BLEEDING), [11, 12], "Plague: every enemy left")

	# Shadowstep: 2x and a stun on the furthest.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11)])
	battle = _kit._battle([_holding(&"shadowstep")], monsters)
	_dummies(monsters, [3.0, 10.0])
	landing = _at_use(_kit._run(battle, 120), &"shadowstep")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [11], "Shadowstep: the furthest")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [20], "for 2x")
	assert_eq(_given(landing, AbilityEffect.Status.STUNNED), [11], "and stuns it")

	# Lightning Bolt: 2.6x through armor, from its reach of 7 tiles.
	monsters = _kit._typed([_kit._dummy(10, {"armor": 6})])
	var mage: Combatant = _holding(&"lightning_bolt")
	battle = _kit._battle([mage], monsters)
	_dummies(monsters, [6.0])
	landing = _at_use(_kit._run(battle, 20), &"lightning_bolt")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [26], "Lightning Bolt: 2.6x, armor or not")

	# Static Field: as the fight starts, every enemy is slowed.
	battle = _kit._battle([_holding(&"static_field")], [_kit._dummy(10), _kit._dummy(11)])
	events = _kit._run(battle, 3)
	assert_eq(_given(events, AbilityEffect.Status.SLOWED), [10, 11], "Static Field: every enemy")

	# Overload: every fifth ordinary strike also strikes every enemy for 0.6x.
	var striker: Combatant = _holding(&"overload")
	battle = _kit._battle([striker], [_kit._dummy(10), _kit._dummy(11)], 3.0)
	events = _kit._run(battle, 160)
	var fired: Array[SimEvent] = _kit._used(events, &"overload")
	assert_gte(striker.strikes, 10, "ten strikes or more")
	assert_eq(fired.size(), floori(striker.strikes / 5.0), "Overload: on every fifth strike")
	landing = _at_use(events, &"overload")
	var sparks: Array[SimEvent] = []
	for e: SimEvent in _kit._of(landing, hit, 1):
		if e.amount == 6:
			sparks.append(e)
	assert_eq(_kit._targets(sparks), [10, 11], "every enemy, for 0.6x")

	# Thunderstorm: with an enemy within 8 tiles, every enemy takes 2.5x and is stunned.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11)])
	battle = _kit._battle([_holding(&"thunderstorm")], monsters)
	_dummies(monsters, [5.0, 15.0])
	landing = _at_use(_kit._run(battle, 20), &"thunderstorm")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [25, 25], "Thunderstorm: 2.5x, everyone")
	assert_eq(_given(landing, AbilityEffect.Status.STUNNED), [10, 11], "all stunned")

	# Radiance: every enemy within 2 tiles takes 0.4x the healing power, and every ally within 2
	# tiles of the cleric mends.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)])
	var cleric: Combatant = _holding(&"radiance", {"heal_power": 20})
	var near: Combatant = _kit._hero(2, Kit.STILL)
	var far: Combatant = _kit._hero(3, {"windup": Kit.NEVER, "move_speed": 0.0})
	battle = _kit._battle([cleric, near, far], monsters)
	_dummies(monsters, [5.0, 5.0, 12.0])
	far.x = 0.0
	landing = _at_use(_kit._run(battle, 80), &"radiance")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [10, 11], "Radiance: those near")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [8, 8], "for 0.4x the healing power")
	var mended: Array[int] = _given(landing, AbilityEffect.Status.MENDING)
	mended.sort()
	assert_eq(mended, [1, 2], "and the allies near the cleric mend, not one far off")

	# Wrath: its damage comes from the healing power too.
	monsters = _kit._typed([_kit._dummy(10)])
	battle = _kit._battle([_holding(&"wrath", {"heal_power": 20})], monsters)
	landing = _at_use(_kit._run(battle, 40), &"wrath")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [200], "Wrath: 10x the healing power")

	# Aegis: the weakest ally is shielded.
	var hurt: Combatant = _kit._hero(2)
	hurt.health = 30
	battle = _kit._battle([_holding(&"aegis"), hurt, _kit._hero(3)], [_kit._dummy(10)])
	landing = _at_use(_kit._run(battle, 20), &"aegis")
	assert_eq(_given(landing, AbilityEffect.Status.SHIELDED), [2], "Aegis: the weakest ally")

	# Hallowed Ground: as the fight starts, every enemy is weakened.
	battle = _kit._battle([_holding(&"hallowed_ground")], [_kit._dummy(10), _kit._dummy(11)])
	events = _kit._run(battle, 3)
	assert_eq(_given(events, AbilityEffect.Status.WEAKENED), [10, 11], "Hallowed Ground")

	# Resurrection: when an ally dies, every fallen ally stands up at half health, once a fight.
	var priest: Combatant = _holding(&"resurrection", Kit.STILL)
	var fallen: Combatant = _kit._hero(2, Kit.STILL)
	fallen.health = 0
	var dying: Combatant = _kit._hero(3, Kit.STILL)
	dying.health = 1
	var shooter: Combatant = _kit._shooter(10, {"damage": 5})
	battle = _kit._battle([dying, fallen, priest], [shooter])
	events = _kit._run(battle, 600)
	var revived: Array[SimEvent] = _kit._of(events, SimEvent.Kind.REVIVED)
	var raised: Array[int] = _kit._targets(revived)
	raised.sort()
	assert_eq(raised, [2, 3], "Resurrection: every fallen ally stands up")
	assert_eq(_kit._used(events, &"resurrection").size(), 1, "once a fight")
	if not revived.is_empty():
		assert_eq(revived[0].amount, 50, "with 50% health")
