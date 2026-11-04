extends RefCounted

## Inside the chapel of the Virgin Mary in Liblice (town_room.gd's place "chapel"). Behind
## its small baroque front (town_lesna._chapel: 6 m across, 7 m deep) it is bigger inside
## than it is outside (the user, 4. 11.: "dustier, damp, bigger, musty, eerie", and bigger
## inside than out his choice): the long nave under its barrel vault, the choir loft over
## the door on its two posts with the stair up to it, seven rows of pews either side of
## the aisle, the triumphal arch and two steps up to the presbytery beyond it with the
## altar, St Prokop and the harmonium. The damp climbs the walls in brown tide lines and
## black mould, the whitewash flakes off, the vault leaks into a bucket in the aisle,
## cobwebs hang in the corners and off the chandelier, dust turns in the light from the
## oval windows, the air is a grey musty haze.
##
##   you walk     a click on something across the nave takes you there on foot
##                (room_walk.gd) and then it is done: the candles by the door, the altar
##                from the rail, the confessional under the loft, a pew to sit in;
##   the candles  up close (candle_closeup.gd): your match, or a coin and one of the
##                chapel's, struck on the box, brought to a wick: one more flame on the
##                stand (they stay lit while you are in Liblice; the other wardens' too,
##                and theirs for you: co-op);
##   the rope     the bell rings over the village;
##   Mrs Hruba    kneels in the second pew from four to six (town_people.gd has her
##                indoors then), and talks quietly;
##   the rest     looked at closer: the eye goes to it, a click lets it go.
## Now and then, the more the worse you are (the hidden sanity, coop_night.gd), never
## explained: somebody stands up in the loft while you are not looking there and is gone
## when you look again; St Prokop has turned his head; the figure under the dust sheet is
## somewhere else each time; something breathes behind the confessional's curtain; every
## flame on the stand out at once while your back was to it, without a sound; the harmonium
## up in the presbytery, three slow notes, when you are at the far end from it; a cold
## draught from the door, the flames and the light through the dust flickering together.
## Nobody narrates.
##
## The light follows the clock while you stand there (`_set_dusk`, `_follow_hour`): the
## sun's shafts sink and warm through the afternoon and go at dusk, the moon's come; the
## candles are lit from six on, never while you look (Mrs Hruba is gone when you turn
## round, and they burn). At night (the user, 4. 11.: open through the night, a night to
## it, just enough light to see by, candles burning) the door gives all the same:
## the moon in rays through the west windows down to the aisle's floor, dust turning in
## them, clouds going over it (behind rain hardly any), the day's damp haze gone grey-blue
## and lit round the windows and the candles (the user, 4. 11.: "the haze it has by day,
## godrays from the moon, dust, really top"), the altar's
## two candles lit, the eternal light red on its chain in the presbytery, grave lanterns on
## the step before the rail and under St Prokop, stubs burning down before the first pew,
## more flames on the stand than anybody left (somebody came in the evening); no pigeons,
## an owl up in the roof, the candles' small crackle (louder near them), a beam ticking,
## wax, a moth at the red glass; and the worse things come a little easier.

const K = preload("res://scripts/interior_kit.gd")
const WALK = preload("res://scripts/town/room_walk.gd")
const CANDLE_CLOSEUP = preload("res://scripts/town/candle_closeup.gd")
const GESTURE = preload("res://scripts/ui/gesture.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
## The building in the village (town_lesna._chapel): its oval windows outside along its
## sides, their height.
const WINDOWS_Z := [-0.9, 1.4]
const WINDOW_Y := 2.45
## The nave: x across, z from the triumphal arch (-) to the door (+); its barrel vault from
## the walls' top to its crown.
const W := 6.4
const D := 11.0
const WALL_H := 4.8
const CROWN := 6.6
## The arch's wall and its opening; the presbytery beyond it, its floor two steps up, its
## own lower vault (heights over its floor).
const ARCH_T := 0.5
const ARCH_W := 4.0
const PRES_W := 4.6
const PRES_D := 3.8
const STEP := 0.18
const PRES_Y := 0.36
const PRES_WALL := 3.9
const PRES_CROWN := 5.0
## The choir loft over the door: its front, the top of its floor, its two posts.
const LOFT_Z := 3.3
const LOFT_Y := 2.8
const POSTS_X := [-1.8, 1.8]
## The pews: seven rows (their seats' middle) either side of the aisle.
const ROWS := [-4.1, -3.05, -2.0, -0.95, 0.1, 1.15, 2.2]
const AISLE := 0.55
const PEW_L := 2.1
## The nave's oval windows (along z) and their middle's height.
const NAVE_WINDOWS_Z := [-3.5, -0.4, 2.5]
const NAVE_WINDOW_Y := 3.6
## How high the damp has climbed the walls.
const DAMP_H := 2.3
## The bucket in the aisle under the leak in the vault.
const BUCKET := Vector3(0.36, 0.0, 0.62)
## How long a cold draught lasts.
const DRAFT_SEC := 5.0
## The dusk and the dawn: from the day's light to the night's between these hours (the
## village's night, town_trip._night, begins at seven); the afternoon warming.
const DUSK_FROM := 18.4
const DUSK_TO := 19.2
const DAWN_FROM := 5.0
const DAWN_TO := 6.0
const LATE_FROM := 15.5
const LATE_TO := 16.5
## The candles burn from Mrs Hruba's going at six till the morning.
const LIT_FROM := 18.0
const LIT_TO := 6.5
const WARM := Color(1.0, 0.64, 0.3)
## The moon's light at night: steep through the west windows down to the aisle.
const MOON_DIR := Vector3(1.0, -1.25, -0.12)
## The wicks in the rack's picture (candle_stand.png), as shares of it, top tier first.
const RACK_CUPS := [[0.214, 0.032], [0.361, 0.032], [0.508, 0.032], [0.653, 0.032], [0.798, 0.032],
	[0.204, 0.166], [0.355, 0.166], [0.506, 0.166], [0.653, 0.166], [0.800, 0.166],
	[0.190, 0.311], [0.346, 0.311], [0.505, 0.311], [0.658, 0.311], [0.812, 0.311]]
## The cups the flames of others go to, spread over the stand.
const LIGHT_ORDER := [7, 2, 11, 5, 13, 0, 9, 3, 14, 6, 1, 12, 8, 4, 10]
## Where you stand when you come in: under the loft, inside the door.
const STAND := Vector3(0.0, 1.6, 4.2)
## The figure under the dust sheet stands somewhere else each time: [where, yaw].
const SHEET_SPOTS := [
	[Vector3(-1.8, PRES_Y, -9.05), 25.0],
	[Vector3(-2.9, 0.0, -4.85), 60.0],
	[Vector3(-2.05, 0.0, 3.55), 100.0],
	[Vector3(0.95, LOFT_Y, 3.75), 180.0],
	[Vector3(2.9, 0.0, -1.45), -90.0],
]
const HRUBA_LINES := [
	"Sit down if you want. He does not mind who.",
	"I light one for Karel. And one for Vera, though she would not thank me for it.",
	"They used to ring it for the dead. Now they ring it at noon and at six, and nobody is dead.",
	"Your camp had a priest come up once. In seventy-one. He did not stay the night either.",
]
const WAYS := [["door", "nave"], ["nave", "pews"], ["pews", "seat_w"], ["pews", "seat_e"], ["pews", "front"],
	["front", "rail"], ["rail", "altar"], ["door", "confess"], ["door", "candles"]]

var room
var parts: Dictionary = {}
var flames: Array = []
var cups: Array = []
var _t := 0.0
var _line := 0
var _looking := ""
var _look_back := {}
var _rope: MeshInstance3D
var _rope_y := 0.9
var _rope_t := 0.0
var _hruba: MeshInstance3D
var _walker
var _sitting := false
var _rng := RandomNumberGenerator.new()
var _sanity := 100.0
var _players: Array = []
var _amb: AudioStreamPlayer
var _fx: AudioStreamPlayer
var _drip_snd: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _rain_snd: AudioStreamPlayer
## The leak: the next drop's countdown, the drop falling (its node, its time down).
var _drip_t := 1.0
var _drop: MeshInstance3D
var _drop_t := -1.0
var _rain := false
## The one in the loft: shown or not, seen how long, unseen how long, times this visit.
var _watcher: Sprite3D
var _watch_on := false
var _watch_seen := 0.0
var _watch_unseen := 0.0
var _watch_n := 0
var _watch_sink := -1.0
var _loft_unseen := 0.0
var _watch_roll := 3.0
## St Prokop turned: the statue, unseen how long, turned now, seen turned how long.
var _saint: MeshInstance3D
var _saint_tex: Array = []
var _saint_unseen := 0.0
var _saint_turned := false
var _saint_seen := 0.0
var _saint_done := false
## The figure under the sheet, which spot, unseen how long.
var _sheet: MeshInstance3D
var _sheet_at := 0
var _sheet_unseen := 0.0
var _pigeons_t := 30.0
var _breath_t := -1.0
var _shafts: Array = []
var _flame_tex: Array = []
var _old_flames := false
var _dust: CPUParticles3D
## The candles up close (candle_closeup.gd), made with the room; a coin paid for a match
## not struck yet; your own candle standing in a cup, not lit yet; those lit.
var _candle_cu
var paid_match := false
var set_cup := -1
var own_cups: Array = []
## The flames all out at once: the stand unseen how long, the next roll, done this visit;
## the threads of smoke left over the cups ({node, t}).
var _stand_unseen := 0.0
var _out_roll := 6.0
var _out_done := false
var _smokes: Array = []
## The harmonium by itself: the next roll, how many times this visit.
var _organ: AudioStreamPlayer
var _organ_roll := 9.0
var _organ_n := 0
## The draught: how far through it (-1 none), the next roll, how long till another may come.
var _draft_t := -1.0
var _draft_roll := 7.0
var _draft_wait := 0.0
## The hour's light now: 0 day .. 1 night, 0 morning .. 1 late afternoon; the windows it
## goes through ({mat, light, west}); when to ask the clock again.
var _k := 0.0
var _late := 0.0
var _wins: Array = []
var _hour_t := 0.5
## The lights that are not on the stand, each what flickers of it ({kind, phase, base,
## light, halo, col, flame, mat, glow}); where the altar's and the stubs' wicks are, lit or
## not yet; the evening's flames on the stand seen to.
var _night_lights: Array = []
var _altar_tips: Array = []
var _altar_mid := Vector3.ZERO
var _altar_lit := false
var _stub_tips: Array = []
var _stubs_lit := false
var _stand_done := false
## The candles' crackle, the next of the night's small sounds.
var _candle_amb: AudioStreamPlayer
var _night_t := 20.0
static var _halo_tex: ImageTexture
static var _soft_tex: ImageTexture
## The moon: its patches on the floor ({light, mat, base}), the dust in its rays, how
## bright it is through the clouds now; the glow of the stand's flames in the haze.
var _moon_pools: Array = []
var _moon_dust: Array = []
var _moon := 1.0
var _stand_glow: MeshInstance3D
static var _moon_tex: ImageTexture


func _init(p_room) -> void:
	room = p_room


func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


func _size(tex: String, height: float) -> Vector2:
	var path := CAMP + tex + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		return Vector2(height * float(t.get_width()) / float(t.get_height()), height)
	return Vector2(height, height)


## The hidden sanity of this machine's warden (coop_night.gd keeps it, 0..100).
func _read_sanity() -> float:
	var trip = room.get_parent()
	var main = trip._main() if trip != null and trip.has_method("_main") else null
	var night = main.get("_coop_night") if main != null else null
	if night == null or not is_instance_valid(night):
		return 100.0
	var s = night.get("sanity")
	if not (s is Dictionary):
		return 100.0
	return float((s as Dictionary).get("own" if Coop.is_client() else "host", 100.0))


## 0 calm .. 1 at the end of the tether.
func _low() -> float:
	# At night the chapel is worse for anybody.
	return clampf((100.0 - _sanity) / 100.0 + 0.15 * _k, 0.0, 1.0)


## 0 day .. 1 night at this hour.
static func night_k(hour: float) -> float:
	if hour >= 12.0:
		return clampf((hour - DUSK_FROM) / (DUSK_TO - DUSK_FROM), 0.0, 1.0)
	return clampf((DAWN_TO - hour) / (DAWN_TO - DAWN_FROM), 0.0, 1.0)


## 0 till the afternoon .. 1 the sun low.
static func late_k(hour: float) -> float:
	if hour < 12.0:
		return 0.0
	return clampf((hour - LATE_FROM) / (LATE_TO - LATE_FROM), 0.0, 1.0)


static func lit_time(hour: float) -> bool:
	return hour >= LIT_FROM or hour < LIT_TO


## The vault's height over the nave at `x` (its walls' top to the crown, a flat arch).
static func vault_y(x: float) -> float:
	var k := clampf(absf(x) / (W * 0.5), 0.0, 1.0)
	return WALL_H + sqrt(maxf(0.0, 1.0 - k * k)) * (CROWN - WALL_H)


# ── building ─────────────────────────────────────────────────────────────────

func build(hour: float, candles: int) -> void:
	_rng.randomize()
	_sanity = _read_sanity()
	_k = night_k(hour)
	_late = late_k(hour)
	var root: Node3D = room._root
	_nave(root)
	_presbytery(root)
	_loft(root)
	_pews(root)
	_windows(root, hour)
	_by_the_door(root)
	_on_the_walls(root)
	_decay(root)
	_cobwebs(root)
	_leak(root)
	_confessional(root)
	_sheet_figure(root)
	_make_watcher(root)
	_air(root, hour)
	_light(hour, candles)
	_lamps_and_candles(root)
	_set_dusk(_k, _late)
	if lit_time(hour):
		_light_altar(root)
		_light_stubs(root)
	if hour >= 16.0 and hour < 18.0:
		_mrs_hruba()
	_walker = WALK.new(room, _spots(), WAYS, "door", SFX + "rooms/steps_wood.mp3", -13.0)
	_walker.put("door")
	room._look.yaw_limit_deg = 160.0
	room._look.pitch_up_deg = 52.0
	room._look.pitch_down_deg = 34.0
	room._hot_box("door", Vector3(0, 1.3, D * 0.5 - 0.05), Vector3(1.6, 2.6, 0.12), [])
	_sounds()
	_make_closeup()
	# Somebody let go of the rope just before you came in.
	if _rope != null and _rng.randf() < 0.1 + 0.25 * _low():
		_rope_t = 1.6


## Where you can stand and how you look there.
static func _spots() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	return {
		"door": {"at": STAND, "rot": r.call(-3.0, 0.0)},
		"nave": {"at": Vector3(-0.12, 1.6, 0.05), "rot": r.call(-3.0, 0.0)},
		"pews": {"at": Vector3(-0.1, 1.6, float(ROWS[3]) + 0.4), "rot": r.call(-4.0, 0.0)},
		"seat_w": {"at": Vector3(-1.45, 1.13, float(ROWS[3]) + 0.05), "rot": r.call(-3.0, 0.0)},
		"seat_e": {"at": Vector3(1.45, 1.13, float(ROWS[3]) + 0.05), "rot": r.call(-3.0, 0.0)},
		"front": {"at": Vector3(0.0, 1.6, -4.62), "rot": r.call(-1.0, 0.0)},
		"rail": {"at": Vector3(0.0, 1.6 + STEP, -5.2), "rot": r.call(2.0, 0.0)},
		"altar": {"at": Vector3(0.0, 1.6 + PRES_Y, -7.6), "rot": r.call(-4.0, 0.0)},
		"confess": {"at": Vector3(-0.55, 1.6, 4.15), "rot": r.call(-8.0, 90.0)},
		"candles": {"at": Vector3(1.55, 1.6, 4.02), "rot": r.call(-16.0, -162.0)},
	}


## A camp texture on a quad facing `facing`, its material its own (to scale its repeat).
func _quad(tex: String, size: Vector2, pos: Vector3, facing: Vector3, name := "Face") -> MeshInstance3D:
	var mi: MeshInstance3D = K.picture(room._root, tex, size, pos, rad_to_deg(atan2(facing.x, facing.z)), name)
	mi.material_override = (mi.material_override as StandardMaterial3D).duplicate()
	return mi


## A keyed picture flat on a surface: `normal` out of it into the room, `size` metres,
## its middle at `pos`, turned `spin` about its normal.
func _decal(tex: String, size: Vector2, pos: Vector3, normal: Vector3, spin := 0.0, tint := Color(1, 1, 1)) -> MeshInstance3D:
	if not _exists(tex):
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Decay"
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := K._base(tint)
	m.albedo_texture = load(CAMP + tex + ".png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	mi.material_override = m
	var z := normal.normalized()
	var up := Vector3.UP if absf(z.y) < 0.9 else Vector3(0, 0, -1)
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	mi.transform = Transform3D(Basis(x, y, z).rotated(z, spin), pos + z * 0.006)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room._root.add_child(mi)
	return mi


## The damp band up a wall: its picture repeated along `length`, `DAMP_H` high.
func _damp(length: float, mid: Vector3, facing: Vector3, y0 := 0.0) -> void:
	var tex := "chapel_damp_wall2" if _exists("chapel_damp_wall2") else "chapel_damp_wall"
	if not _exists(tex):
		return
	var q := _quad(tex, Vector2(length, DAMP_H), Vector3(mid.x, y0 + DAMP_H * 0.5, mid.z) + facing * 0.004, facing, "Damp")
	var t: Texture2D = load(CAMP + tex + ".png")
	var rep := DAMP_H * float(t.get_width()) / float(t.get_height())
	(q.material_override as StandardMaterial3D).uv1_scale = Vector3(maxf(1.0, roundf(length / rep)), 1, 1)


## A barrel vault of planks over `width` (its middle at x 0) from `y0` to `crown`, `depth`
## long around `z`.
func _vault(root: Node3D, width: float, y0: float, crown: float, z: float, depth: float, mat: Material) -> void:
	var n := 8
	for i in n:
		var a0 := PI * float(i) / float(n)
		var a1 := PI * float(i + 1) / float(n)
		var p0 := Vector2(-cos(a0) * width * 0.5, y0 + sin(a0) * (crown - y0))
		var p1 := Vector2(-cos(a1) * width * 0.5, y0 + sin(a1) * (crown - y0))
		var mid := (p0 + p1) * 0.5
		var plank := K.slab(root, Vector3(p0.distance_to(p1) + 0.05, 0.08, depth), Vector3(mid.x, mid.y + 0.04, z), mat, "Vault")
		plank.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)


func _nave(root: Node3D) -> void:
	var lime := K.surface("chapel_lime" if _exists("chapel_lime") else "chapel_wall", 2.4, Color(0.8, 0.8, 0.76))
	var stone := K.surface("chapel_floor", 1.4, Color(0.7, 0.68, 0.62))
	var vault := K.surface("chapel_vault_damp" if _exists("chapel_vault_damp") else "chapel_vault", 2.6, Color(0.84, 0.84, 0.8))
	K.slab(root, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), stone, "Floor")
	K.slab(root, Vector3(0.1, WALL_H, D), Vector3(-W * 0.5 - 0.05, WALL_H * 0.5, 0), lime, "WallWest")
	K.slab(root, Vector3(0.1, WALL_H, D), Vector3(W * 0.5 + 0.05, WALL_H * 0.5, 0), lime, "WallEast")
	K.slab(root, Vector3(W, CROWN + 0.1, 0.1), Vector3(0, (CROWN + 0.1) * 0.5, D * 0.5 + 0.05), lime, "WallDoor")
	# The triumphal arch: the opening in steps to its round top, as thick as a church's.
	var arch := K.slab(root, Vector3(W, CROWN + 0.1, ARCH_T), Vector3(0, (CROWN + 0.1) * 0.5, -D * 0.5 - ARCH_T * 0.5), lime, "Arch")
	var hw := ARCH_W * 0.5
	K.cut_wall(arch, [[-hw, hw, 0.0, 3.7], [-hw + 0.18, hw - 0.18, 3.7, 4.0], [-hw + 0.55, hw - 0.55, 4.0, 4.22],
		[-hw + 1.0, hw - 1.0, 4.22, 4.36], [-0.45, 0.45, 4.36, 4.44]])
	_vault(root, W, WALL_H, CROWN, 0.0, D + 0.1, vault)
	# The damp up every wall of the nave.
	_damp(D, Vector3(-W * 0.5, 0, 0), Vector3(1, 0, 0))
	_damp(D, Vector3(W * 0.5, 0, 0), Vector3(-1, 0, 0))
	_damp(W, Vector3(0, 0, D * 0.5), Vector3(0, 0, -1))
	_damp((W - ARCH_W) * 0.5, Vector3(-(W + ARCH_W) * 0.25, 0, -D * 0.5), Vector3(0, 0, 1))
	_damp((W - ARCH_W) * 0.5, Vector3((W + ARCH_W) * 0.25, 0, -D * 0.5), Vector3(0, 0, 1))


