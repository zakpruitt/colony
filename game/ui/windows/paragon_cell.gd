class_name ParagonCell
extends Control
## One paragon stat under a hero's talent tree (spec 055 R7, on the UI layer by spec 060): a
## [code]+1[/code] button, the stat's name and the bonus its points give so far. [method refresh]
## reads the hero each frame.

## UI pixels between the button and the name, and between the name and the bonus.
const GAP: float = 5.0
## Letters a stat's name keeps when the row is too wide for the full names.
const SHORT_NAME: int = 5
## Seconds a stat's bonus shows in yellow after a point goes in.
const FLASH_SECONDS: float = 0.5

## The stat this cell shows: a [TrainingDef] id.
var id: StringName
var buy_button: UiButton
var name_label: Label
var rank_label: Label

var _flash: float = 0.0
var _rank: int = 0


## A cell for stat [param training_id], the [param index]th (0-based).
func _init(training_id: StringName, index: int) -> void:
	id = training_id
	name = "Paragon%d" % (index + 1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_button = WindowText.button("Spend", "+1")
	add_child(buy_button)
	var def: TrainingDef = Content.training(training_id)
	var middle: float = floorf((UiTheme.BUTTON_HEIGHT - UiText.LINE_HEIGHT) / 2.0)
	name_label = WindowText.label("Name", def.display_name, &"white")
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS  # for its tooltip
	name_label.position = Vector2(buy_button.size.x + GAP, middle)
	add_child(name_label)
	rank_label = WindowText.label("Rank", "", &"green")
	rank_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(rank_label)


## Brings the cell up to date with [param hero] and runs its flash down by [param delta];
## [param short] shows the stat's name cut to [constant SHORT_NAME] letters.
func refresh(hero: Hero, delta: float, short: bool = false) -> void:
	var def: TrainingDef = Content.training(id)
	var shown_name: String = def.display_name.left(SHORT_NAME) if short else def.display_name
	WindowText.set_text(name_label, shown_name)
	var rank: int = hero.paragon_rank(def.stat)
	_rank = rank
	WindowText.set_text(rank_label, "+%d%%" % roundi(rank * def.per_rank * 100.0))
	rank_label.position = Vector2(
		name_label.position.x + name_label.size.x + GAP, name_label.position.y
	)
	size = Vector2(rank_label.position.x + rank_label.size.x, UiTheme.BUTTON_HEIGHT)
	buy_button.disabled = hero.paragon_points() <= 0
	_flash = maxf(_flash - delta, 0.0)
	var colour: StringName = &"green" if rank > 0 else &"steel"
	if _flash > 0.0:
		colour = &"yellow"
	rank_label.add_theme_color_override(&"font_color", Palette.color(colour))


## The cell as one line: "<name> <points> <bonus>" ([code]Power 2 +6%[/code]); the cell shows
## the name and the bonus.
func text() -> String:
	return "%s %d %s" % [Content.training(id).display_name, _rank, rank_label.text]


## Starts the flash: a point just went in.
func start_flash() -> void:
	_flash = FLASH_SECONDS


## Stops the flash at once.
func stop_flash() -> void:
	_flash = 0.0


## Seconds of flash left.
func flash() -> float:
	return _flash
