class_name RankTag
extends Control
## The small tag on a talent node its path's rank still holds shut: a dark pill along the bottom
## right of the node's slot with a padlock and the rank that opens the node ([code]5[/code]). It
## keeps to the slot's bottom third, off the picture's middle; the full words are on the card.

## Space inside the pill round its contents, and between the padlock and the number.
const PAD: int = 2
const GAP: int = 2
## The padlock's size in pixels (one pixel a cell of [constant UiIcon.LOCK]).
const LOCK_SIZE: Vector2i = Vector2i(5, 6)
## The pill's height: the digits' capitals and a pixel above and below.
const HEIGHT: int = UiText.CAP_HEIGHT + 2
## How far the pill stands in from the slot's bottom and right edges (on the frame's edge).
const INSET: int = 1

var _rank: int = 0


func _init() -> void:
	name = "RankTag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows [param rank] on the tag and sets it at the bottom right of a slot [param slot] in size;
## 0 hides it.
func show_rank(rank: int, slot: Vector2) -> void:
	_rank = rank
	visible = rank > 0
	if rank <= 0:
		return
	size = Vector2(PAD + LOCK_SIZE.x + GAP + number_rect().size.x + PAD, HEIGHT)
	position = slot - size - Vector2.ONE * INSET
	queue_redraw()


## The number written on the tag ("5"), or "" when it is hidden.
func text() -> String:
	return str(_rank) if _rank > 0 else ""


## Where the number's capitals are drawn, in the tag's own pixels: a pixel under its top edge.
## The number is drawn here rather than by a [Label], whose line box would hang past the pill.
func number_rect() -> Rect2:
	var wide: int = UiText.width(text()) - UiText.SPACING if _rank > 0 else 0
	return Rect2(PAD + LOCK_SIZE.x + GAP, 1, wide, UiText.CAP_HEIGHT)


## The rank shown, or 0 for none.
func shown_rank() -> int:
	return _rank


## True: the tag always carries its padlock.
func has_lock() -> bool:
	return visible


func _draw() -> void:
	# A slate edge with its corners cut by a pixel, for a pill, and ink inside it.
	var edge: Color = Palette.color(&"slate")
	draw_rect(Rect2(1, 0, size.x - 2, size.y), edge)
	draw_rect(Rect2(0, 1, size.x, size.y - 2), edge)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Palette.color(&"ink"))
	var at := Vector2(PAD, floorf((size.y - LOCK_SIZE.y) / 2.0))
	for y: int in UiIcon.LOCK.size():
		for x: int in UiIcon.LOCK[y].length():
			var symbol: String = UiIcon.LOCK[y][x]
			if symbol == ".":
				continue
			var colour: StringName = &"ink" if symbol == "k" else (&"silver" if y < 2 else &"steel")
			draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Palette.color(colour))
	var number: Rect2 = number_rect()
	var baseline := Vector2(number.position.x, number.end.y)
	draw_string(
		UiText.font(false),
		baseline,
		text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiText.SIZE,
		Palette.color(&"silver")
	)
