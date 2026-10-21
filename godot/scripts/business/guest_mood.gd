extends Node3D

## How a waiting guest's patience goes, over their head in the room (the brief of 21. 10.:
## "the customer in the room taps their foot, looks at their watch, throws up their hands;
## sounds and lines as their patience falls"), the same in all four places: a little
## bubble at the room's pixel (nothing while they are fresh; dots; a watch; a red scribble
## at the end), a line in a speech bubble now and then as it gets worse ("Hello?",
## "Any time now."), and a grumble. Who stands or sits is the place's (the stand's queue,
## scripts/food/service_life.gd): it tells this each tick where the head is and how much
## patience is left (`show_for`), then `sweep()` takes away the bubbles of those it did not
## mention. `stomp(key)` is how far their feet are off the ground now (the impatient ones
## stamp, in steps like the rest of a figure). `impatient(key)` says when they stand in their
## impatient pose (<sprite>_wait.png: a hand on the hip, a look at the watch; Grok, from
## each guest's own sprite), `show_wait` puts it on: the cross ones fidget between it and
## standing, the furious hold it.

const PX_PER_M := 128.0 / 1.4
const FACES := preload("res://scripts/business/guest_face.gd")
## The lines, by how cross they are (picked by the guest, the same on every machine).
const LINES := {
	2: ["Hello?", "Any time now.", "Is anybody there?", "I've been standing here ages.", "Still waiting..."],
	3: ["What's it going to be?", "Forget it soon.", "This is a joke.", "Unbelievable.", "I'm off in a minute."],
}
const SFX_GRUMBLE := "res://assets/sfx/bistro/guest_grumble.mp3"

var _b: Dictionary = {}
var _seen: Dictionary = {}
var _t := 0.0
static var _tex: Dictionary = {}
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	set_meta("retro_skip", true)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 3.0
	_audio.max_distance = 18.0
	_audio.volume_db = -12.0
	add_child(_audio)


func _process(delta: float) -> void:
	_t += delta


## Guest `key` (any id the place keeps) with their head at `head` (global) and `left` of
## their patience (0..1; < 0: not waiting).
func show_for(key: String, head: Vector3, left: float, name := "") -> void:
	_seen[key] = true
	var mood := FACES.mood_of(left) if left >= 0.0 else -1
	var b: Dictionary = _b.get(key, {})
	if b.is_empty():
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = false
		s.no_depth_test = true
		s.render_priority = 4
		s.pixel_size = 1.0 / PX_PER_M
		add_child(s)
		var l := Label3D.new()
		l.font = load("res://scripts/ui/retro_ui.gd").FONT_TEXT
		l.font_size = 8
		l.pixel_size = 1.0 / PX_PER_M
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.shaded = false
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.modulate = Color(1.0, 0.92, 0.75)
		l.outline_size = 3
		l.outline_modulate = Color(0.08, 0.05, 0.03)
		l.render_priority = 5
		l.visible = false
		add_child(l)
		b = {"sprite": s, "label": l, "mood": -1, "said_t": -99.0, "name": name}
		_b[key] = b
	var s2: Sprite3D = b["sprite"]
	var l2: Label3D = b["label"]
	s2.visible = mood >= 1
	if s2.visible:
		s2.texture = _bubble(mood, int(_t * 2.0) % 2)
		s2.global_position = head + Vector3(0, 0.22, 0)
	# Worse than before: a line and a grumble (the furious say it again now and then).
	var was := int(b["mood"])
	b["mood"] = mood
	var line_due := mood >= 2 and (mood > was or (mood == 3 and _t - float(b["said_t"]) > 7.0))
	if line_due:
		var lines: Array = LINES[mood]
		l2.text = str(lines[absi(hash(key + str(mood) + str(int(_t / 7.0)))) % lines.size()])
		b["said_t"] = _t
		if _audio != null and ResourceLoader.exists(SFX_GRUMBLE) and not _audio.playing:
			_audio.stream = load(SFX_GRUMBLE)
			_audio.pitch_scale = 0.9 + float(absi(hash(key)) % 30) / 100.0
			_audio.global_position = head
			_audio.play()
	l2.visible = _t - float(b["said_t"]) < 2.6
	if l2.visible:
		l2.global_position = head + Vector3(0, 0.38, 0)


