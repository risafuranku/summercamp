extends RefCounted

## A business's room built again in its building in the camp, behind its real glass (the
## user 26. 10.: the pub's, the bistro's and the Jednota's windows seen into from the camp
## as the cabins' are). One plan: the layout's own code builds the room in both places
## (pub_layout.bar_outside); this stands in for the service interior it would be given
## (its signs, its lamps) and keeps the lamps, for business/room_lights.gd to light by
## the place's hours.

const K := preload("res://scripts/interior_kit.gd")

var lamps: Array = []


func _sign(parent: Node3D, text: String, pos: Vector3, font_size: int, style: String = "enamel") -> Node3D:
	return K.wall_sign(parent, text, pos, font_size, style)


func _pub_lamp(parent: Node3D, at: Vector3) -> void:
	lamps.append(K.pub_lamp(parent, at))
