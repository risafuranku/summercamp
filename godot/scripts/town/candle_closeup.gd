extends "res://scripts/closeup/closeup_view.gd"

## The chapel's votive stand up close (chapel_view.gd, the user, 4. 11.: "lighting a candle
## as a micro-interaction with a match"): the three tiers of red glass cups, the tin, the
## saucer of matches, the wall behind, a picture filling the whole plate (nothing is said
## here, so no strip under it), and your two gloved hands. The mouse is the right hand.
##
##   a match     your own (the bag's "matches": its use goes when one catches), or the
##               chapel's: click the tin or the saucer, a coin goes in and a match comes
##               out of the saucer (no coin if your own candle stands in a cup);
##   a candle    your own (the bag's "candle", a votive in its red cup): you hold it by
##               the rim first, click a free place and it stands there in the old cup's
##               ring, and that one is the one to light;
##   the strike  the left hand comes up with the box: hold the button and drag the head
##               along the striker, quickly: a slow drag only scrapes, a quick one may
##               need a second go; the flame flares, sinks, burns down in BURN_SEC;
##   the wick    the flame held at a free cup's wick for HOLD_SEC catches it: the flame is
##               on the stand in the room (chapel_view.lit_on_stand, and so for the other
##               wardens); shake the match out or let it burn to your fingers (a hiss,
##               it drops); then the plate shuts by itself.
##
## All the light comes from the flames (LIGHT_SHADER on the canvas, Build's shade steps),
## the red glass of a burning cup glowing from inside. Never scripted, never said, weighed
## by the hidden sanity (the chapel's): as yours catches another goes out, or all the
## flames lean over to the door (right of the picture, as the rack stands), or a whisper.
##
## Esc, a right click or a click off the plate leaves it (closeup_view.gd's way).
## A tool drives it through debug_at / debug_press / debug_stroke (the same way as a hand:
## the head along the striker, the flame held to a wick), debug_strike, debug_flame_to.

const CAMP := "res://assets/textury/camp/"
const SFX := "res://assets/sfx/"
const INVENTORY = preload("res://scripts/ui/inventory.gd")
const PIC := CAMP + "candle_closeup.png"
## The wicks' tips in the picture, the top tier first, each left to right: chapel_view's
## cups in the same order.
const CUPS := [Vector2(56, 30), Vector2(108, 30), Vector2(161, 30), Vector2(214, 30), Vector2(266, 29),
	Vector2(52, 84), Vector2(106, 84), Vector2(161, 84), Vector2(215, 84), Vector2(268, 84),
	Vector2(46, 146), Vector2(103, 146), Vector2(160, 146), Vector2(216, 146), Vector2(272, 146)]
## The red glass under a wick (from the wick's tip), for the glow.
const GLASS := Vector2(0, 16)
## Where the wick is in a flame bent over (the rest have it in the middle).
const FLAME_FOOT := {"candle_flame_5": 4.0, "candle_flame_6": 3.0}
const TIN := Rect2(7, 198, 54, 60)
const SLOT := Vector2(35, 212)
const DISH := Rect2(63, 227, 59, 36)
const FROM_DISH := Vector2(92, 240)
## How far a click on a cup reaches, how near the flame must be to a wick.
const CUP_REACH := 22.0
const WICK_REACH := 9.0
## The right hand's pictures: the pinch of finger and thumb, the open hand's fingertips.
const PINCH := Vector2(5, 14)
const OPEN_TIP := Vector2(35, 2)
## From the pinch up to the head of a whole match, how far a match runs behind the fingers.
const MATCH_UP := 42.0
const MATCH_IN := 6.0
## Your own votive cup: its wick in its picture, the pinch on its rim down from the wick.
const OWN_WICK := Vector2(20, 14)
const OWN_RIM := 10.0
## The left hand with the box: where it stands when up, the striker in its picture.
const BOX_AT := Vector2(-6, 112)
const STRIKER := Rect2(81, 30, 75, 16)
const STRIKE_SPEED := 230.0
const BURN_SEC := 6.0
const HOLD_SEC := 0.8
const SHAKE_SPEED := 420.0
const AMBIENT := 0.5

