extends Node

## The game's sound in two channels, music and effects, each with its own volume (UNDO.games'
## bar sets them apart, scripts/web/undo_hub.gd). Two buses into Master: "Music" and "Sfx".
## The game makes its buses as it goes (the radio's, the night insects', the rooms'...), each
## sent to Master: here each is sent on to Music (the songs: MUSIC_BUSES) or Sfx (the rest),
## and a player left on Master goes to Sfx. Something that is music and plays on no bus of
## its own takes `bus = MIXER.MUSIC`. The player's own volume stays on Master (GameSettings).
## GameSettings' child "Mixer".
##   MIXER.node().set_channel("music", 0.6, false)

const MUSIC := "Music"
const SFX := "Sfx"
## The buses whose sound is songs (the score, the menu's theme, the radio's): music. Every
## other bus of the game (the world, the night, the rooms, the phone, the Caretaker's and the
## fever's treatments of songs heard as dread) is effects.
const MUSIC_BUSES := ["WorldMusic", "AmbientMusic", "Chase", "Radio", "RadioMusic"]
## Buses with a volume of their own in the settings, left on Master: the others' voices in
## co-op (scripts/coop/voice.gd, GameSettings "voices").
const OWN_BUSES := ["Voices"]
const PLAYERS := ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]

var _volume := {"music": 1.0, "sfx": 1.0}
var _muted := {"music": false, "sfx": false}
var _since := 0.0


static func node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("GameSettings") if tree != null else null
	return settings.get_node_or_null("Mixer") if settings != null else null


func _init() -> void:
	name = "Mixer"


func _ready() -> void:
	for bus in [MUSIC, SFX]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus(1)
			AudioServer.set_bus_name(1, bus)
			AudioServer.set_bus_send(1, "Master")
	AudioServer.bus_layout_changed.connect(_route_buses)
	AudioServer.bus_renamed.connect(func(_i: int, _old: StringName, _new: StringName) -> void: _route_buses())
	get_tree().node_added.connect(_on_node_added)
	_route_buses()
	_apply()


## A channel's volume (0..1, as the hub's bar gives it) and whether it is muted.
func set_channel(channel: String, volume: float, muted: bool) -> void:
	if not _volume.has(channel):
		return
	_volume[channel] = clampf(volume, 0.0, 1.0)
	_muted[channel] = muted
	_apply()


func _apply() -> void:
	for pair in [["music", MUSIC], ["sfx", SFX]]:
		var i := AudioServer.get_bus_index(pair[1])
		if i < 0:
			continue
		var v: float = _volume[pair[0]]
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, _muted[pair[0]] or v <= 0.0)


## Every bus the game sent to Master (or that was routed before it got its name) on to its
## channel by its name. Buses sent to another bus of the game keep it.
func _route_buses() -> void:
	for i in range(1, AudioServer.bus_count):
		var bus := AudioServer.get_bus_name(i)
		if bus == MUSIC or bus == SFX or OWN_BUSES.has(bus):
			continue
		var send := AudioServer.get_bus_send(i)
		if send != &"Master" and send != StringName(MUSIC) and send != StringName(SFX):
			continue
		var want := MUSIC if MUSIC_BUSES.has(bus) else SFX
		if send != StringName(want):
			AudioServer.set_bus_send(i, want)


## Looked over twice a second too: a bus's send set back to Master after it was made raises
## no signal.
func _process(delta: float) -> void:
	_since += delta
	if _since >= 0.5:
		_since = 0.0
		_route_buses()


func _on_node_added(n: Node) -> void:
	if not PLAYERS.has(n.get_class()):
		return
	_to_sfx(n)
	# (Its own _ready may set its bus: looked at again after it.)
	if not n.is_node_ready():
		n.ready.connect(_to_sfx.bind(n), CONNECT_ONE_SHOT)


func _to_sfx(n: Node) -> void:
	if is_instance_valid(n) and StringName(n.get("bus")) == &"Master":
		n.set("bus", SFX)