## The steps, the arch's floor, the presbytery: its walls and vault, the rail, the altar's
## table before its retable, the crucifix, St Prokop, the harmonium, the dead flowers.
func _presbytery(root: Node3D) -> void:
	var lime := K.surface("chapel_lime" if _exists("chapel_lime") else "chapel_wall", 2.4, Color(0.8, 0.8, 0.76))
	var stone := K.surface("chapel_floor", 1.4, Color(0.74, 0.72, 0.66))
	var vault := K.surface("chapel_vault_damp" if _exists("chapel_vault_damp") else "chapel_vault", 2.6, Color(0.84, 0.84, 0.8))
	var z0 := -D * 0.5 - ARCH_T
	var zb := z0 - PRES_D
	var zm := (z0 + zb) * 0.5
	K.slab(root, Vector3(ARCH_W + 1.2, STEP, 0.5), Vector3(0, STEP * 0.5, -D * 0.5 + 0.25), stone, "Step")
	K.slab(root, Vector3(ARCH_W, PRES_Y, ARCH_T), Vector3(0, PRES_Y * 0.5, -D * 0.5 - ARCH_T * 0.5), stone, "Step2")
	K.slab(root, Vector3(PRES_W, PRES_Y, PRES_D), Vector3(0, PRES_Y * 0.5, zm), stone, "PresFloor")
	K.slab(root, Vector3(0.1, PRES_WALL, PRES_D), Vector3(-PRES_W * 0.5 - 0.05, PRES_Y + PRES_WALL * 0.5, zm), lime, "PresWest")
	K.slab(root, Vector3(0.1, PRES_WALL, PRES_D), Vector3(PRES_W * 0.5 + 0.05, PRES_Y + PRES_WALL * 0.5, zm), lime, "PresEast")
	K.slab(root, Vector3(PRES_W, PRES_Y + PRES_CROWN + 0.1, 0.1), Vector3(0, (PRES_Y + PRES_CROWN + 0.1) * 0.5, zb - 0.05), lime, "PresBack")
	_vault(root, PRES_W, PRES_Y + PRES_WALL, PRES_Y + PRES_CROWN, zm, PRES_D + 0.1, vault)
	_damp(PRES_D, Vector3(-PRES_W * 0.5, 0, zm), Vector3(1, 0, 0), PRES_Y)
	_damp(PRES_D, Vector3(PRES_W * 0.5, 0, zm), Vector3(-1, 0, 0), PRES_Y)
	_damp(PRES_W, Vector3(0, 0, zb), Vector3(0, 0, 1), PRES_Y)
	# The communion rail on the first step, a gap in its middle.
	if _exists("communion_rail"):
		for side in [-1.0, 1.0]:
			var half := ARCH_W * 0.5 - 0.45
			var rail := K.cutout(root, "communion_rail", Vector2(half, 0.82), Vector3(float(side) * (0.45 + half * 0.5), STEP, -D * 0.5 + 0.06), 0.0, false, "Rail")
			(rail.mesh as QuadMesh).size = Vector2(half, 0.82)
	# The altar: its table on the floor against the retable on the back wall.
	var table := Vector3(2.3, 0.98, 0.72)
	var tpos := Vector3(0, PRES_Y + table.y * 0.5, zb + table.z * 0.5 + 0.02)
	K.slab(root, table, tpos, K.surface("veneer_dark", 0.6), "AltarTable")
	if _exists("chapel_altar_front"):
		_quad("chapel_altar_front", Vector2(table.x + 0.06, table.y), tpos + Vector3(0, 0, table.z * 0.5 + 0.006), Vector3(0, 0, 1), "AltarFront")
	K.slab(root, Vector3(table.x + 0.1, 0.03, table.z + 0.06), tpos + Vector3(0, table.y * 0.5 + 0.015, 0), K.surface("paper_old", 0.4, Color(0.78, 0.76, 0.7)), "AltarCloth")
	var rs := _size("chapel_retable", 2.25) if _exists("chapel_retable") else Vector2(3.2, 2.4)
	var retable := _quad("chapel_retable" if _exists("chapel_retable") else "chapel_altar", rs, Vector3(0, PRES_Y + table.y + rs.y * 0.5, zb + 0.004), Vector3(0, 0, 1), "Retable")
	parts["altar"] = retable
	room._hot_box("altar", Vector3(0, PRES_Y + table.y + 0.9, zb + 0.3), Vector3(rs.x, rs.y, 0.4), [retable])
	# The flowers nobody has changed since spring, either end of the table.
	for sx in [-0.85, 0.85]:
		if _exists("dead_flowers"):
			K.cutout(root, "dead_flowers", _size("dead_flowers", 0.62), Vector3(sx, PRES_Y + table.y + 0.03, zb + 0.32), 0.0, false, "DeadFlowers")
	K.cutout(root, "crucifix", Vector2(0.4, 0.8), Vector3(1.75, PRES_Y + 1.25, zb + 0.02), 0.0, false, "Crucifix")
	# St Prokop on his console on the back wall, west of the altar.
	var con_y := PRES_Y + 1.25
	if _exists("wall_console"):
		K.cutout(root, "wall_console", _size("wall_console", 0.3), Vector3(-1.75, con_y - 0.3, zb + 0.03), 0.0, false, "Console")
	_saint = K.cutout(root, "saint_statue", _size("saint_statue", 1.15), Vector3(-1.75, con_y, zb + 0.12), 0.0, false, "Saint")
	_saint_tex = [(_saint.material_override as StandardMaterial3D).albedo_texture]
	if _exists("saint_statue_turned"):
		_saint_tex.append(load(CAMP + "saint_statue_turned.png"))
	room._hot_box("saint", Vector3(-1.75, con_y + 0.55, zb + 0.2), Vector3(0.5, 1.2, 0.3), [_saint])
	# The harmonium in the presbytery's east corner.
	if _exists("harmonium"):
		var hm := K.cutout(root, "harmonium", _size("harmonium", 1.15), Vector3(1.75, PRES_Y, zb + 0.95), 0.0, true, "Harmonium")
		room._hot_box("harmonium", Vector3(1.75, PRES_Y + 0.55, zb + 0.95), Vector3(0.9, 1.1, 0.6), [hm])


