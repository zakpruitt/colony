class_name CharacterSprite
extends Node2D
## A hero or monster drawn from its part-based sheet (docs/style-bible.md) and animated in code:
## it breathes, walks, winds up and strikes, flinches and dies (spec 007).
##
## Every pose is computed in [method advance] from elapsed time, never from a wall clock or a
## Tween, so a test can step it exactly. The pose has layers: a base loop (idle or walk), and
## on top of it an attack, a hit and a death, each with its own timer. When a layer ends its
## channels are not computed at all, so the parts return exactly to their rest transforms.
##
## Nodes: this node is where the character stands. Its child Mirror flips it to face left,
## Mirror's child Rig moves the whole body (bob, lean, lunge, knockback, squash), and Rig's
## children are the parts, one Sprite2D each, named as in the sheet and turning around their
## own pivots. Idle motion moves a part's [member Sprite2D.offset] by whole pixels, so it never
## disturbs a part's transform.

## Fires at the moment an attack is released: the end of its wind-up.
signal struck
## Fires once, when the death collapse has ended and the character is hidden.
signal died

enum Style {
	HUMANOID,  ## Has a head: the head and arm bob as it breathes.
	FLIER,  ## Has wings: it hovers and beats them.
	CRAWLER,  ## Has legs but no head: its body bobs over its legs.
	BLOB,  ## Nothing else: the whole body squashes and stretches.
}

const HEROES_DIR: String = "res://assets/sprites/heroes"
const MONSTERS_DIR: String = "res://assets/sprites/monsters"
const FLASH_SHADER: Shader = preload("res://game/entities/flash.gdshader")

# Idle.
## Seconds for one breath.
const BREATH_PERIOD: float = 1.9
## How far a blob squashes as it breathes (a fraction of its height).
const BLOB_BREATH: float = 0.07
## Seconds for one hover of a flier, and how many pixels it rises and falls.
const HOVER_PERIOD: float = 1.3
const HOVER_HEIGHT: float = 1.5
## Seconds for one wing beat, and how many pixels a wing moves up and down while hovering.
const WING_BEAT: float = 0.36
const WING_LIFT: float = 2.0
## Seconds between blinks, and how long the eyes stay shut.
const BLINK_EVERY: float = 3.3
const BLINK_TIME: float = 0.12

# Walking.
## Seconds per step: the body bobs once per step, a swinging part swings once per two.
const STEP_TIME: float = 0.3
## How many pixels the body rises on each step (a blob hops higher).
const STEP_HOP: float = 1.5
const BLOB_HOP: float = 3.0
## How far the body leans into its walk, in radians.
const WALK_LEAN: float = 0.08
## How far an arm and its weapon swing, and how far legs swing, in radians.
const ARM_SWING: float = 0.3
const LEG_SWING: float = 0.25
## How far wings beat while flying, in radians.
const WING_SWING: float = 0.6
## Seconds to blend between standing and walking.
const WALK_BLEND: float = 0.15

# Attacks. The attack curve runs from -1 (fully wound up) through 0 (rest) to +1 (struck).
## Seconds for the strike itself, from wound up to past the rest pose.
const STRIKE_TIME: float = 0.06
## Seconds the strike's follow-through is held, so the eye catches it.
const HOLD_TIME: float = 0.14
## Seconds to settle back from the follow-through to rest.
const SETTLE_TIME: float = 0.22
## How far the arm turns back (melee) or up (ranged) when wound up, and forward when struck.
const MELEE_WINDUP_TURN: float = 1.2
const MELEE_STRIKE_TURN: float = 1.0
const RANGED_WINDUP_TURN: float = 1.2
const RANGED_STRIKE_TURN: float = 0.5
## How much further the weapon turns at the hand, back when wound up and forward when struck.
## A ranged wind-up turns it the other way, so the arm lifts it high but keeps it upright.
const WEAPON_WINDUP_TURN: float = 0.5
const WEAPON_STRIKE_TURN: float = 0.35
const WEAPON_RANGED_WINDUP_TURN: float = -0.6
## How many pixels the body shifts back while winding up and forward on the strike.
const BODY_WINDUP_SHIFT: float = 1.5
const BODY_STRIKE_SHIFT: float = 2.5
## How many pixels a character with no arm or weapon gathers back and then lunges.
const LUNGE_BACK: float = 3.0
const LUNGE_FORWARD: float = 7.0

