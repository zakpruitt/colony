extends HudFixture
## Spec 103: "side quests" become quests, in what the player reads, the code and the data, and
## quests and gates share one base definition, [JobDef].

## A save of seed 1 on winding stages after 3000 ticks, written by the game before the rename.
const OLD_SAVE: String = (
	'{"area":"mossy_hollow","areas":{},"auto_buy":false,"auto_push":true,"deepest_depth":3,'
	+ '"gold":226,"guardian_order":"challenge","guardians_beaten":[],"heroes":['
	+ '{"class":"knight","level":5,"paragon":{"power":0,"quickness":0,"toughness":0},'
	+ '"talents":[],"xp":427},'
	+ '{"class":"rogue","level":5,"paragon":{"power":0,"quickness":0,"toughness":0},'
	+ '"talents":[],"xp":427},'
	+ '{"class":"mage","level":5,"paragon":{"power":0,"quickness":0,"toughness":0},'
	+ '"talents":[],"xp":427},'
	+ '{"class":"cleric","level":5,"paragon":{"power":0,"quickness":0,"toughness":0},'
	+ '"talents":[],"xp":427}],'
	+ '"last_stable_depth":3,"open_areas":["mossy_hollow"],"pace":"steady",'
	+ '"resources":{"glowcaps":36},"seed":1,"side_paths":"explore","target_depth":4,'
	+ '"tick":3000,"upgrades":{"fat_purse":0,"field_medicine":0,"quick_march":0,'
	+ '"sharp_blades":0,"stout_armor":0},"version":9}'
)
## The steps played from that save, and the hash they gave on the code before the rename.
const OLD_SAVE_STEPS: int = 600
## Re-recorded by spec 104, whose quests take longer and are worked by every able hero.
const OLD_SAVE_HASH: int = 1594568790
## The folders whose scripts and resources must not say "side quest", and the one line allowed to.
const CHECKED_FOLDERS: Array[String] = ["res://sim", "res://game", "res://data"]
const FORK_LABEL: String = '"sidequest/"'
const ROGUE_ID: int = 2

# --- R1 ------------------------------------------------------------------------


func test_r1_an_old_save_plays_the_same() -> void:
	var saved: Dictionary = JSON.parse_string(OLD_SAVE)
	var sim: Simulation = Simulation.from_save(saved, Main.STAGE_SHAPE)
	assert_not_null(sim, "the old save loads")
	if sim == null:
		return
	var events: Array[SimEvent] = run_ticks(sim, OLD_SAVE_STEPS)
	assert_eq(sim.state_hash(), OLD_SAVE_HASH, "and plays on as it did")
	var done: int = 0
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.QUEST_DONE:
			done += 1
	assert_gt(done, 0, "(a quest was done in those steps)")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_player_reads_quest() -> void:
	_sim = Simulation.new(1)
	_build_hud()
	_hud.advance(0.0)
	var shown: Array[String] = []
	shown.append_array(HelpPanel.IDEA)
	assert_true("\n".join(HelpPanel.IDEA).contains("unlock quests"), "the help's line")
	# The hero window's Skills tab tip.
	_ui.hero_windows.toggle(ROGUE_ID)
	var sheet: HeroWindow = _ui.hero_windows.front()
	assert_not_null(sheet, "a hero window is open")
	if sheet != null:
		var tip: String = _ui.tip.text_for(sheet.tab_buttons[HeroWindow.Page.SKILLS])
		assert_ne(tip, "", "the Skills tab has a tip")
		shown.append(tip)
	# The away story.
	var report := AwayReport.new()
	report.seconds = 600.0
	report.quests_done = 3
	report.quests_missed = 2
	report.most_needed_microskill = &"lockpicker"
	var labels: Array[String] = []
	for row: AwayStory.Row in AwayStory.rows(report, _sim.party):
		labels.append(row.label)
		shown.append("%s %s" % [row.label, row.value])
	assert_has(labels, "Quests done", "the away story's row")
	assert_has(labels, "Quests missed", "and the misses'")
	# The tally window and the journal, each told of a quest done and two missed.
	var quest: int = Content.quest_ids().find(&"locked_chest")
	var skill: int = Content.microskill_ids().find(&"lockpicker")
	for event: SimEvent in [
		SimEvent.new(SimEvent.Kind.QUEST_DONE, 1, ROGUE_ID, quest, 40),
		SimEvent.new(SimEvent.Kind.QUEST_MISSED, 2, -1, quest, skill, false),
		SimEvent.new(SimEvent.Kind.QUEST_MISSED, 3, -1, quest, skill, true),
	]:
		_world.sim_event.emit(event)
	var tally: TallyWindow = _hud.tally
	tally.open()
	tally.set_span(Tally.Span.SESSION)
	_hud.advance(STEP)
	var rows: Array[String] = tally.rows()
	assert_has(rows, "Rogue: 1 quest", "the tally's line")
	shown.append_array(rows)
	var journal: Array[String] = _hud.journal.lines()
	assert_eq(journal.size(), 3, "a journal line each")
	shown.append_array(journal)
	for text: String in shown:
		assert_false(text.to_lower().contains("side quest"), "no side quest in: %s" % text)


