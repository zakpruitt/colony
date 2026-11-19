class_name DepthLadder
extends RefCounted
## What the stage list says about each stage: its marks, how it looks for this party and its line
## in words, and what a click asks for. This decides only; [StageList] draws the stages on the
## sharp layer and hears the mouse.
##
## Every mark is read from the simulation each time it is asked for ([method marks]): the party's
## stage, the safe stage, held (at or above the safe stage), visited (reached since), never reached,
## the target and a guardian's stage (crossed out while its guardian is beaten), so nothing can
## drift. [method ask] sets a new target, as the HUD's [code]-[/code] and [code]+[/code] do, and
## says once in the journal's ticker when it is dangerous.

## How a stage looks for this party: see [method risk].
enum Risk { SAFE, REACHABLE, DANGEROUS }

## What [method hover_text] adds to a stage that can be clicked.
const CLICK_HINT: String = "Click to send the party here"
## A stage number's colour for each risk: none of them the white, yellow or green of the party's,
## the target's or the safe stage's marks.
const RISK_COLOURS: Dictionary[Risk, StringName] = {
	Risk.SAFE: &"cyan",
	Risk.REACHABLE: &"orange",
	Risk.DANGEROUS: &"red",
}

var _simulation: Simulation
## The journal the dangerous click is written to, or null.
var _journal: Journal
## A target asked for that the simulation has not applied yet (it applies on the next tick), or 0.
var _asked_target: int = 0


func _init(simulation: Simulation, journal: Journal = null) -> void:
	_simulation = simulation
	_journal = journal


## Forgets an asked target once the simulation has applied it. Called every frame.
func advance() -> void:
	if _asked_target > 0 and _simulation.expedition.target_depth == _asked_target:
		_asked_target = 0


## How the stage at [param level_depth] looks for this party, from its lowest hero level L: safe
## at or above the safe stage, within reach down to stage L + 1, dangerous below that.
## A rough guide, not a promise: it loosely follows the guardians' balance (a party of level
## stage + 4 beats the guardian of that stage), and ordinary stages are easier than their
## guardians. It changes no rule: any stage can still be chosen.
func risk(level_depth: int) -> Risk:
	var e: Expedition = _simulation.expedition
	var lowest: int = PartyLevels.lowest(_simulation.party)
	return StageRisk.judge(level_depth, e.last_stable_depth, e.level_at(level_depth), lowest)


## What the stage at [param depth] shows: any of &"party", &"safe", &"held", &"visited",
## &"unreached", &"target", &"guardian", &"guardian_beaten". Exactly one of held, visited and
## unreached; a beaten guardian's stage has both guardian marks.
func marks(depth: int) -> Array[StringName]:
	var found: Array[StringName] = []
	if depth < 1:
		return found
	var e: Expedition = _simulation.expedition
	if depth == e.depth:
		found.append(&"party")
	if depth == e.last_stable_depth:
		found.append(&"safe")
	if depth <= e.last_stable_depth:
		found.append(&"held")
	elif depth <= maxi(e.deepest_depth, e.depth):
		found.append(&"visited")
	else:
		found.append(&"unreached")
	if depth == shown_target():
		found.append(&"target")
	if e.guardian_of(depth) != &"":
		found.append(&"guardian")
		if guardian_beaten(depth):
			found.append(&"guardian_beaten")
	return found


## The name of the guardian of [param depth] ("Slime King"), or "" for a stage with none.
func guardian_name(depth: int) -> String:
	var id: StringName = _simulation.expedition.guardian_of(depth) if depth >= 1 else &""
	if id == &"":
		return ""
	var def: MonsterDef = Content.monster(id)
	return def.display_name if def != null else "Guardian"


## True while the guardian of [param depth] is beaten: its chamber holds nobody and no fight with
## it is going on there.
func guardian_beaten(depth: int) -> bool:
	var e: Expedition = _simulation.expedition
	var shaft: LabyrinthChamber = _simulation.labyrinth.level(depth).shaft_chamber()
	if shaft == null:
		return false
	if e.battle != null and e.depth == depth and e.chamber() == shaft:
		return false
	return not e.is_populated(depth, shaft.index)


## The line in words for the stage at [param depth]: [code]Mossy Hollow 7: visited[/code],
## [code]Mossy Hollow 5: Slime King (beaten)[/code] and so on, followed by
## [constant CLICK_HINT] when a click would send the party there, then on a second line how the
## stage looks for this party: [code]Within reach[/code] or [code]Dangerous: heroes
## are level 3[/code], nothing for a safe stage.
func hover_text(depth: int) -> String:
	var parts: PackedStringArray = hover_parts(depth)
	var text: String = parts[0] if parts[1].is_empty() else "%s. %s" % [parts[0], parts[1]]
	return text if parts[2].is_empty() else "%s\n%s" % [text, parts[2]]


## The line's three parts: what the stage is, the click hint (or ""), and how it looks (or "").
func hover_parts(depth: int) -> PackedStringArray:
	var shown: Array[StringName] = marks(depth)
	var what: String = "not reached yet"
	if shown.has(&"held"):
		what = "held"
	elif shown.has(&"visited"):
		what = "visited"
	if shown.has(&"safe"):
		what = "safe, the party falls back here"
	if shown.has(&"party"):
		what = "the party is here"
	if shown.has(&"guardian"):
		what = guardian_name(depth)
		if shown.has(&"guardian_beaten"):
			what += " (beaten)"
		if shown.has(&"party"):
			what += ", the party is here"
	if shown.has(&"target") and not shown.has(&"party"):
		what += ", the party is heading here"
	var click: String = ""
	if can_target(depth) and not shown.has(&"target"):
		click = CLICK_HINT
	var place: String = PlaceText.here(_simulation, depth)
	return PackedStringArray(["%s: %s" % [place, what], click, risk_line(depth)])


## The line for how [param depth] looks: "" for a safe stage.
func risk_line(depth: int) -> String:
	match risk(depth):
		Risk.REACHABLE:
			return "Within reach"
		Risk.DANGEROUS:
			return "Dangerous: heroes are level %d" % PartyLevels.lowest(_simulation.party)
	return ""


## True for a stage the simulation takes as a target: [method Simulation.set_target_depth] takes
## any stage from 1 on.
func can_target(depth: int) -> bool:
	return depth >= 1


## The target as shown: the one asked for until the simulation applies it, then its own.
func shown_target() -> int:
	return _asked_target if _asked_target > 0 else _simulation.expedition.target_depth


## Asks the simulation for [param depth] as the target, as the HUD's - and + buttons do, and for
## a dangerous stage that is not already the target says so once in the journal's ticker. Returns
## false (and does nothing) for a stage the simulation does not take as a target.
func ask(depth: int) -> bool:
	if not can_target(depth):
		return false
	var changed: bool = depth != shown_target()
	_asked_target = depth
	_simulation.set_target_depth(depth)
	if changed and _journal != null and risk(depth) == Risk.DANGEROUS:
		_journal.announce(
			(
				"Target set to %s: dangerous for level %d heroes"
				% [PlaceText.here(_simulation, depth), PartyLevels.lowest(_simulation.party)]
			)
		)
	return true
