class_name SpellEffects
extends Node
## Spells on screen (spec 057 R4): each kind of spell effect has its own small visual, made of
## palette squares and the existing particles ([FxParticle]): a fireball that flies with a flame
## trail and bursts, a meteor that falls from above the screen, a shard of ice that flies straight
## and shatters, a frost burst along the floor, flakes over the enemies, a spark that jumps from
## enemy to enemy, a column of light on whoever is healed or blessed, a beam from above, knives in
## a fan, flames, and a violet puff of shadow. Fire reads orange, frost pale blue, holy pale gold,
## shadow violet.
##
## A flying spell leaves its caster in the wind-up's last moments (from ABILITY_STARTED), so it
## reaches its target as the wind-up ends; it bursts when ABILITY_USED says the spell landed, on
## that tick, wherever it has got to. Every other kind shows when it lands. Every particle is gone
## within a second of landing; the effects layer holds them (they all pass).
##
## A stun or a death of the caster, or the death of the target, takes a spell still in flight away;
## the end of a fight takes every spell in flight; a wipe or a change of stage or area takes every
## visual. Nothing starts in a frame catching up on a stall ([method World.catching_up]) or for an
## event too old ([method World.is_recent]). [CombatEffects] makes and advances it.
##
## A visual that shows on whom a spell lands (flakes, flames, light, a beam, shadow, a spark's
## jumps) shows only on the fighters the simulation says it reached: those its fighter's HIT,
## HEALED, REVIVED and STATUS_BEGAN events of the same tick credit to it, read as [AbilityEffects]
## reads them ([AbilityCredit]).

## The most particles these visuals make at once.
const MAX_PARTICLES: int = 120
## The kind of visual each ability shows; the kinds that fly; the colour family of each kind.
const KINDS: Dictionary[StringName, StringName] = {
	&"fireball": &"fireball",
	&"meteor": &"meteor",
	&"ice_lance": &"ice_shard",
	&"frost_nova": &"frost_burst",
	&"deep_freeze": &"frost_burst",
	&"blizzard": &"blizzard",
	&"chain_spark": &"chain_spark",
	&"inferno": &"flames",
	&"wildfire": &"flames",
	&"ignite": &"flames",
	&"prayer": &"light_column",
	&"blessing": &"light_column",
	&"renewal": &"light_column",
	&"sanctuary": &"light_column",
	&"miracle": &"light_column",
	&"guardian_angel": &"light_column",
	&"smite": &"holy_beam",
	&"holy_fire": &"holy_beam",
	&"wrath": &"holy_beam",
	&"fan_of_knives": &"knives",
	&"mark_for_death": &"shadow",
	&"vanish": &"shadow",
	&"smoke_step": &"shadow",
}
const FLIES: Array[StringName] = [&"fireball", &"meteor", &"ice_shard"]
## The kinds that show on each fighter the spell reaches, as the events say it does.
const REACHING: Array[StringName] = [
	&"blizzard", &"chain_spark", &"flames", &"light_column", &"holy_beam", &"shadow"
]
const FAMILY_OF: Dictionary[StringName, StringName] = {
	&"fireball": &"fire",
	&"meteor": &"fire",
	&"flames": &"fire",
	&"ice_shard": &"frost",
	&"frost_burst": &"frost",
	&"blizzard": &"frost",
	&"chain_spark": &"spark",
	&"light_column": &"holy",
	&"holy_beam": &"holy",
	&"knives": &"steel",
	&"shadow": &"shadow",
}
## The palette colours of each family, the one it reads as first.
const FAMILIES: Dictionary[StringName, Array] = {
	&"fire": [&"orange", &"amber", &"yellow", &"red"],
	&"frost": [&"cyan", &"white", &"silver"],
	&"holy": [&"yellow", &"sand", &"white"],
	&"shadow": [&"orchid", &"plum", &"dusk"],
	&"spark": [&"white", &"yellow", &"cyan"],
	&"steel": [&"silver", &"white", &"steel"],
}
## Seconds the longest flight takes (a meteor's a little longer), and its head's size in pixels.
const FLIGHT: float = 0.35
const METEOR_FLIGHT: float = 0.45
## Pixels above its feet a spell flies at and bursts at, and above the top of the screen a meteor
## starts; how far to the side of its target it starts.
const AIM_HEIGHT: float = 12.0
const METEOR_ABOVE: float = 12.0
const METEOR_SIDE: float = 36.0
## Seconds a flight may wait at its target for its landing before it goes.
const LATE: float = 0.4

