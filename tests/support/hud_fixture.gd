class_name HudFixture
extends ColonyTest
## A test of the views over a simulation of the test's own, built by hand as Main builds them
## and played by hand, none of them processing by itself.
##
## A test sets [member _sim] and builds: [method _build_hud] for the World, the CombatEffects, the
## Hud and the UI layer ([method _make_hud] also sets the simulation and shows a first frame), or
## [method _build_world] and then [method _add_hud] and [method _add_ui] for less. Everything
## built is freed after each test. Then it plays:
## - [method _frame], one frame: ticks stepped, the world synced, then [member _frame_parts];
## - [method _step_until], a tick at a time until something holds, the world and HUD following.
## [PlayFixture] adds frames of play at 60 frames a second.

## A frame at 60 frames a second.
const STEP: float = 1.0 / 60.0
## Where [method _click_at] leaves the mouse unless a test says otherwise: clear of the HUD.
const MOUSE_REST: Vector2 = Vector2(320, 200)
## The world's screen, which input and the HUD's places are in.
const SCREEN: Vector2 = Vector2(640, 360)

var _sim: Simulation
var _world: World
var _fx: CombatEffects
## Null until [method _add_hud].
var _hud: Hud
## Null until [method _add_ui].
var _ui: UiRoot
## What a frame moves on after the world, each called with the frame's seconds, in order: the HUD
## once it is built, unless the test sets others.
var _frame_parts: Array[Callable] = []
## The ticks [method _frame] steps unless a call gives them.
var _frame_ticks: int = 1
## The seconds [method _frame] moves the views on by unless a call gives them.
var _frame_seconds: float = STEP
## Every event the world has told of since [method _hear_events], oldest first.
var _events: Array[SimEvent] = []
## The seconds the world and HUD move on by for each tick [method _step_until] steps.
var _tick_seconds: float = 0.1
## Whether the HUD follows each tick [method _step_until] steps (by [member _tick_seconds]), or
## only once it ends (by a [constant STEP]).
var _hud_each_tick: bool = true
## Where [method _click_at] leaves the mouse.
var _mouse_rest: Vector2 = MOUSE_REST

# --- Building ------------------------------------------------------------------


## The World over [member _sim] and the CombatEffects on it, no HUD and no UI layer yet.
func _build_world() -> void:
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	_hud = null
	_ui = null
	_frame_parts = []


