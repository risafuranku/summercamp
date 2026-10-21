extends Node3D

## The world answering your body (the brief of 21. 10.: "the trees and the world are
## static"), outdoors round you, for every warden (you and the other wardens' figures, so
## each machine draws its own without a word on the wire):
##   - the grass, the flowers, the ferns, nettles and blueberries part round their feet and
##     come back (ground_tuft.gdshader reads where the feet are: the shader globals
##     body_0..body_3), and rustle as you go through the tall ones;
##   - here and there a tree's low branch swishes across your view as you push past it
##     (one tree in six, always the same ones), with a few leaves off it;
##   - by day, out of the rain: leaves come down round you under the birches, a cone drops
##     off a spruce now and then, small birds and crows fly up out of a tree you walk up
##     to (a crow calls), a squirrel on a trunk runs up out of sight as you come, butterflies
##     over the meadow;
##   - a guest you walk into steps aside and turns to you (guest_agents.dodge: the god
##     cursor's hop, smaller), with a word when it was you;
##   - a puddle splashes under your boot (drops, a ring), the lake's edge too, where you can
##     wade in a step or two (camp_lake.gd), and the ducks on the shore make off when you run
##     at them;
##   - your wet boots leave dark prints on the boards and the paths a while, muddy ones
##     brown prints (player_controller.boots_wet / boots_mud).
## Everything here moves in steps, twelve a second, like the rest of the Build sprites;
## the camera never. Made by weather_visuals.gd in the camp's world; not while you are in a
## room.

const FPS := 12.0
const W := "res://assets/textury/world/"
const SFX_WORLD := "res://assets/sfx/world/"
## The globals the ground's shader reads (project.godot [shader_globals]).
const BODY_GLOBALS := ["body_0", "body_1", "body_2", "body_3"]
## The body's origin is this far under its feet (player_controller's capsule).
const FEET_Y := 0.35
## Forest floor plants you rustle through (scripts/ambient/forest_floor.gd), and how near.
const RUSTLY := ["fern", "nettles", "blueberry", "thistle", "leaf_pile"]
const RUSTLE_R := 0.75
const BRANCH_EVERY := 6
const BIRD_CHANCE := 0.35
const BIRD_NEAR := 5.5

var player_getter: Callable

var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _t := 0.0
var _tex: Dictionary = {}
var _snd: Array = []
var _snd_i := 0
## Trees (refreshed every few seconds): [node, pos, kind] and the plants at their feet.
var _trees: Array = []
var _plants: Array = []           # [pos, kind]
var _scan := 0.0
var _feet: Dictionary = {}        # warden id -> {at, rustle}
var _tree_cool: Dictionary = {}   # tree id -> seconds till it may do something again
var _sprites: Array = []          # flying/falling things: {node, v, life, kind, ...}
var _prints: Array = []
var _print_next := 0
var _branch_layer: CanvasLayer
var _branch: TextureRect
var _branch_t := -1.0
var _branch_side := 1.0
var _branch_cool := 0.0
var _leaf_t := 2.0
var _bfly: Array = []             # butterflies
var _squirrel: Dictionary = {}
var _ducks: Array = []
var _duck_wait := 0.0
var _lake: Node
var _player: CharacterBody3D


func _ready() -> void:
	name = "BodyWorld"
	_rng.randomize()
	for i in 4:
		var p := AudioStreamPlayer3D.new()
		p.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
		p.unit_size = 3.0
		p.max_distance = 30.0
		add_child(p)
		_snd.append(p)
	_branch_layer = CanvasLayer.new()
	_branch_layer.layer = 57
	add_child(_branch_layer)
	_branch = TextureRect.new()
	_branch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_branch.stretch_mode = TextureRect.STRETCH_SCALE
	_branch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_branch.visible = false
	_branch_layer.add_child(_branch)
	_player = player_getter.call() if player_getter.is_valid() else null
	if _player != null and _player.has_signal("foot_fell"):
		_player.foot_fell.connect(_on_foot)
	# Everything it may show or play, loaded now: a first load in the middle of a walk is
	# a hitch (a crow's call cost a 50 ms frame).
	for f in PRELOAD_TEX:
		_texture(f)
	for f in PRELOAD_SFX:
		_stream(f)


func _texture(file: String) -> Texture2D:
	if not _tex.has(file):
		_tex[file] = load(W + file) if ResourceLoader.exists(W + file) else null
	return _tex[file]


