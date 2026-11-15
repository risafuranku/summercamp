extends Node

## Main's own input, heard inside its instance's screen where the rest of the warden's input
## is (scripts/instance/instance.gd): the screen's first child, so it comes where main's own
## did before the screen, after the other nodes' _input and _unhandled_input (a room takes
## its Esc and its E before main's pause and interaction see them).

var main: Node


func _input(event: InputEvent) -> void:
	main.screen_input(event)


func _unhandled_input(event: InputEvent) -> void:
	main.screen_unhandled_input(event)
