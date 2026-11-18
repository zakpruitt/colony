class_name DefeatNote
extends Node
## The defeat note (spec 041): after a wipe, a small panel in the upper middle of the screen says
## what beat the party and where, the plainest true reason when there is one, and offers up to
## [constant MOST] things that would help, each a button one click away. It changes no rule.
##
## It listens to [signal World.sim_event]. Many ticks can arrive in one frame (a stall, or 4x), so
## the depth and the safe depth of a defeat are never read from the expedition when its events
## arrive, which may be after the revival: they are the expedition's at the end of the last frame
## ([method advance]) moved on by each [code]DEPTH_CHANGED[/code] and
## [code]STABLE_DEPTH_REACHED[/code] since (spec 046 R1). A lost fight's
## [code]ENCOUNTER_ENDED[/code] names the chamber, whose survivors ([method Expedition.monsters_in],
## a read that changes nothing, of the chamber's own record, which keeps them until the party wins
## there) are the monsters alive when the last hero fell; [code]PARTY_WIPED[/code] then works out
## the first line ([method wipe_line]; [method journal_line] is the journal's). Only a recent wipe
## ([method World.is_recent]) is told: one from a stall or the time away is not, and leaves a note
## already showing as it was (spec 046 R5). The note stays while the heroes are down and stand up
## again ([method FallenParty.is_telling]) and [constant LINGER_SECONDS] after, never counting down
## while the mouse is over it ([method point_at]), and whatever fight starts meanwhile; then its text steps down [constant FADE_COLOURS] and it goes. Text never
## fades by opacity.
##
## The suggestions are read again at every [method advance], so they follow the gold, except while
## the mouse is over the note: a click acts on what its button showed (spec 046 R3). Hold reads
## Holding only while the simulation's order is Hold, or has just been asked for (spec 046 R2). The
## note hides while the shop, a hero sheet, the tally, the area map or the away report is open
## (the windows of the UI layer, spec 058, float over it and do not hide it). It moves only in
## [method advance], so a test can step it exactly.

## What the note can suggest, in the order it prefers them.
enum Help { TALENTS, TRAIN, UPGRADE, HOLD }

## The most suggestions shown at once.
const MOST: int = 3
## The party this many depths or more below its safe depth is too deep: that is the reason given.
const TOO_DEEP: int = 2
## The font multiple of the WIPED banner ([CombatEffects]) in the middle of the screen; it pops one
## larger as it appears. The note's bottom keeps [constant WIPED_GAP] world pixels above it.
const WIPED_SCALE: int = 3
const WIPED_GAP: float = 6.0
## Seconds the note stays after the heroes stand, while the mouse is not over it.
const LINGER_SECONDS: float = 8.0
## Then the text steps down through these colours, each for FADE_STEP seconds,
## and the note goes.
const FADE_COLOURS: Array[StringName] = [&"silver", &"steel", &"slate"]
const FADE_STEP: float = 0.2
## Each suggestion's tooltip: one plain sentence.
const TIPS: Dictionary[Help, String] = {
	Help.TALENTS: "Opens the Talents tab of a hero with talent points: new abilities to take.",
	Help.TRAIN: "Opens this hero's Talents tab: paragon points make one hero stronger for good.",
	Help.UPGRADE: "Opens the Shop: upgrades make the whole party stronger.",
	Help.HOLD: "Orders the party to stay away from guardians and grow stronger first.",
}
const HOLDING_TIP: String = "The party stays away from guardians until Orders (O) sends it in."

## The note seen, on the sharp layer; the lines and buttons are its children.
var panel: DefeatNoteView
## One button per suggestion slot, left to right; a slot with no suggestion is hidden.
var buttons: Array[UiButton] = []