const PRELOAD_TEX := ["branch.png", "leaf_birch.png", "leaf_oak.png", "leaf_maple.png", "kick_cone.png",
	"sky_bird_up.png", "sky_bird_down.png", "sky_crow_up.png", "sky_crow_down.png", "rain_splash.png",
	"rain_ring.png", "boot_print.png", "body_bfly_white_open.png", "body_bfly_white_shut.png",
	"body_bfly_tort_open.png", "body_bfly_tort_shut.png", "body_squirrel_still.png",
	"body_squirrel_climb_a.png", "body_squirrel_climb_b.png", "body_duck_stand.png",
	"body_duck_walk.png", "body_duck_up.png", "body_duck_down.png"]
const PRELOAD_SFX := ["corn_rustle.mp3", "kick_cone.mp3", "res://assets/sfx/nature/crow.mp3",
	"res://assets/sfx/lake/stroke.mp3", "res://assets/sfx/nature/ducks_a.mp3"]
var _streams: Dictionary = {}


func _stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var path := file if file.begins_with("res://") else SFX_WORLD + file
		_streams[file] = load(path) if ResourceLoader.exists(path) else null
	return _streams[file]


func _sound(file: String, at: Vector3, db: float, pitch := 1.0, cut := 0.0) -> void:
	var st := _stream(file)
	if st == null:
		return
	var pl: AudioStreamPlayer3D = _snd[_snd_i]
	_snd_i = (_snd_i + 1) % _snd.size()
	pl.stream = st
	pl.global_position = at
	pl.volume_db = db
	pl.pitch_scale = pitch
	pl.play()
	if cut > 0.0:
		var p0 := pl
		var stream0 := pl.stream
		get_tree().create_timer(cut).timeout.connect(func() -> void:
			if is_instance_valid(p0) and p0.stream == stream0:
				p0.stop())


func _main() -> Node:
	return get_tree().current_scene


func _outdoors() -> bool:
	var m := _main()
	if m == null or bool(m.get("_menu_mode")):
		return false
	return not (m.has_method("_is_any_interior_open") and bool(m.call("_is_any_interior_open")))


func _hour() -> float:
	var m := _main()
	var h = m.get("_time_of_day_hours") if m != null else null
	return float(h) if h != null else 12.0


func _raining() -> bool:
	var m := _main()
	var ws = m.get("weather_system") if m != null else null
	return ws != null and ws.has_method("is_raining") and bool(ws.is_raining())


func _day_life() -> bool:
	var h := _hour()
	return h >= 7.0 and h < 19.0 and not _raining()


# ── every frame: where the feet are, for the grass ─────────────────────────────

func _process(delta: float) -> void:
	_set_body_globals()
	if not _outdoors():
		_branch.visible = false
		return
	_t += delta
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	if _player == null or not is_instance_valid(_player):
		_player = player_getter.call() if player_getter.is_valid() else null
		if _player != null and _player.has_signal("foot_fell") and not _player.foot_fell.is_connected(_on_foot):
			_player.foot_fell.connect(_on_foot)
	_scan -= dt
	if _scan <= 0.0:
		_scan = 4.0
		_scan_trees()
	for k in _tree_cool.keys():
		_tree_cool[k] = float(_tree_cool[k]) - dt
		if float(_tree_cool[k]) <= 0.0:
			_tree_cool.erase(k)
	var wardens := _wardens()
	for w in wardens:
		_rustle(w, dt)
		_near_trees(w, dt)
		_bump_guests(w)
	_step_branch(dt)
	_leaves(dt)
	_step_sprites(dt)
	_step_prints(dt)
	_step_butterflies(dt)
	_step_squirrel(dt)
	_step_ducks(dt)
	_mates_doors()


## Co-op: another warden went into a building or came out of it (their state's room): its
## door swings open here too (the brief of 21. 10.: "the other sees the door open").
var _mate_rooms: Dictionary = {}


func _mates_doors() -> void:
	if Coop.wardens.is_empty():
		return
	for id in Coop.others():
		var st: Dictionary = Coop.state_of(id)
		var room = st.get("room", {})
		var key := str((room as Dictionary).get("k", "")) if room is Dictionary else ""
		var was := str(_mate_rooms.get(id, ""))
		if key == was:
			continue
		_mate_rooms[id] = key
		var k := key if key != "" else was
		if not ":" in k:
			continue
		var DOOR = load("res://scripts/attractions/door_anim.gd")
		var s: Node3D = DOOR.structure_at(Vector2i(int(k.get_slice(":", 0)), int(k.get_slice(":", 1))))
		if s != null:
			DOOR.open(DOOR.find_door(s), 2.6)


