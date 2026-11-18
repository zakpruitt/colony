class_name HeroSheet
extends Control
## One hero's sheet (spec 026): who the hero is, how they stand, what they can do and what they
## are doing now, in plain words. It drops from under the HUD's top band at the left, opposite the
## shop, and never reaches the party frames or the strip just above them. Clicking a hero's frame
## or pressing Tab opens it; it never pauses the game. Every value is read from the simulation on
## each [method advance], so nothing goes stale across a level up, an upgrade or a loaded save.
## Drawn as a [HudPanel] is, in the shop's look.
##
## Spec 034 keeps it compact: a header that is always shown (the portrait, class, role, level,
## activity, and the health and XP lines with their bars), then a row of tabs, each opening one
## [enum Page]. Only the open page's content is shown, so only it takes clicks. [kbd]Q[/kbd] and
## [kbd]E[/kbd] (passed on by the HUD) move between pages, wrapping; the open page is kept across
## heroes and across closing and reopening, and a new HUD starts on Stats. A [ShopMarker] on the
## Talents tab counts the shown hero's unspent talent and paragon points, and one on the Skills tab
## counts the microskills the hero learned since their Skills page was last open.
##
## The Talents page (spec 055) is a [TalentTab]: the hero's whole tree, what each node does, and
## its paragon points. The sheet grows to [constant TALENTS_SIZE] while it is open, as the tree
## needs, and is [constant SIZE] on the other pages. A paragon stat's [code]+1[/code], or the number
## key the HUD passes to [method train_row], asks the simulation to put one of the hero's paragon
## points into that stat. Once the hero chooses a path, the class line reads
## [code]Knight, Berserker[/code].
##
## The Skills page (spec 028) lists each microskill the hero's class learns, in the class's order:
## one the hero has in white with its one-line description, one to come in grey with the level it
## comes at.

## Emitted when the sheet opens, closes or switches hero.
signal shown_changed

## The sheet's pages, in tab order.
enum Page { STATS, TALENTS, SKILLS }

