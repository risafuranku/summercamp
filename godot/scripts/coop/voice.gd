extends Node

## Your voice to the other wardens (co-op, carried by scripts/coop/coop.gd send_voice):
##   - the walkie-talkie, every warden's in co-op: hold its key (V; rebind it in Controls,
##     GameSettings "radio_talk") and talk; the others hear you out of their own radio's
##     little speaker, narrow and a bit crushed, the squelch before and after. It comes
##     up in your left hand while you talk (hands_lo/radio.png).
##   - the megaphone, once you have it in your bag (from the room behind the office): hold
##     its key (G, "megaphone_talk"); everyone hears you from where you stand, loud, far
##     and through the horn. In your right hand while you shout.
## The microphone: AudioStreamMicrophone (project setting audio/driver/enable_input) into
## a muted bus with a capture effect, cut down to 16 kHz mono, mu-law, 20 ms a packet.
## Made by Coop (its child), so it lives as long as the game.

const RATE := 16000
const FRAME := 320
const GAIN := 1.6
const SFX := "res://assets/sfx/radio/"
const HANDS = preload("res://scripts/ui/hands.gd")
const INVENTORY = preload("res://scripts/ui/inventory.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const HAND_TEX := {"radio": "res://assets/textury/hands_lo/radio.png", "megaphone": "res://assets/textury/hands_lo/megaphone.png"}
## A packet's flags: which (radio or megaphone), the first of a go, the last.
const F_MEGA := 1
const F_START := 2
const F_END := 4

var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
## What you are talking into now: "", "radio", "megaphone".
var _sending := ""
var _first := true
var _out := PackedFloat32Array()
var _sum := 0.0
var _count := 0
var _pos := 0.0
var _step := 3.0
## Hearing the others: "id:radio" / "id:megaphone" -> {player, playback, last, id}.
var _rx: Dictionary = {}
var _layer: CanvasLayer
var _hand: TextureRect
var _hand_kind := ""
var _up := 0.0
var _label: Label
var _hands: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buses()
	_layer = CanvasLayer.new()
	_layer.layer = 59
	add_child(_layer)
	_hand = TextureRect.new()
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.visible = false
	_layer.add_child(_hand)
	_label = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, 2)
	_label.anchor_left = 0.0
	_label.anchor_top = 0.0
	_label.position = Vector2(16, 44)
	_label.visible = false
	_layer.add_child(_label)


# ── the buses the voices go through ─────────────────────────────────────────

func _buses() -> void:
	if AudioServer.get_bus_index("VoiceMic") < 0:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, "VoiceMic")
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(i, _capture)
		AudioServer.set_bus_mute(i, true)
	else:
		_capture = AudioServer.get_bus_effect(AudioServer.get_bus_index("VoiceMic"), 0) as AudioEffectCapture
	# The radio's speaker: narrow and crushed. The megaphone's horn: harder, louder.
	for spec in [["VoiceRadio", 380.0, 3000.0, 0.22, 0.0], ["VoiceMegaphone", 520.0, 3600.0, 0.42, 4.0]]:
		if AudioServer.get_bus_index(str(spec[0])) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, str(spec[0]))
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = float(spec[1])
		AudioServer.add_bus_effect(i, hp)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = float(spec[2])
		AudioServer.add_bus_effect(i, lp)
		var dist := AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
		dist.drive = float(spec[3])
		AudioServer.add_bus_effect(i, dist)
		AudioServer.set_bus_volume_db(i, float(spec[4]))
		AudioServer.set_bus_send(i, "Master")


# ── talking ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var want := ""
	if _may_talk():
		if _held("megaphone_talk") and _has_megaphone():
			want = "megaphone"
		elif _held("radio_talk") and Coop.has_partner():
			want = "radio"
	if want != _sending:
		if _sending != "":
			_stop()
		if want != "":
			_start(want)
	if _sending != "":
		_pump()
		if _sending == "megaphone":
			_alert_guests(_my_position(), delta)
	_update_rx()
	_update_hand(delta)


