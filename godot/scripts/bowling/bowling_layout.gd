extends RefCounted

## The bowling alley's hall (scripts/bowling/bowling_interior.gd builds it with this): the
## same concrete box as outside (building_models._bowling, 10.4 x 17.6 m: the room inside
## its walls), in room space with the front wall at +Z and the lanes running to -Z.
##
##   the front    in by the door on the left (where it is painted outside); the shoe
##                and lane counter along the left wall, the snack bar on the right, a few
##                tables between, the benches behind the approaches
##   the lanes    four, in two pairs with the ball return between them; each lane is the
##                real thing across (1.05 m of boards, the gutters) and shortened along
##                (LANE_ROOM of the real 18.3 m; the pin deck behind the head pin is to
##                scale): BowlingRules' lane metres go through lane_point()
##   the back     the masking panel over the pin decks, painted by the camp; behind it
##                the pit and the walkway where the pins are set up by hand
##   the cellar   under it all (cellar(): its own room, far off in the hall's world so
##                neither's lights reach the other): damp concrete, one bulb, oil drums, and on its
##                back wall the pinsetting machine's gear train from the books (the
##                Stavomat's iron or the Brnoswick's enamel), worked by cellar_station.gd
##
## Pure layout: sizes, spots, the static build. Nothing in it changes while you play.

const RULES = preload("res://core/systems/bowling_rules.gd")
const KIT = preload("res://scripts/interior_kit.gd")

const W := 10.0
const L := 17.2
const H := 4.4
const FRONT_Z := L * 0.5
const BACK_Z := -L * 0.5
## The foul line and the head pin in the room; the lane between them is LANE_ROOM long.
const FOUL_Z := 1.0
const HEAD_Z := -5.6
const LANE_ROOM := FOUL_Z - HEAD_Z
const APPROACH_Z := 3.4
const MASK_Z := -6.05
const PIT_Z := -7.0
## The pin deck's end (the room's z) and how deep the pit behind it runs.
const DECK_END := HEAD_Z - 0.95
const PIT_DEPTH := 0.62
## The lanes' middles across the hall: two pairs, the ball return between each pair.
const LANES := [-2.62, -0.8, 0.8, 2.62]
const RETURNS := [-1.71, 1.71]
const LANE_W := RULES.LANE_W
const GUTTER_W := RULES.GUTTER_W
## The door (as painted outside at -0.271 of the 10.4 m front) and where you stand
## coming in.
const DOOR_X := -2.82
const ENTRY := Vector3(-2.82, 1.62, 7.7)
## Camera spots: [position, rotation (degrees)].
const SPOTS := {
	"hall": [Vector3(-2.6, 1.62, 7.6), Vector3(-6.0, -8.0, 0.0)],
	"desk": [Vector3(-4.35, 1.62, 6.3), Vector3(-10.0, -90.0, 0.0)],
	"bufet": [Vector3(4.35, 1.62, 7.0), Vector3(-10.0, 90.0, 0.0)],
	"pit": [Vector3(0.0, 1.35, -7.75), Vector3(-12.0, 180.0, 0.0)],
}
## The benches behind each lane, where the party waits its turn (room, the floor).
const BENCH_Z := 4.05
## The tables of the front (room, the floor): where people wait for a lane or eat.
const TABLES := [Vector3(-0.4, 0, 6.3), Vector3(1.4, 0, 6.6), Vector3(0.5, 0, 5.2)]
## The queue at the counter (room, the floor), the first at it: [position, facing].
const DESK_QUEUE := [[Vector3(-2.85, 0, 6.35), Vector3(-1, 0, 0)], [Vector3(-2.6, 0, 7.05), Vector3(-1, 0, -0.3)],
	[Vector3(-2.2, 0, 7.55), Vector3(-0.6, 0, -1)], [Vector3(-1.6, 0, 7.85), Vector3(-0.4, 0, -1)],
	[Vector3(-1.0, 0, 8.05), Vector3(-0.2, 0, -1)], [Vector3(-0.4, 0, 8.1), Vector3(-0.1, 0, -1)]]

## The cellar: where its room is in the hall's own world (far over it: neither's lights reach
## the other, and the retro shader cuts away whatever is under the ground for a camera under
## it, the lake mirror's way), its size.
const CELLAR_AT := Vector3(0.0, 60.0, 0.0)
const CELLAR_SIZE := Vector3(7.0, 2.5, 5.0)

