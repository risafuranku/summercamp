extends RefCounted

## One plan for the small service buildings: the toilet block, the shower house, the generator
## shed and the warehouse (W26, one world). The building outside (building_models: _toilets,
## _showers, _substation) is a skin round its room; the room inside (service_interior.gd,
## shed/generator_shed.gd) stands in it in the camp's own world, its doorways the building's
## own, the leaves the building's own leaves.
##
## Room space: the floor's middle at the origin, the front +Z, the floor at y 0. The room's
## walls (interior_kit.room) stand WALL thick outside its inside size, the building's skin
## SKIN outside them; the room's floor is FLOOR over the building's ground (2 cm over the
## plinth's band, building_models.PLINTH_TOP).

const WALL := 0.1
const SKIN := 0.04
const FLOOR := 0.15

## The toilet block: two stalls side by side, a door each (the left one the men's).
const TOILET_W := 2.9
const TOILET_H := 2.25
const TOILET_D := 2.1
const TOILET := Vector3(TOILET_W, TOILET_H, TOILET_D)
const TOILET_STALL_X := 0.72
const TOILET_DOOR := Vector2(0.78, 1.82)

## The shower house: one room, its door in the middle of the front.
const SHOWER := Vector3(3.6, 2.5, 3.2)
const SHOWER_DOOR := Vector2(0.9, 2.0)

## The generator shed's set room behind the steel pair. The switch room through its back door
## is a room behind (service_interior.BACK_ROOM_UP: over the building, in the dark).
const SHED := Vector3(3.6, 2.8, 3.4)
const SHED_DOOR := Vector2(1.22, 1.9)

## The warehouse's store room (scripts/business/store_room.gd): racks along the back and the
## left wall, its plank door in the middle of the front (playtest 14. 11.: an indoor building).
const STORE := Vector3(5.2, 2.7, 4.0)
const STORE_DOOR := Vector2(1.0, 1.95)


## The room's inside size for a service profile ("toilet", "wash", "generator", "store").
static func inside(kind: String) -> Vector3:
	match kind:
		"toilet":
			return TOILET
		"wash":
			return SHOWER
		"generator":
			return SHED
		"store":
			return STORE
	return Vector3.ZERO


## The doorways in the front: [[x (from the middle), size], ...].
static func doors(kind: String) -> Array:
	match kind:
		"toilet":
			return [[-TOILET_STALL_X, TOILET_DOOR], [TOILET_STALL_X, TOILET_DOOR]]
		"wash":
			return [[0.0, SHOWER_DOOR]]
		"generator":
			return [[0.0, SHED_DOOR]]
		"store":
			return [[0.0, STORE_DOOR]]
	return []


## The building round a room `inside`: its outer faces (x, z) and the top of its lid (y), from
## the building's ground.
static func outer(room: Vector3) -> Vector3:
	var t := WALL + SKIN
	return Vector3(room.x + t * 2.0, FLOOR + room.y + t, room.z + t * 2.0)


## Where a leaf of the building hangs, in the room's space: the plane of the leaf out in front
## of the skin (z), how far in from it the room's inside face is.
static func leaf_z(room: Vector3) -> float:
	return room.z * 0.5 + WALL + SKIN + 0.03


static func leaf_inner() -> float:
	return WALL + SKIN + 0.03
