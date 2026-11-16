class_name CombatEffects
extends Node2D
## Turns simulation events into impact (spec 010): damage and heal numbers, hit sparks, a shake and
## a hit-stop on a crit, monsters bursting, coins bouncing out and flying to the purse, XP motes,
## level-up bursts, bolt trails, and the beats of the loop (rest, wipe, revival, a stable depth).
##
## It listens to [signal World.sim_event] and draws on [member World.effects_layer], so its effects
## move with the world. Everything moves only in [method advance], from elapsed time, so a test can
## step it exactly; [code]_process[/code] calls it once a frame, after the world has synced.
## Every effect ends by shrinking, blinking or flying away, and frees itself.

## One coin of a gold gain has reached the gold target; amount is that coin's share.
signal coin_collected(amount: int)

# Caps (R11).
## The most numbers on screen at once; further numbers are not shown.
const MAX_NUMBERS: int = 40
## The most particles at once; further particles are not made.
const MAX_PARTICLES: int = 300

# Numbers (R1, R2).
## Font multiples of a number, and of a crit.
const NUMBER_SCALE: int = 2
const CRIT_SCALE: int = 3
## Seconds a number lives, and a crit (both under the spec's 0.8).
const NUMBER_LIFE: float = 0.7
const CRIT_LIFE: float = 0.78
## A number's leap upward and drift sideways, in pixels per second, and its fall.
const NUMBER_LEAP: float = 95.0
const NUMBER_DRIFT: float = 22.0
const NUMBER_GRAVITY: float = 230.0
## How high on the target a number appears, as a share of the sprite's height above its feet.
const NUMBER_HEIGHT: float = 0.62
## Numbers on one target within this many seconds of each other stack: each further one starts
## STACK_STEP pixels higher and is pushed to alternate sides.
const STACK_WINDOW: float = 0.35
const STACK_STEP: float = 8.0
const STACK_SIDE: float = 5.0
const STACK_MAX: int = 4

# Sparks (R3).
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

# Weight (R4).
## Pixels of camera shake for a crit and for a hero's death.
const CRIT_SHAKE: float = 2.5
const HERO_DEATH_SHAKE: float = 6.0
## Seconds every character's animation stands still on a crit.
const CRIT_FREEZE: float = 0.06

# Bursts (R5).
const BURST_MIN: int = 10
const BURST_MAX: int = 20
const BURST_GRAVITY: float = 380.0
const PUFF_SIZE: int = 14
const PUFF_LIFE: float = 0.3

# Coins (R6).
## One coin per this much gold, at least 1 and at most COINS_MAX.
const GOLD_PER_COIN: int = 5
const COINS_MAX: int = 12

# XP (R7).
## One mote per this much XP, at least 1 and at most MOTES_MAX.
const XP_PER_MOTE: int = 10
const MOTES_MAX: int = 3

# Level up (R8).
const LEVEL_UP_TIME: float = 1.2
const LEVEL_UP_PARTICLES: int = 22

# Bolts (R9).
## A trail square is dropped every this many pixels of a bolt's flight.
const TRAIL_STEP: float = 2.0
const TRAIL_LIFE: float = 0.16

# Beats (R10).
## Seconds between a resting hero's z's.
const Z_EVERY: float = 1.1
const BANNER_LIFE_STABLE: float = 2.0
## How far above the middle of the screen the depth banner sits, so it never covers WIPED.
const STABLE_RAISE: float = 40.0
const LIGHT_HEIGHT: int = 44
const LIGHT_LIFE: float = 0.55

## Where coins fly to, in screen pixels. The HUD sets it.
var gold_screen_target: Vector2 = Vector2(600, 12)

var _world: World
var _simulation: Simulation
var _rng := RandomNumberGenerator.new()
var _spark_texture: Texture2D

