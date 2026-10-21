extends CanvasLayer

## Sat at the staffroom's old chunky laptop (DESIGN.md §7c; the user 21. 10.: "a PC in
## the form of an old chunky laptop, with the reception PC's functions"). The camera sits
## down on its chair, then the close-up comes up: the laptop on the formica table, a mug,
## the ashtray (Grok, assets/textury/closeup/laptop.png, in the game's pixels), and on its
## screen the office PC's own desktop, the very same machine (building_interior.gd's
## _crt_viewport and its os_shell): everything it does, the programs, the mail, Builder,
## the shops. Drawn at the window's full resolution like the office monitor, mapped onto
## the screen's four corners as they were measured on the render
## (laptop_screen.json), and the mouse and the keys go to it the same way back.
## S (not typing) or a click below the machine stands you up; Esc is the pause menu's.
## Co-op: one warden at the PC at a time (here or at the office); the others in the room
## see their screen on the laptop (partner_frame) and them on its chair.

const PIC := "res://assets/textury/closeup/laptop.png"
const CORNERS := "res://assets/textury/closeup/laptop_screen.json"
const PLAN = preload("res://scripts/staff/staffroom_plan.gd")
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const SIT_SEC := 0.45
## How tall the screen stands in the window (the picture is zoomed in round it).
const SCREEN_OF_WINDOW := 0.58
const SFX_SIT := "res://assets/sfx/backroom/bed_creak.mp3"
const SHADER := """
shader_type canvas_item;
uniform sampler2D pic : filter_nearest;
uniform sampler2D os : filter_linear;
uniform mat3 to_screen;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float lit = 1.0;
uniform float has_os = 1.0;
void fragment() {
	vec3 h = to_screen * vec3(UV, 1.0);
	vec2 s = h.xy / h.z;
	vec4 c = texture(pic, UV);
	if (has_os > 0.5 && s.x >= 0.0 && s.x <= 1.0 && s.y >= 0.0 && s.y <= 1.0) {
		vec3 o = texture(os, uv_rect.xy + s * uv_rect.zw).rgb;
		// A passive-matrix panel of the nineties: a little dim and cold, its edge darker.
		float edge = smoothstep(0.0, 0.035, min(min(s.x, 1.0 - s.x), min(s.y, 1.0 - s.y)));
		c.rgb = o * vec3(0.9, 0.95, 0.97) * (0.72 + 0.28 * edge) * lit;
	}
	COLOR = c;
}
"""

var _bi                       # building_interior.gd (the office PC)
var _cam: Camera3D
var _cam_from := {}
var _pic: Texture2D
var _rect: TextureRect
var _mat: ShaderMaterial
var _corners: Array = [Vector2(0.35, 0.09), Vector2(0.65, 0.1), Vector2(0.64, 0.47), Vector2(0.35, 0.43)]
## Picture uv -> screen uv (and back), for the shader and the mouse.
var _h := Basis()
var _h_inv := Basis()
## The part of the picture shown, in picture uv (zoomed in round the screen).
var _view := Rect2(0, 0, 1, 1)
var _open_t := -1.0
var _tween: Tween
var _audio: AudioStreamPlayer
var _partner_tex: ImageTexture
var _partner_left := 0.0


func _init() -> void:
	layer = 62
	visible = false


func _ready() -> void:
	_pic = load(PIC) if ResourceLoader.exists(PIC) else null
	if FileAccess.file_exists(CORNERS):
		var d = JSON.parse_string(FileAccess.get_file_as_string(CORNERS))
		if d is Dictionary and d.get("corners") is Array and (d["corners"] as Array).size() == 4:
			_corners = []
			for c in d["corners"]:
				_corners.append(Vector2(float(c[0]), float(c[1])))
	var back := ColorRect.new()
	back.color = Color(0, 0, 0)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_rect = TextureRect.new()
	_rect.texture = _pic
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("pic", _pic)
	_rect.material = _mat
	add_child(_rect)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -10.0
	add_child(_audio)
	_h = _homography(_corners)
	_h_inv = _h.inverse()
	_mat.set_shader_parameter("to_screen", _h)
	get_tree().root.size_changed.connect(_layout)


