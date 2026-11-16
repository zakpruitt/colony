class_name PixelSheet
extends RefCounted
## A sprite sheet baked by `python tools/art.py bake` from a .px source: one PNG holding the
## parts left to right, and a .json beside it that names them. See docs/style-bible.md.

static var _cache: Dictionary[String, PixelSheet] = {}

## The sprite's category (hero, monster_small, tile, ...).
var category: String
## The size of one part's canvas, in pixels.
var size: Vector2i
## The pixel that sits on the ground and that the sprite turns around, within one part's canvas.
var pivot: Vector2i
## The parts, in the order they are drawn.
var part_names: PackedStringArray

var _path: String
var _texture: Texture2D
var _parts: Dictionary[StringName, AtlasTexture] = {}


## The sheet baked at res://<...>.png (its .json is beside it). Cached per path.
## Returns null, with an error naming the file, if either file is missing or malformed.
static func load_sheet(png_path: String) -> PixelSheet:
	if _cache.has(png_path):
		return _cache[png_path]
	var sheet := PixelSheet.new()
	if not sheet._read(png_path):
		return null
	_cache[png_path] = sheet
	return sheet


## The texture of one part: a region of the sheet.
## Asking for a part the sheet does not have is an error naming the sheet and the part,
## and returns null.
func part(part_name: StringName) -> AtlasTexture:
	if not _parts.has(part_name):
		var known: String = ", ".join(part_names)
		push_error("PixelSheet %s has no part '%s' (it has %s)" % [_path, part_name, known])
		return null
	return _parts[part_name]


## Whether the sheet has a part called [param part_name].
func has_part(part_name: StringName) -> bool:
	return _parts.has(part_name)


func _read(png_path: String) -> bool:
	_path = png_path
	var json_path: String = png_path.get_basename() + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		push_error(
			"PixelSheet: %s is missing or not a JSON object; bake its .px source" % json_path
		)
		return false
	var described: Dictionary = parsed
	var pivot_xy: Array = described.get("pivot", [])
	var names: Array = described.get("parts", [])
	if pivot_xy.size() != 2 or names.is_empty():
		push_error("PixelSheet: %s has no pivot or no parts; bake its .px source" % json_path)
		return false
	_texture = load(png_path) as Texture2D
	if _texture == null:
		push_error("PixelSheet: cannot load the texture %s" % png_path)
		return false
	category = str(described.get("category", ""))
	# JSON numbers arrive as floats.
	var width: float = described.get("width", 0.0)
	var height: float = described.get("height", 0.0)
	var pivot_x: float = pivot_xy[0]
	var pivot_y: float = pivot_xy[1]
	size = Vector2i(roundi(width), roundi(height))
	pivot = Vector2i(roundi(pivot_x), roundi(pivot_y))
	for index: int in names.size():
		var part_name: String = str(names[index])
		part_names.append(part_name)
		var region := AtlasTexture.new()
		region.atlas = _texture
		region.region = Rect2(index * size.x, 0, size.x, size.y)
		_parts[StringName(part_name)] = region
	return true