# Hits.
## Seconds the character shows solid white when hit.
const FLASH_TIME: float = 0.08
## Seconds the whole flinch lasts, how far it is knocked back, and how fast it gets there.
const HIT_TIME: float = 0.3
const KNOCKBACK: float = 3.0
const KNOCK_OUT_TIME: float = 0.04
## Seconds the hit squash lasts and how strong it is at first.
const HIT_SQUASH_TIME: float = 0.14
const HIT_SQUASH: float = 0.18

# Death.
## Seconds of the whole collapse (under the spec's 0.4), and of the pop that starts it.
const DEATH_TIME: float = 0.34
const DEATH_POP_TIME: float = 0.07

## How far apart in their cycles two characters created one after another start (a fraction of a
## cycle: the golden ratio spreads any number of them evenly).
const PHASE_SPREAD: float = 0.618034

static var _created: int = 0

var _sheet: PixelSheet
var _mirror: Node2D
var _rig: Node2D
var _flash: ShaderMaterial
var _style: Style = Style.BLOB
var _parts: Dictionary[StringName, Sprite2D] = {}
var _rest_position: Dictionary[StringName, Vector2] = {}
var _rest_offset: Dictionary[StringName, Vector2] = {}
var _wings: Array[StringName] = []
var _legs: Array[StringName] = []
## Where the weapon's pivot is relative to the arm's, so the weapon turns with the arm.
var _weapon_from_arm: Vector2 = Vector2.ZERO

var _phase: float = 0.0
var _time: float = 0.0
var _facing: int = 1
var _walking: bool = false
var _walk_weight: float = 0.0
var _walk_time: float = 0.0
## Seconds since the attack started, or -1 when there is none.
var _attack_time: float = -1.0
var _windup: float = 0.0
var _ranged: bool = false
var _released: bool = false
## Seconds since a wind-up was cancelled, or -1 when none is easing back; and where on the attack
## curve it was when cancelled.
var _cancel_time: float = -1.0
var _cancel_from: float = 0.0
## Seconds since the hit, or -1 when there is none.
var _hit_time: float = -1.0
## Seconds since play_death(), or -1 when not dying.
var _death_time: float = -1.0
var _dead: bool = false

# The pose being built in _apply_pose: whole-body channels and per-part channels.
var _rig_shift: Vector2
var _rig_turn: float
var _rig_scale: Vector2
var _part_turn: Dictionary[StringName, float] = {}
var _part_nudge: Dictionary[StringName, Vector2] = {}


## A character showing every part of the sheet baked at [param sheet_path] (a res:// .png),
## composed as drawn and standing with the sprite's pivot at this node's position.
## Returns null, with an error naming the file, if the sheet cannot be loaded.
static func create(sheet_path: String) -> CharacterSprite:
	if not ResourceLoader.exists(sheet_path):
		push_error("CharacterSprite: no sheet at %s; bake its .px source" % sheet_path)
		return null
	var sheet: PixelSheet = PixelSheet.load_sheet(sheet_path)
	if sheet == null:
		return null
	var character := CharacterSprite.new()
	character._build(sheet, sheet_path)
	return character


## The hero whose class is [param class_id], from assets/sprites/heroes/<id>.png.
static func for_hero(class_id: StringName) -> CharacterSprite:
	return create("%s/%s.png" % [HEROES_DIR, class_id])