## Every warden's feet into the ground's shader: x, z, the ground's height, how hard
## (lying down you flatten more round you). Unused slots 0.
func _set_body_globals() -> void:
	var i := 0
	if _outdoors():
		for n in _warden_nodes():
			if i >= BODY_GLOBALS.size():
				break
			var p := (n as Node3D).global_position
			var feet := p.y + (FEET_Y if n == _player else 0.0)
			var k := 1.0
			if n == _player and int(_player.get("stance")) == 2:
				k = 1.6
			RenderingServer.global_shader_parameter_set(BODY_GLOBALS[i], Vector4(p.x, p.z, feet, k))
			i += 1
	while i < BODY_GLOBALS.size():
		RenderingServer.global_shader_parameter_set(BODY_GLOBALS[i], Vector4(0, 0, -999.0, 0.0))
		i += 1


func _warden_nodes() -> Array:
	var out: Array = []
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree():
		out.append(_player)
	for r in get_tree().get_nodes_in_group("coop_remote_player"):
		if r is Node3D and (r as Node3D).is_visible_in_tree():
			out.append(r)
	return out


## [node, feet position, speed (m/s), is it you]
func _wardens() -> Array:
	var out: Array = []
	for n in _warden_nodes():
		var id := (n as Node).get_instance_id()
		var p := (n as Node3D).global_position
		if n == _player:
			p.y += FEET_Y
		var last: Dictionary = _feet.get(id, {"at": p, "rustle": 0.0})
		var v := Vector2(p.x - (last["at"] as Vector3).x, p.z - (last["at"] as Vector3).z).length() * FPS
		if v > 12.0:
			v = 0.0
		last["at"] = p
		_feet[id] = last
		out.append([n, p, v, n == _player])
	return out


# ── trees and what grows under them ───────────────────────────────────────────

func _scan_trees() -> void:
	_trees.clear()
	_plants.clear()
	var me: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	for t in get_tree().get_nodes_in_group("trees"):
		if not (t is Node3D) or (t as Node).is_in_group("corn"):
			continue
		var tp := (t as Node3D).global_position
		if Vector2(tp.x - me.x, tp.z - me.z).length() > 60.0:
			continue
		var kind := int(t.get_meta("tree_kind", 0))
		_trees.append([t, tp, kind])
		for c in (t as Node).get_children():
			var nm := str(c.name)
			if nm.begins_with("Floor_") and c is Node3D:
				var k := nm.substr(6)
				if k in RUSTLY:
					_plants.append([(c as Node3D).global_position, k])


## Through ferns or nettles: a rustle (the corn's, quieter and higher), now and then.
func _rustle(w: Array, dt: float) -> void:
	var at: Vector3 = w[1]
	var speed: float = w[2]
	var id := (w[0] as Node).get_instance_id()
	var f: Dictionary = _feet[id]
	f["rustle"] = maxf(0.0, float(f["rustle"]) - dt)
	if speed < 0.5 or float(f["rustle"]) > 0.0:
		return
	for pl in _plants:
		var pp: Vector3 = pl[0]
		if Vector2(pp.x - at.x, pp.z - at.z).length() < RUSTLE_R and absf(pp.y - at.y) < 1.0:
			_sound("corn_rustle.mp3", pp, -15.0 + minf(speed, 4.0) * 1.2, _rng.randf_range(1.12, 1.3), 0.55)
			f["rustle"] = _rng.randf_range(0.45, 0.8)
			if str(pl[1]) == "fern" and _rng.randf() < 0.15 and _day_life():
				_butterfly_up(pp)
			return


## Near a tree: one in six swishes a low branch across your view as you push past it;
## by day birds may go up out of it as you come.
func _near_trees(w: Array, _dt: float) -> void:
	var at: Vector3 = w[1]
	var speed: float = w[2]
	var mine: bool = w[3]
	for tr in _trees:
		var t0 = tr[0]
		if not is_instance_valid(t0):
			continue
		var t := t0 as Node3D
		var tp: Vector3 = tr[1]
		var d := Vector2(tp.x - at.x, tp.z - at.z).length()
		if d > BIRD_NEAR:
			continue
		var id := t.get_instance_id()
		if _tree_cool.has(id):
			continue
		var h := absi(hash("%d|%d" % [roundi(tp.x * 10.0), roundi(tp.z * 10.0)]))
		if mine and d < 1.35 and speed > 1.6 and h % BRANCH_EVERY == 0 and int(tr[2]) != 2 and _branch_cool <= 0.0:
			var side := (_player.global_basis.inverse() * (tp - at)).x
			_whip(1.0 if side > 0.0 else -1.0, int(tr[2]))
			_tree_cool[id] = 20.0
			continue
		if speed > 1.2 and d < BIRD_NEAR and _day_life() and (h / 7) % 100 < int(BIRD_CHANCE * 100.0):
			_birds_up(t, tp, int(tr[2]))
			_tree_cool[id] = 90.0


