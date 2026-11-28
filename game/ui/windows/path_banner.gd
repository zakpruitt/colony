class_name PathBanner
extends Control
## The banner over one path of a talent tree: the path's name in bold, the hero's rank in it at
## the right of that line ([code]Rank 2[/code], [code]Rank 10, top[/code] at the last), and, under
## it, what a hero on it becomes ([member SkillPathDef.summary]) on up to two lines, in a box edged
## and striped in the path's colour ([PathColours]). Under the box, its [RankBar]: how far the
## path's XP has come toward the next rank. The tree's view shows one at the top of each path's
## panel.

## UI pixels inside the box's edge, and the width of the coloured stripe down its left side.
const PAD: float = 4.0
const STRIPE: float = 3.0
## Where the words start, right of the stripe.
const WORDS_X: float = PAD + STRIPE + 3.0
## UI pixels between the box and the bar under it.
const BAR_GAP: float = 3.0

## The path shown (0 to 2), and its colour's palette name.
var index: int = 0
var path_colour: StringName = PathColours.PLAIN
var name_label: Label
var summary_label: Label
var rank_label: Label
## The bar to the next rank.
var rank_bar: RankBar

var _rank: int = -1
var _width: float = 0.0
## The box's height: the words and the space round them.
var _box_height: float = 0.0


## The banner of path [param path_index] of [param tree], [param width] UI pixels wide.
func _init(tree: TalentTreeDef, path_index: int, width: float) -> void:
	index = path_index
	_width = width
	name = "Banner%d" % path_index
	mouse_filter = Control.MOUSE_FILTER_PASS  # for its tooltip; the wheel goes on to the scroll
	path_colour = PathColours.of(tree.class_id, path_index)
	var shown: SkillPathDef = tree.path(path_index)
	var title: String = shown.display_name if shown != null else ""
	var summary: String = shown.summary if shown != null else ""
	name_label = WindowText.label("Name", title, path_colour, true)
	name_label.position = Vector2(WORDS_X, PAD)
	add_child(name_label)
	rank_label = WindowText.label("Rank", "", &"silver")
	add_child(rank_label)
	summary_label = WindowText.label("Summary", "", &"silver")
	var lines: Array[String] = WindowText.wrap(summary, width - WORDS_X - PAD)
	WindowText.set_text(summary_label, "\n".join(PackedStringArray(lines)))
	summary_label.position = Vector2(WORDS_X, PAD + UiText.LINE_HEIGHT)
	add_child(summary_label)
	rank_bar = RankBar.new(path_colour)
	add_child(rank_bar)
	show_rank(RankStanding.new())  # rank 0 until a hero is read
	_rank = -1
	set_height(summary_label.position.y + summary_label.size.y + PAD + BAR_GAP + RankBar.HEIGHT)


## Shows the hero's [param standing] in the path: its rank at the right of the name's line, and
## on the bar the XP into the rank of its span (full at the top).
func show_rank(standing: RankStanding) -> void:
	_rank = standing.rank
	rank_bar.show_share(standing.share())
	var text: String = "Rank %d, top" % _rank if standing.top else "Rank %d" % _rank
	if rank_label.text == text:
		return
	WindowText.set_text(rank_label, text)
	rank_label.position = Vector2(_width - PAD - rank_label.size.x, PAD)


## The rank shown, or -1 before one was.
func shown_rank() -> int:
	return _rank


## Makes the banner [param tall] UI pixels tall, its bar at the foot (the banners of a tree are as
## tall as the tallest).
func set_height(tall: float) -> void:
	size = Vector2(_width, tall)
	custom_minimum_size = size
	_box_height = tall - BAR_GAP - RankBar.HEIGHT
	rank_bar.position = Vector2(0, _box_height + BAR_GAP)
	rank_bar.size = Vector2(_width, RankBar.HEIGHT)
	queue_redraw()


## Runs the bar's sweep on by [param delta] seconds.
func advance(delta: float) -> void:
	rank_bar.advance(delta)


## Ends what plays: the bar stands where the XP is.
func stop() -> void:
	rank_bar.stop()


## The palette name of the box's edge and stripe: the path's colour.
func colour() -> StringName:
	return path_colour


func _draw() -> void:
	var box := Rect2(0, 0, size.x, _box_height)
	draw_rect(box, Palette.color(path_colour))
	draw_rect(box.grow(-1.0), Palette.color(&"night"))
	draw_rect(Rect2(1, 1, STRIPE, _box_height - 2.0), Palette.color(path_colour))
