extends Node

## UNDO.games, where the web demo runs (protocol v1 over web/undo-bridge.js, as every UNDO game):
## the hub's bar gives the music's and the effects' volumes (scripts/audio/mixer.gd), the time
## played is measured while a camp is played (`undo:state playing/idle`), the bar's insets come
## as `undo:viewport`. The page's own events come the same way: hidden or shown again (the game
## pauses on a hidden page, not on a lost focus: a click on the hub's bar must not stop it).
## Outside the hub (a direct link, the test server) only the page's events. Web only:
## GameSettings' child "Undo".
##   UNDO_HUB.node().set_playing(true)     UNDO_HUB.node().page_hidden.connect(...)

signal page_hidden(hidden: bool)
signal viewport_changed(top: float, bottom: float)

const MIXER = preload("res://scripts/audio/mixer.gd")
const GAME_SLUG := "cursed-camp"
## How often `undo:ready` is said until the hub answers with the profile.
const READY_EVERY := 0.75
const POLL_EVERY := 0.05

var embedded := false
var profile := {}
var viewport := {"top": 0.0, "bottom": 0.0}
var playing := false
var _bridge: JavaScriptObject
var _have_profile := false
var _ready_timer := 0.0
var _poll := 0.0


static func node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("GameSettings") if tree != null else null
	return settings.get_node_or_null("Undo") if settings != null else null


func _init() -> void:
	name = "Undo"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_bridge = JavaScriptBridge.get_interface("__ccUndo")
	embedded = _bridge != null and bool(_bridge.embedded)
	if embedded:
		_post({"type": "undo:ready", "game": GAME_SLUG})


func _process(delta: float) -> void:
	if _bridge == null:
		return
	if embedded and not _have_profile:
		_ready_timer += delta
		if _ready_timer >= READY_EVERY:
			_ready_timer = 0.0
			_post({"type": "undo:ready", "game": GAME_SLUG})
	_poll += delta
	if _poll < POLL_EVERY:
		return
	_poll = 0.0
	var raw = _bridge.drain()
	if not (raw is String) or raw == "":
		return
	var list = JSON.parse_string(raw)
	if list is Array:
		for message in list:
			if message is Dictionary:
				_receive(message)


func _receive(message: Dictionary) -> void:
	match String(message.get("type", "")):
		"undo:profile":
			_have_profile = true
			profile = message.get("profile", {}) if message.get("profile") is Dictionary else {}
			_apply_audio(profile.get("audio", {}) if profile.get("audio") is Dictionary else {}, bool(profile.get("muted", false)))
		"undo:audio":
			_apply_audio(message.get("audio", {}) if message.get("audio") is Dictionary else {}, bool(message.get("muted", false)))
		"undo:viewport":
			viewport = {"top": float(message.get("top", 0.0)), "bottom": float(message.get("bottom", 0.0))}
			viewport_changed.emit(viewport.top, viewport.bottom)
		"page:hidden":
			page_hidden.emit(true)
		"page:visible":
			page_hidden.emit(false)


## The bar's two channels onto the mixer's (each 0..1 and muted; `muted` all of it).
func _apply_audio(value: Dictionary, muted: bool) -> void:
	var mixer := MIXER.node()
	if mixer == null:
		return
	for channel in ["music", "sfx"]:
		var item: Dictionary = value.get(channel, {}) if value.get(channel) is Dictionary else {}
		mixer.set_channel(channel, float(item.get("volume", 1.0)), muted or bool(item.get("muted", false)))


## The hub counts the time played while this is on (a camp in play, not the title).
func set_playing(value: bool) -> void:
	if playing == value:
		return
	playing = value
	_post({"type": "undo:state", "state": "playing" if value else "idle"})


func _post(message: Dictionary) -> void:
	if embedded and _bridge != null:
		_bridge.post(JSON.stringify(message))
