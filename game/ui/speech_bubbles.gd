class_name SpeechBubbles
extends Control
## The lines characters in the world say, each in a [SpeechBubble] over its speaker, on the UI
## layer: over the world and the frame of the screen, under the button bar and every window, and
## never in the mouse's way. [UiRoot] makes it; [World] shows lines through it ([method World.say])
## and moves it on at the end of every sync ([method advance]), after the camera has moved.
##
## A speaker is a hero or monster id (the bubble then sits over the top of its sprite, and goes
## when the sprite does) or a Callable that returns a point in the world. Every frame each
## bubble's speaker is found in the world, carried through the world's canvas transform (the
## camera) to the 640x360 screen and through [method UiRoot.world_to_ui] to the layer. A speaker
## has one bubble at a time; there are at most [constant MOST] bubble nodes, reused, the oldest
## first when all are showing. A later bubble that would overlap an earlier one is lifted clear.

## The most bubbles, and so the most bubble nodes.
const MOST: int = 8
## A line's hold when none is given: [constant HOLD_BASE] seconds and [constant HOLD_PER] a
## character, at most [constant HOLD_MOST].
const HOLD_BASE: float = 1.2
const HOLD_PER: float = 0.06
const HOLD_MOST: float = 4.0
## UI pixels between two bubbles lifted apart.
const GAP: float = 2.0

## The world whose characters speak, set by [member World.bubbles]; null shows no id's line.
var world: World
## The room the bubbles stay inside, in UI pixels.
var room: Vector2 = Vector2(UiRoot.MIN_ROOM)

var _root: UiRoot
## Every bubble node made, and those showing, oldest first.
var _pool: Array[SpeechBubble] = []
var _shown: Array[SpeechBubble] = []
## How many lines have been shown: each bubble's [member SpeechBubble.order].
var _said: int = 0
## The places taken this frame, kept between frames so placing makes no new array.
var _taken: Array[Rect2] = []


func _init() -> void:
	name = "Bubbles"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Puts the bubbles on [param root], which turns the world's screen points into its UI pixels.
func setup(root: UiRoot) -> void:
	_root = root
	fit_room(root.room())


## Keeps the bubbles inside [param ui_room] from now on.
func fit_room(ui_room: Vector2i) -> void:
	room = Vector2(ui_room)
	size = room


## Shows [param text] over [param speaker] (an int character id, or a Callable returning a world
## point) for [param seconds] ([method hold_for] when 0 or less), in place of any line it is
## saying. A Callable is matched by identity: a caller who wants its line replaced keeps the
## Callable and passes it again. An id with no sprite in the world says nothing.
func show_line(speaker: Variant, text: String, seconds: float = 0.0) -> void:
	var sprite: CharacterSprite = null
	if speaker is int:
		var id: int = speaker
		sprite = world.character(id) if world != null else null
		if sprite == null:
			return
	elif not (speaker is Callable and (speaker as Callable).is_valid()):
		return
	var bubble: SpeechBubble = bubble_of(speaker)
	if bubble != null:
		_shown.erase(bubble)
	else:
		bubble = _spare()
	_said += 1
	bubble.order = _said
	bubble.start(speaker, text, hold_for(text, seconds))
	if sprite != null:
		bubble.sprite = sprite
		bubble.head = Vector2(0, SpriteBounds.body_rect(sprite, Vector2.ZERO).position.y)
	_shown.append(bubble)
	_place_all()


## Takes every bubble away at once.
func clear() -> void:
	for bubble: SpeechBubble in _shown:
		_put_away(bubble)
	_shown.clear()


## How many bubbles show now.
func shown_count() -> int:
	return _shown.size()


## The text of the bubble over [param speaker] ("" when none).
func line_of(speaker: Variant) -> String:
	var bubble: SpeechBubble = bubble_of(speaker)
	return bubble.text if bubble != null else ""


## The bubble over [param speaker], or null.
func bubble_of(speaker: Variant) -> SpeechBubble:
	for bubble: SpeechBubble in _shown:
		if typeof(bubble.speaker) == typeof(speaker) and bubble.speaker == speaker:
			return bubble
	return null


## Moves every bubble on by [param delta] seconds and puts each over its speaker; one whose life
## is over or whose speaker is gone goes. Called by [method World.sync]; tests call it.
func advance(delta: float) -> void:
	var index: int = 0
	while index < _shown.size():
		var bubble: SpeechBubble = _shown[index]
		if bubble.advance(delta):
			index += 1
			continue
		_put_away(bubble)
		_shown.remove_at(index)
	_place_all()


## How long [param text] is held: [param seconds] when above 0, otherwise by its length.
static func hold_for(text: String, seconds: float) -> float:
	if seconds > 0.0:
		return seconds
	return minf(HOLD_BASE + HOLD_PER * text.length(), HOLD_MOST)


## Puts each bubble over its speaker, oldest first, each lifted clear of those placed before it;
## a bubble whose speaker is gone goes.
func _place_all() -> void:
	_taken.clear()
	var index: int = 0
	while index < _shown.size():
		var bubble: SpeechBubble = _shown[index]
		var at: Vector2 = _point_of(bubble)
		if not at.is_finite():
			_put_away(bubble)
			_shown.remove_at(index)
			continue
		bubble.place(at, room)
		var placed: Rect2 = bubble.reach()
		var lifted: Rect2 = placed
		var moved: bool = true
		while moved:
			moved = false
			for taken: Rect2 in _taken:
				if lifted.intersects(taken):
					lifted.position.y = taken.position.y - GAP - lifted.size.y
					moved = true
		if lifted.position.y < placed.position.y:
			bubble.place(at, room, placed.position.y - lifted.position.y)
		_taken.append(bubble.reach())
		index += 1


## Where [param bubble]'s speaker's head is now, in UI pixels; not finite once it is gone.
func _point_of(bubble: SpeechBubble) -> Vector2:
	var in_world: Vector2
	if bubble.speaker is int:
		var id: int = bubble.speaker
		var sprite: CharacterSprite = bubble.sprite
		if world == null or not is_instance_valid(sprite) or world.character(id) != sprite:
			return Vector2.INF
		in_world = sprite.position + bubble.head
	else:
		var point: Callable = bubble.speaker
		if not point.is_valid():
			return Vector2.INF
		in_world = point.call()
	var screen: Vector2 = in_world
	if world != null and world.is_inside_tree():
		screen = world.get_global_transform_with_canvas() * in_world
	return _root.world_to_ui(screen) if _root != null else screen


## A bubble node to show a new line in: a spare one, a new one while there are fewer than
## [constant MOST], else the oldest showing.
func _spare() -> SpeechBubble:
	for bubble: SpeechBubble in _pool:
		if not _shown.has(bubble):
			return bubble
	if _pool.size() < MOST:
		var made := SpeechBubble.new()
		made.visible = false
		add_child(made)
		_pool.append(made)
		return made
	var oldest: SpeechBubble = _shown.pop_front()
	return oldest


func _put_away(bubble: SpeechBubble) -> void:
	bubble.visible = false
	bubble.sprite = null
	bubble.speaker = null
