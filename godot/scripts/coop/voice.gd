extends Node

## Your voice to the other wardens (co-op, carried by scripts/coop/coop.gd send_voice):
##   - your own voice: hold V (rebind it in Controls, GameSettings "radio_talk") and talk;
##     the others hear you from where you stand, near and fading with the distance
##     (Richard 24. 11.: „pořádně zprovoznit VOIP. když držim V, kliknutím přepínám jestli
##     mluvim lokálně nebo do vysílačky, když jí mám v inventáři“);
##   - the walkie-talkie, in your bag in co-op ("walkie", given as the game for two starts):
##     a click while V is held turns your talking to it and back; the others hear you out of
##     their own radio's little speaker (theirs in their bag), narrow and a bit crushed, the
##     squelch before and after, wherever they are. It comes up in your left hand while you
##     talk into it (hands_lo/radio.png). The choice stays for the next time.
##   - the megaphone, once you have it in your bag (from the room behind the office): hold
##     its key (G, "megaphone_talk"); everyone hears you from where you stand, loud, far
##     and through the horn. In your right hand while you shout.
## The microphone: AudioStreamMicrophone (project setting audio/driver/enable_input) into
## a muted bus with a capture effect, cut down to 16 kHz mono, mu-law, 20 ms a packet.
## Made by Coop (its child), so it lives as long as the game.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const RATE := 16000
const FRAME := 320
const GAIN := 1.6
const SFX := "res://assets/sfx/radio/"
const HANDS = preload("res://scripts/ui/hands.gd")
const INVENTORY = preload("res://scripts/ui/inventory.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const HAND_TEX := {"radio": "res://assets/textury/hands_lo/radio.png", "megaphone": "res://assets/textury/hands_lo/megaphone.png"}
## A packet's flags: which (radio or megaphone), the first of a go, the last.
const PA_RULES := preload("res://core/systems/pa_rules.gd")
const F_MEGA := 1
const F_START := 2
const F_END := 4
const F_LOCAL := 8
## Your own voice: full within LOCAL_NEAR metres, gone past LOCAL_FAR.
const LOCAL_NEAR := 3.0
const LOCAL_FAR := 32.0

var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
## What you are talking into now: "", "local", "radio", "megaphone".
var _sending := ""
## What V talks into: "local" (your voice, near) or "radio" (the walkie, with one in the bag).
var _v_mode := "local"
## The walkie given into the bag once a game for two is on.
var _walkie_given := false
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
	# Your own voice, near: as it is (the 3D player fades it).
	if AudioServer.get_bus_index("VoiceLocal") < 0:
		var li := AudioServer.bus_count
		AudioServer.add_bus(li)
		AudioServer.set_bus_name(li, "VoiceLocal")
		AudioServer.set_bus_send(li, "Master")
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
	_give_walkie()
	var want := ""
	if _may_talk():
		if _held("megaphone_talk") and _has_megaphone():
			want = "megaphone"
		elif _held("radio_talk") and INSTANCE.coop(self).has_partner():
			want = "radio" if _v_mode == "radio" and _has_walkie() else "local"
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
	return InputMap.has_action(action) and INSTANCE.input(self).is_action_pressed(action)


## In the game, not in a menu, not typing.
func _may_talk() -> bool:
	var tree := get_tree()
	if tree == null or tree.paused:
		return false
	var main := INSTANCE.main_of(self)
	if main == null or main.get("_gameplay_started") != true or main.get("_menu_mode") == true:
		return false
	var focus := get_viewport().gui_get_focus_owner()
	return not (focus is LineEdit or focus is TextEdit)


func _has_megaphone() -> bool:
	var bag = INVENTORY.find(get_tree())
	return bag != null and bag.has("megaphone")


func _has_walkie() -> bool:
	var bag = INVENTORY.find(get_tree())
	return bag != null and bag.has("walkie")


## A game for two on: the walkie into your bag, once (everyone had one before it was a thing
## in the bag).
func _give_walkie() -> void:
	if _walkie_given or not INSTANCE.coop(self).has_partner():
		return
	var main := INSTANCE.main_of(self)
	if main == null or main.get("_gameplay_started") != true:
		return
	var bag = INVENTORY.find(get_tree())
	if bag == null:
		return
	_walkie_given = true
	if not bag.has("walkie") and bag.has_method("add_item"):
		bag.add_item("walkie")


## A click while V is held: your voice to the walkie and back (with one in the bag). The
## click is the voice's, nothing else's.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _sending != "local" and _sending != "radio":
		return
	get_viewport().set_input_as_handled()
	if not _has_walkie():
		return
	_v_mode = "radio" if _v_mode == "local" else "local"
	_stop()
	_start(_v_mode)

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
	if kind != "local":
		_sfx("radio_on.wav" if kind == "radio" else "megaphone_on.wav", -14.0)
	_set_hand(kind)


func _stop() -> void:
	_send(PackedFloat32Array(), true)
	if _mic != null:
		_mic.stop()
	if _sending != "local":
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
	var flags := (F_MEGA if _sending == "megaphone" else 0) | (F_LOCAL if _sending == "local" else 0) | (F_START if _first else 0) | (F_END if last else 0)
	_first = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size())
	for i in samples.size():
		bytes[i] = _mulaw(samples[i])
	if INSTANCE.coop(self).has_partner():
		INSTANCE.coop(self).send_voice(flags, bytes)


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
	var main := INSTANCE.main_of(self)
	var agents = main.get("_guest_agents") if main != null else null
	if agents != null and agents.has_method("alert"):
		agents.alert(at, 45.0, 3.0)
		# Out of the PA's horns too (24. 11.: "lépe je slyšet megafon"): round every pole.
		var pa = main.get("_pa_horns")
		if pa != null and is_instance_valid(pa):
			for h in pa.horns():
				agents.alert(h, PA_RULES.RANGE_M, 3.0)


