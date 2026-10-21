class_name CabinLayout
extends RefCounted

## The cabin's plan, one source for both sides of it (the user 21. 10.: "rebuild the
## cabin's inside so it really is the outside model, and remake that too; every tier a
## visible upgrade inside and out"): the model in the camp (building_models.cabin) and
## the room you go into (cabin_interior.gd) are built from these numbers, so a window you
## look out of is the window you see from outside, and its view is the camp beyond it.
##
## Model space: metres, the footprint's middle on the ground, the front (+Z) with the door.
## Room space is the same, only lower: the room's floor top is at y ROOM_FLOOR where the
## model's is at MODEL_FLOOR (room -> model: + ROOM_TO_MODEL).
##
##                 back (-Z): the window over the table
##        +---------------------------------+-----------+
##        | bed                    table    | bathroom  |  Lv2+: the annex, its door in
##        |                                 |   (Lv2+)  |  the right wall; Lv1: a window
##        | wardrobe (2+)           fridge  +-----------+  there instead
##        +----[win]------[door]------[win]-+
##                 front (+Z): the porch from Lv2

const WALL_T := 0.12
const MODEL_FLOOR := 0.15
const ROOM_FLOOR := 0.05
const ROOM_TO_MODEL := Vector3(0.0, MODEL_FLOOR - ROOM_FLOOR, 0.0)

## Outer walls (x, z), wall height, roof rise; per level.
const SIZE := {1: Vector2(4.2, 3.6), 2: Vector2(4.4, 3.8), 3: Vector2(4.6, 4.0)}
const WALL_H := {1: 2.45, 2: 2.5, 3: 2.55}
const ROOF_RISE := {1: 1.05, 2: 1.1, 3: 1.15}

## The openings. A window: [centre in model space, size (w, h), which wall: "front",
## "back", "right"]. Their middles 1.5 m over the floor, as a person looks out.
const SILL_MID := 1.52
const DOOR_W := 0.86
const DOOR_H := 1.96
const FRONT_WIN_X := 1.3
const FRONT_WIN := Vector2(0.7, 0.6)
const BACK_WIN := Vector2(0.92, 0.66)
const SIDE_WIN := Vector2(0.72, 0.6)
## The bathroom built on at the right (Lv2+): how far out, how long, its middle along z,
## its door in the cabin's right wall (z of its middle).
const ANNEX := {2: Vector3(1.7, 2.0, -0.62), 3: Vector3(1.7, 2.0, -0.62)}
const BATH_DOOR_W := 0.8
const BATH_DOOR_H := 1.92
const BATH_WIN := Vector2(0.4, 0.34)

## The bed (all levels at the same place, so the sleepers and lodge_bed.gd agree): its
## frame's middle on the room's floor, along the left wall, the head at the back.
const BED := Vector3(-1.46, ROOM_FLOOR, -0.66)
const BED_TOP := 0.59
## The best cabin's stove (its chimney outside over it): how far in from the front.
const STOVE_FROM_FRONT := 0.5


static func size(level: int) -> Vector2:
	return SIZE[clampi(level, 1, 3)]


static func wall_h(level: int) -> float:
	return WALL_H[clampi(level, 1, 3)]


static func roof_rise(level: int) -> float:
	return ROOF_RISE[clampi(level, 1, 3)]


## The room inside the walls (x, z), room space, centred.
static func inner(level: int) -> Vector2:
	return size(level) - Vector2(WALL_T, WALL_T) * 2.0


## The windows you can look out of: [{id, wall, centre (model space), size, out (the way
## it faces, model space)}]. The bathroom's frosted one is not among them.
static func windows(level: int) -> Array:
	var s := size(level)
	var y := MODEL_FLOOR + SILL_MID
	var out: Array = [
		{"id": "front_l", "wall": "front", "centre": Vector3(-FRONT_WIN_X, y, s.y * 0.5), "size": FRONT_WIN, "out": Vector3(0, 0, 1)},
		{"id": "front_r", "wall": "front", "centre": Vector3(FRONT_WIN_X, y, s.y * 0.5), "size": FRONT_WIN, "out": Vector3(0, 0, 1)},
		{"id": "back", "wall": "back", "centre": Vector3(0.15, y + 0.04, -s.y * 0.5), "size": BACK_WIN, "out": Vector3(0, 0, -1)},
	]
	if level <= 1:
		out.append({"id": "side", "wall": "right", "centre": Vector3(s.x * 0.5, y, 0.2), "size": SIDE_WIN, "out": Vector3(1, 0, 0)})
	return out


static func has_bath(level: int) -> bool:
	return level >= 2


## The annex's outer box (model space): centre on the ground, size.
static func annex_box(level: int) -> AABB:
	var a: Vector3 = ANNEX.get(clampi(level, 2, 3), ANNEX[2])
	var s := size(level)
	return AABB(Vector3(s.x * 0.5, 0.0, a.z - a.y * 0.5), Vector3(a.x, wall_h(level) * 0.82, a.y))


## The bathroom door's middle along z in the right wall.
static func bath_door_z(level: int) -> float:
	return (ANNEX.get(clampi(level, 2, 3), ANNEX[2]) as Vector3).z + 0.1


## Model space -> room space and back.
static func to_room(p: Vector3) -> Vector3:
	return p - ROOM_TO_MODEL


static func to_model(p: Vector3) -> Vector3:
	return p + ROOM_TO_MODEL
