extends Node

## Headless check of the quiet details of the night (DESIGN §2):
## threat_senses.gd (insect hush, the HUD face's fear and glance), the radio station
## that does not exist, the night log stamped with tomorrow's date, and the story pool.
##
##   godot --headless --path godot res://tools/uncanny_check.tscn

const SENSES := preload("res://scripts/threat_senses.gd")


class FakeBrain:
	extends RefCounted
	var pos: Vector3 = Vector3.INF

	func get_presence() -> Dictionary:
		return {} if pos == Vector3.INF else {"position": pos}


var _failures: Array[String] = []


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0, 1.6, 0)
	cam.look_at(Vector3(0, 1.6, -10))
	var brain := FakeBrain.new()
	var s = SENSES.new()

	# Behind and to the left: the face glances left, the insects stop, the eyes widen.
	brain.pos = Vector3(-3, 0, 6)
	_run(s, [brain], cam, 2.0)
	_expect(s.gaze == -1, "behind-left: gaze %d, want -1" % s.gaze)
	_expect(s.hush > 0.9, "behind-left at 6.7 m: hush %.2f, want > 0.9" % s.hush)
	_expect(s.fear > 0.5, "behind-left at 6.7 m: fear %.2f, want > 0.5" % s.fear)

	# Right behind you and slightly right.
	brain.pos = Vector3(4, 0, 3)
	_run(s, [brain], cam, 0.2)
	_expect(s.gaze == 1, "behind-right: gaze %d, want 1" % s.gaze)

	# In plain sight: no need to point.
	brain.pos = Vector3(1, 0, -8)
	_run(s, [brain], cam, 1.5)
	_expect(s.gaze == 0, "in front: gaze %d, want 0" % s.gaze)

	# Far away: nothing.
	brain.pos = Vector3(0, 0, 60)
	_run(s, [brain], cam, 1.5)
	_expect(s.gaze == 0, "far: gaze %d, want 0" % s.gaze)

	# Silence lifts slowly once it is gone.
	s.reset()
	brain.pos = Vector3(2, 0, 4)
	_run(s, [brain], cam, 2.0)
	brain.pos = Vector3.INF
	_run(s, [brain], cam, 1.0)
	_expect(s.hush > 0.7, "1 s after it left: hush %.2f, want > 0.7 (slow return)" % s.hush)
	_run(s, [brain], cam, 10.0)
	_expect(s.hush < 0.05, "10 s after it left: hush %.2f, want ~0" % s.hush)

	# The phantom glance: at most once a night, on roughly a third of nights, and only
	# when standing still.
	var nights_with := 0
	for night in 400:
		var t = SENSES.new()
		var glances := 0
		var was := 0
		for i in 200:
			t.update(0.1, [], cam, night, 0.0 if i < 50 else 30.0)
			if t.gaze != 0 and was == 0:
				glances += 1
				_expect(i >= 50, "night %d: phantom glance while moving" % night)
			was = t.gaze
		_expect(glances <= 1, "night %d: %d phantom glances" % [night, glances])
		if glances > 0:
			nights_with += 1
	var share := float(nights_with) / 400.0
	_expect(share > 0.25 and share < 0.45, "phantom on %.0f%% of nights, want ~35%%" % (share * 100.0))

	# The station that does not exist: intro, N pips (every fifth with a longer pause),
	# outro, as one playlist.
	var interior: Script = load("res://scripts/building_interior.gd")
	var station: AudioStream = interior.build_station_stream(12)
	_expect(station is AudioStreamPlaylist, "station stream is not a playlist")
	if station is AudioStreamPlaylist:
		var pl := station as AudioStreamPlaylist
		_expect(pl.stream_count == 14, "station: %d streams, want 14" % pl.stream_count)
		var long_pauses := 0
		for i in range(1, pl.stream_count - 1):
			if pl.get_list_stream(i).resource_path.ends_with("station_pip5.wav"):
				long_pauses += 1
		_expect(long_pauses == 2, "station: %d long pauses in 12 pips, want 2" % long_pauses)
		_expect(not pl.loop, "station must not loop")
		print("UNCANNY CHECK: station with 12 pips = %.1f s" % station.get_length())

	# A mail stamped later than it was delivered sorts and prints with its stamp.
	var shell = load("res://scripts/crt_os_shell.gd").new()
	var night_log := {"day": 4, "time": "03:00", "stamp_day_offset": 1}
	_expect(shell._email_mail_datetime_label(night_log) == "Day 5  03:00", "night log label: %s" % shell._email_mail_datetime_label(night_log))
	_expect(shell._email_mail_sort_key(night_log) > shell._email_mail_sort_key({"day": 4, "time": "23:59"}), "night log does not sort after its own day")
	shell.free()

	# The story pool: every mail parses, no two mails share a subject and body, and
	# there is exactly one mail stamped with a later day.
	var pool = JSON.parse_string(FileAccess.get_file_as_string("res://data/pools/emails/story/week01_story.json"))
	_expect(pool is Array and pool.size() > 10, "story pool did not parse")
	if pool is Array:
		var seen := {}
		var stamped := 0
		for m in pool:
			var key := "%s|%s" % [m.get("subject", ""), m.get("body", "")]
			_expect(not seen.has(key), "story pool duplicate: %s" % m.get("subject", ""))
			seen[key] = true
			if int(m.get("stamp_day_offset", 0)) != 0:
				stamped += 1
			_expect(str(m.get("body", "")).find("transmission tag") < 0, "story pool filler tag in: %s" % m.get("subject", ""))
		_expect(stamped == 1, "story pool: %d stamped mails, want 1" % stamped)

	print("")
	if _failures.is_empty():
		print("UNCANNY CHECK: PASS")
		get_tree().quit(0)
	else:
		print("UNCANNY CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _run(s, brains: Array, cam: Camera3D, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		s.update(0.05, brains, cam, -1, 0.0)
		t += 0.05


func _expect(ok: bool, what: String) -> void:
	if not ok and _failures.size() < 20:
		_failures.append(what)