## The monster [param monster_id], from assets/sprites/monsters/<id>.png.
static func for_monster(monster_id: StringName) -> CharacterSprite:
	return create("%s/%s.png" % [MONSTERS_DIR, monster_id])


func _process(delta: float) -> void:
	advance(delta)


## Stands still, breathing. Ends a walk; an attack or a hit in progress plays on.
func play_idle() -> void:
	if not _dead:
		_walking = false


## Walks in place: a quicker bob, a lean toward its facing and swinging limbs.
func play_walk() -> void:
	if not _dead:
		_walking = true


## Winds up for [param windup_seconds] (drawing back, or raising the weapon if [param ranged]),
## strikes past the rest pose, emitting [signal struck], and settles back. A character with no
## arm or weapon lunges with its whole body instead.
func play_attack(windup_seconds: float, ranged: bool) -> void:
	if _dead:
		return
	_attack_time = 0.0
	_windup = maxf(windup_seconds, 0.0)
	_ranged = ranged
	_released = false
	_cancel_time = -1.0
	_apply_pose()


## Ends an attack still in its wind-up without the strike: [signal struck] does not fire and the
## character eases back to rest and to what it was doing. After the strike, or with no attack,
## does nothing.
func cancel_attack() -> void:
	if _attack_time < 0.0 or _released:
		return
	_cancel_from = _attack_curve()
	_attack_time = -1.0
	_cancel_time = 0.0
	_apply_pose()


## Flashes white, flinches back from its facing with a squash, and recovers to what it was doing.
func play_hit() -> void:
	if _dead:
		return
	_hit_time = 0.0
	_apply_pose()


## Pops, collapses, then hides and emits [signal died]. Later calls do nothing until
## [method revive].
func play_death() -> void:
	if _dead:
		return
	_dead = true
	_death_time = 0.0
	_walking = false
	_attack_time = -1.0
	_cancel_time = -1.0
	_hit_time = -1.0
	_apply_pose()


## After a death: visible, idle and alive again, at rest. [signal died] fires again on a later
## death. Does nothing to a living character.
func revive() -> void:
	if not _dead:
		return
	_dead = false
	_death_time = -1.0
	_walking = false
	_walk_weight = 0.0
	_walk_time = 0.0
	_attack_time = -1.0
	_cancel_time = -1.0
	_hit_time = -1.0
	_reset_pose()
	visible = true


## Faces right for 1 and left for -1, mirroring in place around the pivot.
func set_facing(direction: int) -> void:
	_facing = -1 if direction < 0 else 1
	_mirror.scale = Vector2(_facing, 1)
	# The pivot pixel covers x from 0 to 1; mirroring about x = 0.5 keeps it there.
	_mirror.position = Vector2(0 if _facing > 0 else 1, 0)


## True from play_death() on, until revive().
func is_dead() -> bool:
	return _dead


## Advances animation by this much time. Called from _process; tests call it directly.
func advance(delta: float) -> void:
	if _dead and _death_time < 0.0:
		return
	_time += delta
	var target: float = 1.0 if _walking else 0.0
	_walk_weight = move_toward(_walk_weight, target, delta / WALK_BLEND)
	_walk_time = _walk_time + delta if _walk_weight > 0.0 else 0.0
	if _attack_time >= 0.0:
		_attack_time += delta
		if not _released and _attack_time >= _windup:
			_released = true
			struck.emit()
		if _attack_time >= _windup + STRIKE_TIME + HOLD_TIME + SETTLE_TIME:
			_attack_time = -1.0
	if _cancel_time >= 0.0:
		_cancel_time += delta
		if _cancel_time >= SETTLE_TIME:
			_cancel_time = -1.0
	if _hit_time >= 0.0:
		_hit_time += delta
		if _hit_time >= HIT_TIME:
			_hit_time = -1.0
	if _death_time >= 0.0:
		_death_time += delta
		if _death_time >= DEATH_TIME:
			_death_time = -1.0
			_reset_pose()
			visible = false
			died.emit()
			return
	_apply_pose()