## The panel's size in pixels (spec 034 R1: at most 240x150), and its size while the Talents page
## is open (spec 055: the whole tree, nothing to scroll), still clear of the strip above the frames.
const SIZE: Vector2 = Vector2(240, 150)
const TALENTS_SIZE: Vector2 = TalentTab.SIZE
## Space inside the border.
const PADDING: float = 4.0
## Pixels between the panel and the top band above it.
const DROP: float = 2.0
## The portrait's box (a frame's [constant HeroFrame.ICON_BOX] at twice the size) and the
## left edge of the text beside it.
const PORTRAIT_BOX: Rect2 = Rect2(6, 6, 36, 36)
const HEADER_X: float = 48.0
## The left and right edges of the lines under the portrait and of the pages.
const BODY_LEFT: float = 8.0
const BODY_RIGHT: float = SIZE.x - 8.0
## The health and XP lines and their bars.
const HEALTH_Y: float = 44.0
const HEALTH_BAR: Rect2 = Rect2(BODY_LEFT, 53, BODY_RIGHT - BODY_LEFT, 7)
const XP_Y: float = 62.0
const XP_BAR: Rect2 = Rect2(BODY_LEFT, 71, BODY_RIGHT - BODY_LEFT, 5)
## The tab row: its top, where the first tab starts, and the space between tabs (room for a
## marker pinned to a tab's right edge).
const TABS_Y: float = 78.0
const TABS_X: float = 6.0
const TAB_GAP: float = 10.0
## The tab names, in [enum Page] order.
const TAB_NAMES: Array[String] = ["Stats", "Talents", "Skills"]
## The dim line of keys at the right of the tab row.
const KEYS_HINT: String = "Q E tabs   Tab next hero"
## The line the tabs stand on, and the top of a page's content.
const TAB_LINE_Y: float = TABS_Y + HudButton.HEIGHT
const PAGE_Y: float = TAB_LINE_Y + 3.0
## The stat block: where it starts, a row's height, and where its second column starts.
const STATS_Y: float = PAGE_Y
const STAT_ROW: float = 10.0
const STATS_SECOND_X: float = 124.0
## Pixels between a stat's name and its value, and between the value and its bonus.
const STAT_GAP: float = 6.0
const BONUS_GAP: float = 4.0
## The Skills page: its first row, a row's height and the most rows any class needs.
const MICROSKILLS_Y: float = PAGE_Y
const MICROSKILL_ROW: float = 10.0
const MICROSKILL_ROWS: int = 2
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
	Expedition.State.CLIMBING: "Moving on",
	Expedition.State.REVIVING: "Recovering",
}
## The colour of each activity, matching the HUD's state word.
const DOING_COLOURS: Dictionary[String, StringName] = {
	"Walking": &"silver",
	"Fighting": &"orange",
	"Healing": &"green",
	"Resting": &"green",
	"Moving on": &"tan",
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
## The tab buttons, in [enum Page] order; the open page's is lit.
var tab_buttons: Array[HudButton] = []
## The markers on the Talents tab (the shown hero's unspent talent and paragon points) and on the
## Skills tab (microskills learned since that hero's Skills page was last open).
var talents_marker: ShopMarker
var skills_marker: ShopMarker
## The Talents page (spec 055).
var talents: TalentTab
## The hero's class portrait at twice a frame's size; a skull while the hero is down.
var portrait: TextureRect

var _simulation: Simulation
## Each page's content, in [enum Page] order; only the open page's is visible.
var _pages: Array[Control] = []
var _page: Page = Page.STATS
## How many microskills each hero had when their Skills page was last open (or when the sheet
## was made), by hero id.
var _skills_seen: Dictionary[int, int] = {}
## The Skills page's rows, top to bottom.
var _microskill_rows: Array[Label] = []
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
	draw_rect(Rect2(PADDING, TAB_LINE_Y, SIZE.x - 2.0 * PADDING, 1), dusk)
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


## Call once, before the first advance. [param world] may be null (no flashes then).
func setup(simulation: Simulation, world: World) -> void:
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
	_add_line(self, &"class", &"white", Vector2(HEADER_X, 5))
	_make_big(_values[&"class"])
	_add_line(self, &"role", &"steel", Vector2(HEADER_X, 23))
	_add_line(self, &"level", &"yellow", Vector2(HEADER_X, 23))
	_add_line(self, &"activity", &"silver", Vector2(HEADER_X, 33))
	_caption(self, "Health", Vector2(BODY_LEFT, HEALTH_Y))
	_add_line(self, &"health", &"white", Vector2(BODY_LEFT, HEALTH_Y))
	_caption(self, "XP", Vector2(BODY_LEFT, XP_Y))
	_add_line(self, &"xp", &"silver", Vector2(BODY_LEFT, XP_Y))
	for page_name: String in TAB_NAMES:
		var page_box := Control.new()
		if page_name == TAB_NAMES[Page.TALENTS]:
			talents = TalentTab.new()
			talents.setup(simulation)
			page_box = talents
		page_box.name = "%sPage" % page_name
		page_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page_box.size = TALENTS_SIZE if page_box == talents else SIZE
		add_child(page_box)
		_pages.append(page_box)
	_build_stats(FIRST_COLUMN, BODY_LEFT)
	_build_stats(SECOND_COLUMN, STATS_SECOND_X)
	_build_microskills()
	_build_tabs()
	close_button = HudButton.new("x")
	close_button.name = "Close"
	close_button.custom_minimum_size = Vector2(HudButton.HEIGHT, HudButton.HEIGHT)
	close_button.size = close_button.get_combined_minimum_size()
	close_button.position = Vector2(SIZE.x - PADDING - close_button.size.x, PADDING)
	close_button.pressed.connect(close)
	add_child(close_button)
	for hero: Hero in simulation.party.heroes:
		_skills_seen[hero.id] = hero.microskills().size()
	if world != null:
		world.sim_event.connect(_on_sim_event)
	_show_page()
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
	_set_line(&"class", TalentTab.title(hero))  # spec 055 R9: the path beside the class
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
	talents.show_hero(hero.id)
	talents.refresh(delta)
	_refresh_microskills(hero)
	_refresh_markers(hero, delta)
	var part: StringName = &"skull" if _down else hero.class_id
	var texture: Texture2D = _icons.part(part) if _icons.has_part(part) else null
	if portrait.texture != texture:
		portrait.texture = texture
	_layout()
	queue_redraw()


## Shows the sheet of the hero with id [param hero_id]. The open page stays as it was. (Since spec
## 059 the shop is a window: the HUD closes it only if it lies over the sheet, as any window.)
func open(hero_id: int) -> void:
	if _simulation == null or _simulation.party.hero(hero_id) == null:
		return
	var switched: bool = hero_id != _hero_id or not visible
	_hero_id = hero_id
	visible = true
	if switched:
		talents.show_hero(hero_id)
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


## The page open (or that will be open when the sheet next opens).
func page() -> Page:
	return _page


## Opens [param which]: its tab is lit and only its content is shown.
func open_page(which: Page) -> void:
	_page = which
	_show_page()
	var hero: Hero = _shown_hero()
	if hero != null:
		_refresh_markers(hero, 0.0)


## Opens the next page, wrapping from the last to the first.
func next_page() -> void:
	open_page(((_page + 1) % TAB_NAMES.size()) as Page)


## Opens the previous page, wrapping from the first to the last.
func previous_page() -> void:
	open_page(((_page + TAB_NAMES.size() - 1) % TAB_NAMES.size()) as Page)


## True when the tab of [param which] carries its marker for the shown hero: Talents when the hero
## has a talent or paragon point to spend, Skills when the hero learned a microskill since their
## Skills page was last open. False while the sheet is closed, and for Stats.
func page_marked(which: Page) -> bool:
	var hero: Hero = _shown_hero()
	if hero == null or not is_open():
		return false
	match which:
		Page.TALENTS:
			return HeroSheet.unspent(hero) > 0
		Page.SKILLS:
			return _new_skills(hero) > 0
	return false


## Asks the simulation to put one of the shown hero's paragon points into paragon stat
## [param index] (0-based), if the sheet is open on its Talents page and the hero has a point;
## otherwise does nothing. The stat's [code]+1[/code] and the number keys call it.
func train_row(index: int) -> void:
	if not is_open() or _page != Page.TALENTS or _shown_hero() == null:
		return
	talents.spend_paragon(index)


## The talent and paragon points [param hero] has to spend (spec 055: its frame's and its Talents
## tab's marker count them, with the frame's new microskills).
static func unspent(hero: Hero) -> int:
	return hero.talent_points() + hero.paragon_points()


## The text of a line of the sheet, for tests, whichever page is open: &"class", &"role",
## &"level", &"health", &"xp", &"activity", and one per stat: &"stat_health", &"stat_damage",
## &"stat_armor", &"stat_attack_speed", &"stat_crit", &"stat_range", &"stat_healing" ("" when the
## class does not heal); the Talents page's &"talent_points" ([code]2 talent points[/code], or
## when the next comes) and &"paragon_points" ([code]3 paragon points[/code], or when they come);
## one per paragon stat: &"training_power", &"training_toughness", &"training_quickness", as
## "<name> <points> <bonus>" ([code]Power 2 +6%[/code]); and &"microskills", the Skills page's rows,
## one per line ("Lockpicker: Opens locks", "Trapspotter, level 6").
func line(key: StringName) -> String:
	if key == &"microskills":
		var rows: PackedStringArray = []
		for row: Label in _microskill_rows:
			if row.visible:
				rows.append(row.text)
		return "\n".join(rows)
	var talent_text: String = _talent_line(key)
	if not talent_text.is_empty():
		return talent_text
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


## The Talents page's line [param key] names, or "" for a key of another page.
func _talent_line(key: StringName) -> String:
	var cell: TalentTab.ParagonCell = paragon_cell(key)
	var text: String = cell.text() if cell != null else ""
	if key == &"talent_points":
		text = talents.points_label.text
	elif key == &"paragon_points":
		text = talents.paragon_label.text
	return text


## The paragon stat's cell a line key names (&"training_power", ...), or null.
func paragon_cell(key: StringName) -> TalentTab.ParagonCell:
	for cell: TalentTab.ParagonCell in talents.paragon_cells:
		if key == StringName("training_" + String(cell.id)):
			return cell
	return null


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
	# A bonus is the camp upgrade's and the hero's paragon points' together (spec 051).
	var toughness: float = (
		_multiplier(UpgradeDef.Stat.HEALTH) * hero.paragon_multiplier(TrainingDef.Stat.TOUGHNESS)
	)
	var power: float = (
		_multiplier(UpgradeDef.Stat.DAMAGE) * hero.paragon_multiplier(TrainingDef.Stat.POWER)
	)
	var quickness: float = hero.paragon_multiplier(TrainingDef.Stat.QUICKNESS)
	_set_stat(&"stat_health", str(hero.max_health()), toughness)
	_set_stat(&"stat_damage", str(fighter.damage), power)
	_set_stat(&"stat_armor", str(fighter.armor), 1.0)
	var speed: float = quickness / maxf(def.attack_interval, 0.01)
	_set_stat(&"stat_attack_speed", "%.1f/s" % speed, quickness)
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


## How many microskills [param hero] learned since their Skills page was last open.
func _new_skills(hero: Hero) -> int:
	var count: int = hero.microskills().size()
	var seen: int = _skills_seen.get(hero.id, count)
	return maxi(count - seen, 0)


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
	var parent: Control = _pages[Page.STATS]
	var widest: int = 0
	for key: StringName in keys:
		widest = maxi(widest, PixelText.width(STAT_NAMES[key]))
	var y: float = STATS_Y
	for key: StringName in keys:
		_names[key] = _caption(parent, STAT_NAMES[key], Vector2(x, y))
		_add_line(parent, key, &"white", Vector2(x + widest + STAT_GAP, y))
		var bonus: Label = PixelText.label("", &"green")
		bonus.name = "%sBonus" % String(key).capitalize().replace(" ", "")
		bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bonus.position = Vector2(x, y)
		parent.add_child(bonus)
		_bonuses[key] = bonus
		y += STAT_ROW


## The Skills page: a row per microskill the class can learn.
func _build_microskills() -> void:
	var y: float = MICROSKILLS_Y
	for i: int in MICROSKILL_ROWS:
		var row: Label = _caption(_pages[Page.SKILLS], "", Vector2(BODY_LEFT, y))
		row.name = "Microskill%d" % i
		_microskill_rows.append(row)
		y += MICROSKILL_ROW


## The tab row: a button per page, the two markers pinned to their tabs, and the keys hint.
func _build_tabs() -> void:
	var x: float = TABS_X
	for i: int in TAB_NAMES.size():
		var tab := HudButton.new(TAB_NAMES[i])
		tab.name = "%sTab" % TAB_NAMES[i]
		tab.position = Vector2(x, TABS_Y)
		tab.pressed.connect(open_page.bind(i as Page))
		add_child(tab)
		tab_buttons.append(tab)
		x += tab.size.x + TAB_GAP
	var hint: Label = _caption(self, KEYS_HINT, Vector2.ZERO)
	hint.name = "KeysHint"
	_colour(hint, &"slate")
	hint.position = Vector2(BODY_RIGHT - PixelText.width(KEYS_HINT), TABS_Y + 2.0)
	talents_marker = _marker("TalentsMarker")
	skills_marker = _marker("SkillsMarker")


func _marker(marker_name: String) -> ShopMarker:
	var made := ShopMarker.new()
	made.name = marker_name
	made.visible = false
	add_child(made)
	return made


## Shows only the open page's content and lights its tab; the sheet takes the page's size.
func _show_page() -> void:
	for i: int in _pages.size():
		_pages[i].visible = i == _page
	for i: int in tab_buttons.size():
		tab_buttons[i].lit = i == _page
	size = TALENTS_SIZE if _page == Page.TALENTS else SIZE  # spec 055: room for the tree
	queue_redraw()


## Brings the two markers up to date with [param hero] (marking what the open Skills page shows
## as seen), pins them to their tabs and runs their pulse on by [param delta] seconds.
func _refresh_markers(hero: Hero, delta: float) -> void:
	if _page == Page.SKILLS:
		_skills_seen[hero.id] = hero.microskills().size()
	_pin(talents_marker, tab_buttons[Page.TALENTS], HeroSheet.unspent(hero), delta)
	_pin(skills_marker, tab_buttons[Page.SKILLS], _new_skills(hero), delta)


## Shows [param marker] with [param count] while it is above 0, pinned to [param tab]'s right
## edge (beside its name, not over it, and clear of the XP bar above), and runs its pulse on by
## [param delta] seconds.
func _pin(marker: ShopMarker, tab: HudButton, count: int, delta: float) -> void:
	marker.count = count
	marker.visible = count > 0
	marker.advance(delta)
	marker.position = Vector2(tab.position.x + tab.size.x - 1.0, tab.position.y)


## Fills the Skills page's rows from [param hero]'s class and level.
func _refresh_microskills(hero: Hero) -> void:
	var def: HeroClassDef = hero.def()
	var count: int = mini(def.microskills.size(), def.microskill_levels.size())
	for i: int in _microskill_rows.size():
		var row: Label = _microskill_rows[i]
		var skill: MicroskillDef = Content.microskill(def.microskills[i]) if i < count else null
		row.visible = skill != null
		if skill == null:
			continue
		var level: int = def.microskill_levels[i]
		var has: bool = hero.level >= level
		var text: String = "%s: %s" % [skill.display_name, skill.description]
		if not has:
			text = "%s, level %d" % [skill.display_name, level]
		if row.text != text:
			row.text = text
			row.reset_size()
		_colour(row, &"white" if has else &"steel")


func _add_line(parent: Control, key: StringName, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label("", colour)
	made.name = String(key).capitalize().replace(" ", "")
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(made)
	_values[key] = made
	return made


func _caption(parent: Control, text: String, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, &"steel")
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(made)
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


func _on_sim_event(event: SimEvent) -> void:
	if event.kind != SimEvent.Kind.PARAGON_SPENT or event.source_id != shown_hero_id():
		return
	talents.flash_paragon(event.target_id)