var _world: World
var _simulation: Simulation
var _credit: AbilityCredit
## The spells landing in the tick being heard that show on whom they reach: per
## "source:ability", the fighters shown on so far, in order.
var _reaching: Dictionary[String, Array] = {}
var _reaching_tick: int = -1
var _rng := RandomNumberGenerator.new()
var _particles: Array[FxParticle] = []
var _flights: Array[Flight] = []


## One spell on its way: its kind, its caster and target, the ability, the seconds before it
## leaves and its time in the air, and its head once it has left.
class Flight:
	var kind: StringName
	var source: int
	var target: int
	var ability: StringName
	var wait: float
	var air: float
	var time: float = 0.0
	var start: Vector2
	var head: FxParticle
	var trail_from: Vector2 = Vector2.INF
	## The trail it has left: taken with it if it never lands.
	var bits: Array[FxParticle] = []


## Call once, before the first advance. [param credit] is [AbilityEffects]'s, which hears each
## event before this does and says which ability a blow or heal was.
func setup(world: World, simulation: Simulation, credit: AbilityCredit) -> void:
	_world = world
	_simulation = simulation
	_credit = credit
	_rng.seed = 57
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)


## Moves every visual on by [param delta] real seconds. [CombatEffects] calls it each frame.
func advance(delta: float) -> void:
	if _world == null or _world.effects_layer == null:
		return
	if _world.catching_up():
		_clear()  # the picture jumps to the simulation's: nothing is left in the air (R7)
		return
	for flight: Flight in _flights.duplicate():
		_fly(flight, delta)
	for particle: FxParticle in _particles.duplicate():
		if not particle.advance(delta):
			_drop(particle)


## The particles of [param kind] showing now (a flight's head and trail among them).
func particles(kind: StringName) -> Array[FxParticle]:
	var found: Array[FxParticle] = []
	for particle: FxParticle in _particles:
		if particle.kind == kind:
			found.append(particle)
	return found


## Every particle showing now.
func all_particles() -> Array[FxParticle]:
	return _particles.duplicate()


## How many particles show now.
func live() -> int:
	return _particles.size()


# --- Events --------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	var fresh: bool = _world.is_recent(event) and not _world.catching_up()
	if event.tick != _reaching_tick:
		_reaching.clear()
		_reaching_tick = event.tick
	match event.kind:
		SimEvent.Kind.ABILITY_STARTED:
			if fresh:
				_launch(event)
		SimEvent.Kind.ABILITY_USED:
			var flight: Flight = _flight_of(event.source_id, event.ability_id)
			if flight != null:
				_end_flight(flight, false)  # it lands: its trail fades on its own
			if fresh and KINDS.has(event.ability_id):
				if KINDS[event.ability_id] in REACHING:
					_reaching[_key(event.source_id, event.ability_id)] = []
				else:
					_land(event, KINDS[event.ability_id])
		SimEvent.Kind.HIT, SimEvent.Kind.HEALED:
			if fresh and _credit != null:
				_reach(event.source_id, _credit.ability_id, event.target_id)
		SimEvent.Kind.REVIVED:
			if fresh:
				for key: String in _reaching:
					if key.begins_with("%d:" % event.source_id):
						_reach(event.source_id, StringName(key.get_slice(":", 1)), event.target_id)
		SimEvent.Kind.STATUS_BEGAN:
			if fresh:
				_reach(event.source_id, event.ability_id, event.target_id)
			if event.status == AbilityEffect.Status.STUNNED:
				_ground(event.target_id, false)
		SimEvent.Kind.DIED:
			_ground(event.source_id, true)
		SimEvent.Kind.ENCOUNTER_ENDED:
			for flight: Flight in _flights.duplicate():
				_end_flight(flight, true)
		SimEvent.Kind.PARTY_WIPED, SimEvent.Kind.AREA_CHANGED, SimEvent.Kind.DEPTH_CHANGED:
			_clear()


func _key(source: int, ability: StringName) -> String:
	return "%d:%s" % [source, ability]


