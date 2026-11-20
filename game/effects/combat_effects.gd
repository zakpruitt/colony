class_name CombatEffects
extends Node2D
## Turns simulation events into impact: damage and heal numbers, hit sparks, a shake and
## a hit-stop on a crit, monsters bursting, coins bouncing out and flying to the purse, XP motes,
## bolt trails and a guardian's burst. Where a number starts is [NumberPlace]'s; the beats of the
## loop (a level up, rest, a wipe, a revival, a stable stage, a guardian's coming and its fall)
## are [LoopBeats]'.
##
## It listens to [signal World.sim_event] and makes its effects through the world's [FxPool]
## ([member World.fx]), on [member World.effects_layer], so they move with the world. Everything
## moves only in [method advance], from elapsed time, so a test can step it exactly;
## [code]_process[/code] calls it once a frame, after the world has synced, and it advances the
## pool. Every effect ends by shrinking, blinking or flying away, and the pool frees it.

## One coin of a gold gain has reached the gold target; amount is that coin's share.
signal coin_collected(amount: int)

# Caps.
## The most numbers on screen at once; further numbers are not shown.
const MAX_NUMBERS: int = 40
## The most particles at once; further particles are not made.
const MAX_PARTICLES: int = FxPool.COMBAT

# Numbers.
## Font multiples of a number, and of a crit.
const NUMBER_SCALE: int = 2
const CRIT_SCALE: int = 3
## Seconds a number lives, and a crit (both under 0.8).
const NUMBER_LIFE: float = 0.7
const CRIT_LIFE: float = 0.78
## A number's leap upward and drift sideways, in pixels per second, and its fall.
const NUMBER_LEAP: float = 95.0
const NUMBER_DRIFT: float = 22.0
const NUMBER_GRAVITY: float = 230.0
## How high on the target a number appears, as a share of the sprite's height above its feet.
const NUMBER_HEIGHT: float = 0.62
## Pixels across between the places a number may start ([NumberPlace]).
const NUMBER_STEP: float = NumberPlace.STEP

# Sparks.
const SPARK_SHEET: String = "res://assets/sprites/fx/spark.png"
const SPARKS_MIN: int = 4
const SPARKS_MAX: int = 8
## A crit throws this many, at least twice the most a hit throws.
const CRIT_SPARKS_MIN: int = 16
const CRIT_SPARKS_MAX: int = 20
const SPARK_GRAVITY: float = 420.0
## The colours of a hit's sparks, and of a crit's (brighter).
const SPARK_COLORS: Array[StringName] = [&"amber", &"orange", &"yellow"]
const CRIT_SPARK_COLORS: Array[StringName] = [&"white", &"yellow", &"white"]
## How high on the target the sparks fly from, as a share of the sprite's height.
const IMPACT_HEIGHT: float = 0.45

# Weight.
## Pixels of camera shake for a crit and for a hero's death.
const CRIT_SHAKE: float = 2.5
const HERO_DEATH_SHAKE: float = 6.0
## Seconds every character's animation stands still on a crit.
const CRIT_FREEZE: float = 0.06

# Bursts.
const BURST_MIN: int = 10
const BURST_MAX: int = 20
const BURST_GRAVITY: float = 380.0
const PUFF_SIZE: int = 14
const PUFF_LIFE: float = 0.3

# Coins.
## One coin per this much gold, at least 1 and at most COINS_MAX.
const GOLD_PER_COIN: int = 5
const COINS_MAX: int = 12

# XP.
## One mote per this much XP, at least 1 and at most MOTES_MAX.
const XP_PER_MOTE: int = 10
const MOTES_MAX: int = 3

## How far above a hero's feet LEVEL UP sits ([LoopBeats]).
const LEVEL_UP_RAISE: float = LoopBeats.LEVEL_UP_RAISE

# Bolts.
## A trail square is dropped every this many pixels of a bolt's flight.
const TRAIL_STEP: float = 2.0
const TRAIL_LIFE: float = 0.16

