class_name DefeatNote
extends Control
## The defeat note (spec 041): after a wipe, a small panel in the upper middle of the screen says
## what beat the party and where, the plainest true reason when there is one, and offers up to
## [constant MOST] things that would help, each a button one click away. It changes no rule.
##
## It listens to [signal World.sim_event]. A lost fight's [code]ENCOUNTER_ENDED[/code] names the
## chamber, whose survivors ([method Expedition.monsters_in], a read that changes nothing) are the
## monsters alive when the last hero fell; [code]PARTY_WIPED[/code] then makes the note's lines
## ([method wipe_line], which the journal uses for its own line). Only a recent wipe
## ([method World.is_recent]) is told: one from a stall or the time away is not. The note stays
## while the heroes are down and stand up again ([method FallenParty.is_telling]), then its text
## steps down [constant FADE_COLOURS] and it goes. Text never fades by opacity.
##
## The suggestions are read again at every [method advance], so they follow the gold. The note
## hides while the shop, a hero sheet, the journal, help, orders or the away report is open. It
## moves only in [method advance], so a test can step it exactly.

## The player asked for a target depth through the note (Go up a depth): the HUD shows it at once.
signal target_asked(depth: int)

## What the note can suggest, in the order it prefers them.
enum Help { TRAIN, UPGRADE, HOLD, GO_UP }

## The most suggestions shown at once.
const MOST: int = 3
## The party this many depths or more below its safe depth is too deep: that is the reason given.
const TOO_DEEP: int = 2
## The font multiple of the WIPED banner ([CombatEffects]) in the middle of the screen; it pops one
## larger as it appears. The note's bottom keeps [constant WIPED_GAP] pixels above it.
const WIPED_SCALE: int = 3
const WIPED_GAP: float = 6.0
## Space inside the border, a line's height, and the space above the row of buttons.
const PADDING: Vector2 = Vector2(6, 4)
const LINE: float = 10.0
const BUTTONS_GAP: float = 3.0
## Pixels between two buttons.
const BUTTON_GAP: float = 4.0
## Once the heroes stand, the text steps down through these colours, each for FADE_STEP seconds,
## and the note goes.
const FADE_COLOURS: Array[StringName] = [&"silver", &"steel", &"slate"]
const FADE_STEP: float = 0.2
## Each suggestion's tooltip: one plain sentence.
const TIPS: Dictionary[Help, String] = {
	Help.TRAIN: "Opens this hero's Training tab: training makes one hero stronger for good.",
	Help.UPGRADE: "Opens the Shop: upgrades make the whole party stronger.",
	Help.HOLD: "Orders the party to stay away from guardians and grow stronger first.",
	Help.GO_UP: "Sets the target one depth up, where the monsters are weaker.",
}
const HOLDING_TIP: String = "The party stays away from guardians until Orders (O) sends it in."

## The panel seen; the lines and buttons are its children.
var panel: HudPanel
## One button per suggestion slot, left to right; a slot with no suggestion is hidden.
var buttons: Array[HudButton] = []

var _simulation: Simulation
var _world: World
var _hud: Hud
var _labels: Array[Label] = []
## The lines of the defeat being told, the first and maybe a second.
var _lines: Array[String] = []
## The suggestions showing, in order.
var _helps: Array[Help] = []
## The hero the Train suggestion opens, or -1.
var _trainee: int = -1
## True from a recent wipe until the heroes stand.
var _telling: bool = false
## Seconds into the fade once they stand, or -1 when not fading.
var _fade: float = -1.0
## The defeat being told: its depth, the safe depth then, and its guardian (or &"").
var _depth: int = 0
var _safe: int = 0
var _guardian: StringName = &""
## True once Hold here was pressed for this defeat: the button reads Holding.
var _held: bool = false
## The chamber of the fight just lost, as Vector2i(depth, index); index -1 when none.
var _lost_at: Vector2i = Vector2i(0, -1)
## The last wipe worked out, and its first line.
var _wipe: SimEvent = null
var _wipe_line: String = ""
## Defeats in a row by one guardian: its depth (0 for none) and how many.
var _streak_depth: int = 0
var _streak: int = 0