## [param ability] of [param source], landing in this tick, has reached fighter [param id]: its
## visual shows there, once.
func _reach(source: int, ability: StringName, id: int) -> void:
	var key: String = _key(source, ability)
	if not _reaching.has(key) or id < 0 or id in _reaching[key]:
		return
	var sprite: CharacterSprite = _world.character(id)
	if sprite == null or not sprite.visible:
		return
	var shown: Array = _reaching[key]
	match KINDS[ability]:
		&"blizzard":
			_flakes(id)
		&"flames":
			_flames(id)
		&"light_column":
			_column(id)
		&"holy_beam":
			_beam(id)
		&"shadow":
			_shadow(id)
		&"chain_spark":
			var at: Vector2 = sprite.position + Vector2(0, -AIM_HEIGHT)
			if not shown.is_empty():
				var last_id: int = shown.back()
				var last: CharacterSprite = _world.character(last_id)
				if last != null:
					_bolt_line(last.position + Vector2(0, -AIM_HEIGHT), at)
			_flash(&"chain_spark", at, &"white" if shown.is_empty() else &"yellow", 5)
	shown.append(id)


## A flying spell's wind-up begins: it leaves in time to arrive as the wind-up ends.
func _launch(event: SimEvent) -> void:
	var kind: StringName = KINDS.get(event.ability_id, &"")
	if not kind in FLIES or _world.character(event.source_id) == null:
		return
	var speed: int = maxi(_world.speed, 1)
	var ticks: int = event.amount - (_simulation.tick - event.tick)
	var left: float = float(ticks) / Simulation.TICKS_PER_SECOND / speed
	if left <= 0.0 or _world.character(event.target_id) == null:
		return
	var flight := Flight.new()
	flight.kind = kind
	flight.source = event.source_id
	flight.target = event.target_id
	flight.ability = event.ability_id
	flight.air = minf(left, (METEOR_FLIGHT if kind == &"meteor" else FLIGHT) / speed)
	flight.wait = left - flight.air
	_flights.append(flight)


## Takes away the flights of [param id] as caster and, if [param as_target], at it.
func _ground(id: int, as_target: bool) -> void:
	for flight: Flight in _flights.duplicate():
		if flight.source == id or (as_target and flight.target == id):
			_end_flight(flight, true)


func _clear() -> void:
	for flight: Flight in _flights.duplicate():
		_end_flight(flight, true)
	for particle: FxParticle in _particles.duplicate():
		_drop(particle)


func _flight_of(source: int, ability: StringName) -> Flight:
	for flight: Flight in _flights:
		if flight.source == source and flight.ability == ability:
			return flight
	return null


## Ends [param flight]: its head goes, and with [param whole] its trail too.
func _end_flight(flight: Flight, whole: bool) -> void:
	_flights.erase(flight)
	if flight.head != null and _particles.has(flight.head):
		_drop(flight.head)
	if whole:
		for bit: FxParticle in flight.bits:
			if _particles.has(bit):
				_drop(bit)


# --- Flight --------------------------------------------------------------------


func _fly(flight: Flight, delta: float) -> void:
	flight.time += delta
	var caster: CharacterSprite = _world.character(flight.source)
	var target: CharacterSprite = _world.character(flight.target)
	if target == null or flight.time > flight.wait + flight.air + LATE:
		_end_flight(flight, true)
		return
	if flight.time < flight.wait:
		return
	var to: Vector2 = target.position + Vector2(0, -AIM_HEIGHT)
	if flight.head == null:
		flight.start = _start_of(flight, caster, to)
		flight.head = _particle(flight.kind)
		if flight.head == null:
			_flights.erase(flight)
			return
		_shape_head(flight)
	var s: float = clampf((flight.time - flight.wait) / maxf(flight.air, 0.001), 0.0, 1.0)
	var at: Vector2 = flight.start.lerp(to, s)
	if flight.kind == &"fireball":
		at.y -= 6.0 * sin(PI * s)  # a little arc
	flight.head.age = 0.0
	flight.head.start(at)
	_trail(flight, at)


