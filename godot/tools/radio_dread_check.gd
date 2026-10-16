extends SceneTree

## The radio going wrong (scripts/radio/radio_dread.gd), without the game around it:
## every sound it can ask for loads, dread follows the lamps and the hour, the
## interlude names tonight's visitor and counts the guests plus one, something close
## silences the songs.
##   godot --headless --path godot --script res://tools/radio_dread_check.gd

const DREAD = preload("res://scripts/radio/radio_dread.gd")

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("radio_dread_check")
	var r = DREAD.new()
	root.add_child(r)
	await process_frame

	var ids: Array = ["static", "carrier", "buzzer", "v_callsign", "v_hostu", "v_opakuji", "v_zrusit", "v_konec",
		"v_hlidac", "v_datum", "f_count", "f_count2", "f_dobrou", "l_a1", "l_b1", "l_a2", "l_b2", "s_chair", "s_cough",
		"s_whistle", "s_kids", "s_knock", "s_breath"]
	ids.append_array(DREAD.CODEWORDS.values())
	ids.append_array(DREAD.GENERAL_WORDS)
	ids.append_array(DREAD.NIGHT_CREATURES)
	ids.append_array(DREAD.NEAR_LINES)
	ids.append_array(DREAD.TUNES)
	for n in 21:
		ids.append("v_n%d" % n)
	var missing: Array = []
	for id in ids:
		if r._clip(id) == null:
			missing.append(id)
	_check(missing.is_empty(), "all %d sounds load %s" % [ids.size(), str(missing) if not missing.is_empty() else ""])
	_check(r._clip("buzzer") is AudioStreamWAV and (r._clip("buzzer") as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "the buzz loops")

	var night := {"night": true, "hours": 2.0, "day": 4, "tonight": []}
	var prev := -1.0
	var rising := true
	for lvl in 5:
		var c := night.duplicate()
		c["risk"] = lvl / 4.0
		var t: float = DREAD.compute_target(c)
		rising = rising and t > prev
		prev = t
	_check(rising, "dread rises with every NIGHT RISK lamp")
	var crit := night.duplicate()
	crit["risk"] = 1.0
	_check(DREAD.compute_target(crit) > 0.85, "critical at 02:00 is near the top (%.2f)" % DREAD.compute_target(crit))
	var noon := {"night": false, "hours": 12.0, "day": 4, "tonight": [], "risk": 1.0}
	_check(DREAD.compute_target(noon) < 0.3, "by day the lamps only make the set sick (%.2f)" % DREAD.compute_target(noon))
	var first := crit.duplicate()
	first["day"] = 1
	_check(DREAD.compute_target(first) <= DREAD.QUIET_NIGHT_CAP + 0.001, "the first night only frets")
	var visited := night.duplicate()
	visited["risk"] = 0.25
	visited["tonight"] = ["girl", "stalker"]
	var calm := night.duplicate()
	calm["risk"] = 0.25
	_check(DREAD.compute_target(visited) > DREAD.compute_target(calm) + 0.2, "what is out tonight makes it worse")

	var ctx := {"night": true, "hours": 23.0, "day": 4, "tonight": ["girl"], "guests": 7, "risk": 1.0}
	r._ctx = ctx
	var named := 0
	var counted := true
	var fits := true
	var longest := 0.0
	for i in 30:
		var built: Dictionary = r.build_interlude(ctx, 0.9)
		var pl: AudioStreamPlaylist = built["stream"]
		fits = fits and pl.stream_count <= AudioStreamPlaylist.MAX_STREAMS and pl.stream_count > 8
		longest = maxf(longest, float(built["length"]))
		var has_word := false
		var has_7 := false
		var has_8 := false
		for k in pl.stream_count:
			var s := pl.get_list_stream(k)
			has_word = has_word or s == r._clip("v_holka")
			has_7 = has_7 or s == r._clip("v_n7")
			has_8 = has_8 or s == r._clip("v_n8")
		named += 1 if has_word else 0
		counted = counted and has_7 and has_8
	_check(named >= 10, "tonight's word (the girl) is read in most broadcasts (%d/30)" % named)
	_check(counted, "the guests are counted: seven, seven, eight")
	_check(fits, "every broadcast fits one playlist")
	_check(longest > 15.0 and longest < 90.0, "a broadcast lasts a while (longest %.0f s)" % longest)

	var music := AudioStreamPlayer.new()
	root.add_child(music)
	music.stream = r._clip("static")
	music.play()
	r.bind_music(music)
	var near := {"night": true, "hours": 1.0, "day": 4, "tonight": ["silent_man"], "guests": 5, "risk": 0.5, "nearest": 4.0}
	for i in 180:
		r.update(1.0 / 60.0, near.duplicate(), -11.0, -80.0, true, null)
	_check(r.music_gain < 0.25, "something close silences the song (gain %.2f)" % r.music_gain)
	_check((r._layers["carrier"] as RefCounted).get("target") > 0.3, "and leaves the dead carrier")
	var far := near.duplicate()
	far["nearest"] = INF
	for i in 900:
		r.update(1.0 / 60.0, far.duplicate(), -11.0, -80.0, true, null)
	_check(r.music_gain > 0.6 or r._event != DREAD.Ev.NONE, "and the song comes back when it leaves")

	r.debug_override = 0.0
	r.update(0.1, far.duplicate(), -11.0, -80.0, true, null)
	_check(r.dread == 0.0 and r.dropout_interval_scale() == 1.0, "debug override pins dread")

	print("radio_dread_check: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
