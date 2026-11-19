extends ColonyTest
## Spec 002, art foundation: Godot's side of the sprite pipeline.
## The palette, baking and the lint are tested in tools/tests/test_art.py.

const KNIGHT_PNG: String = "res://assets/sprites/heroes/knight.png"
const KNIGHT_JSON: String = "res://assets/sprites/heroes/knight.json"
const PALETTE_TXT: String = "res://assets/style/palette.txt"
const GALLERY: String = "res://game/art/gallery.tscn"


func test_r7_sheet_gives_parts_by_name() -> void:
	var sheet: PixelSheet = PixelSheet.load_sheet(KNIGHT_PNG)
	assert_not_null(sheet, "the knight sheet loads")
	if sheet == null:
		return
	assert_eq(sheet.category, "hero")
	assert_eq(sheet.size, Vector2i(32, 32))
	assert_eq(sheet.pivot, Vector2i(16, 31))
	assert_eq(sheet.part_names, PackedStringArray(["body", "head", "arm", "weapon"]))
	assert_same(PixelSheet.load_sheet(KNIGHT_PNG), sheet, "sheets are cached per path")

	for index: int in sheet.part_names.size():
		var part_name: StringName = StringName(sheet.part_names[index])
		assert_true(sheet.has_part(part_name), "has %s" % part_name)
		var texture: AtlasTexture = sheet.part(part_name)
		assert_not_null(texture, "part %s" % part_name)
		if texture == null:
			continue
		assert_eq(texture.region, Rect2(index * 32, 0, 32, 32), "region of %s" % part_name)
		assert_eq(texture.atlas.get_size(), Vector2(128, 32), "the atlas is the whole sheet")

	var weapon: Image = sheet.part(&"weapon").get_image()
	assert_eq(weapon.get_size(), Vector2i(32, 32))
	assert_true(weapon.get_used_rect().has_area(), "the weapon part has pixels")

	assert_false(sheet.has_part(&"tail"))
	assert_null(sheet.part(&"tail"))
	assert_push_error("knight.png has no part 'tail'")


func test_r8_palette_colours_by_name() -> void:
	assert_eq(Palette.color(&"ink"), Color("#181425"))

	var lines: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(PALETTE_TXT).split("\n", false):
		if not line.strip_edges().is_empty():
			lines.append(line.strip_edges())
	var colours: PackedColorArray = Palette.all()
	assert_eq(colours.size(), 32)
	assert_eq(lines.size(), 32)
	for index: int in mini(colours.size(), lines.size()):
		var fields: PackedStringArray = lines[index].split(" ")
		assert_eq(colours[index], Color("#" + fields[1]), "colour %d" % index)
		assert_eq(Palette.color(StringName(fields[2])), colours[index], fields[2])

	assert_eq(Palette.color(&"no_such_colour"), Color.MAGENTA)
	assert_push_error("no_such_colour")


func test_r9_knight_is_baked_and_listed() -> void:
	assert_true(FileAccess.file_exists(KNIGHT_JSON), "the knight's JSON is baked")
	var texture: Texture2D = load(KNIGHT_PNG)
	assert_not_null(texture, "the knight's PNG imports")
	if texture != null:
		assert_eq(texture.get_size(), Vector2(128, 32))

	var scene: PackedScene = load(GALLERY)
	assert_not_null(scene, "the gallery scene loads")
	if scene == null:
		return
	var gallery: Gallery = scene.instantiate()
	add_child_autofree(gallery)
	await wait_process_frames(2)
	assert_has(gallery.shown_sheets(), KNIGHT_PNG, "the gallery shows the knight")
	assert_push_error_count(0)
	assert_engine_error_count(0)