func _build(sheet: PixelSheet, sheet_path: String) -> void:
	_sheet = sheet
	name = sheet_path.get_file().get_basename().to_pascal_case()
	_phase = fposmod(_created * PHASE_SPREAD, 1.0)
	_created += 1
	_mirror = Node2D.new()
	_mirror.name = "Mirror"
	add_child(_mirror)
	_rig = Node2D.new()
	_rig.name = "Rig"
	_flash = ShaderMaterial.new()
	_flash.shader = FLASH_SHADER
	_flash.set_shader_parameter("flash", 0.0)
	_rig.material = _flash
	_mirror.add_child(_rig)
	for part_name: String in sheet.part_names:
		var key: StringName = StringName(part_name)
		var pivot: Vector2i = sheet.part_pivot(key)
		var part := Sprite2D.new()
		part.name = part_name
		part.texture = sheet.part(key)
		part.centered = false
		part.use_parent_material = true
		part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_rest_offset[key] = -Vector2(pivot)
		_rest_position[key] = Vector2(pivot - sheet.pivot)
		part.offset = _rest_offset[key]
		part.position = _rest_position[key]
		_rig.add_child(part)
		_parts[key] = part
		if part_name.begins_with("wing"):
			_wings.append(key)
		elif part_name.begins_with("leg"):
			_legs.append(key)
	if _parts.has(&"arm") and _parts.has(&"weapon"):
		_weapon_from_arm = Vector2(sheet.part_pivot(&"weapon") - sheet.part_pivot(&"arm"))
	if _parts.has(&"head"):
		_style = Style.HUMANOID
	elif not _wings.is_empty():
		_style = Style.FLIER
	elif not _legs.is_empty():
		_style = Style.CRAWLER
	set_facing(1)


func _apply_pose() -> void:
	_rig_shift = Vector2.ZERO
	_rig_turn = 0.0
	_rig_scale = Vector2.ONE
	_part_turn.clear()
	_part_nudge.clear()
	var flash: float = 0.0

	_pose_breath(1.0 - _walk_weight)
	if _walk_weight > 0.0:
		_pose_walk(_walk_weight)
	if _attack_time >= 0.0:
		_pose_attack(_attack_curve())
	if _cancel_time >= 0.0:
		_pose_attack(_cancel_from * (1.0 - smoothstep(0.0, 1.0, _cancel_time / SETTLE_TIME)))
	if _hit_time >= 0.0:
		_pose_hit(_hit_time)
		if _hit_time < FLASH_TIME:
			flash = 1.0
	if _death_time >= 0.0:
		_pose_death(_death_time)
		if _death_time < DEATH_POP_TIME:
			flash = 1.0

	_rig.position = _rig_shift
	_rig.rotation = _rig_turn
	_rig.scale = _rig_scale
	_flash.set_shader_parameter("flash", flash)
	for key: StringName in _parts:
		var part: Sprite2D = _parts[key]
		part.offset = _rest_offset[key] + _nudge_of(key)
		part.transform = Transform2D(_turn_of(key), _rest_position[key])
	if _parts.has(&"arm") and _parts.has(&"weapon"):
		var arm: Sprite2D = _parts[&"arm"]
		var weapon: Sprite2D = _parts[&"weapon"]
		weapon.transform = arm.transform * Transform2D(_turn_of(&"weapon"), _weapon_from_arm)
	if _parts.has(&"eyes"):
		var blink: float = fposmod(_time + _phase * BLINK_EVERY, BLINK_EVERY)
		_parts[&"eyes"].visible = blink >= BLINK_TIME


func _reset_pose() -> void:
	_rig.position = Vector2.ZERO
	_rig.rotation = 0.0
	_rig.scale = Vector2.ONE
	_flash.set_shader_parameter("flash", 0.0)
	for key: StringName in _parts:
		_parts[key].offset = _rest_offset[key]
		_parts[key].transform = Transform2D(0.0, _rest_position[key])