## The stations (scripts/business/station3d.gd, hosted by bowling_interior.gd): id -> {room,
## label, tab_label, icon}, in the order of the work: the counter (shoes and lanes) where an
## order starts, then the pit behind each pair of lanes. You come in at the counter the
## first time.
const ENTRY_STATION := "desk"
const STATIONS := {
	"desk": {"room": "hall", "label": "the shoe counter", "tab_label": "COUNTER", "icon": "res://assets/textury/bowling/shoes_red.png"},
	"bufet": {"room": "hall", "label": "the snack bar", "tab_label": "SNACK BAR", "icon": "res://assets/textury/bowling/hotdog.png", "lanes": [0, 1, 2, 3]},
	"pit_a": {"room": "hall", "label": "the pit of lanes 1 and 2", "tab_label": "PIT 1-2", "icon": "res://assets/textury/bowling/pin.png", "lanes": [0, 1]},
	"pit_b": {"room": "hall", "label": "the pit of lanes 3 and 4", "tab_label": "PIT 3-4", "icon": "res://assets/textury/bowling/pin.png", "lanes": [2, 3]},
	"cellar": {"room": "cellar", "label": "the pinsetter in the cellar", "tab_label": "CELLAR", "icon": "res://assets/textury/bowling/gear_small.png"},
}
## Where each is worked: the counter's top from behind it (the hall on the far side), the
## two pin decks of a pair and the pit behind them from the walkway (looking up the lanes).
const SURFACES := {
	"desk": {"at": Vector3(-3.55, 1.102, 6.2), "size": Vector2(2.6, 0.72), "yaw": -90.0, "flat": true, "cam_back": 0.95, "cam_up": 1.3, "cam_aim": 0.05, "tex": ""},
	"bufet": {"at": Vector3(3.6, 1.102, 6.9), "size": Vector2(2.4, 0.72), "yaw": 90.0, "flat": true, "cam_back": 0.9, "cam_up": 1.2, "cam_aim": 0.05, "tex": ""},
	"pit_a": {"at": Vector3(-1.71, 0.062, -6.3), "size": Vector2(3.4, 1.7), "yaw": 180.0, "flat": true, "cam_back": 1.45, "cam_up": 1.55, "cam_aim": 0.0, "tex": ""},
	"pit_b": {"at": Vector3(1.71, 0.062, -6.3), "size": Vector2(3.4, 1.7), "yaw": 180.0, "flat": true, "cam_back": 1.45, "cam_up": 1.55, "cam_aim": 0.0, "tex": ""},
	# In the cellar's own space (its floor's middle): the machine's front on its back wall.
	"cellar": {"at": Vector3(0.0, 1.12, -CELLAR_SIZE.z * 0.5 + 0.47), "size": Vector2(3.2, 1.8), "yaw": 0.0, "flat": false, "cam_back": 2.05, "tex": ""},
}


## A point on lane `i` from BowlingRules' lane metres (x across from its middle, z from
## the head pin, the foul line at +LANE_LEN): the lane's boards squeezed to LANE_ROOM, the
## deck behind the head pin to scale. y above the boards.
static func lane_point(i: int, x: float, z: float, y: float = 0.0) -> Vector3:
	var rz := HEAD_Z + (z * LANE_ROOM / RULES.LANE_LEN if z >= 0.0 else z)
	return Vector3(float(LANES[i]) + x, y, rz)


## The bench spot of party member `k` (0-3) behind lane `i`.
static func bench_spot(i: int, k: int) -> Vector3:
	return Vector3(float(LANES[i]) + (float(k) - 1.5) * 0.36, 0.0, BENCH_Z + 0.25 + (0.3 if k % 2 == 1 else 0.0))


## The top of the little table behind lane `i`'s bench, on the hall's side (its middle).
static func snack_table(i: int) -> Vector3:
	return Vector3(float(LANES[i]) + 0.55, 0.58, BENCH_Z + 0.95)


## The spot to watch lane `i` from, behind its bowler.
static func lane_spot(i: int) -> Array:
	return [Vector3(float(LANES[i]), 1.62, 3.9), Vector3(-9.0, 0.0, 0.0)]