## What they say when you walk into them (one format each: the Czech is in cs.po).
const BUMP_LINES := ["%s: \"Hey! Watch it.\"", "%s: \"Easy there.\"", "%s: \"Sorry, sorry.\"", "%s: \"Do you mind?\""]
var _bumped: Dictionary = {}      # party key -> msec it may be bumped again


## A guest in your way: walked into at a walk or faster, they hop aside and look at you;
## yours get a word on the status line. Every machine does it for every warden's figure.
func _bump_guests(w: Array) -> void:
	var speed: float = w[2]
	if speed < 1.2:
		return
	var m := _main()
	var ga = m.get("_guest_agents") if m != null else null
	if ga == null:
		return
	var parties = ga.get("_parties")
	if not (parties is Dictionary):
		return
	var at: Vector3 = w[1]
	var now := Time.get_ticks_msec()
	for key in (parties as Dictionary).keys():
		var pd: Dictionary = parties[key]
		var p: Vector3 = pd.get("last_pos", Vector3.INF)
		if p == Vector3.INF or Vector2(p.x - at.x, p.z - at.z).length() > 0.8 or absf(p.y - at.y) > 1.5:
			continue
		var members: Array = pd.get("members", [])
		if members.is_empty() or not is_instance_valid(members[0]) or not (members[0] as Node3D).visible:
			continue
		if int(_bumped.get(key, 0)) > now:
			continue
		_bumped[key] = now + 5000
		ga.dodge(at, 0.9, 1.2)
		if bool(w[3]):
			var hud = m.get("_hud_manager")
			var who := str((pd.get("info", {}) as Dictionary).get("name", "Guest"))
			if hud != null and hud.has_method("push_status"):
				hud.push_status(tr(BUMP_LINES[_rng.randi() % BUMP_LINES.size()]) % who, 0)


# ── the branch across your eyes ───────────────────────────────────────────────

func _whip(side: float, kind: int) -> void:
	var tex := _texture("branch.png")
	if tex == null:
		return
	_branch.texture = tex
	_branch_t = 0.0
	_branch_side = side
	_branch_cool = 6.0
	_sound("corn_rustle.mp3", _player.global_position + Vector3(0, 1.4, 0), -9.0, 1.25, 0.4)
	if kind == 1 and _day_life():
		for i in 3:
			_leaf_at(_player.global_position + Vector3(_rng.randf_range(-0.6, 0.6), 2.0, _rng.randf_range(-0.6, 0.6)) - _player.global_basis.z * 0.8)


## Across the view from the tree's side and gone, in steps, a little bigger than a hand
## (it is right at your eyes), on the hands' pixel grid and light.
func _step_branch(dt: float) -> void:
	_branch_cool = maxf(0.0, _branch_cool - dt)
	if _branch_t < 0.0:
		_branch.visible = false
		return
	_branch_t += dt
	var dur := 0.42
	if _branch_t > dur:
		_branch_t = -1.0
		_branch.visible = false
		return
	var vp := _branch_layer.get_viewport().get_visible_rect().size
	var hands = load("res://scripts/ui/hands.gd")
	var k: float = hands.px(vp.y)
	var tex := _branch.texture
	# Twice a hand's pixel: it is right at your eyes, wider than the view.
	var size := tex.get_size() * k * 2.0
	var f := _branch_t / dur
	# From the tree's edge of the view across and out of the other, a dip in the middle.
	var x0 := vp.x * 0.5 + _branch_side * (vp.x * 0.5 + size.x * 0.2)
	var x1 := vp.x * 0.5 - _branch_side * (vp.x * 0.5 + size.x * 1.1)
	var x := lerpf(x0, x1, f) - size.x * 0.5
	var y := vp.y * 0.12 + sin(f * PI) * vp.y * 0.18
	_branch.size = size
	_branch.flip_h = _branch_side < 0.0
	_branch.position = (Vector2(x, y) / k).floor() * k
	var h := hands.of(self) as Node
	_branch.material = h.get("material") if h != null else null
	_branch.visible = true


