extends Node3D

## A station of a business, worked where it stands in its room (DESIGN.md §7b; decided
## with the user 20. 10.: "the stations in the 3D room, no flat screens"). The bistro's,
## the pub's, the corn stand's and the Jednota's stations all extend this.
##
## The station is a node in its room, put where its counter is (the room's layout says
## where: `surf_*`). Its work surface is the counter's top (or the wall it stands
## against), a Build texture; the things on it are Duke 3D sprites at the room's pixel
## (91 px to a metre): a slice lying in the pan, the basket hanging on its hook. They are
## drawn from the business's live state (kitchen.gd, taproom.gd...) twelve times a second
## whoever is at the station, so everybody in the room sees the slices brown.
##
## Stepping up to it (a click on it in the room) the room's camera goes in steps, twelve a
## second, to a fixed pose over the surface (`cam_pose`). The pointer is cast through the
## camera onto the surface; what can be used glints under it and the gloved finger points;
## a press, a hold, a drag and a release go to the station. Over it hangs the order rail
## (ticket_rail.gd, in the room's pixel, in front of the camera), and under the room the
## frame (station_hud.gd): the sentence of what a click would do, the bar with BACK and the
## room's other stations, the ticket you picked, big.
##
## Coordinates on the surface are "design pixels", 640 x 360 across it whatever its size
## in metres (the stations were first laid out on their 16:9 Build pictures). On a counter
## design y runs from the back edge (0) to the cook (360); on a wall from the top down.
##
## Subclasses override:
##   _build()              make the things once (sprites, meters), in the room
##   _show()               put them where the state says (twelve a second, always)
##   _spots() -> Array     what can be used now: {id, rect: Rect2 (design px)} or
##                         {id, node: a sprite}, and "verb": what a click would do
##   _press(id) / _release(id) / _drag(at)   the pointer on a spot (at: design px)
##   _key(event)           a key while at it
##   _tick(delta)          every frame while somebody is at it here
##   _opened() / _closing()
##   big_ticket() -> Dictionary   the ticket shown big in the frame ({} none)
##   bar_text() -> String  the counts at the right end of the bar
##   rail_tickets() -> Array      the tickets on the rail ([] none: no rail)
##   hand_tool() -> String the tool in your gloved hand now (station_hands.gd TOOLS)

signal closed
## Another station of this room was asked for (the bar's tab, a number key, Tab).
signal switch_to(station: String)

const RETRO_UI := preload("res://scripts/ui/retro_ui.gd")
const HOVER_GLINT := preload("res://scripts/ui/hover_glint.gd")
const SPRITE_GLINT := preload("res://scripts/business/sprite_glint.gdshader")
const GLINT_TEX := "res://assets/textury/ui/hover_glint.png"
## The rooms' pixel (AGENTS.md "One pixel throughout"): 128 px to a 1.4 m tile.
const PX_PER_M := 128.0 / 1.4
const DESIGN := Vector2(640.0, 360.0)
const STEP := 1.0 / 12.0
## The camera's way to the station and back, in steps.
const CAM_SEC := 0.5

## Who and where (set by the room before it is added).
var building_key := ""
var station := ""
var room := ""
var label := ""
## The work surface in the room's space: its centre, its size in metres (across, then
## deep on a counter or high on a wall), the way its back edge faces (yaw: 0 the back
## wall, 90 the left wall, -90 the right wall) and whether it lies flat.
var surf_at := Vector3.ZERO
var surf_size := Vector2(1.6, 0.9)
var surf_yaw := 0.0
var surf_flat := true
## The camera over it: how far back towards the cook and how high over the surface (a
## counter), or how far out from the wall (a wall). 0: worked out from the size.
var cam_back := 0.0
var cam_up := 0.0
## How far over the surface the camera looks (a tall thing on it, the tap's tower).
var cam_aim := 0.0
## How far to the side (the surface's own x) the camera stands and looks: something
## beside the counter in the picture too (the Jednota's trolley by its packing table).
var cam_side := 0.0
## The business's live state (kitchen.gd, taproom.gd...), set by the room.
var state: Node
## The room's camera (set while you are at it: the pointer is cast through it).
var camera: Camera3D
## The frame under the room (station_hud.gd), set by the room.
var hud: Node

