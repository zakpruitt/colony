class_name Journal
extends Control
## The party's journal (spec 027 R3): the last [constant CAPACITY] notable happenings as plain
## sentences stamped with the game time, newest first.
##
## It listens to [signal World.sim_event] and writes a line for a new deepest depth, a depth turning
## stable, a level up, a wipe (and the depth the party falls back to), a guardian slain, an upgrade
## bought, a microskill learned, and a side quest done (with its reward), passed by or sprung (with
## the microskill it needed) (spec 028). The newest line shows in a one-line [member ticker] just
## above the party frames for [constant TICKER_SECONDS], then fades through the palette and goes;
## events too old to animate ([method World.is_recent]) are written but not shown there.
## [kbd]J[/kbd] opens and closes [member panel], the last [constant SHOWN_LINES] lines below the top
## band at the left; [kbd]Esc[/kbd] closes it (and lets the HUD close the shop or hero sheet too),
## and so does the shop or the hero sheet (spec 026) opening. The sheet drops into the same place,
## so opening the journal closes the sheet. Nothing here pauses the game.
##
## The node itself has no size: its two children, each a [HudPanel], are what is seen. It moves
## only in [method advance], so a test can step it exactly.

## Lines kept, newest first.
const CAPACITY: int = 50
## Lines the panel lists.
const SHOWN_LINES: int = 12
## Seconds the newest line shows in the ticker at full strength.
const TICKER_SECONDS: float = 4.0
## Then its text steps down through these colours, each for FADE_STEP seconds, and it goes.
const FADE_COLOURS: Array[StringName] = [&"silver", &"steel", &"slate"]
const FADE_STEP: float = 0.2
## Space inside a panel's border; a line's height; the title row's height.
const PADDING: float = 4.0
const LINE_HEIGHT: float = 9.0
const TITLE_HEIGHT: float = 13.0
## The panel's width, and the column the sentence starts at after the time.
const PANEL_WIDTH: float = 300.0
const TEXT_COLUMN: float = 40.0
## The ticker's height, and the pixels between it and the top of the party frames.
const TICKER_HEIGHT: float = 13.0
const TICKER_GAP: float = 3.0

## The list of the last lines, shown while the journal is open.
var panel: HudPanel
## The newest line, for a few seconds after it is written.
var ticker: HudPanel

var _simulation: Simulation
var _world: World
## Lines as written, newest first: the game time and the sentence.
var _times: Array[String] = []
var _sentences: Array[String] = []
var _ticker_label: Label
var _ticker_age: float = INF
var _time_labels: Array[Label] = []
var _line_labels: Array[Label] = []
var _empty_label: Label
## What the journal knows of the party, kept in step with the events.
var _depth: int = 1
var _deepest: int = 1
var _shop_was_open: bool = false
var _sheet_was_open: bool = false


func _init() -> void:
	name = "Journal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_J:
			if is_open():
				close()
			else:
				open()
		KEY_ESCAPE:
			# Not marked handled, so the HUD's Esc closes the shop or the sheet as well.
			close()
			return
		_:
			return
	get_viewport().set_input_as_handled()


## Call once, before the first advance. [param world] may be null (nothing is written then).
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	_depth = simulation.expedition.depth
	_deepest = simulation.expedition.deepest_depth
	_build_panel()
	_build_ticker()
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Runs the ticker on by [param delta] seconds, closes the journal if the shop or the hero sheet
## has just opened,
## and brings the panel up to date. Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	_depth = _simulation.expedition.depth
	var shop_open: bool = _shop_is_open()
	if shop_open and not _shop_was_open:
		close()
	_shop_was_open = shop_open
	var sheet: HeroSheet = _sheet()
	var sheet_open: bool = sheet != null and sheet.is_open()
	if sheet_open and not _sheet_was_open:
		close()
	_sheet_was_open = sheet_open
	_ticker_age += delta
	_show_ticker()


## Every line kept, newest first, each the game time then the sentence: [code]12:04  Mage
## reached level 4[/code].
func lines() -> Array[String]:
	var all: Array[String] = []
	for i: int in _sentences.size():
		all.append("%s  %s" % [_times[i], _sentences[i]])
	return all


## The sentence in the ticker, or "" when nothing is showing.
func ticker_text() -> String:
	return _ticker_label.text if ticker.visible else ""


## The lines the open panel lists, top to bottom; empty while it is closed.
func shown_lines() -> Array[String]:
	var shown: Array[String] = []
	if not is_open():
		return shown
	for i: int in _line_labels.size():
		if _line_labels[i].visible:
			shown.append("%s  %s" % [_time_labels[i].text, _line_labels[i].text])
	return shown


## True while the panel is shown.
func is_open() -> bool:
	return panel.visible


