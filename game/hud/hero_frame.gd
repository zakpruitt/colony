class_name HeroFrame
extends HudPanel
## One hero's frame along the bottom of the HUD (spec 011, R1 and R2): a 16x16 class icon, the
## class name, the level, a health bar and an XP bar toward the next level, all on the frame's
## own dark panel. The bars ease to new values; a hit flashes the frame; a dead hero's frame is
## dimmed with a skull for an icon; a level-up pulses the level and restarts the XP bar.
##
## Spec 037 R4: a [ShopMarker] inside the frame's top-right corner (clear of the ticker's strip
## above), with the level moved left of it, counts what the hero has for the player to do: its
## unspent talent and paragon points (spec 051, spec 055), and the microskills learned since the
## hero's Skills page was last open. It follows the same rules as the hero window's tab tags
## (spec 034).

## Clicking the frame opens or closes this hero's window (spec 026, spec 060).
signal clicked(hero_id: int)

const SIZE: Vector2 = Vector2(142, 34)
## Seconds a bar takes to ease to a new value.
const EASE_SECONDS: float = 0.3
## Seconds a hit flashes the frame.
const FLASH_SECONDS: float = 0.12
## Seconds the level number pulses after a level-up.
const PULSE_SECONDS: float = 0.8
## The health bar is green above this fraction, yellow down to [constant RED_BELOW], red below.
const GREEN_ABOVE: float = 0.5
const RED_BELOW: float = 0.25

## The darker row under each health colour.
const SHADES: Dictionary[StringName, StringName] = {
	&"green": &"forest",
	&"yellow": &"amber",
	&"red": &"crimson",
}

const ICON_BOX: Rect2 = Rect2(4, 7, 20, 20)
const HEALTH_BAR: Rect2 = Rect2(28, 14, 110, 8)
const XP_BAR: Rect2 = Rect2(28, 24, 110, 5)
const TEXT_Y: float = 3.0
## The marker's top, and the pixels between it and the level left of it.
const MARKER_Y: float = 2.0
const MARKER_GAP: float = 2.0
## What a click on the frame does, the end of its tooltip.
const CLICK_TIP: String = "Click for details"

var hero_id: int
var icon: TextureRect
var name_label: Label
var level_label: Label
## True while the party is being revived after a wipe: set by the HUD before [method refresh].
var recovering: bool = false
## True while this hero's window is open (spec 026, spec 060): the frame's edge is drawn in yellow.
var marked: bool = false
## The hero's fighter in the battle under way, or null outside a fight: set by the HUD before
## [method refresh] (spec 030 R1).
var fighter: Combatant
## The party's gold: set by the HUD before [method refresh]. Nothing on the frame reads it since
## spec 051 took the price off training.
var gold: int = 0
## The marker saying this hero has something for the player to do (spec 037 R4).
var marker: ShopMarker
## The statuses the hero bears in a fight (spec 056 R5).
var status_icons: StatusIcons

var _hud: Hud
## The hero, as last refreshed.
var _hero: Hero
var _class_id: StringName
var _icon_part: StringName = &""
var _dead: bool = false
var _flash: float = 0.0
var _pulse: float = 0.0
var _level: int = 0
var _health: EasedValue = EasedValue.new(EASE_SECONDS)
var _xp: EasedValue = EasedValue.new(EASE_SECONDS)
## How many microskills the hero had when their Skills page was last open (or when the frame was
## made), as the hero window counts them.
var _skills_seen: int = 0