## How far guest `key`'s feet are off the ground now: the cross ones stamp (two steps a
## second), the furious hop on the spot.
func stomp(key: String) -> float:
	var mood := int((_b.get(key, {}) as Dictionary).get("mood", -1))
	if mood == 2:
		return 0.03 if int(_t * 4.0) % 4 == 0 else 0.0
	if mood == 3:
		return 0.05 if int(_t * 6.0) % 2 == 0 else 0.0
	return 0.0


## Whether guest `key` stands in the impatient pose now.
func impatient(key: String) -> bool:
	var mood := int((_b.get(key, {}) as Dictionary).get("mood", -1))
	if mood == 3:
		return true
	return mood == 2 and int(_t * 1.5) % 3 != 0


## `sprite` (a guest standing, its standing picture `base`) in their impatient picture,
## at the standing one's height; false when they have none. Standing again is
## poses.set_pose(sprite, base, "") (the pose's path differs, so it is put back).
static func show_wait(sprite: Sprite3D, base: String) -> bool:
	if sprite == null or base == "":
		return false
	var path := base.replace(".png", "_wait.png")
	if not ResourceLoader.exists(path) or not ResourceLoader.exists(base):
		return false
	if str(sprite.get_meta("pose_path", "")) == path:
		return true
	# A figure seen from eight sides draws its own pictures: it lets go while this one is up.
	var fig = sprite.get_meta("doom") if sprite.has_meta("doom") else null
	if fig != null and fig.has_method("release"):
		fig.release()
		sprite.flip_h = false
	if not sprite.has_meta("stand_px"):
		sprite.set_meta("stand_px", sprite.pixel_size)
	var tex: Texture2D = load(path)
	var stand: Texture2D = load(base)
	sprite.texture = tex
	sprite.pixel_size = float(sprite.get_meta("stand_px")) * float(stand.get_height()) / float(maxi(1, tex.get_height()))
	sprite.set_meta("pose_path", path)
	return true


## The bubbles of those not mentioned since the last sweep go.
func sweep() -> void:
	for key in _b.keys():
		if not _seen.has(key):
			var b: Dictionary = _b[key]
			(b["sprite"] as Node).queue_free()
			(b["label"] as Node).queue_free()
			_b.erase(key)
	_seen.clear()


## The bubble's picture for a mood (1 dots, 2 a watch, 3 a red scribble), two frames.
static func _bubble(mood: int, frame: int) -> Texture2D:
	var k := "%d:%d" % [mood, frame]
	if _tex.has(k):
		return _tex[k]
	var img := Image.create(15, 13, false, Image.FORMAT_RGBA8)
	var edge := Color(0.1, 0.07, 0.05)
	var fill := Color(0.96, 0.93, 0.84) if mood < 3 else Color(0.86, 0.22, 0.14)
	# The bubble: a box with its corners cut, the tail at the bottom.
	for y in range(0, 10):
		for x in range(0, 15):
			var corner := (x == 0 or x == 14) and (y == 0 or y == 9)
			if corner:
				continue
			var border := x == 0 or x == 14 or y == 0 or y == 9
			img.set_pixel(x, y, edge if border else fill)
	for p in [Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10), Vector2i(7, 11), Vector2i(7, 12)]:
		img.set_pixel(p.x, p.y, edge)
	img.set_pixel(7, 10, fill)
	var ink := Color(0.12, 0.08, 0.06) if mood < 3 else Color(1, 0.95, 0.8)
	match mood:
		1:
			for i in 3:
				var on := i <= frame + 1
				if on:
					img.set_pixel(4 + i * 3, 6, ink)
					img.set_pixel(4 + i * 3, 5, ink)
		2:
			# A watch: its face and the hand that has gone round.
			for p in [Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(5, 3), Vector2i(9, 3), Vector2i(5, 4), Vector2i(9, 4), Vector2i(5, 5), Vector2i(9, 5), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6)]:
				img.set_pixel(p.x, p.y, ink)
			img.set_pixel(7, 4, ink)
			if frame == 0:
				img.set_pixel(7, 3, ink)
			else:
				img.set_pixel(8, 4, ink)
		3:
			# "#!" scribbled.
			for p in [Vector2i(3, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(3, 5), Vector2i(5, 5), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(3, 7), Vector2i(5, 7)]:
				img.set_pixel(p.x + (1 if frame == 1 else 0), p.y, ink)
			for y in range(2, 7):
				img.set_pixel(10, y, ink)
			img.set_pixel(10, 8, ink)
	var t := ImageTexture.create_from_image(img)
	_tex[k] = t
	return t