# Guardians.
## A guardian's death: a hard shake and a hit-stop.
const GUARDIAN_DEATH_SHAKE: float = 12.0
const GUARDIAN_FREEZE: float = 0.2
## Its burst, in three waves: seconds after the death each starts, and how many particles each
## throws, all in the guardian's own colours.
const GUARDIAN_WAVE_TIMES: Array[float] = [0.0, 0.32, 0.64]
const GUARDIAN_WAVE_SIZES: Array[int] = [34, 24, 18]
## The particles its death may make beyond MAX_PARTICLES: exactly its three waves and their
## flashes (two a wave).
const GUARDIAN_ALLOWANCE: int = 34 + 24 + 18 + 6
const GUARDIAN_GRAVITY: float = 300.0
## The coins of its gold: at least GUARDIAN_COINS_MIN, at most GUARDIAN_COINS_MAX.
const GUARDIAN_COINS_MIN: int = 20
const GUARDIAN_COINS_MAX: int = 28
## Where coins fly to, in screen pixels. The HUD sets it.
var gold_screen_target: Vector2 = Vector2(600, 12)
## Where each hero's XP motes fly to, in screen pixels, by hero id: its frame. The HUD sets it;
## a hero with none has its motes fly to its chest.
var frame_screen_targets: Dictionary[int, Vector2] = {}
## The effects of side quests and microskills, advanced with these.
var quest_effects: QuestEffects
## Abilities and statuses on screen, advanced with these.
var ability_effects: AbilityEffects
## Resource drops rising and flying to the purse, advanced with these.
var resource_effects: ResourceEffects
## Spells seen flying and landing, advanced with these.
var spell_effects: SpellEffects

var _world: World
var _simulation: Simulation
## The beats of the loop, advanced with these.
var _beats: LoopBeats
var _rng := RandomNumberGenerator.new()
var _spark_texture: Texture2D

## Where the last monster fell (its feet), for the XP and gold that follow its DIED.
var _fallen_at: Vector2 = Vector2.ZERO
## Per bolt (instance id): where its trail last dropped a square; and the bolts already flashed.
var _trail_from: Dictionary[int, Vector2] = {}
var _flashed: Dictionary[int, bool] = {}
## Colours of each monster sheet, by its path.
var _sheet_colors: Dictionary[String, PackedColorArray] = {}
## A guardian's burst waves still to come.
var _waves: Array[FxGuardianWave] = []


func _ready() -> void:
	process_priority = 2  # after the world has synced


func _process(delta: float) -> void:
	advance(delta)


## Call once, before the first advance.
func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	_rng.seed = 10
	var sheet: PixelSheet = PixelSheet.load_sheet(SPARK_SHEET)
	_spark_texture = sheet.part(&"spark") if sheet != null else null
	if ability_effects == null:
		ability_effects = AbilityEffects.new()
		ability_effects.name = "AbilityEffects"
		add_child(ability_effects)
	ability_effects.setup(world, simulation)  # it hears each event first: see _hit
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)
	if _beats == null:
		_beats = LoopBeats.new()
	_beats.setup(self, world, simulation, _rng, _spark_texture)  # it hears each event next
	if quest_effects == null:
		quest_effects = QuestEffects.new()
		quest_effects.name = "QuestEffects"
		add_child(quest_effects)
	quest_effects.setup(world, simulation)
	if resource_effects == null:
		resource_effects = ResourceEffects.new()
		add_child(resource_effects)
	resource_effects.setup(world, _screen_to_world)
	resource_effects.keep = ability_effects.keep_drop_in_band
	if spell_effects == null:
		spell_effects = SpellEffects.new()
		spell_effects.name = "SpellEffects"
		add_child(spell_effects)
	spell_effects.setup(world, simulation, ability_effects.credit)


## Advances every effect, the world's whole [FxPool] last. Called every frame; tests call it.
func advance(delta: float) -> void:
	if _world == null or _world.fx == null:
		return
	ability_effects.advance(delta)
	spell_effects.advance(delta)
	resource_effects.advance(delta)
	_beats.light_revival()
	_advance_waves(delta)
	_follow_bolts()
	_beats.advance(delta)
	_world.fx.advance(delta)


