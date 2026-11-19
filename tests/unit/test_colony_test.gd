extends ColonyTest
## Tests for specs/071-shared-test-base/spec.md: every test script reaches ColonyTest, the copied
## helpers are gone, and a save path goes with its backup and temporary files.

const TESTS: String = "res://tests"
const BASE: String = "res://tests/colony_test.gd"
## Helpers every test once copied, declared now by ColonyTest alone (under other names).
const COPIED: Array[String] = ["func _key(", "func _mouse("]


func test_r1_every_test_script_extends_the_base() -> void:
	var scripts: Array[String] = []
	_scripts_in(TESTS, scripts)
	assert_gt(scripts.size(), 100, "the tests are read")
	for path: String in scripts:
		if path == BASE:
			continue
		assert_true(_reaches_base(path), "%s extends ColonyTest" % path)


func test_r2_the_copied_helpers_are_gone() -> void:
	var scripts: Array[String] = []
	_scripts_in(TESTS, scripts)
	for path: String in scripts:
		var number: int = 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			for copied: String in COPIED:
				assert_false(line.begins_with(copied), "%s:%d declares %s" % [path, number, copied])


func test_r2_a_save_path_is_removed_with_its_backups() -> void:
	var path: String = save_path("r2")
	var user_dir: String = OS.get_user_data_dir()
	assert_true(ProjectSettings.globalize_path(path).begins_with(user_dir), "under user: %s" % path)
	assert_true(path.contains(str(OS.get_process_id())), "named for this process: %s" % path)
	var files: Array[String] = [path, path + SaveStore.BACKUP_SUFFIX, path + SaveStore.TEMP_SUFFIX]
	for file_path: String in files:
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string("{}")
		file.close()
		assert_true(FileAccess.file_exists(file_path), "written: %s" % file_path)
	after_each()
	for file_path: String in files:
		assert_false(FileAccess.file_exists(file_path), "removed: %s" % file_path)


## Every .gd file under [param dir], recursively.
func _scripts_in(dir: String, into: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			into.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		_scripts_in(dir.path_join(sub), into)


## Whether [param path]'s chain of `extends` reaches ColonyTest, by name or through a base.
func _reaches_base(path: String) -> bool:
	var seen: Array[String] = []
	var current: String = path
	while not seen.has(current):
		seen.append(current)
		var parent: String = _extends(current)
		if parent == "ColonyTest":
			return true
		if not parent.begins_with('"res://'):
			return false
		current = parent.trim_prefix('"').trim_suffix('"')
	return false


## What [param path] extends, as written after `extends`: a class name or a quoted path.
func _extends(path: String) -> String:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("extends "):
			return line.trim_prefix("extends ").strip_edges()
	return ""
