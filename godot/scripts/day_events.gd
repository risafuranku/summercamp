extends Node

## The day (DESIGN.md §5c). By day the camp should sound and feel lived in, and small
## things go wrong that only the warden sorts out. Left alone, each one costs: moods,
## money, a review. The night has its jobs (scripts/night_jobs.gd); the day has these.
##
## Each morning a few events are planned for the day (two on day 1, up to five with a
## full camp), spread between 08:30 and 18:30:
##   litter    rubbish dumped by a facility: hold E to bag it
##   raccoons  raccoons in the bins behind the bistro / shop / pub: E to shoo them
##   delivery  the Jednota van at the gate: E to sign for it (else no fresh bread)
##   lost_kid  a family's boy has wandered off (families only): find him, E
##   noise     tramps or lads keeping the quiet ones awake: talk to the loud party
##   tree      a branch down across a path after the wind: hold E to saw it up
## Each one pages you, shows in the HUD's TODAY list and gets the waypoint.
##
## Life (P7): loops at the facilities while guests are about (kids at the slide,
## football, the guitar at the fire, the pub through its door) and far-off one-shots
## (an axe, a dog, a moped on the road) so the camp is never silent by day.

signal changed

const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const FIRST_HOUR := 8.5
const LAST_HOUR := 18.5
const REACH := 3.4
const SFX := "res://assets/sfx/life/"
const KID_SPRITE := "res://assets/textury/npc/host_kid.png"
const RACCOON_SPRITE := "res://assets/textury/npc/raccoon.png"

## kind -> how long it may wait (minutes), what it costs left alone, what fixing it pays.
const RULES := {
	"litter": {"wait": 180, "hold": 1.4, "fail_mood": -6.0, "ok_mood": 2.0},
	"raccoons": {"wait": 90, "hold": 0.0, "fail_mood": -4.0, "fail_money": 40, "ok_mood": 1.0},
	"delivery": {"wait": 60, "hold": 0.0, "fail_mood": -5.0, "ok_mood": 1.0},
	"lost_kid": {"wait": 180, "hold": 0.0, "fail_mood": -20.0, "ok_mood": 12.0, "tip": 30},
	"noise": {"wait": 120, "hold": 0.0, "fail_mood": -15.0, "ok_mood": 4.0},
	"tree": {"wait": 240, "hold": 3.0, "fail_mood": -4.0, "ok_mood": 2.0},
}

## Facility -> loop, who makes it, when.
const LIFE_LOOPS := {
	"lake_slide": {"file": "kids_slide.mp3", "from": 9.5, "to": 19.5, "db": -6.0},
	"sports_field": {"file": "football.mp3", "from": 10.0, "to": 19.0, "db": -7.0},
	"bonfire": {"file": "guitar_fire.mp3", "from": 17.0, "to": 23.5, "db": -5.0},
	"pub": {"file": "pub_chatter.mp3", "from": 11.0, "to": 23.5, "db": -6.0},
}
const LIFE_ONESHOTS := ["axe.mp3", "dog_far.mp3", "moped.mp3"]

var _events: Array = []
var _planned_day := -1
var _next_id := 1
var _props: Dictionary = {}   # event id -> Node3D
var _main: Node
var _rng := RandomNumberGenerator.new()
var _target_id := -1
var _work := 0.0
var _work_player: AudioStreamPlayer3D
var _loops: Dictionary = {}   # "x:y" -> AudioStreamPlayer3D
var _life_t := 2.0
var _oneshot_t := 30.0
var _anim_t := 0.0
var _last_abs := 0


func setup(main_node: Node) -> void:
	_main = main_node
	_rng.randomize()


func reset() -> void:
	for id in _props.keys():
		_free_props(int(id))
	_events.clear()
	_planned_day = -1
	_target_id = -1
	for k in _loops.keys():
		if is_instance_valid(_loops[k]):
			_loops[k].queue_free()
	_loops.clear()