# ── leaves, cones, birds ───────────────────────────────────────────────────────

## Under the birches by day a leaf comes down near you now and then (more in autumn).
func _leaves(dt: float) -> void:
	_leaf_t -= dt
	if _leaf_t > 0.0 or _player == null or not _day_life():
		return
	_leaf_t = _rng.randf_range(1.2, 3.0)
	var me := _player.global_position
	var near: Array = []
	for tr in _trees:
		var tp: Vector3 = tr[1]
		if Vector2(tp.x - me.x, tp.z - me.z).length() < 9.0:
			near.append(tr)
	if near.is_empty():
		return
	var tr: Array = near[_rng.randi() % near.size()]
	var tp: Vector3 = tr[1]
	if int(tr[2]) == 1:
		_leaf_at(tp + Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(3.0, 4.5), _rng.randf_range(-1.6, 1.6)))
	elif int(tr[2]) == 0 and _rng.randf() < 0.12:
		_cone_at(tp + Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(3.0, 5.0), _rng.randf_range(-1.0, 1.0)))


func _sprite(tex: Texture2D, px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	return s


func _leaf_at(at: Vector3) -> void:
	var names := ["leaf_birch.png", "leaf_oak.png", "leaf_maple.png"]
	var tex := _texture(names[0] if _rng.randf() < 0.7 else names[_rng.randi() % names.size()])
	if tex == null or _sprites.size() > 40:
		return
	var s := _sprite(tex, 0.016)
	s.global_position = at
	# The season's colour (wind_life.gd's leaves): still green it reads as nothing falling.
	var tint := Season.leaf_tint(_season_day(), _hour())
	if tint.r + tint.g + tint.b < 0.6 or tint.g > tint.r * 1.1:
		tint = Color(0.78, 0.48, 0.18)
	s.modulate = tint
	_sprites.append({"node": s, "v": Vector3(_rng.randf_range(-0.3, 0.3), -0.55, _rng.randf_range(-0.3, 0.3)), "life": 9.0, "kind": "leaf", "ph": _rng.randf() * TAU})


func _season_day() -> int:
	var m := _main()
	var d = m.get("_day_index") if m != null else null
	return int(d) if d != null else 1


func _cone_at(at: Vector3) -> void:
	var tex := _texture("kick_cone.png")
	if tex == null:
		return
	var s := _sprite(tex, 0.01)
	s.global_position = at
	_sprites.append({"node": s, "v": Vector3(0, -0.5, 0), "life": 4.0, "kind": "cone", "ph": 0.0})


## Birds out of the crown: two or three small ones, or a crow that calls, up and away
## from you, their wings beating in two frames.
func _birds_up(t: Node3D, tp: Vector3, kind: int) -> void:
	if kind == 2:
		return
	var crow := _rng.randf() < 0.3
	var up := _texture("sky_crow_up.png" if crow else "sky_bird_up.png")
	var dn := _texture("sky_crow_down.png" if crow else "sky_bird_down.png")
	if up == null or dn == null:
		return
	var away := tp - _player.global_position if _player != null else Vector3.FORWARD
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var n := 1 if crow else _rng.randi_range(2, 3)
	for i in n:
		var s := _sprite(up, 0.03 if crow else 0.016)
		var top := 3.6 + float(t.scale.y) * 1.4
		s.global_position = tp + Vector3(_rng.randf_range(-0.8, 0.8), top + _rng.randf_range(-0.6, 0.4), _rng.randf_range(-0.8, 0.8))
		var dir := (away.rotated(Vector3.UP, _rng.randf_range(-0.7, 0.7)) * _rng.randf_range(4.0, 6.0) + Vector3.UP * _rng.randf_range(2.0, 3.2))
		_sprites.append({"node": s, "v": dir, "life": 5.0, "kind": "bird", "up": up, "dn": dn, "ph": float(i)})
	_sound("corn_rustle.mp3", tp + Vector3(0, 4.0, 0), -13.0, 1.4, 0.35)
	if crow:
		_sound("res://assets/sfx/nature/crow.mp3", tp + Vector3(0, 4.0, 0), -8.0, _rng.randf_range(0.95, 1.05))


func _step_sprites(dt: float) -> void:
	var keep: Array = []
	for sp in _sprites:
		var n0 = sp["node"]
		if not is_instance_valid(n0):
			continue
		var n := n0 as Sprite3D
		if not is_instance_valid(n):
			continue
		sp["life"] = float(sp["life"]) - dt
		var v: Vector3 = sp["v"]
		match str(sp["kind"]):
			"leaf":
				sp["ph"] = float(sp["ph"]) + dt * 3.0
				var sway := Vector3(cos(float(sp["ph"])), 0.0, sin(float(sp["ph"]) * 0.7)) * 0.5
				if n.global_position.y > _ground_at(n.global_position) + 0.02:
					n.global_position += (v + sway) * dt
					n.flip_h = sin(float(sp["ph"]) * 1.3) > 0.0
				else:
					sp["life"] = minf(float(sp["life"]), 2.0)
			"cone":
				v.y -= 9.8 * dt
				n.global_position += v * dt
				var g := _ground_at(n.global_position)
				if n.global_position.y <= g + 0.05:
					n.global_position.y = g + 0.05
					if v.y < -1.0:
						_sound("kick_cone.mp3", n.global_position, -10.0, _rng.randf_range(0.9, 1.1))
					v = Vector3.ZERO
				sp["v"] = v
			"bird":
				n.global_position += v * dt
				sp["ph"] = float(sp["ph"]) + 1.0
				n.texture = sp["up"] if int(sp["ph"]) % 2 == 0 else sp["dn"]
			"splash":
				n.global_position += v * dt
				v.y -= 9.8 * dt
				sp["v"] = v
			"ring":
				var a := clampf(float(sp["life"]) / 0.8, 0.0, 1.0)
				n.scale = Vector3.ONE * (1.0 + (1.0 - a) * 1.6)
				n.modulate.a = 0.34 if a < 0.4 else (0.67 if a < 0.75 else 1.0)
		if float(sp["life"]) > 0.0:
			keep.append(sp)
		else:
			n.queue_free()
	_sprites = keep


func _ground_at(p: Vector3) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 6.0)
	q.collision_mask = 1
	if _player != null:
		q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else 0.0


