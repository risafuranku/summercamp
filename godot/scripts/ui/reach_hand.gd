extends CanvasLayer

## Your hand going to what you use (playtest 20. 10.: "our hands everywhere"): E on a door,
## a switch, a handle, the barrier, the phone, a thing to pick up brings the gloved hand
## out to it for a beat, Build-weapon style: reached out, the grip or the push, back, and
## down out of view, whole frames at twelve a second (hands_lo/hand7_*). The torch keeps
## the right hand, so then it is the left (the same pictures mirrored); the hand is
## claimed meanwhile (hands.gd), lit and dithered with the others.
## Made by hands.gd; reads the HUD's hint to know what E is on (nothing on "Talk").

const HANDS = preload("res://scripts/ui/hands.gd")
const DIR := "res://assets/textury/hands_lo/"
const FPS := 12.0
## kind -> the frames, each [picture, ticks]; "" in a slot is the hand out of view.
const SEQ := {
	"grab": [["hand7_reach", 2], ["hand7_grab", 3], ["hand7_reach", 1]],
	"press": [["hand7_reach", 1], ["hand7_press", 3], ["hand7_reach", 1]],
	"reach": [["hand7_reach", 4]],
}
const GRAB_WORDS := ["open", "door", "enter", "go in", "close", "barrier", "raise", "lower", "knock", "phone", "lift", "turn", "board", "get on"]
const PRESS_WORDS := ["switch", "light", "breaker", "ring", "press", "bell", "button", "fuse"]
const NO_WORDS := ["talk", "read", "look", "listen"]

var _rect: TextureRect
var _tex: Dictionary = {}
var _seq: Array = []
var _tick := 0.0
var _up := 0.0
var _side := "right"
var _hands: Node


func _init() -> void:
	layer = 59
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	_rect = TextureRect.new()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)


func _tex_of(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png") if ResourceLoader.exists(DIR + n + ".png") else null
	return _tex[n]


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo() or not _seq.is_empty():
		return
	var main := get_tree().current_scene
	if main == null or get_tree().paused or bool(main.get("_menu_mode")):
		return
	if main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open")):
		return
	var hud = main.get("_hud_manager")
	var hint := str(hud.get("_hint_text")).to_lower() if hud != null else ""
	if hint.strip_edges() == "":
		return
	reach(_kind_for(hint))


func _kind_for(hint: String) -> String:
	for w in NO_WORDS:
		if hint.contains(w):
			return ""
	for w in PRESS_WORDS:
		if hint.contains(w):
			return "press"
	for w in GRAB_WORDS:
		if hint.contains(w):
			return "grab"
	return "reach"


## The hand out to the thing and back (`kind`: grab, press, reach).
func reach(kind: String) -> void:
	if kind == "" or not SEQ.has(kind) or _tex_of("hand7_reach") == null:
		return
	if _hands == null or not is_instance_valid(_hands):
		_hands = HANDS.of(self)
	# The torch keeps its hand: reach with the other one.
	_side = "left" if _hands != null and _hands.torch_hand() == "right" and str(_hands.holder("right")) == "torch" else "right"
	_seq = []
	for f in SEQ[kind]:
		_seq.append([str(f[0]), int(f[1])])
	_up = 0.5
	if _hands != null:
		_hands.claim(_side, "work#reach")


func _process(delta: float) -> void:
	var main0 := get_tree().current_scene
	if not _seq.is_empty() and main0 != null and main0.has_method("_is_any_interior_open") and bool(main0.call("_is_any_interior_open")):
		# Through the door already: the room has its own hands.
		_seq.clear()
		_up = 0.0
		if _hands != null and is_instance_valid(_hands):
			_hands.release(_side, "work#reach")
	if _seq.is_empty() and _up <= 0.0:
		_rect.visible = false
		return
	_tick += delta
	if _tick < 1.0 / FPS:
		return
	_tick = 0.0
	var frame := ""
	if not _seq.is_empty():
		var head: Array = _seq[0]
		frame = str(head[0])
		head[1] = int(head[1]) - 1
		if int(head[1]) <= 0:
			_seq.pop_front()
		_up = 1.0
	else:
		# Down out of view in two steps, then the hand is free again.
		_up = maxf(0.0, _up - 0.5)
		frame = "hand7_reach"
		if _up <= 0.0:
			_rect.visible = false
			if _hands != null and is_instance_valid(_hands):
				_hands.release(_side, "work#reach")
			return
	var t := _tex_of(frame)
	if t == null:
		t = _tex_of("hand7_reach")
	if t == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var k := HANDS.px(vp.y)
	_rect.texture = t
	_rect.size = t.get_size() * k
	_rect.flip_h = _side == "left"
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	var bar := float(hud.get_bar_height_px()) if hud != null and hud.has_method("get_bar_height_px") else 0.0
	var x := vp.x * 0.56 - _rect.size.x * 0.3
	var y := vp.y - bar - _rect.size.y * 0.9 * _up + _rect.size.y * 0.35 * (1.0 - _up)
	if _side == "left":
		x = vp.x - x - _rect.size.x
	var mo: Vector2 = _hands.motion if _hands != null and is_instance_valid(_hands) else Vector2.ZERO
	_rect.position = ((Vector2(x, y) + mo * k) / k).floor() * k
	_rect.material = _hands.material if _hands != null and is_instance_valid(_hands) else null
	_rect.visible = true
