extends Node

## The cigarette and the bottle out in the world (pockets.gd owns this): the smoke you
## breathe out hanging in front of you, the butt flicked off glowing where it lands, the
## cap off a bottle, a bottle set down or thrown (it smashes on the hard ground, thuds
## in the grass), the sick. All of it sprites (assets/textury/habits/), in the camp's
## world outdoors or in the open room's own world indoors.
##
## Co-op: the other warden's figure (remote_player.gd) gets the same on it: the ember
## at their mouth (a speck of light at night, brighter on a drag), the flame of their
## lighter, the smoke they breathe out, their lighter, cap, gulps and burps heard from
## where they stand, their butts and bottles landing where they threw them. Standing by
## them, your lighter or your lit cigarette lights theirs (and theirs yours); two open
## bottles held up close clink.

const ART := "res://assets/textury/habits/"
const SFX := "res://assets/sfx/habits/"
const PIXEL_M := 0.0045
const GRAVITY := 9.0
## A thrown thing's flight: [node, velocity, kind, extra] until it lands.
var _flying: Array = []
## Puffs of smoke in a world: {node, vel, life, max}.
var _puffs: Array = []
## Butts glowing where they landed: {node, light, t}.
var _embers: Array = []
## Bottles standing where they were set down: id -> {node, level, opened}.
var _bottles: Dictionary = {}
var _litter: Array = []
var _tex: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _partner_fx: Node3D
var _partner_ember: MeshInstance3D
var _ember_mat: StandardMaterial3D
var _ember_bright_mat: StandardMaterial3D
var _partner_light: OmniLight3D
var _partner_flame: Sprite3D
var _partner_audio: AudioStreamPlayer3D
var _clink_cd := 0.0
var _light_cd := 0.0
var _t := 0.0

## pockets.gd
var pockets


func _ready() -> void:
	_rng.randomize()


## Pictures standing in for others: the glowing butt is the last stub of a lit one.
const SAME := {"butt_lit": "cig_end"}


func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(ART + n + ".png") if ResourceLoader.exists(ART + n + ".png") else null
		if _tex[n] == null and SAME.has(n):
			_tex[n] = tex(str(SAME[n]))
	return _tex[n]


# ── where ────────────────────────────────────────────────────────────────────

## The camera you see through now and the node of its world to put things in.
func _view() -> Dictionary:
	var main := get_tree().current_scene
	if main == null:
		return {}
	if pockets != null and pockets._indoors():
		for layer in _open_rooms(main):
			var vp: SubViewport = layer.get("_viewport") as SubViewport
			var cam: Camera3D = vp.get_camera_3d() if vp != null else (layer.get("_cam") as Camera3D)
			if cam != null and cam.is_inside_tree():
				return {"cam": cam, "root": cam.get_parent(), "indoors": true}
		return {}
	var p = main.get("_player")
	var cam2: Camera3D = p.get("_camera") as Camera3D if p != null else null
	var root = main.get("_world_3d")
	if cam2 == null or root == null:
		return {}
	return {"cam": cam2, "root": root, "indoors": false}


func _open_rooms(main: Node) -> Array:
	var out: Array = []
	var im = main.get("_interior_manager")
	if im != null and im.has_method("_get_registered_interior_nodes"):
		for r in im._get_registered_interior_nodes():
			if r is CanvasLayer and (r as CanvasLayer).visible and r.get("_viewport") != null:
				out.append(r)
	var trip = im.get("_town_trip") if im != null else null
	var room = trip.get("_room") if trip != null else null
	if room != null and room.has_method("is_open") and room.is_open():
		out.append(room)
	return out


func _sprite(n: String, billboard := true) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex(n)
	s.pixel_size = PIXEL_M
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	return s


func _sound(at: Node3D, file: String, db := -4.0, far := 22.0) -> void:
	if at == null or not ResourceLoader.exists(SFX + file):
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = load(SFX + file)
	a.volume_db = db
	a.unit_size = 2.5
	a.max_distance = far
	a.pitch_scale = _rng.randf_range(0.94, 1.06)
	at.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