var _open := false
var _closing_now := false
var _t := 0.0
var _acc := 0.0
## The pointer: on the surface (design px, -1 off it), and the surface point without the
## edges (for dragging past them).
var _mouse := Vector2(-1, -1)
var _mouse_free := Vector2(-1, -1)
var _vp_mouse := Vector2(-1, -1)
## The pointer's ray in this node's space (for things held up off the surface).
var _ray_o := Vector3.ZERO
var _ray_d := Vector3.ZERO
var _hover := ""
var _hover_verb := ""
var _held := ""
var _msg_line := ""
var _glint = HOVER_GLINT.new()
var _glint_on = null
var _hot: MeshInstance3D
var _audio: Array = []
var _audio_i := 0
var _pops: Array = []
var _rail: Node3D
## The tickets on the rail last time (a new one clips on with a ding).
var _rail_seen: Dictionary = {}
## Your gloved hand with the station's tool in it (station_hands.gd), while you are at it.
var _hands_ui: CanvasLayer

static var _room_tex: Dictionary = {}
## The shot drivers' pointer (screen px; x < 0: the real one): a warped mouse does not
## always reach the window in a test run.
static var debug_mouse := Vector2(-1, -1)


## The pointer on the screen (the shot drivers' when they set one).
static func mouse_of(vp: Viewport) -> Vector2:
	return debug_mouse if debug_mouse.x >= 0.0 else vp.get_mouse_position()
static var _sprite_glint_mats: Dictionary = {}


func _ready() -> void:
	position = surf_at
	rotation_degrees.y = surf_yaw
	for i in 4:
		var a := AudioStreamPlayer.new()
		a.volume_db = -8.0
		add_child(a)
		_audio.append(a)
	_hot = MeshInstance3D.new()
	_hot.name = "HotSpot"
	var hm := StandardMaterial3D.new()
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(1, 1, 1, 0)
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hot.material_override = hm
	_hot.visible = false
	_hot.set_meta("retro_skip", true)
	add_child(_hot)
	_build()
	_show()


# ── the surface ──────────────────────────────────────────────────────────────

## A point of the surface (design px) in this node's space, `lift` metres off it.
func local_at(px: Vector2, lift := 0.0) -> Vector3:
	var u := px.x / DESIGN.x - 0.5
	var v := px.y / DESIGN.y - 0.5
	if surf_flat:
		return Vector3(u * surf_size.x, lift, v * surf_size.y)
	return Vector3(u * surf_size.x, -v * surf_size.y, lift)


## A length in design px across the surface, in metres.
func metres_x(px: float) -> float:
	return px / DESIGN.x * surf_size.x


## Where the pointer's ray crosses the height `lift` over the surface (this node's space):
## a thing held in the hand is drawn there, right under the finger, not over the point
## of the surface below it.
func held_at(lift: float) -> Vector3:
	if _ray_d == Vector3.ZERO:
		return local_at(_mouse_free, lift)
	if surf_flat and absf(_ray_d.y) > 0.0001:
		var t := (lift - _ray_o.y) / _ray_d.y
		if t > 0.0:
			return _ray_o + _ray_d * t
	elif not surf_flat and absf(_ray_d.z) > 0.0001:
		var t2 := (lift - _ray_o.z) / _ray_d.z
		if t2 > 0.0:
			return _ray_o + _ray_d * t2
	return local_at(_mouse_free, lift)