# --- R3 ------------------------------------------------------------------------


func test_r3_nothing_says_side_quest() -> void:
	var files: Array[String] = []
	for folder: String in CHECKED_FOLDERS:
		_files_in(folder, files)
	assert_gt(files.size(), 100, "the scripts and resources are read")
	# side_quest, sidequest, SideQuest, side quest, side-quest; not "beside QuestProps".
	var words := RegEx.create_from_string("(?i)(\\b|_)side[ _-]?quest")
	var wrong: Array[String] = []
	var labels: int = 0
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var line: String = lines[i]
			if line.contains(FORK_LABEL) and path.ends_with("chamber_rules.gd"):
				labels += 1
				line = line.replace(FORK_LABEL, "")
			if words.search(line) != null:
				wrong.append("%s:%d: %s" % [path, i + 1, lines[i].strip_edges()])
	assert_eq(labels, 1, "the random fork's label is the one place")
	assert_eq(wrong, [] as Array[String], "nothing else says side quest")


## Every .gd and .tres under [param folder], into [param into].
func _files_in(folder: String, into: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		_files_in(folder.path_join(sub), into)
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd") or file.ends_with(".tres"):
			into.append(folder.path_join(file))


# --- R4 ------------------------------------------------------------------------


func test_r4_quests_and_gates_are_jobs() -> void:
	var jobs: Array[Resource] = []
	for id: StringName in Content.quest_ids():
		jobs.append(Content.quest(id))
	for id: StringName in Content.gate_ids():
		jobs.append(Content.gate(id))
	assert_eq(jobs.size(), Content.quest_ids().size() + Content.gate_ids().size())
	for job: Resource in jobs:
		assert_true(job is JobDef, "%s is a JobDef" % job.resource_path)
		if job is QuestDef:
			assert_eq((job as JobDef).work_range(), Vector2(8.0, 18.0), "a quest: 8 to 18 seconds")
		elif job is JobDef:
			assert_eq((job as JobDef).work_range(), Vector2(3.0, 6.0), "a gate: 3 to 6 seconds")
		if job is JobDef:
			assert_eq((job as JobDef).validate(), PackedStringArray(), "and sound")
	var quest: QuestDef = Content.quest(Content.quest_ids()[0]).duplicate()
	var gate: GateDef = Content.gate(Content.gate_ids()[0]).duplicate()
	for job: JobDef in [quest, gate]:
		var unknown: JobDef = job.duplicate()
		unknown.microskill = &"juggling"
		assert_eq(
			unknown.validate(), PackedStringArray(["microskill juggling does not exist"]), "unknown"
		)
		var none: JobDef = job.duplicate()
		none.microskill = &""
		assert_eq(none.validate(), PackedStringArray(["microskill is empty"]), "no microskill")
		var span: Vector2 = job.work_range()
		for seconds: float in [span.y + 3.0, span.x - 0.5]:
			var slow: JobDef = job.duplicate()
			slow.work_seconds = seconds
			assert_eq(
				slow.validate(),
				PackedStringArray(
					["work_seconds %s is outside %s to %s" % [seconds, span.x, span.y]]
				),
				"work out of range"
			)
		var unnamed: JobDef = job.duplicate()
		unnamed.display_name = ""
		unnamed.description = ""
		assert_eq(
			unnamed.validate(),
			PackedStringArray(["display_name is empty", "description is empty"]),
			"naming"
		)
	quest.reward_factor = 0.0
	quest.miss_damage = 1.0
	assert_eq(
		quest.validate(),
		PackedStringArray(
			["reward_factor 0.0 is not above 0", "miss_damage 1.0 is outside 0 to below 1"]
		),
		"a quest's own checks follow"
	)