## Every frame. `can_act`: first-person, nothing open.
func tick(delta: float, abs_minute: int, is_day: bool, day_index: int, can_act: bool) -> void:
	_anim_t += delta
	_last_abs = abs_minute
	var hour := float(posmod(abs_minute, 1440)) / 60.0
	if is_day and hour >= 7.0 and _planned_day != day_index:
		_plan(day_index, abs_minute)
	for ev in _events:
		match str(ev["state"]):
			"pending":
				if abs_minute >= int(ev["at"]):
					_start(ev, abs_minute)
			"open":
				if abs_minute >= int(ev["deadline"]):
					_fail(ev)
				elif str(ev["kind"]) == "noise" and not _guest_exists(int(ev.get("guest_id", -1))):
					_close(ev, "done", "")
	_animate_props()
	_update_target(delta, can_act)
	_life_t -= delta
	if _life_t <= 0.0:
		_life_t = 3.0
		_update_life(hour)
	_oneshot_t -= delta
	if _oneshot_t <= 0.0:
		_oneshot_t = _rng.randf_range(35.0, 110.0)
		if hour >= 7.0 and hour <= 20.0:
			_play_far_oneshot()


## Night falls: what is still open is lost (it was a day's chance).
func on_night() -> void:
	for ev in _events:
		if str(ev["state"]) == "open":
			_fail(ev)
		elif str(ev["state"]) == "pending":
			ev["state"] = "cancelled"
	changed.emit()


func hud_rows() -> Array:
	var rows: Array = []
	for ev in _events:
		if str(ev["state"]) == "open":
			rows.append({"title": ev["title"], "where": ev["where"]})
	return rows


func open_events() -> Array:
	return _events.filter(func(e): return str(e["state"]) == "open").map(func(e): return e.duplicate())