## A frame for [param hero], drawing its icons from [param hud].
func _init(hero: Hero, hud: Hud) -> void:
	super()
	hero_id = hero.id
	_hero = hero
	_hud = hud
	_class_id = hero.class_id
	name = "Frame%d" % hero.id
	size = SIZE
	var box := HudPanel.new()
	box.name = "IconBox"
	box.position = ICON_BOX.position
	box.size = ICON_BOX.size
	box.fill = Palette.color(&"ink")
	box.bevel = Palette.color(&"ink")
	box.border = Palette.color(&"dusk")
	add_child(box)
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.position = Vector2(2, 2)
	icon.size = Vector2(16, 16)
	box.add_child(icon)
	name_label = PixelText.label(hero.def().display_name, &"white")
	name_label.name = "Name"
	name_label.position = Vector2(HEALTH_BAR.position.x, TEXT_Y)
	add_child(name_label)
	level_label = PixelText.label("", &"yellow")
	level_label.name = "Level"
	add_child(level_label)
	marker = ShopMarker.new()
	marker.name = "Marker"
	marker.visible = false
	add_child(marker)
	status_icons = StatusIcons.new()
	add_child(status_icons)
	_skills_seen = hero.microskills().size()
	_health.snap(_health_fraction(hero))
	_xp.snap(xp_progress(hero))
	refresh(hero, 0.0)


## The hero's progress from its level toward the next, from 0 to 1.
static func xp_progress(hero: Hero) -> float:
	var floor_xp: int = Hero.xp_for_level(hero.level)
	var next_xp: int = Hero.xp_for_level(hero.level + 1)
	return clampf(float(hero.xp - floor_xp) / float(maxi(next_xp - floor_xp, 1)), 0.0, 1.0)


## Brings the frame up to date with [param hero] and advances its animations by [param delta].
## During a fight the health and death are [member fighter]'s (spec 030 R1), else the hero's own.
func refresh(hero: Hero, delta: float) -> void:
	_hero = hero
	_flash = maxf(_flash - delta, 0.0)
	_pulse = maxf(_pulse - delta, 0.0)
	var health: float = _health_fraction(hero)
	_dead = not hero.is_alive()
	if fighter != null:
		health = clampf(float(fighter.health) / float(maxi(fighter.max_health, 1)), 0.0, 1.0)
		_dead = not fighter.is_alive()
	_health.advance(health, delta)
	_xp.advance(xp_progress(hero), delta)
	var part: StringName = &"skull" if _dead else _class_id
	if part != _icon_part:
		_icon_part = part
		icon.texture = _hud.icon(part)
	_level = hero.level
	# Spec 027 R4: where the level was, "Down" for a fallen hero, "Recovering" during a revival.
	var level_text: String = "Lv %d" % _level
	if recovering:
		level_text = "Recovering"
	elif _dead:
		level_text = "Down"
	if level_label.text != level_text:
		level_label.text = level_text
		level_label.reset_size()
	_refresh_marker(hero, delta)
	_refresh_statuses()
	var right: float = HEALTH_BAR.end.x - level_label.size.x
	if marker.visible:
		right = marker.position.x - MARKER_GAP - level_label.size.x
	var lift: float = 1.0 if _pulse > 0.0 else 0.0
	level_label.position = Vector2(right, TEXT_Y - lift)
	var level_colour: StringName = &"yellow"
	if _pulse > 0.0 and int(_pulse / 0.1) % 2 == 0:
		level_colour = &"white"
	if recovering:
		level_colour = &"pink"
	elif _dead:
		level_colour = &"red"
	level_label.add_theme_color_override(&"font_color", Palette.color(level_colour))
	name_label.add_theme_color_override(
		&"font_color", Palette.color(&"slate" if _dead else &"white")
	)
	icon.self_modulate = Color.WHITE
	if _flash > 0.0:
		fill = Palette.color(&"crimson")
		bevel = Palette.color(&"red")
		border = Palette.color(&"white")
	elif _dead:
		fill = Palette.color(&"ink")
		bevel = Palette.color(&"night")
		border = Palette.color(&"ink")
	else:
		fill = Palette.color(&"night")
		bevel = Palette.color(&"dusk")
		border = Palette.color(&"ink")
	_apply_mark()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(hero_id)
		accept_event()


## Makes the frame clickable, and edges it in yellow while [member marked] (the hero's window is
## open); a hit's flash still shows. Called by [method refresh].
func _apply_mark() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if marked and _flash <= 0.0:
		border = Palette.color(&"yellow")
		bevel = Palette.color(&"amber")