func _my_position() -> Vector3:
	var main := INSTANCE.main_of(self)
	var p = main.get("_player") if main != null else null
	return (p as Node3D).global_position if p is Node3D else Vector3.INF


# ── hearing ──────────────────────────────────────────────────────────────────

## A packet from another warden (INSTANCE.coop(self)._voice).
func on_voice(id: int, flags: int, data: PackedByteArray) -> void:
	var mega := (flags & F_MEGA) != 0
	var kind := "megaphone" if mega else ("local" if (flags & F_LOCAL) != 0 else "radio")
	# The walkie's voice out of yours: none in your bag, nothing heard.
	if kind == "radio" and not _has_walkie():
		return
	var key := "%d:%s" % [id, kind]
	var rx: Dictionary = _rx.get(key, {})
	if rx.is_empty():
		rx = _make_rx(id, kind)
		_rx[key] = rx
	var player: Node = rx["player"]
	if (flags & F_START) != 0 and kind != "local":
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
		# The same out of the PA's nearest horn (24. 11.).
		var pa_p = rx.get("pa_player")
		if pa_p != null and is_instance_valid(pa_p):
			if not (pa_p as AudioStreamPlayer3D).playing:
				(pa_p as AudioStreamPlayer3D).play()
				rx["pa_playback"] = (pa_p as AudioStreamPlayer3D).get_stream_playback()
			var pb2 = rx.get("pa_playback")
			if pb2 is AudioStreamGeneratorPlayback and (pb2 as AudioStreamGeneratorPlayback).can_push_buffer(frames.size()):
				(pb2 as AudioStreamGeneratorPlayback).push_buffer(frames)
	rx["last"] = Time.get_ticks_msec()
	if (flags & F_END) != 0:
		if kind != "local":
			_sfx_at(rx, "radio_off.wav" if not mega else "megaphone_off.wav")
		rx["last"] = 0


