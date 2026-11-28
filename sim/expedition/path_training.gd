class_name PathTraining
extends RefCounted
## The path XP a won fight gives, kept out of [Expedition]. Every hero of the party, standing or
## fallen, gains in each of its class's paths the nodes it holds there plus the uses of that path's
## abilities in the fight ([member Combatant.uses]), each ability counted at most
## [member TalentTreeDef.uses_counted] times. A rank passed is reported with
## [constant SimEvent.Kind.PATH_RANKED], once for each rank in order.


## [param run]'s heroes won [param fought]: each gains its path XP.
static func after_win(run: Expedition, fought: Battle) -> void:
	for hero: Hero in run._party.heroes:
		var taken: Array[StringName] = hero.talents()
		var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
		if taken.is_empty() or tree == null:
			continue
		var fighter: Combatant = fought.combatant(hero.id)
		for path: int in tree.paths.size():
			var gained: int = 0
			for node: StringName in tree.paths[path].nodes:
				if taken.has(node):
					gained += 1
				var uses: int = fighter.uses.get(node, 0) if fighter != null else 0
				gained += mini(uses, maxi(tree.uses_counted, 0))
			if gained <= 0:
				continue
			var before: int = hero.ranks.add(path, gained, tree)
			for rank: int in range(before + 1, hero.ranks.rank(path, tree) + 1):
				run._emit(SimEvent.Kind.PATH_RANKED, hero.id, path, rank)
