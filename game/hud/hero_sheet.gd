class_name HeroSheet
extends Control
## One hero's sheet (spec 026): who the hero is, how they stand, what they can do and what they
## are doing now, in plain words. It drops from under the HUD's top band at the left, opposite the
## shop, and never reaches the party frames or the strip just above them. Clicking a hero's frame
## or pressing Tab opens it; it never pauses the game. Every value is read from the simulation on
## each [method advance], so nothing goes stale across a level up, an upgrade or a loaded save.
## Drawn as a [HudPanel] is, in the shop's look.

## Emitted when the sheet opens, closes or switches hero.
signal shown_changed

## The panel's size in pixels.
const SIZE: Vector2 = Vector2(232, 149)
## Space inside the border.
const PADDING: float = 4.0
## Pixels between the panel and the top band above it.
const DROP: float = 2.0
## The portrait's box (a frame's [constant HeroFrame.ICON_BOX] at twice the size) and the
## left edge of the text beside it.
const PORTRAIT_BOX: Rect2 = Rect2(6, 6, 36, 36)
const HEADER_X: float = 48.0
## The left and right edges of the sections under the header.
const BODY_LEFT: float = 8.0
const BODY_RIGHT: float = SIZE.x - 8.0
## The two bars.
const HEALTH_BAR: Rect2 = Rect2(BODY_LEFT, 59, BODY_RIGHT - BODY_LEFT, 7)
const XP_BAR: Rect2 = Rect2(BODY_LEFT, 79, BODY_RIGHT - BODY_LEFT, 5)
## The stat block: where it starts, a row's height, and where its second column starts.
const STATS_Y: float = 92.0
const STAT_ROW: float = 10.0
const STATS_SECOND_X: float = 124.0
## Pixels between a stat's name and its value, and between the value and its bonus.
const STAT_GAP: float = 6.0
const BONUS_GAP: float = 4.0
## The role of each class, in one word.
const ROLE_WORDS: Dictionary[HeroClassDef.Role, String] = {
	HeroClassDef.Role.TANK: "Tank",
	HeroClassDef.Role.MELEE: "Striker",
	HeroClassDef.Role.RANGED: "Caster",
	HeroClassDef.Role.HEALER: "Healer",
}
## What a hero is doing in each expedition state (fighting is worked out from the battle).
const DOING_WORDS: Dictionary[Expedition.State, String] = {
	Expedition.State.TRAVELLING: "Walking",
	Expedition.State.RESTING: "Resting",
	Expedition.State.CLIMBING: "Climbing",
	Expedition.State.REVIVING: "Recovering",
}
## The colour of each activity, matching the HUD's state word.
const DOING_COLOURS: Dictionary[String, StringName] = {
	"Walking": &"silver",
	"Fighting": &"orange",
	"Healing": &"green",
	"Resting": &"green",
	"Climbing": &"tan",
	"Recovering": &"pink",
	"Down": &"red",
}
## The stat block: each stat's key and label, in two columns.
const FIRST_COLUMN: Array[StringName] = [
	&"stat_health", &"stat_damage", &"stat_armor", &"stat_healing"
]
const SECOND_COLUMN: Array[StringName] = [&"stat_attack_speed", &"stat_crit", &"stat_range"]
const STAT_NAMES: Dictionary[StringName, String] = {
	&"stat_health": "Health",
	&"stat_damage": "Damage",
	&"stat_armor": "Armor",
	&"stat_healing": "Healing",
	&"stat_attack_speed": "Attack speed",
	&"stat_crit": "Crit chance",
	&"stat_range": "Range",
}

## The close button at the top right.
var close_button: HudButton
## The hero's class portrait at twice a frame's size; a skull while the hero is down.
var portrait: TextureRect

var _simulation: Simulation
var _icons: PixelSheet
var _hero_id: int = -1
## The labels of the sheet's lines, by the key [method line] takes.
var _values: Dictionary[StringName, Label] = {}
## Each stat's name label and bonus label, by key.
var _names: Dictionary[StringName, Label] = {}
var _bonuses: Dictionary[StringName, Label] = {}
var _health: EasedValue = EasedValue.new(HeroFrame.EASE_SECONDS)
var _xp: EasedValue = EasedValue.new(HeroFrame.EASE_SECONDS)
var _health_goal: float = 0.0
var _xp_goal: float = 0.0
var _down: bool = false


func _init() -> void:
	name = "HeroSheet"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	size = SIZE
	position = Vector2(Hud.MARGIN, Hud.TOP_BAND + DROP)


