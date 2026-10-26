extends RefCounted

## The hands work beside you as another warden would, at every business with stations (the
## user 25. 10.: "let me work together with him like another player: he takes stations, I
## can go anywhere and come first, he is always where he is needed and where I am not";
## 26. 10.: the pub, the bistro and the Jednota as the corn stand): each to their own job's
## station unless a warden is at it (you come first), then to the free station that most
## wants doing, never two to one; with nothing wanted, aside. The place says how much each
## station wants doing (its `need`, from its own records); the wardens' stations are in
## their room states (interior_manager.coop_room, Coop.state_of), so every machine works it
## out the same and the figures stand where the work is done.


## slug -> the station that hand works now ("" aside). `role_at`: role -> its station;
## `stations`: where a hand may be moved to, in the chain's order (the first wins a tie);
## `busy`: the stations wardens are at; `need`: station -> how much it wants doing (0 none).
static func places(crew: Array, role_at: Dictionary, stations: Array, busy: Array, need: Callable) -> Dictionary:
	var out := {}
	var taken := {}
	var wanting: Array = []
	for p in crew:
		var own := str(role_at.get(str(p.get("role", "")), ""))
		if own != "" and not busy.has(own) and not taken.has(own):
			taken[own] = true
			out[str(p.get("slug", ""))] = own
		else:
			wanting.append(p)
	var needs := {}
	for p in wanting:
		var best := ""
		var best_need := 0.0
		for st in stations:
			if busy.has(st) or taken.has(st):
				continue
			if not needs.has(st):
				needs[st] = float(need.call(str(st)))
			if float(needs[st]) > best_need:
				best_need = float(needs[st])
				best = str(st)
		if best != "":
			taken[best] = true
		out[str(p.get("slug", ""))] = best
	return out


## The stations wardens are at in `key`'s rooms of kind `t` (interior_manager.coop_room:
## "corn" behind the stand, "service" in the pub, the bistro, the Jednota): this machine's
## and the others'.
static func wardens_at(tree: SceneTree, key: String, t: String) -> Array:
	var out: Array = []
	var m: Node = tree.current_scene if tree != null else null
	var im = m.get("_interior_manager") if m != null else null
	if im != null and is_instance_valid(im) and im.has_method("coop_room"):
		var mine: Dictionary = im.coop_room()
		if str(mine.get("k", "")) == key and str(mine.get("t", "")) == t and str(mine.get("w", "")) != "":
			out.append(str(mine["w"]))
	if Coop.is_active():
		for pid in Coop.others():
			var room: Dictionary = Coop.state_of(pid).get("room", {})
			if str(room.get("k", "")) == key and str(room.get("t", "")) == t and str(room.get("w", "")) != "":
				out.append(str(room["w"]))
	return out


## station -> the name of the hand working it now (the stations' tabs say so).
static func names_at(crew: Array, places_now: Dictionary) -> Dictionary:
	var out := {}
	for p in crew:
		var at := str(places_now.get(str(p.get("slug", "")), ""))
		if at != "":
			out[at] = short_name(str(p.get("name", "")))
	return out


## The word a tab has room for: the first name, or the surname of a Mrs, the Novak of the
## Novak boy.
static func short_name(full: String) -> String:
	for w in full.split(" ", false):
		if not (w in ["Mrs", "Mr", "the", "The"]):
			return w
	return full