func waypoint(from: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for ev in _events:
		if str(ev["state"]) != "open":
			continue
		var p := _event_pos(ev)
		if p == Vector3.INF:
			continue
		var d := from.distance_to(p)
		if d < best_d:
			best_d = d
			best = {"position": p + Vector3(0, 2.4, 0), "label": str(ev["short"])}
	return best


## Hint for the thing in front of the player ("" when nothing).
func hint() -> String:
	var ev := _event_by_id(_target_id)
	if ev.is_empty():
		return ""
	match str(ev["kind"]):
		"litter":
			return "[HOLD E] Bag the rubbish"
		"raccoons":
			return "[E] Shoo the raccoons"
		"delivery":
			return "[E] Sign for the Jednota delivery"
		"lost_kid":
			return "[E] \"Come on, your mum is looking for you.\""
		"tree":
			return "[HOLD E] Saw up the branch"
	return ""


## E pressed. True when it was for a day event (instant ones resolve here).
func try_interact() -> bool:
	var ev := _event_by_id(_target_id)
	if ev.is_empty():
		return false
	if float((RULES[str(ev["kind"])] as Dictionary).get("hold", 0.0)) > 0.0:
		return true
	_resolve(ev)
	return true


## The player talked to a guest (main._talk_to_guest): settles a noise complaint.
func on_talked_to(guest: Dictionary) -> void:
	for ev in _events:
		if str(ev["state"]) == "open" and str(ev["kind"]) == "noise" and int(ev.get("guest_id", -1)) == int(guest.get("id", -2)):
			_resolve(ev)
			_report("%s: \"Fine, fine. We'll keep it down.\"" % str(guest.get("name", "They")), 1)


func export_state() -> Dictionary:
	var evs: Array = []
	for ev in _events:
		if str(ev["state"]) == "open" or str(ev["state"]) == "pending":
			evs.append(ev.duplicate(true))
	return {"events": evs, "planned_day": _planned_day, "next_id": _next_id}


func import_state(data: Dictionary) -> void:
	reset()
	_planned_day = int(data.get("planned_day", -1))
	_next_id = int(data.get("next_id", 1))
	for e in data.get("events", []):
		if e is Dictionary:
			var ev: Dictionary = e
			_events.append(ev)
			if str(ev["state"]) == "open":
				_spawn_props(ev)
	changed.emit()


# ── debug (shot driver) ───────────────────────────────────────────────────────

## Starts one event of `kind` now. Returns it, or {} when the camp has nothing for it.
func debug_start(kind: String) -> Dictionary:
	var ev := _make(kind, _last_abs, _active_guests())
	if ev.is_empty():
		return {}
	_events.append(ev)
	_start(ev, _last_abs)
	return ev


## Puts the player `dist` metres from the newest open event, looking at it.
func debug_goto(dist: float = 2.4) -> void:
	var player = _main.get("_player")
	for i in range(_events.size() - 1, -1, -1):
		var ev: Dictionary = _events[i]
		if str(ev["state"]) != "open":
			continue
		var p := _event_pos(ev)
		if p == Vector3.INF:
			return
		var from := p + Vector3(dist, 0.0, dist * 0.4).normalized() * dist
		player.global_position = _ground(from) + Vector3(0, 0.1, 0)
		var to := p - from
		player.rotation.y = atan2(-to.x, -to.z)
		var head = player.get_node_or_null("Head")
		if head != null:
			head.rotation.x = -0.25
		return


# ── planning ──────────────────────────────────────────────────────────────────

func _plan(day_index: int, abs_minute: int) -> void:
	_planned_day = day_index
	_events = _events.filter(func(e): return str(e["state"]) == "open")
	var guests := _active_guests()
	var count := clampi(1 + int(ceil(float(day_index) / 2.0)) + (1 if guests.size() >= 4 else 0), 2, 5)
	var pool := _available_kinds(guests)
	if pool.is_empty():
		return
	pool.shuffle()
	var kinds: Array = []
	for k in pool:
		if kinds.size() >= count:
			break
		kinds.append(k)
	# A second lot of rubbish when there is room for it.
	if kinds.size() < count and pool.has("litter"):
		kinds.append("litter")
	var day_start := abs_minute - posmod(abs_minute, 1440)
	var start := maxi(abs_minute + 20, day_start + int(FIRST_HOUR * 60.0))
	var end := day_start + int(LAST_HOUR * 60.0)
	if end <= start:
		return
	for i in kinds.size():
		var at := start + int(float(end - start) * (float(i) + _rng.randf_range(0.1, 0.9)) / float(kinds.size()))
		var ev := _make(str(kinds[i]), at, guests)
		if not ev.is_empty():
			_events.append(ev)
	changed.emit()


func _available_kinds(guests: Array) -> Array:
	var out: Array = ["litter"]
	if not _coords_of(["restaurant", "vecerka", "pub"]).is_empty():
		out.append("raccoons")
		out.append("delivery")
	var arch := guests.map(func(g): return str(g.get("archetype", "")))
	if arch.has("family"):
		out.append("lost_kid")
	var loud := arch.has("tramp") or arch.has("drunk")
	var quiet := arch.has("picker") or arch.has("quiet_guy") or arch.has("family")
	if loud and quiet:
		out.append("noise")
	if not _coords_of(["path"]).is_empty() and (_rng.randf() < 0.45 or _windy()):
		out.append("tree")
	return out


func _make(kind: String, at: int, guests: Array) -> Dictionary:
	var ev := {"id": _next_id, "kind": kind, "at": at, "state": "pending", "deadline": at + int(RULES[kind]["wait"]), "coord": [-1, -1]}
	_next_id += 1
	match kind:
		"litter":
			var c := _pick(["bonfire", "pub", "restaurant", "lake_slide", "sports_field", "vecerka", "shower_block", "toilet_block"])
			if c.x < 0:
				c = _pick(["path"])
			if c.x < 0:
				return {}
			var label := _label_at(c)
			ev.merge({"title": "Rubbish dumped", "short": "Rubbish", "where": "By the %s" % label, "coord": [c.x, c.y], "label": label}, true)
		"raccoons":
			var r := _pick(["restaurant", "vecerka", "pub"])
			if r.x < 0:
				return {}
			ev.merge({"title": "Raccoons in the bins", "short": "Raccoons", "where": "Behind the %s" % _label_at(r), "coord": [r.x, r.y]}, true)
		"delivery":
			ev.merge({"title": "Jednota delivery", "short": "Van", "where": "At the gate: sign for it", "gate": true}, true)
		"lost_kid":
			var fam: Array = guests.filter(func(g): return str(g.get("archetype", "")) == "family")
			if fam.is_empty():
				return {}
			var g: Dictionary = fam[_rng.randi_range(0, fam.size() - 1)]
			var spot := _edge_spot()
			ev.merge({"title": "A boy is missing", "short": "Boy", "where": "%s: he was here a minute ago" % str(g.get("name", "The family")), "coord": [spot.x, spot.y], "guest_id": int(g.get("id", -1)), "family": str(g.get("name", "The family"))}, true)
		"noise":
			var loud: Array = guests.filter(func(g): return ["tramp", "drunk"].has(str(g.get("archetype", ""))))
			if loud.is_empty():
				return {}
			var g2: Dictionary = loud[_rng.randi_range(0, loud.size() - 1)]
			ev.merge({"title": "Noise complaint", "short": "Noise", "where": "Talk to %s" % str(g2.get("name", "them")), "guest_id": int(g2.get("id", -1)), "guest_name": str(g2.get("name", ""))}, true)
		"tree":
			var p := _pick(["path"])
			if p.x < 0:
				return {}
			ev.merge({"title": "A branch across the path", "short": "Branch", "where": "Path %d:%d" % [p.x, p.y], "coord": [p.x, p.y]}, true)
	return ev


func _start(ev: Dictionary, abs_minute: int) -> void:
	ev["deadline"] = abs_minute + int(RULES[str(ev["kind"])]["wait"])
	if str(ev["kind"]) == "noise" and not _guest_exists(int(ev.get("guest_id", -1))):
		ev["state"] = "cancelled"
		return
	if str(ev["kind"]) == "lost_kid" and not _guest_exists(int(ev.get("guest_id", -1))):
		ev["state"] = "cancelled"
		return
	ev["state"] = "open"
	_spawn_props(ev)
	var line := ""
	match str(ev["kind"]):
		"litter":
			line = "Someone has dumped a bin bag by the %s. Guests are complaining." % str(ev.get("label", "path"))
		"raccoons":
			line = "Something is in the bins behind the %s." % _label_at(_coord(ev))
		"delivery":
			line = "The Jednota van is at the gate. The driver will not wait long."
		"lost_kid":
			line = "%s: \"Have you seen our boy? Red cap. He was right here.\"" % str(ev.get("family", "The family"))
		"noise":
			line = "Complaint: \"%s are making a racket. Some of us came here for the quiet.\"" % str(ev.get("guest_name", "Somebody"))
		"tree":
			line = "A branch has come down across the path at %d:%d." % [_coord(ev).x, _coord(ev).y]
	_report("Pager: %s" % line, 2)
	_page()
	changed.emit()


func _resolve(ev: Dictionary) -> void:
	var rules: Dictionary = RULES[str(ev["kind"])]
	var text := ""
	match str(ev["kind"]):
		"litter":
			text = "Rubbish bagged."
		"raccoons":
			text = "The raccoons are gone. For now."
			_sfx_at("shoo.mp3", _event_pos(ev), 0.0)
		"delivery":
			text = "Signed for the delivery. Fresh rohliky at the shop."
		"lost_kid":
			text = "Found the boy. %s: \"Thank God. Here, for your trouble.\" +$%d" % [str(ev.get("family", "The family")), int(rules.get("tip", 0))]
			if CoreRoot.actions != null:
				CoreRoot.actions.add_money(int(rules.get("tip", 0)))
			_mood_for(float(rules["ok_mood"]), "They found him. Good staff here.", ["family"])
		"noise":
			text = "The noise is down. For tonight."
		"tree":
			text = "The path is clear."
	if str(ev["kind"]) != "lost_kid":
		_mood_for(float(rules.get("ok_mood", 0.0)), "", [])
	_close(ev, "done", text)


func _fail(ev: Dictionary) -> void:
	var rules: Dictionary = RULES[str(ev["kind"])]
	var text := ""
	var thought := ""
	var who: Array = []
	match str(ev["kind"]):
		"litter":
			text = "Nobody bagged the rubbish by the %s." % str(ev.get("label", "path"))
			thought = "Rubbish everywhere by the %s. Nobody picks it up." % str(ev.get("label", "path"))
		"raccoons":
			text = "The raccoons got into the stores: -$%d." % int(rules.get("fail_money", 0))
			thought = "Something got into the food. Lovely."
			if CoreRoot.actions != null:
				CoreRoot.actions.add_money(-int(rules.get("fail_money", 0)))
		"delivery":
			text = "The Jednota van left. No fresh bread today."
			thought = "No bread at the shop. In a camp. Unbelievable."
		"lost_kid":
			text = "The boy came back by himself at dusk. He will not say where he was."
			thought = "He came back by himself. He keeps humming something."
			who = ["family"]
		"noise":
			text = "Nobody did anything about the noise."
			thought = "Nobody did anything about the racket. Never again."
			who = ["picker", "quiet_guy", "family"]
		"tree":
			text = "The branch is still across the path."
			thought = "A tree across the path all day. Is anyone running this place?"
	_mood_for(float(rules.get("fail_mood", 0.0)), thought, who)
	_close(ev, "failed", text)


func _close(ev: Dictionary, state: String, text: String) -> void:
	ev["state"] = state
	_free_props(int(ev["id"]))
	if _target_id == int(ev["id"]):
		_target_id = -1
		_work = 0.0
		_clear_work()
	if not text.is_empty():
		_report(text, 1 if state == "done" else 3)
	changed.emit()


# ── the player at it ──────────────────────────────────────────────────────────

func _update_target(delta: float, can_act: bool) -> void:
	var cam := _camera()
	var best := -1
	if can_act and cam != null:
		var best_score := INF
		var fwd := -cam.global_transform.basis.z
		for ev in _events:
			if str(ev["state"]) != "open" or str(ev["kind"]) == "noise":
				continue
			var p := _event_pos(ev) + Vector3(0, 0.5, 0)
			var to := p - cam.global_position
			var d := to.length()
			var reach := REACH + (2.5 if str(ev["kind"]) == "delivery" else 0.0)
			if d > reach or d < 0.01:
				continue
			var dot := (to / d).dot(fwd)
			if dot < 0.6:
				continue
			var score := d * (2.0 - dot)
			if score < best_score:
				best_score = score
				best = int(ev["id"])
	if best != _target_id:
		_target_id = best
		_work = 0.0
		_clear_work()
	var ev := _event_by_id(_target_id)
	if ev.is_empty():
		return
	var hold := float((RULES[str(ev["kind"])] as Dictionary).get("hold", 0.0))
	if hold <= 0.0:
		return
	if can_act and InputMap.has_action("interact") and Input.is_action_pressed("interact"):
		if _work <= 0.0:
			_sfx_at("saw_log.mp3" if str(ev["kind"]) == "tree" else "", _event_pos(ev), -2.0)
		_work += delta / hold
		var hud = _hud()
		if hud != null and hud.has_method("set_work_progress"):
			hud.set_work_progress("SAWING" if str(ev["kind"]) == "tree" else "BAGGING RUBBISH", _work)
		if _work >= 1.0:
			_resolve(ev)
	elif _work > 0.0:
		_work = 0.0
		_clear_work()


func _clear_work() -> void:
	var hud = _hud()
	if hud != null and hud.has_method("clear_work_progress"):
		hud.clear_work_progress()


# ── props in the world ────────────────────────────────────────────────────────

func _spawn_props(ev: Dictionary) -> void:
	var world := _world()
	if world == null:
		return
	var pos := _event_pos(ev)
	if pos == Vector3.INF:
		return
	var root := Node3D.new()
	root.name = "DayEvent_%s" % str(ev["kind"])
	world.add_child(root)
	root.global_position = pos
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ev["id"]) * 7919
	match str(ev["kind"]):
		"litter":
			var bag := _box(root, Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.45), Color(0.08, 0.08, 0.09))
			bag.rotation.y = rng.randf() * TAU
			_box(root, Vector3(0.05, 0.53, 0.0), Vector3(0.12, 0.08, 0.1), Color(0.08, 0.08, 0.09))
			for k in ["cans", "papers", "bottles"]:
				var m: Dictionary = INTERIOR_PREP.build_mess(root, Vector3(rng.randf_range(-0.7, 0.7), 0.02, rng.randf_range(-0.7, 0.7)), k, rng)
				(m["body"] as Node).queue_free()
		"raccoons":
			_cylinder(root, Vector3(0, 0.45, 0), 0.3, 0.9, Color(0.42, 0.44, 0.42))
			var lid := _cylinder(root, Vector3(0.4, 0.04, 0.2), 0.32, 0.04, Color(0.38, 0.4, 0.38))
			lid.rotation.z = 0.2
			for i in 2:
				var s := _sprite(root, RACCOON_SPRITE, 0.55, Vector3(-0.5 + i * 0.9, 0.0, 0.55 - i * 0.3))
				s.set_meta("hop", float(i) * 1.3)
			_loop_at(root, "raccoons_bin.mp3", -4.0, 18.0)
		"delivery":
			# An old white Avia van, JEDNOTA on the side.
			var white := Color(0.86, 0.86, 0.82)
			_box(root, Vector3(0, 1.25, -0.5), Vector3(2.0, 1.9, 3.2), white)
			_box(root, Vector3(0, 1.0, 1.65), Vector3(2.0, 1.4, 1.1), white)
			_box(root, Vector3(0, 1.45, 2.21), Vector3(1.7, 0.5, 0.02), Color(0.2, 0.26, 0.3))
			_box(root, Vector3(0, 0.6, -0.5), Vector3(2.04, 0.16, 3.24), Color(0.2, 0.42, 0.2))
			for x in [-0.95, 0.95]:
				for z in [-1.4, 1.5]:
					var w := _cylinder(root, Vector3(x, 0.38, z), 0.38, 0.25, Color(0.08, 0.08, 0.08))
					w.rotation.z = PI * 0.5
			for side in [-1.0, 1.0]:
				var l := Label3D.new()
				l.text = "JEDNOTA"
				l.font_size = 48
				l.pixel_size = 0.005
				l.modulate = Color(0.12, 0.4, 0.14)
				l.outline_size = 0
				l.position = Vector3(side * 1.015, 1.45, -0.5)
				l.rotation.y = side * PI * 0.5
				root.add_child(l)
			_loop_at(root, "van_horn.mp3", -6.0, 40.0, true)
		"lost_kid":
			var kid := _sprite(root, KID_SPRITE, 1.2, Vector3.ZERO)
			kid.set_meta("sway", 1.0)
		"tree":
			# A birch from the camp's own woods (its bark and leaf textures), lying across
			# the path: trunk, a crown of leaf clumps, a few snapped twigs.
			var wg = _main.get("world_generator") if _main != null else null
			var fallen := Node3D.new()
			root.add_child(fallen)
			fallen.rotation.y = rng.randf() * TAU
			var bark := _tree_mat(wg, "birch_bark", 0, Color(0.85, 0.83, 0.78))
			var leaf := _tree_mat(wg, "leaf", 1, Color(0.4, 0.58, 0.28))
			var trunk := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.09
			cyl.bottom_radius = 0.17
			cyl.height = 4.4
			cyl.radial_segments = 7
			trunk.mesh = cyl
			trunk.material_override = bark
			trunk.rotation.z = PI * 0.5
			trunk.position = Vector3(0, 0.16, 0)
			fallen.add_child(trunk)
			for i in 5:
				var blob := MeshInstance3D.new()
				var sm := SphereMesh.new()
				var r := rng.randf_range(0.45, 0.8)
				sm.radius = r
				sm.height = r * 1.5
				sm.radial_segments = 7
				sm.rings = 4
				blob.mesh = sm
				blob.material_override = leaf
				blob.position = Vector3(-1.6 - rng.randf_range(0.0, 1.4), r * 0.55, rng.randf_range(-0.7, 0.7))
				fallen.add_child(blob)
			for i in 3:
				var twig := _cylinder(root, Vector3(rng.randf_range(-1.2, 1.2), 0.05, rng.randf_range(-0.8, 0.8)), 0.03, 0.8, Color(0.36, 0.26, 0.16))
				twig.rotation = Vector3(0, rng.randf() * TAU, PI * 0.5)
	_props[int(ev["id"])] = root


