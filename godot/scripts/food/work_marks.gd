extends Node

## Where the work waits in the pub and the Jednota (the bistro has its own:
## scripts/bistro/bistro_marks.gd) (scripts/service_interior.gd
## makes one per room it builds): over each place a small Grok picture bobs while there
## is something to do there (assets/textury/ui/mark_*.png):
##   pub      the tap and the bottles while somebody waits to be served; the washer
##            when the clean mugs run out and dirty ones stand by it;
##   Jednota  the till while somebody waits at it; over the rack the picture of a good
##            gone from it (or a box, when the trolley has one with room for it); over
##            the packing table a carton when the trolley is bare and the storeroom has
##            what the rack lacks (scripts/jednota/jednota.gd).
## Not over the job you have open, nor over the one the other warden is at (co-op: they
## are behind the counter doing it). Stepped like the rest of the room (8 a second).

const BUSINESS = preload("res://scripts/business/business_runtime.gd")
const JEDNOTA_RULES = preload("res://core/systems/jednota_rules.gd")
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
	# scripts/jednota/jednota_layout.gd STATIONS[...]["mark"]; a picture may be a whole path.
	"vecerka": {
		"till": ["shop", Vector3(2.0, 1.7, -0.2), "mark_till"],
		"shelves": ["shop", Vector3(-0.75, 1.62, -2.25), "res://assets/textury/jednota/box_closed.png"],
		"store": ["store", Vector3(-0.2, 1.6, -1.62), "res://assets/textury/jednota/box_closed.png"],
		"deli": ["shop", Vector3(2.0, 1.7, -1.75), "res://assets/textury/jednota/parcel.png"],
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
## The Jednota: the good gone from the rack (its picture over the rack), or a box.
var _shelves_pic := ""
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
		if on and job == "shelves" and _shelves_pic != "" and ResourceLoader.exists(_shelves_pic):
			var tex: Texture2D = load(_shelves_pic)
			if m.texture != tex:
				m.texture = tex
				m.pixel_size = HEIGHT / float(maxi(1, tex.get_height()))
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
		"vecerka":
			var shop = _shop()
			if shop == null:
				if n > 0:
					out.append("till")
				return out
			if not shop.tickets(key).is_empty():
				out.append("till")
			if not shop.deli_tickets(key).is_empty():
				out.append("deli")
			var gone := ""
			var room_for_box := false
			var store_has := false
			var trolley_bare := true
			for g in JEDNOTA_RULES.all_goods():
				var on := int(shop.shelf(key).get(g, 0))
				var tr := int(shop.trolley(key).get(g, 0))
				if tr > 0:
					trolley_bare = false
					if on < int(shop.cap(key)):
						room_for_box = true
				if on == 0 and gone == "":
					gone = g
				if on + tr < int(shop.cap(key)) and shop.backroom(key, g) > 0:
					store_has = true
			if gone != "" or room_for_box:
				out.append("shelves")
				_shelves_pic = ("res://assets/textury/jednota/goods_%s.png" % gone) if gone != "" else "res://assets/textury/jednota/box_closed.png"
			if trolley_bare and store_has:
				out.append("store")
	return out



func _shop():
	var tree := get_tree()
	return tree.get_first_node_in_group("jednotas") if tree != null else null


func _make(job: String, spot: Array) -> Sprite3D:
	var parent: Node3D = roots.get(str(spot[0]), roots.get("", null))
	if parent == null or not is_instance_valid(parent):
		return null
	var path := str(spot[2]) if str(spot[2]).begins_with("res://") else DIR + str(spot[2]) + ".png"
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