var _simulation: Simulation
var _world: World
var _hud: Hud
## True while the note is told (see [method is_shown]).
var _on_screen: bool = false
## The lines of the defeat being told, the first and maybe a second.
var _lines: Array[String] = []
## The suggestions showing, in order.
var _helps: Array[Help] = []
## The hero the Train suggestion opens, or -1.
var _trainee: int = -1
## True from a recent wipe until the heroes stand.
var _telling: bool = false
## Seconds the note still lingers after the heroes stood, or -1 when not lingering.
var _linger: float = -1.0
## Seconds into the fade once the linger is over, or -1 when not fading.
var _fade: float = -1.0
## Where the mouse is, in screen pixels.
var _mouse: Vector2 = UiTip.NOWHERE
## The suggestions the buttons show, as last laid out, and the heroes Train and Spend talent
## points showed then.
var _shown: Array[Help] = []
var _shown_trainee: int = -1
var _shown_spender: int = -1
## The hero the Spend talent points suggestion opens, or -1 (spec 055).
var _spender: int = -1
## The guardian of the defeat being told (or &""): Hold is offered against it.
var _guardian: StringName = &""
## True once Hold here was pressed for this defeat: the button stays, whatever the order.
var _held: bool = false
## The tick Hold was asked for at, or -1: until the simulation steps, it reads Holding.
var _hold_asked: int = -1
## The depth and the safe depth as the events have told them so far (spec 046 R1).
var _depth_now: int = 0
var _safe_now: int = 0
## The area those depths are stages of (spec 049).
var _area_now: StringName = &""
## The chamber of the fight just lost, as Vector2i(depth, index) (index -1 when none), the names
## of the monsters alive in it and its guardian (or &"").
var _lost_at: Vector2i = Vector2i(0, -1)
var _lost_names: Array[String] = []
var _lost_guardian: StringName = &""
## The last wipe worked out: the event, its first line, its depth, the safe depth then and its
## guardian (or &"").
var _wipe: SimEvent = null
var _wipe_line: String = ""
var _wipe_depth: int = 0
var _wipe_area: StringName = &""
var _wipe_safe: int = 0
var _wipe_guardian: StringName = &""
## Defeats in a row by one guardian: its depth (0 for none) and how many.
var _streak_depth: int = 0
var _streak: int = 0


func _init() -> void:
	name = "DefeatNote"


## Call once, before the first advance. [param world] may be null (then nothing is told, as
## nothing is recent); [param hud] may be null (the buttons then only reach the simulation).
func setup(simulation: Simulation, world: World, hud: Hud) -> void:
	_simulation = simulation
	_world = world
	_hud = hud
	_area_now = simulation.expedition.place
	panel = DefeatNoteView.new()
	buttons = panel.buttons
	for i: int in buttons.size():
		buttons[i].pressed.connect(press.bind(i))
		if hud != null and hud.frame_tip != null:
			hud.frame_tip.attach(buttons[i], _tip.bind(i))
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Follows the heroes standing up, runs the fade on by [param delta] seconds, reads the
## suggestions again and lays the note out. Called every frame by the HUD, after the world has
## told every event of the frame; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	# The world has told every event so far: the expedition's depths are those the events reached.
	_depth_now = _simulation.expedition.depth
	_safe_now = _simulation.expedition.last_stable_depth
	_area_now = _simulation.expedition.place
	_update(delta)


## The work of [method advance], without reading the expedition's depths: also called while the
## world is telling a frame's events.
func _update(delta: float) -> void:
	if _telling and _stood():
		_telling = false
		_linger = LINGER_SECONDS
	elif _hovered() and (_linger >= 0.0 or _fade >= 0.0):
		_linger = maxf(_linger, 0.0)  # read while the mouse rests on it: it waits
		_fade = -1.0
	elif _linger >= 0.0:
		_linger -= delta
		if _linger < 0.0:
			_fade = 0.0
	elif _fade >= 0.0:
		_fade += delta
		if _fade >= FADE_STEP * FADE_COLOURS.size():
			_fade = -1.0
	var told: bool = _telling or _linger >= 0.0 or _fade >= 0.0
	if told and not _hovered():
		_suggest()  # under the mouse, the row stays as it is
	_on_screen = told
	panel.visible = told
	if told:
		_show()


## True while the note is on screen.
func is_shown() -> bool:
	return _on_screen


## Moves the mouse to [param at], in the screen's 640x360 pixels (where input events are): while
## it is over the note, the note waits.
func point_at(at: Vector2) -> void:
	_mouse = at


## The note's first line, and its second when there is one.
func lines() -> Array[String]:
	return _lines.duplicate()


## The button texts showing, in order.
func suggestions() -> Array[String]:
	var texts: Array[String] = []
	for help: Help in _helps:
		texts.append(_text(help))
	return texts


## What clicking button [param index] does, by the suggestion that button showed: opens the
## Talents tab of a hero with talent points (spec 055) or of the hero it named, opens the shop, or
## sets the guardian order to Hold.
func press(index: int) -> void:
	if index < 0 or index >= _shown.size():
		return
	match _shown[index]:
		Help.TALENTS:
			if _hud != null and _hud.hero_windows != null:
				_hud.hero_windows.open(_shown_spender, HeroWindow.Page.TALENTS)
		Help.TRAIN:
			if _hud != null and _hud.hero_windows != null:
				_hud.hero_windows.open(_shown_trainee, HeroWindow.Page.TALENTS)
		Help.UPGRADE:
			if _hud != null and _hud.shop != null:
				_hud.shop.open()
		Help.HOLD:
			if not _holding():
				_held = true
				_hold_asked = _simulation.tick
				_simulation.set_guardian_order(Expedition.GuardianOrder.HOLD)
	_update(0.0)


