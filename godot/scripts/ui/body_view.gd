extends CanvasLayer

## Your own body from your eyes (the brief of 21. 10.: "a body that stands on the ground"):
##   - looking down, your legs and boots come up into the bottom of the view, where your
##     feet are (the point a step ahead of you put through the camera), Build-weapon style:
##     Grok's jeans and green wellies (hands_lo/feet_*.png) at the hands' pixel and in their
##     light (hands.gd), one foot forward and the other as you walk (a frame per footstep:
##     player_controller.foot_fell), caked after mud (feet_mud), darker wet through;
##   - lying on your belly, your gloved hands planted ahead of you in turn as you crawl
##     (hands_lo/crawl_*.png, the pipes' hands);
##   - a shadow under you on the ground (a blob like the guests' and the other wardens').
## Made by the player (player_controller._ensure_body_view); not in a room or a close-up.

const HANDS = preload("res://scripts/ui/hands.gd")
const DIR := "res://assets/textury/hands_lo/"
## How far ahead of your origin the boots are (m), on the ground.
const FEET_AHEAD := 0.26
## The ground is this far above the body's origin (its capsule's bottom).
const FLOOR_Y := 0.35

var player: CharacterBody3D

var _feet: TextureRect
var _hand_l: TextureRect
var _hand_r: TextureRect
var _tex: Dictionary = {}
## Which foot is forward in the picture: 0 together, 1 left, -1 right.
var _foot := 0
var _still_t := 0.0
var _crawl_left := true
var _crawl_t := 0.0
var _acc := 0.0
var _shadow: MeshInstance3D


func _init() -> void:
	layer = 58
	name = "BodyView"


func _ready() -> void:
	_feet = _rect()
	_hand_l = _rect()
	_hand_r = _rect()
	if player != null:
		player.foot_fell.connect(_on_foot)
		_make_shadow()


func _rect() -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	add_child(r)
	return r


func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png") if ResourceLoader.exists(DIR + n + ".png") else null
	return _tex[n]


func _on_foot(left: bool) -> void:
	_foot = 1 if left else -1
	_still_t = 0.0
	_crawl_left = left
	_crawl_t = 0.0


## A blob on the ground under you (the guests' kind, a little softer: two shades).
func _make_shadow() -> void:
	var img := Image.create(24, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 24:
			var d := Vector2((x + 0.5 - 12.0) / 12.0, (y + 0.5 - 7.0) / 7.0).length()
			if d < 0.7:
				img.set_pixel(x, y, Color(0, 0, 0, 0.42))
			elif d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.22))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var q := QuadMesh.new()
	q.size = Vector2(0.62, 0.38)
	q.orientation = PlaneMesh.FACE_Y
	q.material = m
	_shadow = MeshInstance3D.new()
	_shadow.name = "BodyShadow"
	_shadow.mesh = q
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.position = Vector3(0.0, FLOOR_Y + 0.025, -0.04)
	# The player is still setting up its children when this is ready.
	player.add_child.call_deferred(_shadow)


func _process(delta: float) -> void:
	var show := _showing()
	if _shadow != null:
		# Lying down the blob is long, under all of you.
		var st := int(player.get("stance")) if player != null else 0
		_shadow.visible = show and _shadow.is_inside_tree() and player.is_on_floor()
		_shadow.scale = Vector3(1.0, 1.0, 2.4 if st == 2 else 1.0)
		_shadow.position.z = 0.55 if st == 2 else -0.04
	if not show:
		_feet.visible = false
		_hand_l.visible = false
		_hand_r.visible = false
		return
	_still_t += delta
	_crawl_t += delta
	_acc += delta
	if _acc < 1.0 / 12.0:
		return
	_acc = 0.0
	var vp := get_viewport().get_visible_rect().size
	var k := HANDS.px(vp.y)
	var hands := HANDS.of(self)
	var mat: Material = hands.material if hands != null else null
	var mo: Vector2 = hands.motion if hands != null else Vector2.ZERO
	var stance := int(player.get("stance"))
	if stance == 2:
		_feet.visible = false
		_crawl(vp, k, mat, mo)
		return
	_hand_l.visible = false
	_hand_r.visible = false
	_place_feet(vp, k, mat, mo)


