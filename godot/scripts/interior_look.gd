extends RefCounted

## Restricted look-around for interiors (DESIGN §10): you stay where you entered and only
## turn your head, within limits, like the office in Five Nights at Freddy's.
##
## The cursor stays visible for clicking things in the room. Pushing it into the outer
## band of the screen turns the head that way (faster the closer to the edge); the arrow
## keys do the same. Inside the band the view only sways a little with the cursor, so
## the room stays still under the mouse while you aim at something. Limits are soft: the
## turn slows down before it stops.

## Outer share of the screen width/height that turns the head.
const EDGE_BAND := 0.16
const MAX_YAW_SPEED_DEG := 85.0
const MAX_PITCH_SPEED_DEG := 50.0
const KEY_YAW_SPEED_DEG := 70.0
## How quickly the turn speed follows the cursor (higher = snappier).
const RESPONSE := 7.0
## Small sway with the cursor anywhere on screen, like the old static views.
const SWAY_YAW_DEG := 2.4
const SWAY_PITCH_DEG := 1.6
## The last part of the range in which the turn slows to a stop.
const SOFT_ZONE_DEG := 14.0

var yaw_limit_deg: float = 60.0
var pitch_up_deg: float = 18.0
var pitch_down_deg: float = 24.0

## Current head offset from the base view, degrees.
var yaw_deg: float = 0.0
var pitch_deg: float = 0.0

var _yaw_speed: float = 0.0
var _pitch_speed: float = 0.0


func _init(p_yaw_limit_deg: float = 60.0, p_pitch_up_deg: float = 18.0, p_pitch_down_deg: float = 24.0) -> void:
	yaw_limit_deg = p_yaw_limit_deg
	pitch_up_deg = p_pitch_up_deg
	pitch_down_deg = p_pitch_down_deg


func reset() -> void:
	yaw_deg = 0.0
	pitch_deg = 0.0
	_yaw_speed = 0.0
	_pitch_speed = 0.0


## `cursor`: the mouse position normalised to 0..1 over the screen (or a negative value
## when the cursor should not steer, e.g. it is outside the window).
## `key_axis`: -1 turn left, 1 turn right (arrow keys).
## Returns the rotation offset (pitch, yaw, 0) in radians to add to the base view.
func update(delta: float, cursor: Vector2, key_axis: float = 0.0) -> Vector3:
	var dt := clampf(delta, 0.0, 0.1)
	var steer := cursor.x >= 0.0 and cursor.y >= 0.0
	var want_yaw := 0.0
	var want_pitch := 0.0
	if steer:
		want_yaw = -_edge_push(cursor.x) * MAX_YAW_SPEED_DEG
		want_pitch = -_edge_push(cursor.y) * MAX_PITCH_SPEED_DEG
	want_yaw -= clampf(key_axis, -1.0, 1.0) * KEY_YAW_SPEED_DEG
	var k := 1.0 - exp(-RESPONSE * dt)
	_yaw_speed = lerpf(_yaw_speed, want_yaw, k)
	_pitch_speed = lerpf(_pitch_speed, want_pitch, k)

	yaw_deg = _advance(yaw_deg, _yaw_speed * dt, -yaw_limit_deg, yaw_limit_deg)
	pitch_deg = _advance(pitch_deg, _pitch_speed * dt, -pitch_down_deg, pitch_up_deg)

	var sway := Vector2.ZERO
	if steer:
		sway = Vector2((cursor.x - 0.5) * 2.0, (cursor.y - 0.5) * 2.0)
	return Vector3(
		deg_to_rad(pitch_deg - sway.y * SWAY_PITCH_DEG),
		deg_to_rad(yaw_deg - sway.x * SWAY_YAW_DEG),
		0.0
	)


## 0 inside the screen, rising to 1 at the very edge (-1 on the low side).
static func _edge_push(v: float) -> float:
	if v < EDGE_BAND:
		var t := 1.0 - clampf(v / EDGE_BAND, 0.0, 1.0)
		return -t * t
	if v > 1.0 - EDGE_BAND:
		var t := clampf((v - (1.0 - EDGE_BAND)) / EDGE_BAND, 0.0, 1.0)
		return t * t
	return 0.0


## Moves `value` by `step`, slowing down inside the last SOFT_ZONE_DEG before a limit.
static func _advance(value: float, step: float, lo: float, hi: float) -> float:
	if step > 0.0:
		var room := hi - value
		step *= clampf(room / SOFT_ZONE_DEG, 0.0, 1.0)
	elif step < 0.0:
		var room := value - lo
		step *= clampf(room / SOFT_ZONE_DEG, 0.0, 1.0)
	return clampf(value + step, lo, hi)


## Normalised (0..1) screen cursor for an interior drawn full-window.
static func cursor_of(viewport: Viewport) -> Vector2:
	if viewport == null:
		return Vector2(-1.0, -1.0)
	var screen := viewport.get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var m := viewport.get_mouse_position()
	if m.x < 0.0 or m.y < 0.0 or m.x > screen.x or m.y > screen.y:
		return Vector2(-1.0, -1.0)
	return m / screen


## Left/right arrow keys as an axis (-1..1).
static func key_axis() -> float:
	var axis := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		axis -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		axis += 1.0
	return axis


## Where a mesh lies on screen, normalised 0..1, for clicking things that used to be
## fixed screen rectangles (the view turns now). Empty Rect2 when it is behind you.
static func screen_rect_of(camera: Camera3D, render_size: Vector2, mesh: MeshInstance3D) -> Rect2:
	if camera == null or mesh == null or not mesh.is_inside_tree() or render_size.x <= 0.0 or render_size.y <= 0.0:
		return Rect2()
	var box := mesh.get_aabb()
	var xf := mesh.global_transform
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var corner := xf * box.get_endpoint(i)
		if camera.is_position_behind(corner):
			return Rect2()
		var p := camera.unproject_position(corner) / render_size
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)
