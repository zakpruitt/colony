class_name HeroWindow
extends UiWindow
## One hero's window (spec 060): the hero sheet of specs 026, 034 and 055 as a window of spec 058
## on the UI layer, one per hero, any of them open at once, so two heroes can be read side by
## side. [HeroWindows] makes them and opens them; the window's id is [code]hero_<n>[/code], n
## the hero's place in the party from 0.
##
## A header always shows: the class portrait at twice its size, the class and its path in bold
## ([code]Knight, Berserker[/code]), the level, the role, what the hero is doing now, and health and
## XP as bars with their numbers. Under it a row of tabs, each opening one [enum Page]: Stats
## ([HeroStatsTab]), Talents ([HeroTalentsTab]) and Skills ([HeroSkillsTab]). A tag on the Talents
## tab counts the hero's unspent talent and paragon points, and one on the Skills tab the
## microskills it learned since its Skills tab was last open. Each window keeps its own tab.
##
## Every value is read from the simulation at each [method advance], so nothing goes stale across
## a level up, a command or a crowded frame. It is laid out by hand ([WindowText]), the same size
## on every tab and for every hero, so windows line up when compared. In a room too short for its
## tallest tab (960x540), [HeroWindows] makes it shorter and the tabs' content scrolls inside it
## ([member scroll]); a question on the Talents tab brings the view back to the top, where it is.

## The window's tabs, in order.
enum Page { STATS, TALENTS, SKILLS }

## The tab names, in [enum Page] order.
const TAB_NAMES: Array[String] = ["Stats", "Talents", "Skills"]
## The width of the window's content, in UI pixels: two windows fit side by side in 1280 of room.
const WIDTH: float = 600.0
## The portrait's box, and the left edge of the header's words beside it.
const PORTRAIT_BOX: Rect2 = Rect2(0, 0, 36, 36)
const TEXT_X: float = 46.0
## The header's lines: the class and level, the role and what it does, the health and XP numbers,
## and their bars under them.
const ROLE_Y: float = 13.0
const NUMBERS_Y: float = 27.0
const BARS_Y: float = 41.0
const HEALTH_BAR_HEIGHT: float = 6.0
const XP_BAR_HEIGHT: float = 4.0
## UI pixels between two things on a line, and between the health half and the XP half.
const GAP: float = 12.0
## The row of tabs, the space between tabs (room for a tag on a tab's corner), the line under the
## row, and the top of a tab's content.
const TABS_Y: float = 53.0
const TAB_GAP: float = 16.0
const TAB_LINE_Y: float = TABS_Y + UiTheme.BUTTON_HEIGHT + 3.0
const PAGE_Y: float = TAB_LINE_Y + 6.0
## The room a scroll bar takes at the right of the tabs' content, when it scrolls.
const SCROLL_ROOM: float = 12.0
## The dim line of keys at the right of the tab row.
const KEYS_HINT: String = "Q E tabs   Tab next hero   Shift+Tab close"
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

## The hero this window is for.
var hero_id: int = -1
## The hero's class portrait, at twice its size; a skull while the hero is down.
var portrait: TextureRect
## The class (and path) line, in bold.
var class_label: Label
## The tab buttons, in [enum Page] order; the open tab's is lit.
var tab_buttons: Array[UiButton] = []
## The tags on the Talents and Skills tabs.
var talents_tag: Tag
var skills_tag: Tag
## The three tabs' contents.
var stats: HeroStatsTab
var talents: HeroTalentsTab
var skills: HeroSkillsTab
## Holds the tabs' content under the tab row; it scrolls when the window is shorter than the
## tallest tab needs.
var scroll: ScrollContainer

