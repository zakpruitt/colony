class_name Milestones
extends Node
## Marks the biggest things a run does on the frame of the screen (spec 066), with the two sizes
## of moment [UiMoment] has. It hears the world's events:
## [br]- a guardian slain gets a banner, the guardian's own sprite its picture: [code]Slime King is
## beaten[/code] over [code]The Claypits are open[/code] when that opened an area, else
## [code]Mossy Hollow 10 is behind you[/code]. One banner, not two: the guardian's waits for the
## areas reported opened on its tick, and is queued on the next [method advance];
## [br]- an area opened with no guardian's banner to carry it gets its own, with its resource's
## icon: [code]Ember Deep is open[/code] over [code]It gives embers[/code];
## [br]- a level bursts the hero's frame and steps its level number up
## ([method HeroFrameView.step_level]); no banner;
## [br]- a talent point gained pulses that frame's tag ([method HeroFrameView.pulse_tag]);
## [br]- a new safe stage bursts the place panel's [code]Safe N[/code] and steps it up
## ([method PlacePanel.step_safe]); a stage no further than the safe one it knows does nothing.
##
## Only for what just happened: nothing starts for an event that is not recent or while the world
## is catching up ([method UiMoment.may_start]), and a catch-up clears what is running. It reads
## the simulation and changes nothing in it.

## Where a monster's sheet is, by its id.
const SHEET_PATH: String = CharacterSprite.MONSTERS_DIR + "/%s.png"

static var _pictures: Dictionary[StringName, Texture2D] = {}

var _simulation: Simulation
var _world: World
var _hud: Hud
var _moment: UiMoment
## The area the events heard so far have the party in, and the safe stage known there.
var _area: StringName
var _safe: int = 1
## The guardian slain whose banner waits for its tick's other events; null for none. With it, the
## guardian's monster, the area it held and the areas its fall opened.
var _slain: SimEvent
var _slain_guardian: StringName
var _slain_area: StringName
var _opened: Array[StringName] = []


## Hears [param world]'s events from now on, marking them on [param hud]'s frame through
## [param moment].
func setup(simulation: Simulation, world: World, hud: Hud, moment: UiMoment) -> void:
	name = "Milestones"
	_simulation = simulation
	_world = world
	_hud = hud
	_moment = moment
	_area = simulation.expedition.place
	_safe = simulation.expedition.last_stable_depth
	if not world.sim_event.is_connected(hear):
		world.sim_event.connect(hear)


func _process(delta: float) -> void:
	advance(delta)


## Takes in one event, in the order the simulation reported it.
func hear(event: SimEvent) -> void:
	if _moment == null:
		return
	if _world.catching_up():
		_clear()
	if _slain != null and event.tick != _slain.tick:
		_announce_slain()
	match event.kind:
		SimEvent.Kind.AREA_CHANGED:
			var ids: Array[StringName] = Content.area_ids()
			if event.amount >= 0 and event.amount < ids.size():
				_area = ids[event.amount]
				_safe = _simulation.area_progress(_area).x
		SimEvent.Kind.GUARDIAN_SLAIN:
			_on_slain(event)
		SimEvent.Kind.AREA_OPENED:
			_on_opened(event)
		SimEvent.Kind.LEVEL_UP:
			var frame: HeroFrameView = _frame_of(event.target_id)
			if frame != null and _moment.may_start(event):
				_moment.burst(frame, event)
				frame.step_level()
		SimEvent.Kind.TALENT_POINT_GAINED:
			var frame: HeroFrameView = _frame_of(event.source_id)
			if frame != null and _moment.may_start(event):
				frame.pulse_tag()
		SimEvent.Kind.STABLE_DEPTH_REACHED:
			# The simulation tells of a stage once; one told again (after a defeat) is not new.
			var further: bool = event.amount > _safe
			_safe = maxi(_safe, event.amount)
			if further and _moment.may_start(event):
				_moment.burst(_hud.place_panel.safe_label, event)
				_hud.place_panel.step_safe()


## Queues the banner of a guardian slain on an earlier frame and runs the safe stage's step on by
## [param delta] seconds; while the world catches up, clears what is running instead. Called
## every frame; tests call it.
func advance(delta: float) -> void:
	if _moment == null:
		return
	if _world.catching_up():
		_clear()
		return
	if _slain != null:
		_announce_slain()
	_hud.place_panel.advance(delta)


