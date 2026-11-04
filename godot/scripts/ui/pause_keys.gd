extends Node

## P and F10: the pause menu from anywhere (main.pause_key), where Esc leaves a room or a job
## instead (the user, 4. 11.). Under the root, last, so it hears a key before the rooms and
## the jobs: they take every key they get.

var main: Node


func _init() -> void:
	name = "PauseKeys"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or main == null or not is_instance_valid(main):
		return
	if k.physical_keycode != KEY_P and k.physical_keycode != KEY_F10:
		return
	if bool(main.call("pause_key", k.physical_keycode)):
		get_viewport().set_input_as_handled()