var _simulation: Simulation
var _holder: Control
var _was_asking: bool = false
var _body: Control
var _pages: Array[Control] = []
var _page: Page = Page.STATS
var _icons: PixelSheet
## How many microskills the hero had when its Skills tab was last open (or the window was made).
var _skills_seen: int = 0
var _values: Dictionary[StringName, Label] = {}
var _health: EasedValue = EasedValue.new(HeroFrame.EASE_SECONDS)
var _xp: EasedValue = EasedValue.new(HeroFrame.EASE_SECONDS)
var _down: bool = false
var _health_goal: float = 0.0
var _xp_goal: float = 0.0
## The part of the class's icon sheet the portrait shows.
var _portrait_part: StringName = &""


## The window of [param hero], the [param place]th hero of the party (from 0); [param tip] gives
## its controls their tooltips (may be null).
func _init(simulation: Simulation, hero: Hero, place: int, tip: UiTip) -> void:
	var body := Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	super(HeroWindows.id_for(place), hero.def().display_name, body)
	on_bar = false
	_simulation = simulation
	_body = body
	hero_id = hero.id
	_icons = PixelSheet.load_sheet(Hud.ICONS_PATH)
	_skills_seen = hero.microskills().size()
	_build_header()
	_build_tabs(tip)
	stats = HeroStatsTab.new(simulation, hero.id, WIDTH)
	talents = HeroTalentsTab.new(simulation, hero.id, WIDTH, tip)
	skills = HeroSkillsTab.new(simulation, hero.id, WIDTH)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(0, PAGE_Y)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)
	_holder = Control.new()
	_holder.name = "Pages"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_holder)
	for page_box: Control in [stats, talents, skills]:
		_holder.add_child(page_box)
		_pages.append(page_box)
	set_body_height(body_height())
	body.draw.connect(_draw_body)
	open_changed.connect(_on_open_changed)
	_show_page()
	advance(0.0)


## The height the content needs on its tallest tab.
func body_height() -> float:
	var tallest: float = 0.0
	for page_box: Control in _pages:
		tallest = maxf(tallest, page_box.size.y)
	return PAGE_Y + tallest


## Makes the content [param height] UI pixels tall on every tab (so every hero's window is the
## same size), and the window as big as it then needs. Shorter than [method body_height], the
## tabs' content scrolls, with room at the right for the scroll bar.
func set_body_height(height: float) -> void:
	var view: float = height - PAGE_Y
	var short: bool = height < body_height() - 0.5
	var wide: float = WIDTH + (SCROLL_ROOM if short else 0.0)
	_body.custom_minimum_size = Vector2(wide, height)
	_body.size = _body.custom_minimum_size
	scroll.custom_minimum_size = Vector2(wide, view)
	scroll.size = scroll.custom_minimum_size
	_fit_holder()
	reset_size()
	fit_size()
	settle()


## True when the tabs' content is shorter than the open tab needs, so it scrolls.
func scrolls() -> bool:
	return _holder.custom_minimum_size.y > scroll.size.y + 0.5


## The window's height less its content's: the title bar and the margins.
func chrome_height() -> float:
	return size.y - _body.size.y


## Lays the window's frame out now (its title bar and margins are containers, which would
## otherwise wait for the next frame), so what it shows is where it is drawn at once.
func settle() -> void:
	var queue: Array[Node] = [self]
	while not queue.is_empty():
		var each: Node = queue.pop_front()
		if each is Container:
			each.notification(Container.NOTIFICATION_SORT_CHILDREN)
		queue.append_array(each.get_children())


## Brings every line up to date with the hero and eases the bars. [HeroWindows] calls it every
## frame for every window, open or not; tests call it.
func advance(delta: float) -> void:
	var hero: Hero = _hero()
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
	WindowText.set_text(class_label, HeroTalentsTab.title(hero))
	var role: String = ROLE_WORDS.get(hero.def().role, "")
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
	var colour: StringName = DOING_COLOURS.get(doing.get_slice(" ", 0), &"silver")
	_values[&"activity"].add_theme_color_override(&"font_color", Palette.color(colour))
	_lay_out_header()
	stats.refresh()
	talents.refresh(delta)
	skills.refresh()
	_fit_holder()
	var asking: bool = talents.asking() != HeroTalentsTab.Asking.NOTHING
	if asking and not _was_asking:
		scroll.scroll_vertical = 0  # the question is at the top of the tab
	_was_asking = asking
	_refresh_tags(hero)
	var part: StringName = &"skull" if _down else hero.class_id
	if part != _portrait_part:
		_portrait_part = part
		portrait.texture = _icons.part(part) if _icons.has_part(part) else null
	_body.queue_redraw()