## Builds the hall into `root`. Returns {tubes: [StandardMaterial3D], glass: StandardMaterial3D,
## clicks: {name: StaticBody3D}} for the room to light and to click.
static func build(root: Node3D) -> Dictionary:
	var out := {"tubes": [], "clicks": {}, "lights": []}
	var wall := _tex_or("bowl_wall", "concrete")
	var room := KIT.room(root, Vector3(W, H, L), _tex_or("bowl_carpet", "lino_floor"), wall, "ceiling_board", 1.6, 1.4)
	# The back wall, in the dark behind the masking panel, darker.
	(room["back"] as MeshInstance3D).material_override = KIT.surface(wall, 1.6, Color(0.55, 0.55, 0.55))
	# The camp's stripes round the walls inside too: red, white, sky blue at hip height,
	# painted on (one band of the three, its picture stretched along the wall).
	if ResourceLoader.exists(KIT.TEX + "bowl_stripes.png"):
		_band(root, "bowl_stripes", W - 0.02, Vector3(0, 1.02, FRONT_Z - 0.022), 180.0)
		for side: float in [-1.0, 1.0]:
			_band(root, "bowl_stripes", FRONT_Z - MASK_Z, Vector3(side * (W * 0.5 - 0.022), 1.02, (FRONT_Z + MASK_Z) * 0.5), -90.0 * side)
	else:
		var stripes := [[Color(0.66, 0.16, 0.13), 1.18], [Color(0.86, 0.84, 0.78), 1.02], [Color(0.3, 0.46, 0.7), 0.86]]
		for s in stripes:
			var m := _flat(s[0])
			var y: float = s[1]
			KIT.slab(root, Vector3(W - 0.02, 0.16, 0.02), Vector3(0, y, FRONT_Z - 0.012), m, "Stripe")
			for side: float in [-1.0, 1.0]:
				KIT.slab(root, Vector3(0.02, 0.16, FRONT_Z - MASK_Z), Vector3(side * (W * 0.5 - 0.012), y, (FRONT_Z + MASK_Z) * 0.5), m, "Stripe")
	_lanes(root)
	_front(root, out)
	_back(root, out)
	_lights(root, out)
	# The glass-block strip high on both long walls: the daylight comes in there.
	var glass := StandardMaterial3D.new()
	var gt := KIT.TEX + "glass_blocks.png"
	if ResourceLoader.exists(gt):
		glass.albedo_texture = load(gt)
		glass.uv1_scale = Vector3(8.0, 1.0, 1.0)
	glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glass.emission_enabled = true
	glass.emission = Color(0.0, 0.0, 0.0)
	if ResourceLoader.exists(gt):
		glass.emission_texture = load(gt)
	glass.emission_energy_multiplier = 0.6
	for side: float in [-1.0, 1.0]:
		var q := KIT.slab(root, Vector3(0.03, 0.42, 11.0), Vector3(side * (W * 0.5 - 0.02), H - 0.45, 1.6), glass, "GlassBlocks")
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out["glass"] = glass
	return out