const LIGHT_SHADER := """
shader_type canvas_item;
uniform float ambient = 0.5;
uniform int count = 0;
uniform vec4 lights[17];
uniform float glass[17];
uniform vec2 glass_at = vec2(0.0, 16.0);
varying vec2 px;

void vertex() {
	px = VERTEX;
}

void fragment() {
	float l = ambient;
	float glow = 0.0;
	for (int i = 0; i < 17; i++) {
		if (i >= count) {
			break;
		}
		vec4 L = lights[i];
		float d = length(px - L.xy) / L.z;
		l += max(0.0, 1.0 - d) * max(0.0, 1.0 - d) * L.w;
		if (glass[i] > 0.0) {
			float g = length((px - L.xy - glass_at) / vec2(21.0, 20.0));
			glow += max(0.0, 1.0 - g * g) * glass[i];
		}
	}
	// Build's shade steps, the dark cold, the lit warm.
	float s = floor(l * 7.0) / 7.0;
	vec3 tint = mix(vec3(0.66, 0.7, 0.76), vec3(1.08, 0.9, 0.68), clamp(s * 1.2 - 0.45, 0.0, 1.0));
	vec3 c = COLOR.rgb * s * tint;
	// The red of the glass lit from inside.
	float red = max(0.0, COLOR.r - max(COLOR.g, COLOR.b));
	c += vec3(1.0, 0.3, 0.08) * red * floor(min(glow, 1.0) * 5.0) / 5.0 * 2.2;
	COLOR.rgb = c;
}
"""

var _chapel
var _mat: ShaderMaterial
var _tex: Dictionary = {}
var _sounds: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _fx: AudioStreamPlayer
var _burn_snd: AudioStreamPlayer
var _scrape_snd: AudioStreamPlayer
## "free" (the open hand), "fetch" (the hand on its way), "candle" (your candle in the
## hand), "match" (unlit), "burning", "out" (done with this match).
var _stage := ""
## Where the hand's working point is (picture px): the head of the match, the wick of your
## candle, the fingertips; the pinch is `_grip` from it.
var _hand := Vector2(250, 200)
var _last := Vector2(250, 200)
var _grip := Vector2.ZERO
var _grip_to := Vector2.ZERO
var _holding := ""
## The hand's way when it goes by itself: [{to, t, then}].
var _seq: Array = []
var _seq_t := 0.0
var _seq_from := Vector2.ZERO
## The left hand, 0 down .. 1 up; wanted up or not.
var _box_k := 0.0
var _box_up := false
var _own_match := false
var _strikes := 0
var _stroke := 0.0
var _stroke_t := 0.0
var _was_down := false
## The system pointer shown this frame (off the plate, over the striker): elsewhere the
## drawn hand is the pointer.
var _pointer := true
var _spark_t := 0.0
var _burn_t := 0.0
var _hold_cup := -1
var _hold_t := 0.0
## The cup that caught this time, the ages of the flames (how far they have caught).
var _caught := -1
var _age: Dictionary = {}
## Flames going out up close, smoke over cups and the match: {at, t}.
var _dying: Dictionary = {}
var _smoke: Array = []
## How the match went out: its last position, falling.
var _fall := {}
var _jerk_t := 0.0
## The shake: how long fast, the last direction, the turns lately.
var _fast_t := 0.0
var _dir := 0.0
var _turns: Array = []
var _leave_t := -1.0
## What waits a moment, the hand going on meanwhile: [{t, then}].
var _later: Array = []
## Never scripted: what the night has for this match.
var _lean_t := 0.0
var _out_wait := -1.0
var _out_cup := -1
var _whisper_wait := -1.0
var _anim := 0.0
var debug_mouse := Vector2(-1, -1)
var debug_down := false
var _debug_way := {}
var _debug_cup := -1


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_rng.randomize()
	var sh := Shader.new()
	sh.code = LIGHT_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_canvas.material = _mat
	_fx = AudioStreamPlayer.new()
	add_child(_fx)
	_burn_snd = AudioStreamPlayer.new()
	add_child(_burn_snd)
	_scrape_snd = AudioStreamPlayer.new()
	add_child(_scrape_snd)
	if ResourceLoader.exists(SFX + "chapel/candle_burn.ogg"):
		var s = (load(SFX + "chapel/candle_burn.ogg") as AudioStreamOggVorbis).duplicate()
		s.loop = true
		_burn_snd.stream = s
	_burn_snd.volume_db = -15.0
	if ResourceLoader.exists(SFX + "chapel/candle_scrape.mp3"):
		_scrape_snd.stream = load(SFX + "chapel/candle_scrape.mp3")
	_scrape_snd.volume_db = -8.0


