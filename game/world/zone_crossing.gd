class_name ZoneCrossing
extends Node
## The crossing from one place to another (spec 054): while the party is between stages the
## screen dims to dark and a title names where it is arriving, then it opens on the new zone.
##
## A child of [World], which calls [method update] each frame after the events. Everything is
## worked out from the simulation's own clock, so a frame that steps many ticks shows the crossing
## where the simulation has got to (spec 054 R7), and at 2x or 4x it is only sooner.
##
## - A change of stage (CLIMBING) dims over the first [constant FADE_SHARE] of the climb, is dark
##   while the world changes stage (at [constant SWITCH_SHARE]) and opens over the last share, so
##   it ends exactly when the simulation's change of stage does.
## - A journey to another area dims over [constant FADE_SECONDS] and holds "Leaving <area>" for
##   its first half and the arrival's name for the second; it opens over [constant OPEN_SECONDS]
##   once the party has arrived. Once dark it stays at least as dark until the party arrives:
##   a journey that starts during a change of stage, or turns to a new destination (which starts
##   its clock again), never lights the screen on the way.
## - A revival on another stage (spec 048 as amended) holds on the fallen for
##   [constant FallenParty.HOLD_SECONDS], dims, names the stage, and opens over
##   [constant OPEN_SECONDS] as the heroes stand up.

## The share of a climb spent dimming, and the same at its end opening.
const FADE_SHARE: float = 0.25
## The share of a climb at which the world shows the stage it is going to: deep in the dark.
const SWITCH_SHARE: float = 0.5
## From this share of the climb on, the heroes are seen stepping out of the doorway.
const OUT_SHARE: float = 1.0 - FADE_SHARE
## Game seconds a journey or a revival takes to dim, and to open once it is over.
const FADE_SECONDS: float = 0.5
const OPEN_SECONDS: float = 0.5
## A hero this many pixels or less from the doorway's middle is gone through it.
const GONE_WITHIN: float = 0.5
## The title shows while the screen is at least this dark.
const TITLE_FROM: float = 0.5

var _darkness: float = 0.0
var _title: String = ""
## The tick the last arrival or revival elsewhere happened on, for the opening after it; -1 when
## there is none to open on.
var _opened_tick: int = -1
## The last PARTY_REVIVED heard, by tick, so the DEPTH_CHANGED after it is known for a revival.
var _revived_tick: int = -1
## The darkness of the last update while the party was between places (climbing or on its way),
## kept so a journey never lightens it; 0 once it is not.
var _held: float = 0.0


## How dark the screen is now, from 0 (not at all) to 1 (black).
func darkness() -> float:
	return _darkness


## The title over the dark: where the party is arriving, or "" when none shows.
func title() -> String:
	return _title


## True while a crossing dims the screen.
func is_crossing() -> bool:
	return _darkness > 0.0


## Takes note of an event the world has passed on: an arrival in another area, or a revival on
## another stage, opens the screen after it.
func heard(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.AREA_CHANGED:
			_opened_tick = event.tick
		SimEvent.Kind.PARTY_REVIVED:
			_revived_tick = event.tick
		SimEvent.Kind.DEPTH_CHANGED:
			if event.tick == _revived_tick:
				_opened_tick = event.tick  # a revival on another stage


## Works out the darkness and the title for [param simulation] as it is now.
func update(simulation: Simulation) -> void:
	var e: Expedition = simulation.expedition
	var now: int = simulation.tick
	var held: float = _held
	_darkness = 0.0
	_title = ""
	match e.state:
		Expedition.State.CLIMBING:
			var share: float = ClimbProgress.share(e)
			_darkness = clampf(minf(share, 1.0 - share) / FADE_SHARE, 0.0, 1.0)
			if e.travel.pending_area != &"":
				_name("Leaving " + PlaceText.area_name(e.place))  # a journey is ordered: it goes there
			else:
				_name(PlaceText.here(simulation, ClimbProgress.stage_to(e)))
		Expedition.State.JOURNEYING:
			var left: float = float(e.travel.arrive_tick - now) / Simulation.TICKS_PER_SECOND
			var since: float = AreaTravel.JOURNEY_SECONDS - left
			_darkness = maxf(clampf(since / FADE_SECONDS, 0.0, 1.0), held)
			var turning: bool = e.travel.pending_area != &""  # a new destination, taken next tick
			if turning or since < AreaTravel.JOURNEY_SECONDS / 2.0:
				_name("Leaving " + PlaceText.area_name(e.place))
			else:
				_name(PlaceText.of(e.area, e.travel.journey_stage(e)))
		Expedition.State.REVIVING:
			var back_to: int = int(e.revival_place().y)
			if back_to != e.depth:
				var left: float = float(e.revive_tick - now) / Simulation.TICKS_PER_SECOND
				var since: float = Expedition.REVIVE_SECONDS - left - FallenParty.HOLD_SECONDS
				_darkness = clampf(since / FADE_SECONDS, 0.0, 1.0)
				_name(PlaceText.here(simulation, back_to))
	var between: bool = e.state in [Expedition.State.CLIMBING, Expedition.State.JOURNEYING]
	_held = _darkness if between else 0.0
	if _opened_tick >= 0 and _darkness <= 0.0:
		var since: float = float(now - _opened_tick) / Simulation.TICKS_PER_SECOND
		_darkness = clampf(1.0 - since / OPEN_SECONDS, 0.0, 1.0)
		if _darkness <= 0.0:
			_opened_tick = -1


## The stage the world shows for [param simulation]: the party's, or, past the middle of a change
## of stage, the one it is going to. On a journey it keeps [param shown], the stage it showed (a
## journey can start half way through a change of stage), until the party arrives.
static func stage_shown(simulation: Simulation, shown: int = 0) -> int:
	var e: Expedition = simulation.expedition
	if e.state == Expedition.State.JOURNEYING and shown > 0:
		return shown
	if e.state == Expedition.State.CLIMBING and ClimbProgress.share(e) >= SWITCH_SHARE:
		return ClimbProgress.stage_to(e)
	return e.depth


## How much of each hero shows on a change of stage: gone into the doorway on the way out, as
## [param gap] (pixels from the doorway's middle) closes, then out of sight until the screen
## opens on them stepping out. 1 otherwise.
static func hero_shown(simulation: Simulation, gap: float) -> float:
	var e: Expedition = simulation.expedition
	if e.state != Expedition.State.CLIMBING:
		return 1.0
	var share: float = ClimbProgress.share(e)
	if share >= OUT_SHARE:
		return 1.0
	if share >= SWITCH_SHARE:
		return 0.0
	return clampf((absf(gap) - GONE_WITHIN) / (LabyrinthView.TILE - GONE_WITHIN), 0.0, 1.0)


func _name(text: String) -> void:
	if _darkness >= TITLE_FROM:
		_title = text