## The open tab (or the one that will be open when the window next opens).
func page() -> Page:
	return _page


## Opens tab [param which]: its button is lit and only its content is shown.
func open_page(which: Page) -> void:
	_page = which
	_show_page()
	var hero: Hero = _hero()
	if hero != null:
		_refresh_tags(hero)


## Opens the next tab, wrapping from the last to the first.
func next_page() -> void:
	open_page(((_page + 1) % TAB_NAMES.size()) as Page)


## Opens the previous tab, wrapping from the first to the last.
func previous_page() -> void:
	open_page(((_page + TAB_NAMES.size() - 1) % TAB_NAMES.size()) as Page)


## True when tab [param which] carries its tag: Talents when the hero has a talent or paragon
## point to spend, Skills when it learned a microskill since its Skills tab was last open.
func page_marked(which: Page) -> bool:
	match which:
		Page.TALENTS:
			return talents_tag.count > 0
		Page.SKILLS:
			return skills_tag.count > 0
	return false


## Puts one of the hero's paragon points into paragon stat [param index] (0-based), if the window
## is open on its Talents tab and the hero has a point; otherwise does nothing. The number keys
## call it on the front hero window.
func train_row(index: int) -> void:
	if is_open() and _page == Page.TALENTS:
		talents.spend_paragon(index)


## The text of a line of the window, for tests, whichever tab is open: &"class", &"role",
## &"level", &"health", &"xp", &"activity"; a stat's line (&"stat_damage" and the rest, see
## [method HeroStatsTab.line]); the Talents tab's &"talent_points" and &"paragon_points", and a
## paragon stat's &"training_power" ([code]Power 2 +6%[/code]); and &"microskills", the Skills
## tab's lines, one per line.
func line(key: StringName) -> String:
	if key == &"class":
		return class_label.text
	if key == &"microskills":
		return "\n".join(PackedStringArray(skills.lines()))
	if key == &"talent_points":
		return talents.points_label.text
	if key == &"paragon_points":
		return talents.paragon_label.text
	for cell: ParagonCell in talents.paragon_cells:
		if key == StringName("training_" + String(cell.id)):
			return cell.text()
	if HeroStatsTab.STAT_NAMES.has(key):
		return stats.line(key)
	var value: Label = _values.get(key, null)
	return value.text if value != null else ""


## The fraction a bar shows this frame: &"health" or &"xp".
func bar_fraction(key: StringName) -> float:
	match key:
		&"health":
			return _health.value
		&"xp":
			return _xp.value
	return 0.0


## The colour a header line is drawn in (&"activity", &"level" and so on).
func line_colour(key: StringName) -> Color:
	var value: Label = _values.get(key, null)
	return value.get_theme_color(&"font_color") if value != null else Color.BLACK


## The talent and paragon points [param hero] has to spend (its frame's marker and its Talents
## tab's tag count them).
static func unspent(hero: Hero) -> int:
	return hero.talent_points() + hero.paragon_points()


## A distance in tiles as words: whole numbers without a decimal (7), others with one (6.5).
static func tiles(distance: float) -> String:
	if is_equal_approx(distance, roundf(distance)):
		return str(roundi(distance))
	return "%.1f" % distance


# --- Reading the simulation ------------------------------------------------------


func _hero() -> Hero:
	return _simulation.party.hero(hero_id) if _simulation != null else null


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


# --- Building and laying out -----------------------------------------------------


