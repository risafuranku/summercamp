extends Node3D

## The hands at work in a business's rooms (DESIGN.md §7b, the hands): each one on the
## shift now, come in today, stands at their job's place in their sprite at work
## (assets/textury/npc/staff/<slug>_work.png, Grok, the people of the ID photos); one
## whose place a warden has taken stands aside, idle. Somebody away today is not there.
## The one who worked here before is at his place at night too, when the place is shut
## and dark, and nobody asked him to be. One who did not come in today left a note where
## they would stand (a click reads it). Made by scripts/service_interior.gd for a room.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
## Seen from eight sides as in Doom (scripts/figures/doom_figure.gd): a hand with a set
## faces their station (its mark over it) at work, in their work pose from every side, and
## standing aside faces the same way; without a set, the old sprite from the front.
const DOOM = preload("res://scripts/figures/doom_figure.gd")
const STAFF_DIR := "res://assets/textury/npc/staff/"
## People are 128 px to 1.74 m (AGENTS.md "One pixel throughout").
const PERSON_M := 1.74
const STEP := 0.5

var key := ""
## role -> {root: Node3D (the room it is in), pos: Vector3 (on the floor, room space),
## station: the station id the role works at ("" none), note: where the note of one away
## today is pinned (room space; over the place by default)}
var spots: Dictionary = {}
## -> [station ids a warden is at now]
var busy_of: Callable
## person -> the place (a role of `spots`) they work now, "" aside: where a place moves its
## hands about to work beside the wardens (the corn stand: cornstand.crew_places). Unset,
## each at their own job's place, aside while a warden is at it.
var place_of: Callable
## -> the station open on this machine ("" none): a hand standing between its camera and
## its counter steps aside too (spot "clear_of": the stations whose view they would block).
var open_of: Callable

var _figs: Dictionary = {}
## role -> the note of a hand away today (Sprite3D, with its look box).
var _notes: Dictionary = {}
const NOTE_TEX := "res://assets/textury/camp/note_away.png"
var _acc := 0.0
var _view_acc := 0.0
static var _tex: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := STAFF_DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func _process(delta: float) -> void:
	_tick_hand_overs(delta)
	# The picture for where you look from, twelve times a second (the room's camera moves).
	_view_acc += delta
	if _view_acc >= 1.0 / 12.0:
		_view_acc = 0.0
		var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
		if cam != null:
			for slug in _figs:
				var f = _figs[slug]
				if is_instance_valid(f) and f.has_meta("doom") and f.visible:
					(f.get_meta("doom") as DOOM).show(cam.global_position)
	_acc += delta
	if _acc < STEP:
		return
	_acc = 0.0
	refresh()