## A place of the surface lit as where a held thing would go (a free place in the pan);
## Rect2() takes it off.
func mark_target(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		if _glint_on is String:
			_glint_off()
		return
	_glint_rect(r)


## The surface point (design px) under a point of this node's space.
func design_of(local: Vector3) -> Vector2:
	if surf_flat:
		return Vector2((local.x / surf_size.x + 0.5) * DESIGN.x, (local.z / surf_size.y + 0.5) * DESIGN.y)
	return Vector2((local.x / surf_size.x + 0.5) * DESIGN.x, (0.5 - local.y / surf_size.y) * DESIGN.y)


## Where the camera stands over the station (global): over the counter towards the cook,
## looking down at it at a steep angle, the top of the view left for the rail; level in
## front of a wall.
func cam_pose() -> Transform3D:
	var c := global_transform
	var toward_cook := c.basis.z.normalized()
	if surf_flat:
		var k := surf_size.x / 1.6
		var back := cam_back if cam_back > 0.0 else 0.66 * k
		var up := cam_up if cam_up > 0.0 else 1.02 * k
		var side := c.basis.x.normalized() * cam_side
		var eye := c.origin + toward_cook * back + Vector3(0, up, 0) + side
		var look := c.origin - toward_cook * (0.1 * k) + Vector3(0, cam_aim, 0) + side
		return Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
	var out := cam_back if cam_back > 0.0 else surf_size.x * 0.62
	var eye2 := c.origin + toward_cook * out + Vector3(0, 0.12, 0)
	return Transform3D(Basis(), eye2).looking_at(c.origin + Vector3(0, 0.05, 0), Vector3.UP)


## The camera from where it is to `to`, in steps twelve a second.
static func step_camera(host: Node, cam: Camera3D, to: Transform3D, seconds := CAM_SEC) -> Tween:
	var from := cam.global_transform
	var steps := maxi(1, int(round(seconds * 12.0)))
	var tw := host.create_tween()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(cam):
			return
		var e: float = Tween.interpolate_value(0.0, 1.0, floorf(k * steps) / steps, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		cam.global_transform = from.interpolate_with(to, e), 0.0, 1.0, seconds)
	return tw


# ── sprites at the room's pixel ──────────────────────────────────────────────

## `path` shrunk to the room's pixel: its longer side `metres` long, 91 px to the metre
## (a picture made finer is box-shrunk, never shown small at its own size; one made
## coarser keeps its pixels). The edge is hard, as Build's sprites were. Made once.
static func room_tex(path: String, metres: float) -> Texture2D:
	var long_px := maxi(1, roundi(metres * PX_PER_M))
	var key := "%s|%d" % [path, long_px]
	if _room_tex.has(key):
		return _room_tex[key]
	if not ResourceLoader.exists(path):
		_room_tex[key] = null
		return null
	var src: Texture2D = load(path)
	var img: Image = src.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var longest := maxi(img.get_width(), img.get_height())
	if longest > long_px:
		var k := float(long_px) / float(longest)
		var w := maxi(1, roundi(img.get_width() * k))
		var h := maxi(1, roundi(img.get_height() * k))
		# Premultiplied, so the clear pixels round the edge do not darken it.
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a))
		img.resize(w, h, Image.INTERPOLATE_TRILINEAR)
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a < 0.45:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					img.set_pixel(x, y, Color(minf(1.0, c.r / c.a), minf(1.0, c.g / c.a), minf(1.0, c.b / c.a), 1.0))
	var t := ImageTexture.create_from_image(img)
	_room_tex[key] = t
	return t


## The metres a picture is at the room's pixel when left at its own size.
static func own_metres(path: String) -> float:
	if not ResourceLoader.exists(path):
		return 0.1
	var t: Texture2D = load(path)
	return float(maxi(t.get_width(), t.get_height())) / PX_PER_M