## The chapel's view: its flames are the stand's. Everything read and drawn once off
## screen here, while the room is built: no hitch at the first look.
func setup(view) -> void:
	_chapel = view
	for t in ["candle_hand_pinch", "candle_hand_open", "candle_hand_box", "candle_match_0", "candle_match_1", "candle_match_2", "candle_match_3", "candle_match_4",
			"candle_match_spent", "candle_mflame_0", "candle_mflame_1", "candle_mflame_2", "candle_mflame_3", "candle_mflame_4", "candle_flame_0", "candle_flame_1",
			"candle_flame_2", "candle_flame_3", "candle_flame_4", "candle_flame_5", "candle_flame_6", "candle_own", "candle_coin", "candle_smoke_0", "candle_smoke_1", "candle_smoke_2"]:
		_t(t)
	for f in ["chapel/candle_strike_dud.mp3", "chapel/candle_flare.mp3", "chapel/candle_catch.mp3", "chapel/candle_shake.mp3", "chapel/candle_hiss.mp3",
			"chapel/candle_drop.mp3", "chapel/candle_take.mp3", "chapel/candle_set.mp3", "chapel/candle_out.mp3", "chapel/candle_whisper.mp3", "chapel/candle_draft.mp3",
			"chapel/coin_box.mp3", "director/knock_wrong.mp3"]:
		_snd(f)
	_update_lights()
	_canvas.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _t(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := CAMP + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


func _bag():
	return INVENTORY.find(get_tree())


func _snd(path: String) -> AudioStream:
	if not _sounds.has(path):
		_sounds[path] = load(SFX + path) if ResourceLoader.exists(SFX + path) else null
	return _sounds[path]


func _sound(path: String, db: float) -> void:
	var s := _snd(path)
	if s != null:
		_fx.stream = s
		_fx.volume_db = db
		_fx.play()


# ── what is up to you now ────────────────────────────────────────────────────

func _opened() -> void:
	_caught = -1
	_leave_t = -1.0
	_age.clear()
	_dying.clear()
	_smoke.clear()
	_fall = {}
	_seq.clear()
	_later.clear()
	_lean_t = 0.0
	_out_wait = -1.0
	_whisper_wait = -1.0
	_box_k = 0.0
	_begin()
	_hand = _mouse if _mouse.x >= 0.0 else Vector2(250, 200)
	_last = _hand
	_grip = _grip_to


## The next thing for the hands, with what you have.
func _begin() -> void:
	_stage = "free"
	_holding = ""
	_grip_to = Vector2.ZERO
	_box_up = false
	_own_match = false
	var bag = _bag()
	if _chapel == null or (_chapel.set_cup < 0 and _free().is_empty()):
		return
	if _chapel.set_cup < 0 and bag != null and bag.has("candle"):
		_stage = "candle"
		_holding = "candle"
		_grip_to = Vector2(0, OWN_RIM)
		return
	if bag != null and bag.has("matches"):
		_own_match = true
		_take_match()
	elif _chapel.paid_match:
		_take_match()


func _free() -> Array:
	var out: Array = _chapel.free_cups() if _chapel != null else []
	return out.filter(func(c): return int(c) < CUPS.size())


func _take_match() -> void:
	_stage = "match"
	_holding = "match"
	_grip_to = Vector2(0, MATCH_UP)
	_box_up = true
	_strikes = 0
	_stroke = 0.0
	_stroke_t = 0.0


func _hotspots() -> Array:
	var out: Array = []
	match _stage:
		"free":
			if _chapel != null and (not _free().is_empty() or _chapel.set_cup >= 0):
				out.append({"id": "tin", "rect": TIN})
				out.append({"id": "dish", "rect": DISH})
		"candle":
			for i in _free():
				var w: Vector2 = CUPS[int(i)]
				out.append({"id": "cup:%d" % int(i), "rect": Rect2(w - Vector2(CUP_REACH, 12.0), Vector2(CUP_REACH * 2.0, CUP_REACH * 2.0))})
	return out


func _clicked(id: String) -> void:
	if id == "tin" or id == "dish":
		_fetch()
	elif id.begins_with("cup:"):
		_set_candle(int(id.get_slice(":", 1)))


## Your candle into cup `cup`: down from the hand, out of the bag, and the wick is its.
func _set_candle(cup: int) -> void:
	var bag = _bag()
	if bag == null or not bag.has("candle") or not bag.consume("candle"):
		_begin()
		return
	_stage = "fetch"
	_way(CUPS[cup], 0.28, func():
		_chapel.set_cup = cup
		_sound("chapel/candle_set.mp3", -6.0)
		_holding = ""
		_begin())
	_way_back(0.3)


## The hand to the tin with a coin, to the saucer for a match, back to where the pointer is.
func _fetch() -> void:
	var coin: bool = _chapel.set_cup < 0
	_stage = "fetch"
	if coin and CoreRoot.get_money() < 1:
		_way(SLOT, 0.3, func(): _sound("director/knock_wrong.mp3", -14.0))
		_way_back(0.3, func(): _stage = "free")
		return
	if coin:
		_holding = "coin"
		_way(SLOT + Vector2(0, -2), 0.3, func():
			if CoreRoot.actions.spend_money(1):
				_chapel.paid_match = true
				_sound("chapel/coin_box.mp3", -6.0)
			_holding = "")
	_way(FROM_DISH, 0.26, func():
		_sound("chapel/candle_take.mp3", -5.0)
		_holding = "match"
		# The same pinch, the working point now the match's head above it.
		_grip_to = Vector2(0, MATCH_UP)
		_grip = _grip_to
		_hand -= _grip
		_seq_from = _hand)
	_way_back(0.32, func(): _take_match())


func _way(to: Vector2, seconds: float, then := Callable()) -> void:
	if _seq.is_empty():
		_seq_from = _hand
		_seq_t = 0.0
	_seq.append({"to": to, "t": seconds, "then": then})


## Back to the pointer (wherever it has gone in the meantime).
func _way_back(seconds: float, then := Callable()) -> void:
	_seq.append({"to": null, "t": seconds, "then": then})


func _tick_way(delta: float, mouse: Vector2) -> bool:
	if _seq.is_empty():
		return false
	var s: Dictionary = _seq[0]
	_seq_t += delta
	var k := clampf(_seq_t / float(s["t"]), 0.0, 1.0)
	var to: Vector2 = s["to"] if s["to"] != null else (mouse if mouse.x >= 0.0 else _seq_from)
	_hand = _seq_from.lerp(to, k * k * (3.0 - 2.0 * k)).round()
	if k >= 1.0:
		_seq.pop_front()
		_seq_from = _hand
		_seq_t = 0.0
		var then: Callable = s["then"]
		if then.is_valid():
			then.call()
	return true


# ── each frame ───────────────────────────────────────────────────────────────

func _tick(delta: float) -> void:
	var bag = _bag()
	if get_tree().paused or HandCursor.menu_over or (bag != null and bag.is_open()):
		_cursor(true)
		return
	_anim += delta
	_tick_debug(delta)
	var m := debug_mouse if debug_mouse.x >= 0.0 else _mouse
	var down := debug_down or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_pointer = m.x < 0.0
	if not _tick_way(delta, m) and m.x >= 0.0:
		_hand = m.round()
	_grip = _grip.lerp(_grip_to, 1.0 - exp(-delta * 16.0))
	_box_k += (( 1.0 if _box_up else 0.0) - _box_k) * (1.0 - exp(-delta * 11.0))
	_spark_t = maxf(0.0, _spark_t - delta)
	_jerk_t = maxf(0.0, _jerk_t - delta)
	_lean_t = maxf(0.0, _lean_t - delta)
	match _stage:
		"match":
			_tick_strike(delta, down)
		"burning":
			_tick_burning(delta)
	_tick_later(delta)
	_tick_cups(delta)
	_tick_fall(delta)
	_tick_night(delta)
	_track_speed(delta)
	_last = _hand
	if _leave_t >= 0.0:
		_leave_t -= delta
		if _leave_t < 0.0:
			close_view()
			return
	_cursor(_pointer)
	_update_lights()


func _cursor(on: bool) -> void:
	var want := Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _box_at() -> Vector2:
	return (BOX_AT + Vector2(0, (1.0 - _box_k) * (float(H) - BOX_AT.y + 10.0))).round()


func _striker() -> Rect2:
	return Rect2(_box_at() + STRIKER.position, STRIKER.size)


## The head dragged along the box with the button down: slow scrapes, quick may catch.
func _tick_strike(delta: float, down: bool) -> void:
	var r := _striker().grow(3.0)
	var over := _box_k > 0.95 and r.has_point(_hand)
	# The arrows of the motion wanted over the striker (the game's way: hand_cursor.gd).
	if over:
		_pointer = true
		HandCursor.want(HandCursor.RUB)
	var on := down and over
	if on and not _was_down and not _scrape_snd.playing:
		_scrape_snd.play()
	_was_down = down
	if not on or not r.has_point(_last):
		_stroke = 0.0
		_stroke_t = 0.0
		return
	var moved := absf(_hand.x - _last.x)
	_stroke += moved
	_stroke_t += delta
	if moved > 1.0 and not _scrape_snd.playing:
		_scrape_snd.pitch_scale = _rng.randf_range(0.9, 1.1)
		_scrape_snd.play()
	if _stroke >= STRIKER.size.x * 0.5:
		var quick := _stroke / maxf(0.001, _stroke_t) >= STRIKE_SPEED
		_stroke = 0.0
		_stroke_t = 0.0
		if quick:
			_strike()


func _strike() -> void:
	_strikes += 1
	_scrape_snd.stop()
	var chance := 0.5 if _strikes == 1 else (0.8 if _strikes == 2 else 1.0)
	if _rng.randf() < chance:
		_ignite()
	else:
		_sound("chapel/candle_strike_dud.mp3", -5.0)
		_spark_t = 0.14


func _ignite() -> void:
	_stage = "burning"
	_burn_t = 0.0
	_hold_cup = -1
	_hold_t = 0.0
	_fast_t = 0.0
	_turns.clear()
	var bag = _bag()
	if _own_match and bag != null:
		bag.consume("matches")
	else:
		_chapel.paid_match = false
	_sound("chapel/candle_flare.mp3", -3.0)
	if _burn_snd.stream != null:
		_burn_snd.play()
	_box_up = false


## How much of the match is left: its picture.
func _match_frame() -> String:
	if _stage == "burning":
		return "candle_match_%d" % (1 + mini(3, int(_burn_t / BURN_SEC * 4.0)))
	if _stage == "out":
		return "candle_match_spent"
	return "candle_match_0"


func _pinch() -> Vector2:
	var p := _hand + _grip
	if _jerk_t > 0.0:
		p += Vector2(3, 5) * (_jerk_t / 0.25)
	return p.round()


## The top of the match now (the flame stands on it).
func _tip() -> Vector2:
	var t := _t(_match_frame())
	var h := float(t.get_height()) if t != null else MATCH_UP + MATCH_IN
	return _pinch() - Vector2(0, h - MATCH_IN)


func _tick_burning(delta: float) -> void:
	_burn_t += delta
	var tip := _tip()
	if _caught < 0:
		# Any of the flame will do: from the match's end to its point.
		var cup := _wick_near(tip - Vector2(0, 6))
		if cup != _hold_cup:
			_hold_cup = cup
			_hold_t = 0.0
		if cup >= 0:
			_hold_t += delta
			if _hold_t >= HOLD_SEC:
				_catch(cup)
	if _burn_t >= BURN_SEC:
		_sound("chapel/candle_hiss.mp3", -4.0)
		_jerk_t = 0.25
		_match_out()


## The wick the flame is at, of those it can light (your candle if it stands in a cup).
func _wick_near(p: Vector2) -> int:
	var cups: Array = [_chapel.set_cup] if _chapel.set_cup >= 0 else _free()
	var best := -1
	var near := WICK_REACH + 4.0
	for i in cups:
		var d := p.distance_to(_wick(int(i)))
		if d < near:
			near = d
			best = int(i)
	return best


func _wick(cup: int) -> Vector2:
	return CUPS[cup]


## It has caught: the flame on the stand, the night's say.
func _catch(cup: int) -> void:
	_caught = cup
	if cup == _chapel.set_cup:
		_chapel.own_cups.append(cup)
		_chapel.set_cup = -1
	_age[cup] = 0.0
	_chapel.lit_on_stand(cup)
	_sound("chapel/candle_catch.mp3", -3.0)
	_roll_night(cup)


func _match_out() -> void:
	_stage = "out"
	_burn_snd.stop()
	_holding = "match"
	_smoke.append({"at": _tip(), "t": 0.0})
	_after(0.45, func():
		_fall = {"at": _pinch() + Vector2(0, MATCH_IN), "v": 0.0, "pic": "candle_match_spent"}
		_holding = "")
	_after(0.65, func():
		_grip_to = Vector2.ZERO
		if _caught >= 0:
			_leave_t = 1.1
		else:
			_begin())


func _after(seconds: float, then: Callable) -> void:
	_later.append({"t": seconds, "then": then})


func _tick_later(delta: float) -> void:
	for l in _later.duplicate():
		l["t"] = float(l["t"]) - delta
		if float(l["t"]) <= 0.0:
			_later.erase(l)
			(l["then"] as Callable).call()


func _tick_fall(delta: float) -> void:
	if _fall.is_empty():
		return
	_fall["v"] = float(_fall["v"]) + 520.0 * delta
	var at: Vector2 = _fall["at"]
	at.y += float(_fall["v"]) * delta
	_fall["at"] = at
	if at.y >= 262.0:
		_sound("chapel/candle_drop.mp3", -9.0)
		_fall = {}


## The match shaken out: after the wick has caught one quick flick does it, before that
## it takes a real shake (a fast move across the plate is not one).
func _track_speed(delta: float) -> void:
	if _stage != "burning" or delta <= 0.0:
		return
	var v := (_hand - _last) / delta
	var fast := v.length() >= SHAKE_SPEED
	_fast_t = _fast_t + delta if fast else maxf(0.0, _fast_t - delta * 3.0)
	var along := v.x if absf(v.x) >= absf(v.y) else v.y
	if fast and along * _dir < 0.0:
		_turns.append(_anim)
	if fast:
		_dir = signf(along)
	while not _turns.is_empty() and _anim - float(_turns[0]) > 0.7:
		_turns.pop_front()
	if _burn_t < 0.4:
		return
	if (_caught >= 0 and _fast_t >= 0.07) or _turns.size() >= 3:
		_sound("chapel/candle_shake.mp3", -5.0)
		_match_out()


func _lit() -> Array:
	var out: Array = []
	if _chapel != null:
		for f in _chapel.flames:
			var cup := int((f as Dictionary).get("cup", -1))
			if cup >= 0 and cup < CUPS.size():
				out.append(cup)
	return out


func _tick_cups(delta: float) -> void:
	for cup in _age.keys():
		_age[cup] = float(_age[cup]) + delta
	for cup in _dying.keys():
		_dying[cup] = float(_dying[cup]) + delta
		if float(_dying[cup]) >= 0.5:
			_dying.erase(cup)
			_smoke.append({"at": _wick(int(cup)), "t": 0.0})
	for s in _smoke.duplicate():
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= 2.4:
			_smoke.erase(s)


# ── the night's say ──────────────────────────────────────────────────────────

## As yours catches, now and then, the worse you are the more: one of these.
func _roll_night(cup: int) -> void:
	_chapel._sanity = _chapel._read_sanity()
	var low: float = _chapel._low()
	var others := _lit().filter(func(c): return int(c) != cup)
	var roll := _rng.randf()
	if not others.is_empty() and roll < 0.05 + 0.35 * low:
		_out_cup = int(others[_rng.randi_range(0, others.size() - 1)])
		_out_wait = _rng.randf_range(0.5, 1.1)
	elif roll < 0.1 + 0.55 * low:
		_lean_t = _rng.randf_range(1.2, 1.9)
		_sound("chapel/candle_draft.mp3", -15.0)
	elif roll < 0.14 + 0.7 * low:
		_whisper_wait = _rng.randf_range(0.8, 1.8)


func _tick_night(delta: float) -> void:
	if _out_wait >= 0.0:
		_out_wait -= delta
		if _out_wait < 0.0 and _lit().has(_out_cup):
			_dying[_out_cup] = 0.0
			_chapel.put_out(_out_cup)
			_sound("chapel/candle_out.mp3", -7.0)
	if _whisper_wait >= 0.0:
		_whisper_wait -= delta
		if _whisper_wait < 0.0:
			_sound("chapel/candle_whisper.mp3", -14.0)


## The flames' light for the shader: every cup, the match, flickering by steps.
func _update_lights() -> void:
	if _mat == null:
		return
	var lights := PackedVector4Array()
	var glass := PackedFloat32Array()
	var step := floorf(_anim * 11.0)
	for cup in _lit():
		var w := _wick(int(cup))
		var catching := clampf(float(_age.get(cup, 9.0)) / 0.5, 0.15, 1.0)
		var flick := 1.0 + 0.1 * sin(step * 1.7 + float(cup) * 2.1)
		lights.append(Vector4(w.x, w.y - 5.0, 62.0 * flick, 0.62 * catching))
		glass.append(0.95 * catching * flick)
	if _stage == "burning" and lights.size() < 16:
		var tip := _tip()
		var flare := clampf(1.0 - _burn_t / 0.5, 0.0, 1.0)
		var flick := 1.0 + 0.08 * sin(step * 2.3)
		lights.append(Vector4(tip.x, tip.y - 6.0, (116.0 + 70.0 * flare) * flick, 1.1 + 1.0 * flare))
		glass.append(0.0)
	var n := lights.size()
	lights.resize(17)
	glass.resize(17)
	_mat.set_shader_parameter("lights", lights)
	_mat.set_shader_parameter("glass", glass)
	_mat.set_shader_parameter("count", n)
	_mat.set_shader_parameter("ambient", AMBIENT)
	_mat.set_shader_parameter("glass_at", GLASS)


# ── drawing ──────────────────────────────────────────────────────────────────

## The picture over the whole plate: no strip, nothing is said here.
func _draw_all() -> void:
	var c := _canvas
	c.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.02))
	if picture != null:
		c.draw_texture_rect(picture, Rect2(0, 0, W, H), false)
	_paint(c)
	c.draw_rect(Rect2(0, 0, W, 1), RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(0, 0, 1, H), RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(0, H - 1, W, 1), RETRO_UI.C_PLATE_DARK)
	c.draw_rect(Rect2(W - 1, 0, 1, H), RETRO_UI.C_PLATE_DARK)