## The picture of guardian [param monster_id] for a banner: its sprite as it stands, every part
## of its sheet drawn in order, cut to what is drawn and made square. Null for an unknown one.
static func guardian_picture(monster_id: StringName) -> Texture2D:
	if _pictures.has(monster_id):
		return _pictures[monster_id]
	var path: String = SHEET_PATH % monster_id
	if not ResourceLoader.exists(path):
		return null
	var sheet: PixelSheet = PixelSheet.load_sheet(path)
	if sheet == null:
		return null
	var whole := Image.create_empty(sheet.size.x, sheet.size.y, false, Image.FORMAT_RGBA8)
	var canvas := Rect2i(Vector2i.ZERO, sheet.size)
	for part_name: String in sheet.part_names:
		var part: Image = sheet.part(StringName(part_name)).get_image()
		if part == null or part.is_empty():
			return null
		if part.is_compressed():
			part.decompress()
		part.convert(Image.FORMAT_RGBA8)
		whole.blend_rect(part, canvas, Vector2i.ZERO)
	var used: Rect2i = whole.get_used_rect()
	var side: int = maxi(used.size.x, used.size.y)
	if side <= 0:
		return null
	var square := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	# Centred sideways, its feet on the bottom edge.
	square.blit_rect(whole, used, Vector2i((side - used.size.x) / 2, side - used.size.y))
	var picture: Texture2D = ImageTexture.create_from_image(square)
	_pictures[monster_id] = picture
	return picture


## A guardian's headline: [code]Slime King is beaten[/code].
static func beaten_text(guardian: String) -> String:
	return "%s is beaten" % guardian


## What a guardian that opened nothing gave: [code]Mossy Hollow 10 is behind you[/code].
static func behind_text(area: StringName, stage: int) -> String:
	return "%s is behind you" % PlaceText.of(area, stage)


## That [param areas] opened: [code]The Claypits are open[/code], [code]Ember Deep is
## open[/code] (a name that is many things, or more than one area, takes "are").
static func open_text(areas: Array[StringName]) -> String:
	var names := PackedStringArray()
	for area: StringName in areas:
		names.append(PlaceText.area_name(area))
	var many: bool = names.size() > 1 or (names.size() == 1 and names[0].ends_with("s"))
	return "%s %s open" % [" and ".join(names), "are" if many else "is"]


## What an area gives, by its resource: [code]It gives clay[/code].
static func gives_text(resource: StringName) -> String:
	return "It gives %s" % ResourceIcon.plural(resource)


## A guardian was slain: its banner waits for the areas opened on the same tick.
func _on_slain(event: SimEvent) -> void:
	if not _moment.may_start(event):
		return
	var guardian: StringName = EncounterRoll.guardian_at(Content.area(_area), event.amount)
	if Content.monster(guardian) == null:
		return
	_slain = event
	_slain_guardian = guardian
	_slain_area = _area
	_opened.clear()


## An area opened: told on the waiting guardian's banner, or with no such banner on its own.
func _on_opened(event: SimEvent) -> void:
	var ids: Array[StringName] = Content.area_ids()
	if event.amount < 0 or event.amount >= ids.size():
		return
	var area: StringName = ids[event.amount]
	if _slain != null:
		_opened.append(area)
		return
	var def: AreaDef = Content.area(area)
	_moment.announce_picture(
		ResourceIcon.texture(def.resource),
		open_text([area] as Array[StringName]),
		gives_text(def.resource),
		event
	)


## Queues the waiting guardian's banner.
func _announce_slain() -> void:
	var line: String = behind_text(_slain_area, _slain.amount)
	if not _opened.is_empty():
		line = open_text(_opened)
	_moment.announce_picture(
		guardian_picture(_slain_guardian),
		beaten_text(Content.monster(_slain_guardian).display_name),
		line,
		_slain
	)
	_slain = null
	_opened.clear()


## Ends what this started on the frame's pieces and forgets the banner waiting: the world is
## catching up (the moment drops its own bursts and banners).
func _clear() -> void:
	_slain = null
	_opened.clear()
	_hud.place_panel.stop_step()
	for frame: HeroFrameView in _hud.frames:
		if frame.level_step > 0.0 or frame.tag_pulse > 0.0:
			frame.snap()


func _frame_of(hero_id: int) -> HeroFrameView:
	for frame: HeroFrameView in _hud.frames:
		if frame.hero_id == hero_id:
			return frame
	return null
