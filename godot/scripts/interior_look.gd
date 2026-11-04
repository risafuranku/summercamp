extends RefCounted

## Restricted look-around for interiors (DESIGN §10): you stay where you entered and only
## turn your head, within limits, like the office in Five Nights at Freddy's.
##
## Point and click (the user 4. 11. afternoon: "the view inside is still odd, I feel I am
## steering a camera on a joint; keep point and click, the cursor turning the camera at the
## edges", one look everywhere: the reception, the desk, the games, the rooms, the sewer,
## the bus): over the screen the cursor only points, the room stays put under it (a hair
## of parallax for depth); in the outer EDGE_TURN of the left and the right side the head
## turns that way, picking up toward the very edge (EDGE_POWER) and stopping as soon as the
## cursor comes back in. A and D (and the arrows) turn it too, W and S tip it up and down.
## Limits are soft: the turn slows down before it stops. (Till 4. 11. the cursor was a
## stick from the middle: the whole screen turned.)

## Outer share of the screen width that holds a turn at its end (the tent's old dwell).
const EDGE_BAND := 0.20
## The bands along the screen's sides that turn the head (a share of the width / height),
## and how the turn rises across one (a power: gentle where it starts, all of it at the
## edge). A button held (something dragged) narrows them to the outermost part.
const EDGE_TURN := 0.12
const EDGE_POWER := 1.4
const EDGE_HELD := 0.4
## The stick: the dead middle (a share of the way from the middle to the edge) and how the
## turn rises past it (a power: gentle near the middle, all of it at the edge). A held
## button is work under the pointer: the dead middle grows most of the way to the edge.
const STICK_DEAD := 0.26
const STICK_POWER := 1.6
const STICK_HELD := 0.6
const MAX_YAW_SPEED_DEG := 150.0
const MAX_PITCH_SPEED_DEG := 95.0
const KEY_YAW_SPEED_DEG := 130.0
const KEY_PITCH_SPEED_DEG := 90.0
## How quickly the turn picks up, and how quickly it stops once the cursor leaves the
## band (faster: a head stops when you stop turning it, it does not coast; the coasting
## was the "on ice" feel of the 2026-10-16 playtest).
const ACCEL := 18.0
const BRAKE := 26.0
## A small parallax with the cursor anywhere on screen, so the room has depth under the
## mouse; followed by a critically damped spring, never by the turn itself.
const SWAY_YAW_DEG := 0.8
const SWAY_PITCH_DEG := 0.5
const SWAY_FOLLOW := 16.0
## Breathing: the view rises and settles a hair, slowly.
const BREATH_DEG := 0.12
const BREATH_HZ := 0.22
## The last part of the range in which the turn slows to a stop.
const SOFT_ZONE_DEG := 14.0

var yaw_limit_deg: float = 60.0
## This look's dead middle (a desk's work fills the picture: a wider one there), and
## whether W and S tilt the head (not where they row a boat).
var dead: float = STICK_DEAD
var keys_tilt := true
var pitch_up_deg: float = 18.0
var pitch_down_deg: float = 24.0

## Current head offset from the base view, degrees.
var yaw_deg: float = 0.0
var pitch_deg: float = 0.0

var _yaw_speed: float = 0.0
var _pitch_speed: float = 0.0
var _sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
var _t := 0.0
## Holding a turn key on at the end of the range: through the door on that side.
const PUSH_THROUGH_SEC := 0.32
var _push_t := 0.0
var _push_dir := 0
var _pushed := 0


func _init(p_yaw_limit_deg: float = 60.0, p_pitch_up_deg: float = 18.0, p_pitch_down_deg: float = 24.0) -> void:
	yaw_limit_deg = p_yaw_limit_deg
	pitch_up_deg = p_pitch_up_deg
	pitch_down_deg = p_pitch_down_deg


func reset() -> void:
	yaw_deg = 0.0
	pitch_deg = 0.0
	_yaw_speed = 0.0
	_pitch_speed = 0.0
	_sway = Vector2.ZERO
	_sway_v = Vector2.ZERO


