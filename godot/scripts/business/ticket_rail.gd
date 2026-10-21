extends Node3D

## The order rail over a station (Papa's), in the room itself: a steel rail hung in front
## of the room's camera across the top of the view while you are at a station
## (scripts/business/station3d.gd makes it), the tickets clipped on it, oldest at the
## left. In the room's own pixel: one pixel of a ticket is one line of the room's
## picture. Each ticket is a little picture of its own (a SubViewport the station draws:
## station3d.draw_ticket), redrawn when it changes. A new ticket swings on with its clip,
## the picked one hangs lower, one that has gone red shakes on the rail. It moves smoothly
## (the brief of 21. 10.); each ticket carries the guest's face and their patience
## (station3d.draw_ticket), redrawn as it changes.

const DIST := 0.9
const TW := 32
const TH := 46
const GAP := 3
const SLOTS := 10
const STEP := 1.0 / 12.0
const SWING_SEC := 0.34
const RAIL_TEX := "res://assets/textury/camp/steel_brushed.png"

## -> [{id, band (0 green, 1 amber, 2 red), sig (what makes it look different), ...}]
var tickets_of: Callable
## (c: Control, ticket: Dictionary, size: Vector2) -> void
var draw_ticket: Callable
## -> the picked ticket's id ("" none)
var picked_of: Callable

var _cards: Dictionary = {}
var _bar: MeshInstance3D
var _acc := 0.0
var _t := 0.0
var _texel := 0.004
var _top := 0.0
var _left := 0.0


func _ready() -> void:
	set_meta("retro_skip", true)
	_layout()
	_bar = MeshInstance3D.new()
	_bar.set_meta("retro_skip", true)
	var b := BoxMesh.new()
	b.size = Vector3(_texel * 520.0, _texel * 3.0, _texel * 2.0)
	_bar.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.no_depth_test = true
	m.render_priority = 18
	m.albedo_color = Color(0.62, 0.62, 0.64)
	if ResourceLoader.exists(RAIL_TEX):
		m.albedo_texture = load(RAIL_TEX)
		m.uv1_scale = Vector3(6.0, 0.05, 1.0)
	_bar.material_override = m
	_bar.position = Vector3(0.0, _top + _texel * 1.5, -DIST)
	add_child(_bar)
	_refresh()


## One pixel of a ticket to one line of the room's picture, the rail near the top.
func _layout() -> void:
	var cam := get_parent() as Camera3D
	if cam == null:
		return
	var lines := 240.0
	var aspect := 16.0 / 9.0
	var vp := cam.get_viewport()
	if vp is SubViewport:
		lines = float(maxi(120, (vp as SubViewport).size.y))
		aspect = float((vp as SubViewport).size.x) / maxf(1.0, float((vp as SubViewport).size.y))
	var h := DIST * tan(deg_to_rad(cam.fov * 0.5))
	# One ticket pixel to a line of the room's picture, never smaller than a 240-line
	# picture's line (the tickets stay big enough to read in the sharper looks).
	_texel = 2.0 * h / minf(lines, 240.0)
	_top = h - _texel * 6.0
	_left = -h * aspect + _texel * 6.0


func _process(delta: float) -> void:
	_t += delta
	_refresh()


func _refresh() -> void:
	var tix: Array = tickets_of.call() if tickets_of.is_valid() else []
	var picked := str(picked_of.call()) if picked_of.is_valid() else ""
	var live := {}
	for i in mini(tix.size(), SLOTS):
		var t: Dictionary = tix[i]
		var id := str(t.get("id", ""))
		live[id] = true
		var card: Dictionary = _cards.get(id, {})
		if card.is_empty():
			card = _make_card()
			card["born"] = _t
			_cards[id] = card
		# The face blinks and shakes, the red bar flashes: a ticket in the red is redrawn
		# four times a second, the rest when they change.
		var sig := "%s|%s|%s|%d|%d" % [str(t.get("sig", "")), int(t.get("band", 0)), id == picked, int(float(t.get("left", 1.0)) * 24.0), int(_t * 4.0) if float(t.get("left", 1.0)) < 0.4 else 0]
		if sig != str(card.get("sig", "")):
			card["sig"] = sig
			card["t"] = t.duplicate()
			card["t"]["picked"] = id == picked
			(card["ctl"] as Control).queue_redraw()
			(card["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		var pivot: Node3D = card["pivot"]
		var x := _left + (float(TW) * 0.5 + float(i) * float(TW + GAP)) * _texel
		var y := _top
		if id == picked:
			y -= _texel * 6.0
		if int(t.get("band", 0)) == 2:
			# Red: it shakes on its clip.
			x += _texel * sin(_t * 40.0) * 0.8
		# Sliding along the rail to its place (the ones in front were served), and down to
		# picked, smoothly.
		var want := Vector3(x, y, -DIST)
		var now: Vector3 = card.get("at", want)
		now = now.lerp(want, 1.0 - exp(-14.0 * maxf(0.0, _t - float(card.get("seen", _t)))))
		card["at"] = now
		card["seen"] = _t
		pivot.position = now
		# Swinging onto the rail on its clip, eased.
		var k := clampf((_t - float(card["born"])) / SWING_SEC, 0.0, 1.0)
		var swing := (1.0 - k) * (1.0 - k)
		pivot.rotation.x = -swing * 1.1 + sin(k * PI * 2.0) * 0.12 * (1.0 - k)
	for id in _cards.keys():
		if not live.has(id):
			(_cards[id]["pivot"] as Node).queue_free()
			_cards.erase(id)


func _make_card() -> Dictionary:
	var pivot := Node3D.new()
	pivot.set_meta("retro_skip", true)
	add_child(pivot)
	var vp := SubViewport.new()
	vp.size = Vector2i(TW, TH)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	pivot.add_child(vp)
	var ctl := Control.new()
	ctl.size = Vector2(TW, TH)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(ctl)
	var card := {"pivot": pivot, "vp": vp, "ctl": ctl, "sig": "", "t": {}}
	ctl.draw.connect(func() -> void:
		if draw_ticket.is_valid():
			draw_ticket.call(ctl, card["t"], Vector2(TW, TH)))
	var spr := Sprite3D.new()
	spr.set_meta("retro_skip", true)
	spr.texture = vp.get_texture()
	spr.pixel_size = _texel
	spr.shaded = false
	spr.double_sided = true
	spr.no_depth_test = true
	spr.render_priority = 20
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.position = Vector3(0, -float(TH) * 0.5 * _texel, 0)
	pivot.add_child(spr)
	card["spr"] = spr
	return card


## The ticket under a point of the room's picture ("" none).
func ticket_at(vp_mouse: Vector2) -> String:
	var cam := get_parent() as Camera3D
	if cam == null:
		return ""
	for id in _cards:
		var spr: Sprite3D = _cards[id]["spr"]
		var box := spr.get_aabb()
		var r := Rect2()
		var first := true
		for i in 8:
			var p := cam.unproject_position(spr.global_transform * box.get_endpoint(i))
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
		if r.has_point(vp_mouse):
			return str(id)
	return ""