var _texts: Array[FxText] = []
var _particles: Array[FxParticle] = []
var _coins: Array[FxCoin] = []
var _motes: Array[FxMote] = []
## Seconds of effects time so far: the clock numbers stack by.
var _clock: float = 0.0
## Per target id: Vector2(when its last number appeared, how many are stacked).
var _stacks: Dictionary[int, Vector2] = {}
## Where the last monster fell (its feet), for the XP and gold that follow its DIED.
var _fallen_at: Vector2 = Vector2.ZERO
## Per bolt (instance id): where its trail last dropped a square; and the bolts already flashed.
var _trail_from: Dictionary[int, Vector2] = {}
var _flashed: Dictionary[int, bool] = {}
## Resting, and each hero's seconds to its next z.
var _resting: bool = false
var _z_in: Dictionary[int, float] = {}
## A revival seen this frame, shown once the world has put the heroes back on their feet.
var _revival_due: bool = false
## Colours of each monster sheet, by its path.
var _sheet_colors: Dictionary[String, PackedColorArray] = {}


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
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)


## Advances every effect. Called every frame; tests call it.
func advance(delta: float) -> void:
	if _world == null or _world.effects_layer == null:
		return
	_clock += delta
	if _revival_due:
		_revival_due = false
		_revival_lights()
	_follow_bolts()
	_rest_z(delta)
	for particle: FxParticle in _particles.duplicate():
		if not particle.advance(delta):
			_particles.erase(particle)
			particle.queue_free()
	for text: FxText in _texts.duplicate():
		if text.on_screen:
			text.set_anchor(_screen_to_world(_view_size() * 0.5 + text.screen_offset))
		elif text.follow_id >= 0 and _world.character(text.follow_id) != null:
			text.set_anchor(_world.feet_position(text.follow_id) + text.screen_offset)
		if not text.advance(delta):
			_texts.erase(text)
			text.queue_free()
	var purse: Vector2 = _screen_to_world(gold_screen_target)
	for coin: FxCoin in _coins.duplicate():
		if coin.advance(delta, purse):
			_coins.erase(coin)
			coin.queue_free()
			coin_collected.emit(coin.share)
	for mote: FxMote in _motes.duplicate():
		var hero: CharacterSprite = _world.character(mote.hero_id)
		if hero == null:
			_motes.erase(mote)
			mote.queue_free()
			continue
		if mote.advance(delta, _chest(mote.hero_id)):
			_flash(mote.position, Palette.color(&"cyan"), 5)
			_motes.erase(mote)
			mote.queue_free()


## How many numbers are on screen.
func live_numbers() -> int:
	var count: int = 0
	for text: FxText in _texts:
		if text.kind == &"damage" or text.kind == &"heal":
			count += 1
	return count


## How many particles exist.
func live_particles() -> int:
	return _particles.size()


# --- Events --------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	var recent: bool = _world.is_recent(event)
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
		SimEvent.Kind.LEVEL_UP:
			if recent:
				_level_up(event.target_id)
		SimEvent.Kind.REST_STARTED:
			_resting = true
			_z_in.clear()
		SimEvent.Kind.REST_ENDED, SimEvent.Kind.ENCOUNTER_STARTED:
			_resting = false
		SimEvent.Kind.PARTY_WIPED:
			_resting = false
			if recent:
				_banner("WIPED", &"red", 3, Expedition.REVIVE_SECONDS, Vector2.ZERO)
		SimEvent.Kind.PARTY_REVIVED:
			if recent:
				_revival_due = true
		SimEvent.Kind.STABLE_DEPTH_REACHED:
			if recent:
				var words: String = "DEPTH %d STABLE" % event.amount
				_banner(words, &"yellow", 2, BANNER_LIFE_STABLE, Vector2(0, -STABLE_RAISE))


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
		var spark: FxParticle = _particle(&"spark")
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
		var sparkle: FxParticle = _particle(&"sparkle")
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
	if recent:
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
		var bit: FxParticle = _particle(&"burst")
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
	var puff: FxParticle = _particle(&"puff")
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
		_world.effects_layer.add_child(mote)
		_motes.append(mote)