## How many numbers are on screen.
func live_numbers() -> int:
	var count: int = 0
	for text: FxText in texts():
		if text.kind == &"damage" or text.kind == &"heal":
			count += 1
	return count


## How many particles exist.
func live_particles() -> int:
	return _world.fx.count(&"combat") if _world != null and _world.fx != null else 0


## The words and numbers these effects show now, oldest first.
func texts() -> Array[FxText]:
	var found: Array[FxText] = []
	if _world != null and _world.fx != null:
		found.assign(_world.fx.nodes(&"combat_text"))
	return found


## The particles these effects show now, oldest first.
func particles() -> Array[FxParticle]:
	var found: Array[FxParticle] = []
	if _world != null and _world.fx != null:
		found.assign(_world.fx.nodes(&"combat"))
	return found


## The coins on their way now.
func coins() -> Array[FxCoin]:
	var found: Array[FxCoin] = []
	if _world != null and _world.fx != null:
		found.assign(_world.fx.nodes(&"coin"))
	return found


## The XP motes on their way now.
func motes() -> Array[FxMote]:
	var found: Array[FxMote] = []
	if _world != null and _world.fx != null:
		found.assign(_world.fx.nodes(&"mote"))
	return found


## The guardian in [param simulation]'s fight, or null when the fight has none (or there is no
## fight): a monster whose [member MonsterDef.guardian] is true.
static func battle_guardian(simulation: Simulation) -> Combatant:
	if simulation == null or simulation.expedition.battle == null:
		return null
	for monster: Combatant in simulation.expedition.battle.monsters:
		var def: MonsterDef = Content.monster(monster.def_id)
		if def != null and def.guardian:
			return monster
	return null


## True for the combatant id of a guardian seen in a fight.
func is_guardian(id: int) -> bool:
	return _world.guardians.has(id)


# --- Events --------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	var recent: bool = _world.may_animate(event)
	match event.kind:
		SimEvent.Kind.HIT:
			if recent:
				_hit(event)
		SimEvent.Kind.HEALED:
			if recent and event.amount >= 1:
				_healed(event)
		SimEvent.Kind.DIED:
			_died(event, recent)
		SimEvent.Kind.XP_GAINED:
			if recent:
				_xp(event)
		SimEvent.Kind.GOLD_GAINED:
			if recent:
				_gold(event)
			else:
				coin_collected.emit(event.amount)


func _hit(event: SimEvent) -> void:
	var target: CharacterSprite = _world.character(event.target_id)
	if target == null:
		return
	var feet: Vector2 = target.position
	var height: float = _height(target)
	var away: float = 1.0
	var attacker: CharacterSprite = _world.character(event.source_id)
	if attacker != null and not is_equal_approx(attacker.position.x, feet.x):
		away = signf(feet.x - attacker.position.x)
	var crit: bool = event.flag
	var on_monster: bool = event.target_id >= Expedition.FIRST_MONSTER_ID
	var color_name: StringName = &"white" if on_monster else &"red"
	if crit:
		color_name = &"amber"
	color_name = ability_effects.number_color(event, color_name)  # a status's own
	var words: String = str(event.amount) + ("!" if crit else "")
	_number(event.target_id, words, color_name, CRIT_SCALE if crit else NUMBER_SCALE, &"damage")
	var impact: Vector2 = feet + Vector2(-away * 3.0, -roundf(height * IMPACT_HEIGHT))
	var count: int = (
		_rng.randi_range(CRIT_SPARKS_MIN, CRIT_SPARKS_MAX)
		if crit
		else _rng.randi_range(SPARKS_MIN, SPARKS_MAX)
	)
	var colors: Array[StringName] = CRIT_SPARK_COLORS if crit else SPARK_COLORS
	for i: int in count:
		var spark: FxParticle = new_particle(&"spark")
		if spark == null:
			break
		spark.color = Palette.color(colors[i % colors.size()])
		spark.texture = _spark_texture if i % 2 == 0 else null
		spark.size = 3 if crit and i % 3 == 0 else 2
		var speed: float = _rng.randf_range(60.0, 150.0) * (1.4 if crit else 1.0)
		var angle: float = _rng.randf_range(-1.1, 0.35)
		spark.velocity = Vector2(cos(angle) * speed * away, sin(angle) * speed)
		spark.gravity = SPARK_GRAVITY
		spark.life = _rng.randf_range(0.22, 0.4) * (1.3 if crit else 1.0)
		spark.floor_y = feet.y
		spark.start(impact)
	_flash(impact, Palette.color(&"white"), 11 if crit else 5)
	if crit:
		_world.camera.shake(CRIT_SHAKE)
		_world.freeze(CRIT_FREEZE)


