extends RefCounted

## What a room (or a toilet / shower block) looks like when the player walks in to clean
## it (pure). Every time a room goes dirty it gets a new mess: a seed and a level. The
## same seed always gives the same mess, so a save, the paper map and the interior all
## agree on what is left to do.
##
##   level 0   just built, or a quiet guest: one or two things
##   level 4   a party of lads after four nights: everything, everywhere
##
## Spots are named places in an interior ("f1" on the floor, "t1" on the table, "wc" in
## the bathroom). The rules choose which spots are messy and with what; the interior
## knows where each spot is and builds the props for the kind of mess
## (scripts/interior_prep.gd).

## kind -> label, verb, seconds, sfx (scripts/interior_tasks.gd plays assets/sfx/rooms/<sfx>)
const MESS := {
	"bottles": {"label": "Clear away the bottles", "verb": "Clearing up", "seconds": 1.4, "sfx": "task_litter.mp3"},
	"cans": {"label": "Pick up the beer cans", "verb": "Picking up", "seconds": 1.2, "sfx": "task_litter.mp3"},
	"papers": {"label": "Pick up the wrappers", "verb": "Picking up", "seconds": 1.1, "sfx": "task_litter.mp3"},
	"butts": {"label": "Sweep up the cigarette ends", "verb": "Sweeping", "seconds": 1.5, "sfx": "task_litter.mp3"},
	"food": {"label": "Scrape off the old goulash", "verb": "Scraping", "seconds": 1.7, "sfx": "task_scrub.mp3"},
	"clothes": {"label": "Bag the forgotten clothes", "verb": "Bagging", "seconds": 1.3, "sfx": "task_bed.mp3"},
	"mud": {"label": "Mop the muddy footprints", "verb": "Mopping", "seconds": 2.0, "sfx": "task_scrub.mp3"},
	"sand": {"label": "Sweep out the sand", "verb": "Sweeping", "seconds": 1.5, "sfx": "task_litter.mp3"},
	"vomit": {"label": "Mop up the sick", "verb": "Mopping", "seconds": 2.4, "sfx": "task_scrub.mp3"},
	"mushrooms": {"label": "Throw out the rotten mushrooms", "verb": "Throwing out", "seconds": 1.4, "sfx": "task_litter.mp3"},
	"toys": {"label": "Pick up the toys", "verb": "Picking up", "seconds": 1.3, "sfx": "task_litter.mp3"},
	"ash": {"label": "Sweep up the ash and tent pegs", "verb": "Sweeping", "seconds": 1.6, "sfx": "task_litter.mp3"},
	"sawdust": {"label": "Sweep up the builders' sawdust", "verb": "Sweeping", "seconds": 1.4, "sfx": "task_litter.mp3"},
	# Bathrooms and the toilet / shower blocks.
	"toilet_grime": {"label": "Scrub the toilet", "verb": "Scrubbing", "seconds": 2.2, "sfx": "task_scrub.mp3"},
	"sink_grime": {"label": "Wipe the sink", "verb": "Wiping", "seconds": 1.5, "sfx": "task_scrub.mp3"},
	"shower_mould": {"label": "Scrub the mould off the tiles", "verb": "Scrubbing", "seconds": 2.2, "sfx": "task_scrub.mp3"},
	"puddle": {"label": "Mop the floor", "verb": "Mopping", "seconds": 1.8, "sfx": "task_scrub.mp3"},
	"paper_out": {"label": "Put in a new toilet roll", "verb": "Refilling", "seconds": 1.0, "sfx": "task_bed.mp3"},
	"hair": {"label": "Pull the hair out of the drain", "verb": "Pulling", "seconds": 1.8, "sfx": "task_scrub.mp3"},
	"graffiti": {"label": "Scrub the writing off the door", "verb": "Scrubbing", "seconds": 2.0, "sfx": "task_scrub.mp3"},
	"blocked": {"label": "Unblock the toilet", "verb": "Plunging", "seconds": 3.2, "sfx": "task_scrub.mp3"},
	"showerhead": {"label": "Screw the shower head back on", "verb": "Fixing", "seconds": 3.0, "sfx": "task_scrub.mp3"},
}

## Room spots, by room kind: floor spots and (cabins) bathroom spots.
const ROOM_SPOTS := {
	"tent": ["f1", "f2", "f3", "f4", "f5"],
	"cabin": ["f1", "f2", "f3", "f4", "f5", "f6"],
}
const BATH_SPOTS := ["wc", "sink", "bfloor"]
const BATH_KINDS := {"wc": ["toilet_grime"], "sink": ["sink_grime", "hair"], "bfloor": ["puddle", "mud", "paper_out"]}

## Ordinary leftovers, then what each archetype adds (and how much worse they leave it).
const COMMON := ["papers", "bottles", "cans", "clothes", "mud"]
const BY_ARCHETYPE := {
	"quiet_guy": {"level": 0, "kinds": ["papers"]},
	"drunk": {"level": 2, "kinds": ["bottles", "cans", "vomit", "butts"]},
	"cheap_chick": {"level": 1, "kinds": ["clothes", "sand", "papers"]},
	"tramp": {"level": 1, "kinds": ["ash", "cans", "mud", "food"]},
	"family": {"level": 2, "kinds": ["toys", "food", "mud", "sand"]},
	"picker": {"level": 0, "kinds": ["mushrooms", "mud"]},
}
## Things on a table are things you put on a table.
const TABLE_KINDS := ["bottles", "food", "cans", "mushrooms", "papers"]

