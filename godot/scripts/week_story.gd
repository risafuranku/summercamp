extends Node

## The week, told in the camp (DESIGN.md §5e). Vera's story mails (data/pools/emails/
## story) say strange things; once a night from day 2 something in the camp quietly
## agrees with them. Each beat is one specific thing (a torch, a person, the barrier,
## the phone), short, deniable, never explained and never a jumpscare (DESIGN §2), and
## they close in on the office as the week goes on:
##
##   night 2  22:30  a torch walks the far fence ("Do not walk along the fence after
##                   the lamps go out. Your uncle did." comes on day 6)
##   night 3  23:00  after "count them again after 22:00": one guest too many, standing
##                   at the far edge of the camp, facing the office
##   night 4  02:58  the barrier lifts and drops by itself (the 03:00 night log mail:
##                   "02:58 gate closed")
##   night 6  01:00  the office phone rings four times ("somebody picked up and listened")
##   night 7  23:30  the person and the torch, together, at the fence by the office; the
##                   insects stop
##
## A figure or a torch is gone when you come within reach of it, or when its time is up.
## Played beats are remembered in the save; each plays once a week.

const FIGURE_SPRITE := "res://assets/textury/npc/host1.png"
const PHONE_SFX := "res://assets/sfx/uncanny/office_phone.mp3"

## id -> night (the day the night began), start hour (24+ = after midnight), minutes it lasts.
const BEATS := {
	"torch": {"night": 2, "at": 22.5, "minutes": 50},
	"one_more": {"night": 3, "at": 23.0, "minutes": 70},
	"barrier": {"night": 4, "at": 26.97, "minutes": 1},
	"phone": {"night": 6, "at": 25.0, "minutes": 1},
	"by_the_office": {"night": 7, "at": 23.5, "minutes": 60},
}
const VANISH_TORCH_M := 18.0
const VANISH_FIGURE_M := 14.0

var hush := 0.0                    # main adds this to the insects' silence
var _done: Dictionary = {}         # beat id -> true
var _live: Dictionary = {}         # beat id -> {"node": Node3D, "until": abs minute}
var _main: Node
var _torch_t := 0.0


func setup(main_node: Node) -> void:
	_main = main_node


func reset() -> void:
	_clear_live()
	_done.clear()
	hush = 0.0


## `abs_minute` counts from day 1 00:00. `outdoors`: the player is in the camp, not in
## an interior or a minigame (beats wait for that, so they are seen or heard).
func tick(delta: float, abs_minute: int, outdoors: bool, player_pos: Vector3) -> void:
	for id in BEATS.keys():
		if _done.has(id) or _live.has(id):
			continue
		var beat: Dictionary = BEATS[id]
		var start := int((int(beat["night"]) - 1) * 1440 + float(beat["at"]) * 60.0)
		var stop := start + int(beat["minutes"]) + 90
		if abs_minute >= start and abs_minute <= stop and outdoors:
			_play(id, abs_minute + int(beat["minutes"]), player_pos)
		elif abs_minute > stop:
			_done[id] = true  # missed: the week moves on without it
	_update_live(delta, abs_minute, player_pos)


## Figures and torches only appear in the dark at a distance you can still see across
## (24-36 m, at the fence nearest to you); never next to you. Until there is such a
## place the beat waits inside its window.
func _play(id: String, until: int, player_pos: Vector3) -> void:
	var spot := {}
	match id:
		"torch":
			spot = _fence_spot(player_pos, 22.0, 40.0, -1.5)
			if spot.is_empty():
				return
		"one_more":
			spot = _camp_spot(player_pos, 24.0, 32.0)
			if spot.is_empty():
				return
		"by_the_office":
			var at := _office_spot()
			if at == Vector3.INF or player_pos == Vector3.INF:
				return
			var d := Vector2(at.x - player_pos.x, at.z - player_pos.z).length()
			if d < 22.0 or d > 45.0:
				return
	_done[id] = true
	match id:
		"torch":
			var pos: Vector3 = spot["pos"]
			var along: Vector3 = spot["along"]
			var torch := _make_torch()
			torch.position = pos - along * 15.0
			torch.set_meta("from", pos - along * 15.0)
			torch.set_meta("to", pos + along * 15.0)
			_live[id] = {"node": torch, "until": until, "vanish": VANISH_TORCH_M}
		"one_more":
			var fig := _make_figure(spot["pos"])
			_live[id] = {"node": fig, "until": until, "vanish": VANISH_FIGURE_M}
		"barrier":
			var gate = get_tree().get_first_node_in_group("camp_gate")
			if gate != null and gate.has_method("open_briefly"):
				gate.open_briefly()
		"phone":
			var at: Vector3 = _main.call("get_reception_door_position") if _main != null and _main.has_method("get_reception_door_position") else Vector3.INF
			if at != Vector3.INF:
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
			var at := _office_spot()
			var root := Node3D.new()
			root.name = "StoryByTheOffice"
			_world().add_child(root)
			root.global_position = at
			_make_figure(at, root)
			var torch := _make_torch(root)
			torch.position = Vector3(0.45, 1.1, 0.0)
			_live[id] = {"node": root, "until": until, "vanish": VANISH_FIGURE_M + 4.0, "hush": true}


