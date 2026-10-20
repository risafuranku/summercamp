extends CanvasLayer

## What you carry and use with your own hands, anywhere you can stand (outdoors, in the
## rooms, in Lesna's places): a cigarette and a bottle of Lesnak, each a thing you hold
## and work with, drawn like a Build-engine weapon: whole sprites (Grok) moved twelve
## times a second, never shapes drawn by code.
##
##   C  the cigarette (scripts/habits/cigarette.gd): the pack, the lighter (flick it with
##      C, hold C to keep the flame to the tip), then hold C for a drag and let go to
##      breathe it out. X knocks the ash off, X held throws it away.
##   B  the bottle (scripts/habits/bottle.gd): hold B to lever the cap off with the
##      lighter, then hold B to drink. X sets it down, X held throws it.
## The cigarette is in the left hand, the bottle in the right (hands.gd): with the bottle
## out the torch goes to the left hand and the cigarette into your mouth (C still draws on
## it); the lighter in the left and the bottle in the right put the torch in your pocket.
## The hands hide (the thing goes on burning) at the PC, in a close-up, the boat, the
## pipes, an attraction; they come back when you are on your feet again.
##
## Smoke you breathe out is on the screen and in the world (habit_world.gd), where it
## drifts with the wind and hangs in a room; the butt, the cap and the bottle land where
## they are thrown. In co-op the other warden sees and hears all of it on your figure,
## and the two of you can give each other a light and clink bottles (habit_world.gd).
##
## What you have is in the bag (scripts/ui/inventory.gd): packs of Start, bottles; used
## from there with a double click or with C and B. town_trip.gd owns this node.