func _healed(event: SimEvent) -> void:
	var target: CharacterSprite = _world.character(event.target_id)
	if target == null:
		return
	_number(event.target_id, "+%d" % event.amount, &"green", NUMBER_SCALE, &"heal")
	var height: float = _height(target)
	for i: int in 6:
		var sparkle: FxParticle = new_particle(&"sparkle")
		if sparkle == null:
			break
		sparkle.color = Palette.color(&"green" if i % 2 == 0 else &"white")
		sparkle.texture = _spark_texture if i % 3 == 0 else null
		sparkle.size = 1 + i % 2
		sparkle.velocity = Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-40.0, -15.0))
		sparkle.life = _rng.randf_range(0.4, 0.7)
		var around := Vector2(_rng.randf_range(-9.0, 9.0), -_rng.randf_range(2.0, height * 0.8))
		sparkle.start(target.position + around.round())


func _died(event: SimEvent, recent: bool) -> void:
	var dying: CharacterSprite = _world.character(event.source_id)
	if event.source_id < Expedition.FIRST_MONSTER_ID:
		if recent:
			_world.camera.shake(HERO_DEATH_SHAKE)
		return
	if dying == null:
		return
	_fallen_at = dying.position
	if recent and is_guardian(event.source_id):
		_guardian_death(dying)
	elif recent:
		_burst(dying)


func _burst(dying: CharacterSprite) -> void:
	var feet: Vector2 = dying.position
	var height: float = _height(dying)
	var middle: Vector2 = feet + Vector2(0, -roundf(height * 0.4))
	var colors: PackedColorArray = _colors_of(dying)
	if colors.is_empty():
		colors = PackedColorArray([Palette.color(&"white")])
	var count: int = _rng.randi_range(14, 18)
	count = clampi(count, BURST_MIN, BURST_MAX)
	for i: int in count:
		var bit: FxParticle = new_particle(&"burst")
		if bit == null:
			break
		bit.color = colors[_rng.randi_range(0, colors.size() - 1)]
		bit.size = _rng.randi_range(2, 3)
		var angle: float = _rng.randf_range(PI * 1.05, PI * 1.95)
		var speed: float = _rng.randf_range(70.0, 170.0)
		bit.velocity = Vector2(cos(angle), sin(angle)) * speed
		bit.gravity = BURST_GRAVITY
		bit.floor_y = feet.y
		bit.bounce = 0.35
		bit.life = _rng.randf_range(0.55, 0.95)
		var spread := Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
		bit.start(middle + spread.round())
	var puff: FxParticle = new_particle(&"puff")
	if puff != null:
		puff.shape = FxParticle.Shape.PUFF
		puff.color = Palette.color(&"silver")
		puff.size = PUFF_SIZE
		puff.life = PUFF_LIFE
		puff.velocity = Vector2(0, -12)
		puff.start(middle)