## `cursor`: the mouse position normalised to 0..1 over the screen (or a negative value
## when the cursor should not steer, e.g. it is outside the window).
## `key_axis`: -1 turn left, 1 turn right (A/D, the arrows: turn_axis). W and S tilt it here.
## Returns the rotation offset (pitch, yaw, 0) in radians to add to the base view. It is
## already smooth: set the camera to base + offset directly, no further easing.
func update(delta: float, cursor: Vector2, key_axis: float = 0.0) -> Vector3:
	var dt := clampf(delta, 0.0, 0.1)
	_t += dt
	var steer := cursor.x >= 0.0 and cursor.y >= 0.0
	var want_yaw := 0.0
	var want_pitch := 0.0
	if steer:
		# A look with a wider calm middle (a station's work fills the picture) has narrower
		# bands; something held, narrower still.
		var band := EDGE_TURN * clampf((1.0 - dead) / (1.0 - STICK_DEAD), 0.45, 1.0)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			band *= EDGE_HELD
		# Round by the left and right edges only: along the bottom lies the way out (the
		# exit band, a click), along the top what hangs there (the rail of orders); up and
		# down is W and S.
		var edge := _edges(Vector2(cursor.x, 0.5), band)
		want_yaw = -edge.x * MAX_YAW_SPEED_DEG
	want_yaw -= clampf(key_axis, -1.0, 1.0) * KEY_YAW_SPEED_DEG
	if keys_tilt:
		want_pitch += tilt_axis() * KEY_PITCH_SPEED_DEG
	_yaw_speed = _follow(_yaw_speed, want_yaw, dt)
	_pitch_speed = _follow(_pitch_speed, want_pitch, dt)

	if yaw_limit_deg >= 180.0:
		yaw_deg = wrapf(yaw_deg + _yaw_speed * dt, -180.0, 180.0)
	else:
		yaw_deg = _advance(yaw_deg, _yaw_speed * dt, -yaw_limit_deg, yaw_limit_deg)
	pitch_deg = _advance(pitch_deg, _pitch_speed * dt, -pitch_down_deg, pitch_up_deg)

	_track_push(clampf(key_axis, -1.0, 1.0), dt)
	var sway_target := Vector2.ZERO
	if steer:
		sway_target = Vector2((cursor.x - 0.5) * 2.0, (cursor.y - 0.5) * 2.0)
	# Critically damped spring: arrives without overshoot, does not drift. Stepped by its
	# exact solution, so it holds at any frame time: the Euler step blew up under ~19 fps
	# (frames over 52 ms), and in the caravan with its many windows the view flew round
	# with the mouse (playtest 25. 10.).
	var w := SWAY_FOLLOW
	var off := _sway - sway_target
	var e := exp(-w * dt)
	var lead := _sway_v + off * w
	_sway = sway_target + (off + lead * dt) * e
	_sway_v = (_sway_v - lead * w * dt) * e
	var breath := sin(_t * TAU * BREATH_HZ) * BREATH_DEG
	return Vector3(
		deg_to_rad(pitch_deg - _sway.y * SWAY_PITCH_DEG + breath),
		deg_to_rad(yaw_deg - _sway.x * SWAY_YAW_DEG),
		0.0
	)


func _track_push(k: float, dt: float) -> void:
	if yaw_limit_deg >= 180.0:
		return
	var dir := 0
	if k < -0.5 and yaw_deg >= yaw_limit_deg - 1.5:
		dir = -1
	elif k > 0.5 and yaw_deg <= -yaw_limit_deg + 1.5:
		dir = 1
	if dir == 0:
		_push_t = 0.0
		_push_dir = 0
		return
	if dir != _push_dir:
		_push_dir = dir
		_push_t = 0.0
	_push_t += dt
	if _push_t >= PUSH_THROUGH_SEC:
		_pushed = dir
		_push_t = -100.0   # once per push: let go and push again


## A push past the end of the turn, as if A/D had been held there (a key that turns you
## round, the tent's E).
func push(dir: int) -> void:
	_pushed = dir