## The idle layer, at [param weight] (it fades out while walking).
func _pose_breath(weight: float) -> void:
	if weight <= 0.0:
		return
	var breath: float = sin(TAU * (_time / BREATH_PERIOD + _phase))
	match _style:
		Style.HUMANOID:
			# On the out-breath the head, then the arm a moment later, sink one pixel.
			var lagged: float = sin(TAU * (_time / BREATH_PERIOD + _phase) - 0.7)
			_nudge(&"head", Vector2(0, _pixel(weight * (0.5 - 0.5 * breath))))
			var arm_drop: float = _pixel(weight * (0.5 - 0.5 * lagged))
			_nudge(&"arm", Vector2(0, arm_drop))
			_nudge(&"weapon", Vector2(0, arm_drop))
		Style.FLIER:
			var hover: float = sin(TAU * (_time / HOVER_PERIOD + _phase))
			_rig_shift.y += weight * HOVER_HEIGHT * (hover - 1.0)
			var beat: float = sin(TAU * (_time / WING_BEAT + _phase))
			for wing: StringName in _wings:
				_nudge(wing, Vector2(0, _pixel(weight * WING_LIFT * beat)))
		Style.CRAWLER:
			_nudge(&"body", Vector2(0, _pixel(weight * (0.5 - 0.5 * breath))))
		Style.BLOB:
			_rig_scale *= Vector2(
				1.0 - weight * BLOB_BREATH * breath, 1.0 + weight * BLOB_BREATH * breath
			)


## The walk layer, at [param weight] (it blends in and out over WALK_BLEND).
func _pose_walk(weight: float) -> void:
	# Offset by the character's phase (two steps a cycle), so a crowd does not march in step.
	var steps: float = _walk_time / STEP_TIME + 2.0 * _phase
	var hop: float = absf(sin(PI * steps))
	var swing: float = sin(PI * steps)
	match _style:
		Style.BLOB:
			_rig_shift.y -= weight * BLOB_HOP * hop
			var stretch: float = weight * 0.12 * (hop * 2.0 - 1.0)
			_rig_scale *= Vector2(1.0 - stretch, 1.0 + stretch)
			_rig_turn += weight * WALK_LEAN
		Style.FLIER:
			_rig_shift.y -= weight * STEP_HOP * hop
			_rig_turn += weight * WALK_LEAN
		_:
			_rig_shift.y -= weight * STEP_HOP * hop
			_rig_turn += weight * WALK_LEAN
	_turn(&"arm", weight * ARM_SWING * swing)
	for leg: StringName in _legs:
		var side: float = -1.0 if String(leg).ends_with("back") else 1.0
		_turn(leg, weight * LEG_SWING * swing * side)
	var beat: float = sin(TAU * (_walk_time / WING_BEAT + _phase))
	for wing: StringName in _wings:
		var side: float = -1.0 if String(wing).ends_with("back") else 1.0
		_turn(wing, weight * WING_SWING * beat * side)


## Where the attack is on its curve: -1 wound up, 0 at rest, +1 struck through.
func _attack_curve() -> float:
	var t: float = _attack_time
	if t < _windup:
		return -_ease_out(t / _windup)
	t -= _windup
	if t < STRIKE_TIME:
		return lerpf(-1.0, 1.0, _ease_out(t / STRIKE_TIME))
	t -= STRIKE_TIME
	if t < HOLD_TIME:
		return 1.0
	t -= HOLD_TIME
	return 1.0 - smoothstep(0.0, 1.0, t / SETTLE_TIME)


