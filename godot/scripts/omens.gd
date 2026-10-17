extends Node

## Omens (DESIGN.md §5e): small, specific, deniable things in the night camp (DESIGN §2).
## Nothing here is scheduled. Every in-game minute you spend outdoors at night there is
## a chance that something shows itself, and that chance comes out of the simulation:
## how many people you let in, how unhappy they are, what has already come for them on
## earlier nights, the dark after a tripped breaker, something hunting tonight. Which
## omen it is is a weighted draw from what fits where you stand and who is in the camp.
## Two playthroughs never get the same week.
##
##   torch          a torch walking along the fence nearest you, outside it
##   one_more       one person too many, standing 25-30 m off, facing the office
##   barrier        the barrier lifts and drops with nobody at it (you are near the gate)
##   phone          the office phone rings four times (you are well away from it)
##   by_the_office  a person and a torch at the fence by the office; the insects stop
##                  (only once the camp has had real trouble at night)
##
## At most one a night, then quiet for a while; an omen you have had is less likely to
## repeat. Figures and torches appear only across open ground (line of sight, never next
## to you) and are gone when you walk up to them or when their time is up.

const FIGURE_SPRITE := "res://assets/textury/npc/host1.png"
const PHONE_SFX := "res://assets/sfx/uncanny/office_phone.mp3"

const NIGHT_FROM := 21.5 * 60.0   # minute of day
const NIGHT_TO := 4.5 * 60.0
## Chance per outdoor night minute = RATE * pressure (pressure ~0.3 empty camp, 2-6 busy).
const RATE := 0.0007
const COOLDOWN_MIN := 900
const VANISH_TORCH_M := 18.0
const VANISH_FIGURE_M := 14.0

var hush := 0.0                    # main adds this to the insects' silence
var _seen: Dictionary = {}         # omen id -> times it has happened
var _last_night := -1              # night index of the last omen
var _quiet_until := -1             # abs minute
var _live: Dictionary = {}         # omen id -> {node, until, vanish, hush, from, to, minutes}
var _main: Node
var _rng := RandomNumberGenerator.new()
var _torch_t := 0.0
var _last_minute := -1


func setup(main_node: Node) -> void:
	_main = main_node
	_rng.randomize()


func reset() -> void:
	_clear_live()
	_seen.clear()
	_last_night = -1
	_quiet_until = -1
	_last_minute = -1
	hush = 0.0
	_rng.randomize()


## How much the night presses on the camp. `ctx`: guests, unhappy, kinds_seen (enemy
## kinds that have come so far), nights_visited, hunting (enemies out tonight),
## dark (breaker tripped / power cut).
static func pressure(ctx: Dictionary) -> float:
	var p := 0.3
	p += 0.08 * float(ctx.get("guests", 0))
	p += 0.35 * float(ctx.get("unhappy", 0))
	p += 0.5 * float(ctx.get("kinds_seen", 0))
	p += 0.3 * float(ctx.get("nights_visited", 0))
	p += 0.4 if int(ctx.get("hunting", 0)) > 0 else 0.0
	p += 0.6 if bool(ctx.get("dark", false)) else 0.0
	# Every one let in at the desk who was not booked.
	p += 1.2 * float(ctx.get("admitted", 0))
	return p


## Draw weights for the omens that fit right now. `ctx` as above plus `near_gate`,
## `far_from_office`, `pressure`. `seen` = times each omen has happened.
static func weights(ctx: Dictionary, seen: Dictionary) -> Dictionary:
	var w := {}
	w["torch"] = 1.0 + (0.8 if bool(ctx.get("dark", false)) else 0.0)
	var guests := int(ctx.get("guests", 0))
	if guests > 0:
		w["one_more"] = 0.5 + 0.1 * guests + 0.2 * float(ctx.get("unhappy", 0)) + 1.5 * float(ctx.get("admitted", 0))
	if bool(ctx.get("near_gate", false)):
		w["barrier"] = 0.8
	if bool(ctx.get("far_from_office", false)):
		w["phone"] = 0.7
	var p := float(ctx.get("pressure", 0.0))
	if int(ctx.get("kinds_seen", 0)) >= 2 or p >= 3.0:
		w["by_the_office"] = 0.3 * p
	for id in w.keys():
		w[id] = float(w[id]) * pow(0.35, float(seen.get(id, 0)))
	return w


func _pick(w: Dictionary) -> String:
	var total := 0.0
	for id in w.keys():
		total += float(w[id])
	if total <= 0.0:
		return ""
	var r := _rng.randf() * total
	for id in w.keys():
		r -= float(w[id])
		if r <= 0.0:
			return str(id)
	return str(w.keys().back())