# ── your own ─────────────────────────────────────────────────────────────────

## Smoke in front of your face, left to drift (and seen by anyone looking at you).
func exhale(drag: float) -> void:
	var v := _view()
	if v.is_empty():
		return
	var cam: Camera3D = v["cam"]
	var fwd := -cam.global_basis.z
	_puff_at(v["root"], cam.global_position + fwd * 1.1 + Vector3.DOWN * 0.1, fwd * 0.3, drag, bool(v["indoors"]))


func _puff_at(root: Node, at: Vector3, push: Vector3, drag: float, indoors: bool) -> void:
	var wind := Vector3.ZERO
	if not indoors and pockets != null:
		var w := float(pockets._env().get("wind", 0.0))
		wind = Vector3(0.7, 0.0, 0.3).normalized() * w * 1.6
	var n := clampi(int(1.0 + drag * 1.2), 1, 4)
	for k in n:
		var s := _sprite("smoke_1")
		# Lit by the place (grey in the dark, not glowing) and thin.
		s.shaded = true
		s.pixel_size = PIXEL_M * 0.6
		s.modulate = Color(1, 1, 1, 0.45)
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s.transparent = true
		root.add_child(s)
		s.global_position = at + Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.04, 0.06), _rng.randf_range(-0.08, 0.08)) + push * float(k) * 0.12
		_puffs.append({"node": s, "vel": push + wind + Vector3(0, 0.18 if not indoors else 0.08, 0), "life": -float(k) * 0.12,
			"max": (7.0 if indoors else 3.2) * _rng.randf_range(0.8, 1.2), "grow": 0.0})


func throw_butt(lit: bool, _length: float) -> void:
	var v := _view()
	if v.is_empty():
		return
	var cam: Camera3D = v["cam"]
	if bool(v["indoors"]):
		# Stubbed out on the floor in front of you.
		var hit := _floor_ahead(cam, 1.0)
		if not hit.is_empty():
			var b := _sprite("butt", false)
			v["root"].add_child(b)
			b.global_position = hit["position"] + Vector3.UP * 0.01
			b.rotation.x = -PI * 0.5
			b.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			_keep_litter(b)
		return
	var fwd := -cam.global_basis.z
	var s := _sprite("butt_lit" if lit else "butt")
	v["root"].add_child(s)
	var from := cam.global_position + fwd * 0.4 + Vector3.DOWN * 0.2 + cam.global_basis.x * -0.15
	s.global_position = from
	var vel := fwd * 6.5 + Vector3.UP * 2.4
	_flying.append([s, vel, "butt", lit])
	send("butt", [from, vel, lit])


func cap_off() -> void:
	var v := _view()
	if v.is_empty():
		return
	var cam: Camera3D = v["cam"]
	var s := _sprite("cap_spin")
	v["root"].add_child(s)
	var from := cam.global_position - cam.global_basis.z * 0.45 + cam.global_basis.x * 0.12 + Vector3.DOWN * 0.15
	s.global_position = from
	var vel := -cam.global_basis.z * 1.2 + Vector3.UP * 2.0 + cam.global_basis.x * _rng.randf_range(-0.8, 0.8)
	_flying.append([s, vel, "cap", false])


func throw_bottle(level: float) -> void:
	var v := _view()
	if v.is_empty():
		return
	var cam: Camera3D = v["cam"]
	if bool(v["indoors"]):
		set_bottle_down(level)
		return
	var fwd := -cam.global_basis.z
	var s := _sprite("bottle_side")
	v["root"].add_child(s)
	var from := cam.global_position + fwd * 0.4 + cam.global_basis.x * 0.2
	s.global_position = from
	var vel := fwd * 9.0 + Vector3.UP * 3.2
	_flying.append([s, vel, "bottle", level])
	send("bottle", [from, vel])


