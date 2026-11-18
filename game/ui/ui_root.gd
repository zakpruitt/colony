class_name UiRoot
extends CanvasLayer
## The sharp UI layer (spec 058 R1): drawn over the world in UI pixels, each a whole number of
## screen pixels, so text and windows are finer than the 640x360 world under them.
##
## While a UiRoot is in the tree the game window draws in
## [constant Window.CONTENT_SCALE_MODE_CANVAS_ITEMS] mode: the window still thinks in the world's
## 640x360 pixels (the world, the old HUD and every input event keep their coordinates), but renders
## at the window's own size. (In a [SubViewport] that stretches 640x360 the same way, as the
## screenshot tool's does, the layer leaves the viewport as it is and fits its size.) [Main] draws
## the world and the old HUD into a 640x360 [SubViewport] that is scaled up by a whole number with
## hard edges; this layer is scaled by [code]ui_scale / world_scale[/code] on top, so one UI pixel
## is [method ui_scale] screen pixels. The UI scale is the largest whole number that still leaves
## [constant MIN_ROOM] of room, so the room is between 960x540 and about 1280x720.
##
## Everything on the layer is a child of [member frame], a [Control] as big as [method room] that
## carries the theme ([UiTheme]). Windows ([member windows]) and the button bar ([member bar]) are
## made by [method setup].

## The world's own size in its pixels; the window is a whole multiple of it.
const WORLD_SIZE: Vector2i = Vector2i(640, 360)
## The least room the UI is given, in UI pixels, when the window is big enough for it.
const MIN_ROOM: Vector2i = Vector2i(960, 540)
## The canvas layer the UI is drawn on: above the old HUD (10) and the effects.
const LAYER: int = 20
## The windows spec 058 made, by id.
const HELP: StringName = &"help"
const JOURNAL: StringName = &"journal"
const ORDERS: StringName = &"orders"
## The window icons' sheet: a part per window id.
const ICONS_PATH: String = "res://assets/sprites/ui/window_icons.png"
## UI pixels between default places, and between them and the room's edges and the HUD's bands.
const PLACE_GAP: float = 8.0

## How many windows' worth of UiRoots are in the tree, and the window's scale mode before the first.
static var _users: int = 0
static var _saved_mode: Window.ContentScaleMode = Window.CONTENT_SCALE_MODE_VIEWPORT

## The room-sized control everything on the layer hangs from, themed by [UiTheme].
var frame: Control
## The windows on this layer (spec 058 R5), made by [method setup].
var windows: UiWindows
## The row of buttons that open and close the windows (spec 058 R7), made by [method setup].
var bar: UiButtonBar

var _world_scale: int = 1
var _ui_scale: int = 1
var _room: Vector2i = WORLD_SIZE
## True once a test has chosen the room: the window's own size is then ignored.
var _for_test: bool = false


func _init() -> void:
	name = "UI"
	layer = LAYER
	frame = Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme = UiTheme.theme()
	add_child(frame)


func _enter_tree() -> void:
	var host: Viewport = get_viewport()
	var window: Window = host as Window
	if window != null:
		if _users == 0:
			_saved_mode = window.content_scale_mode
		_users += 1
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if not host.size_changed.is_connected(_refit):
		host.size_changed.connect(_refit)
	_refit()


func _exit_tree() -> void:
	var host: Viewport = get_viewport()
	if host.size_changed.is_connected(_refit):
		host.size_changed.disconnect(_refit)
	var window: Window = host as Window
	if window == null:
		return
	_users = maxi(_users - 1, 0)
	# Not now: changing the mode while a scene leaves the tree makes the window rebuild its canvas
	# in the middle of the scene's exit, and the controls still leaving it then fail to let go.
	UiRoot._restore_mode.call_deferred()


## Puts the game window's scale mode back as it was before the first UiRoot, if none is left.
## (It looks the window up again: when the game quits, the window may be gone by then.)
static func _restore_mode() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if _users == 0 and tree != null and is_instance_valid(tree.root):
		tree.root.content_scale_mode = _saved_mode


## Makes the windows (help, the journal and the orders, spec 058 R8) and the button bar, puts
## each window back where [param settings] last had it (null: nowhere, as in tests and screenshots)
## and tells [param hud] of them. Call once, after the layer is in the tree.
func setup(simulation: Simulation, hud: Hud, settings: SoundSettings) -> void:
	windows = UiWindows.new()
	windows.setup(self, settings)
	bar = UiButtonBar.new()
	frame.add_child(bar)
	frame.add_child(windows)  # over the bar
	windows.fit_room(_room)
	var icons: PixelSheet = PixelSheet.load_sheet(ICONS_PATH)
	var tip := UiTip.new()  # the orders' choices share the bar's look of tooltip
	var help := UiWindow.new(HELP, HelpPanel.TITLE, HelpPanel.new(), "H", KEY_H)
	var view := JournalView.new()
	var journal := UiWindow.new(JOURNAL, "Journal", view, "J", KEY_J)
	var panel := OrdersPanel.new()
	var orders := UiWindow.new(ORDERS, OrdersPanel.TITLE, panel, "O", KEY_O)
	for made: UiWindow in [help, journal, orders]:
		made.icon = icons.part(made.window_id) if icons != null else null
	if hud != null and hud.journal != null:
		view.setup(hud.journal)
	panel.setup(simulation, tip)
	for made: UiWindow in [help, journal, orders]:
		windows.register(made)
	place_defaults()
	for made: UiWindow in [help, journal, orders]:
		made.place_at(made.default_place, Vector2(_room))
	bar.setup(self, windows)
	frame.add_child(tip)
	windows.restore()
	if hud != null:
		hud.windows = windows


