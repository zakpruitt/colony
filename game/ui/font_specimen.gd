class_name FontSpecimen
extends Control
## Shows the pixel font so a person can judge it: the whole character set, the characters that
## are easy to confuse side by side, and a sample line in four palette colours over a dark and a
## light background (docs/style-bible.md, "Text").
## Run: python tools/dev.py shot --scene=res://game/ui/font_specimen.tscn --name=font

## The line spec 009 asks to be comfortably readable at 640x360.
const SAMPLE: String = "Depth 12  Gold 3,450  Lv 7"
## Every character the font draws, grouped.
const CHARACTER_SET: PackedStringArray = [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789  . , ! ? : ; ' \" + - x / % ( ) < > = * # _",
]
## Pairs that must not be mistaken for each other.
const LOOKALIKES: String = "0O  1lI  5S  8B  2Z  rn m  vy  ij"
const PROSE: PackedStringArray = [
	"The quick brown fox jumps over the lazy dog.",
	"Knight hits Rat for 12 (crit!)  HP 34/40  x2  +15% gold",
]
## The palette colours the sample is shown in.
const TINTS: Array[StringName] = [&"white", &"yellow", &"cyan", &"red"]
const MARGIN: int = 8
const GAP: int = 4


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

	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation", GAP)
	rows.add_child(panels)
	panels.add_child(_panel(Palette.color(&"ink")))
	panels.add_child(_panel(Palette.color(&"night")))
	panels.add_child(_panel(Palette.color(&"silver")))
	panels.add_child(_panel(Palette.color(&"sand")))


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
