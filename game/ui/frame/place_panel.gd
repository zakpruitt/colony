class_name PlacePanel
extends FramePiece
## Where the party is, at the top left, on the sharp layer. Its top row: the area's
## name as a button (a click opens the area map; [member area_mark] counts the areas
## opened since the map was last opened), the stage in large digits, the target with its
## [code]-[/code] and [code]+[/code] buttons, and the Auto switch. Under it, the line saying what
## the party is doing and why ([method Hud.status_text], in the state's colour), and at the right
## the safe stage ([code]Safe 3[/code]): kept off the top row so the panel leaves the boss bar room
## at 960x540. The texts are the HUD's; this only draws them, and the HUD connects the buttons.
## A new safe stage steps [code]Safe N[/code] up in yellow ([method step_safe], run on by
## [method run_step]; [Milestones] calls both).

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
## Each control's tooltip.
const STAGE_TIP: String = "The stage the party is on now."
const STATUS_TIP: String = "What the party is doing right now, and why."
const SAFE_TIP: String = "The last safe stage: a wipe sends the party back there."
const TARGET_TIP: String = "The stage the party is heading for."
const MINUS_TIP: String = "Set the target one stage back."
const PLUS_TIP: String = "Set the target one stage further."
const AUTO_TIP: String = (
	"When on, the party goes a stage further each time it holds its target " + "long enough."
)

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
## Seconds left of the safe stage's step up; 0 when still.
var safe_step: float = 0.0

var _lift: float = 0.0
## What the panel was last shown: [method show_place] words and lays out only a change.
var _shown: ShownValues = ShownValues.new()


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
	_shown.begin()
	_shown.see(area)
	_shown.see(stage)
	_shown.see(stage_colour)
	_shown.see(lift)
	_shown.see(safe)
	_shown.see(target)
	_shown.see(auto_on)
	_shown.see(status)
	_shown.see(status_colour)
	_shown.see(area_mark.visible)
	if not _shown.changed():
		return
	if area_button.text != area:
		area_button.text = area
	# Sized at 1x here; the label stays big enough at its 2x font because a Control never shrinks
	# below its minimum size.
	WindowText.set_text(stage_label, str(stage))
	WindowText.set_colour(stage_label, stage_colour)
	WindowText.set_text(safe_label, "Safe %d" % safe)
	WindowText.set_text(target_label, str(target))
	auto_button.text = "Auto on" if auto_on else "Auto off"
	auto_button.lit = auto_on
	WindowText.set_text(status_label, status)
	WindowText.set_colour(status_label, status_colour)
	_lift = lift
	lay_out()


## [code]Safe N[/code] steps up, in yellow, for [constant HeroFrameView.STEP_SECONDS].
func step_safe() -> void:
	safe_step = HeroFrameView.STEP_SECONDS
	_show_step()


## Runs the safe stage's step on by [param delta] seconds. [Milestones] calls it every frame,
## before the world syncs, not the HUD.
func run_step(delta: float) -> void:
	if safe_step <= 0.0:
		return
	safe_step = maxf(safe_step - delta, 0.0)
	_show_step()


## Ends the safe stage's step at once (the world is catching up).
func stop_step() -> void:
	if safe_step > 0.0:
		safe_step = 0.0
		_show_step()


## The area's name tells the area and what a click does; each other control says what it is.
func add_tips(tips: UiTip) -> void:
	tips.attach(area_button, HudFrame.area_tip(), area_button.get_text)
	tips.attach(stage_label, STAGE_TIP)
	tips.attach(status_label, STATUS_TIP)
	tips.attach(safe_label, SAFE_TIP)
	tips.attach(target_label, TARGET_TIP)
	tips.attach(target_caption, TARGET_TIP)
	tips.attach(minus_button, MINUS_TIP)
	tips.attach(plus_button, PLUS_TIP)
	tips.attach(auto_button, AUTO_TIP)


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
	x += WindowText.ink(stage_label) * STAGE_SCALE + GAP * 2.0
	target_caption.position = Vector2(x, text_y)
	x += WindowText.ink(target_caption) + GAP
	minus_button.position = Vector2(x, BUTTON_Y)
	x += minus_button.size.x + 4.0
	target_label.position = Vector2(x, text_y)
	x += WindowText.ink(target_label) + 4.0
	plus_button.position = Vector2(x, BUTTON_Y)
	x += plus_button.size.x + GAP
	auto_button.position = Vector2(x, BUTTON_Y)
	x += auto_button.size.x
	status_label.position = Vector2(PAD + 2.0, LINE_Y)
	# The safe stage at the right of the line under the buttons, clear of the status.
	var status_end: float = status_label.position.x + WindowText.ink(status_label)
	var safe_x: float = maxf(x - WindowText.ink(safe_label), status_end + GAP * 2.0)
	safe_label.position = Vector2(safe_x, LINE_Y - HeroFrameView.step_lift(safe_step))
	x = maxf(x, safe_x + WindowText.ink(safe_label))
	size = Vector2(ceilf(x + PAD), HEIGHT)


## The safe stage as its step has it now: yellow and raised while stepping, else silver in place.
func _show_step() -> void:
	var colour: StringName = &"yellow" if safe_step > 0.0 else &"silver"
	WindowText.set_colour(safe_label, colour)
	lay_out()