## Set down at your feet: shut (2.0) back in the bag if there is room, else on the
## ground; open, standing on the ground (E picks it up again).
func set_bottle_down(level: float) -> void:
	if level > 1.5 and pockets != null and pockets.bag != null and pockets.bag.has_method("add_item") and pockets.bag.add_item("beer"):
		return
	var v := _view()
	if v.is_empty():
		return
	var hit := _floor_ahead(v["cam"], 0.8)
	if hit.is_empty():
		return
	var s := _sprite("bottle_stand", false)
	v["root"].add_child(s)
	var h := float(s.texture.get_height()) if s.texture != null else 40.0
	s.global_position = hit["position"] + Vector3.UP * (h * PIXEL_M * 0.5)
	var id := "%d" % Time.get_ticks_msec()
	_bottles[id] = {"node": s, "level": minf(level, 1.0), "opened": level <= 1.0}


func vomit() -> void:
	var v := _view()
	if v.is_empty():
		return
	var hit := _floor_ahead(v["cam"], 0.7)
	if hit.is_empty():
		return
	var s := Sprite3D.new()
	s.texture = load("res://assets/textury/mess/dirt_vomit.png") if ResourceLoader.exists("res://assets/textury/mess/dirt_vomit.png") else null
	s.pixel_size = 0.006
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.rotation.x = -PI * 0.5
	v["root"].add_child(s)
	s.global_position = hit["position"] + Vector3.UP * 0.012
	_keep_litter(s)


## The floor a step or so in front of the camera.
func _floor_ahead(cam: Camera3D, dist: float) -> Dictionary:
	var space := cam.get_world_3d().direct_space_state
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at := cam.global_position + fwd * dist
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 4.0)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {"position": Vector3(at.x, cam.global_position.y - 1.6, at.z)}
	return hit


func _keep_litter(n: Node3D) -> void:
	_litter.append(n)
	while _litter.size() > 40:
		var o = _litter.pop_front()
		if o != null and is_instance_valid(o):
			o.queue_free()


# ── the frame ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	_clink_cd = maxf(0.0, _clink_cd - delta)
	_light_cd = maxf(0.0, _light_cd - delta)
	_fly(delta)
	_drift(delta)
	_glow(delta)
	_partner(delta)


func _fly(delta: float) -> void:
	var keep: Array = []
	for f in _flying:
		var n: Sprite3D = f[0]
		if n == null or not is_instance_valid(n):
			continue
		var vel: Vector3 = f[1]
		vel.y -= GRAVITY * delta
		var from := n.global_position
		var to := from + vel * delta
		var space := n.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(q)
		if hit.is_empty() and to.y > -50.0:
			n.global_position = to
			f[1] = vel
			# Spinning as it goes, in steps.
			n.rotation.z = floorf(_t * 12.0) * 0.9
			keep.append(f)
			continue
		var at: Vector3 = hit.get("position", to)
		_land(n, str(f[2]), f[3], at)
	_flying = keep


func _land(n: Sprite3D, kind: String, extra, at: Vector3) -> void:
	n.rotation.z = 0.0
	match kind:
		"butt":
			n.global_position = at + Vector3.UP * 0.02
			n.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			_sound(n, "butt_land.mp3", -8.0)
			if bool(extra):
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.42, 0.15)
				l.light_energy = 0.35
				l.omni_range = 0.6
				l.shadow_enabled = false
				n.add_child(l)
				_embers.append({"node": n, "light": l, "t": 0.0})
			_keep_litter(n)
		"cap":
			n.texture = tex("cap_flat")
			n.global_position = at + Vector3.UP * 0.01
			_keep_litter(n)
		"bottle":
			var hard := _hard_ground(at)
			if hard:
				n.texture = tex("bottle_smash")
				_sound(n, "smash.mp3", -2.0, 34.0)
			else:
				_sound(n, "bottle_thud.mp3", -5.0)
			n.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			var h := float(n.texture.get_height()) if n.texture != null else 20.0
			n.global_position = at + Vector3.UP * (h * PIXEL_M * 0.5)
			_keep_litter(n)