## Where a flight leaves from: the caster's raised hand, or (a meteor) above the screen.
func _start_of(flight: Flight, caster: CharacterSprite, to: Vector2) -> Vector2:
	if flight.kind == &"meteor":
		var side: float = (
			-METEOR_SIDE if caster == null or caster.position.x < to.x else METEOR_SIDE
		)
		return Vector2(to.x + side, _screen_top() - METEOR_ABOVE)
	if caster == null:
		return to
	var facing: float = signf(to.x - caster.position.x) if to.x != caster.position.x else 1.0
	return caster.position + Vector2(6.0 * facing, -AIM_HEIGHT - 6.0)


func _shape_head(flight: Flight) -> void:
	var head: FxParticle = flight.head
	head.shape = FxParticle.Shape.PUFF
	head.life = 10.0  # it is kept young while it flies (see _fly) and taken when it lands
	match flight.kind:
		&"fireball":
			head.color = Palette.color(&"orange")
			head.size = 5
		&"meteor":
			head.color = Palette.color(&"orange")
			head.size = 8
		&"ice_shard":
			head.shape = FxParticle.Shape.SQUARE
			head.color = Palette.color(&"cyan")
			head.size = 3


## Drops trail squares along the head's path since the last frame.
func _trail(flight: Flight, at: Vector2) -> void:
	if flight.trail_from == Vector2.INF:
		flight.trail_from = at
		return
	var colors: Array = FAMILIES[FAMILY_OF[flight.kind]]
	var step: float = 3.0
	var gap: float = flight.trail_from.distance_to(at)
	var count: int = mini(floori(gap / step), 8)
	for i: int in count:
		var bit: FxParticle = _particle(flight.kind)
		if bit == null:
			break
		var color_name: StringName = colors[_rng.randi_range(0, colors.size() - 1)]
		bit.color = Palette.color(color_name)
		bit.size = 3 if flight.kind == &"meteor" else 2
		bit.life = _rng.randf_range(0.12, 0.22)
		if flight.kind != &"ice_shard":
			bit.velocity = Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-24.0, -8.0))
		bit.start(flight.trail_from.lerp(at, float(i + 1) / (count + 1)))
		flight.bits.append(bit)
	if count > 0:
		flight.trail_from = at


# --- Landing -------------------------------------------------------------------


func _land(event: SimEvent, kind: StringName) -> void:
	var ability: AbilityDef = Content.ability(event.ability_id)
	if ability == null:
		return
	match kind:
		&"fireball":
			_burst_at(event.target_id, kind, 14, 110.0, 9)
		&"meteor":
			_burst_at(event.target_id, kind, 22, 150.0, 14)
		&"ice_shard":
			_shatter(event.target_id)
		&"frost_burst":
			_frost_burst(event.target_id)
		&"knives":
			_knives(event.source_id)


