class_name SidePathWords
extends RefCounted
## How the screen words a side path: a gate opened, worked, or passed for want of its microskill,
## and what a cache paid. A gate's and a microskill's name are their definitions'; what a hero
## does to open a gate is the one thing said of it here, in [constant SENTENCES].

## Each gate's own words, by its id: what its opener did, what the party is doing while it is
## worked, and whether its name is counted ("a rune seal", "rune seals") or not ("rubble"). A
## gate with no row is "opened" and "Opening", and counted.
const SENTENCES: Dictionary[StringName, Array] = {
	&"hidden_crack": ["found a hidden crack", "Searching a crack", true],
	&"locked_gate": ["picked a lock", "Picking a lock", true],
	&"rubble": ["cleared the rubble", "Clearing rubble", false],
	&"rune_seal": ["read a rune seal", "Reading a rune seal", true],
}
## The columns of a row of [constant SENTENCES].
const _OPENED: int = 0
const _WORKING: int = 1
const _COUNTED: int = 2
## The status of a party walking a side path.
const EXPLORING: String = "Exploring a side path"


## The gate at [param index] in [method Content.gate_ids], or null.
static func gate_at(index: int) -> GateDef:
	var ids: Array[StringName] = Content.gate_ids()
	return Content.gate(ids[index]) if index >= 0 and index < ids.size() else null


## What [param who] did to open [param gate]: [code]The Rogue picked a lock[/code].
static func opened(who: String, gate: GateDef) -> String:
	if SENTENCES.has(gate.id):
		return "The %s %s" % [who, SENTENCES[gate.id][_OPENED]]
	return "The %s opened %s" % [who, one(gate)]


## What the party is doing while [param gate] is worked: [code]Picking a lock[/code].
static func working(gate: GateDef) -> String:
	if SENTENCES.has(gate.id):
		return SENTENCES[gate.id][_WORKING]
	return "Opening %s" % one(gate)


## [param gate] passed with nobody able to open it: [code]A rune seal: needs a
## Runereader[/code].
static func sealed(gate: GateDef) -> String:
	var named: String = one(gate)
	return "%s%s: needs %s" % [named.left(1).to_upper(), named.substr(1), _skill(gate)]


## [param gate]'s kind passed [param times] times with nobody able: [code]Passed 6 rune seals:
## needs a Runereader[/code].
static func passed(gate: GateDef, times: int) -> String:
	var what: String = one(gate) if times == 1 else "%d %s" % [times, many(gate)]
	if times != 1 and not _counted(gate):
		what = "%s %d times" % [many(gate), times]
	return "Passed %s: needs %s" % [what, _skill(gate)]


## What the microskill of [param gate] is good for: [code]opens rune seals[/code].
static func opens(gate: GateDef) -> String:
	return "opens %s" % many(gate)


## What a cache paid, on one line: [code]Cache: +120 gold, +9 clay, 40 XP each[/code].
static func cache(pay: CacheReader.Pay) -> String:
	var parts: PackedStringArray = ["+%s gold" % UiFormat.group_thousands(pay.gold)]
	if pay.resource != &"":
		var held: String = UiFormat.group_thousands(pay.resource_amount)
		parts.append("+%s %s" % [held, ResourceIcon.plural(pay.resource)])
	parts.append("%s XP each" % UiFormat.group_thousands(pay.xp_each))
	return "Cache: " + ", ".join(parts)


## One of [param gate], inside a sentence: [code]a rune seal[/code], [code]rubble[/code].
static func one(gate: GateDef) -> String:
	var named: String = gate.display_name.to_lower()
	return "%s %s" % [_article(named), named] if _counted(gate) else named


## More than one of [param gate], inside a sentence: [code]rune seals[/code].
static func many(gate: GateDef) -> String:
	var named: String = gate.display_name.to_lower()
	return named + "s" if _counted(gate) else named


## True if [param gate]'s name takes "a" before it and "s" after.
static func _counted(gate: GateDef) -> bool:
	if not SENTENCES.has(gate.id):
		return true
	var counted: bool = SENTENCES[gate.id][_COUNTED]
	return counted


## The microskill that opens [param gate], as someone who has it: [code]a Runereader[/code].
static func _skill(gate: GateDef) -> String:
	var def: MicroskillDef = Content.microskill(gate.microskill)
	var named: String = def.display_name if def != null else "?"
	return "%s %s" % [_article(named), named]


static func _article(word: String) -> String:
	return "an" if word.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
