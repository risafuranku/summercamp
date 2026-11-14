extends RefCounted

## The configuration's rows and what each does (one place for every screen that sets
## them: retro_menu.gd OptionsPage, the pause menu's plate; scripts/ui/title/page_config.gd,
## the title's printout on the counter). A row is {id, name} and either "bar" (its steps,
## drawn as a scale) or "action" (it goes somewhere: the screen does that). value(id) is
## what the row shows now, change(id, dir) steps it (-1 / +1). Settings are GameSettings'
## (this machine's), the view and body and the work hints the warden's (profiles.gd).

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const PROFILES = preload("res://scripts/profiles.gd")
const LANG = preload("res://scripts/lang.gd")

const MODE_IDS := ["windowed", "fullscreen", "borderless"]
const MODE_LABELS := ["WINDOWED", "FULLSCREEN", "BORDERLESS"]
## The bottom is off (GameSettings.MASTER_DB_OFF mutes Master), not -40 dB still heard.
const VOLUME_STEPS := [-80.0, -40.0, -30.0, -24.0, -20.0, -16.0, -12.0, -9.0, -6.0, -4.0, -2.0, 0.0, 3.0, 6.0]
const MOUSE_STEPS := [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
## View and body (the warden's: profiles.gd profile_body): the FOV, how much the head
## bobs and leans (0 against sickness).
const FOV_STEPS := [60.0, 64.0, 68.0, 72.0, 76.0, 80.0, 84.0, 90.0]
const PCT_STEPS := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

## The settings themselves, the machine's (no going-somewhere rows).
const MAIN := [
	{"id": "mode", "name": "Window mode"},
	{"id": "resolution", "name": "Resolution"},
	{"id": "render", "name": "Render style"},
	{"id": "palette", "name": "256-colour palette"},
	{"id": "volume", "name": "Master volume", "bar": 13},
	{"id": "mic", "name": "Microphone"},
	# The pointer's speed for every look (playtest 1. 11.: "add mouse sensitivity": it was
	# only the warden's X and Y, two pages down); those stay as fine tuning.
	{"id": "mouse", "name": "Mouse sensitivity", "bar": 9},
	{"id": "hints", "name": "Work hints"},
]
const BODY := [
	{"id": "fov", "name": "Field of view"},
	{"id": "mouse_x", "name": "Mouse X", "bar": 9},
	{"id": "mouse_y", "name": "Mouse Y", "bar": 9},
	{"id": "invert", "name": "Invert mouse Y"},
	{"id": "bob", "name": "Head bob", "bar": 10},
	{"id": "lean", "name": "Lean", "bar": 10},
	{"id": "crouch", "name": "Crouch (Ctrl)"},
]


## What the row says now: {"text": the value in English (translate it to show it; "" for
## none), "bar": 0..1 along its scale (-1: no scale)}.
static func value(id: String) -> Dictionary:
	var text := ""
	var bar := -1.0
	if GameSettings == null:
		return {"text": text, "bar": bar}
	match id:
		"mode":
			text = MODE_LABELS[maxi(0, MODE_IDS.find(GameSettings.get_window_mode()))]
		"resolution":
			var r: Vector2i = GameSettings.get_resolution()
			text = "%d X %d" % [r.x, r.y]
			if GameSettings.get_window_mode() != "windowed":
				text = "DESKTOP"
		"render":
			text = str(RETRO_RENDER.PRESET_LABELS.get(GameSettings.get_retro_preset(), "")).to_upper()
		"palette":
			text = "ON" if GameSettings.get_retro_palette_enabled() else "OFF"
		"volume":
			var db: float = GameSettings.get_master_volume_db()
			var vi := nearest(VOLUME_STEPS, db)
			text = "OFF" if vi == 0 else "%+d DB" % int(round(db))
			bar = float(vi) / float(VOLUME_STEPS.size() - 1)
		"mouse":
			var m: float = GameSettings.get_mouse_sensitivity()
			text = "%d%%" % int(round(m * 100.0))
			bar = float(nearest(MOUSE_STEPS, m) + 1) / float(MOUSE_STEPS.size())
		"mic":
			text = mic_name(GameSettings.get_mic_device())
		"invert":
			text = "ON" if GameSettings.get_invert_mouse_y() else "OFF"
		"hints":
			# The businesses' next step lit (the brief of 21. 10.), the warden's.
			text = "ON" if PROFILES.profile_hints() else "OFF"
		"fov":
			text = "%d°" % int(round(float(body().get("fov", 72.0))))
		"mouse_x", "mouse_y":
			var mb := float(body().get(id, 1.0))
			text = "%d%%" % int(round(mb * 100.0))
			bar = float(nearest(MOUSE_STEPS, mb) + 1) / float(MOUSE_STEPS.size())
		"bob", "lean":
			var pb := float(body().get(id, 1.0))
			text = "%d%%" % int(round(pb * 100.0))
			bar = float(nearest(PCT_STEPS, pb)) / float(PCT_STEPS.size() - 1)
		"crouch":
			text = "TOGGLE" if bool(body().get("crouch_toggle", false)) else "HOLD"
	return {"text": text, "bar": bar}


## Steps the row by `dir` (+1 / -1): false when it is not a setting.
static func change(id: String, dir: int) -> bool:
	if GameSettings == null:
		return false
	match id:
		"mode":
			var mi := posmod(MODE_IDS.find(GameSettings.get_window_mode()) + dir, MODE_IDS.size())
			GameSettings.set_window_mode(MODE_IDS[mi], true, true)
		"resolution":
			var list: Array[Vector2i] = GameSettings.get_supported_resolutions()
			var ri := posmod(list.find(GameSettings.get_resolution()) + dir, list.size())
			GameSettings.set_resolution(list[ri], true, true)
		"render":
			var order: Array[String] = RETRO_RENDER.PRESET_ORDER
			var pi := posmod(order.find(GameSettings.get_retro_preset()) + dir, order.size())
			GameSettings.set_retro_preset(order[pi], true)
		"palette":
			GameSettings.set_retro_palette_enabled(not GameSettings.get_retro_palette_enabled(), true)
		"volume":
			var vi := clampi(nearest(VOLUME_STEPS, GameSettings.get_master_volume_db()) + dir, 0, VOLUME_STEPS.size() - 1)
			GameSettings.set_master_volume_db(VOLUME_STEPS[vi], true, true)
		"mouse":
			var mi2 := clampi(nearest(MOUSE_STEPS, GameSettings.get_mouse_sensitivity()) + dir, 0, MOUSE_STEPS.size() - 1)
			GameSettings.set_mouse_sensitivity(MOUSE_STEPS[mi2], true)
		"mic":
			var devices: Array = GameSettings.get_mic_devices()
			var di := posmod(devices.find(GameSettings.get_mic_device()) + dir, devices.size())
			GameSettings.set_mic_device(str(devices[di]), true)
		"invert":
			GameSettings.set_invert_mouse_y(not GameSettings.get_invert_mouse_y(), true)
		"hints":
			PROFILES.set_profile_hints(PROFILES.profile_id, not PROFILES.profile_hints())
		"fov":
			var fi := clampi(nearest(FOV_STEPS, float(body().get("fov", 72.0))) + dir, 0, FOV_STEPS.size() - 1)
			set_body("fov", FOV_STEPS[fi])
		"mouse_x", "mouse_y":
			var mxi := clampi(nearest(MOUSE_STEPS, float(body().get(id, 1.0))) + dir, 0, MOUSE_STEPS.size() - 1)
			set_body(id, MOUSE_STEPS[mxi])
		"bob", "lean":
			var pi2 := clampi(nearest(PCT_STEPS, float(body().get(id, 1.0))) + dir, 0, PCT_STEPS.size() - 1)
			set_body(id, PCT_STEPS[pi2])
		"crouch":
			set_body("crouch_toggle", not bool(body().get("crouch_toggle", false)))
		_:
			return false
	return true


static func reset() -> void:
	if GameSettings != null:
		GameSettings.reset_defaults()


## A microphone as a row says it: the default in the game's words, the rest as Windows names
## them, short enough for a row.
static func mic_name(device: String) -> String:
	if GameSettings == null or device == GameSettings.MIC_DEFAULT:
		return LANG.t("DEFAULT")
	return device.to_upper() if device.length() <= 26 else device.substr(0, 24).to_upper() + ".."


static func body() -> Dictionary:
	return PROFILES.profile_body()


static func set_body(key: String, v) -> void:
	PROFILES.set_profile_body(PROFILES.profile_id, key, v)


static func nearest(steps: Array, v: float) -> int:
	var best := 0
	for i in steps.size():
		if absf(float(steps[i]) - v) < absf(float(steps[best]) - v):
			best = i
	return best