func _make_rx(id: int, kind: String) -> Dictionary:
	var mega := kind == "megaphone"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.6
	var player: Node
	if kind == "local":
		# Their own voice from where they stand (_update_rx), fading with the distance.
		var pl := AudioStreamPlayer3D.new()
		pl.stream = gen
		pl.bus = "VoiceLocal"
		pl.unit_size = LOCAL_NEAR
		pl.max_distance = LOCAL_FAR
		var main_l: Node = INSTANCE.main_of(self)
		var w3l = main_l.get("_world_3d") if main_l != null else null
		(w3l if w3l is Node else main_l).add_child(pl)
		return {"player": pl, "playback": null, "last": 0, "id": id, "mega": false, "local": true}
	if mega:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = gen
		p3.bus = "VoiceMegaphone"
		p3.unit_size = 30.0
		p3.max_distance = 320.0
		p3.max_db = 6.0
		player = p3
		var world: Node = INSTANCE.main_of(self)
		var w3d = world.get("_world_3d") if world != null else null
		(w3d if w3d is Node else world).add_child(p3)
		# The PA's horn nearest you says it too (24. 11.), on the PA's bus; silent with no pole.
		var gen2 := AudioStreamGenerator.new()
		gen2.mix_rate = RATE
		gen2.buffer_length = 0.6
		var pa3 := AudioStreamPlayer3D.new()
		pa3.stream = gen2
		pa3.bus = "PA"
		pa3.unit_size = 9.0
		pa3.max_distance = PA_RULES.RANGE_M + 20.0
		pa3.volume_db = -80.0
		(w3d if w3d is Node else world).add_child(pa3)
		return {"player": player, "playback": null, "last": 0, "id": id, "mega": mega, "pa_player": pa3, "pa_playback": null}
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
		if bool(rx.get("local", false)):
			_place_local(rx)
			continue
		if talking:
			on_air = "%s %s" % ["MEGAPHONE:" if bool(rx["mega"]) else "RADIO:", INSTANCE.coop(self).name_of(int(rx["id"])).to_upper()]
		if bool(rx["mega"]):
			var p3: AudioStreamPlayer3D = rx["player"]
			var fig: Node3D = INSTANCE.coop(self).figure_of(int(rx["id"]))
			if fig != null and is_instance_valid(fig) and fig.is_inside_tree():
				p3.global_position = fig.global_position + Vector3(0, 1.6, 0)
				if talking:
					_alert_guests(fig.global_position, get_process_delta_time())
			else:
				var cam := get_viewport().get_camera_3d()
				if cam != null:
					p3.global_position = cam.global_position + Vector3(0, 0, -6.0)
			# Out of the PA's horn nearest you (24. 11.).
			var pa3 = rx.get("pa_player")
			var main := INSTANCE.main_of(self)
			var pa = main.get("_pa_horns") if main != null else null
			var ear := get_viewport().get_camera_3d()
			if pa3 != null and is_instance_valid(pa3):
				var h: Vector3 = pa.nearest_horn(ear.global_position) if pa != null and is_instance_valid(pa) and ear != null else Vector3.INF
				if h == Vector3.INF:
					(pa3 as AudioStreamPlayer3D).volume_db = -80.0
				else:
					(pa3 as AudioStreamPlayer3D).global_position = h
					(pa3 as AudioStreamPlayer3D).volume_db = -3.0
	if _sending == "radio" or _sending == "megaphone":
		on_air = "%s  TALKING" % ("MEGAPHONE" if _sending == "megaphone" else "RADIO")
	_label.text = on_air
	_label.visible = on_air != ""


## Their own voice where they are: their figure in the room you are both in, else theirs in
## the camp; nowhere to be seen, not heard.
func _place_local(rx: Dictionary) -> void:
	var p3: AudioStreamPlayer3D = rx["player"]
	if p3 == null or not is_instance_valid(p3) or not p3.is_inside_tree():
		return
	var id := int(rx["id"])
	var fig: Node3D = null
	var main := INSTANCE.main_of(self)
	var im = main.get("_interior_manager") if main != null else null
	var figs = im.get("_coop_figs") if im != null else null
	if figs is Dictionary and (figs as Dictionary).has(id):
		var f = ((figs as Dictionary)[id] as Dictionary).get("fig")
		if f != null and is_instance_valid(f) and (f as Node3D).is_visible_in_tree():
			fig = f
	if fig == null:
		var camp: Node3D = INSTANCE.coop(self).figure_of(id)
		if camp != null and is_instance_valid(camp) and camp.is_visible_in_tree():
			fig = camp
	if fig == null:
		p3.volume_db = -80.0
		return
	p3.volume_db = 0.0
	p3.global_position = fig.global_position + Vector3(0, 1.55, 0)


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
	var main := INSTANCE.main_of(self)
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("get_bar_height_px"):
		bar = float(hud.get_bar_height_px())
	var y := vp.y - bar - _hand.size.y * 0.8 * raise
	var x := vp.x * 0.08 if _hand_kind == "radio" else vp.x * 0.92 - _hand.size.x
	_hand.position = (Vector2(x, y) / k).floor() * k
	if _hands != null and is_instance_valid(_hands):
		_hand.material = _hands.material
