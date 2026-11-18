class_name CharacterMoves
extends RefCounted
## The moves a character performs for its abilities (spec 057), made in code from the parts it
## already has: no drawn frames. A [CharacterSprite] owns one, advances it and lays what it works
## out ([member shift], [member turn], [member scale], [member turns]) over the rest of its pose.
##
## A move is timed around its blow: it has a lead (the seconds until the blow falls, the action's
## wind-up) and a recovery after it ([constant RECOVER], at most 0.4 s). Before the blow it draws
## back, rises or gathers; on the blow it strikes, lands or thrusts; after it, it settles back to
## rest, so that when it ends nothing of it is left. A move with a lead plays in the main slot and
## replaces the one there; a move with none (a passive firing, a hop) plays in the second slot,
## over whatever the character is doing.
##
## Each move is one function here, `_pose_<name>`, and one row of [constant RECOVER]: adding a move
## is adding those two (and its name to [constant AbilityDef.MOVES], for an ability's move).
## Squash and stretch: a body is a little taller in the air and shorter and wider when it lands.

## Seconds of recovery after the blow, per move; [constant HOP] and [constant CHEER] are the
## view's own (spec 057 R5), played for a kill or crit and after a fight won.
const RECOVER: Dictionary[StringName, float] = {
	&"leap": 0.32,
	&"spin": 0.3,
	&"dash": 0.3,
	&"heavy_swing": 0.4,
	&"throw": 0.3,
	&"brace": 0.4,
	&"shout": 0.4,
	&"cast": 0.3,
	&"channel": 0.35,
	&"prayer": 0.4,
	&"flourish": 0.35,
	&"hop": 0.28,
	&"cheer": 0.5,
}
const HOP: StringName = &"hop"
const CHEER: StringName = &"cheer"

## Pixels: how high a leap goes, how far forward it may come down, how far a dash gathers back
## and how far forward it streaks, how high a cast and a channel lift, a hop and a cheer rise.
const LEAP_HEIGHT: float = 12.0
const LEAP_FORWARD: float = 8.0
const DASH_BACK: float = 8.0
const DASH_FORWARD: float = 10.0
const CAST_LIFT: float = 4.0
const CHANNEL_LIFT: float = 6.0
const SPIN_HOP: float = 3.0
const HOP_HEIGHT: float = 5.0
const CHEER_HEIGHT: float = 6.0
## The share of a lead spent on the strike itself at its end (a swing, a throw, a thrust).
const STRIKE_SHARE: float = 0.15
## Pixels from the feet to the toes and heels: a body turned lifts by this times the turn's sine,
## so leaning never puts a foot through the floor.
const FOOT_REACH: float = 8.0

## What the moves add to the pose now: the body's shift (x toward its facing), its turn, its scale
## (a multiplier) and each part's turn, in radians. Nothing (zero, one, empty) at rest.
var shift: Vector2 = Vector2.ZERO
var turn: float = 0.0
var scale: Vector2 = Vector2.ONE
var turns: Dictionary[StringName, float] = {}
## How many main moves have reached their blow, ever: a test sees a blow fall by this.
var impacts: int = 0

var _main: Slot
var _over: Slot
## The main move whose blow fell last, for [method landed_move].
var _landed: StringName = &""


## One move playing: its name, its seconds so far, its lead and recovery, and the room it has.
class Slot:
	var move: StringName
	var time: float = 0.0
	var lead: float = 0.0
	var recover: float = 0.0
	var room: float = INF
	var landed: bool = false

	## How far through the lead it is, 0 to 1 (1 once the blow has fallen, or with no lead).
	func before() -> float:
		return clampf(time / lead, 0.0, 1.0) if lead > 0.0 else 1.0

	## How far through the recovery it is, 0 before the blow to 1 at its end.
	func after() -> float:
		if time < lead:
			return 0.0
		return clampf((time - lead) / recover, 0.0, 1.0) if recover > 0.0 else 1.0

	## True before the blow.
	func early() -> bool:
		return time < lead