static func _lanes(root: Node3D) -> void:
	var lane_tex := _tex_or("bowl_lane", "parquet")
	var boards := KIT.surface(lane_tex, 1.1)
	var gutter := KIT.surface("steel_brushed", 0.6, Color(0.7, 0.7, 0.72))
	var capping := KIT.surface("veneer_dark", 0.8)
	var len_z := FOUL_Z - (HEAD_Z - 0.95)
	var mid_z := (FOUL_Z + HEAD_Z - 0.95) * 0.5
	for i in LANES.size():
		var x: float = LANES[i]
		KIT.slab(root, Vector3(LANE_W, 0.06, len_z), Vector3(x, 0.03, mid_z), boards, "Lane")
		# The aiming arrows and the dots, darker boards let in.
		for k in 7:
			var ax := x + (float(k) - 3.0) * 0.13
			var az := FOUL_Z - 1.6 - absf(float(k) - 3.0) * 0.12
			KIT.slab(root, Vector3(0.03, 0.005, 0.12), Vector3(ax, 0.062, az), KIT.surface("veneer_dark", 0.3, Color(0.8, 0.62, 0.5)), "Arrow")
		for side: float in [-1.0, 1.0]:
			KIT.slab(root, Vector3(GUTTER_W, 0.02, len_z), Vector3(x + side * (LANE_W + GUTTER_W) * 0.5, 0.0, mid_z), gutter, "Gutter")
		# The approach, the foul line across it.
		KIT.slab(root, Vector3(LANE_W + GUTTER_W * 2.0, 0.06, APPROACH_Z - FOUL_Z), Vector3(x, 0.03, (APPROACH_Z + FOUL_Z) * 0.5), KIT.surface(lane_tex, 1.1, Color(1.08, 1.05, 1.0)), "Approach")
		KIT.slab(root, Vector3(LANE_W + GUTTER_W * 2.0, 0.006, 0.03), Vector3(x, 0.063, FOUL_Z), KIT.surface("veneer_dark", 0.3, Color(0.35, 0.32, 0.3)), "FoulLine")
		# The pin deck behind the head pin, the pit behind that: its dark floor between
		# the kickbacks, the black cushion hanging at its back the ball stops against.
		KIT.slab(root, Vector3(LANE_W + GUTTER_W * 2.0, 0.06, 1.0), Vector3(x, 0.03, HEAD_Z - 0.45), KIT.surface(lane_tex, 0.9, Color(0.86, 0.8, 0.7)), "Deck")
		KIT.slab(root, Vector3(LANE_W + GUTTER_W * 2.0, 0.006, PIT_DEPTH), Vector3(x, 0.003, DECK_END - PIT_DEPTH * 0.5), KIT.surface("planks_dark", 0.5, Color(0.55, 0.52, 0.48)), "Pit")
		KIT.slab(root, Vector3(LANE_W + GUTTER_W * 2.0, 0.26, 0.05), Vector3(x, 0.13, DECK_END - PIT_DEPTH - 0.03), KIT.surface("veneer_dark", 0.6, Color(0.3, 0.28, 0.3)), "Cushion")
		for side: float in [-1.0, 1.0]:
			KIT.slab(root, Vector3(0.04, 0.42, DECK_END - HEAD_Z + 0.15 + PIT_DEPTH), Vector3(x + side * (LANE_W * 0.5 + GUTTER_W + 0.02), 0.21, (HEAD_Z + 0.15 + DECK_END - PIT_DEPTH) * 0.5), capping, "Kickback")
	# The capping between the lanes and at the sides, the ball returns' hoods.
	var edges := [-3.38, -0.0, 3.38]
	for ex in edges:
		KIT.slab(root, Vector3(0.12 if ex != 0.0 else 0.06, 0.1, len_z + APPROACH_Z - FOUL_Z), Vector3(ex, 0.05, (APPROACH_Z + HEAD_Z - 0.95) * 0.5), capping, "Capping")
	for rx in RETURNS:
		KIT.slab(root, Vector3(0.24, 0.12, len_z), Vector3(rx, 0.06, mid_z), capping, "ReturnTrack")
		KIT.slab(root, Vector3(0.34, 0.55, 1.1), Vector3(rx, 0.275, FOUL_Z + 0.9), capping, "ReturnHood")
		KIT.slab(root, Vector3(0.3, 0.06, 0.9), Vector3(rx, 0.58, FOUL_Z + 0.9), KIT.surface("steel_brushed", 0.5), "BallRack")