## Every frame. `abs_minute` counts from day 1 00:00; `outdoors`: in the camp, not in an
## interior or a minigame; `ctx` as for pressure().
func tick(delta: float, abs_minute: int, outdoors: bool, player_pos: Vector3, ctx: Dictionary) -> void:
	_update_live(delta, abs_minute, player_pos)
	if abs_minute == _last_minute:
		return
	var minutes := 1 if _last_minute < 0 else clampi(abs_minute - _last_minute, 0, 30)
	_last_minute = abs_minute
	var mod := float(posmod(abs_minute, 1440))
	var is_night := mod >= NIGHT_FROM or mod < NIGHT_TO
	if not is_night or not outdoors or not _live.is_empty() or abs_minute < _quiet_until:
		return
	var night := int(abs_minute / 1440) if mod >= NIGHT_FROM else int(abs_minute / 1440) - 1
	if night == _last_night:
		return
	var p := pressure(ctx)
	var chance := 1.0 - pow(1.0 - minf(0.5, RATE * p), float(minutes))
	if _rng.randf() >= chance:
		return
	var full := ctx.duplicate()
	full.merge(_situation(player_pos), true)
	full["pressure"] = p
	var id := _pick(weights(full, _seen))
	if id != "" and _play(id, abs_minute, player_pos):
		_seen[id] = int(_seen.get(id, 0)) + 1
		_last_night = night
		_quiet_until = abs_minute + COOLDOWN_MIN


## The night director asks for an omen now (it has its own pacing): the usual draw for
## where you stand, without the per-minute chance. Returns which, or "".
func play_now(player_pos: Vector3, ctx: Dictionary) -> String:
	if not _live.is_empty():
		return ""
	var full := ctx.duplicate()
	full.merge(_situation(player_pos), true)
	full["pressure"] = pressure(ctx)
	var w := weights(full, _seen)
	var id := _pick(w)
	var now := _last_minute if _last_minute >= 0 else 0
	if id != "" and _play(id, now, player_pos):
		_seen[id] = int(_seen.get(id, 0)) + 1
		return id
	return ""


## Where the player stands, for the draw: near_gate, far_from_office.
func _situation(player_pos: Vector3) -> Dictionary:
	var office := _office_door()
	var gate = get_tree().get_first_node_in_group("camp_gate") if is_inside_tree() else null
	return {
		"near_gate": gate != null and _near(player_pos, Vector3(float(gate.gap_center_x), 0, float(gate.fence_z)), 45.0),
		"far_from_office": office != Vector3.INF and not _near(player_pos, office, 25.0),
	}


## False when the omen has no place to happen right now (the draw is simply lost).
func _play(id: String, now: int, player_pos: Vector3) -> bool:
	match id:
		"torch":
			var spot := _fence_spot(player_pos, 22.0, 40.0, -1.5)
			if spot.is_empty():
				return false
			var minutes := _rng.randi_range(30, 60)
			var along: Vector3 = spot["along"] * (1.0 if _rng.randf() < 0.5 else -1.0)
			var torch := _make_torch()
			var from: Vector3 = spot["pos"] - along * 15.0
			torch.position = from
			_live[id] = {"node": torch, "until": now + minutes, "minutes": minutes, "vanish": VANISH_TORCH_M,
				"from": from, "to": spot["pos"] + along * 15.0}
		"one_more":
			var spot := _camp_spot(player_pos, 24.0, 32.0)
			if spot.is_empty():
				return false
			var fig := _make_figure(spot["pos"])
			_live[id] = {"node": fig, "until": now + _rng.randi_range(40, 90), "vanish": VANISH_FIGURE_M}
		"barrier":
			var gate = get_tree().get_first_node_in_group("camp_gate")
			if gate == null or not gate.has_method("open_briefly"):
				return false
			gate.open_briefly()
		"phone":
			var at := _office_door()
			if at == Vector3.INF:
				return false
			var p := AudioStreamPlayer3D.new()
			p.stream = load(PHONE_SFX)
			p.unit_size = 9.0
			p.max_distance = 60.0
			p.volume_db = -2.0
			_world().add_child(p)
			p.global_position = at + Vector3(0, 1.2, 0)
			p.finished.connect(p.queue_free)
			p.play()
		"by_the_office":
			var at := _office_spot(player_pos)
			if at == Vector3.INF:
				return false
			var root := Node3D.new()
			root.name = "OmenByTheOffice"
			_world().add_child(root)
			root.global_position = at
			_make_figure(at, root)
			var torch := _make_torch(root)
			torch.position = Vector3(0.45, 1.1, 0.0)
			_live[id] = {"node": root, "until": now + _rng.randi_range(40, 70), "vanish": VANISH_FIGURE_M + 4.0, "hush": true}
		_:
			return false
	return true


