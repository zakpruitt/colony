class_name QuestWork
extends RefCounted
## The expedition's quests: meeting one, and the work on it while the party
## stands WORKING. Kept apart from [Expedition] so its file stays under gdlint's 1000 lines.

## Each worker past the first shortens a quest's work by this share of one worker's pace.
const HELPER_SHARE: float = 0.35


## The ticks a quest takes with [param worker_count] workers (at least 1 each way).
static func work_ticks(def: QuestDef, worker_count: int) -> int:
	var base_ticks: int = Combatant.seconds_to_ticks(def.work_seconds)
	var pace: float = 1.0 + HELPER_SHARE * (maxi(worker_count, 1) - 1)
	return maxi(roundi(base_ticks / pace), 1)


## Everyone working now, lead first; empty when the party is not WORKING.
static func workers(run: Expedition) -> Array[int]:
	if run.state != Expedition.State.WORKING:
		return []
	return run._workers.duplicate()


## The party reaches [param quest] in [param room]: every living hero with its microskill starts on
## it, the lowest id leading; with nobody able, the party walks past, and a hazard springs on it.
static func meet(run: Expedition, room: LabyrinthChamber, quest: StringName) -> void:
	var def: QuestDef = Content.quest(quest)
	var quest_index: int = Content.quest_ids().find(quest)
	var fill: ChamberState = run._record(run.depth, room.index)
	var able: Array[Hero] = run._party.heroes_with_microskill(def.microskill)
	if not able.is_empty():
		run.state = Expedition.State.WORKING
		run._work_key = Vector2i(run.depth, room.index)
		run._work_quest = quest
		run._worker = able[0].id
		run._workers = []
		for hero: Hero in able:
			run._workers.append(hero.id)
		run._work_start = run._tick
		run._work_ticks = work_ticks(def, able.size())
		run._emit(SimEvent.Kind.QUEST_STARTED, run._worker, quest_index, run._work_ticks)
		return
	var skill_index: int = Content.microskill_ids().find(def.microskill)
	if def.miss_damage > 0.0:
		run._emit(SimEvent.Kind.QUEST_MISSED, -1, quest_index, skill_index, true)
		for hero: Hero in run._party.heroes:
			# Never below 1, and nothing to the dead: a hazard hurts, but cannot wipe the party.
			var lost: int = mini(roundi(def.miss_damage * hero.max_health()), hero.health - 1)
			if lost <= 0:
				continue
			hero.health -= lost
			run._emit(SimEvent.Kind.HIT, -1, hero.id, lost)
		fill.cleared_tick = run._tick
		return
	if not fill.missed:
		fill.missed = true
		run._emit(SimEvent.Kind.QUEST_MISSED, -1, quest_index, skill_index, false)


## Waits out the work, then gives the reward, clears the chamber and travels on. On a side path
## the work is its gate's ([method SidePathWalk.work]).
static func work(run: Expedition) -> void:
	if run._tick - run._work_start < run._work_ticks:
		return
	if run.side_path >= 0:
		run._side.work(run)
		return
	var def: QuestDef = Content.quest(run._work_quest)
	var quest_index: int = Content.quest_ids().find(run._work_quest)
	var amount: int = def.reward_at(run.level_at(run._work_key.x))
	run._emit(SimEvent.Kind.QUEST_DONE, run._worker, quest_index, amount)
	if def.reward == QuestDef.Reward.XP:
		for hero: Hero in run._party.heroes:
			if hero.is_alive():
				run._give_xp(hero, amount)
	else:
		run._party.gold += amount
		run._emit(SimEvent.Kind.GOLD_GAINED, run._worker, -1, amount)
	ResourceDrops.on_quest(run, run._worker, run._work_key.x)
	var fill: ChamberState = run._chambers[run._work_key]
	fill.cleared_tick = run._tick
	fill.missed = false
	run._work_key = Vector2i(0, -1)
	run._work_quest = &""
	run._worker = -1
	run._workers = []
	run.state = Expedition.State.TRAVELLING
