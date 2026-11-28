class_name RosterCard
extends PanelContainer
## One card on the Camp window's Heroes tab ([RosterTab]): a hero of the colony, or a class
## waiting at camp to be recruited.
##
## A hero's card ([method for_hero]) shows its picture (a click on it opens the hero's window),
## its title ([method HeroTalentsTab.title]), its level, [code]At Camp[/code] when it is benched,
## and a [code]Swap[/code] button with, beside it, [code]At the next Camp[/code] while a swap of it
## waits. It is lit (a yellow edge) while it is the choice a swap starts from.
##
## A waiting class's card ([method for_recruit]) shows the class's picture and name, the artifact
## that was found (its picture and name), the level it would arrive at, its request in the hero's
## words with the resource's icon, and a [code]Recruit[/code] button, off while the party is short
## of the request.

## A left click on the card itself, not on its picture or a button.
signal pressed

## The card's words once a swap of its hero is asked for, and on a benched hero's.
const WAITING_WORDS: String = "At the next Camp"
const CAMP_WORDS: String = "At Camp"
## UI pixels: the space inside the card's edge, and the gaps between its picture and its words
## and between the parts of a line.
const PAD: int = 3
const GAP: int = 5
const LINE_GAP: int = 4
## The picture's size: a 16x16 portrait drawn at twice its size.
const PICTURE: Vector2 = Vector2(32, 32)
## The artifact's picture on a waiting card, at its own size.
const ARTIFACT_PICTURE: Vector2 = Vector2(16, 16)
## The picture an artifact with none of its own shows (its part in the pictures' sheets).
const SHARED_ARTIFACT: StringName = &"artifact"

## The hero shown, or -1 on a waiting class's card.
var hero_id: int = -1
## The class shown: the hero's, or the one waiting.
var class_id: StringName = &""
## True on a benched hero's card.
var benched: bool = false
## The portrait; a click on a hero's opens its window.
var picture: TextureButton
## The title in bold: the hero's class and path, or the waiting class's name.
var title_label: Label
## A hero's: its level, [code]At Camp[/code] (benched only), the Swap button and the mark beside
## it ([constant WAITING_WORDS] or "").
var level_label: Label
var camp_label: Label
var swap_button: UiButton
var mark_label: Label
## A waiting class's: the artifact's picture and name, the level it would arrive at, the request
## ([code]Bring 300 gold and 40 Glowcaps[/code]) and the resource's icon after it, and the button.
var artifact_picture: TextureRect
var artifact_label: Label
var arrives_label: Label
var request_label: Label
var request_icon: TextureRect
var recruit_button: UiButton
## True while the card is the choice a swap starts from: drawn with a yellow edge.
var lit: bool = false:
	set(value):
		if lit != value:
			lit = value
			_restyle()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_restyle()


## A card for [param hero], at camp when [param at_camp], [param width] UI pixels wide.
static func for_hero(hero: Hero, at_camp: bool, width: float) -> RosterCard:
	var made := RosterCard.new()
	made.name = "Hero%d" % hero.id
	made.hero_id = hero.id
	made.class_id = hero.class_id
	made.benched = at_camp
	made.custom_minimum_size.x = width
	var words: VBoxContainer = made._start(hero.def())
	made.title_label = _line(words, "Title", HeroTalentsTab.title(hero), &"white", true)
	var second: HBoxContainer = _row(words, LINE_GAP)
	made.level_label = _line(second, "Level", "Level %d" % hero.level, &"silver")
	made.camp_label = _line(second, "AtCamp", CAMP_WORDS, &"tan")
	made.camp_label.visible = at_camp
	var third: HBoxContainer = _row(words, LINE_GAP)
	made.swap_button = WindowText.button("Swap", "Swap")
	made.swap_button.toggle_mode = false
	made.swap_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	third.add_child(made.swap_button)
	made.mark_label = _line(third, "Mark", "", &"orange")
	made.mark_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return made


## A card for [param waiting], a class whose artifact was found, [param width] UI pixels wide.
static func for_recruit(waiting: StringName, width: float) -> RosterCard:
	var def: HeroClassDef = Content.hero_class(waiting)
	var made := RosterCard.new()
	made.name = "Recruit_%s" % waiting
	made.class_id = waiting
	made.custom_minimum_size.x = width
	var words: VBoxContainer = made._start(def)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = _row(words, LINE_GAP)
	made.title_label = _line(head, "Title", def.display_name, &"white", true)
	made.artifact_picture = _picture_rect("Artifact", artifact_of(def), ARTIFACT_PICTURE)
	made.artifact_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(made.artifact_picture)
	made.artifact_label = _line(head, "ArtifactName", def.artifact_name, &"amber")
	made.arrives_label = _line(words, "Arrives", "", &"silver")
	var asks: HBoxContainer = _row(words, 2)
	made.request_label = _line(asks, "Request", request_text(def), &"tan")
	made.request_icon = ResourceIcon.rect(def.recruit_resource)
	made.request_icon.name = "RequestIcon"
	made.request_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.request_icon.visible = def.recruit_resource != &"" and def.recruit_resource_count > 0
	asks.add_child(made.request_icon)
	made.recruit_button = WindowText.button("Recruit", "Recruit")
	made.recruit_button.toggle_mode = false
	made.recruit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(words.get_parent() as Control).add_child(made.recruit_button)
	return made


