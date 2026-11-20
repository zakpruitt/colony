class_name FxGuardianWave
extends RefCounted
## One wave of a guardian's burst, waiting to go off: seconds until it does, where,
## and in which colours. [CombatEffects] counts it down and calls [method burst].

var due: float = 0.0
var count: int = 0
var index: int = 0
var middle: Vector2 = Vector2.ZERO
var feet_y: float = 0.0
var reach: Vector2 = Vector2.ONE
var colors: PackedColorArray = []


## [param distinct] (the colours of [param sprite]'s sheet), each repeated in proportion to how
## many of the sheet's pixels it colours, most used first, every one at least once.
static func weighted_colors(
	sprite: CharacterSprite, distinct: PackedColorArray
) -> PackedColorArray:
	var sheet: Texture2D = SpriteBounds.sheet_of(sprite)
	var image: Image = sheet.get_image() if sheet != null else null
	if image == null or image.is_empty() or distinct.is_empty():
		return distinct
	if image.is_compressed():
		image.decompress()
	var counts: Dictionary[String, int] = {}
	var total: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			pixel.a = 1.0
			var key: String = pixel.to_html(false)
			counts[key] = counts.get(key, 0) + 1
			total += 1
	var order: Array[Color] = []
	for color: Color in distinct:
		order.append(color)
	order.sort_custom(
		func(a: Color, b: Color) -> bool:
			return counts.get(a.to_html(false), 0) > counts.get(b.to_html(false), 0)
	)
	var weighted: PackedColorArray = []
	for color: Color in order:
		var used: int = counts.get(color.to_html(false), 0)
		var share: int = roundi(24.0 * used / maxf(total, 1.0))
		for i: int in maxi(share, 1):
			weighted.append(color)
	return weighted


## One wave: the first bursts out from the middle in every direction, the second from points
## across the body, the last rises from it in slow embers. Each opens with a flash and a ring.
func burst(fx: CombatEffects, rng: RandomNumberGenerator, spark: Texture2D) -> void:
	var from: Vector2 = middle
	if index == 1:
		from += Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.3)) * reach
	from = from.round()
	var flash_size: int = 36 - 10 * mini(index, 2)
	var flash: FxParticle = fx.new_particle(&"flash", CombatEffects.GUARDIAN_ALLOWANCE)
	if flash != null:
		flash.shape = FxParticle.Shape.PUFF
		flash.color = Palette.color(&"white" if index == 0 else &"yellow")
		flash.size = flash_size
		flash.life = 0.18
		flash.start(from)
	var ring: FxParticle = fx.new_particle(&"flash", CombatEffects.GUARDIAN_ALLOWANCE)
	if ring != null:
		ring.shape = FxParticle.Shape.PUFF
		ring.color = colors[0]
		ring.size = flash_size + 12
		ring.life = 0.26
		ring.start(from)
	for i: int in count:
		var bit: FxParticle = fx.new_particle(&"guardian", CombatEffects.GUARDIAN_ALLOWANCE)
		if bit == null:
			break
		bit.color = colors[rng.randi_range(0, colors.size() - 1)]
		bit.floor_y = feet_y
		var at: Vector2 = from
		match index:
			0:
				var angle: float = TAU * (i + rng.randf_range(0.0, 0.8)) / count
				var speed: float = rng.randf_range(120.0, 280.0)
				bit.velocity = Vector2(cos(angle), sin(angle) * 0.8 - 0.35) * speed
				bit.gravity = CombatEffects.GUARDIAN_GRAVITY
				bit.drag = 1.2
				bit.size = rng.randi_range(3, 5)
				bit.bounce = 0.4
				bit.life = rng.randf_range(0.8, 1.15)
			1:
				var spot := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
				at = middle + spot * reach
				var angle: float = rng.randf_range(PI * 1.05, PI * 1.95)
				bit.velocity = Vector2(cos(angle), sin(angle)) * rng.randf_range(80.0, 200.0)
				bit.gravity = CombatEffects.GUARDIAN_GRAVITY
				bit.size = rng.randi_range(2, 4)
				bit.bounce = 0.35
				bit.life = rng.randf_range(0.7, 1.0)
			_:
				at = middle + Vector2(rng.randf_range(-1.0, 1.0) * reach.x, 0.0)
				bit.velocity = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-90.0, -40.0))
				bit.gravity = -30.0
				bit.size = rng.randi_range(2, 3)
				bit.texture = spark if i % 3 == 0 else null
				bit.life = rng.randf_range(0.8, 1.2)
		bit.start(at.round())