## The choir loft over the door: its floor on the beam and two posts, the painted
## balustrade, the steep stair up the east wall to it.
func _loft(root: Node3D) -> void:
	var wood := K.surface("pew_wood" if _exists("pew_wood") else "veneer_dark", 0.7, Color(0.62, 0.56, 0.5))
	var depth := D * 0.5 - LOFT_Z
	var zc := LOFT_Z + depth * 0.5
	# The floor, open where the stair comes up (the east wall's last metre and a half).
	K.slab(root, Vector3(W - 0.7, 0.25, depth), Vector3(-0.35, LOFT_Y - 0.125, zc), wood, "LoftFloor")
	K.slab(root, Vector3(0.7, 0.25, 0.7), Vector3(W * 0.5 - 0.35, LOFT_Y - 0.125, LOFT_Z + 0.35), wood, "LoftFloor")
	K.slab(root, Vector3(W, 0.3, 0.16), Vector3(0, LOFT_Y - 0.15, LOFT_Z + 0.08), wood, "LoftBeam")
	K.slab(root, Vector3(W, 1.0, 0.08), Vector3(0, LOFT_Y + 0.5, LOFT_Z + 0.04), wood, "Balustrade")
	if _exists("choir_loft"):
		var face := _quad("choir_loft", Vector2(W, 1.0), Vector3(0, LOFT_Y + 0.5, LOFT_Z - 0.004), Vector3(0, 0, -1), "LoftFront")
		(face.material_override as StandardMaterial3D).uv1_scale = Vector3(2, 1, 1)
		parts["loft"] = face
	room._hot_box("loft", Vector3(0, LOFT_Y + 0.6, LOFT_Z), Vector3(W - 0.4, 1.2, 0.3), [parts.get("loft")] if parts.get("loft") != null else [])
	for px in POSTS_X:
		K.slab(root, Vector3(0.26, LOFT_Y - 0.3, 0.26), Vector3(float(px), (LOFT_Y - 0.3) * 0.5, LOFT_Z + 0.2), wood, "Post")
		K.slab(root, Vector3(0.4, 0.12, 0.4), Vector3(float(px), LOFT_Y - 0.36, LOFT_Z + 0.2), wood, "PostHead")
		K.slab(root, Vector3(0.36, 0.1, 0.36), Vector3(float(px), 0.05, LOFT_Z + 0.2), wood, "PostFoot")
	# The stair: steep treads up the east wall towards the door, into the loft's floor.
	var n := 12
	var z0 := LOFT_Z + 0.15
	for i in n:
		var y := float(i + 1) * LOFT_Y / float(n)
		K.slab(root, Vector3(0.62, 0.05, 0.22), Vector3(W * 0.5 - 0.36, y - 0.025, z0 + float(i) * 0.155), wood, "Tread")
	var run := float(n) * 0.155
	var slope := K.slab(root, Vector3(0.06, 0.22, sqrt(run * run + LOFT_Y * LOFT_Y)), Vector3(W * 0.5 - 0.66, LOFT_Y * 0.5, z0 + run * 0.5), wood, "Stringer")
	slope.rotation.x = -atan2(LOFT_Y, run)


## Seven rows each side of the aisle: seat, back (to the door, the hymn books' shelf on
## it), kneeler, the carved end to the aisle, all grey with dust.
func _pews(root: Node3D) -> void:
	var wood := K.surface("pew_wood" if _exists("pew_wood") else "veneer_dark", 0.7, Color(0.78, 0.74, 0.68))
	for z in ROWS:
		for side in [-1.0, 1.0]:
			var cx: float = float(side) * (AISLE + PEW_L * 0.5)
			var zz: float = z
			K.slab(root, Vector3(PEW_L, 0.06, 0.4), Vector3(cx, 0.45, zz), wood, "PewSeat")
			K.slab(root, Vector3(PEW_L, 0.5, 0.05), Vector3(cx, 0.8, zz + 0.2), wood, "PewBack")
			K.slab(root, Vector3(PEW_L, 0.06, 0.06), Vector3(cx, 0.48, zz + 0.2), wood, "PewRail")
			K.slab(root, Vector3(PEW_L, 0.08, 0.12), Vector3(cx, 0.14, zz + 0.48), wood, "Kneeler")
			if _exists("pew_back"):
				var pb := _quad("pew_back", Vector2(PEW_L, 0.56), Vector3(cx, 0.78, zz + 0.228), Vector3(0, 0, 1), "PewBackFace")
				(pb.material_override as StandardMaterial3D).albedo_color = Color(0.86, 0.84, 0.8)
			var ax: float = float(side) * AISLE
			K.slab(root, Vector3(0.05, 0.95, 0.62), Vector3(ax, 0.475, zz + 0.08), wood, "PewEnd")
			K.slab(root, Vector3(0.05, 0.95, 0.62), Vector3(float(side) * (AISLE + PEW_L), 0.475, zz + 0.08), wood, "PewEnd")
			if _exists("pew_end"):
				var face := K.picture(root, "pew_end", Vector2(0.62, 0.95), Vector3(ax - float(side) * 0.03, 0.475, zz + 0.08), -90.0 * float(side), "PewEndFace")
				var m := (face.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.5
				m.albedo_color = Color(0.86, 0.84, 0.8)
				face.material_override = m
	var mid := (float(ROWS[2]) + float(ROWS[4])) * 0.5
	room._hot_box("pews_w", Vector3(-AISLE - PEW_L * 0.5, 0.7, mid), Vector3(PEW_L, 0.6, 2.4), [])
	room._hot_box("pews_e", Vector3(AISLE + PEW_L * 0.5, 0.7, mid), Vector3(PEW_L, 0.6, 2.4), [])


## The oval windows, grey with the dirt on the glass, their cold light; the shafts of it
## slanting down through the dust from the east side.
func _windows(root: Node3D, _hour: float) -> void:
	var tex := "chapel_oval" if _exists("chapel_oval") else "stained_window"
	var size := _size(tex, 1.35) if _exists(tex) else Vector2(0.85, 1.35)
	var spots: Array = []
	for side in [-1.0, 1.0]:
		for wz in NAVE_WINDOWS_Z:
			spots.append([Vector3(float(side) * (W * 0.5 - 0.01), NAVE_WINDOW_Y, float(wz)), float(side)])
		spots.append([Vector3(float(side) * (PRES_W * 0.5 - 0.01), PRES_Y + 2.7, -D * 0.5 - ARCH_T - PRES_D * 0.5), float(side)])
	for sp in spots:
		var at: Vector3 = sp[0]
		var side: float = sp[1]
		var win := K.cutout(root, tex, size, at - Vector3(0, size.y * 0.5, 0), -90.0 * side, false, "Oval")
		var m := win.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = m.albedo_texture
		var l := OmniLight3D.new()
		l.position = at + Vector3(-side * 1.2, -0.6, 0)
		root.add_child(l)
		_wins.append({"mat": m, "light": l, "west": side < 0.0})
		# The sun's shafts come in through the east side, the moon's through the west side,
		# steep, thin and cold; how much of each is the hour's (_set_dusk, _tick_lights).
		if side < 0.0:
			_moon_ray(root, at + Vector3(0.05, 0, 0), PRES_Y if at.z < -D * 0.5 else 0.0)
		else:
			_shaft(root, at + Vector3(-0.05, 0, 0), Vector3(-1.0, -0.72, 0.18).normalized(), 6.5, Color(0.17, 0.18, 0.16))
	room._hot_box("window", Vector3(-W * 0.5 + 0.1, NAVE_WINDOW_Y, float(NAVE_WINDOWS_Z[1])), Vector3(0.2, 1.3, 0.9), [])


static var _shaft_tex: ImageTexture


## A shaft of light: two crossed quads along `dir` from the window, added on, fading along
## and across in a few steps (the Build way, banded, no soft glow).
func _shaft(root: Node3D, from: Vector3, dir: Vector3, length: float, col: Color, width := 0.6, tex: Texture2D = null, kind := "sun") -> void:
	if _shaft_tex == null:
		var img := Image.create(16, 48, false, Image.FORMAT_RGBA8)
		for yy in 48:
			for xx in 16:
				var across := sin(PI * (float(xx) + 0.5) / 16.0)
				var along := 1.0 - float(yy) / 47.0
				var v := floorf(across * along * along * 5.0) / 5.0
				img.set_pixel(xx, yy, Color(v, v, v, 1.0))
		_shaft_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = tex if tex != null else _shaft_tex
	m.albedo_color = col
	m.set_meta("retro_skip", true)
	var y := -dir.normalized()
	var mi := MeshInstance3D.new()
	mi.name = "Shaft"
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	mi.mesh = q
	mi.material_override = m
	mi.position = from - y * length * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("retro_skip", true)
	root.add_child(mi)
	_shafts.append({"node": mi, "axis": y, "col": col, "kind": kind, "from": from, "len": length})
	_face_shaft(_shafts.back())


## The moon through one of the west windows: a broad ray and its brighter core down to the
## floor (`floor_y`), banded the Build way and hardly fading, where it lies in a pale patch
## on the stones with a light over it for the pews either side; dust turning in it.
func _moon_ray(root: Node3D, from: Vector3, floor_y: float) -> void:
	if _moon_tex == null:
		var img := Image.create(16, 48, false, Image.FORMAT_RGBA8)
		for yy in 48:
			for xx in 16:
				var across := sin(PI * (float(xx) + 0.5) / 16.0)
				var along := 1.0 - 0.5 * float(yy) / 47.0
				var v := floorf(across * along * 5.0) / 5.0
				img.set_pixel(xx, yy, Color(v, v, v, 1.0))
		_moon_tex = ImageTexture.create_from_image(img)
	var down := MOON_DIR.normalized()
	var t := (from.y - floor_y) / -down.y
	var hit := from + down * t
	_shaft(root, from, down, t, Color(0.06, 0.07, 0.11), 1.7, _moon_tex, "moon")
	_shaft(root, from, down, t, Color(0.15, 0.18, 0.28), 0.95, _moon_tex, "moon")
	_shaft(root, from + down * 0.04, down, t, Color(0.12, 0.15, 0.23), 0.4, _moon_tex, "moon")
	# The patch on the floor, longer the way the ray leans.
	var patch := _flat_glow(root, hit + Vector3(0, 0.012, 0), Vector2(1.25, 0.8), Color(0.28, 0.33, 0.5), 0.5)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.65, 0.95)
	l.light_energy = 0.7
	l.omni_range = 2.8
	l.position = hit + Vector3(0, 0.9, 0)
	root.add_child(l)
	_moon_pools.append({"light": l, "mat": patch.material_override, "base": 0.7, "alpha": 0.5})
	# The haze lit round the window it comes in by.
	var glow := _halo(root, from + Vector3(0.25, 0, 0), 2.2, Color(0.42, 0.52, 0.78), true)
	_moon_pools.append({"mat": glow.material_override, "alpha": 0.12})
	_moon_motes(root, from, down, t)


## Dust turning in a ray of the moon, only there: specks it lights, added on.
func _moon_motes(root: Node3D, from: Vector3, down: Vector3, length: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "MoonDust"
	p.amount = 46
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.24, length * 0.45, 0.24)
	# Its box along the ray: local Y up the ray to the window.
	var y := -down
	var x := y.cross(Vector3(0, 0, 1)).normalized()
	var z := x.cross(y).normalized()
	p.transform = Transform3D(Basis(x, y, z), from + down * length * 0.5)
	p.direction = Vector3(0.2, 1.0, 0.1)
	p.spread = 180.0
	p.gravity = Vector3(0, -0.006, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.03
	var q := QuadMesh.new()
	q.size = Vector2(0.013, 0.013)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.albedo_color = Color(0.72, 0.8, 1.0)
	m.set_meta("retro_skip", true)
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.9))
	g.add_point(0.75, Color(1, 1, 1, 0.9))
	p.color_ramp = g
	p.set_meta("retro_skip", true)
	root.add_child(p)
	_moon_dust.append(p)


