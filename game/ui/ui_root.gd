class_name UiRoot
extends CanvasLayer
## The sharp UI layer: drawn over the world in UI pixels, each a whole number of
## screen pixels, so text and windows are finer than the 640x360 world under them.
##
## While a UiRoot is in the tree the game window draws in
## [constant Window.CONTENT_SCALE_MODE_CANVAS_ITEMS] mode: the window still thinks in the world's
## 640x360 pixels (the world and every input event keep their coordinates), but renders
## at the window's own size. (In a [SubViewport] that stretches 640x360 the same way, as the
## screenshot tool's does, the layer leaves the viewport as it is and fits its size.) [Main] draws
## the world into a 640x360 [SubViewport] that is scaled up by a whole number with
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
## The canvas layer the UI is drawn on: above the HUD's layer (10) and the effects.
const LAYER: int = 20
## The ids of help, the journal and the orders, whose entries [WindowBook] holds.
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
## The windows on this layer, made by [method setup].
var windows: UiWindows
## The row of buttons that open and close the windows, made by [method setup].
var bar: UiButtonBar
## A window per hero, made by [method setup] when there is a HUD.
var hero_windows: HeroWindows
## The keys the front window answers, made by [method setup] when there is a HUD.
var keys: WindowKeys

## The windows on the bar as [WindowBook] lists them, each with a window, made by
## [method setup].
var entries: Array[WindowEntry] = []
## The tooltip the windows and the button bar share, made by [method setup].
var tip: UiTip
## The moment a gain is marked, above the windows, made by [method setup].
var moment: UiMoment

## The HUD whose frame of the screen is on this layer, or null.
var _hud: Hud
## The contents this layer made and advances (help, the journal, the orders, any added).
var _advanced: Array[WindowContent] = []
## The report after time away while it is up.
var _away: AwayWindow
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


## Gives the game window back the scale mode it had before the first UiRoot, if none is left.
## (It looks the window up again: when the game quits, the window may be gone by then.)
static func _restore_mode() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if _users == 0 and tree != null and is_instance_valid(tree.root):
		tree.root.content_scale_mode = _saved_mode


## Makes the windows of [WindowBook] and the button bar, puts each window back where
## [param settings] last had it (null: nowhere, as in tests and screenshots) and tells [param hud]
## of them. Call once, after the layer is in the tree.
func setup(simulation: Simulation, hud: Hud, settings: SoundSettings) -> void:
	windows = UiWindows.new()
	windows.setup(self, settings)
	if hud != null:  # the frame of the screen, under everything else on the layer
		_hud = hud
		hud.adopt_frame(self)
	bar = UiButtonBar.new()
	frame.add_child(bar)
	frame.add_child(windows)  # over the bar
	windows.fit_room(_room)
	tip = UiTip.new()  # the windows' controls share the bar's look of tooltip
	var made_here: Array[UiWindow] = _make_windows(simulation, hud)
	if hud != null:  # the hero windows, each opened from its hero's frame
		hero_windows = HeroWindows.new()
		frame.add_child(hero_windows)
		hero_windows.setup(simulation, self, tip, hud.world_view())
		hud.hero_windows = hero_windows
		keys = WindowKeys.new()
		add_child(keys)
		keys.setup(windows, hero_windows, hud.shop, hud.tally)
	moment = UiMoment.new()  # over the windows, under the tips and the defeat note
	frame.add_child(moment)
	moment.fit_room(_room)
	place_defaults()
	for made: UiWindow in made_here:
		made.place_at(made.default_place, Vector2(_room))
	bar.setup(self, windows)
	if hero_windows != null:
		hero_windows.place_defaults()  # again, now the bar has its size: they keep clear of it
	frame.add_child(tip)
	if hud != null:
		hud.lift_tip(self)  # over the bar, the windows and their own tip
	windows.restore()
	if hud != null:
		hud.windows = windows