## A Duke 3D sprite of `path` on the station, its longer side `metres` long: lying flat
## on the surface (`flat`) or standing up off it facing the cook. Lit by the room.
func sprite(path: String, metres: float, flat := true, parent: Node3D = null) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.double_sided = true
	s.shaded = true
	s.pixel_size = 1.0 / PX_PER_M
	if flat and surf_flat:
		s.axis = Vector3.AXIS_Y
	var tex := room_tex(path, metres)
	s.texture = tex
	if tex != null:
		# Coarser than the room's pixel: keep its pixels at the size asked for.
		s.pixel_size = metres / float(maxi(tex.get_width(), tex.get_height()))
	s.set_meta("tex_key", "%s|%s" % [path, metres])
	(parent if parent != null else self).add_child(s)
	return s


## Swaps a sprite's picture (the slice going golden), at the same size.
func retex(s: Sprite3D, path: String, metres: float) -> void:
	var key := "%s|%s" % [path, metres]
	if s == null or str(s.get_meta("tex_key", "")) == key:
		return
	var tex := room_tex(path, metres)
	if tex == null:
		return
	s.texture = tex
	s.pixel_size = metres / float(maxi(tex.get_width(), tex.get_height()))
	s.set_meta("tex_key", key)


## A sprite put at a surface point.
func put(s: Node3D, px: Vector2, lift := 0.0) -> void:
	if s != null:
		s.position = local_at(px, lift)


## A meter standing over something (a pixel column: frame, a green window, the fill),
## unshaded so it reads under a dim bulb. `set_meter` fills it.
func meter(w := 5, h := 16) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.double_sided = true
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = 1.0 / PX_PER_M
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	s.texture = ImageTexture.create_from_image(img)
	s.set_meta("meter_img", img)
	s.set_meta("meter_sig", "")
	s.offset = Vector2(0, h * 0.5)
	add_child(s)
	return s


## A meter's fill (0..1 from the bottom), its window (zone.x..zone.y; -1 none) and colour.
func set_meter(s: Sprite3D, fill: float, zone := Vector2(-1, -1), col := RETRO_UI.C_AMBER, blink := false) -> void:
	if s == null:
		return
	var img: Image = s.get_meta("meter_img")
	var w := img.get_width()
	var h := img.get_height()
	var on := not blink or int(_t * 4.0) % 2 == 0
	var filled := clampi(int(round(clampf(fill, 0.0, 1.0) * float(h - 2))), 0, h - 2)
	var sig := "%d|%.2f|%.2f|%s|%s" % [filled, zone.x, zone.y, col.to_html(), on]
	if sig == str(s.get_meta("meter_sig")):
		return
	s.set_meta("meter_sig", sig)
	img.fill(Color(0.05, 0.04, 0.03, 1.0))
	img.fill_rect(Rect2i(1, 1, w - 2, h - 2), Color(0.2, 0.17, 0.13, 1.0))
	if zone.x >= 0.0:
		var z0 := int(round(zone.x * float(h - 2)))
		var z1 := int(round(zone.y * float(h - 2)))
		img.fill_rect(Rect2i(1, h - 1 - z1, w - 2, maxi(1, z1 - z0)), Color(0.24, 0.42, 0.18, 1.0))
	if on and filled > 0:
		img.fill_rect(Rect2i(1, h - 1 - filled, w - 2, filled), col)
	(s.texture as ImageTexture).update(img)


# ── what is under the pointer ────────────────────────────────────────────────

## The pointer (in the room's viewport pixels, the camera's), each frame while open.
func point(vp_mouse: Vector2) -> void:
	_vp_mouse = vp_mouse
	_mouse = Vector2(-1, -1)
	_mouse_free = Vector2(-1, -1)
	if camera == null or not is_instance_valid(camera) or vp_mouse.x < 0.0:
		_set_hover("", "")
		_point_hand()
		return
	var inv := global_transform.affine_inverse()
	var o: Vector3 = inv * camera.project_ray_origin(vp_mouse)
	var d: Vector3 = inv.basis * camera.project_ray_normal(vp_mouse)
	_ray_o = o
	_ray_d = d
	var hit := Vector3.INF
	if surf_flat and absf(d.y) > 0.0001:
		var t := -o.y / d.y
		if t > 0.0:
			hit = o + d * t
	elif not surf_flat and absf(d.z) > 0.0001:
		var t2 := -o.z / d.z
		if t2 > 0.0:
			hit = o + d * t2
	if hit != Vector3.INF:
		_mouse_free = design_of(hit)
		if Rect2(Vector2.ZERO, DESIGN).grow(24.0).has_point(_mouse_free):
			_mouse = _mouse_free
	_find_hover()
	if _held != "":
		_drag(_mouse_free)
	_point_hand()