const CIG = preload("res://scripts/habits/cigarette.gd")
const BOTTLE = preload("res://scripts/habits/bottle.gd")
const WORLD = preload("res://scripts/habits/habit_world.gd")
const HANDS_KIT = preload("res://scripts/ui/hands.gd")
## The coarse hands (hands.gd), then the full-size ones for what is not made coarse yet.
const HANDS := "res://assets/textury/hands_lo/"
const HANDS_HI := "res://assets/textury/hands/"
const ART := "res://assets/textury/habits/"
const SFX := "res://assets/sfx/habits/"
const FPS := 12.0
## Pictures not made yet stand in with the old ones.
## (Only pictures of the same thing: an old hand with a cigarette in it would show two.)
const FALLBACK := {
	"hand2_beer_open": "beer", "hand2_beer_drink": "beer_drink", "hand2_beer_tilt": "hand2_beer_drink", "hand2_beer_foam": "hand2_beer_open",
	"hand2_beer_opening": "hand2_beer_shut", "cig_3q": "cig_full", "cig_half": "cig_full",
	"cig_quarter": "cig_quarter_ash", "cig_end": "cig_quarter_ash", "butt_lit": "cig_quarter_ash",
}
## Where on each hand picture (its own pixels) the thing in it goes: the gap between the
## fingers for the cigarette, the lighter's nozzle for the flame, the mouth of the
## bottle for the foam. Measured on the sprites (tools/artgen: hand2_*).
const ANCHOR := {
	"hand2_v": Vector2(61, 21), "hand2_v_mouth": Vector2(83, 29),
	"hand2_lighter": Vector2(77, 4), "hand2_pack": Vector2(40, 15),
	# The lighter held to the tip of the cigarette in your mouth, one picture: its nozzle;
	# the filter comes in at the bottom at x 65.
	"hand4_lighting": Vector2(65, 17),
}
## Where on the cigarette pictures your fingers hold it (from its bottom left corner).
const CIG_GRIP := Vector2(11, -11)
const WOBBLE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float t = 0.0;
uniform float jolt = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float a = amount * 0.012;
	// The world leans one way and the other, slowly.
	float roll = sin(t * 0.37) * amount * 0.018;
	vec2 c0 = uv - 0.5;
	uv = vec2(c0.x * cos(roll) - c0.y * sin(roll), c0.x * sin(roll) + c0.y * cos(roll)) + 0.5;
	uv.x += sin(uv.y * 9.0 + t * 1.7) * a;
	uv.y += cos(uv.x * 7.0 + t * 1.3) * a * 0.7 + jolt * 0.012;
	vec3 c = texture(screen, uv).rgb;
	// A ghost of the view to one side, the way the eyes stop agreeing.
	float g_off = a * 2.2 + amount * 0.004 * (1.0 + sin(t * 0.61));
	vec3 g = texture(screen, uv + vec2(g_off, 0.0)).rgb;
	COLOR = vec4(mix(c, (c + g) * 0.5, clamp(amount * 0.8, 0.0, 0.6)), 1.0);
}
"""

## The bag the cigarettes and bottles are in (scripts/ui/inventory.gd).
var bag
## 0.. how drunk (a bottle is one; it wears off).
var drunk := 0.0
## Callable() -> bool: may you use something now (playing, nothing in the way).
var allowed: Callable
## Callable(): kept for town_trip (the stamina is given back drag by drag now).
var on_smoked: Callable

var cig: CIG = CIG.new()
var bottle: BOTTLE = BOTTLE.new()
var world: WORLD

var _tex: Dictionary = {}
var _left: TextureRect
var _cig_rect: TextureRect
var _lips: TextureRect
var _flame: TextureRect
var _right: TextureRect
var _puff_layer: Control
## The smoke breathed out: soft, with real see-through edges, not the hands' dither.
var _smoke_layer: Control
var _puffs: Array = []        # {pos, vel, life, max, delay, f0}
var _falls: Array = []        # ash flakes falling on the screen: {pos, vel, tex, life}
var _wobble: ColorRect
var _wob_mat: ShaderMaterial
var _audio: Dictionary = {}   # channel -> AudioStreamPlayer
var _tick := 0.0
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
var _left_up := 0.0           # 0 down out of view .. 1 up
var _right_up := 0.0
var _left_frame := ""
var _shown := false
var _c_was := false
var _b_was := false
var _hiccup_t := 30.0
var _jolt := 0.0
var _shake := 0.0
var _sway_t := 0.0
var _hands: Node
var _x_target := ""
var _offer_t := -1.0
## The pack held out to the other warden (seconds left of it).
var _offering := 0.0
var _toast := 0
var _strike_kick := 0
var _tap_kick := 0
var _gulp_kick := 0
var _flame_t := 0.0
var _flame_was := 0
var _foam_t := 0.0
var _dying_t := 0.0
var _c_tap := false
var _b_tap := false
var _x_tap := false
## The frame B was last pressed in (habit_world: a tap by the other warden clinks).
var b_tap_frame := -10
var _last_floor_y := 0.0
var _was_on_floor := true
var _vomit_t := -1.0


func _init() -> void:
	name = "Pockets"
	layer = 58
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("habits")


func _ready() -> void:
	_rng.randomize()
	for a in [["smoke", KEY_C], ["drink", KEY_B], ["habit_drop", KEY_X]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			InputMap.action_add_event(a[0], ev)
	_wobble = ColorRect.new()
	_wobble.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wobble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wob_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WOBBLE_SHADER
	_wob_mat.shader = sh
	_wobble.material = _wob_mat
	_wobble.visible = false
	add_child(_wobble)
	_puff_layer = Control.new()
	_puff_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_puff_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_puff_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_puff_layer.draw.connect(_draw_puffs)
	add_child(_puff_layer)
	_smoke_layer = Control.new()
	_smoke_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_smoke_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smoke_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_smoke_layer.draw.connect(_draw_smoke)
	add_child(_smoke_layer)
	# Back to front: the cigarette under the fingers that hold it, the one in your mouth
	# under the lighter, the flame over the lighter, the bottle hand on its own side.
	_cig_rect = _rect("Cig")
	_lips = _rect("Lips")
	_left = _rect("LeftHand")
	_flame = _rect("Flame")
	_right = _rect("RightHand")
	for ch in ["c", "c2", "b", "b2", "fx"]:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_audio[ch] = p
	world = WORLD.new()
	world.pockets = self
	add_child(world)


func _rect(n: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = n
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	add_child(r)
	return r


func tex(n: String) -> Texture2D:
	if _tex.has(n):
		return _tex[n]
	var t: Texture2D = null
	for p in [HANDS + n + ".png", ART + n + ".png", HANDS_HI + n + ".png"]:
		if ResourceLoader.exists(p):
			t = load(p)
			break
	if t == null and FALLBACK.has(n):
		t = tex(str(FALLBACK[n]))
	_tex[n] = t
	return t


# ── using things ─────────────────────────────────────────────────────────────

## A cigarette ("smoke") or a bottle ("drink") out of the bag, if you can now.
## `from_bag`: asked by the bag itself (open, it would otherwise count as in the way).
func try_use(what: String, from_bag := false) -> bool:
	if not _can_act(from_bag):
		return false
	if what == "smoke":
		if cig.active():
			return false
		if bag == null or not bag.has("cigs"):
			_say("No cigarettes. The Jednota in Liblice has Start.")
			return false
		bag.consume("cigs")
		cig.start()
		return true
	if bottle.active():
		return false
	if bag == null or not bag.has("beer"):
		_say("No beer. The Jednota in Liblice has Lesnak.")
		return false
	bag.consume("beer")
	bottle.start()
	return true


## A bottle you set down and picked up again (habit_world.gd): back in the hand as it was.
func take_bottle(level: float, opened: bool) -> bool:
	if bottle.active() or not _can_act():
		return false
	bottle.start()
	bottle.opened = opened
	bottle.level = level
	return true


func is_busy() -> bool:
	return cig.active() or bottle.active()


func hands_full() -> bool:
	return bottle.active()


func _can_act(from_bag := false) -> bool:
	return allowed.is_valid() and bool(allowed.call()) and not _blocked(from_bag)


# ── the frame ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick += delta
	var can := _can_act()
	var c_held := can and Input.is_action_pressed("smoke") and not _typing()
	var b_held := can and Input.is_action_pressed("drink") and not _typing()
	# A tap of X shorter than a frame is a frame of it held (then let go: a tap).
	var x_held := can and (Input.is_action_pressed("habit_drop") or _x_tap) and not _typing()
	_x_tap = false
	var c_pressed := (c_held and not _c_was) or (can and _c_tap)
	var b_pressed := (b_held and not _b_was) or (can and _b_tap)
	_c_tap = false
	_b_tap = false
	_c_was = c_held
	_b_was = b_held
	if c_pressed and not cig.active():
		if world != null and world.partner_in_reach() and bag != null and bag.has("cigs"):
			# By the other warden: wait to see if it is a tap (smoke) or a hold (offer one).
			_offer_t = 0.0
		else:
			try_use("smoke")
		c_pressed = false
	if _offer_t >= 0.0:
		_offer_t += delta
		if not c_held:
			_offer_t = -1.0
			if not cig.active():
				try_use("smoke")
		elif _offer_t >= 0.45:
			_offer_t = -1.0
			_offer_cig()
	if b_pressed and not bottle.active():
		try_use("drink")
		b_pressed = false
	var env := _env()
	# X goes to the cigarette when there is one in the hand, else to the bottle: chosen
	# when it goes down and kept till it comes up (a held X threw both).
	if not x_held:
		_x_target = ""
	elif _x_target == "":
		_x_target = "cig" if cig.active() and cig.state in [CIG.HOLD, CIG.EXHALE] else "bottle"
	var x_cig: bool = x_held and _x_target == "cig"
	cig.tick(delta, {"c_held": c_held, "c_pressed": c_pressed, "x_held": x_cig}, env)
	bottle.set_keys_for_frame(b_held)
	bottle.tick(delta, {"b_held": b_held, "b_pressed": b_pressed, "x_held": x_held and _x_target == "bottle"}, env)
	for e in cig.events:
		_cig_event(str(e[0]), e[1])
	cig.events.clear()
	for e in bottle.events:
		_bottle_event(str(e[0]), e[1])
	bottle.events.clear()
	if bottle.drunk_add > 0.0:
		drunk += bottle.drunk_add
		bottle.drunk_add = 0.0
	_update_drunk(delta)
	_claim_hands()
	_update_loops(c_held)
	_update_puffs(delta)
	_flame_t += delta
	_dying_t = maxf(0.0, _dying_t - delta)
	_foam_t = maxf(0.0, _foam_t - delta)
	_shown = can
	_acc += delta
	if _acc >= 1.0 / FPS:
		_acc = 0.0
		_layout()


## A tap shorter than a frame still counts (the press is seen here, the hold in _process).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.is_action("smoke"):
			_c_tap = true
		elif event.is_action("drink"):
			_b_tap = true
			b_tap_frame = Engine.get_process_frames()
		elif event.is_action("habit_drop"):
			_x_tap = true


## Typing in a text field (the PC's mail, a name): the keys are letters, not hands.
func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	return f is LineEdit or f is TextEdit


## Where you are, for the wind, the rain and the shaking: {indoors, wind, rain, speed}.
func _env() -> Dictionary:
	var main := _main()
	var indoors := _indoors()
	var wind := 0.15
	var rain := 0.0
	var ws = main.get("weather_system") if main != null else null
	if ws != null:
		var w := int(ws.get("current_weather"))
		wind = [0.12, 0.8, 0.05, 0.3, 0.5, 1.0, 0.2][clampi(w, 0, 6)]
		if ws.has_method("is_raining") and bool(ws.is_raining()):
			rain = 1.0 if w >= 4 else 0.5
	var p := _player()
	var speed := 0.0
	var jumped := false
	if p != null and not indoors:
		var v: Vector3 = p.get("velocity")
		speed = Vector2(v.x, v.z).length()
		var on_floor: bool = p.is_on_floor() if p.has_method("is_on_floor") else true
		jumped = _was_on_floor and not on_floor and v.y > 1.0
		_was_on_floor = on_floor
	return {"indoors": indoors, "wind": wind, "rain": rain, "speed": speed, "jumped": jumped, "drunk": drunk}


func _indoors() -> bool:
	var main := _main()
	return main != null and main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))


## Anything open over the view that wants your hands (a close-up, the PC, the boat...).
func _blocked(from_bag := false) -> bool:
	if get_tree().paused:
		return true
	for n in get_tree().get_nodes_in_group("closeup"):
		if n is CanvasLayer and (n as CanvasLayer).visible:
			return true
	var main := _main()
	if main == null:
		return true
	var im = main.get("_interior_manager")
	var bi = im.get("_building_interior") if im != null else null
	if bi != null and bool(bi.get("_crt_active")):
		return true
	for f in ["_lake_trip", "_sewer_pipe_minigame", "_utility_repair_minigame"]:
		var o = main.get(f)
		if o != null and is_instance_valid(o):
			if o.has_method("is_active") and bool(o.is_active()):
				return true
			if o.has_method("is_open") and bool(o.is_open()):
				return true
	if main.has_method("_in_attraction") and bool(main.call("_in_attraction")):
		return true
	if not from_bag and bag != null and bag.has_method("is_open") and bool(bag.is_open()):
		return true
	return false


# ── what the cigarette did ───────────────────────────────────────────────────

func _cig_event(e: String, v) -> void:
	match e:
		"pack":
			_play("c", "pack.mp3", -4.0)
		"lips":
			pass
		"strike":
			_play("c", "strike_catch.mp3" if int(v) == 1 else "strike_fail.mp3", -3.0)
			_strike_kick = 2
			_flame_t = 0.0
			_push("l", "hand5_lighting_strike", 2)
			world.send("strike", [int(v)])
		"flame_off":
			pass
		"blown_out":
			_say_once("The wind takes the flame.")
		"lit":
			_play("c2", "light_up.mp3", -4.0)
			_breathe(0.6)
			world.send("lit", [])
		"relight":
			pass
		"drag":
			_play("c2", "drag.mp3", -7.0)
		"exhale":
			var d := float(v)
			_breathe(d)
			# A drag steadies you: the breath comes back with it.
			var p := _player()
			if p != null:
				p.set("stamina", minf(1.0, float(p.get("stamina")) + 0.12 * minf(d, 2.2)))
				if float(p.get("stamina")) > 0.3:
					p.set("_stamina_locked", false)
			world.send("exhale", [d])
		"cough":
			_play("c", "cough_fit.mp3", -3.0)
			_shake = 1.0
			# Each cough a ragged little puff.
			for k in 3:
				_after(0.35 + 0.42 * k, func(): _blow(0.15))
			world.send("cough", [])
		"ash_tap":
			_play("c", "ash_tap.mp3", -6.0)
			_tap_kick = 3
			_push("l", "hand5_cig_tap", 3)
			_ash_flake(float(v))
		"ash_none":
			pass
		"ash_fall":
			_ash_flake(float(v))
		"doused":
			_play("c", "hiss_rain.mp3", -5.0)
			_say_once("The rain has put it out. C lights it again.")
		"burned":
			_play("c", "burn_fingers.mp3", -2.0)
			_say_once("Down to your fingers.")
		"throw":
			_play("c", "flick.mp3" if not _indoors() else "stub.mp3", -5.0)
		"thrown":
			world.throw_butt(float(v) > 0.0, absf(float(v)))


func _breathe(drag: float) -> void:
	_play("c", "exhale.mp3" if drag > 0.9 else "exhale_short.mp3", -6.0)
	_blow(drag)


# ── what the bottle did ──────────────────────────────────────────────────────

func _bottle_event(e: String, v) -> void:
	match e:
		"up":
			_play("b", "../town/bottle_down.mp3", -14.0)
		"lever":
			_play("b", "cap_lever.mp3", -5.0)
		"lever_stop":
			_stop("b")
		"pop":
			_play("b", "cap_pop.mp3", -3.0)
			_cap_off_screen()
			_push("r", "hand5_beer_pop", 3)
			world.cap_off()
			world.send("pop", [])
		"foam":
			_play("b2", "foam.mp3", -4.0)
			world.send("foam", [])
		"raise":
			pass
		"gulp":
			_play("b2", "gulp.mp3", -6.0)
			_gulp_kick = 2
			_push("r", "hand5_beer_gulp", 2)
			world.send("gulp", [])
		"lower":
			if int(v) == 1:
				_after(0.7, func(): _play("b", "burp_big.mp3", -3.0); world.send("burp", []))
			elif _rng.randf() < 0.25 + drunk * 0.1:
				_after(0.6, func(): _play("b", "../town/burp.mp3", -6.0); world.send("burp", []))
			_maybe_vomit()
		"empty":
			_play("b", "empty_blow.mp3", -6.0)
			_say_once("Empty. X sets it down, hold X to throw it.")
		"throw":
			pass
		"thrown":
			world.throw_bottle(float(v))
		"set_down":
			if world.partner_in_reach():
				world.send("give_bottle", [float(v)])
				_play("b", "bottle_set.mp3", -8.0)
				_say("You hand %s the bottle." % Coop.partner_name())
			else:
				_play("b", "bottle_set.mp3", -6.0)
				world.set_bottle_down(float(v))


# ── drunk ────────────────────────────────────────────────────────────────────

func _update_drunk(delta: float) -> void:
	# A bottle wears off in about two and a half minutes.
	drunk = maxf(0.0, drunk - delta / 150.0)
	_jolt = move_toward(_jolt, 0.0, delta * 6.0)
	_shake = move_toward(_shake, 0.0, delta * 1.2)
	var playing := allowed.is_valid() and bool(allowed.call())
	_wobble.visible = playing and (drunk > 0.02 or _jolt > 0.0)
	if _wobble.visible:
		_wob_mat.set_shader_parameter("amount", minf(drunk, 3.0) * 0.6)
		_wob_mat.set_shader_parameter("t", floorf(_tick * FPS) / FPS)
		_wob_mat.set_shader_parameter("jolt", _jolt)
	if not playing:
		return
	# Hiccups, from the second bottle on.
	if drunk > 1.3:
		_hiccup_t -= delta
		if _hiccup_t <= 0.0:
			_hiccup_t = _rng.randf_range(14.0, 38.0) / minf(drunk, 3.0)
			_play("fx", "hiccup.mp3", -5.0)
			_jolt = 1.0
			world.send("hiccup", [])
	# The legs do not quite go where you look: a slow drift of the heading.
	var p := _player()
	if p != null and drunk > 0.8 and not _indoors():
		_sway_t += delta
		var v: Vector3 = p.get("velocity")
		if Vector2(v.x, v.z).length() > 0.5:
			p.rotate_y(sin(_sway_t * 0.9) * delta * 0.05 * minf(drunk - 0.6, 2.5))
	if _vomit_t >= 0.0:
		_vomit_t -= delta
		if _vomit_t < 0.0:
			_play("fx", "vomit.mp3", -2.0)
			_shake = 1.0
			drunk = maxf(0.0, drunk - 1.2)
			world.vomit()
			world.send("vomit", [])


func _maybe_vomit() -> void:
	if drunk > 3.4 and _vomit_t < 0.0 and _rng.randf() < (drunk - 3.2) * 0.35:
		_vomit_t = _rng.randf_range(2.5, 6.0)


# ── the torch and the sounds that go on ──────────────────────────────────────

## Which hand holds what (hands.gd): the bottle the right, the lighter and the
## cigarette the left (the cigarette gives way to the torch and goes in your mouth).
func _claim_hands() -> void:
	if _hands == null or not is_instance_valid(_hands):
		_hands = HANDS_KIT.of(self)
		if _hands == null:
			return
	if bottle.active():
		_hands.claim("right", "bottle")
	else:
		_hands.release("right", "bottle")
	var lighting := cig.state in [CIG.PACK, CIG.LIPS]
	# Levering a cap off, the left hand has the lighter too (the cigarette in your mouth).
	if lighting or bottle.state == BOTTLE.OPENING:
		_hands.claim("left", "lighter")
	else:
		_hands.release("left", "lighter")
	if cig.active() and not lighting:
		_hands.claim("left", "cig")
	else:
		_hands.release("left", "cig")
	# The light in your hands: the lighter's flame, the ember flaring on a drag.
	if cig.state == CIG.LIPS and cig.flame == 2:
		_hands.glow("flame", Color(0.75, 0.5, 0.22) * (0.85 + 0.15 * float(int(_tick * 12.0) % 3 == 0)))
	elif cig.state == CIG.DRAG:
		_hands.glow("ember", Color(0.3, 0.1, 0.03))


## The cigarette in your mouth, not your fingers: the left hand has the torch.
func _cig_in_mouth() -> bool:
	if bottle.state == BOTTLE.OPENING:
		return true
	return _hands != null and is_instance_valid(_hands) and bool(_hands.cig_in_mouth())


var _flame_player: AudioStreamPlayer


func _update_loops(_c_held: bool) -> void:
	var want: bool = cig.state == CIG.LIPS and cig.flame == 2
	if _flame_player == null:
		_flame_player = AudioStreamPlayer.new()
		var s: AudioStream = load(SFX + "flame_loop.mp3") if ResourceLoader.exists(SFX + "flame_loop.mp3") else null
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		_flame_player.stream = s
		_flame_player.volume_db = -14.0
		add_child(_flame_player)
	if want and not _flame_player.playing:
		_flame_player.play()
	elif not want and _flame_player.playing:
		_flame_player.stop()
	if cig.state != CIG.DRAG and _audio["c2"].playing and str(_audio["c2"].get_meta("f", "")) == "drag.mp3":
		_audio["c2"].stop()


func _play(ch: String, file: String, db := -6.0) -> void:
	var path := SFX + file
	if file.begins_with("../"):
		path = "res://assets/sfx/" + file.substr(3)
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = _audio[ch]
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.set_meta("f", file)
	p.play()


func _stop(ch: String) -> void:
	_audio[ch].stop()


func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(f)


var _said: Dictionary = {}


func _say_once(text: String) -> void:
	if float(_said.get(text, -100.0)) > _tick - 20.0:
		return
	_said[text] = _tick
	_say(text)


func _say(text: String) -> void:
	var main := _main()
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, 0)


func _main() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


func _player() -> CharacterBody3D:
	var main := _main()
	return main.get("_player") as CharacterBody3D if main != null else null


# ── drawing the hands ────────────────────────────────────────────────────────

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := HANDS_KIT.px(vp.y)
	var bar := _bar_px()
	var bob := _bob() * s
	if _hands != null and is_instance_valid(_hands):
		bob += (_hands.motion as Vector2) * s
	var step := floorf(_tick * FPS)
	# Rooms: above the room's own layers, under the close-ups.
	layer = 61 if _indoors() else 58
	_offering = maxf(0.0, _offering - 1.0 / FPS)
	var left_want: bool = _shown and (cig.active() and cig.state != CIG.THROW or (cig.state == CIG.THROW and cig.t < 0.2) or _offering > 0.0)
	_left_up = move_toward(_left_up, 1.0 if left_want else 0.0, 1.0 / FPS * 4.0)
	var right_want: bool = _shown and bottle.active() and not (bottle.state == BOTTLE.THROW and bottle.t > 0.2)
	_right_up = move_toward(_right_up, 1.0 if right_want else 0.0, 1.0 / FPS * 4.0)
	_layout_left(vp, s, bar, bob, step)
	_layout_right(vp, s, bar, bob, step)
	var shake := Vector2(sin(step * 2.1), cos(step * 1.7)) * 3.0 * s * _shake
	# Lit like the place you stand in, stepped and dithered (hands.gd's material: Build
	# shade steps, PS1 dither, 15-bit colour); the flame is its own light.
	var mat: Material = _hands.material if _hands != null and is_instance_valid(_hands) else null
	for r in [_left, _cig_rect, _lips, _flame, _right]:
		var tr := r as TextureRect
		if not tr.visible:
			continue
		# On the hands' pixel grid.
		tr.position = ((tr.position + shake) / s).floor() * s
		tr.material = null if tr == _flame else mat
		tr.modulate = Color(0.78, 0.78, 0.76) if tr == _cig_rect and not cig.lit else Color.WHITE


func _layout_left(vp: Vector2, s: float, bar: float, bob: Vector2, step: float) -> void:
	var up := 1.0 - (1.0 - _left_up) * (1.0 - _left_up)
	_cig_rect.visible = false
	_lips.visible = false
	_flame.visible = false
	if up <= 0.0:
		_left.visible = false
		return
	var frame := "hand2_v"
	var mouth := false
	if _offering > 0.0 and not cig.active():
		# The pack held out at arm's length to the other warden, one tapped up for them.
		var pt := tex("hand2_pack")
		if pt != null:
			_left.texture = pt
			_left.size = pt.get_size() * s
			_left.visible = true
			var reach := 1.0 - absf(_offering - 0.55) / 0.55
			_left.position = _ease("l", Vector2(vp.x * 0.42 - _left.size.x * 0.5, vp.y - bar - _left.size.y * (0.55 + 0.35 * reach) * up), s)
		return
	if cig.state in [CIG.HOLD, CIG.DRAG, CIG.EXHALE] and _cig_in_mouth():
		# The left hand has the torch: the cigarette stays in your mouth.
		_left.visible = false
		_lay_lips(vp, s, bar, bob, true)
		return
	match cig.state:
		CIG.PACK:
			frame = "hand2_pack"
		CIG.LIPS:
			# The lighter and the cigarette in your mouth as one picture when there is one;
			# its tip catches (the same picture, the end glowing) as you draw on the flame.
			if tex("hand4_lighting") != null:
				frame = "hand4_lighting"
			else:
				frame = "hand2_lighter"
				mouth = true
		CIG.DRAG:
			frame = "hand2_v_mouth"
		CIG.EXHALE:
			frame = "hand2_v_mouth" if cig.t < 0.18 else "hand2_v"
	if frame == "hand2_v" and _hold_tex() != null:
		frame = "hold"
	elif frame == "hand2_v_mouth" and tex("hand4_cig_mouth") != null:
		frame = "hand4_cig_mouth"
	if cig.state == CIG.THROW and frame == "hold" and tex("hand5_cig_flick") != null:
		# Held a beat (cocked back by its offset), then the flick: the butt gone from the
		# fingers (a wind-up picture of its own when there is one).
		if cig.t >= 0.17:
			frame = "hand5_cig_flick"
		elif tex("hand5_cig_windup") != null:
			frame = "hand5_cig_windup"
	frame = _sequence("l", frame)
	var t := _hold_tex() if frame == "hold" else tex(frame)
	# The in-betweens with a cigarette in them burn down with it too.
	if frame == "hand5_cig_mid" and _hold_tex("mid") != null:
		t = _hold_tex("mid")
	elif frame == "hand5_cig_tap" and _hold_tex("tap") != null:
		t = _hold_tex("tap")
	if frame == "hand4_lighting" and (cig.lit or (cig.light_progress > 0.4 and int(floorf(_tick * FPS)) % 3 != 0)):
		t = tex("hand4_lighting_lit") if tex("hand4_lighting_lit") != null else t
	if t == null:
		# No picture of this hand yet: the cigarette in your mouth still shows.
		_left.visible = false
		if mouth:
			_lay_lips(vp, s, bar, bob, false)
		return
	_left.texture = t
	_left.size = t.get_size() * s
	_left.visible = true
	var x := 0.0
	var y := 0.0
	var big := frame in ["hand2_v_mouth", "hand4_cig_mouth", "hand2_lighter", "hand4_lighting", "hand2_pack"]
	# The tip of the cigarette in your mouth (cig_lips_*: it comes up from the bottom middle).
	var lips_tip := vp.y - bar - 28.0 * s
	if frame == "hand4_cig_mouth":
		# At your mouth, the palm to you: the filter at the bottom middle, in your lips.
		# (the filter's round end measured on the sprite: 46 across, at its bottom edge)
		x = vp.x * 0.5 - 46.0 * s
		y = vp.y - bar - (_left.size.y - 3.0 * s) * up + (1.0 - up) * _left.size.y * 0.3
	elif frame == "hand2_v_mouth":
		# Up at your mouth: the gap between the fingers just over the bottom middle, the
		# back of the hand filling the lower view.
		x = vp.x * 0.5 - float(ANCHOR[frame].x) * s
		y = vp.y - bar - (float(ANCHOR[frame].y) + 10.0) * s * up + (1.0 - up) * _left.size.y * 0.3
	elif frame == "hand4_lighting":
		# The cigarette's filter at your lips: the picture's bottom on the bottom edge,
		# the filter in the middle.
		x = vp.x * 0.5 - 65.0 * s
		y = vp.y - bar - _left.size.y * up + (1.0 - up) * _left.size.y * 0.25
	elif frame == "hand2_lighter":
		# The nozzle just under the tip of the one in your mouth.
		x = vp.x * 0.5 - float(ANCHOR[frame].x) * s + 2.0 * s
		y = lips_tip + 5.0 * s - float(ANCHOR[frame].y) * s * up + (1.0 - up) * _left.size.y * 0.5
	elif frame == "hand2_pack":
		x = vp.x * 0.3 - _left.size.x * 0.5
		y = vp.y - bar - _left.size.y * 0.7 * up
	elif frame == "hand5_pack_mouth":
		# The pack up at your lips, one pulled out of it.
		x = vp.x * 0.5 - _left.size.x * 0.5
		y = vp.y - bar - _left.size.y * 0.88 * up
	elif frame == "hand5_lighting_strike":
		x = vp.x * 0.5 - 65.0 * s
		y = vp.y - bar - _left.size.y * up
	elif frame == "hand5_cig_mid":
		# Halfway to your mouth.
		x = vp.x * 0.3 - _left.size.x * 0.5
		y = vp.y - bar - _left.size.y * 0.8 * up
	elif frame == "hand5_cig_windup":
		x = vp.x * 0.08
		y = vp.y - bar - _left.size.y * 0.58 * up
	elif frame == "hand5_cig_flick":
		x = vp.x * 0.16
		y = vp.y - bar - _left.size.y * 0.74 * up
	else:
		x = vp.x * 0.1
		y = vp.y - bar - _left.size.y * 0.66 * up
	var pos := Vector2(x, y) + bob * (0.5 if big else 1.0)
	# The flick of the wheel jerks the hand; a throw winds back, then snaps out.
	if _strike_kick > 0:
		pos.y += 2.0 * s
		_strike_kick -= 1
	if _tap_kick > 0 and frame != "hand5_cig_tap":
		# The finger knocks the ash off: down sharply, back a little past.
		pos.y += (3.0 if _tap_kick > 1 else -1.0) * s
		_tap_kick -= 1
	if cig.state == CIG.PACK:
		# Two taps on the heel of the hand to knock one out, then up to the mouth.
		if (cig.t > 0.32 and cig.t < 0.4) or (cig.t > 0.52 and cig.t < 0.6):
			pos.y += 4.0 * s
		elif cig.t > 0.72:
			pos += Vector2(vp.x * 0.12, -10.0 * s)
	if cig.state == CIG.THROW and frame != "hand5_cig_flick":
		pos += (Vector2(-8.0, 6.0) if cig.t < 0.15 else Vector2(46.0, -34.0)) * s
	# Drinking, the cigarette hand drops out of the way (and comes back up after).
	if bottle.state == BOTTLE.DRINK or (bottle.state == BOTTLE.FOAM and Input.is_action_pressed("drink")):
		if cig.state in [CIG.HOLD, CIG.EXHALE]:
			pos += Vector2(-6.0 * s, _left.size.y * 0.42)
	_left.position = pos.floor()
	# The cigarette in your mouth: from the bottom middle, its tip where the lighter is.
	if mouth or (cig.state == CIG.DRAG and frame != "hand4_cig_mouth"):
		_lay_lips(vp, s, bar, bob, false)
	# The flame on the lighter (and a breath of it dying when the thumb comes off).
	if cig.state == CIG.LIPS and cig.flame == 0 and _flame_was == 2:
		_dying_t = 0.12
	_flame_was = cig.flame if cig.state == CIG.LIPS else 0
	if cig.state == CIG.LIPS and cig.flame == 0 and _dying_t > 0.0:
		var dt := tex("flame_dying")
		if dt != null:
			_flame.texture = dt
			_flame.size = dt.get_size() * s
			var a0: Vector2 = _left.position + Vector2(ANCHOR.get(frame, ANCHOR["hand2_lighter"])) * s
			_flame.position = (a0 - Vector2(_flame.size.x * 0.5, _flame.size.y * 0.92)).floor()
			_flame.z_index = 2
			_flame.visible = true
	if cig.state == CIG.LIPS and cig.flame > 0 and frame != "hand5_lighting_strike":
		var ff := "flame_sparks"
		if cig.flame == 2:
			var wind := float(_env().get("wind", 0.0))
			# Catching, then a flicker between small and tall, bent over in the wind,
			# standing tall at the tip.
			if _flame_t < 0.09:
				ff = "flame_catch"
			elif wind > 0.5 and int(step) % 3 != 0:
				ff = "flame_wind"
			elif cig.light_progress > 0.6:
				ff = "flame_tall" if int(step) % 5 != 0 else "flame_small"
			else:
				ff = "flame_small" if (int(step) * 7) % 5 < 3 else "flame_tall"
		var ft := tex(ff)
		if ft != null:
			_flame.texture = ft
			_flame.size = ft.get_size() * s
			var a: Vector2 = _left.position + Vector2(ANCHOR.get(frame, ANCHOR["hand2_lighter"])) * s
			_flame.position = (a - Vector2(_flame.size.x * 0.5, _flame.size.y * 0.92)).floor()
			_flame.z_index = 2
			_flame.visible = true
	# Held: the hand with the cigarette in it, burned down to its stage (one picture,
	# cig_stages.py); the older two-piece hand only if that is missing.
	if frame == "hand2_v" and _hold_tex() != null:
		pass
	elif cig.state in [CIG.HOLD, CIG.EXHALE, CIG.THROW] and frame == "hand2_v":
		var ct := tex(cig.stage())
		if ct == null:
			ct = tex(cig.stage().replace("_out", "").replace("_ash", ""))
		if ct != null:
			_cig_rect.texture = ct
			_cig_rect.size = ct.get_size() * s
			var grip: Vector2 = _left.position + Vector2(ANCHOR["hand2_v"]) * s
			_cig_rect.position = (grip - Vector2(CIG_GRIP.x, _cig_rect.size.y / s + CIG_GRIP.y) * s).floor()
			_cig_rect.visible = true
			# Gone out in the rain: the paper greyer, no ember.
			_cig_rect.modulate = Color(0.78, 0.78, 0.76) if not cig.lit else Color.WHITE


const HOLD := "res://assets/textury/hands_lo/cig/hold_"
var _tips: Dictionary = {}


## The hand holding the cigarette at its stage now (null: not made).
func _hold_tex(pic := "hold") -> Texture2D:
	var n := _hold_stage()
	var t := tex("cig/%s_%s" % [pic, n])
	if t == null and n.ends_with("_out"):
		t = tex("cig/%s_%s" % [pic, n.trim_suffix("_out")])
	return t


## new, full, 3q, half, quarter, end; _ash with ash on it, _out gone out.
func _hold_stage() -> String:
	if not cig.lit and cig.length > 0.97:
		return "new"
	var st := "full"
	if cig.length < 0.12:
		st = "end"
	elif cig.length < 0.38:
		st = "quarter"
	elif cig.length < 0.62:
		st = "half"
	elif cig.length < 0.86:
		st = "3q"
	if not cig.lit:
		return st + "_out"
	if cig.ash > 0.1:
		if st == "full":
			st = "3q"
		if st != "end":
			return st + "_ash"
	return st


## Where the burning end is on the screen now (Vector2.INF: not in view).
func _tip_on_screen() -> Vector2:
	if not _left.visible or _left.texture == null or not _left.texture.resource_path.contains("/cig/hold_"):
		return Vector2.INF
	if _tips.is_empty():
		var f := FileAccess.open(HOLD + "tips.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			_tips = d if d is Dictionary else {}
	var key := _left.texture.resource_path.get_file().trim_prefix("hold_").trim_suffix(".png")
	var tp: Array = _tips.get(key, [])
	if tp.size() < 2:
		return Vector2.INF
	var s := _left.size.x / maxf(1.0, float(_left.texture.get_width()))
	return _left.position + Vector2(float(tp[0]), float(tp[1])) * s


## The cigarette in your mouth, from the bottom middle of the view going away.
func _lay_lips(vp: Vector2, s: float, bar: float, bob: Vector2, alone: bool) -> void:
	var lf := "cig_lips_unlit"
	# Catching: the tip glows on and off before it takes.
	if not cig.lit and cig.light_progress > 0.4:
		lf = "cig_lips_lit" if (int(floorf(_tick * FPS)) % 3) != 0 else "cig_lips_unlit"
	if cig.lit:
		lf = "cig_lips_glow" if cig.state == CIG.DRAG else "cig_lips_lit"
		if cig.length < 0.5 and cig.state != CIG.DRAG:
			lf = "cig_lips_half"
	var lt := tex(lf)
	if lt == null:
		return
	_lips.texture = lt
	_lips.size = lt.get_size() * s
	# Alone in your mouth it sits a little lower and bobs with your step.
	# Its base at the bottom edge; burned half down the tip is lower.
	var drop := 0.25 if lf == "cig_lips_half" else 0.0
	_lips.position = Vector2(vp.x * 0.5 - _lips.size.x * 0.5, vp.y - bar - _lips.size.y * (1.0 - drop) + bob.y * (0.6 if alone else 0.3))
	_lips.visible = true
	# Lighting it the cigarette is nearer the eye than the lighter; on a drag the fingers
	# are on it, nearer still.
	_lips.z_index = 1 if cig.state in [CIG.PACK, CIG.LIPS] else 0
	if cig.state == CIG.DRAG and not alone:
		# The drag: the cigarette is in your mouth and your fingers on it.
		_lips.position.y += 4.0 * s


func _layout_right(vp: Vector2, s: float, bar: float, bob: Vector2, step: float) -> void:
	var up := 1.0 - (1.0 - _right_up) * (1.0 - _right_up)
	if up <= 0.0:
		_right.visible = false
		return
	var frame: String = bottle.frame()
	# Drinking as you see it: the neck at your lips at the bottom, the bottle going up and
	# away (hand4_beer_drink); on the way up the neck comes towards you (hand4_beer_raise).
	# The old tipped one had the neck pointing away: never shown when these are there.
	if frame == "hand2_beer_drink" and tex("hand4_beer_drink") != null:
		frame = "hand4_beer_drink"
	elif frame == "hand2_beer_tilt":
		frame = "hand4_beer_raise" if tex("hand4_beer_raise") != null else ("hand4_beer_drink" if tex("hand4_beer_drink") != null else "hand2_beer_drink")
	if bottle.state == BOTTLE.OPENING and tex("hand5_beer_lever") != null:
		# Straining at the cap: the two pictures in turn, faster as it gives.
		var rate := 3 if bottle.t < bottle.open_need * 0.6 else 2
		frame = "hand5_beer_lever" if int(step / rate) % 2 == 1 else "hand2_beer_opening"
	if bottle.state == BOTTLE.THROW and tex("hand5_beer_windup") != null:
		frame = "hand5_beer_windup" if bottle.t < 0.17 else "hand5_beer_throw"
	frame = _sequence("r", frame)
	var t := tex(frame)
	if t == null:
		_right.visible = false
		return
	_right.texture = t
	_right.size = t.get_size() * s
	_right.visible = true
	var x := vp.x * 0.64
	var y := vp.y - bar - _right.size.y * 0.72 * up
	if frame == "hand4_beer_drink":
		# The neck in your mouth just under the bottom edge.
		x = vp.x * 0.5 - _right.size.x * 0.5
		y = vp.y - bar - _right.size.y * 0.97 * up + (1.0 - up) * _right.size.y * 0.4
	elif frame == "hand4_beer_raise":
		x = vp.x * 0.52 - _right.size.x * 0.4
		y = vp.y - bar - _right.size.y * 0.85 * up
	elif frame == "hand2_beer_tilt":
		x = vp.x * 0.55 - _right.size.x * 0.5
		y = vp.y - bar - _right.size.y * 0.85 * up
	elif frame == "hand2_beer_drink":
		x = vp.x * 0.5 - _right.size.x * 0.5
		y = vp.y - bar - _right.size.y * 0.95 * up
	elif frame in ["hand2_beer_opening", "hand5_beer_lever", "hand5_beer_pop"]:
		x = vp.x * 0.5 - _right.size.x * 0.5
		y = vp.y - bar - _right.size.y * 0.8 * up
		if frame != "hand5_beer_pop":
			# Straining at the cap.
			x += (2.0 if int(step) % 2 == 0 else -1.0) * s
	elif frame == "hand5_beer_gulp":
		x = vp.x * 0.5 - _right.size.x * 0.5
		y = vp.y - bar - _right.size.y * 0.97 * up
	elif frame == "hand5_beer_windup":
		x = vp.x * 0.6
		y = vp.y - bar - _right.size.y * 0.98 * up
	elif frame == "hand5_beer_throw":
		x = vp.x * 0.5 - _right.size.x * 0.45
		y = vp.y - bar - _right.size.y * 0.85 * up
	elif frame == "hand2_beer_foam":
		x += (1.0 if int(step) % 2 == 0 else -1.0) * s
	var pos := Vector2(x, y) + bob
	if frame == "hand2_beer_drink" or frame == "hand4_beer_drink":
		# Tipped further up the emptier it is; each swallow a small jog.
		# (the neck stays at your lips: the new picture tips by its base sinking less)
		if frame == "hand2_beer_drink":
			pos.y -= (1.0 - bottle.level) * 14.0 * s
		else:
			pos.y += (1.0 - bottle.level) * 4.0 * s
		if _gulp_kick > 0:
			pos.y -= 2.0 * s
			_gulp_kick -= 1
	if bottle.state == BOTTLE.FOAM and _foam_t <= 0.0 and frame == "hand2_beer_foam":
		_foam_t = 0.32
		_foam_drip()
	if bottle.state == BOTTLE.THROW and not frame.begins_with("hand5_beer_"):
		pos += (Vector2(10.0, 8.0) if bottle.t < 0.15 else Vector2(-30.0, -60.0)) * s
	if _toast > 0:
		# Na zdravi: out and up towards the other bottle, a knock, back.
		pos += Vector2(-28.0, -26.0) * s * (1.0 if _toast > 2 else 0.4)
		_toast -= 1
	_right.position = pos.floor()


## A cigarette from your pack for the other warden: the pack held out to them, one less
## in it, one in their bag (they hear the pack and are told).
func _offer_cig() -> void:
	if bag == null or not bag.has("cigs"):
		return
	bag.consume("cigs")
	_offering = 1.1
	_play("c", "pack.mp3", -4.0)
	world.send("offer_cig", [])
	_say("You offer %s a Start." % Coop.partner_name())


## The hands are animated like a Build-engine weapon: whole pictures, each held for a
## whole number of frames at twelve a second, never a glide between two places. Going
## from one pose to another plays the drawn in-between (the hand halfway to your mouth,
## the pack at your lips); a flick of the wheel, a tap of the ash, a swallow, the cap
## popping are frames of their own pushed in for a beat.
const FRAME_TICKS := 2
## (from, to) -> the pictures between them.
const BETWEEN := {
	"hold>hand4_cig_mouth": ["hand5_cig_mid"], "hand4_cig_mouth>hold": ["hand5_cig_mid"],
	"hand2_pack>hand4_lighting": ["hand5_pack_mouth"],
	"hand4_lighting>hand4_cig_mouth": [], "hand4_cig_mouth>hand4_lighting": [],
	"hand2_beer_open>hand4_beer_raise": [], "hand4_beer_drink>hand2_beer_open": ["hand4_beer_raise"],
}
var _seq_q := {"l": [], "r": []}
var _seq_to := {"l": "", "r": ""}


## A picture pushed in for `ticks` frames (if it is drawn).
func _push(side: String, frame: String, ticks: int) -> void:
	if tex(frame) == null:
		return
	(_seq_q[side] as Array).push_front([frame, ticks])


## The picture to show this frame for a hand that should be in `want`.
func _sequence(side: String, want: String) -> String:
	if want != _seq_to[side]:
		var key := "%s>%s" % [_seq_to[side], want]
		for f in BETWEEN.get(key, []):
			if tex(str(f)) != null:
				(_seq_q[side] as Array).append([str(f), FRAME_TICKS])
		_seq_to[side] = want
	var q: Array = _seq_q[side]
	if q.is_empty():
		return want
	var head: Array = q[0]
	head[1] = int(head[1]) - 1
	if int(head[1]) <= 0:
		q.pop_front()
	return str(head[0])


## (The glide is gone: a hand is where its frame puts it.)
var _eased: Dictionary = {}


func _ease(k: String, target: Vector2, s: float) -> Vector2:
	var cur: Vector2 = _eased.get(k, Vector2.INF)
	var hidden := (_left_up if k == "l" else _right_up) < 0.05
	if cur == Vector2.INF or hidden:
		cur = target
	else:
		cur += (target - cur) * 0.5
		if cur.distance_to(target) < s:
			cur = target
	_eased[k] = cur
	return cur.floor()


func _bar_px() -> float:
	if _indoors():
		return 0.0
	var main := _main()
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("get_bar_height_px"):
		return float(hud.get_bar_height_px())
	return 0.0


func _bob() -> Vector2:
	var p := _player()
	if p == null or _indoors():
		return Vector2.ZERO
	var b = p.get("_bob_offset")
	if b is Vector3:
		return Vector2((b as Vector3).x * 45.0, -(b as Vector3).y * 70.0)
	return Vector2.ZERO


# ── smoke on the screen ──────────────────────────────────────────────────────

## A breath of smoke: puffs from your mouth, more the longer the drag, drifting off with
## the wind (outdoors) or hanging (in a room). And the same breath in the world.
func _blow(drag: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var env := _env()
	var wind := 0.0 if bool(env["indoors"]) else float(env["wind"])
	# One breath: a main puff from the middle of the mouth, a couple more behind it as
	# the breath goes on (a long drag, more), rolling forward and up, thinning out
	# through the eight frames of smoke2_*; with the wind it is carried off sideways,
	# in a room it hangs and rises slowly.
	var indoors := bool(env["indoors"])
	var n := clampi(int(1.0 + drag * 1.2), 1, 4)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var k0 := vp.y / 720.0
	for k in n:
		_puffs.append({
			"pos": Vector2(vp.x * (0.5 + _rng.randf_range(-0.03, 0.03)), vp.y * (0.74 - 0.03 * k)),
			"vel": Vector2(_rng.randf_range(-14.0, 14.0) + side * wind * 180.0, _rng.randf_range(-46.0, -26.0) * (0.55 if indoors else 1.0)) * k0,
			"life": 0.0, "max": _rng.randf_range(2.0, 2.8) * (1.6 if indoors else 1.0 - wind * 0.35),
			"delay": float(k) * 0.16, "f0": 0, "soft": true, "flip": _rng.randf() < 0.5,
		})
	world.exhale(drag)


func _ash_flake(amount: float) -> void:
	var tip := _tip_on_screen()
	if tip == Vector2.INF and not _cig_rect.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var t := tex("ash_long" if amount > 0.22 else "ash_flake")
	if t == null:
		return
	# From the end of the cigarette in your fingers.
	var at := tip if tip != Vector2.INF else _cig_rect.position + Vector2(_cig_rect.size.x * 0.9, _cig_rect.size.y * 0.1)
	_falls.append({"pos": at, "vel": Vector2(_rng.randf_range(-20.0, 20.0), 40.0) * vp.y / 720.0, "tex": t, "life": 0.0})


## The breath of smoke: the soft frames (smoke2_*, alpha from the render), growing a
## little as it goes, fading smoothly, tinted by the place's light (grey at night).
func _draw_smoke() -> void:
	if tex("smoke2_0") == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var s := HANDS_KIT.px(vp.y)
	var lit: Color = _hands.light_raw if _hands != null and is_instance_valid(_hands) else Color.WHITE
	var tint := Color(maxf(lit.r, 0.22), maxf(lit.g, 0.22), maxf(lit.b, 0.24))
	var nframes := 0
	while tex("smoke2_%d" % nframes) != null and nframes < 16:
		nframes += 1
	for p in _puffs:
		if float(p["delay"]) > 0.0 or not bool(p.get("soft", false)):
			continue
		var k := clampf(float(p["life"]) / float(p["max"]), 0.0, 0.999)
		var t := tex("smoke2_%d" % int(k * float(nframes)))
		if t == null:
			continue
		var grow := 1.0 + k * 0.6
		var sz := t.get_size() * s * grow
		var at := (((p["pos"] as Vector2) - sz * 0.5) / s).floor() * s
		var a := 0.82 * pow(1.0 - k, 0.8)
		if bool(p.get("flip", false)):
			_smoke_layer.draw_set_transform(at + Vector2(sz.x, 0.0), 0.0, Vector2(-1.0, 1.0))
			_smoke_layer.draw_texture_rect(t, Rect2(Vector2.ZERO, sz), false, Color(tint.r, tint.g, tint.b, a))
			_smoke_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_smoke_layer.draw_texture_rect(t, Rect2(at, sz), false, Color(tint.r, tint.g, tint.b, a))


## The cap levered off flies up past the bottle and off the screen, turning over.
func _cap_off_screen() -> void:
	if not _right.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var k := vp.y / 720.0
	var frames: Array = []
	for n in ["cap_spin", "cap_edge", "cap_flat", "cap_edge"]:
		var t := tex(n)
		if t != null:
			frames.append(t)
	if frames.is_empty():
		return
	var at := _right.position + Vector2(_right.size.x * 0.5, _right.size.y * 0.05)
	_falls.append({"pos": at, "vel": Vector2(_rng.randf_range(-220.0, -120.0), -620.0) * k, "tex": frames[0], "life": 0.0,
		"g": 1700.0 * k, "spin": frames, "big": 2.0})


## Foam running off the mouth of the bottle and down past the hand.
func _foam_drip() -> void:
	var t := tex("foam_drip")
	if t == null or not _right.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	# Off the lip of the bottle (its mouth is near the top of the picture, a little left of
	# the middle), sliding down the glass: slow, short-lived, small.
	var at := _right.position + Vector2(_right.size.x * _rng.randf_range(0.3, 0.42), _right.size.y * _rng.randf_range(0.05, 0.14))
	_falls.append({"pos": at, "vel": Vector2(_rng.randf_range(-12.0, 12.0), 30.0) * vp.y / 720.0, "tex": t, "life": 0.0,
		"g": 160.0 * vp.y / 720.0, "max": 0.7})


func _update_puffs(delta: float) -> void:
	# A thread of smoke off the tip now and then while it is held lit.
	_wisp_t -= delta
	var tip := _tip_on_screen()
	if _wisp_t <= 0.0 and cig.lit and cig.state == CIG.HOLD and (tip != Vector2.INF or _cig_rect.visible):
		_wisp_t = _rng.randf_range(1.1, 2.0)
		var vp := get_viewport().get_visible_rect().size
		var wind := 0.0 if _indoors() else float(_env().get("wind", 0.0))
		var from := tip if tip != Vector2.INF else _cig_rect.position + Vector2(_cig_rect.size.x * 0.92, 0.0)
		_puffs.append({"pos": from + Vector2(0.0, -float(tex("smoke_2").get_height() if tex("smoke_2") != null else 20) * HANDS_KIT.px(get_viewport().get_visible_rect().size.y) * 0.5),
			"vel": Vector2(wind * 90.0 + _rng.randf_range(-6.0, 6.0), -26.0) * vp.y / 720.0,
			"life": 0.0, "max": _rng.randf_range(1.6, 2.4), "delay": 0.0, "f0": 0, "seq": WISP_SEQ})
	if _puffs.is_empty() and _falls.is_empty():
		return
	for p in _puffs:
		if float(p["delay"]) > 0.0:
			p["delay"] = float(p["delay"]) - delta
			continue
		p["life"] = float(p["life"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["vel"] = (p["vel"] as Vector2) * (1.0 - delta * 0.6)
	_puffs = _puffs.filter(func(p): return float(p["life"]) < float(p["max"]))
	for f in _falls:
		f["life"] = float(f["life"]) + delta
		f["vel"] = (f["vel"] as Vector2) + Vector2(0.0, float(f.get("g", 900.0))) * delta
		f["pos"] = (f["pos"] as Vector2) + (f["vel"] as Vector2) * delta
		# A cap turning over as it flies: its pictures in turn, twelve a second.
		if f.has("spin"):
			var fr: Array = f["spin"]
			f["tex"] = fr[int(floorf(float(f["life"]) * FPS)) % fr.size()]
	var h := get_viewport().get_visible_rect().size.y
	_falls = _falls.filter(func(f): return (f["pos"] as Vector2).y < h and float(f["life"]) < float(f.get("max", 99.0)))
	_puff_layer.queue_redraw()
	_smoke_layer.queue_redraw()


## A breath: dense, spreading, a wide cloud, torn apart, a few dots (smoke_*). The wisp
## (smoke_2) is the thread rising off the cigarette in your fingers.
const PUFF_SEQ := [0, 1, 3, 4, 5]
const WISP_SEQ := [2, 2, 5]
var _wisp_t := 0.0


## The puffs are the smoke sprites (smoke_0..5), from dense to almost gone over their
## life, at whole-pixel steps.
func _draw_puffs() -> void:
	# The smoke, the ash, the cap and the foam on the screen: the same light, shade
	# steps and PS1 dither as the hands they come from.
	if _hands != null and is_instance_valid(_hands) and _puff_layer.material != _hands.material:
		_puff_layer.material = _hands.material
	var vp := get_viewport().get_visible_rect().size
	var s := HANDS_KIT.px(vp.y)
	for p in _puffs:
		if float(p["delay"]) > 0.0 or (bool(p.get("soft", false)) and tex("smoke2_0") != null):
			continue
		var k := float(p["life"]) / float(p["max"])
		var seq: Array = p.get("seq", PUFF_SEQ)
		var fi: int = seq[mini(seq.size() - 1, int(p["f0"]) + int(k * float(seq.size() - int(p["f0"]))))]
		var t := tex("smoke_%d" % fi)
		if t == null:
			continue
		var sz := t.get_size() * s
		var at := (((p["pos"] as Vector2) - sz * 0.5) / s).floor() * s
		# Thin smoke thinning out in steps; lit and dithered by the hands' material.
		var a := floorf((0.55 * (1.0 - k * 0.7)) * 8.0) / 8.0
		_puff_layer.draw_texture_rect(t, Rect2(at, sz), false, Color(1.0, 1.0, 1.0, a))
	var lit2 := Color.WHITE
	for f in _falls:
		var t2: Texture2D = f["tex"]
		var sc := s * float(f.get("big", 1.0))
		var at2 := (((f["pos"] as Vector2)) / s).floor() * s
		_puff_layer.draw_texture_rect(t2, Rect2(at2, t2.get_size() * sc), false, lit2)


# ── co-op ────────────────────────────────────────────────────────────────────

## What the other machine needs to draw your hands on your figure (coop.gd puts it in
## the warden state as "hb").
func coop_state() -> Dictionary:
	if not cig.active() and not bottle.active():
		return {}
	return {"c": cig.coop_code(), "l": snappedf(cig.length, 0.05), "b": bottle.coop_code()}


## The pose the other machine draws your figure in (coop.gd puts it in "act"):
## a drag, lighting up, drinking always; a cigarette or a bottle held only standing.
func coop_pose(speed: float) -> String:
	if bottle.state == BOTTLE.DRINK:
		return "drink"
	if cig.state == CIG.DRAG:
		return "smoke"
	if cig.state in [CIG.PACK, CIG.LIPS]:
		return "light"
	if speed > 0.4:
		return ""
	if cig.active() and cig.state != CIG.THROW:
		return "cigar"
	if bottle.active():
		return "bottle"
	return ""


func coop_habit(kind: String, data: Array) -> void:
	if world != null:
		world.coop_habit(kind, data)


## For the screenshot driver: what each hand picture shows and where.
func debug_rects() -> Array:
	var out: Array = ["cig=%d lit=%s len=%.2f ash=%.2f bottle=%d" % [cig.state, cig.lit, cig.length, cig.ash, bottle.state]]
	for r in [_left, _cig_rect, _lips, _flame, _right]:
		var tr := r as TextureRect
		out.append("%s %s %s %s %s" % [tr.name, tr.visible, tr.texture.resource_path.get_file() if tr.texture != null else "-", tr.position, tr.size])
	return out
