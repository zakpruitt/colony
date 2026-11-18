class_name HeroWindows
extends Node
## The hero windows (spec 060): one [HeroWindow] per hero, each a window of spec 058 registered
## with [UiWindows] as [code]hero_<n>[/code] (n the hero's place in the party, from 0), so they
## move, layer, close on [kbd]Esc[/kbd] and are remembered like any other window, and any of them
## can be open at once to compare heroes.
##
## A click on a hero's frame opens or closes its window ([method toggle]); [kbd]Tab[/kbd] opens the
## next hero's window and brings it to the front ([method open_next]); [kbd]Shift+Tab[/kbd] closes
## the front one ([method close_front]). The [Hud] passes on those keys, and [kbd]Q[/kbd],
## [kbd]E[/kbd] and [kbd]1[/kbd] to [kbd]3[/kbd] to the front hero window ([method front]).
##
## Each hero's window has its own default place. When the room is wide enough for two windows
## side by side (1280x720), they stand in two columns under the HUD's top band, clear of the hero
## frames' line: the first and third hero's on the left, the second and fourth's on the right, the
## third and fourth set in a little and lower so their title bars show. In a narrower room
## (960x540) they cascade from the top left under the top band, each set right of the one before
## and every other one down, so every title shows; there the windows are made short enough that
## two of them stay clear of the frames' line, and their tabs' content scrolls.

## Emitted when a hero window opens or closes, or another comes to the front.
signal changed

## The start of every hero window's id.
const PREFIX: String = "hero_"
## UI pixels between windows, and between them and the room's edges.
const GAP: float = 8.0
## How far the third and fourth hero's windows are set in and down from the first two, side by
## side; and how far each window of a cascade is set from the one before.
const SECOND_ROW: Vector2 = Vector2(16, 28)
const CASCADE: Vector2 = Vector2(64, 28)

var _ui: UiRoot
var _simulation: Simulation
## The windows by hero id, in the party's order.
var _windows: Dictionary[int, HeroWindow] = {}
var _ids: Array[int] = []
## The content height every window needs to show its tallest tab whole.
var _tallest: float = 0.0


func _init() -> void:
	name = "HeroWindows"


## The window id of the window of the party's [param place]th hero, from 0 ([code]&"hero_0"[/code]).
static func id_for(place: int) -> StringName:
	return StringName(PREFIX + str(place))


## Call once, after the layer's windows exist: makes a window per hero of [param simulation],
## each the same size, and registers it with [param ui]'s windows. [param tip] gives the windows'
## controls their tooltips (may be null).
func setup(simulation: Simulation, ui: UiRoot, tip: UiTip) -> void:
	_simulation = simulation
	_ui = ui
	var tallest: float = 0.0
	for hero: Hero in simulation.party.heroes:
		var made := HeroWindow.new(simulation, hero, _ids.size(), tip)
		_windows[hero.id] = made
		_ids.append(hero.id)
		tallest = maxf(tallest, made.body_height())
	_tallest = tallest
	for hero_id: int in _ids:
		var made: HeroWindow = _windows[hero_id]
		made.set_body_height(tallest)  # every hero's window the same size, to compare
		ui.windows.register(made)
		made.settle()
		made.open_changed.connect(_on_changed)
	place_defaults()
	for hero_id: int in _ids:
		_windows[hero_id].place_at(_windows[hero_id].default_place, Vector2(ui.room()))
	ui.windows.changed.connect(_on_changed.bind(null))


## Works out each hero window's default place for the room the layer has now (see the class
## description).
func place_defaults() -> void:
	if _ui == null or _ids.is_empty():
		return
	var room := Vector2(_ui.room())
	var top: float = ceilf(_ui.world_to_ui(Vector2(0, Hud.TOP_BAND)).y) + GAP / 2.0
	var frames: float = floorf(_ui.world_to_ui(Vector2(0, UiRoot.frames_top())).y) - GAP / 2.0
	_set_heights(_tallest)
	var window_size: Vector2 = _windows[_ids[0]].size
	var rows: float = top + SECOND_ROW.y + window_size.y
	var side_by_side: bool = room.x >= 2.0 * window_size.x + 3.0 * GAP and rows <= frames
	if not side_by_side:
		# Two cascaded windows, one set down from the other, clear of the frames' line.
		var chrome: float = _windows[_ids[0]].chrome_height()
		_set_heights(minf(_tallest, frames - top - CASCADE.y - chrome))
		window_size = _windows[_ids[0]].size
	for i: int in _ids.size():
		var place: Vector2
		if side_by_side:
			var column: int = i % 2
			var row: int = (i / 2) % 2
			var x: float = GAP if column == 0 else room.x - GAP - window_size.x
			var inward: float = SECOND_ROW.x * row * (1.0 if column == 0 else -1.0)
			place = Vector2(x + inward, top + SECOND_ROW.y * row)
		else:
			place = Vector2(GAP + CASCADE.x * i, top + CASCADE.y * (i % 2))
		_windows[_ids[i]].default_place = place.round()