## The hand after the pointer, with the tool for what is under it.
func _point_hand() -> void:
	if _hands_ui == null or not is_instance_valid(_hands_ui):
		return
	_hands_ui.set("tool", hand_tool())
	_hands_ui.set("on_work", _held != "" or _hover != "" or _mouse.x >= 0.0)


func _find_hover() -> void:
	if _held != "":
		return
	var spots := _spots()
	# Sprites first (they stand nearer), the last made on top; then the surface's places.
	for i in range(spots.size() - 1, -1, -1):
		var s: Dictionary = spots[i]
		var n = s.get("node", null)
		if n != null and is_instance_valid(n) and (n as Node3D).is_visible_in_tree() and _screen_rect(n as Node3D).grow(2.0).has_point(_vp_mouse):
			_set_hover(str(s["id"]), str(s.get("verb", "")), n)
			return
	if _mouse.x >= 0.0:
		for i in range(spots.size() - 1, -1, -1):
			var s: Dictionary = spots[i]
			if s.has("rect") and (s["rect"] as Rect2).has_point(_mouse):
				_set_hover(str(s["id"]), str(s.get("verb", "")), s["rect"])
				return
	_set_hover("", "")


## A node's box on the camera's picture (viewport pixels).
func _screen_rect(n: Node3D) -> Rect2:
	var box: AABB
	if n is VisualInstance3D:
		box = (n as VisualInstance3D).get_aabb()
	else:
		box = AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1))
	var r := Rect2()
	var first := true
	for i in 8:
		var p: Vector3 = n.global_transform * box.get_endpoint(i)
		if camera.is_position_behind(p):
			continue
		var sp := camera.unproject_position(p)
		if first:
			r = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			r = r.expand(sp)
	return r


func _set_hover(id: String, verb: String, what = null) -> void:
	_hover = id
	_hover_verb = verb
	if what == null or id == "":
		_glint_off()
		return
	if what is Sprite3D:
		_glint_sprite(what as Sprite3D)
	elif what is MeshInstance3D:
		# _glint_on may be a rect's key (a String): compare like with like.
		if not (_glint_on is MeshInstance3D and _glint_on == what):
			_glint_off()
			_glint.show_on([what])
			_glint_on = what
	elif what is Rect2:
		_glint_rect(what as Rect2)
	else:
		_glint_off()


func _glint_off() -> void:
	if _glint_on is Sprite3D and is_instance_valid(_glint_on):
		(_glint_on as Sprite3D).material_overlay = null
	_glint_on = null
	_glint.clear()
	_hot.visible = false


func _glint_sprite(s: Sprite3D) -> void:
	if _glint_on is Sprite3D and _glint_on == s:
		return
	_glint_off()
	if s.texture == null:
		return
	var tex_id := s.texture.get_instance_id()
	var m: ShaderMaterial = _sprite_glint_mats.get(tex_id, null)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = SPRITE_GLINT
		m.set_shader_parameter("mask", s.texture)
		if ResourceLoader.exists(GLINT_TEX):
			m.set_shader_parameter("glint", load(GLINT_TEX))
			m.set_shader_parameter("has_glint", true)
		_sprite_glint_mats[tex_id] = m
	s.material_overlay = m
	_glint_on = s