func _pic(c: Control, name: String, at: Vector2) -> void:
	var t := _t(name)
	if t != null:
		c.draw_texture(t, at.round())


## `name` with the middle of its foot at `foot`.
func _stood(c: Control, name: String, foot: Vector2) -> void:
	var t := _t(name)
	if t != null:
		c.draw_texture(t, (foot - Vector2(t.get_width() * 0.5, t.get_height())).round())


## A cup's flame on its wick: its own black stub over the picture's.
func _on_wick(c: Control, name: String, wick: Vector2) -> void:
	var t := _t(name)
	if t != null:
		var x: float = float(FLAME_FOOT.get(name, t.get_width() * 0.5))
		c.draw_texture(t, (wick + Vector2(-x, 5.0 - float(t.get_height()))).round())


func _paint(c: Control) -> void:
	if _chapel == null:
		return
	# What stands in the cups: your own candles, then every flame.
	for cup in _own_cups():
		_pic(c, "candle_own", CUPS[cup] - OWN_WICK)
	var lean := _lean_t > 0.0
	var step := int(_anim * 10.0)
	for cup in _lit():
		_on_wick(c, _flame_pic(int(cup), step, lean), _wick(int(cup)))
	for cup in _dying.keys():
		var k := float(_dying[cup])
		_on_wick(c, "candle_flame_1" if k < 0.25 else "candle_flame_0", _wick(int(cup)))
	# The flame coming on the wick you are holding the match to.
	if _stage == "burning" and _caught < 0 and _hold_cup >= 0 and _hold_t > HOLD_SEC * 0.45:
		_on_wick(c, "candle_flame_0", _wick(_hold_cup))
	for s in _smoke:
		_stood(c, "candle_smoke_%d" % mini(2, int(float(s["t"]) / 0.8)), s["at"])
	if not _fall.is_empty():
		_stood(c, str(_fall["pic"]), _fall["at"])
	# The left hand with its box, under the right.
	if _box_k > 0.02:
		_pic(c, "candle_hand_box", _box_at())
	_paint_hand(c, step)


