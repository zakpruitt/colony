class_name SidePathWords
extends RefCounted
## How the screen words a side path: a gate opened, worked, or passed for want of its microskill,
## and what a cache paid. A gate's and a microskill's name are their definitions'; what a hero
## does to open a gate is the one thing said of it here, in [constant SENTENCES].

## Each gate's own words, by its id: what its opener did, and what the party is doing while it
## is worked. A gate with no row is "opened" and "Opening".
const SENTENCES: Dictionary[StringName, Array] = {
	&"hidden_crack": ["found a hidden crack", "Searching a crack"],
	&"locked_gate": ["picked a lock", "Picking a lock"],
	&"rubble": ["cleared the rubble", "Clearing rubble"],
	&"rune_seal": ["read a rune seal", "Reading a rune seal"],
}
## The gates whose name is not counted: no "a" before it and no "s" after.
const UNCOUNTED: Array[StringName] = [&"rubble"]
## The status of a party walking a side path.
const EXPLORING: String = "Exploring a side path"


## The gate at [param index] in [method Content.gate_ids], or null.
static func gate_at(index: int) -> GateDef:
	var ids: Array[StringName] = Content.gate_ids()
	return Content.gate(ids[index]) if index >= 0 and index < ids.size() else null


## What [param who] did to open [param gate]: [code]The Rogue picked a lock[/code].
static func opened(who: String, gate: GateDef) -> String:
	return "The %s %s" % [who, _own(gate, 0, "opened %s" % one(gate))]


## What the party is doing while [param gate] is worked: [code]Picking a lock[/code].
static func working(gate: GateDef) -> String:
	return _own(gate, 1, "Opening %s" % one(gate))


## [param gate] passed with nobody able to open it: [code]A rune seal: needs a
## Runereader[/code].
static func sealed(gate: GateDef) -> String:
	var named: String = one(gate)
	return "%s%s: needs %s" % [named.left(1).to_upper(), named.substr(1), _skill(gate)]


## [param gate]'s kind passed [param times] times with nobody able: [code]Passed 6 rune seals:
## needs a Runereader[/code].
static func passed(gate: GateDef, times: int) -> String:
	var what: String = one(gate) if times == 1 else "%d %s" % [times, many(gate)]
	if times != 1 and UNCOUNTED.has(gate.id):
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
	return named if UNCOUNTED.has(gate.id) else "%s %s" % [_article(named), named]


## More than one of [param gate], inside a sentence: [code]rune seals[/code].
static func many(gate: GateDef) -> String:
	var named: String = gate.display_name.to_lower()
	return named if UNCOUNTED.has(gate.id) else named + "s"


## [param gate]'s own words at [param column] of its row, or [param other] if it has none.
static func _own(gate: GateDef, column: int, other: String) -> String:
	var row: Array = SENTENCES.get(gate.id, [])
	return row[column] if column < row.size() else other


## The microskill that opens [param gate], as someone who has it: [code]a Runereader[/code].
static func _skill(gate: GateDef) -> String:
	var def: MicroskillDef = Content.microskill(gate.microskill)
	var named: String = def.display_name if def != null else "?"
	return "%s %s" % [_article(named), named]


static func _article(word: String) -> String:
	return "an" if word.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
