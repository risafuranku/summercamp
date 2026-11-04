extends RefCounted

## The Liblice motel's one plan (the user, 3. 11. 2026: "the whole gallery of rooms"; 4. 11.:
## "it should work like in some RPG": a corridor inside, keys off the board): the building
## in the village (motel_block.gd), the rooms you go into (motel_rooms.gd) and the corridor
## (motel_hall.gd), all opened by town_room.gd, are built from it, so the window you look
## out of is the window seen from the car park, and the lamp you switch on lights it.
##
## Motel space: the block's middle on the ground at the origin, x east along its front,
## y up, z south; the front (FRONT_Z) faces north to the street. Seven bays of BAY metres:
## the reception in the two west ones downstairs, rooms 1-5 in the other five, rooms 6-12
## over all seven. The rooms lie along the front, their windows on the street; behind them
## the corridor (CORRIDOR_Z) runs the block's length on both floors, reached from the
## reception by a short passage, the stairs at its east end. A room: from its door on the
## corridor a little hall, the bathroom off it, the bedroom beyond.
##
## A room's own space: the middle of its bedroom's floor at the origin, the same axes (its
## street wall at -ROOM_D / 2, the hall and the bathroom behind its back wall).

const SIZE := Vector3(22.0, 6.4, 9.0)
const FRONT_Z := -4.5
const WALL := 0.2
const BAYS := 7
const BAY := 22.0 / 7.0
## The upper floor (the gallery's top), the rooms' height inside, their depth.
const UPPER_Y := 3.2
const ROOM_H := 2.7
const ROOM_D := 4.3
## In a bay, from its west edge: the window's sides; the window's sill and head over the
## room's floor; a door's height.
const WIN := Vector2(1.65, 2.85)
const WIN_Y := Vector2(0.9, 2.15)
const DOOR_H := 2.05
## The reception's street door in its bay, from its west edge.
const DOOR := Vector2(0.4, 1.3)
## The corridor (motel space): its north and south walls; the stairs up along its south
## side at the east end, rising to the west (foot at STAIRS_X.y, top at STAIRS_X.x).
const CORRIDOR_Z := Vector2(1.95, 3.6)
const STAIRS_X := Vector2(6.6, 10.6)
const STAIRS_Z := Vector2(2.9, 3.6)
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
## The rooms he lets, each its own (motel_rooms.gd), and what a night costs: the keys on
## his board. The one he does not. The one you get if nothing says otherwise.
const LETS := {2: 12, 4: 15, 9: 25, 11: 10}
const NEVER := 6
const YOURS := 4

# ── the room inside (its own space) ──────────────────────────────────────────

## Inner width (between the partitions).
const ROOM_W := BAY - 0.15
## Two single beds under the headboard on the back wall, the bedside cabinet between them
## (the user, 4. 11.: "work out the night in the motel"): their middles.
const BED_X := [-0.97, 0.25]
const BED_SIZE := Vector3(0.82, 0.5, 1.95)
const BED_Z := ROOM_D * 0.5 - BED_SIZE.z * 0.5
const NIGHTSTAND := Vector3(-0.36, 0.0, ROOM_D * 0.5 - 0.22)
## The headboard wall's picture, its own 16:9 tall over the room's width, from this high;
## only the part of it from CROP.x to CROP.y across, its left edge on the west wall (the
## opening to the hall is east of it).
const HEADWALL_Y := 0.25
const HEADWALL_CROP := Vector2(0.12, 0.88)
## The opening from the bedroom to the hall in the back wall (x from, to); its height.
const BATH_DOOR := Vector2(0.82, 1.44)
const BATH_DOOR_H := 2.0
## Behind the back wall, BACK_D deep: the bathroom in the west and middle, the hall in the
## east, a wall between them at WALL_X with the bathroom's door in it (z from, to); the
## room's door from the corridor in the hall's south wall (x from, to).
const BACK_Z := ROOM_D * 0.5 + 0.1
const BACK_D := 1.75
const BATH_D := BACK_D
const BATH_H := 2.4
const BATH_X := Vector2(-ROOM_W * 0.5, 0.52)
const WALL_X := 0.57
const HALL_X := Vector2(0.62, ROOM_W * 0.5)
const INNER_DOOR_Z := Vector2(BACK_Z + 0.75, BACK_Z + 1.4)
const ENTRY_X := Vector2(0.74, 1.38)
## Where you stand when you come in (eye height), and lie in the first bed; the
## wardrobe's middle along the west wall.
const STAND := Vector3(1.06, 1.6, BACK_Z + BACK_D - 0.8)
const WARDROBE_Z := -0.5
const LIE := Vector3(-0.97, 0.78, 1.55)


