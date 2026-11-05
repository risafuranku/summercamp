extends RefCounted

## The caravan's plan, one source for both sides of it: the van in the camp
## (building_models.caravan) and the room you go into (caravan_interior.gd), which stands
## inside it in the camp's one world (W26: the room's walls stood out of the van's sides,
## its wallpaper seen from the camp, the user 5. 11.). Model space: metres, the van's middle
## on the ground, the door side +Z; room space the same, its floor at VAN_FLOOR.

## The room inside: length along x, width along z, height; its walls' thickness.
const L := 4.96
const W := 2.0
const H := 1.95
const WALL_T := 0.1
## The van's floor over the ground.
const VAN_FLOOR := 0.42
## The van's tin round the room's walls: its body SKIN thick outside them all round.
const SKIN := 0.03
const BODY := Vector3(L + 2.0 * (WALL_T + SKIN), H + 2.0 * (WALL_T + SKIN), W + 2.0 * (WALL_T + SKIN))
const BODY_BOTTOM := VAN_FLOOR - WALL_T - SKIN
## The door: its middle along x, its leaf's size.
const DOOR_X := -1.24
const DOOR_W := 0.62
const DOOR_H := 1.55
## The windows, the van's panes and the room's frames: [glass size, centre (room space),
## yaw]. The big one over the dinette at the towing end, the little one at the back end,
## three on the door side, three on the kitchen side, all at the window height.
const WINDOWS := [
	[Vector2(0.9, 0.5), Vector3(L * 0.5 - 0.004, 1.25, 0.0), -90.0],
	[Vector2(0.62, 0.44), Vector3(-L * 0.5 + 0.004, 1.25, 0.0), 90.0],
	[Vector2(0.78, 0.56), Vector3(0.69, 1.25, W * 0.5 - 0.004), 180.0],
	[Vector2(0.78, 0.56), Vector3(1.84, 1.25, W * 0.5 - 0.004), 180.0],
	[Vector2(0.62, 0.5), Vector3(-1.98, 1.25, W * 0.5 - 0.004), 180.0],
	[Vector2(0.7, 0.5), Vector3(-1.49, 1.25, -W * 0.5 + 0.004), 0.0],
	[Vector2(0.7, 0.5), Vector3(0.25, 1.25, -W * 0.5 + 0.004), 0.0],
	[Vector2(0.7, 0.5), Vector3(1.64, 1.25, -W * 0.5 + 0.004), 0.0],
]
## The doorway through the van's side (model space: x along, y up): the room's opening
## (caravan_interior._cut_walls) under the leaf.
const DOORWAY := Rect2(DOOR_X - DOOR_W * 0.5, VAN_FLOOR + 0.075, DOOR_W, 1.59 - 0.075)
