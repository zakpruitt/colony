extends GutTest
## Spec 070: the game's code is tidied, with nothing on screen changed. These tests read the
## scripts under game/ as text.

const GAME: String = "res://game"

## What R2 deletes, as a class's script and the declaration that must be gone from it.
const DEAD: Array[Array] = [
	["world/zone_crossing.gd", "func is_crossing("],
	["ui/ui_windows.gd", "func is_waiting("],
	["hud/tally.gd", "func lines_by_ability("],
	["ui/windows/window_content.gd", "func made_by("],
	["hud/depth_ladder.gd", "func risk_word("],
	["ui/ui_tip.gd", "func title_for("],
	["hud/hud.gd", "const TOP_Y:"],
	["hud/hud.gd", "const TOP_HEIGHT:"],
	["hud/hud.gd", "const FRAMES_HEIGHT:"],
	["hud/hud.gd", "const GAP:"],
	["ui/windows/talent_node.gd", "const NAME_LINES:"],
]

## The history and spec references R3 forbids in a comment. A comment that points at "the spec"
## without a number tells a reader as little as one with it.
const HISTORY: Array[String] = [
	"(?i)spec \\d",
	"\\bR\\d+\\b",
	"(?i)since spec",
	"(?i)\\bthe old\\b",
	"(?i)\\bas it was\\b",
	"(?i)\\bspecs?\\b",
]


func test_r2_the_dead_names_are_gone() -> void:
	for dead: Array in DEAD:
		var path: String = "%s/%s" % [GAME, dead[0]]
		var declared: String = dead[1]
		var text: String = FileAccess.get_file_as_string(path)
		assert_false(text.is_empty(), "%s can be read" % path)
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with(declared):
				fail_test("%s still declares %s" % [path, declared])
	# A name declared in some other file under game/ would be just as dead.
	for path: String in _scripts():
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			for dead_name: String in [
				"is_crossing(",
				"is_waiting(",
				"lines_by_ability(",
				"made_by(",
				"risk_word(",
				"title_for(",
				"FRAMES_HEIGHT",
				"NAME_LINES",
			]:
				if line.contains("func " + dead_name) or line.contains("const " + dead_name):
					fail_test("%s declares %s" % [path, dead_name])


func test_r3_no_comment_in_game_tells_history() -> void:
	var patterns: Array[RegEx] = []
	for pattern: String in HISTORY:
		patterns.append(RegEx.create_from_string(pattern))
	var found: Array[String] = []
	for path: String in _scripts():
		for comment: Array in _comments(FileAccess.get_file_as_string(path)):
			var text: String = comment[1]
			for pattern: RegEx in patterns:
				if pattern.search(text) != null:
					found.append("%s:%d: %s" % [path, comment[0], text])
					break
	assert_gt(_scripts().size(), 50, "the scripts under game/ were read")
	assert_eq(found.size(), 0, "comments that tell history:\n" + "\n".join(found.slice(0, 40)))


func test_r4_labels_are_set_one_way() -> void:
	for path: String in _scripts():
		var text: String = FileAccess.get_file_as_string(path)
		assert_false(text.contains("func _set_text"), "%s has its own _set_text" % path)
		assert_false(text.contains("func _ink"), "%s has its own _ink" % path)
	var helper: String = FileAccess.get_file_as_string(GAME + "/ui/windows/window_text.gd")
	assert_true(helper.contains("static func ink("), "WindowText.ink exists")


func test_r5_sprites_are_measured_one_way() -> void:
	var scanning: Array[String] = []
	for path: String in _scripts():
		if FileAccess.get_file_as_string(path).contains('find_children("*", "Sprite2D"'):
			scanning.append(path.get_file())
	assert_eq(scanning, ["sprite_bounds.gd"] as Array[String], "only SpriteBounds scans a sprite")


## The comments in [param source], each as [line number, text]: a run of whole-line comments
## joined into one text, so a reference wrapped across two lines is read whole, and each comment
## after code (set off by two spaces, as the formatter writes it) on its own.
func _comments(source: String) -> Array[Array]:
	var found: Array[Array] = []
	var run: Array[String] = []
	var run_start: int = 0
	var number: int = 0
	for line: String in source.split("\n"):
		number += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			if run.is_empty():
				run_start = number
			run.append(stripped.lstrip("#").strip_edges())
			continue
		if not run.is_empty():
			found.append([run_start, " ".join(run)])
			run.clear()
		var at: int = line.find("  # ")
		if at >= 0:
			found.append([number, line.substr(at + 4)])
	if not run.is_empty():
		found.append([run_start, " ".join(run)])
	return found


## Every script under game/, by path.
func _scripts() -> Array[String]:
	var found: Array[String] = []
	var folders: Array[String] = [GAME]
	while not folders.is_empty():
		var folder: String = folders.pop_back()
		for sub: String in DirAccess.get_directories_at(folder):
			folders.append("%s/%s" % [folder, sub])
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"):
				found.append("%s/%s" % [folder, file])
	found.sort()
	return found
