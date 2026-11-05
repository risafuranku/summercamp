extends SceneTree

## The radio's four tiers and the hells (the user 5. 11.), without the game around it:
## the tiers by prefix and by the night, what is drawn when, the splinters and the cut for
## the worst in radio_dread, a dread song left raw, the hide's hells, the motel set's lists,
## the chases' loops (looped, two in step), the Cheap Chick's laugh, the far illusions.
##   godot --headless --path godot --audio-driver Dummy --script res://tools/radio_tiers_check.gd

const TIERS = preload("res://scripts/radio/radio_tiers.gd")
const DREAD = preload("res://scripts/radio/radio_dread.gd")
const CARETAKER = preload("res://scripts/audio/caretaker.gd")
const CHASE = preload("res://scripts/audio/chase_music.gd")
const DIRECTOR = preload("res://scripts/night/night_director.gd")
const DIR := "res://assets/sfx/radio/"

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("  ", "ok   " if ok else "FAIL ", what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("radio_tiers_check")
	_check(TIERS.tier_of(DIR + "goodvibes_song.mp3") == 0 and TIERS.tier_of(DIR + "night_motif.mp3") == 1
		and TIERS.tier_of(DIR + "teror_spravce.mp3") == 2 and TIERS.tier_of(DIR + "peklo_kolena.mp3") == 3
		and TIERS.tier_of(DIR + "nightnoise.mp3") == 1, "tiers by prefix")
	_check(TIERS.tier_now(false, 1.0) == 0 and TIERS.tier_now(true, 0.2) == 1 and TIERS.tier_now(true, 0.6) == 2
		and TIERS.tier_now(true, 0.95) == 3, "tiers by the night (day 0 whatever the dread)")

	var paths: Array = []
	for f in DirAccess.get_files_at(DIR):
		var n := f.trim_suffix(".import").trim_suffix(".remap")
		if n.ends_with(".mp3") and not paths.has(DIR + n):
			paths.append(DIR + n)
	var count := {0: 0, 1: 0, 2: 0, 3: 0}
	for p in paths:
		count[TIERS.tier_of(p)] += 1
	print("    songs by tier ", count)
	_check(int(count[2]) >= 7 and int(count[3]) >= 8, "the dread tiers have their songs (teror %d, peklo %d)" % [count[2], count[3]])
	var bad: Array = []
	for p in paths:
		if load(p) == null:
			bad.append(p)
	_check(bad.is_empty(), "every radio song loads %s" % [str(bad) if not bad.is_empty() else ""])

	var t = TIERS.new()
	t.setup(paths)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var day := _draws(t, {"night": false, "tonight": []}, 1.0, rng)
	_check(day.is_empty(), "by day nothing of the night's, whatever the dread")
	var calm := _draws(t, {"night": true, "tonight": []}, 0.3, rng)
	_check(calm.is_empty(), "a quiet night: the playlist's own songs")
	var granny := _draws(t, {"night": true, "tonight": ["basket"]}, 0.3, rng)
	_check(_sum(granny) > 20 and granny.keys().size() == 1 and str(granny.keys()[0]).ends_with("night_hajejdadej.mp3"),
		"the granny out: her lullaby now and then (%d of 400) %s" % [_sum(granny), str(granny.keys())])
	var press := _draws(t, {"night": true, "tonight": []}, 0.6, rng)
	_check(_sum(press) > 120 and _sum(press) < 220 and press.keys().all(func(k): return TIERS.tier_of(k) == 2),
		"pressing: only teror_, %d of 400" % _sum(press))
	var worst := _draws(t, {"night": true, "tonight": []}, 0.95, rng)
	var hells := 0
	for k in worst:
		if TIERS.tier_of(k) == 3:
			hells += int(worst[k])
	_check(_sum(worst) > 280 and hells > _sum(worst) - hells, "the worst: mostly peklo_ (%d of %d drawn, %d of 400)" % [hells, _sum(worst), _sum(worst)])
	var last := ""
	var twice := false
	for i in 200:
		var p: String = t.pick({"night": true, "tonight": []}, 0.95, rng)
		if p != "" and p == last:
			twice = true
		if p != "":
			last = p
	_check(not twice, "never the same twice running")
	_check(TIERS.tier_of(t.pick_break(0.95, rng)) == 3 and TIERS.tier_of(t.pick_break(0.6, rng)) == 2, "the cut brings the worst's (peklo past PEKLO, teror under)")

	# radio_dread: the splinters and the cut.
	var r = DREAD.new()
	root.add_child(r)
	await process_frame
	var missing: Array = []
	for id in DREAD.FLASHES + ["s_laugh"]:
		if r._clip(id) == null:
			missing.append(id)
	_check(missing.is_empty(), "every splinter and the laugh load %s" % [str(missing) if not missing.is_empty() else ""])
	var music := AudioStreamPlayer.new()
	music.stream = load(DIR + "goodvibes_song.mp3")
	root.add_child(music)
	music.play()
	r.bind_music(music)
	r.debug_override = 0.9
	var ctx := {"night": true, "hours": 2.0, "day": 4, "tonight": ["girl"], "risk": 1.0, "nearest": INF, "listening": true, "client": false, "raw": false}
	var flashes := 0
	var breaks := 0
	var cut_seen := false
	var was := DREAD.Ev.NONE
	for i in 12000:
		r.update(0.1, ctx.duplicate(), -11.0, -80.0, true, null)
		# (A creature on the frequency ends when its clip does: faster than the sound runs here.)
		if r._event == DREAD.Ev.CREATURE:
			r._end_event()
		if r._event != was and r._event == DREAD.Ev.FLASH:
			flashes += 1
			if r.music_gain < 0.05:
				cut_seen = true
		was = r._event
		if r.take_break():
			breaks += 1
			r._snap_back = true
	_check(flashes >= 3, "splinters through the song on the worst night (%d in 20 min)" % flashes)
	_check(cut_seen, "a splinter cuts the song at once")
	_check(breaks >= 2 and breaks <= 9, "the worst cuts the song now and then (%d in 20 min)" % breaks)
	var raw := ctx.duplicate()
	raw["raw"] = true
	for i in 30:
		r.update(0.1, raw.duplicate(), -11.0, -80.0, true, null)
	var only := true
	for i in 300:
		var e: int = r._pick_event()
		if e == DREAD.Ev.FLASH or e == DREAD.Ev.BREAK or e == DREAD.Ev.DRIFT or e == DREAD.Ev.GHOST:
			only = false
	_check(only, "a dread song on air: no splinter, cut, drift or ghost over it")
	_check(r._raw > 0.9 and r._fx_hall != null and r._fx_hall.wet < 0.05, "a dread song on air is left raw (hall %.2f)" % (r._fx_hall.wet if r._fx_hall != null else -1.0))
	var client := ctx.duplicate()
	client["client"] = true
	r._raw = 0.0
	r._break_at = -9999.0
	r._ctx = client
	_check(not r._break_ready(), "the other machine's set never cuts (the host's does)")

	# The hide's hells, the motel's lists.
	var lost: Array = []
	# (The motel set's lists read off its source: it needs the game's autoloads to load.)
	var motel := FileAccess.get_file_as_string("res://scripts/town/motel_radio.gd")
	var lists := motel.substr(motel.find("const SONGS"), motel.find("const JINGLE") - motel.find("const SONGS"))
	lists += motel.substr(motel.find("const HELL"), motel.find("]", motel.find("const HELL")) - motel.find("const HELL"))
	var names: Array = CARETAKER.SONGS + CARETAKER.HELLS
	var re := RegEx.create_from_string("\"([a-z0-9_]+)\"")
	for m in re.search_all(lists):
		names.append(m.get_string(1))
	_check(names.size() > 50, "the motel set's lists read (%d names)" % names.size())
	for n in names:
		if not ResourceLoader.exists(DIR + str(n) + ".mp3"):
			lost.append(n)
	_check(lost.is_empty(), "the hide's and the motel set's songs are all there %s" % [str(lost) if not lost.is_empty() else ""])

	# The chases.
	var c = CHASE.new()
	root.add_child(c)
	await process_frame
	var looped := true
	for k in CHASE.LOOPS:
		for p in CHASE.LOOPS[k]:
			var s = load(p)
			looped = looped and s is AudioStreamOggVorbis and (s as AudioStreamOggVorbis).loop
	_check(looped, "the chase loops loop (their import)")
	var ga: AudioStream = load(CHASE.LOOPS["basket"][0])
	var gb: AudioStream = load(CHASE.LOOPS["basket"][1])
	_check(absf(ga.get_length() - gb.get_length()) < 0.001, "the granny's two loops are the same length (in step: %.4f / %.4f s)" % [ga.get_length(), gb.get_length()])
	for i in 20:
		c.want("basket", 1.0, 1.0)
		c.tick(0.016)
	_check(c.playing() and c._a.playing and c._b.playing and c._a.volume_db > -12.0 and c._b.volume_db > -3.0, "she runs at you: both loops in, the harder one up close")
	c.want("basket", 0.5, 0.0)
	for i in 120:
		c.want("basket", 0.5, 0.0)
		c.tick(0.016)
	_check(c._b.volume_db < -20.0 and c._a.volume_db > -10.0, "further off: the harder loop goes (%.1f / %.1f dB)" % [c._a.volume_db, c._b.volume_db])
	c.want("basket", -1.0)
	c.tick(0.016)
	_check(not c.playing() and not c._a.playing, "she stops to look: it stops dead")
	c.want("stalker", 1.0)
	c.tick(0.016)
	_check(c.playing() and c._b.stream == null, "the antlered man's charge: its own loop")
	for i in 60:
		c.tick(0.016)
	_check(not c.playing(), "nobody running at you: it goes")

	_check(ResourceLoader.exists("res://assets/sfx/npc/girl_laugh.mp3") and load("res://assets/sfx/npc/girl_laugh.mp3").get_length() > 3.0, "her laugh")
	var ill := true
	for i in range(1, 7):
		ill = ill and ResourceLoader.exists("res://assets/sfx/night/illusion_%d.ogg" % i)
	_check(ill and DIRECTOR.EVENTS.has("hell_far") and DIRECTOR.LOG_LINES.has("hell_far"), "the hells far off in the night: six, a beat of the director's")

	print("radio_tiers_check: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)


func _draws(t, ctx: Dictionary, dread: float, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for i in 400:
		var p: String = t.pick(ctx, dread, rng)
		if p != "":
			out[p] = int(out.get(p, 0)) + 1
		else:
			# The playlist's song played.
			t.played("res://assets/sfx/radio/goodvibes_song.mp3")
	return out


func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s
