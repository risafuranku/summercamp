extends Node3D

## What you pick up, carry, set down and throw (the brief of 21. 10.: "take the bottle and
## throw it, carry the sack"):
##   - the small things lying about (nudge_props.gd: bottles, cans, cones, the bucket, a
##     stone, a log): E with one under the crosshair takes it, it is in your right hand
##     (a Build sprite at the hands' pixel and in their light: hands_lo/hold_*, the bottle
##     the habits' hand), E sets it down where you look, the left button throws it: an arc,
##     a bounce off a wall, the sound of it landing; the torch goes to the left hand as for
##     any work (hands.gd);
##   - work things (the rubbish sack you bagged: day_events.gd) in both arms
##     (hands_lo/carry_*): slower, the torch in your pocket and dark; the sack goes in the
##     dumpsters (E at them) and only then is the rubbish done; set down anywhere it lies
##     there to be picked up again;
##   - what is in your hand is not in the bag (inventory.gd: the bag is for pockets).
## At night a thrown thing is a noise where it lands: `heard(pos, loudness)` goes to the
## group "night_ears" (no enemy listens yet: the hook for the night's code).
## Co-op: picked up, set down and thrown on every machine (Coop.send_body "carry"); what
## the other wardens carry is drawn at their figure's hand.

const HANDS = preload("res://scripts/ui/hands.gd")
const HL := "res://assets/textury/hands_lo/"
const REACH := 2.4
## kind -> the hand's picture (one hand), or two hands for work things.
const HOLD_TEX := {"bottle": "hand2_beer_shut", "can": "hold_can", "cone": "hold_cone", "stone": "hold_stone", "log": "hold_log"}
const WORK_TEX := {"sack": "carry_sack", "box": "carry_box"}
## How hard each is thrown (m/s) and how loud it lands for the night (0..1).
const THROW := {"bottle": [9.0, 0.8], "can": [9.5, 0.7], "cone": [10.0, 0.25], "stone": [11.0, 0.9], "log": [7.0, 0.8], "bucket": [6.0, 1.0]}
const SLOW := {"sack": 0.82, "box": 0.78}

var player_getter: Callable
var nudge: Node

## What you hold: {} nothing, else {kind, id (the prop's), work (bool), ev (a day event)}.
var held: Dictionary = {}
var _layer: CanvasLayer
var _hand: TextureRect
var _item: TextureRect
var _tex: Dictionary = {}
var _throw := -1
var _acc := 0.0
var _up := 0.0
var _hint := ""
var _target: Dictionary = {}
## Co-op: the things in the other wardens' hands, drawn by their figures.
var _mates: Dictionary = {}       # peer id -> Sprite3D


func _ready() -> void:
	name = "Carry"
	add_to_group("carry")
	_layer = CanvasLayer.new()
	_layer.layer = 59
	add_child(_layer)
	_item = _rect()
	_hand = _rect()
	# Loaded now, not on the first pick-up (a hitch).
	for n in HOLD_TEX.values() + WORK_TEX.values() + ["hand7_grab", "hand7_reach"]:
		_t(str(n))


func _rect() -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	_layer.add_child(r)
	return r


func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		var p := n if n.begins_with("res://") else HL + n + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
	return _tex[n]


func _player() -> CharacterBody3D:
	return player_getter.call() if player_getter.is_valid() else null


func _main() -> Node:
	return get_tree().current_scene


func _can_act() -> bool:
	var m := _main()
	var p := _player()
	if m == null or p == null or bool(m.get("_menu_mode")) or get_tree().paused:
		return false
	if m.has_method("_is_any_interior_open") and bool(m.call("_is_any_interior_open")):
		return false
	if not bool(p.get("controls_enabled")) or bool(p.get("seated")):
		return false
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


# ── what is under the crosshair ───────────────────────────────────────────────

## The nearest small thing on the line of your look, within reach.
func _find_target() -> Dictionary:
	var p := _player()
	if p == null or nudge == null or not nudge.has_method("props_near"):
		return {}
	var cam := p.get("_camera") as Camera3D
	if cam == null:
		return {}
	var o := cam.global_position
	var fwd: Vector3 = -(p.call("look_basis") as Basis).z
	var best: Dictionary = {}
	var best_d := INF
	for pr in nudge.props_near(o, REACH + 0.5):
		var c: Vector3 = (pr["pos"] as Vector3) + Vector3(0, 0.1, 0)
		var to := c - o
		var along := to.dot(fwd)
		if along < 0.2 or along > REACH:
			continue
		var off := (to - fwd * along).length()
		if off < 0.32 + 0.05 * along and off < best_d:
			best_d = off
			best = pr
	return best


