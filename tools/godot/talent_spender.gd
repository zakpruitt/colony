class_name TalentSpender
extends RefCounted
## The headless run's way of spending talent and paragon points (spec 051 R11), for
## `python tools/dev.py sim --spend-talents` and the tests that compare it: each hero takes its
## trunk in order, then one path of its tree (the first unless told), and puts every paragon
## point into Power.


## Asks [param sim] to spend every point each hero has: one talent command per unspent talent
## point (the nodes in order, at the fork path [param path], 0 or 1) and one Power command per
## paragon point. Call it before a step; the commands apply on that step.
static func spend(sim: Simulation, path: int = 0) -> void:
	for hero: Hero in sim.party.heroes:
		var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
		if tree != null:
			var plan: Array[StringName] = hero.talents()
			for point: int in hero.talent_points():
				var next: Array[StringName] = tree.next_nodes(plan)
				if next.is_empty():
					break
				# At the fork next_nodes lists path a, then path b.
				var node: StringName = next[mini(path, next.size() - 1)]
				plan.append(node)
				sim.take_talent(hero.id, node)
		for point: int in hero.paragon_points():
			sim.spend_paragon(hero.id, TrainingDef.Stat.POWER)