## A patch of light lying on a floor: the glow's rings laid flat, added on.
func _flat_glow(root: Node3D, at: Vector3, size: Vector2, col: Color, alpha: float) -> MeshInstance3D:
	var mi := _halo(root, at, 1.0, col)
	var m := mi.material_override as StandardMaterial3D
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	(mi.mesh as QuadMesh).size = size
	mi.rotation_degrees.x = -90.0
	return mi


## A shaft turns about its own line to face the eye (a flat quad, never seen edge on).
func _face_shaft(s: Dictionary) -> void:
	var mi: MeshInstance3D = s["node"]
	var y: Vector3 = s["axis"]
	var v: Vector3 = room._cam.position - mi.position
	var z := v - y * v.dot(y)
	if z.length() < 0.01:
		return
	z = z.normalized()
	mi.basis = Basis(y.cross(z), y, z)


## The door from inside, the stoup by it, the box on its post, the votive stand, the rope
## down through the loft's floor.
func _by_the_door(root: Node3D) -> void:
	var dz := D * 0.5 - 0.01
	if _exists("chapel_door_in"):
		K.cutout(root, "chapel_door_in", _size("chapel_door_in", 2.75), Vector3(0, 0.0, dz), 180.0, false, "Door")
	else:
		K.picture(root, "door_interior", Vector2(1.2, 2.2), Vector3(0, 1.1, dz), 180.0, "Door")
	if _exists("holy_water"):
		K.cutout(root, "holy_water", _size("holy_water", 0.4), Vector3(1.05, 0.9, dz - 0.02), 180.0, false, "Stoup")
	if _exists("collection_box"):
		var box := K.cutout(root, "collection_box", _size("collection_box", 1.0), Vector3(-1.45, 0.0, 5.0), 0.0, true, "OfferBox")
		room._hot_box("box", Vector3(-1.45, 0.8, 5.0), Vector3(0.4, 0.5, 0.4), [box])
	# The votive candles by the door, turned to the nave: the iron rack on its table, the
	# one you see up close (candle_closeup.gd), cup for cup.
	var rack := _exists("candle_stand")
	var stand_tex := "candle_stand" if rack else ("votive_stand" if _exists("votive_stand") else "candles_rack")
	var ss := _size(stand_tex, 1.52 if rack else 1.1)
	var at := Vector3(1.95, 0.0, 5.05) if rack else Vector3(1.55, 0.0, 5.05)
	var stand := K.cutout(root, stand_tex, ss, at, 180.0, false, "Votive")
	parts["stand"] = {"node": stand, "size": ss, "at": at}
	room._hot_box("candles", at + Vector3(0, 0.78, 0), Vector3(ss.x, 1.5, 0.4), [stand])
	cups = _rack_cups(ss, at, 180.0) if rack else _cup_spots(stand_tex, ss, at, 180.0)
	# The bell's rope down through the loft's floor, its grip within reach of the door.
	if _exists("bell_rope"):
		var rlen := LOFT_Y - 0.25 - 0.9
		var rs := _size("bell_rope", rlen)
		_rope_y = 0.9
		_rope = K.cutout(root, "bell_rope", rs, Vector3(-1.0, _rope_y, 4.95), 0.0, true, "Rope")
		room._hot_box("rope", Vector3(-1.0, 1.35, 4.95), Vector3(0.3, 1.1, 0.3), [_rope])


## The rack's cups as spots in the room for the flames, from RACK_CUPS (the picture's wicks,
## the same fifteen in the same order as candle_closeup.CUPS). The quad faces +Z turned `yaw`.
func _rack_cups(size: Vector2, at: Vector3, yaw: float) -> Array:
	var th := deg_to_rad(yaw)
	var right := Vector3(cos(th), 0.0, -sin(th))
	var fwd := Vector3(sin(th), 0.0, cos(th))
	var out: Array = []
	for c in RACK_CUPS:
		out.append(at + right * ((float(c[0]) - 0.5) * size.x) + Vector3(0, (1.0 - float(c[1])) * size.y + 0.01, 0) + fwd * 0.03)
	return out


## The cups of the old stand (its picture's red glass, found once), as spots in the room for
## the flames: in the top half of the picture the two rows with the most runs of red (its
## two tiers), each run a cup. The stand's quad faces +Z turned `yaw`.
func _cup_spots(tex: String, size: Vector2, at: Vector3, yaw: float) -> Array:
	var out: Array = []
	var path := CAMP + tex + ".png"
	if not ResourceLoader.exists(path):
		return out
	var img: Image = (load(path) as Texture2D).get_image()
	if img == null:
		return out
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var best := [[-1, []], [-1, []]]
	for ry in int(h * 0.5):
		var runs: Array = []
		var run_start := -1
		for x in w + 1:
			var red := false
			if x < w:
				var c := img.get_pixel(x, ry)
				red = c.a > 0.5 and c.r > c.g * 1.5 and c.r > c.b * 1.4 and c.r > 0.3
			if red and run_start < 0:
				run_start = x
			elif not red and run_start >= 0:
				if x - run_start >= 1:
					runs.append((float(run_start + x) * 0.5) / float(w))
				run_start = -1
		var tier := 0 if ry < int(h * 0.2) else 1
		if runs.size() > (best[tier][1] as Array).size():
			best[tier] = [ry, runs]
	var th := deg_to_rad(yaw)
	var right := Vector3(cos(th), 0.0, -sin(th))
	var fwd := Vector3(sin(th), 0.0, cos(th))
	for b in best:
		var ry: int = b[0]
		if ry < 0:
			continue
		for u in b[1]:
			var v := float(ry) / float(h)
			out.append(at + right * ((float(u) - 0.5) * size.x) + Vector3(0, (1.0 - v) * size.y + 0.02, 0) + fwd * 0.03)
	return out


## The Stations of the Cross along the walls, three each side.
func _on_the_walls(root: Node3D) -> void:
	var spots := [-4.75, -1.95, 1.0]
	var i := 1
	for side in [-1.0, 1.0]:
		for z in spots:
			var tex := "station_%d" % i
			if _exists(tex):
				var st := K.cutout(root, tex, _size(tex, 0.5), Vector3(float(side) * (W * 0.5 - 0.02), 1.85, float(z)), -90.0 * float(side), false, "Station")
				(st.material_override as StandardMaterial3D).albedo_color = Color(0.82, 0.8, 0.76)
				if i == 1:
					room._hot_box("stations", Vector3(float(side) * (W * 0.5 - 0.05), 2.1, float(z)), Vector3(0.1, 0.55, 0.45), [st])
			i += 1


## The rot: stains and mould up the walls and over the vault, the plaster fallen off the
## bricks, the cracks; the floor's puddles, the plaster on it, the leaves blown in, moss.
func _decay(root: Node3D) -> void:
	var wx := W * 0.5
	var wall := [
		["decay_stain", Vector2(1.1, 0.9), Vector3(-wx, 3.95, -2.1), Vector3(1, 0, 0), 0.2],
		["decay_stain", Vector2(0.9, 0.75), Vector3(wx, 4.15, 0.9), Vector3(-1, 0, 0), -0.4],
		["decay_mould", Vector2(0.55, 0.45), Vector3(-wx, 2.35, -0.4), Vector3(1, 0, 0), 0.0],
		["decay_mould", Vector2(0.45, 0.4), Vector3(wx, 2.3, 2.5), Vector3(-1, 0, 0), 2.6],
		["decay_mould", Vector2(0.6, 0.5), Vector3(-wx, 2.4, -3.6), Vector3(1, 0, 0), 1.0],
		["decay_bricks", Vector2(0.75, 0.6), Vector3(wx, 2.95, -1.8), Vector3(-1, 0, 0), 0.0],
		["decay_crack", Vector2(0.55, 1.1), Vector3(-wx, 3.4, 1.6), Vector3(1, 0, 0), 0.1],
		["decay_crack", Vector2(0.5, 1.0), Vector3(1.6, 5.1, -D * 0.5), Vector3(0, 0, 1), -0.3],
		["decay_stain", Vector2(1.1, 0.9), Vector3(-1.9, 5.3, -D * 0.5), Vector3(0, 0, 1), 0.5],
		["decay_stain", Vector2(1.0, 0.8), Vector3(1.4, 4.4, D * 0.5), Vector3(0, 0, -1), 0.0],
		["decay_mould", Vector2(0.5, 0.42), Vector3(-PRES_W * 0.5, PRES_Y + 2.3, -D * 0.5 - ARCH_T - 1.0), Vector3(1, 0, 0), 0.4],
	]
	for d in wall:
		var tint := Color(0.74, 0.76, 0.7) if str(d[0]) == "decay_mould" else Color(0.86, 0.85, 0.8)
		_decal(str(d[0]), d[1], d[2], d[3], float(d[4]), tint)
	# Over the vault: round the leak, and along its foot by the walls.
	for v in [[0.36, 0.62, 1.8], [-1.9, -3.0, 1.4], [2.2, 3.3, 1.2], [-0.9, -4.6, 1.3]]:
		var x: float = v[0]
		var y := vault_y(x)
		var n := Vector3(-x / pow(W * 0.5, 2.0), -(y - WALL_H) / pow(CROWN - WALL_H, 2.0), 0).normalized()
		_decal("decay_stain", Vector2(float(v[2]), float(v[2]) * 0.8), Vector3(x, y - 0.05, float(v[1])), n, 0.7, Color(0.84, 0.83, 0.78))
	_decal("decay_bricks", Vector2(0.8, 0.6), Vector3(2.3, vault_y(2.3) - 0.05, -0.2), Vector3(-0.6, -1.0, 0).normalized(), 0.0)
	var flat := Vector3.UP
	var floor := [
		["floor_puddle", Vector2(1.25, 0.9), BUCKET + Vector3(0.05, 0.0, 0.05), 0.4],
		["floor_puddle", Vector2(1.0, 0.7), Vector3(-2.75, 0.0, -2.2), 1.6],
		["floor_plaster", Vector2(0.8, 0.6), Vector3(2.75, 0.0, -1.75), 0.0],
		["floor_plaster", Vector2(0.6, 0.5), Vector3(2.2, 0.0, -0.2), 2.0],
		["floor_leaves", Vector2(0.9, 0.6), Vector3(0.5, 0.0, 5.05), 0.3],
		["floor_leaves", Vector2(0.7, 0.5), Vector3(-0.9, 0.0, 4.2), 2.2],
		["floor_leaves", Vector2(0.5, 0.4), Vector3(0.15, 0.0, 2.95), 1.1],
		["floor_moss", Vector2(1.2, 0.5), Vector3(-W * 0.5 + 0.25, 0.0, 5.0), 1.57],
		["floor_moss", Vector2(1.0, 0.45), Vector3(W * 0.5 - 0.25, 0.0, 4.6), -1.57],
		["floor_moss", Vector2(0.9, 0.4), Vector3(-PRES_W * 0.5 + 0.25, PRES_Y, -9.4), 1.57],
	]
	for f in floor:
		_decal(str(f[0]), f[1], f[2], flat, float(f[3]), Color(0.8, 0.8, 0.76))


