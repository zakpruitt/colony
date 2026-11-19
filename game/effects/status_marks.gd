class_name StatusMarks
extends Node2D
## The statuses on screen: on whoever has one, for as long as it lasts, gone the frame
## it ends. What is on whom comes from a [StatusBook] kept from the events in order, never
## from the live state ahead of them; nothing is drawn on a fighter that has fallen or gone.
##
## - stunned: three stars circling the head, and the sprite held still
##   ([member CharacterSprite.held]);
## - taunting, marked, mighty, weakened, hasted, slowed: their marks in a row over the head (a
##   red "!", a target, a bright or a broken sword, an arrow up or down);
## - shielded: an outline round the body that dims (cyan, blue, navy) as the shield is used, by
##   what the flagged MISSED events say it absorbed;
## - burning, bleeding, chilled: the sprite washed orange, red or pale blue, with small motes of
##   that colour (their damage numbers take it too, [method AbilityEffects.number_color]);
## - mending: green motes rising;
## - nimble, untouchable: the sprite half faded.
##
## A child of the [World] just before [member World.effects_layer], at its height: over the
## darkness, under the numbers. [AbilityEffects]
## advances it; [method advance] works out what shows, [method _draw] draws it.

## The sheet of status marks, one 7x7 part per status, named as [enum AbilityEffect.Status].
const SHEET_PATH: String = "res://assets/sprites/ui/status_icons.png"
## A mark's size, in pixels, and the gap between the head and the row of marks over it.
const MARK: int = 7
const MARK_GAP: float = 2.0
## The statuses shown as marks over the head, in the row's order.
const ROW: Array[AbilityEffect.Status] = [
	AbilityEffect.Status.TAUNTING,
	AbilityEffect.Status.MARKED,
	AbilityEffect.Status.MIGHTY,
	AbilityEffect.Status.WEAKENED,
	AbilityEffect.Status.HASTED,
	AbilityEffect.Status.SLOWED,
]
## How many stars circle a stunned head, and how many times a second they go round.
const STARS: int = 3
const STAR_TURNS: float = 0.8
## How far a burning, bleeding or chilled sprite is washed toward its colour.
const TINT_SHARE: float = 0.4
## The share of its opacity a nimble or untouchable sprite is drawn at.
const FADE: float = 0.5
## Motes: how many each status shows, the seconds one takes to cross the body, and their colours.
const MOTES: int = 3
const MOTE_SECONDS: float = 0.9
const MOTE_COLORS: Dictionary[int, Array] = {
	AbilityEffect.Status.BURNING: [&"orange", &"amber", &"yellow"],
	AbilityEffect.Status.BLEEDING: [&"red", &"crimson", &"red"],
	AbilityEffect.Status.CHILLED: [&"cyan", &"white", &"cyan"],
	AbilityEffect.Status.MENDING: [&"green", &"white", &"green"],
}
## The shield's outline colour as the shield is used: above two thirds left, above a third, below.
const SHIELD_COLORS: Array[StringName] = [&"cyan", &"blue", &"navy"]

var book: StatusBook

var _world: World
var _sheet: PixelSheet
var _time: float = 0.0
## The statuses drawn on each fighter this frame, in [enum AbilityEffect.Status] order.
var _shown: Dictionary[int, Array] = {}
## The fighters whose sprite was given a status's look last frame.
var _looked: Dictionary[int, bool] = {}
## What the last draw drew on each fighter, as words ("star", "mark:taunting",
## "outline:cyan", "mote:burning"): the tests read what is truly drawn.
var _drawn: Dictionary[int, Array] = {}


## Call once, before the first advance.
func setup(world: World, statuses: StatusBook) -> void:
	_world = world
	book = statuses
	_sheet = PixelSheet.load_sheet(SHEET_PATH)


## The mark of status [param kind], from the sheet of status marks (the HUD uses it too).
static func icon(kind: int) -> Texture2D:
	var sheet: PixelSheet = PixelSheet.load_sheet(SHEET_PATH)
	if sheet == null:
		return null
	return sheet.part(StringName(str(AbilityEffect.Status.keys()[kind]).to_lower()))


## Works out what shows this frame and gives each fighter's sprite its look. [param delta] runs
## the stars and motes on.
func advance(delta: float) -> void:
	if _world == null or book == null:
		return
	_time += delta
	_shown.clear()
	var looked: Dictionary[int, bool] = {}
	for id: int in book.fighters():
		var sprite: CharacterSprite = _world.character(id)
		if not _drawable(sprite):
			continue
		var kinds: Array[int] = []
		for status: ShownStatus in book.statuses_of(id):
			kinds.append(status.kind)
		_shown[id] = kinds
		_look(sprite, kinds)
		looked[id] = true
	for id: int in _looked:
		var sprite: CharacterSprite = _world.character(id)
		if not looked.has(id) and sprite != null:
			sprite.set_status_look(Color.WHITE, 0.0, 1.0)
			sprite.held = false
	_looked = looked
	queue_redraw()


## The statuses drawn on fighter [param id] this frame; empty for one that has fallen or gone.
func shown(id: int) -> Array[int]:
	var kinds: Array[int] = []
	var showing: Array = _shown.get(id, [])
	kinds.assign(showing)
	return kinds


## What the last draw drew on fighter [param id] (see [member _drawn]).
func drawn(id: int) -> Array[String]:
	var words: Array[String] = []
	var said: Array = _drawn.get(id, [])
	words.assign(said)
	return words