## Brings [member marker] up to date with [param hero] (marking the microskills its open Skills
## tab shows as seen, as the window does), pins it in the top-right corner and runs its pulse on by
## [param delta] seconds.
func _refresh_marker(hero: Hero, delta: float) -> void:
	var learned: int = hero.microskills().size()
	var windows: HeroWindows = _hud.hero_windows if _hud != null else null
	var shown: HeroWindow = windows.window_of(hero_id) if windows != null else null
	if shown != null and shown.is_open() and shown.page() == HeroWindow.Page.SKILLS:
		_skills_seen = learned
	marker.count = HeroWindow.unspent(hero) + maxi(learned - _skills_seen, 0)
	marker.visible = marker.count > 0
	marker.advance(delta)
	marker.position = Vector2(HEALTH_BAR.end.x - marker.size.x, MARKER_Y)


## Spec 056 R5: the hero's statuses right of its name, and the frame's own tooltip line.
func _refresh_statuses() -> void:
	var tally: TallyPanel = _hud.tally if _hud != null else null
	var statuses: Array[ShownStatus] = []
	if tally != null and not _dead:
		statuses = tally.tally.credit.statuses.statuses_of(hero_id)
	status_icons.show_statuses(statuses)
	status_icons.position = Vector2(name_label.position.x + name_label.size.x + 3.0, TEXT_Y + 1.0)


## The frame's tooltip, as [method HeroWindows.frame_tip] builds it: the class and its path (spec
## 055), the hero's statuses with the seconds each has left (spec 056), then what a click does.
func tip() -> String:
	var tally: TallyPanel = _hud.tally if _hud != null else null
	var line: String = tally.status_line(hero_id) if tally != null and not _dead else ""
	return HeroWindows.frame_tip(_hero, line)


## The hero was hit: flash the frame for an instant.
func hit() -> void:
	_flash = FLASH_SECONDS


## The hero levelled up: pulse the level number and restart the XP bar from empty.
func level_up() -> void:
	_pulse = PULSE_SECONDS
	_xp.snap(0.0)


## The part of the icon sheet shown: the hero's class, or [code]skull[/code] while dead.
func icon_part() -> StringName:
	return _icon_part


## The health bar's fraction as drawn this frame.
func shown_health() -> float:
	return _health.value


## The health bar's colour: green above half, yellow from a quarter to half, red below.
func health_color() -> Color:
	return Palette.color(_health_colour_name(_health.value))


## The XP bar's fraction as drawn this frame.
func shown_xp() -> float:
	return _xp.value


## Seconds of hit flash left; 0 when not flashing.
func flash() -> float:
	return _flash


## True while the hero is dead.
func is_dimmed() -> bool:
	return _dead


## Seconds of level pulse left; 0 when not pulsing.
func level_pulse() -> float:
	return _pulse


func _draw() -> void:
	super()
	var empty: Color = Palette.color(&"ink")
	if _dead:
		HudPanel.draw_bar(self, HEALTH_BAR, 0.0, empty, empty, Palette.color(&"night"))
		HudPanel.draw_bar(self, XP_BAR, 0.0, empty, empty, Palette.color(&"night"))
		return
	var colour: StringName = _health_colour_name(_health.value)
	var shade: StringName = SHADES[colour]
	HudPanel.draw_bar(
		self,
		HEALTH_BAR,
		_health.value,
		Palette.color(colour),
		Palette.color(shade),
		Palette.color(&"dark_brown")
	)
	HudPanel.draw_bar(
		self, XP_BAR, _xp.value, Palette.color(&"cyan"), Palette.color(&"blue"), empty
	)


static func _health_colour_name(fraction: float) -> StringName:
	if fraction > GREEN_ABOVE:
		return &"green"
	if fraction >= RED_BELOW:
		return &"yellow"
	return &"red"


static func _health_fraction(hero: Hero) -> float:
	return clampf(float(hero.health) / float(maxi(hero.max_health(), 1)), 0.0, 1.0)