## Starts [param move] with its blow [param lead] seconds from now, going at most [param room]
## pixels toward its target, its recovery shortened by a game speed of [param pace].
func play(move: StringName, lead: float, room: float, pace: float) -> void:
	if not RECOVER.has(move):
		push_error("CharacterMoves: no move %s" % move)
		return
	var slot := Slot.new()
	slot.move = move
	slot.lead = maxf(lead, 0.0)
	slot.recover = RECOVER[move] / maxf(pace, 1.0)
	slot.room = maxf(room, 0.0)
	if slot.lead > 0.0:
		_main = slot
	else:
		slot.landed = true
		_over = slot
	pose()


## Brings the main move's blow forward to now, if it has not fallen yet: the simulation has
## just landed it (frames and ticks drift a little apart; a fight's last blow comes with its end).
func land() -> void:
	if _main == null or _main.landed:
		return
	_main.time = _main.lead
	_main.landed = true
	impacts += 1
	_landed = _main.move
	pose()


## Ends every move at once: nothing of any is left in the pose.
func stop() -> void:
	_main = null
	_over = null
	pose()


## Moves every move on by [param delta] seconds; one past its recovery ends.
func advance(delta: float) -> void:
	if _main != null:
		_main.time += delta
		if not _main.landed and _main.time >= _main.lead:
			_main.landed = true
			impacts += 1
			_landed = _main.move
		if _main.time >= _main.lead + _main.recover:
			_main = null
	if _over != null:
		_over.time += delta
		if _over.time >= _over.lead + _over.recover:
			_over = null
	pose()


## Works out what the moves add to the pose now, into [member shift], [member turn],
## [member scale] and [member turns].
func pose() -> void:
	shift = Vector2.ZERO
	turn = 0.0
	scale = Vector2.ONE
	turns.clear()
	for slot: Slot in [_main, _over]:
		if slot != null:
			call("_pose_" + String(slot.move), slot)
	if turn != 0.0:
		shift.y -= absf(sin(turn)) * FOOT_REACH


## The main move playing (an ability's, or a cheer), or &"" when none is.
func playing() -> StringName:
	return _main.move if _main != null else &""


## Every move playing: the main one first, then the one over it.
func names() -> Array[StringName]:
	var found: Array[StringName] = []
	for slot: Slot in [_main, _over]:
		if slot != null:
			found.append(slot.move)
	return found


## The main move whose blow fell most recently.
func landed_move() -> StringName:
	return _landed


## True while any move plays.
func is_moving() -> bool:
	return _main != null or _over != null


## True when the moves add nothing to the pose.
func at_rest() -> bool:
	return shift == Vector2.ZERO and turn == 0.0 and scale == Vector2.ONE and turns.is_empty()


# --- Moves ---------------------------------------------------------------------
# Each takes its slot and adds to the pose with _add. Angles: a part's turn below zero lifts the
# arm forward and up (a weapon held up turns back over the shoulder); above zero it chops forward
# and down. The body's x is toward its facing; y below zero is up.


## Jumps in an arc and comes down on the blow, in front of its target.
func _pose_leap(slot: Slot) -> void:
	var forward: float = minf(slot.room, LEAP_FORWARD)
	if slot.early():
		var u: float = slot.before()
		if u < 0.3:
			var g: float = _ease_out(u / 0.3)
			_add(Vector2(-2.0 * g, 0.0), 0.0, _squash(0.15 * g), {&"arm": -0.6 * g})
			return
		var s: float = (u - 0.3) / 0.7
		var air: float = sin(PI * s)
		var chop: float = smoothstep(0.75, 1.0, s)
		_add(
			Vector2(lerpf(-2.0, forward, s), -LEAP_HEIGHT * air),
			0.15 * s,
			_stretch(0.14 * air),
			{
				&"arm": lerpf(-1.8, 1.2, chop),
				&"weapon": lerpf(-0.6, 0.3, chop),
				&"head": -0.15 * air
			}
		)
		return
	var v: float = slot.after()
	var k: float = 1.0 - smoothstep(0.0, 1.0, v)
	var landing: float = (1.0 - v) * (1.0 - v)
	_add(
		Vector2(forward * k, 0.0),
		0.15 * k,
		_squash(0.22 * landing),
		{&"arm": 1.2 * k, &"weapon": 0.3 * k}
	)