## Toilet and shower blocks: spots inside the block (scripts/service_interior.gd places
## them: the stalls and showers are seen from the side rooms, A / D).
const BLOCK_SPOTS := {
	"toilet": ["stall_l", "stall_r", "urinal", "door_l", "door_r", "floor_c", "wall_l"],
	"wash": ["shower_l", "shower_r", "drain_l", "drain_r", "floor_c", "floor_l", "floor_r"],
}
const BLOCK_KINDS := {
	"stall_l": ["puddle", "paper_out", "mud"], "stall_r": ["puddle", "paper_out", "mud"],
	"urinal": ["butts", "puddle"], "door_l": ["graffiti"], "door_r": ["graffiti"], "wall_l": ["graffiti"],
	"floor_c": ["puddle", "mud", "papers"],
	"shower_l": ["shower_mould"], "shower_r": ["shower_mould"],
	"drain_l": ["hair", "puddle"], "drain_r": ["hair", "puddle"],
	"floor_l": ["puddle", "clothes", "sand"], "floor_r": ["sand", "clothes", "hair"],
}
## What a breakdown is, inside: the fix is one more (longer) job.
const BLOCK_BREAKDOWN := {"toilet": {"spot": "stall_r", "kind": "blocked"}, "wash": {"spot": "drain_r", "kind": "showerhead"}}


static func task_for(spot: String, kind: String) -> Dictionary:
	var m: Dictionary = MESS.get(kind, MESS["papers"])
	return {"id": spot, "spot": spot, "mess": kind, "label": str(m["label"]), "verb": str(m["verb"]), "seconds": float(m["seconds"]), "sfx": str(m["sfx"])}


## The mess left by the guests leaving: level from who they were and how long they
## stayed. `archetypes` may repeat (one entry per party).
static func level_for(archetypes: Array, party_size: int, nights: int, unhappy: bool) -> int:
	var lv := 0
	for a in archetypes:
		lv = maxi(lv, int((BY_ARCHETYPE.get(str(a), {}) as Dictionary).get("level", 0)))
	if party_size >= 3:
		lv += 1
	if nights >= 3:
		lv += 1
	if unhappy:
		lv += 1
	return clampi(lv, 0, 4)


## The cleaning list for a room. `mess` = {seed, level, archetypes, fresh}: `fresh` is
## a room nobody has slept in yet (the builders' leftovers). The bed task comes first
## and is always there; the bathroom toilet whenever the room has one.
static func room_tasks(kind: String, has_bathroom: bool, mess: Dictionary, bed_task: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(mess.get("seed", 1))
	var level := clampi(int(mess.get("level", 1)), 0, 4)
	var fresh := bool(mess.get("fresh", false))
	var pool: Array = ["sawdust", "papers"] if fresh else COMMON.duplicate()
	if not fresh:
		for a in mess.get("archetypes", []):
			var extra: Array = (BY_ARCHETYPE.get(str(a), {}) as Dictionary).get("kinds", [])
			# Their own kind of mess, three times as likely as the ordinary stuff.
			for _i in 3:
				pool.append_array(extra)
	var out: Array = []
	if not bed_task.is_empty():
		out.append(bed_task)
	var spots: Array = (ROOM_SPOTS.get(kind, []) as Array).duplicate()
	_shuffle(spots, rng)
	var count := clampi(1 + level + rng.randi_range(0, 1), 1, spots.size())
	if fresh:
		count = mini(count, 2)
	for i in count:
		var spot := str(spots[i])
		var kinds := pool
		if spot.begins_with("t"):
			kinds = pool.filter(func(k): return TABLE_KINDS.has(k))
			if kinds.is_empty():
				kinds = ["bottles"]
		# Prefer something not already on the list: a room is a mix of things.
		var pick := str(kinds[rng.randi_range(0, kinds.size() - 1)])
		for _try in 3:
			if not out.any(func(t): return str(t.get("mess", "")) == pick):
				break
			pick = str(kinds[rng.randi_range(0, kinds.size() - 1)])
		out.append(task_for(spot, pick))
	if has_bathroom:
		out.append(task_for("wc", "toilet_grime"))
		if not fresh and (level >= 1 and rng.randf() < 0.35 + 0.15 * level):
			var k: Array = BATH_KINDS["sink"]
			out.append(task_for("sink", str(k[rng.randi_range(0, k.size() - 1)])))
		if not fresh and (level >= 2 and rng.randf() < 0.25 + 0.15 * level):
			var k2: Array = BATH_KINDS["bfloor"]
			out.append(task_for("bfloor", str(k2[rng.randi_range(0, k2.size() - 1)])))
	return out


## The cleaning list inside a toilet ("toilet") or shower ("wash") block: the worse its
## condition, the more spots; a broken block also has its breakdown to fix.
static func block_tasks(block: String, condition: float, broken: bool, seed: int) -> Array:
	var out: Array = []
	var spots: Array = (BLOCK_SPOTS.get(block, []) as Array).duplicate()
	if spots.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var brk: Dictionary = BLOCK_BREAKDOWN.get(block, {})
	if broken and not brk.is_empty():
		out.append(task_for(str(brk["spot"]), str(brk["kind"])))
		spots.erase(str(brk["spot"]))
	var dirt := clampf(0.9 - condition, 0.0, 0.9)
	if dirt <= 0.0 and not broken:
		return out
	_shuffle(spots, rng)
	var count := clampi(1 + int(ceil(dirt / 0.15)), 1, spots.size())
	if broken:
		count = maxi(count, 2)
	for i in count:
		var spot := str(spots[i])
		var kinds: Array = BLOCK_KINDS.get(spot, ["puddle"])
		out.append(task_for(spot, str(kinds[rng.randi_range(0, kinds.size() - 1)])))
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
