extends RefCounted

## The family's boy in the sewer (scripts/enemies/boy_brain.gd; DESIGN §5a.2): tag.
## "Na honěnou! Honím já!" from behind you as you crawl off the ladder, and he is it: he
## comes down after you and crawls along the way you took, and you may not stop. Every pipe you crawl puts him a
## length back; lying still (looking about at a junction, the map, a bump) he comes on,
## his hands slapping the water, his breath at your feet; at your ankle, "Mám tě!": his
## face, the hit, and he is back a few lengths, giggling. A hole is home (domeček): while
## you work at one he waits. Look back (hold S) and you see how near he is, crawling at
## you on his belly. Out of the sewer with it mended: found, back in the tent by morning.
## Light he is slow and lets you be at junctions a while, heavy he is quick.

const DIR := "res://assets/sfx/npc/boy/"
const NIGHTMARE_FX = preload("res://scripts/night/nightmare_fx.gd")
const FACE := "res://assets/textury/npc/boy_face.png"
const CRAWL := "res://assets/textury/npc/boy_crawl.png"
const CRAWL_FALLBACK := "res://assets/textury/npc/boy_t1.png"
const PITCH := 1.22
## How far back he is, in pipe lengths (gap): where he starts, the most, and what each
## pipe you crawl gives you.
const GAP_START := 3.0
const GAP_MAX := 4.0
const GAP_PER_PIPE := 1.0
## By tier (1 light .. 3 heavy): how fast he gains while you lie still (lengths a second),
## the grace before he starts, how hard he hits.
const GAIN := [0.0, 0.32, 0.45, 0.62]
const GRACE := [0.0, 4.0, 3.0, 2.2]
const HIT := [0, 14, 20, 30]
## A pipe length in metres (the crawl's CELL), for where you see him.
const LENGTH := 3.2
## The crawl's ways (N E S W) and your eye over the water (sewer_pipe_minigame.gd).
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const EYE_Y := 0.40

var host
var tier := 1
## How far back he is now (lengths) and how many times he caught you (for the checks).
var gap := GAP_START
var caught := 0
var _still := 0.0
var _started := false
var _next_line := 6.0
var _next_splash := 1.0
var _said_near := false
var _face_t := 0.0
var _body: Sprite3D
## The junctions you have crawled through, oldest first (he comes along them).
var _trail: Array = []
var _face: TextureRect
var _ear: AudioStreamPlayer


func start(host_node, boy_tier: int) -> void:
	host = host_node
	tier = clampi(boy_tier, 1, 3)
	gap = GAP_START
	caught = 0
	_still = 0.0
	_started = false
	_trail.clear()
	var tex: Texture2D = load(CRAWL if ResourceLoader.exists(CRAWL) else CRAWL_FALLBACK)
	_body = Sprite3D.new()
	_body.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_body.shaded = true
	_body.double_sided = true
	_body.texture = tex
	_body.pixel_size = 0.5 / float(tex.get_height())
	_body.offset = Vector2(0.0, tex.get_height() * 0.5)
	_body.visible = false
	host._geo.add_child(_body)
	_ear = AudioStreamPlayer.new()
	_ear.bus = host.audio_bus()
	host.add_child(_ear)
	_face = TextureRect.new()
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.texture = load(FACE) if ResourceLoader.exists(FACE) else null
	# In the world's game pixels and palette (materials/closeup_retro.gdshader).
	_face.material = NIGHTMARE_FX.retro_material()
	_face.visible = false
	host.add_child(_face)


func stop() -> void:
	for n in [_body, _face, _ear]:
		if n != null and is_instance_valid(n):
			n.queue_free()


## You crawled a pipe (the crawl's _try_move / _back_up): a length on him.
func moved() -> void:
	_trail.append(host._node)
	if _trail.size() > 12:
		_trail.pop_front()
	if not _started:
		# Off the ladder: he is down after you, and it starts.
		_started = true
		_say("tag_start", -4.0)
		_next_line = randf_range(8.0, 12.0)
		return
	gap = minf(GAP_MAX, gap + GAP_PER_PIPE)
	_still = 0.0
	_said_near = false


func tick(delta: float) -> void:
	if _face_t > 0.0:
		_face_t -= delta
		_face.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 10.0
		NIGHTMARE_FX.update_retro(_face.get_viewport_rect().size.y)
		if _face_t <= 0.0:
			_face.visible = false
	if host._intro_t >= 0.0 or host._caught_t >= 0.0 or not _started:
		return
	var crawling: bool = host._moving
	# Home: at a hole he waits.
	var home: bool = host._at_leak
	if crawling or home:
		_still = 0.0
	else:
		_still += delta
		if _still > GRACE[tier]:
			gap = maxf(0.0, gap - GAIN[tier] * delta)
	_place()
	_sounds(delta, crawling or home)
	if gap <= 0.0:
		_catch()


## Him back along the way you came, `gap` half-lengths behind you, on the water.
func _place() -> void:
	var from: Vector3 = host._rig.position
	var left := clampf(gap, 0.25, GAP_MAX) * LENGTH * 0.5
	var at := from
	var i := _trail.size() - 1
	while left > 0.0 and i >= 0:
		var to: Vector3 = host._world_pos(_trail[i])
		to.y = from.y
		var seg := at.distance_to(to)
		if seg >= left:
			at = at.move_toward(to, left)
			left = 0.0
		else:
			at = to
			left -= seg
			i -= 1
	at.y = from.y - EYE_Y + 0.02
	_body.position = at
	_body.visible = gap < GAP_MAX - 0.2


func _sounds(delta: float, safe: bool) -> void:
	_next_splash -= delta
	if _next_splash <= 0.0 and not safe:
		_next_splash = lerpf(0.6, 2.0, gap / GAP_MAX)
		_at(DIR + "crawl_water.mp3", lerpf(-2.0, -16.0, gap / GAP_MAX))
	if gap < 1.2 and not _said_near:
		_said_near = true
		_at(DIR + "breath_close.mp3", -4.0)
		_say("tag_near_%d" % randi_range(1, 3), -5.0)
	_next_line -= delta
	if _next_line <= 0.0:
		_next_line = randf_range(12.0, 20.0)
		if randf() < 0.5:
			_at(DIR + "giggle_%d.mp3" % randi_range(1, 2), -10.0)


## At your ankle: "Mám tě!", his face, the hit; he lets go and is back a few lengths.
func _catch() -> void:
	caught += 1
	gap = GAP_START
	_still = 0.0
	_say("tag_got", -2.0)
	_sfx(DIR + "shriek.mp3", 0.0, 1.0)
	if _face.texture != null:
		_face.visible = true
		_face_t = 0.85
	host._bump_t = 0.0
	host.player_hurt.emit(HIT[tier])


func _say(id: String, db: float) -> void:
	_sfx(DIR + id + ".mp3", db, PITCH)


func _sfx(path: String, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := _ear
	if p.playing:
		p = AudioStreamPlayer.new()
		p.bus = host.audio_bus()
		host.add_child(p)
		p.finished.connect(p.queue_free)
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## A sound where he is in the pipe.
func _at(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = host.audio_bus()
	p.stream = load(path)
	p.volume_db = db
	p.max_distance = 26.0
	p.unit_size = 4.0
	host._geo.add_child(p)
	p.position = _body.position + Vector3(0, 0.3, 0)
	p.pitch_scale = 1.1
	p.play()
	p.finished.connect(p.queue_free)