## A place of the surface itself (a bowl, the sack): a quad over it takes the glint.
func _glint_rect(r: Rect2) -> void:
	var key := "%s" % r
	if _glint_on is String and str(_glint_on) == key:
		return
	_glint_off()
	var q := PlaneMesh.new() if surf_flat else QuadMesh.new()
	var size := Vector2(metres_x(r.size.x), r.size.y / DESIGN.y * surf_size.y)
	if q is PlaneMesh:
		(q as PlaneMesh).size = size
	else:
		(q as QuadMesh).size = size
	_hot.mesh = q
	_hot.position = local_at(r.get_center(), 0.006)
	_hot.visible = true
	_glint.show_on([_hot])
	_glint_on = key


func hovered() -> String:
	return _hover


func hover_verb() -> String:
	return _hover_verb


func holding() -> String:
	return _held


## The pointer pressed (left button) at the station: on what is under it.
func press() -> void:
	if _hover == "" or _closing_now:
		return
	_held = _hover
	_glint_off()
	_point_hand()
	if _hands_ui != null and is_instance_valid(_hands_ui):
		_hands_ui.call("act", true)
	_press(_held)


func release() -> void:
	if _held == "":
		return
	var was := _held
	_held = ""
	if _hands_ui != null and is_instance_valid(_hands_ui):
		_hands_ui.call("act", false)
	_release(was)


# ── open, closed ─────────────────────────────────────────────────────────────

func is_open() -> bool:
	return _open


## You stepped up to it (the room has started the camera on its way).
func open_station(cam: Camera3D) -> void:
	camera = cam
	_open = true
	_closing_now = false
	_held = ""
	_rail_seen.clear()
	for t in rail_tickets():
		_rail_seen[str(t.get("id", ""))] = true
	_make_rail()
	if _hands_ui == null or not is_instance_valid(_hands_ui):
		_hands_ui = load("res://scripts/business/station_hands.gd").new()
		_hands_ui.name = "StationHand"
		get_tree().root.add_child(_hands_ui)
	_opened()


## You stepped away (or the room closed under you).
func close_station() -> void:
	if not _open:
		return
	release()
	_closing()
	_open = false
	_glint_off()
	_hover = ""
	_hover_verb = ""
	if _rail != null and is_instance_valid(_rail):
		_rail.queue_free()
	_rail = null
	if _hands_ui != null and is_instance_valid(_hands_ui):
		_hands_ui.queue_free()
	_hands_ui = null
	closed.emit()


func _make_rail() -> void:
	if _rail != null and is_instance_valid(_rail):
		_rail.queue_free()
	_rail = null
	if camera == null or not has_rail():
		return
	_rail = load("res://scripts/business/ticket_rail.gd").new()
	_rail.name = "TicketRail"
	_rail.set("tickets_of", func() -> Array: return rail_tickets())
	_rail.set("draw_ticket", Callable(self, "draw_ticket"))
	_rail.set("picked_of", func() -> String: return picked_ticket())
	camera.add_child(_rail)


## The ticket on the rail under the pointer ("" none).
func rail_ticket_at(vp_mouse: Vector2) -> String:
	if _rail == null or not is_instance_valid(_rail):
		return ""
	return str(_rail.call("ticket_at", vp_mouse))


# ── saying things ────────────────────────────────────────────────────────────

func say(who: String, text: String) -> void:
	if hud != null and is_instance_valid(hud):
		hud.call("say", who, text)


## Papa's slip for an order just served, in the frame (station_hud.serve_card).
func score_card(v: Dictionary, what := "") -> void:
	if hud != null and is_instance_valid(hud) and hud.has_method("serve_card"):
		hud.call("serve_card", v, what)


func sfx(path_or_name: String, db := -8.0, pitch := 1.0) -> void:
	var path := path_or_name
	if not path.begins_with("res://"):
		path = sfx_dir() + path_or_name + ".mp3"
	if not ResourceLoader.exists(path):
		path = path.get_basename() + ".wav"
		if not ResourceLoader.exists(path):
			return
	var a: AudioStreamPlayer = _audio[_audio_i]
	_audio_i = (_audio_i + 1) % _audio.size()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = pitch
	a.play()


