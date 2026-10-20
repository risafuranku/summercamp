extends Node3D

## The hands at work in a business's rooms (DESIGN.md §7b, the hands): each one on the
## shift now, come in today, stands at their job's place in their sprite at work
## (assets/textury/npc/staff/<slug>_work.png, Grok, the people of the ID photos); one
## whose place a warden has taken stands aside, idle. Somebody away today is not there.
## The one who worked here before is at his place at night too, when the place is shut
## and dark, and nobody asked him to be. One who did not come in today left a note where
## they would stand (a click reads it). Made by scripts/service_interior.gd for a room.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
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
## -> the station open on this machine ("" none): a hand standing between its camera and
## its counter steps aside too (spot "clear_of": the stations whose view they would block).
var open_of: Callable

var _figs: Dictionary = {}
## role -> the note of a hand away today (Sprite3D, with its look box).
var _notes: Dictionary = {}
const NOTE_TEX := "res://assets/textury/camp/note_away.png"
var _acc := 0.0
static var _tex: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := STAFF_DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func _process(delta: float) -> void:
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
		if not spots.has(role):
			continue
		var slug := str(p.get("slug", ""))
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
		var t := tex(slug if aside else slug + "_work")
		if t == null:
			t = tex(slug)
		fig.texture = t
		fig.visible = t != null
		fig.offset = Vector2(0, float(t.get_height()) * 0.5) if t != null else Vector2.ZERO
		var pos: Vector3 = spot["pos"]
		if aside:
			pos += (spot.get("aside", Vector3(0.7, 0, 0.4)) as Vector3)
		fig.position = pos
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


func _make(slug: String) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "Hand_" + slug
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.pixel_size = PERSON_M / 128.0
	return s


func clear() -> void:
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
