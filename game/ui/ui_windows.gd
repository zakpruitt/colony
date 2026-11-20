class_name UiWindows
extends Control
## The windows on the UI layer: any number open at once, overlapping, in an
## order. A press anywhere on a window brings it to the front before what was pressed acts;
## [kbd]Esc[/kbd] closes the front window only; each window's key opens and closes it. When the
## room changes, a window the player never moved takes its default place for the new room, and one
## they did is moved wholly back in if it fits.
##
## Whether each window is open, and where it is if the player moved it, are kept in the settings
## file, beside the sound setting (the [SoundSettings] file, under [constant SETTINGS_KEY]), never
## in the save, and put back when the windows are next made; those that were open open once the
## away report has gone ([method open_waiting]). [method reset_places] puts every window back where
## a new game has it.

## Emitted when a window opens, closes or is moved, after it is saved.
signal changed

## The key the windows' places live under in the settings file.
const SETTINGS_KEY: String = "windows"

var _ui: UiRoot
var _settings: SoundSettings
## The windows by id, and the ids in the order they were registered (the button bar's order).
var _windows: Dictionary[StringName, UiWindow] = {}
var _ids: Array[StringName] = []
var _room: Vector2 = Vector2(UiRoot.MIN_ROOM)
## True while saved places are being put back, so they are not saved again on the way.
var _restoring: bool = false
## Windows that were open last session, waiting to open until the game has started.
var _waiting: Array[StringName] = []
## True while [method open_waiting] opens them.
var _opening_waiting: bool = false


func _init() -> void:
	name = "Windows"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		var under: UiWindow = window_at(button.position)
		if under != null:
			raise(under)
		return
	if KeyBook.pressed(event, KEY_ESCAPE):
		var top: UiWindow = front()
		if top != null:
			top.close()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = KeyBook.fresh_key(event)
	if key == null:
		return
	for id: StringName in _ids:
		if _windows[id].keycode == key.keycode:
			toggle(id)
			get_viewport().set_input_as_handled()
			return


## Call once: [param ui] is the layer, [param settings] where places are kept (null: nowhere).
func setup(ui: UiRoot, settings: SoundSettings) -> void:
	_ui = ui
	_settings = settings
	_room = Vector2(ui.room())


## Adds [param added] (closed, at its [member UiWindow.default_place]), unless one with its id is
## already here.
func register(added: UiWindow) -> void:
	if _windows.has(added.window_id):
		return
	_windows[added.window_id] = added
	_ids.append(added.window_id)
	add_child(added)
	added.fit_size()
	added.place_at(added.default_place, _room)
	added.open_changed.connect(_on_window_changed)
	added.moved.connect(_on_window_changed)


## The window called [param id], or null.
func window(id: StringName) -> UiWindow:
	return _windows.get(id, null)


## Every window's id, in the order they were registered.
func ids() -> Array[StringName]:
	return _ids.duplicate()


## True while the window called [param id] is open.
func is_open(id: StringName) -> bool:
	var found: UiWindow = window(id)
	return found != null and found.is_open()


## Opens the window called [param id] and brings it to the front.
func open_window(id: StringName) -> void:
	var found: UiWindow = window(id)
	if found == null:
		return
	raise(found)
	found.open()


## Closes the window called [param id].
func close_window(id: StringName) -> void:
	var found: UiWindow = window(id)
	if found != null:
		found.close()


## Opens the window called [param id] if it is closed (at the front), closes it if it is open.
func toggle(id: StringName) -> void:
	if is_open(id):
		close_window(id)
	else:
		open_window(id)


## The open window in front of every other, or null when none is open.
func front() -> UiWindow:
	for index: int in range(get_child_count() - 1, -1, -1):
		var child: UiWindow = get_child(index) as UiWindow
		if child != null and child.is_open():
			return child
	return null


## The windows from the back to the front, open or not.
func order() -> Array[UiWindow]:
	var made: Array[UiWindow] = []
	for child: Node in get_children():
		if child is UiWindow:
			made.append(child as UiWindow)
	return made


