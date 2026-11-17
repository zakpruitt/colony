class_name ResourceIcon
extends RefCounted
## How the screen shows a resource (spec 052): its 8x8 icon, its name as a title, and the
## sentences saying where it comes from and how that area is opened.

## The sheet of resource icons, one part per resource, named by its id.
const SHEET_PATH: String = "res://assets/sprites/ui/resource_icons.png"
## The icon's size in pixels.
const SIZE: Vector2 = Vector2(8, 8)

static var _sheet: PixelSheet


## Resource [param id]'s icon, or null for an unknown one.
static func texture(id: StringName) -> Texture2D:
	if _sheet == null:
		_sheet = PixelSheet.load_sheet(SHEET_PATH)
	if _sheet == null or Content.resource_def(id) == null:
		return null
	return _sheet.part(id)


## A TextureRect showing resource [param id]'s icon, ignoring the mouse.
static func rect(id: StringName) -> TextureRect:
	var made := TextureRect.new()
	made.name = "Icon"
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.stretch_mode = TextureRect.STRETCH_KEEP
	made.texture = texture(id)
	made.size = SIZE
	return made


## Resource [param id]'s name as a title, more than one of it: "Glowcaps", "Old bones".
static func title(id: StringName) -> String:
	var def: ResourceDef = Content.resource_def(id)
	if def == null:
		return String(id)
	return def.plural.left(1).to_upper() + def.plural.substr(1)


## Resource [param id]'s name in a sentence, more than one of it: "glowcaps", "old bones".
static func plural(id: StringName) -> String:
	var def: ResourceDef = Content.resource_def(id)
	return def.plural if def != null else String(id)


## Where resource [param id] comes from: [code]Clay comes from the Claypits[/code],
## [code]Glowcaps come from Mossy Hollow[/code].
static func comes_from(id: StringName) -> String:
	var def: ResourceDef = Content.resource_def(id)
	# A word with no plural of its own ("clay") takes "comes"; a plural ("glowcaps") "come".
	var verb: String = (
		"comes" if def != null and def.plural == def.display_name.to_lower() else "come"
	)
	return "%s %s from %s" % [title(id), verb, in_sentence(Content.area_of_resource(id))]


## How area [param area_id] is opened, if [param simulation] has it closed:
## [code]beat the Slime King in Mossy Hollow to open it[/code]; "" when it is open (or opened by
## none).
static func how_opened(simulation: Simulation, area_id: StringName) -> String:
	var def: AreaDef = Content.area(area_id)
	if def == null or simulation == null or simulation.is_area_open(area_id):
		return ""
	var opener: AreaDef = Content.area(def.opened_by)
	var guardian: MonsterDef = Content.monster(opener.guardian) if opener != null else null
	if guardian == null:
		return ""
	return "beat the %s in %s to open it" % [guardian.display_name, in_sentence(opener.id)]


## Where resource [param id] comes from, and how that area is opened if it is closed:
## [code]Clay comes from the Claypits: beat the Slime King in Mossy Hollow to open it.[/code]
static func where_from(simulation: Simulation, id: StringName) -> String:
	var sentence: String = comes_from(id)
	var opening: String = how_opened(simulation, Content.area_of_resource(id))
	return sentence + "." if opening.is_empty() else "%s: %s." % [sentence, opening]


## Area [param area_id]'s name inside a sentence: a leading "The" is lower case.
static func in_sentence(area_id: StringName) -> String:
	var called: String = PlaceText.area_name(area_id)
	return "the " + called.substr(4) if called.begins_with("The ") else called
