extends "res://scripts/enemies/child_brain.gd"

## The boy (Family; the user 21. 10.: "když táta spawnul enemáka, kluk je v trubkách nebo
## v kukuřičným poli nebo v budově s pojistkama ... u nočních rutinních úkolů ti bude
## kurvit život"). The family's boy is not in their tent tonight: he is where the night's
## routine work is, and each of those places is a children's game with its own rules
## (DESIGN §5 "The boy"):
##   corn     hide and seek: he whispers cold, warmer, burning; found, you lead him out by
##            the hand and you must not look back at him (scripts/corn_hunt.gd, boy mode)
##   breaker  "Cukr, kava, limonada ... BUM!" at the board (to come)
##   sewer    tag in the pipes (to come; the raccoon stays the pipes' other thing)
## How hard the family presses (the night's difficulty) is how far gone he is: light he
## plays fair, medium he cheats (the hints lie now and then), heavy he is all nightmare.
##
## His father is the omen: once the boy is out there, now and then the father stands in
## your way in the dark, his hand out holding nothing, and asks after him; look away and
## he is not there.
##
## Found and out: he is back in the tent by morning, remembering nothing. Not found by
## dawn: the family is gone (`claimed`, main._claim_turned_guests).
## No place for him in this camp (no corn, no generator, no sewer): the old Extra Child
## among the tents (child_brain.gd).

const DAD_SPRITE := "res://assets/textury/npc/boy_dad.png"
const DAD_FALLBACK := "res://assets/textury/npc/host_family.png"
const DAD_LINES := ["res://assets/sfx/npc/boy/dad_1.mp3", "res://assets/sfx/npc/boy/dad_2.mp3",
	"res://assets/sfx/npc/boy/dad_3.mp3", "res://assets/sfx/npc/boy/dad_4.mp3"]
## The father: the wait between his showings (s, light .. heavy), how far off (m), how
## long he stands at most, how near you may come.
const DAD_EVERY := [Vector2(55.0, 85.0), Vector2(40.0, 65.0), Vector2(28.0, 45.0)]
const DAD_DIST := Vector2(8.0, 11.0)
const DAD_STAND := 12.0
const DAD_NEAR := 3.5

## 1 light, 2 medium, 3 heavy.
var tier := 1
## Where he is tonight: "corn", "breaker", "sewer", or "" (the old child among the tents).
var place := ""
var found := false
## A test night: his job within a minute or two, not an hour on.
var soon := false
var _job_made := false
var _dad: Sprite3D
var _dad_next := 20.0
var _dad_until := -1.0
var _dad_seen := false
var _dad_unseen := 0.0
var _dad_line := 0


func get_enemy_id() -> String:
	return "child"


func _on_start() -> void:
	tier = 1 if _difficulty <= 2 else (2 if _difficulty == 3 else 3)
	place = _pick_place()
	if place == "":
		super._on_start()
		return
	# Gone by morning unless he is found and brought out.
	claimed = true
	_dad = _make_body(DAD_SPRITE if ResourceLoader.exists(DAD_SPRITE) else DAD_FALLBACK, 1.8)
	_dad.visible = false
	# The base hides it indoors and tells the insects where it is.
	_body = _dad
	_dad_next = _rng.randf_range(15.0, 30.0)


func _on_tick(dt: float) -> void:
	if place == "":
		super._on_tick(dt)
		return
	if not _job_made:
		_job_made = _make_job()
	_tick_dad(dt)


## Tests: put him at `where` ("corn", "breaker") tonight; a job of his made already is
## called off.
func force_place(where: String) -> void:
	var m := _main()
	var nj = m.get("_night_jobs") if m != null else null
	if nj != null:
		for j in nj.get("_jobs"):
			if (j as Dictionary).has("boy") and str(j["state"]) == "pending":
				j["state"] = "cancelled"
	place = where
	_job_made = false


## The boy was brought out (main._on_corn_hunt_finished): back in the tent by morning.
func boy_found() -> void:
	found = true
	claimed = false
	if _dad != null:
		_dad.visible = false


func _main() -> Node:
	return _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null


## The places this camp has for him, one picked: the corn, the generator's board (the
## pipes to come).
func _pick_place() -> String:
	var m := _main()
	var have: Array = []
	if m != null and m.has_method("corn_field_ready") and bool(m.call("corn_field_ready")):
		have.append("corn")
	var nj = m.get("_night_jobs") if m != null else null
	if nj != null and not (nj.call("_coords_of", ["power_generator"]) as Array).is_empty():
		have.append("breaker")
	if have.is_empty():
		return ""
	return str(have[_rng.randi() % have.size()])


## Tonight's job at his place, with him in it (scripts/night_jobs.gd add_boy_job).
func _make_job() -> bool:
	var m := _main()
	var nj = m.get("_night_jobs") if m != null else null
	if nj == null or not nj.has_method("add_boy_job"):
		return false
	var who: Dictionary = _night_entry.get("guest", {})
	return bool(nj.call("add_boy_job", place, tier, who, soon))


## Is he still out there (his job open, not found)?
func _boy_out() -> bool:
	if found:
		return false
	var m := _main()
	var nj = m.get("_night_jobs") if m != null else null
	return nj != null and nj.has_method("boy_job_open") and bool(nj.call("boy_job_open"))


# ── the father ───────────────────────────────────────────────────────────────

## Now and then, while the boy is out there and you are outdoors: the father in front of
## you in the dark, 8-11 m off, his hand out holding nothing, asking after him (a line
## more each time, the last one asked twice). Gone when you look away, come near, or after
## a while.
func _tick_dad(dt: float) -> void:
	if _dad == null:
		return
	if _dad.visible:
		var head := _dad.global_position + Vector3(0, 1.5, 0)
		var seen := _is_seen(head)
		if seen:
			_dad_seen = true
			_dad_unseen = 0.0
		else:
			_dad_unseen += dt
		var gone := _elapsed >= _dad_until or _distance_to_player(_dad.global_position) < DAD_NEAR \
			or (_dad_seen and _dad_unseen > 0.6) or not _boy_out()
		if gone:
			_dad.visible = false
			var every: Vector2 = DAD_EVERY[tier - 1]
			_dad_next = _rng.randf_range(every.x, every.y)
		return
	if not _boy_out():
		return
	_dad_next -= dt
	if _dad_next > 0.0:
		return
	# In front of you, a little to one side: where your torch goes.
	for _i in 10:
		var p := _point_from_player(_rng.randf_range(DAD_DIST.x, DAD_DIST.y), _rng.randf_range(-22.0, 22.0))
		if p == Vector3.INF or _ray_blocked(_player_pos() + Vector3(0, 1.6, 0), p + Vector3(0, 1.4, 0)):
			continue
		_dad.global_position = p
		_dad.visible = true
		_dad_seen = false
		_dad_unseen = 0.0
		_dad_until = _elapsed + DAD_STAND
		var line: String = DAD_LINES[mini(_dad_line, DAD_LINES.size() - 1)]
		_dad_line += 1
		_sound_quarry(line, p + Vector3(0, 1.6, 0), -2.0, 1.0, 30.0)
		return
	_dad_next = 4.0