## The front-most open window under [param at], a point in the viewport's coordinates (where
## input events are), or null.
func window_at(at: Vector2) -> UiWindow:
	for index: int in range(get_child_count() - 1, -1, -1):
		var child: UiWindow = get_child(index) as UiWindow
		if child == null or not child.is_visible_in_tree():
			continue
		var local: Vector2 = child.get_global_transform_with_canvas().affine_inverse() * at
		if Rect2(Vector2.ZERO, child.size).has_point(local):
			return child
	return null


## Brings [param window] in front of every other window.
func raise(window_to_raise: UiWindow) -> void:
	if window_to_raise.get_parent() == self:
		move_child(window_to_raise, -1)


## Puts every window back at its default place, and saves.
func reset_places() -> void:
	for id: StringName in _ids:
		_windows[id].place_at(_windows[id].default_place, _room)
		_windows[id].placed = false
	_save()
	changed.emit()


## Keeps every window inside a room of [param room] UI pixels (the window was resized).
func fit_room(room: Vector2i) -> void:
	_room = Vector2(room)
	size = _room
	for id: StringName in _ids:
		var shown: UiWindow = _windows[id]
		if shown.placed:
			shown.fit_in(_room)
		else:
			shown.place_at(shown.default_place, _room)


## Puts back each window's place, as the settings file has it, and notes which were open:
## [method open_waiting] opens them.
func restore() -> void:
	var saved: Dictionary = _read().get(SETTINGS_KEY, {}) as Dictionary
	_restoring = true
	for id: StringName in _ids:
		var entry: Variant = saved.get(String(id), null)
		if not entry is Dictionary:
			continue
		var place: Dictionary = entry
		var x: Variant = place.get("x", null)
		var y: Variant = place.get("y", null)
		if x is float and y is float:  # JSON numbers are floats
			var at := Vector2(x as float, y as float)
			_windows[id].place_at(at, _room)
			_windows[id].placed = true
		if place.get("open", false) == true and not _waiting.has(id):
			_waiting.append(id)
	_restoring = false


## Opens the windows that were open last session, once, as play starts (under the away report,
## when there is one).
func open_waiting() -> void:
	var opening: Array[StringName] = _waiting.duplicate()
	_waiting.clear()
	_opening_waiting = true
	for id: StringName in opening:
		open_window(id)
	_opening_waiting = false


## True while [method open_waiting] is opening the windows left open last session.
func is_opening_waiting() -> bool:
	return _opening_waiting


## True when [param at], in the viewport's coordinates (where input events are), is on an open
## window or the button bar: what lies under it must not answer the mouse there.
func covers(at: Vector2) -> bool:
	if window_at(at) != null:
		return true
	var bar: Control = _ui.bar if _ui != null else null
	if bar == null or not bar.is_visible_in_tree():
		return false
	var local: Vector2 = bar.get_global_transform_with_canvas().affine_inverse() * at
	return Rect2(Vector2.ZERO, bar.size).has_point(local)


## Writes every window's place and whether it is open to the settings file, keeping everything
## else in it.
func _save() -> void:
	if _settings == null or _restoring:
		return
	var places: Dictionary = {}
	for id: StringName in _ids:
		var shown: UiWindow = _windows[id]
		var entry: Dictionary = {"open": shown.is_open() or _waiting.has(id)}
		if shown.placed:  # a window never moved takes the default of whatever room it is in
			entry["x"] = shown.position.x
			entry["y"] = shown.position.y
		places[String(id)] = entry
	var data: Dictionary = _read()
	data[SETTINGS_KEY] = places
	var path: String = _settings.file_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


## The settings file's dictionary, or an empty one.
func _read() -> Dictionary:
	if _settings == null or not FileAccess.file_exists(_settings.file_path()):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_settings.file_path())) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _on_window_changed(_window: UiWindow) -> void:
	_save()
	changed.emit()
