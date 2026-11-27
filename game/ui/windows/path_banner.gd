class_name PathBanner
extends Control
## The banner over one path of a talent tree: the path's name in bold and,
## under it, one short line saying what a hero on it becomes ([member SkillPathDef.summary]), in a
## box edged and striped in the path's colour ([PathColours]). The tree's view shows one over each
## path.

## UI pixels inside the box's edge, and the width of the coloured stripe down its left side.
const PAD: float = 4.0
const STRIPE: float = 3.0
## Where the words start, right of the stripe.
const WORDS_X: float = PAD + STRIPE + 3.0

## The path shown (0 to 2), and its colour's palette name.
var index: int = 0
var path_colour: StringName = PathColours.PLAIN
var name_label: Label
var summary_label: Label


## The banner of path [param path_index] of [param tree], [param width] UI pixels wide.
func _init(tree: TalentTreeDef, path_index: int, width: float) -> void:
	index = path_index
	name = "Banner%d" % path_index
	mouse_filter = Control.MOUSE_FILTER_PASS  # for its tooltip; the wheel goes on to the scroll
	path_colour = PathColours.of(tree.class_id, path_index)
	var shown: SkillPathDef = tree.path(path_index)
	var title: String = shown.display_name if shown != null else ""
	var summary: String = shown.summary if shown != null else ""
	name_label = WindowText.label("Name", title, path_colour, true)
	name_label.position = Vector2(WORDS_X, PAD)
	add_child(name_label)
	summary_label = WindowText.label("Summary", "", &"silver")
	var lines: Array[String] = WindowText.wrap(summary, width - WORDS_X - PAD)
	WindowText.set_text(summary_label, "\n".join(PackedStringArray(lines)))
	summary_label.position = Vector2(WORDS_X, PAD + UiText.LINE_HEIGHT)
	add_child(summary_label)
	size = Vector2(width, summary_label.position.y + summary_label.size.y + PAD)
	custom_minimum_size = size


## Makes the banner [param tall] UI pixels tall (the banners of a tree are as tall as the tallest).
func set_height(tall: float) -> void:
	size.y = tall
	custom_minimum_size = size
	queue_redraw()


## The palette name of the box's edge and stripe: the path's colour.
func colour() -> StringName:
	return path_colour


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Palette.color(path_colour))
	draw_rect(box.grow(-1.0), Palette.color(&"night"))
	draw_rect(Rect2(1, 1, STRIPE, size.y - 2.0), Palette.color(path_colour))
