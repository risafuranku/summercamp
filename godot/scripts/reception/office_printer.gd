extends Node3D

## The office's dot-matrix printer (Richard 24. 11., docs/pc.md "Úkoly z tiskárny", "jen
## připomínky"): on the desk left of the PC, Grok's picture (`camp/office_printer.png`,
## tools/artgen/prompts_pda.tsv spr_printer). Whatever new comes to wait in the camp (tonight's
## job, a day's trouble, a breakdown: scripts/ui/camp_plan.gd `reminders`, the PDA's Tasks the
## same) it prints on a slip of tractor-feed paper while the PC is on, its print head heard as
## the PC's sounds are (os_shell.sound_db). The newest slip stands up out of it, the two before
## lie beside it. Only a reminder: nothing is owed for it, nothing comes of leaving it.
##
## building_interior makes it in the PC corner and sets `host`; it watches the camp itself.

const K := preload("res://scripts/interior_kit.gd")
const INSTANCE := preload("res://scripts/instance/instance.gd")
const PLAN := preload("res://scripts/ui/camp_plan.gd")
const STEP12 := preload("res://scripts/ui/step12.gd")
const FONT: FontFile = preload("res://assets/fonts/tiny5.fnt")
const SOUND := "res://assets/sfx/os98/printer.mp3"
## Where it stands (the PC corner's own space): on the desk between the monitor and the radio,
## turned to the chair as the monitor is; with the second monitor there (it takes that place,
## the radio goes up on it) on the floor right of the desk. Its picture's size, metres.
const AT_DESK := Vector3(0.79, 0.82, -1.48)
const AT_FLOOR := Vector3(1.66, 0.0, -1.30)
const SIZE := Vector2(0.34, 0.24)
const YAW := 18.0
## A slip: its size, where it comes out (above the printer's lid), how long the print takes.
const SLIP := Vector2(0.21, 0.13)
const SLIP_OUT := Vector3(0.0, 0.17, 0.02)
const PRINT_SEC := 2.4
const POLL_SEC := 2.0
const KEEP := 3
const PAPER := Color(0.93, 0.92, 0.84)
const INK := Color(0.14, 0.13, 0.16)

var host: Node
## Where it stands now (place()).
var AT := AT_DESK
var _body: MeshInstance3D
var _seen: Dictionary = {}
var _primed := false
var _queue: Array = []
var _poll := 0.0
var _printing := -1.0
var _slips: Array = []
var _sound: AudioStreamPlayer


func _ready() -> void:
	_body = K.cutout(self, "office_printer", SIZE, AT, YAW, false, "OfficePrinter")
	_sound = AudioStreamPlayer.new()
	_sound.name = "PrinterSound"
	if ResourceLoader.exists(SOUND):
		_sound.stream = load(SOUND)
	add_child(_sound)


## On the desk, or (`dual`: the second monitor is there) on the floor beside it; its slips
## with it.
func place(dual: bool) -> void:
	var to := AT_FLOOR if dual else AT_DESK
	if to == AT:
		return
	var shift := to - AT
	AT = to
	if _body != null:
		_body.position = AT
	for s in _slips:
		(s as Node3D).position += shift


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SEC
		_watch()
	if _printing >= 0.0:
		_printing += delta
		if _printing >= PRINT_SEC:
			_printing = -1.0
	elif not _queue.is_empty() and _pc_db() > -79.0:
		_print(str(_queue.pop_front()))


## The camp's reminders: a new one goes in the queue (the first look only learns what is
## already there: a loaded camp does not print its whole list).
func _watch() -> void:
	var main := INSTANCE.main_of(self)
	if main == null or main.get("_gameplay_started") != true:
		return
	var now := {}
	for r in PLAN.reminders(main):
		var key := str(r["key"])
		now[key] = true
		if not _seen.has(key) and _primed and str(r["text"]) != "":
			_queue.append(str(r["text"]))
	_seen = now
	_primed = true


## How loud the PC's sounds are where you are (-80: it is off, or you are not near).
func _pc_db() -> float:
	var crt = host.get("_crt_ui") if host != null else null
	return float(crt.call("sound_db")) if crt != null and is_instance_valid(crt) and crt.has_method("sound_db") else -80.0


func _print(text: String) -> void:
	_printing = 0.0
	if _sound.stream != null:
		_sound.volume_db = -6.0 + _pc_db()
		_sound.play()
	# The slip before is torn off and laid beside it; the oldest of the pile goes.
	if not _slips.is_empty():
		var last: Node3D = _slips[-1]
		last.position = AT + Vector3(0.28, 0.002 + 0.001 * float(_slips.size()), 0.12 + 0.015 * float(_slips.size() % 2))
		last.rotation_degrees = Vector3(-90.0, YAW - 8.0 + 9.0 * float(_slips.size() % 3), 0.0)
	while _slips.size() >= KEEP:
		(_slips.pop_front() as Node).queue_free()
	var slip := _make_slip(text)
	_slips.append(slip)
	# Up out of the printer as the head works across: in steps, as the room's own motion goes.
	slip.scale = Vector3(1.0, 0.05, 1.0)
	STEP12.add(create_tween(), slip, {"scale": Vector3.ONE}, PRINT_SEC, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)


## The camp's clock ("21:07"), at the slip's top.
func _clock() -> String:
	var gm = INSTANCE.guests(self)
	if gm == null:
		return ""
	return "%02d:%02d" % [int(gm.get("_last_known_hour")), int(gm.get("_last_known_minute"))]


## A slip of the green-barred paper with the reminder on it in the print head's dots.
func _make_slip(text: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Slip"
	root.position = AT + SLIP_OUT.rotated(Vector3.UP, deg_to_rad(YAW))
	root.rotation_degrees.y = YAW
	add_child(root)
	var paper := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = SLIP
	q.center_offset = Vector3(0, SLIP.y * 0.5, 0)
	paper.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = PAPER
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.material_override = m
	root.add_child(paper)
	var label := Label3D.new()
	label.font = FONT
	label.font_size = 8
	label.pixel_size = 0.0021
	label.modulate = INK
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = (SLIP.x - 0.02) / label.pixel_size
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text = "%s\n%s" % [_clock(), text]
	# (A Label3D's left-aligned lines start at its origin: the origin at the slip's left margin.)
	label.position = Vector3(-SLIP.x * 0.5 + 0.01, SLIP.y - 0.008, 0.001)
	root.add_child(label)
	return root
