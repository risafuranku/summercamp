extends CanvasLayer

## The warden's palmtop (Richard 24. 11., docs/player.md "PDA se stylusem"; instead of the TAB
## site plan and the belt pager): held up in the left hand while TAB is (with the bag: it
## comes and goes with it, scripts/ui/inventory.gd sets `force_open`), its stylus the mouse,
## you walk slower, the camp goes on. Its system and apps are scripts/pda/pda_os.gd and
## scripts/pda/apps/. A message (hud_manager.push_pager -> `notify`) with the PDA away makes
## it buzz in your pocket and a small picture of it blink in the corner until you look. At
## night its backlight is on.
##
## The hand is Grok's (tools/artgen/pda_art.py, approved 24. 11.), drawn at the HUD's whole
## pixel scale; the screen in it is SCREEN, two screen pixels to each of its own. The bag
## opens on the right of the screen with it (inventory._origin).

const INSTANCE = preload("res://scripts/instance/instance.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const OS_SCRIPT = preload("res://scripts/pda/pda_os.gd")
const HAND_TEX := "res://assets/textury/hands/pda.png"
const ICONS := "res://assets/textury/pda/icons.png"
## The screen in the hand's picture (tools/artgen/pda_art.py prints it).
const SCREEN := Rect2(233, 135, 69, 160)
## The device's top edge in the picture (its top is kept on the screen, the buttons below
## the glass may go off the bottom).
const DEVICE_TOP := 85.0
## Never smaller than this: under it the glass is too narrow to read (a 720p window's client
## area is 681 high, where the HUD itself goes down to 2).
const MIN_SCALE := 3
## Screen pixels to one of the glass's.
const LCD_PX := 2
## Up and down: seconds, eased out (nothing springs back at the end).
const SLIDE_SEC := 0.18
## How fast you walk with it up.
const WALK_K := 0.6
## How long the small picture blinks after a buzz, and its blink.
const BLINK_SEC := 14.0
const BLINK_PERIOD := 0.45
## (ElevenLabs, tools/audiogen/prompts_pda.tsv, normalized to -23 LUFS.)
const SOUNDS := {
	"buzz": ["res://assets/sfx/pda/buzz.mp3", 2.0],
	"buzz_short": ["res://assets/sfx/pda/buzz_short.mp3", -4.0],
	"tap": ["res://assets/sfx/pda/tap.mp3", -6.0],
	"beep": ["res://assets/sfx/pda/beep.mp3", -8.0],
	"up": ["res://assets/sfx/pda/up.mp3", -3.0],
}

var main: Node
## Held up: the bag's TAB (inventory._set_forced), tools.
var force_open := false

var _k := 0.0
var _scale := 3
var _built_for := Vector2.ZERO
var _root: Control
var _hand: TextureRect
var _os: Control
var _blink: TextureRect
var _blink_shadow: TextureRect
var _blink_left := 0.0
var _blink_t := 0.0
var _streams := {}
var _player_sfx: AudioStreamPlayer
var _was_up := false
var _last_buzz_ms := -100000


func setup(main_node: Node) -> void:
	main = main_node
	if _os != null:
		_os.main = main


func _ready() -> void:
	layer = 97
	_root = Control.new()
	_root.name = "PdaRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hand = TextureRect.new()
	_hand.name = "Hand"
	_hand.texture = load(HAND_TEX) if ResourceLoader.exists(HAND_TEX) else null
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hand)
	_os = OS_SCRIPT.new()
	_os.name = "OknaCE"
	_os.main = main
	_os.set_sounds(play)
	_hand.add_child(_os)
	# The small picture in the corner after a buzz: the messages' bell off the PDA's own sheet.
	_blink = TextureRect.new()
	_blink.name = "Buzzed"
	_blink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_blink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink.visible = false
	_blink.texture = _bell()
	_blink.modulate = RETRO_UI.C_AMBER
	_blink_shadow = TextureRect.new()
	_blink_shadow.texture = _blink.texture
	_blink_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_blink_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_shadow.modulate = Color(0, 0, 0, 0.85)
	_blink_shadow.visible = false
	add_child(_blink_shadow)
	add_child(_blink)
	_player_sfx = AudioStreamPlayer.new()
	_player_sfx.bus = "Sfx" if AudioServer.get_bus_index("Sfx") >= 0 else "Master"
	add_child(_player_sfx)
	for k in SOUNDS:
		var path := str(SOUNDS[k][0])
		if ResourceLoader.exists(path):
			_streams[k] = load(path)
	_root.visible = false