## Turns right round with the weapon out, a little off the floor.
func _pose_spin(slot: Slot) -> void:
	if slot.early():
		var u: float = slot.before()
		if u < 0.25:
			var g: float = _ease_out(u / 0.25)
			_add(Vector2.ZERO, -0.12 * g, _squash(0.1 * g), {&"arm": -0.6 * g})
			return
		var s: float = (u - 0.25) / 0.75
		_add(
			Vector2(0.0, -SPIN_HOP * sin(PI * s)),
			0.0,
			Vector2(cos(TAU * s), 1.0 + 0.06 * sin(PI * s)),
			{&"arm": -1.3, &"weapon": 0.4}
		)
		return
	var v: float = slot.after()
	var k: float = 1.0 - smoothstep(0.0, 1.0, v)
	_add(
		Vector2.ZERO,
		0.08 * k,
		_squash(0.14 * (1.0 - v) * (1.0 - v)),
		{&"arm": -1.3 * k, &"weapon": 0.4 * k}
	)


## Gathers back, then streaks to its target and back.
func _pose_dash(slot: Slot) -> void:
	var forward: float = minf(slot.room, DASH_FORWARD)
	if slot.early():
		var u: float = slot.before()
		if u < 0.55:
			var g: float = _ease_out(u / 0.55)
			_add(Vector2(-DASH_BACK * g, 0.0), -0.08 * g, _squash(0.13 * g), {&"arm": -1.0 * g})
			return
		var s: float = (u - 0.55) / 0.45
		var e: float = s * s
		var streak: float = 0.25 * sin(PI * s)
		_add(
			Vector2(lerpf(-DASH_BACK, forward, e), 0.0),
			0.2 * s,
			Vector2(1.0 + streak, 1.0 - 0.5 * streak),
			{&"arm": lerpf(-1.0, 1.1, e), &"weapon": 0.3 * e}
		)
		return
	var v: float = slot.after()
	var k: float = 1.0 - smoothstep(0.0, 1.0, v)
	_add(
		Vector2(forward * k, 0.0),
		0.2 * k,
		_squash(0.12 * (1.0 - v) * (1.0 - v)),
		{&"arm": 1.1 * k, &"weapon": 0.3 * k}
	)


## A long draw back over the whole wind-up, then a big follow-through, held.
func _pose_heavy_swing(slot: Slot) -> void:
	var step: float = minf(slot.room, 4.0)
	var drawn: Dictionary[StringName, float] = {&"arm": -2.0, &"weapon": -0.7, &"head": -0.2}
	var through: Dictionary[StringName, float] = {&"arm": 1.2, &"weapon": 0.3, &"head": 0.15}
	_strike(
		slot,
		Vector2(-3.0, 0.0),
		-0.15,
		_stretch(0.1),
		drawn,
		Vector2(step, 0.0),
		0.22,
		_squash(0.15),
		through,
		0.35
	)


## The arm back over the shoulder, then a whip forward that lets go.
func _pose_throw(slot: Slot) -> void:
	var drawn: Dictionary[StringName, float] = {&"arm": -2.2, &"weapon": -0.4, &"head": -0.1}
	var through: Dictionary[StringName, float] = {&"arm": 1.1, &"weapon": 0.2, &"head": 0.1}
	_strike(
		slot,
		Vector2(-2.0, 0.0),
		-0.12,
		_stretch(0.07),
		drawn,
		Vector2(minf(slot.room, 2.0), 0.0),
		0.15,
		_squash(0.08),
		through,
		0.2
	)


## Crouches behind the shield, holds, and stands.
func _pose_brace(slot: Slot) -> void:
	var k: float = _envelope(slot, 0.4)
	_add(
		Vector2(-1.5 * k, 0.0),
		0.1 * k,
		_squash(0.15 * k),
		{&"head": 0.25 * k, &"arm": 0.6 * k, &"weapon": -0.3 * k}
	)


