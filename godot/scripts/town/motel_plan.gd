extends RefCounted

## The Liblice motel's one plan (the user, 3. 11. 2026: "the whole gallery of rooms"):
## the building in the village (motel_block.gd) and the rooms you go into (motel_rooms.gd,
## opened by town_room.gd) are both built from it, so the window you look out of is the
## window seen from the car park, and the lamp you switch on lights it.
##
## Motel space: the block's middle on the ground at the origin, x east along its front,
## y up, z south; the front (FRONT_Z) faces north to the street. Seven bays of BAY metres:
## the reception in the two west ones downstairs, rooms 1-5 in the other five, rooms 6-12
## over all seven along the gallery, reached by the stairs up the east end.
##
## A room's own space: the middle of its floor at the origin, the same axes (its street
## wall at -ROOM_D / 2).

const SIZE := Vector3(22.0, 6.4, 9.0)
const FRONT_Z := -4.5
const WALL := 0.2
const BAYS := 7
const BAY := 22.0 / 7.0
## The upper floor (the gallery's top), the rooms' height inside, their depth.
const UPPER_Y := 3.2
const ROOM_H := 2.7
const ROOM_D := 4.3
## In a bay, from its west edge: the door's sides, the window's sides; the window's sill
## and head over the room's floor.
const DOOR := Vector2(0.4, 1.3)
const DOOR_H := 2.05
const WIN := Vector2(1.65, 2.85)
const WIN_Y := Vector2(0.9, 2.15)
## The gallery stands out this far from the front, its slab this thick; the rail.
const GALLERY_D := 1.6
const GALLERY_T := 0.2
const RAIL_H := 1.0
## The stairs: along the east end wall, from the ground at STAIR_FOOT_Z up to the landing
## at the gallery's east end.
const STAIR_W := 1.2
const STAIR_FOOT_Z := 1.7
const STEPS := 16
## The reception: bays 0 and 1 downstairs; its door in bay 1, a window in each.
const LOBBY_BAYS := [0, 1]
const LOBBY_DOOR_BAY := 1
## Šimek's rooms: every bay's room by its number.
const ROOMS := {
	1: {"bay": 2, "up": false}, 2: {"bay": 3, "up": false}, 3: {"bay": 4, "up": false},
	4: {"bay": 5, "up": false}, 5: {"bay": 6, "up": false},
	6: {"bay": 0, "up": true}, 7: {"bay": 1, "up": true}, 8: {"bay": 2, "up": true},
	9: {"bay": 3, "up": true}, 10: {"bay": 4, "up": true}, 11: {"bay": 5, "up": true},
	12: {"bay": 6, "up": true},
}
## The room he lets (the best mattress), the one he does not.
const YOURS := 4
const NEVER := 6

# ── the room inside (its own space) ──────────────────────────────────────────

## Inner width (between the partitions).
const ROOM_W := BAY - 0.15
## Two single beds pushed together under the headboard on the back wall: their middles.
const BED_X := [-0.42, 0.42]
const BED_SIZE := Vector3(0.82, 0.5, 1.95)
const BED_Z := ROOM_D * 0.5 - BED_SIZE.z * 0.5
## The headboard wall's picture: as wide as the wall, its own 16:9 tall, from this high.
const HEADWALL_Y := 0.25
## Where you stand when you come in (eye height), and lie in the first bed; the
## wardrobe's middle along the west wall.
const STAND := Vector3(-0.15, 1.6, -1.25)
const WARDROBE_Z := -0.5
const LIE := Vector3(-0.42, 0.78, 1.55)


static func bay_x0(bay: int) -> float:
	return -SIZE.x * 0.5 + float(bay) * BAY


static func floor_y(n: int) -> float:
	return UPPER_Y if bool(ROOMS[n]["up"]) else 0.0


## A room's middle on its floor (motel space).
static func room_origin(n: int) -> Vector3:
	var b := int(ROOMS[n]["bay"])
	return Vector3(bay_x0(b) + BAY * 0.5, floor_y(n), FRONT_Z + WALL + ROOM_D * 0.5)