## Advances the contents this layer made by [param delta] seconds. Called every frame; tests
## call it.
func advance(delta: float) -> void:
	for content: WindowContent in _advanced:
		if is_instance_valid(content):
			content.advance(delta)
	if bar != null:
		bar.advance(delta)


func _process(delta: float) -> void:
	advance(delta)


## Opens the report after time away telling of [param report]: a window in the middle
## of the room, in front of every other. Call after [method setup].
func show_away(report: AwayReport, party: Party) -> AwayWindow:
	var made := AwayWindow.new(report, party)
	windows.add_child(made)  # not registered: never saved, no button on the bar
	made.centre_in(Vector2(_room))
	made.open()
	windows.raise(made)
	_away = made
	return made


## A window for each entry of [WindowBook] whose content there is, registered in the list's
## order, each with its icon and its key; the bar's own list is kept as [member entries].
func _make_windows(simulation: Simulation, hud: Hud) -> Array[UiWindow]:
	var icons: PixelSheet = PixelSheet.load_sheet(ICONS_PATH)
	var made: Array[UiWindow] = []
	entries.clear()
	for entry: WindowEntry in WindowBook.entries(simulation, hud, tip):
		var content: WindowContent = entry.make_content.call()
		if content == null:
			continue
		var shown := UiWindow.new(
			entry.id, entry.title, content, KeyBook.key_name(entry.key), entry.key
		)
		shown.short_name = entry.short_name
		if icons != null and icons.has_part(entry.icon_part):
			shown.icon = icons.part(entry.icon_part)
		if not entry.advanced_elsewhere:
			_advanced.append(content)
		entries.append(entry)
		windows.register(shown)
		made.append(shown)
	return made


## Works out each window's default place for the room it has now, as its [WindowEntry] says,
## in the list's order; then the hero windows'.
func place_defaults() -> void:
	if windows == null:
		return
	var top: float = ceilf(world_to_ui(Vector2(0, HudFrame.TOP_BAND)).y) + PLACE_GAP / 2.0
	for entry: WindowEntry in entries:
		var shown: UiWindow = windows.window(entry.id)
		if shown != null:
			shown.default_place = entry.place.call(shown, Vector2(_room), top, windows)
	if hero_windows != null:
		hero_windows.place_defaults()


## The top of the hero frames' line in this layer's room, in the world's 640x360 screen pixels.
func frames_top() -> float:
	return ui_to_world(Vector2(0, HudFrame.frames_line(_room))).y


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


## [param world_px], a point in the world's 640x360 screen pixels (where the world and input
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


## Lays the layer out as a window of [param window] screen pixels would (for tests and
## screenshots). The window's own size is ignored from then on.
func set_window_for_test(window: Vector2i) -> void:
	_for_test = true
	_fit(window)
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


## The window whose title bar the mouse holds now (the away report too), or null.
func _held() -> UiWindow:
	if is_instance_valid(_away) and _away.is_dragging():
		return _away
	if windows == null:
		return null
	for id: StringName in windows.ids():
		if windows.window(id).is_dragging():
			return windows.window(id)
	return null


func _apply() -> void:
	scale = Vector2.ONE * float(_ui_scale) / float(_world_scale)
	frame.position = Vector2.ZERO
	frame.size = Vector2(_room)
	var held: UiWindow = _held()
	var held_at: Vector2 = held.position if held != null else Vector2.ZERO
	if windows != null:
		place_defaults()
		windows.fit_room(_room)
	if bar != null:
		bar.fit_room(_room)
	if moment != null:
		moment.fit_room(_room)
	if _hud != null:
		_hud.fit_frame(_room)
	if is_instance_valid(_away) and not _away.is_queued_for_deletion():
		# Centred until the player drags it; then kept where it was, moved back on screen if need be.
		if _away.placed:
			_away.fit_in(Vector2(_room))
		else:
			_away.centre_in(Vector2(_room))
	if held != null:  # it stays in the hand, not back at its default or the middle
		held.place_at(held_at, Vector2(_room))