static func _front(root: Node3D, out: Dictionary) -> void:
	# The shoe and lane counter along the left wall, the shoe shelf behind it.
	var formica := KIT.surface("formica", 0.8)
	var veneer := KIT.surface("veneer_dark", 0.8)
	KIT.slab(root, Vector3(0.6, 1.05, 2.6), Vector3(-3.55, 0.525, 6.2), veneer, "DeskFront")
	KIT.slab(root, Vector3(0.75, 0.05, 2.7), Vector3(-3.55, 1.075, 6.2), formica, "DeskTop")
	KIT.slab(root, Vector3(0.45, 2.2, 3.2), Vector3(-4.75, 1.1, 6.2), veneer, "ShoeShelf")
	if ResourceLoader.exists(KIT.TEX + "bowl_shoeshelf.png"):
		KIT.picture(root, "bowl_shoeshelf", Vector2(3.1, 1.9), Vector3(-4.52, 1.15, 6.2), 90.0, "ShoeShelfFront")
	else:
		for row in 5:
			for col in 7:
				var c := Color(0.36, 0.22, 0.14) if (row + col) % 3 else Color(0.5, 0.12, 0.1)
				KIT.slab(root, Vector3(0.05, 0.14, 0.3), Vector3(-4.51, 0.45 + row * 0.38, 4.85 + col * 0.45), _flat(c), "Shoes")
	out["clicks"]["desk"] = _click_box(root, "desk", Vector3(1.0, 1.2, 2.8), Vector3(-3.55, 0.8, 6.2))
	# The snack bar on the right: its counter, the steamer and the jars on it, the fridge.
	KIT.slab(root, Vector3(0.6, 1.05, 2.4), Vector3(3.6, 0.525, 6.9), KIT.surface("counter_steel", 0.8), "BufetFront")
	KIT.slab(root, Vector3(0.75, 0.05, 2.5), Vector3(3.6, 1.075, 6.9), formica, "BufetTop")
	KIT.prop(root, "fridge_tall", Vector3(4.6, 0.0, 8.2), -90.0)
	KIT.prop(root, "bottle_shelf", Vector3(4.85, 0.0, 6.9), -90.0)
	out["clicks"]["bufet"] = _click_box(root, "bufet", Vector3(1.0, 1.2, 2.6), Vector3(3.6, 0.8, 6.9))
	# Tables to wait or eat at, and the benches behind the approaches.
	for t in TABLES:
		KIT.prop(root, "pub_table", t, 0.0)
		for k in 2:
			KIT.prop(root, "chair_wood", t + Vector3(-0.6 if k == 0 else 0.6, 0, 0), 90.0 if k == 0 else -90.0)
	for i in LANES.size():
		KIT.prop(root, "bench_slatted", Vector3(float(LANES[i]), 0.0, BENCH_Z + 0.3), 180.0)
		# A little table behind each bench for what the snack bar brings (lane.gd).
		var t := snack_table(i)
		KIT.slab(root, Vector3(0.42, 0.03, 0.42), t - Vector3(0, 0.015, 0), veneer, "SnackTable")
		KIT.slab(root, Vector3(0.05, t.y - 0.03, 0.05), Vector3(t.x, (t.y - 0.03) * 0.5, t.z), KIT.surface("steel_brushed", 0.4), "SnackTableLeg")
		out["clicks"]["lane%d" % i] = _click_box(root, "lane%d" % i, Vector3(LANE_W, 0.4, 2.0), Vector3(float(LANES[i]), 0.2, FOUL_Z + 1.0))


static func _back(root: Node3D, out: Dictionary) -> void:
	# The masking panel over the pin decks: the camp's own paint job, the stripes again
	# (a picture there later), the dark under it where the pins stand.
	var panel := KIT.surface("concrete", 1.2, Color(0.82, 0.8, 0.74))
	KIT.slab(root, Vector3(7.0, 2.4, 0.08), Vector3(0, 2.2, MASK_Z), panel, "Masking")
	if ResourceLoader.exists(KIT.TEX + "bowl_masking.png"):
		KIT.picture(root, "bowl_masking", Vector2(6.9, 2.3), Vector3(0, 2.2, MASK_Z + 0.045), 0.0, "MaskMural")
	else:
		var cols := [Color(0.66, 0.16, 0.13), Color(0.86, 0.84, 0.78), Color(0.3, 0.46, 0.7)]
		for k in 9:
			KIT.slab(root, Vector3(0.78, 1.5, 0.01), Vector3(-3.1 + k * 0.78, 2.05, MASK_Z + 0.045), _flat(cols[k % 3]), "MaskStripe")
	# Behind it: the walkway the pinsetter works from, a step up, a door in from the side.
	var walk_from := DECK_END - PIT_DEPTH - 0.06
	KIT.slab(root, Vector3(W, 0.3, walk_from - BACK_Z), Vector3(0, 0.15, (walk_from + BACK_Z) * 0.5), KIT.surface("planks_dark", 0.6), "Walkway")
	KIT.slab(root, Vector3(1.6, 2.2, 0.06), Vector3(-4.2, 1.1, MASK_Z), KIT.surface("door_wood", 1.0), "PitDoor")
	# The pinsetter's beacon on the ceiling over the lanes (seen from the whole hall, over the
	# boards): red, a red glow round it, while it stands jammed.
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.25, 0.04, 0.03)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.12, 0.06)
	lamp.emission_energy_multiplier = 0.0
	var lm := KIT.slab(root, Vector3(0.2, 0.16, 0.2), Vector3(0.0, H - 0.42, -1.0), lamp, "JamBeacon")
	lm.set_meta("retro_skip", true)
	KIT.slab(root, Vector3(0.03, 0.34, 0.03), Vector3(0.0, H - 0.17, -1.0), KIT.surface("steel_brushed", 0.3), "BeaconRod")
	out["jam_lamp"] = lamp
	var glow := OmniLight3D.new()
	glow.name = "JamGlow"
	glow.light_color = Color(1.0, 0.15, 0.08)
	glow.omni_range = 5.5
	glow.light_energy = 0.0
	glow.position = Vector3(0.0, H - 0.6, -1.0)
	root.add_child(glow)
	out["jam_glow"] = glow
	out["clicks"]["pit"] = _click_box(root, "pit", Vector3(1.4, 2.0, 0.4), Vector3(-4.2, 1.0, MASK_Z + 0.2))
	# The pin decks of each pair: a click goes round into the pit behind them.
	out["clicks"]["pit_a"] = _click_box(root, "pit_a", Vector3(3.3, 0.7, 1.3), Vector3(-1.71, 0.35, HEAD_Z - 0.45))
	out["clicks"]["pit_b"] = _click_box(root, "pit_b", Vector3(3.3, 0.7, 1.3), Vector3(1.71, 0.35, HEAD_Z - 0.45))