func _build_header() -> void:
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var picture: Texture2D = _icons.part(_hero().class_id) if _icons != null else null
	var shown: Vector2 = Vector2(picture.get_size()) * 2.0 if picture != null else Vector2(32, 32)
	portrait.size = shown
	portrait.position = (PORTRAIT_BOX.size - shown) / 2.0
	_body.add_child(portrait)
	class_label = WindowText.label("Class", "", &"white", true)
	class_label.position = Vector2(TEXT_X, 0)
	_body.add_child(class_label)
	_add_line(&"level", &"yellow", Vector2(0, 0))
	_add_line(&"role", &"steel", Vector2(TEXT_X, ROLE_Y))
	_add_line(&"activity", &"silver", Vector2(0, ROLE_Y))
	var health_caption: Label = WindowText.label("HealthCaption", "Health", &"steel")
	health_caption.position = Vector2(TEXT_X, NUMBERS_Y)
	_body.add_child(health_caption)
	var xp_caption: Label = WindowText.label("XpCaption", "XP", &"steel")
	xp_caption.position = Vector2(_half(), NUMBERS_Y)
	_body.add_child(xp_caption)
	_add_line(&"health", &"white", Vector2(0, NUMBERS_Y))
	_add_line(&"xp", &"silver", Vector2(0, NUMBERS_Y))


## The tab row: a button per tab, the two tags pinned to their tabs' corners, and the keys hint.
func _build_tabs(tip: UiTip) -> void:
	var x: float = 0.0
	for i: int in TAB_NAMES.size():
		var tab: UiButton = WindowText.button("%sTab" % TAB_NAMES[i], TAB_NAMES[i])
		tab.position = Vector2(x, TABS_Y)
		tab.pressed.connect(open_page.bind(i as Page))
		_body.add_child(tab)
		tab_buttons.append(tab)
		x += tab.size.x + TAB_GAP
	var hint: Label = WindowText.label("KeysHint", KEYS_HINT, &"slate")
	var middle: float = floorf((UiTheme.BUTTON_HEIGHT - UiText.LINE_HEIGHT) / 2.0)
	hint.position = Vector2(WIDTH - hint.size.x, TABS_Y + middle)
	_body.add_child(hint)
	talents_tag = Tag.new("TalentsTag")
	skills_tag = Tag.new("SkillsTag")
	for tag: Tag in [talents_tag, skills_tag]:
		_body.add_child(tag)
	if tip != null:
		tip.attach(tab_buttons[Page.STATS], "What the hero can do, and what raises it.")
		tip.attach(tab_buttons[Page.TALENTS], "The hero's talent tree and paragon points.")
		tip.attach(tab_buttons[Page.SKILLS], "The small skills that open side quests.")


func _add_line(key: StringName, colour: StringName, at: Vector2) -> void:
	var made: Label = WindowText.label(String(key).capitalize().replace(" ", ""), "", colour)
	made.position = at
	_body.add_child(made)
	_values[key] = made


func _set_line(key: StringName, text: String) -> void:
	WindowText.set_text(_values[key], text)


## Where the XP half of the numbers line starts.
func _half() -> float:
	return floorf(TEXT_X + (WIDTH - TEXT_X) / 2.0 + GAP / 2.0)


## Right-aligns the level and each number, and puts what the hero does after its role.
func _lay_out_header() -> void:
	var level: Label = _values[&"level"]
	level.position.x = WIDTH - level.size.x
	var role: Label = _values[&"role"]
	_values[&"activity"].position.x = TEXT_X + role.size.x + (GAP if role.size.x > 0 else 0.0)
	var health: Label = _values[&"health"]
	health.position.x = _half() - GAP - health.size.x
	var xp: Label = _values[&"xp"]
	xp.position.x = WIDTH - xp.size.x


## Shows only the open tab's content and lights its button.
func _show_page() -> void:
	for i: int in _pages.size():
		_pages[i].visible = i == _page
	for i: int in tab_buttons.size():
		tab_buttons[i].lit = i == _page
	if scroll != null:
		_fit_holder()
		scroll.scroll_vertical = 0


