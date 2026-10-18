extends Node

## Where the work waits in the pub, the bistro and the Jednota (scripts/service_interior.gd
## makes one per room it builds): over each place a small Grok picture bobs while there
## is something to do there (assets/textury/ui/mark_*.png):
##   pub      the tap and the bottles while somebody waits to be served; the washer
##            when the clean mugs run out and dirty ones stand by it;
##   bistro   the pass while somebody waits for a plate; the stove when nothing is
##            fried ahead (site.prep) and there is cheese or potatoes to fry;
##   Jednota  the till while somebody waits at it.
## Not over the job you have open, nor over the one the other warden is at (co-op: they
## are behind the counter doing it). Stepped like the rest of the room (8 a second).

const BUSINESS = preload("res://scripts/business/business_runtime.gd")
const DIR := "res://assets/textury/ui/"
const STEP := 0.125
const HEIGHT := 0.26

## job -> [room ("" any of the profile's), position in that room, picture]
const SPOTS := {
	"pub": {
		"tap": ["", Vector3(1.275, 1.86, -1.405), "mark_tap"],
		"shots": ["", Vector3(1.75, 2.12, -2.0), "mark_shot"],
		"wash": ["", Vector3(2.35, 1.52, -1.2), "mark_wash"],
	},
	"rest": {
		"hatch": ["kitchen", Vector3(0.0, 1.5, 0.25), "mark_plate"],
		# Seen from the dining room: over the kitchen door, the orders wait in there.
		"hatch_door": ["dining", Vector3(1.6, 2.32, -2.3), "mark_plate"],
		"fryer": ["kitchen", Vector3(0.0, 1.72, -2.02), "mark_pan"],
	},
	"vecerka": {
		"till": ["shop", Vector3(-1.43, 1.62, -0.35), "mark_till"],
	},
}

var profile := ""
var key := ""
## room -> Node3D the marks of that room hang under.
var roots: Dictionary = {}
## The jobs not to mark now (yours open, the other warden's): set by the room each frame.
var busy: Array = []
## Whoever waits in this building now (business_runtime's waiting list), read each step.
var waiting_count: Callable = func() -> int: return 0
## Shot driver: >= 0 pins how many wait.
var debug_waiting := -1

var _marks: Dictionary = {}   # job -> Sprite3D
var _acc := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < STEP:
		return
	_acc = 0.0
	var want := wanted()
	var spots: Dictionary = SPOTS.get(profile, {})
	for job in spots:
		var on: bool = want.has(job) and not busy.has(job)
		var m: Sprite3D = _marks.get(job, null)
		if on and m == null:
			m = _make(job, spots[job])
		if m == null:
			continue
		m.visible = on
		if on:
			# A bob and a beat, in steps.
			var beat := int(_t / STEP)
			var base: Vector3 = spots[job][1]
			m.position = base + Vector3(0.0, 0.035 if beat % 4 < 2 else 0.0, 0.0)
			m.modulate.a = 1.0 if beat % 8 < 6 else 0.75


## The jobs with work waiting now.
func wanted() -> Array:
	var out: Array = []
	var n := debug_waiting if debug_waiting >= 0 else int(waiting_count.call())
	var site := BUSINESS.site(key)
	match profile:
		"pub":
			if n > 0:
				out.append("tap")
				out.append("shots")
			var g: Dictionary = site.get("glasses", {})
			if not g.is_empty() and int(g.get("clean", 9)) < 4 and int(g.get("dirty", 0)) > 0:
				out.append("wash")
		"rest":
			if n > 0:
				out.append("hatch")
				out.append("hatch_door")
			var prep: Dictionary = site.get("prep", {})
			var stock: Dictionary = site.get("stock", {})
			if not prep.is_empty() and ((int(prep.get("cheese", 0)) < 2 and int(stock.get("cheese", 0)) > 0) or (int(prep.get("fries", 0)) < 2 and int(stock.get("potatoes", 0)) > 0)):
				out.append("fryer")
		"vecerka":
			if n > 0:
				out.append("till")
	return out


func _make(job: String, spot: Array) -> Sprite3D:
	var parent: Node3D = roots.get(str(spot[0]), roots.get("", null))
	if parent == null or not is_instance_valid(parent):
		return null
	var path := DIR + str(spot[2]) + ".png"
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var s := Sprite3D.new()
	s.name = "WorkMark_" + job
	s.texture = tex
	s.pixel_size = HEIGHT / float(maxi(1, tex.get_height()))
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 4
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.position = spot[1]
	parent.add_child(s)
	_marks[job] = s
	return s


func clear() -> void:
	for m in _marks.values():
		if m != null and is_instance_valid(m):
			m.queue_free()
	_marks.clear()