## Shows the panel of the last lines, closing the "While you were away" panel and the hero sheet
## if they are up.
func open() -> void:
	var sheet: HeroSheet = _sheet()
	if sheet != null and sheet.is_open():
		sheet.close()
	_sheet_was_open = false
	var hud: Node = get_parent()
	if hud is Hud and (hud as Hud).help != null:
		(hud as Hud).help.close()  # spec 030: never with the help panel
	var layer: Node = hud.get_parent() if hud != null else null
	if layer != null:
		for child: Node in layer.get_children():
			if child is AwayPanel:
				(child as AwayPanel).close()
	panel.visible = true
	_fill_panel()


## Hides the panel.
func close() -> void:
	panel.visible = false


## Writes [param sentence] as a line now, without showing it in the ticker: the goals tracker's
## line for a finished goal (spec 037 R3), which the tracker itself celebrates.
func write(sentence: String) -> void:
	if _simulation == null or sentence.is_empty():
		return
	_times.push_front(clock(_simulation.tick))
	_sentences.push_front(sentence)
	if _sentences.size() > CAPACITY:
		_times.resize(CAPACITY)
		_sentences.resize(CAPACITY)
	if is_open():
		_fill_panel()


## Game time as m:ss, or h:mm:ss from an hour on.
static func clock(tick: int) -> String:
	var seconds: int = floori(float(tick) / Simulation.TICKS_PER_SECOND)
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	return "%d:%02d" % [seconds / 60, seconds % 60]


# --- Writing -------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	var sentence: String = _sentence(event)
	if sentence.is_empty():
		return
	_times.push_front(clock(event.tick))
	_sentences.push_front(sentence)
	if _sentences.size() > CAPACITY:
		_times.resize(CAPACITY)
		_sentences.resize(CAPACITY)
	if _world == null or _world.is_recent(event):
		_ticker_label.text = sentence
		_ticker_label.reset_size()
		_ticker_age = 0.0
		_show_ticker()
	if is_open():
		_fill_panel()


## The sentence for [param event], or "" for an event the journal does not write.
func _sentence(event: SimEvent) -> String:
	var sentence: String = ""
	match event.kind:
		SimEvent.Kind.DEPTH_CHANGED:
			_depth = event.amount
			if event.amount > _deepest:
				_deepest = event.amount
				sentence = "Reached depth %d, the deepest yet" % event.amount
		SimEvent.Kind.STABLE_DEPTH_REACHED:
			sentence = "Depth %d is now stable" % event.amount
		SimEvent.Kind.LEVEL_UP:
			var hero: Hero = _simulation.party.hero(event.target_id)
			var who: String = hero.def().display_name if hero != null else "A hero"
			sentence = "%s reached level %d" % [who, event.amount]
		SimEvent.Kind.PARTY_WIPED:
			var back_to: int = _simulation.expedition.last_stable_depth
			sentence = "Wiped on depth %d, falling back to depth %d" % [_depth, back_to]
			if back_to == _depth:
				sentence = "Wiped on depth %d, regrouping there" % _depth
		SimEvent.Kind.GUARDIAN_SLAIN:
			var def: MonsterDef = Content.monster(_simulation.expedition.guardian_of(event.amount))
			var guardian: String = def.display_name if def != null else "guardian"
			sentence = "Slew the %s on depth %d" % [guardian, event.amount]
		SimEvent.Kind.UPGRADE_BOUGHT:
			# The event is the same whether the player or auto-buy bought it.
			var ids: Array[StringName] = Content.upgrade_ids()
			if event.source_id >= 0 and event.source_id < ids.size():
				var upgrade: UpgradeDef = Content.upgrade(ids[event.source_id])
				sentence = "Bought %s, rank %d" % [upgrade.display_name, event.amount]
		SimEvent.Kind.MICROSKILL_LEARNED:
			var learner: Hero = _simulation.party.hero(event.source_id)
			var skill: MicroskillDef = _microskill(event.target_id)
			if learner != null and skill != null:
				sentence = "%s learned %s" % [learner.def().display_name, skill.display_name]
		SimEvent.Kind.SIDE_QUEST_DONE, SimEvent.Kind.SIDE_QUEST_MISSED:
			sentence = _quest_sentence(event)
	return sentence


