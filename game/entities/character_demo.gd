class_name CharacterDemo
extends Node2D
## Shows the nine characters of spec 007 cycling together through idle, walk, melee attack, ranged
## attack, hit and death, then reappearing: heroes facing right, monsters facing left, at 2x with
## their names, and once more below at their real size.
## Run: python tools/dev.py shot --scene=res://game/entities/character_demo.tscn --name=cast
##      --seconds=0.7 --count=10
## The cycle is timed so those ten shots catch a wind-up, its strike, and the white flash of a hit.

const HEROES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
const MONSTERS: Array[StringName] = [&"slime", &"cave_bat", &"skeleton", &"spider", &"ogre"]
const CAST: Array[StringName] = [
	&"knight", &"rogue", &"mage", &"cleric", &"slime", &"cave_bat", &"skeleton", &"spider", &"ogre"
]
## Seconds for one whole cycle of the animations.
const CYCLE_SECONDS: float = 7.0
## Seconds into the cycle at which each animation starts.
const TIMELINE: Array[Array] = [
	[0.0, &"idle"],
	[1.0, &"walk"],
	[2.45, &"melee attack"],
	[3.85, &"ranged attack"],
	[5.57, &"hit"],
	[6.1, &"death"],
	[6.7, &"reappear"],
]
## Seconds an attack winds up for.
const WINDUP_SECONDS: float = 0.9
## How much bigger than real size the named rows are drawn.
const ZOOM: float = 2.0
## Where each row's floor is, and how far apart its characters stand, in screen pixels.
const HERO_FLOOR: float = 122.0
const MONSTER_FLOOR: float = 252.0
const REAL_SIZE_FLOOR: float = 334.0
const ZOOMED_SPACING: float = 104.0
const REAL_SIZE_SPACING: float = 46.0
const FONT_SIZE: int = 8
const SCREEN: Vector2 = Vector2(640, 360)

var _clock: float = 0.0
var _cast: Array[CharacterSprite] = []
var _real_size: Array[CharacterSprite] = []
var _stage: Node2D
var _phase_label: Label


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Palette.color(&"dark_brown")
	background.size = SCREEN
	add_child(background)
	for floor_y: float in [HERO_FLOOR, MONSTER_FLOOR, REAL_SIZE_FLOOR]:
		var ground := ColorRect.new()
		ground.color = Palette.color(&"umber")
		ground.position = Vector2(0, floor_y)
		ground.size = Vector2(SCREEN.x, 2 if floor_y == REAL_SIZE_FLOOR else 3)
		add_child(ground)
	_phase_label = _label("", Vector2(8, 6))
	_phase_label.add_theme_color_override("font_color", Palette.color(&"amber"))
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_add_names()
	_run_event(&"reappear")
	_run_event(&"idle")


func _process(delta: float) -> void:
	advance(delta)


## Moves the demo's cycle on by [param delta] seconds, starting each animation when its time
## comes. The characters animate themselves each frame.
func advance(delta: float) -> void:
	var from: float = _clock
	_clock += delta
	if _clock < CYCLE_SECONDS:
		_run_events_between(from, _clock)
		return
	_run_events_between(from, CYCLE_SECONDS)
	_clock = fposmod(_clock, CYCLE_SECONDS)
	_run_events_between(-1.0, _clock)


## The nine characters in the named rows: the four heroes, then the five monsters.
func characters() -> Array[CharacterSprite]:
	return _cast


func _run_events_between(after: float, up_to: float) -> void:
	for event: Array in TIMELINE:
		var at: float = event[0]
		if at > after and at <= up_to:
			var name_of_event: StringName = event[1]
			_run_event(name_of_event)


func _run_event(event: StringName) -> void:
	_phase_label.text = "spec 007 cast: %s" % event
	if event == &"reappear":
		_rebuild()
		return
	for character: CharacterSprite in _cast + _real_size:
		match event:
			&"idle":
				character.play_idle()
			&"walk":
				character.play_walk()
			&"melee attack":
				character.play_idle()
				character.play_attack(WINDUP_SECONDS, false)
			&"ranged attack":
				character.play_attack(WINDUP_SECONDS, true)
			&"hit":
				character.play_hit()
			&"death":
				character.play_death()


func _rebuild() -> void:
	for character: CharacterSprite in _cast + _real_size:
		character.queue_free()
	_cast.clear()
	_real_size.clear()
	var ids: Array[StringName] = CAST
	for index: int in ids.size():
		var id: StringName = ids[index]
		var hero: bool = index < HEROES.size()
		var zoomed: CharacterSprite = _make(id, hero)
		zoomed.scale = Vector2(ZOOM, ZOOM)
		zoomed.position = _zoomed_spot(index)
		_cast.append(zoomed)
		var real: CharacterSprite = _make(id, hero)
		real.position = Vector2(_real_size_left() + index * REAL_SIZE_SPACING, REAL_SIZE_FLOOR)
		_real_size.append(real)


func _make(id: StringName, hero: bool) -> CharacterSprite:
	var character: CharacterSprite = (
		CharacterSprite.for_hero(id) if hero else CharacterSprite.for_monster(id)
	)
	character.set_facing(1 if hero else -1)
	_stage.add_child(character)
	return character


func _add_names() -> void:
	var ids: Array[StringName] = CAST
	for index: int in ids.size():
		var label: Label = _label(String(ids[index]).replace("_", " "), Vector2.ZERO)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(ZOOMED_SPACING, 10)
		label.position = _zoomed_spot(index) + Vector2(-ZOOMED_SPACING / 2.0, 5)
	_label("real size", Vector2(8, REAL_SIZE_FLOOR - 12))


## Where the zoomed character [param index] stands: heroes on the upper floor, monsters below.
func _zoomed_spot(index: int) -> Vector2:
	if index < HEROES.size():
		var left: float = (SCREEN.x - (HEROES.size() - 1) * ZOOMED_SPACING) / 2.0
		return Vector2(roundf(left + index * ZOOMED_SPACING), HERO_FLOOR)
	var column: int = index - HEROES.size()
	var monsters_left: float = (SCREEN.x - (MONSTERS.size() - 1) * ZOOMED_SPACING) / 2.0
	return Vector2(roundf(monsters_left + column * ZOOMED_SPACING), MONSTER_FLOOR)


func _real_size_left() -> float:
	return roundf((SCREEN.x - (HEROES.size() + MONSTERS.size() - 1) * REAL_SIZE_SPACING) / 2.0)


func _label(text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Palette.color(&"silver"))
	add_child(label)
	return label
