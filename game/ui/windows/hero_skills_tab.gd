class_name HeroSkillsTab
extends Control
## A hero window's Skills tab: a [HeroSkillsTab.Card] per microskill the hero's class learns, in the
## class's order. A learned one shows its picture owned, its name in white, what it does, and which
## quests it answers; one still to come is dimmed, its picture locked with its level under it.
## Read from the simulation at each [method refresh].

## UI pixels between two cards, and between a card's picture and its words.
const CARD_GAP: float = 10.0
const PICTURE_GAP: float = 6.0

## The cards, in the class's order.
var cards: Array[Card] = []

var _simulation: Simulation
var _hero_id: int = -1


## The tab of hero [param hero_id], [param width] UI pixels wide.
func _init(simulation: Simulation, hero_id: int, width: float) -> void:
	name = "SkillsPage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_simulation = simulation
	_hero_id = hero_id
	var hero: Hero = simulation.party.hero(hero_id)
	var def: HeroClassDef = hero.def() if hero != null else null
	var y: float = 0.0
	if def != null:
		var count: int = mini(def.microskills.size(), def.microskill_levels.size())
		for i: int in count:
			var skill: MicroskillDef = Content.microskill(def.microskills[i])
			if skill == null:
				continue
			var card := Card.new(skill, def.microskill_levels[i], width)
			card.position = Vector2(0, y)
			add_child(card)
			cards.append(card)
			y += card.size.y + CARD_GAP
	size = Vector2(width, maxf(y - CARD_GAP, 0.0))
	custom_minimum_size = size


## Brings every card up to date with the hero's level.
func refresh() -> void:
	var hero: Hero = _simulation.party.hero(_hero_id) if _simulation != null else null
	if hero == null:
		return
	var y: float = 0.0
	for card: Card in cards:
		card.show_learned(hero.level >= card.level)
		card.position.y = y  # a card to come is a line taller, for its level under the picture
		y += card.size.y + CARD_GAP


## The cards' lines, one per card: [code]Lockpicker: Opens locks[/code] for one learned,
## [code]Trapspotter, level 6[/code] for one to come.
func lines() -> Array[String]:
	var made: Array[String] = []
	for card: Card in cards:
		var skill: MicroskillDef = card.skill
		if card.learned:
			made.append("%s: %s" % [skill.display_name, skill.description])
		else:
			made.append("%s, level %d" % [skill.display_name, card.level])
	return made


## One microskill's card: its picture in a large [UiIcon], owned when the hero has it and locked,
## its level under it ([code]Level 8[/code]), when not; beside it its name, what it does (or the
## level it comes at), and the quests it answers, the words wrapped to the card's width.
class Card:
	extends Control

	## The microskill shown, and the level the class learns it at.
	var skill: MicroskillDef
	var level: int = 0
	## True when the hero has it.
	var learned: bool = false
	var name_label: Label
	var text_label: Label
	var answers_label: Label
	## The microskill's slot at the card's left, and its picture.
	var slot: UiIcon
	var picture: TextureRect
	## [code]Level 8[/code], under the slot while the microskill is still to come.
	var level_label: Label

	var _width: float = 0.0
	## Where the words start, right of the picture.
	var _words_x: float = 0.0

	func _init(shown: MicroskillDef, at_level: int, width: float) -> void:
		skill = shown
		level = at_level
		name = "Card_%s" % shown.id
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot = UiIcon.new(shown.id, true, UiIcon.Shape.CUT)
		slot.name = "Slot"
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		picture = slot.picture_rect
		level_label = WindowText.label("Level", "Level %d" % at_level, &"steel")
		add_child(level_label)
		# The slot and its level centred in one column, as wide as the wider of them.
		var column: float = maxf(slot.size.x, level_label.size.x)
		slot.position.x = floorf((column - slot.size.x) / 2.0)
		level_label.position = Vector2(
			floorf((column - level_label.size.x) / 2.0), slot.size.y + 1.0
		)
		_words_x = column + PICTURE_GAP
		_width = width - _words_x
		width = _width
		name_label = WindowText.label("Name", shown.display_name, &"white", true)
		name_label.position = Vector2(_words_x, 0)
		add_child(name_label)
		text_label = WindowText.label("Text", "", &"silver")
		text_label.position = Vector2(_words_x, UiText.LINE_HEIGHT)
		add_child(text_label)
		answers_label = WindowText.label("Answers", "", &"green")
		add_child(answers_label)
		var quests: Array[String] = []
		for quest_id: StringName in Content.quest_ids():
			var quest: QuestDef = Content.quest(quest_id)
			if quest != null and quest.microskill == shown.id:
				quests.append(
					"%s (%s)" % [quest.display_name, UiFormat.lower_first(quest.description)]
				)
		var answers: String = "Answers: " + ", ".join(PackedStringArray(quests))
		var lines: Array[String] = WindowText.wrap(answers, width)
		answers_label.text = "\n".join(PackedStringArray(lines))
		answers_label.size = Vector2(width, lines.size() * UiText.LINE_HEIGHT)
		answers_label.visible = not quests.is_empty()
		learned = true
		show_learned(false)

	## Shows the card as learned (white, what it does, the slot owned) or to come (dimmed, its
	## level, the slot locked).
	func show_learned(has: bool) -> void:
		if has == learned:
			return
		learned = has
		var text: String = "Comes at level %d" % level
		if has:
			text = skill.description + "."
		var lines: Array[String] = WindowText.wrap(text, _width)
		text_label.text = "\n".join(PackedStringArray(lines))
		text_label.size = Vector2(_width, lines.size() * UiText.LINE_HEIGHT)
		answers_label.position = Vector2(_words_x, text_label.position.y + text_label.size.y)
		var bottom: float = answers_label.position.y
		if answers_label.visible:
			bottom += answers_label.size.y
		slot.show_state(UiIcon.State.OWNED if has else UiIcon.State.LOCKED)
		level_label.visible = not has
		var low: float = level_label.position.y + level_label.size.y if not has else slot.size.y
		size = Vector2(_words_x + _width, maxf(bottom, low))
		var dim: StringName = TalentNode.DIM
		WindowText.set_colour(name_label, &"white" if has else dim)
		WindowText.set_colour(text_label, &"silver" if has else dim)
		WindowText.set_colour(answers_label, &"green" if has else dim)