## The Hud over the world. With [param layered] it is on a canvas layer of its own, as Main has
## it, above GUT's runner (layer 128), whose window would otherwise take the mouse.
func _add_hud(layered: bool = false) -> void:
	_hud = Hud.new()
	if layered:
		var layer := CanvasLayer.new()
		layer.layer = 129
		add_child_autofree(layer)
		layer.add_child(_hud)
	else:
		add_child_autofree(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_frame_parts = [_hud.advance]


## The UI layer over the HUD (the windows, the bar, the frame of the screen): over the HUD's own
## layer when the HUD has one. Laid out for [param room] first, unless it is zero.
func _add_ui(room: Vector2i = Vector2i.ZERO) -> void:
	_ui = UiRoot.new()
	if _hud != null and _hud.get_parent() is CanvasLayer:
		_ui.layer = 130
	add_child_autofree(_ui)
	if room != Vector2i.ZERO:
		_ui.set_room_for_test(room)
	_ui.setup(_sim, _hud, null)


## The World, the CombatEffects and the Hud over [member _sim], and the UI layer unless not
## [param with_ui] (see [method _add_hud] for [param layered]).
func _build_hud(with_ui: bool = true, layered: bool = false) -> void:
	_build_world()
	_add_hud(layered)
	if with_ui:
		_add_ui()


## [method _build_hud] over [param simulation] (the UI layer laid out for [param room] unless it
## is zero), then a first frame of the HUD. Returns the HUD.
func _make_hud(
	simulation: Simulation,
	with_ui: bool = true,
	room: Vector2i = Vector2i.ZERO,
	layered: bool = false,
) -> Hud:
	_sim = simulation
	_build_world()
	_add_hud(layered)
	if with_ui:
		_add_ui(room)
	_hud.advance(0.0)
	return _hud


## From now on, every event the world tells of goes into [member _events] (emptied first, if
## [param emptied]).
func _hear_events(emptied: bool = true) -> void:
	if emptied:
		_events.clear()
	_world.sim_event.connect(func(event: SimEvent) -> void: _events.append(event))


# --- Situations ----------------------------------------------------------------


## Puts the party at the start of stage [param depth], hunting there, auto-push off, the stage
## reached and [param stable] the last held.
func _hunting_on(depth: int, stable: int) -> void:
	var e: Expedition = _sim.expedition
	_sim.set_auto_push(false)
	e.depth = depth
	e.x = _sim.labyrinth.level(depth).chambers[0].rect.position.x
	e.deepest_depth = maxi(e.deepest_depth, depth)
	e.last_stable_depth = stable
	e.target_depth = depth


## Hero [param hero_id]'s window on [param hud] (null: the test's HUD), opened.
func _open(hero_id: int, hud: Hud = null) -> HeroWindow:
	var on: Hud = _hud if hud == null else hud
	on.hero_windows.open(hero_id)
	return on.hero_windows.window_of(hero_id)


## Whether the party is in a fight.
func _fighting() -> bool:
	return _sim.expedition.state == Expedition.State.FIGHTING and _sim.expedition.battle != null


## The id of a monster the world shows, or -1.
func _monster() -> int:
	for id: int in _world._monsters:
		if _world.character(id) != null:
			return id
	return -1


## Where in [member _hud]'s goals the line [param sentence] is, or -1.
func _line(sentence: String) -> int:
	return _hud.goals.lines().find(sentence)


## The effect texts of [param kind] on show.
func _texts(kind: StringName) -> Array[FxText]:
	var found: Array[FxText] = []
	for text: FxText in _fx.texts():
		if text.kind == kind:
			found.append(text)
	return found


## The top of the highest hero frame on [param hud] (null: the test's HUD), on the 640x360 screen.
func _frames_top(hud: Hud = null) -> float:
	var top: float = SCREEN.y
	for frame: HeroFrameView in (_hud if hud == null else hud).frames:
		top = minf(top, frame.get_global_rect().position.y)
	return top


# --- Playing -------------------------------------------------------------------


## One frame: [param ticks] ticks (a negative count: [member _frame_ticks]) stepped, the world
## synced, then each of [member _frame_parts] moved on, all by [param delta] seconds (NAN:
## [member _frame_seconds]).
func _frame(ticks: int = -1, delta: float = NAN) -> void:
	var seconds: float = _frame_seconds if is_nan(delta) else delta
	for i: int in _frame_ticks if ticks < 0 else ticks:
		_sim.step()
	_world.sync(seconds)
	for part: Callable in _frame_parts:
		part.call(seconds)


## Steps the simulation a tick at a time until [param done] returns true (true), or for
## [param ticks] ticks (false), the world following each tick and the HUD as
## [member _hud_each_tick] says.
func _step_until(done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		_sim.step()
		_world.sync(_tick_seconds)
		if _hud_each_tick:
			_hud.advance(_tick_seconds)
		if done.call():
			if not _hud_each_tick:
				_hud.advance(STEP)
			return true
	if not _hud_each_tick:
		_hud.advance(STEP)
	return false


# --- The mouse -----------------------------------------------------------------


## A click at [param at] (the world's screen pixels), the mouse then left at [member _mouse_rest].
func _click_at(at: Vector2) -> void:
	click(at)
	mouse_move(_mouse_rest)


## Clicks the middle of [param control], then leaves the mouse at rest. A control on the UI layer
## is clicked once its window has laid out, [param layout_frames] frames on, through the UI's
## scale.
func _click(control: Control, layout_frames: int = 1) -> void:
	if _ui == null or not _ui.frame.is_ancestor_of(control):
		_click_at(control.get_global_rect().get_center())
		return
	for i: int in layout_frames:
		await get_tree().process_frame
	_click_at(_ui.ui_to_world(control.get_global_rect().get_center()))


## The HUD's stage list.
func _ladder() -> StageList:
	return _hud.ladder


## A left click at [param at] on the stage list, delivered as the GUI delivers one.
func _click_ladder(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		_ladder()._gui_input(event)