## Gravel, paths, concrete, the road: things break there. Grass and earth take them.
func _hard_ground(at: Vector3) -> bool:
	var main := get_tree().current_scene
	var gm = main.get("grid_manager") if main != null else null
	if gm != null and gm.has_method("world_to_grid"):
		var c: Vector2i = gm.world_to_grid(at)
		var st = CoreRoot.get_state() if CoreRoot != null and CoreRoot.has_method("get_state") else null
		if st != null and st.grid != null and st.grid.cells.has(c):
			var ty := str(st.grid.cells[c].get("type", ""))
			return ty.contains("path") or ty.contains("road") or ty.contains("concrete")
	return at.distance_to(Vector3.ZERO) > 260.0


func _drift(delta: float) -> void:
	var keep: Array = []
	for p in _puffs:
		var n: Sprite3D = p["node"]
		if n == null or not is_instance_valid(n):
			continue
		p["life"] = float(p["life"]) + delta
		if float(p["life"]) < 0.0:
			n.visible = false
			keep.append(p)
			continue
		n.visible = true
		var k := float(p["life"]) / float(p["max"])
		if k >= 1.0:
			n.queue_free()
			continue
		n.global_position += (p["vel"] as Vector3) * delta
		p["vel"] = (p["vel"] as Vector3) * (1.0 - delta * 0.5) + Vector3(0, 0.03, 0) * delta
		# From dense to almost gone: the smoke sprites in order, a step at a time.
		var fi: int = [0, 1, 3, 4, 5][mini(4, int(k * 5.0))]
		n.texture = tex("smoke_%d" % fi)
		n.pixel_size = PIXEL_M * 0.6 * (1.0 + k * 1.6)
		n.modulate.a = floorf(0.45 * (1.0 - k) * 8.0) / 8.0
		keep.append(p)
	_puffs = keep


func _glow(delta: float) -> void:
	var keep: Array = []
	for e in _embers:
		var n = e["node"]
		if n == null or not is_instance_valid(n):
			continue
		e["t"] = float(e["t"]) + delta
		var l: OmniLight3D = e["light"]
		var k := float(e["t"]) / 9.0
		if k >= 1.0:
			l.queue_free()
			(n as Sprite3D).texture = tex("butt")
			continue
		# It flickers down, a step at a time.
		l.light_energy = 0.35 * (1.0 - k) * (0.7 + 0.3 * float(int(_t * 12.0) % 3 != 0))
		keep.append(e)
	_embers = keep


# ── picking a set-down bottle up ─────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _bottles.is_empty() or not event.is_action_pressed("interact") or pockets == null:
		return
	var v := _view()
	if v.is_empty():
		return
	var cam: Camera3D = v["cam"]
	var mid := cam.get_viewport().get_visible_rect().size * 0.5
	var o := cam.project_ray_origin(mid)
	var fwd := cam.project_ray_normal(mid)
	for id in _bottles.keys():
		var b: Dictionary = _bottles[id]
		var n: Node3D = b["node"]
		if n == null or not is_instance_valid(n) or n.get_world_3d() != cam.get_world_3d():
			continue
		var to := n.global_position - o
		var along := to.dot(fwd)
		if along <= 0.0 or to.length() > 2.4 or (to - fwd * along).length() > 0.3:
			continue
		if pockets.take_bottle(float(b["level"]), bool(b["opened"])):
			n.queue_free()
			_bottles.erase(id)
			get_viewport().set_input_as_handled()
		return


# ── co-op ────────────────────────────────────────────────────────────────────

func send(kind: String, data: Array) -> void:
	if Coop.has_method("send_habit"):
		Coop.send_habit(kind, data)


