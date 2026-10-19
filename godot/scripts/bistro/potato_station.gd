extends "res://scripts/bistro/station_view.gd"

## The potato corner of the cellar (assets/textury/bistro/st_potatoes.png): the sack at
## the left, the old enamel peeler drum, the chip cutter on its table, the bucket.
##   peel     click the sack: four potatoes into the drum (off the books' shelf as each
##            one is cut); click
##            the switch: it rumbles. Stop it when they are peeled (the bar's green): too
##            soon and they keep their skins (run it again), too long and one is worn
##            down to a marble (gone).
##   cut      click a peeled potato: into the cutter; pull the lever down (drag it, or a
##            click): chips into the bucket. The bucket is the stove's (the trays are
##            the kitchen's: kitchen.gd prep "chips_raw").

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const SACK := Rect2(10, 200, 85, 125)
const DRUM := Rect2(105, 60, 150, 110)
const SWITCH := Rect2(212, 124, 34, 34)
const CHUTE_AT := Vector2(258, 170)
const CUTTER := Rect2(380, 60, 190, 120)
const LEVER := Rect2(396, 18, 150, 124)
const GRID_AT := Vector2(470, 155)
const BUCKET := Rect2(262, 240, 82, 92)

var _drum := 0          # potatoes in the drum
var _run := -1.0        # seconds running, -1 off
var _peel_t := 0.0      # how long these have been in it
var _peeled := 0        # peeled, waiting by the chute
var _in_cutter := false
var _lever := 0.0       # 0 up .. 1 down
var _pulling := false
var _drum_snd: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	station = "potatoes"
	how = "Sack: potatoes into the drum. Switch on, off when the bar is green. A peeled one into the cutter, pull the lever."
	room = "basement"
	picture = tex("st_potatoes")
	for n in ["potato_raw", "potato_peeled", "chips_heap", "chips_bucket", "peelings"]:
		tex(n)
	_drum_snd = AudioStreamPlayer.new()
	var path := "res://assets/sfx/bistro/peeler.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			st.loop = true
		_drum_snd.stream = st
	_drum_snd.volume_db = -8.0
	add_child(_drum_snd)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var stock: int = maxi(0, BUSINESS.stock_of(building_key, "potatoes"))
	if _drum == 0 and _run < 0.0:
		out.append({"id": "sack", "rect": SACK, "verb": ("Tip potatoes into the peeler (%d in the sack)" % stock) if stock > 0 else "The sack is empty: order potatoes in the books"})
	if _drum > 0:
		out.append({"id": "switch", "rect": SWITCH, "verb": "Stop the peeler" if _run >= 0.0 else "Start the peeler"})
	if _peeled > 0 and not _in_cutter:
		out.append({"id": "peeled", "rect": Rect2(CHUTE_AT - Vector2(50, 30), Vector2(100, 46)), "verb": "Put a peeled potato in the cutter (%d)" % _peeled})
	if _in_cutter:
		out.append({"id": "lever", "rect": LEVER, "verb": "Pull the lever down"})
	return out


func _press(id: String) -> void:
	match id:
		"sack":
			var stock: int = maxi(0, BUSINESS.stock_of(building_key, "potatoes"))
			var room := int(RULES.PREP_CAP["chips_raw"]) - kitchen.prep(building_key, "chips_raw") - _peeled
			var n := mini(mini(RULES.PEEL_BATCH, stock), room)
			if n <= 0:
				say("", "The bucket upstairs is full." if stock > 0 else "No potatoes. Order some in the books.")
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
			say("", "Still in their skins. Run it again.")
		1:
			_peeled += _drum
			_drum = 0
			say("", "Peeled.")
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
	if not _pulling or at.x < 0.0:
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
	pop("+1", BUCKET.get_center() + Vector2(0, -30), RETRO_UI.C_GREEN_LIGHT)
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


func _paint(c: Control) -> void:
	if kitchen == null:
		return
	var st := floorf(_t * 12.0)
	# The drum: potatoes tumbling in it while it runs, the bar for how peeled.
	var shake := Vector2(0, 0)
	if _run >= 0.0:
		shake = Vector2((int(st) % 2) * 2 - 1, 0)
	for i in _drum:
		var a := st * 0.9 + i * 1.7 if _run >= 0.0 else i * 1.7
		var p := Vector2(172, 100) + Vector2(cos(a) * 26.0, sin(a) * 14.0) + shake
		blit(c, "potato_peeled" if RULES.peel_state(_peel_t) >= 1 else "potato_raw", p)
	if _drum > 0:
		var r := Rect2(DRUM.position.x + 10, DRUM.end.y + 12, DRUM.size.x - 20, 6)
		meter(c, r, _peel_t / 9.0, Vector2(RULES.PEEL_DONE / 9.0, RULES.PEEL_OVER / 9.0), [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][RULES.peel_state(_peel_t)])
		if _run >= 0.0 and int(st) % 6 < 3:
			ink(c, SWITCH.position + Vector2(36, 20), "ON", RETRO_UI.C_RED_LIGHT)
	# Peeled ones by the chute.
	for i in _peeled:
		blit(c, "potato_peeled", CHUTE_AT + Vector2(-30 + i * 18, -6 + (i % 2) * 4))
	# The cutter: the potato on the grid, pressed through it as the lever comes down; an
	# arrow by the lever while it waits for the pull.
	if _in_cutter:
		var t := tex("potato_peeled")
		if t != null:
			var sz := t.get_size() * float(PIX) * Vector2(1.0 + _lever * 0.3, 1.0 - _lever * 0.6)
			c.draw_texture_rect(t, Rect2((GRID_AT + Vector2(-sz.x * 0.5, -sz.y - 4.0 + _lever * 10.0)).floor(), sz.floor()), false)
		if _lever < 0.05 and int(st) % 12 < 8:
			ink(c, Vector2(LEVER.position.x + 6, LEVER.position.y + 30 + (int(st) % 12) * 2), "PULL", RETRO_UI.C_AMBER_LIGHT)
			ink(c, Vector2(LEVER.position.x + 14, LEVER.position.y + 44 + (int(st) % 12) * 2), "v", RETRO_UI.C_AMBER_LIGHT, RETRO_UI.FONT_BIG, 10)
	# The bucket of raw chips (the stove's).
	var chips := kitchen.prep(building_key, "chips_raw")
	if chips > 0:
		for i in mini(chips, 6):
			blit(c, "chips_heap", BUCKET.get_center() + Vector2(-14 + (i % 3) * 14, -26 - (i / 3) * 8))
	ink(c, BUCKET.position + Vector2(-4, -20), "RAW CHIPS %d" % chips, RETRO_UI.C_BONE)
	ink(c, SACK.position + Vector2(4, -6), "SACK %d" % maxi(0, BUSINESS.stock_of(building_key, "potatoes")), RETRO_UI.C_BONE)
