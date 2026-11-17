extends GutTest
## Unit tests for the defeat note's wording (spec 041): the monsters that beat the party, grouped
## by name.


func test_one_kind_is_counted_in_the_plural() -> void:
	assert_eq(DefeatNote.crowd(["Ogre", "Ogre", "Ogre"] as Array[String]), "3 ogres")


func test_one_monster_takes_an_article() -> void:
	assert_eq(DefeatNote.crowd(["Ogre"] as Array[String]), "an ogre")
	assert_eq(DefeatNote.crowd(["Cave bat"] as Array[String]), "a cave bat")


func test_kinds_are_listed_in_the_order_met() -> void:
	var names: Array[String] = ["Slime", "Cave bat", "Slime"]
	assert_eq(DefeatNote.crowd(names), "2 slimes and a cave bat")
	names = ["Goblin", "Ogre", "Goblin", "Spider", "Spider"]
	assert_eq(DefeatNote.crowd(names), "2 goblins, an ogre and 2 spiders")


func test_nobody_is_empty() -> void:
	assert_eq(DefeatNote.crowd([] as Array[String]), "")