func _draw() -> void:
	var night: Color = Palette.color(&"night")
	var dusk: Color = Palette.color(&"dusk")
	var ink: Color = Palette.color(&"ink")
	HudPanel.draw_panel(self, Rect2(Vector2.ZERO, size), night, dusk, ink)
	HudPanel.draw_panel(self, PORTRAIT_BOX, ink, ink, dusk)
	for y: float in [PORTRAIT_BOX.end.y + 4.0, STATS_Y - 4.0, SIZE.y - 15.0]:
		draw_rect(Rect2(BODY_LEFT, y, BODY_RIGHT - BODY_LEFT, 1), dusk)
	var health_colour: StringName = &"red" if _down else _health_colour(_health.value)
	HudPanel.draw_bar(
		self,
		HEALTH_BAR,
		_health.value,
		Palette.color(health_colour),
		Palette.color(HeroFrame.SHADES[health_colour]),
		Palette.color(&"dark_brown")
	)
	HudPanel.draw_bar(self, XP_BAR, _xp.value, Palette.color(&"cyan"), Palette.color(&"blue"), ink)


## Call once, before the first advance. [param world] may be null.
func setup(simulation: Simulation, _world: World) -> void:
	_simulation = simulation
	_icons = PixelSheet.load_sheet(Hud.ICONS_PATH)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = PORTRAIT_BOX.position + Vector2(2, 2)
	portrait.size = PORTRAIT_BOX.size - Vector2(4, 4)
	add_child(portrait)
	_add_line(&"class", "", &"white", Vector2(HEADER_X, 5))
	_make_big(_values[&"class"])
	_add_line(&"role", "", &"steel", Vector2(HEADER_X, 23))
	_add_line(&"level", "", &"yellow", Vector2(HEADER_X, 23))
	_add_line(&"activity", "", &"silver", Vector2(HEADER_X, 33))
	_caption("Health", Vector2(BODY_LEFT, 49))
	_add_line(&"health", "", &"white", Vector2(BODY_LEFT, 49))
	_caption("XP", Vector2(BODY_LEFT, 69))
	_add_line(&"xp", "", &"silver", Vector2(BODY_LEFT, 69))
	_build_stats(FIRST_COLUMN, BODY_LEFT)
	_build_stats(SECOND_COLUMN, STATS_SECOND_X)
	var hint: Label = _caption("Tab next hero   Esc close", Vector2(BODY_LEFT, SIZE.y - 12.0))
	hint.add_theme_color_override(&"font_color", Palette.color(&"slate"))
	close_button = HudButton.new("x")
	close_button.name = "Close"
	close_button.custom_minimum_size = Vector2(HudButton.HEIGHT, HudButton.HEIGHT)
	close_button.size = close_button.get_combined_minimum_size()
	close_button.position = Vector2(SIZE.x - PADDING - close_button.size.x, PADDING)
	close_button.pressed.connect(close)
	add_child(close_button)
	advance(0.0)


## Brings every line up to date with the shown hero and eases the bars. Called every frame by the
## HUD; tests call it.
func advance(delta: float) -> void:
	var hero: Hero = _shown_hero()
	if hero == null:
		return
	var fighter: Combatant = _fighter(hero)
	var health: int = fighter.health if fighter != null else hero.health
	var max_health: int = fighter.max_health if fighter != null else hero.max_health()
	_down = health <= 0 or (fighter != null and not fighter.is_alive())
	_health_goal = clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	_xp_goal = HeroFrame.xp_progress(hero)
	_health.advance(_health_goal, delta)
	_xp.advance(_xp_goal, delta)
	var def: HeroClassDef = hero.def()
	_set_line(&"class", def.display_name)
	var role: String = ROLE_WORDS.get(def.role, "")
	_set_line(&"role", role)
	_set_line(&"level", "Level %d" % hero.level)
	_set_line(&"health", "%d / %d" % [maxi(health, 0), max_health])
	var floor_xp: int = Hero.xp_for_level(hero.level)
	var next_xp: int = Hero.xp_for_level(hero.level + 1)
	_set_line(
		&"xp",
		(
			"%d / %d XP, %d to level %d"
			% [hero.xp - floor_xp, next_xp - floor_xp, next_xp - hero.xp, hero.level + 1]
		)
	)
	var doing: String = _activity(fighter)
	_set_line(&"activity", doing)
	var word: String = doing.get_slice(" ", 0)
	var colour: StringName = DOING_COLOURS.get(word, &"silver")
	_colour(_values[&"activity"], colour)
	_refresh_stats(hero)
	var part: StringName = &"skull" if _down else hero.class_id
	var texture: Texture2D = _icons.part(part) if _icons.has_part(part) else null
	if portrait.texture != texture:
		portrait.texture = texture
	_layout()
	queue_redraw()