## Something the other warden did with their hands (Coop._habit).
func coop_habit(kind: String, data: Array) -> void:
	# Whose hands (Coop.sender: the warden it came from).
	var fig := _figure_of(Coop.sender)
	match kind:
		"strike":
			if fig != null:
				_sound(fig, "strike_catch.mp3" if int(data[0]) == 1 else "strike_fail.mp3", -6.0)
		"lit":
			if fig != null:
				_sound(fig, "light_up.mp3", -6.0)
		"exhale":
			if fig != null:
				_sound(fig, "exhale.mp3", -10.0, 10.0)
				var face := _partner_mouth(fig)
				var cam := fig.get_viewport().get_camera_3d() if fig.get_viewport() != null else null
				var push := Vector3.ZERO
				if cam != null:
					push = (cam.global_position - face).normalized() * 0.25
				_puff_at(fig.get_parent(), face, push, float(data[0]), false)
		"cough":
			if fig != null:
				_sound(fig, "cough_fit.mp3", -4.0)
		"pop":
			if fig != null:
				_sound(fig, "cap_pop.mp3", -5.0)
		"foam":
			if fig != null:
				_sound(fig, "foam.mp3", -6.0)
		"gulp":
			if fig != null:
				_sound(fig, "gulp.mp3", -9.0, 10.0)
		"burp":
			if fig != null:
				_sound(fig, "burp_big.mp3", -4.0, 30.0)
		"hiccup":
			if fig != null:
				_sound(fig, "hiccup.mp3", -6.0)
		"vomit":
			if fig != null:
				_sound(fig, "vomit.mp3", -3.0)
		"clink":
			_sound(fig, "clink.mp3", -2.0)
			if pockets != null:
				pockets._play("fx", "clink.mp3", -3.0)
				pockets._toast = 4
				pockets._say("Na zdravi.")
		"offer_cig":
			# They hold their pack out to you: one cigarette into your bag.
			if fig != null:
				_sound(fig, "pack.mp3", -5.0)
			if pockets != null and pockets.bag != null:
				if pockets.bag.has_method("add_item") and pockets.bag.add_item("cigs", 1):
					pockets._say("%s offers you a Start. C to smoke it." % Coop.partner_name())
				else:
					pockets._say("%s offers you a Start, but your bag is full." % Coop.partner_name())
		"give_bottle":
			# A bottle from their hand into yours (or at your feet, your hand full).
			if pockets != null:
				var lv := float(data[0])
				if lv > 1.5:
					if not pockets.take_bottle(1.0, false):
						set_bottle_down(2.0)
				elif not pockets.take_bottle(lv, true):
					set_bottle_down(lv)
				pockets._say("%s hands you a bottle." % Coop.partner_name())
		"light_you":
			# They held their flame or their cigarette to yours (to whom: data[0]).
			if not data.is_empty() and int(data[0]) != multiplayer.get_unique_id():
				return
			if pockets != null and pockets.cig.state == pockets.CIG.LIPS:
				pockets.cig.lit = true
				pockets.cig.events.append(["lit", 0])
				pockets.cig.state = pockets.CIG.EXHALE
				pockets.cig.t = 0.0
				pockets._say("A light from %s." % Coop.sender_name())
		"butt", "bottle":
			var root := get_tree().current_scene.get("_world_3d") as Node3D if get_tree().current_scene != null else null
			if root == null:
				return
			var s := _sprite("butt_lit" if kind == "butt" and bool(data[2]) else ("butt" if kind == "butt" else "bottle_side"))
			root.add_child(s)
			s.global_position = data[0]
			_flying.append([s, data[1], kind, data[2] if kind == "butt" else 1.0])


## The warden whose hands are near yours: the nearest of the others, close enough.
var _partner_id := 0


func _partner_figure() -> Node3D:
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	_partner_id = Coop.nearest_other(cam.global_position, 6.0) if cam != null else Coop.remote_id
	return _figure_of(_partner_id)