func _update_live(delta: float, abs_minute: int, player_pos: Vector3) -> void:
	_torch_t += delta
	var want_hush := 0.0
	for id in _live.keys():
		var entry: Dictionary = _live[id]
		var node: Node3D = entry["node"]
		if node == null or not is_instance_valid(node):
			_live.erase(id)
			continue
		if entry.has("from"):
			# The torch walks the fence at a stroll, swinging a little.
			var total := float(entry["minutes"])
			var left := float(int(entry["until"]) - abs_minute)
			var t := clampf(1.0 - left / maxf(1.0, total), 0.0, 1.0)
			node.position = (entry["from"] as Vector3).lerp(entry["to"], t)
			node.position.y = 1.35 + sin(_torch_t * 3.1) * 0.05
		var flat := Vector2(node.global_position.x - player_pos.x, node.global_position.z - player_pos.z)
		if abs_minute >= int(entry["until"]) or (player_pos != Vector3.INF and flat.length() < float(entry["vanish"])):
			node.queue_free()
			_live.erase(id)
			continue
		if bool(entry.get("hush", false)):
			want_hush = 1.0
	hush = move_toward(hush, want_hush, delta * (2.0 if want_hush > hush else 0.25))


## Nothing solid (a tree, a cabin) between the player's eyes and `at`.
func _in_sight(player_pos: Vector3, at: Vector3) -> bool:
	var w := _world()
	if not w.is_inside_tree() or w.get_world_3d() == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(player_pos + Vector3(0, 1.6, 0), at)
	var player = _main.get("_player") if _main != null else null
	if player is CollisionObject3D:
		q.exclude = [player.get_rid()]
	return w.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _near(player_pos: Vector3, at: Vector3, dist: float) -> bool:
	if player_pos == Vector3.INF or at == Vector3.INF:
		return false
	return Vector2(at.x - player_pos.x, at.z - player_pos.z).length() < dist


func _office_door() -> Vector3:
	if _main != null and _main.has_method("get_reception_door_position"):
		return _main.call("get_reception_door_position")
	return Vector3.INF


## By the gate fence beside the office, just inside: without `player_pos` the nominal
## spot; with it, the first spot beside the office that is 22-45 m away and in sight.
func _office_spot(player_pos: Vector3 = Vector3.INF) -> Vector3:
	var at := _office_door()
	var r := _bounds()
	if at == Vector3.INF or r.size == Vector2.ZERO:
		return Vector3.INF
	if player_pos == Vector3.INF:
		return Vector3(at.x - 6.0, 0.0, r.position.y + 1.5)
	for dx: float in [-6.0, 6.0, -9.0, 9.0, -12.0, 12.0]:
		var p := Vector3(at.x + dx, 0.0, r.position.y + 1.5)
		var d := Vector2(p.x - player_pos.x, p.z - player_pos.z).length()
		if d >= 22.0 and d <= 45.0 and _in_sight(player_pos, p + Vector3(0, 1.6, 0)):
			return p
	return Vector3.INF


## The camp's fenced rectangle on the ground (x, z).
func _bounds() -> Rect2:
	var gm = _main.get("grid_manager") if _main != null else null
	if gm == null:
		return Rect2()
	var a: Vector3 = gm.grid_to_world(Vector2i(0, 0))
	var b: Vector3 = gm.grid_to_world(Vector2i(int(gm.grid_width) - 1, int(gm.grid_height) - 1))
	var half := float(gm.tile_size) * 0.5
	var lo := Vector2(minf(a.x, b.x) - half, minf(a.z, b.z) - half)
	var hi := Vector2(maxf(a.x, b.x) + half, maxf(a.z, b.z) + half)
	return Rect2(lo, hi - lo)


## A point in the camp `min_d`-`max_d` m from the player, in sight, as far from the office
## as can be (somebody at the edge of what you can see, facing it). {pos} or empty.
func _camp_spot(player_pos: Vector3, min_d: float, max_d: float) -> Dictionary:
	var r := _bounds().grow(-2.0)
	if r.size.x <= 0.0 or player_pos == Vector3.INF:
		return {}
	var office := _office_spot()
	var me := Vector2(player_pos.x, player_pos.z)
	var best := {}
	var best_d := -1.0
	var turn := _rng.randf() * TAU
	for i in 24:
		var ang := turn + TAU * float(i) / 24.0
		var p := me + Vector2(cos(ang), sin(ang)) * _rng.randf_range(min_d, max_d)
		if not r.has_point(p) or not _in_sight(player_pos, Vector3(p.x, 1.2, p.y)):
			continue
		var d := p.distance_to(Vector2(office.x, office.z)) if office != Vector3.INF else 0.0
		if d > best_d:
			best_d = d
			best = {"pos": Vector3(p.x, 0.0, p.y)}
	return best