func _pose_attack(curve: float) -> void:
	var back: float = maxf(-curve, 0.0)
	var forward: float = maxf(curve, 0.0)
	if _parts.has(&"arm") or _parts.has(&"weapon"):
		var windup_turn: float = RANGED_WINDUP_TURN if _ranged else MELEE_WINDUP_TURN
		var strike_turn: float = RANGED_STRIKE_TURN if _ranged else MELEE_STRIKE_TURN
		var turn: float = forward * strike_turn - back * windup_turn
		if _parts.has(&"arm"):
			_turn(&"arm", turn)
			var cock: float = WEAPON_RANGED_WINDUP_TURN if _ranged else WEAPON_WINDUP_TURN
			_turn(&"weapon", forward * WEAPON_STRIKE_TURN - back * cock)
		else:
			_turn(&"weapon", turn)
		_rig_shift.x += forward * BODY_STRIKE_SHIFT - back * BODY_WINDUP_SHIFT
		_rig_turn += 0.07 * forward - 0.05 * back
		_turn(&"head", 0.12 * forward - 0.1 * back)
		return
	# No arm or weapon: gather back and squat, then lunge stretched out with the whole body.
	_rig_shift.x += forward * LUNGE_FORWARD - back * LUNGE_BACK
	_rig_scale *= Vector2(1.0 + 0.15 * back + 0.18 * forward, 1.0 - 0.18 * back - 0.1 * forward)
	_rig_turn += 0.12 * forward
	for wing: StringName in _wings:
		var side: float = -1.0 if String(wing).ends_with("back") else 1.0
		_turn(wing, side * (0.6 * back - 0.4 * forward))
	for leg: StringName in _legs:
		var side: float = -1.0 if String(leg).ends_with("back") else 1.0
		_turn(leg, side * 0.25 * (back - forward))


func _pose_hit(t: float) -> void:
	var knock: float
	if t < KNOCK_OUT_TIME:
		knock = t / KNOCK_OUT_TIME
	else:
		knock = 1.0 - smoothstep(0.0, 1.0, (t - KNOCK_OUT_TIME) / (HIT_TIME - KNOCK_OUT_TIME))
	_rig_shift.x -= KNOCKBACK * knock
	_rig_turn -= 0.1 * knock
	if t < HIT_SQUASH_TIME:
		var squash: float = HIT_SQUASH * (1.0 - t / HIT_SQUASH_TIME)
		_rig_scale *= Vector2(1.0 + squash, 1.0 - squash)
	_turn(&"head", -0.25 * knock)
	_turn(&"arm", -0.35 * knock)


func _pose_death(t: float) -> void:
	if t < DEATH_POP_TIME:
		var pop: float = t / DEATH_POP_TIME
		_rig_scale *= Vector2(1.0 - 0.15 * pop, 1.0 + 0.2 * pop)
		_rig_shift.y -= 2.0 * pop
		return
	var fall: float = (t - DEATH_POP_TIME) / (DEATH_TIME - DEATH_POP_TIME)
	var eased: float = fall * fall
	_rig_scale *= Vector2(0.85 + 0.75 * eased, 1.2 - 1.05 * eased)
	_rig_shift.y -= 2.0 * (1.0 - eased)
	_rig_shift.x -= 2.0 * eased
	_rig_turn -= 0.2 * eased
	_turn(&"head", -0.6 * eased)
	_turn(&"arm", 0.9 * eased)
	_turn(&"weapon", 0.6 * eased)


func _turn(key: StringName, radians: float) -> void:
	if _parts.has(key):
		_part_turn[key] = _turn_of(key) + radians


func _nudge(key: StringName, pixels: Vector2) -> void:
	if _parts.has(key):
		_part_nudge[key] = _nudge_of(key) + pixels


func _turn_of(key: StringName) -> float:
	return _part_turn[key] if _part_turn.has(key) else 0.0


func _nudge_of(key: StringName) -> Vector2:
	return _part_nudge[key] if _part_nudge.has(key) else Vector2.ZERO


## Rounds to whole pixels, so idle motion moves parts a pixel at a time and stays crisp.
static func _pixel(value: float) -> float:
	return roundf(value)


static func _ease_out(u: float) -> float:
	var clamped: float = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - clamped) * (1.0 - clamped)