func _free_props(id: int) -> void:
	var n = _props.get(id, null)
	if n != null and is_instance_valid(n):
		n.queue_free()
	_props.erase(id)


func _animate_props() -> void:
	for id in _props.keys():
		var root: Node3D = _props[id]
		if not is_instance_valid(root):
			continue
		for c in root.get_children():
			if c is Sprite3D and c.has_meta("hop"):
				var ph := float(c.get_meta("hop"))
				(c as Sprite3D).position.y = absf(sin(_anim_t * 5.0 + ph)) * 0.12
				(c as Sprite3D).flip_h = sin(_anim_t * 0.7 + ph) > 0.0
			elif c is Sprite3D and c.has_meta("sway"):
				(c as Sprite3D).rotation.z = sin(_anim_t * 1.3) * 0.03


## The camp's tree textures (world_generator) on a plain material: the wind shader
## sways by height, which is wrong for a tree lying on its side.
func _tree_mat(wg, kind: String, variant: int, fallback: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = fallback
	if wg != null and wg.has_method("_tree_material"):
		var wind = wg.call("_tree_material", kind, variant)
		if wind is ShaderMaterial:
			var tex = (wind as ShaderMaterial).get_shader_parameter("albedo_tex")
			if tex is Texture2D:
				mat.albedo_texture = tex
				var c = (wind as ShaderMaterial).get_shader_parameter("albedo_color")
				mat.albedo_color = (c as Color).clamp() if c is Color else Color.WHITE
	return mat


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = INTERIOR_PREP.flat(color)
	parent.add_child(m)
	return m


func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	m.mesh = c
	m.position = pos
	m.material_override = INTERIOR_PREP.flat(color)
	parent.add_child(m)
	return m


func _sprite(parent: Node3D, path: String, height_m: float, pos: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	if ResourceLoader.exists(path):
		s.texture = load(path)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	if s.texture != null:
		s.pixel_size = height_m / float(s.texture.get_height())
	s.centered = true
	s.offset = Vector2(0, s.texture.get_height() * 0.5 if s.texture != null else 0.0)
	s.position = pos
	parent.add_child(s)
	return s


# ── life ──────────────────────────────────────────────────────────────────────

func _update_life(hour: float) -> void:
	var world := _world()
	if world == null:
		return
	var guests := _active_guests()
	var arch := guests.map(func(g): return str(g.get("archetype", "")))
	var raining := false
	if _main != null and _main.has_method("_is_raining_weather_active"):
		raining = bool(_main.call("_is_raining_weather_active"))
	var wanted := {}
	for type in LIFE_LOOPS.keys():
		var rule: Dictionary = LIFE_LOOPS[type]
		if hour < float(rule["from"]) or hour > float(rule["to"]) or guests.is_empty():
			continue
		if raining and type != "pub":
			continue
		if type == "bonfire" and not (arch.has("tramp") or hour >= 19.0):
			continue
		if type == "sports_field" and not (arch.has("drunk") or arch.has("family") or arch.has("tramp")):
			continue
		for c in _coords_of([type]):
			wanted["%d:%d" % [c.x, c.y]] = [c, rule]
	# Kids by the tents while a family is in.
	if arch.has("family") and hour >= 8.0 and hour <= 20.0 and not raining:
		var tents := _coords_of(["tent_1", "tent_2", "tent_3", "cabin_1", "cabin_2", "cabin_3"])
		if not tents.is_empty():
			wanted["kids"] = [tents[0], {"file": "kids_play.mp3", "db": -9.0}]
	for k in _loops.keys():
		if not wanted.has(k):
			if is_instance_valid(_loops[k]):
				_loops[k].queue_free()
			_loops.erase(k)
	for k in wanted.keys():
		if _loops.has(k) and is_instance_valid(_loops[k]):
			continue
		var c: Vector2i = wanted[k][0]
		var rule2: Dictionary = wanted[k][1]
		var p := _ground(_grid_world(c)) + Vector3(0, 1.2, 0)
		var player := _sfx_at(str(rule2["file"]), p, float(rule2["db"]), 34.0, true)
		if player != null:
			_loops[k] = player


func _play_far_oneshot() -> void:
	var cam := _camera()
	if cam == null:
		return
	var a := _rng.randf() * TAU
	var p := cam.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(30.0, 45.0)
	_sfx_at(LIFE_ONESHOTS[_rng.randi_range(0, LIFE_ONESHOTS.size() - 1)], p, -8.0, 80.0)


func _sfx_at(file: String, pos: Vector3, db: float, max_dist := 30.0, loop := false) -> AudioStreamPlayer3D:
	var world := _world()
	if world == null or file.is_empty() or pos == Vector3.INF or not ResourceLoader.exists(SFX + file):
		return null
	var p := AudioStreamPlayer3D.new()
	var stream = load(SFX + file)
	if loop and stream is AudioStreamMP3:
		stream = (stream as AudioStreamMP3).duplicate()
		(stream as AudioStreamMP3).loop = true
	p.stream = stream
	p.volume_db = db
	p.max_distance = max_dist
	p.unit_size = 6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	world.add_child(p)
	p.global_position = pos
	p.play()
	if not loop:
		p.finished.connect(p.queue_free)
	return p


func _loop_at(root: Node3D, file: String, db: float, max_dist: float, repeat_only := false) -> void:
	var p := _sfx_at(file, root.global_position + Vector3(0, 0.8, 0), db, max_dist, not repeat_only)
	if p == null:
		return
	p.reparent(root)
	if repeat_only:
		# A horn now and then, not a drone.
		var t := Timer.new()
		t.wait_time = 25.0
		t.autostart = true
		root.add_child(t)
		t.timeout.connect(func(): if is_instance_valid(p): p.play())


# ── helpers ───────────────────────────────────────────────────────────────────

func _event_by_id(id: int) -> Dictionary:
	if id < 0:
		return {}
	for ev in _events:
		if int(ev["id"]) == id and str(ev["state"]) == "open":
			return ev
	return {}


func _coord(ev: Dictionary) -> Vector2i:
	var c: Array = ev.get("coord", [-1, -1])
	return Vector2i(int(c[0]), int(c[1]))


func _event_pos(ev: Dictionary) -> Vector3:
	if bool(ev.get("gate", false)):
		var gate := get_tree().get_first_node_in_group("camp_gate") if is_inside_tree() else null
		if gate == null:
			return Vector3.INF
		return _ground(Vector3(float(gate.get("gap_center_x")) + 4.2, 0.0, float(gate.get("fence_z")) + 5.0))
	if str(ev["kind"]) == "noise":
		return _guest_pos(int(ev.get("guest_id", -1)))
	var c := _coord(ev)
	if c.x < 0:
		return Vector3.INF
	var p := _grid_world(c)
	# Beside the building, not in it (the side away from the camp centre... any side).
	if str(ev["kind"]) in ["litter", "raccoons"]:
		var off := Vector3(1.6, 0, 1.1) if (c.x + c.y) % 2 == 0 else Vector3(-1.5, 0, -1.2)
		p += off
	return _ground(p)


func _grid_world(c: Vector2i) -> Vector3:
	var gm = _main.get("grid_manager") if _main != null else null
	if gm == null:
		return Vector3.INF
	return gm.grid_to_world(c)


func _ground(p: Vector3) -> Vector3:
	if p == Vector3.INF:
		return p
	var world := _world()
	if world == null or world.get_world_3d() == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 30, 0), p + Vector3(0, -30, 0))
	q.collide_with_areas = false
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() and float(hit["position"].y) < p.y + 3.0 else p