## Rears back with its weapon up, then lunges into the shout, puffed up.
func _pose_shout(slot: Slot) -> void:
	var drawn: Dictionary[StringName, float] = {&"arm": -1.6, &"head": -0.4}
	var through: Dictionary[StringName, float] = {&"arm": -1.2, &"weapon": 0.4, &"head": 0.2}
	_strike(
		slot,
		Vector2(-1.5, -1.0),
		-0.2,
		_stretch(0.08),
		drawn,
		Vector2(1.0, 0.0),
		0.12,
		Vector2(1.18, 1.1),
		through,
		0.4
	)


## Staff raised, the body lifts a little off the floor; then a thrust as it lands.
func _pose_cast(slot: Slot) -> void:
	_lift_and_thrust(slot, CAST_LIFT, {&"arm": -1.6, &"weapon": 0.5}, 0.0)


## Arms up and held, lifted higher and trembling; then a thrust down as it lands.
func _pose_channel(slot: Slot) -> void:
	_lift_and_thrust(slot, CHANNEL_LIFT, {&"arm": -2.6, &"weapon": 1.0, &"head": -0.3}, 0.6)


## Head bowed, then arms raised, lifted a little; held, then lowered.
func _pose_prayer(slot: Slot) -> void:
	var bowed: Dictionary[StringName, float] = {&"head": 0.5, &"arm": 0.5}
	var raised: Dictionary[StringName, float] = {&"head": -0.35, &"arm": -2.4, &"weapon": 0.7}
	if slot.early():
		var u: float = slot.before()
		var bow: float = _ease_out(minf(u / 0.45, 1.0))
		var lift: float = smoothstep(0.5, 1.0, u)
		var parts: Dictionary[StringName, float] = {}
		for key: StringName in [&"head", &"arm", &"weapon"]:
			parts[key] = lerpf(_part(bowed, key) * bow, _part(raised, key), lift)
		_add(
			Vector2(0.0, -3.0 * lift),
			lerpf(0.12 * bow, -0.05, lift),
			_squash(lerpf(0.06 * bow, -0.08, lift)),
			parts
		)
		return
	var k: float = _envelope(slot, 0.3)
	_add(Vector2(0.0, -3.0 * k), -0.05 * k, _stretch(0.08 * k), _times(raised, k))


## A short hop and a flick of the weapon, over whatever the character is doing.
func _pose_flourish(slot: Slot) -> void:
	var v: float = slot.after() if not slot.early() else 0.0
	var air: float = sin(PI * v)
	_add(
		Vector2(0.0, -HOP_HEIGHT * air),
		0.0,
		_bounce(v),
		{&"weapon": -0.8 * air, &"head": -0.1 * air}
	)


## A small hop of joy: a kill, a crit (spec 057 R5).
func _pose_hop(slot: Slot) -> void:
	var v: float = slot.after()
	_add(Vector2(0.0, -HOP_HEIGHT * sin(PI * v)), 0.0, _bounce(v), {})


## After a fight won: still until its turn (its lead), then a hop with the weapon raised.
func _pose_cheer(slot: Slot) -> void:
	if slot.early():
		return
	var v: float = slot.after()
	var air: float = sin(PI * v)
	var up: float = sin(PI * minf(v * 1.4, 1.0))
	_add(
		Vector2(0.0, -CHEER_HEIGHT * air),
		0.0,
		_bounce(v),
		{&"arm": -2.2 * up, &"weapon": 0.6 * up, &"head": -0.2 * up}
	)


# --- Shapes shared by moves --------------------------------------------------


## A strike: from rest to the drawn pose over the lead, to the follow-through in its last
## [constant STRIKE_SHARE], held for [param hold] of the recovery and settled back after.
func _strike(
	slot: Slot,
	back: Vector2,
	back_turn: float,
	back_scale: Vector2,
	drawn: Dictionary[StringName, float],
	forward: Vector2,
	forward_turn: float,
	forward_scale: Vector2,
	through: Dictionary[StringName, float],
	hold: float
) -> void:
	if slot.early():
		var u: float = slot.before()
		var g: float = _ease_out(minf(u / (1.0 - STRIKE_SHARE), 1.0))
		var s: float = _ease_out(maxf(u - (1.0 - STRIKE_SHARE), 0.0) / STRIKE_SHARE)
		var parts: Dictionary[StringName, float] = {}
		for key: StringName in _keys(drawn, through):
			parts[key] = lerpf(_part(drawn, key) * g, _part(through, key), s)
		_add(
			(back * g).lerp(forward, s),
			lerpf(back_turn * g, forward_turn, s),
			Vector2.ONE.lerp(back_scale, g).lerp(forward_scale, s),
			parts
		)
		return
	var k: float = _envelope(slot, hold)
	_add(forward * k, forward_turn * k, Vector2.ONE.lerp(forward_scale, k), _times(through, k))


