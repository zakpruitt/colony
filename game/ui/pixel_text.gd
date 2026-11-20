class_name PixelText
extends RefCounted
## Colony's pixel font (assets/fonts/pixel.px, see docs/style-bible.md "Text") and helpers for
## code that draws text. Every Control already uses the font through the project theme
## (res://game/ui/theme.tres); these are for measuring text and for labels that need a colour.

const FONT_PATH: String = "res://assets/fonts/pixel.png"
## The font's one size, the size its glyphs were drawn at. It is the cell height of the sheet,
## not the cap height (5) or the line height (7): Godot's image font importer counts the cell.
const SIZE: int = 8
## The offset of the shadow under a label from [method label], in pixels.
const SHADOW_OFFSET: int = 1

static var _font: Font


## The pixel font, imported from its baked sheet by Godot's image font importer.
static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font


## How many pixels wide [param text] is in the pixel font: the sum of its characters' advances,
## each a glyph's drawn width plus one column of spacing.
static func width(text: String) -> int:
	if text.is_empty():
		return 0
	return roundi(font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x)


## A [Label] showing [param text] in the pixel font, tinted with the palette colour called
## [param color_name], with a 1-pixel [code]ink[/code] shadow so it reads over any background.
static func label(text: String, color_name: StringName = &"white") -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_font_override(&"font", font())
	made.add_theme_font_size_override(&"font_size", SIZE)
	WindowText.set_colour(made, color_name)
	made.add_theme_color_override(&"font_shadow_color", Palette.color(&"ink"))
	made.add_theme_constant_override(&"shadow_offset_x", SHADOW_OFFSET)
	made.add_theme_constant_override(&"shadow_offset_y", SHADOW_OFFSET)
	return made