static func _lights(root: Node3D, out: Dictionary) -> void:
	# Fluorescent tubes in rows over the front and down the lanes.
	var tube := StandardMaterial3D.new()
	tube.albedo_color = Color(0.92, 0.95, 0.9)
	tube.emission_enabled = true
	tube.emission = Color(0.9, 0.96, 1.0)
	tube.emission_energy_multiplier = 1.6
	out["tubes"].append(tube)
	for z in [7.0, 4.6, 1.6, -1.6, -4.4]:
		for x in [-3.0, 0.0, 3.0]:
			KIT.slab(root, Vector3(1.2, 0.05, 0.08), Vector3(x, H - 0.06, z), tube, "Tube")
	for z in [6.0, 2.0, -3.0]:
		var l := OmniLight3D.new()
		l.name = "TubeLight"
		l.light_color = Color(0.92, 0.96, 1.0)
		l.omni_range = 9.0
		l.light_energy = 0.9
		l.position = Vector3(0.0, H - 0.4, z)
		root.add_child(l)
		out["lights"].append(l)
	# The pin decks lit from under the masking panel.
	var deck := SpotLight3D.new()
	deck.name = "DeckLight"
	deck.light_color = Color(1.0, 0.95, 0.85)
	deck.spot_range = 4.0
	deck.spot_angle = 60.0
	deck.light_energy = 1.4
	deck.position = Vector3(0.0, 1.2, MASK_Z + 0.3)
	deck.rotation_degrees = Vector3(-60.0, 180.0, 0.0)
	root.add_child(deck)
	out["lights"].append(deck)


