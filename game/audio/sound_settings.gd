class_name SoundSettings
extends RefCounted
## Keeps the player's sound choices (for now, only whether sounds are muted) in a small JSON file
## under [code]user://[/code], separate from the save (spec 021 R5). Like [SaveStore] it takes its
## path when created, so tests can give it a file of their own and never touch the real one.

## Where the game's sound settings live unless told otherwise.
const DEFAULT_PATH: String = "user://colony.settings"
## The key of the muted choice in the file.
const MUTED_KEY: String = "sfx_muted"

var _path: String


## Settings kept in the file at [param path].
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Whether sounds were left muted: false if the file is missing, unreadable or says nothing.
func muted() -> bool:
	var data: Dictionary = _read()
	var value: Variant = data.get(MUTED_KEY, false)
	return value is bool and value


## Records whether sounds are muted. Returns true if the file was written.
func set_muted(value: bool) -> bool:
	var data: Dictionary = _read()
	data[MUTED_KEY] = value
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_string(JSON.stringify(data))
	file.close()
	return stored


## The file this keeps.
func file_path() -> String:
	return _path


## The dictionary in the file, or an empty one. Raises no engine error.
func _read() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return {}
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data