## Cobwebs in the corners under the vault, round the windows, in the loft's corners and
## low between the pews; strands hanging off the vault and the chandelier.
func _cobwebs(root: Node3D) -> void:
	var tex := ["pub_cobweb", "bistro_cobweb"]
	var wx := W * 0.5
	var webs := [
		[Vector3(-wx + 0.3, WALL_H - 0.75, -D * 0.5 + 0.3), 45.0, 0.9],
		[Vector3(wx - 0.3, WALL_H - 0.75, -D * 0.5 + 0.3), -45.0, 0.8],
		[Vector3(-wx + 0.3, WALL_H - 0.6, D * 0.5 - 0.3), 135.0, 0.9],
		[Vector3(wx - 0.3, WALL_H - 0.6, D * 0.5 - 0.3), -135.0, 0.85],
		[Vector3(-wx + 0.25, LOFT_Y - 0.85, D * 0.5 - 0.25), 135.0, 0.6],
		[Vector3(wx - 0.25, 2.0, D * 0.5 - 0.25), -135.0, 0.5],
		[Vector3(-PRES_W * 0.5 + 0.3, PRES_Y + PRES_WALL - 0.7, -D * 0.5 - ARCH_T - PRES_D + 0.3), 45.0, 0.8],
		[Vector3(PRES_W * 0.5 - 0.3, PRES_Y + PRES_WALL - 0.7, -D * 0.5 - ARCH_T - PRES_D + 0.3), -45.0, 0.7],
		[Vector3(float(POSTS_X[0]) + 0.25, LOFT_Y - 0.75, LOFT_Z + 0.25), 45.0, 0.45],
		[Vector3(float(POSTS_X[1]) - 0.25, LOFT_Y - 0.75, LOFT_Z + 0.25), -45.0, 0.45],
	]
	var i := 0
	for wv in webs:
		var t: String = tex[i % 2]
		if _exists(t):
			var c := K.cutout(root, t, _size(t, float(wv[2])), wv[0], float(wv[1]), false, "Cobweb")
			(c.material_override as StandardMaterial3D).albedo_color = Color(0.78, 0.78, 0.74)
		i += 1
	# Low between the pews' ends along the walls.
	for z in [float(ROWS[0]), float(ROWS[3]), float(ROWS[5])]:
		for side in [-1.0, 1.0]:
			var t: String = tex[int(z * 10.0) % 2]
			if _exists(t):
				K.cutout(root, t, _size(t, 0.3), Vector3(float(side) * (AISLE + PEW_L + 0.2), 0.08, z + 0.2), 90.0, false, "Cobweb")
	if _exists("cobweb_strands"):
		for sv in [[-2.7, -2.6, 1.3], [2.6, 1.8, 1.1], [-2.5, 2.9, 1.0], [1.2, -4.9, 1.2], [-1.1, 0.4, 0.9]]:
			var x: float = sv[0]
			var h: float = sv[2]
			K.cutout(root, "cobweb_strands", _size("cobweb_strands", h), Vector3(x, vault_y(x) - h - 0.02, float(sv[1])), 0.0, true, "Strands")
	# The chandelier off the crown, unlit, its arms webbed together.
	if _exists("chapel_chandelier"):
		var ch := 1.05
		var top := CROWN - 0.75
		K.slab(root, Vector3(0.025, CROWN - top, 0.025), Vector3(0, (CROWN + top) * 0.5, -1.2), K.surface("galvanized", 0.3, Color(0.35, 0.32, 0.28)), "Chain")
		var c := K.cutout(root, "chapel_chandelier", _size("chapel_chandelier", ch), Vector3(0, top - ch, -1.2), 0.0, true, "Chandelier")
		(c.material_override as StandardMaterial3D).albedo_color = Color(0.85, 0.82, 0.76)
		if _exists("cobweb_strands"):
			K.cutout(root, "cobweb_strands", _size("cobweb_strands", 0.9), Vector3(0.25, top - ch - 0.55, -1.05), 0.0, true, "Strands")


## The bucket in the aisle under the leak, the drop that falls into it.
func _leak(root: Node3D) -> void:
	var tex := "pub_bucket" if _exists("pub_bucket") else "mop_bucket"
	if _exists(tex):
		var b := K.cutout(root, tex, _size(tex, 0.34), BUCKET, 0.0, true, "Bucket")
		(b.material_override as StandardMaterial3D).albedo_color = Color(0.8, 0.8, 0.76)
		room._hot_box("bucket", BUCKET + Vector3(0, 0.2, 0), Vector3(0.4, 0.4, 0.4), [b])
	_drop = MeshInstance3D.new()
	_drop.name = "Drop"
	var q := QuadMesh.new()
	q.size = Vector2(0.016, 0.06)
	_drop.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.7, 0.74, 0.72)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_drop.material_override = m
	_drop.visible = false
	_drop.set_meta("retro_skip", true)
	root.add_child(_drop)
	var trip = room.get_parent()
	var main = trip._main() if trip != null and trip.has_method("_main") else null
	var ws = main.get("weather_system") if main != null else null
	_rain = ws != null and int(ws.get("current_weather")) >= 3 and int(ws.get("current_weather")) <= 5
	_drip_t = 0.6


## The confessional under the loft by the west wall: a box with its carved front.
func _confessional(root: Node3D) -> void:
	var at := Vector3(-W * 0.5 + 0.42, 0.0, 4.25)
	var tex := "confessional"
	if not _exists(tex):
		return
	var s := _size(tex, 2.25)
	K.slab(root, Vector3(0.8, 2.0, s.x * 0.86), at + Vector3(-0.02, 1.0, 0), K.surface("veneer_dark", 0.6, Color(0.5, 0.42, 0.36)), "ConfessionalBox")
	var f := K.cutout(root, tex, s, at + Vector3(0.4, 0, 0), 90.0, false, "Confessional")
	(f.material_override as StandardMaterial3D).albedo_color = Color(0.86, 0.84, 0.8)
	room._hot_box("confess", at + Vector3(0.42, 1.1, 0), Vector3(0.2, 2.1, s.x), [f])


## The figure under the dust sheet: somewhere else each time (worse, nearer).
func _sheet_figure(root: Node3D) -> void:
	if not _exists("dust_sheet_figure"):
		return
	var lo := _low()
	var weights := [3.0, 2.0, 1.0 + 3.0 * lo, 1.0 + 3.0 * lo, 1.5]
	_sheet_at = _pick(weights)
	var sp: Array = SHEET_SPOTS[_sheet_at]
	_sheet = K.cutout(root, "dust_sheet_figure", _size("dust_sheet_figure", 1.78), sp[0], float(sp[1]), true, "SheetFigure")
	(_sheet.material_override as StandardMaterial3D).albedo_color = Color(0.82, 0.82, 0.78)
	room._hot_box("sheet", (sp[0] as Vector3) + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6), [_sheet])


func _pick(weights: Array) -> int:
	var sum := 0.0
	for w in weights:
		sum += float(w)
	var r := _rng.randf() * sum
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1


## The one who stands up in the loft (the last guest who left your camp, as they looked).
func _make_watcher(root: Node3D) -> void:
	var trip = room.get_parent()
	var path := ""
	if trip != null and trip.has_method("_last_departed_sprite"):
		path = str(trip._last_departed_sprite())
	if path == "" or not ResourceLoader.exists(path):
		# Nobody has left the camp yet: one of its guests all the same.
		path = "res://assets/textury/npc/host%d.png" % _rng.randi_range(1, 3)
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	_watcher = Sprite3D.new()
	_watcher.name = "LoftWatcher"
	_watcher.texture = t
	_watcher.pixel_size = 1.7 / float(t.get_height())
	_watcher.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_watcher.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_watcher.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_watcher.shaded = true
	_watcher.offset = Vector2(0, t.get_height() * 0.5)
	_watcher.modulate = Color(0.66, 0.66, 0.7)
	_watcher.visible = false
	root.add_child(_watcher)


## The haze of the damp air, the dust turning in it.
func _air(root: Node3D, _hour: float) -> void:
	var env: Environment = room._env
	env.fog_enabled = true
	env.fog_light_energy = 1.0
	env.fog_sky_affect = 0.0
	var p := CPUParticles3D.new()
	p.name = "Dust"
	p.amount = 260
	p.lifetime = 16.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(W * 0.5 - 0.4, 1.9, D * 0.5 - 0.6)
	p.position = Vector3(0, 2.6, 0)
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 180.0
	p.gravity = Vector3(0, -0.004, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.035
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.014)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.96, 0.84)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 0.8))
	g.add_point(0.8, Color(1, 1, 1, 0.8))
	p.color_ramp = g
	p.set_meta("retro_skip", true)
	root.add_child(p)
	_dust = p


# ── light ────────────────────────────────────────────────────────────────────

func _light(hour: float, candles: int) -> void:
	# Somebody lit candles on the stand in the evening: as many on every warden's.
	if lit_time(hour):
		_stand_done = true
		var lit := _night_lit(hour)
		if candles < lit:
			candles = lit
			room._candles = lit
	var kept: Array = room.get_meta("candle_cups", [])
	for i in candles:
		add_flame(int(kept[i]) if i < kept.size() else -1)


## The light of the hour, the morning's, the late afternoon's (`late`) and the night's (`k`)
## blended, also while you stand there. At night the same damp haze as by day, grey-blue
## with the moon in it: the far end of the nave goes into it, the candles glow through it;
## just enough light to find the pews by; the moon through the dirt on the glass, full on
## the west side, only the sky's glow on the east; the dust seen only where a light is (the
## moon's own is in its rays).
func _set_dusk(k: float, late: float) -> void:
	_k = k
	_late = late
	var env: Environment = room._env
	env.fog_light_color = Color(0.46, 0.49, 0.44).lerp(Color(0.5, 0.44, 0.36), late).lerp(Color(0.1, 0.115, 0.165), k)
	env.fog_density = lerpf(0.042, 0.046, k)
	env.ambient_light_color = Color(0.76, 0.8, 0.76).lerp(Color(0.8, 0.74, 0.66), late).lerp(Color(0.46, 0.52, 0.72), k)
	env.ambient_light_energy = lerpf(lerpf(0.24, 0.19, late), 0.16, k)
	var glass := Color(0.86, 0.9, 0.84).lerp(Color(1.0, 0.8, 0.58), late).lerp(Color(0.36, 0.44, 0.66), k)
	var beam := Color(0.86, 0.9, 0.88).lerp(Color(1.0, 0.78, 0.55), late).lerp(Color(0.5, 0.6, 0.86), k)
	for w in _wins:
		var m: StandardMaterial3D = w["mat"]
		var l: OmniLight3D = w["light"]
		var west: bool = w["west"]
		m.emission = glass
		m.emission_energy_multiplier = lerpf(1.15, 0.85 if west else 0.42, k)
		m.albedo_color = Color(0.82, 0.84, 0.8).lerp(Color(0.3, 0.33, 0.4), k)
		l.light_color = beam
		l.light_energy = lerpf(0.3, 0.15 if west else 0.08, k)
		l.omni_range = lerpf(5.0, 6.0, k)
	# The sun's shafts lower and warmer as it goes.
	var y := -Vector3(-1.0, lerpf(-0.72, -0.42, late), 0.18).normalized()
	var col := Color(0.17, 0.18, 0.16).lerp(Color(0.26, 0.19, 0.12), late)
	for sh in _shafts:
		if str(sh["kind"]) == "sun":
			sh["axis"] = y
			sh["col"] = col
			(sh["node"] as MeshInstance3D).position = (sh["from"] as Vector3) - y * float(sh["len"]) * 0.5
	if _dust != null:
		(_dust.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.96, 0.84).lerp(Color(0.55, 0.56, 0.62), k)
	for d in _moon_dust:
		if is_instance_valid(d):
			(d as CPUParticles3D).emitting = k > 0.02


## The clock while you stand there: the light goes with it, and from six on what is to
## burn is lit.
func _follow_hour() -> void:
	var trip = room.get_parent()
	if trip == null or not trip.has_method("hour"):
		return
	var h := float(trip.hour())
	var k := night_k(h)
	var late := late_k(h)
	if absf(k - _k) > 0.002 or absf(late - _late) > 0.002:
		_set_dusk(k, late)
	if lit_time(h):
		_evening(h)


## Never while you look: Mrs Hruba is gone when you turn round, the altar's candles burn,
## the stubs, the stand has its evening's flames.
func _evening(h: float) -> void:
	var root: Node3D = room._root
	if _hruba != null and h >= LIT_FROM and _looking == "" and not _seen(_hruba.position + Vector3(0, 0.6, 0)):
		_hruba.queue_free()
		_hruba = null
		var hot: Dictionary = room._hot.get("her", {})
		if hot.get("body") != null:
			(hot["body"] as Node).queue_free()
		room._hot.erase("her")
	if not _altar_lit and not _altar_tips.is_empty() and not _seen(_altar_mid):
		_light_altar(root)
	if not _stubs_lit and not _stub_tips.is_empty():
		var seen := false
		for tip in _stub_tips:
			seen = seen or _seen(tip)
		if not seen:
			_light_stubs(root)
	if not _stand_done and (_candle_cu == null or not _candle_cu.visible):
		var at: Vector3 = (parts.get("stand", {}) as Dictionary).get("at", Vector3(1.55, 0.0, 5.05))
		if not _seen(at + Vector3(0, 1.1, 0)):
			_stand_done = true
			for i in maxi(0, _night_lit(h) - flames.size()):
				add_flame()
			room._candles = flames.size()


## How many burn on the stand at night before you come: the night's own number
## (town_trip._night_index), the same on every warden's machine.
func _night_lit(hour: float) -> int:
	var trip = room.get_parent()
	var n := 1
	if trip != null and trip.has_method("_night_index"):
		n = int(trip._night_index(hour))
	return 3 + posmod(n * 7 + 2, 5)


## The cups with no flame on them (their indexes in `cups`).
func free_cups() -> Array:
	var out: Array = []
	for i in maxi(1, cups.size()):
		out.append(i)
	for f in flames:
		out.erase(int((f as Dictionary).get("cup", -1)))
	return out


