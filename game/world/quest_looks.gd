class_name QuestLooks
extends RefCounted
## How one chamber shows its quest's prop: which of the prop's looks, a tint (a palette swap),
## whether it is mirrored, and the little things lying round it (its dressing).
##
## All of it is chosen by [method choose] from a [RandomNumberGenerator] seeded from the area,
## the stage and the chamber's index, never the simulation's stream: a room shows its quest the
## same way every time it is seen, and the clearings of the ambience ([AmbienceClearings]) work
## out the same dressing without a world. The quest's states play the same in every look: a part
## is named [code]<look>_<state>[/code].

## Each quest's looks, in its sheet's order.
const LOOKS: Dictionary[StringName, Array] = {
	&"locked_chest": [&"plain", &"iron", &"coffer"],
	&"stuck_door": [&"planks", &"studded", &"round"],
	&"rune_stone": [&"tall", &"squat", &"cracked"],
	&"tripwire": [&"plain", &"bells", &"darts"],
	&"hurt_wanderer": [&"hooded", &"miner", &"pilgrim"],
}
## Each quest's state while it waits and is worked, and once it is done.
const WAITING: Dictionary[StringName, StringName] = {
	&"locked_chest": &"locked",
	&"stuck_door": &"stuck",
	&"rune_stone": &"dim",
	&"tripwire": &"taut",
	&"hurt_wanderer": &"hurt",
}
const DONE: Dictionary[StringName, StringName] = {
	&"locked_chest": &"open",
	&"stuck_door": &"open",
	&"rune_stone": &"lit",
	&"tripwire": &"slack",
	&"hurt_wanderer": &"stand",
}
## Swaps of a prop's wood: none, paler, darker.
const WOOD_TINTS: Array[Dictionary] = [
	{},
	{&"tan": &"sand", &"clay": &"tan", &"umber": &"clay", &"dark_brown": &"umber"},
	{&"tan": &"clay", &"clay": &"umber", &"umber": &"dark_brown"},
]
## Each quest's tints: the first changes nothing.
const TINTS: Dictionary[StringName, Array] = {
	&"locked_chest": WOOD_TINTS,
	&"stuck_door": WOOD_TINTS,
	&"tripwire": WOOD_TINTS,
	&"rune_stone":
	[
		{},
		{&"silver": &"sand", &"steel": &"tan", &"slate": &"clay", &"dusk": &"umber"},
		{&"silver": &"steel", &"steel": &"slate", &"slate": &"dusk", &"dusk": &"night"},
	],
	&"hurt_wanderer":
	[
		{},
		# A pilgrim's robe (sand, shaded tan) changes too, and with it the staffs' tan.
		{
			&"green": &"blue",
			&"forest": &"navy",
			&"pine": &"night",
			&"sand": &"silver",
			&"tan": &"steel",
		},
		{
			&"green": &"red",
			&"forest": &"crimson",
			&"pine": &"plum",
			&"sand": &"clay",
			&"tan": &"umber",
		},
	],
}
## The quest whose prop is never mirrored: a door hangs on the wall side (its hinge is drawn on
## the right).
const HINGED: StringName = &"stuck_door"
## Each quest's dressing, parts of [constant DRESSING_SHEET].
const DRESSING: Dictionary[StringName, Array] = {
	&"locked_chest": [&"coins", &"bone", &"key"],
	&"stuck_door": [&"planks", &"splinters", &"hinge"],
	&"rune_stone": [&"candles", &"candle", &"scroll"],
	&"tripwire": [&"skull", &"dart", &"darts"],
	&"hurt_wanderer": [&"pack", &"lantern", &"cup"],
}
const DRESSING_SHEET: String = "res://assets/sprites/props/quest_dressing.png"
## Where a piece of dressing may lie: its middle this many pixels to either side of the prop's
## foot. A piece spans [constant PIECE_HALF] each way, so it stays within 2 tiles of the foot
## (32 pixels) and at least 2 pixels clear of the furthest work spot
## ([constant QuestProps.WORK_GAP] and [constant QuestStage.BEHIND], 18 pixels). Two on one
## side lie a little over each other, a small heap.
const SLOTS: Array[float] = [-28.0, -24.0, 24.0, 28.0]
## Half the widest piece of dressing, in pixels: a slot is used only where a piece this wide
## still lies on the room's open floor.
const PIECE_HALF: float = 4.0
## At most this many pieces round one prop.
const MOST_PIECES: int = 3
## A palette swap, done on the colours already drawn ([code]COLOR[/code], never a second sample
## of the texture). Each colour that matches a [code]from[/code] becomes its [code]to[/code].
const SWAP_SHADER: String = """
shader_type canvas_item;
uniform vec4 from_colors[6];
uniform vec4 to_colors[6];
uniform int count = 0;
void fragment() {
	for (int i = 0; i < 6; i++) {
		if (i < count && distance(COLOR.rgb, from_colors[i].rgb) < 0.01) {
			COLOR.rgb = to_colors[i].rgb;
			break;
		}
	}
}
"""

