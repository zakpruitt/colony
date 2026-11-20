class_name BossBarView
extends Panel
## The guardian's health for the whole of a guardian fight, on the sharp
## layer at the top centre: its name in bold capitals over a wide bar with its health as a number
## on it ([code]1,234 / 2,000[/code]).
##
## It reads the fight from [member Expedition.battle]: it shows while the battle has a guardian
## in it and hides as soon as there is none (won, wiped, or anything else). The bar eases toward
## the guardian's health, a trail of lost health drains after it, and it flashes white for a moment
## on each recent hit. It moves only in [method advance], so a test can step it exactly; the
## [Hud] places it.

## The widest the panel grows, in UI pixels, and as a share of the room's width (so that, beside
## the place panel and the countdown, it can still sit near the centre at 960x540).
const MAX_WIDTH: float = 360.0
const ROOM_SHARE: float = 0.28
## UI pixels inside the panel's edge; the name's top; the bar's top and height (a line of text
## and its edge).
const PAD: float = 6.0
const NAME_Y: float = 3.0
const BAR_Y: float = 18.0
const BAR_HEIGHT: float = UiText.LINE_HEIGHT + 4.0
## Seconds the bar takes to ease to a new health, and the trail of lost health behind it.
const EASE_SECONDS: float = 0.25
const TRAIL_SECONDS: float = 0.7
## Seconds the bar flashes white after a hit.
const FLASH_SECONDS: float = 0.08

var name_label: Label
## The guardian's health as a number, on the bar.
var health_label: Label

var _simulation: Simulation
var _world: World
var _guardian_id: int = -1
var _shown := EasedValue.new(EASE_SECONDS)
var _trail := EasedValue.new(TRAIL_SECONDS)
var _flash: float = 0.0


func _init() -> void:
	name = "BossBar"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP  # a click here goes no further (to the world)
	visible = false
	size = Vector2(MAX_WIDTH, 40)
	name_label = UiText.label("", &"white", true)
	name_label.name = "Name"
	add_child(name_label)
	health_label = UiText.label("", &"white", true)
	health_label.name = "Health"
	add_child(health_label)


## Call once, before the first advance.
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)


## Follows the fight and moves the bar on by [param delta] seconds.
func advance(delta: float) -> void:
	var guardian: Combatant = _guardian()
	if guardian == null:
		_guardian_id = -1
		visible = false
		return
	var fraction: float = clampf(float(guardian.health) / maxf(guardian.max_health, 1.0), 0.0, 1.0)
	if guardian.id != _guardian_id:
		_guardian_id = guardian.id
		_shown.snap(fraction)
		_trail.snap(fraction)
		_flash = 0.0
		var def: MonsterDef = Content.monster(guardian.def_id)
		name_label.text = def.display_name.to_upper() if def != null else ""
		name_label.reset_size()
	_shown.advance(fraction, delta)
	_trail.advance(fraction, delta)
	_flash = maxf(_flash - delta, 0.0)
	var number: String = (
		"%s / %s"
		% [Hud.group_thousands(maxi(guardian.health, 0)), Hud.group_thousands(guardian.max_health)]
	)
	if health_label.text != number:
		health_label.text = number
		health_label.reset_size()
	visible = true
	queue_redraw()


## The bar and its trail show the guardian's health at once, and a flash ends (after a stall).
func snap() -> void:
	var guardian: Combatant = _guardian()
	if guardian == null:
		return
	var fraction: float = clampf(float(guardian.health) / maxf(guardian.max_health, 1.0), 0.0, 1.0)
	_shown.snap(fraction)
	_trail.snap(fraction)
	_flash = 0.0
	queue_redraw()


## Puts the panel at [param at], [param width] wide and [param height] tall, its name and number
## centred.
func place(at: Vector2, width: float, height: float) -> void:
	position = at
	size = Vector2(width, height)
	name_label.position = Vector2(floorf((width - WindowText.ink(name_label)) / 2.0), NAME_Y)
	var bar: Rect2 = bar_rect()
	health_label.position = Vector2(
		floorf(bar.get_center().x - WindowText.ink(health_label) / 2.0), bar.position.y + 2.0
	)


## Where the bar is drawn, in the panel.
func bar_rect() -> Rect2:
	return Rect2(PAD, BAR_Y, size.x - PAD * 2.0, BAR_HEIGHT)


## True while the bar is on screen.
func is_showing() -> bool:
	return visible


## The eased health fraction on screen, 0 to 1.
func shown_fraction() -> float:
	return _shown.value


## The guardian's name as shown.
func shown_name() -> String:
	return name_label.text


## True while the bar flashes from a hit.
func is_flashing() -> bool:
	return _flash > 0.0


## The guardian in the fight, or null when there is no guardian fight.
func _guardian() -> Combatant:
	return CombatEffects.battle_guardian(_simulation)


func _draw() -> void:
	var bar: Rect2 = bar_rect()
	# Lost health first, in amber, draining after the bar; then the health itself.
	UiBar.draw_bar(
		self,
		bar,
		_trail.value,
		Palette.color(&"amber"),
		Palette.color(&"orange"),
		Palette.color(&"ink")
	)
	var inner: Rect2 = bar.grow(-1.0)
	var filled: float = roundf(inner.size.x * clampf(_shown.value, 0.0, 1.0))
	if filled <= 0.0:
		return
	var colour: Color = Palette.color(&"white") if _flash > 0.0 else Palette.color(&"red")
	var shade: Color = Palette.color(&"silver") if _flash > 0.0 else Palette.color(&"crimson")
	draw_rect(Rect2(inner.position, Vector2(filled, inner.size.y)), colour)
	draw_rect(Rect2(inner.position, Vector2(filled, 1)), Palette.color(&"pink"))
	var bottom: Vector2 = inner.position + Vector2(0, inner.size.y - 1)
	draw_rect(Rect2(bottom, Vector2(filled, 1)), shade)


func _on_sim_event(event: SimEvent) -> void:
	if event.kind != SimEvent.Kind.HIT or event.target_id != _guardian_id or _guardian_id < 0:
		return
	if _world != null and not _world.may_animate(event):
		return
	_flash = FLASH_SECONDS