## -1 / 1 once the head has been pushed on past the end of the turn (A/D or arrows held),
## else 0. Reading it clears it.
func take_push() -> int:
	var p := _pushed
	_pushed = 0
	return p


## Turn speed toward `want`: picking up at ACCEL, braking (toward zero or the other way)
## at BRAKE.
static func _follow(speed: float, want: float, dt: float) -> float:
	var braking := absf(want) < absf(speed) or signf(want) != signf(speed)
	var k := 1.0 - exp(-(BRAKE if braking else ACCEL) * dt)
	return lerpf(speed, want, k)


## The edges' push for the cursor at `c` (0..1 over the screen): nothing over the middle,
## then across the outer `band` of a side up to 1 at the edge, that way (-1 left / up).
static func _edges(c: Vector2, band: float) -> Vector2:
	var v := Vector2.ZERO
	if band <= 0.0:
		return v
	if c.x < band:
		v.x = -pow(clampf(1.0 - c.x / band, 0.0, 1.0), EDGE_POWER)
	elif c.x > 1.0 - band:
		v.x = pow(clampf((c.x - (1.0 - band)) / band, 0.0, 1.0), EDGE_POWER)
	if c.y < band:
		v.y = -pow(clampf(1.0 - c.y / band, 0.0, 1.0), EDGE_POWER)
	elif c.y > 1.0 - band:
		v.y = pow(clampf((c.y - (1.0 - band)) / band, 0.0, 1.0), EDGE_POWER)
	return v


## The stick's push for a way `v` from the middle (-1..1 to the edges, corners further):
## nothing inside `dead`, then along it, up to 1.
static func _stick(v: Vector2, dead_zone: float) -> Vector2:
	var r := v.length()
	if r <= dead_zone:
		return Vector2.ZERO
	return v / r * pow(clampf((r - dead_zone) / (1.0 - dead_zone), 0.0, 1.0), STICK_POWER)


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


## A/D and the arrow keys as an axis (-1..1): turning the head in a room.
static func turn_axis() -> float:
	var axis := key_axis()
	if Input.is_physical_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		axis += 1.0
	return clampf(axis, -1.0, 1.0)


## W S and the arrows as an axis (1 up, -1 down): tilting the head in a room.
static func tilt_axis() -> float:
	var axis := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		axis += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		axis -= 1.0
	return axis


## Which side tab a click hit (-1 left, 1 right, 0 none): the tabs are a few percent of
## the width at mid height (make_side_hints).
static func side_tab_at(viewport: Viewport, hints: Control) -> int:
	if hints == null:
		return 0
	var c := cursor_of(viewport)
	if c.x < 0.0 or absf(c.y - 0.5) > 0.05:
		return 0
	if c.x < 0.09 and str(hints.get_meta("left", "")) != "":
		return -1
	if c.x > 0.91 and str(hints.get_meta("right", "")) != "":
		return 1
	return 0


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


# ── leaving: Esc, or the door behind you (the bottom edge of the screen) ───────

## Bottom share of the screen where the door behind you is "under" the cursor.
const EXIT_BAND := 0.07


static func in_exit_zone(viewport: Viewport) -> bool:
	var c := cursor_of(viewport)
	return c.y >= 1.0 - EXIT_BAND


## Space leaves too (the user, 4. 11.), wherever Space is nobody else's: not where it
## serves, rows, turns a page or types (those take it before they ask this).
static func is_space(event: InputEvent) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.physical_keycode == KEY_SPACE


static func is_exit_event(event: InputEvent, viewport: Viewport) -> bool:
	if event.is_action_pressed("ui_cancel") or is_space(event):
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return in_exit_zone(viewport)
	return false