func _xp(event: SimEvent) -> void:
	if _world.character(event.target_id) == null:
		return
	var count: int = clampi(event.amount / XP_PER_MOTE, 1, MOTES_MAX)
	for i: int in count:
		var mote := FxMote.new()
		mote.name = "XpMote"
		mote.hero_id = event.target_id
		mote.velocity = Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-130.0, -80.0))
		mote.age = -0.06 * i
		mote.start(_fallen_at + Vector2(_rng.randf_range(-4.0, 4.0), -10.0).round())
		mote.target = _mote_target.bind(mote.hero_id)
		mote.arrived.connect(_mote_arrived)
		_world.fx.add(mote, &"mote")


func _gold(event: SimEvent) -> void:
	var source: CharacterSprite = _world.character(event.source_id)
	var feet: Vector2 = source.position if source != null else _fallen_at
	var guardian: bool = is_guardian(event.source_id)
	var count: int = guardian_coin_count(event.amount) if guardian else coin_count(event.amount)
	for i: int in count:
		var coin := FxCoin.new()
		coin.name = "Coin"
		coin.share = coin_share(event.amount, count, i)
		coin.floor_y = feet.y - 4.0
		coin.velocity = Vector2(_rng.randf_range(-75.0, 75.0), _rng.randf_range(-170.0, -100.0))
		coin.rest_time = 0.35 + 0.05 * i
		if guardian:
			# A fountain: higher and wider, and they leave for the purse in a long stream.
			coin.velocity = Vector2(
				_rng.randf_range(-130.0, 130.0), _rng.randf_range(-260.0, -150.0)
			)
			coin.rest_time = 0.6 + 0.04 * i
		coin.age = _rng.randf_range(0.0, 0.3)
		coin.start(feet + Vector2(_rng.randf_range(-3.0, 3.0), -12.0).round())
		coin.target = _purse
		coin.arrived.connect(coin_collected.emit)
		_world.fx.add(coin, &"coin")


## How many coins a gain of [param amount] gold shows: one per GOLD_PER_COIN, 1 to COINS_MAX.
static func coin_count(amount: int) -> int:
	return clampi(amount / GOLD_PER_COIN, 1, COINS_MAX)


## How many coins a guardian's gain of [param amount] gold shows: one per GOLD_PER_COIN,
## GUARDIAN_COINS_MIN to GUARDIAN_COINS_MAX.
static func guardian_coin_count(amount: int) -> int:
	return clampi(amount / GOLD_PER_COIN, GUARDIAN_COINS_MIN, GUARDIAN_COINS_MAX)


## The share of coin [param index] of [param count] in a gain of [param amount]: equal shares,
## the remainder spread one each over the first coins, so the shares add up to the amount.
static func coin_share(amount: int, count: int, index: int) -> int:
	return amount / count + (1 if index < amount % count else 0)


# --- Guardians -----------------------------------------------------------------


## The biggest moment in the game: a hard shake, a hit-stop, then the guardian bursting in three
## waves of its own colours, each opening with a flash.
func _guardian_death(dying: CharacterSprite) -> void:
	_world.camera.shake(GUARDIAN_DEATH_SHAKE)
	_world.freeze(GUARDIAN_FREEZE)
	var feet: Vector2 = dying.position
	var height: float = _height(dying)
	var middle: Vector2 = feet + Vector2(0, -roundf(height * 0.45))
	# Its colours as often as its sheet uses them, so the burst reads as the guardian's body.
	var colors: PackedColorArray = FxGuardianWave.weighted_colors(dying, _colors_of(dying))
	if colors.is_empty():
		colors = PackedColorArray([Palette.color(&"white")])
	for i: int in GUARDIAN_WAVE_TIMES.size():
		var wave := FxGuardianWave.new()
		wave.due = GUARDIAN_WAVE_TIMES[i]
		wave.count = GUARDIAN_WAVE_SIZES[i]
		wave.index = i
		wave.middle = middle
		wave.feet_y = feet.y
		wave.reach = Vector2(maxf(height * 0.4, 6.0), maxf(height * 0.35, 6.0))
		wave.colors = colors
		_waves.append(wave)
	_advance_waves(0.0)


func _advance_waves(delta: float) -> void:
	for wave: FxGuardianWave in _waves.duplicate():
		wave.due -= delta
		if wave.due > 0.0:
			continue
		_waves.erase(wave)
		wave.burst(self, _rng, _spark_texture)


