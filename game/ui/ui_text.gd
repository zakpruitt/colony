class_name UiText
extends RefCounted
## The UI layer's font, made for reading: [code]assets/fonts/ui.px[/code] and its bold
## [code]ui_bold.px[/code], baked by [code]tools/art.py[/code] and imported as images. This class
## turns each sheet into a [FontFile] (so every [Control] on the layer gets it from [UiTheme]) and
## measures text, as [PixelText] does for the world's font.
##
## A glyph is one part of the sheet, drawn from the left edge of a [constant CELL] cell: capitals
## and digits [constant CAP_HEIGHT] rows tall above the baseline, lower case [constant X_HEIGHT]
## tall with ascenders and descenders. Its advance is its drawn width plus [constant SPACING],
## worked out here from its pixels, so the sheet is the only place a width lives; digits all
## advance [constant DIGIT_ADVANCE] so numbers keep their width, and a space
## [constant SPACE_ADVANCE].

const REGULAR_PATH: String = "res://assets/fonts/ui.png"
const BOLD_PATH: String = "res://assets/fonts/ui_bold.png"
## The font's one size: the cell height. Use only this or a whole multiple of it.
const SIZE: int = 12
## One glyph's canvas on the sheet.
const CELL: Vector2i = Vector2i(9, 12)
## Rows above the baseline that capitals and digits fill; the x-height of lower case.
const CAP_HEIGHT: int = 9
const X_HEIGHT: int = 6
## Pixels above the baseline and below it that a line keeps: one row of air over the capitals and
## the three descender rows, so a descender never touches the capital under it. A line is their
## sum, [constant LINE_HEIGHT].
const ASCENT: int = 10
const DESCENT: int = 3
const LINE_HEIGHT: int = ASCENT + DESCENT
## Columns between two glyphs; a space's advance; every digit's advance.
const SPACING: int = 1
const SPACE_ADVANCE: int = 4
const DIGIT_ADVANCE: int = 7
## The sheet's part for each character that is not a letter or a digit.
const PUNCTUATION: Dictionary[String, String] = {
	" ": "space",
	"!": "exclamation",
	'"': "quote",
	"#": "hash",
	"$": "dollar",
	"%": "percent",
	"&": "ampersand",
	"'": "apostrophe",
	"(": "paren_left",
	")": "paren_right",
	"*": "asterisk",
	"+": "plus",
	",": "comma",
	"-": "minus",
	".": "period",
	"/": "slash",
	":": "colon",
	";": "semicolon",
	"<": "less",
	"=": "equals",
	">": "greater",
	"?": "question",
	"@": "at",
	"[": "bracket_left",
	"\\": "backslash",
	"]": "bracket_right",
	"^": "caret",
	"_": "underscore",
	"`": "backtick",
	"{": "brace_left",
	"|": "bar",
	"}": "brace_right",
	"~": "tilde",
}

## The built fonts and what was read to build them, by "is it the bold".
static var _fonts: Dictionary[bool, FontFile] = {}
static var _images: Dictionary[bool, Image] = {}
## Each character's index on its sheet, by "is it the bold".
static var _index: Dictionary[bool, Dictionary] = {}


## The UI font, or its bold when [param bold] is true.
static func font(bold: bool = false) -> FontFile:
	if not _fonts.has(bold):
		_build(bold)
	return _fonts[bold]


## How many UI pixels wide [param text] is: the sum of its characters' advances.
static func width(text: String, bold: bool = false) -> int:
	var total: int = 0
	for character: String in text:
		total += advance(character, bold)
	return total


## How far the pen moves after [param character]: its drawn width plus [constant SPACING]
## ([constant DIGIT_ADVANCE] for a digit, [constant SPACE_ADVANCE] for a space, 0 for a character
## the font has no glyph for).
static func advance(character: String, bold: bool = false) -> int:
	if character == " ":
		return SPACE_ADVANCE
	if character.length() == 1 and character >= "0" and character <= "9":
		return DIGIT_ADVANCE + (1 if bold else 0)
	if not has_glyph(character, bold):
		return 0
	return drawn_width(character, bold) + SPACING


