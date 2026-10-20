extends Node3D

## The hands at work in a business's rooms (DESIGN.md §7b, the hands): each one on the
## shift now, come in today, stands at their job's place in their sprite at work
## (assets/textury/npc/staff/<slug>_work.png, Grok, the people of the ID photos); one
## whose place a warden has taken stands aside, idle. Somebody away today is not there.
## The one who worked here before is at his place at night too, when the place is shut
## and dark, and nobody asked him to be. Made by scripts/service_interior.gd for a room.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const STAFF_DIR := "res://assets/textury/npc/staff/"
## People are 128 px to 1.74 m (AGENTS.md "One pixel throughout").
const PERSON_M := 1.74
const STEP := 0.5

var key := ""
## role -> {root: Node3D (the room it is in), pos: Vector3 (on the floor, room space),
## station: the station id the role works at ("" none)}
var spots: Dictionary = {}
## -> [station ids a warden is at now]
var busy_of: Callable

var _figs: Dictionary = {}
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
		var aside := str(spot.get("station", "")) != "" and busy.has(str(spot["station"]))
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
