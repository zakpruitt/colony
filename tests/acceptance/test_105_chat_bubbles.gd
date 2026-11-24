extends MainFixture
## Spec 105: a character in the world says a short line in a bubble over its head, drawn sharp on
## the UI layer, following the speaker, under the windows, and gone with stale time.

const KNIGHT: int = 1
const ROGUE: int = 2
const LINE: String = "Hold still, friend."
const LONG_LINE: String = (
	"We have walked these tunnels since the lamps were lit, and the dark still goes on further"
	+ " than any of us can see, so keep your blades out and your eyes open"
)
## How far a tail's tip may be from the point it points at, in UI pixels.
const NEAR: float = 2.0
const SHOWCASE: String = "res://game/dev/showcase.tscn"
const FRAME: float = 1.0 / 60.0

# --- Helpers -------------------------------------------------------------------


## The top of character [param id]'s sprite, its head, in UI pixels on [param main]'s layer.
func _head_ui(main: Main, id: int) -> Vector2:
	var sprite: CharacterSprite = main.world.character(id)
	var head: Vector2 = sprite.global_position + Vector2(0, SpriteBounds.box_of(sprite).position.y)
	return main.ui.world_to_ui(main.world_viewport.get_canvas_transform() * head)


## A world point [param ui_px] (UI pixels) is over, as the camera has it now.
func _world_under(main: Main, ui_px: Vector2) -> Vector2:
	var screen: Vector2 = main.ui.ui_to_world(ui_px)
	return main.world.get_global_transform_with_canvas().affine_inverse() * screen


## Where world point [param at] is on [param main]'s UI layer, as the camera has it now.
func _ui_of(main: Main, at: Vector2) -> Vector2:
	return main.ui.world_to_ui(main.world.get_global_transform_with_canvas() * at)


## [param frames] frames of [param main] with [param ticks] ticks each.
func _frames_of(main: Main, frames: int, ticks: int = 0) -> void:
	for i: int in frames:
		_frame(main, ticks)


# --- R1 ------------------------------------------------------------------------


func test_r1_a_bubble_shows_over_its_speaker() -> void:
	var main: Main = _main(ROOM_LARGE)
	_frame(main)
	var bubbles: SpeechBubbles = main.ui.bubbles
	assert_eq(main.world.bubbles, bubbles, "Main hands the layer's bubbles to the world")
	main.world.say(KNIGHT, LINE)
	_frame(main, 0)
	assert_eq(bubbles.line_of(KNIGHT), LINE, "the line shows")
	assert_eq(bubbles.shown_count(), 1, "in one bubble")
	var bubble: SpeechBubble = bubbles.bubble_of(KNIGHT)
	var head: Vector2 = _head_ui(main, KNIGHT)
	assert_lt(bubble.tip().distance_to(head), NEAR, "its tail points at the head %s" % head)
	assert_lt(bubble.reach().position.y + bubble.size.y, head.y, "the panel is over the head")
	assert_eq(bubble.lines(), PackedStringArray([LINE]), "a short line is one line")

	main.world.say(ROGUE, LONG_LINE)
	_frame(main, 0)
	var long: SpeechBubble = bubbles.bubble_of(ROGUE)
	assert_eq(long.lines().size(), SpeechBubble.MOST_LINES, "a long line wraps onto 3 lines")
	for line: String in long.lines():
		assert_lte(UiText.width(line), SpeechBubble.WIDTH, "'%s' is at most 160 wide" % line)
	assert_true(long.lines()[0].begins_with("We have walked"), "it starts where the line starts")

	var spot: Vector2 = _world_under(main, Vector2(400, 300))
	var wanderer: Callable = func() -> Vector2: return spot
	main.world.say(wanderer, "Help me!")
	_frame(main, 0)
	assert_eq(bubbles.line_of(wanderer), "Help me!", "a Callable speaker has a bubble too")
	var tip: Vector2 = bubbles.bubble_of(wanderer).tip()
	assert_lt(tip.distance_to(_ui_of(main, spot)), NEAR, "over the point it returns")

	var short_hold: float = 1.2 + 0.06 * "Hi.".length()
	assert_almost_eq(SpeechBubbles.hold_for("Hi.", 0.0), short_hold, 0.001, "1.2 s + 0.06 s each")
	assert_almost_eq(SpeechBubbles.hold_for(LONG_LINE, 0.0), 4.0, 0.001, "capped at 4 s")
	assert_almost_eq(SpeechBubbles.hold_for("Hi.", 2.5), 2.5, 0.001, "a given time is kept")
	bubbles.clear()
	main.world.say(KNIGHT, "Hi.")
	_frames_of(main, roundi((short_hold - 0.1) / STEP))
	assert_eq(bubbles.line_of(KNIGHT), "Hi.", "it still shows a little before its hold is up")
	_frames_of(main, roundi(0.2 / STEP))
	assert_eq(bubbles.shown_count(), 0, "and is gone a little after")


# --- R2 ------------------------------------------------------------------------


