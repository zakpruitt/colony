class_name TalentSpender
extends RefCounted
## The headless run's way of spending talent and paragon points, for
## `python tools/dev.py sim --spend-talents` and the tests that compare it: each hero takes the
## first node it can of one path (the first unless told), then of the others in path order, passing
## over nodes its path's rank still holds shut, and puts every paragon point into Power.


## Asks [param sim] to spend every point each hero has: one talent command per unspent talent
## point (the first open node of path [param path], tier by tier and left before right, else of
## the other paths in order; a node its path's rank holds shut is passed over) and one Power
## command per paragon point. Call it before a step; the commands apply on that step.
static func spend(sim: Simulation, path: int = 0) -> void:
	for hero: Hero in sim.party.heroes:
		var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
		if tree != null:
			var plan: Array[StringName] = hero.talents()
			for point: int in hero.talent_points():
				var node: StringName = _next(hero, tree, plan, path)
				if node.is_empty():
					break
				plan.append(node)
				sim.take_talent(hero.id, node)
		for point: int in hero.paragon_points():
			sim.spend_paragon(hero.id, TrainingDef.Stat.POWER)


static func _next(
	hero: Hero, tree: TalentTreeDef, plan: Array[StringName], path: int
) -> StringName:
	var open: Array[StringName] = []
	for node: StringName in tree.open_nodes(plan):
		if hero.ranks.rank(tree.path_of(node), tree) >= tree.rank_needed(node):
			open.append(node)
	for node: StringName in open:
		if tree.path_of(node) == path:
			return node
	return open[0] if not open.is_empty() else &""