## One more flame on the stand, on cup `cup` if that one is free, else on the next empty
## one (a small light with it).
func add_flame(cup := -1) -> bool:
	var free := free_cups()
	if free.is_empty():
		return false
	var i: int = cup if free.has(cup) else int(free[0])
	if not free.has(cup):
		for o in LIGHT_ORDER:
			if free.has(o):
				i = int(o)
				break
	var root: Node3D = room._root
	var at: Vector3 = cups[i] if i < cups.size() else Vector3(1.55, 1.0, 5.0)
	var tex := "candle_flame_2" if _exists("candle_flame_2") else "votive_flame_0"
	var f := K.cutout(root, tex if _exists(tex) else "candles_rack", Vector2(0.045, 0.1), at, 0.0, true, "Flame")
	var m := f.material_override as StandardMaterial3D
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	f.set_meta("retro_skip", true)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.68, 0.34)
	l.light_energy = 0.22
	l.omni_range = lerpf(2.2, 2.6, _k)
	l.position = at + Vector3(0, 0.1, -0.15)
	root.add_child(l)
	# In the dark each flame has its glow round it.
	var halo := _halo(root, at + Vector3(0, 0.05, -0.02), 0.24, Color(1.0, 0.6, 0.28))
	halo.visible = _k > 0.01
	flames.append({"node": f, "light": l, "phase": randf() * 4.0, "cup": i, "halo": halo})
	_keep_cups()
	return true


## Which cups burn, kept on the room while you are in Liblice (it counts them in `_candles`).
func _keep_cups() -> void:
	var lit: Array = []
	for f in flames:
		lit.append(int((f as Dictionary).get("cup", -1)))
	room.set_meta("candle_cups", lit)


## Cup `cup`'s flame out (the stand's count with it; the other wardens' stands go on
## burning: what goes out here goes out for this warden).
func put_out(cup: int) -> void:
	for f in flames.duplicate():
		if int((f as Dictionary).get("cup", -1)) == cup:
			_smoke_at(cup)
			(f["node"] as Node).queue_free()
			(f["light"] as Node).queue_free()
			if f.get("halo") != null and is_instance_valid(f["halo"]):
				(f["halo"] as Node).queue_free()
			flames.erase(f)
	own_cups.erase(cup)
	room._candles = flames.size()
	_keep_cups()


## A thread of smoke over a cup for a few seconds (its three pictures in turn).
func _smoke_at(cup: int) -> void:
	if cup < 0 or cup >= cups.size() or not _exists("candle_smoke_0"):
		return
	var s := K.cutout(room._root, "candle_smoke_0", Vector2(0.05, 0.2), (cups[cup] as Vector3) + Vector3(0, 0.05, 0), 0.0, true, "Smoke")
	(s.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.set_meta("retro_skip", true)
	_smokes.append({"node": s, "t": 0.0})


## Mrs Hruba on her knees in the second pew on the left, her back to you.
func _mrs_hruba() -> void:
	var path := "res://assets/textury/npc/town_hruba_kneel.png"
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	var h := 1.05
	var size := Vector2(h * float(t.get_width()) / float(t.get_height()), h)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, h * 0.5, 0)
	mi.mesh = q
	var m := K._base(Color(1, 1, 1))
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(-AISLE - 0.7, 0.05, float(ROWS[0]) + 0.62)
	mi.name = "MrsHruba"
	room._root.add_child(mi)
	_hruba = mi
	room._hot_box("her", mi.position + Vector3(0, 0.55, 0), Vector3(0.5, 1.0, 0.5), [mi])


# ── night ────────────────────────────────────────────────────────────────────

## The altar's two candlesticks, the eternal light on its chain in the presbytery, grave
## lanterns on the step before the rail, under St Prokop and under a Station, two plates
## of stubs (before the rail, before the first pew). All there by day too: the lamp and the
## lanterns burn day and night, the candles from the evening (_light_altar, _light_stubs).
func _lamps_and_candles(root: Node3D) -> void:
	var z0 := -D * 0.5 - ARCH_T
	var zb := z0 - PRES_D
	var top := PRES_Y + 0.98 + 0.03
	_altar_mid = Vector3(0, top + 0.4, zb + 0.3)
	if _exists("altar_candlestick"):
		var cs := _size("altar_candlestick", 0.62)
		var wick := _wick("altar_candlestick")
		for sx in [-0.52, 0.52]:
			var at := Vector3(float(sx), top, zb + 0.3)
			K.cutout(root, "altar_candlestick", cs, at, 0.0, false, "AltarCandle")
			_altar_tips.append(at + Vector3((wick.x - 0.5) * cs.x, (1.0 - wick.y) * cs.y - 0.02, 0.012))
	if _exists("sanctuary_lamp"):
		var ls := _size("sanctuary_lamp", 0.86)
		var x := 1.3
		var z := z0 - 0.8
		var y0 := PRES_Y + 2.05
		var lamp := K.cutout(root, "sanctuary_lamp", ls, Vector3(x, y0, z), 0.0, true, "EternalLight")
		var k := clampf(x / (PRES_W * 0.5), 0.0, 1.0)
		var vy := PRES_Y + PRES_WALL + sqrt(maxf(0.0, 1.0 - k * k)) * (PRES_CROWN - PRES_WALL)
		var hook := y0 + ls.y
		K.slab(root, Vector3(0.012, maxf(0.05, vy - hook), 0.012), Vector3(x, (vy + hook) * 0.5, z), K.surface("galvanized", 0.3, Color(0.44, 0.36, 0.22)), "Chain")
		# Its own flame in the red glass is all that lights it (the red light it throws
		# on the walls would only blaze it).
		var m := lamp.material_override as StandardMaterial3D
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var tint := Color(0.74, 0.5, 0.46)
		m.albedo_color = tint
		var glass := Vector3(x, y0 + ls.y * 0.3, z)
		var red := Color(0.95, 0.14, 0.08)
		_night_lights.append({"kind": "lamp", "phase": _rng.randf() * 6.0, "base": 0.32, "col": red, "mat": m, "tint": tint,
			"light": _night_light(root, glass + Vector3(0, -0.2, 0.5), red, 0.32, 4.0),
			"halo": _halo(root, glass + Vector3(0, 0, 0.04), 0.36, red)})
		_night_lights.append({"kind": "glow", "phase": 1.0, "col": red, "alpha": 0.14,
			"halo": _halo(root, glass + Vector3(0, 0, 0.06), 1.5, red, true)})
	if _exists("grave_lantern"):
		var gs := _size("grave_lantern", 0.21)
		var red := Color(1.0, 0.3, 0.14)
		for g in [[Vector3(-1.2, STEP, -D * 0.5 + 0.36), [-0.2, 0.02, 0.22]],
				[Vector3(-1.75, PRES_Y, zb + 0.34), [-0.13, 0.13]],
				[Vector3(-W * 0.5 + 0.22, 0.0, -1.95), [0.0]]]:
			var c: Vector3 = g[0]
			for dx in g[1]:
				var at := c + Vector3(float(dx), 0.0, absf(float(dx)) * 0.2)
				var ln := K.cutout(root, "grave_lantern", gs, at, 0.0, true, "GraveLantern")
				var m := ln.material_override as StandardMaterial3D
				m.emission_enabled = true
				m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				m.emission_texture = m.albedo_texture
				m.emission = Color(1.0, 0.55, 0.35)
				m.emission_energy_multiplier = 1.3
				_night_lights.append({"kind": "lantern", "phase": _rng.randf() * 6.0, "base": 1.0, "mat": m, "glow": 1.3, "col": red,
					"halo": _halo(root, at + Vector3(0, gs.y * 0.45, 0.03), 0.24, red)})
			_night_lights.append({"kind": "lantern", "phase": _rng.randf() * 6.0, "base": 0.3,
				"light": _night_light(root, c + Vector3(0, 0.3, 0.3), red, 0.3, 2.4)})
	# The stand's flames in the haze by the door, as bright as there are flames (_tick_night).
	var st: Dictionary = parts.get("stand", {})
	if not st.is_empty():
		_stand_glow = _halo(root, (st["at"] as Vector3) + Vector3(0, 1.15, -0.12), 2.2, Color(1.0, 0.6, 0.28), true)
	if _exists("candle_stubs"):
		var ss := _size("candle_stubs", 0.17)
		var wick := _wick("candle_stubs")
		for at in [Vector3(0.95, STEP, -D * 0.5 + 0.34), Vector3(-0.38, 0.0, float(ROWS[0]) - 0.5)]:
			K.cutout(root, "candle_stubs", ss, at, 0.0, true, "Stubs")
			_stub_tips.append(at + Vector3((wick.x - 0.5) * ss.x, (1.0 - wick.y) * ss.y - 0.008, 0.01))


## The altar's candles burning, and their light in the haze round the altar.
func _light_altar(root: Node3D) -> void:
	_altar_lit = true
	for tip in _altar_tips:
		_night_flame(root, tip, Vector2(0.05, 0.11), WARM, 0.5, 4.2, 0.42)
	_night_lights.append({"kind": "glow", "phase": 0.0, "col": WARM, "alpha": 0.1,
		"halo": _halo(root, _altar_mid + Vector3(0, 0.02, 0.25), 3.0, WARM, true)})


func _light_stubs(root: Node3D) -> void:
	_stubs_lit = true
	for tip in _stub_tips:
		_night_flame(root, tip, Vector2(0.03, 0.065), WARM, 0.28, 2.6, 0.3)


