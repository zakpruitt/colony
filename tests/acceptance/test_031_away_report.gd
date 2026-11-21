extends ColonyTest
## Spec 031: the away report tells the whole story. The replays here run an [AwayReplay] on a
## simulation loaded from a save held in memory, so no test reads or writes a save file.

## Ticks the saved game has played before it was saved, and the time away replayed.
const PLAYED_TICKS: int = 3000
const AWAY_SECONDS: float = 3600.0

## One hour's replay and the same hour stepped by hand, shared by R1 and R2.
var _report: AwayReport
var _stepped: Simulation
var _events: Array[SimEvent] = []


func before_all() -> void:
	var sim := Simulation.new(Main.SIMULATION_SEED)
	for i: int in PLAYED_TICKS:
		sim.step()
	sim.drain_events()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.to_save()))
	var replay := AwayReplay.new(Simulation.from_save(saved), AWAY_SECONDS)
	while not replay.run(1_000_000):
		pass
	_report = replay.report
	_stepped = Simulation.from_save(saved)
	_events.clear()
	for i: int in replay.total_ticks:
		_stepped.step()
		_events.append_array(_stepped.drain_events())


func _count(kind: SimEvent.Kind) -> int:
	var count: int = 0
	for event: SimEvent in _events:
		if event.kind == kind:
			count += 1
	return count


func _party() -> Party:
	return Simulation.new(Main.SIMULATION_SEED).party


## The panel's text before this spec, for [param report] and [param party].
func _old_text(report: AwayReport, party: Party) -> String:
	var rows: PackedStringArray = [
		"While you were away",
		"Away %s" % AwayStory.duration(report.seconds),
		"Gold +%s" % UiFormat.group_thousands(report.gold_gained),
		"Mossy Hollow %d to %d" % [report.depth_before, report.depth_after],
		# Spec 062 R5: a short list, a row each.
		"Slain %s" % UiFormat.group_thousands(report.kills),
		"Wipes %d" % report.wipes,
	]
	for hero: Hero in party.heroes:
		rows.append("%s +2 levels" % hero.def().display_name)
	rows.append(AwayWindow.CLOSE_TEXT)  # spec 062 R5: its button closes it
	return "\n".join(rows)


func _plain_report(party: Party) -> AwayReport:
	var report := AwayReport.new()
	report.seconds = 7200.0
	report.gold_gained = 1234
	report.depth_before = 3
	report.depth_after = 6
	report.area_before = &"mossy_hollow"  # spec 049: the place is an area and a stage
	report.area_after = &"mossy_hollow"
	report.kills = 210
	report.wipes = 1
	for hero: Hero in party.heroes:
		report.levels_gained[hero.id] = 2
	return report


func _skill(id: StringName) -> int:
	return Content.microskill_ids().find(id)


## A report with every new line showing: six microskills learned, so the cap is reached.
func _full_report(party: Party) -> AwayReport:
	var report: AwayReport = _plain_report(party)
	report.upgrades_bought = 3
	report.guardians_slain = 2
	report.deepest_guardian = &"clay_colossus"
	report.side_quests_done = 14
	report.side_quests_missed = 3
	report.most_needed_microskill = &"trapspotter"
	var ids: Array[StringName] = Content.microskill_ids()
	for i: int in 6:
		var hero: Hero = party.heroes[i % party.heroes.size()]
		report.microskills_learned.append(Vector2i(hero.id, i % ids.size()))
	return report


func test_r1_kills_are_kills() -> void:
	var deaths: int = 0
	var gold_gains: int = 0
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
			deaths += 1
		elif event.kind == SimEvent.Kind.GOLD_GAINED:
			gold_gains += 1
	assert_gt(_count(SimEvent.Kind.SIDE_QUEST_DONE), 0, "the hour includes side quests done")
	assert_gt(deaths, 0, "and monsters slain")
	assert_ne(gold_gains, deaths, "gold gains are not kills in this run")
	assert_eq(_report.kills, deaths, "kills are monster deaths")


func test_r2_it_counts_the_rest() -> void:
	var guardians: int = 0
	var deepest: int = -1
	var missed: Dictionary[int, int] = {}
	var learned: Array[Vector2i] = []
	for event: SimEvent in _events:
		match event.kind:
			SimEvent.Kind.GUARDIAN_SLAIN:
				guardians += 1
				deepest = maxi(deepest, event.amount)
			SimEvent.Kind.SIDE_QUEST_MISSED:
				var seen: int = missed.get(event.amount, 0)
				missed[event.amount] = seen + 1
			SimEvent.Kind.MICROSKILL_LEARNED:
				learned.append(Vector2i(event.source_id, event.target_id))
	gut.p(
		(
			"guardians %d, done %d, missed %d, learned %d"
			% [
				guardians,
				_count(SimEvent.Kind.SIDE_QUEST_DONE),
				_count(SimEvent.Kind.SIDE_QUEST_MISSED),
				learned.size()
			]
		)
	)
	assert_gt(guardians, 0, "the hour beats a guardian")
	assert_gt(learned.size(), 0, "and teaches a microskill")
	assert_eq(_report.guardians_slain, guardians, "guardians slain")
	assert_eq(
		_report.deepest_guardian, _stepped.expedition.guardian_of(deepest), "deepest guardian"
	)
	assert_ne(_report.deepest_guardian, &"", "named")
	assert_eq(_report.side_quests_done, _count(SimEvent.Kind.SIDE_QUEST_DONE), "side quests done")
	assert_eq(
		_report.side_quests_missed, _count(SimEvent.Kind.SIDE_QUEST_MISSED), "side quests missed"
	)
	assert_eq(_report.microskills_learned, learned, "microskills learned, in order")
	if missed.is_empty():
		assert_eq(_report.most_needed_microskill, &"", "nothing missed, nothing needed")
	else:
		var top: int = 0
		for skill: int in missed:
			top = maxi(top, missed[skill])
		var index: int = Content.microskill_ids().find(_report.most_needed_microskill)
		var count: int = missed.get(index, 0)
		assert_eq(count, top, "the most needed microskill was missed most")


