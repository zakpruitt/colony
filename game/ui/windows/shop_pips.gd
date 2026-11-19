class_name ShopPips
extends Control
## An upgrade's ranks as pips (spec 065 R3), under its name on its shop card: one pip per rank in
## one line, filled for each rank bought, every fifth pip larger so the ranks can be counted at a
## glance. The pip of a rank just bought fills with a flash ([method flash_pip]).
##
## Drawn here in code from the palette: a filled pip yellow in an amber edge, an empty one a dark
## hole in a slate edge; the flashing pip is white, then yellow, inside a white ring. Its width
## is what [method width_for] gives for its count.

## Seconds a pip flashes after its rank is bought.
const FLASH_SECONDS: float = 0.5
## A pip's side in UI pixels, small and every fifth, and the gap between pips.
const SMALL: int = 4
const LARGE: int = 6
const GAP: int = 2

var _count: int = 0
var _filled: int = 0
var _flash_index: int = -1
var _flash: float = 0.0


func _init() -> void:
	name = "Pips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, LARGE)


## The width [param pips] pips take in one line, in UI pixels.
static func width_for(pips: int) -> int:
	if pips <= 0:
		return 0
	var large: int = floori(pips / 5.0)
	return (pips - large) * SMALL + large * LARGE + (pips - 1) * GAP


## Shows [param filled] of [param count] pips filled.
func show_ranks(filled_ranks: int, count_of: int) -> void:
	if filled_ranks == _filled and count_of == _count:
		return
	_filled = filled_ranks
	_count = count_of
	custom_minimum_size = Vector2(width_for(_count), LARGE)
	queue_redraw()


## How many pips there are: the upgrade's top rank.
func count() -> int:
	return _count


## How many pips are filled: the ranks bought.
func filled() -> int:
	return _filled


## True when pip [param index] (0-based) is filled.
func is_filled(index: int) -> bool:
	return index >= 0 and index < _filled


## True when pip [param index] (0-based) is a fifth pip, drawn larger.
func is_large(index: int) -> bool:
	return (index + 1) % 5 == 0


## Pip [param index]'s box, in global (canvas) coordinates, as [method Control.get_global_rect].
func pip_rect(index: int) -> Rect2:
	return get_global_transform() * _local_rect(index)


## Starts pip [param index] (0-based) flashing: its rank was just bought.
func flash_pip(index: int) -> void:
	_flash_index = index
	_flash = FLASH_SECONDS
	queue_redraw()


## The pip flashing now, or -1 when none is.
func flashing() -> int:
	return _flash_index if _flash > 0.0 else -1


## Seconds of the flash left; 0 when still.
func flash_left() -> float:
	return _flash


## Stops the flash at once (the world caught up).
func stop_flash() -> void:
	if _flash > 0.0:
		_flash = 0.0
		queue_redraw()


## Runs the flash down by [param delta] seconds.
func advance(delta: float) -> void:
	if _flash <= 0.0:
		return
	var was_bright: bool = _flash > FLASH_SECONDS / 2.0
	_flash = maxf(_flash - delta, 0.0)
	if _flash == 0.0 or was_bright != (_flash > FLASH_SECONDS / 2.0):
		queue_redraw()


func _local_rect(index: int) -> Rect2:
	var x: int = 0
	for i: int in index:
		x += (LARGE if is_large(i) else SMALL) + GAP
	var side: int = LARGE if is_large(index) else SMALL
	return Rect2(Vector2(x, floorf((LARGE - side) / 2.0)), Vector2(side, side))


func _draw() -> void:
	var flashing_now: int = flashing()
	for i: int in _count:
		var box: Rect2 = _local_rect(i)
		if i == flashing_now:
			draw_rect(box.grow(1.0), Palette.color(&"white"))
			var bright: bool = _flash > FLASH_SECONDS / 2.0
			draw_rect(box, Palette.color(&"white" if bright else &"yellow"))
			continue
		var inner: Rect2 = box.grow(-1.0)
		if is_filled(i):
			draw_rect(box, Palette.color(&"amber"))
			draw_rect(inner, Palette.color(&"yellow"))
		else:
			draw_rect(box, Palette.color(&"slate"))
			draw_rect(inner, Palette.color(&"ink"))
