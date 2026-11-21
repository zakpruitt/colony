extends "res://tests/support/hud_fixture.gd"
## The fixture both of spec 052's acceptance test files extend: its constants, the HUD built
## on a seeded simulation, and the helpers they share. It holds no tests itself.
##
## The view tests build a World on a seeded simulation with the CombatEffects and the Hud on it,
## every _process turned off, on a canvas layer above GUT's (as Main has it), and drive them a
## frame at a time.

const SEED: int = 42
const MOSSY: StringName = &"mossy_hollow"
const CLAYPITS: StringName = &"claypits"
const CRYPT: StringName = &"old_crypt"
const EMBER: StringName = &"ember_deep"
const GLOWCAPS: StringName = &"glowcaps"
const CLAY: StringName = &"clay"
const BONES: StringName = &"old_bones"
const EMBERS: StringName = &"embers"
## Strong enough to win every fight in the first two areas.
const STRONG_LEVEL: int = 25
## Where the mouse is when it is over nothing of the HUD's.
const AWAY: Vector2 = Vector2(320, 200)
## Spec 016's recorded hashes (an untouched simulation, every 1500 ticks up to 20 minutes) as they
## were on dev before this spec: R11 shows the game is the same once the resources are left out.
const HASHES_BEFORE: Dictionary = {
	3:
	[
		3793668176,
		1214036140,
		3894860287,
		816719926,
		637789871,
		3221476330,
		3183358185,
		3928131485,
	],
	11:
	[
		3372118570,
		622540149,
		1375365754,
		1948124930,
		1885808759,
		1752451346,
		2263356909,
		2125969758,
	],
}
## R10: minutes the Mossy-only party plays, and the most it may then take to hold clay.
const MOSSY_MINUTES: float = 30.0
const CLAY_MINUTES: float = 5.0
## R2: kills of each size rolled for a drop.
const KILLS: int = 200

var _heard: Array[SimEvent] = []


func after_each() -> void:
	super()
	mouse_move(AWAY)
	_heard.clear()


# --- Helpers -------------------------------------------------------------------


func _build_hud(with_ui: bool = true, layered: bool = true) -> void:
	super(with_ui, layered)
	_frame_parts = [_fx.advance, _hud.advance, _ui.bar.advance]
	_world.sim_event.connect(func(event: SimEvent) -> void: _heard.append(event))


func _index(id: StringName) -> int:
	return Content.resource_ids().find(id)


## The tooltip shown after resting the mouse on [param control]: the UI layer's for a control in
## a window (spec 059), the frame of the screen's otherwise (spec 061; spec 062: the note after a
## defeat too).
func _tip(control: Control) -> String:
	var framed: bool = _hud.screen_frame.is_ancestor_of(control)
	if framed or _hud.defeat_note.panel.is_ancestor_of(control):
		_hud.frame_tip.point_at(control.get_global_rect().get_center())
		_hud.frame_tip.advance(UiTip.DELAY + 0.01)
		var shown: String = _hud.frame_tip.shown_text()
		_hud.frame_tip.point_at(UiTip.NOWHERE)
		_hud.frame_tip.advance(0.0)
		return shown
	var card: UiTip.Card = _hud.shop.tip.card_for(control)  # spec 065: a shop card's is a card
	return card.body if card != null else _hud.shop.tip.text_for(control)


func _heard_of(kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in _heard:
		if event.kind == kind:
			found.append(event)
	return found


## What [param sim] did over [param ticks] ticks: every kill as [size, stage, monster id, def id],
## the drops by monster (or worker) id, the side quests done, and all the events.
func _watch(sim: Simulation, ticks: int) -> Dictionary:
	var kills: Array = []
	var drops: Dictionary = {}
	var events: Array[SimEvent] = []
	for i: int in ticks:
		var fight: Battle = sim.expedition.battle
		var stage: int = sim.expedition.depth
		sim.step()
		for event: SimEvent in sim.drain_events():
			events.append(event)
			if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
				var dead: Combatant = fight.combatant(event.source_id) if fight != null else null
				if dead != null:
					var def: MonsterDef = Content.monster(dead.def_id)
					kills.append([def.size, stage, dead.id, dead.def_id])
			elif event.kind == SimEvent.Kind.RESOURCE_GAINED:
				drops[event.source_id] = event
	return {"kills": kills, "drops": drops, "events": events}


## Of [param watched]'s kills of size [param size], the share that dropped something.
func _drop_share(watched: Dictionary, size: MonsterDef.Size) -> Vector2i:
	var dropped: int = 0
	var killed: int = 0
	for kill: Array in watched["kills"]:
		if kill[0] != size:
			continue
		killed += 1
		if (watched["drops"] as Dictionary).has(kill[2]):
			dropped += 1
	return Vector2i(dropped, killed)


## A party at [param level] sent to the Claypits (opened by hand), arrived and standing there.
func _in_claypits(level: int) -> Simulation:
	var sim := Simulation.new(SEED)
	set_party_level(sim, level)
	sim.expedition.travel.open[CLAYPITS] = true
	sim.set_destination(CLAYPITS, 1)
	for i: int in 400:
		sim.step()
		if sim.expedition.area == CLAYPITS and sim.expedition.state != Expedition.State.JOURNEYING:
			break
	sim.drain_events()
	return sim


## [param sim]'s state hash as it was before this spec: without the resources held and the
## guardians beaten (spec 016 R5's recorded hashes are of this).
func _hash_before_resources(sim: Simulation) -> int:
	var party_parts: Array = sim.party.hash_parts()
	if sim.party.has_resources():
		party_parts.pop_back()
	var run_parts: Array = sim.expedition.hash_parts()
	for part: Variant in run_parts:
		if part is Array and (part as Array).size() == 4 and (part as Array)[0] == "areas":
			var travel_parts: Array = (part as Array)[3]
			var last: Variant = travel_parts.back()
			if last is Array and (last as Array).size() == 2 and (last as Array)[0] == "beaten":
				travel_parts.pop_back()
	var parts: Array = [sim._seed, sim.tick, party_parts, run_parts]
	if sim.upgrades.any():
		parts.append(sim.upgrades.hash_parts())
	if sim.auto_buy:
		parts.append("auto_buy")
	return hash(parts)


func _offers_upgrade_goal() -> bool:
	for goal: Goals.Goal in _hud.goals.applicable():
		if goal.kind == Goals.Kind.UPGRADE:
			return true
	return false


## Plays to the next fight and loses it, a frame a tick. True once the party is down.
func _lose_a_fight() -> bool:
	for i: int in 3000:
		_frame()
		if _sim.expedition.battle != null:
			break
	if _sim.expedition.battle == null:
		return false
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	for i: int in 3000:
		_frame()
		if _sim.expedition.state == Expedition.State.REVIVING:
			return true
	return false


func _build_hud_on(sim: Simulation) -> void:
	_sim = sim
	_build_hud()


func _journal_count(sentence: String) -> int:
	var count: int = 0
	for line: String in _hud.journal.lines():
		if line.ends_with(sentence):
			count += 1
	return count