## True if the font has a glyph for [param character].
static func has_glyph(character: String, bold: bool = false) -> bool:
	if not _index.has(bold):
		_build(bold)
	return (_index[bold] as Dictionary).has(character)


## The pixels [param character]'s glyph inks, each a column and row of its [constant CELL] (the
## baseline is under row [code]CAP_HEIGHT - 1[/code]). Empty for a character with no glyph.
static func ink(character: String, bold: bool = false) -> Array[Vector2i]:
	var inked: Array[Vector2i] = []
	if not has_glyph(character, bold):
		return inked
	var index: int = (_index[bold] as Dictionary)[character]
	var image: Image = _images[bold]
	for y: int in CELL.y:
		for x: int in CELL.x:
			if image.get_pixel(index * CELL.x + x, y).a > 0.5:
				inked.append(Vector2i(x, y))
	return inked


## How many columns of its cell [param character]'s glyph inks, from the left edge.
static func drawn_width(character: String, bold: bool = false) -> int:
	var widest: int = 0
	for pixel: Vector2i in ink(character, bold):
		widest = maxi(widest, pixel.x + 1)
	return widest


## The character a part of the sheet draws, from its name: [code]cap_a[/code] is A, [code]a[/code]
## is a, [code]digit_0[/code] is 0, [code]period[/code] is a full stop; "" for an unknown name.
static func character_of(part: String) -> String:
	if part.begins_with("cap_") and part.length() == 5:
		return part.right(1).to_upper()
	if part.begins_with("digit_") and part.length() == 7:
		return part.right(1)
	if part.length() == 1:
		return part
	for character: String in PUNCTUATION:
		if PUNCTUATION[character] == part:
			return character
	return ""


## A [Label] showing [param text] in the UI font (its bold if [param bold]), in the palette colour
## called [param colour].
static func label(text: String, colour: StringName = &"silver", bold: bool = false) -> Label:
	var made := Label.new()
	made.text = text
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_font_override(&"font", font(bold))
	made.add_theme_font_size_override(&"font_size", SIZE)
	WindowText.set_colour(made, colour)
	return made


## Reads one sheet and makes its font: every glyph a whole-pixel bitmap with no smoothing, drawn
## only at [constant SIZE] or a whole multiple of it.
static func _build(bold: bool) -> void:
	var path: String = BOLD_PATH if bold else REGULAR_PATH
	var image: Image = load(path) as Image
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(path.get_basename() + ".json")
	)
	var names: Array = (parsed as Dictionary).get("parts", []) if parsed is Dictionary else []
	if image == null or names.is_empty():
		push_error("UiText: cannot read %s and its .json; bake its .px source" % path)
		image = Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	_images[bold] = image
	var index: Dictionary[String, int] = {}
	for at: int in names.size():
		var character: String = character_of(str(names[at]))
		if not character.is_empty():
			index[character] = at
	_index[bold] = index
	var made := FontFile.new()
	made.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	made.generate_mipmaps = false
	made.hinting = TextServer.HINTING_NONE
	made.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	made.allow_system_fallback = false
	made.fixed_size = SIZE
	made.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	var cache: Vector2i = Vector2i(SIZE, 0)
	made.set_texture_image(0, cache, 0, image)
	made.set_cache_ascent(0, SIZE, ASCENT)
	made.set_cache_descent(0, SIZE, DESCENT)
	_fonts[bold] = made
	for character: String in index:
		var code: int = character.unicode_at(0)
		var at: int = index[character]
		made.set_glyph_advance(0, SIZE, code, Vector2(advance(character, bold), 0))
		made.set_glyph_offset(0, cache, code, Vector2(0, -CAP_HEIGHT))
		made.set_glyph_size(0, cache, code, Vector2(CELL))
		made.set_glyph_uv_rect(0, cache, code, Rect2(at * CELL.x, 0, CELL.x, CELL.y))
		made.set_glyph_texture_idx(0, cache, code, 0)
