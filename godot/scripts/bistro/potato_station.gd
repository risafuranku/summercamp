extends "res://scripts/bistro/bistro_station.gd"

## The potato corner of the cellar (DESIGN.md §7b): the wall there is a Build texture
## (st_potatoes: the sack, the old enamel peeler drum on its stand, the chip cutter on
## its table, the bucket), the potatoes and the chips sprites in front of it in the room.
##   peel     the sack: four potatoes into the drum (off the books' shelf as each is cut);
##            the switch: it rumbles. Stop it when they are peeled (the column in the
##            green): too soon and they keep their skins (run it again), too long and one
##            is worn down to a marble (gone).
##   cut      a peeled potato into the cutter; pull the lever down (drag it down, or a
##            click): chips into the bucket. The bucket is the stove's (kitchen.gd prep
##            "chips_raw").

const SACK := Rect2(10, 200, 85, 125)
const DRUM := Rect2(105, 60, 150, 110)
const DRUM_C := Vector2(172, 100)
const SWITCH := Rect2(208, 120, 40, 40)
const CHUTE_AT := Vector2(258, 176)
const CUTTER := Rect2(380, 60, 190, 120)
const LEVER := Rect2(396, 18, 150, 124)
const GRID_AT := Vector2(470, 150)
const BUCKET := Rect2(262, 240, 82, 92)

var _drum := 0
var _run := -1.0
var _peel_t := 0.0
var _peeled := 0
var _in_cutter := false
var _lever := 0.0
var _pulling := false
var _drum_snd: AudioStreamPlayer
var _drum_spr: Array = []
var _chute_spr: Array = []
var _cut_spr: Sprite3D
var _heap: Array = []
var _peel_meter: Sprite3D


func _build() -> void:
	super._build()
	for i in RULES.PEEL_BATCH:
		_drum_spr.append(bsprite("potato_raw", true, 1.4))
	for i in 8:
		_chute_spr.append(bsprite("potato_peeled", true, 1.4))
	_cut_spr = bsprite("potato_peeled", true, 1.6)
	for i in 6:
		_heap.append(bsprite("chips_heap", true, 1.4))
	_peel_meter = meter(5, 20)
	_peel_meter.position = local_at(Vector2(DRUM.end.x + 4, DRUM.end.y - 10), 0.08)
	_drum_snd = AudioStreamPlayer.new()
	var path := "res://assets/sfx/bistro/peeler.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			st.loop = true
		_drum_snd.stream = st
	_drum_snd.volume_db = -8.0
	add_child(_drum_snd)


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var st := floorf(_t * 12.0)
	var shake := Vector2(float(int(st) % 2) * 2.0 - 1.0, 0.0) if _run >= 0.0 else Vector2.ZERO
	for i in _drum_spr.size():
		var spr: Sprite3D = _drum_spr[i]
		spr.visible = i < _drum
		if spr.visible:
			var a := st * 0.9 + i * 1.7 if _run >= 0.0 else i * 1.7
			bretex(spr, "potato_peeled" if RULES.peel_state(_peel_t) >= 1 else "potato_raw", 1.4)
			put(spr, DRUM_C + Vector2(cos(a) * 26.0, sin(a) * 12.0) + shake, 0.05)
	_peel_meter.visible = _drum > 0
	if _drum > 0:
		var ps := RULES.peel_state(_peel_t)
		set_meter(_peel_meter, _peel_t / 9.0, Vector2(RULES.PEEL_DONE / 9.0, RULES.PEEL_OVER / 9.0), [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][ps], ps == 2)
	for i in _chute_spr.size():
		var spr: Sprite3D = _chute_spr[i]
		spr.visible = i < _peeled
		put(spr, CHUTE_AT + Vector2(-24 + (i % 4) * 16, -4 + (i / 4) * 10), 0.06)
	_cut_spr.visible = _in_cutter
	if _in_cutter:
		var squash := floorf(_lever * 4.0) / 4.0
		_cut_spr.scale = Vector3(1.0 + squash * 0.3, 1.0 - squash * 0.6, 1.0)
		put(_cut_spr, GRID_AT + Vector2(0, -8.0 + squash * 10.0), 0.05)
	var chips := kitchen.prep(building_key, "chips_raw")
	for i in _heap.size():
		var spr: Sprite3D = _heap[i]
		spr.visible = i < chips
		put(spr, BUCKET.get_center() + Vector2(-16 + (i % 3) * 16, -30 - (i / 3) * 8), 0.05)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var stock: int = maxi(0, BUSINESS.stock_of(building_key, "potatoes"))
	if _drum == 0 and _run < 0.0 and stock > 0:
		out.append({"id": "sack", "rect": SACK, "verb": "Tip potatoes into the peeler (%d in the sack)" % stock})
	if _drum > 0:
		out.append({"id": "switch", "rect": SWITCH, "verb": "Stop the peeler" if _run >= 0.0 else "Start the peeler"})
	if _peeled > 0 and not _in_cutter:
		out.append({"id": "peeled", "rect": Rect2(CHUTE_AT - Vector2(40, 22), Vector2(80, 40)), "verb": "A peeled potato into the cutter (%d)" % _peeled})
	if _in_cutter:
		out.append({"id": "lever", "rect": LEVER, "verb": "Pull the lever down"})
	return out