# ── water and mud under your boots ────────────────────────────────────────────

func _on_foot(left: bool) -> void:
	if _player == null or not _outdoors():
		return
	var surf := str(_player.get("last_step_surface"))
	var at := _player.global_position + Vector3(0.0, FEET_Y, 0.0)
	var side := _player.global_basis.x * (-0.12 if left else 0.12)
	if _in_lake(at):
		_player.set("boots_wet", 1.0)
		_splash(at + side, 1.0)
		_sound("res://assets/sfx/lake/stroke.mp3", at, -14.0, _rng.randf_range(1.15, 1.35), 0.5)
	elif surf == "puddle":
		_splash(at + side, 0.7)
	var wet := float(_player.get("boots_wet"))
	var mud := float(_player.get("boots_mud"))
	if surf in ["wood", "gravel"] and wet > 0.25:
		_print(at + side, Color(0.32, 0.3, 0.3), wet)
	elif surf in ["grass", "gravel", "wood"] and mud > 0.3:
		_print(at + side, Color(0.36, 0.25, 0.14), mud)


## Drops up and a ring spreading on the water (Grok rain_splash, rain_ring).
func _splash(at: Vector3, k: float) -> void:
	var drop := _texture("rain_splash.png")
	var ring := _texture("rain_ring.png")
	if drop != null:
		for i in 3:
			var s := _sprite(drop, 0.006)
			s.global_position = at + Vector3(_rng.randf_range(-0.1, 0.1), 0.05, _rng.randf_range(-0.1, 0.1))
			_sprites.append({"node": s, "v": Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(1.2, 2.0) * k, _rng.randf_range(-0.6, 0.6)), "life": 0.32, "kind": "splash", "ph": 0.0})
	if ring != null:
		var r := Sprite3D.new()
		r.texture = ring
		r.hframes = maxi(1, int(ring.get_width() / maxf(1.0, ring.get_height())))
		r.pixel_size = 0.022
		r.rotation.x = -PI * 0.5
		r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(r)
		r.global_position = Vector3(at.x, at.y + 0.07, at.z)
		_sprites.append({"node": r, "v": Vector3.ZERO, "life": 0.8, "kind": "ring", "ph": 0.0})


func _in_lake(p: Vector3) -> bool:
	if _lake == null or not is_instance_valid(_lake):
		var m := _main()
		_lake = m.find_child("CampLake", true, false) if m != null else null
	return _lake != null and _lake.has_method("in_water") and bool(_lake.in_water(p))