## The headboard picture's middle across and its width (room space).
static func headwall_rect() -> Vector2:
	var w := ROOM_W * (HEADWALL_CROP.y - HEADWALL_CROP.x)
	return Vector2(-ROOM_W * 0.5 + w * 0.5, w)


## A point of the headboard's full picture (u across 0..1, v down 0..1) in the room: x, y.
## The picture faces the room from the back wall, so its u runs from east to west.
static func headwall_at(u: float, v: float) -> Vector2:
	var hh := ROOM_W * 9.0 / 16.0
	var r := headwall_rect()
	return Vector2(r.x + r.y * 0.5 - (u - HEADWALL_CROP.x) * ROOM_W, HEADWALL_Y + hh * (1.0 - v))


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


## The reception's street door (motel space): its middle on the floor.
static func door_at(bay: int, up: bool) -> Vector3:
	return Vector3(bay_x0(bay) + (DOOR.x + DOOR.y) * 0.5, UPPER_Y if up else 0.0, FRONT_Z)


## Room `n`'s door on the corridor (motel space): its middle on the floor.
static func hall_door(n: int) -> Vector3:
	var o := room_origin(n)
	return Vector3(o.x + (ENTRY_X.x + ENTRY_X.y) * 0.5, o.y, CORRIDOR_Z.x)


## The reception's door to the passage to the corridor: on its back wall at the east end, in
## its own space; the passage's middle along x (motel space).
const LOBBY_HALL_X := 2.42


static func passage_x() -> float:
	return lobby_origin().x + LOBBY_HALL_X


## The rooms either side of `n` on its floor.
static func beside(n: int) -> Array:
	var out: Array = []
	var b := int(ROOMS[n]["bay"])
	for k in ROOMS:
		if bool(ROOMS[k]["up"]) == bool(ROOMS[n]["up"]) and absi(int(ROOMS[k]["bay"]) - b) == 1:
			out.append(int(k))
	return out


## The room over `n` (0: the roof).
static func above(n: int) -> int:
	if bool(ROOMS[n]["up"]):
		return 0
	for k in ROOMS:
		if bool(ROOMS[k]["up"]) and int(ROOMS[k]["bay"]) == int(ROOMS[n]["bay"]):
			return int(k)
	return 0


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


## A room's door in its own space: the reception's street door; a room's door from the
## corridor, in its hall's south wall.
static func room_door(n: int) -> Vector3:
	if n == 0:
		return to_room(0, door_at(LOBBY_DOOR_BAY, false))
	return Vector3((ENTRY_X.x + ENTRY_X.y) * 0.5, 0.0, BACK_Z + BACK_D + 0.05)


# ── who is in which room tonight ─────────────────────────────────────────────

## The rooms taken tonight (the same on every machine: the day's seed): a travelling
## salesman, a lorry driver, a couple off the 12; never six, never the ones he lets out to
## you (their keys are on the board).
static func taken(day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("motel_taken_%d" % day)
	var out: Array = []
	var want := 2 + rng.randi_range(0, 2)
	var guard := 0
	while out.size() < want and guard < 40:
		guard += 1
		var n := rng.randi_range(1, 12)
		if LETS.has(n) or n == NEVER or out.has(n):
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