func _init() -> void:
	name = "DefeatNote"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO
	visible = false


## Call once, before the first advance. [param world] may be null (then nothing is told, as
## nothing is recent); [param hud] may be null (the buttons then only reach the simulation).
func setup(simulation: Simulation, world: World, hud: Hud) -> void:
	_simulation = simulation
	_world = world
	_hud = hud
	panel = HudPanel.new()
	panel.name = "DefeatPanel"
	add_child(panel)
	for i: int in 2:
		var label: Label = PixelText.label("", &"white" if i == 0 else &"silver")
		label.name = "Line%d" % i
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		_labels.append(label)
	for i: int in MOST:
		var button := HudButton.new("")
		button.name = "Help%d" % i
		button.visible = false
		button.pressed.connect(press.bind(i))
		panel.add_child(button)
		buttons.append(button)
		if hud != null and hud.tooltip != null:
			hud.tooltip.tip([button], _tip.bind(i))
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Follows the heroes standing up, runs the fade on by [param delta] seconds, reads the
## suggestions again and lays the note out. Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	if _telling and _stood():
		_telling = false
		_fade = 0.0
	elif not _telling and _fade >= 0.0:
		_fade += delta
		if _fade >= FADE_STEP * FADE_COLOURS.size():
			_fade = -1.0
	var told: bool = _telling or _fade >= 0.0
	if told:
		_suggest()
	visible = told and not _covered()
	if visible:
		_show()


## True while the note is on screen.
func is_shown() -> bool:
	return visible


## The note's first line, and its second when there is one.
func lines() -> Array[String]:
	return _lines.duplicate()


## The button texts showing, in order.
func suggestions() -> Array[String]:
	var texts: Array[String] = []
	for help: Help in _helps:
		texts.append(_text(help))
	return texts


## What clicking button [param index] does: opens the cheapest hero's Training tab, opens the
## shop, sets the guardian order to Hold, or lowers the target depth by one.
func press(index: int) -> void:
	if index < 0 or index >= _helps.size():
		return
	match _helps[index]:
		Help.TRAIN:
			if _hud != null and _hud.hero_sheet != null:
				_hud.hero_sheet.open_page(HeroSheet.Page.TRAINING)
				_hud.hero_sheet.open(_trainee)
		Help.UPGRADE:
			if _hud != null and _hud.shop != null:
				_hud.shop.open()
		Help.HOLD:
			if not _held:
				_held = true
				_simulation.set_guardian_order(Expedition.GuardianOrder.HOLD)
		Help.GO_UP:
			var from: int = _simulation.expedition.target_depth
			if _hud != null and _hud.target_label != null and _hud.target_label.text.is_valid_int():
				from = _hud.target_label.text.to_int()  # a target asked for and not yet applied
			var target: int = maxi(from - 1, 1)
			_simulation.set_target_depth(target)
			target_asked.emit(target)
	advance(0.0)


## The first line for the wipe [param event] ([code]Beaten by the Slime King on depth 5[/code]),
## worked out once per wipe; the journal writes it as its line for the wipe (spec 041 R6).
func wipe_line(event: SimEvent) -> String:
	if event == _wipe:
		return _wipe_line
	_wipe = event
	var e: Expedition = _simulation.expedition
	_depth = e.depth
	_safe = e.last_stable_depth
	_guardian = &""
	var names: Array[String] = []
	if _lost_at.y >= 0 and _lost_at.x == _depth:
		for monster: Combatant in e.monsters_in(_lost_at.x, _lost_at.y):
			var def: MonsterDef = Content.monster(monster.def_id)
			if def == null:
				continue
			if def.guardian:
				_guardian = def.id
			names.append(def.display_name)
	_lost_at = Vector2i(0, -1)
	if _guardian != &"":
		_streak = _streak + 1 if _streak_depth == _depth else 1
		_streak_depth = _depth
		var who: String = Content.monster(_guardian).display_name
		_wipe_line = "Beaten by the %s on depth %d" % [who, _depth]
		if _streak > 1:
			_wipe_line += " (%d times)" % _streak
	else:
		_streak_depth = 0
		_streak = 0
		_wipe_line = "Beaten on depth %d" % _depth
		if not names.is_empty():
			_wipe_line += " by " + crowd(names)
	return _wipe_line