static func _click_box(root: Node3D, what: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Click_" + what
	b.set_meta("bowling_click", what)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = pos
	root.add_child(b)
	return b


## Builds the cellar into `root` (placed at CELLAR_AT): the room, the bulb, the drums and
## the junk, the machine's frame on the back wall (the gears on it are the station's).
## Returns {bulb: OmniLight3D, bulb_mat: StandardMaterial3D, frame: MeshInstance3D}.
static func cellar(root: Node3D) -> Dictionary:
	var out := {}
	var s := CELLAR_SIZE
	var wall := _tex_or("bowl_cellar_wall", "concrete")
	KIT.room(root, s, _tex_or("bowl_cellar_floor", "concrete"), wall, _tex_or("bowl_cellar_wall", "concrete"), 1.6, 1.4)
	var back_z := -s.z * 0.5
	# The machine's frame against the back wall: the drive the chains run up from.
	var steel := KIT.surface(_tex_or("bowl_machine", "steel_brushed"), 0.9)
	out["frame"] = KIT.slab(root, Vector3(3.5, 2.05, 0.42), Vector3(0, 1.1, back_z + 0.23), steel, "MachineFrame")
	KIT.slab(root, Vector3(3.7, 0.12, 0.6), Vector3(0, 0.06, back_z + 0.32), steel, "MachineFoot")
	# Four chains up through the ceiling to the lanes over it, the main shaft along the top.
	var chain := KIT.surface("steel_brushed", 0.3, Color(0.35, 0.3, 0.27))
	for k in 4:
		KIT.slab(root, Vector3(0.05, s.y - 2.1, 0.03), Vector3(-1.2 + k * 0.8, 2.1 + (s.y - 2.1) * 0.5, back_z + 0.3), chain, "Chain")
	KIT.slab(root, Vector3(s.x - 0.4, 0.12, 0.12), Vector3(0, s.y - 0.25, back_z + 0.55), chain, "Shaft")
	# The wooden grating under the machine, the oil soaked into it; drums, crates of broken
	# pins, a bucket under the drip.
	KIT.prop(root, "duckboard", Vector3(0, 0.0, back_z + 1.2), 0.0, 1.6)
	KIT.prop(root, "oil_drum", Vector3(-2.9, 0.0, back_z + 0.6), 10.0)
	KIT.prop(root, "oil_drum", Vector3(-2.35, 0.0, back_z + 0.75), -25.0)
	KIT.prop(root, "beer_crates", Vector3(2.8, 0.0, back_z + 0.7), 85.0)
	KIT.prop(root, "slop_bucket", Vector3(1.75, 0.0, back_z + 0.95), 0.0)
	KIT.prop(root, "cardboard_boxes", Vector3(-2.8, 0.0, 1.5), 30.0)
	KIT.prop(root, "locker", Vector3(3.1, 0.0, 1.4), -90.0)
	# The stairs down from the hall in the front corner.
	var wood := KIT.surface("planks_dark", 0.6)
	for k in 8:
		KIT.slab(root, Vector3(0.9, 0.05, 0.28), Vector3(-2.9, 0.28 + k * 0.29, s.z * 0.5 - 0.3 - k * 0.24), wood, "Step")
	KIT.slab(root, Vector3(0.05, 2.5, 2.2), Vector3(-2.42, 1.2, s.z * 0.5 - 1.1), wood, "Stringer")
	# One bare bulb on its flex over the machine.
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.9, 0.7)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.82, 0.55)
	bm.emission_energy_multiplier = 1.4
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	bulb.mesh = sm
	bulb.material_override = bm
	bulb.set_meta("retro_skip", true)
	bulb.position = Vector3(0.3, s.y - 0.55, back_z + 1.35)
	root.add_child(bulb)
	KIT.slab(root, Vector3(0.01, 0.5, 0.01), bulb.position + Vector3(0, 0.3, 0), chain, "Flex")
	var light := OmniLight3D.new()
	light.name = "BulbLight"
	light.light_color = Color(1.0, 0.82, 0.58)
	light.omni_range = 6.5
	light.light_energy = 1.1
	light.shadow_enabled = false
	light.position = bulb.position
	root.add_child(light)
	out["bulb"] = light
	out["bulb_mat"] = bm
	# The red lamp on the frame and the hall's door down here: clicks.
	out["clicks"] = {"stairs": _click_box(root, "stairs", Vector3(1.0, 2.4, 2.2), Vector3(-2.9, 1.2, s.z * 0.5 - 1.1))}
	return out


## A camp texture of the alley's own if it is there yet, else the stand-in.
static func _tex_or(name: String, fallback: String) -> String:
	return name if ResourceLoader.exists(KIT.TEX + name + ".png") else fallback


## A painted band along a wall (`length` metres, 0.48 high, facing `yaw`): its picture once
## across its height, repeating along it every 1.7 m.
static func _band(root: Node3D, tex: String, length: float, pos: Vector3, yaw: float) -> MeshInstance3D:
	var q := KIT.picture(root, tex, Vector2(length, 0.48), pos, yaw, "Stripes")
	(q.material_override as StandardMaterial3D).uv1_scale = Vector3(maxf(1.0, round(length / 1.7)), 1.0, 1.0)
	return q


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m
