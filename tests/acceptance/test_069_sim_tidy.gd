extends GutTest
## Acceptance tests for specs/069-sim-tidy/spec.md. R1 is the unedited suite and the lead's
## comparison of the sim JSON; R3, R6 and R7 are for the reviewer.

## Comment text that tells history or names a spec, matched without regard to case.
const HISTORY: String = "(?i)spec \\d|since spec|\\bthe old\\b|as it was|as it did before"
## A requirement number, matched as written.
const REQUIREMENT: String = "\\bR\\d+\\b"


func test_r2_no_comment_in_sim_tells_history() -> void:
	var history := RegEx.create_from_string(HISTORY)
	var requirement := RegEx.create_from_string(REQUIREMENT)
	var files: PackedStringArray = _scripts("res://sim")
	assert_gt(files.size(), 30, "every script under sim/ is read")
	var found: PackedStringArray = []
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var comment: String = _comment(lines[i])
			if history.search(comment) != null or requirement.search(comment) != null:
				found.append("%s:%d: %s" % [path, i + 1, comment.strip_edges()])
	assert_eq(found, PackedStringArray(), "no comment names a spec or tells history")
	# The scanner finds what it is meant to find.
	assert_eq(_comment('var a: String = "#x"  # spec 049'), "# spec 049")
	assert_not_null(history.search(_comment("## Spec 051 R14: a rule")))
	assert_not_null(requirement.search(_comment("# (R14)")))
	assert_null(
		history.search(_comment("## The events recorded since the last call, oldest first."))
	)


func test_r4_seconds_become_ticks_in_one_place() -> void:
	var found: PackedStringArray = []
	var in_combatant: int = 0
	for path: String in _scripts("res://sim"):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			if not (lines[i].contains("roundi(") and lines[i].contains("TICKS_PER_SECOND")):
				continue
			if path.ends_with("/combatant.gd"):
				in_combatant += 1
			else:
				found.append("%s:%d: %s" % [path, i + 1, lines[i].strip_edges()])
	assert_eq(found, PackedStringArray(), "only Combatant turns seconds into ticks")
	assert_eq(in_combatant, 1, "Combatant.seconds_to_ticks does it, once")


## Every .gd file under [param dir], at any depth.
func _scripts(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found


## The comment on [param line], from its # to the end, or "" if it has none. A # inside a string
## does not start one.
func _comment(line: String) -> String:
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == '"' or c == "'":
			quote = c
		elif c == "#":
			return line.substr(i)
		i += 1
	return ""