func _figure_of(id: int) -> Node3D:
	var f: Node3D = Coop.figure_of(id)
	return f if f != null and f.visible else null


## Their mouth: a little under the top of the figure, a step towards you.
func _partner_mouth(fig: Node3D) -> Vector3:
	var at := fig.global_position + Vector3(0.0, 1.58, 0.0)
	var cam := fig.get_viewport().get_camera_3d() if fig.get_viewport() != null else null
	if cam != null:
		var to := cam.global_position - at
		to.y = 0.0
		if to.length() > 0.01:
			at += to.normalized() * 0.12
	return at


## Their hands as the state says ("hb": c, l, b): the ember at their mouth, the flame.
func _partner(_delta: float) -> void:
	var fig := _partner_figure()
	var hb: Dictionary = Coop.state_of(_partner_id).get("hb", {}) if Coop.is_active() else {}
	if fig == null or hb.is_empty():
		if _partner_fx != null and is_instance_valid(_partner_fx):
			_partner_fx.visible = false
		return
	if _partner_fx == null or not is_instance_valid(_partner_fx) or _partner_fx.get_parent() != fig.get_parent():
		_make_partner_fx(fig.get_parent())
	_partner_fx.visible = true
	var c := int(hb.get("c", 0))
	var mouth := _partner_mouth(fig)
	# Where the burning end is drawn in their pose (found in its picture), else at the
	# mouth or the hand by guess.
	var drawn := _ember_point(fig)
	_partner_fx.global_position = drawn if drawn != Vector3.INF else mouth
	var lit := c in [3, 4]
	_partner_ember.visible = lit
	_partner_light.visible = lit
	if lit:
		var drag := c == 4
		_partner_ember.material_override = _ember_bright_mat if drag else _ember_mat
		# It breathes: brighter and a pixel bigger on a drag, dimmer between.
		(_partner_ember.mesh as QuadMesh).size = Vector2.ONE * (0.03 if drag else 0.02)
		# Held at their side between drags, at their mouth on one (unless the pose says).
		_partner_ember.position = Vector3.ZERO if drag or drawn != Vector3.INF else Vector3(0.0, -0.45, 0.0)
		_partner_light.position = _partner_ember.position
		# A speck of light on their fingers and face, not a lamp: brighter on a drag.
		_partner_light.light_energy = 0.12 if drag else 0.04 + 0.015 * float(int(_t * 12.0) % 3 == 0)
	_partner_flame.visible = c == 2
	if c == 2:
		_partner_flame.texture = tex("flame_small" if int(_t * 12.0) % 4 != 0 else "flame_tall")
	_offer_light(fig, hb)
	_offer_clink(fig, hb)


