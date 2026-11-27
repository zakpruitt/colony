extends "res://tests/unit/abilities_on_screen_test_base.gd"
## Spec 057's helpers for its acceptance tests (tests/acceptance/test_057_lively_moves.gd), on top
## of spec 056's rig: reading a move from a sprite's Rig node and its drawn pixels, the spell
## visuals, an ordinary swing, a hop, and fights with every class's full tree.

var _part_pixels: Dictionary[String, Array] = {}


func _rig(sprite: CharacterSprite) -> Node2D:
	return sprite.get_node("Mirror/Rig") as Node2D


func _hero_sprite(class_id: StringName) -> CharacterSprite:
	var sprite: CharacterSprite = CharacterSprite.for_hero(class_id)
	add_child_autofree(sprite)
	sprite.set_process(false)
	sprite.position = Vector2(200, 200)
	return sprite


## The biggest turn of any part of [param sprite] from its rest, in radians.
func _part_turn(sprite: CharacterSprite) -> float:
	var most: float = 0.0
	for node: Node in _rig(sprite).get_children():
		most = maxf(most, absf((node as Node2D).rotation))
	return most


## The move's own share of [param sprite]'s pose is nothing.
func _move_at_rest(sprite: CharacterSprite) -> bool:
	return sprite.moves.at_rest()


func _spells() -> SpellEffects:
	return _fx.spell_effects


func _opaque_pixels(atlas: AtlasTexture) -> Array:
	var key: String = "%s %s" % [atlas.atlas.resource_path, atlas.region]
	if _part_pixels.has(key):
		return _part_pixels[key]
	var image: Image = atlas.atlas.get_image()
	if image == null or image.is_empty():
		image = Image.load_from_file(ProjectSettings.globalize_path(atlas.atlas.resource_path))
	if image.is_compressed():
		image.decompress()
	var region := Rect2i(atlas.region)
	var found: Array = []
	for y: int in region.size.y:
		for x: int in region.size.x:
			if image.get_pixel(region.position.x + x, region.position.y + y).a >= 0.5:
				found.append(Vector2(x, y))
	_part_pixels[key] = found
	return found


## The world pixels [param sprite] covers as drawn now; its weapon left out if [param body_only].
func _drawn(sprite: CharacterSprite, body_only: bool) -> Dictionary[Vector2i, bool]:
	var covered: Dictionary[Vector2i, bool] = {}
	if not sprite.visible:
		return covered
	var to_world: Transform2D = _world.global_transform.affine_inverse()
	for node: Node in sprite.find_children("*", "Sprite2D", true, false):
		var part: Sprite2D = node as Sprite2D
		var atlas: AtlasTexture = part.texture as AtlasTexture
		if not part.is_visible_in_tree() or atlas == null or atlas.atlas == null:
			continue
		if body_only and part.name == "weapon":
			continue
		var drawn: Transform2D = to_world * part.global_transform
		for pixel: Vector2 in _opaque_pixels(atlas):
			var at: Vector2 = drawn * (part.offset + pixel + Vector2(0.5, 0.5))
			covered[Vector2i(floori(at.x), floori(at.y))] = true
	return covered


func _shares(a: Dictionary[Vector2i, bool], b: Dictionary[Vector2i, bool]) -> bool:
	for pixel: Vector2i in a:
		if b.has(pixel):
			return true
	return false


## The box around [param sprite]'s pixels as drawn now, in world pixels.
func _drawn_rect(sprite: CharacterSprite) -> Rect2:
	var pixels: Dictionary[Vector2i, bool] = _drawn(sprite, false)
	if pixels.is_empty():
		return Rect2()
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for pixel: Vector2i in pixels:
		low = Vector2i(mini(low.x, pixel.x), mini(low.y, pixel.y))
		high = Vector2i(maxi(high.x, pixel.x), maxi(high.y, pixel.y))
	return Rect2(Vector2(low), Vector2(high - low + Vector2i.ONE))


func _only_on(kind: StringName, on: int, others: Array[int], label: String) -> void:
	var shown: Array[FxParticle] = _spells().particles(kind)
	assert_gt(shown.size(), 0, "%s shows" % label)
	var x: float = _world.character(on).position.x
	for particle: FxParticle in shown:
		assert_almost_eq(particle.position.x, x, 12.0, "%s shows on whom it reached" % label)
	for other: int in others:
		var at: float = _world.character(other).position.x
		if absf(at - x) < 24.0:
			continue  # a neighbour within 24 px is held by the first loop's 12 px
		for particle: FxParticle in shown:
			assert_gt(absf(particle.position.x - at), 12.0, "%s leaves %d out" % [label, other])


func _swing(sprite: CharacterSprite, ranged: bool) -> Vector2:
	sprite.play_attack(0.3, ranged)
	var span := Vector2.ZERO
	for i: int in 60:
		sprite.advance(FRAME)
		var x: float = _rig(sprite).position.x
		span = Vector2(minf(span.x, x), maxf(span.y, x))
	return span


## How high hero [param id] hops in the next half second, from its moves' share of the pose.
func _hop(id: int) -> float:
	var sprite: CharacterSprite = _world.character(id)
	var rise: float = -sprite.moves.shift.y
	for i: int in 30:
		_frame()
		rise = maxf(rise, -sprite.moves.shift.y)
	return rise


func _full_trees_of(simulation: Simulation) -> void:
	for hero: Hero in simulation.party.heroes:
		hero.gain_xp(Hero.xp_for_level(TREE_LEVEL) - hero.xp)
		var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
		hero.set_talents(tree.path(PATHS[hero.class_id]).nodes)
		hero.health = hero.max_health()


## Steps [param simulation] (with a frame after each tick if [param watched]) to the end of its
## first fight from now: the tick it ended on, or -1.
func _first_fight_end(simulation: Simulation, watched: bool) -> int:
	var fought: bool = false
	for i: int in FIGHT_LIMIT_TICKS:
		simulation.step()
		if watched:
			for f: int in 6:
				_frame()
		fought = fought or simulation.expedition.state == Expedition.State.FIGHTING
		if fought and simulation.expedition.state != Expedition.State.FIGHTING:
			return simulation.tick
	return -1
