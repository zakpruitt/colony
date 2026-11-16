class_name SaveStore
extends RefCounted
## Keeps the save file: writes a dictionary as JSON without ever leaving half a
## file, keeps the previous save as one backup, and reads back whichever of the
## two is whole. What goes in the dictionary is the simulation's business
## ([method Simulation.to_save]); this class only knows files.

## Where the game's save lives unless a store is told otherwise.
const DEFAULT_PATH: String = "user://colony.save"
## Appended to the save's path for the file written before it is renamed into place.
const TEMP_SUFFIX: String = ".tmp"
## Appended to the save's path for the previous save.
const BACKUP_SUFFIX: String = ".bak"

var _path: String


## A store for the save at [param path]; its backup and temporary file sit beside it.
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Writes [param data] as JSON to a temporary file, keeps any existing save as the
## backup, then renames the temporary file into place. Returns true on success.
func write(data: Dictionary) -> bool:
	var temp_path: String = _path + TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_string(JSON.stringify(data))
	file.close()
	if not stored:
		DirAccess.remove_absolute(temp_path)
		return false
	if FileAccess.file_exists(_path):
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(backup_path())
		if DirAccess.rename_absolute(_path, backup_path()) != OK:
			DirAccess.remove_absolute(temp_path)
			return false
	return DirAccess.rename_absolute(temp_path, _path) == OK


## The saved dictionary; the backup's if the save is missing, unreadable, not
## JSON or not a dictionary; an empty dictionary if the backup fails too.
func read() -> Dictionary:
	for path: String in [_path, backup_path()]:
		var data: Variant = _read_dictionary(path)
		if data is Dictionary:
			return data
	return {}


## Where the previous save is kept.
func backup_path() -> String:
	return _path + BACKUP_SUFFIX


## The dictionary the file at [param path] holds as JSON, or null. Raises no engine error.
func _read_dictionary(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if not (json.data is Dictionary):
		return null
	return json.data
