extends CanvasLayer

## Your gloved hand at a station (the brief of 20. 10., "our hands at every station"):
## the right hand in the work glove comes up from the bottom of the view with the
## station's tool in it (the tongs, the brush, the salt, the tap's handle, the opener, the
## knife...), Duke 3D style: whole pictures (hands_lo/st_*), twelve a second, never turned,
## on the hands' pixel grid (Hands.px), lit like the other hands (Hands.material) and
## swaying with them (Hands.motion). It goes after the pointer in steps and reaches as far
## up the view as the arm goes; off the work it sinks. A press is phased like a weapon:
## the wind-up (the rest picture raised), the act (its own picture, held while the button
## is), the follow-through (the act picture dropped a little), back to rest.
## Made by scripts/business/station3d.gd while a station is open; the station says which
## tool is in the hand now (`hand_tool()`).

const HANDS = preload("res://scripts/ui/hands.gd")
const DIR := "res://assets/textury/hands_lo/"
const FPS := 12.0
## tool -> its pictures: rest, act (pressed). Where a picture's tool works (the tongs'
## tips, the fingertip, the cup's rim) is its topmost end (`_tip_of`), put towards the
## pointer. A tool whose pictures are not there yet falls back to the bare glove ("open").
const TOOLS := {
	"open": {"rest": "st_open", "act": "st_grab"},
	"press": {"rest": "st_open", "act": "st_press"},
	"tongs": {"rest": "st_tongs", "act": "st_tongs_cob"},
	"brush": {"rest": "st_brush", "act": "st_brush_stroke"},
	"salt": {"rest": "st_salt", "act": "st_salt_shake"},
	"husk": {"rest": "st_open", "act": "st_husk"},
	"cup": {"rest": "st_cup", "act": "st_cup_tea"},
	# The pub (two-frame Grok sheets: rest, act).
	"tap": {"rest": "st_tap", "act": "st_tap_act"},
	"bottle": {"rest": "st_bottle", "act": "st_bottle_act"},
	"wash": {"rest": "st_wash", "act": "st_wash_act"},
	"pencil": {"rest": "st_pencil", "act": "st_pencil_act"},
	"coin": {"rest": "st_coin", "act": "st_coin_act"},
	"dart": {"rest": "st_dart", "act": "st_dart_act"},
	# The bistro, the Jednota's deli counter.
	"ladle": {"rest": "st_ladle", "act": "st_ladle_act"},
	"opener": {"rest": "st_opener", "act": "st_opener_act"},
	"knife": {"rest": "st_knife", "act": "st_knife_act"},
	"wrap": {"rest": "st_wrap", "act": "st_wrap_act"},
}

var tool := "open"
## The pointer is over the work (else the hand sinks out of the way).
var on_work := false

var _rect: TextureRect
var _tex: Dictionary = {}
var _tips: Dictionary = {}
var _acc := 0.0
var _pos := Vector2(-1, -1)
## The press, phased: "" at rest, "wind", "act" (while held), "follow".
var _phase := ""
var _phase_ticks := 0
var _held := false
## A tool changed: down for a tick, then the new one up.
var _swap := 0
## Something done in passing (the pencil's mark on a mat as a beer goes over): that
## tool's act picture for a few ticks, whatever is in the hand.
var _flash_tool := ""
var _flash_ticks := 0
var _shown_tool := ""
var _hands: Node


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_rect = TextureRect.new()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)
	_hands = HANDS.of(self)


func _exit_tree() -> void:
	if _hands != null and is_instance_valid(_hands):
		_hands.release("right", "work#station")


## `t`'s act picture for `ticks` ticks (twelve a second), then back to the tool in hand.
func flash(t: String, ticks: int) -> void:
	_flash_tool = t
	_flash_ticks = ticks


## The button went down on the work (true) or up (false).
func act(down: bool) -> void:
	_held = down
	if down:
		_phase = "wind"
		_phase_ticks = 1
	elif _phase == "act" or _phase == "wind":
		# Seen in the act at least a beat, then the follow-through.
		_phase = "follow"
		_phase_ticks = 2