func _held(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


## In the game, not in a menu, not typing.
func _may_talk() -> bool:
	var tree := get_tree()
	if tree == null or tree.paused:
		return false
	var main := tree.current_scene
	if main == null or main.get("_gameplay_started") != true or main.get("_menu_mode") == true:
		return false
	var focus := get_viewport().gui_get_focus_owner()
	return not (focus is LineEdit or focus is TextEdit)


func _has_megaphone() -> bool:
	var bag = INVENTORY.find(get_tree())
	return bag != null and bag.has("megaphone")


func _start(kind: String) -> void:
	if _mic == null:
		_mic = AudioStreamPlayer.new()
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = "VoiceMic"
		add_child(_mic)
	_step = AudioServer.get_mix_rate() / float(RATE)
	if _capture != null:
		_capture.clear_buffer()
	_mic.play()
	_sending = kind
	_first = true
	_out.clear()
	_sum = 0.0
	_count = 0
	_pos = 0.0
	_sfx("radio_on.wav" if kind == "radio" else "megaphone_on.wav", -14.0)
	_set_hand(kind)


func _stop() -> void:
	_send(PackedFloat32Array(), true)
	if _mic != null:
		_mic.stop()
	_sfx("radio_off.wav" if _sending == "radio" else "megaphone_off.wav", -14.0)
	_sending = ""
	_set_hand("")


## What the microphone took since last time: mono, down to RATE (each new sample the
## mean of the ones it stands for), sent FRAME at a time.
func _pump() -> void:
	if _capture == null:
		return
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var buf := _capture.get_buffer(n)
	for f in buf:
		_sum += (f.x + f.y) * 0.5
		_count += 1
		_pos += 1.0
		if _pos >= _step:
			_pos -= _step
			_out.append(clampf(_sum / float(_count) * GAIN, -1.0, 1.0))
			_sum = 0.0
			_count = 0
	while _out.size() >= FRAME:
		_send(_out.slice(0, FRAME), false)
		_out = _out.slice(FRAME)


func _send(samples: PackedFloat32Array, last: bool) -> void:
	var flags := (F_MEGA if _sending == "megaphone" else 0) | (F_START if _first else 0) | (F_END if last else 0)
	_first = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size())
	for i in samples.size():
		bytes[i] = _mulaw(samples[i])
	if Coop.has_partner():
		Coop.send_voice(flags, bytes)


static func _mulaw(x: float) -> int:
	var m := absf(x)
	var y := log(1.0 + 255.0 * m) / log(256.0)
	return (0x80 if x < 0.0 else 0) | int(clampf(y, 0.0, 1.0) * 127.0)


static func _unmulaw(b: int) -> float:
	var m := float(b & 0x7F) / 127.0
	var x := (pow(256.0, m) - 1.0) / 255.0
	return -x if (b & 0x80) != 0 else x


## The camp's guests near the one on the megaphone look up (guest_agents.alert),
## twice a second at most.
var _alert_t := 0.0


func _alert_guests(at: Vector3, delta: float) -> void:
	_alert_t -= delta
	if _alert_t > 0.0 or at == Vector3.INF:
		return
	_alert_t = 0.5
	var main := get_tree().current_scene
	var agents = main.get("_guest_agents") if main != null else null
	if agents != null and agents.has_method("alert"):
		agents.alert(at, 45.0, 3.0)


func _my_position() -> Vector3:
	var main := get_tree().current_scene
	var p = main.get("_player") if main != null else null
	return (p as Node3D).global_position if p is Node3D else Vector3.INF


# ── hearing ──────────────────────────────────────────────────────────────────

## A packet from another warden (Coop._voice).
func on_voice(id: int, flags: int, data: PackedByteArray) -> void:
	var mega := (flags & F_MEGA) != 0
	var key := "%d:%s" % [id, "megaphone" if mega else "radio"]
	var rx: Dictionary = _rx.get(key, {})
	if rx.is_empty():
		rx = _make_rx(id, mega)
		_rx[key] = rx
	var player: Node = rx["player"]
	if (flags & F_START) != 0:
		_sfx_at(rx, "radio_on.wav" if not mega else "megaphone_on.wav")
	if not player.get("playing"):
		player.call("play")
		rx["playback"] = player.call("get_stream_playback")
	var pb = rx.get("playback")
	if pb is AudioStreamGeneratorPlayback and data.size() > 0:
		var frames := PackedVector2Array()
		frames.resize(data.size())
		for i in data.size():
			var v := _unmulaw(data[i])
			frames[i] = Vector2(v, v)
		if (pb as AudioStreamGeneratorPlayback).can_push_buffer(frames.size()):
			(pb as AudioStreamGeneratorPlayback).push_buffer(frames)
	rx["last"] = Time.get_ticks_msec()
	if (flags & F_END) != 0:
		_sfx_at(rx, "radio_off.wav" if not mega else "megaphone_off.wav")
		rx["last"] = 0