func test_r2_it_follows_its_speaker() -> void:
	var main: Main = _main(ROOM_LARGE)
	_frame(main)
	var bubbles: SpeechBubbles = main.ui.bubbles
	main.world.say(KNIGHT, LINE, 30.0)
	_frame(main, 0)
	var from: float = main.world.feet_position(KNIGHT).x
	var camera_from: Vector2 = main.world_viewport.get_canvas_transform().origin
	for i: int in 3000:
		_frame(main)
		var walked: bool = absf(main.world.feet_position(KNIGHT).x - from) >= 40.0
		if walked and main.world_viewport.get_canvas_transform().origin != camera_from:
			break
	assert_gte(absf(main.world.feet_position(KNIGHT).x - from), 40.0, "the knight walked 40 px")
	var camera_to: Vector2 = main.world_viewport.get_canvas_transform().origin
	assert_ne(camera_to, camera_from, "and the camera moved")
	var head: Vector2 = _head_ui(main, KNIGHT)
	var tip: Vector2 = bubbles.bubble_of(KNIGHT).tip()
	assert_lt(tip.distance_to(head), NEAR, "the tail still points at the head")

	var room := Vector2(main.ui.room())
	for at: Vector2 in [Vector2(10, 300), Vector2(room.x - 10, 300)]:
		var spot: Vector2 = _world_under(main, at)
		var edge: Callable = func() -> Vector2: return spot
		main.world.say(edge, LONG_LINE)
		_frame(main, 0)
		var bubble: SpeechBubble = bubbles.bubble_of(edge)
		var panel: Rect2 = bubble.reach()
		assert_gte(panel.position.x, 0.0, "a speaker at %s keeps the panel inside on the left" % at)
		assert_lte(panel.end.x, room.x, "and on the right")
		var speaker_x: float = _ui_of(main, spot).x
		assert_lt(absf(bubble.tip().x - speaker_x), NEAR, "while the tail still points at it")
		bubbles.clear()

	main.world._remove(KNIGHT)
	_frame(main, 0)
	assert_eq(bubbles.line_of(KNIGHT), "", "a speaker that is gone takes its bubble with it")
	assert_eq(bubbles.shown_count(), 0, "none is left")


# --- R3 ------------------------------------------------------------------------


func test_r3_one_bubble_a_speaker() -> void:
	var main: Main = _main(ROOM_LARGE)
	_frame(main)
	var bubbles: SpeechBubbles = main.ui.bubbles
	main.world.say(KNIGHT, "First.")
	main.world.say(KNIGHT, "Second.")
	_frame(main, 0)
	assert_eq(bubbles.shown_count(), 1, "one bubble a speaker")
	assert_eq(bubbles.line_of(KNIGHT), "Second.", "the later line replaces the first")

	bubbles.clear()
	main.world.say(KNIGHT, "Short.", 1.0)
	var hidden: int = 0
	var partly: int = 0
	var frames: int = 0
	var bubble: SpeechBubble = null
	while bubbles.shown_count() > 0 and frames < 200:
		_frame(main, 0)
		frames += 1
		bubble = bubbles.bubble_of(KNIGHT)
		if bubble == null:
			break
		if not bubble.visible:
			hidden += 1
		for node: CanvasItem in [bubbles, bubble, bubble.tail]:
			if node.modulate.a < 1.0 or node.self_modulate.a < 1.0:
				partly += 1
	assert_eq(bubbles.shown_count(), 0, "after its hold the bubble is gone")
	assert_almost_eq(frames * STEP, 1.0, 2.0 * STEP, "after 1 s")
	assert_gt(hidden, 0, "it blinked out")
	assert_eq(partly, 0, "never partly transparent")

	main.world.say(KNIGHT, LINE)
	main.world.say(ROGUE, LINE)
	_frame(main, 0)
	assert_eq(bubbles.shown_count(), 2, "two speakers, two bubbles")
	var first: Rect2 = bubbles.bubble_of(KNIGHT).reach()
	var second: Rect2 = bubbles.bubble_of(ROGUE).reach()
	assert_false(first.intersects(second), "side by side they do not overlap")
	assert_lt(second.position.y, first.position.y, "the later one is nudged up")


# --- R4 ------------------------------------------------------------------------


func test_r4_windows_cover_bubbles() -> void:
	var main: Main = _main(ROOM_LARGE)
	var ui: UiRoot = main.ui
	var bubbles: SpeechBubbles = ui.bubbles
	assert_eq(bubbles.get_parent(), ui.frame, "the bubbles hang from the layer's frame")
	var at: int = bubbles.get_index()
	assert_lt(main.hud.screen_frame.get_index(), at, "over the frame of the screen")
	for over: Node in [ui.bar, ui.windows, ui.hero_windows, ui.moment, ui.tip]:
		assert_gt(over.get_index(), at, "under %s" % over.name)
	assert_eq(bubbles.mouse_filter, Control.MOUSE_FILTER_IGNORE, "they take no mouse")
	main.world.say(KNIGHT, LINE)
	_frame(main, 0)
	var controls: Array[Control] = []
	_controls(bubbles, controls)
	assert_gt(controls.size(), 0, "a bubble is a control")
	for control: Control in controls:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s takes none" % control)