## A spell: lifting [param lift] pixels with the arms as [param raised] over the lead (trembling by
## [param tremble] pixels), then a thrust forward that lands on the blow, and a settle.
func _lift_and_thrust(
	slot: Slot, lift: float, raised: Dictionary[StringName, float], tremble: float
) -> void:
	var thrust: Dictionary[StringName, float] = {&"arm": 0.9, &"weapon": 0.2, &"head": 0.1}
	if slot.early():
		var u: float = slot.before()
		var g: float = _ease_out(minf(u / (1.0 - STRIKE_SHARE), 1.0))
		var s: float = maxf(u - (1.0 - STRIKE_SHARE), 0.0) / STRIKE_SHARE
		var shake: float = tremble * g * sin(slot.time * TAU * 11.0) * (1.0 - s)
		var parts: Dictionary[StringName, float] = {}
		for key: StringName in _keys(raised, thrust):
			parts[key] = lerpf(_part(raised, key) * g, _part(thrust, key), _ease_out(s))
		_add(
			Vector2(1.5 * s + shake, -lift * g * (1.0 - s * s)),
			0.08 * s,
			Vector2.ONE.lerp(_stretch(0.08), g * (1.0 - s)),
			parts
		)
		return
	var v: float = slot.after()
	var k: float = 1.0 - smoothstep(0.0, 1.0, v)
	_add(Vector2(1.5 * k, 0.0), 0.08 * k, _squash(0.15 * (1.0 - v) * (1.0 - v)), _times(thrust, k))


## How strongly a held pose shows after the blow: whole until [param hold] of the recovery, then
## easing to nothing. With no lead the pose comes in over the first quarter first.
func _envelope(slot: Slot, hold: float) -> float:
	if slot.early():
		return _ease_out(slot.before())
	var v: float = slot.after()
	var rise: float = 1.0
	if slot.lead <= 0.0:
		rise = _ease_out(minf(v / 0.25, 1.0))
	if v < hold:
		return rise
	return rise * (1.0 - smoothstep(0.0, 1.0, (v - hold) / (1.0 - hold)))


## A hop's shape at [param v] of it: stretched going up, squashed as it lands.
static func _bounce(v: float) -> Vector2:
	if v > 0.8:
		return _squash(0.12 * sin(PI * (v - 0.8) / 0.2))
	return _stretch(0.1 * sin(PI * v / 0.8))


## Shorter and wider by [param amount] (a share of its size).
static func _squash(amount: float) -> Vector2:
	return Vector2(1.0 + amount, 1.0 - amount)


## Taller and narrower by [param amount].
static func _stretch(amount: float) -> Vector2:
	return Vector2(1.0 - 0.6 * amount, 1.0 + amount)


static func _ease_out(u: float) -> float:
	var clamped: float = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - clamped) * (1.0 - clamped)


static func _part(parts: Dictionary[StringName, float], key: StringName) -> float:
	return parts[key] if parts.has(key) else 0.0


static func _times(parts: Dictionary[StringName, float], k: float) -> Dictionary[StringName, float]:
	var scaled: Dictionary[StringName, float] = {}
	for key: StringName in parts:
		scaled[key] = parts[key] * k
	return scaled


static func _keys(
	a: Dictionary[StringName, float], b: Dictionary[StringName, float]
) -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in a.keys() + b.keys():
		if not keys.has(key):
			keys.append(key)
	return keys


func _add(
	by: Vector2, radians: float, times: Vector2, parts: Dictionary[StringName, float]
) -> void:
	shift += by
	turn += radians
	scale *= times
	for key: StringName in parts:
		if parts[key] != 0.0:
			turns[key] = _part(turns, key) + parts[key]
