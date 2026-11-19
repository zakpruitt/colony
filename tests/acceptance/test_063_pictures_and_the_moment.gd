extends "res://tests/acceptance/frame_062_test.gd"
## Spec 063: a picture for everything a player can gain, the slot that shows one, the tooltip card,
## the burst and the banner that mark a gain, their sounds and the sheet that shows them all. The
## slot, card and banner are driven by real mouse events pushed into the viewport; R6 by real
## simulation events through a Main.

const SPECIMEN_SCENE: String = "res://game/ui/picture_specimen.tscn"
const OLD_SHEET: String = "res://assets/sprites/ui/talent_icons"
## Pixels (of 256) two abilities of one class must differ in at least, to be told apart at a glance.
const GLANCE_PIXELS: int = 48
const PICTURE: Vector2 = Vector2(16, 16)
## A level with paragon points enough for 23 spends (one a level after 14).
const PARAGON_LEVEL: int = 40

# --- R1 ------------------------------------------------------------------------


func test_r1_its_own_picture() -> void:
	var ids: Array[StringName] = _picture_ids()
	assert_eq(ids.size(), 57, "44 abilities, 5 upgrades, 3 paragon stats and 5 microskills")
	var unique: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		unique[id] = true
	assert_eq(unique.size(), ids.size(), "no two kinds of content share an id")
	var seen: Dictionary[String, StringName] = {}
	for id: StringName in ids:
		assert_true(UiIcon.has_picture(id), "%s has a picture" % id)
		var texture: Texture2D = UiIcon.picture(id)
		assert_not_null(texture, "%s: found by its id" % id)
		if texture == null:
			continue
		assert_eq(Vector2(texture.get_size()), PICTURE, "%s: 16x16" % id)
		var image: Image = texture.get_image()
		var key: String = Marshalls.raw_to_base64(image.get_data())
		assert_false(seen.has(key), "%s is not the same picture as %s" % [id, seen.get(key, &"")])
		seen[key] = id
		assert_true(_on_palette(image), "%s: in the master palette" % id)
		assert_gt(_opaque(image), 40, "%s: a picture, not a speck" % id)
	# Abilities of one class can be told apart at a glance.
	for class_id: StringName in Content.hero_class_ids():
		var tree: Array[StringName] = _tree_of(class_id)
		for i: int in tree.size():
			for j: int in range(i + 1, tree.size()):
				var a: Image = UiIcon.picture(tree[i]).get_image()
				var b: Image = UiIcon.picture(tree[j]).get_image()
				assert_gte(
					_differing(a, b), GLANCE_PIXELS, "%s and %s differ plainly" % [tree[i], tree[j]]
				)
	assert_false(UiIcon.has_picture(&"no_such_thing"), "an unknown id has no picture")
	assert_null(UiIcon.picture(&"no_such_thing"), "and none is found")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_slot() -> void:
	var ui: UiRoot = _ui_root(ROOM_LARGE)
	var large := UiIcon.new(&"fireball")
	var small := UiIcon.new(&"fireball", false)
	var cut := UiIcon.new(&"fireball", true, UiIcon.Shape.CUT)
	for i: int in 3:
		var icon: UiIcon = [large, small, cut][i]
		icon.position = Vector2(100 + 60 * i, 100)
		ui.frame.add_child(icon)
	assert_eq(large.picture_rect.size, Vector2(32, 32), "large: at twice its size")
	assert_eq(small.picture_rect.size, Vector2(16, 16), "small: at its own size")
	assert_eq(large.picture_rect.texture, UiIcon.picture(&"fireball"), "the picture")
	assert_true(Rect2(Vector2.ZERO, large.size).encloses(large.picture_rect.get_rect()), "framed")
	assert_gt(large.size.x, 32.0, "the frame is round the picture")
	assert_lt(small.size.x, large.size.x, "the small frame is small")
	assert_eq(large.outline().size(), 4, "a square frame")
	assert_eq(cut.outline().size(), 8, "a frame with cut corners")
	# Four states, each differing in more than colour.
	var frames: Dictionary[UiIcon.State, StringName] = {}
	var tints: Dictionary[UiIcon.State, Color] = {}
	var locks: Dictionary[UiIcon.State, bool] = {}
	for state: UiIcon.State in [
		UiIcon.State.OWNED, UiIcon.State.READY, UiIcon.State.LOCKED, UiIcon.State.CLOSED
	]:
		large.show_state(state)
		assert_eq(large.state(), state, "shows state %d" % state)
		frames[state] = large.frame_colour()
		tints[state] = large.picture_rect.modulate
		locks[state] = large.has_lock()
	assert_eq(frames[UiIcon.State.OWNED], &"amber", "owned: a gold frame")
	assert_eq(tints[UiIcon.State.OWNED], Color.WHITE, "owned: full colour")
	assert_eq(frames[UiIcon.State.READY], &"yellow", "ready: a yellow frame")
	assert_eq(tints[UiIcon.State.READY], Color.WHITE, "ready: full colour")
	var locked: Color = tints[UiIcon.State.LOCKED]
	var closed: Color = tints[UiIcon.State.CLOSED]
	assert_lt(locked.v, 0.8, "locked: the picture dimmed")
	assert_lt(closed.v, locked.v / 2.0, "closed: the picture dark, barely there")
	assert_false(locks[UiIcon.State.LOCKED], "locked: no padlock")
	assert_true(locks[UiIcon.State.CLOSED], "closed: a padlock")
	assert_ne(frames[UiIcon.State.LOCKED], frames[UiIcon.State.OWNED], "locked: plain frame")
	# Only ready pulses: owned keeps its frame, ready steps and comes back.
	large.show_state(UiIcon.State.OWNED)
	var owned_colours: Dictionary[StringName, bool] = {}
	for i: int in 20:
		large.advance(0.05)
		owned_colours[large.frame_colour()] = true
	assert_eq(owned_colours.size(), 1, "owned does not pulse")
	large.show_state(UiIcon.State.READY)
	var ready_colours: Dictionary[StringName, bool] = {}
	for i: int in 30:
		large.advance(0.05)
		ready_colours[large.frame_colour()] = true
	assert_gt(ready_colours.size(), 1, "ready pulses gently")
	# The count, in the equal-width digits, at the bottom right.
	large.set_count("12/20")
	assert_true(large.count_label.visible, "a count shows")
	assert_eq(large.count_label.text, "12/20")
	assert_eq(large.count_label.get_theme_font(&"font"), UiText.font(true), "the UI font")
	assert_eq(UiText.width("1", true), UiText.width("8", true), "its digits are one width")
	var count_box: Rect2 = large.count_label.get_rect()
	assert_almost_eq(count_box.end.x, large.size.x, 3.0, "at the right")
	assert_almost_eq(count_box.end.y, large.size.y, 3.0, "at the bottom")
	large.set_count("")
	assert_false(large.count_label.visible, "no count")
	# It brightens under the real mouse, and reports a left click.
	large.show_state(UiIcon.State.LOCKED)
	var plain: StringName = large.frame_colour()
	_move(ui.ui_to_world(large.get_global_rect().get_center()))
	assert_true(large.is_lit(), "lit under the mouse")
	assert_ne(large.frame_colour(), plain, "brighter")
	watch_signals(large)
	_click_ui(ui, large.get_global_rect().get_center())
	assert_signal_emit_count(large, "clicked", 1, "a left click reports")
	_button(ui.ui_to_world(large.get_global_rect().get_center()), true, MOUSE_BUTTON_RIGHT)
	assert_signal_emit_count(large, "clicked", 1, "a right click does not")
	_move(Vector2(-50, -50))
	assert_false(large.is_lit(), "unlit when the mouse leaves")