## A print of your boot on the boards or the path, wet (dark) or muddy (brown); goes in
## three steps of see-through, like the snow's.
func _print(at: Vector3, col: Color, strength: float) -> void:
	var tex := _texture("boot_print.png")
	if tex == null:
		return
	if _prints.size() < 24:
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 0.01
		s.rotation.x = -PI * 0.5
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		_prints.append({"node": s, "age": 0.0, "life": 1.0})
	var pr: Dictionary = _prints[_print_next % _prints.size()]
	_print_next += 1
	var s2: Sprite3D = pr["node"]
	s2.global_position = Vector3(at.x, at.y + 0.015, at.z)
	s2.rotation = Vector3(-PI * 0.5, _player.rotation.y, 0.0)
	s2.modulate = Color(col.r, col.g, col.b, 1.0)
	pr["age"] = 0.0
	pr["life"] = lerpf(15.0, 45.0, clampf(strength, 0.0, 1.0))
	s2.visible = true


func _step_prints(dt: float) -> void:
	for pr in _prints:
		var s: Sprite3D = pr["node"]
		if not s.visible:
			continue
		pr["age"] = float(pr["age"]) + dt
		var f := float(pr["age"]) / float(pr["life"])
		if f >= 1.0:
			s.visible = false
		else:
			s.modulate.a = 1.0 if f < 0.5 else (0.66 if f < 0.8 else 0.33)
			s.transparency = 0.0 if f < 0.5 else (0.34 if f < 0.8 else 0.67)


# ── butterflies, the squirrel, the ducks (Grok, world/body_*) ────────────────────

## By day over the meadow, warm and dry, until the autumn's last third: a few round you.
func _step_butterflies(dt: float) -> void:
	var a := _texture("body_bfly_white_open.png")
	if a == null or _player == null:
		return
	var h := _hour()
	var want := 3 if h >= 10.0 and h < 17.0 and not _raining() and _season_day() < 20 else 0
	var me := _player.global_position
	while _bfly.size() < want:
		_butterfly_up(me + Vector3(_rng.randf_range(-8, 8), 0.0, _rng.randf_range(-8, 8)))
	for b in _bfly.duplicate():
		var n0 = b["node"]
		if not is_instance_valid(n0):
			_bfly.erase(b)
			continue
		var n := n0 as Sprite3D
		if not is_instance_valid(n) or n.global_position.distance_to(me) > 18.0 or want == 0 and _rng.randf() < 0.05:
			if is_instance_valid(n):
				n.queue_free()
			_bfly.erase(b)
			continue
		b["ph"] = float(b["ph"]) + 1.0
		var flit := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.7), _rng.randf_range(-1, 1)) * 0.9
		var v: Vector3 = (b["v"] as Vector3).lerp(flit, 0.35)
		var g := _ground_at(n.global_position)
		if n.global_position.y < g + 0.3:
			v.y = absf(v.y) + 0.3
		elif n.global_position.y > g + 1.8:
			v.y = -absf(v.y)
		b["v"] = v
		n.global_position += v * dt
		n.texture = b["open"] if int(b["ph"]) % 3 != 0 else b["shut"]


func _butterfly_up(at: Vector3) -> void:
	var white := _rng.randf() < 0.6
	var open := _texture("body_bfly_white_open.png" if white else "body_bfly_tort_open.png")
	var shut := _texture("body_bfly_white_shut.png" if white else "body_bfly_tort_shut.png")
	if open == null or shut == null or _bfly.size() > 6:
		return
	var s := _sprite(open, 0.006)
	s.global_position = Vector3(at.x, _ground_at(at) + _rng.randf_range(0.4, 1.2), at.z)
	_bfly.append({"node": s, "v": Vector3.ZERO, "ph": _rng.randf() * 3.0, "open": open, "shut": shut})