func _make_rx(id: int, mega: bool) -> Dictionary:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.6
	var player: Node
	if mega:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = gen
		p3.bus = "VoiceMegaphone"
		p3.unit_size = 30.0
		p3.max_distance = 320.0
		p3.max_db = 6.0
		player = p3
		var world: Node = get_tree().current_scene
		var w3d = world.get("_world_3d") if world != null else null
		(w3d if w3d is Node else world).add_child(p3)
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = gen
		p2.bus = "VoiceRadio"
		player = p2
		add_child(p2)
	return {"player": player, "playback": null, "last": 0, "id": id, "mega": mega}


## The megaphone sounds from the one shouting (their figure in your world); the radio
## from your own. The name of who is on the air.
func _update_rx() -> void:
	var on_air := ""
	var now := Time.get_ticks_msec()
	for key in _rx.keys():
		var rx: Dictionary = _rx[key]
		var talking := now - int(rx["last"]) < 400
		if talking:
			on_air = "%s %s" % ["MEGAPHONE:" if bool(rx["mega"]) else "RADIO:", Coop.name_of(int(rx["id"])).to_upper()]
		if bool(rx["mega"]):
			var p3: AudioStreamPlayer3D = rx["player"]
			var fig: Node3D = Coop.figure_of(int(rx["id"]))
			if fig != null and is_instance_valid(fig) and fig.is_inside_tree():
				p3.global_position = fig.global_position + Vector3(0, 1.6, 0)
				if talking:
					_alert_guests(fig.global_position, get_process_delta_time())
			else:
				var cam := get_viewport().get_camera_3d()
				if cam != null:
					p3.global_position = cam.global_position + Vector3(0, 0, -6.0)
	if _sending != "":
		on_air = "%s  TALKING" % ("MEGAPHONE" if _sending == "megaphone" else "RADIO")
	_label.text = on_air
	_label.visible = on_air != ""


func _sfx(file: String, db: float) -> void:
	if not ResourceLoader.exists(SFX + file):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(SFX + file)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _sfx_at(rx: Dictionary, file: String) -> void:
	if not ResourceLoader.exists(SFX + file):
		return
	if bool(rx["mega"]):
		var src: AudioStreamPlayer3D = rx["player"]
		var p := AudioStreamPlayer3D.new()
		p.stream = load(SFX + file)
		p.unit_size = 20.0
		p.max_distance = 300.0
		p.bus = "VoiceMegaphone"
		src.get_parent().add_child(p)
		p.global_position = src.global_position
		p.play()
		p.finished.connect(p.queue_free)
	else:
		_sfx(file, -10.0)


# ── in your hand ─────────────────────────────────────────────────────────────

func _set_hand(kind: String) -> void:
	if _hands == null or not is_instance_valid(_hands):
		_hands = HANDS.of(self)
	if _hands != null:
		_hands.release("left", "radio")
		_hands.release("right", "megaphone")
		if kind == "radio":
			_hands.claim("left", "radio")
		elif kind == "megaphone":
			_hands.claim("right", "megaphone")
	if kind != "":
		_hand_kind = kind
		var path: String = HAND_TEX.get(kind, "")
		_hand.texture = load(path) if ResourceLoader.exists(path) else null


func _update_hand(delta: float) -> void:
	_up = move_toward(_up, 1.0 if _sending != "" else 0.0, delta * 5.0)
	_hand.visible = _up > 0.0 and _hand.texture != null
	if not _hand.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var k := HANDS.px(vp.y)
	_hand.size = _hand.texture.get_size() * k
	var raise := 1.0 - (1.0 - _up) * (1.0 - _up)
	var bar := 0.0
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("get_bar_height_px"):
		bar = float(hud.get_bar_height_px())
	var y := vp.y - bar - _hand.size.y * 0.8 * raise
	var x := vp.x * 0.08 if _hand_kind == "radio" else vp.x * 0.92 - _hand.size.x
	_hand.position = (Vector2(x, y) / k).floor() * k
	if _hands != null and is_instance_valid(_hands):
		_hand.material = _hands.material