# --- R3 ------------------------------------------------------------------------


func test_r3_the_card() -> void:
	var ui: UiRoot = _ui_root(ROOM_LARGE)
	var tip := UiTip.new()
	var carded := Control.new()
	carded.position = Vector2(400, 300)
	carded.size = Vector2(36, 36)
	var plain := Control.new()
	plain.position = Vector2(600, 300)
	plain.size = Vector2(36, 36)
	ui.frame.add_child(carded)
	ui.frame.add_child(plain)
	ui.frame.add_child(tip)
	tip.attach_card(carded, func() -> UiTip.Card: return _card(&"last_stand", "Needs a point"))
	tip.attach(plain, "Just words.", "A title")
	tip.point_at(carded.get_global_rect().get_center())
	tip.advance(UiTip.DELAY + 0.05)
	assert_true(tip.visible, "the card shows after the delay")
	assert_true(tip.card_shown(), "as a card")
	assert_eq(tip.card_picture.texture, UiIcon.picture(&"last_stand"), "the picture")
	assert_eq(tip.card_title.text, "Last Stand", "a bold title")
	assert_eq(tip.card_title.get_theme_font(&"font"), UiText.font(true), "bold")
	assert_eq(tip.card_kind.text, "Passive", "the kind")
	assert_eq(tip.card_kind.get_theme_color(&"font_color"), Palette.color(&"steel"), "in grey")
	assert_gt(tip.card_body.text.count("\n"), 0, "the body wrapped")
	assert_eq(
		tip.card_body.text.replace("\n", " "), Content.ability(&"last_stand").description, "whole"
	)
	assert_eq(tip.card_stand.text, "Needs a point", "how it stands")
	assert_eq(tip.card_stand.get_theme_color(&"font_color"), Palette.color(&"orange"), "its colour")
	var order: Array[Label] = [tip.card_title, tip.card_kind, tip.card_body, tip.card_stand]
	for i: int in range(1, order.size()):
		assert_gte(
			order[i].get_global_rect().position.y,
			order[i - 1].get_global_rect().end.y - 0.5,
			"%s under %s" % [order[i].name, order[i - 1].name]
		)
	assert_lt(
		tip.card_picture.get_global_rect().end.x,
		tip.card_title.get_global_rect().position.x + 0.5,
		"the picture beside the words"
	)
	assert_false(tip.get_global_rect().intersects(carded.get_global_rect()), "not over it")
	# A plain tip is unchanged.
	tip.point_at(plain.get_global_rect().get_center())
	tip.advance(UiTip.DELAY + 0.05)
	assert_false(tip.card_shown(), "a plain tip is not a card")
	assert_eq(tip.shown_text(), "Just words.")
	assert_eq(tip.shown_title(), "A title")
	assert_true(tip.label.is_visible_in_tree(), "its words show")
	# Cards stay above every window (spec 062 R12).
	var main: Main = _main(ROOM_LARGE)
	main.ui.windows.open_window(ShopWindow.ID)
	var shop: UiWindow = main.ui.windows.window(ShopWindow.ID)
	assert_true(_is_over(main.ui, main.ui.tip, shop), "the windows' tip is over a window")
	assert_true(_is_over(main.ui, main.hud.frame_tip, shop), "the frame's tip too")
	main.free()