## Sizes the scrolled holder to the open tab, so the scroll bar reaches its end and no further.
func _fit_holder() -> void:
	var shown: Control = _pages[_page] if _page < _pages.size() else null
	var tall: float = shown.size.y if shown != null else 0.0
	_holder.custom_minimum_size = Vector2(WIDTH, tall)
	_holder.size = _holder.custom_minimum_size


## Brings the two tags up to date with [param hero] (counting what the open Skills tab shows as
## seen) and pins each to its tab's top right corner.
func _refresh_tags(hero: Hero) -> void:
	if _page == Page.SKILLS and is_open():
		_skills_seen = hero.microskills().size()
	talents_tag.show_count(HeroWindow.unspent(hero), tab_buttons[Page.TALENTS])
	skills_tag.show_count(
		maxi(hero.microskills().size() - _skills_seen, 0), tab_buttons[Page.SKILLS]
	)


func _draw_body() -> void:
	var ink: Color = Palette.color(&"ink")
	var dusk: Color = Palette.color(&"dusk")
	_body.draw_rect(PORTRAIT_BOX, dusk)
	_body.draw_rect(PORTRAIT_BOX.grow(-1.0), ink)
	_body.draw_rect(Rect2(0, TAB_LINE_Y, WIDTH, 1), dusk)
	var health_bar := Rect2(TEXT_X, BARS_Y, _half() - GAP - TEXT_X, HEALTH_BAR_HEIGHT)
	var health_colour: StringName = &"red"
	if not _down and _health.value > HeroFrame.GREEN_ABOVE:
		health_colour = &"green"
	elif not _down and _health.value >= HeroFrame.RED_BELOW:
		health_colour = &"yellow"
	_bar(health_bar, _health.value, Palette.color(health_colour))
	var xp_bar := Rect2(_half(), BARS_Y, WIDTH - _half(), XP_BAR_HEIGHT)
	_bar(xp_bar, _xp.value, Palette.color(&"cyan"))


## A window just opened: laid out at once, every line read now and the bars at their values,
## not easing from where they were when it closed.
func _on_open_changed(_window: UiWindow) -> void:
	if not is_open():
		return
	settle()
	advance(0.0)
	_health.snap(_health_goal)
	_xp.snap(_xp_goal)
	_body.queue_redraw()


## A bar in [param rect]: an ink edge, filled from the left to [param fraction] in [param colour].
func _bar(rect: Rect2, fraction: float, colour: Color) -> void:
	_body.draw_rect(rect, Palette.color(&"ink"))
	var inner: Rect2 = rect.grow(-1.0)
	_body.draw_rect(inner, Palette.color(&"dark_brown"))
	var filled: float = roundf(inner.size.x * clampf(fraction, 0.0, 1.0))
	if filled > 0.0:
		_body.draw_rect(Rect2(inner.position, Vector2(filled, inner.size.y)), colour)


## A small count on the corner of a tab: what waits there.
class Tag:
	extends Label

	## The number shown; the tag shows only while it is above 0.
	var count: int = 0

	func _init(tag_name: String) -> void:
		name = tag_name
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_font_override(&"font", UiText.font(true))
		add_theme_font_size_override(&"font_size", UiText.SIZE)
		add_theme_color_override(&"font_color", Palette.color(&"ink"))
		add_theme_constant_override(&"line_spacing", 0)
		var box: StyleBoxFlat = UiTheme.box(&"yellow", &"amber", 2, 0)
		add_theme_stylebox_override(&"normal", box)

	## Shows [param shown] while above 0, on the top right corner of [param tab].
	func show_count(shown: int, tab: UiButton) -> void:
		count = shown
		visible = shown > 0
		var text_now: String = str(shown)
		if text != text_now:
			text = text_now
		size = Vector2(UiText.width(text_now, true) - UiText.SPACING + 6, UiText.LINE_HEIGHT + 2)
		position = Vector2(tab.position.x + tab.size.x - 6.0, tab.position.y - 6.0)