func _gold(event: SimEvent) -> void:
	var source: CharacterSprite = _world.character(event.source_id)
	var feet: Vector2 = source.position if source != null else _fallen_at
	var count: int = coin_count(event.amount)
	for i: int in count:
		var coin := FxCoin.new()
		coin.name = "Coin"
		coin.share = coin_share(event.amount, count, i)
		coin.floor_y = feet.y - 4.0
		coin.velocity = Vector2(_rng.randf_range(-75.0, 75.0), _rng.randf_range(-170.0, -100.0))
		coin.rest_time = 0.35 + 0.05 * i
		coin.age = _rng.randf_range(0.0, 0.3)
		coin.start(feet + Vector2(_rng.randf_range(-3.0, 3.0), -12.0).round())
		_world.effects_layer.add_child(coin)
		_coins.append(coin)


## How many coins a gain of [param amount] gold shows: one per GOLD_PER_COIN, 1 to COINS_MAX.
static func coin_count(amount: int) -> int:
	return clampi(amount / GOLD_PER_COIN, 1, COINS_MAX)


## The share of coin [param index] of [param count] in a gain of [param amount]: equal shares,
## the remainder spread one each over the first coins, so the shares add up to the amount.
static func coin_share(amount: int, count: int, index: int) -> int:
	return amount / count + (1 if index < amount % count else 0)


func _level_up(hero_id: int) -> void:
	var hero: CharacterSprite = _world.character(hero_id)
	if hero == null:
		return
	var feet: Vector2 = hero.position
	var colors: Array[StringName] = [&"yellow", &"amber", &"white", &"orange"]
	for i: int in LEVEL_UP_PARTICLES:
		var bit: FxParticle = _particle(&"rise")
		if bit == null:
			break
		bit.color = Palette.color(colors[i % colors.size()])
		bit.texture = _spark_texture if i % 4 == 0 else null
		bit.size = 1 + i % 2
		bit.velocity = Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-75.0, -30.0))
		bit.gravity = -25.0
		bit.life = _rng.randf_range(0.6, LEVEL_UP_TIME)
		bit.start(
			feet + Vector2(_rng.randf_range(-11.0, 11.0), -_rng.randf_range(0.0, 8.0)).round()
		)
	var words: FxText = _text(&"banner")
	words.text = "LEVEL UP"
	words.color = Palette.color(&"yellow")
	words.scale_factor = 1
	words.life = LEVEL_UP_TIME
	words.velocity = Vector2(0, -6)
	words.follow_id = hero_id
	words.screen_offset = Vector2(0, -32)
	words.start(feet + words.screen_offset)


func _banner(
	words: String, color_name: StringName, factor: int, life: float, offset: Vector2
) -> void:
	var banner: FxText = _text(&"banner")
	banner.text = words
	banner.color = Palette.color(color_name)
	banner.scale_factor = factor
	banner.life = life
	banner.on_screen = true
	banner.screen_offset = offset
	banner.start(_screen_to_world(_view_size() * 0.5 + offset))


func _revival_lights() -> void:
	for hero: Hero in _simulation.party.heroes:
		var sprite: CharacterSprite = _world.character(hero.id)
		if sprite == null:
			continue
		var outer: FxParticle = _particle(&"light")
		if outer == null:
			return
		outer.shape = FxParticle.Shape.COLUMN
		outer.color = Palette.color(&"yellow")
		outer.size = 12
		outer.height = LIGHT_HEIGHT
		outer.life = LIGHT_LIFE
		outer.start(sprite.position)
		var core: FxParticle = _particle(&"light")
		if core == null:
			return
		core.shape = FxParticle.Shape.COLUMN
		core.color = Palette.color(&"white")
		core.size = 6
		core.height = LIGHT_HEIGHT
		core.life = LIGHT_LIFE
		core.start(sprite.position)


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
			var piece: FxParticle = _particle(&"trail")
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
				var bit: FxParticle = _particle(&"flash")
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


## While the party rests, a z drifts up from each living hero now and then.
func _rest_z(delta: float) -> void:
	if not _resting:
		return
	var index: int = 0
	for hero: Hero in _simulation.party.heroes:
		index += 1
		var sprite: CharacterSprite = _world.character(hero.id)
		if sprite == null or sprite.is_dead():
			continue
		var due: float = _z_in.get(hero.id, 0.15 + 0.27 * index) - delta
		if due > 0.0:
			_z_in[hero.id] = due
			continue
		_z_in[hero.id] = Z_EVERY
		var z: FxText = _text(&"z")
		z.text = "z"
		z.color = Palette.color(&"silver")
		z.life = 1.3
		z.velocity = Vector2(5, -16)
		z.sway = 2.0
		z.sway_period = 0.9
		z.start(sprite.position + Vector2(4, -26))