## Shows the sheet of the hero with id [param hero_id], closing the shop if it is open.
func open(hero_id: int) -> void:
	if _simulation == null or _simulation.party.hero(hero_id) == null:
		return
	var hud: Hud = get_parent() as Hud
	if hud != null and hud.shop != null:
		hud.shop.close()
	var switched: bool = hero_id != _hero_id or not visible
	_hero_id = hero_id
	visible = true
	if switched:
		advance(0.0)
		_health.snap(_health_goal)
		_xp.snap(_xp_goal)
		queue_redraw()
		shown_changed.emit()


## Opens the sheet on the first hero if it is closed, or moves it to the next hero, wrapping.
func open_next() -> void:
	if _simulation == null or _simulation.party.heroes.is_empty():
		return
	var heroes: Array[Hero] = _simulation.party.heroes
	var index: int = -1
	if is_open():
		for i: int in heroes.size():
			if heroes[i].id == _hero_id:
				index = i
	open(heroes[(index + 1) % heroes.size()].id)


## Opens the sheet on [param hero_id], or closes it if it already shows that hero.
func toggle(hero_id: int) -> void:
	if is_open() and _hero_id == hero_id:
		close()
	else:
		open(hero_id)


## Hides the sheet.
func close() -> void:
	if not visible and _hero_id < 0:
		return
	visible = false
	_hero_id = -1
	shown_changed.emit()


## True while the sheet is shown.
func is_open() -> bool:
	return visible


## The id of the hero shown, or -1 when closed.
func shown_hero_id() -> int:
	return _hero_id if visible else -1


## The text of a line of the sheet, for tests: &"class", &"role", &"level", &"health", &"xp",
## &"activity", and one per stat: &"stat_health", &"stat_damage", &"stat_armor",
## &"stat_attack_speed", &"stat_crit", &"stat_range", &"stat_healing" ("" when the class does
## not heal).
func line(key: StringName) -> String:
	var value: Label = _values.get(key, null)
	if value == null or not value.visible:
		return ""
	if not _names.has(key):
		return value.text
	var text: String = "%s %s" % [_names[key].text, value.text]
	var bonus: Label = _bonuses[key]
	if bonus.visible and not bonus.text.is_empty():
		text += " " + bonus.text
	return text


## The fraction a bar shows this frame: &"health" or &"xp".
func bar_fraction(key: StringName) -> float:
	match key:
		&"health":
			return _health.value
		&"xp":
			return _xp.value
	return 0.0


## The colour a line's value is drawn in.
func line_colour(key: StringName) -> Color:
	var value: Label = _values.get(key, null)
	return value.get_theme_color(&"font_color") if value != null else Color.BLACK


## The colour a stat's bonus is drawn in.
func bonus_colour(key: StringName) -> Color:
	var bonus: Label = _bonuses.get(key, null)
	return bonus.get_theme_color(&"font_color") if bonus != null else Color.BLACK


# --- Reading the simulation ------------------------------------------------------


func _shown_hero() -> Hero:
	if _simulation == null or _hero_id < 0:
		return null
	return _simulation.party.hero(_hero_id)


## The hero's fighter in the battle under way, or null outside a fight.
func _fighter(hero: Hero) -> Combatant:
	var expedition: Expedition = _simulation.expedition
	if expedition.state != Expedition.State.FIGHTING or expedition.battle == null:
		return null
	return expedition.battle.combatant(hero.id)


## What the hero is doing, in words.
func _activity(fighter: Combatant) -> String:
	var expedition: Expedition = _simulation.expedition
	if expedition.state == Expedition.State.REVIVING:
		return DOING_WORDS[Expedition.State.REVIVING]
	if _down:
		return "Down"
	if expedition.state == Expedition.State.FIGHTING:
		return _fighting(fighter)
	if DOING_WORDS.has(expedition.state):
		return DOING_WORDS[expedition.state]
	return Hud.STATE_WORDS.get(expedition.state, "")


func _fighting(fighter: Combatant) -> String:
	if fighter == null or fighter.target_id < 0:
		return "Fighting"
	var target: Combatant = _simulation.expedition.battle.combatant(fighter.target_id)
	if target == null:
		return "Fighting"
	if target.team == Combatant.Team.HEROES:
		var ally: Hero = _simulation.party.hero(target.id)
		return "Healing %s" % ally.def().display_name if ally != null else "Healing"
	var monster: MonsterDef = Content.monster(target.def_id)
	return "Fighting %s" % monster.display_name if monster != null else "Fighting"