## The share of fighter [param id]'s shield still to absorb, from 0 to 1, as the events tell it.
func shield_left(id: int) -> float:
	return book.shield_left(id)


## The outline's colour for fighter [param id]'s shield now: it dims as the shield is used.
func shield_color(id: int) -> Color:
	return Palette.color(SHIELD_COLORS[_shield_step(id)])


## Which of [constant SHIELD_COLORS] fighter [param id]'s shield is drawn in now.
func _shield_step(id: int) -> int:
	var left: float = shield_left(id)
	return 0 if left > 2.0 / 3.0 else (1 if left > 1.0 / 3.0 else 2)


func _drawable(sprite: CharacterSprite) -> bool:
	return sprite != null and sprite.visible and not sprite.is_dead() and sprite.modulate.a > 0.01


## Gives [param sprite] the look of [param kinds]: held while stunned, washed while burning,
## bleeding or chilled, half faded while nimble or untouchable.
func _look(sprite: CharacterSprite, kinds: Array[int]) -> void:
	var tint := Color.WHITE
	var share: float = 0.0
	for kind: int in AbilityEffects.STATUS_COLORS:
		if kind in kinds:
			tint = Palette.color(AbilityEffects.STATUS_COLORS[kind])
			share = TINT_SHARE
			break
	var faded: bool = (
		AbilityEffect.Status.NIMBLE in kinds or AbilityEffect.Status.UNTOUCHABLE in kinds
	)
	sprite.set_status_look(tint, share, FADE if faded else 1.0)
	sprite.held = AbilityEffect.Status.STUNNED in kinds


func _draw() -> void:
	_drawn.clear()
	for id: int in _shown:
		var sprite: CharacterSprite = _world.character(id)
		if sprite == null:
			continue
		var kinds: Array = _shown[id]
		var body: Rect2 = SpriteBounds.body_rect(sprite)
		if AbilityEffect.Status.SHIELDED in kinds:
			_draw_outline(body.grow(2.0), shield_color(id))
			_note(id, "outline:%s" % SHIELD_COLORS[_shield_step(id)])
		for kind: int in MOTE_COLORS:
			if kind in kinds:
				_draw_motes(id, kind, body)
				_note(id, "mote:%s" % ShownStatus.status_name(kind).to_lower())
		var stunned: bool = AbilityEffect.Status.STUNNED in kinds
		var row: Array[int] = []
		for kind: int in ROW:
			if kind in kinds:
				row.append(kind)
		var row_y: float = body.position.y - MARK_GAP - MARK - (3.0 if stunned else 0.0)
		var row_width: float = row.size() * (MARK + 1) - 1
		var x: float = roundf(sprite.position.x - row_width / 2.0)
		for kind: int in row:
			if _draw_mark(kind, Vector2(x, row_y)):
				_note(id, "mark:%s" % ShownStatus.status_name(kind).to_lower())
			x += MARK + 1
		if stunned:
			_draw_stars(id, sprite.position.x, body)


func _note(id: int, what: String) -> void:
	var words: Array = _drawn.get(id, [])
	words.append(what)
	_drawn[id] = words


## A rectangle's edge, one pixel wide, its corners cut.
func _draw_outline(rect: Rect2, colour: Color) -> void:
	var r: Rect2 = Rect2(rect.position.round(), rect.size.round())
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), colour)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), colour)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), colour)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), colour)


func _draw_mark(kind: int, at: Vector2) -> bool:
	var texture: Texture2D = (
		_sheet.part(StringName(str(AbilityEffect.Status.keys()[kind]).to_lower()))
		if _sheet != null
		else null
	)
	if texture == null:
		return false
	draw_texture(texture, at.round())
	return true


## Stars going round the head of fighter [param id], whose feet are at [param middle] across.
func _draw_stars(id: int, middle: float, body: Rect2) -> void:
	var across: float = maxf(body.size.x / 2.0, 6.0)
	var y: float = body.position.y + 1.0
	for i: int in STARS:
		var angle: float = TAU * (_time * STAR_TURNS + float(i) / STARS + id * 0.17)
		var at := Vector2(middle + cos(angle) * across, y + sin(angle) * 2.0)
		var half: float = floorf(MARK / 2.0)
		if _draw_mark(AbilityEffect.Status.STUNNED, at - Vector2(half, half)):
			_note(id, "star")


## Small motes of status [param kind] over [param body]: drips falling for bleeding, rising for
## the rest.
func _draw_motes(id: int, kind: int, body: Rect2) -> void:
	var colours: Array = MOTE_COLORS[kind]
	var falling: bool = kind == AbilityEffect.Status.BLEEDING
	for i: int in MOTES:
		var start: float = float(i) / MOTES + id * 0.13 + kind * 0.29
		var phase: float = fposmod(_time / MOTE_SECONDS + start, 1.0)
		var across: float = body.position.x + body.size.x * (0.2 + 0.3 * i)
		across += roundf(sin((phase + i) * TAU) * 1.5)
		var height: float = body.size.y * (0.25 + 0.65 * phase if falling else 0.9 - 0.85 * phase)
		var at := Vector2(across, body.position.y + height).round()
		var colour_name: StringName = colours[i % colours.size()]
		var size: float = 2.0 if i == 0 else 1.0
		draw_rect(Rect2(at, Vector2(size, size)), Palette.color(colour_name))