## The reception's middle on its floor (motel space), its inner size.
static func lobby_origin() -> Vector3:
	var x0 := -SIZE.x * 0.5 + WALL
	var x1 := bay_x0(2) - 0.075
	return Vector3((x0 + x1) * 0.5, 0.0, FRONT_Z + WALL + ROOM_D * 0.5)


static func lobby_size() -> Vector3:
	var x0 := -SIZE.x * 0.5 + WALL
	var x1 := bay_x0(2) - 0.075
	return Vector3(x1 - x0, ROOM_H, ROOM_D)


## The door of a bay (motel space): its middle on the floor.
static func door_at(bay: int, up: bool) -> Vector3:
	return Vector3(bay_x0(bay) + (DOOR.x + DOOR.y) * 0.5, UPPER_Y if up else 0.0, FRONT_Z)


## The window of a bay (motel space): the glass's middle.
static func window_at(bay: int, up: bool) -> Vector3:
	return Vector3(bay_x0(bay) + (WIN.x + WIN.y) * 0.5, (UPPER_Y if up else 0.0) + (WIN_Y.x + WIN_Y.y) * 0.5, FRONT_Z)


static func window_size() -> Vector2:
	return Vector2(WIN.y - WIN.x, WIN_Y.y - WIN_Y.x)


## Motel space -> a room's (or the reception's: n = 0) own.
static func to_room(n: int, p: Vector3) -> Vector3:
	return p - (lobby_origin() if n == 0 else room_origin(n))


## The window and the door of a room in its own space (n = 0: the reception's two windows).
static func room_windows(n: int) -> Array:
	if n == 0:
		return [to_room(0, window_at(0, false)), to_room(0, window_at(1, false))]
	var b := int(ROOMS[n]["bay"])
	return [to_room(n, window_at(b, bool(ROOMS[n]["up"])))]


static func room_door(n: int) -> Vector3:
	if n == 0:
		return to_room(0, door_at(LOBBY_DOOR_BAY, false))
	var b := int(ROOMS[n]["bay"])
	return to_room(n, door_at(b, bool(ROOMS[n]["up"])))


# ── who is in which room tonight ─────────────────────────────────────────────

## The rooms taken tonight besides yours (the same on every machine: the day's seed): a
## travelling salesman, a lorry driver, a couple off the 12; never six.
static func taken(day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("motel_taken_%d" % day)
	var out: Array = []
	var want := 2 + rng.randi_range(0, 2)
	var guard := 0
	while out.size() < want and guard < 40:
		guard += 1
		var n := rng.randi_range(1, 12)
		if n == YOURS or n == NEVER or out.has(n):
			continue
		out.append(n)
	return out


## When the lamp goes off in a taken room (hours after midnight added to 24).
static func lights_out(day: int, n: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("motel_out_%d_%d" % [day, n])
	return 22.0 + rng.randf() * 3.5


## Number six some nights (the user, 3. 11.: "the light in six"): lit behind its drawn
## curtain from a while before midnight to a while before dawn. Never explained.
static func six_lit(day: int, hour: float) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("motel_six_%d" % day)
	if rng.randf() > 0.25:
		return false
	var on := 23.0 + rng.randf() * 1.5
	var off := 2.5 + rng.randf() * 1.5
	return hour >= on or hour < off


## The chapel's bell at three in the morning, some nights (the card on its door says so).
static func bell_at_three(day: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("liblice_bell3_%d" % day)
	return rng.randf() < 0.28


## The guest who left the camp, standing in the car park looking up the road to it, some
## nights: from when, till when (hours, past midnight + 24), or [] for none.
static func carpark_watch(day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("motel_watch_%d" % day)
	if rng.randf() > 0.25:
		return []
	var on := 21.5 + rng.randf() * 2.0
	return [on, 24.0 + 3.0 + rng.randf() * 1.5]