## The dumpsters near where you look (the sack goes in them).
func _dumpsters_near() -> Node3D:
	var p := _player()
	var m := _main()
	var bm = m.get("building_manager") if m != null else null
	var root: Node = bm.get_node_or_null("Structures") if bm != null else null
	if root == null or p == null:
		return null
	# The camp's own by the gate (camp_gate.gd) and any built ones.
	var all: Array = get_tree().get_nodes_in_group("camp_bins")
	all.append_array(root.get_children())
	for c in all:
		if c is Node3D and str(c.get_meta("building_type", "")) == "dumpsters":
			var d := Vector2((c as Node3D).global_position.x - p.global_position.x, (c as Node3D).global_position.z - p.global_position.z).length()
			if d < 3.2:
				return c
	return null


func any_dumpsters() -> bool:
	if get_tree().get_first_node_in_group("camp_bins") != null:
		return true
	var m := _main()
	var bm = m.get("building_manager") if m != null else null
	var root: Node = bm.get_node_or_null("Structures") if bm != null else null
	if root == null:
		return false
	for c in root.get_children():
		if str(c.get_meta("building_type", "")) == "dumpsters":
			return true
	return false


## main._update_interaction_hint: ours when we have something to say.
func hint() -> String:
	return _hint


func _update_hint() -> void:
	_hint = ""
	_target = {}
	if not _can_act():
		return
	if not held.is_empty():
		if str(held["kind"]) == "sack" and _dumpsters_near() != null:
			_hint = "[E] Into the dumpster"
		elif bool(held.get("work", false)):
			_hint = "[E] Put it down"
		else:
			_hint = "[E] Put down   [LMB] Throw"
		return
	_target = _find_target()
	if not _target.is_empty():
		_hint = "[E] Pick up the %s" % tr(str(KIND_NAMES.get(str(_target["kind"]), _target["kind"])))


const KIND_NAMES := {"bottle": "bottle", "can": "can", "cone": "cone", "bucket": "bucket", "stone": "stone", "log": "log", "sack": "rubbish sack", "box": "box"}


# ── input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _can_act():
		return
	var key := event as InputEventKey
	var mb := event as InputEventMouseButton
	var e_press := key != null and key.pressed and not key.echo and event.is_action_pressed("interact")
	var lmb := mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if not held.is_empty():
		if lmb and not bool(held.get("work", false)):
			throw_held()
			get_viewport().set_input_as_handled()
		elif e_press or (lmb and bool(held.get("work", false))):
			if str(held["kind"]) == "sack" and _dumpsters_near() != null:
				_bin_sack()
			else:
				put_down()
			get_viewport().set_input_as_handled()
		return
	if (e_press or lmb) and not _target.is_empty():
		take(_target)
		get_viewport().set_input_as_handled()


func take(pr: Dictionary) -> void:
	if nudge == null or not held.is_empty():
		return
	var kind := str(pr["kind"])
	nudge.take_prop(str(pr["id"]))
	held = {"kind": kind, "id": str(pr["id"]), "work": WORK_TEX.has(kind), "ev": int(pr.get("ev", -1))}
	_send("take", [str(pr["id"])])
	_claim()
	_play_kind_sound(kind, _player().global_position, -12.0)


## A work thing straight into your arms (day_events: the rubbish just bagged).
func take_work(kind: String, ev_id: int) -> bool:
	if not held.is_empty():
		return false
	held = {"kind": kind, "id": "", "work": true, "ev": ev_id}
	_claim()
	return true


func put_down() -> void:
	if held.is_empty() or nudge == null:
		return
	var p := _player()
	var at := _floor_ahead(1.0)
	var id: String = held["id"]
	if id == "":
		id = nudge.add_loose(str(held["kind"]), at, {"ev": int(held.get("ev", -1))})
	else:
		nudge.put_prop(id, at)
	_send("put", [id, str(held["kind"]), at])
	_play_kind_sound(str(held["kind"]), at, -10.0)
	held = {}
	_release()
	if p != null:
		p.set("carry_speed_mult", 1.0)


