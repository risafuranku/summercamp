extends Node

## Load on the corn stand's hands (TODO W50, the user 4. 11.: "I have the corn stand and two
## hands, and there is always a queue and people go away hungry; one hand should cope easily,
## the second only for a big rush"). A steady stream of guests orders at the stand for
## SIM_SEC seconds (a second at a time: the pot boils and the hands work as in the game, the
## clock 1.5 game minutes a second); counted: cobs handed over, cob orders given up (their
## patience gone), drinks, the average wait. One hand (the counter's) and two (the husk's and
## the counter's) of each speed, at a few rates of cob orders a minute. Lines "LOAD ...".
##   godot --headless --path godot --audio-driver Dummy res://tools/stand_load.tscn

const CORN := preload("res://core/systems/corn_rules.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const CORNSTAND := preload("res://scripts/corn/cornstand.gd")
const KEY := "11:11"
const SIM_SEC := 360
const RATES := [4.0, 6.0, 8.0, 12.0]
const ARCH := ["picker", "drunk", "quiet_guy", "tramp"]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for crew in [["counter"], ["husk", "counter"]]:
		for speed in [0, 1, 2]:
			var line := "LOAD hands=%d speed=%d" % [crew.size(), speed]
			for rate in RATES:
				if only != "" and only != "%d" % crew.size():
					continue
				var r := _run(rate, crew, speed)
				line += "  | %2.0f/min: served %3d lost %3d (%2.0f%%) wait %4.1fs" % [rate, int(r["served"]), int(r["lost"]), 100.0 * float(r["lost"]) / maxf(1.0, float(r["served"] + r["lost"])), float(r["wait"])]
			print(line)
	get_tree().quit()


func _clock(gm: float) -> void:
	GuestManager._last_known_day = 3
	GuestManager._last_known_hour = int(gm / 60.0)
	GuestManager._last_known_minute = int(gm) % 60


func _run(rate: float, roles: Array, speed: int) -> Dictionary:
	_rng.seed = 4111 + int(rate * 10.0)
	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.guests.clear()
	state.money = 50000
	state.day = 3
	var gm := 9.0 * 60.0
	_clock(gm)
	state.grid.occupy_cell(Vector2i(11, 11), "corn_stand", "corn_stand_11_11", Vector2i(11, 11))
	var site: Dictionary = a.biz_site(KEY, "corn_stand")
	for g in ["cobs", "butter", "tea", "limo"]:
		site["stock"][g] = 100000
	var slugs := ["pepicek", "klara"]
	for i in roles.size():
		var p := RULES.person(str(slugs[i]), "corn")
		p["role"] = str(roles[i])
		p["shift"] = "day"
		p["speed"] = speed
		p["temper"] = ""
		a.biz_hire(KEY, p, 1)
	var stand = CORNSTAND.of(get_tree())
	stand._sites.clear()
	stand._crew_t.clear()
	stand._process(0.0)
	var seen := {}       # tid -> since (game minute)
	var done := {}
	var served := 0
	var lost := 0
	var wait_sum := 0.0
	var next_id := 9000
	# Visits a second: the cob orders a minute over the figures a visit brings (1.6).
	var per_sec := rate / 60.0 / 1.6
	for sec in SIM_SEC:
		gm += 1.5
		_clock(gm)
		if _rng.randf() < per_sec:
			var f := 1 if _rng.randf() < 0.55 else (2 if _rng.randf() < 0.7 else 3)
			var now := int(gm) + (3 - 1) * 1440
			state.guests.append({"id": next_id, "name": "Load %d" % next_id, "archetype": ARCH[next_id % ARCH.size()], "status": "active",
				"party_size": f, "mood": 60.0, "needs": {},
				"activity": {"kind": "visit", "target_key": KEY, "start": now, "arrive": now, "end": now + 2000}})
			next_id += 1
		stand._process(1.0)
		var tix: Array = stand.tickets(KEY)
		var open := {}
		for t in tix:
			open[str(t["id"])] = true
			if not seen.has(str(t["id"])):
				seen[str(t["id"])] = [int(t["since"]), str(t["kind"])]
		var srv: Dictionary = stand.site(KEY)["served"]
		for tid in seen:
			if done.has(tid) or open.has(tid):
				continue
			done[tid] = true
			if str(seen[tid][1]) != "cob":
				continue
			if srv.has(tid):
				served += 1
				wait_sum += (gm + 2.0 * 1440.0 - float(seen[tid][0])) / 1.5
			else:
				lost += 1
		# Whoever has nothing more coming leaves.
		var keep: Array = []
		for g in state.guests:
			var visit := "%d@%d" % [int(g["id"]), int(g["activity"]["start"])]
			var any := false
			for t in tix:
				if str(t["visit"]) == visit:
					any = true
					break
			if any or int(g["activity"]["arrive"]) + CORN.ORDER_DELAY + 4 > int(gm) + 2 * 1440:
				keep.append(g)
		state.guests.clear()
		for g in keep:
			state.guests.append(g)
	return {"served": served, "lost": lost, "wait": wait_sum / maxf(1.0, float(served))}
