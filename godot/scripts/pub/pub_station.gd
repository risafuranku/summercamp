extends "res://scripts/bistro/station_view.gd"

## A station of the pub played full screen, the bistro's way (station_view.gd: the picture
## a flat Build-engine texture, the things on it Grok sprites, the sentence, the bar).
## The rail across the top is the beer mats of everybody with an order open, oldest at
## the left: their name in the landlord's pencil, what they want, a stroke for every one
## they have had, a bar for how long they have waited. Click a mat to pour for them.
## The bar's right end: the mugs on the rack and in the washer, the keg.

const PUB := preload("res://core/systems/pub_rules.gd")
const TAPROOM := preload("res://scripts/pub/taproom.gd")
const PUB_TEX := "res://assets/textury/pub/"
const PUB_SFX := "res://assets/sfx/pub/"
const MARKS := "res://assets/textury/ui/"
## The stations of the pub's rooms, in the order their tabs stand on the bar.
const PUB_TABS := {"bar": [["tap", "TAP"], ["back", "BACK BAR"], ["wash", "WASHER"]], "cellar": [["keg", "KEG"]]}
## The little pictures on the mats (assets/textury/ui/mark_*.png, Grok).
const DRINK_ICONS := {"hladinka": "mark_mug", "snyt": "mark_mug", "mliko": "mark_foam", "rum": "mark_shot",
	"zelena": "mark_shot", "slivovice": "mark_shot", "kofola": "mark_kofola"}
const SPIRIT_TINT := {"rum": Color(0.75, 0.45, 0.2), "zelena": Color(0.45, 0.8, 0.35), "slivovice": Color(1.0, 1.0, 0.92), "kofola": Color(1, 1, 1)}

var taproom


func _ready() -> void:
	super._ready()
	room = "bar"
	for n in ["mat", "mark_mug", "mark_foam", "mark_shot", "mark_kofola", "mark_keg", "mark_dirty"]:
		tex(n)


## A picture of the pub's (assets/textury/pub/<n>.png), else the bistro's or a mark.
func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		var found: Texture2D = null
		for dir in [PUB_TEX, TEX, MARKS]:
			var p: String = dir + n + ".png"
			if ResourceLoader.exists(p):
				found = load(p)
				break
		_tex[n] = found
	return _tex[n]


func sfx(n: String, db := -8.0, pitch := 1.0) -> void:
	for dir in [PUB_SFX, SFX_DIR]:
		var path: String = dir + n + ".mp3"
		if ResourceLoader.exists(path):
			var a: AudioStreamPlayer = _audio[_audio_i]
			_audio_i = (_audio_i + 1) % _audio.size()
			a.stream = load(path)
			a.volume_db = db
			a.pitch_scale = pitch
			a.play()
			return


func open_view() -> void:
	taproom = TAPROOM.of(get_tree())
	super.open_view()


func _room_tabs() -> Array:
	return PUB_TABS.get(room, [])


# ── the mats ─────────────────────────────────────────────────────────────────

func _tickets() -> Array:
	return taproom.tickets(building_key) if taproom != null and building_key != "" else []


## The orders this station pours ("tap" or "bar"), oldest first; the picked one first.
func orders_here(kind_of: String) -> Array:
	var out: Array = []
	for t in _tickets():
		if PUB.kind(str(t["drink"])) == kind_of:
			if str(t["id"]) == picked:
				out.push_front(t)
			else:
				out.append(t)
	return out


func _ticket_verb(t: Dictionary) -> String:
	var bits := PUB.label(str(t["drink"]))
	if int(t["round"]) > 0:
		bits += " (another)"
	return "%s: %s" % [ORDERS_first(str(t["name"])), bits]


