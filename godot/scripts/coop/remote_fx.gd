extends Node

## The night's screen and ears of another warden (scripts/night/nightmare_fx.gd, on their
## machine), for an enemy brain on the host's that hunts their stand-in (coop_proxy.gd):
## every call goes over to them (Coop.send_night_fx) and is played there, on their screen
## alone. What a brain gives it is sent as it can travel: a texture as its path, a camera
## as "their own camera". `ext` is for what is not the fx layer's (the Photographer's
## pictures: coop_night.gd `_on_ext`). Calls that say the same as the last of their kind
## (a close-up held, the presence each tick) are not sent again.

const FX_TEX := preload("res://scripts/night/fx_tex.gd")

## The peer whose screen this is.
var peer := 0


func _init(p := 0) -> void:
	peer = p
var _last := {}
var _presence := 0.0
## The steady ones (each tick from a brain): at most this often each.
const STEADY := {"set_dread": 0.1, "set_presence": 0.1, "set_eyes": 0.05}
var _steady_at := {}


static func pack(v):
	# A texture as fx_tex.gd has it: its path, or how it was made (the head turned upside
	# down, the mouth cut out of a face), so the other machine makes it too.
	if v is Texture2D:
		return {"_tex": FX_TEX.encode(v as Texture2D)}
	if v is Camera3D:
		return {"_cam": true}
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(pack(x))
		return out
	return v


func _send(method: String, args: Array) -> void:
	if peer == 0:
		return
	var packed: Array = pack(args)
	var key := method
	if method in ["set_dread", "set_presence"]:
		key = method + str(args[0])
	var now := Time.get_ticks_msec() / 1000.0
	# The steady ones again now and then even unchanged: the other side lets a level go
	# a second after it last heard of it (so one the brain forgets does not hang on).
	var stale := STEADY.has(method) and now - float(_steady_at.get(key, -9.0)) > 0.5
	if _last.get(key) == packed and not stale:
		return
	if STEADY.has(method):
		if now - float(_steady_at.get(key, -9.0)) < float(STEADY[method]):
			return
		_steady_at[key] = now
	_last[key] = packed
	# A one-off (a face for two frames, a flash) is always sent; only what holds is kept.
	if method in ["subliminal", "freeze", "glitch", "red_flash", "tinnitus", "white_blast", "blood", "ext"]:
		_last.erase(key)
	# An "off" ends what was on: always said, and the next "on" is new again.
	if method.ends_with("_off"):
		_last.erase(key)
		_last.erase(method.trim_suffix("_off"))
		if method == "close_up_off":
			_last.erase("overlay")
			_last.erase("split")
	Coop.send_night_fx(method, packed, peer)


func set_dread(source: String, level: float) -> void:
	_send("set_dread", [source, snappedf(level, 0.02)])


func set_presence(source: String, level: float) -> void:
	_presence = maxf(_presence * 0.9, level)
	_send("set_presence", [source, snappedf(level, 0.02)])


func presence() -> float:
	return _presence


func set_eyes(source: String, head: Vector3, cam: Camera3D, open: float = 1.0, tilt: float = 0.0, half_gap: float = 0.035, open2: float = -1.0) -> void:
	_send("set_eyes", [source, head.snapped(Vector3.ONE * 0.01), cam, snappedf(open, 0.05), snappedf(tilt, 0.01), half_gap, snappedf(open2, 0.05)])


func close_up(tex: Texture2D, scale: float, stretch_y: float = 1.0, shake: float = 0.0, rot: float = 0.0, off: Vector2 = Vector2.ZERO) -> void:
	_send("close_up", [tex, snappedf(scale, 0.01), stretch_y, shake, snappedf(rot, 0.01), off])


func close_up_off() -> void:
	_send("close_up_off", [])
	_last.erase("close_up")


func overlay(tex: Texture2D, scale: float, shake: float = 0.0, off: Vector2 = Vector2.ZERO, rot: float = 0.0) -> void:
	_send("overlay", [tex, snappedf(scale, 0.01), shake, off, snappedf(rot, 0.01)])


func overlay_off() -> void:
	_send("overlay_off", [])
	_last.erase("overlay")


func split(tex: Texture2D, scale: float, open: float, shake: float = 0.0) -> void:
	_send("split", [tex, snappedf(scale, 0.01), snappedf(open, 0.01), shake])


func split_off() -> void:
	_send("split_off", [])
	_last.erase("split")


func blood(amount: float, at: Vector2 = Vector2(-1, -1)) -> void:
	_send("blood", [amount, at])


func blood_off() -> void:
	_send("blood_off", [])


func set_black(alpha: float) -> void:
	_send("set_black", [snappedf(alpha, 0.02)])


func glitch(amount: float, seconds: float) -> void:
	_send("glitch", [amount, seconds])


func subliminal(tex: Texture2D, frames: int = 2, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	_send("subliminal", [tex, frames, scale, tint])


func freeze(seconds: float) -> void:
	_send("freeze", [seconds])


func red_flash(alpha: float) -> void:
	_send("red_flash", [alpha])


func white_blast(strength: float = 1.0) -> void:
	_send("white_blast", [strength])


func tinnitus(seconds: float) -> void:
	_send("tinnitus", [seconds])


## Their view turned by the enemy (enemy_base.gd `_set_yaw/_pitch/_roll`): the turn from
## where it was when it began; each says it all, so it may be lost on the way.
func view(pitch: float, roll: float, yaw: float) -> void:
	if peer != 0:
		Coop.send_night_fx("look", [pitch, roll, yaw], peer)


func view_off() -> void:
	_send("view_off", [])


## Their warden dragged to `to`.
func move_to(to: Vector3) -> void:
	_send("move_to", [to])


## A sound in the room with them, no direction.
func play_2d(file: String, db: float, pitch: float) -> void:
	_send("play_2d", [file, db, pitch])
	_last.erase("play_2d")


## Something of an enemy's own on their screen (coop_night.gd `_on_ext`).
func ext(what: String, args: Array) -> void:
	_send("ext", [what, args])
