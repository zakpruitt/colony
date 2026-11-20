class_name FramePiece
extends Panel
## A panel of the frame of the screen, on the sharp layer. The [Hud] holds its pieces in one list
## ([member Hud.pieces]) and drives each the same way: [method advance] every frame,
## [method catch_up] after a stall, [method add_tips] once as it joins. What a piece shows is
## handed to it in its own setup; the [Hud] places it.


## Moves the piece on by delta seconds. Called every frame; does work only when what it shows
## changed.
func advance(_delta: float) -> void:
	pass


## Shows the present at once, after a stall or a fast-forward.
func catch_up() -> void:
	pass


## Gives the piece the frame's tooltip for its controls.
func add_tips(_tips: UiTip) -> void:
	pass