func _draw_ticket(c: Control, t: Dictionary, r: Rect2) -> void:
	var is_picked := str(t["id"]) == picked
	if is_picked:
		r.position.y += 4.0
	var age := int(t.get("age", 0))
	var band := PUB.patience_band(age)
	var mat := tex("mat")
	var disc := Rect2(r.position + Vector2(0, 8), Vector2(r.size.x, r.size.x))
	if mat != null:
		c.draw_texture_rect(mat, disc, false)
	else:
		c.draw_rect(disc, Color(0.9, 0.87, 0.8))
	# The name across the top of the mat in red pencil, the drink in the middle.
	var who := ORDERS_first(str(t["name"])).substr(0, 7).to_upper()
	var nw := RETRO_UI.FONT_TEXT.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(floorf(r.position.x + (r.size.x - nw) * 0.5), r.position.y + 6), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.85, 0.6))
	var drink := str(t["drink"])
	var ic := tex(str(DRINK_ICONS.get(drink, "mark_mug")))
	if ic != null:
		var tint: Color = SPIRIT_TINT.get(drink, Color(1, 1, 1))
		c.draw_texture_rect(ic, Rect2((disc.get_center() - ic.get_size() * 0.5 - Vector2(0, 4)).floor(), ic.get_size()), false, tint)
	var short: String = {"hladinka": "HLAD", "snyt": "SNYT", "mliko": "MLIKO", "rum": "RUM", "zelena": "ZELENA", "slivovice": "SLIVO", "kofola": "KOFOLA"}.get(drink, drink.to_upper())
	var sw := RETRO_UI.FONT_TEXT.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(floorf(disc.get_center().x - sw * 0.5), disc.end.y - 8), short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.18, 0.12, 0.1))
	# A pencil stroke for every one they have had already.
	var had: int = taproom.strokes(building_key, str(t["visit"]), int(t["member"])) if taproom != null else 0
	for i in mini(had, 6):
		c.draw_rect(Rect2(disc.position.x + 7 + i * 4, disc.position.y + 5 + (i % 2), 1, 6), Color(0.2, 0.18, 0.2, 0.85))
	# How long they have waited: a bar under the mat, green, amber, red.
	var left := 1.0 - clampf(float(age) / float(PUB.PATIENCE_GONE), 0.0, 1.0)
	var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
	var bar := Rect2(r.position.x + 3, r.end.y - 4, r.size.x - 6, 3)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	if band < 2 or int(_t * 4.0) % 2 == 0:
		c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * left), bar.size.y)), col)
	if is_picked:
		c.draw_rect(Rect2(disc.position - Vector2(1, 1), Vector2(disc.size.x + 2, 1)), RETRO_UI.C_AMBER)
		c.draw_rect(Rect2(Vector2(disc.position.x - 1, disc.end.y), Vector2(disc.size.x + 2, 1)), RETRO_UI.C_AMBER)


func _ticket_clicked(tid: String) -> void:
	picked = "" if picked == tid else tid
	sfx("tick", -12.0, 1.2)


## The right end of the bar: the mugs, the keg.
func _paint_bar(c: Control, r: Rect2) -> void:
	if taproom == null or building_key == "":
		return
	var m: Dictionary = taproom.mugs(building_key)
	var k: Dictionary = taproom.keg(building_key)
	var text := "MUGS %d" % int(m["clean"])
	if int(m["dirty"]) > 0:
		text += "  DIRTY %d" % int(m["dirty"])
	var trouble: String = taproom.tap_trouble(building_key)
	text += "   KEG " + ({"dry": "DRY", "empty": "EMPTY", "off": "OFF"}.get(trouble, "%d" % int(k["line"])))
	var alarm := int(m["clean"]) == 0 or trouble != ""
	var w := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(r.end.x - w - 2, r.position.y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_RED_LIGHT if alarm else RETRO_UI.C_BONE_DIM)


## A sprite of the pub's drawn with its bottom middle at `foot` (things standing on the bar).
func stand(c: Control, n: String, foot: Vector2, alpha := 1.0, tint := Color(1, 1, 1)) -> Rect2:
	var t := tex(n)
	if t == null:
		return Rect2(foot, Vector2.ZERO)
	var sz := t.get_size() * float(PIX)
	var r := Rect2((foot - Vector2(sz.x * 0.5, sz.y)).floor(), sz)
	if alpha > 0.0:
		c.draw_texture_rect(t, r, false, Color(tint.r, tint.g, tint.b, alpha))
	return r


## A glass's contents: the full render cut off at `level` (a share of its height) from the
## bottom, standing at `foot`.
func fill_to(c: Control, n: String, foot: Vector2, level: float, tint := Color(1, 1, 1)) -> void:
	var t := tex(n)
	if t == null or level <= 0.0:
		return
	var sz := t.get_size() * float(PIX)
	var h := floorf(sz.y * clampf(level, 0.0, 1.0))
	if h < 1.0:
		return
	var src_h := float(t.get_height()) * h / sz.y
	c.draw_texture_rect_region(t, Rect2((foot - Vector2(sz.x * 0.5, h)).floor(), Vector2(sz.x, h)), Rect2(0, t.get_height() - src_h, t.get_width(), src_h), tint)
