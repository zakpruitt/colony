class_name ParagonCell
extends Control
## One paragon stat under a hero's talent tree: a medallion, the stat's picture in a
## large [UiIcon] with the stat's rank as its count, and under it the stat's name and the total its
## ranks give ([code]+6% damage and healing[/code]). A click on the medallion spends a point
## ([HeroTalentsTab]); it shows ready (pulsing) while the hero has one. [method refresh] reads the
## hero each frame.

## The cell's width: room for the longest total under the medallion.
const WIDTH: float = 132.0
## UI pixels between the medallion and the name.
const GAP: float = 1.0
## Seconds a stat's total shows in yellow after a point goes in.
const FLASH_SECONDS: float = 0.5

## The stat this cell shows: a [TrainingDef] id.
var id: StringName
var medallion: UiIcon
## The stat's own picture, in the medallion.
var picture: TextureRect
var name_label: Label
## The total the stat's ranks give.
var total_label: Label
## The same label as [member total_label], under a second name.
var rank_label: Label

var _flash: float = 0.0
var _rank: int = 0


## A cell for stat [param training_id], the [param index]th (0-based).
func _init(training_id: StringName, index: int) -> void:
	id = training_id
	name = "Paragon%d" % (index + 1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion = UiIcon.new(training_id, true, UiIcon.Shape.CUT)
	medallion.name = "Medallion"
	medallion.mouse_filter = Control.MOUSE_FILTER_PASS  # the wheel goes on to the window's scroll
	medallion.position = Vector2(floorf((WIDTH - medallion.size.x) / 2.0), 0)
	add_child(medallion)
	picture = medallion.picture_rect
	var def: TrainingDef = Content.training(training_id)
	name_label = WindowText.label("Name", def.display_name, &"white", true)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS  # for its tooltip
	add_child(name_label)
	total_label = WindowText.label("Total", "", &"green")
	total_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(total_label)
	rank_label = total_label
	size = Vector2(WIDTH, medallion.size.y + GAP + 2.0 * UiText.LINE_HEIGHT)
	custom_minimum_size = size


## Brings the cell up to date with [param hero]: its rank, its total in words and its look.
func show_hero(hero: Hero) -> void:
	var def: TrainingDef = Content.training(id)
	var rank: int = hero.paragon_rank(def.stat)
	_rank = rank
	medallion.set_count(str(rank))
	var can_spend: bool = hero.paragon_points() > 0
	var look: UiIcon.State = UiIcon.State.OWNED if rank > 0 else UiIcon.State.LOCKED
	medallion.show_state(UiIcon.State.READY if can_spend else look)
	WindowText.set_text(total_label, total_text(def, rank))
	_centre(name_label, medallion.size.y + GAP)
	_centre(total_label, medallion.size.y + GAP + UiText.LINE_HEIGHT)
	_show_colour()


## Runs the cell's pulse and flash on by [param delta] seconds.
func advance(delta: float) -> void:
	medallion.advance(delta)
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_show_colour()


## The total [param rank] points of [param def] give, in words: [code]+6% damage and healing[/code]
## (the stat's description, a rank's share replaced by the whole).
static func total_text(def: TrainingDef, rank: int) -> String:
	var what: String = def.description
	if what.begins_with("+"):
		what = what.substr(what.find(" ") + 1) if what.find(" ") > 0 else ""
	return ("+%d%% %s" % [roundi(rank * def.per_rank * 100.0), what]).strip_edges()


## The cell as one line: "<name> <points> +<percent>%" ([code]Power 2 +6%[/code]).
func text() -> String:
	var def: TrainingDef = Content.training(id)
	return "%s %d +%d%%" % [def.display_name, _rank, roundi(_rank * def.per_rank * 100.0)]


## Starts the flash: a point just went in.
func start_flash() -> void:
	_flash = FLASH_SECONDS
	_show_colour()


## Stops the flash at once.
func stop_flash() -> void:
	_flash = 0.0
	_show_colour()


## Seconds of flash left.
func flash() -> float:
	return _flash


## The total's colour: yellow while the cell flashes, else green once it has a rank.
func _show_colour() -> void:
	var colour: StringName = &"green" if _rank > 0 else &"steel"
	if _flash > 0.0:
		colour = &"yellow"
	WindowText.set_colour(total_label, colour)


func _centre(label: Label, y: float) -> void:
	label.position = Vector2(floorf((WIDTH - label.size.x) / 2.0), y)