func throw_held() -> void:
	if held.is_empty() or nudge == null or bool(held.get("work", false)):
		return
	var p := _player()
	var cam := p.get("_camera") as Camera3D
	var look: Basis = p.call("look_basis")
	var fwd := -look.z
	var from := cam.global_position + fwd * 0.45 + look.x * 0.22 - Vector3(0, 0.12, 0)
	var spec: Array = THROW.get(str(held["kind"]), [8.0, 0.6])
	var vel := fwd * float(spec[0]) + Vector3.UP * 2.2 + Vector3(p.velocity.x, 0.0, p.velocity.z) * 0.6
	var id: String = held["id"]
	nudge.throw_prop(id, from, vel, float(spec[1]))
	_send("throw", [id, from, vel, float(spec[1])])
	_throw = 0
	held = {}
	_release()


## The sack in the dumpster: the rubbish done (day_events), the lid's clang.
func _bin_sack() -> void:
	var ev := int(held.get("ev", -1))
	var de = _main().get("_day_events") if _main() != null else null
	if de != null and de.has_method("sack_binned"):
		de.sack_binned(ev)
	var bin := _dumpsters_near()
	_play_kind_sound("bucket", bin.global_position if bin != null else _player().global_position, -6.0)
	if held.get("id", "") != "":
		_send("bin", [str(held["id"])])
	held = {}
	_release()


func _floor_ahead(dist: float) -> Vector3:
	var p := _player()
	var cam := p.get("_camera") as Camera3D
	var look: Basis = p.call("look_basis")
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - look.z * 2.6)
	q.exclude = [p.get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.6:
		return hit["position"]
	var fwd := -p.global_basis.z
	var at := p.global_position + Vector3(0, 0.35, 0) + fwd * dist
	var q2 := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 2.0)
	q2.exclude = [p.get_rid()]
	var h2 := space.intersect_ray(q2)
	return h2["position"] if not h2.is_empty() else at


func _claim() -> void:
	var h := HANDS.of(self)
	if h != null:
		h.claim("right", "work#carry")
		if bool(held.get("work", false)):
			h.claim("left", "work#carry")
	var p := _player()
	if p != null:
		p.set("carry_speed_mult", float(SLOW.get(str(held["kind"]), 1.0)))


func _release() -> void:
	var h := HANDS.of(self)
	if h != null:
		h.release("left", "work#carry")
	_up = maxf(_up, 0.0)
	var p := _player()
	if p != null:
		p.set("carry_speed_mult", 1.0)


func _play_kind_sound(kind: String, at: Vector3, db: float) -> void:
	if nudge != null and nudge.has_method("play_kind"):
		nudge.play_kind(kind, at, db)


