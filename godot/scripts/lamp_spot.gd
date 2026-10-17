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
