class_name GateTip
extends Node2D
## What a closed gate says under the mouse: its name, its description, and who in the party
## opens it or what would. Drawn in the world over the gate, like the name over a hero at
## work, in a small dark box kept inside the screen.
##
## [SideProps] makes it and tells it which gate, if any, the mouse is on.

## The widest its words run before they wrap, the padding round them and the pixels between the
## box and the gate, all in world pixels.
const WIDTH: int = 150
const PAD: int = 3
const GAP: float = 3.0
## Pixels from one line's baseline to the next.
const LINE: int = PixelText.SIZE + 1
## What a closed gate adds while the party is ordered past every gate.
const PRESSING_ON: String = "The party is pressing on"

## The gate's name, its description and the line about who opens it; "" while hidden.
var title: String = ""
var body: String = ""
var who: String = ""
## What the party's side path order adds while it keeps the party from the gate; else "".
var order: String = ""

## The lines drawn (the title first), the first of them that says who opens it, and the box
## they are drawn in, in world pixels.
var _lines: PackedStringArray = []
var _who_from: int = 0
var _box: Rect2 = Rect2()
## The size the lines take, worked out when they are worded.
var _size: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "GateTip"
	# Over the passing effects and their words: a rising line must not run through its own.
	z_index = World.EFFECTS_Z + 10
	z_as_relative = false
	visible = false


## The line that rises from a gate nobody can open, for the microskill at [param skill_index]
## in [method Content.microskill_ids]; "" for none.
static func sealed_line(skill_index: int) -> String:
	var skills: Array[StringName] = Content.microskill_ids()
	if skill_index < 0 or skill_index >= skills.size():
		return ""
	return "Needs a %s" % Content.microskill(skills[skill_index]).display_name


## Who opens the gate of side path [param index] on [param stage]: the hero who would now, by
## its class; else the hero of [param simulation]'s party whose class learns the gate's
## microskill soonest, and at what level; else that nobody in the party does.
static func who_line(simulation: Simulation, stage: int, index: int) -> String:
	var paths: Array[SidePath] = simulation.labyrinth.level(stage).side_paths
	var def: GateDef = Content.gate(paths[index].gate) if index < paths.size() else null
	if def == null:
		return ""
	var opener: Hero = SidePathRules.opener(simulation.expedition, stage, index)
	if opener != null:
		return "The %s can open this" % opener.def().display_name
	var learner: HeroClassDef = null
	var at_level: int = 0
	for hero: Hero in simulation.party.heroes:
		var found: int = hero.def().microskills.find(def.microskill)
		if found < 0 or found >= hero.def().microskill_levels.size():
			continue
		var level: int = hero.def().microskill_levels[found]
		if learner == null or level < at_level:
			learner = hero.def()
			at_level = level
	if learner == null:
		return "Nobody in the party learns this"
	var skill: MicroskillDef = Content.microskill(def.microskill)
	return (
		"A %s could open this: the %s learns it at level %d"
		% [skill.display_name, learner.display_name, at_level]
	)


## Words the tip for the gate of side path [param index] on [param stage], as the party is now.
## False, and nothing written, for a gate with no definition. [method place] then shows it.
func write(simulation: Simulation, stage: int, index: int) -> bool:
	var paths: Array[SidePath] = simulation.labyrinth.level(stage).side_paths
	var def: GateDef = Content.gate(paths[index].gate) if index < paths.size() else null
	if def == null:
		return false
	title = def.display_name
	body = def.description
	who = who_line(simulation, stage, index)
	var pressing: bool = simulation.expedition.side_paths == Expedition.SidePaths.PRESS_ON
	order = PRESSING_ON if pressing else ""
	_lines = PackedStringArray([title])
	_lines.append_array(_wrap(body))
	_who_from = _lines.size()
	_lines.append_array(_wrap(who))
	if pressing:
		_lines.append_array(_wrap(order))
	var widest: int = 0
	for line: String in _lines:
		widest = maxi(widest, PixelText.width(line))
	_size = Vector2(widest + 2 * PAD, _lines.size() * LINE + 2 * PAD)
	queue_redraw()
	return true


## Shows the words last worded over the gate standing in [param over] (world pixels), inside
## [param screen] (the part of the world on screen).
func place(over: Rect2, screen: Rect2) -> void:
	var at := Vector2(over.get_center().x - _size.x / 2.0, over.position.y - GAP - _size.y)
	if at.y < screen.position.y:
		at.y = over.end.y + GAP
	at.x = clampf(at.x, screen.position.x, maxf(screen.end.x - _size.x, screen.position.x))
	at.y = clampf(at.y, screen.position.y, maxf(screen.end.y - _size.y, screen.position.y))
	var box := Rect2(at.round(), _size)
	if box != _box or not visible:
		_box = box
		visible = true
		queue_redraw()


## The lines as they are drawn, the title first.
func shown_lines() -> PackedStringArray:
	return _lines


## Shows nothing.
func hide_tip() -> void:
	if not visible:
		return
	visible = false
	title = ""
	body = ""
	who = ""
	order = ""


## [param words] on as many lines as [constant WIDTH] needs, broken between words.
static func _wrap(words: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in words.split(" "):
		var longer: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and PixelText.width(longer) > WIDTH:
			lines.append(line)
			line = word
		else:
			line = longer
	if not line.is_empty():
		lines.append(line)
	return lines


func _draw() -> void:
	draw_rect(_box, Palette.color(&"ink"))
	draw_rect(_box.grow(-1.0), Palette.color(&"night"))
	var font: Font = PixelText.font()
	for i: int in _lines.size():
		var at: Vector2 = _box.position + Vector2(PAD, PAD + i * LINE + PixelText.SIZE - 2)
		var colour: StringName = &"yellow" if i == 0 else &"white"
		if i >= _who_from:
			colour = &"silver"
		draw_string(
			font,
			at,
			_lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			PixelText.SIZE,
			Palette.color(colour)
		)
