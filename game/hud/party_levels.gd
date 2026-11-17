class_name PartyLevels
extends RefCounted
## Spec 047 R6: the one rule for the party's lowest hero level, read by the depth ladder's risk,
## the goals tracker's guardian goal and the defeat note's reason, so the three never disagree.


## The lowest level of any hero in [param party], living or dead (a fallen hero comes back at its
## level); 1 for a party with no heroes, the level every hero starts at.
static func lowest(party: Party) -> int:
	var found: int = 0
	for hero: Hero in party.heroes:
		if found == 0 or hero.level < found:
			found = hero.level
	return maxi(found, 1)