func _refresh_stats(hero: Hero) -> void:
	var def: HeroClassDef = hero.def()
	var fighter: Combatant = hero.combatant()
	var toughness: float = _multiplier(UpgradeDef.Stat.HEALTH)
	var power: float = _multiplier(UpgradeDef.Stat.DAMAGE)
	_set_stat(&"stat_health", str(hero.max_health()), toughness)
	_set_stat(&"stat_damage", str(fighter.damage), power)
	_set_stat(&"stat_armor", str(fighter.armor), 1.0)
	_set_stat(&"stat_attack_speed", "%.1f/s" % (1.0 / maxf(def.attack_interval, 0.01)), 1.0)
	_set_stat(&"stat_crit", "%d%%" % roundi(def.crit_chance * 100.0), 1.0)
	var reach: String = "Melee"
	if def.attack_range > Battle.MELEE_REACH:
		reach = "%s tiles" % HeroSheet.tiles(def.attack_range)
	_set_stat(&"stat_range", reach, 1.0)
	var heals: bool = def.heal_power > 0
	_set_stat(&"stat_healing", str(fighter.heal_power), power)
	for label: Label in [_names[&"stat_healing"], _values[&"stat_healing"]]:
		label.visible = heals
	_bonuses[&"stat_healing"].visible = heals and power > 1.0


func _multiplier(stat: UpgradeDef.Stat) -> float:
	return _simulation.upgrades.multiplier(stat)


## A distance in tiles as words: whole numbers without a decimal (7), others with one (6.5).
static func tiles(distance: float) -> String:
	if is_equal_approx(distance, roundf(distance)):
		return str(roundi(distance))
	return "%.1f" % distance


## The health bar's colour, as on a frame: green above half, yellow to a quarter, red below.
static func _health_colour(fraction: float) -> StringName:
	if fraction > HeroFrame.GREEN_ABOVE:
		return &"green"
	if fraction >= HeroFrame.RED_BELOW:
		return &"yellow"
	return &"red"


# --- Building and laying out -----------------------------------------------------


func _build_stats(keys: Array[StringName], x: float) -> void:
	var widest: int = 0
	for key: StringName in keys:
		widest = maxi(widest, PixelText.width(STAT_NAMES[key]))
	var y: float = STATS_Y
	for key: StringName in keys:
		_names[key] = _caption(STAT_NAMES[key], Vector2(x, y))
		_add_line(key, "", &"white", Vector2(x + widest + STAT_GAP, y))
		var bonus: Label = PixelText.label("", &"green")
		bonus.name = "%sBonus" % String(key).capitalize().replace(" ", "")
		bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bonus.position = Vector2(x, y)
		add_child(bonus)
		_bonuses[key] = bonus
		y += STAT_ROW


func _add_line(key: StringName, text: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.name = String(key).capitalize().replace(" ", "")
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	_values[key] = made
	return made


func _caption(text: String, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, &"steel")
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


func _make_big(label: Label) -> void:
	label.add_theme_font_size_override(&"font_size", PixelText.SIZE * 2)
	label.add_theme_constant_override(&"shadow_offset_x", PixelText.SHADOW_OFFSET * 2)
	label.add_theme_constant_override(&"shadow_offset_y", PixelText.SHADOW_OFFSET * 2)


func _set_line(key: StringName, text: String) -> void:
	var label: Label = _values[key]
	if label.text != text:
		label.text = text
		label.reset_size()


## Sets a stat's value and, when [param multiplier] is above 1, its bonus beside it.
func _set_stat(key: StringName, value: String, multiplier: float) -> void:
	_set_line(key, value)
	var bonus: Label = _bonuses[key]
	var text: String = ""
	if multiplier > 1.0:
		text = "(+%d%%)" % roundi((multiplier - 1.0) * 100.0)
	if bonus.text != text:
		bonus.text = text
		bonus.reset_size()
	bonus.visible = not text.is_empty()


func _colour(label: Label, colour: StringName) -> void:
	label.add_theme_color_override(&"font_color", Palette.color(colour))


## Right-aligns the level, the health and the XP, and puts each bonus after its value.
func _layout() -> void:
	var level: Label = _values[&"level"]
	level.position.x = BODY_RIGHT - level.size.x
	for key: StringName in [&"health", &"xp"]:
		var value: Label = _values[key]
		value.position.x = BODY_RIGHT - value.size.x
	for key: StringName in _bonuses:
		var value: Label = _values[key]
		_bonuses[key].position.x = value.position.x + value.size.x + BONUS_GAP
