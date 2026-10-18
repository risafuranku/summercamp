extends "res://scripts/closeup/closeup_view.gd"

## The pub's glass washer, close up (assets/textury/closeup/glass_wash.png): every beer
## you pour goes out in a clean mug and comes back dirty (the pub's books keep count:
## site.glasses {clean, dirty}). No clean mugs, nothing to pour into. Here:
##   click the dirty stack to take a mug, then scrub it on the brush: hold the button
##   and work the mouse up and down over the washer, the foam rings and the lipstick
##   coming off stroke by stroke; a clean one goes on the rack with a click.
## A hand behind the bar does the washing too.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PIC := "res://assets/textury/closeup/glass_wash.png"
const SFX_SPLASH := "res://assets/sfx/bistro/ladle_plate.mp3"
const SFX_CLINK := "res://assets/sfx/pub/glass_clink.mp3"
const SFX_DOWN := "res://assets/sfx/pub/glass_down.mp3"

const DIRTY := Rect2(0, 88, 66, 150)
const BRUSH := Rect2(88, 10, 72, 150)
const RACK := Rect2(155, 0, 165, 140)
const STROKES := 7.0
## The mug on the brush is two renders (closeup/parts/mug_clean, mug_dirty): the dirt
## fades off stroke by stroke; the suds are a render too.
const PARTS := "res://assets/textury/closeup/parts/"
var _tex: Dictionary = {}

var building_key := ""
var _held := false
var _dirt := 1.0
var _last_y := -1.0
var _dir := 0
var _travel := 0.0
var _splash_t := 0.0
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


static func glasses(key: String) -> Dictionary:
	var site: Dictionary = BUSINESS.site(key)
	if site.is_empty():
		return {}
	if not site.has("glasses"):
		site["glasses"] = {"clean": 16, "dirty": 0}
	return site["glasses"]


func _opened() -> void:
	_held = false
	var g := glasses(building_key)
	if g.is_empty():
		return
	if int(g["dirty"]) == 0:
		say("", "Nothing to wash. %d clean mugs on the rack." % int(g["clean"]), false)
	else:
		say("", "%d dirty mugs." % int(g["dirty"]), false)


func _hotspots() -> Array:
	var out: Array = []
	if not _held:
		out.append({"id": "dirty", "rect": DIRTY})
	elif _dirt <= 0.02:
		out.append({"id": "rack", "rect": RACK})
	return out


func _clicked(id: String) -> void:
	var g := glasses(building_key)
	if g.is_empty():
		return
	match id:
		"dirty":
			if int(g["dirty"]) <= 0:
				say("", "None dirty. Go and pour.")
				return
			g["dirty"] = int(g["dirty"]) - 1
			_held = true
			_dirt = 1.0
			_travel = 0.0
			play(SFX_CLINK, -10.0)
		"rack":
			g["clean"] = int(g["clean"]) + 1
			_held = false
			_flash = 0.4
			play(SFX_DOWN, -8.0)
			say("", "%d clean, %d to go." % [int(g["clean"]), int(g["dirty"])], false)


func _tick(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_splash_t -= delta
	if not _held or _dirt <= 0.0:
		_last_y = -1.0
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and BRUSH.has_point(_mouse):
		HandCursor.want(HandCursor.GRAB)
		if _last_y >= 0.0:
			var dy := _mouse.y - _last_y
			var d := signi(int(dy))
			_travel += absf(dy)
			# A stroke: a change of direction after a good long push.
			if d != 0 and d != _dir and _travel > 24.0:
				_dirt = maxf(0.0, _dirt - 1.0 / STROKES)
				_travel = 0.0
				if _splash_t <= 0.0:
					play(SFX_SPLASH, -14.0)
					_splash_t = 0.25
				if _dirt <= 0.0:
					say("", "Clean.")
			if d != 0:
				_dir = d
		_last_y = _mouse.y
	else:
		_last_y = -1.0


func _part(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(PARTS + key + ".png") if ResourceLoader.exists(PARTS + key + ".png") else null
	return _tex[key]


func _paint(c: Control) -> void:
	var g := glasses(building_key)
	if g.is_empty():
		return
	# How many are where, chalked.
	ink(c, RETRO_UI.FONT_LABEL, DIRTY.position + Vector2(4, -4), "DIRTY %d" % int(g["dirty"]), RETRO_UI.C_RED_LIGHT, Color(0, 0, 0, 0.9))
	ink(c, RETRO_UI.FONT_LABEL, RACK.position + Vector2(4, -4), "CLEAN %d" % int(g["clean"]), RETRO_UI.C_AMBER_LIGHT, Color(0, 0, 0, 0.9))
	if _held:
		# The mug on the brush, going up and down with your hand; the dirt fading off it.
		var y := clampf(_mouse.y if BRUSH.has_point(_mouse) else BRUSH.get_center().y, BRUSH.position.y + 10, BRUSH.end.y - 50)
		var clean := _part("mug_clean")
		var dirty := _part("mug_dirty")
		var ref := clean if clean != null else dirty
		if ref != null:
			var sz := Vector2(ref.get_size())
			var m := Rect2(BRUSH.get_center().x - sz.x * 0.5, y, sz.x, sz.y)
			if clean != null:
				c.draw_texture_rect(clean, m, false)
			if dirty != null:
				c.draw_texture_rect(dirty, m, false, Color(1, 1, 1, _dirt))
		# Suds round the brush, in steps.
		var suds := _part("suds")
		if suds != null:
			var st := floorf(_t * 12.0)
			for i in 6:
				var sx := BRUSH.position.x + 16 + fmod(i * 17.0 + st * 3.0, 56.0)
				var sy := BRUSH.end.y - 34 - fmod(i * 11.0 + st * 2.0, 26.0)
				c.draw_texture_rect(suds, Rect2(sx, sy, 12, 12), false, Color(1, 1, 1, 0.85))
	if _flash > 0.0:
		c.draw_rect(RACK, Color(1, 1, 0.8, _flash * 0.5))
	if hovered() != "":
		for h in _hotspots():
			if str(h["id"]) == hovered():
				c.draw_rect(h["rect"], Color(1.0, 0.92, 0.6, 0.12))