## The square of the screen (0..1) to picture uv: the four corners tl, tr, br, bl.
## Returns picture -> screen (the inverse of that map), as a Basis used like a mat3.
static func _homography(c: Array) -> Basis:
	var p0: Vector2 = c[0]
	var p1: Vector2 = c[1]
	var p2: Vector2 = c[2]
	var p3: Vector2 = c[3]
	# Unit square -> quad (Heckbert).
	var sx := p0.x - p1.x + p2.x - p3.x
	var sy := p0.y - p1.y + p2.y - p3.y
	var dx1 := p1.x - p2.x
	var dx2 := p3.x - p2.x
	var dy1 := p1.y - p2.y
	var dy2 := p3.y - p2.y
	var den := dx1 * dy2 - dx2 * dy1
	var g := (sx * dy2 - dx2 * sy) / den
	var hh := (dx1 * sy - sx * dy1) / den
	var a := p1.x - p0.x + g * p1.x
	var b := p3.x - p0.x + hh * p3.x
	var d := p1.y - p0.y + g * p1.y
	var e := p3.y - p0.y + hh * p3.y
	# Columns of the matrix (x' = a u + b v + p0.x, ...): Basis(columns).
	var sq_to_quad := Basis(Vector3(a, d, g), Vector3(b, e, hh), Vector3(p0.x, p0.y, 1.0))
	return sq_to_quad.inverse()


static func _apply(m: Basis, p: Vector2) -> Vector2:
	var v := m * Vector3(p.x, p.y, 1.0)
	return Vector2(v.x / v.z, v.y / v.z) if absf(v.z) > 0.00001 else Vector2(-1, -1)


func _layout() -> void:
	var win := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280, 720)
	if _pic == null or win.x <= 0.0:
		return
	var pw := float(_pic.get_width())
	var ph := float(_pic.get_height())
	var top: Vector2 = (_corners[0] + _corners[1]) * 0.5
	var bot: Vector2 = (_corners[3] + _corners[2]) * 0.5
	var screen_h := (bot.y - top.y) * ph
	# Zoomed so the screen is SCREEN_OF_WINDOW of the window tall, but always covering it.
	var k := maxf(win.y * SCREEN_OF_WINDOW / maxf(1.0, screen_h), maxf(win.x / pw, win.y / ph))
	var size := Vector2(pw, ph) * k
	var mid := (top + bot) * 0.5 * Vector2(pw, ph) * k
	var pos := Vector2(win.x * 0.5 - mid.x, win.y * 0.44 - mid.y)
	pos.x = clampf(pos.x, win.x - size.x, 0.0)
	pos.y = clampf(pos.y, win.y - size.y, 0.0)
	_rect.position = pos.round()
	_rect.size = size.round()


func is_open() -> bool:
	return visible