## [param def]'s request in the hero's words: [code]Bring 300 gold and 40 Glowcaps[/code], or
## [code]Bring 300 gold[/code] when it asks no resource.
static func request_text(def: HeroClassDef) -> String:
	var gold: String = "Bring %s gold" % UiFormat.group_thousands(def.recruit_gold)
	if def.recruit_resource == &"" or def.recruit_resource_count <= 0:
		return gold
	var count: String = UiFormat.group_thousands(def.recruit_resource_count)
	return "%s and %s %s" % [gold, count, ResourceIcon.title(def.recruit_resource)]


## What [param def]'s request still lacks ([param lacking], from [method Roster.lacks]: gold, then
## its resource), in words ([code]Needs 120 more gold and 15 more Glowcaps[/code]); "" for nothing.
static func short_text(def: HeroClassDef, lacking: Vector2i) -> String:
	var parts: PackedStringArray = []
	if lacking.x > 0:
		parts.append("%s more gold" % UiFormat.group_thousands(lacking.x))
	if lacking.y > 0:
		var missing: String = UiFormat.group_thousands(lacking.y)
		parts.append("%s more %s" % [missing, ResourceIcon.title(def.recruit_resource)])
	return "" if parts.is_empty() else "Needs " + " and ".join(parts)


## The picture of [param def]'s artifact: its own, or the one every class without one shares.
static func artifact_of(def: HeroClassDef) -> Texture2D:
	var own: StringName = def.artifact_picture
	return UiIcon.picture(own if own != &"" and UiIcon.has_picture(own) else SHARED_ARTIFACT)


## The portrait of a hero of [param def]: the class it looks like.
static func portrait(def: HeroClassDef) -> Texture2D:
	var sheet: PixelSheet = PixelSheet.load_sheet(HudFrame.ICONS_PATH)
	var part: StringName = def.look()
	return sheet.part(part) if sheet != null and sheet.has_part(part) else null


## [param hero]'s tooltip: its level, its unspent talent points and the rank of each path.
static func tip_text(hero: Hero) -> String:
	var points: int = hero.talent_points()
	var lines: PackedStringArray = [
		"Level %d. %d talent point%s unspent." % [hero.level, points, "" if points == 1 else "s"]
	]
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	if tree != null:
		var ranks: PackedStringArray = []
		for path: int in tree.paths.size():
			ranks.append("%s rank %d" % [tree.path(path).display_name, hero.ranks.rank(path, tree)])
		lines.append(", ".join(ranks) + ".")
	return "\n".join(lines)


## Words a hero's card for [param hero]: its title and level, and [param waiting] (a swap of it
## asked for) as the mark beside its button.
func show_hero(hero: Hero, waiting: bool) -> void:
	WindowText.set_text(title_label, HeroTalentsTab.title(hero))
	WindowText.set_text(level_label, "Level %d" % hero.level)
	WindowText.set_text(mark_label, WAITING_WORDS if waiting else "")


## Words a waiting class's card: the level it would arrive at ([param level]) and whether
## [param can_pay] its request.
func show_recruit(level: int, can_pay: bool) -> void:
	WindowText.set_text(arrives_label, "Arrives at level %d" % level)
	recruit_button.disabled = not can_pay


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	accept_event()
	pressed.emit()


## Makes the card's row, its picture of [param def] and the column its words go in.
func _start(def: HeroClassDef) -> VBoxContainer:
	var whole: HBoxContainer = _row(self, GAP)
	picture = TextureButton.new()
	picture.name = "Picture"
	picture.texture_normal = portrait(def)
	picture.ignore_texture_size = true
	picture.stretch_mode = TextureButton.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.custom_minimum_size = PICTURE
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	picture.focus_mode = Control.FOCUS_NONE
	whole.add_child(picture)
	var words := VBoxContainer.new()
	words.name = "Words"
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override(&"separation", 1)
	whole.add_child(words)
	return words


func _restyle() -> void:
	var edge: StringName = &"yellow" if lit else &"dusk"
	add_theme_stylebox_override(&"panel", UiTheme.box(&"night", edge, PAD - 1, PAD - 1))


static func _row(parent: Control, separation: int) -> HBoxContainer:
	var made := HBoxContainer.new()
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_constant_override(&"separation", separation)
	parent.add_child(made)
	return made


static func _line(
	parent: Control, line_name: String, text: String, colour: StringName, bold: bool = false
) -> Label:
	var made: Label = UiText.label(text, colour, bold)
	made.name = line_name
	made.add_theme_constant_override(&"line_spacing", 0)
	parent.add_child(made)
	return made


static func _picture_rect(rect_name: String, texture: Texture2D, shown: Vector2) -> TextureRect:
	var made := TextureRect.new()
	made.name = rect_name
	made.texture = texture
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	made.stretch_mode = TextureRect.STRETCH_SCALE
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.custom_minimum_size = shown
	return made