## A spot near the camp's edge, among the trees: where a boy would wander off to.
func _edge_spot() -> Vector2i:
	var gm = _main.get("grid_manager") if _main != null else null
	var w := int(gm.get("grid_width")) if gm != null else 20
	var h := int(gm.get("grid_height")) if gm != null else 20
	var side := _rng.randi_range(0, 3)
	match side:
		0:
			return Vector2i(1, _rng.randi_range(2, h - 3))
		1:
			return Vector2i(w - 2, _rng.randi_range(2, h - 3))
		2:
			return Vector2i(_rng.randi_range(2, w - 3), h - 2)
		_:
			return Vector2i(_rng.randi_range(2, w - 3), 2)


func _label_at(c: Vector2i) -> String:
	var state = CoreRoot.get_state()
	if state == null or not state.grid.cells.has(c):
		return "path"
	var type := str(state.grid.cells[c].get("type", ""))
	var def = CoreRoot.registry.get_def(StringName(type))
	return (str(def.display_name).split(" (")[0] if def != null else type.capitalize()).to_lower()


func _coords_of(types: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return out
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		if cell.get("root_coord", coord) == coord and types.has(str(cell.get("type", ""))):
			out.append(coord)
	return out


func _pick(types: Array) -> Vector2i:
	var all := _coords_of(types)
	if all.is_empty():
		return Vector2i(-1, -1)
	return all[_rng.randi_range(0, all.size() - 1)]


func _active_guests() -> Array:
	var out: Array = []
	var state = CoreRoot.get_state()
	if state == null:
		return out
	for g in state.guests:
		if g is Dictionary and str((g as Dictionary).get("status", "")) == "active":
			out.append(g)
	return out


func _guest_exists(id: int) -> bool:
	return _active_guests().any(func(g): return int(g.get("id", -2)) == id)


func _guest_pos(id: int) -> Vector3:
	var agents = _main.get("_guest_agents") if _main != null else null
	if agents != null and agents.has_method("guest_world_position"):
		return agents.guest_world_position(id)
	return Vector3.INF


## Moves the mood of the guests (all, or those of `archetypes`) and gives them a line.
func _mood_for(delta: float, thought: String, archetypes: Array) -> void:
	if delta == 0.0 or GuestManager == null or not GuestManager.has_method("apply_camp_event"):
		return
	GuestManager.apply_camp_event(delta, thought, archetypes)


func _windy() -> bool:
	if _main == null:
		return false
	var w = _main.get("_weather_state")
	return w != null and int(w) in [1, 5]


func _camera() -> Camera3D:
	if _main != null and _main.has_method("_get_player_camera"):
		return _main.call("_get_player_camera")
	return null


func _world() -> Node3D:
	return _main.get("_world_3d") if _main != null else null


func _hud():
	return _main.get("_hud_manager") if _main != null else null


func _report(text: String, kind: int) -> void:
	var hud = _hud()
	if hud != null:
		hud.push_status(text, kind, "day_events")


func _page() -> void:
	var hud = _hud()
	if hud != null and hud.has_method("page"):
		hud.page()