## A word or a number floating up off the surface and fading (+$9, BURNT), in the room's
## pixel, in steps.
func pop(text: String, px: Vector2, col: Color = RETRO_UI.C_AMBER_LIGHT, big := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = RETRO_UI.FONT_BIG if big else RETRO_UI.FONT_LABEL
	l.font_size = 10 if big else 8
	l.pixel_size = 1.0 / PX_PER_M * (1.5 if big else 1.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.double_sided = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.modulate = col
	l.outline_size = 0
	l.render_priority = 10
	l.position = local_at(px, 0.12)
	add_child(l)
	_pops.append({"node": l, "t": 0.0, "from": l.position})


# ── time ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	if _open and not get_tree().paused:
		_tick(delta)
		if int(_t * 2.0) != int((_t - delta) * 2.0):
			_check_rail()
	for p in _pops:
		p["t"] = float(p["t"]) + delta
	_acc += delta
	if _acc < STEP:
		return
	_acc = 0.0
	# Twelve a second: the things where the state says, the pops rising.
	if is_visible_in_tree():
		_show()
	var keep: Array = []
	for p in _pops:
		var l: Label3D = p["node"]
		var k := float(p["t"]) / 1.3
		if k >= 1.0 or not is_instance_valid(l):
			if is_instance_valid(l):
				l.queue_free()
			continue
		l.position = (p["from"] as Vector3) + Vector3(0, floorf(k * 12.0) / 12.0 * 0.22, 0)
		l.modulate.a = 1.0 - k * k
		keep.append(p)
	_pops = keep


## Twice a second at the station: a new ticket on the rail dings.
func _check_rail() -> void:
	var now := {}
	var fresh := false
	for t in rail_tickets():
		var id := str(t.get("id", ""))
		now[id] = true
		fresh = fresh or not _rail_seen.has(id)
	if fresh:
		sfx(ding_sound(), -12.0)
	_rail_seen = now


# ── for subclasses ───────────────────────────────────────────────────────────

func sfx_dir() -> String:
	return "res://assets/sfx/"


func ding_sound() -> String:
	return "order_in"


func has_rail() -> bool:
	return true


func rail_tickets() -> Array:
	return []


## The tool in your hand for what the pointer is over (or holds): station_hands.gd TOOLS.
func hand_tool() -> String:
	return "press" if _hover != "" else "open"


## The rail's picked ticket's id ("" none).
func picked_ticket() -> String:
	return ""


## A ticket on the rail was clicked.
func rail_clicked(_id: String) -> void:
	pass


## Draws ticket `t` onto `c` (the ticket's own little picture, `size` px).
func draw_ticket(_c: Control, _t: Dictionary, _size: Vector2) -> void:
	pass


func big_ticket() -> Dictionary:
	return {}


func bar_text() -> String:
	return ""


func _build() -> void:
	pass


func _show() -> void:
	pass


func _spots() -> Array:
	return []


func _press(_id: String) -> void:
	pass


func _release(_id: String) -> void:
	pass


func _drag(_at: Vector2) -> void:
	pass


func _key(_e: InputEventKey) -> void:
	pass


func key(e: InputEventKey) -> void:
	_key(e)


func _tick(_delta: float) -> void:
	pass


func _opened() -> void:
	pass


func _closing() -> void:
	pass


# ── debug (the shot drivers) ─────────────────────────────────────────────────

## The mouse onto a point of the surface (design px), `lift` metres over it: the hand
## and the glint follow it as they would the player's.
func debug_mouse_to(px: Vector2, lift := 0.0) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var g: Vector3 = global_transform * local_at(px, lift)
	var sp := camera.unproject_position(g)
	var vsize := camera.get_viewport().get_visible_rect().size
	var win := get_tree().root.get_visible_rect().size
	debug_mouse = sp / vsize * win
	get_tree().root.warp_mouse(debug_mouse)


## Back to the real pointer.
func debug_mouse_free() -> void:
	debug_mouse = Vector2(-1, -1)