## The messages' bell off the PDA's sheet, white (tinted by `modulate`: the sheet is ink).
func _bell() -> Texture2D:
	if not ResourceLoader.exists(ICONS):
		return null
	var img: Image = (load(ICONS) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var bell := img.get_region(Rect2i(32, 0, 32, 32))
	for y in 32:
		for x in 32:
			bell.set_pixel(x, y, Color(1, 1, 1, bell.get_pixel(x, y).a))
	return ImageTexture.create_from_image(bell)


## A message for the warden (hud_manager.push_pager): into the inbox; with the PDA away it
## buzzes and its picture blinks in the corner.
func notify(text: String, kind: int, group := "") -> void:
	var inbox = _os.app_node("inbox")
	if inbox == null:
		return
	inbox.add(text, kind, group, _os.clock_text())
	if _root.visible and _k > 0.5:
		_os.queue_redraw()
		play("beep")
		return
	buzz()
	_blink_left = BLINK_SEC


## The buzz in your pocket: once for a message and its page (hud_manager.page) together.
func buzz() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_buzz_ms < 800:
		return
	_last_buzz_ms = now
	play("buzz")


func play(sound: String) -> void:
	if not _streams.has(sound) or _player_sfx == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	p.volume_db = float(SOUNDS[sound][1])
	p.bus = _player_sfx.bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func is_up() -> bool:
	return _k > 0.0


func _process(delta: float) -> void:
	var want := force_open and _allowed()
	var was := _k
	_k = move_toward(_k, 1.0 if want else 0.0, delta / SLIDE_SEC)
	_root.visible = _k > 0.0
	if want and not _was_up:
		play("up")
	_was_up = want
	_tick_blink(delta)
	_walk_slow()
	if not _root.visible:
		return
	_layout()
	var e := 1.0 - pow(1.0 - _k, 3.0)
	var full_y := float(_hand.get_meta("up_y", 0.0))
	_hand.position.y = roundf(lerpf(get_viewport().get_visible_rect().size.y + 8.0, full_y, e))
	if was != _k and _k >= 1.0:
		_os.queue_redraw()
	if _k >= 1.0:
		_os.tick(delta)
		# The glass's backlight: on at night, off by day (eased, it is a lamp).
		var lit_to := 1.0 if _is_dark() else 0.0
		if not is_equal_approx(_os.lit, lit_to):
			_os.lit = move_toward(_os.lit, lit_to, delta * 2.0)
			_os.queue_redraw()
		var mp := _os.get_local_mouse_position()
		if Rect2(Vector2.ZERO, Vector2(_os.lcd)).has_point(mp):
			HandCursor.want(HandCursor.STYLUS, self)


## Placed for the window: the HUD's pixel scale, the glass as many of its own pixels as two
## screen pixels each give, the hand right of the bag, the screen near the top.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == _built_for or _hand.texture == null:
		return
	_built_for = vp
	_scale = maxi(MIN_SCALE, RETRO_UI.ui_scale(vp.y, vp.x))
	var tex_size := _hand.texture.get_size()
	_hand.size = tex_size * float(_scale)
	# Left of the screen's middle (the bag opens on the right with it).
	var screen_px := SCREEN.size * float(_scale)
	var x := vp.x * 0.30 - SCREEN.get_center().x * float(_scale)
	var top := maxf(12.0, minf((SCREEN.position.y - DEVICE_TOP + 3.0) * float(_scale), vp.y - screen_px.y - 12.0))
	_hand.position.x = roundf(x)
	_hand.set_meta("up_y", roundf(top - SCREEN.position.y * float(_scale)))
	_os.lcd = Vector2i(int(screen_px.x) / LCD_PX, int(screen_px.y) / LCD_PX)
	_os.position = SCREEN.position * float(_scale) + ((screen_px - Vector2(_os.lcd * LCD_PX)) * 0.5).floor()
	_os.size = Vector2(_os.lcd)
	_os.scale = Vector2(LCD_PX, LCD_PX)
	_os.queue_redraw()
	# The buzz's picture: in the bottom left corner, over the status bar.
	var hud = main.get("_hud_manager") if main != null else null
	var bar_h: float = float(hud.call("get_bar_height_px")) if hud != null and hud.has_method("get_bar_height_px") else 0.0
	var bs := float(maxi(1, RETRO_UI.ui_scale(vp.y, vp.x) - 1))
	_blink.size = Vector2(32, 32) * bs
	_blink.position = Vector2(8.0 * bs, vp.y - bar_h - _blink.size.y - 4.0 * bs)
	_blink_shadow.size = _blink.size
	_blink_shadow.position = _blink.position + Vector2(bs, bs)


func _tick_blink(delta: float) -> void:
	if _blink_left <= 0.0 or _k > 0.5:
		if _blink.visible:
			_blink.visible = false
			_blink_shadow.visible = false
		if _k > 0.5:
			_blink_left = 0.0
		return
	_blink_left -= delta
	_blink_t += delta
	var on := fmod(_blink_t, BLINK_PERIOD * 2.0) < BLINK_PERIOD and _blink_left > 0.0 and _world_hud_up()
	if on != _blink.visible:
		_blink.visible = on
		_blink_shadow.visible = on
		if on:
			_built_for = Vector2.ZERO
			_layout()


func _world_hud_up() -> bool:
	return main != null and main.get("_gameplay_started") == true and main.get("_menu_mode") != true


func _walk_slow() -> void:
	var p = main.get("_player") if main != null else null
	if p != null and is_instance_valid(p) and "pda_speed_mult" in p:
		var want := lerpf(1.0, WALK_K, _k)
		if not is_equal_approx(float(p.get("pda_speed_mult")), want):
			p.set("pda_speed_mult", want)


func _allowed() -> bool:
	return main != null and main.get("_gameplay_started") == true and main.get("_menu_mode") != true and main.get("_game_over_active") != true


func _is_dark() -> bool:
	var gm = INSTANCE.guests(main) if main != null else null
	if gm == null:
		return false
	var h := int(gm.get("_last_known_hour"))
	return h >= 20 or h < 6


## The arrows for the snake while it is up (W A S D keep walking you).
func _input(event: InputEvent) -> void:
	if not _root.visible or _k < 1.0:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _os.key(key):
		get_viewport().set_input_as_handled()