# --- R4 ------------------------------------------------------------------------


func test_r4_the_burst() -> void:
	var main: Main = _settled(ROOM_LARGE)
	var moment: UiMoment = main.ui.moment
	assert_not_null(moment, "the moment is on the UI layer")
	moment.set_process(false)
	var row := HBoxContainer.new()
	row.position = Vector2(300, 300)
	main.ui.frame.add_child(row)
	var before := UiIcon.new(&"power")
	var icon := UiIcon.new(&"toughness")
	var after := UiIcon.new(&"quickness")
	for each: UiIcon in [before, icon, after]:
		row.add_child(each)
	await _frames()
	var places: Array[Vector2] = [before.position, icon.position, after.position]
	var size: Vector2 = icon.size
	main.sound.drain_started()
	moment.burst(icon)
	assert_eq(main.sound.drain_started(), [&"gain_small"] as Array[StringName], "its sound")
	assert_true(moment.is_bursting(icon), "a burst starts")
	var peak: float = 1.0
	var flashed: bool = false
	var sparks: int = 0
	var reach: float = 0.0
	var elapsed: float = 0.0
	while elapsed < 0.6:
		moment.advance(0.02)
		elapsed += 0.02
		peak = maxf(peak, icon.scale.x)
		flashed = flashed or moment.is_flashing(icon)
		sparks = maxi(sparks, moment.spark_count())
		reach = maxf(reach, moment.spark_reach())
		assert_eq(
			[before.position, icon.position, after.position], places, "nothing moves in the layout"
		)
		assert_eq(icon.size, size, "nor changes size")
		assert_eq(icon.pivot_offset, size / 2.0, "it pops about its middle")
	assert_almost_eq(peak, 1.3, 0.02, "it pops to 1.3 times its size")
	assert_true(flashed, "its frame flashes white")
	assert_gte(sparks, 8, "a ring of sparks")
	assert_gt(reach, size.x / 2.0 + 6.0, "spreading out from it")
	moment.advance(0.02)
	assert_eq(icon.scale, Vector2.ONE, "settled within 0.6 s")
	assert_false(moment.is_bursting(icon), "over")
	assert_eq(moment.spark_count(), 0, "no sparks left")
	main.ui.windows.open_window(ShopWindow.ID)
	var shop: UiWindow = main.ui.windows.window(ShopWindow.ID)
	assert_true(_is_over(main.ui, moment, shop), "drawn above the windows")
	main.free()