func _tex_of(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png") if ResourceLoader.exists(DIR + n + ".png") else null
	return _tex[n]


## Where on picture `n` its tool works, as a share of its size: the middle of its
## topmost few rows (a hand reaching forward ends in what it works with).
func _tip_of(n: String) -> Vector2:
	if _tips.has(n):
		return _tips[n]
	var tip := Vector2(0.3, 0.08)
	var t := _tex_of(n)
	if t != null:
		var img := t.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var top := -1
			var xs := 0.0
			var count := 0
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.5:
						if top < 0:
							top = y
						if y <= top + 3:
							xs += float(x)
							count += 1
				if top >= 0 and y > top + 3:
					break
			if count > 0:
				tip = Vector2(xs / count / float(img.get_width()), (float(top) + 2.0) / float(img.get_height()))
	_tips[n] = tip
	return tip


## The camp's reach hands, while the stations' own bare glove is not there.
const OLD_GLOVE := {"open": {"rest": "hand7_reach", "act": "hand7_grab"}, "press": {"rest": "hand7_reach", "act": "hand7_press"}}


## The pictures of `t`, or the bare glove's when they are missing.
func _tool_of(t: String) -> Dictionary:
	var d: Dictionary = TOOLS.get(t, TOOLS["open"])
	if _tex_of(str(d["rest"])) == null or _tex_of(str(d["act"])) == null:
		var bare := "press" if t == "press" else "open"
		d = TOOLS[bare]
		if _tex_of(str(d["rest"])) == null or _tex_of(str(d["act"])) == null:
			d = OLD_GLOVE[bare]
	return d


## The books or the Z report over the station: the hand is down meanwhile.
func _covered() -> bool:
	for n in get_tree().get_nodes_in_group("closeup"):
		if n is CanvasLayer and (n as CanvasLayer).visible:
			var sc = n.get_script()
			if sc != null and str(sc.resource_path).get_file().contains("closeup"):
				return true
	return false


func _process(delta: float) -> void:
	if not visible:
		return
	if _covered():
		_rect.visible = false
		_pos = Vector2(-1, -1)
		return
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	if tool != _shown_tool:
		_shown_tool = tool
		_swap = 1 if _pos.x >= 0.0 else 0
	var d := _tool_of(tool)
	# The phase, a tick at a time.
	var pic := str(d["rest"])
	var lift := 0.0
	match _phase:
		"wind":
			lift = 4.0
			_phase_ticks -= 1
			if _phase_ticks <= 0:
				_phase = "act" if _held else "follow"
				_phase_ticks = 2
		"act":
			pic = str(d["act"])
		"follow":
			pic = str(d["act"])
			lift = -3.0
			_phase_ticks -= 1
			if _phase_ticks <= 0:
				_phase = ""
	if _flash_ticks > 0:
		_flash_ticks -= 1
		var fd := _tool_of(_flash_tool)
		if _tex_of(str(fd["act"])) != null:
			d = fd
			pic = str(fd["act"])
			lift = 0.0
	var t := _tex_of(pic)
	if t == null:
		_rect.visible = false
		return
	var vp := get_viewport().get_visible_rect().size
	var k := HANDS.px(vp.y)
	var size := t.get_size() * k
	var mouse: Vector2 = load("res://scripts/business/station3d.gd").mouse_of(get_viewport())
	var tip := _tip_of(str(d["rest"]))
	var want := mouse - tip * size
	# The arm reaches as far up as it goes (its sleeve still at the bottom edge) and never
	# drops below half of it; off the work it sinks out of the way.
	want.y = clampf(want.y, vp.y - size.y, vp.y - size.y * 0.55)
	if not on_work and not _held:
		want.y = vp.y - size.y * 0.42
	if _swap > 0:
		want.y = vp.y - size.y * 0.3
		_swap -= 1
	want.x = clampf(want.x, -size.x * 0.25, vp.x - size.x * 0.75)
	want.y -= lift * k
	if _pos.x < 0.0:
		_pos = Vector2(want.x, vp.y)
	# After the pointer in steps, most of the way each tick.
	_pos += (want - _pos) * 0.6
	if (want - _pos).length() < float(k):
		_pos = want
	var mo: Vector2 = _hands.motion if _hands != null and is_instance_valid(_hands) else Vector2.ZERO
	_rect.texture = t
	_rect.size = size
	_rect.position = ((_pos + mo * k) / k).floor() * k
	_rect.material = _hands.material if _hands != null and is_instance_valid(_hands) else null
	_rect.visible = true
	if _hands != null and is_instance_valid(_hands):
		_hands.claim("right", "work#station")