## The first line for the wipe [param event] ([code]Beaten by the Slime King on Mossy Hollow
## 5[/code]),
## worked out once per wipe from the fight lost and the depths the events had reached.
func wipe_line(event: SimEvent) -> String:
	if event == _wipe:
		return _wipe_line
	_wipe = event
	if _wipe_area != _area_now:
		_streak_depth = 0
	_wipe_depth = _depth_now
	_wipe_area = _area_now
	_wipe_safe = _safe_now
	_wipe_guardian = &""
	var names: Array[String] = []
	if _lost_at.y >= 0 and _lost_at.x == _wipe_depth:
		names = _lost_names
		_wipe_guardian = _lost_guardian
	_lost_at = Vector2i(0, -1)
	_lost_names = []
	_lost_guardian = &""
	if _wipe_guardian != &"":
		_streak = _streak + 1 if _streak_depth == _wipe_depth else 1
		_streak_depth = _wipe_depth
		var who: String = Content.monster(_wipe_guardian).display_name
		_wipe_line = "Beaten by the %s on %s" % [who, _place(_wipe_depth)]
		if _streak > 1:
			_wipe_line += " (%d times)" % _streak
	else:
		_streak_depth = 0
		_streak = 0
		_wipe_line = "Beaten on %s" % _place(_wipe_depth)
		if not names.is_empty():
			_wipe_line += " by " + crowd(names)
	return _wipe_line


## The journal's line for the wipe [param event] (spec 041 R6, spec 046 R6): the first line and
## where the party falls back to, [code]Beaten by the Slime King on Mossy Hollow 5; falling back
## to Mossy Hollow 4[/code], or [code]; regrouping there[/code] when it fell on its safe stage.
func journal_line(event: SimEvent) -> String:
	var line: String = wipe_line(event)
	if _wipe_safe == _wipe_depth:
		return line + "; regrouping there"
	return line + "; falling back to %s" % _place(_wipe_safe)


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
		SimEvent.Kind.DEPTH_CHANGED:
			_depth_now = event.amount
		SimEvent.Kind.AREA_CHANGED:
			var ids: Array[StringName] = Content.area_ids()
			if event.amount >= 0 and event.amount < ids.size():
				_area_now = ids[event.amount]
				_safe_now = _simulation.area_progress(_area_now).x
		SimEvent.Kind.STABLE_DEPTH_REACHED:
			_safe_now = event.amount
		SimEvent.Kind.ENCOUNTER_STARTED:
			_lost_at = Vector2i(0, -1)
		SimEvent.Kind.ENCOUNTER_ENDED:
			_lost_at = Vector2i(0, -1)
			if not event.flag:
				_lost(event.amount)
		SimEvent.Kind.GUARDIAN_SLAIN:
			if event.amount == _streak_depth:
				_streak_depth = 0
				_streak = 0
		SimEvent.Kind.PARTY_WIPED:
			wipe_line(event)
			if _world != null and _world.is_recent(event):
				_tell()


## Remembers the fight just lost in chamber [param chamber_index] of the depth the events have
## reached: where, and the monsters alive in it.
func _lost(chamber_index: int) -> void:
	_lost_at = Vector2i(_depth_now, chamber_index)
	_lost_names = []
	_lost_guardian = &""
	for monster: Combatant in _simulation.expedition.monsters_in(_lost_at.x, _lost_at.y):
		var def: MonsterDef = Content.monster(monster.def_id)
		if def == null:
			continue
		if def.guardian:
			_lost_guardian = def.id
		_lost_names.append(def.display_name)


## Starts telling the wipe just worked out.
func _tell() -> void:
	_guardian = _wipe_guardian
	_lines = [_wipe_line]
	var reason: String = _reason()
	if not reason.is_empty():
		_lines.append(reason)
	_held = false
	_hold_asked = -1
	_telling = true
	_linger = -1.0
	_fade = -1.0
	_suggest()
	_update(0.0)


## The plainest true reason for the wipe just worked out, or "": a guardian above the heroes'
## level, then a depth too far below the safe one.
func _reason() -> String:
	if _wipe_guardian != &"":
		var lowest: int = _lowest_level()
		var area: AreaDef = Content.area(_wipe_area)
		var level: int = area.level_at(_wipe_depth) if area != null else _wipe_depth
		var wanted: int = Goals.guardian_level(level)
		if lowest < wanted:
			return "Heroes are level %d; it is balanced for about %d" % [lowest, wanted]
	if _wipe_depth - _wipe_safe >= TOO_DEEP:
		var below: int = _wipe_depth - _wipe_safe
		return "%s is %d past the safe stage" % [_place(_wipe_depth), below]
	return ""