# --- R5 ------------------------------------------------------------------------


func test_r5_the_banner() -> void:
	for room: Vector2i in ROOMS:
		var what: String = "%s" % room
		var main: Main = _settled(room)
		var moment: UiMoment = main.ui.moment
		moment.set_process(false)
		main.sound.drain_started()
		moment.announce(&"sharp_blades", "Sharp Blades, rank 5", "+25% damage and healing")
		moment.advance(0.0)
		assert_eq(moment.shown_headline(), "Sharp Blades, rank 5", "%s: a banner drops in" % what)
		assert_true(moment.banner.is_visible_in_tree(), "%s: it shows" % what)
		assert_eq(
			main.sound.drain_started(), [&"gain_grand"] as Array[StringName], "%s: a sound" % what
		)
		assert_eq(moment.banner_picture.texture, UiIcon.picture(&"sharp_blades"), what)
		assert_eq(moment.banner_picture.size, Vector2(48, 48), "%s: at three times" % what)
		assert_eq(moment.banner_headline.get_theme_font(&"font"), UiText.font(true), "bold")
		assert_eq(moment.banner_line.text, "+25% damage and healing", "%s: a line" % what)
		moment.advance(0.5)
		var rect: Rect2 = moment.banner.get_global_rect()
		var middle: float = main.ui.frame.size.x / 2.0
		assert_almost_eq(rect.get_center().x, middle, 1.0, "%s: in the middle" % what)
		var place: Rect2 = main.hud.place_panel.get_global_rect()
		assert_gte(rect.position.y, place.end.y, "%s: under the boss bar's place" % what)
		assert_lt(rect.position.y, place.end.y + 24.0, "%s: at the top" % what)
		for piece: String in ["place panel", "purse", "hero frames"]:
			for covered: Control in _covered(main, piece):
				assert_false(
					rect.intersects(covered.get_global_rect()),
					"%s: never covers the %s" % [what, piece]
				)
		# The note after a defeat is drawn over it.
		assert_true(
			_is_over(main.ui, main.hud.defeat_note.panel, moment.banner),
			"%s: the defeat note over it" % what
		)
		# It stays 2.5 s.
		moment.advance(1.9)
		assert_eq(moment.shown_headline(), "Sharp Blades, rank 5", "%s: still at 2.4 s" % what)
		moment.advance(0.15)
		assert_eq(moment.shown_headline(), "", "%s: gone after 2.5 s" % what)
		# Or until clicked.
		moment.announce(&"fat_purse", "Fat Purse, rank 1", "+5% gold from kills")
		moment.advance(0.3)
		_click_ui(main.ui, moment.banner.get_global_rect().get_center())
		moment.advance(0.0)
		assert_eq(moment.shown_headline(), "", "%s: a click sends it away" % what)
		# They wait their turn: at most three, a newer one replacing the oldest waiting.
		for i: int in 5:
			moment.announce(&"power", "Gain %d" % (i + 1), "a line")
		assert_eq(moment.waiting(), 3, "%s: at most three wait" % what)
		var shown: Array[String] = []
		for i: int in 400:
			moment.advance(0.05)
			var headline: String = moment.shown_headline()
			if not headline.is_empty() and (shown.is_empty() or shown[-1] != headline):
				shown.append(headline)
		assert_eq(
			shown, ["Gain 3", "Gain 4", "Gain 5"] as Array[String], "%s: in turn, newest" % what
		)
		main.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_only_for_what_just_happened() -> void:
	var main: Main = _main(ROOM_LARGE)
	var moment: UiMoment = main.ui.moment
	moment.set_process(false)
	var sim: Simulation = main.simulation
	_raise(main, PARAGON_LEVEL)
	var hero: Hero = sim.party.heroes[0]
	var frame: UiIcon = UiIcon.new(&"power")
	frame.position = Vector2(300, 300)
	main.ui.frame.add_child(frame)
	var gains: Array[int] = [0]
	main.world.sim_event.connect(
		func(event: SimEvent) -> void:
			if event.kind != SimEvent.Kind.PARAGON_SPENT:
				return
			gains[0] += 1
			moment.announce(&"power", "Gain %d" % gains[0], "Power", event)
			moment.burst(frame, event)
	)
	main.world.sync(STEP)
	# A frame of 300 ticks holding ten gains: none of them just happened.
	for i: int in 10:
		sim.spend_paragon(hero.id, TrainingDef.Stat.POWER)
	for i: int in 300:
		sim.step()
	main.world.sync(STEP)
	assert_eq(gains[0], 10, "ten real gains heard")
	assert_true(main.world.catching_up(), "the world is catching up")
	moment.advance(STEP)
	assert_eq(moment.shown_headline(), "", "no banner for a stale frame")
	assert_eq(moment.waiting(), 0, "none waits")
	assert_false(moment.is_bursting(frame), "no burst")
	# Ten gains that just happened, in one frame: at most the three newest banners show.
	main.world.sync(STEP)
	gains[0] = 0
	for i: int in 10:
		sim.spend_paragon(hero.id, TrainingDef.Stat.POWER)
	sim.step()
	main.world.sync(STEP)
	assert_eq(gains[0], 10, "ten more real gains")
	assert_false(main.world.catching_up(), "not catching up")
	assert_true(moment.is_bursting(frame), "a burst for what just happened")
	var shown: Array[String] = []
	for i: int in 400:
		moment.advance(0.05)
		var headline: String = moment.shown_headline()
		if not headline.is_empty() and (shown.is_empty() or shown[-1] != headline):
			shown.append(headline)
	assert_eq(shown, ["Gain 8", "Gain 9", "Gain 10"] as Array[String], "the three newest")
	# An old event is not recent, even with no catch-up.
	var old := SimEvent.new(SimEvent.Kind.PARAGON_SPENT, sim.tick - 100, hero.id, -1, 0)
	moment.announce(&"power", "Old", "line", old)
	moment.burst(frame, old)
	moment.advance(0.0)
	assert_eq(moment.shown_headline(), "", "no banner for an old event")
	assert_false(moment.is_bursting(frame), "no burst for it")
	# Those waiting, and what is running, are dropped when a catch-up starts.
	gains[0] = 0
	for i: int in 3:
		sim.spend_paragon(hero.id, TrainingDef.Stat.POWER)
	sim.step()
	main.world.sync(STEP)
	assert_eq(moment.waiting(), 3, "three wait")
	moment.advance(0.0)
	assert_ne(moment.shown_headline(), "", "one shows")
	for i: int in 300:
		sim.step()
	main.world.sync(STEP)
	moment.advance(STEP)
	assert_eq(moment.waiting(), 0, "dropped as the catch-up starts")
	assert_eq(moment.shown_headline(), "", "the shown one too")
	assert_false(moment.is_bursting(frame), "and the burst")
	assert_eq(frame.scale, Vector2.ONE, "left at its own size")
	main.free()