## A burst of [param count] fire squares from the target's chest and a flash of [param flash].
func _burst_at(id: int, kind: StringName, count: int, speed: float, flash: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var at: Vector2 = target.position + Vector2(0, -AIM_HEIGHT)
	var glow: FxParticle = _particle(kind)
	if glow != null:
		glow.shape = FxParticle.Shape.PUFF
		glow.color = Palette.color(&"amber")
		glow.size = flash
		glow.life = 0.16
		glow.start(at)
	var colors: Array = FAMILIES[&"fire"]
	for i: int in count:
		var bit: FxParticle = _particle(kind)
		if bit == null:
			break
		var color_name: StringName = colors[i % colors.size()]
		bit.color = Palette.color(color_name)
		bit.size = 3 if i % 3 == 0 else 2
		var angle: float = TAU * (i + _rng.randf()) / count
		bit.velocity = Vector2.from_angle(angle) * _rng.randf_range(0.4, 1.0) * speed
		bit.gravity = 160.0
		bit.floor_y = target.position.y
		bit.life = _rng.randf_range(0.3, 0.55)
		bit.start(at)


## The ice shard breaks on its target: pale splinters flying out and falling.
func _shatter(id: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var at: Vector2 = target.position + Vector2(0, -AIM_HEIGHT)
	var colors: Array = FAMILIES[&"frost"]
	for i: int in 12:
		var bit: FxParticle = _particle(&"ice_shard")
		if bit == null:
			break
		var color_name: StringName = colors[i % colors.size()]
		bit.color = Palette.color(color_name)
		bit.size = 2 if i % 2 == 0 else 1
		bit.velocity = Vector2.from_angle(TAU * i / 12.0) * _rng.randf_range(60.0, 140.0)
		bit.gravity = 320.0
		bit.floor_y = target.position.y
		bit.life = _rng.randf_range(0.3, 0.5)
		bit.start(at)


## A ring of frost that spreads both ways along the floor from the target.
func _frost_burst(id: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var feet: Vector2 = target.position + Vector2(0, -1)
	var colors: Array = FAMILIES[&"frost"]
	for i: int in 18:
		var bit: FxParticle = _particle(&"frost_burst")
		if bit == null:
			break
		var color_name: StringName = colors[i % colors.size()]
		bit.color = Palette.color(color_name)
		bit.size = 3 if i % 4 == 0 else 2
		var side: float = -1.0 if i % 2 == 0 else 1.0
		bit.velocity = Vector2(side * _rng.randf_range(50.0, 130.0), _rng.randf_range(-40.0, -5.0))
		bit.gravity = 260.0
		bit.drag = 2.5
		bit.floor_y = feet.y
		bit.bounce = 0.2
		bit.life = _rng.randf_range(0.4, 0.65)
		bit.start(feet)


## Flakes falling over fighter [param id].
func _flakes(id: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var colors: Array = FAMILIES[&"frost"]
	for i: int in 8:
		var bit: FxParticle = _particle(&"blizzard")
		if bit == null:
			break
		var color_name: StringName = colors[i % colors.size()]
		bit.color = Palette.color(color_name)
		bit.size = 2 if i % 3 == 0 else 1
		bit.velocity = Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(28.0, 45.0))
		bit.life = _rng.randf_range(0.6, 0.85)
		var over := Vector2(_rng.randf_range(-11.0, 11.0), -_rng.randf_range(28.0, 40.0))
		bit.start(target.position + over.round())


## A jagged line of spark squares from [param from] to [param to].
func _bolt_line(from: Vector2, to: Vector2) -> void:
	var colors: Array = FAMILIES[&"spark"]
	var steps: int = clampi(ceili(from.distance_to(to) / 3.0), 1, 24)
	var across: Vector2 = (to - from).orthogonal().normalized()
	for i: int in steps + 1:
		var bit: FxParticle = _particle(&"chain_spark")
		if bit == null:
			break
		var u: float = float(i) / steps
		var jag: float = 0.0 if i == 0 or i == steps else _rng.randf_range(-3.0, 3.0)
		var color_name: StringName = colors[i % colors.size()]
		bit.color = Palette.color(color_name)
		bit.size = 1
		bit.life = _rng.randf_range(0.16, 0.26)
		bit.start(from.lerp(to, u) + across * jag)


## Flames licking up fighter [param id].
func _flames(id: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var colors: Array = FAMILIES[&"fire"]
	for i: int in 9:
		var bit: FxParticle = _particle(&"flames")
		if bit == null:
			break
		var color_name: StringName = colors[i % colors.size()]
		bit.color = Palette.color(color_name)
		bit.size = 3 if i % 3 == 0 else 2
		bit.velocity = Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-60.0, -28.0))
		bit.life = _rng.randf_range(0.3, 0.55)
		bit.start(target.position + Vector2(_rng.randf_range(-6.0, 6.0), -2.0).round())


## A column of pale gold light standing on fighter [param id], with motes rising in it.
func _column(id: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var feet: Vector2 = target.position
	for spec: Array in [[&"yellow", 9, 0.5], [&"white", 3, 0.45]]:
		var light: FxParticle = _particle(&"light_column")
		if light == null:
			return
		var color_name: StringName = spec[0]
		light.shape = FxParticle.Shape.COLUMN
		light.color = Palette.color(color_name)
		light.size = spec[1]
		light.height = 40
		light.life = spec[2]
		light.start(feet)
	for i: int in 5:
		var mote: FxParticle = _particle(&"light_column")
		if mote == null:
			break
		mote.color = Palette.color(&"sand" if i % 2 == 0 else &"white")
		mote.size = 1
		mote.velocity = Vector2(0, -_rng.randf_range(30.0, 55.0))
		mote.life = _rng.randf_range(0.4, 0.6)
		mote.start(
			feet + Vector2(_rng.randf_range(-4.0, 4.0), -_rng.randf_range(2.0, 14.0)).round()
		)


## A beam of light from under the HUD's top band onto fighter [param id], flashing at its feet: it
## never covers the boss bar or the panels there (R8).
func _beam(id: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var feet: Vector2 = target.position
	var height: int = maxi(roundi(feet.y - _band_top()), 16)
	for spec: Array in [[&"yellow", 5], [&"white", 1]]:
		var beam: FxParticle = _particle(&"holy_beam")
		if beam == null:
			return
		var color_name: StringName = spec[0]
		beam.shape = FxParticle.Shape.COLUMN
		beam.color = Palette.color(color_name)
		beam.size = spec[1]
		beam.height = height
		beam.life = 0.28
		beam.start(feet)
	_flash(&"holy_beam", feet + Vector2(0, -3), &"sand", 10)


## Knives flying out from fighter [param id] in a fan, the way it faces.
func _knives(id: int) -> void:
	var thrower: CharacterSprite = _world.character(id)
	if thrower == null:
		return
	var facing: float = 1.0 if (thrower.get_node("Mirror") as Node2D).scale.x > 0.0 else -1.0
	var at: Vector2 = thrower.position + Vector2(4.0 * facing, -AIM_HEIGHT)
	var colors: Array = FAMILIES[&"steel"]
	for i: int in 7:
		var knife: FxParticle = _particle(&"knives")
		if knife == null:
			break
		var angle: float = lerpf(-0.6, 0.6, i / 6.0)
		var color_name: StringName = colors[i % colors.size()]
		knife.color = Palette.color(color_name)
		knife.size = 2
		knife.velocity = Vector2(cos(angle) * facing, sin(angle)) * 170.0
		knife.life = 0.3
		knife.start(at)


## A violet puff of shadow on fighter [param id], wisps curling off it.
func _shadow(id: int) -> void:
	var target: CharacterSprite = _world.character(id)
	if target == null:
		return
	var at: Vector2 = target.position + Vector2(0, -AIM_HEIGHT)
	_flash(&"shadow", at, &"plum", 12)
	var colors: Array = FAMILIES[&"shadow"]
	for i: int in 8:
		var wisp: FxParticle = _particle(&"shadow")
		if wisp == null:
			break
		var color_name: StringName = colors[i % colors.size()]
		wisp.color = Palette.color(color_name)
		wisp.shape = FxParticle.Shape.PUFF
		wisp.size = 3 if i % 2 == 0 else 2
		wisp.velocity = Vector2.from_angle(TAU * i / 8.0) * 22.0 + Vector2(0, -18.0)
		wisp.drag = 2.0
		wisp.life = _rng.randf_range(0.4, 0.6)
		wisp.start(at)


func _flash(kind: StringName, at: Vector2, color_name: StringName, size: int) -> void:
	var flash: FxParticle = _particle(kind)
	if flash == null:
		return
	flash.shape = FxParticle.Shape.PUFF
	flash.color = Palette.color(color_name)
	flash.size = size
	flash.life = 0.14
	flash.start(at)


# --- Making and placing --------------------------------------------------------


func _particle(kind: StringName) -> FxParticle:
	if _particles.size() >= MAX_PARTICLES:
		return null
	var made := FxParticle.new()
	made.name = "Spell"
	made.kind = kind
	_world.effects_layer.add_child(made)
	_particles.append(made)
	return made


func _drop(particle: FxParticle) -> void:
	_particles.erase(particle)
	if particle.get_parent() != null:
		particle.get_parent().remove_child(particle)
	particle.queue_free()


## The world row just under the HUD's top band (the boss bar, the panels there).
func _band_top() -> float:
	var zoom: float = _world.camera.zoom.y if _world.camera != null else 1.0
	return ceilf(_screen_top() + (Hud.TOP_BAND + 1.0) / zoom)


## The world row at the top of the screen.
func _screen_top() -> float:
	var camera: WorldCamera = _world.camera
	if camera == null:
		return 0.0
	var view: Vector2 = (
		camera.get_viewport_rect().size if camera.is_inside_tree() else WorldCamera.FALLBACK_VIEW
	)
	return camera.position.y + camera.offset.y - view.y / 2.0 / camera.zoom.y