## A sprite that keeps its size on the screen and ignores the fog: a light seen far off.
func _far_glow(n: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex(n)
	m.albedo_color = Color(1.0, 0.55, 0.2) if tex(n) == null else Color.WHITE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.fixed_size = true
	m.disable_fog = true
	m.disable_receive_shadows = true
	return m


var _ember_px: Dictionary = {}


## The burning end in the other warden's picture now (their pose's own pixels of ember),
## in the world: on the sprite facing you, a touch in front of it. INF: none drawn.
func _ember_point(fig: Node3D) -> Vector3:
	var spr := fig.get_node_or_null("Sprite") as Sprite3D
	if spr == null or spr.texture == null:
		return Vector3.INF
	var t := spr.texture
	var key := t.get_rid().get_id()
	if not _ember_px.has(key):
		_ember_px[key] = Vector2.INF
		var img := t.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var sum := Vector2.ZERO
			var n := 0
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.5 and c.r > 0.78 and c.g > 0.2 and c.g < 0.66 and c.b < 0.32 and c.r - c.g > 0.3:
						sum += Vector2(x, y)
						n += 1
			if n > 0 and n < 40:
				_ember_px[key] = sum / float(n)
	var p: Vector2 = _ember_px[key]
	if p == Vector2.INF:
		return Vector3.INF
	var cam := fig.get_viewport().get_camera_3d() if fig.get_viewport() != null else null
	if cam == null:
		return Vector3.INF
	var w := float(t.get_width())
	var h := float(t.get_height())
	var dx := (p.x - w * 0.5) * spr.pixel_size * (-1.0 if spr.flip_h else 1.0)
	var dy := (h - p.y) * spr.pixel_size
	var right := cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var toward := cam.global_position - spr.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.ZERO
	return spr.global_position + right * dx + Vector3.UP * (dy + spr.offset.y * spr.pixel_size - h * spr.pixel_size * 0.5) + toward * 0.03


func _make_partner_fx(parent: Node) -> void:
	if _partner_fx != null and is_instance_valid(_partner_fx):
		_partner_fx.queue_free()
	_partner_fx = Node3D.new()
	_partner_fx.name = "PartnerHabits"
	parent.add_child(_partner_fx)
	# The ember: seen through the dark and the fog from across the camp, a few pixels
	# of orange that never shrink to nothing (fixed size on the screen, no fog on it).
	_ember_mat = _far_glow("ember")
	_ember_bright_mat = _far_glow("ember_bright")
	_partner_ember = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	_partner_ember.mesh = q
	_partner_ember.material_override = _ember_mat
	_partner_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_partner_fx.add_child(_partner_ember)
	_partner_light = OmniLight3D.new()
	_partner_light.light_color = Color(1.0, 0.45, 0.18)
	_partner_light.omni_range = 0.5
	_partner_light.shadow_enabled = false
	_partner_fx.add_child(_partner_light)
	_partner_flame = _sprite("flame_small")
	_partner_flame.shaded = false
	_partner_flame.pixel_size = 0.003
	_partner_flame.position = Vector3(0.05, -0.06, 0.0)
	_partner_fx.add_child(_partner_flame)


## Close and facing them: your flame (or your lit cigarette) to theirs, which is in their
## mouth waiting; it is lit on their machine.
func _offer_light(fig: Node3D, hb: Dictionary) -> void:
	if _light_cd > 0.0 or pockets == null or int(hb.get("c", 0)) != 1:
		return
	var mine: int = pockets.cig.coop_code()
	if not (mine in [2, 3, 4]) or not _facing(fig, 1.4):
		return
	if mine == 2 or Input.is_action_pressed("smoke"):
		_light_cd = 3.0
		send("light_you", [_partner_id])
		pockets._say("You give %s a light." % Coop.name_of(_partner_id))


## Both with an open bottle up, face to face: the bottles knock.
func _offer_clink(fig: Node3D, hb: Dictionary) -> void:
	if _clink_cd > 0.0 or pockets == null or int(hb.get("b", 0)) < 3:
		return
	if pockets.bottle.coop_code() < 3 or not _facing(fig, 1.3):
		return
	if Input.is_action_just_pressed("drink") or Engine.get_process_frames() - int(pockets.b_tap_frame) <= 1:
		_clink_cd = 6.0
		_sound(fig, "clink.mp3", -2.0)
		pockets._play("fx", "clink.mp3", -3.0)
		pockets._toast = 4
		send("clink", [])
		pockets._say("Na zdravi.")


## The other warden is close in front of you (to offer, hand over, light, clink).
func partner_in_reach() -> bool:
	var fig := _partner_figure()
	return fig != null and _facing(fig, 1.6)


func _facing(fig: Node3D, reach: float) -> bool:
	var v := _view()
	if v.is_empty() or bool(v["indoors"]):
		return false
	var cam: Camera3D = v["cam"]
	var to := fig.global_position + Vector3.UP * 1.4 - cam.global_position
	if to.length() > reach + 0.6:
		return false
	return to.normalized().dot(-cam.global_basis.z) > 0.75