# --- R7 ------------------------------------------------------------------------


func test_r7_the_present_screens_show_the_pictures() -> void:
	var main: Main = _main(ROOM_LARGE)
	_raise(main, STRONG_LEVEL)
	var windows: HeroWindows = main.hud.hero_windows
	for hero: Hero in main.simulation.party.heroes:
		windows.open(hero.id)
		var window: HeroWindow = windows.window_of(hero.id)
		var talents: HeroTalentsTab = window.talents
		var nodes: Array = talents.tree.trunk_nodes + talents.tree.path_nodes[0]
		nodes.append_array(talents.tree.path_nodes[1])
		for node: TalentNode in nodes:
			assert_eq(node.icon.texture, UiIcon.picture(node.ability_id), "%s" % node.ability_id)
			assert_eq(node.icon.size, Vector2(32, 32), "%s: at twice its size" % node.ability_id)
		for cell: ParagonCell in talents.paragon_cells:
			assert_eq(cell.picture.texture, UiIcon.picture(cell.id), "paragon %s" % cell.id)
		var skills: HeroSkillsTab = window.skills
		for card: HeroSkillsTab.Card in skills.cards:
			assert_eq(card.picture.texture, UiIcon.picture(card.skill.id), "%s" % card.skill.id)
	for row: ShopRow in main.hud.shop.rows:
		assert_eq(row.picture.texture, UiIcon.picture(row.id), "shop %s" % row.id)
	main.free()
	# The eight shared pictures of spec 060 are gone.
	for ext: String in [".px", ".png", ".json"]:
		assert_false(FileAccess.file_exists(OLD_SHEET + ext), "talent_icons%s removed" % ext)
	var script: Script = load("res://sim/defs/ability_def.gd")
	assert_false(script.get_script_constant_map().has("PICTURES"), "AbilityDef.PICTURES removed")
	var has_field: bool = false
	for property: Dictionary in script.get_script_property_list():
		has_field = has_field or property["name"] == "picture"
	assert_false(has_field, "AbilityDef.picture removed")
	for id: StringName in Content.ability_ids():
		var text: String = FileAccess.get_file_as_string("res://data/abilities/%s.tres" % id)
		assert_false(text.contains("picture ="), "%s has no picture field" % id)


