class_name FontSpecimen
extends Control
## Shows the fonts so a person can judge them: the whole character set, the characters that are
## easy to confuse side by side, and sample lines. On the left, in the world's 640x360 pixels, the
## old pixel font (docs/style-bible.md, "Text") over a dark and a light background in four palette
## colours; on the right, on the sharp UI layer (spec 058), the UI font and its bold.
## Run: python tools/dev.py shot --scene=res://game/ui/font_specimen.tscn --name=font

## The line spec 009 asks to be comfortably readable at 640x360.
const SAMPLE: String = "Stage 12  Gold 3,450  Lv 7"
## Every character the old font draws, grouped.
const CHARACTER_SET: PackedStringArray = [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789  . , ! ? : ; ' \" + - x / % ( ) < > = * # _",
]
## Every character the UI font draws, grouped.
const UI_CHARACTER_SET: PackedStringArray = [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789  1,234,567  12:04  45%",
	". , : ; ! ? ' \" + - = * / \\ % & # @ $ _ ^ ~ ` | ( ) [ ] { } < >",
]
## Pairs that must not be mistaken for each other.
const LOOKALIKES: String = "0O  1lI  5S  8B  2Z  rn m  vy  ij"
const PROSE: PackedStringArray = [
	"The quick brown fox jumps over the lazy dog.",
	"Knight hits Rat for 12 (crit!)  HP 34/40  x2  +15% gold",
]
## The palette colours the old font's sample is shown in.
const TINTS: Array[StringName] = [&"white", &"yellow", &"cyan", &"red"]
const MARGIN: int = 8
const GAP: int = 4
## The UI font's half: where it starts across the room, and the room it is laid out for.
const UI_HALF: float = 0.5

## The sharp layer the UI font is shown on.
var ui: UiRoot


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.color(&"dusk")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	margin.add_theme_constant_override("margin_right", 320 + MARGIN)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GAP)
	margin.add_child(rows)

	# Plain labels: what any Label gets from the project theme.
	for line: String in CHARACTER_SET:
		rows.add_child(_plain(line))
	rows.add_child(_plain(LOOKALIKES))
	rows.add_child(_plain(SAMPLE))
	for line: String in PROSE:
		rows.add_child(_plain(line))

	var panels := GridContainer.new()
	panels.columns = 2
	panels.add_theme_constant_override("h_separation", GAP)
	panels.add_theme_constant_override("v_separation", GAP)
	rows.add_child(panels)
	panels.add_child(_panel(Palette.color(&"ink")))
	panels.add_child(_panel(Palette.color(&"night")))
	panels.add_child(_panel(Palette.color(&"silver")))
	panels.add_child(_panel(Palette.color(&"sand")))

	ui = UiRoot.new()
	add_child(ui)
	_ui_half()


func _plain(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


## The sample line in every tint, over one background colour.
func _panel(color: Color) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(GAP)
	panel.add_theme_stylebox_override("panel", style)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", GAP)
	panel.add_child(lines)
	for tint: StringName in TINTS:
		lines.add_child(PixelText.label(SAMPLE, tint))
	return panel


## The UI font and its bold, on a window's panel in the right half of the UI layer's room.
func _ui_half() -> void:
	var room: Vector2 = Vector2(ui.room())
	var panel := PanelContainer.new()
	panel.name = "UiFont"
	panel.theme_type_variation = UiTheme.WINDOW
	panel.position = Vector2(roundf(room.x * UI_HALF), MARGIN * 2)
	panel.custom_minimum_size = Vector2(roundf(room.x * UI_HALF) - MARGIN * 2, 0)
	ui.frame.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	margin.add_child(rows)
	for bold: bool in [false, true]:
		rows.add_child(UiText.label("UI font, bold" if bold else "UI font", &"yellow", true))
		for line: String in UI_CHARACTER_SET:
			rows.add_child(UiText.label(line, &"white", bold))
		rows.add_child(UiText.label(LOOKALIKES, &"cyan", bold))
		rows.add_child(UiText.label(SAMPLE, &"yellow", bold))
		for line: String in PROSE:
			rows.add_child(UiText.label(line, &"silver", bold))
		var gap := Control.new()
		gap.custom_minimum_size.y = MARGIN
		rows.add_child(gap)
