class_name LampSpot
extends RefCounted

## Where a lamp stands on a path tile, one rule for the camp (building_manager.gd) and
## the Builder's map (crt_map_panel.gd), so the two always agree (playtest 2026-10-17:
## "in the Builder the lamp is not turned to its path"): at the edge where the path does
## not go on; at a crossing (the path goes all four ways) in a corner between two arms,
## never on the path itself. In tiles from the middle of the tile (x, y on the grid).

const EDGE := 0.4
const CORNER := 0.38


static func offset(coord: Vector2i, is_path: Callable) -> Vector2:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if not bool(is_path.call(coord + d)):
			return Vector2(d) * EDGE
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	return (corners[absi(coord.x * 7 + coord.y * 13) % 4] as Vector2) * CORNER


## The lamp's yaw so its arm reaches over the path (toward the tile's middle).
static func yaw(off: Vector2) -> float:
	return atan2(-off.x, -off.y)


## A bench on a path tile (playtest 1. 11.: "benches on the path like the lamps, at its
## edge but still on it, by the turn"): its back to the edge the Builder's turn points it
## to (turn 0: the bench faces +y, its back to -y), unless the path goes on that way; then
## the nearest edge round where it does not. At a crossing (the path all four ways) the
## turn's own edge. BENCH_EDGE from the tile's middle, facing over the path: its seat on
## the gravel, its back over the verge (the gravel is the middle half of a path tile; at
## 0.3 it stood beside the path on the grass, at 0.22 in the way on it: playtest 7. 11.).
const BENCH_EDGE := 0.26


static func bench_edge(coord: Vector2i, turn: int, is_path: Callable) -> Vector2i:
	var backs := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
	for k in [0, 1, 3, 2]:
		var d: Vector2i = backs[wrapi(turn + k, 0, 4)]
		if not bool(is_path.call(coord + d)):
			return d
	return backs[wrapi(turn, 0, 4)]


static func bench_offset(coord: Vector2i, turn: int, is_path: Callable) -> Vector2:
	return Vector2(bench_edge(coord, turn, is_path)) * BENCH_EDGE