# --- R8 ------------------------------------------------------------------------


func test_r8_two_sounds() -> void:
	for sound: StringName in [&"gain_small", &"gain_grand"]:
		assert_has(SoundPlayer.SOUNDS, sound, "%s is one of the sounds" % sound)
		var path: String = SoundPlayer.DIR + String(sound)
		assert_true(FileAccess.file_exists(path + ".sfx"), "%s has a recipe" % sound)
		var stream: AudioStream = load(path + ".wav") as AudioStream
		assert_not_null(stream, "%s is baked" % sound)
		if stream != null:
			assert_lte(stream.get_length(), 1.2, "%s is short" % sound)
	var main: Main = _settled(ROOM_LARGE)
	var player: SoundPlayer = main.sound
	player.set_process(false)
	for sound: StringName in [&"gain_small", &"gain_grand"]:
		player._process(1.0)
		assert_true(player.play(sound), "%s plays" % sound)
		player._process(0.1)
		assert_false(player.play(sound), "%s not again within 0.15 s" % sound)
		player._process(0.06)
		assert_true(player.play(sound), "%s again after 0.15 s" % sound)
	# The burst plays the small one, the banner the grand one, neither twice within 0.15 s.
	var moment: UiMoment = main.ui.moment
	moment.set_process(false)
	player._process(1.0)
	player.drain_started()
	var icon := UiIcon.new(&"power")
	main.ui.frame.add_child(icon)
	moment.burst(icon)
	moment.burst(icon)
	moment.announce(&"power", "One", "line")
	moment.advance(0.0)
	moment.banner_clicked()
	moment.announce(&"power", "Two", "line")
	moment.advance(0.0)
	assert_eq(
		player.drain_started(),
		[&"gain_small", &"gain_grand"] as Array[StringName],
		"each once within 0.15 s"
	)
	main.free()


