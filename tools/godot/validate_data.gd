extends SceneTree
## Loads every resource under res://data and asks it whether it is valid.
##
## A content class opts in by defining
## [code]func validate() -> PackedStringArray[/code], returning one line per
## problem (empty when the resource is fine).
##
## Run: godot --headless --path . -s res://tools/godot/validate_data.gd

const DATA_DIR: String = "res://data"
const EXTENSIONS: PackedStringArray = ["tres", "res"]


func _init() -> void:
	var problems: int = 0
	var paths: PackedStringArray = _resources_under(DATA_DIR)
	for path: String in paths:
		for problem: String in _problems_in(path):
			problems += 1
			print("[data] FAIL %s: %s" % [path, problem])
	print("[data] %d resources, %d problems" % [paths.size(), problems])
	quit(1 if problems > 0 else 0)


func _problems_in(path: String) -> PackedStringArray:
	var resource: Resource = load(path)
	if resource == null:
		return ["does not load"]
	if not resource.has_method(&"validate"):
		return []
	var result: PackedStringArray = resource.call(&"validate")
	return result


func _resources_under(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file: String in DirAccess.get_files_at(dir):
		if EXTENSIONS.has(file.get_extension()):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_resources_under(dir.path_join(sub)))
	return found
