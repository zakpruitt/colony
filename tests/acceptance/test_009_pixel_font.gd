extends ColonyTest
## Spec 009, pixel font and the UI theme. R3 (the lint's font category) is tested in
## tools/tests/test_art.py.

const THEME_PATH: String = "res://game/ui/theme.tres"
const MAIN_SCENE_PATH: String = "res://game/main.tscn"
const SPECIMEN: String = "res://game/ui/font_specimen.tscn"
## Every character R1 lists, space first.
const CHARACTERS: String = (
	" ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" + ".,!?:;'\"+-x/%()<>=*#_"
)
## The tallest a glyph may be, descender included (R2).
const MAX_GLYPH_HEIGHT: int = 7
const CAP_HEIGHT: int = 5


## The font's one size, the size it was drawn at.
func _native_size() -> int:
	var file: FontFile = PixelText.font() as FontFile
	return file.fixed_size if file != null else 0


## The opaque pixels of one character's glyph, as an image the size of its cell.
func _glyph_image(character: String) -> Image:
	var file: FontFile = PixelText.font() as FontFile
	var size: Vector2i = Vector2i(_native_size(), 0)
	var glyph: int = file.get_glyph_index(size.x, character.unicode_at(0), 0)
	var uv: Rect2 = file.get_glyph_uv_rect(0, size, glyph)
	var sheet: Image = file.get_texture_image(0, size, file.get_glyph_texture_idx(0, size, glyph))
	return sheet.get_region(Rect2i(uv))


func test_r1_every_character_has_a_glyph() -> void:
	var font: Font = PixelText.font()
	assert_not_null(font, "the pixel font loads")
	if font == null:
		return
	assert_true(font is FontFile, "the font is a FontFile")
	var size: int = _native_size()
	var white: Color = Palette.color(&"white")
	for index: int in CHARACTERS.length():
		var character: String = CHARACTERS[index]
		var code: int = character.unicode_at(0)
		assert_true(font.has_char(code), "the font has '%s'" % character)
		var advance: float = font.get_char_size(code, size).x
		assert_gt(advance, 0.0, "'%s' has a positive advance" % character)
		var image: Image = _glyph_image(character)
		var used: Rect2i = image.get_used_rect()
		if character == " ":
			assert_false(used.has_area(), "space draws nothing")
			continue
		assert_true(used.has_area(), "'%s' draws at least one pixel" % character)
		# The advance is the drawn width plus one column of spacing, from the left edge.
		assert_eq(used.position.x, 0, "'%s' starts at the left of its cell" % character)
		assert_eq(int(advance), used.end.x + 1, "'%s' advance is its width plus one" % character)
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a != 0.0:
					assert_eq(pixel, white, "'%s' pixel %d,%d is white" % [character, x, y])


func test_r2_metrics() -> void:
	var font: Font = PixelText.font()
	assert_not_null(font, "the pixel font loads")
	if font == null:
		return
	var size: int = _native_size()
	assert_lte(font.get_height(size), float(MAX_GLYPH_HEIGHT), "ascent plus descent")
	assert_eq(font.get_ascent(size), float(CAP_HEIGHT), "the baseline sits under the caps")
	var probe: Label = autofree(Label.new())
	var line_spacing: int = probe.get_theme_constant(&"line_spacing")
	assert_lte(font.get_height(size), float(MAX_GLYPH_HEIGHT + line_spacing))
	assert_lt(PixelText.width("i"), PixelText.width("m"), "proportional: i is narrower than m")

	for index: int in CHARACTERS.length():
		var used: Rect2i = _glyph_image(CHARACTERS[index]).get_used_rect()
		assert_lte(used.end.y, MAX_GLYPH_HEIGHT, "'%s' is at most 7 tall" % CHARACTERS[index])
	for capital: String in ["H", "E", "M", "0", "8"]:
		var used: Rect2i = _glyph_image(capital).get_used_rect()
		assert_eq(used.position.y, 0, "'%s' reaches the cap line" % capital)
		assert_eq(used.size.y, CAP_HEIGHT, "'%s' is 5 tall" % capital)
	for descender: String in ["g", "j", "p", "q", "y"]:
		var used: Rect2i = _glyph_image(descender).get_used_rect()
		assert_gt(used.end.y, CAP_HEIGHT, "'%s' goes below the baseline" % descender)


func test_r5_default_label_uses_the_pixel_font() -> void:
	var theme_setting: String = ProjectSettings.get_setting("gui/theme/custom", "")
	assert_eq(theme_setting, THEME_PATH, "the project's default theme")
	var theme: Theme = load(THEME_PATH) as Theme
	assert_not_null(theme, "the theme loads")
	if theme == null:
		return
	assert_eq(theme.default_font, PixelText.font(), "the theme's default font")
	assert_eq(theme.default_font_size, _native_size(), "at the font's native size")

	var label := Label.new()
	label.text = "Depth 12"
	add_child_autofree(label)
	assert_eq(label.get_theme_font(&"font"), PixelText.font(), "a bare Label's font")
	assert_eq(label.get_theme_font_size(&"font_size"), _native_size(), "a bare Label's size")

	# R4: a real font, drawn pixel for pixel.
	var file: FontFile = PixelText.font() as FontFile
	assert_not_null(file, "the font is a FontFile")
	if file == null:
		return
	assert_eq(file.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "no anti-aliasing")
	assert_false(file.generate_mipmaps, "no mipmaps")
	assert_eq(
		file.fixed_size_scale_mode,
		TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY,
		"scaled only by whole numbers"
	)
	var filter: int = ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter"
	)
	assert_eq(filter, 0, "nearest filtering")


func test_r5_clock_label_uses_the_pixel_font() -> void:
	var scene: PackedScene = load(MAIN_SCENE_PATH)
	var main: Main = scene.instantiate()
	add_child_autofree(main)
	var clock: Label = main.get_node("HUD/ClockLabel")
	assert_eq(clock.get_theme_font(&"font"), PixelText.font(), "the clock's font")
	assert_eq(clock.get_theme_font_size(&"font_size"), _native_size(), "the clock's size")


func test_r6_pixel_text_helpers() -> void:
	assert_eq(PixelText.width(""), 0)
	assert_lt(PixelText.width("ii"), PixelText.width("mm"))
	# H is 4 wide with one column of spacing; i is 1 wide.
	assert_eq(PixelText.width("H"), 5)
	assert_eq(PixelText.width("Hi"), 7)

	var label: Label = PixelText.label("Gold 3,450", &"yellow")
	add_child_autofree(label)
	assert_eq(label.text, "Gold 3,450")
	assert_eq(label.get_theme_font(&"font"), PixelText.font())
	assert_eq(label.get_theme_color(&"font_color"), Palette.color(&"yellow"), "tinted")
	assert_eq(label.get_theme_color(&"font_shadow_color"), Palette.color(&"ink"), "ink shadow")
	assert_eq(label.get_theme_constant(&"shadow_offset_x"), 1, "1-pixel shadow")
	assert_eq(label.get_theme_constant(&"shadow_offset_y"), 1, "1-pixel shadow")

	var plain: Label = PixelText.label("Lv 7")
	add_child_autofree(plain)
	assert_eq(plain.get_theme_color(&"font_color"), Palette.color(&"white"), "white by default")


func test_r7_specimen_runs() -> void:
	var scene: PackedScene = load(SPECIMEN)
	assert_not_null(scene, "the specimen scene loads")
	if scene == null:
		return
	var specimen: Node = scene.instantiate()
	add_child_autofree(specimen)
	await wait_process_frames(30)
	assert_push_error_count(0)
	assert_engine_error_count(0)