func _showing() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if bool(player.get("seated")) or bool(player.get("_death_fall_active")):
		return false
	var cam := player.get("_camera") as Camera3D
	if cam == null or not cam.current:
		return false
	var main := get_tree().current_scene
	if main != null and main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open")):
		return false
	# A close-up over the view (as pockets.gd asks it).
	for n in get_tree().get_nodes_in_group("closeup"):
		if n is CanvasLayer and (n as CanvasLayer).visible:
			return false
	return true


func _place_feet(vp: Vector2, k: float, mat: Material, mo: Vector2) -> void:
	var cam := player.get("_camera") as Camera3D
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := player.global_position + Vector3(0.0, FLOOR_Y, 0.0) + fwd * FEET_AHEAD
	if cam.is_position_behind(at):
		_feet.visible = false
		return
	# Back from the camera's own (small) viewport to the window's pixels.
	var cvp := cam.get_viewport().get_visible_rect().size
	var p := cam.unproject_position(at) * (vp / cvp)
	if _still_t > 0.45:
		_foot = 0
	var mud := float(player.get("boots_mud"))
	var tex := _t("feet_mud") if mud > 0.45 and _t("feet_mud") != null else _t("feet_stand")
	if _foot != 0 and _t("feet_step") != null:
		tex = _t("feet_step")
	if tex == null:
		_feet.visible = false
		return
	var size := tex.get_size() * k
	var bar := 0.0
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("get_bar_height_px"):
		bar = float(hud.get_bar_height_px())
	# The toes at your feet's point; the legs always reach down out of the view.
	var y := maxf(p.y - size.y * 0.12, vp.y - bar - size.y)
	if y >= vp.y - bar - size.y * 0.08:
		_feet.visible = false
		return
	var x := p.x - size.x * 0.5
	_feet.texture = tex
	_feet.size = size
	_feet.flip_h = _foot == -1
	_feet.material = mat
	# Wet through (a puddle, the lake's edge, the snow): darker, a while.
	var wet := clampf(float(player.get("boots_wet")), 0.0, 1.0)
	# Down on the ground in the open the boots catch more light than the hands held in
	# the body's shade (hands.gd measures for those): a third more.
	_feet.modulate = Color(1.32, 1.32, 1.32).lerp(Color(0.95, 0.97, 1.03), wet)
	if mud > 0.2 and _t("feet_mud") == null:
		# No caked picture yet: the mud's brown over them, as much as there is.
		_feet.modulate = _feet.modulate.lerp(Color(1.05, 0.82, 0.58), clampf(mud, 0.0, 0.7))
	_feet.position = ((Vector2(x, y) + mo * k * 0.5) / k).floor() * k
	_feet.visible = true


## On your belly: the hands planted ahead in turn, the one just moved a little higher.
func _crawl(vp: Vector2, k: float, mat: Material, mo: Vector2) -> void:
	var plant := _t("crawl_plant")
	var reach := _t("crawl_reach")
	if plant == null or reach == null:
		return
	var bar := 0.0
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("get_bar_height_px"):
		bar = float(hud.get_bar_height_px())
	var moving := _crawl_t < 0.6
	for side in [-1, 1]:
		var r: TextureRect = _hand_l if side < 0 else _hand_r
		var lead: bool = (side < 0) == _crawl_left
		var tex: Texture2D = reach if lead and moving and _crawl_t < 0.25 else plant
		var size := tex.get_size() * k
		var up := size.y * (0.62 if lead and moving else 0.5)
		var x: float = vp.x * 0.5 + (vp.x * 0.16) * side - size.x * 0.5
		r.texture = tex
		r.size = size
		r.flip_h = side < 0
		r.material = mat
		r.modulate = Color.WHITE
		r.position = ((Vector2(x, vp.y - bar - up) + mo * k * 0.5) / k).floor() * k
		r.visible = true
