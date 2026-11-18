class_name HeroFrameView
extends Control
## One hero's frame along the bottom of the screen (spec 011 R1 and R2, spec 061 R5), on the sharp
## layer: the class portrait, the class in bold, the level, the health bar with its number on it
## ([code]34 / 40[/code]), the XP bar toward the next level, up to three status marks (spec 056 R5)
## and the tag counting what the hero has for the player to do (spec 037 R4). The bars ease to new
## values; a hit flashes the frame; a dead hero's frame is dimmed with a skull for a portrait and
## [code]Down[/code] for a level, [code]Recovering[/code] during a revival (spec 027 R4); a
## level-up pulses the level and restarts the XP bar. Its edge is yellow while the hero's window
## is open, and a click opens or closes that window (spec 060).
##
## The tag counts the hero's unspent talent and paragon points (spec 051, spec 055) and the
## microskills learned since the hero's Skills tab was last open, as the hero window's tab tags do
## (spec 034).

## Clicking the frame opens or closes this hero's window (spec 026, spec 060).
signal clicked(hero_id: int)

## The frame's size in UI pixels.
const SIZE: Vector2 = Vector2(214, 48)
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
## The portrait's box, the portrait in it (its 16x16 art at its own size, so that the hero
## window's portrait is twice the frame's, spec 026 R2), and the bars.
const ICON_BOX: Rect2 = Rect2(5, 14, 20, 20)
const ICON_SIZE: Vector2 = Vector2(16, 16)
const HEALTH_BAR: Rect2 = Rect2(31, 18, 177, UiText.LINE_HEIGHT + 2)
const XP_BAR: Rect2 = Rect2(31, 36, 177, 6)
## The top of the name's row, and the pixels between the tag and the level left of it.
const TEXT_Y: float = 3.0
const MARKER_GAP: float = 3.0
## The status marks' scale: their pixel art drawn at a whole multiple.
const MARK_SCALE: float = 2.0
## What a click on the frame does, the end of its tooltip.
const CLICK_TIP: String = "Click for details"

var hero_id: int
var icon: TextureRect
var name_label: Label
var level_label: Label
## The hero's health as a number, on the health bar.
var health_label: Label
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
## The tag saying this hero has something for the player to do (spec 037 R4).
var marker: UiBadge
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
var _health: EasedValue = EasedValue.new(EASE_SECONDS)
var _xp: EasedValue = EasedValue.new(EASE_SECONDS)
## How many microskills the hero had when their Skills page was last open (or when the frame was
## made), as the hero window counts them.
var _skills_seen: int = 0


## A frame for [param hero], drawing its portraits from [param hud].
func _init(hero: Hero, hud: Hud) -> void:
	hero_id = hero.id
	_hero = hero
	_hud = hud
	_class_id = hero.class_id
	name = "Frame%d" % hero.id
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = ICON_BOX.position + (ICON_BOX.size - ICON_SIZE) / 2.0
	icon.size = ICON_SIZE
	add_child(icon)
	name_label = UiText.label(hero.def().display_name, &"white", true)
	name_label.name = "Name"
	name_label.position = Vector2(HEALTH_BAR.position.x, TEXT_Y)
	add_child(name_label)
	level_label = UiText.label("", &"yellow", true)
	level_label.name = "Level"
	add_child(level_label)
	health_label = UiText.label("", &"white", true)
	health_label.name = "Health"
	health_label.add_theme_color_override(&"font_shadow_color", Palette.color(&"ink"))
	health_label.add_theme_constant_override(&"shadow_offset_x", 1)
	health_label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(health_label)
	status_icons = StatusIcons.new()
	status_icons.scale = Vector2.ONE * MARK_SCALE
	add_child(status_icons)
	marker = UiBadge.new()
	marker.name = "Marker"
	add_child(marker)
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
	var points: Vector2i = Vector2i(hero.health, hero.max_health())
	_dead = not hero.is_alive()
	if fighter != null:
		health = clampf(float(fighter.health) / float(maxi(fighter.max_health, 1)), 0.0, 1.0)
		points = Vector2i(fighter.health, fighter.max_health)
		_dead = not fighter.is_alive()
	_health.advance(health, delta)
	_xp.advance(xp_progress(hero), delta)
	var part: StringName = &"skull" if _dead else _class_id
	if part != _icon_part:
		_icon_part = part
		icon.texture = _hud.icon(part) if _hud != null else null
	# Spec 027 R4: where the level was, "Down" for a fallen hero, "Recovering" during a revival.
	var level_text: String = "Lv %d" % hero.level
	if recovering:
		level_text = "Recovering"
	elif _dead:
		level_text = "Down"
	_set_text(level_label, level_text)
	var number: String = (
		"%s / %s" % [Hud.group_thousands(maxi(points.x, 0)), Hud.group_thousands(maxi(points.y, 1))]
	)
	_set_text(health_label, "" if _dead else number)
	_refresh_marker(hero, delta)
	_refresh_statuses()
	_lay_out()
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
	queue_redraw()