static var _shader: Shader
static var _materials: Dictionary[String, ShaderMaterial] = {}

var quest: StringName
var look: StringName
## Which of [constant TINTS] for the quest; 0 for none.
var tint: int = 0
var mirrored: bool = false
## The dressing's parts, and where each lies: pixels from the prop's foot along the floor.
var dressing: Array[StringName] = []
var dressing_at: Array[float] = []


## The looks of [param quest]'s prop in chamber [param chamber_index] of stage [param depth] of
## area [param area], standing at [param spot] on a floor whose open span is
## [param floor_span] (the left and right walls' x, in world pixels).
static func choose(
	area: StringName,
	depth: int,
	chamber_index: int,
	quest_id: StringName,
	spot: Vector2,
	floor_span: Vector2
) -> QuestLooks:
	var made := QuestLooks.new()
	made.quest = quest_id
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("quest_looks/%s/%d/%d" % [area, depth, chamber_index])
	var looks: Array = LOOKS.get(quest_id, [&"plain"])
	made.look = looks[rng.randi_range(0, looks.size() - 1)]
	var tints: Array = TINTS.get(quest_id, [{}])
	made.tint = rng.randi_range(0, tints.size() - 1)
	made.mirrored = rng.randi_range(0, 1) == 1
	if quest_id == HINGED:
		# The hinge (drawn on the right) on the side of the nearer wall.
		made.mirrored = spot.x - floor_span.x < floor_span.y - spot.x
	var count: int = rng.randi_range(1, MOST_PIECES)
	var slots: Array[float] = SLOTS.duplicate()
	for i: int in range(slots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var kept: float = slots[i]
		slots[i] = slots[j]
		slots[j] = kept
	# Each piece once round a prop.
	var listed: Array = DRESSING.get(quest_id, [])
	var pieces: Array = listed.duplicate()
	for at: float in slots:
		if made.dressing.size() >= count or pieces.is_empty():
			break
		var x: float = spot.x + at
		if x - PIECE_HALF < floor_span.x or x + PIECE_HALF > floor_span.y:
			continue
		var piece: StringName = pieces.pop_at(rng.randi_range(0, pieces.size() - 1))
		made.dressing.append(piece)
		made.dressing_at.append(at)
	return made


## The part of the prop's sheet that shows [param state] in this look.
func part_name(state: StringName) -> StringName:
	return StringName("%s_%s" % [look, state])


## The palette swap of this look's tint, or null when it has none.
func material() -> ShaderMaterial:
	var tints: Array = TINTS.get(quest, [{}])
	var swaps: Dictionary = tints[tint]
	if swaps.is_empty():
		return null
	var key: String = "%s/%d" % [quest, tint]
	if _materials.has(key):
		return _materials[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SWAP_SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	var from: PackedColorArray = []
	var to: PackedColorArray = []
	for colour: StringName in swaps:
		var into: StringName = swaps[colour]
		from.append(Palette.color(colour))
		to.append(Palette.color(into))
	made.set_shader_parameter(&"from_colors", from)
	made.set_shader_parameter(&"to_colors", to)
	made.set_shader_parameter(&"count", from.size())
	_materials[key] = made
	return made


## The rectangles the dressing covers round a prop standing at [param spot], in world pixels:
## each piece's opaque pixels, as [QuestProps] stands them.
func dressing_rects(spot: Vector2) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var sheet: PixelSheet = PixelSheet.load_sheet(DRESSING_SHEET)
	if sheet == null:
		return found
	for i: int in dressing.size():
		var box: Rect2i = SpriteBounds.opaque(sheet.part(dressing[i]))
		var feet := Vector2(spot.x + dressing_at[i], spot.y)
		var corner: Vector2 = feet - Vector2(sheet.pivot) - Vector2(0, 1) + Vector2(box.position)
		found.append(Rect2(corner, Vector2(box.size)))
	return found