func _update_live(delta: float, abs_minute: int, player_pos: Vector3) -> void:
	_torch_t += delta
	var want_hush := 0.0
	for id in _live.keys():
		var entry: Dictionary = _live[id]
		var node: Node3D = entry["node"]
		if node == null or not is_instance_valid(node):
			_live.erase(id)
			continue
		if node.has_meta("from"):
			# The torch walks the fence at a stroll, swinging a little.
			var total := float(BEATS[id]["minutes"])
			var left := float(int(entry["until"]) - abs_minute)
			var t := clampf(1.0 - left / maxf(1.0, total), 0.0, 1.0)
			node.position = (node.get_meta("from") as Vector3).lerp(node.get_meta("to"), t)
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


## By the gate fence, a few metres west of the office door, just inside.
func _office_spot() -> Vector3:
	var at: Vector3 = _main.call("get_reception_door_position") if _main != null and _main.has_method("get_reception_door_position") else Vector3.INF
	var r := _bounds()
	if at == Vector3.INF or r.size == Vector2.ZERO:
		return Vector3.INF
	return Vector3(at.x - 6.0, 0.0, r.position.y + 1.5)


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


## A point in the camp `min_d`-`max_d` m from the player, as far from the office as can be
## (somebody at the edge of what you can see, facing it). {pos} or empty.
func _camp_spot(player_pos: Vector3, min_d: float, max_d: float) -> Dictionary:
	var r := _bounds().grow(-2.0)
	if r.size.x <= 0.0 or player_pos == Vector3.INF:
		return {}
	var office := _office_spot()
	var me := Vector2(player_pos.x, player_pos.z)
	var best := {}
	var best_d := -1.0
	for i in 24:
		var ang := TAU * float(i) / 24.0
		var p := me + Vector2(cos(ang), sin(ang)) * (min_d + max_d) * 0.5
		if not r.has_point(p) or not _in_sight(player_pos, Vector3(p.x, 1.2, p.y)):
			continue
		var d := p.distance_to(Vector2(office.x, office.z)) if office != Vector3.INF else 0.0
		if d > best_d:
			best_d = d
			best = {"pos": Vector3(p.x, 0.0, p.y)}
	return best


## A point by the fence `min_d`-`max_d` m from the player ({pos, along}), `inset` m inside
## the fence (negative: outside it). Empty if the fences are all too near or too far.
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
	var best := {}
	var best_score := INF
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := int(a.distance_to(b) / 2.0)
		for i in range(2, n - 1):
			var p := a.lerp(b, float(i) / float(n))
			var d := p.distance_to(me)
			if d < min_d or d > max_d or not _in_sight(player_pos, Vector3(p.x, 1.4, p.y)):
				continue
			var score := absf(d - (min_d + max_d) * 0.5)
			if score < best_score:
				best_score = score
				var dir := (b - a).normalized()
				best = {"pos": Vector3(p.x, 0.0, p.y), "along": Vector3(dir.x, 0.0, dir.y)}
	return best


func _make_torch(parent: Node3D = null) -> Node3D:
	var root := Node3D.new()
	root.name = "StoryTorch"
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
	hm.no_depth_test = false
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	(parent if parent != null else _world()).add_child(root)
	return root


## Someone standing still, facing the office: an ordinary guest sprite, in shadow.
func _make_figure(pos: Vector3, parent: Node3D = null) -> Node3D:
	var s := Sprite3D.new()
	s.name = "StoryFigure"
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
	return {"done": _done.keys()}


func import_state(data: Dictionary) -> void:
	_clear_live()
	_done.clear()
	for id in data.get("done", []):
		_done[str(id)] = true


## Tools: where the live beats are (the shot driver's Expression has no ternaries).
func debug_live() -> Dictionary:
	var out := {}
	for id in _live.keys():
		var node = _live[id].get("node")
		if node != null and is_instance_valid(node):
			out[id] = node.global_position
	return out