# --- Making effects ------------------------------------------------------------


## A number over [param target_id], stacked off any it showed a moment ago, or nothing at the cap.
func _number(
	target_id: int, words: String, color_name: StringName, factor: int, kind: StringName
) -> void:
	if live_numbers() >= MAX_NUMBERS:
		return
	var target: CharacterSprite = _world.character(target_id)
	var stack: Vector2 = _stacks.get(target_id, Vector2(-INF, -1))
	var count: int = int(stack.y) + 1 if _clock - stack.x < STACK_WINDOW else 0
	count = count % (STACK_MAX + 1)
	_stacks[target_id] = Vector2(_clock, count)
	var side: float = 0.0
	if count > 0:
		side = STACK_SIDE if count % 2 == 1 else -STACK_SIDE
	var at: Vector2 = target.position + Vector2(side, -roundf(_height(target) * NUMBER_HEIGHT))
	at.y -= STACK_STEP * count
	var number: FxText = _text(kind)
	number.text = words
	number.color = Palette.color(color_name)
	number.scale_factor = factor
	number.life = CRIT_LIFE if factor > NUMBER_SCALE else NUMBER_LIFE
	var drift: float = _rng.randf_range(0.4, 1.0) * NUMBER_DRIFT
	if side != 0.0:
		drift *= signf(side)
	elif _rng.randi_range(0, 1) == 0:
		drift = -drift
	number.velocity = Vector2(drift, -NUMBER_LEAP)
	number.gravity = NUMBER_GRAVITY
	number.start(at)


func _text(kind: StringName) -> FxText:
	var made := FxText.new()
	made.name = "Text"
	made.kind = kind
	_world.effects_layer.add_child(made)
	_texts.append(made)
	return made


## A new particle on the effects layer, or null at the cap.
func _particle(kind: StringName) -> FxParticle:
	if _particles.size() >= MAX_PARTICLES:
		return null
	var made := FxParticle.new()
	made.name = "Particle"
	made.kind = kind
	_world.effects_layer.add_child(made)
	_particles.append(made)
	return made


## A bright square that shrinks away in a moment, where something struck or arrived.
func _flash(at: Vector2, color: Color, size: int) -> void:
	var flash: FxParticle = _particle(&"flash")
	if flash == null:
		return
	flash.shape = FxParticle.Shape.PUFF
	flash.color = color
	flash.size = size
	flash.life = 0.12
	flash.start(at)


# --- Reading the world ---------------------------------------------------------


## The canvas height of a character's sprite, in pixels.
func _height(sprite: CharacterSprite) -> float:
	for part: Node in sprite.find_children("*", "Sprite2D", true, false):
		var texture: Texture2D = (part as Sprite2D).texture
		if texture != null:
			return float(texture.get_height())
	return 24.0


## A point on a hero's chest, where motes fly to.
func _chest(hero_id: int) -> Vector2:
	return _world.feet_position(hero_id) + Vector2(0, -14)


## Every colour drawn in the sheet of [param sprite] other than its ink outline, read from the
## sheet's pixels once per sheet.
func _colors_of(sprite: CharacterSprite) -> PackedColorArray:
	var sheet: Texture2D = null
	for part: Node in sprite.find_children("*", "Sprite2D", true, false):
		var atlas: AtlasTexture = (part as Sprite2D).texture as AtlasTexture
		if atlas != null:
			sheet = atlas.atlas
			break
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


## The world pixel under the screen pixel [param screen], through the world's camera.
func _screen_to_world(screen: Vector2) -> Vector2:
	var camera: WorldCamera = _world.camera
	if camera == null:
		return screen
	return camera.position + camera.offset - _view_size() * 0.5 + screen