func refresh() -> void:
	var s := BUSINESS.site(key)
	var want := {}
	var busy: Array = busy_of.call() if busy_of.is_valid() else []
	var open := str(open_of.call()) if open_of.is_valid() else ""
	var people: Array = BUSINESS.crew_now(key)
	# The one who has worked here before: at his place in the dark when it is shut.
	if BUSINESS.shift_now(s) == "closed":
		for p in s.get("crew", []):
			if str(p.get("strange", "")) == "night":
				people.append(p)
	for p in people:
		var role := str(p.get("role", ""))
		var slug := str(p.get("slug", ""))
		var moved := ""
		if place_of.is_valid():
			moved = str(place_of.call(p))
			if moved != "" and spots.has(moved) and not want.has(moved):
				role = moved
		if not spots.has(role):
			continue
		if want.has(role):
			continue
		want[role] = slug
		var spot: Dictionary = spots[role]
		var fig: Sprite3D = _figs.get(slug, null)
		if fig == null or not is_instance_valid(fig) or fig.get_parent() != spot["root"]:
			if fig != null and is_instance_valid(fig):
				fig.queue_free()
			fig = _make(slug)
			(spot["root"] as Node3D).add_child(fig)
			_figs[slug] = fig
		var aside := (str(spot.get("station", "")) != "" and busy.has(str(spot["station"]))) or (open != "" and (spot.get("clear_of", []) as Array).has(open))
		# Moved about and nothing wanted anywhere: aside, at their own place.
		if place_of.is_valid() and moved == "":
			aside = true
		var pos: Vector3 = spot["pos"]
		if aside:
			pos += (spot.get("aside", Vector3(0.7, 0, 0.4)) as Vector3)
		fig.set_meta("base_pos", pos)
		fig.set_meta("aside", aside)
		fig.set_meta("role", role)
		fig.position = pos + _lean_of(slug)
		if fig.has_meta("doom"):
			var d: DOOM = fig.get_meta("doom")
			d.set_anim("stand" if aside or not d.has_anim("work") else "work")
			# Toward their station: the mark (the note's place) over it, else as they were.
			# (The figure's way is the camp's: the room's own turn put on it. At a turned
			# corn stand they stood facing away: playtest 25. 10.)
			var to: Vector3 = (spot.get("note", pos) as Vector3) - pos
			if Vector2(to.x, to.z).length() > 0.05:
				var room := spot["root"] as Node3D
				d.face(room.global_basis * to if room.is_inside_tree() else to)
			fig.visible = true
			continue
		var t := tex(slug if aside else slug + "_work")
		if t == null:
			t = tex(slug)
		fig.texture = t
		fig.visible = t != null
		fig.offset = Vector2(0, float(t.get_height()) * 0.5) if t != null else Vector2.ZERO
	_show_notes(s, want)
	for slug in _figs.keys():
		var keep := false
		for r in want:
			if str(want[r]) == str(slug):
				keep = true
		if not keep:
			if is_instance_valid(_figs[slug]):
				(_figs[slug] as Node).queue_free()
			_figs.erase(slug)


# ── handing over ────────────────────────────────────────────────────────────
# A hand serving: they lean in over their counter and back, and what they serve goes over
# to whoever takes it, in steps, twelve a second (the user 25. 10.: "the staff at the corn
# needs an animation of serving"; their sets are a standing and a working pose).
const LEAN_M := 0.13
const LEAN_SEC := 0.55
const OVER_SEC := 0.42
var _leans: Dictionary = {}     # slug -> [seconds in, the way they lean (room space)]
var _overs: Array = []          # {sprite, from, to, t}


## The hand at `role` hands `thing` over to `to` (room space, on the floor): false when
## nobody is at that place (away, or standing aside for a warden).
func hand_over(role: String, thing: Texture2D, to: Vector3, height_m := 0.2) -> bool:
	for slug in _figs:
		var fig: Sprite3D = _figs[slug]
		if not is_instance_valid(fig) or not fig.visible or str(fig.get_meta("role", "")) != role or bool(fig.get_meta("aside", true)):
			continue
		var spot: Dictionary = spots[role]
		var base: Vector3 = fig.get_meta("base_pos", fig.position)
		var way: Vector3 = (spot.get("note", base) as Vector3) - base
		way.y = 0.0
		way = way.normalized() if way.length() > 0.01 else Vector3(0, 0, 1)
		_leans[slug] = [0.0, way]
		if thing != null:
			var spr := Sprite3D.new()
			spr.texture = thing
			spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			spr.shaded = true
			spr.pixel_size = height_m / float(maxi(1, thing.get_height()))
			var from := base + way * 0.45 + Vector3(0, 1.0, 0)
			spr.position = from
			(spot["root"] as Node3D).add_child(spr)
			_overs.append({"sprite": spr, "from": from, "to": to + Vector3(0, 1.05, 0), "t": -LEAN_SEC * 0.4})
		return true
	return false


func _lean_of(slug: String) -> Vector3:
	if not _leans.has(slug):
		return Vector3.ZERO
	var l: Array = _leans[slug]
	var k := clampf(float(l[0]) / LEAN_SEC, 0.0, 1.0)
	# In and back on one swell, in steps as the sprites move.
	k = floorf(k * 7.0) / 7.0
	return (l[1] as Vector3) * LEAN_M * sin(k * PI)