# --- R9 ------------------------------------------------------------------------


func test_r9_a_sheet_to_look_at() -> void:
	assert_true(ResourceLoader.exists(SPECIMEN_SCENE), "the specimen scene exists")
	var scene: PackedScene = load(SPECIMEN_SCENE)
	var specimen: PictureSpecimen = scene.instantiate()
	add_child_autofree(specimen)
	specimen.ui.set_room_for_test(ROOM_LARGE)
	specimen.lay_out()
	var groups: Array[String] = []
	for class_id: StringName in Content.hero_class_ids():
		groups.append(Content.hero_class(class_id).display_name)
	groups.append_array(["Upgrades", "Paragon", "Skills"])
	assert_eq(specimen.group_names(), groups, "grouped by class, upgrades, paragon and skills")
	var room := Rect2(Vector2.ZERO, Vector2(ROOM_LARGE))
	for id: StringName in _picture_ids():
		var shown: Array[UiIcon] = specimen.icons_of(id)
		var states: Array[UiIcon.State] = []
		for icon: UiIcon in shown:
			states.append(icon.state())
			assert_true(room.encloses(icon.get_global_rect()), "%s: wholly on the sheet" % id)
			assert_eq(icon.picture_rect.texture, UiIcon.picture(id), "%s: its picture" % id)
		for state: UiIcon.State in [
			UiIcon.State.OWNED, UiIcon.State.READY, UiIcon.State.LOCKED, UiIcon.State.CLOSED
		]:
			assert_has(states, state, "%s in state %d" % [id, state])
		var label: Label = specimen.name_of(id)
		assert_not_null(label, "%s has its name under it" % id)
		if label != null:
			assert_eq(label.text, _display_name(id), "%s: its name" % id)
			assert_true(room.encloses(_ink(label)), "%s: its name on the sheet" % id)
			assert_gte(label.position.y, shown[0].position.y, "%s: under it" % id)
	for i: int in 40:
		specimen.advance(0.05)
	assert_true(specimen.moment.bursts_seen() > 0, "a burst")
	assert_ne(specimen.moment.shown_headline(), "", "and a banner")
	assert_true(room.encloses(specimen.moment.banner.get_global_rect()), "on the sheet")


# --- R10 -----------------------------------------------------------------------


func test_r10_fits_both_rooms() -> void:
	var longest_title: String = ""
	var longest_body: String = ""
	var longest_id: StringName
	for id: StringName in _picture_ids():
		if _display_name(id).length() > longest_title.length():
			longest_title = _display_name(id)
		if _description(id).length() > longest_body.length():
			longest_body = _description(id)
			longest_id = id
	for room: Vector2i in ROOMS:
		var what: String = "%s" % room
		var main: Main = _settled(room)
		var inside := Rect2(Vector2.ZERO, Vector2(room))
		var moment: UiMoment = main.ui.moment
		moment.set_process(false)
		moment.announce(longest_id, longest_title, longest_body)
		moment.advance(0.0)  # it drops in
		moment.advance(1.0)  # and is down
		assert_true(inside.encloses(moment.banner.get_global_rect()), "%s: banner on screen" % what)
		for label: Label in [moment.banner_headline, moment.banner_line]:
			_assert_uncut(label, moment.banner, what)
		# A card with the longest title and body, at an edge of the room.
		var tip: UiTip = main.ui.tip
		var corner := Control.new()
		corner.size = Vector2(36, 36)
		corner.position = Vector2(room) - Vector2(40, 200)
		main.ui.frame.add_child(corner)
		var card := UiTip.Card.new()
		card.picture_id = longest_id
		card.title = longest_title
		card.kind = "Action, every 45 s"
		card.body = longest_body
		card.stand = "Needs 12 more clay, from The Claypits"
		card.stand_colour = &"orange"
		tip.attach_card(corner, func() -> UiTip.Card: return card)
		tip.point_at(corner.get_global_rect().get_center())
		tip.advance(UiTip.DELAY + 0.05)
		assert_true(tip.card_shown(), "%s: the card shows" % what)
		assert_true(inside.encloses(tip.get_global_rect()), "%s: card on screen" % what)
		for label: Label in [tip.card_title, tip.card_kind, tip.card_body, tip.card_stand]:
			_assert_uncut(label, tip, what)
		main.free()


