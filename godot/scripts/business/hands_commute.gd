extends Node

## The businesses' hands come in by the morning bus and go home through the gate (the user
## 25. 10.: "the staff at the corn ... in the evening they leave through the gate for the
## bus, they come by the morning bus for the camp's opening"; 26. 10.: their own bus).
## Drawn from the clock on every machine, with no state of its own (who works today is
## the books', the hour is the camp's), so in co-op both wardens see the same hand at the
## same place:
##   in    a day hand comes up from the stop through the barrier off the works bus after
##         the night (bus_timetable.STAFF_ARRIVE; a little apart) and walks to their place;
##         a late hand comes off the 380's last run and walks in for the evening shift. A
##         building's hand goes in at its door and is gone; the corn stand's stands at
##         their place behind the counter till it opens. Still on the way when it opens,
##         they are not at work yet (business_runtime.crew_now leaves them out: nobody at
##         the counter, no figure behind it) till they get there.
##   out   when their shift is over, from their place the same way out to the road, for
##         the works bus after the closing (the day's and the late shift's)
##   boxes the van's boxes (docs/businesses.md, 25. 11. „Krabice u závory“): a place's hand
##         on shift fetches its box from the pallet by the barrier and carries it in. The
##         host gives a free box on the pallet to a hand of its place who is in (one box a
##         place at a time: actions.biz_box_carry "s<slug>" from the hour `t0`), every machine
##         draws the walk from that (to the pallet, back with the box in their arms; away from
##         their place meanwhile: business_runtime.arriving), the host puts the goods on the
##         shelves when they are back (biz_box_in).
## The way is the staffroom hands' (staff_runtime.way: the guests' grid, quicker on the
## paths); the figures the businesses' own (their Doom sets, standing, bobbing a step).