## A point by the fence `min_d`-`max_d` m from the player, in sight ({pos, along}),
## `inset` m inside the fence (negative: outside it). Empty if there is none.
func _fence_spot(player_pos: Vector3, min_d: float, max_d: float, inset: float) -> Dictionary:
	var r := _bounds()
	if r.size == Vector2.ZERO or player_pos == Vector3.INF:
		return {}
	var edges := [
		[Vector2(r.position.x, r.end.y - inset), Vector2(r.end.x, r.end.y - inset)],
		[Vector2(r.position.x + inset, r.position.y), Vector2(r.position.x + inset, r.end.y)],
		[Vector2(r.end.x - inset, r.position.y), Vector2(r.end.x - inset, r.end.y)],
		[Vector2(r.position.x, r.position.y + inset), Vector2(r.end.x, r.position.y + inset)],
	]
	var me := Vector2(player_pos.x, player_pos.z)
	var candidates: Array = []
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := int(a.distance_to(b) / 2.0)
		for i in range(2, n - 1):
			var p := a.lerp(b, float(i) / float(n))
			var d := p.distance_to(me)
			if d < min_d or d > max_d or not _in_sight(player_pos, Vector3(p.x, 1.4, p.y)):
				continue
			var dir := (b - a).normalized()
			candidates.append({"pos": Vector3(p.x, 0.0, p.y), "along": Vector3(dir.x, 0.0, dir.y)})
	if candidates.is_empty():
		return {}
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _make_torch(parent: Node3D = null) -> Node3D:
	var root := Node3D.new()
	root.name = "OmenTorch"
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.6)
	light.light_energy = 1.6
	light.omni_range = 5.0
	root.add_child(light)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	bulb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.55)
	mat.emission_energy_multiplier = 3.0
	bulb.material_override = mat
	root.add_child(bulb)
	# The glow you see across the field: a soft billboard dot the night fog does not eat.
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	halo.mesh = quad
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.65, 0.9))
	grad.set_color(1, Color(1.0, 0.75, 0.4, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var hm := StandardMaterial3D.new()
	hm.albedo_texture = tex
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.disable_fog = true
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	(parent if parent != null else _world()).add_child(root)
	return root


## Someone standing still, facing the office: an ordinary guest sprite, in shadow.
func _make_figure(pos: Vector3, parent: Node3D = null) -> Node3D:
	var s := Sprite3D.new()
	s.name = "OmenFigure"
	if ResourceLoader.exists(FIGURE_SPRITE):
		s.texture = load(FIGURE_SPRITE)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Unlit and dim: a silhouette that reads against the night without a lamp on it.
	s.shaded = false
	s.modulate = Color(0.24, 0.24, 0.27)
	if s.texture != null:
		s.pixel_size = 1.8 / float(s.texture.get_height())
		s.offset = Vector2(0, s.texture.get_height() * 0.5)
	if parent != null:
		parent.add_child(s)
	else:
		_world().add_child(s)
		s.global_position = pos
	return s


func _clear_live() -> void:
	for id in _live.keys():
		var node = _live[id].get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_live.clear()


func _world() -> Node3D:
	var w = _main.get("_world_3d") if _main != null else null
	return w if w != null else self


func export_state() -> Dictionary:
	return {"seen": _seen.duplicate(), "last_night": _last_night, "quiet_until": _quiet_until}


func import_state(data: Dictionary) -> void:
	_clear_live()
	var s = data.get("seen", {})
	_seen = (s as Dictionary).duplicate() if s is Dictionary else {}
	_last_night = int(data.get("last_night", -1))
	_quiet_until = int(data.get("quiet_until", -1))
	_last_minute = -1


## Tools: where the live omens are (the shot driver's Expression has no ternaries).
func debug_live() -> Dictionary:
	var out := {}
	for id in _live.keys():
		var node = _live[id].get("node")
		if node != null and is_instance_valid(node):
			out[id] = node.global_position
	return out


## Tools: make `id` happen now if it can (scenario shots).
func debug_force(id: String, abs_minute: int, player_pos: Vector3) -> bool:
	return _play(id, abs_minute, player_pos)