func test_r3_the_panel_says_it() -> void:
	var party: Party = _party()
	var plain: AwayReport = _plain_report(party)
	var before := AwayWindow.new(plain, party)
	add_child_autofree(before)
	assert_eq(before.text(), _old_text(plain, party), "with none of them, the text is unchanged")

	var report: AwayReport = _full_report(party)
	var panel := AwayWindow.new(report, party)
	add_child_autofree(panel)
	var rows: PackedStringArray = panel.text().split("\n")
	assert_has(rows, "Guardians slain 2")  # spec 062 R5: a row each
	assert_has(rows, "Furthest guardian Clay Colossus")
	assert_has(rows, "Side quests done 14")
	assert_has(rows, "Side quests missed 3")
	assert_has(rows, "Upgrades bought 3")
	var ids: Array[StringName] = Content.microskill_ids()
	var learned: PackedStringArray = []
	for row: String in rows:
		if row.contains(" learned "):
			learned.append(row)
	assert_eq(learned.size(), 4, "at most four microskill lines")
	for i: int in 4:
		var hero: Hero = party.heroes[i % party.heroes.size()]
		var skill: String = Content.microskill(ids[i % ids.size()]).display_name
		assert_eq(learned[i], "%s learned %s" % [hero.def().display_name, skill], "in order")
	assert_has(rows, "and 2 more", "the rest are counted")
	assert_eq(rows[rows.size() - 1], AwayWindow.CLOSE_TEXT, "the button stays last")

	# A count of zero shows no line; one learned microskill shows no "and N more".
	var some: AwayReport = _plain_report(party)
	some.guardians_slain = 1
	some.deepest_guardian = &"slime_king"
	some.microskills_learned = [Vector2i(party.heroes[1].id, _skill(&"lockpicker"))]
	var few := AwayWindow.new(some, party)
	add_child_autofree(few)
	var text: String = few.text()
	assert_string_contains(text, "Guardians slain 1\nFurthest guardian Slime King")
	assert_string_contains(text, "%s learned Lockpicker" % party.heroes[1].def().display_name)
	assert_false(text.contains("Side quests"), "no side quest lines at zero")
	assert_false(text.contains("more"), "no 'and N more' under the cap")


func test_r4_misses_teach() -> void:
	var party: Party = _party()
	var panel := AwayWindow.new(_full_report(party), party)
	add_child_autofree(panel)
	assert_has(panel.text().split("\n"), "Most needed: Trapspotter")

	var clean: AwayReport = _full_report(party)
	clean.side_quests_missed = 0
	clean.most_needed_microskill = &""
	var none := AwayWindow.new(clean, party)
	add_child_autofree(none)
	assert_false(none.text().contains("Most needed"), "no misses, no most-needed line")
	assert_false(none.text().contains("missed"), "nor a missed line")


func test_r5_it_still_fits() -> void:
	var party: Party = _party()
	var panel := AwayWindow.new(_full_report(party), party)
	add_child_autofree(panel)
	# Spec 062: a window in the middle of the UI layer's smallest room, between the place panel
	# and the hero frames' line.
	var room := Vector2(UiRoot.MIN_ROOM)
	panel.open()
	await wait_process_frames(2)  # laid out (a hidden container is not)
	panel.centre_in(room)
	var rect := Rect2(panel.position, panel.size)
	var frames_top: float = HudFrame.frames_line(UiRoot.MIN_ROOM)
	assert_gte(rect.position.x, 0.0, "inside the screen on the left")
	assert_lte(rect.end.x, room.x, "and on the right")
	assert_gte(rect.position.y, HudFrame.FRAME_TOP + PlacePanel.HEIGHT, "below the top band")
	assert_lte(rect.end.y, frames_top, "above the party frames")
	var rows: int = panel.text().split("\n").size()
	assert_gte(rows, 16, "every line is showing")
	var labels: Array[Label] = panel.labels
	assert_eq(labels.size() + 2, rows, "a row per line, under the title and over the button")
	var body := Rect2(Vector2.ZERO, panel.size)
	for i: int in labels.size():
		var label: Label = labels[i]
		var at: Vector2 = label.get_global_rect().position - panel.get_global_rect().position
		var line := Rect2(
			at, Vector2(UiText.width(label.text) - UiText.SPACING, UiText.LINE_HEIGHT)
		)
		assert_true(body.encloses(line), "line %d inside the panel" % i)
		if i > 0:
			assert_gte(
				label.get_global_rect().position.y - labels[i - 1].get_global_rect().position.y,
				float(UiText.LINE_HEIGHT),
				"line %d clear of the one above" % i
			)