## The bars show the hero's health and XP at once, and a flash or pulse ends: after a stall, when
## what happened is long over (spec 061 R9).
func snap() -> void:
	_flash = 0.0
	_pulse = 0.0
	var health: float = _health_fraction(_hero)
	if fighter != null:
		health = clampf(float(fighter.health) / float(maxi(fighter.max_health, 1)), 0.0, 1.0)
	_health.snap(health)
	_xp.snap(xp_progress(_hero))
	refresh(_hero, 0.0)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(hero_id)
		accept_event()


## The frame's tooltip, as [method HeroWindows.frame_tip] builds it: the class and its path (spec
## 055), the hero's statuses with the seconds each has left (spec 056), then what a click does.
func tip() -> String:
	var tally: TallyPanel = _hud.tally if _hud != null else null
	var line: String = tally.status_line(hero_id) if tally != null and not _dead else ""
	return HeroWindows.frame_tip(_hero, line)


## The frame's tooltip title: the hero's class and level.
func tip_title() -> String:
	return "%s, level %d" % [_hero.def().display_name, _hero.level]


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


## Brings [member marker] up to date with [param hero] (marking the microskills its open Skills
## tab shows as seen, as the window does) and runs its pulse on by [param delta] seconds.
func _refresh_marker(hero: Hero, delta: float) -> void:
	var learned: int = hero.microskills().size()
	var windows: HeroWindows = _hud.hero_windows if _hud != null else null
	var shown: HeroWindow = windows.window_of(hero_id) if windows != null else null
	if shown != null and shown.is_open() and shown.page() == HeroWindow.Page.SKILLS:
		_skills_seen = learned
	marker.count = HeroWindow.unspent(hero) + maxi(learned - _skills_seen, 0)
	marker.visible = marker.count > 0
	marker.advance(delta)


## Spec 056 R5: the hero's statuses, as the tally's book has them.
func _refresh_statuses() -> void:
	var tally: TallyPanel = _hud.tally if _hud != null else null
	var statuses: Array[ShownStatus] = []
	if tally != null and not _dead:
		statuses = tally.tally.credit.statuses.statuses_of(hero_id)
	status_icons.show_statuses(statuses)


## The name and its status marks at the left of the top row, the tag at its right and the level
## left of the tag; the number in the middle of the health bar.
func _lay_out() -> void:
	var right: float = HEALTH_BAR.end.x
	if marker.visible:
		marker.position = Vector2(right - marker.size.x, TEXT_Y - 1.0)
		right = marker.position.x - MARKER_GAP
	var lift: float = 1.0 if _pulse > 0.0 else 0.0
	level_label.position = Vector2(right - _ink(level_label), TEXT_Y - lift)
	var marks_x: float = name_label.position.x + _ink(name_label) + 4.0
	status_icons.position = Vector2(marks_x, TEXT_Y + 2.0)
	health_label.position = Vector2(
		floorf(HEALTH_BAR.get_center().x - _ink(health_label) / 2.0), HEALTH_BAR.position.y + 1.0
	)


## The colour of the frame's edge now: white in a hit's flash, yellow while the hero's window is
## open, else dim.
func edge_colour() -> Color:
	if _flash > 0.0:
		return Palette.color(&"white")
	if marked:
		return Palette.color(&"yellow")
	return Palette.color(&"dusk" if _dead else &"slate")


## The frame's fill now: crimson in a hit's flash, ink for a fallen hero, else night.
func fill_colour() -> Color:
	if _flash > 0.0:
		return Palette.color(&"crimson")
	return Palette.color(&"ink" if _dead else &"night")


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, edge_colour())
	draw_rect(rect.grow(-1.0), fill_colour())
	if marked and _flash <= 0.0:
		draw_rect(rect.grow(-1.0), Palette.color(&"amber"), false, 1.0)
	draw_rect(ICON_BOX, Palette.color(&"dusk"))
	draw_rect(ICON_BOX.grow(-1.0), Palette.color(&"ink"))
	var empty: Color = Palette.color(&"ink")
	if _dead:
		HudPanel.draw_bar(self, HEALTH_BAR, 0.0, empty, empty, Palette.color(&"night"))
		HudPanel.draw_bar(self, XP_BAR, 0.0, empty, empty, Palette.color(&"night"))
		return
	var colour: StringName = _health_colour_name(_health.value)
	HudPanel.draw_bar(
		self,
		HEALTH_BAR,
		_health.value,
		Palette.color(colour),
		Palette.color(SHADES[colour]),
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


static func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
		label.reset_size()


static func _ink(label: Label) -> float:
	return maxf(UiText.width(label.text, true) - UiText.SPACING, 0.0)
