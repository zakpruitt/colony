class_name QuestWork
extends RefCounted
## The expedition's quests: meeting one, and the work on it while the party
## stands WORKING. Kept apart from [Expedition] so its file stays under gdlint's 1000 lines.


## The party reaches [param quest] in [param room]: a living hero with its microskill starts on it;
## with nobody able, the party walks past, and a hazard springs on it.
static func meet(run: Expedition, room: LabyrinthChamber, quest: StringName) -> void:
	var def: QuestDef = Content.quest(quest)
	var quest_index: int = Content.quest_ids().find(quest)
	var fill: ChamberState = run._record(run.depth, room.index)
	var worker: Hero = run._party.hero_with_microskill(def.microskill)
	if worker != null:
		run.state = Expedition.State.WORKING
		run._work_key = Vector2i(run.depth, room.index)
		run._work_quest = quest
		run._worker = worker.id
		run._work_start = run._tick
		run._work_ticks = maxi(Combatant.seconds_to_ticks(def.work_seconds), 1)
		run._emit(SimEvent.Kind.QUEST_STARTED, worker.id, quest_index, run._work_ticks)
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
	run.state = Expedition.State.TRAVELLING