## A dark band along the bottom with "Leave", shown when the cursor reaches it.
static func make_exit_hint(layer: CanvasLayer, text := "Turn round and leave   [Esc]") -> Control:
	var hint := Control.new()
	hint.name = "ExitHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.modulate.a = 0.0
	hint.draw.connect(func():
		var s := hint.size
		var h := s.y * EXIT_BAND
		for i in 8:
			hint.draw_rect(Rect2(0, s.y - h * (1.0 - i / 8.0), s.x, h / 8.0), Color(0, 0, 0, 0.08 + i * 0.06))
		var font := hint.get_theme_default_font()
		var fs := int(maxf(14.0, s.y * 0.026))
		var shown := hint.tr(text)
		var w := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := s.y - h * 0.35
		# A small arrow pointing back over your shoulder.
		var ax := s.x * 0.5 - w * 0.5 - fs * 1.4
		hint.draw_colored_polygon(PackedVector2Array([Vector2(ax, y - fs * 0.6), Vector2(ax + fs, y - fs * 0.6), Vector2(ax + fs * 0.5, y)]), Color(0.95, 0.88, 0.62))
		hint.draw_string(font, Vector2(s.x * 0.5 - w * 0.5 + 2, y + 2), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		hint.draw_string(font, Vector2(s.x * 0.5 - w * 0.5, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.88, 0.62))
	)
	layer.add_child(hint)
	return hint


## Small tabs at the left and right edge, mid height, naming the room through the door
## on that side and its key ("<  Kitchen  [A]"). Text via set_side_hints(); "" hides one.
## (The rooms themselves carry no floating labels: this is the game's UI, not the room's.)
static func make_side_hints(layer: CanvasLayer) -> Control:
	var hint := Control.new()
	hint.name = "SideHints"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.set_meta("left", "")
	hint.set_meta("right", "")
	hint.draw.connect(func():
		var s := hint.size
		var font := hint.get_theme_default_font()
		var fs := int(maxf(13.0, s.y * 0.022))
		for side in ["left", "right"]:
			var text := hint.tr(str(hint.get_meta(side, "")))
			if text == "":
				continue
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pad := fs * 0.6
			var arrow := fs * 0.9
			var box_w := w + pad * 2.0 + arrow
			var box_h := fs * 1.8
			var y := s.y * 0.5 - box_h * 0.5
			var x := 0.0 if side == "left" else s.x - box_w
			hint.draw_rect(Rect2(x, y, box_w, box_h), Color(0, 0, 0, 0.55))
			hint.draw_rect(Rect2(x + (box_w - 2 if side == "left" else 0), y, 2, box_h), Color(0.95, 0.88, 0.62, 0.7))
			var ty := y + box_h * 0.5 + fs * 0.35
			var cy := y + box_h * 0.5
			if side == "left":
				hint.draw_colored_polygon(PackedVector2Array([Vector2(pad, cy), Vector2(pad + arrow * 0.6, cy - fs * 0.45), Vector2(pad + arrow * 0.6, cy + fs * 0.45)]), Color(0.95, 0.88, 0.62))
				hint.draw_string(font, Vector2(pad + arrow, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.88, 0.62))
			else:
				var ax := s.x - pad
				hint.draw_colored_polygon(PackedVector2Array([Vector2(ax, cy), Vector2(ax - arrow * 0.6, cy - fs * 0.45), Vector2(ax - arrow * 0.6, cy + fs * 0.45)]), Color(0.95, 0.88, 0.62))
				hint.draw_string(font, Vector2(x + pad, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.88, 0.62))
	)
	layer.add_child(hint)
	return hint


static func set_side_hints(hint: Control, left: String, right: String) -> void:
	if hint == null:
		return
	if str(hint.get_meta("left", "")) == left and str(hint.get_meta("right", "")) == right:
		return
	hint.set_meta("left", left)
	hint.set_meta("right", right)
	hint.queue_redraw()


static func update_exit_hint(hint: Control, viewport: Viewport, delta: float, allowed := true) -> void:
	if hint == null:
		return
	var target := 1.0 if allowed and in_exit_zone(viewport) else 0.0
	hint.modulate.a = move_toward(hint.modulate.a, target, delta * 5.0)
	hint.move_to_front()
	if hint.modulate.a > 0.0:
		hint.queue_redraw()