# --- Helpers -------------------------------------------------------------------


func _picture_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for class_id: StringName in Content.hero_class_ids():
		ids.append_array(_tree_of(class_id))
	for id: StringName in Content.ability_ids():
		if not ids.has(id):
			ids.append(id)
	ids.append_array(Content.upgrade_ids())
	ids.append_array(Content.training_ids())
	ids.append_array(Content.microskill_ids())
	return ids


func _tree_of(class_id: StringName) -> Array[StringName]:
	var tree: TalentTreeDef = Content.talent_tree(class_id)
	var ids: Array[StringName] = tree.trunk.duplicate()
	ids.append_array(tree.path_a)
	ids.append_array(tree.path_b)
	return ids


func _display_name(id: StringName) -> String:
	if Content.ability(id) != null:
		return Content.ability(id).display_name
	if Content.upgrade(id) != null:
		return Content.upgrade(id).display_name
	if Content.training(id) != null:
		return Content.training(id).display_name
	return Content.microskill(id).display_name


func _description(id: StringName) -> String:
	if Content.ability(id) != null:
		return Content.ability(id).description
	if Content.upgrade(id) != null:
		return Content.upgrade(id).description
	if Content.training(id) != null:
		return Content.training(id).description
	return Content.microskill(id).description


func _card(id: StringName, stand: String) -> UiTip.Card:
	var card := UiTip.Card.new()
	card.picture_id = id
	card.title = Content.ability(id).display_name
	card.kind = "Passive"
	card.body = Content.ability(id).description
	card.stand = stand
	card.stand_colour = &"orange"
	return card


## A main scene whose world has caught up and is in step, as in play from the second frame on.
func _settled(room: Vector2i) -> Main:
	var main: Main = _main(room)
	main.world.sync(STEP)
	main.world.sync(STEP)
	return main


## A UiRoot alone, laid out for [param room], over GUT's runner.
func _ui_root(room: Vector2i) -> UiRoot:
	var ui := UiRoot.new()
	add_child_autofree(ui)
	ui.set_room_for_test(room)
	ui.layer = 130
	return ui


func _covered(main: Main, piece: String) -> Array[Control]:
	match piece:
		"place panel":
			return [main.hud.place_panel] as Array[Control]
		"purse":
			return [main.hud.purse] as Array[Control]
	var frames: Array[Control] = []
	for frame: HeroFrameView in main.hud.frames:
		frames.append(frame)
	return frames


func _assert_uncut(label: Label, holder: Control, what: String) -> void:
	var bold: bool = label.get_theme_font(&"font") == UiText.font(true)
	var lines: PackedStringArray = label.text.split("\n")
	var widest: float = 0.0
	for line: String in lines:
		widest = maxf(widest, UiText.width(line, bold) - UiText.SPACING)
	var box: Rect2 = label.get_global_rect()
	assert_gte(box.size.x + 0.5, widest, "%s: %s is not cut across" % [what, label.name])
	assert_gte(box.size.y + 0.5, lines.size() * UiText.LINE_HEIGHT, "%s: nor down" % [what])
	assert_true(
		holder.get_global_rect().grow(0.5).encloses(box),
		"%s: %s inside %s %s" % [what, label.name, box, holder.get_global_rect()]
	)


func _on_palette(image: Image) -> bool:
	var colours: Dictionary[Color, bool] = {}
	for colour: Color in Palette.all():
		colours[colour] = true
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a == 0.0:
				continue
			if pixel.a < 1.0 or not colours.has(Color(pixel, 1.0)):
				return false
	return true


func _opaque(image: Image) -> int:
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


func _differing(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count
