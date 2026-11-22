class_name WindingPreview
extends Main
## A development scene: the game on winding stages (three floors, ladders, a route that doubles
## back), a new game every time, never loaded and never saved. No menu leads here:
## [code]godot --path . res://game/dev/winding.tscn[/code] plays it, and
## [code]python tools/dev.py shot --scene=res://game/dev/winding.tscn[/code] shows it.


func _ready() -> void:
	super()
	# A played Main makes itself a store on the player's file: this game is never written there.
	save_store = null


## A new winding game, whatever a save holds.
func _load_or_new() -> Simulation:
	return Simulation.new(SIMULATION_SEED, Labyrinth.Shape.WINDING)