# --- Ongoing -------------------------------------------------------------------


## Drops trail squares behind every bolt in flight, and flashes each where it lands.
func _follow_bolts() -> void:
	var seen: Dictionary[int, bool] = {}
	for child: Node in _world.effects_layer.get_children():
		var bolt: Bolt = child as Bolt
		if bolt == null or bolt.is_queued_for_deletion():
			continue
		var id: int = bolt.get_instance_id()
		seen[id] = true
		var from: Vector2 = _trail_from.get(id, bolt.from)
		var gap: Vector2 = bolt.position - from
		var steps: int = mini(floori(gap.length() / TRAIL_STEP), 12)
		for i: int in steps:
			var piece: FxParticle = new_particle(&"trail")
			if piece == null:
				break
			piece.color = bolt.color
			piece.size = 2
			piece.life = TRAIL_LIFE * float(i + 1) / steps
			piece.start(from + gap * float(i + 1) / steps)
		if steps > 0:
			_trail_from[id] = bolt.position
		if bolt.arrived() and not _flashed.has(id):
			_flashed[id] = true
			_flash(bolt.position, bolt.head_color, 7)
			for i: int in 4:
				var bit: FxParticle = new_particle(&"flash")
				if bit == null:
					break
				bit.color = bolt.color
				bit.velocity = Vector2.from_angle(TAU * (i + 0.5) / 4.0) * 60.0
				bit.life = 0.18
				bit.start(bolt.position)
	for id: int in _trail_from.keys():
		if not seen.has(id):
			_trail_from.erase(id)
	for id: int in _flashed.keys():
		if not seen.has(id):
			_flashed.erase(id)


# --- Making effects ------------------------------------------------------------


## A number over [param target_id], placed so its whole path stays clear of the numbers already
## showing and on screen, or nothing at the cap.
func _number(
	target_id: int, words: String, color_name: StringName, factor: int, kind: StringName
) -> void:
	if live_numbers() >= MAX_NUMBERS:
		return
	var target: CharacterSprite = _world.character(target_id)
	var base: Vector2 = target.position + Vector2(0, -roundf(_height(target) * NUMBER_HEIGHT))
	var number: FxText = new_text(kind)
	number.text = words
	number.color = Palette.color(color_name)
	number.scale_factor = factor
	# A crit is drawn over every other number.
	number.z_index = 1 if factor > NUMBER_SCALE else 0
	number.life = CRIT_LIFE if factor > NUMBER_SCALE else NUMBER_LIFE
	number.gravity = NUMBER_GRAVITY
	var drift: float = _rng.randf_range(0.4, 1.0) * NUMBER_DRIFT
	var lean: float = -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
	var showing: Array[FxText] = texts()
	if NumberPlace.place(
		number, base, NUMBER_LEAP, drift, lean, target.position, _view_rect(), showing
	):
		show_text(number)
	else:
		number.free()  # nowhere is clear: like a number past the cap, it is not shown


## A new text of [param kind], not yet shown: [method show_text] puts it on the layer once it is
## placed.
func new_text(kind: StringName) -> FxText:
	var made := FxText.new()
	made.name = "Text"
	made.kind = kind
	made.follow = _keep_text
	return made


## Puts [param text] on the effects layer.
func show_text(text: FxText) -> void:
	_world.fx.add(text, &"combat_text")


## After each advance: a banner stays in the middle of the screen, a text over a fighter stays over
## it, and every text but a banner keeps off the health bars.
func _keep_text(text: FxText) -> bool:
	if text.on_screen:
		text.set_anchor(screen_middle(text.screen_offset))
		return true
	if text.follow_id >= 0 and _world.character(text.follow_id) != null:
		text.set_anchor(_world.feet_position(text.follow_id) + text.screen_offset)
	ability_effects.keep_text_in_band(text)
	return true