## Makes every hero window's content [param height] UI pixels tall.
func _set_heights(height: float) -> void:
	for hero_id: int in _ids:
		_windows[hero_id].set_body_height(height)


## Brings every open window up to date with the simulation. The HUD calls it every frame.
func advance(delta: float) -> void:
	for hero_id: int in _ids:
		var shown: HeroWindow = _windows[hero_id]
		if shown.is_open():
			shown.advance(delta)


## The window of hero [param hero_id], or null.
func window_of(hero_id: int) -> HeroWindow:
	return _windows.get(hero_id, null)


## Opens hero [param hero_id]'s window in front of every other, on tab [param page] if given
## (one of [enum HeroWindow.Page]), else on the tab it had.
func open(hero_id: int, page: int = -1) -> void:
	var shown: HeroWindow = window_of(hero_id)
	if shown == null:
		return
	if page >= 0:
		shown.open_page(page as HeroWindow.Page)
	_ui.windows.open_window(shown.window_id)
	shown.advance(0.0)
	changed.emit()


## Opens hero [param hero_id]'s window, or closes it if it is open.
func toggle(hero_id: int) -> void:
	if is_open(hero_id):
		window_of(hero_id).close()
	else:
		open(hero_id)


## Opens the window of the hero after the front hero window's (the first hero's when none is
## open), wrapping, and brings it to the front; the others stay as they are.
func open_next() -> void:
	if _ids.is_empty():
		return
	var shown: HeroWindow = front()
	var index: int = _ids.find(shown.hero_id) if shown != null else -1
	open(_ids[(index + 1) % _ids.size()])


## Closes the front hero window, if one is open.
func close_front() -> void:
	var shown: HeroWindow = front()
	if shown != null:
		shown.close()


## Closes every hero window.
func close_all() -> void:
	for hero_id: int in _ids:
		_windows[hero_id].close()


## The open hero window in front of every other hero window, or null when none is open.
func front() -> HeroWindow:
	var order: Array[UiWindow] = _ui.windows.order() if _ui != null else []
	for index: int in range(order.size() - 1, -1, -1):
		var shown: HeroWindow = order[index] as HeroWindow
		if shown != null and shown.is_open():
			return shown
	return null


## True while hero [param hero_id]'s window is open; with -1, while any hero window is.
func is_open(hero_id: int = -1) -> bool:
	if hero_id < 0:
		return not open_ids().is_empty()
	var shown: HeroWindow = window_of(hero_id)
	return shown != null and shown.is_open()


## The heroes whose windows are open, in the party's order.
func open_ids() -> Array[int]:
	var made: Array[int] = []
	for hero_id: int in _ids:
		if _windows[hero_id].is_open():
			made.append(hero_id)
	return made


## Starts the flash of paragon stat [param index] in hero [param hero_id]'s window (a point just
## went in).
func flash_paragon(hero_id: int, index: int) -> void:
	var shown: HeroWindow = window_of(hero_id)
	if shown != null:
		shown.talents.flash_paragon(index)


## The tooltip of hero [param hero_id]'s frame (spec 055 R9, spec 056 R5), the one place it is
## built: [code]Click for details[/code], with the class and its path before it once a path is
## chosen ([code]Knight, Berserker: click for details[/code]), and between them the hero's
## statuses with their seconds left, [param statuses].
static func frame_tip(hero: Hero, statuses: String = "") -> String:
	var titled: String = HeroTalentsTab.title(hero) if hero != null and hero.path() >= 0 else ""
	if statuses.is_empty():
		return "Click for details" if titled.is_empty() else "%s: click for details" % titled
	var said: String = statuses if titled.is_empty() else "%s: %s" % [titled, statuses]
	return "%s. Click for details" % said


func _on_changed(_window: UiWindow) -> void:
	changed.emit()