# --- R5 ------------------------------------------------------------------------


func test_r5_stale_time_starts_nothing() -> void:
	var main: Main = _main(ROOM_LARGE)
	_frame(main)
	var bubbles: SpeechBubbles = main.ui.bubbles
	var sim: Simulation = main.simulation
	var old := SimEvent.new(SimEvent.Kind.HIT, sim.tick - World.ANIMATE_TICKS - 1)
	main.world.say_for(old, KNIGHT, LINE)
	_frame(main, 0)
	assert_eq(bubbles.shown_count(), 0, "an old event shows nothing")
	var fresh := SimEvent.new(SimEvent.Kind.HIT, sim.tick)
	main.world.say_for(fresh, KNIGHT, LINE)
	_frame(main, 0)
	assert_eq(bubbles.shown_count(), 1, "a fresh one shows its line")

	_frame(main, World.STALL_TICKS * 4)
	assert_true(main.world.catching_up(), "a stall is caught up on")
	assert_eq(bubbles.shown_count(), 0, "and clears the bubbles")

	# On to stage 2, a tick a frame, a bubble always up until the world shows another stage.
	raise_party(sim, 30)
	sim.expedition.target_depth = 2
	var spot: Vector2 = _world_under(main, Vector2(400, 300))
	var wanderer: Callable = func() -> Vector2: return spot
	var stage: int = main.world.shown_stage()
	var changed: bool = false
	for i: int in 20000:
		if bubbles.shown_count() == 0:
			main.world.say(wanderer, LINE, 30.0)
			_frame(main, 0)
		assert_eq(bubbles.shown_count(), 1, "a bubble is up")
		_frame(main)
		if main.world.shown_stage() != stage:
			changed = true
			break
	assert_true(changed, "the world went on to another stage")
	assert_eq(bubbles.shown_count(), 0, "which cleared the bubbles")


# --- R6 ------------------------------------------------------------------------


func test_r6_it_is_cheap() -> void:
	var main: Main = _main(ROOM_LARGE)
	_frame(main)
	var bubbles: SpeechBubbles = main.ui.bubbles
	var before: int = SpeechBubble.measures
	main.world.say(KNIGHT, LINE, 30.0)
	assert_gt(SpeechBubble.measures, before, "showing a line measures it")
	_frames_of(main, 12)  # past the pop
	var bubble: SpeechBubble = bubbles.bubble_of(KNIGHT)
	var measured: int = SpeechBubble.measures
	var redraws: int = bubble.redraws
	var nodes: int = bubbles.get_child_count() + bubble.get_child_count()
	var from: Vector2 = bubble.position
	_frames_of(main, 30, 1)
	assert_ne(bubble.position, from, "the bubble moved with its speaker")
	assert_eq(SpeechBubble.measures, measured, "moving measures no text")
	assert_eq(bubble.redraws, redraws, "a bubble that only moves does not redraw")
	assert_eq(bubbles.get_child_count() + bubble.get_child_count(), nodes, "and makes no nodes")

	var speakers: Array[Callable] = []
	for i: int in 10:
		var spot: Vector2 = _world_under(main, Vector2(100 + 60 * i, 200))
		var speaker: Callable = func() -> Vector2: return spot
		speakers.append(speaker)
		main.world.say(speaker, "Line %d." % i)
	_frame(main, 0)
	assert_lte(bubbles.get_child_count(), SpeechBubbles.MOST, "at most 8 bubble nodes")
	assert_eq(bubbles.shown_count(), SpeechBubbles.MOST, "8 show")
	assert_eq(bubbles.line_of(speakers[9]), "Line 9.", "the last asked for shows")
	assert_eq(bubbles.line_of(KNIGHT), "", "the oldest made way")
	assert_eq(bubbles.line_of(speakers[0]), "", "and the next oldest")


# --- R7 ------------------------------------------------------------------------


func test_r7_the_showcase_has_a_bubble_row() -> void:
	assert_eq(
		Showcase.caption(&"chat_bubble"), "A CHAT BUBBLE OVER A WALKING HERO", "the row exists"
	)
	var showcase: Showcase = (load(SHOWCASE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	var main: Main = showcase.main
	var front: int = main.simulation.party.heroes[0].id
	showcase.skip_to(&"chat_bubble")
	var over_walker: bool = false
	var moved: bool = false
	var last: Vector2 = Vector2.INF
	while showcase.moment() == &"chat_bubble" and showcase.elapsed < 30.0:
		showcase.advance(FRAME)
		var bubble: SpeechBubble = main.ui.bubbles.bubble_of(front)
		var walking: bool = main.simulation.expedition.state == Expedition.State.TRAVELLING
		if bubble != null and walking:
			over_walker = true
			if last != Vector2.INF and bubble.tip() != last:
				moved = true
			last = bubble.tip()
	var seen: bool = showcase.evidence.get(&"chat_bubble", false)
	assert_true(seen, "its watcher marked it seen")
	assert_true(over_walker, "a bubble showed over the front hero while the party walked")
	assert_true(moved, "and travelled with it")