## In the wood by day one squirrel on a trunk near you; come within five metres and it
## runs up out of sight.
func _step_squirrel(dt: float) -> void:
	var still := _texture("body_squirrel_still.png")
	if still == null or _player == null:
		return
	var me := _player.global_position
	if _squirrel.is_empty():
		if not _day_life() or _rng.randf() > dt * 0.05:
			return
		var best: Array = []
		for tr in _trees:
			var d := Vector2((tr[1] as Vector3).x - me.x, (tr[1] as Vector3).z - me.z).length()
			if d > 9.0 and d < 16.0 and int(tr[2]) != 2:
				best = tr
				break
		if best.is_empty():
			return
		var tp: Vector3 = best[1]
		var to_me := me - tp
		to_me.y = 0.0
		var s := _sprite(still, 0.006)
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.global_position = tp + to_me.normalized() * 0.2 + Vector3(0, _rng.randf_range(1.2, 2.2), 0)
		_squirrel = {"node": s, "run": false, "ph": 0.0, "top": tp.y + 4.0, "life": 40.0}
		return
	var n0 = _squirrel["node"]
	if not is_instance_valid(n0):
		_squirrel = {}
		return
	var n := n0 as Sprite3D
	_squirrel["life"] = float(_squirrel["life"]) - dt
	if not is_instance_valid(n) or float(_squirrel["life"]) <= 0.0:
		if is_instance_valid(n):
			n.queue_free()
		_squirrel = {}
		return
	if not bool(_squirrel["run"]) and n.global_position.distance_to(me + Vector3(0, 1.2, 0)) < 5.0:
		_squirrel["run"] = true
		_sound("corn_rustle.mp3", n.global_position, -16.0, 1.6, 0.3)
	if bool(_squirrel["run"]):
		_squirrel["ph"] = float(_squirrel["ph"]) + 1.0
		var a := _texture("body_squirrel_climb_a.png")
		var b := _texture("body_squirrel_climb_b.png")
		if a != null and b != null:
			n.texture = a if int(_squirrel["ph"]) % 2 == 0 else b
		n.global_position.y += 2.2 * dt
		if n.global_position.y > float(_squirrel["top"]):
			n.queue_free()
			_squirrel = {}


## Two or three ducks on the camp's shore by day, out of the rain; run at them and they
## waddle off, then take to the air over the water.
func _step_ducks(dt: float) -> void:
	var stand := _texture("body_duck_stand.png")
	if stand == null or _player == null:
		return
	if _ducks.is_empty():
		_duck_wait -= dt
		if _duck_wait > 0.0 or not _day_life():
			return
		_in_lake(Vector3.ZERO)
		if _lake == null or not _lake.has_method("duck_spots"):
			return
		var spots: Array = _lake.duck_spots()
		for sp in spots:
			var s := _sprite(stand, 0.007)
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.offset = Vector2(0.0, stand.get_height() * 0.5)
			s.global_position = sp
			_ducks.append({"node": s, "state": "sit", "v": Vector3.ZERO, "ph": _rng.randf() * 4.0, "home": sp})
		return
	var me := _player.global_position
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	for d in _ducks:
		var n0 = d["node"]
		if not is_instance_valid(n0):
			continue
		var n := n0 as Sprite3D
		if not is_instance_valid(n):
			continue
		d["ph"] = float(d["ph"]) + 1.0
		var to := n.global_position - me
		to.y = 0.0
		match str(d["state"]):
			"sit":
				if to.length() < (6.0 if speed > 4.0 else 2.5) and speed > 1.0:
					d["state"] = "waddle"
					d["v"] = to.normalized() * 1.4
					_sound("res://assets/sfx/nature/ducks_a.mp3", n.global_position, -6.0, _rng.randf_range(1.0, 1.15), 1.2)
				elif int(d["ph"]) % 40 == 0:
					n.flip_h = not n.flip_h
			"waddle":
				n.global_position += (d["v"] as Vector3) * dt
				var w := _texture("body_duck_walk.png")
				n.texture = w if int(d["ph"]) % 2 == 0 and w != null else stand
				n.flip_h = (d["v"] as Vector3).dot(_player.global_basis.x) < 0.0
				if to.length() > 9.0 or float(d["ph"]) > 40.0 and to.length() < 4.0:
					d["state"] = "fly"
					d["v"] = Vector3((d["v"] as Vector3).x, 0.0, (d["v"] as Vector3).z).normalized() * 6.0 + Vector3.UP * 2.4
					d["ph"] = 0.0
			"fly":
				n.global_position += (d["v"] as Vector3) * dt
				var up := _texture("body_duck_up.png")
				var dn := _texture("body_duck_down.png")
				if up != null and dn != null:
					n.texture = up if int(d["ph"]) % 2 == 0 else dn
				if float(d["ph"]) > 70.0:
					n.visible = false
	# All flown: back on the shore after a while out of sight.
	var gone := true
	for d in _ducks:
		if is_instance_valid(d["node"]) and (d["node"] as Node3D).visible:
			gone = false
	if gone or not _day_life():
		for d in _ducks:
			if is_instance_valid(d["node"]):
				(d["node"] as Node).queue_free()
		_ducks.clear()
		_duck_wait = 240.0