const INSTANCE = preload("res://scripts/instance/instance.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const DOOM := preload("res://scripts/figures/doom_figure.gd")
const DOOR_ANIM := preload("res://scripts/attractions/door_anim.gd")
const CREW := preload("res://scripts/business/crew_figures.gd")
const STAND := preload("res://scripts/business/corn_stand_life.gd")
const TIMES := preload("res://scripts/town/bus_timetable.gd")
const GEO := preload("res://scripts/geo/geo_data.gd")
const PALLET := preload("res://scripts/business/delivery_pallet.gd")
const BOX_SIZE := Vector3(0.46, 0.32, 0.36)
## How long a hand stands at the stop for the works bus at most (hours): past that there is
## none tonight and they are gone down the road.
const STOP_WAIT_H := 2.5
const PERSON_M := 1.74
## Their pace, in metres a game minute: the staffroom's hands' (at the guests' stroll the
## walk up from the bus took till eight and the place stood open with nobody in it).
const M_PER_MIN := 2.0
## When the day hands come through the barrier: the works bus at the stop after the night
## (it ends at 6:30), and the few steps up from it.
const DAY_IN: float = TIMES.STAFF_ARRIVE[0] + 2.0 / 60.0
## A late hand: off the 380's last run in (it stands at the camp till after six).
static func _late_in() -> float:
	return float(TIMES.CAMP_ARRIVE[TIMES.CAMP_ARRIVE.size() - 1]) + 2.0 / 60.0
const BOB_HZ := 2.4

var _figs: Dictionary = {}      # "key/slug" -> Sprite3D
var _carried: Dictionary = {}   # "key/slug/box" -> MeshInstance3D (the box in their arms)
var _ways: Dictionary = {}      # "key/slug/in|out/day" -> PackedVector3Array
var _t := 0.0
var _poll := 0.0
var _view := 0.0


func _main() -> Node:
	return INSTANCE.main_of(self) if is_inside_tree() else null


func _hour() -> float:
	var m := _main()
	return float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 12.0


func _staff_runtime() -> Node:
	return get_tree().get_first_node_in_group("staff_runtime") if is_inside_tree() else null


func _process(delta: float) -> void:
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		# The ways change as the camp is built.
		if int(_t) % 30 == 0:
			_ways.clear()
	_draw(delta)


## Where `key`'s place is in the camp: a building's door outside, or the corn stand's place
## of `role` behind its counter (then `stays` true: they stand there till it opens).
func _place_of(key: String, role: String) -> Dictionary:
	var m := _main()
	var bm = m.get("building_manager") if m != null else null
	var root: Node = bm.get_node_or_null("Structures") if bm != null else null
	if root == null:
		return {}
	var parts := key.split(":")
	if parts.size() != 2:
		return {}
	var o := Vector2i(int(parts[0]), int(parts[1]))
	for c in root.get_children():
		if not (c is Node3D) or c.get_meta("grid_origin", Vector2i(-99, -99)) != o:
			continue
		var s := c as Node3D
		if str(s.get_meta("building_type", "")) == "corn_stand":
			var at: Vector3 = STAND.CREW_AT.get(role, Vector3(0, 0, -0.9))
			return {"at": s.global_transform * at, "stays": true, "face": s.global_basis * Vector3(0, 0, 1)}
		var way: Dictionary = DOOR_ANIM.entry_points(s, 0)
		if way.is_empty():
			return {"at": s.global_position, "stays": false}
		return {"at": way["outside"], "stays": false}
	return {}


## Today's comings and goings at the hour `h`: [{id, slug, path, k (0..1 along), standing}].
func _now_walking(h: float) -> Array:
	var out: Array = []
	var st = INSTANCE.core(self).get_state() if CoreRoot != null else null
	if st == null or not (st.biz is Dictionary):
		return out
	var sr := _staff_runtime()
	if sr == null or not sr.has_method("way"):
		return out
	var road: Vector3 = sr.road_spot()
	if road == Vector3.INF:
		return out
	var day := int(INSTANCE.core(self).get_day())
	var sites: Dictionary = st.biz.get("sites", {})
	for key in sites:
		var s: Dictionary = sites[key]
		var late := bool(s.get("late", false))
		var n := 0
		for p in s.get("crew", []):
			n += 1
			if int(p.get("absent", -1)) == day or str(p.get("strange", "")) != "" or int(p.get("since", 0)) > day:
				continue
			var slug := str(p.get("slug", ""))
			var role := str(p.get("role", ""))
			var place := _place_of(str(key), role)
			if place.is_empty():
				continue
			var shift := str(p.get("shift", "day"))
			# A little apart, off the bus one after another.
			var lag := float(n % 4) * 1.5 / 60.0
			var come := (DAY_IN + lag) if shift == "day" else (_late_in() + lag)
			var opens := float(BUSINESS.OPEN_HOUR) if shift == "day" else float(RULES.DAY_CLOSE)
			var ends := (float(RULES.DAY_CLOSE) if shift == "day" else float(RULES.LATE_CLOSE)) + lag
			if shift == "late" and not late:
				continue
			var id := "%s/%s" % [key, slug]
			var path_in := _way(id + "/in/%d" % day, sr, road, place["at"])
			var walk_h := maxf(1.0, _len(path_in) / M_PER_MIN) / 60.0
			# A late hand off the 380 takes their time at the stop: in a few minutes before
			# their shift (not standing by the day's hand at the stand for an hour).
			if shift == "late":
				come = maxf(come, opens - walk_h - 5.0 / 60.0 + lag)
			if h >= come and h < come + walk_h:
				out.append({"id": id, "slug": slug, "path": path_in, "k": (h - come) / walk_h, "in": true, "key": str(key)})
			elif bool(place.get("stays", false)) and h >= come + walk_h and h < opens:
				out.append({"id": id, "slug": slug, "path": PackedVector3Array([place["at"], place["at"] + (place.get("face", Vector3.FORWARD) as Vector3) * 0.2]), "k": 0.0, "standing": true})
			elif (h + 24.0 if h < 6.0 else h) >= ends:
				# Out through the barrier and on down the road to the stop, to wait there
				# for the works bus (they went out of being just past the barrier: the
				# user 4. 11.).
				var hh := h + 24.0 if h < 6.0 else h
				var path_out := _way(id + "/out/%d" % day, sr, place["at"], road)
				if not _ways.has(id + "/home/%d" % day):
					var home := PackedVector3Array(path_out)
					home.append(_camp_stop(road))
					_ways[id + "/home/%d" % day] = home
				path_out = _ways[id + "/home/%d" % day]
				var out_h := maxf(1.0, _len(path_out) / M_PER_MIN) / 60.0
				var gone := ends + out_h
				for t in TIMES.STAFF_LEAVE:
					if float(t) >= gone and float(t) - gone < STOP_WAIT_H:
						gone = float(t)
						break
				if hh < gone:
					var k := (hh - ends) / out_h
					out.append({"id": id, "slug": slug, "path": path_out, "k": minf(k, 1.0), "standing": k >= 1.0})
	_box_walks(out, sr, road)
	return out


## The game's hour since the camp began (day 1 at 0).
func _abs_h() -> float:
	return float(int(INSTANCE.core(self).get_day()) - 1) * 24.0 + _hour()


func _role_of(key: String, slug: String) -> String:
	var st = INSTANCE.core(self).get_state()
	for p in ((st.biz.get("sites", {}) as Dictionary).get(key, {}) as Dictionary).get("crew", []):
		if str(p.get("slug", "")) == slug:
			return str(p.get("role", ""))
	return ""


## The hands' fetches of the van's boxes (see the head): given out (the host), walked.
func _box_walks(out: Array, sr: Node, road: Vector3) -> void:
	var st = INSTANCE.core(self).get_state()
	var boxes: Array = (st.biz as Dictionary).get("boxes", [])
	var fetching := {}
	var gate := get_tree().get_first_node_in_group("camp_gate") if get_tree() != null else null
	if boxes.is_empty() or gate == null:
		PALLET.fetching = fetching
		return
	var pal := PALLET.spot(gate) + Vector3(0.9, 0.0, 0.0)
	pal.y = road.y
	var now := _abs_h()
	var host: bool = not INSTANCE.coop(self).is_client()
	var busy := {}
	for bx in boxes:
		if str(bx.get("by", "")).begins_with("s"):
			busy[str(bx["key"])] = true
	var done: Array = []
	for bx in boxes:
		var key := str(bx["key"])
		var by := str(bx.get("by", ""))
		if by.begins_with("s") and bx.has("t0"):
			var slug := by.substr(1)
			var place := _place_of(key, _role_of(key, slug))
			if place.is_empty():
				continue
			var go := _way("%s/%s/box/%d" % [key, slug, int(bx["id"])], sr, place["at"], pal)
			var leg := maxf(0.5, _len(go) / M_PER_MIN) / 60.0
			var t0 := float(bx["t0"])
			var id := "%s/%s/box" % [key, slug]
			if now < t0 + leg:
				fetching[int(bx["id"])] = true
				out.append({"id": id, "slug": slug, "path": go, "k": (now - t0) / leg, "away": true})
			elif now < t0 + 2.0 * leg:
				var back := PackedVector3Array(go)
				back.reverse()
				out.append({"id": id, "slug": slug, "path": back, "k": (now - t0 - leg) / leg, "away": true, "box": true})
			elif host:
				done.append(int(bx["id"]))
		elif by == "" and not bx.has("at") and host and not busy.has(key):
			var crew: Array = BUSINESS.crew_now(key)
			if not crew.is_empty():
				busy[key] = true
				INSTANCE.core(self).actions.biz_box_carry(int(bx["id"]), "s" + str((crew[0] as Dictionary).get("slug", "")), now)
	for id2 in done:
		INSTANCE.core(self).actions.biz_box_in(id2)
	PALLET.fetching = fetching


## Where the hands wait for the bus: by the camp's stop, on the ground.
func _camp_stop(fallback: Vector3) -> Vector3:
	var s: Dictionary = GEO.stop_point("camp")
	var p = s.get("p", s.get("pos", null))
	if p is Vector2:
		return Vector3((p as Vector2).x, fallback.y, (p as Vector2).y)
	if p is Vector3:
		return Vector3((p as Vector3).x, fallback.y, (p as Vector3).z)
	return fallback


func _way(cache: String, sr: Node, a: Vector3, b: Vector3) -> PackedVector3Array:
	if not _ways.has(cache):
		_ways[cache] = sr.way(a, b)
	return _ways[cache]


static func _len(path: PackedVector3Array) -> float:
	var d := 0.0
	for i in range(1, path.size()):
		d += path[i - 1].distance_to(path[i])
	return d


## The point `k` (0..1) of the way along `path`, and the way it goes there.
static func _along(path: PackedVector3Array, k: float) -> Array:
	var d := _len(path) * clampf(k, 0.0, 1.0)
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if d <= seg or i == path.size() - 1:
			var t := 0.0 if seg < 0.001 else clampf(d / seg, 0.0, 1.0)
			return [path[i - 1].lerp(path[i], t), path[i] - path[i - 1]]
		d -= seg
	return [path[path.size() - 1] if path.size() > 0 else Vector3.ZERO, Vector3.FORWARD]


func _draw(delta: float) -> void:
	var m := _main()
	var world: Node3D = m.get("_world_3d") if m != null else null
	if world == null:
		BUSINESS.arriving = {}
		return
	var walking := _now_walking(_hour())
	# Who is still on the way in: not at work yet (business_runtime.crew_now).
	var arriving := {}
	for w in walking:
		if bool(w.get("in", false)):
			arriving[str(w["id"])] = true
		elif bool(w.get("away", false)):
			# Gone to fetch a box: not at their place meanwhile.
			arriving[str(w["id"]).trim_suffix("/box")] = true
	BUSINESS.arriving = arriving
	var seen := {}
	_view += delta
	var view_now := _view >= 1.0 / 12.0
	if view_now:
		_view = 0.0
	var cam := world.get_viewport().get_camera_3d() if world.is_inside_tree() else null
	for w in walking:
		var id := str(w["id"])
		seen[id] = true
		var spr: Sprite3D = _figs.get(id, null)
		if spr == null or not is_instance_valid(spr):
			spr = _make(str(w["slug"]))
			world.add_child(spr)
			_figs[id] = spr
		var r := _along(w["path"], float(w["k"]))
		var at: Vector3 = r[0]
		var dir: Vector3 = r[1]
		if not bool(w.get("standing", false)):
			# The step bob, twelve times a second.
			var ph := floorf((_t + float(absi(hash(id)) % 100) * 0.01) * 12.0) / 12.0
			at.y += absf(sin(ph * TAU * BOB_HZ * 0.5)) * 0.04
		spr.position = at
		_carry_box(id, at, bool(w.get("box", false)), world, cam)
		if spr.has_meta("doom"):
			var d: DOOM = spr.get_meta("doom")
			d.set_anim("stand")
			d.face(dir)
			if view_now and cam != null:
				d.show(cam.global_position)
	for id in _figs.keys():
		if not seen.has(id):
			if is_instance_valid(_figs[id]):
				(_figs[id] as Node).queue_free()
			_figs.erase(id)
	for id2 in _carried.keys():
		if not seen.has(id2):
			if is_instance_valid(_carried[id2]):
				(_carried[id2] as Node).queue_free()
			_carried.erase(id2)


## The box in a hand's arms on the way back from the pallet: at their chest, a little toward
## your eye (in front of their picture).
func _carry_box(id: String, at: Vector3, on: bool, world: Node3D, cam: Camera3D) -> void:
	var m: MeshInstance3D = _carried.get(id, null)
	if not on:
		if m != null and is_instance_valid(m):
			m.visible = false
		return
	if m == null or not is_instance_valid(m):
		m = MeshInstance3D.new()
		m.name = "CarriedBox"
		var bm := BoxMesh.new()
		bm.size = BOX_SIZE
		m.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(1.4, 1.4, 1.4)
		if ResourceLoader.exists(PALLET.BOX_TEX):
			mat.albedo_texture = load(PALLET.BOX_TEX)
		m.material_override = mat
		world.add_child(m)
		_carried[id] = m
	var toward := Vector3.ZERO
	if cam != null:
		toward = cam.global_position - at
		toward.y = 0.0
		toward = toward.normalized() * 0.28 if toward.length() > 0.01 else Vector3.ZERO
	m.visible = true
	m.global_position = at + Vector3(0, 1.0, 0) + toward


func _exit_tree() -> void:
	BUSINESS.arriving = {}


func _make(slug: String) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "Commuter_" + slug
	s.add_to_group("gate_users")
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.pixel_size = PERSON_M / 128.0
	var set := DOOM.set_of(slug)
	if not set.is_empty():
		DOOM.new(s, set, PERSON_M * float(set.get("h", 128)) / 128.0)
	else:
		var t := CREW.tex(slug)
		s.texture = t
		if t != null:
			s.offset = Vector2(0, float(t.get_height()) * 0.5)
	return s
