extends CanvasLayer

## What you carry home from Lesna and use anywhere, in first person like a Build-engine
## weapon sprite (assets/textury/hands/, Grok, 12 steps a second):
##   C  a cigarette (a pack of Start has 20): the bare left hand comes up from the bottom
##      left, the lighter clicks, three drags (the tip glows, the hand comes up to the
##      mouth, smoke breathed out across the view in pixel puffs), the butt flicked
##      away. It steadies you: your stamina is back when you are done.
##   B  a bottle of Lesnak 10 (the gloved right hand): the cap pops, three long pulls
##      with the bottle tipped up, the empty set down. Each one leaves the view swimming
##      a while longer, more with every bottle (a stepped screen warp, Redneck Rampage
##      style), and a burp now and then.
## Not in rooms, close-ups, the bus or the menu; one thing at a time.
## town_trip.gd owns it and saves the counts.

const HANDS := "res://assets/textury/hands/"
const SFX := "res://assets/sfx/town/"
const FPS := 12.0
const LINES_PER_PIXEL := 300.0
const WOBBLE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float t = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float a = amount * 0.012;
	uv.x += sin(uv.y * 9.0 + t * 1.7) * a;
	uv.y += cos(uv.x * 7.0 + t * 1.3) * a * 0.7;
	vec3 c = texture(screen, uv).rgb;
	// A ghost of the view to one side, the way the eyes stop agreeing.
	vec3 g = texture(screen, uv + vec2(a * 2.2, 0.0)).rgb;
	COLOR = vec4(mix(c, (c + g) * 0.5, clamp(amount, 0.0, 0.6)), 1.0);
}
"""

var cigarettes := 0
var beers := 0
## 0.. how drunk (each bottle adds one; it wears off).
var drunk := 0.0
## Callable() -> bool: may you use something now (outdoors, playing, nothing open).
var allowed: Callable
## Callable(): smoking done (the owner gives the stamina back).
var on_smoked: Callable

var _hand: TextureRect
var _tex: Dictionary = {}
var _seq := ""                 # "", "smoke", "drink"
var _seq_t := 0.0
var _acc := 0.0
var _audio: AudioStreamPlayer
var _puffs: Array = []         # {pos, r, life}
var _puff_layer: Control
var _wobble: ColorRect
var _wob_mat: ShaderMaterial
var _tick := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Pockets"
	layer = 58
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	_rng.randomize()
	for a in [["smoke", KEY_C], ["drink", KEY_B]]:
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
	_puff_layer.draw.connect(_draw_puffs)
	add_child(_puff_layer)
	_hand = TextureRect.new()
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.visible = false
	add_child(_hand)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -4.0
	add_child(_audio)
	for n in ["cig", "cig_mouth", "beer", "beer_drink"]:
		var path: String = HANDS + str(n) + ".png"
		_tex[n] = load(path) if ResourceLoader.exists(path) else null


func _unhandled_input(event: InputEvent) -> void:
	if _seq != "" or not (allowed.is_valid() and bool(allowed.call())):
		return
	if event.is_action_pressed("smoke"):
		if cigarettes <= 0:
			_say("No cigarettes. The Jednota in Lesna has Start.")
			return
		cigarettes -= 1
		_start("smoke")
	elif event.is_action_pressed("drink"):
		if beers <= 0:
			_say("No beer. The Jednota in Lesna has Lesnak.")
			return
		beers -= 1
		_start("drink")


func is_busy() -> bool:
	return _seq != ""


func _say(text: String) -> void:
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, 0)


func _play(file: String, db := -4.0) -> void:
	if ResourceLoader.exists(SFX + file):
		_audio.stream = load(SFX + file)
		_audio.volume_db = db
		_audio.pitch_scale = _rng.randf_range(0.95, 1.05)
		_audio.play()


func _start(what: String) -> void:
	_seq = what
	_seq_t = 0.0
	_cue = 0


# ── the sequences ────────────────────────────────────────────────────────────

## Smoking: [time, frame, raise 0..1, event]; drinking likewise.
const SMOKE := [
	[0.0, "cig", 0.0, ""], [0.5, "cig", 1.0, "light"], [1.6, "cig_mouth", 1.0, "draw"],
	[3.0, "cig", 1.0, "exhale"], [5.2, "cig_mouth", 1.0, "draw"], [6.6, "cig", 1.0, "exhale"],
	[8.8, "cig_mouth", 1.0, "draw"], [10.2, "cig", 1.0, "exhale_cough"], [12.4, "cig", 0.0, "flick"], [13.2, "", 0.0, "end"],
]
const DRINK := [
	[0.0, "beer", 0.0, ""], [0.5, "beer", 1.0, "open"], [1.4, "beer_drink", 1.0, "gulp"],
	[3.6, "beer", 1.0, ""], [4.6, "beer_drink", 1.0, "gulp"], [6.8, "beer", 1.0, "burp"],
	[8.0, "beer", 0.0, "down"], [8.8, "", 0.0, "end"],
]

var _cue := 0


func _process(delta: float) -> void:
	_tick += delta
	# Drunk wears off (a bottle lasts about two minutes).
	drunk = maxf(0.0, drunk - delta / 120.0)
	_wobble.visible = drunk > 0.02 and (allowed.is_valid() and bool(allowed.call()) or _seq != "")
	if _wobble.visible:
		# The warp moves in steps too.
		_wob_mat.set_shader_parameter("amount", minf(drunk, 3.0) * 0.6)
		_wob_mat.set_shader_parameter("t", floorf(_tick * FPS) / FPS)
	_update_puffs(delta)
	if _seq == "":
		_hand.visible = false
		return
	_seq_t += delta
	var seq: Array = SMOKE if _seq == "smoke" else DRINK
	while _cue < seq.size() and _seq_t >= float(seq[_cue][0]):
		_event(str(seq[_cue][3]))
		_cue += 1
	if _seq == "":
		return
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	# The frame and how far up it is: between the cues, eased, in steps.
	var i := maxi(0, _cue - 1)
	var cur: Array = seq[i]
	var nxt: Array = seq[mini(i + 1, seq.size() - 1)]
	var span := maxf(0.001, float(nxt[0]) - float(cur[0]))
	var k := clampf((_seq_t - float(cur[0])) / span, 0.0, 1.0)
	var raise := lerpf(float(cur[2]), float(nxt[2]), smoothstep(0.0, 1.0, minf(1.0, k * 2.5)))
	var frame := str(cur[1])
	if frame == "" or _tex.get(frame) == null:
		_hand.visible = false
		return
	_hand.texture = _tex[frame]
	_hand.visible = true
	var vp := get_viewport().get_visible_rect().size
	var s := float(maxi(1, int(round(vp.y / LINES_PER_PIXEL))))
	var big := 1.25 if frame.ends_with("_mouth") or frame.ends_with("_drink") else 1.0
	_hand.size = _hand.texture.get_size() * s * big
	var bob := Vector2(sin(floorf(_tick * FPS) * 0.5) * 2.0, cos(floorf(_tick * FPS) * 0.33) * 2.0) * s
	var x := 0.0
	if _seq == "smoke":
		x = vp.x * (0.08 if big > 1.0 else 0.12)
	else:
		x = vp.x * (0.42 if big > 1.0 else 0.62)
	var y := vp.y - _hand.size.y * (0.9 if big > 1.0 else 0.8) * raise + _hand.size.y * (1.0 - raise) * 0.2
	_hand.position = (Vector2(x, y) + bob).floor()
	# The cigarette's tip glows on a drag.
	_hand.modulate = Color.WHITE


func _event(e: String) -> void:
	match e:
		"light":
			_play("light.mp3")
		"draw":
			_play("draw.mp3", -6.0)
		"exhale", "exhale_cough":
			_play("exhale.mp3", -6.0)
			_blow()
			if e == "exhale_cough" and _rng.randf() < 0.5:
				get_tree().create_timer(1.0).timeout.connect(func(): _play("cough.mp3", -6.0))
		"flick":
			pass
		"open":
			_play("beer_open.mp3")
		"gulp":
			_play("gulp.mp3", -4.0)
		"burp":
			if _rng.randf() < 0.6:
				_play("burp.mp3", -6.0)
		"down":
			_play("bottle_down.mp3", -8.0)
			drunk += 1.0
		"end":
			var was := _seq
			_seq = ""
			_hand.visible = false
			if was == "smoke" and on_smoked.is_valid():
				on_smoked.call()


# ── smoke ────────────────────────────────────────────────────────────────────

## A breath of smoke: a few puffs from low in the middle, drifting up and out.
func _blow() -> void:
	var vp := get_viewport().get_visible_rect().size
	for k in 7:
		_puffs.append({
			"pos": Vector2(vp.x * _rng.randf_range(0.38, 0.55), vp.y * _rng.randf_range(0.78, 0.9)),
			"vel": Vector2(_rng.randf_range(-40.0, 60.0), _rng.randf_range(-90.0, -50.0)),
			"r": _rng.randf_range(10.0, 22.0) * vp.y / 720.0,
			"life": 0.0, "max": _rng.randf_range(1.6, 2.6), "delay": float(k) * 0.09,
		})


func _update_puffs(delta: float) -> void:
	if _puffs.is_empty():
		return
	for p in _puffs:
		if float(p["delay"]) > 0.0:
			p["delay"] = float(p["delay"]) - delta
			continue
		p["life"] = float(p["life"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["r"] = float(p["r"]) + delta * 26.0
	_puffs = _puffs.filter(func(p): return float(p["life"]) < float(p["max"]))
	_puff_layer.queue_redraw()


## Pixel puffs: dithered discs that thin out as they spread, positions in steps.
func _draw_puffs() -> void:
	var vp := get_viewport().get_visible_rect().size
	var px := float(maxi(2, int(round(vp.y / 240.0))))
	for p in _puffs:
		if float(p["delay"]) > 0.0:
			continue
		var fade := 1.0 - float(p["life"]) / float(p["max"])
		var c: Vector2 = ((p["pos"] as Vector2) / px).floor() * px
		var r: float = p["r"]
		var steps := int(r / px)
		for gy in range(-steps, steps + 1):
			for gx in range(-steps, steps + 1):
				var d := Vector2(gx, gy).length() / maxf(1.0, float(steps))
				if d > 1.0:
					continue
				# Ordered dither: fewer dots towards the edge and as it fades.
				var bayer := float(((gx & 1) * 2 + (gy & 1) * 3) % 4) / 4.0
				if bayer > fade * (1.1 - d):
					continue
				_puff_layer.draw_rect(Rect2(c + Vector2(gx, gy) * px, Vector2(px, px)), Color(0.82, 0.82, 0.8, 0.55))