func _tick_hand_overs(delta: float) -> void:
	for slug in _leans.keys():
		var l: Array = _leans[slug]
		l[0] = float(l[0]) + delta
		var fig: Sprite3D = _figs.get(slug, null)
		if fig != null and is_instance_valid(fig):
			fig.position = (fig.get_meta("base_pos", fig.position) as Vector3) + _lean_of(slug)
		if float(l[0]) >= LEAN_SEC:
			_leans.erase(slug)
	for o in _overs.duplicate():
		o["t"] = float(o["t"]) + delta
		var spr: Sprite3D = o["sprite"]
		if not is_instance_valid(spr):
			_overs.erase(o)
			continue
		var k := clampf(float(o["t"]) / OVER_SEC, 0.0, 1.0)
		k = floorf(k * OVER_SEC * 12.0) / maxf(1.0, OVER_SEC * 12.0)
		spr.visible = float(o["t"]) >= 0.0
		spr.position = (o["from"] as Vector3).lerp(o["to"], k) + Vector3(0, 0.12 * sin(k * PI), 0)
		if float(o["t"]) >= OVER_SEC + 0.15:
			spr.queue_free()
			_overs.erase(o)


func _make(slug: String) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "Hand_" + slug
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.pixel_size = PERSON_M / 128.0
	var set := DOOM.set_of(slug)
	if not set.is_empty():
		DOOM.new(s, set, PERSON_M * float(set.get("h", 128)) / 128.0)
	return s


func clear() -> void:
	for o in _overs:
		if is_instance_valid(o["sprite"]):
			(o["sprite"] as Node).queue_free()
	_overs.clear()
	_leans.clear()
	for slug in _figs:
		if is_instance_valid(_figs[slug]):
			(_figs[slug] as Node).queue_free()
	_figs.clear()
	for r in _notes:
		if is_instance_valid(_notes[r]):
			(_notes[r] as Node).queue_free()
	_notes.clear()


## Notes where the hands away today would stand (not where somebody else works the job).
func _show_notes(s: Dictionary, working: Dictionary) -> void:
	var day := int(CoreRoot.get_day()) if CoreRoot != null else -1
	var want := {}
	for p in s.get("crew", []):
		var role := str(p.get("role", ""))
		if int(p.get("absent", -1)) != day or not spots.has(role) or working.has(role):
			continue
		want[role] = str(p.get("name", "a hand"))
	for role in want:
		if _notes.has(role) and is_instance_valid(_notes[role]):
			continue
		if not ResourceLoader.exists(NOTE_TEX):
			continue
		var spot: Dictionary = spots[role]
		var n := Sprite3D.new()
		n.name = "AwayNote_" + str(role)
		n.texture = load(NOTE_TEX)
		n.pixel_size = 0.16 / float(maxi(1, n.texture.get_height()))
		n.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		n.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		n.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		n.shaded = true
		n.position = spot.get("note", (spot["pos"] as Vector3) + Vector3(0, 1.0, 0))
		var body := StaticBody3D.new()
		body.set_meta("interior_click_type", "bistro_look")
		body.set_meta("bistro_look", "A note in pencil from %s: not coming in today." % str(want[role]))
		body.set_meta("bistro_name", "note")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.2, 0.22, 0.2)
		shape.shape = box
		body.add_child(shape)
		# In a room not shown now its box is off till the room is (service_interior._bodies_live).
		body.set_meta("live_layer", body.collision_layer)
		if not (spot["root"] as Node3D).visible:
			body.collision_layer = 0
		n.add_child(body)
		(spot["root"] as Node3D).add_child(n)
		_notes[role] = n
	for role in _notes.keys():
		if not want.has(role):
			if is_instance_valid(_notes[role]):
				(_notes[role] as Node).queue_free()
			_notes.erase(role)