func _own_cups() -> Array:
	var out: Array = (_chapel.own_cups as Array).duplicate()
	if _chapel.set_cup >= 0:
		out.append(_chapel.set_cup)
	return out


func _flame_pic(cup: int, step: int, lean: bool) -> String:
	var age := float(_age.get(cup, 9.0))
	if age < 0.18:
		return "candle_flame_0"
	if age < 0.42:
		return "candle_flame_1"
	if lean:
		return "candle_flame_5" if (step + cup) % 3 != 0 else "candle_flame_6"
	return "candle_flame_%d" % (2 + (step + cup * 2) % 3)


func _paint_hand(c: Control, step: int) -> void:
	var pinch := _pinch()
	match _holding:
		"match":
			_stood(c, _match_frame(), pinch + Vector2(0, MATCH_IN))
		"candle":
			_pic(c, "candle_own", _hand - OWN_WICK)
		"coin":
			_stood(c, "candle_coin", pinch + Vector2(0, 5))
	var open := _holding == "" and _stage in ["free", "out"] and _hotspot_at(_hand) == ""
	if open:
		_pic(c, "candle_hand_open", _hand - OPEN_TIP)
	else:
		_pic(c, "candle_hand_pinch", pinch - PINCH)
	if _stage == "burning":
		var tip := _tip()
		var pic := "candle_mflame_0" if _burn_t < 0.12 else ("candle_mflame_1" if _burn_t < 0.36 else "candle_mflame_%d" % (2 + step % 3))
		if _lean_t > 0.0:
			tip.x += 2.0
		_stood(c, pic, tip + Vector2(0, 3))
	elif _spark_t > 0.0:
		_stood(c, "candle_mflame_0", _hand + Vector2(0, 2))