## The sentence for a side quest done, passed by or sprung, or "".
func _quest_sentence(event: SimEvent) -> String:
	var ids: Array[StringName] = Content.side_quest_ids()
	if event.target_id < 0 or event.target_id >= ids.size():
		return ""
	var quest: SideQuestDef = Content.side_quest(ids[event.target_id])
	if event.kind == SimEvent.Kind.SIDE_QUEST_DONE:
		var done: String = QuestProps.DONE_WORDS.get(quest.id, quest.display_name)
		if quest.reward == SideQuestDef.Reward.XP:
			return "%s: %d XP each" % [done, event.amount]
		return "%s: %d gold" % [done, event.amount]
	var skill: MicroskillDef = _microskill(event.amount)
	var needs: String = skill.display_name if skill != null else "?"
	if event.flag:
		return "Sprang a %s: needs %s" % [quest.display_name, needs]
	return "Passed a %s: needs %s" % [quest.display_name, needs]


func _microskill(index: int) -> MicroskillDef:
	var ids: Array[StringName] = Content.microskill_ids()
	return Content.microskill(ids[index]) if index >= 0 and index < ids.size() else null


# --- Showing -------------------------------------------------------------------


func _build_panel() -> void:
	panel = HudPanel.new()
	panel.name = "JournalPanel"
	panel.visible = false
	add_child(panel)
	var title: Label = PixelText.label("Journal", &"yellow")
	title.name = "Title"
	title.position = Vector2(PADDING + 2.0, PADDING)
	panel.add_child(title)
	var hint: Label = PixelText.label("J close", &"slate")
	hint.name = "Hint"
	hint.position = Vector2(PANEL_WIDTH - PADDING - 2.0 - PixelText.width(hint.text), PADDING)
	panel.add_child(hint)
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = Palette.color(&"dusk")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.position = Vector2(PADDING, PADDING + TITLE_HEIGHT - 1.0)
	divider.size = Vector2(PANEL_WIDTH - PADDING * 2.0, 1.0)
	panel.add_child(divider)
	var y: float = PADDING + TITLE_HEIGHT + 2.0
	for i: int in SHOWN_LINES:
		var time: Label = PixelText.label("", &"steel")
		time.name = "Time%d" % i
		time.position = Vector2(PADDING + 2.0, y)
		panel.add_child(time)
		_time_labels.append(time)
		var line: Label = PixelText.label("", &"white" if i == 0 else &"silver")
		line.name = "Line%d" % i
		line.position = Vector2(TEXT_COLUMN, y)
		panel.add_child(line)
		_line_labels.append(line)
		y += LINE_HEIGHT
	_empty_label = PixelText.label("Nothing yet: the party's deeds will be written here", &"slate")
	_empty_label.name = "Empty"
	_empty_label.position = Vector2(PADDING + 2.0, PADDING + TITLE_HEIGHT + 2.0)
	panel.add_child(_empty_label)
	panel.size = Vector2(PANEL_WIDTH, y + PADDING)
	panel.position = Vector2(Hud.MARGIN, Hud.TOP_BAND + ShopPanel.DROP)


func _build_ticker() -> void:
	ticker = HudPanel.new()
	ticker.name = "Ticker"
	ticker.visible = false
	add_child(ticker)
	_ticker_label = PixelText.label("", &"white")
	_ticker_label.name = "Text"
	_ticker_label.position = Vector2(5, 2)
	ticker.add_child(_ticker_label)


func _fill_panel() -> void:
	for i: int in SHOWN_LINES:
		var has: bool = i < _sentences.size()
		_time_labels[i].visible = has
		_line_labels[i].visible = has
		if has:
			_time_labels[i].text = _times[i]
			_line_labels[i].text = _sentences[i]
	_empty_label.visible = _sentences.is_empty()


## Shows the ticker while its line is fresh, its text stepping down through FADE_COLOURS at the
## end, centred just above the party frames.
func _show_ticker() -> void:
	var fade: float = _ticker_age - TICKER_SECONDS
	var showing: bool = fade < FADE_STEP * FADE_COLOURS.size() and _ticker_label.text != ""
	ticker.visible = showing
	if not showing:
		return
	var colour: StringName = &"white"
	if fade >= 0.0:
		colour = FADE_COLOURS[mini(floori(fade / FADE_STEP), FADE_COLOURS.size() - 1)]
	_ticker_label.add_theme_color_override(&"font_color", Palette.color(colour))
	var width: float = PixelText.width(_ticker_label.text) + 10.0
	ticker.size = Vector2(width, TICKER_HEIGHT)
	var frames_top: float = Hud.SCREEN.y - Hud.MARGIN - HeroFrame.SIZE.y
	ticker.position = Vector2(
		floorf((Hud.SCREEN.x - width) / 2.0), frames_top - TICKER_GAP - TICKER_HEIGHT
	)


func _sheet() -> HeroSheet:
	var hud: Hud = get_parent() as Hud
	return hud.hero_sheet if hud != null else null


func _shop_is_open() -> bool:
	var hud: Hud = get_parent() as Hud
	return hud != null and hud.shop != null and hud.shop.is_open()
