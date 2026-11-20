class_name StatusIcons
extends Control
## Up to three small status marks on a hero frame, the statuses the hero bears now in
## [enum AbilityEffect.Status] order, from the tally's [StatusBook]; and the line naming every one
## of them with the seconds it has left, for the frame's tooltip.

## The most marks shown, their size and the pixels between two.
const MOST: int = 3
const MARK: float = 7.0
const GAP: float = 1.0

## The statuses shown now, at most [constant MOST].
var kinds: Array[int] = []


func _init() -> void:
	name = "StatusIcons"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(MOST * MARK + (MOST - 1) * GAP, MARK)


## Shows the first [constant MOST] of [param statuses]; the same marks as shown change nothing.
func show_statuses(statuses: Array[ShownStatus]) -> void:
	var count: int = mini(statuses.size(), MOST)
	var same: bool = count == kinds.size()
	for i: int in count:
		if same and kinds[i] != statuses[i].kind:
			same = false
	if same:
		return
	kinds.clear()
	for i: int in count:
		kinds.append(statuses[i].kind)
	queue_redraw()


## Every one of [param statuses] with the whole seconds it has left at simulation tick
## [param now]: "Shielded 6 s, Hasted 9 s"; empty for none.
static func describe(statuses: Array[ShownStatus], now: int) -> String:
	var parts: PackedStringArray = []
	for status: ShownStatus in statuses:
		var left: int = ceili(float(maxi(status.end_tick - now, 0)) / Simulation.TICKS_PER_SECOND)
		parts.append("%s %d s" % [ShownStatus.status_name(status.kind), left])
	return ", ".join(parts)


func _draw() -> void:
	var x: float = 0.0
	for kind: int in kinds:
		var texture: Texture2D = StatusMarks.icon(kind)
		if texture != null:
			draw_texture(texture, Vector2(x, 0))
		x += MARK + GAP
