class_name MonsterThumb
extends Control
## A monster's sprite at rest, small, for the area map (spec 053): its parts drawn together as the
## world draws them standing still, at 1x when the sprite is at most [constant MOST] pixels tall
## and at half size when larger (a guardian's 64-pixel sprite), standing on the bottom edge. A
## guardian's thumb shows a 7x5 [code]green[/code] tick in its top-right corner once beaten. A
## closed area's thumbs are [member dim]: darkened in colour, never by opacity.

## The tallest sprite drawn at 1x; a taller one is drawn at half size.
const MOST: int = 32
## Pixels between two thumbs in a row.
const GAP: float = 2.0
## A tick in 7x5 pixels, as the goals tracker draws one: [code]#[/code] is green.
const TICK: Array[String] = ["......#", ".....#.", "#...#..", ".#.#...", "..#...."]
## The colour a dim thumb is multiplied by.
const DIM: Color = Color(0.35, 0.35, 0.4)

## The monster shown.
var monster_id: StringName = &""
## True for a beaten guardian: the tick is drawn.
var beaten: bool = false:
	set(value):
		if beaten != value:
			beaten = value
			queue_redraw()
## True for a closed area's monster.
var dim: bool = false:
	set(value):
		if dim != value:
			dim = value
			self_modulate = DIM if dim else Color.WHITE
			queue_redraw()

var _sheet: PixelSheet
var _scale: float = 1.0


func _init(id: StringName) -> void:
	monster_id = id
	name = String(id).to_pascal_case()
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sheet = PixelSheet.load_sheet("%s/%s.png" % [CharacterSprite.MONSTERS_DIR, id])
	if _sheet == null:
		size = Vector2(16, 16)
		return
	if _sheet.size.y > MOST:
		_scale = 0.5
	size = Vector2(_sheet.size) * _scale


## The monster's name, as the map's tooltip says it: [code]Mud Golem[/code].
func display_name() -> String:
	var def: MonsterDef = Content.monster(monster_id)
	return def.display_name if def != null else String(monster_id)


func _draw() -> void:
	if _sheet != null:
		for part: String in _sheet.part_names:
			draw_texture_rect(_sheet.part(StringName(part)), Rect2(Vector2.ZERO, size), false)
	if not beaten:
		return
	var at := Vector2(size.x - 7.0, 0.0)
	for y: int in TICK.size():
		for x: int in TICK[y].length():
			if TICK[y][x] == "#":
				draw_rect(Rect2(at + Vector2(x, y + 1), Vector2.ONE), Palette.color(&"ink"))
				draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Palette.color(&"green"))
