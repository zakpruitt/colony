class_name PathBanner
extends Control
## The banner over one path of a talent tree (spec 064 R1, R3, R4): the path's name in bold and,
## under it, one short line saying what a hero on it becomes
## ([member TalentTreeDef.path_summaries]), in a box edged and striped in the path's colour
## ([PathColours]). Closed (the hero chose the other path), the box is dimmed to greys, a padlock
## shows at its right and [code]Not chosen[/code] beside the name. The tree's view, and the
## question before a path, show it.

## UI pixels inside the box's edge, and the width of the coloured stripe down its left side.
const PAD: float = 4.0
const STRIPE: float = 3.0
## Where the words start, right of the stripe.
const WORDS_X: float = PAD + STRIPE + 3.0
## The padlock's cells, in UI pixels (it is [constant UiIcon.LOCK], 5 cells by 6).
const LOCK_CELL: float = 2.0

## The path shown (0 or 1), and its colour's palette name.
var index: int = 0
var path_colour: StringName = PathColours.PLAIN
var name_label: Label
var summary_label: Label
## [code]Not chosen[/code], shown only while the path is closed.
var closed_label: Label

var _closed: bool = false


## The banner of path [param path_index] of [param tree], [param width] UI pixels wide.
func _init(tree: TalentTreeDef, path_index: int, width: float) -> void:
	index = path_index
	name = "Banner%d" % path_index
	mouse_filter = Control.MOUSE_FILTER_PASS  # for its tooltip; the wheel goes on to the scroll
	path_colour = PathColours.of(tree.class_id, path_index)
	var title: String = tree.path_names[path_index] if path_index < tree.path_names.size() else ""
	var summary: String = ""
	if path_index < tree.path_summaries.size():
		summary = tree.path_summaries[path_index]
	name_label = WindowText.label("Name", title, path_colour, true)
	name_label.position = Vector2(WORDS_X, PAD)
	add_child(name_label)
	closed_label = WindowText.label("NotChosen", "Not chosen", &"slate")
	closed_label.visible = false
	add_child(closed_label)
	summary_label = WindowText.label("Summary", "", &"silver")
	var lines: Array[String] = WindowText.wrap(summary, width - WORDS_X - PAD)
	WindowText.set_text(summary_label, "\n".join(PackedStringArray(lines)))
	summary_label.position = Vector2(WORDS_X, PAD + UiText.LINE_HEIGHT)
	add_child(summary_label)
	size = Vector2(width, summary_label.position.y + summary_label.size.y + PAD)
	custom_minimum_size = size
	closed_label.position = Vector2(width - PAD - LOCK_CELL * 5.0 - 4.0 - closed_label.size.x, PAD)
	_apply()


## Makes the banner [param tall] UI pixels tall (the two of a tree are as tall as the taller).
func set_height(tall: float) -> void:
	size.y = tall
	custom_minimum_size = size
	queue_redraw()


## Shows the path as closed (the hero walks the other) or open.
func show_closed(closed: bool) -> void:
	if closed == _closed:
		return
	_closed = closed
	_apply()


## True while the banner shows its path as closed.
func is_closed() -> bool:
	return _closed


## True when the padlock shows (the path is closed).
func has_lock() -> bool:
	return _closed


## The palette name of the box's edge and stripe now: the path's colour, or dusk when closed.
func colour() -> StringName:
	return PathColours.DIM if _closed else path_colour


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Palette.color(colour()))
	draw_rect(box.grow(-1.0), Palette.color(&"ink" if _closed else &"night"))
	draw_rect(Rect2(1, 1, STRIPE, size.y - 2.0), Palette.color(colour()))
	if not _closed:
		return
	var at := Vector2(size.x - PAD - LOCK_CELL * 5.0, PAD)
	for y: int in UiIcon.LOCK.size():
		for x: int in UiIcon.LOCK[y].length():
			var symbol: String = UiIcon.LOCK[y][x]
			if symbol == ".":
				continue
			var shade: StringName = &"ink" if symbol == "k" else (&"silver" if y < 2 else &"steel")
			draw_rect(
				Rect2(at + Vector2(x, y) * LOCK_CELL, Vector2.ONE * LOCK_CELL), Palette.color(shade)
			)


func _apply() -> void:
	closed_label.visible = _closed
	name_label.add_theme_color_override(
		&"font_color", Palette.color(&"steel" if _closed else path_colour)
	)
	summary_label.add_theme_color_override(
		&"font_color", Palette.color(&"slate" if _closed else &"silver")
	)
	queue_redraw()