## Works out each window's default place for the room it has now, none over another: the journal
## at the top left under the HUD's top band, help at the top right, and the orders under the
## journal, or lower still, under where the area map opens, when that leaves the hero frames' line
## clear. Until specs 059 to 061 move the old panels, the journal and help cannot also keep clear
## of where they open (they fill the top of the screen); the HUD closes a window over a panel as it
## opens ([method Hud.advance]).
func place_defaults() -> void:
	if windows == null:
		return
	var top: float = ceilf(world_to_ui(Vector2(0, Hud.TOP_BAND)).y) + PLACE_GAP / 2.0
	var journal: UiWindow = windows.window(JOURNAL)
	var orders: UiWindow = windows.window(ORDERS)
	var help: UiWindow = windows.window(HELP)
	if journal != null:
		journal.default_place = Vector2(PLACE_GAP, top)
	if orders != null and journal != null:
		var under: float = top + journal.size.y + PLACE_GAP
		var map_bottom: float = (
			Hud.TOP_BAND + AreaMap.DROP + AreaMap.height_for(Content.area_ids().size())
		)
		var lower: float = ceilf(world_to_ui(Vector2(0, map_bottom)).y) + PLACE_GAP
		var frames: float = floorf(world_to_ui(Vector2(0, frames_top())).y)
		if lower > under and lower + orders.size.y + PLACE_GAP <= frames:
			under = lower
		orders.default_place = Vector2(PLACE_GAP, under)
	if help != null:
		help.default_place = Vector2(_room.x - PLACE_GAP - help.size.x, top)


## The top of the hero frames' line, in the world's 640x360 screen pixels.
static func frames_top() -> float:
	return Hud.SCREEN.y - Hud.MARGIN - HeroFrame.SIZE.y


## How many screen pixels one UI pixel is.
func ui_scale() -> int:
	return _ui_scale


## How many screen pixels one world pixel is.
func world_scale() -> int:
	return _world_scale


## The UI's room in UI pixels: the part of the window the world is drawn in, divided by
## [method ui_scale].
func room() -> Vector2i:
	return _room


## [param world_px], a point in the world's 640x360 screen pixels (where the old HUD and input
## events are), in UI pixels.
func world_to_ui(world_px: Vector2) -> Vector2:
	return world_px * float(_world_scale) / float(_ui_scale)


## [param ui_px], a point in UI pixels, in the world's 640x360 screen pixels.
func ui_to_world(ui_px: Vector2) -> Vector2:
	return ui_px * float(_ui_scale) / float(_world_scale)


## Lays the layer out as a window whose UI room is [param ui_room] would (for tests and
## screenshots): 1280x720 as a 1280x720 window, 960x540 as a 1920x1080 one. The window's own size
## is ignored from then on.
func set_room_for_test(ui_room: Vector2i) -> void:
	_for_test = true
	var window: Vector2i = ui_room
	for times: int in range(1, 5):
		if room_for(ui_room * times) == ui_room:
			window = ui_room * times
			break
	_fit(window)
	_room = ui_room
	_apply()


## The world's scale in a window of [param window] screen pixels: the largest whole number that
## fits 640x360 in it, at least 1.
static func world_scale_for(window: Vector2i) -> int:
	return maxi(1, mini(window.x / WORLD_SIZE.x, window.y / WORLD_SIZE.y))


## The UI's scale in a window of [param window] screen pixels: the largest whole number that still
## leaves [constant MIN_ROOM] of room in the world's part of the window, at least 1.
static func ui_scale_for(window: Vector2i) -> int:
	var shown: Vector2i = WORLD_SIZE * world_scale_for(window)
	return maxi(1, mini(shown.x / MIN_ROOM.x, shown.y / MIN_ROOM.y))


## The UI's room in a window of [param window] screen pixels, in UI pixels.
static func room_for(window: Vector2i) -> Vector2i:
	return WORLD_SIZE * world_scale_for(window) / ui_scale_for(window)


func _refit() -> void:
	if _for_test or not is_inside_tree():
		return
	var host: Viewport = get_viewport()
	var window: Window = host as Window
	_fit(window.size if window != null else (host as SubViewport).size)
	_apply()


func _fit(window: Vector2i) -> void:
	_world_scale = world_scale_for(window)
	_ui_scale = ui_scale_for(window)
	_room = room_for(window)


func _apply() -> void:
	scale = Vector2.ONE * float(_ui_scale) / float(_world_scale)
	frame.position = Vector2.ZERO
	frame.size = Vector2(_room)
	if windows != null:
		place_defaults()
		windows.fit_room(_room)
	if bar != null:
		bar.fit_room(_room)