## A candle's flame at `tip` (the pictures of the stand's, in their steps), its light and
## its glow.
func _night_flame(root: Node3D, tip: Vector3, size: Vector2, col: Color, energy: float, reach: float, halo: float) -> void:
	var tex := "candle_flame_2" if _exists("candle_flame_2") else "votive_flame_0"
	var f := K.cutout(root, tex, size, tip, 0.0, true, "NightFlame")
	(f.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A flame stays a point of light through the haze from the far end of the nave.
	(f.material_override as StandardMaterial3D).disable_fog = true
	f.set_meta("retro_skip", true)
	_night_lights.append({"kind": "candle", "phase": _rng.randf() * 4.0, "base": energy, "flame": f, "col": col,
		"light": _night_light(root, tip + Vector3(0, size.y * 0.7, 0.4), col, energy, reach),
		"halo": _halo(root, tip + Vector3(0, size.y * 0.45, 0.02), halo, col)})


func _night_light(root: Node3D, at: Vector3, col: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.position = at
	root.add_child(l)
	return l


## A glow round a light in the dark: a flat disc turned to you, in a few hard rings (the
## Build way, no soft bloom), added on; `soft`: light in the haze, big and faint, its many
## steps going off into nothing, no disc to see.
func _halo(root: Node3D, at: Vector3, size: float, col: Color, soft := false) -> MeshInstance3D:
	if soft and _soft_tex == null:
		var si := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		for yy in 48:
			for xx in 48:
				var e := clampf(1.0 - Vector2(float(xx) - 23.5, float(yy) - 23.5).length() / 24.0, 0.0, 1.0)
				si.set_pixel(xx, yy, Color(1, 1, 1, floorf(e * e * (3.0 - 2.0 * e) * 10.0) / 10.0))
		_soft_tex = ImageTexture.create_from_image(si)
	if _halo_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for yy in 32:
			for xx in 32:
				var d := clampf(1.0 - Vector2(float(xx) - 15.5, float(yy) - 15.5).length() / 16.0, 0.0, 1.0)
				img.set_pixel(xx, yy, Color(1, 1, 1, floorf(d * d * 4.0) / 4.0))
		_halo_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.disable_fog = true
	m.albedo_texture = _soft_tex if soft else _halo_tex
	m.albedo_color = Color(col.r, col.g, col.b, 0.55)
	m.set_meta("retro_skip", true)
	var mi := MeshInstance3D.new()
	mi.name = "Halo"
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("retro_skip", true)
	root.add_child(mi)
	return mi


## The top of a picture's opaque part (a wick), as shares of its width and height.
func _wick(tex: String) -> Vector2:
	var t: Texture2D = load(CAMP + tex + ".png")
	var img: Image = t.get_image() if t != null else null
	if img == null:
		return Vector2(0.5, 0.0)
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	for y in img.get_height():
		var x0 := -1
		var x1 := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 >= 0:
			return Vector2((float(x0 + x1) * 0.5 + 0.5) / float(img.get_width()), float(y) / float(img.get_height()))
	return Vector2(0.5, 0.0)


## The lights: the sun's shafts and the moon's as much as the hour has of them, the
## candles' flames in their steps (with the draught bent and low like those on the stand),
## the eternal light slow and red, the lanterns breathing, the glows in the haze with them
## (their glows only in the dark); the moon behind the clouds.
func _tick_lights(step: float, gust: float) -> void:
	# Clouds going over the moon: its rays, their patches, their light and the dust in them
	# with it, slowly and in steps; behind rain hardly any.
	var ts := floorf(_t * 6.0) / 6.0
	_moon = 0.7 + 0.3 * (0.5 + 0.5 * sin(ts * 0.21 + 1.3)) * (0.5 + 0.5 * sin(ts * 0.093 + 0.4))
	if _rain:
		_moon *= 0.3
	var moon := _moon * _k
	for sh in _shafts:
		var much: float = moon if str(sh["kind"]) == "moon" else 1.0 - _k
		var node: MeshInstance3D = sh["node"]
		node.visible = much > 0.004
		var sc: Color = sh["col"]
		(node.material_override as StandardMaterial3D).albedo_color = sc * much * (1.0 - 0.8 * gust)
	for mp in _moon_pools:
		var ml = mp.get("light")
		if ml != null and is_instance_valid(ml):
			(ml as OmniLight3D).light_energy = float(mp["base"]) * moon
		var mm = mp.get("mat")
		if mm != null:
			var mc: Color = (mm as StandardMaterial3D).albedo_color
			(mm as StandardMaterial3D).albedo_color = Color(mc.r, mc.g, mc.b, float(mp["alpha"]) * moon)
	for dust in _moon_dust:
		if is_instance_valid(dust):
			((dust as CPUParticles3D).material_override as StandardMaterial3D).albedo_color = Color(0.72, 0.8, 1.0, moon)
	if _stand_glow != null and is_instance_valid(_stand_glow):
		var lit := mini(flames.size(), 6)
		_stand_glow.visible = _k > 0.01 and lit > 0
		(_stand_glow.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.6, 0.28, 0.03 * float(lit) * _k * (1.0 - 0.6 * gust))
	# By day what burns throws little of a light you could see.
	var day_low := lerpf(0.3, 1.0, _k)
	for nl in _night_lights:
		var ph := float(nl["phase"])
		var k := 1.0
		match str(nl["kind"]):
			"candle":
				var fi := int(step + ph * 3.0) % 4 if gust <= 0.0 else int(step) % 4
				var f = nl.get("flame")
				if f != null and is_instance_valid(f):
					var tex: Texture2D = _flame_pic(fi, gust)
					if tex != null:
						((f as MeshInstance3D).material_override as StandardMaterial3D).albedo_texture = tex
				k = (0.85 + 0.15 * float(fi % 2)) * (1.0 - 0.6 * gust)
			"lamp":
				var s1 := floorf(_t * 5.0)
				k = 0.84 + 0.1 * sin(s1 * 0.7 + ph) + 0.06 * sin(s1 * 2.9)
			"glow":
				var s3 := floorf(_t * 8.0)
				k = (0.86 + 0.14 * sin(s3 * 1.9 + ph)) * (1.0 - 0.5 * gust)
			_:
				var s2 := floorf(_t * 7.0)
				k = (0.82 + 0.18 * absf(sin(s2 * 1.3 + ph))) * (1.0 - 0.4 * gust)
		var l = nl.get("light")
		if l != null and is_instance_valid(l):
			(l as OmniLight3D).light_energy = float(nl["base"]) * k * day_low
		var h = nl.get("halo")
		if h != null and is_instance_valid(h):
			var c: Color = nl["col"]
			(h as MeshInstance3D).visible = _k > 0.01
			((h as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, float(nl.get("alpha", 0.55)) * k * _k)
		var m = nl.get("mat")
		if m != null:
			if nl.has("tint"):
				var t: Color = nl["tint"]
				(m as StandardMaterial3D).albedo_color = Color(t.r * (0.8 + 0.2 * k), t.g * (0.8 + 0.2 * k), t.b * (0.8 + 0.2 * k))
			else:
				(m as StandardMaterial3D).emission_energy_multiplier = float(nl.get("glow", 1.0)) * k * lerpf(0.45, 1.0, _k)


# ── sound ────────────────────────────────────────────────────────────────────

func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	room.add_child(p)
	_players.append(p)
	return p


func _sounds() -> void:
	_amb = _player(-20.0)
	_fx = _player(-12.0)
	_drip_snd = _player(-13.0)
	_loop(_amb, "chapel/room_tone.ogg", -19.0)
	_wind = _player(-27.0)
	_loop(_wind, "chapel/wind_gap.ogg", -27.0)
	if _rain:
		_rain_snd = _player(-24.0)
		_loop(_rain_snd, "weather/raininside.mp3", -24.0)
	_pigeons_t = _rng.randf_range(12.0, 40.0)
	_organ = _player(-17.0)
	_candle_amb = _player(-60.0)
	_loop(_candle_amb, "chapel/night_candles.ogg", -60.0)
	_night_t = _rng.randf_range(12.0, 34.0)


## How near you are to what burns, 0 far .. 1 beside it.
func _by_candles() -> float:
	var eye: Vector3 = room._cam.position
	var d := 99.0
	if _altar_lit:
		d = minf(d, eye.distance_to(_altar_mid))
	if not flames.is_empty():
		var at: Vector3 = (parts.get("stand", {}) as Dictionary).get("at", Vector3(1.55, 0.0, 5.05))
		d = minf(d, eye.distance_to(at + Vector3(0, 1.1, 0)))
	return clampf(1.0 - d / 7.0, 0.0, 1.0)


## In the quiet of the dark: the candles' crackle (louder beside them), now and then a beam
## ticking in the cold, wax beside the candles, a moth at the red glass under it.
func _tick_night_sound(delta: float) -> void:
	if _candle_amb == null:
		return
	var near := _by_candles()
	var want := -60.0 if _k < 0.05 or (flames.is_empty() and not _altar_lit) else lerpf(lerpf(-44.0, -25.0, _k), lerpf(-34.0, -16.0, _k), near)
	_candle_amb.volume_db = move_toward(_candle_amb.volume_db, want, 10.0 * delta)
	if _k < 0.5:
		return
	_night_t -= delta
	if _night_t > 0.0:
		return
	_night_t = _rng.randf_range(16.0, 48.0)
	var eye: Vector3 = room._cam.position
	if eye.z < -3.5 and _rng.randf() < 0.5:
		_fx_play("chapel/night_moth.mp3", -15.0)
	elif near > 0.35 and _rng.randf() < 0.6:
		_fx_play("chapel/night_wax.mp3", -14.0)
	else:
		_fx_play("chapel/night_beam.mp3", -16.0)


func _loop(p: AudioStreamPlayer, path: String, db: float) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	var s = load(SFX + path)
	if s is AudioStreamMP3:
		s = (s as AudioStreamMP3).duplicate()
		s.loop = true
	elif s is AudioStreamOggVorbis:
		s = (s as AudioStreamOggVorbis).duplicate()
		s.loop = true
	p.stream = s
	p.volume_db = db
	p.play()


func _fx_play(path: String, db: float) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	_fx.stream = load(SFX + path)
	_fx.volume_db = db
	_fx.play()


# ── each frame ───────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_t += delta
	var step := floorf(_t * 12.0)
	var gust := _gust()
	for i in flames.size():
		var f: Dictionary = flames[i]
		var node: MeshInstance3D = f["node"]
		if not is_instance_valid(node):
			continue
		# In the draught they all go with it, the same picture at the same moment, bent over.
		var k := int(step + float(f["phase"]) * 3.0) % 4 if gust <= 0.0 else int(step) % 4
		var tex: Texture2D = _flame_pic(k, gust)
		if tex != null:
			(node.material_override as StandardMaterial3D).albedo_texture = tex
		var e := (0.18 + 0.06 * float(k % 2)) * (1.0 - 0.75 * gust)
		(f["light"] as OmniLight3D).light_energy = e
		var h = f.get("halo")
		if h != null and is_instance_valid(h):
			(h as MeshInstance3D).visible = _k > 0.01
			((h as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.6, 0.28, e * 2.0 * _k)
	_tick_lights(step, gust)
	_tick_night_sound(delta)
	_hour_t -= delta
	if _hour_t <= 0.0:
		_hour_t = 0.5
		_follow_hour()
	if _rope != null and _rope_t > 0.0:
		_rope_t -= delta
		# The rope jerks up and down with the strokes, in steps.
		var swing := sin(floorf(_rope_t * 12.0) / 12.0 * 9.0) * 0.1 * minf(1.0, _rope_t)
		_rope.position.y = _rope_y + swing
		_rope.rotation.z = swing * 0.3
	for s in _shafts:
		_face_shaft(s)
	_tick_drip(delta)
	_tick_watcher(delta)
	_tick_saint(delta)
	_tick_sheet(delta)
	_tick_smoke(delta)
	# Nothing new begins behind the close-up: your eyes are on the stand.
	if _candle_cu == null or not _candle_cu.visible:
		_tick_stand(delta)
		_tick_organ(delta)
		_tick_draft(delta)
	_pigeons_t -= delta
	if _pigeons_t <= 0.0:
		_pigeons_t = _rng.randf_range(28.0, 75.0)
		if _k > 0.5:
			# The pigeons asleep; an owl up in the roof.
			_pigeons_t += 30.0
			_fx_play("life/owl_hoot.mp3", -21.0)
		else:
			_fx_play("chapel/pigeons.mp3", -15.0)
	if _breath_t > 0.0:
		_breath_t -= delta
		if _breath_t <= 0.0 and _looking == "confess":
			_fx_play("chapel/confession_breath.mp3", -14.0)


## The flames' pictures, read once: those of the close-up, bent over when the draught blows.
func _flame_pic(k: int, gust: float) -> Texture2D:
	if _flame_tex.is_empty():
		for i in 7:
			var path := CAMP + "candle_flame_%d.png" % i
			_flame_tex.append(load(path) if ResourceLoader.exists(path) else null)
		_old_flames = _flame_tex[2] == null
		if _old_flames:
			for i in 4:
				var old := CAMP + "votive_flame_%d.png" % i
				_flame_tex[i] = load(old) if ResourceLoader.exists(old) else null
	if _old_flames:
		return _flame_tex[k % 4]
	if gust > 0.3:
		return _flame_tex[5 if k % 3 != 0 else 6]
	return _flame_tex[2 + k % 3]


func _seen(p: Vector3) -> bool:
	return room._cam.is_position_in_frustum(p)


func _tick_drip(delta: float) -> void:
	if _drop == null:
		return
	if _drop_t >= 0.0:
		_drop_t += delta
		var top := vault_y(BUCKET.x) - 0.1
		var fall := 0.5 * 9.8 * _drop_t * _drop_t
		var stepped := floorf(fall * 4.0) / 4.0
		_drop.position = Vector3(BUCKET.x, top - stepped, BUCKET.z)
		if top - fall <= 0.3:
			_drop_t = -1.0
			_drop.visible = false
			var path := SFX + "chapel/drip_bucket.mp3"
			if not ResourceLoader.exists(path):
				path = SFX + "pipes/wetdrop.mp3"
			if ResourceLoader.exists(path):
				_drip_snd.stream = load(path)
				_drip_snd.pitch_scale = _rng.randf_range(0.92, 1.08)
				_drip_snd.play()
		return
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = _rng.randf_range(0.5, 1.0) if _rain else _rng.randf_range(1.6, 3.2)
		_drop_t = 0.0
		_drop.visible = true


## Somebody up in the loft, while you are not looking there; gone when you look again.
func _tick_watcher(delta: float) -> void:
	if _watcher == null:
		return
	var spot := Vector3(0, LOFT_Y + 1.0, LOFT_Z + 0.4)
	if _watch_on:
		var p := _watcher.position + Vector3(0, 1.2, 0)
		if _watch_sink >= 0.0:
			# Stepping back from the rail: down behind it, in steps.
			_watch_sink += delta
			_watcher.position.y = LOFT_Y - floorf(_watch_sink * 8.0) / 8.0 * 1.3
			if _watch_sink >= 1.0:
				_hide_watcher()
			return
		if _seen(p):
			_watch_seen += delta
			_watch_unseen = 0.0
			if _watch_seen > 3.2:
				_watch_sink = 0.0
				_fx_play("chapel/loft_creak.mp3", -14.0)
		else:
			_watch_unseen += delta
			if _watch_seen > 0.25 and _watch_unseen > 0.4:
				_hide_watcher()
				_fx_play("chapel/loft_creak.mp3", -17.0)
			elif _watch_seen <= 0.25 and _watch_unseen > 40.0:
				_hide_watcher()
		return
	if _seen(spot):
		_loft_unseen = 0.0
	else:
		_loft_unseen += delta
	_watch_roll -= delta
	if _watch_roll > 0.0:
		return
	_watch_roll = 3.0
	if _t < 15.0 or _watch_n >= 2 or _loft_unseen < 5.0 or _looking != "":
		return
	if _rng.randf() < 0.025 + 0.12 * _low():
		_watch_on = true
		_watch_n += 1
		_watch_seen = 0.0
		_watch_unseen = 0.0
		_watch_sink = -1.0
		_watcher.position = Vector3(_rng.randf_range(-2.3, 2.3), LOFT_Y, LOFT_Z + 0.4)
		if absf(_watcher.position.x - float(POSTS_X[0])) < 0.3 or absf(_watcher.position.x - float(POSTS_X[1])) < 0.3:
			_watcher.position.x *= 0.6
		_watcher.visible = true


func _hide_watcher() -> void:
	_watch_on = false
	_watch_sink = -1.0
	if _watcher != null:
		_watcher.visible = false


## St Prokop's head turned to you when you look back at him (not often, more the worse
## you are); turned back once you have seen it and looked away.
func _tick_saint(delta: float) -> void:
	if _saint == null or _saint_tex.size() < 2:
		return
	var p := _saint.position + Vector3(0, 0.6, 0)
	var m := _saint.material_override as StandardMaterial3D
	if _seen(p):
		if not _saint_turned and not _saint_done and _saint_unseen > 6.0 and _t > 10.0:
			if _rng.randf() < 0.05 + 0.25 * _low():
				_saint_turned = true
				m.albedo_texture = _saint_tex[1]
		_saint_unseen = 0.0
		if _saint_turned:
			_saint_seen += delta
	else:
		_saint_unseen += delta
		if _saint_turned and _saint_seen > 1.2 and _saint_unseen > 0.6:
			_saint_turned = false
			_saint_done = true
			m.albedo_texture = _saint_tex[0]


## The worse you are, the less the sheet keeps still: unseen a while, it is elsewhere.
func _tick_sheet(delta: float) -> void:
	if _sheet == null:
		return
	if _seen(_sheet.position + Vector3(0, 0.9, 0)):
		_sheet_unseen = 0.0
		return
	_sheet_unseen += delta
	if _sheet_unseen < 12.0 or _low() < 0.4:
		return
	_sheet_unseen = 0.0
	if _rng.randf() > 0.35 * _low():
		return
	var choices: Array = []
	for i in SHEET_SPOTS.size():
		var sp: Array = SHEET_SPOTS[i]
		if i != _sheet_at and not _seen((sp[0] as Vector3) + Vector3(0, 0.9, 0)):
			choices.append(i)
	if choices.is_empty():
		return
	_sheet_at = int(choices[_rng.randi_range(0, choices.size() - 1)])
	var to: Array = SHEET_SPOTS[_sheet_at]
	_sheet.position = to[0]
	_sheet.rotation_degrees.y = float(to[1])
	var hb = room._hot.get("sheet", {}).get("body")
	if hb != null:
		(hb as Node3D).position = (to[0] as Vector3) + Vector3(0, 0.9, 0)


## Every flame on the stand out at once while your back was to it, without a sound (more
## likely the worse you are, once a visit): you see it when you turn round, the threads
## of smoke still going up if you turn soon enough.
func _tick_stand(delta: float) -> void:
	if flames.is_empty() or _out_done:
		return
	var at: Vector3 = (parts.get("stand", {}) as Dictionary).get("at", Vector3(1.55, 0.0, 5.05))
	if _seen(at + Vector3(0, 1.1, 0)):
		_stand_unseen = 0.0
		return
	_stand_unseen += delta
	_out_roll -= delta
	if _out_roll > 0.0:
		return
	_out_roll = 6.0
	if _t < 20.0 or _stand_unseen < 8.0 or flames.size() < 2 or _looking != "":
		return
	_sanity = _read_sanity()
	if _rng.randf() < 0.008 + 0.09 * _low():
		_all_out()


func _all_out() -> void:
	_out_done = true
	for f in flames.duplicate():
		put_out(int((f as Dictionary).get("cup", -1)))


func _tick_smoke(delta: float) -> void:
	for s in _smokes.duplicate():
		var n: MeshInstance3D = s["node"]
		s["t"] = float(s["t"]) + delta
		if not is_instance_valid(n) or float(s["t"]) > 7.0:
			if is_instance_valid(n):
				n.queue_free()
			_smokes.erase(s)
			continue
		var tex := "candle_smoke_%d" % mini(2, int(float(s["t"]) / 2.4))
		if _exists(tex):
			(n.material_override as StandardMaterial3D).albedo_texture = load(CAMP + tex + ".png")


## The harmonium up in the presbytery: three slow notes, only when you are down at the far
## end of the nave from it, once a visit at most, nobody at it when you get there.
func _tick_organ(delta: float) -> void:
	_organ_roll -= delta
	if _organ_roll > 0.0:
		return
	_organ_roll = 9.0
	if _organ_n >= 1 or _t < 30.0 or _looking != "" or room._cam.position.z < 0.5:
		return
	_sanity = _read_sanity()
	if _rng.randf() < 0.01 + 0.1 * _low():
		_organ_n += 1
		_organ_notes()


func _organ_notes() -> void:
	if _organ == null or not ResourceLoader.exists(SFX + "chapel/candle_harmonium.mp3"):
		return
	_organ.stream = load(SFX + "chapel/candle_harmonium.mp3")
	_organ.play()


## How hard the draught is blowing now (0 none), in steps, twelve a second.
func _gust() -> float:
	if _draft_t < 0.0:
		return 0.0
	var k := clampf(_draft_t / DRAFT_SEC, 0.0, 1.0)
	var swell := sin(k * PI)
	var stepped := floorf(_draft_t * 12.0)
	var shake := 0.55 + 0.45 * sin(stepped * 2.3) * sin(stepped * 0.7)
	return clampf(swell * shake, 0.0, 1.0)


## A cold draught from the door: the low moan under it, the flames and the shafts of light
## flickering together, the dust carried up the nave, the bell's rope stirring.
func _tick_draft(delta: float) -> void:
	if _draft_t >= 0.0:
		_draft_t += delta
		if _draft_t >= DRAFT_SEC:
			_end_draft()
			return
		var g := _gust()
		if _wind != null:
			_wind.volume_db = -27.0 + 8.0 * g
		if _rope != null and _rope_t <= 0.0:
			_rope.rotation.z = sin(floorf(_draft_t * 12.0) / 12.0 * 2.4) * 0.05 * g
		return
	_draft_wait -= delta
	_draft_roll -= delta
	if _draft_roll > 0.0:
		return
	_draft_roll = 7.0
	if _draft_wait > 0.0 or _t < 14.0 or _looking != "":
		return
	_sanity = _read_sanity()
	if _rng.randf() < 0.012 + 0.07 * _low():
		_start_draft()


func _start_draft() -> void:
	_draft_t = 0.0
	_draft_wait = _rng.randf_range(80.0, 160.0)
	if _dust != null:
		_dust.gravity = Vector3(0, -0.004, -0.09)
	_fx_play("chapel/candle_draft.mp3", -13.0)


func _end_draft() -> void:
	_draft_t = -1.0
	if _wind != null:
		_wind.volume_db = -27.0
	if _dust != null:
		_dust.gravity = Vector3(0, -0.004, 0)
	if _rope != null and _rope_t <= 0.0:
		_rope.rotation.z = 0.0


# ── clicks ───────────────────────────────────────────────────────────────────

func click(id: String, hour: float) -> bool:
	if _walker != null and _walker.busy:
		return true
	if _looking != "":
		_unlook()
		return true
	if _sitting and id != "her":
		_stand_up()
		return true
	match id:
		"candles":
			_walker.go("candles", func(): _candles_close())
		"box", "rope":
			# By the door: within reach from there.
			var act := func():
				if id == "rope":
					_ring()
				elif CoreRoot.get_money() >= 1 and CoreRoot.actions.spend_money(1):
					_play("chapel/coin_box.mp3", -4.0)
			if _walker.here == "door":
				act.call()
			else:
				_walker.go("door", act)
		"her":
			_line += 1
			room.say("Mrs Hruba", HRUBA_LINES[_line % HRUBA_LINES.size()])
		"harmonium":
			_walker.go("altar", func():
				_play("chapel/harmonium.mp3", -8.0)
				_look_at("harmonium"))
		"pews_w", "pews_e":
			_walker.go("seat_w" if id == "pews_w" else "seat_e", func():
				_sitting = true
				_play("chapel/pew_creak.mp3", -8.0)
				room._look.pitch_down_deg = 20.0)
		"altar", "saint":
			_walker.go("rail", func(): _look_at(id))
		"confess":
			_walker.go("confess", func():
				_look_at("confess")
				# Behind the curtain, now and then, the worse you are: a breath.
				if _rng.randf() < 0.12 + 0.45 * _low():
					_breath_t = _rng.randf_range(1.2, 2.6))
		"stations", "window", "bucket", "sheet", "loft":
			_look_at(id)
		_:
			return false
	return true


## At the stand: the eye goes down to it (candle_closeup.gd). Tools have no hands to strike
## a match with (GESTURE.auto, the harnesses): the coin and the flame at once.
func _candles_close() -> void:
	if GESTURE.auto:
		_light_candle()
		return
	open_closeup()


func open_closeup() -> void:
	_make_closeup()
	_candle_cu.open_view()


func _make_closeup() -> void:
	if _candle_cu != null:
		return
	_candle_cu = CANDLE_CLOSEUP.new()
	room.add_child(_candle_cu)
	room.add_overlay(_candle_cu)
	_candle_cu.setup(self)


func _light_candle() -> void:
	if free_cups().is_empty() or CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
		_play("director/knock_wrong.mp3", -14.0)
		return
	_play("chapel/coin_box.mp3", -6.0)
	if lit_on_stand():
		room.get_tree().create_timer(0.45).timeout.connect(func(): _play("chapel/match.mp3", -6.0))


## One more flame burning here, for the other wardens too (candle_lit: town_trip sends it).
func lit_on_stand(cup := -1) -> bool:
	if not add_flame(cup):
		return false
	room._candles = flames.size()
	if room.has_signal("candle_lit"):
		room.candle_lit.emit(flames.size())
	return true


func _stand_up() -> void:
	_sitting = false
	room._look.pitch_down_deg = 34.0
	_play("chapel/pew_creak.mp3", -10.0)
	_walker.go("pews")


func _ring() -> void:
	if _rope_t > 0.0:
		return
	_rope_t = 2.4
	room.wants_closeup.emit("bell")


## The eye goes to the thing (narrower, turned to it); any click lets it go.
func _look_at(id: String) -> void:
	var body = room._hot.get(id, {}).get("body")
	if body == null:
		return
	var target: Vector3 = (body as Node3D).position
	if id == "loft" and _watch_on and _watcher != null:
		target = _watcher.position + Vector3(0, 1.3, 0)
	var eye: Vector3 = room._cam.position
	var d := target - eye
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	_looking = id
	_look_back = {"rot": room._base_rot, "fov": room._cam.fov}
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room, "_base_rot", Vector3(pitch, yaw, 0.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room._cam, "fov", clampf(66.0 * 2.4 / maxf(2.4, d.length()), 20.0, 56.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unlook() -> void:
	_looking = ""
	_breath_t = -1.0
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room, "_base_rot", _look_back.get("rot", Vector3.ZERO), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room._cam, "fov", float(_look_back.get("fov", 66.0)), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Esc: looking at something, let it go first; else out.
func wants_out() -> bool:
	if _looking != "":
		_unlook()
		return false
	if _walker != null:
		_walker.stop()
	_play("chapel/door.mp3", -10.0)
	return true


## The door clicked: from across the nave you walk back to it first, then out.
func walk_out() -> void:
	if _walker == null or _walker.busy:
		return
	if _looking != "":
		_unlook()
		return
	_sitting = false
	room._look.pitch_down_deg = 34.0
	if _walker.here == "door":
		_play("chapel/door.mp3", -10.0)
		room.close()
		return
	_walker.go("door", func():
		_play("chapel/door.mp3", -10.0)
		room.close())


## The other wardens: in the aisle under the loft, a little ahead of the door.
func place_mates(mates: Dictionary, ids: Array) -> void:
	var spots := [Vector3(0.75, 0.0, 3.55), Vector3(-0.8, 0.0, 2.95), Vector3(1.25, 0.0, 2.95)]
	var k := 0
	for id in ids:
		var fig = mates.get(int(id))
		if fig == null:
			continue
		fig.visible = true
		fig.show_at(spots[k % spots.size()], "stand")
		k += 1


func close() -> void:
	if _looking != "":
		room._cam.fov = float(_look_back.get("fov", 66.0))
	_looking = ""
	if _candle_cu != null and is_instance_valid(_candle_cu):
		_candle_cu.queue_free()
	_candle_cu = null
	if _walker != null:
		_walker.stop()
		_walker.free_all()
	for p in _players:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_players.clear()
	room._env.fog_enabled = false


func _play(path: String, db: float) -> void:
	room._play(SFX + path, db)


## Debug (tools/shot_driver.gd): the one in the loft now, St Prokop turned now.
func debug_watcher() -> void:
	if _watcher == null:
		return
	_watch_on = true
	_watch_seen = 0.0
	_watch_sink = -1.0
	_watcher.position = Vector3(0.7, LOFT_Y, LOFT_Z + 0.4)
	_watcher.visible = true


func debug_saint() -> void:
	if _saint != null and _saint_tex.size() > 1:
		_saint_turned = true
		(_saint.material_override as StandardMaterial3D).albedo_texture = _saint_tex[1]


## Debug: every flame out now, the three notes now, the draught now.
func debug_all_out() -> void:
	_all_out()


func debug_organ() -> void:
	_organ_notes()


func debug_draft() -> void:
	_start_draft()
