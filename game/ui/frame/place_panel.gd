class_name PlacePanel
extends Panel
## Where the party is, at the top left (spec 061 R1), on the sharp layer. Its top row: the area's
## name as a button (a click opens the area map, spec 053; [member area_mark] counts the areas
## opened since the map was last opened), the stage in large digits, the safe stage
## ([code]Safe 3[/code]), the target with its [code]-[/code] and [code]+[/code] buttons, and the
## Auto switch. Under it, the line saying what the party is doing and why ([method Hud.status_text],
## in the state's colour). The texts are the HUD's; this only draws them, and the HUD connects the
## buttons.

## The panel's height; its rows' tops; the space inside its edge and between neighbours.
const HEIGHT: float = 41.0
const BUTTON_Y: float = 2.0
const LINE_Y: float = 26.0
const PAD: float = 4.0
const GAP: float = 6.0
## The stage's digits are the bold font at this multiple.
const STAGE_SCALE: int = 2
## The least width of the Auto switch: as wide as "Auto off", so it does not jump.
const AUTO_TEXTS: Array[String] = ["Auto on", "Auto off"]

## The area's name: a click opens the area map.
var area_button: UiButton
## The number of areas opened since the map was last opened, on the area's name.
var area_mark: UiBadge
var stage_label: Label
var safe_label: Label
var target_caption: Label
var minus_button: UiButton
var target_label: Label
var plus_button: UiButton
var auto_button: UiButton
var status_label: Label

var _lift: float = 0.0


func _init() -> void:
	name = "PlacePanel"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP
	area_button = UiButton.new("")
	area_button.name = "AreaButton"
	add_child(area_button)
	area_mark = UiBadge.new()
	area_mark.name = "AreaMark"
	add_child(area_mark)
	stage_label = UiText.label("1", &"white", true)
	stage_label.name = "StageNumber"
	stage_label.add_theme_font_size_override(&"font_size", UiText.SIZE * STAGE_SCALE)
	add_child(stage_label)
	safe_label = UiText.label("", &"silver")
	safe_label.name = "Safe"
	add_child(safe_label)
	target_caption = UiText.label("Target", &"steel")
	target_caption.name = "TargetCaption"
	add_child(target_caption)
	minus_button = UiButton.new("-")
	minus_button.name = "Minus"
	add_child(minus_button)
	target_label = UiText.label("", &"yellow", true)
	target_label.name = "Target"
	add_child(target_label)
	plus_button = UiButton.new("+")
	plus_button.name = "Plus"
	add_child(plus_button)
	auto_button = UiButton.new("Auto off")
	auto_button.name = "Auto"
	add_child(auto_button)
	status_label = UiText.label("", &"silver")
	status_label.name = "Status"
	add_child(status_label)


## Shows the place: the area [param area], stage [param stage] (lifted [param lift] UI pixels and
## in [param stage_colour] while it is emphasised), the safe stage [param safe], the target
## [param target], Auto [param auto_on], and the [param status] line in [param status_colour]; then
## lays the panel out.
func show_place(
	area: String,
	stage: int,
	stage_colour: StringName,
	lift: float,
	safe: int,
	target: int,
	auto_on: bool,
	status: String,
	status_colour: StringName
) -> void:
	if area_button.text != area:
		area_button.text = area
	_set_text(stage_label, str(stage))
	stage_label.add_theme_color_override(&"font_color", Palette.color(stage_colour))
	_set_text(safe_label, "Safe %d" % safe)
	_set_text(target_label, str(target))
	auto_button.text = "Auto on" if auto_on else "Auto off"
	auto_button.lit = auto_on
	_set_text(status_label, status)
	status_label.add_theme_color_override(&"font_color", Palette.color(status_colour))
	_lift = lift
	lay_out()


## Lays the panel out from left to right and sizes it to fit.
func lay_out() -> void:
	var x: float = PAD
	var widest: int = 0
	for text: String in AUTO_TEXTS:
		widest = maxi(widest, UiText.width(text, true) - UiText.SPACING)
	auto_button.custom_minimum_size.x = widest + 2 * (UiTheme.BUTTON_PAD_X + 1)
	for button: UiButton in [area_button, minus_button, plus_button, auto_button]:
		button.reset_size()
		button.size = button.get_combined_minimum_size()
	area_button.position = Vector2(x, BUTTON_Y)
	if area_mark.visible:
		area_mark.position = Vector2(
			area_button.position.x + area_button.size.x - area_mark.size.x + 2.0, BUTTON_Y - 1.0
		)
	x += area_button.size.x + GAP
	var text_y: float = BUTTON_Y + floorf((UiTheme.BUTTON_HEIGHT - UiText.LINE_HEIGHT) / 2.0)
	# The big digits' capitals centred on the row: they rise ASCENT - CAP_HEIGHT above the line.
	var caps: float = float(UiText.CAP_HEIGHT * STAGE_SCALE)
	var air: float = float((UiText.ASCENT - UiText.CAP_HEIGHT) * STAGE_SCALE)
	stage_label.position = Vector2(
		x, BUTTON_Y + floorf((UiTheme.BUTTON_HEIGHT - caps) / 2.0) - air - _lift
	)
	x += _ink(stage_label, true) * STAGE_SCALE + GAP
	safe_label.position = Vector2(x, text_y)
	x += _ink(safe_label, false) + GAP * 2.0
	target_caption.position = Vector2(x, text_y)
	x += _ink(target_caption, false) + GAP
	minus_button.position = Vector2(x, BUTTON_Y)
	x += minus_button.size.x + 4.0
	target_label.position = Vector2(x, text_y)
	x += _ink(target_label, true) + 4.0
	plus_button.position = Vector2(x, BUTTON_Y)
	x += plus_button.size.x + GAP
	auto_button.position = Vector2(x, BUTTON_Y)
	x += auto_button.size.x
	status_label.position = Vector2(PAD + 2.0, LINE_Y)
	x = maxf(x, status_label.position.x + _ink(status_label, false))
	size = Vector2(ceilf(x + PAD), HEIGHT)


static func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
		label.reset_size()


## How wide [param label]'s text inks at the font's own size, in UI pixels.
static func _ink(label: Label, bold: bool) -> float:
	return maxf(UiText.width(label.text, bold) - UiText.SPACING, 0.0)