func _closing() -> void:
	_burn_snd.stop()
	_scrape_snd.stop()
	_seq.clear()
	_later.clear()
	_stage = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ── for tools ────────────────────────────────────────────────────────────────

func debug_at(p: Vector2) -> void:
	debug_mouse = p


func debug_press(on: bool) -> void:
	debug_down = on


## The pointer from `from` to `to` over `seconds`, the button down all the way.
func debug_stroke(from: Vector2, to: Vector2, seconds: float) -> void:
	debug_mouse = from
	debug_down = true
	_debug_way = {"from": from, "to": to, "t": 0.0, "sec": seconds}


## One quick stroke along the striker that takes (the box must be up).
func debug_strike() -> void:
	_strikes = 2
	var r := _striker()
	debug_stroke(r.position + Vector2(4, 8), r.end - Vector2(4, 8), 0.16)


## The flame kept at cup `cup`'s wick (the match gets shorter under it), -1 to let go.
func debug_flame_to(cup: int) -> void:
	_debug_cup = cup


func _tick_debug(delta: float) -> void:
	if _debug_cup >= 0 and _stage == "burning":
		debug_mouse = _wick(_debug_cup) + _hand - _tip()
	if _debug_way.is_empty():
		return
	# The first frame stands at the start, however long the frames are in a test run.
	_debug_way["t"] = float(_debug_way["t"]) + delta if bool(_debug_way.get("on", false)) else 0.0
	_debug_way["on"] = true
	var k := clampf(float(_debug_way["t"]) / float(_debug_way["sec"]), 0.0, 1.0)
	debug_mouse = (_debug_way["from"] as Vector2).lerp(_debug_way["to"], k)
	if k >= 1.0:
		_debug_way = {}
		debug_down = false


func debug_click(id: String) -> void:
	_clicked(id)


func debug_stage() -> String:
	return "%s holding=%s caught=%d burn=%.1f strikes=%d lit=%d box=%.2f" % [_stage, _holding, _caught, _burn_t, _strikes, _lit().size(), _box_k]