## A new particle on the effects layer, or null at the cap, raised by [param allowance] (only a
## guardian's death passes one).
func new_particle(kind: StringName, allowance: int = 0) -> FxParticle:
	var made := FxParticle.new()
	made.name = "Particle"
	made.kind = kind
	return made if _world.fx.add(made, &"combat", allowance) else null


## A bright square that shrinks away in a moment, where something struck or arrived.
func _flash(at: Vector2, color: Color, size: int) -> void:
	var flash: FxParticle = new_particle(&"flash")
	if flash == null:
		return
	flash.shape = FxParticle.Shape.PUFF
	flash.color = color
	flash.size = size
	flash.life = 0.12
	flash.start(at)


# --- Reading the world ---------------------------------------------------------


## The world pixel [param offset] screen pixels from the middle of the screen, where a banner
## stays.
func screen_middle(offset: Vector2) -> Vector2:
	return _screen_to_world(_view_size() * 0.5 + offset)


## The canvas height of a character's sprite, in pixels.
func _height(sprite: CharacterSprite) -> float:
	return SpriteBounds.canvas_height(sprite)


## Where hero [param hero_id]'s XP motes fly to: its frame on the screen when the HUD has said where
## that is, else its chest; not finite once the hero has no sprite.
func _mote_target(hero_id: int) -> Vector2:
	if _world.character(hero_id) == null:
		return Vector2.INF
	if frame_screen_targets.has(hero_id):
		return _screen_to_world(frame_screen_targets[hero_id])
	return _chest(hero_id)


func _mote_arrived(at: Vector2) -> void:
	_flash(at, Palette.color(&"cyan"), 5)


## Where coins fly to now, in world pixels.
func _purse() -> Vector2:
	return _screen_to_world(gold_screen_target)


## A point on a hero's chest, where motes fly to.
func _chest(hero_id: int) -> Vector2:
	return _world.feet_position(hero_id) + Vector2(0, -14)


## Every colour drawn in the sheet of [param sprite] other than its ink outline, read from the
## sheet's pixels once per sheet.
func _colors_of(sprite: CharacterSprite) -> PackedColorArray:
	var sheet: Texture2D = SpriteBounds.sheet_of(sprite)
	if sheet == null:
		return PackedColorArray()
	var path: String = sheet.resource_path
	if _sheet_colors.has(path):
		return _sheet_colors[path]
	var colors: PackedColorArray = sheet_colors(sheet)
	_sheet_colors[path] = colors
	return colors


## The distinct opaque colours of a sheet, without [code]ink[/code] unless it has nothing else.
static func sheet_colors(sheet: Texture2D) -> PackedColorArray:
	var image: Image = sheet.get_image()
	if image == null or image.is_empty():
		image = Image.load_from_file(ProjectSettings.globalize_path(sheet.resource_path))
	var colors: PackedColorArray = []
	if image == null or image.is_empty():
		return colors
	if image.is_compressed():
		image.decompress()
	var ink: Color = Palette.color(&"ink")
	var seen: Dictionary[String, bool] = {}
	var inked: bool = false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			pixel.a = 1.0
			if pixel.to_html(false) == ink.to_html(false):
				inked = true
				continue
			var key: String = pixel.to_html(false)
			if not seen.has(key):
				seen[key] = true
				colors.append(pixel)
	if colors.is_empty() and inked:
		colors.append(ink)
	return colors


func _view_size() -> Vector2:
	var camera: WorldCamera = _world.camera
	if camera != null and camera.is_inside_tree():
		return camera.get_viewport_rect().size
	return WorldCamera.FALLBACK_VIEW


## The part of the world on screen now.
func _view_rect() -> Rect2:
	var top_left: Vector2 = _screen_to_world(Vector2.ZERO)
	return Rect2(top_left, _screen_to_world(_view_size()) - top_left)


## The world pixel under the screen pixel [param screen], through the world's camera.
func _screen_to_world(screen: Vector2) -> Vector2:
	var camera: WorldCamera = _world.camera
	if camera == null:
		return screen
	return camera.position + camera.offset + (screen - _view_size() * 0.5) / camera.zoom
