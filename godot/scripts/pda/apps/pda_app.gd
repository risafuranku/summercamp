extends RefCounted

## An app of the PDA's "Okna CE" (scripts/pda/pda_os.gd): it draws itself in the work area
## with the system's helpers (`os.text`, `os.button`, `os.hit`...) and answers the stylus.

## The system (pda_os.gd).
var os


## Coming up on the screen, and going.
func opened() -> void:
	pass


func closed() -> void:
	pass


## Whether it runs a clock of its own while open (the snake): `tick` every frame then.
func wants_tick() -> bool:
	return false


func tick(_delta: float) -> void:
	pass


func draw(_r: Rect2) -> void:
	pass


## A button or a hit of its own let go of (`os.hit` ids).
func press(_id: String) -> void:
	pass


## The stylus down where there is no button (`p` in the screen's pixels).
func tap(_p: Vector2) -> void:
	pass
