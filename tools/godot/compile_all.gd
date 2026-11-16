extends SceneTree
## Loads every project script so a parse error (or a warning, which this
## project treats as an error) fails `python tools/dev.py check`.
##
## Run: godot --headless --path . -s res://tools/godot/compile_all.gd

const SKIP_DIRS: PackedStringArray = ["res://addons", "res://.godot"]


func _init() -> void:
	var failed: PackedStringArray = []
	var scripts: PackedStringArray = _scripts_under("res://")
	for path: String in scripts:
		if load(path) == null:
			failed.append(path)
	for path: String in failed:
		print("[compile] FAIL %s" % path)
	print("[compile] %d scripts, %d failed" % [scripts.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)


func _scripts_under(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		var path: String = dir.path_join(sub)
		if not SKIP_DIRS.has(path):
			found.append_array(_scripts_under(path))
	return found