## True while the guardian order is Hold, or Hold was asked for and the simulation has not stepped
## since.
func _holding() -> bool:
	if _hold_asked >= 0 and _hold_asked == _simulation.tick:
		return true
	return _simulation.expedition.guardian_order == Expedition.GuardianOrder.HOLD


## Reads which suggestions apply now, at most [constant MOST] in [enum Help] order; with four,
## Buy an upgrade is the one left out.
func _suggest() -> void:
	var e: Expedition = _simulation.expedition
	var gold: int = _simulation.party.gold
	_helps.clear()
	_spender = -1
	for hero: Hero in _simulation.party.heroes:
		if _spender < 0 and hero.talent_points() > 0:
			_spender = hero.id
	if _spender >= 0:
		_helps.append(Help.TALENTS)  # spec 055 R8: ahead of the other advice
	_trainee = _trainee_with_points()
	if _trainee >= 0:
		_helps.append(Help.TRAIN)
	if _cheapest_upgrade() > 0 and _cheapest_upgrade() <= gold:
		_helps.append(Help.UPGRADE)
	if _guardian != &"" and (_held or e.guardian_order == Expedition.GuardianOrder.CHALLENGE):
		_helps.append(Help.HOLD)
	# Spec 055: with talent points as well, the upgrade gives way, never Hold here.
	if _helps.size() > MOST:
		_helps.erase(Help.UPGRADE)
	_helps = _helps.slice(0, MOST)


func _text(help: Help) -> String:
	match help:
		Help.TRAIN:
			var hero: Hero = _simulation.party.hero(_trainee)
			return "Train %s" % (hero.def().display_name if hero != null else "a hero")
		Help.UPGRADE:
			return "Buy an upgrade"
		Help.TALENTS:
			return "Spend talent points"
	return "Holding" if _holding() else "Hold here"


func _tip(index: int) -> String:
	if index < 0 or index >= _shown.size():
		return ""
	if _shown[index] == Help.HOLD and _holding():
		return HOLDING_TIP
	return TIPS[_shown[index]]


## The id of the first hero in formation with a paragon point to spend (spec 051), or -1.
func _trainee_with_points() -> int:
	for hero: Hero in _simulation.party.heroes:
		if hero.paragon_points() > 0:
			return hero.id
	return -1


## The cheapest price of any camp upgrade's next rank, or 0 if none can be bought. One whose
## resource the party lacks cannot (spec 052).
func _cheapest_upgrade() -> int:
	var cheapest: int = 0
	for id: StringName in Content.upgrade_ids():
		var price: int = _simulation.upgrades.cost(id)
		if not _simulation.upgrades.has_resource_for(id, _simulation.party):
			continue
		if price > 0 and (cheapest == 0 or price < cheapest):
			cheapest = price
	return cheapest


func _lowest_level() -> int:
	return PartyLevels.lowest(_simulation.party)


## True while the mouse is over the note's panel.
func _hovered() -> bool:
	return _on_screen and panel.is_inside_tree() and Hud.on_screen(panel).has_point(_mouse)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		point_at(motion.position)  # the note lies over every window (spec 062 R4)


## True once the party is up and the heroes have stood (spec 038), or the world tells nothing.
func _stood() -> bool:
	if _simulation.expedition.state == Expedition.State.REVIVING:
		return false
	return _world == null or not _world.fallen_party.is_telling()


# --- Showing -------------------------------------------------------------------


## Lays the note out: its lines over its buttons, centred across the room with its bottom just
## above WIPED.
func _show() -> void:
	var colour: StringName = &""
	if _fade >= 0.0:
		colour = FADE_COLOURS[mini(floori(_fade / FADE_STEP), FADE_COLOURS.size() - 1)]
	var texts: Array[String] = []
	var lit: Array[bool] = []
	for help: Help in _helps:
		texts.append(_text(help))
		lit.append(help == Help.HOLD and _holding())
	_shown = _helps.duplicate()
	_shown_trainee = _trainee
	_shown_spender = _spender
	var wiped: Rect2 = FxText.box("WIPED", PixelText.SIZE * (WIPED_SCALE + 1))
	var bottom: float = Hud.SCREEN.y / 2.0 + wiped.position.y - WIPED_GAP
	var room_width: float = Hud.SCREEN.x
	if _hud != null:
		room_width = _hud.note_room().x
		bottom = _hud.world_to_note(Vector2(0.0, bottom)).y
	panel.show_note(_lines, texts, lit, colour, room_width, bottom)


## [param stage] of the area of the wipe, as the screen names it (spec 049).
func _place(stage: int) -> String:
	return PlaceText.of(_wipe_area, stage)