## Monster names as a crowd, grouped by name in the order met, lower case:
## [code]3 ogres[/code], [code]2 slimes and a cave bat[/code]; "" for none.
static func crowd(names: Array[String]) -> String:
	var order: Array[String] = []
	var counts: Dictionary[String, int] = {}
	for each: String in names:
		if not counts.has(each):
			order.append(each)
		counts[each] = counts.get(each, 0) + 1
	var parts: Array[String] = []
	for each: String in order:
		var lower: String = each.to_lower()
		if counts[each] == 1:
			parts.append(("an " if lower.left(1) in ["a", "e", "i", "o", "u"] else "a ") + lower)
		else:
			parts.append("%d %ss" % [counts[each], lower])
	if parts.size() <= 1:
		return "" if parts.is_empty() else parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]


# --- Reacting ------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.ENCOUNTER_STARTED:
			_lost_at = Vector2i(0, -1)
		SimEvent.Kind.ENCOUNTER_ENDED:
			_lost_at = Vector2i(0, -1)
			if not event.flag:
				_lost_at = Vector2i(_simulation.expedition.depth, event.amount)
		SimEvent.Kind.GUARDIAN_SLAIN:
			if event.amount == _streak_depth:
				_streak_depth = 0
				_streak = 0
		SimEvent.Kind.PARTY_WIPED:
			wipe_line(event)
			if _world != null and _world.is_recent(event):
				_tell()


## Starts telling the wipe just worked out.
func _tell() -> void:
	_lines = [_wipe_line]
	var reason: String = _reason()
	if not reason.is_empty():
		_lines.append(reason)
	_held = false
	_telling = true
	_fade = -1.0
	advance(0.0)


## The plainest true reason for the defeat, or "": a guardian above the heroes' level, then a
## depth too far below the safe one.
func _reason() -> String:
	if _guardian != &"":
		var lowest: int = _lowest_level()
		var wanted: int = Goals.guardian_level(_depth)
		if lowest < wanted:
			return "Heroes are level %d; it is balanced for about %d" % [lowest, wanted]
	if _depth - _safe >= TOO_DEEP:
		return "Depth %d is %d below the safe depth" % [_depth, _depth - _safe]
	return ""


## Reads which suggestions apply now, the first [constant MOST] in [enum Help] order.
func _suggest() -> void:
	var e: Expedition = _simulation.expedition
	var gold: int = _simulation.party.gold
	_helps.clear()
	_trainee = _cheapest_trainee(gold)
	if _trainee >= 0:
		_helps.append(Help.TRAIN)
	if _cheapest_upgrade() > 0 and _cheapest_upgrade() <= gold:
		_helps.append(Help.UPGRADE)
	if _guardian != &"" and (_held or e.guardian_order == Expedition.GuardianOrder.CHALLENGE):
		_helps.append(Help.HOLD)
	if _guardian == &"" and _depth > _safe:
		_helps.append(Help.GO_UP)
	_helps = _helps.slice(0, MOST)


func _text(help: Help) -> String:
	match help:
		Help.TRAIN:
			var hero: Hero = _simulation.party.hero(_trainee)
			return "Train %s" % (hero.def().display_name if hero != null else "a hero")
		Help.UPGRADE:
			return "Buy an upgrade"
		Help.HOLD:
			return "Holding" if _held else "Hold here"
	return "Go up a depth"


func _tip(index: int) -> String:
	if index < 0 or index >= _helps.size():
		return ""
	if _helps[index] == Help.HOLD and _held:
		return HOLDING_TIP
	return TIPS[_helps[index]]