func open_for(bi, cam: Camera3D) -> void:
	if visible or bi == null:
		return
	_bi = bi
	_cam = cam
	var vp = _bi.get("_crt_viewport")
	if vp == null and _bi.has_method("_build_crt_viewport"):
		_bi.call("_build_crt_viewport")
		vp = _bi.get("_crt_viewport")
	if vp is SubViewport:
		_mat.set_shader_parameter("os", (vp as SubViewport).get_texture())
		var dual: bool = bool(_bi.get("_dual"))
		_mat.set_shader_parameter("uv_rect", Vector4(0.0, 0.0, 0.5 if dual else 1.0, 1.0))
	# Sitting down: the eye over the keys, looking at the screen.
	_cam_from = {"position": _cam.position, "rotation": _cam.rotation, "fov": _cam.fov}
	var eye := PLAN.LAPTOP_EYE
	var look := PLAN.LAPTOP + Vector3(0, 0.16, -0.12)
	var rot := Transform3D(Basis(), eye).looking_at(look, Vector3.UP).basis.get_euler()
	if _tween != null:
		_tween.kill()
	_tween = CAM_MOVE.move(self, _cam, {"position": eye, "rotation": rot, "fov": 50.0}, SIT_SEC, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_play(SFX_SIT, -16.0)
	_tween.finished.connect(_show, CONNECT_ONE_SHOT)


func _show() -> void:
	if _bi == null:
		return
	visible = true
	_open_t = 0.0
	_layout()
	_bi.call("_set_crt_viewport_live", true)
	var ui = _bi.get("_crt_ui")
	if ui != null:
		if ui.has_method("set_screen"):
			ui.set_screen(0)
		ui.open_panel()
		if ui.has_method("extras") and ui.extras() != null:
			ui.extras().poke()
	_bi.set_meta("laptop_active", true)


## Up from the laptop: the picture goes, the eye goes back to where it stood.
func close_view() -> void:
	if not visible:
		return
	close_now()
	if _cam != null and not _cam_from.is_empty():
		if _tween != null:
			_tween.kill()
		_tween = CAM_MOVE.move(self, _cam, _cam_from, SIT_SEC, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)


func close_now() -> void:
	if not visible:
		return
	visible = false
	if _bi != null:
		_bi.set_meta("laptop_active", false)
		var ui = _bi.get("_crt_ui")
		if ui != null:
			ui.close_panel()
		if not bool(_bi.call("is_crt_view_active")):
			_bi.call("_set_crt_viewport_live", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	if _partner_left > 0.0:
		_partner_left -= delta
		if _partner_left <= 0.0:
			_partner_tex = null
	if not visible:
		return
	_open_t += delta
	# On in a few steps, like the game's other pictures.
	var k := clampf(floorf(_open_t / 0.05) / 4.0, 0.0, 1.0)
	_rect.modulate = Color(k, k, k)
	var powered := true
	var ui = _bi.get("_crt_ui") if _bi != null else null
	if ui != null and ui.has_method("_has_power"):
		powered = bool(ui.call("_has_power"))
	_mat.set_shader_parameter("has_os", 1.0 if powered else 0.0)
	# The pointer: the machine's own over its screen, the glove below it (stand up).
	var m := get_viewport().get_mouse_position()
	if _to_os(m) == Vector2.INF:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		HandCursor.want(HandCursor.WALK if INTERIOR_LOOK.in_exit_zone(get_viewport()) else HandCursor.ARROW)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


## A window point to the OS's pixel (INF off the screen).
func _to_os(p: Vector2) -> Vector2:
	if _rect.size.x <= 0.0:
		return Vector2.INF
	var uv := (p - _rect.position) / _rect.size
	var s := _apply(_h, uv)
	if s.x < 0.0 or s.x > 1.0 or s.y < 0.0 or s.y > 1.0:
		return Vector2.INF
	return Vector2(s.x * 640.0, s.y * 480.0)


func _input(event: InputEvent) -> void:
	if not visible or _bi == null:
		return
	var vp: SubViewport = _bi.get("_crt_viewport")
	if vp == null:
		return
	var ui = _bi.get("_crt_ui")
	if ui != null and ui.has_method("extras") and ui.extras() != null and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
		var was_saving: bool = ui.extras().is_saving()
		ui.extras().poke()
		if was_saving and (event is InputEventMouseButton or event is InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouse:
		var at := _to_os((event as InputEventMouse).position)
		if at == Vector2.INF:
			# Below the machine: a click stands you up.
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and INTERIOR_LOOK.in_exit_zone(get_viewport()):
				close_view()
			get_viewport().set_input_as_handled()
			return
		var ev: InputEventMouse = event.duplicate()
		ev.position = at
		ev.global_position = at
		if ev is InputEventMouseMotion:
			var sc := 640.0 / maxf(1.0, _rect.size.x * absf(_corners[1].x - _corners[0].x))
			(ev as InputEventMouseMotion).relative = (event as InputEventMouseMotion).relative * sc
		vp.push_input(ev, true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.is_action_pressed("ui_cancel"):
			return
		var typing: bool = bool(_bi.call("_crt_typing"))
		if not typing and ke.physical_keycode == KEY_S and ke.pressed and not ke.echo and not bool(_bi.call("_crt_keys_taken")):
			close_view()
			get_viewport().set_input_as_handled()
			return
		if ke.pressed and not ke.echo and ui != null and ui.has_method("play"):
			ui.play("key", randf_range(-19.0, -15.0))
		vp.push_input(ke, true)
		get_viewport().set_input_as_handled()


## Co-op: the other warden's screen while they sit at it (a JPEG a few times a second).
func partner_frame(frame: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_jpg_from_buffer(frame) != OK:
		return
	if _partner_tex == null or _partner_tex.get_size() != Vector2(img.get_size()):
		_partner_tex = ImageTexture.create_from_image(img)
	else:
		_partner_tex.update(img)
	_partner_left = 0.8


func partner_texture() -> Texture2D:
	return _partner_tex


## Your screen for the others (main.coop_screen_frame) while you sit here.
func screen_frame() -> PackedByteArray:
	if not visible or _bi == null:
		return PackedByteArray()
	return _bi.call("coop_screen_frame_any")


func _play(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.volume_db = db
		_audio.play()