func _press(id: String) -> void:
	match id:
		"sack":
			var stock: int = maxi(0, BUSINESS.stock_of(building_key, "potatoes"))
			var room_left := int(RULES.PREP_CAP["chips_raw"]) - kitchen.prep(building_key, "chips_raw") - _peeled
			var n := mini(mini(RULES.PEEL_BATCH, stock), room_left)
			if n <= 0:
				say("", "The bucket upstairs is full.")
				sfx("tick", -14.0, 0.7)
				return
			# Off the shelf as each one is cut (or lost in the drum), not now.
			_drum = n
			_peel_t = 0.0
			sfx("potatoes_tip", -6.0)
		"switch":
			if _run < 0.0:
				_run = 0.0
				if _drum_snd.stream != null:
					_drum_snd.play()
				sfx("switch", -8.0)
			else:
				_stop()
		"peeled":
			_peeled -= 1
			_in_cutter = true
			_lever = 0.0
			sfx("plate_down", -10.0, 0.7)
		"lever":
			_pulling = true


func _stop() -> void:
	_run = -1.0
	_drum_snd.stop()
	sfx("switch", -8.0, 0.8)
	match RULES.peel_state(_peel_t):
		0:
			say("", "Still in their skins.")
		1:
			_peeled += _drum
			_drum = 0
		_:
			# Worn down to marbles: one of them is gone.
			var lost := 1 if _drum > 0 else 0
			if lost > 0 and CoreRoot != null and CoreRoot.actions != null:
				CoreRoot.actions.biz_take(building_key, {"potatoes": 1})
			_peeled += _drum - lost
			_drum = 0
			pop("-%d" % lost, DRUM.get_center(), RETRO_UI.C_RED_LIGHT)
			say("", "Ran too long. One is a marble.")


func _release(id: String) -> void:
	if id == "lever":
		_pulling = false
		if _lever < 0.9:
			# Let go halfway: it springs back up. A click is a whole pull.
			if _lever < 0.1:
				_lever = 1.0
				_chop()
			else:
				_lever = 0.0


func _drag(at: Vector2) -> void:
	if not _pulling or at.x < -500.0:
		return
	_lever = clampf((at.y - LEVER.position.y) / LEVER.size.y, _lever, 1.0)
	if _lever >= 0.95:
		_pulling = false
		_chop()


func _chop() -> void:
	if not _in_cutter:
		return
	_in_cutter = false
	if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"potatoes": 1}):
		say("", "That was the last of the sack.")
		return
	kitchen.act(building_key, "prep", ["chips_raw", 1])
	pop("+1", BUCKET.get_center() + Vector2(0, -60), RETRO_UI.C_GREEN_LIGHT)
	sfx("chop", -4.0, randf_range(0.95, 1.05))


func _tick(delta: float) -> void:
	if _run >= 0.0:
		_run += delta
		_peel_t += delta
	if not _pulling and _lever > 0.0:
		_lever = maxf(0.0, _lever - delta * 4.0)


func _closing() -> void:
	# What is in the drum or by the chute was never taken off the shelf: back in the sack.
	if _run >= 0.0:
		_run = -1.0
		_drum_snd.stop()
	_drum = 0
	_peeled = 0
	_in_cutter = false


func bar_text() -> String:
	if kitchen == null:
		return ""
	return "RAW CHIPS %d  SACK %d" % [kitchen.prep(building_key, "chips_raw"), maxi(0, BUSINESS.stock_of(building_key, "potatoes"))]


# ── debug (tools/bistro_shots.gd) ────────────────────────────────────────────

func debug_click(id: String) -> void:
	if id == "lever":
		_lever = 1.0
		_chop()
	else:
		_press(id)