## The id of the hero with the cheapest training [param gold] affords (the first on a tie), or -1.
func _cheapest_trainee(gold: int) -> int:
	var best: int = -1
	var best_price: int = 0
	for hero: Hero in _simulation.party.heroes:
		for id: StringName in Content.training_ids():
			var price: int = hero.training_cost(id)
			if price <= 0 or price > gold:
				continue
			if best < 0 or price < best_price:
				best = hero.id
				best_price = price
	return best


## The cheapest price of any camp upgrade's next rank, or 0 if none can be bought.
func _cheapest_upgrade() -> int:
	var cheapest: int = 0
	for id: StringName in Content.upgrade_ids():
		var price: int = _simulation.upgrades.cost(id)
		if price > 0 and (cheapest == 0 or price < cheapest):
			cheapest = price
	return cheapest


func _lowest_level() -> int:
	var lowest: int = 0
	for hero: Hero in _simulation.party.heroes:
		if lowest == 0 or hero.level < lowest:
			lowest = hero.level
	return lowest


## True once the party is up and the heroes have stood (spec 038), or the world tells nothing.
func _stood() -> bool:
	if _simulation.expedition.state == Expedition.State.REVIVING:
		return false
	return _world == null or not _world.fallen_party.is_telling()


## True while a panel the note would sit beside is open.
func _covered() -> bool:
	if _hud == null:
		return false
	for open: bool in [
		_hud.shop != null and _hud.shop.is_open(),
		_hud.hero_sheet != null and _hud.hero_sheet.is_open(),
		_hud.journal != null and _hud.journal.is_open(),
		_hud.help != null and _hud.help.is_open(),
		_hud.orders != null and _hud.orders.is_open(),
	]:
		if open:
			return true
	var layer: Node = _hud.get_parent()
	if layer != null:
		for child: Node in layer.get_children():
			if child is AwayPanel and not child.is_queued_for_deletion():
				return true
	return false


# --- Showing -------------------------------------------------------------------


## Lays the note out: its lines over its buttons, the panel centred across the screen with its
## bottom just above WIPED.
func _show() -> void:
	var colour: StringName = &""
	if _fade >= 0.0:
		colour = FADE_COLOURS[mini(floori(_fade / FADE_STEP), FADE_COLOURS.size() - 1)]
	var width: float = 0.0
	var y: float = PADDING.y - 1.0
	for i: int in _labels.size():
		var label: Label = _labels[i]
		label.visible = i < _lines.size()
		if not label.visible:
			continue
		if label.text != _lines[i]:
			label.text = _lines[i]
			label.reset_size()
		var own: StringName = &"white" if i == 0 else &"silver"
		label.add_theme_color_override(
			&"font_color", Palette.color(own if colour == &"" else colour)
		)
		width = maxf(width, PixelText.width(_lines[i]))
		label.position.y = y
		y += LINE
	var row: float = 0.0
	for i: int in buttons.size():
		var button: HudButton = buttons[i]
		button.visible = i < _helps.size()
		if not button.visible:
			continue
		var text: String = _text(_helps[i])
		if button.text != text:
			button.text = text
		button.lit = _helps[i] == Help.HOLD and _held
		button.text_colour = colour
		row += button.size.x + (BUTTON_GAP if row > 0.0 else 0.0)
	width = maxf(width, row)
	var full: float = width + PADDING.x * 2.0
	for label: Label in _labels:
		label.position.x = floorf((full - PixelText.width(label.text)) / 2.0)
	var x: float = floorf((full - row) / 2.0)
	if not _helps.is_empty():
		y += BUTTONS_GAP
		for i: int in _helps.size():
			buttons[i].position = Vector2(x, y)
			x += buttons[i].size.x + BUTTON_GAP
		y += HudButton.HEIGHT
	panel.size = Vector2(full, y + PADDING.y)
	var wiped: Rect2 = FxText.box("WIPED", PixelText.SIZE * (WIPED_SCALE + 1))
	var bottom: float = Hud.SCREEN.y / 2.0 + wiped.position.y - WIPED_GAP
	panel.position = Vector2(floorf((Hud.SCREEN.x - full) / 2.0), floorf(bottom - panel.size.y))
	panel.queue_redraw()
