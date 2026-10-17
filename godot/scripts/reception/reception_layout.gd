class_name ReceptionLayout
extends RefCounted

## The reception's plan, one source for every side of it: the office's 3D
## (scripts/building_interior.gd), the back room (back_room.gd), the building in the camp
## (building_models.gd reception()) and the two window views into the camp
## (building_interior.gd: the portal cameras).
##
## Room space is the office's own: metres, the floor at y 0, the front wall's inner face at
## z -2.55 with the door in it at x 1.72, the back room through the left wall (x < -2.6).
## The building in the camp is the two rooms side by side under one roof, centred on the
## reception's footprint, its front (+Z) the office's front wall. So what you see through
## a window from inside is what stands outside that window, and the windows you see from
## outside are the ones you look out of (playtest 2026-10-17: "the windows must match the
## interior").
##
##          local -X (west)                                   local +X (east, the gate lane)
##   +--------------------------------------+---------------------------+
##   |  office 5 x 5            |  back room 3 x 2.8 (bed under the     |
##   |  keys  counter   PC      |  east window)                         |
##   |                          +----------- store (no way in) ---------+
##   +--[door]-------[window]---+-------------------------------------- +   front +Z

## The rooms, outer faces of their walls (x, z in room space).
const OFFICE_X := Vector2(-2.6, 2.6)
const OFFICE_Z := Vector2(-2.6, 2.6)
const BACK_X := Vector2(-5.65, -2.6)
const BACK_Z := Vector2(-0.25, 2.65)
const WALL_H := 3.0
const ROOF_RISE := 1.35

## Openings in room space.
const DOOR_X := Vector2(1.22, 2.23)
const DOOR_H := 2.1
const OFFICE_WINDOW_CENTER := Vector3(-0.4, 1.68, -2.51)
const OFFICE_WINDOW_SIZE := Vector2(1.86, 1.38)
## The back room's window: in its far wall (room x -5.6), over the bed, looking out over
## the gate lane toward the barrier.
const BACK_WINDOW_CENTER := Vector3(-5.6, 1.42, 0.86)
const BACK_WINDOW_SIZE := Vector2(0.96, 0.86)   # along z, height

## Room x where the building's middle is (the rooms' combined extent, centred).
const ROOM_CENTER_X := -1.525


## Room space -> the building's local space (origin on the ground at the footprint's
## middle, front +Z). Room +X runs to local -X; room -Z (out of the front wall) to +Z.
static func room_to_local() -> Transform3D:
	return Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), Vector3(ROOM_CENTER_X, 0.0, 0.0))


static func local(room: Vector3) -> Vector3:
	return room_to_local() * room


## The whole building's extent in local space (x from, x to, z from, z to).
static func local_bounds() -> Rect2:
	var a := local(Vector3(maxf(OFFICE_X.y, BACK_X.y), 0, minf(OFFICE_Z.x, BACK_Z.x)))
	var b := local(Vector3(minf(OFFICE_X.x, BACK_X.x), 0, maxf(OFFICE_Z.y, BACK_Z.y)))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(a.x - b.x), absf(a.z - b.z)))