# ── drawing the hand ──────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_update_hint()
	_draw_mates()
	var want := not held.is_empty() and _can_act_visual()
	if _throw >= 0:
		want = true
	_up = move_toward(_up, 1.0 if want else 0.0, delta * 5.0)
	if _up <= 0.0:
		_hand.visible = false
		_item.visible = false
		var h := HANDS.of(self)
		if h != null and held.is_empty() and _throw < 0:
			h.release("right", "work#carry")
		return
	_acc += delta
	if _acc < 1.0 / 12.0:
		return
	_acc = 0.0
	var vp := _layer.get_viewport().get_visible_rect().size
	var k := HANDS.px(vp.y)
	var hands := HANDS.of(self)
	var mat: Material = hands.material if hands != null else null
	var mo: Vector2 = hands.motion if hands != null else Vector2.ZERO
	var bar := 0.0
	var hud = _main().get("_hud_manager") if _main() != null else null
	if hud != null and hud.has_method("get_bar_height_px"):
		bar = float(hud.get_bar_height_px())
	var tex: Texture2D = null
	var item: Texture2D = null
	var x := vp.x * 0.6
	var lift := 0.0
	if _throw >= 0:
		# Back, up and out: the arm goes, the hand opens, it comes down again.
		var frames := ["wind", "wind", "out", "out", "down"]
		var f: String = frames[mini(_throw, frames.size() - 1)]
		tex = _t("hand7_reach") if f != "wind" else _t("hand7_grab")
		lift = -0.15 if f == "wind" else (0.25 if f == "out" else -0.4)
		x = vp.x * (0.66 if f == "wind" else 0.52)
		_throw += 1
		if _throw > frames.size():
			_throw = -1
	elif held.is_empty():
		# Thrown and the arm come down: nothing more to draw.
		_hand.visible = false
		_item.visible = false
		return
	elif bool(held.get("work", false)):
		tex = _t(str(WORK_TEX.get(str(held["kind"]), "")))
		x = vp.x * 0.5
	else:
		tex = _t(str(HOLD_TEX.get(str(held["kind"]), "")))
		if tex == null:
			# No hand of its own: the fist with the thing's own picture in it.
			tex = _t("hand7_grab")
			item = nudge.texture_of(str(held["kind"])) if nudge != null and nudge.has_method("texture_of") else null
	if tex == null:
		_hand.visible = false
		_item.visible = false
		return
	var size := tex.get_size() * k
	var y := vp.y - bar - size.y * (0.78 + lift) * _up + size.y * 0.3 * (1.0 - _up)
	var px := x - size.x * 0.5
	if bool(held.get("work", false)):
		y = vp.y - bar - size.y * 0.72 * _up + size.y * 0.3 * (1.0 - _up)
	_hand.texture = tex
	_hand.size = size
	_hand.material = mat
	_hand.position = ((Vector2(px, y) + mo * k * 0.5) / k).floor() * k
	_hand.visible = true
	if item != null:
		var isz := item.get_size() * k * 2.0
		_item.texture = item
		_item.size = isz
		_item.material = mat
		_item.position = ((Vector2(px + size.x * 0.35 - isz.x * 0.5, y + size.y * 0.08 - isz.y) + mo * k * 0.5) / k).floor() * k
		_item.visible = true
	else:
		_item.visible = false


func _can_act_visual() -> bool:
	var m := _main()
	if m == null or bool(m.get("_menu_mode")):
		return false
	return not (m.has_method("_is_any_interior_open") and bool(m.call("_is_any_interior_open")))


# ── co-op ─────────────────────────────────────────────────────────────────────

func _send(op: String, data: Array) -> void:
	Coop.send_body("carry", [op] + data)


## Another warden took, set down, threw or binned one of the small things.
func coop_body(kind: String, data: Array) -> void:
	if kind != "carry" or data.is_empty() or nudge == null:
		return
	match str(data[0]):
		"take":
			nudge.take_prop(str(data[1]))
		"put":
			if str(data[1]) != "" and nudge.has_prop(str(data[1])):
				nudge.put_prop(str(data[1]), data[3])
			else:
				nudge.add_loose(str(data[2]), data[3], {}, str(data[1]))
		"throw":
			nudge.throw_prop(str(data[1]), data[2], data[3], float(data[4]))
		"bin":
			nudge.drop_prop(str(data[1]))


## What you carry, for the warden state ("cr") and the pose the others draw.
func coop_held() -> String:
	return str(held.get("kind", ""))


func coop_pose() -> String:
	return "bag" if bool(held.get("work", false)) else ""


## The other wardens' small things at their figure's hand (their state's "cr").
func _draw_mates() -> void:
	var coop = Coop
	if nudge == null or coop.wardens.is_empty():
		for id in _mates.keys():
			if is_instance_valid(_mates[id]):
				(_mates[id] as Node3D).visible = false
		return
	var seen := {}
	for r in get_tree().get_nodes_in_group("coop_remote_player"):
		if not (r is Node3D) or not (r as Node3D).is_visible_in_tree():
			continue
		var id := int(r.get_meta("coop_id", 0))
		var st: Dictionary = coop.state_of(id) if coop.has_method("state_of") else {}
		var kind := str(st.get("cr", ""))
		if kind == "" or WORK_TEX.has(kind):
			continue
		seen[id] = true
		var s: Sprite3D = _mates.get(id)
		if s == null or not is_instance_valid(s):
			s = Sprite3D.new()
			s.pixel_size = 0.01
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			add_child(s)
			_mates[id] = s
		s.texture = nudge.texture_of(kind)
		var yaw := float(st.get("y", 0.0))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		s.global_position = (r as Node3D).global_position + right * 0.3 + Vector3(0, 0.85, 0)
		s.visible = true
	for id in _mates.keys():
		if not seen.has(id) and is_instance_valid(_mates[id]):
			(_mates[id] as Node3D).visible = false
