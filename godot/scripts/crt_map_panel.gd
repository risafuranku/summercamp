extends Control

signal status_changed(text: String, kind: int)
signal tool_canceled
signal submenu_close_requested
## What is under the cursor, for the status bar ("12:7  Tent").
signal hover_info(text: String)
## A click on a building with no tool in hand: {type, origin, footprint, root}, or {}
## when the click was on open ground (the card closes).
signal building_clicked(info: Dictionary)
## A guest clicked with no tool in hand (builder_module opens their card).
signal guest_clicked(guest_id: int)

const T = preload("res://scripts/os98/os_theme.gd")
const OS_KEYS = preload("res://scripts/os98/os_keys.gd")
const SAVE_CODEC = preload("res://scripts/save_codec.gd")
const WARDEN_LOOKS = preload("res://scripts/coop/warden_looks.gd")
const PATH_TILES = preload("res://scripts/path_tiles.gd")
## How wide a building is on the map, in tile widths: its 3D model's width plus depth over
## two (an isometric box is that wide on screen whichever way it is turned), measured from
## building_models.gd (a tile is 4 m). The drawn part of its picture (not the empty canvas
## round it, which differs from picture to picture) is fitted to that, so everything is
## to one scale: a gnome next to a pub, a caravan smaller than a cabin. Anything not here
## fills most of its footprint.
const ICON_SPAN := {
	"tent_1": 0.71, "tent_2": 0.8, "tent_3": 0.87, "cabin_1": 1.75, "cabin_2": 2.0, "cabin_3": 2.1,
	"caravan_1": 1.27, "caravan_2": 1.27, "caravan_3": 1.27, "toilet_block": 0.85, "shower_block": 1.02,
	"restaurant": 1.56, "pub": 1.69, "pub_2": 1.69, "corn_stand": 0.6, "bonfire": 0.95, "sports_field": 1.49,
	"lake_slide": 1.26, "playground": 1.28, "ping_pong": 0.54, "hammock": 0.45, "bench": 0.3, "picnic_table": 0.42,
	"flower_bed": 0.42, "gnome": 0.2, "mega_gnome": 0.9, "flagpole": 0.3, "lamp_iso": 0.24, "lamp_post": 0.24, "sewer": 0.7, "power_generator": 0.83, "vecerka_iso": 1.8,
	"staffroom": 1.6,
}
const SFX_DIR := "res://assets/sfx/builder/"

## Status severity, consumed by builder_module for colour + audio feedback.
const STATUS_INFO := 0
const STATUS_GOOD := 1
const STATUS_DENY := 2

const BG_COLOR := Color(0.03, 0.05, 0.04, 1.0)
const GRID_LINE := Color(0.0, 0.0, 0.0, 0.22)
## Forest floor: moss and needles, varied per tile so the map is not a chessboard.
const GROUND_A := Color(0.25, 0.33, 0.17)
const GROUND_B := Color(0.31, 0.31, 0.18)
const WATER := Color(0.13, 0.27, 0.36)
const DIRT := Color(0.44, 0.37, 0.25)
const EDGE_LEFT := Color(0.30, 0.22, 0.14)
const EDGE_RIGHT := Color(0.22, 0.16, 0.10)
## Buildings that smoke (fire or chimney).
const SMOKERS := {"bonfire": 1.0, "pub": 0.6, "pub_2": 0.6, "restaurant": 0.6, "cabin_2": 0.35, "cabin_3": 0.35}
const HOVER_FILL := Color(0.34, 0.64, 0.94, 0.22)
const HOVER_LINE := Color(0.72, 0.88, 1.0, 0.96)
const GHOST_OK_FILL := Color(0.20, 0.58, 0.96, 0.28)
const GHOST_OK_LINE := Color(0.60, 0.82, 1.0, 0.96)
const GHOST_BAD_FILL := Color(0.76, 0.24, 0.24, 0.24)
const GHOST_BAD_LINE := Color(0.98, 0.48, 0.48, 0.94)

const ZOOM_MIN := 0.50
## Close enough to read a tent's guy ropes (playtest 19. 10.: "builder má malej max zoom").
const ZOOM_MAX := 6.50
const KEYBOARD_PAN_SPEED := 360.0
const KEYBOARD_PAN_SPRINT_MULT := 1.7
const MAP_VISUAL_PADDING := 0.28
## The way the map is turned (RCT's four views, T or the toolbar): 0..3, each a quarter
## turn of the camp; the screen's bottom faces VIEW_NAMES[view_rot]. 1 is how it always
## stood. Remembered by the PC (builder_module).
var view_rot := 1
const VIEW_NAMES: Array[String] = ["south-east", "south-west", "north-west", "north-east"]

const ROTATION_LABELS: Array[String] = ["SOUTH", "EAST", "NORTH", "WEST"]

const ICON_PATHS := {
	"site_scaffold": "res://assets/textury/builder/site_scaffold.png",
	"rubble": "res://assets/textury/builder/rubble.png",
	"main_building": "res://assets/textury/builder/base.png",
	"tent_1": "res://assets/textury/builder/stan1.png",
	"cabin_1": "res://assets/textury/builder/chata1.PNG",
	"toilet_block": "res://assets/textury/builder/hajzly.PNG",
	"shower_block": "res://assets/textury/builder/sprchy.PNG",
	"pub": "res://assets/textury/builder/hospoda1.PNG",
	"restaurant": "res://assets/textury/builder/restaurace.PNG",
	"vecerka": "res://assets/textury/builder/vecerka.jpg",
	"bowling": "res://assets/textury/builder/iso_bowling.png",
	"sewer": "res://assets/textury/builder/sewer.PNG",
	"power_generator": "res://assets/textury/builder/gen.PNG",
	"path": "res://assets/textury/builder/parking.PNG",
	"lamp_post": "res://assets/textury/builder/gen.PNG",
	"tree": "res://assets/textury/builder/strom.png",
	"corn": "res://assets/textury/builder/iso_corn.png",
	"tent_2": "res://assets/textury/builder/stan2.png",
	"tent_3": "res://assets/textury/builder/stan3.png",
	"cabin_2": "res://assets/textury/builder/chata2.PNG",
	"cabin_3": "res://assets/textury/builder/chata3.PNG",
	"pub_2": "res://assets/textury/builder/hospoda2.png",
	"caravan_1": "res://assets/textury/builder/iso_caravan.png",
	"caravan_2": "res://assets/textury/builder/iso_caravan2.png",
	"caravan_3": "res://assets/textury/builder/iso_caravan3.png",
	"bench": "res://assets/textury/builder/iso_bench.png",
	"picnic_table": "res://assets/textury/builder/iso_picnic.png",
	"flower_bed": "res://assets/textury/builder/iso_flowerbed.png",
	"gnome": "res://assets/textury/builder/iso_gnome.png",
	"mega_gnome": "res://assets/textury/builder/iso_gnome.png",
	"flagpole": "res://assets/textury/builder/iso_flagpole.png",
	"playground": "res://assets/textury/builder/iso_playground.png",
	"ping_pong": "res://assets/textury/builder/iso_pingpong.png",
	"hammock": "res://assets/textury/builder/iso_hammock.png",
	"corn_stand": "res://assets/textury/builder/iso_corn_stand.png",
	"staffroom": "res://assets/textury/builder/iso_staffroom.png",
	"bonfire": "res://assets/textury/builder/iso_bonfire.png",
	"sports_field": "res://assets/textury/builder/iso_sports.png",
	"lake_slide": "res://assets/textury/builder/iso_slide.png",
	"vecerka_iso": "res://assets/textury/builder/iso_jednota.png",
	"lamp_iso": "res://assets/textury/builder/iso_lamp.png",
	# The spruce leaning in the wind (Grok bld_tree): left, upright, right, the top bent.
	"tree_sway_0": "res://assets/textury/builder/life/tree_0.png",
	"tree_sway_1": "res://assets/textury/builder/life/tree_1.png",
	"tree_sway_2": "res://assets/textury/builder/life/tree_2.png",
	"tree_sway_3": "res://assets/textury/builder/life/tree_3.png",
}

## The same buildings from behind (tools/artgen back_*): turned away from you (rotations
## 1 and 2 on this map) you see their back, not their door. Rotation 3 shows the front,
## 0 the front mirrored, 1 the back, 2 the back mirrored.
const ICON_BACK_PATHS := {
	"pub": "res://assets/textury/builder/back_pub.png",
	"vecerka_iso": "res://assets/textury/builder/back_jednota.png",
	"restaurant": "res://assets/textury/builder/back_bistro.png",
	"cabin_1": "res://assets/textury/builder/back_cabin1.png",
	"cabin_2": "res://assets/textury/builder/back_cabin2.png",
	"cabin_3": "res://assets/textury/builder/back_cabin3.png",
	"tent_1": "res://assets/textury/builder/back_tent1.png",
	"tent_2": "res://assets/textury/builder/back_tent2.png",
	"tent_3": "res://assets/textury/builder/back_tent3.png",
	"caravan_1": "res://assets/textury/builder/back_caravan.png",
	"caravan_2": "res://assets/textury/builder/back_caravan.png",
	"caravan_3": "res://assets/textury/builder/back_caravan.png",
	"toilet_block": "res://assets/textury/builder/back_toilets.png",
	"shower_block": "res://assets/textury/builder/back_showers.png",
}

## The camp's models face +Z (south) at a turn of 0, their door down-left on the map.
## Most pictures are drawn that way (the door on the left face) and are turned on by one
## step (a turn of 0 is the picture as drawn, 1 mirrored, 2 the back, 3 the back
## mirrored); these few are drawn with the door on the right face and keep the old turns.
## (Every building stood a quarter turn off: the pub's door where the 3D pub had a wall.)
const ICON_DOOR_RIGHT := {"shower_block": true, "caravan_1": true, "caravan_2": true, "caravan_3": true, "vecerka_iso": true}


func _view_steps(icon_key: String, rotation_steps: int) -> int:
	var rs := wrapi(rotation_steps, 0, 4)
	return rs if ICON_DOOR_RIGHT.has(icon_key) or ICON_NO_MIRROR.has(icon_key) else wrapi(rs + 3, 0, 4)


## The buildings as the camp's 3D models stand (playtest 20. 10.: the mirrored front and
## back pictures put doors where the 3D building had walls): each one drawn from its
## model from the four corners the map turns to (tools/iso_render.tscn), repainted by
## Grok and fitted back over the render (tools/artgen/iso_views.py). <type>_<s>.png, where
## s = the view plus the building's own turn, at VIEW_PX across a tile's width, with the
## point of the picture over the middle of its footprint (views.json). Pictures without
## them fall back to the old front and back ones above.
const VIEW_DIR := "res://assets/textury/builder/iso3d/"
const VIEW_PX := 128.0
const VIEW_TYPE := {"vecerka_iso": "vecerka", "lamp_iso": "lamp_post", "pub_2": "pub", "cabin": "cabin_1"}
var _views: Dictionary = {}   # "<type>_<s>" -> [texture, anchor, lit windows or null]
## Lodgings whose windows can light on the map: [static-layer centre, view, origin, type].
var _lit_spots: Array = []
var _window_lights: Node
## The map's small life: ducks, glints, moths, mice, ants, birds (map_life.gd).
var _life = preload("res://scripts/builder/map_life.gd").new()
var _lake_cells_f: Array = []
## What stands on the map with where it covers (static-layer rect) and how far forward it
## is: drawn again over a guest behind it, so the guests walk behind buildings and trees
## (RCT's), not over their roofs.
var _occ: Array = []
## The trees sway in a wind, in steps (the static layer drawn again three times a second
## while it blows, each tree a beat after its neighbour: a gust going across the map).
const SWAY_WIND := 0.35
var _sway_step := 0
var _swaying := false
## Flags waving: the flagpole's frames from its 3D flag in the wind (iso_views frames,
## <s>_f<k>), drawn on the dynamic layer, four a second (faster in a wind).
var _flags: Array = []        # [static centre, turn]
## The building site in its stages (Grok bld_stages: the foundation, the walls going up,
## the roof) and the little yellow bulldozer of a demolition (bld_dozer, Transport
## Tycoon's), with its dust (bld_dust); the old scaffold and plain dust without them.
const STAGE_TEX := "res://assets/textury/builder/site/stage_%d.png"
const DOZER_TEX := "res://assets/textury/builder/site/dozer_%d.png"
const DOZER_DUST := "res://assets/textury/builder/site/dust_%d.png"
var _stage_tex: Array = []
var _dozer_tex: Array = []
var _dozer_dust: Array = []
var _dozers: Array = []           # {a, b: cells, t, life}
var _site_stage: Dictionary = {}  # origin -> stage last heard


func _load_views() -> void:
	_views.clear()
	var f := FileAccess.open(VIEW_DIR + "views.json", FileAccess.READ)
	if f == null:
		return
	var index = JSON.parse_string(f.get_as_text())
	if not (index is Dictionary):
		return
	for key in index:
		var path := VIEW_DIR + str(key) + ".png"
		if ResourceLoader.exists(path):
			var a: Array = (index[key] as Dictionary).get("anchor", [0, 0])
			var win := VIEW_DIR + str(key) + "_win.png"
			_views[str(key)] = [load(path), Vector2(float(a[0]), float(a[1])), load(win) if ResourceLoader.exists(win) else null]


## `type`'s picture for a building turned `rot` on the map as it is turned now ([] if none).
func _view_of(icon_key: String, rot: int) -> Array:
	var t := str(VIEW_TYPE.get(icon_key, icon_key))
	return _views.get("%s_%d" % [t, wrapi(view_rot + rot, 0, 4)], [])


## The picture standing on the middle of its footprint (`center`, on the ground), at the
## map's scale; `squash` flattens it toward its foot (the bounce when it lands).
func _draw_view(view: Array, center: Vector2, tint: Color, tile_w: float, squash := 1.0) -> void:
	var tex: Texture2D = view[0]
	var k := tile_w / VIEW_PX
	var sz := tex.get_size() * k
	var top := center - (view[1] as Vector2) * k
	var bottom := top.y + sz.y
	_cv.draw_texture_rect(tex, Rect2(Vector2(top.x, bottom - sz.y * squash).floor(), Vector2(sz.x, sz.y * squash)), false, tint)


## A building's picture from one of the four sides (the card's turning view), or null.
func card_view(building_type: String, side: int) -> Texture2D:
	var t := str(VIEW_TYPE.get(building_type, building_type))
	var v: Array = _views.get("%s_%d" % [t, wrapi(side, 0, 4)], [])
	return v[0] if not v.is_empty() else null


## Turns the map a quarter (RCT's view): the same spot of the camp stays in the middle.
func rotate_view(step: int) -> void:
	if grid_manager == null:
		return
	var iso = _compute_iso_layout(int(grid_manager.grid_width), int(grid_manager.grid_height))
	var mid := _panel_to_cell_f(size * 0.5, iso)
	view_rot = wrapi(view_rot + (1 if step >= 0 else -1), 0, 4)
	_static_dirty = true
	_demolish_hatch_key = ""
	_pan_offset += size * 0.5 - _cell_iso(mid)
	_pan_vel = Vector2.ZERO
	_clamp_pan_offset_for_current_map()
	_emit_status("View from the %s." % VIEW_NAMES[view_rot])
	_play("turn_view", -9.0)
	queue_redraw()


## A point of the panel to the grid cell under it, fractional (the inverse of _cell_to_iso_f).
func _panel_to_cell_f(p: Vector2, iso: Dictionary) -> Vector2:
	var dlt: Vector2 = p - Vector2(iso.origin)
	var ua: float = dlt.x / (float(iso.tile_w) * 0.5)
	var vb: float = dlt.y / (float(iso.tile_h) * 0.5)
	var d := Vector2((ua + vb) * 0.5, (vb - ua) * 0.5)
	var gw := float(grid_manager.grid_width)
	var gh := float(grid_manager.grid_height)
	match wrapi(view_rot, 0, 4):
		1: return Vector2(gw - 1.0 - d.y, d.x)
		2: return Vector2(gw - 1.0 - d.x, gh - 1.0 - d.y)
		3: return Vector2(d.y, gh - 1.0 - d.x)
	return d


const ICON_NO_MIRROR := {
	"main_building": true,
	"tree": true,
	"corn": true,
	"path": true,
	"lamp_post": true,
	"lamp_iso": true,
	"sports_field": true,
}

var grid_manager
var building_manager

# Guests on the map, RollerCoaster Tycoon style: the camp's real agents, drawn as
# tiny people that walk the paths and vanish into buildings. guest_id -> state.
const GUEST_SHIRTS := {
	"quiet_guy": Color(0.42, 0.56, 0.30),
	"drunk": Color(0.86, 0.72, 0.26),
	"cheap_chick": Color(0.10, 0.09, 0.10),
	"tramp": Color(0.48, 0.34, 0.20),
	"family": Color(0.20, 0.45, 0.85),
	"picker": Color(0.70, 0.50, 0.70),
}
const GUEST_SKIN := Color(0.86, 0.66, 0.50)
var _guests: Dictionary = {}
var _guest_poll: float = 0.0
var _guest_time: float = 0.0
# The extra one. Now and then, in the evening, there is a guest on the map that
# nobody booked: standing still at the edge of the camp, facing the reception.
var _extra_guest_until: float = 0.0
var _extra_guest_cell: Vector2 = Vector2.ZERO
var _extra_guest_rng := RandomNumberGenerator.new()
var selected_building: String = ""
var hover_coord: Vector2i = Vector2i(-1, -1)
## The building whose card is open (outlined on the map), or (-1, -1).
var inspect_origin := Vector2i(-1, -1)
var inspect_footprint := Vector2i.ONE
## What the map shows over the camp: "" (nothing), "condition", "power", "rooms", "light".
var overlay := ""
const OVERLAYS := ["", "condition", "power", "rooms", "light"]
var _ov_data: Dictionary = {}     # building origin -> [value 0..1 or -1, label, colour]
var _ov_t := 0.0

var _zoom_level: float = 1.16
var _pan_offset: Vector2 = Vector2.ZERO
var _pan_dragging: bool = false
var _pan_drag_moved: bool = false
var _rmb_pressed_without_selection: bool = false

var _rotation_steps: int = 0
var _drawn_rects: Dictionary = {}        # texture instance id -> Rect2 of its drawn part

var _ghost_locked: bool = false
var _ghost_coord: Vector2i = Vector2i(-1, -1)

var _pending_build_wait: bool = false
var _pending_build_type: String = ""
var _pending_build_coord: Vector2i = Vector2i(-1, -1)
var _pending_build_rot: int = 0

## Paths are drawn as a line (RCT): press, drag an L out (the first move away from the
## start sets which leg comes first; Shift keeps it straight), see it priced, let go to
## build it all at once. Built tile by tile under the cursor it could not be drawn
## (playtest 18. 10.).
var _path_drag_active: bool = false
var _path_start := Vector2i(-1, -1)
var _path_end := Vector2i(-1, -1)
var _path_axis := -1                 # 0 along x first, 1 along y first, -1 not yet
var _path_line: Array = []           # [coord, kind]: PATH_NEW, PATH_HAVE, PATH_BLOCKED
const PATH_NEW := 0
const PATH_HAVE := 1
const PATH_BLOCKED := 2
## Sent on release and not answered yet (a co-op client hears back later).
var _path_batch: Dictionary = {}
## Small things built in a row by dragging (a line of benches, lamps, flower beds): the
## line while the button is down, then one build each, one price.
const ROW_TYPES := ["bench", "lamp_post", "flower_bed", "picnic_table", "gnome", "flagpole"]
var _row_drag := false
var _row_start := Vector2i(-1, -1)
var _row_press := Vector2.ZERO
var _row_line: Array = []        # [coord, ok]
var _row_batch: Dictionary = {}
var _row_cost := 0
var _row_built := 0
var _row_sending := false
var _path_batch_sending := false
var _batch_cells: Array = []
var _batch_cost := 0
var _batch_refused := 0
var _batch_short := 0
## The bulldozer's box priced by the authority, kept while the box stays the same.
var _demolish_sum_rect := Rect2i()
var _demolish_sum: Dictionary = {}
var _demolish_hatch := PackedVector2Array()
var _demolish_hatch_key := ""
var _demolish_removed: Array = []
## Undo (Ctrl+Z, the toolbar): what you built today, newest last; a path drag is one step.
## Taking it back pays the whole price back (it was a mistake, not a demolition).
var _undo: Array = []            # {type, coord, cost, group, day}
var _undo_group := 0

var _demolish_drag_active: bool = false
var _demolish_drag_start: Vector2i = Vector2i(-1, -1)
var _demolish_drag_end: Vector2i = Vector2i(-1, -1)
var _demolish_selection_active: bool = false
var _demolish_selection_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
var _pending_demolish_wait: bool = false
var _pending_demolish_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)

var _icon_cache: Dictionary = {}
var _economy_manager: Node = null
var _last_status: String = ""

# Feedback and life on the map.
var _time := 0.0
var _fx: Array = []            # {kind, cell: Vector2, t, life, text, color}
var _dropped: Dictionary = {}  # structure origin -> time placed (it drops in)
var _last_hover := Vector2i(-2, -2)
var _sfx_players: Array = []
var _night := 0.0              # 0 day .. 1 deep night, for the tint and the lamps

const GROUND_TEX_SUMMER := "res://assets/textury/world/grass_summer.png"
const GROUND_TEX_AUTUMN := "res://assets/textury/world/grass_autumn.png"
const GROUND_TEX_SNOW := "res://assets/textury/world/snow_ground.png"
## The layer being drawn on (see _draw).
var _cv: CanvasItem = self
var _static_layer: Control
var _dyn_layer: Control
var _static_dirty := true
var _static_tile_w := 0.0
var _static_origin := Vector2.ZERO
var _static_size := Vector2.ZERO
var _static_sig := ""
var _sig_t := 0.0
var _ground_tex: Texture2D
## The ground's meshes, made at one unit a tile (see _draw_ground).
const GROUND_SHADE_MAX := 1.34
var _ground_key := ""
var _ground_tex_mesh: ArrayMesh
var _ground_col_mesh: ArrayMesh
var _ground_lines := PackedVector2Array()
var _lake_lines := PackedVector2Array()
var _lake_units: Array = []     # [unit centre, hash]
## The puff a building lands with (Grok, tools/artgen/os_art.py); circles without it.
const DUST_TEX := "res://assets/textury/builder/dust.png"
## A build is a building site on the map for a moment before the building stands (the
## sim has it at once: this is only the picture): the scaffold, the workers hammering in
## steps, then the building with a thump. A demolition leaves a heap of rubble a while.
const WORKER_TEX := [
	"res://assets/textury/builder/site_worker_a.png",
	"res://assets/textury/builder/site_worker_a2.png",
	"res://assets/textury/builder/site_worker_b.png",
]
## Small things go up in a moment; a building takes longer the bigger it is.
const SITE_QUICK := ["bench", "lamp_post", "flower_bed", "gnome", "flagpole", "picnic_table", "hammock"]
const HAMMER_EVERY := 0.36
const RUBBLE_LIFE := 4.0
var _site_len: Dictionary = {}    # origin -> seconds the site stands
var _site_fp: Dictionary = {}     # origin -> footprint
var _site_done: Dictionary = {}   # origin -> true once the building stood up
var _rubble: Array = []           # {o, f, t}
## What the static layer last drew, by origin: [type, footprint] (rubble needs to know
## what went: the removal says only where).
var _known: Dictionary = {}
var _hammer_cd := 0.0
var _rubble_cd := 0.0
var _worker_tex: Array = WORKER_TEX.map(func(p): return load(p) if ResourceLoader.exists(p) else null)
var _worker_minis: Dictionary = {}
## The camp's weather and hour on the map, read each frame from the camp's own (main's
## state, weather_visuals' wind and storm flash; never worked out here).
const WX_RAIN_DROPS := {3: 70, 4: 140, 5: 220}
var _wx := {}
## What the guests think, from GuestManager's snapshot (a second old at most): the bubble
## over each (its worst need, or a good mood now and then).
const THINK_TEX := {
	"hunger": "res://assets/textury/builder/think_hunger.png", "bladder": "res://assets/textury/builder/think_toilet.png",
	"energy": "res://assets/textury/builder/think_sleepy.png", "hygiene": "res://assets/textury/builder/think_dirty.png",
	"safety": "res://assets/textury/builder/think_scared.png", "cold": "res://assets/textury/builder/think_cold.png",
	"happy": "res://assets/textury/builder/think_happy.png",
}
const THINK_NEED := 55.0
var _think_tex: Dictionary = {}
var _guest_minds: Dictionary = {}   # id -> {think, value}
## The map lies, rarely and never in a log (DESIGN §5j): for a frame, a tent nobody built
## beside the others (late in the day, at most once in a long while of the Builder open);
## one tile of the camp says something is buried there.
var _lie_at := 900.0               # Builder time of the next phantom
var _lie: Dictionary = {}          # {cell, until}
var _buried := Vector2i(-2, -2)
## Cheats' pictures (builder_module): KAREL the uncle's old camp, MOLE the buried tile.
var _karel_until := -1.0
var _mole_until := -1.0
var _mind_poll := 0.0
var _wx_drops: Array = []
var _dither: Array = []          # ordered-dither textures, 25/50/75 % ink
var _fog_tex: Texture2D          # the dust puff's shape in white (fog banks)
var _dust_tex: Texture2D = load(DUST_TEX) if ResourceLoader.exists(DUST_TEX) else null
var _water_cells: Array = []    # [centre on the static layer, hash]
var _smokers: Array = []        # [centre, strength, seed]
var _lights: Array = []         # [centre, type]
var _anim_entries: Array = []   # buildings still dropping in
var _zoom_target := 1.16
var _zoom_anchor := Vector2.ZERO
var _zoom_settle := 0.0
var _pan_vel := Vector2.ZERO
var _last_pan_motion := 0.0
## The site in miniature, top right (RCT's map window): a pixel a tile, rebuilt with the
## static layer, the view's outline on it; click it to go there.
var _mini_img: Image
## Construction feedback: the wave, the local grid, outlines, ripples (builder_fx.gd).
var _bfx = preload("res://scripts/builder_fx.gd").new()
## The hidden 3D view (scripts/builder/map3d.gd, made by builder_module): while it shows
## the map, point <-> cell, guests, centring, pan and zoom go through it.
var map3d = null
## Builder's camera with legs: WASD pans as the arrows do (builder_module sets it each frame).
var wasd := false
## Guest miniatures: archetype -> {height px: ImageTexture}, scaled once from the sprites.
var _guest_minis: Dictionary = {}
var _mini_tex: ImageTexture
var _mini_rect := Rect2()
const MINI_PX := 3.0
const MINI_COLORS := {
	"grass": Color(0.30, 0.42, 0.20), "lake": Color(0.16, 0.34, 0.52), "reserved": Color(0.55, 0.46, 0.30),
	"tree": Color(0.12, 0.26, 0.12), "corn": Color(0.74, 0.62, 0.26), "path": Color(0.80, 0.68, 0.46),
	"housing": Color(0.92, 0.56, 0.20), "services": Color(0.40, 0.78, 0.92), "fun": Color(0.95, 0.35, 0.30),
	"utility": Color(0.62, 0.62, 0.66), "office": Color(1.0, 1.0, 1.0),
}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	mouse_exited.connect(_on_mouse_exited)
	_static_layer = Control.new()
	_static_layer.name = "StaticLayer"
	_static_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_static_layer.draw.connect(_draw_static)
	add_child(_static_layer)
	# A Control is culled by its own rect (0,0,size). With size 0 that was a point at the
	# layer's position: a zoom-in moves the layer up-left past the panel's corner and the
	# whole map was culled until it was redrawn (playtest: "the textures disappear for a
	# second on every zoom"). Big enough to always meet the screen.
	_static_layer.size = Vector2(100000, 100000)
	_dyn_layer = Control.new()
	_dyn_layer.name = "DynamicLayer"
	_dyn_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dyn_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dyn_layer.draw.connect(_draw_dynamic)
	_dyn_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_dyn_layer)
	_zoom_target = _zoom_level
	if EventBus.has_signal("building_placed"):
		EventBus.building_placed.connect(_on_world_placed)
	if EventBus.has_signal("building_removed"):
		EventBus.building_removed.connect(_on_world_removed)
	_preload_icons()
	_load_views()
	_load_peeps()
	for i in 3:
		if ResourceLoader.exists(STAGE_TEX % i):
			_stage_tex.append(load(STAGE_TEX % i))
	for i in 8:
		if ResourceLoader.exists(DOZER_TEX % i):
			_dozer_tex.append(load(DOZER_TEX % i))
	for i in 4:
		if ResourceLoader.exists(DOZER_DUST % i):
			_dozer_dust.append(load(DOZER_DUST % i))
	_connect_event_bus()
	_emit_status("Select a tool to begin.")


func _on_world_placed(id: String, o: Vector2i, f: Vector2i, _r: int) -> void:
	_static_dirty = true
	_demolish_sum = {}
	_demolish_hatch_key = ""
	if id == "path" and _path_batch.has(o):
		return
	if id != "tree" and id != "corn" and is_visible_in_tree():
		_bfx.built(_footprint_cells(o, f))
		if id != "path":
			_start_site(id, o, f)


func _on_world_removed(o: Vector2i) -> void:
	_static_dirty = true
	_demolish_sum = {}
	_demolish_hatch_key = ""
	if is_visible_in_tree() and _known.has(o):
		_leave_rubble(o, _known[o])
	if _pending_demolish_wait:
		_demolish_removed.append(o)
		return
	if is_visible_in_tree():
		_bfx.built([o], true)


func _start_site(id: String, o: Vector2i, f: Vector2i) -> void:
	var area := maxi(1, f.x * f.y)
	_site_len[o] = 1.1 if SITE_QUICK.has(id) else clampf(1.8 + 0.45 * float(area), 2.2, 4.0)
	_site_fp[o] = f
	_site_done.erase(o)
	_dropped[o] = _time
	# An upgrade takes the old one down first: no rubble under the new site.
	_rubble = _rubble.filter(func(r): return r["o"] != o)
	_static_dirty = true
	if _hammer_cd <= 0.0:
		_play("hammer", -9.0)
		_hammer_cd = 1.25


func _leave_rubble(o: Vector2i, known: Array) -> void:
	var t := str(known[0])
	if t == "" or t == "path" or t == "lamp_post":
		return
	_rubble.append({"o": o, "f": known[1], "t": _time})
	if _rubble_cd <= 0.0:
		_play("rubble", -7.0)
		_rubble_cd = 0.8


## The sites going up (a blow now and then, dust; done: the thump) and the rubble going.
func _tick_sites(delta: float, quiet := false) -> void:
	_hammer_cd -= delta
	_rubble_cd -= delta
	var busy := false
	for o in _dropped.keys():
		var age := _time - float(_dropped[o])
		var site := float(_site_len.get(o, 0.0))
		var f: Vector2i = _site_fp.get(o, Vector2i.ONE)
		var mid := Vector2(o) + Vector2(f - Vector2i.ONE) * 0.5
		if age < site:
			busy = true
			if int(age / HAMMER_EVERY) != int(maxf(0.0, age - delta) / HAMMER_EVERY) and randf() < 0.4:
				_add_fx("dust", mid + Vector2(0.3, 0.3), 0.45)
			# Each stage of the site has its sound: the concrete, the planks, the roof.
			var stage := clampi(int(age / maxf(site, 0.01) * 3.0), 0, 2)
			if site > 1.5 and not quiet and int(_site_stage.get(o, -1)) != stage:
				_site_stage[o] = stage
				_play(["site_found", "site_walls", "site_roof"][stage], -13.0)
		elif site > 0.0 and not _site_done.has(o):
			_site_done[o] = true
			if not quiet:
				for k in 5:
					_add_fx("dust", mid + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)), 0.7)
				_play("site_done", -8.0)
		if age > site + 0.5:
			_dropped.erase(o)
			_site_stage.erase(o)
			_site_len.erase(o)
			_site_fp.erase(o)
			_site_done.erase(o)
	if busy and _hammer_cd <= 0.0 and not quiet:
		_play("hammer", -10.0)
		_hammer_cd = 1.25
	for i in range(_rubble.size() - 1, -1, -1):
		if _time - float(_rubble[i]["t"]) > RUBBLE_LIFE:
			_rubble.remove_at(i)


## The scaffold as wide as the building will be, the workers by its front corner: one
## hammering (the blow every HAMMER_EVERY), the other bobbing on his own beat.
func _draw_site(center: Vector2, fp: Vector2i, age: float, tile_w: float, tile_h: float, site := 3.0) -> void:
	if _stage_tex.size() == 3 and site > 1.5:
		# The foundation, the walls going up, the roof: a third of the time each.
		var tex: Texture2D = _stage_tex[clampi(int(age / maxf(site, 0.01) * 3.0), 0, 2)]
		var used := _drawn_rect(tex)
		var span := float(fp.x + fp.y) * 0.48
		var k := span * tile_w / maxf(1.0, used.size.x)
		var foot := center.y + span * tile_h * 0.5
		var mid_x := (used.position.x + used.size.x * 0.5) * k
		_cv.draw_texture_rect(tex, Rect2(Vector2(center.x - mid_x, foot - used.end.y * k).floor(), tex.get_size() * k), false)
	else:
		_draw_building_icon(center, fp, "site_scaffold", 0, Color.WHITE, tile_w, tile_h)
	var mini_h := clampi(int(round(tile_h * 1.1 / 4.0)) * 4, 12, 56)
	var wh := maxi(8, int(round(mini_h * 0.85)))
	var down := float(fp.x + fp.y) * tile_h * 0.18
	var blow := fmod(age, HAMMER_EVERY) < 0.12
	var a: Texture2D = _worker_mini(1 if blow else 0, wh)
	if a != null:
		var at := center + Vector2(-tile_w * 0.28 * float(fp.y), down)
		_cv.draw_texture(a, (at - Vector2(a.get_width() * 0.5, a.get_height())).floor())
	if fp.x + fp.y > 2:
		var b: Texture2D = _worker_mini(2, maxi(8, int(round(wh * 0.85))))
		if b != null:
			var bob := -1.0 if fmod(age + 0.17, HAMMER_EVERY) < 0.12 else 0.0
			var bt := center + Vector2(tile_w * 0.28 * float(fp.x), down)
			_cv.draw_texture(b, (bt - Vector2(b.get_width() * 0.5, b.get_height() - bob)).floor())


func _worker_mini(i: int, h: int) -> Texture2D:
	var key := "%d|%d" % [i, h]
	if not _worker_minis.has(key):
		var src: Texture2D = _worker_tex[i] if i < _worker_tex.size() else null
		_worker_minis[key] = _mini_of(src, h) if src != null else null
	return _worker_minis[key]


func _footprint_cells(o: Vector2i, f: Vector2i) -> Array:
	var out: Array = []
	for y in range(maxi(1, f.y)):
		for x in range(maxi(1, f.x)):
			out.append(o + Vector2i(x, y))
	return out


## Grid cell (fractional) to the panel, as the map stands now.
func _cell_iso(c: Vector2) -> Vector2:
	var iso = _compute_iso_layout(int(grid_manager.grid_width), int(grid_manager.grid_height))
	return _cell_to_iso_f(c, iso.origin, iso.tile_w, iso.tile_h)


func setup(new_grid_manager, new_building_manager) -> void:
	grid_manager = new_grid_manager
	building_manager = new_building_manager
	_static_dirty = true
	queue_redraw()


func set_selected_building(new_type: String) -> void:
	var normalized = new_type.strip_edges()
	selected_building = normalized
	if _turns_round_only(selected_building) and _rotation_steps % 2 == 1:
		_rotation_steps -= 1
	_ghost_locked = false
	_ghost_coord = Vector2i(-1, -1)
	_pending_build_wait = false
	_pending_build_type = ""
	_pending_build_coord = Vector2i(-1, -1)
	_path_drag_active = false
	_path_line.clear()
	_demolish_drag_active = false
	_pending_demolish_wait = false
	if selected_building != "demolish":
		_demolish_selection_active = false
	if selected_building == "":
		_emit_status("Selection cleared.")
	else:
		_emit_status("Selected: %s" % _display_name(selected_building))
	queue_redraw()


func rotate_selected_building(step: int) -> void:
	_rotate_building(step)


func apply_zoom_step(direction: int) -> void:
	if _in_3d():
		map3d.zoom_step(direction, get_local_mouse_position())
		return
	var local := get_local_mouse_position()
	_zoom_anchor = local if Rect2(Vector2.ZERO, size).has_point(local) else size * 0.5
	var old := _zoom_target
	if direction > 0:
		_zoom_target = clampf(_zoom_target * 1.18, ZOOM_MIN, ZOOM_MAX)
	elif direction < 0:
		_zoom_target = clampf(_zoom_target / 1.18, ZOOM_MIN, ZOOM_MAX)
	if absf(old - _zoom_target) > 0.001:
		_ghost_locked = false
		_emit_status("Zoom: %d%%" % int(round(_zoom_target * 100.0)))


func _process(delta: float) -> void:
	_update_keyboard_pan(delta)
	if not is_visible_in_tree():
		# On another tab the sites still go up (the build was paused till you came back).
		_time += delta
		_tick_sites(delta, true)
		return
	_time += delta
	_bfx.tick(delta)
	_tick_sites(delta)
	_life.tick(delta, self)
	for i in range(_dozers.size() - 1, -1, -1):
		_dozers[i]["t"] = float(_dozers[i]["t"]) + delta
		if float(_dozers[i]["t"]) >= float(_dozers[i]["life"]):
			_dozers.remove_at(i)
	_read_weather()
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i]["t"] = float(_fx[i]["t"]) + delta
		if float(_fx[i]["t"]) >= float(_fx[i]["life"]):
			_fx.remove_at(i)
	_night = _night_amount()
	if overlay != "":
		_ov_t -= delta
		if _ov_t <= 0.0:
			_ov_t = 1.0
			_refresh_overlay()
	_update_guests(delta)
	var local = get_local_mouse_position()
	if local.x >= 0.0 and local.y >= 0.0 and local.x <= size.x and local.y <= size.y:
		hover_coord = _local_to_grid(local)
	elif not _path_drag_active and not _demolish_drag_active:
		hover_coord = Vector2i(-1, -1)
	if hover_coord != _last_hover:
		_last_hover = hover_coord
		hover_info.emit(_describe(hover_coord))
		if selected_building != "":
			_bfx.point_at(hover_coord)
	if map3d != null and map3d.covers():
		return
	_update_zoom(delta)
	_update_inertia(delta)
	_update_static(delta)
	_dyn_layer.queue_redraw()


func _in_3d() -> bool:
	return map3d != null and map3d.on


## The 3D view over the map or not: its own two layers rest under it.
func set_3d_layers(on3d: bool) -> void:
	_static_layer.visible = not on3d
	_dyn_layer.visible = not on3d
	_static_dirty = true
	_demolish_hatch_key = ""


## The 3D view going out (scripts/builder/map3d.gd): the map at the ground it looked at
## (`cell`, fractional), at the scale it saw (`ext`: the metres its height covered).
func match_view(cell: Vector2, ext: float) -> void:
	if grid_manager == null:
		return
	var gw := int(grid_manager.grid_width)
	var gh := int(grid_manager.grid_height)
	var iso = _compute_iso_layout(gw, gh)
	var want := size.y * float(grid_manager.tile_size) * sqrt(2.0) / maxf(1.0, ext)
	_zoom_level = clampf(_zoom_level * want / maxf(1.0, float(iso.tile_w)), ZOOM_MIN, ZOOM_MAX)
	_zoom_target = _zoom_level
	iso = _compute_iso_layout(gw, gh)
	_pan_offset += size * 0.5 - _cell_to_iso_f(cell, iso.origin, iso.tile_w, iso.tile_h)
	_pan_vel = Vector2.ZERO
	_clamp_pan_offset_for_current_map()
	_static_dirty = true
	_demolish_hatch_key = ""
	queue_redraw()


## The arrow keys pan (not WASD: at the PC S stands you up and D leans you out).
func _update_keyboard_pan(delta: float) -> void:
	if delta <= 0.0 or not is_visible_in_tree() or not OS_KEYS.here(self):
		return
	# The camera with legs pans wherever the pointer is (on the toolbar, a card).
	if not wasd and not has_focus() and not _mouse_inside():
		return
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or (wasd and Input.is_physical_key_pressed(KEY_A)):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or (wasd and Input.is_physical_key_pressed(KEY_D)):
		move.x += 1.0
	if Input.is_key_pressed(KEY_UP) or (wasd and Input.is_physical_key_pressed(KEY_W)):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or (wasd and Input.is_physical_key_pressed(KEY_S)):
		move.y += 1.0
	if move.length_squared() <= 0.0001:
		return
	move = move.normalized()
	var speed = KEYBOARD_PAN_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= KEYBOARD_PAN_SPRINT_MULT
	if _in_3d():
		map3d.key_pan(move, speed * delta)
		return
	_pan_offset -= move * speed * delta
	_clamp_pan_offset_for_current_map()


func _gui_input(event: InputEvent) -> void:
	if grid_manager == null:
		return
	if map3d != null and map3d.take_input(event):
		accept_event()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			# R turns the building (Q and E are the PC's: the user 21. 10.).
			KEY_R:
				_rotate_building(1)
				get_viewport().set_input_as_handled()
				return
			KEY_EQUAL, KEY_KP_ADD:
				apply_zoom_step(1)
				get_viewport().set_input_as_handled()
				return
			KEY_MINUS, KEY_KP_SUBTRACT:
				apply_zoom_step(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
				get_viewport().set_input_as_handled()
				return
			KEY_Z:
				if event.ctrl_pressed:
					undo_last()
					get_viewport().set_input_as_handled()
					return
			KEY_ENTER, KEY_KP_ENTER:
				if selected_building == "demolish" and _demolish_selection_active and not _pending_demolish_wait:
					_send_demolish_request(_demolish_selection_rect)
					get_viewport().set_input_as_handled()
					return
			KEY_SHIFT:
				if _path_drag_active:
					_path_end = Vector2i(-1, -1)
					_request_path_at(get_local_mouse_position())

	if event is InputEventMouseMotion:
		if _pan_dragging:
			if event.relative.length_squared() > 0.08:
				_pan_drag_moved = true
			if _in_3d():
				map3d.pan_by(event.position, event.relative)
			else:
				_pan_offset += event.relative
				var now := Time.get_ticks_msec() / 1000.0
				var dt := clampf(now - _last_pan_motion, 1.0 / 240.0, 0.1)
				_last_pan_motion = now
				_pan_vel = _pan_vel.lerp(event.relative / dt, 0.4)
				_clamp_pan_offset_for_current_map()
		if _path_drag_active:
			_request_path_at(event.position)
		if _row_drag:
			_update_row(_local_to_grid(event.position))
		if _demolish_drag_active:
			_update_demolish_drag(event.position)
		hover_coord = _local_to_grid(event.position)
		queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			apply_zoom_step(1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			apply_zoom_step(-1)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_pan_dragging = true
				_pan_drag_moved = false
				_pan_vel = Vector2.ZERO
				_rmb_pressed_without_selection = selected_building == ""
				# Only the line or the box being drawn goes; the tool stays in hand (the
				# right button pans: it put the tool away on every pan). The tool goes with
				# a second click on its button or card.
				if _path_drag_active or _demolish_drag_active or _row_drag:
					_path_drag_active = false
					_path_line.clear()
					_row_drag = false
					_row_line.clear()
					_demolish_drag_active = false
					_emit_status("Canceled.")
			else:
				if not _pan_drag_moved and _rmb_pressed_without_selection and selected_building == "" and not _any_pending_interaction():
					submenu_close_requested.emit()
					_emit_status("Submenu closed.")
				elif not _pan_drag_moved and not _rmb_pressed_without_selection and selected_building != "" and not _any_pending_interaction():
					# A right click that did not drag puts the tool away (a drag pans and keeps it).
					_cancel_tool_selection()
				_pan_dragging = false
				_rmb_pressed_without_selection = false
				# Let go after a pause: no throw.
				if Time.get_ticks_msec() / 1000.0 - _last_pan_motion > 0.08:
					_pan_vel = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _minimap_click(event.position):
				get_viewport().set_input_as_handled()
				return
			if event.pressed:
				grab_focus()
				_handle_left_press(event.position)
			else:
				if _path_drag_active:
					_end_path_drag()
				if _row_drag:
					_end_row()
				if _demolish_drag_active:
					_finish_demolish_drag()
			queue_redraw()
			get_viewport().set_input_as_handled()
			return


func _handle_left_press(local_pos: Vector2) -> void:
	if selected_building == "":
		# No tool in hand: a click on a guest opens theirs, on a building its card.
		var gid := guest_at(local_pos)
		if gid >= 0:
			guest_clicked.emit(gid)
			_play("click", -12.0)
			return
		var info := structure_at(_local_to_grid(local_pos))
		inspect_origin = info.get("origin", Vector2i(-1, -1))
		inspect_footprint = info.get("footprint", Vector2i.ONE)
		building_clicked.emit(info)
		if not info.is_empty():
			_play("click", -12.0)
		return
	if selected_building == "path":
		_begin_path_drag(local_pos)
		return
	if selected_building == "demolish":
		_begin_demolish_press(local_pos)
		return
	if ROW_TYPES.has(selected_building) and _get_footprint(selected_building) == Vector2i.ONE:
		var c0 := _local_to_grid(local_pos)
		if _is_valid_coord(c0):
			_row_drag = true
			_row_start = c0
			_row_press = local_pos
			_update_row(c0)
			return
	_handle_structure_press(local_pos)


## The row from where the button went down to here, along the longer way; each tile
## fits or not.
func _update_row(coord: Vector2i) -> void:
	if not _is_valid_coord(coord):
		return
	var d := coord - _row_start
	var end := Vector2i(coord.x, _row_start.y) if absi(d.x) >= absi(d.y) else Vector2i(_row_start.x, coord.y)
	_row_line.clear()
	var step := (end - _row_start).sign()
	var p := _row_start
	while true:
		_row_line.append([p, _can_place(p, Vector2i.ONE, selected_building)])
		if p == end:
			break
		p += step
	var n := _row_line.filter(func(e): return bool(e[1])).size()
	if _row_line.size() > 1:
		_emit_status("%s: %d, $%d. Let go to build." % [_display_name(selected_building), n, n * _get_cost(selected_building)])


func _end_row() -> void:
	_row_drag = false
	var todo: Array = _row_line.filter(func(e): return bool(e[1])).map(func(e): return e[0])
	var one := _row_line.size() <= 1
	_row_line.clear()
	if one:
		# No drag: the one thing where it was clicked, as always.
		_handle_structure_press(_row_press)
		return
	if todo.is_empty():
		_emit_status("Nothing to build: the row is blocked.", STATUS_DENY)
		_deny_fx(_row_start, "Blocked")
		return
	var cost := _get_cost(selected_building)
	var n := todo.size() if cost <= 0 else mini(todo.size(), int(CoreRoot.get_money()) / cost)
	if n <= 0:
		_emit_status("Not enough money: %s costs $%d." % [_display_name(selected_building), cost], STATUS_DENY)
		_deny_fx(todo[0], "$%d" % cost)
		return
	_undo_group += 1
	_row_batch.clear()
	_row_cost = 0
	_row_built = 0
	for i in n:
		_row_batch[todo[i]] = selected_building
	_row_sending = true
	for i in n:
		EventBus.RequestBuild.emit(selected_building, todo[i], _rotation_steps)
	_row_sending = false
	if _row_batch.is_empty():
		_flush_row()


func _flush_row() -> void:
	if _row_built <= 0:
		_emit_status("Refused: nothing built.", STATUS_DENY)
		return
	_emit_status("Built %d, $%d." % [_row_built, _row_cost], STATUS_GOOD)
	_play("place", -10.0)


func _handle_structure_press(local_pos: Vector2) -> void:
	_undo_group += 1
	if _pending_build_wait:
		_emit_status("Awaiting build confirmation...")
		return
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		if _ghost_locked:
			_ghost_locked = false
			_emit_status("Placement canceled.")
		return

	# One click builds, as in every tycoon game since 1994; the preview under the
	# cursor already says where, which way and whether it fits.
	var footprint = _get_footprint(selected_building)
	if not _can_place(coord, footprint, selected_building):
		_emit_status("%s does not fit here." % _display_name(selected_building), STATUS_DENY)
		_deny_fx(coord, "Blocked")
		return
	if not _has_money(selected_building):
		_emit_status("Not enough money: %s costs $%d." % [_display_name(selected_building), _get_cost(selected_building)], STATUS_DENY)
		_deny_fx(coord, "$%d" % _get_cost(selected_building))
		return
	_send_build_request(selected_building, coord, _rotation_steps)


func _begin_path_drag(local_pos: Vector2) -> void:
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		return
	_undo_group += 1
	_path_drag_active = true
	_path_start = coord
	_path_end = Vector2i(-1, -1)
	_path_axis = -1
	_request_path_at(local_pos)


## The drag moved: the line from the start to here, each tile priced or refused.
func _request_path_at(local_pos: Vector2) -> void:
	if not _path_drag_active:
		return
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		return
	var straight := Input.is_key_pressed(KEY_SHIFT)
	if coord == _path_end and not (straight and _path_axis != -1):
		return
	_path_end = coord
	var d: Vector2i = coord - _path_start
	if d == Vector2i.ZERO:
		_path_axis = -1
	elif _path_axis == -1:
		_path_axis = 0 if absi(d.x) >= absi(d.y) else 1
	_path_line.clear()
	for c in _path_cells(_path_start, coord, _path_axis, straight):
		var kind := PATH_NEW
		if _path_cell(c):
			kind = PATH_HAVE
		elif not _can_place(c, Vector2i.ONE, "path"):
			kind = PATH_BLOCKED
		_path_line.append([c, kind])
	var n := _path_count(PATH_NEW)
	if n > 0:
		_emit_status("Path: %d new %s, $%d. Let go to build." % [n, "tile" if n == 1 else "tiles", n * _get_cost("path")])


## Start to end along one axis, then the other (the corner where they meet); straight
## keeps only the longer leg.
func _path_cells(a: Vector2i, b: Vector2i, axis: int, straight: bool) -> Array:
	var d := b - a
	if straight:
		b = Vector2i(b.x, a.y) if absi(d.x) >= absi(d.y) else Vector2i(a.x, b.y)
	var corner := Vector2i(a.x, b.y) if axis == 1 else Vector2i(b.x, a.y)
	var out: Array = [a]
	for leg in [[a, corner], [corner, b]]:
		var p: Vector2i = leg[0]
		var step: Vector2i = (leg[1] - leg[0]).sign()
		while p != leg[1]:
			p += step
			out.append(p)
	return out


func _path_count(kind: int) -> int:
	var n := 0
	for e in _path_line:
		if int(e[1]) == kind:
			n += 1
	return n


## Let go: the new tiles of the line are built, as many as the till pays for, from the
## start on; one sound, one price.
func _end_path_drag() -> void:
	if not _path_drag_active:
		return
	_path_drag_active = false
	var todo: Array = []
	for e in _path_line:
		if int(e[1]) == PATH_NEW:
			todo.append(e[0])
	var blocked := _path_count(PATH_BLOCKED)
	_path_line.clear()
	if todo.is_empty():
		if blocked > 0:
			_emit_status("Nothing to build: the way is blocked.", STATUS_DENY)
			_deny_fx(_path_end, "Blocked")
		return
	var cost := _get_cost("path")
	var n := todo.size()
	if cost > 0:
		n = mini(n, int(CoreRoot.get_money()) / cost)
	if n <= 0:
		_emit_status("Not enough money: a path tile costs $%d." % cost, STATUS_DENY)
		_deny_fx(todo[0], "$%d" % cost)
		return
	_path_batch.clear()
	_batch_cells.clear()
	_batch_cost = 0
	_batch_refused = 0
	_batch_short = todo.size() - n
	for i in n:
		_path_batch[todo[i]] = true
	_path_batch_sending = true
	for i in n:
		EventBus.RequestBuild.emit("path", todo[i], 0)
	_path_batch_sending = false
	if _path_batch.is_empty():
		_flush_path_batch()
	else:
		_emit_status("Building %d path tiles..." % n)


## The whole line answered: one ripple round it, one sound, one price.
func _flush_path_batch() -> void:
	if _batch_cells.is_empty():
		_emit_status("Path refused: %s." % ("blocked" if _batch_refused > 0 else "nothing built"), STATUS_DENY)
		return
	var n := _batch_cells.size()
	var msg := "Path built: %d %s, $%d." % [n, "tile" if n == 1 else "tiles", _batch_cost]
	if _batch_short > 0:
		msg += " %d not built: no money." % _batch_short
	_emit_status(msg, STATUS_GOOD if _batch_short == 0 else STATUS_DENY)
	_bfx.built(_batch_cells)
	var mid := Vector2.ZERO
	for c in _batch_cells:
		mid += Vector2(c)
	mid /= float(n)
	if _batch_cost > 0:
		_add_fx("pop", mid, 1.4, "-$%d" % _batch_cost, Color8(255, 220, 80))
	_play("path", -10.0)
	_batch_cells.clear()


func _begin_demolish_press(local_pos: Vector2) -> void:
	if _pending_demolish_wait:
		_emit_status("Awaiting demolish confirmation...")
		return
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		if _demolish_selection_active:
			_demolish_selection_active = false
			_emit_status("Demolish selection canceled.")
		return

	if _demolish_selection_active and _rect_contains_coord(_demolish_selection_rect, coord):
		_send_demolish_request(_demolish_selection_rect)
		return

	_demolish_selection_active = false
	_demolish_drag_active = true
	_demolish_drag_start = coord
	_demolish_drag_end = coord


func _update_demolish_drag(local_pos: Vector2) -> void:
	if not _demolish_drag_active:
		return
	var coord = _local_to_grid(local_pos)
	coord = Vector2i(clampi(coord.x, 0, int(grid_manager.grid_width) - 1), clampi(coord.y, 0, int(grid_manager.grid_height) - 1))
	_demolish_drag_end = coord


func _finish_demolish_drag() -> void:
	if not _demolish_drag_active:
		return
	_demolish_drag_active = false
	var rect = _rect_from_points(_demolish_drag_start, _demolish_drag_end)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	_demolish_selection_rect = rect
	_demolish_selection_active = true
	_emit_status("Area %dx%d selected. Click inside it or press Enter to bulldoze." % [rect.size.x, rect.size.y])


func _send_build_request(building_type: String, coord: Vector2i, rot: int) -> void:
	_pending_build_wait = true
	_pending_build_type = building_type
	_pending_build_coord = coord
	_pending_build_rot = wrapi(rot, 0, 4)
	if EventBus.has_signal("RequestBuild"):
		EventBus.RequestBuild.emit(building_type, coord, _pending_build_rot)
		_emit_status("Build request: %s [%d,%d]" % [_display_name(building_type), coord.x, coord.y])
	else:
		_pending_build_wait = false
		_emit_status("Build request channel unavailable.", STATUS_DENY)


func _send_demolish_request(rect: Rect2i) -> void:
	_pending_demolish_wait = true
	_pending_demolish_rect = rect
	_demolish_removed.clear()
	if EventBus.has_signal("RequestDemolish"):
		EventBus.RequestDemolish.emit(rect)
		_emit_status("Demolish request: %dx%d" % [rect.size.x, rect.size.y])
	else:
		_pending_demolish_wait = false
		_emit_status("Demolish request channel unavailable.", STATUS_DENY)


## Takes back the last thing built today (all of a path drag), paying the price back.
func undo_last() -> bool:
	var st = CoreRoot.get_state()
	var today := int(st.day) if st != null else 1
	_undo = _undo.filter(func(u): return int(u["day"]) == today)
	if _undo.is_empty() or CoreRoot.actions == null:
		_emit_status("Nothing to undo today.", STATUS_DENY)
		return false
	# Co-op: on the other warden's machine the camp is the host's; take it down instead.
	if Coop.is_client():
		_emit_status("Not from here. Bulldoze it instead.", STATUS_DENY)
		return false
	var group := int(_undo.back()["group"])
	var taken := 0
	var back := 0
	while not _undo.is_empty() and int(_undo.back()["group"]) == group:
		var u: Dictionary = _undo.pop_back()
		var cell: Dictionary = st.grid.cells.get(u["coord"], {})
		# Only if it is still what you put there.
		if str(cell.get("type", "")) != str(u["type"]) or cell.get("root_coord", u["coord"]) != u["coord"]:
			continue
		var m0: int = st.money
		if CoreRoot.actions.remove_building(u["coord"]):
			var refunded: int = st.money - m0
			CoreRoot.actions.add_money(maxi(0, int(u["cost"]) - refunded))
			taken += 1
			back += int(u["cost"])
	if taken == 0:
		_emit_status("Nothing to undo: it has changed since.", STATUS_DENY)
		return false
	_emit_status("Undone: %d %s, $%d back." % [taken, "piece" if taken == 1 else "pieces", back], STATUS_GOOD)
	_play("bulldoze", -10.0)
	_static_dirty = true
	return true


func _rotate_building(step: int) -> void:
	if selected_building == "" or selected_building == "path" or selected_building == "demolish":
		_emit_status("Select a structure to rotate.", STATUS_DENY)
		return
	# An oblong one (a caravan, the pitch) only turns round: its footprint stays as it is.
	if _turns_round_only(selected_building):
		_rotation_steps = wrapi(_rotation_steps - _rotation_steps % 2 + (2 if step >= 0 else -2), 0, 4)
	else:
		_rotation_steps = wrapi(_rotation_steps + step, 0, 4)
	_ghost_locked = false
	if EventBus.has_signal("RequestRotate"):
		EventBus.RequestRotate.emit(1 if step >= 0 else -1)
	_emit_status("Direction: %s" % ROTATION_LABELS[_rotation_steps])
	queue_redraw()


func _cancel_tool_selection() -> void:
	selected_building = ""
	_ghost_locked = false
	_path_drag_active = false
	_demolish_drag_active = false
	_demolish_selection_active = false
	_path_line.clear()
	tool_canceled.emit()
	_emit_status("Selection canceled.")


func _set_zoom(new_zoom: float) -> void:
	var old_zoom = _zoom_level
	_zoom_level = clamp(new_zoom, ZOOM_MIN, ZOOM_MAX)
	if absf(old_zoom - _zoom_level) < 0.001:
		return
	_pan_offset *= (_zoom_level / old_zoom)
	_clamp_pan_offset_for_current_map()
	_ghost_locked = false
	_emit_status("Zoom: %d%%" % int(round(_zoom_level * 100.0)))


func _connect_event_bus() -> void:
	if EventBus.has_signal("BuildConfirmed"):
		var ok_cb := Callable(self, "_on_build_confirmed")
		if not EventBus.BuildConfirmed.is_connected(ok_cb):
			EventBus.BuildConfirmed.connect(ok_cb)
	if EventBus.has_signal("BuildRejected"):
		var rej_cb := Callable(self, "_on_build_rejected")
		if not EventBus.BuildRejected.is_connected(rej_cb):
			EventBus.BuildRejected.connect(rej_cb)
	if EventBus.has_signal("DemolishConfirmed"):
		var dem_ok_cb := Callable(self, "_on_demolish_confirmed")
		if not EventBus.DemolishConfirmed.is_connected(dem_ok_cb):
			EventBus.DemolishConfirmed.connect(dem_ok_cb)
	if EventBus.has_signal("DemolishRejected"):
		var dem_rej_cb := Callable(self, "_on_demolish_rejected")
		if not EventBus.DemolishRejected.is_connected(dem_rej_cb):
			EventBus.DemolishRejected.connect(dem_rej_cb)


func _on_build_confirmed(building_type: String, pos: Vector2i, rot: int) -> void:
	if building_type == "path" and _path_batch.has(pos):
		_path_batch.erase(pos)
		var st0 = CoreRoot.get_state()
		_undo.append({"type": "path", "coord": pos, "cost": _get_cost("path"), "group": _undo_group, "day": int(st0.day) if st0 != null else 1})
		while _undo.size() > 40:
			_undo.remove_at(0)
		_batch_cells.append(pos)
		_batch_cost += _get_cost("path")
		_add_fx("dust", Vector2(pos), 0.45)
		_static_dirty = true
		if _path_batch.is_empty() and not _path_batch_sending:
			_flush_path_batch()
		return
	if _row_batch.has(pos) and str(_row_batch[pos]) == building_type:
		_row_batch.erase(pos)
		var st_r = CoreRoot.get_state()
		_undo.append({"type": building_type, "coord": pos, "cost": _get_cost(building_type), "group": _undo_group, "day": int(st_r.day) if st_r != null else 1})
		while _undo.size() > 40:
			_undo.remove_at(0)
		_row_cost += _get_cost(building_type)
		_row_built += 1
		_add_fx("pop", Vector2(pos), 1.0, "-$%d" % _get_cost(building_type), Color8(255, 220, 80))
		_static_dirty = true
		if _row_batch.is_empty() and not _row_sending:
			_flush_row()
		return
	var mine := _pending_build_wait and building_type == _pending_build_type and pos == _pending_build_coord
	# A lamp on a path belongs to the path: not something undo can take off it.
	if mine and not (building_type == "lamp_post" and _path_cell(pos)):
		var st = CoreRoot.get_state()
		_undo.append({"type": building_type, "coord": pos, "cost": _get_cost(building_type), "group": _undo_group, "day": int(st.day) if st != null else 1})
		while _undo.size() > 40:
			_undo.remove_at(0)
	if _pending_build_wait and building_type == _pending_build_type and pos == _pending_build_coord and wrapi(rot, 0, 4) == _pending_build_rot:
		_pending_build_wait = false
		_pending_build_type = ""
		_pending_build_coord = Vector2i(-1, -1)
	var fp := _get_footprint(building_type)
	var mid := Vector2(pos) + Vector2(fp - Vector2i.ONE) * 0.5
	var cost := _get_cost(building_type)
	if building_type == "path":
		_add_fx("dust", mid, 0.45)
		if mine:
			_emit_status("Path built at [%d,%d]." % [pos.x, pos.y], STATUS_GOOD)
			_play("path", -14.0)
	else:
		_emit_status("Built: %s" % _display_name(building_type), STATUS_GOOD)
		for k in 2:
			_add_fx("dust", mid + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)), 0.5)
		var snd := "place"
		if building_type.begins_with("tent"):
			snd = "tent"
		elif building_type == "lamp_post":
			snd = "lamp"
		_play(snd, -10.0)
	if cost > 0:
		_add_fx("pop", mid, 1.3, "-$%d" % cost, Color8(255, 220, 80))
	_static_dirty = true
	queue_redraw()


func _on_build_rejected(building_type: String, pos: Vector2i, rot: int, reason: String) -> void:
	if building_type == "path" and _path_batch.has(pos):
		_path_batch.erase(pos)
		_batch_refused += 1
		if _path_batch.is_empty() and not _path_batch_sending:
			_flush_path_batch()
		return
	if _row_batch.has(pos):
		_row_batch.erase(pos)
		if _row_batch.is_empty() and not _row_sending:
			_flush_row()
		return
	if _pending_build_wait and building_type == _pending_build_type and pos == _pending_build_coord and wrapi(rot, 0, 4) == _pending_build_rot:
		_pending_build_wait = false
		_pending_build_type = ""
		_pending_build_coord = Vector2i(-1, -1)
	_emit_status("Build rejected: %s" % _reason_text(reason), STATUS_DENY)
	_deny_fx(pos, "No")
	queue_redraw()


func _on_demolish_confirmed(area: Rect2i, removed_count: int, fee_paid: int, refund_total: int) -> void:
	if _pending_demolish_wait and _rect_equals(area, _pending_demolish_rect):
		_pending_demolish_wait = false
	_demolish_selection_active = false
	_emit_status("Cleared %d. Refund +$%d, bulldozer -$%d." % [removed_count, refund_total, fee_paid], STATUS_GOOD)
	# Dust over what went (a dozen puffs spread over it), one ripple for the lot.
	var gone := _demolish_removed.duplicate()
	_demolish_removed.clear()
	if not gone.is_empty():
		var stride := maxi(1, gone.size() / 12)
		for i in range(0, gone.size(), stride):
			_add_fx("dust", Vector2(gone[i]), 0.8)
		if is_visible_in_tree():
			_bfx.built(gone, true)
	var mid := Vector2(area.position) + Vector2(area.size - Vector2i.ONE) * 0.5
	# The refund and the bulldozer's fee side by side (one over the other they ran together).
	if refund_total > 0:
		_add_fx("pop", mid + Vector2(-0.45, 0.45), 1.4, "+$%d" % refund_total, Color8(120, 255, 120))
	if fee_paid > 0:
		_add_fx("pop", mid + Vector2(0.45, -0.45), 1.3, "-$%d" % fee_paid, Color8(255, 220, 80))
	# The little yellow bulldozer drives in over what went and backs off again.
	if not _dozer_tex.is_empty() and not gone.is_empty() and is_visible_in_tree():
		var a := Vector2(area.position) - Vector2(1.2, -0.3)
		_dozers.append({"a": a, "b": mid, "t": 0.0, "life": 2.2})
		_play("dozer", -10.0)
	else:
		_play("bulldoze", -6.0)
	_static_dirty = true
	queue_redraw()


## The bulldozers at work: in (pushing, blade down), a shove, back out (a puff of smoke),
## in steps; their dust in four frames.
func _draw_dozers(origin: Vector2, tile_w: float, tile_h: float, mini_h: int) -> void:
	for d in _dozers:
		var t := float(d["t"])
		var life := float(d["life"])
		var a: Vector2 = d["a"]
		var b: Vector2 = d["b"]
		var k := 0.0
		var f := 0
		var step := int(_time * 8.0)
		if t < life * 0.5:
			k = t / (life * 0.5)
			f = 4 + step % 2
		elif t < life * 0.62:
			k = 1.0
			f = 4 + step % 2
		else:
			k = 1.0 - (t - life * 0.62) / (life * 0.38)
			f = 6 + step % 2
		var cell := a.lerp(b, floorf(k * 12.0) / 12.0)
		var tex: Texture2D = _dozer_tex[mini(f, _dozer_tex.size() - 1)]
		var h := maxi(8, int(mini_h * 0.8))
		var key := "dozer|%d|%d" % [f, h]
		if not _worker_minis.has(key):
			_worker_minis[key] = _mini_of(tex, h)
		var mt: Texture2D = _worker_minis[key]
		var foot := _cell_to_iso_f(cell, origin, tile_w, tile_h)
		var dd := _display_cell_f(b) - _display_cell_f(a)
		var right := dd.x - dd.y > 0.0
		var at := (foot - Vector2(mt.get_width() * 0.5, mt.get_height())).floor()
		if right:
			_cv.draw_set_transform(at + Vector2(mt.get_width(), 0), 0.0, Vector2(-1, 1))
			_cv.draw_texture(mt, Vector2.ZERO)
			_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_cv.draw_texture(mt, at)
		if not _dozer_dust.is_empty() and t > life * 0.4 and t < life * 0.8:
			var df := clampi(int((t - life * 0.4) / (life * 0.4) * 4.0), 0, 3)
			var dt: Texture2D = _dozer_dust[df]
			# One scale for all four (from the first, the puff alone): the later ones are
			# bigger with the bits flying off, so the dust bursts instead of shrinking.
			var ds := tile_h * 1.15 / maxf(1.0, (_dozer_dust[0] as Texture2D).get_height())
			var dp := _cell_to_iso_f(b, origin, tile_w, tile_h)
			_cv.draw_texture_rect(dt, Rect2((dp - Vector2(dt.get_width(), dt.get_height() * 1.4) * ds * 0.5).floor(), dt.get_size() * ds), false, Color(1, 1, 1, 0.9))


func _on_demolish_rejected(area: Rect2i, reason: String) -> void:
	if _pending_demolish_wait and _rect_equals(area, _pending_demolish_rect):
		_pending_demolish_wait = false
	_demolish_removed.clear()
	_emit_status("Demolish rejected: %s" % _reason_text(reason), STATUS_DENY)
	_deny_fx(area.position, "No")
	queue_redraw()


## The layers (the map was redrawn whole every frame: 16 fps with Builder open, 2026-10-17).
## The panel draws the background; the static layer the ground, the edges, the paths,
## the trees and the buildings, once, and again only when something changes (a build, a
## demolition, the day, the zoom settling, a resize); panning moves it and zooming
## scales it in between. The dynamic layer on top draws what moves: the water's glints,
## smoke, the guests, the night, the effects, the cursor, the ghost and the previews.
func _draw() -> void:
	_cv = self
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)


func _draw_static() -> void:
	_cv = _static_layer
	_water_cells.clear()
	_smokers.clear()
	_lights.clear()
	_lit_spots.clear()
	_occ.clear()
	_flags.clear()
	_anim_entries.clear()
	_known.clear()
	if grid_manager == null:
		return
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	var gm = _grid_model()
	if grid_w <= 0 or grid_h <= 0 or gm == null:
		return
	var tile_w: float = _static_tile_w
	var tile_h: float = tile_w * 0.5
	var origin: Vector2 = _static_origin
	_draw_ground(gm, grid_w, grid_h, origin, tile_w)
	for entry in _collect_structures(gm, grid_w, grid_h, origin, tile_w, tile_h):
		var ty := str(entry.get("type", ""))
		var er = entry.get("root")
		if ty != "" and er != null and not er.is_in_group("trees") and not er.is_in_group("corn"):
			_known[entry.get("origin", Vector2i.ZERO)] = [ty, entry.get("footprint", Vector2i.ONE)]
		# Still a building site: the dynamic layer draws it until it stands.
		if _dropped.has(entry.get("origin", Vector2i.ZERO)):
			_anim_entries.append(entry)
			continue
		if ty == "flagpole" and _views.has("flagpole_0_f0"):
			_flags.append([entry["center"], int(entry.get("rotation", 0))])
			continue
		_draw_structure(entry, tile_w, tile_h)
		if ty != "path":
			_occ.append([float(entry.get("order", 0.0)), entry, _cover_rect(entry, tile_w, tile_h)])
		if ty.begins_with("tent") or ty.begins_with("cabin") or ty.begins_with("caravan"):
			var lv := _view_of(_icon_key_for_type(ty), int(entry.get("rotation", 0)))
			if not lv.is_empty():
				_lit_spots.append([entry["center"], lv, entry["origin"], ty])
		if SMOKERS.has(ty):
			_smokers.append([entry["center"], float(SMOKERS[ty]), int(entry["origin"].x * 7 + entry["origin"].y * 13)])
		if ty == "lamp_post" or ty == "bonfire":
			_lights.append([entry["center"], ty])
		elif ty == "path" and _path_has_lamp(entry["origin"]):
			_lights.append([_path_lamp_point(entry["origin"], entry["center"], tile_w, tile_h), "lamp_post"])


func _grid_model():
	var st = CoreRoot.get_state() if CoreRoot != null else null
	return st.grid if st != null else null


## The ground (tiles, the cut edges, the grid lines) is made once at one unit a tile and
## drawn scaled: it changes only with the season's picture, the lake and the entrance.
## It was drawn tile by tile on every redraw, ~100 ms on a 28x28 map, and a path drag
## redrew it for every tile (playtest 18. 10.: "the builder is laggy").
func _draw_ground(gm, grid_w: int, grid_h: int, origin: Vector2, tile_w: float) -> void:
	_ground_tex = _season_ground_texture()
	var key := _ground_signature(gm, grid_w, grid_h)
	if key != _ground_key:
		_ground_key = key
		_build_ground(gm, grid_w, grid_h)
	_cv.draw_set_transform(origin, 0.0, Vector2(tile_w, tile_w))
	if _ground_tex_mesh != null:
		_cv.draw_mesh(_ground_tex_mesh, _ground_tex, Transform2D.IDENTITY, Color(GROUND_SHADE_MAX, GROUND_SHADE_MAX, GROUND_SHADE_MAX))
	if _ground_col_mesh != null:
		_cv.draw_mesh(_ground_col_mesh, null)
	if not _ground_lines.is_empty():
		_cv.draw_multiline(_ground_lines, GRID_LINE, -1.0)
	if not _lake_lines.is_empty():
		_cv.draw_multiline(_lake_lines, Color(0.0, 0.0, 0.0, 0.10), -1.0)
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for w in _lake_units:
		_water_cells.append([origin + (w[0] as Vector2) * tile_w, w[1]])


func _ground_signature(gm, grid_w: int, grid_h: int) -> String:
	var lake := 0
	var reserved := 0
	var sum := 0
	for c in gm.tile_types:
		var t := int(gm.tile_types[c])
		if t == grid_manager.TILE_LAKE:
			lake += 1
			sum += c.x * 31 + c.y * 977
		elif t == grid_manager.TILE_RESERVED:
			reserved += 1
			sum += c.x * 7919 + c.y * 13
	return "%dx%d|%d|%d|%d|%s|v%d" % [grid_w, grid_h, lake, reserved, sum, _ground_tex.resource_path if _ground_tex != null else "-", view_rot]


## Vertex colours are kept under 1 (meshes store them as bytes); the brightening the
## tiles had is the mesh's modulate.
func _build_ground(gm, grid_w: int, grid_h: int) -> void:
	var dims := _display_grid_dimensions(grid_w, grid_h)
	var tv := PackedVector2Array()
	var tc := PackedColorArray()
	var tu := PackedVector2Array()
	var cv := PackedVector2Array()
	var cc := PackedColorArray()
	_ground_lines = PackedVector2Array()
	_lake_lines = PackedVector2Array()
	_lake_units.clear()
	_lake_cells_f.clear()
	var depth := 0.45
	for y in grid_h:
		for x in grid_w:
			var coord := Vector2i(x, y)
			var d := _rotate_coord_for_display(coord)
			var c := Vector2((d.x - d.y) * 0.5, (d.x + d.y) * 0.25)
			var top := c + Vector2(0.0, -0.25)
			var right := c + Vector2(0.5, 0.0)
			var bottom := c + Vector2(0.0, 0.25)
			var left := c + Vector2(-0.5, 0.0)
			var quad := PackedVector2Array([top, right, bottom, top, bottom, left])
			var edges := PackedVector2Array([top, right, right, bottom, bottom, left, left, top])
			var h := _hash01(coord)
			var t := int(gm.get_tile_type(coord))
			if t == grid_manager.TILE_LAKE:
				_add_quad(cv, cc, quad, WATER.lightened(h * 0.05))
				_lake_lines.append_array(edges)
				_lake_units.append([c, h])
				_lake_cells_f.append(Vector2(coord))
			else:
				if t == grid_manager.TILE_RESERVED:
					_add_quad(cv, cc, quad, DIRT.lerp(DIRT.darkened(0.1), h))
				elif _ground_tex != null:
					# One picture over the whole map, tile by tile a shade apart.
					var shade := (1.12 + h * 0.22) / GROUND_SHADE_MAX
					_add_quad(tv, tc, quad, Color(shade, shade, shade))
					for q in quad:
						tu.append(q / 2.5)
				else:
					_add_quad(cv, cc, quad, GROUND_A.lerp(GROUND_B, h))
				_ground_lines.append_array(edges)
			# The cut edge of the land along the two front sides, like RCT.
			var dn := Vector2(0.0, depth)
			if d.y == dims.y - 1:
				_add_quad(cv, cc, PackedVector2Array([left, bottom, bottom + dn, left, bottom + dn, left + dn]), EDGE_LEFT)
			if d.x == dims.x - 1:
				_add_quad(cv, cc, PackedVector2Array([bottom, right, right + dn, bottom, right + dn, bottom + dn]), EDGE_RIGHT)
	_ground_tex_mesh = _mesh_2d(tv, tc, tu)
	_ground_col_mesh = _mesh_2d(cv, cc)


func _add_quad(verts: PackedVector2Array, cols: PackedColorArray, quad: PackedVector2Array, col: Color) -> void:
	verts.append_array(quad)
	for i in quad.size():
		cols.append(col)


func _mesh_2d(verts: PackedVector2Array, cols: PackedColorArray, uvs := PackedVector2Array()) -> ArrayMesh:
	if verts.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	if not uvs.is_empty():
		arr[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## The structures in drawing order (back to front), straight from the grid's occupants;
## fills the minimap on the way.
func _collect_structures(gm, grid_w: int, grid_h: int, origin: Vector2, tile_w: float, tile_h: float) -> Array:
	var dims := _display_grid_dimensions(grid_w, grid_h)
	if _mini_img == null or _mini_img.get_width() != dims.x or _mini_img.get_height() != dims.y:
		_mini_img = Image.create(dims.x, dims.y, false, Image.FORMAT_RGBA8)
	_mini_img.fill(_mini_ground())
	for c in gm.tile_types:
		var t := int(gm.tile_types[c])
		if t == grid_manager.TILE_LAKE or t == grid_manager.TILE_RESERVED:
			var dc := _rotate_coord_for_display(c)
			if dc.x >= 0 and dc.y >= 0 and dc.x < dims.x and dc.y < dims.y:
				_mini_img.set_pixelv(dc, MINI_COLORS["lake" if t == grid_manager.TILE_LAKE else "reserved"])
	var found: Array = []
	var keys := PackedInt64Array()
	var kind_of: Dictionary = {}
	var occ: Dictionary = gm.occupants
	for coord in occ:
		var node = occ[coord]
		if node == null or not is_instance_valid(node):
			continue
		var root = _resolve_occupant_root(node)
		if root == null:
			continue
		var root_id := root.get_instance_id()
		var dcell := _rotate_coord_for_display(coord)
		if kind_of.has(root_id):
			_mini_img.set_pixelv(dcell, MINI_COLORS.get(kind_of[root_id], _mini_ground()))
			continue
		var mk := "corn" if root.is_in_group("corn") else ("tree" if root.is_in_group("trees") else _mini_kind(str(root.get_meta("building_type", ""))))
		kind_of[root_id] = mk
		_mini_img.set_pixelv(dcell, MINI_COLORS.get(mk, _mini_ground()))
		var structure_origin: Vector2i = root.get_meta("grid_origin", coord)
		var footprint: Vector2i = root.get_meta("grid_footprint", Vector2i.ONE)
		var anchor := _rotate_coord_for_display(structure_origin + Vector2i(maxi(0, footprint.x - 1), maxi(0, footprint.y - 1)))
		keys.append((((anchor.x + anchor.y) * 1024 + anchor.x) * 1024 + anchor.y) * 8192 + found.size())
		found.append({
			"root": root,
			"type": str(root.get_meta("building_type", "")),
			"rotation": wrapi(int(root.get_meta("build_rotation", 0)), 0, 4),
			"origin": structure_origin,
			"footprint": footprint,
			"center": _footprint_center_iso(structure_origin, footprint, origin, tile_w, tile_h),
			"order": float(anchor.x + anchor.y),
		})
	if _mini_tex == null or _mini_tex.get_width() != dims.x:
		_mini_tex = ImageTexture.create_from_image(_mini_img)
	else:
		_mini_tex.update(_mini_img)
	keys.sort()
	var out: Array = []
	for k in keys:
		out.append(found[k % 8192])
	return out


## Static-layer point to the panel, as the layer stands now (moved and scaled).
func _s2d(p: Vector2) -> Vector2:
	return _static_layer.position + p * _static_layer.scale.x


func _draw_dynamic() -> void:
	_cv = _dyn_layer
	if grid_manager == null:
		return
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	if grid_w <= 0 or grid_h <= 0:
		return
	var iso = _compute_iso_layout(grid_w, grid_h)
	var tile_w: float = iso.tile_w
	var tile_h: float = iso.tile_h
	var origin: Vector2 = iso.origin
	var k := _static_layer.scale.x
	# Light moving on the water (lines, until the Grok glints are there: map_life draws those).
	for w in ([] if _life.has("lake") else _water_cells):
		var c := _s2d(w[0])
		var ph := _time * 1.3 + float(w[1]) * 6.28
		var a := 0.18 + 0.14 * sin(ph)
		var off := Vector2(sin(ph * 0.7) * tile_w * 0.12, cos(ph * 0.5) * tile_h * 0.10)
		_cv.draw_line(c + off - Vector2(tile_w * 0.12, 0), c + off + Vector2(tile_w * 0.12, 0), Color(0.7, 0.85, 1.0, a), 1.0)
	_tick_lie()
	if _time < _karel_until:
		_draw_old_camp(origin, tile_w, tile_h)
	if _time < _mole_until and _is_valid_coord(_buried_tile()):
		var bc := _footprint_center_iso(_buried_tile(), Vector2i.ONE, origin, tile_w, tile_h)
		var r := tile_h * 0.35
		_cv.draw_line(bc - Vector2(r, r * 0.5), bc + Vector2(r, r * 0.5), Color8(200, 20, 20), 2.0)
		_cv.draw_line(bc + Vector2(-r, r * 0.5), bc + Vector2(r, -r * 0.5), Color8(200, 20, 20), 2.0)
	if not _lie.is_empty() and _time < float(_lie["until"]):
		var lc: Vector2i = _lie["cell"]
		_draw_building_icon(_footprint_center_iso(lc, Vector2i.ONE, origin, tile_w, tile_h), Vector2i.ONE, "tent_1", 0, Color(0.92, 0.92, 0.92, 0.96), tile_w, tile_h)
	for rb in _rubble:
		var rc := _footprint_center_iso(rb["o"], rb["f"], origin, tile_w, tile_h)
		var fade := clampf((RUBBLE_LIFE - (_time - float(rb["t"]))) / 0.8, 0.0, 1.0)
		_draw_building_icon(rc, rb["f"], "rubble", 0, Color(1, 1, 1, fade), tile_w, tile_h)
	for e in _anim_entries:
		var moved: Dictionary = (e as Dictionary).duplicate()
		moved["center"] = _s2d(e["center"])
		_draw_structure(moved, tile_w, tile_h)
	for sm in _smokers:
		_draw_smoke(_s2d(sm[0]), tile_h, float(sm[1]), int(sm[2]))
	var fk := int(_time * (4.0 + 4.0 * clampf(float(_wx.get("wind", 0.15)), 0.0, 1.0))) % 4
	for fl in _flags:
		var fv: Array = _views.get("flagpole_%d_f%d" % [wrapi(view_rot + int(fl[1]), 0, 4), fk], [])
		if not fv.is_empty():
			_draw_view(fv, _s2d(fl[0]), Color.WHITE, tile_w)
	var entries: Array = []
	_append_guest_entries(entries, origin, tile_w, tile_h)
	var lights: Array = []
	for l in _lights:
		lights.append([_s2d(l[0]), l[1]])
	_draw_overlay(origin, tile_w, tile_h, lights)
	_draw_inspected(origin, tile_w, tile_h)
	for g in entries:
		_draw_guest(g, tile_h)
	_draw_occluders(entries, tile_w, tile_h)
	var life_h := clampi(int(round(tile_h * 1.1 / 4.0)) * 4, 12, 56)
	_life.draw(_cv, self, origin, tile_w, tile_h, life_h)
	_draw_dozers(origin, tile_w, tile_h, life_h)
	_draw_sleepers(origin, tile_w, tile_h)
	_draw_lodging_badges(origin, tile_w, tile_h)
	if overlay != "light":
		_draw_dusk()
		_draw_night(lights, tile_w, tile_h)
		_draw_lit_windows(tile_w)
		_draw_weather(origin, tile_w, tile_h)
	_life.draw_sky(_cv, self, size, clampi(int(round(tile_h * 1.1 / 4.0)) * 4, 12, 56))
	_draw_fx(origin, tile_w, tile_h)
	var iso_c := Callable(self, "_cell_iso_fast").bind(origin, tile_w, tile_h)
	var valid_c := Callable(self, "_is_valid_coord")
	if selected_building != "":
		_bfx.draw_grid(_cv, iso_c, valid_c, hover_coord, tile_w, tile_h)
		_bfx.draw_wave(_cv, iso_c, valid_c, tile_w, tile_h)
	_bfx.draw_ripples(_cv, iso_c, tile_w, tile_h)
	_draw_path_drag_preview(origin, tile_w, tile_h)
	_draw_ghost_preview(origin, tile_w, tile_h)
	_draw_demolish_preview(origin, tile_w, tile_h)
	if _is_valid_coord(hover_coord) and (selected_building == "" or selected_building == "path"):
		var pulse := 0.75 + 0.25 * sin(_time * 6.0)
		_bfx.draw_area(_cv, iso_c, [hover_coord], tile_w, tile_h, Color(0.55, 0.85, 1.0, pulse), _time, false, 0.16 * pulse)
	_draw_rotation_panel()
	_draw_minimap(origin, tile_w, tile_h)
	_draw_hover_card()


## Every lodging's name over its roof, small: T1, C2, V1 (as on its key at the desk and
## on Vera's plan), so you know which is which without walking in.
func _draw_lodging_badges(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if GuestManager == null or not GuestManager.has_method("room_short"):
		return
	var accs: Dictionary = GuestManager.get_accommodation_states()
	for key in accs.keys():
		var acc: Dictionary = accs[key]
		var kind: String = GuestManager.lodging_kind(str(acc.get("building_type", "")))
		if kind == "":
			continue
		var c: Vector2i = acc.get("coord", Vector2i(-1, -1)) if acc.get("coord", null) is Vector2i else SAVE_CODEC.coord_from_key(str(key))
		if c.x < 0:
			continue
		var def = CoreRoot.registry.get_def(StringName(str(acc.get("building_type", "")))) if CoreRoot != null else null
		var fp: Vector2i = def.footprint if def != null else Vector2i.ONE
		var p := _cell_to_iso_f(Vector2(c) + Vector2(fp) * 0.5 - Vector2(0.5, 0.5), origin, tile_w, tile_h) - Vector2(0, tile_h * 1.25)
		var text: String = GuestManager.room_short(str(key))
		var fs := T.FONT_SIZE
		var tw := T.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2((p - Vector2(tw * 0.5 + 3, 7)).floor(), Vector2(tw + 6, 13))
		var col: Color = {"tent": Color8(48, 112, 54), "cabin": Color8(168, 38, 30), "caravan": Color8(42, 72, 150)}.get(kind, Color8(90, 90, 90))
		_cv.draw_rect(r.grow(1), Color(0, 0, 0, 0.55))
		_cv.draw_rect(r, col)
		_cv.draw_string(T.FONT, r.position + Vector2(3, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color8(250, 244, 226))


## Where a building on `coord` stands on the panel now (its footprint's middle, in the
## panel's own coordinates), or Vector2.INF when it is off the map or off the screen.
func cell_screen_point(coord: Vector2i) -> Vector2:
	if grid_manager == null or not _is_valid_coord(coord):
		return Vector2.INF
	if _in_3d():
		return map3d.cell_point(coord)
	var iso = _compute_iso_layout(int(grid_manager.grid_width), int(grid_manager.grid_height))
	var info := structure_at(coord)
	var o: Vector2i = info.get("origin", coord)
	var f: Vector2i = info.get("footprint", Vector2i.ONE)
	var p := _footprint_center_iso(o, f, iso.origin, iso.tile_w, iso.tile_h) - Vector2(0, iso.tile_h * 0.6)
	return p if Rect2(Vector2.ZERO, size).grow(-4.0).has_point(p) else Vector2.INF


## The building on a cell, as Builder's card wants it ({} for open ground, trees and
## corn). A path cell is "path", with `lamp` when one stands on it.
func structure_at(coord: Vector2i) -> Dictionary:
	if grid_manager == null or not _is_valid_coord(coord):
		return {}
	var tile = grid_manager.get_tile(coord)
	if tile == null or not tile.occupied or tile.occupant == null:
		return {}
	var root = _resolve_occupant_root(tile.occupant)
	if root == null or root.is_in_group("trees") or root.is_in_group("corn"):
		return {}
	var t := str(root.get_meta("building_type", ""))
	if t == "":
		return {}
	var o: Vector2i = root.get_meta("grid_origin", coord)
	if t == "path":
		return {"type": "path", "origin": coord, "footprint": Vector2i.ONE, "root": root, "lamp": _path_has_lamp(coord)}
	return {"type": t, "origin": o, "footprint": root.get_meta("grid_footprint", Vector2i.ONE), "root": root}


func set_overlay(id: String) -> void:
	overlay = id if id in OVERLAYS else ""
	_ov_t = 0.0
	_refresh_overlay()
	_emit_status(("Showing: %s" % OVERLAY_NAMES.get(overlay, overlay)) if overlay != "" else "Overlay off.")


func cycle_overlay() -> String:
	set_overlay(OVERLAYS[(OVERLAYS.find(overlay) + 1) % OVERLAYS.size()])
	return overlay


const OVERLAY_NAMES := {"condition": "wear and repairs", "power": "what each building draws", "rooms": "the rooms: ready, dirty, taken", "light": "light at night"}
const OV_GOOD := Color8(60, 200, 80)
const OV_WARN := Color8(240, 180, 30)
const OV_BAD := Color8(230, 50, 40)
const OV_BLUE := Color8(80, 130, 240)


## What the overlay shows, read once a second (the snapshots are not cheap).
func _refresh_overlay() -> void:
	_ov_data.clear()
	var m: Node = get_tree().current_scene if get_tree() != null else null
	match overlay:
		"condition":
			if m != null and m.has_method("get_upkeep_snapshot"):
				for r in (m.get_upkeep_snapshot() as Dictionary).get("rows", []):
					var cond := float(r.get("condition", 1.0))
					var broken := bool(r.get("broken", false))
					var col := OV_BAD if broken or cond < 0.5 else (OV_WARN if cond < 0.75 else OV_GOOD)
					_ov_data[Vector2i(r["coord"])] = [cond, "BROKEN" if broken else "%d%%" % int(round(cond * 100.0)), col]
		"power":
			if m != null and m.has_method("get_electricity_ui_snapshot"):
				var lines: Array = (m.get_electricity_ui_snapshot() as Dictionary).get("consumption_lines", [])
				var top := 0.001
				for l in lines:
					top = maxf(top, float((l as Dictionary).get("kwh_per_day", 0.0)))
				for l in lines:
					var kwh := float((l as Dictionary).get("kwh_per_day", 0.0))
					var c = (l as Dictionary).get("coord", null)
					if c is Vector2i and kwh > 0.0:
						_ov_data[c] = [kwh / top, "%.1f kWh" % kwh, Color8(255, 200, 40).lerp(Color8(255, 80, 20), kwh / top)]
		"rooms":
			if GuestManager != null:
				for key in GuestManager.get_accommodation_states():
					var rs: Dictionary = GuestManager.get_room_state(str(key))
					if rs.is_empty():
						continue
					var st := str(rs.get("status", ""))
					var occupied := bool(rs.get("occupied", false))
					var col := OV_GOOD if st == "ready" else (OV_WARN if st == "unprepared" else OV_BAD)
					var word := {"ready": "ready", "dirty": "DIRTY", "unprepared": "make up"}.get(st, st) as String
					if occupied:
						col = OV_BLUE
						word = "guests"
					_ov_data[SAVE_CODEC.coord_from_key(str(key))] = [1.0, word, col]


func _draw_overlay(origin: Vector2, tile_w: float, tile_h: float, lights: Array) -> void:
	if overlay == "":
		return
	var iso_c := Callable(self, "_cell_iso_fast").bind(origin, tile_w, tile_h)
	if overlay == "light":
		# The night, and where the lamps and fires push it back (on the ground: flat ellipses).
		_cv.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.08, 0.55))
		for l in lights:
			var p: Vector2 = l[0]
			var r := tile_w * (2.6 if str(l[1]) != "bonfire" else 3.4)
			_cv.draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
			for k in 4:
				_cv.draw_circle(Vector2.ZERO, r * (1.0 - k * 0.22), Color(1.0, 0.85, 0.4, 0.1))
			_cv.draw_set_transform(Vector2.ZERO)
	else:
		var gm = _grid_model()
		for o in _ov_data:
			var v: Array = _ov_data[o]
			var fp := Vector2i.ONE
			var cell: Dictionary = gm.cells.get(o, {}) if gm != null else {}
			var def = CoreRoot.registry.get_def(StringName(str(cell.get("type", "")))) if CoreRoot != null and CoreRoot.registry != null and cell.has("type") else null
			if def != null:
				fp = def.footprint
			var cells: Array = []
			for y in maxi(1, fp.y):
				for x in maxi(1, fp.x):
					cells.append((o as Vector2i) + Vector2i(x, y))
			_bfx.draw_area(_cv, iso_c, cells, tile_w, tile_h, v[2], _time, false, 0.42)
			# Under the building (the room badges are over it).
			var c := _cell_to_iso_f(Vector2(o) + Vector2(fp) * 0.5 - Vector2(0.5, 0.5), origin, tile_w, tile_h) + Vector2(0, tile_h * (0.5 + 0.5 * maxf(fp.x, fp.y)) + 4.0)
			var text := str(v[1])
			var tw := T.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			var rr := Rect2((c - Vector2(tw * 0.5 + 3, 6)).floor(), Vector2(tw + 6, 13))
			_cv.draw_rect(rr, Color(0, 0, 0, 0.72))
			_cv.draw_string(T.FONT, rr.position + Vector2(3, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, (v[2] as Color).lightened(0.35))
	# The key, bottom left.
	var label := "%s   (O: next)" % str(OVERLAY_NAMES.get(overlay, overlay)).capitalize()
	var lw := T.FONT_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var lr := Rect2(Vector2(6, size.y - 22), Vector2(lw + 12, 16))
	_cv.draw_rect(lr, Color(0, 0, 0, 0.7))
	_cv.draw_rect(lr, Color(1, 1, 1, 0.4), false, 1.0)
	_cv.draw_string(T.FONT_BOLD, lr.position + Vector2(6, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(255, 236, 160))


## The building whose card is open: its outline, breathing.
func _draw_inspected(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if inspect_origin.x < 0:
		return
	var cells: Array = []
	for y in maxi(1, inspect_footprint.y):
		for x in maxi(1, inspect_footprint.x):
			cells.append(inspect_origin + Vector2i(x, y))
	var pulse := 0.7 + 0.3 * sin(_time * 5.0)
	_bfx.draw_area(_cv, Callable(self, "_cell_iso_fast").bind(origin, tile_w, tile_h), cells, tile_w, tile_h, Color(1.0, 0.92, 0.5, pulse), _time, false, 0.18)


func _mini_kind(t: String) -> String:
	if t == "path":
		return "path"
	if t == "main_building":
		return "office"
	if t.begins_with("tent") or t.begins_with("cabin") or t.begins_with("caravan"):
		return "housing"
	if t in ["toilet_block", "shower_block", "vecerka", "restaurant", "pub", "pub_2", "bowling"]:
		return "services"
	if t in ["bonfire", "sports_field", "lake_slide"]:
		return "fun"
	return "utility"


## The minimap's diamond: display cell (u, v) -> panel point.
func _mini_xform() -> Transform2D:
	var dims := Vector2(_mini_img.get_width(), _mini_img.get_height()) if _mini_img != null else Vector2(28, 28)
	var w := (dims.x + dims.y) * MINI_PX
	var h := w * 0.5
	var top := Vector2(size.x - w - 10.0 + dims.y * MINI_PX, 10.0)
	_mini_rect = Rect2(Vector2(size.x - w - 10.0, 10.0), Vector2(w, h))
	return Transform2D(Vector2(MINI_PX, MINI_PX * 0.5), Vector2(-MINI_PX, MINI_PX * 0.5), top)


func _draw_minimap(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if _mini_tex == null:
		return
	var xf := _mini_xform()
	var frame := _mini_rect.grow(4.0)
	_cv.draw_rect(frame, Color(0, 0, 0, 0.55))
	_cv.draw_rect(frame, Color(0.72, 0.72, 0.72, 0.9), false, 1.0)
	_cv.draw_set_transform_matrix(xf)
	_cv.draw_texture(_mini_tex, Vector2.ZERO)
	_cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The view: the panel's corners in display cells, on the little map.
	var pts := PackedVector2Array()
	# Held inside the minimap's frame (zoomed out, the view is bigger than the map and the
	# outline ran across the whole Builder).
	var dims_v := Vector2(_mini_img.get_width(), _mini_img.get_height()) if _mini_img != null else Vector2(28, 28)
	for q in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2.ZERO]:
		var dlt: Vector2 = q - origin
		var ua := dlt.x / (tile_w * 0.5)
		var vb := dlt.y / (tile_h * 0.5)
		var cell := Vector2((ua + vb) * 0.5 + 0.5, (vb - ua) * 0.5 + 0.5)
		cell = Vector2(clampf(cell.x, -0.5, dims_v.x + 0.5), clampf(cell.y, -0.5, dims_v.y + 0.5))
		pts.append(xf * cell)
	_cv.draw_polyline(pts, Color(1.0, 1.0, 0.6, 0.9), 1.0)


## Shot driver: put a cell in the middle of the view.
func debug_center_on(cell: Vector2i) -> void:
	if _in_3d():
		map3d.center_on(Vector2(cell))
		return
	_pan_offset += size * 0.5 - _cell_iso(Vector2(cell))
	_pan_vel = Vector2.ZERO
	_clamp_pan_offset_for_current_map()


## Click on the minimap: that spot to the middle of the view.
func _minimap_click(local: Vector2) -> bool:
	if _in_3d():
		return map3d.minimap_click(local)
	if _mini_tex == null or not _mini_rect.grow(4.0).has_point(local):
		return false
	var cell := _mini_xform().affine_inverse() * local
	if grid_manager == null:
		return true
	var gw: int = int(grid_manager.grid_width)
	var gh: int = int(grid_manager.grid_height)
	var iso = _compute_iso_layout(gw, gh)
	var tw: float = iso.tile_w
	var th: float = iso.tile_h
	var at: Vector2 = Vector2(iso.origin) + Vector2((cell.x - 0.5 - (cell.y - 0.5)) * tw * 0.5, (cell.x - 0.5 + cell.y - 0.5) * th * 0.5)
	_pan_offset += size * 0.5 - at
	_pan_vel = Vector2.ZERO
	_clamp_pan_offset_for_current_map()
	_play("click", -14.0)
	return true


## What is under the cursor, on a small card by it (the status bar has it too).
func _draw_hover_card() -> void:
	if not _is_valid_coord(hover_coord) or selected_building != "" or _pan_dragging:
		return
	var text := _describe(hover_coord)
	if text == "" or text.ends_with("Forest floor"):
		return
	var m := get_local_mouse_position() + Vector2(14, 16)
	var tw := T.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var r := Rect2(m.floor(), Vector2(tw + 8, 15))
	if r.end.x > size.x - 2:
		r.position.x = size.x - 2 - r.size.x
	_cv.draw_rect(r, T.TOOLTIP)
	_cv.draw_rect(r, T.DARK, false, 1.0)
	_cv.draw_string(T.FONT, r.position + Vector2(4, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)


## Keeps the static layer where the camera is: rebuilt when it must be, otherwise moved
## (pan) and scaled (zoom on its way).
func _update_static(delta: float) -> void:
	if grid_manager == null or _static_layer == null:
		return
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	if grid_w <= 0 or grid_h <= 0:
		return
	_sig_t -= delta
	if _sig_t <= 0.0:
		_sig_t = 0.5
		var sig := _world_signature()
		if sig != _static_sig:
			_static_sig = sig
			_static_dirty = true
	for e in _anim_entries:
		if not _dropped.has(e.get("origin", Vector2i.ZERO)):
			_static_dirty = true
			break
	var sway := float(_wx.get("wind", 0.15)) > SWAY_WIND and _get_icon("tree_sway_0") != null
	if sway or _swaying:
		var st := int(_time * 3.0)
		if st != _sway_step or sway != _swaying:
			_sway_step = st
			_swaying = sway
			_static_dirty = true
	var iso = _compute_iso_layout(grid_w, grid_h)
	var tile_w: float = iso.tile_w
	var origin: Vector2 = iso.origin
	var zooming := absf(_zoom_level - _zoom_target) > 0.0005 or _zoom_settle > 0.0
	if _static_dirty or size != _static_size or _static_tile_w <= 0.0 or (not zooming and absf(tile_w - _static_tile_w) > 0.01):
		_static_dirty = false
		_static_tile_w = tile_w
		_static_origin = origin
		_static_size = size
		_static_layer.position = Vector2.ZERO
		_static_layer.scale = Vector2.ONE
		_static_layer.queue_redraw()
		return
	var sc := tile_w / _static_tile_w
	_static_layer.scale = Vector2(sc, sc)
	_static_layer.position = origin - _static_origin * sc


## What the static layer shows: the structures and trees there are, the day (the ground
## follows the season). Cheap; checked twice a second.
func _world_signature() -> String:
	var n := 0
	if building_manager != null:
		var root: Node = building_manager.get_node_or_null("Structures")
		if root != null:
			n = root.get_child_count()
	var trees := get_tree().get_nodes_in_group("trees").size() if get_tree() != null else 0
	var corn := get_tree().get_nodes_in_group("corn").size() if get_tree() != null else 0
	var day: int = CoreRoot.get_day() if CoreRoot != null else 1
	var snow := Season.snow_cover(day, 12.0) >= 0.2
	return "%d|%d|%d|%d|%s" % [n, trees, corn, day if day < 10 else 10, snow]


## The ground's picture: the game's own grass, autumn leaves from day 10, snow when it
## lies (the same pictures as the world, scripts/season_look.gd).
## The minimap's open ground in the map's season (the late-summer meadow, the autumn's
## leaves, the snow), as the big map's ground picture is.
func _mini_ground() -> Color:
	var day: int = CoreRoot.get_day() if CoreRoot != null else 1
	if Season.snow_cover(day, 12.0) >= 0.2:
		return Color(0.82, 0.84, 0.86)
	if day >= 10:
		return Color(0.62, 0.48, 0.20)
	return Color(0.48, 0.46, 0.20)


func _season_ground_texture() -> Texture2D:
	var day: int = CoreRoot.get_day() if CoreRoot != null else 1
	var path := GROUND_TEX_SUMMER
	if Season.snow_cover(day, 12.0) >= 0.2 and ResourceLoader.exists(GROUND_TEX_SNOW):
		path = GROUND_TEX_SNOW
	elif day >= 10 and ResourceLoader.exists(GROUND_TEX_AUTUMN):
		path = GROUND_TEX_AUTUMN
	if not ResourceLoader.exists(path):
		return null
	if not _icon_cache.has(path):
		_icon_cache[path] = load(path)
	return _icon_cache[path]


func _update_zoom(delta: float) -> void:
	_zoom_settle = maxf(0.0, _zoom_settle - delta)
	if absf(_zoom_level - _zoom_target) < 0.0005:
		return
	if grid_manager == null:
		_zoom_level = _zoom_target
		return
	var gw: int = int(grid_manager.grid_width)
	var gh: int = int(grid_manager.grid_height)
	var before = _compute_iso_layout(gw, gh)
	var nz := lerpf(_zoom_level, _zoom_target, 1.0 - exp(-delta * 14.0))
	if absf(nz - _zoom_target) < 0.002:
		nz = _zoom_target
	_zoom_level = nz
	var after = _compute_iso_layout(gw, gh)
	# Keep the point under the mouse where it is.
	var anchor := _zoom_anchor
	var want: Vector2 = anchor - (anchor - Vector2(before.origin)) * (float(after.tile_w) / float(before.tile_w))
	_pan_offset += want - Vector2(after.origin)
	_clamp_pan_offset_for_current_map()
	_zoom_settle = 0.12


## The map coasts on a little when you let go of a drag.
func _update_inertia(delta: float) -> void:
	if _pan_dragging or _pan_vel.length_squared() < 4.0:
		if not _pan_dragging:
			_pan_vel = Vector2.ZERO
		return
	_pan_offset += _pan_vel * delta
	_pan_vel *= exp(-delta * 5.5)
	_clamp_pan_offset_for_current_map()


# ── guests ────────────────────────────────────────────────────────────────────

func _update_guests(delta: float) -> void:
	_guest_time += delta
	_guest_poll -= delta
	if _guest_poll > 0.0:
		return
	_guest_poll = 0.1
	var agents = get_tree().root.find_child("GuestAgents", true, false) if get_tree() != null else null
	if agents == null or not agents.has_method("get_visible_guest_positions") or grid_manager == null:
		_guests.clear()
		return
	var seen := {}
	for g_any in agents.get_visible_guest_positions():
		var g: Dictionary = g_any
		var id := int(g.get("guest_id", -1))
		var cell := _world_to_cell_f(g.get("position", Vector3.ZERO))
		var prev: Dictionary = _guests.get(id, {})
		var was: Vector2 = prev.get("cell", cell)
		var moving := not prev.is_empty() and was.distance_to(cell) > 0.004
		# Which way they go on the screen: towards you or away, left or right.
		var dir := int(prev.get("dir", 0))
		var mirror := bool(prev.get("mirror", false))
		if moving:
			var dd := _display_cell_f(cell) - _display_cell_f(was)
			dir = 0 if dd.x + dd.y >= 0.0 else 1
			mirror = dd.x - dd.y > 0.0
		var each: Array = []
		for m in g.get("members", []):
			each.append({"cell": _world_to_cell_f((m as Dictionary).get("position", Vector3.ZERO)), "pose": str(m.get("pose", "")), "flip": bool(m.get("flip", false))})
		if each.is_empty():
			each.append({"cell": cell, "pose": "", "flip": false})
		_guests[id] = {"cell": cell, "archetype": str(g.get("archetype", "")), "moving": moving, "phase": float(prev.get("phase", randf() * 10.0)),
			"dir": dir, "mirror": mirror, "members": each, "kind": str(g.get("kind", "")), "posed": bool(g.get("posed", false))}
		seen[id] = true
	for id in _guests.keys():
		if not seen.has(id):
			_guests.erase(id)
	# The staffroom's hands out at work in the camp, as they look there now.
	_hands.clear()
	var rt := get_tree().get_first_node_in_group("staff_runtime") if get_tree() != null else null
	if rt != null and rt.has_method("map_hands"):
		for h in rt.map_hands():
			_hands.append({"cell": _world_to_cell_f((h as Dictionary).get("position", Vector3.ZERO)), "moving": bool(h.get("moving", false)),
				"texture": h.get("texture"), "flip": bool(h.get("flip", false)), "slug": str(h.get("slug", ""))})
	_update_mate()
	_update_extra_guest()
	_mind_poll -= 0.1
	if _mind_poll <= 0.0:
		_mind_poll = 1.0
		_update_minds()


func _update_minds() -> void:
	_guest_minds.clear()
	_sleepers.clear()
	if GuestManager == null or not GuestManager.has_method("get_guest_life_snapshot"):
		return
	for g in GuestManager.get_guest_life_snapshot():
		if not (g is Dictionary):
			continue
		var think := ""
		var worst: Dictionary = g.get("worst_need", {})
		var wv := float(worst.get("value", 100.0)) if not worst.is_empty() else 100.0
		var wk := str(worst.get("need", worst.get("key", "")))
		var thought := str(g.get("thought", "")).to_lower()
		if (thought.contains("cold") or thought.contains("froze") or thought.contains("ice")) and int(g.get("thought_age", 9999)) < 240:
			think = "cold"
		elif wv < THINK_NEED and THINK_TEX.has(wk):
			think = wk
		elif float(g.get("mood", 50.0)) > 78.0:
			think = "happy"
		# The face over them (RCT's): how they feel now, a beat of its own.
		var needs: Dictionary = g.get("needs", {})
		var mood := float(g.get("mood", 50.0))
		var react := ""
		if float(needs.get("safety", 100.0)) < 30.0:
			react = "alert"
		elif float(needs.get("bladder", 100.0)) < 22.0:
			react = "sweat"
		elif mood < 25.0:
			react = "angry"
		elif str(g.get("archetype", "")) == "drunk" and float(_wx.get("hour", 12.0)) >= 17.0:
			# The drunk in the evening: one beat sick, one singing.
			react = "sick" if (int(g.get("id", 0)) + int(_guest_time / 9.0)) % 2 == 0 else "notes"
		elif mood > 82.0:
			react = ["hearts", "notes", "smile"][int(g.get("id", 0)) % 3]
		_guest_minds[int(g.get("id", -1))] = {"think": think, "value": wv, "react": react}
		# Asleep in their lodging: a Zzz over its roof.
		var lodg = g.get("lodging", null)
		if str(g.get("status", "")) == "sleep" and lodg is Vector2i and (lodg as Vector2i).x >= 0:
			_sleepers[lodg] = true


## The guest under a point of the panel (any of their party's figures), or -1.
func guest_at(local_pos: Vector2) -> int:
	if grid_manager == null:
		return -1
	if _in_3d():
		return map3d.guest_at(local_pos)
	var iso = _compute_iso_layout(int(grid_manager.grid_width), int(grid_manager.grid_height))
	var mini_h := clampi(int(round(iso.tile_h * 1.1 / 4.0)) * 4, 12, 56)
	var best := -1
	var best_d := 1e9
	for id in _guests:
		for m in _guests[id].get("members", [{"cell": _guests[id]["cell"]}]):
			var foot := _cell_to_iso_f(m["cell"], iso.origin, iso.tile_w, iso.tile_h)
			var r := Rect2(foot - Vector2(mini_h * 0.35, mini_h), Vector2(mini_h * 0.7, mini_h + 2.0))
			if r.has_point(local_pos):
				var d := foot.distance_to(local_pos)
				if d < best_d:
					best_d = d
					best = int(id)
	return best


## The map drifts to keep a guest in the middle (their card's Follow).
func follow_guest(id: int, delta: float) -> bool:
	if not _guests.has(id):
		return false
	if _in_3d():
		map3d.follow(Vector2(_guests[id]["cell"]))
		return true
	var want := size * 0.5 - _cell_iso(Vector2(_guests[id]["cell"]))
	_pan_offset += want * clampf(delta * 3.0, 0.0, 1.0)
	_pan_vel = Vector2.ZERO
	_clamp_pan_offset_for_current_map()
	return true


func guest_cell(id: int) -> Vector2:
	return Vector2(_guests[id]["cell"]) if _guests.has(id) else Vector2.INF


## Co-op: the other warden on the map in their own look, where they walk; in a lodging
## or a block, at its door (a room key is its cell).
var _mates: Dictionary = {}   # peer id -> {cell, moving}
## The staffroom's hands at work in the camp: [{cell, moving, texture, flip, slug}].
var _hands: Array = []


func _update_mate() -> void:
	var prev := _mates
	_mates = {}
	for id in Coop.others():
		var cell := Vector2.INF
		var fig := Coop.figure_of(id)
		if fig != null and fig.visible:
			cell = _world_to_cell_f(fig.global_position)
		else:
			var key := str((Coop.state_of(id).get("room", {}) as Dictionary).get("k", ""))
			if key.contains(":"):
				# Several in one room: side by side at its door.
				cell = Vector2(float(key.get_slice(":", 0)), float(key.get_slice(":", 1))) + Vector2(0.3 + 0.2 * float(Coop.others().find(id) % 3), 0.9)
		if cell == Vector2.INF:
			continue
		var was: Dictionary = prev.get(id, {})
		var moving := not was.is_empty() and Vector2(was.get("cell", cell)).distance_to(cell) > 0.004
		_mates[id] = {"cell": cell, "moving": moving}


func _update_extra_guest() -> void:
	if _guest_time < _extra_guest_until or _guests.is_empty():
		return
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null:
		return
	var hour := 0.0
	var tree := get_tree()
	var main = tree.current_scene if tree != null else null
	if main != null:
		hour = float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 0.0
	# Only from late afternoon, rarely (roughly once per in-game evening at the PC).
	if hour < 16.5 or _extra_guest_rng.randf() > 0.0016:
		return
	var gw := float(grid_manager.grid_width)
	var gh := float(grid_manager.grid_height)
	var edge := _extra_guest_rng.randi_range(0, 3)
	var t := _extra_guest_rng.randf_range(0.1, 0.9)
	match edge:
		0: _extra_guest_cell = Vector2(t * gw, 0.4)
		1: _extra_guest_cell = Vector2(gw - 1.4, t * gh)
		2: _extra_guest_cell = Vector2(t * gw, gh - 2.4)
		_: _extra_guest_cell = Vector2(0.4, t * gh)
	_extra_guest_until = _guest_time + _extra_guest_rng.randf_range(14.0, 26.0)


func _world_to_cell_f(p: Vector3) -> Vector2:
	var mc: Vector3 = grid_manager.get_map_min_corner() if grid_manager.has_method("get_map_min_corner") else Vector3.ZERO
	var ts: float = float(grid_manager.tile_size)
	return Vector2((p.x - mc.x) / ts - 0.5, (p.z - mc.z) / ts - 0.5)


## Display-space cell (the map is drawn rotated), fractional.
func _display_cell_f(c: Vector2) -> Vector2:
	var gw := float(grid_manager.grid_width)
	var gh := float(grid_manager.grid_height)
	match wrapi(view_rot, 0, 4):
		1: return Vector2(c.y, gw - 1.0 - c.x)
		2: return Vector2(gw - 1.0 - c.x, gh - 1.0 - c.y)
		3: return Vector2(gh - 1.0 - c.y, c.x)
	return c


## Same projection as _grid_to_iso, for fractional cells.
func _cell_iso_fast(c: Vector2, origin: Vector2, tile_w: float, tile_h: float) -> Vector2:
	return _cell_to_iso_f(c, origin, tile_w, tile_h)


func _cell_to_iso_f(c: Vector2, origin: Vector2, tile_w: float, tile_h: float) -> Vector2:
	var d := _display_cell_f(c)
	return origin + Vector2((d.x - d.y) * tile_w * 0.5, (d.x + d.y) * tile_h * 0.5)


func _append_guest_entries(entries: Array, origin: Vector2, tile_w: float, tile_h: float) -> void:
	for id in _guests.keys():
		var g: Dictionary = _guests[id]
		var members: Array = g.get("members", [])
		for i in members.size():
			var m: Dictionary = members[i]
			var p := _cell_to_iso_f(m["cell"], origin, tile_w, tile_h)
			var dc := _display_cell_f(m["cell"])
			entries.append({"guest": true, "id": int(id), "member": i, "pos": p, "order": dc.x + dc.y + 0.6, "archetype": g["archetype"], "moving": g["moving"],
				"phase": float(g["phase"]) + float(i) * 0.7, "dir": int(g.get("dir", 0)), "mirror": bool(g.get("mirror", false)), "pose": str(m.get("pose", "")),
				"flip": bool(m.get("flip", false)), "kind": str(g.get("kind", "")), "posed": bool(g.get("posed", false))})
	for id in _mates.keys():
		var m: Dictionary = _mates[id]
		var pm := _cell_to_iso_f(m["cell"], origin, tile_w, tile_h)
		var dm := _display_cell_f(m["cell"])
		entries.append({"guest": true, "mate": int(id), "pos": pm, "order": dm.x + dm.y + 0.6, "archetype": "", "moving": m["moving"], "phase": float(id % 7)})
	for h in _hands:
		var ph := _cell_to_iso_f(h["cell"], origin, tile_w, tile_h)
		var dh := _display_cell_f(h["cell"])
		entries.append({"guest": true, "hand": h, "pos": ph, "order": dh.x + dh.y + 0.6, "archetype": "", "moving": h["moving"], "phase": float(hash(str(h["slug"])) % 7)})
	if _guest_time < _extra_guest_until:
		var p2 := _cell_to_iso_f(_extra_guest_cell, origin, tile_w, tile_h)
		var dc2 := _display_cell_f(_extra_guest_cell)
		entries.append({"guest": true, "pos": p2, "order": dc2.x + dc2.y + 0.6, "archetype": "", "moving": false, "phase": 0.0, "extra": true})
	entries.sort_custom(func(a, b): return float(a["order"]) < float(b["order"]))


## A guest as RCT drew them: a few pixels tall, shirt colour by archetype, head,
## legs that scissor when walking. Sized to the tile so zoom keeps proportions.
const GUEST_SPRITES := {
	"quiet_guy": "res://assets/textury/npc/host1.png", "drunk": "res://assets/textury/npc/host2.png",
	"cheap_chick": "res://assets/textury/npc/host3.png", "tramp": "res://assets/textury/npc/host_tramp.png",
	"family": "res://assets/textury/npc/host_family.png", "picker": "res://assets/textury/npc/host_pensioner.png",
}


## The guest's sprite brought down to `h` pixels tall once (smooth, then drawn 1:1 so it
## stays crisp), for each archetype and size.
func _guest_mini(archetype: String, h: int) -> Texture2D:
	var key := archetype if GUEST_SPRITES.has(archetype) else "quiet_guy"
	var by: Dictionary = _guest_minis.get(key, {})
	if by.has(h):
		return by[h]
	var path: String = GUEST_SPRITES[key]
	if not ResourceLoader.exists(path):
		return null
	var tex := _mini_of(load(path) as Texture2D, h)
	by[h] = tex
	_guest_minis[key] = by
	return tex


## Another warden's miniature: their look and jacket (warden_looks.gd).
func _mate_mini(h: int, id: int) -> Texture2D:
	var look: Dictionary = Coop.look_of(id)
	var key := "mate|%d|%d" % [int(look.get("m", 1)), int(look.get("c", 0))]
	var by: Dictionary = _guest_minis.get(key, {})
	if not by.has(h):
		var src: Texture2D = WARDEN_LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), "stand")
		if src == null:
			return null
		by[h] = _mini_of(src, h)
		_guest_minis[key] = by
	return by[h]


func _mini_of(src: Texture2D, h: int) -> Texture2D:
	var img := src.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	var w := maxi(2, int(round(float(img.get_width()) * float(h) / float(img.get_height()))))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	# Hard alpha: no fringe at this size.
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.a = 1.0 if c.a > 0.45 else 0.0
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _draw_think(e: Dictionary, foot: Vector2, sz: Vector2) -> void:
	var mind: Dictionary = _guest_minds.get(int(e.get("id", -1)), {})
	var think := str(mind.get("think", ""))
	# Their face (RCT's): between the bubbles, on a beat of its own.
	var react := str(mind.get("react", ""))
	var rt: Texture2D = _react_tex.get(react)
	if rt != null and fmod(_guest_time + float(e["phase"]) * 3.0 + 4.5, 9.0) < 2.0:
		var rs := clampf(sz.y * 0.55, 10.0, 18.0)
		var hop := -1.0 if int(_guest_time * 6.0) % 2 == 0 else 0.0
		_cv.draw_texture_rect(rt, Rect2((foot + Vector2(-rs * 0.5, -sz.y - rs - 1.0 + hop)).floor(), Vector2(rs, rs)), false)
	if think == "":
		return
	# Up for two and a half seconds in every nine, each guest on their own beat.
	if fmod(_guest_time + float(e["phase"]) * 3.0, 9.0) > 2.5:
		return
	if not _think_tex.has(think):
		var p := str(THINK_TEX.get(think, ""))
		_think_tex[think] = load(p) if p != "" and ResourceLoader.exists(p) else null
	var tex: Texture2D = _think_tex[think]
	if tex == null:
		return
	var bs := clampf(sz.y * 0.7, 12.0, 24.0)
	_cv.draw_texture_rect(tex, Rect2((foot + Vector2(sz.x * 0.1, -sz.y - bs + 2.0)).floor(), Vector2(bs, bs)), false)


## The map's own little people (Grok gst_*, tools/artgen: peeps/<kind>_<0-7>.png): 0-1
## walking towards you, 2-3 walking away (mirrored for the other way), 4-5 and 6-7 two
## things each kind does when it has nothing on: the quiet man watching the lake and
## smoking, the drunk staggering and being sick, the woman in heels smoking and carrying
## her shopping, the tramp strumming on a log and carrying firewood, the father hanging
## washing and the boy kicking a ball, the old picker after a mushroom and eating.
## Without them (or at an attraction) they are the camp's own picture of them, posed as
## the camp poses them (sat at the fire, eating, a kick).
const PEEP_DIR := "res://assets/textury/builder/peeps/"
const PEEP_KIND := {"quiet_guy": "quiet", "drunk": "drunk", "cheap_chick": "chick", "tramp": "tramp", "family": "family", "picker": "picker"}
## The faces over them (Grok bld_react, builder/react/<name>.png).
const REACT_DIR := "res://assets/textury/builder/react/"
const REACTS := ["smile", "angry", "sick", "hearts", "notes", "zzz", "sweat", "alert"]
var _peeps: Dictionary = {}       # kind -> [8 textures] (or [])
var _react_tex: Dictionary = {}
var _sleepers: Dictionary = {}    # lodging origin -> true: somebody asleep in it
var _pose_minis: Dictionary = {}  # "path|h" -> texture


func _load_peeps() -> void:
	for a in PEEP_KIND:
		var kind := str(PEEP_KIND[a])
		var frames: Array = []
		for i in 8:
			var path := PEEP_DIR + "%s_%d.png" % [kind, i]
			if not ResourceLoader.exists(path):
				frames = []
				break
			frames.append(load(path))
		_peeps[kind] = frames
	for r in REACTS:
		var path := REACT_DIR + str(r) + ".png"
		_react_tex[r] = load(path) if ResourceLoader.exists(path) else null


## A picture brought down to `h` pixels tall once (the camp's pose pictures are 128 px).
func _pose_mini(path: String, h: int) -> Texture2D:
	var key := "%s|%d" % [path, h]
	if not _pose_minis.has(key):
		_pose_minis[key] = _mini_of(load(path) as Texture2D, h) if path != "" and ResourceLoader.exists(path) else null
	return _pose_minis[key]


## The frame of a little person now: walking, their kind's own doings, or null (the
## camp's pose picture instead).
func _peep_frame(e: Dictionary, h: int) -> Array:
	var frames: Array = _peeps.get(str(PEEP_KIND.get(str(e.get("archetype", "")), "")), [])
	if frames.is_empty():
		return []
	var beat := int(floorf((_guest_time + float(e["phase"])) * 4.0))
	var i := -1
	var mirror := bool(e.get("mirror", false))
	if bool(e["moving"]):
		i = (0 if int(e.get("dir", 0)) == 0 else 2) + beat % 2
	elif not bool(e.get("posed", false)) and not ["sleep", "rest", "wait_gate", "arrive", "away"].has(str(e.get("kind", ""))):
		# Standing about: now one of their doings, now the other, now just standing.
		var spell := (int(e.get("id", 0)) * 7 + int(_guest_time / 14.0)) % 3
		if spell == 2:
			return []
		i = 4 + spell * 2 + int(floorf((_guest_time + float(e["phase"])) * 2.5)) % 2
		mirror = bool(e.get("flip", false))
	if i < 0:
		return []
	# Every frame at the walking frame's scale (one bent over or sat is lower, not squeezed).
	var key := "peep|%s|%d|%d" % [str(e.get("archetype", "")), i, h]
	if not _pose_minis.has(key):
		var base := float((frames[0] as Texture2D).get_height())
		_pose_minis[key] = _mini_of(frames[i], maxi(4, int(round(float((frames[i] as Texture2D).get_height()) * float(h) / maxf(1.0, base)))))
	return [_pose_minis[key], mirror]


func _draw_guest(e: Dictionary, tile_h: float) -> void:
	var mini_h := clampi(int(round(tile_h * 1.1 / 4.0)) * 4, 12, 56)
	var tex: Texture2D = null
	var mirror := false
	if e.has("mate"):
		tex = _mate_mini(mini_h, int(e["mate"]))
	elif e.has("hand"):
		var hand: Dictionary = e["hand"]
		var ht = hand.get("texture")
		if ht is Texture2D:
			var hk := "hand|%s|%s|%d" % [str(hand["slug"]), str((ht as AtlasTexture).region) if ht is AtlasTexture else str(ht.get_rid()), mini_h]
			if not _pose_minis.has(hk):
				_pose_minis[hk] = _mini_of(ht, mini_h)
			tex = _pose_minis[hk]
			mirror = bool(hand.get("flip", false))
	elif not e.has("extra"):
		var pf := _peep_frame(e, mini_h)
		if not pf.is_empty():
			tex = pf[0]
			mirror = bool(pf[1])
		else:
			var pose := str(e.get("pose", ""))
			tex = _pose_mini(pose, mini_h) if pose != "" else _guest_mini(str(e["archetype"]), mini_h)
			mirror = bool(e.get("flip", false))
	if tex != null:
		var bob := 0.0
		if bool(e["moving"]) and _peeps.get(str(PEEP_KIND.get(str(e.get("archetype", "")), "")), []).is_empty():
			bob = -1.0 if fmod(_guest_time * 6.0 + float(e["phase"]), 2.0) < 1.0 else 0.0
		var foot: Vector2 = Vector2(e["pos"]).floor()
		var sz := tex.get_size()
		_cv.draw_rect(Rect2(foot + Vector2(-sz.x * 0.4, -1.0), Vector2(sz.x * 0.8, 2.0)), Color(0, 0, 0, 0.35))
		var at := (foot - Vector2(sz.x * 0.5, sz.y - bob)).floor()
		if mirror:
			_cv.draw_set_transform(at + Vector2(sz.x, 0), 0.0, Vector2(-1, 1))
			_cv.draw_texture(tex, Vector2.ZERO)
			_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_cv.draw_texture(tex, at)
		if not e.has("mate") and int(e.get("member", 0)) == 0:
			_draw_think(e, foot, sz)
		if e.has("mate"):
			# Their name over them, so they are not taken for a guest.
			var who := Coop.name_of(int(e["mate"]))
			var tw := T.FONT.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			_draw_tag(foot - Vector2(tw * 0.5 + 3.0, sz.y + 17.0), who, false)
		return
	var u := maxf(2.0, roundf(tile_h * 0.12))
	var p: Vector2 = (Vector2(e["pos"]) / u).floor() * u
	var shirt: Color = GUEST_SHIRTS.get(str(e["archetype"]), Color(0.55, 0.52, 0.48))
	var skin := GUEST_SKIN
	if e.has("extra"):
		# Greyer, darker, too tall by one pixel, perfectly still.
		shirt = Color(0.20, 0.21, 0.22)
		skin = Color(0.62, 0.64, 0.66)
	var step := 0.0
	if bool(e["moving"]):
		step = 1.0 if fmod(_guest_time * 6.0 + float(e["phase"]), 2.0) < 1.0 else -1.0
	var legs := Color(0.20, 0.20, 0.26)
	var h := 7.0 if e.has("extra") else 6.0
	# shadow
	_cv.draw_rect(Rect2(p + Vector2(-1.5 * u, -0.5 * u), Vector2(3.0 * u, u)), Color(0, 0, 0, 0.35))
	# legs
	_cv.draw_rect(Rect2(p + Vector2(-u, -2.0 * u), Vector2(u, 2.0 * u + (step if step > 0 else 0.0) * 0.0)), legs)
	_cv.draw_rect(Rect2(p + Vector2(0.0, -2.0 * u), Vector2(u, 2.0 * u)), legs)
	if step != 0.0:
		_cv.draw_rect(Rect2(p + Vector2(-u + step * u, -u), Vector2(u, u)), legs)
	# body
	_cv.draw_rect(Rect2(p + Vector2(-u, -(h - 2.0) * u), Vector2(2.0 * u, (h - 4.0) * u)), shirt)
	# head
	_cv.draw_rect(Rect2(p + Vector2(-u, -h * u), Vector2(2.0 * u, 2.0 * u)), skin)
	if e.has("extra"):
		# Two dots for eyes, which none of the others have.
		_cv.draw_rect(Rect2(p + Vector2(-u, -(h - 1.0) * u), Vector2(u * 0.5, u * 0.5)), Color(0, 0, 0))
		_cv.draw_rect(Rect2(p + Vector2(0.5 * u, -(h - 1.0) * u), Vector2(u * 0.5, u * 0.5)), Color(0, 0, 0))


## Where a structure's picture covers (in the static layer), roughly for the old pictures.
func _cover_rect(entry: Dictionary, tile_w: float, tile_h: float) -> Rect2:
	var c: Vector2 = entry["center"]
	var root = entry.get("root")
	if root != null and (root.is_in_group("trees") or root.is_in_group("corn")):
		return Rect2(c - Vector2(tile_w * 0.6, tile_h * 1.6), Vector2(tile_w * 1.2, tile_h * 1.9))
	var view := _view_of(_icon_key_for_type(str(entry.get("type", ""))), int(entry.get("rotation", 0)))
	if not view.is_empty():
		var k := tile_w / VIEW_PX
		return Rect2(c - (view[1] as Vector2) * k, (view[0] as Texture2D).get_size() * k)
	var fp: Vector2i = entry.get("footprint", Vector2i.ONE)
	var w := float(fp.x + fp.y) * tile_w * 0.5
	return Rect2(c - Vector2(w * 0.5, tile_h * 2.2), Vector2(w, tile_h * 2.6))


## The structures in front of a guest drawn again over them, where they overlap.
func _draw_occluders(entries: Array, tile_w: float, tile_h: float) -> void:
	if _occ.is_empty():
		return
	var mini_h := clampi(int(round(tile_h * 1.1 / 4.0)) * 4, 12, 56)
	var k := _static_layer.scale.x
	var done := {}
	for g in entries:
		var foot: Vector2 = g["pos"]
		var gr := Rect2(foot - Vector2(mini_h * 0.4, mini_h + 4.0), Vector2(mini_h * 0.8, mini_h + 6.0))
		var order := float(g.get("order", 0.0))
		for i in _occ.size():
			var o: Array = _occ[i]
			if done.has(i) or float(o[0]) <= order - 0.25:
				continue
			var r: Rect2 = o[2]
			var on_panel := Rect2(_s2d(r.position), r.size * k)
			if not on_panel.intersects(gr):
				continue
			done[i] = true
			var moved: Dictionary = (o[1] as Dictionary).duplicate()
			moved["center"] = _s2d(o[1]["center"])
			_draw_structure(moved, tile_w, tile_h)


## A Zzz over every lodging somebody sleeps in, rising in steps.
func _draw_sleepers(origin: Vector2, tile_w: float, tile_h: float) -> void:
	var tex: Texture2D = _react_tex.get("zzz")
	if tex == null or _sleepers.is_empty():
		return
	for o in _sleepers:
		var f: Vector2i = (_known.get(o, ["", Vector2i.ONE]) as Array)[1]
		var c := _footprint_center_iso(o, f, origin, tile_w, tile_h)
		var rise := float(int(_time * 3.0 + float(o.x)) % 4) * 2.0
		var bs := clampf(tile_h * 0.5, 10.0, 20.0)
		_cv.draw_texture_rect(tex, Rect2((c + Vector2(tile_w * 0.1, -tile_h * 1.4 - rise)).floor(), Vector2(bs, bs)), false, Color(1, 1, 1, 0.9))


func _hash01(c: Vector2i) -> float:
	var n := (c.x * 73856093) ^ (c.y * 19349663)
	return float(absi(n) % 1000) / 1000.0


func _draw_structure(entry: Dictionary, tile_w: float, tile_h: float) -> void:
	var root = entry.get("root", null)
	if root == null:
		return
	var center: Vector2 = entry.get("center", Vector2.ZERO)
	var footprint: Vector2i = entry.get("footprint", Vector2i.ONE)
	var rotation_steps: int = wrapi(int(entry.get("rotation", 0)), 0, 4)
	var building_type = str(entry.get("type", ""))

	if root.is_in_group("corn"):
		if _draw_icon(center, Vector2(tile_w * 1.02, tile_h * 2.3), "corn", 0, Color(1.0, 1.0, 1.0, 0.98)):
			return
	if root.is_in_group("trees"):
		var tk := "tree"
		if _swaying:
			var dc := _rotate_coord_for_display(entry.get("origin", Vector2i.ZERO))
			tk = "tree_sway_%d" % [1, 0, 1, 2, 1, 3][(_sway_step + dc.x / 2 + (dc.y % 3)) % 6]
		if not _draw_icon(center, Vector2(maxf(12.0, tile_w * 1.22), maxf(12.0, tile_h * 1.85)), tk, 0, Color(1.0, 1.0, 1.0, 0.98)):
			_draw_tree_fallback(center, tile_w, tile_h)
		return

	if building_type == "path":
		_draw_path(center, entry.get("origin", Vector2i.ZERO), tile_w, tile_h)
		if _path_has_lamp(entry.get("origin", Vector2i.ZERO)):
			var po: Vector2i = entry.get("origin", Vector2i.ZERO)
			var lc := _path_lamp_point(po, center, tile_w, tile_h)
			# Turned as the camp turns it, its arm over the path (LampSpot.yaw).
			var turn := wrapi(roundi(LampSpot.yaw(LampSpot.offset(po, Callable(self, "_path_cell"))) / (PI * 0.5)), 0, 4)
			var lamp := _view_of("lamp_post", turn)
			if not lamp.is_empty():
				_draw_view(lamp, lc, Color.WHITE, tile_w)
			else:
				_draw_icon(lc, Vector2(tile_w * 0.6, tile_h * 1.5), _icon_key_for_type("lamp_post"), 0, Color.WHITE)
		return

	var icon_key = _icon_key_for_type(building_type)
	if icon_key != "":
		var squash := 1.0
		# Freshly built: a building site for a moment, then it stands up with a bounce.
		var origin_c: Vector2i = entry.get("origin", Vector2i.ZERO)
		if _dropped.has(origin_c):
			var age := _time - float(_dropped[origin_c])
			var site := float(_site_len.get(origin_c, 0.0))
			if age < site:
				_draw_site(center, footprint, age, tile_w, tile_h, site)
				return
			age -= site
			var k := clampf(age / 0.3, 0.0, 1.0)
			squash = (0.82 + 0.18 * k + 0.1 * sin(k * PI)) if k < 1.0 else 1.0
		if _draw_building_icon(center, footprint, icon_key, rotation_steps, Color(1.0, 1.0, 1.0, 0.98), tile_w, tile_h, squash):
			return

	_draw_placeholder(center, tile_w, tile_h, building_type)


## A path tile as the camp lays it (scripts/path_tiles.gd: composed from its eight
## neighbours, a block of paths one gravel yard), the texture laid on the tile's diamond:
## u along the grid's x, v along its y, however the map is turned.
func _draw_path(center: Vector2, coord: Vector2i, tile_w: float, tile_h: float) -> void:
	var tex := PATH_TILES.texture(PATH_TILES.mask_at(coord, Callable(self, "_is_path_at")))
	var ax := _path_screen_step(Vector2i(1, 0), tile_w, tile_h)
	var ay := _path_screen_step(Vector2i(0, 1), tile_w, tile_h)
	_cv.draw_set_transform_matrix(Transform2D(ax, ay, center - (ax + ay) * 0.5))
	_cv.draw_texture_rect(tex, Rect2(0, 0, 1, 1), false)
	_cv.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_tree_fallback(center: Vector2, tile_w: float, tile_h: float) -> void:
	var trunk = Rect2(center.x - tile_w * 0.07, center.y - tile_h * 0.16, tile_w * 0.14, tile_h * 0.36)
	_cv.draw_rect(trunk, Color(0.30, 0.22, 0.14), true)
	var canopy = PackedVector2Array([
		Vector2(center.x, center.y - tile_h * 0.92),
		Vector2(center.x + tile_w * 0.34, center.y - tile_h * 0.22),
		Vector2(center.x - tile_w * 0.34, center.y - tile_h * 0.22),
	])
	_cv.draw_colored_polygon(canopy, Color(0.20, 0.50, 0.22))


func _draw_placeholder(center: Vector2, tile_w: float, tile_h: float, building_type: String) -> void:
	var fill = Color(0.54, 0.52, 0.50)
	if building_type == "power_generator":
		fill = Color(0.48, 0.50, 0.44)
	var top_center = center + Vector2(0.0, -tile_h * 0.14)
	var top = _diamond_points(top_center, tile_w * 0.56, tile_h * 0.36)
	_cv.draw_colored_polygon(top, fill)
	_cv.draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), Color(0.14, 0.14, 0.14), 1.0)


## How far a light reaches on the ground, in tiles (the light overlay and the ghost).
const LIGHT_REACH := {"lamp_post": 2.6, "lamp": 2.6, "bonfire": 3.4}


## A pool of light on the ground: flat ellipses, brighter to the middle.
func _draw_light_pool(center: Vector2, r: float, a: float) -> void:
	_cv.draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
	for k in 4:
		_cv.draw_circle(Vector2.ZERO, r * (1.0 - k * 0.22), Color(1.0, 0.85, 0.4, a))
	_cv.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1.0, 0.9, 0.5, a * 4.0), 1.0)
	_cv.draw_set_transform(Vector2.ZERO)


## The camp in the middle and close enough to read (the first time Builder opens: it
## started so far out the camp was a smudge).
func focus_camp(zoom := 2.2) -> bool:
	var gm = _grid_model()
	if gm == null or size.x <= 0.0:
		return false
	for c in gm.cells:
		if str((gm.cells[c] as Dictionary).get("type", "")) == "main_building":
			_zoom_level = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
			_zoom_target = _zoom_level
			_static_dirty = true
			_pan_offset = Vector2.ZERO
			debug_center_on(c)
			return true
	# A camp with no office (tools): nothing to look for again.
	return not gm.cells.is_empty()


func _draw_ghost_preview(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if selected_building == "" or selected_building == "path" or selected_building == "demolish":
		return
	if _row_drag and _row_line.size() > 1:
		_draw_row_preview(origin, tile_w, tile_h)
		return
	var coord = _ghost_coord if _ghost_locked else hover_coord
	if not _is_valid_coord(coord):
		return
	var footprint = _get_footprint(selected_building)
	var can_fit = _can_place(coord, footprint, selected_building)
	var can_afford = _has_money(selected_building)
	var can_place = can_fit and can_afford
	var cells: Array = []
	for oy in range(footprint.y):
		for ox in range(footprint.x):
			var c = coord + Vector2i(ox, oy)
			if _is_valid_coord(c):
				cells.append(c)
	var iso_g := Callable(self, "_cell_iso_fast").bind(origin, tile_w, tile_h)
	var col := Color(0.55, 0.85, 1.0) if can_place else (Color(1.0, 0.78, 0.36) if can_fit else Color(1.0, 0.36, 0.3))
	_bfx.draw_area(_cv, iso_g, cells, tile_w, tile_h, col, _time, not can_fit, 0.2 if can_place else 0.26)

	var center = _footprint_center_iso(coord, footprint, origin, tile_w, tile_h)
	var icon_key = _icon_key_for_type(selected_building)
	if icon_key != "":
		_draw_building_icon(center, footprint, icon_key, _rotation_steps, Color(0.62, 0.82, 1.0, 0.76), tile_w, tile_h)

	# A light: where it will reach, and (fainter) where the others already do.
	if LIGHT_REACH.has(selected_building):
		for l in _lights:
			_draw_light_pool(_s2d(l[0]), tile_w * float(LIGHT_REACH.get(str(l[1]), 2.6)), 0.05)
		_draw_light_pool(center, tile_w * float(LIGHT_REACH[selected_building]), 0.11)
	if _supports_rotation(selected_building):
		var dir = _rotation_to_screen_dir(_rotation_steps, tile_w, tile_h)
		_draw_direction_arrow(center + Vector2(0.0, -tile_h * 0.10), dir, tile_h, Color(0.66, 0.90, 1.0, 0.98))
	# The price on a little tag, red when it does not fit or you cannot pay.
	var tag := "$%d" % _get_cost(selected_building)
	if not can_fit:
		tag = _blocked_reason(coord, footprint)
	elif not can_afford:
		tag = "$%d - no money" % _get_cost(selected_building)
	var tw := T.FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var tp := (center + Vector2(tile_w * 0.45, -tile_h * 1.4)).floor()
	_cv.draw_rect(Rect2(tp, Vector2(tw + 6, 14)), T.TOOLTIP if can_place else Color8(255, 210, 210))
	_cv.draw_rect(Rect2(tp, Vector2(tw + 6, 14)), T.DARK, false, 1.0)
	_cv.draw_string(T.FONT, tp + Vector2(3, 11), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)


func _draw_path_drag_preview(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if not _path_drag_active or _path_line.is_empty():
		return
	var iso_c := Callable(self, "_cell_iso_fast").bind(origin, tile_w, tile_h)
	var cost := _get_cost("path")
	var afford := 1 << 30
	if cost > 0:
		afford = int(CoreRoot.get_money()) / cost
	var groups := [[], [], [], []]   # new, already path, blocked, new but no money
	var n_new := 0
	for e in _path_line:
		var kind := int(e[1])
		if kind == PATH_NEW:
			n_new += 1
			if n_new > afford:
				kind = 3
		groups[kind].append(e[0])
	_bfx.draw_area(_cv, iso_c, groups[PATH_HAVE], tile_w, tile_h, _bfx.BLUE, _time, false, 0.12)
	_bfx.draw_area(_cv, iso_c, groups[PATH_NEW], tile_w, tile_h, _bfx.AMBER, _time, false, 0.30)
	_bfx.draw_area(_cv, iso_c, groups[PATH_BLOCKED], tile_w, tile_h, _bfx.RED, _time, true, 0.22)
	_bfx.draw_area(_cv, iso_c, groups[3], tile_w, tile_h, _bfx.RED, _time, false, 0.14)
	var tag := "%d %s  $%d" % [n_new, "tile" if n_new == 1 else "tiles", n_new * cost]
	var bad := n_new == 0 or n_new > afford
	if n_new == 0:
		tag = "Nothing new" if groups[PATH_BLOCKED].is_empty() else "Blocked"
	elif n_new > afford:
		tag += " - money for %d" % afford
	var end: Vector2i = _path_line.back()[0]
	_draw_tag(iso_c.call(Vector2(end)) + Vector2(tile_w * 0.45, -tile_h * 1.4), tag, bad)


## A small priced tag (the ghost's), pale red when it is a no.
func _draw_row_preview(origin: Vector2, tile_w: float, tile_h: float) -> void:
	var icon_key := _icon_key_for_type(selected_building)
	var iso_g := Callable(self, "_cell_iso_fast").bind(origin, tile_w, tile_h)
	var n := 0
	for e in _row_line:
		var c: Vector2i = e[0]
		var ok := bool(e[1])
		_bfx.draw_area(_cv, iso_g, [c], tile_w, tile_h, Color(0.55, 0.85, 1.0) if ok else Color(1.0, 0.36, 0.3), _time, not ok, 0.2)
		if ok:
			n += 1
			if icon_key != "":
				_draw_building_icon(_footprint_center_iso(c, Vector2i.ONE, origin, tile_w, tile_h), Vector2i.ONE, icon_key, _rotation_steps, Color(0.62, 0.82, 1.0, 0.7), tile_w, tile_h)
	var cost := n * _get_cost(selected_building)
	var afford := int(CoreRoot.get_money()) >= cost
	var last: Vector2i = _row_line.back()[0]
	var tag := "%d x $%d = $%d" % [n, _get_cost(selected_building), cost] if afford else "$%d - no money for all" % cost
	_draw_tag(_footprint_center_iso(last, Vector2i.ONE, origin, tile_w, tile_h) + Vector2(tile_w * 0.45, -tile_h * 1.4), tag, not afford or n == 0)


func _draw_tag(at: Vector2, tag: String, bad: bool) -> void:
	var tw := T.FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var tp := at.floor()
	tp.x = clampf(tp.x, 2.0, size.x - tw - 8.0)
	tp.y = clampf(tp.y, 2.0, size.y - 16.0)
	_cv.draw_rect(Rect2(tp, Vector2(tw + 6, 14)), Color8(255, 210, 210) if bad else T.TOOLTIP)
	_cv.draw_rect(Rect2(tp, Vector2(tw + 6, 14)), T.DARK, false, 1.0)
	_cv.draw_string(T.FONT, tp + Vector2(3, 11), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)


func _draw_demolish_preview(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if _demolish_drag_active:
		_draw_demolish_rect(_rect_from_points(_demolish_drag_start, _demolish_drag_end), origin, tile_w, tile_h, false)
	elif _demolish_selection_active:
		_draw_demolish_rect(_demolish_selection_rect, origin, tile_w, tile_h, true)


## The bulldozer's box as one shape (any size: per cell outlines cost too much on a big
## one), what it would take hatched red, and its price from the authority.
func _draw_demolish_rect(rect: Rect2i, origin: Vector2, tile_w: float, tile_h: float, chosen: bool) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var sum := _demolish_summary(rect)
	var p0 := Vector2(rect.position) - Vector2(0.5, 0.5)
	var p1 := Vector2(rect.end) - Vector2(0.5, 0.5)
	var pts := PackedVector2Array([
		_cell_iso_fast(p0, origin, tile_w, tile_h), _cell_iso_fast(Vector2(p1.x, p0.y), origin, tile_w, tile_h),
		_cell_iso_fast(p1, origin, tile_w, tile_h), _cell_iso_fast(Vector2(p0.x, p1.y), origin, tile_w, tile_h)])
	var col: Color = _bfx.RED
	_cv.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.16 if chosen else 0.10))
	# What goes: each such tile crossed, all in one call.
	var key := "%s|%s|%s" % [rect, origin.round(), snappedf(tile_w, 0.01)]
	if key != _demolish_hatch_key:
		_demolish_hatch_key = key
		_demolish_hatch = _demolish_target_lines(rect, origin, tile_w, tile_h)
	if not _demolish_hatch.is_empty():
		_cv.draw_multiline(_demolish_hatch, Color(col.r, col.g, col.b, 0.75), 1.0)
	var width := clampf(tile_h * 0.07, 1.0, 2.5)
	var loop := pts.duplicate()
	loop.append(pts[0])
	_cv.draw_polyline(loop, Color(col.r, col.g, col.b, 0.95), width + (1.0 if chosen else 0.0))
	# The light running round it, as round the other outlines.
	var total := 0.0
	for i in 4:
		total += pts[i].distance_to(pts[(i + 1) % 4])
	var head := fmod(_time * 0.9, 1.0) * total
	var run := 0.0
	for i in 4:
		var a := pts[i]
		var b := pts[(i + 1) % 4]
		var l := a.distance_to(b)
		var s0 := clampf((head - run) / maxf(l, 0.001), 0.0, 1.0)
		var s1 := clampf((head - run + tile_w * 1.2) / maxf(l, 0.001), 0.0, 1.0)
		if s1 > s0 and head - run < l:
			_cv.draw_line(a.lerp(b, s0), a.lerp(b, s1), Color(1, 1, 1, 0.85), width + 1.0)
		run += l
	var tag := "%dx%d" % [rect.size.x, rect.size.y]
	var bad := false
	if not sum.is_empty():
		if int(sum["count"]) == 0:
			tag += "  nothing to clear"
			bad = true
		else:
			tag += "  clear %d  $%d" % [int(sum["tiles"]), int(sum["fee"])]
			if int(sum["refund"]) > 0:
				tag += "  +$%d back" % int(sum["refund"])
			if int(CoreRoot.get_money()) < int(sum["fee"]):
				tag += " - no money"
				bad = true
		if chosen and not bad:
			tag += "  (click it / Enter)"
	var top := pts[0]
	for p in pts:
		if p.y < top.y:
			top = p
	_draw_tag(top + Vector2(-40, -20), tag, bad)


func _demolish_summary(rect: Rect2i) -> Dictionary:
	if rect != _demolish_sum_rect or _demolish_sum.is_empty():
		_demolish_sum_rect = rect
		var auth = CoreRoot.builder_authority if CoreRoot != null else null
		_demolish_sum = auth.summarize_demolish(rect) if auth != null and auth.has_method("summarize_demolish") else {}
	return _demolish_sum


## Two crossing lines over every tile in `rect` that holds a tree, corn or something built.
func _demolish_target_lines(rect: Rect2i, origin: Vector2, tile_w: float, tile_h: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var gm = _grid_model()
	if gm == null:
		return out
	var hw := tile_w * 0.32
	var hh := tile_h * 0.32
	for y in range(maxi(0, rect.position.y), mini(int(grid_manager.grid_height), rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(int(grid_manager.grid_width), rect.end.x)):
			var c := Vector2i(x, y)
			var occ = gm.occupants.get(c)
			if not is_instance_valid(occ) and not gm.cells.has(c):
				continue
			var t := str((gm.cells.get(c, {}) as Dictionary).get("type", ""))
			if t == "main_building" or t == "power_generator":
				continue
			var root = _resolve_occupant_root(occ) if is_instance_valid(occ) else null
			if root != null and bool(root.get_meta("permanent", false)):
				continue
			var p := _cell_iso_fast(Vector2(c), origin, tile_w, tile_h)
			out.append_array([p + Vector2(-hw, 0), p + Vector2(0, hh), p + Vector2(0, -hh), p + Vector2(hw, 0)])
	return out


func _draw_rotation_panel() -> void:
	if selected_building == "" or not _supports_rotation(selected_building):
		return
	var panel_size = Vector2(70.0, 76.0)
	# Bottom right: the minimap has the top right.
	var panel_pos = Vector2(size.x - panel_size.x - 6.0, size.y - panel_size.y - 6.0)
	var panel_rect = Rect2(panel_pos, panel_size)
	_cv.draw_style_box(T.box("window", T.FACE, Vector4.ZERO), panel_rect)

	var center = panel_rect.position + panel_rect.size * 0.5 + Vector2(0.0, -6.0)
	var active = _rotation_steps
	# Each way the building can face, where it lies on the map as it is turned now.
	var arrows: Array = []
	for id in 4:
		var sd := _rotation_to_screen_dir(id, 2.0, 1.0)
		arrows.append({"id": id, "pos": center + Vector2(sd.x * 20.0, sd.y * 18.0), "dir": sd})
	var round_only := _turns_round_only(selected_building)
	for arrow in arrows:
		var arrow_id = int(arrow.get("id", -1))
		if round_only and arrow_id % 2 == 1:
			continue
		var color = T.SHADOW
		if arrow_id == active:
			color = T.NAVY
		_draw_panel_arrow(arrow.get("pos", center), arrow.get("dir", Vector2.RIGHT), color)

	var label = ROTATION_LABELS[active]
	var lw := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_cv.draw_string(T.FONT, panel_rect.position + Vector2((panel_size.x - lw) * 0.5, panel_size.y - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)


func _draw_panel_arrow(pos: Vector2, direction: Vector2, color: Color) -> void:
	var dir = direction.normalized()
	var perp = Vector2(-dir.y, dir.x)
	var len = 8.0
	var wing = 4.0
	var tip = pos + dir * len
	var left = pos - dir * len * 0.25 + perp * wing
	var right = pos - dir * len * 0.25 - perp * wing
	var tri = PackedVector2Array([tip, left, right])
	_cv.draw_colored_polygon(tri, color)


func _draw_direction_arrow(anchor: Vector2, dir: Vector2, tile_h: float, color: Color) -> void:
	var safe_dir = dir
	if safe_dir.length_squared() < 0.001:
		safe_dir = Vector2(0.0, 1.0)
	safe_dir = safe_dir.normalized()
	var perp = Vector2(-safe_dir.y, safe_dir.x)
	var len = maxf(8.0, tile_h * 1.06)
	var wing = maxf(5.0, len * 0.46)
	var start = anchor - safe_dir * len * 0.5
	var tip = anchor + safe_dir * len * 0.5
	_cv.draw_line(start, tip, Color(0.0, 0.0, 0.0, 0.85), 3.9)
	_cv.draw_line(tip, tip - safe_dir * wing + perp * wing * 0.58, Color(0.0, 0.0, 0.0, 0.85), 3.9)
	_cv.draw_line(tip, tip - safe_dir * wing - perp * wing * 0.58, Color(0.0, 0.0, 0.0, 0.85), 3.9)
	_cv.draw_line(start, tip, color, 2.5)
	_cv.draw_line(tip, tip - safe_dir * wing + perp * wing * 0.58, color, 2.5)
	_cv.draw_line(tip, tip - safe_dir * wing - perp * wing * 0.58, color, 2.5)


func _draw_icon(center: Vector2, draw_size: Vector2, icon_key: String, rotation_steps: int, tint: Color) -> bool:
	var tex = _get_icon(icon_key)
	if tex == null:
		return false
	rotation_steps = _view_steps(icon_key, rotation_steps)
	var rs := wrapi(rotation_steps, 0, 4)
	var back: Texture2D = _get_back_icon(icon_key) if (rs == 1 or rs == 2) else null
	if back != null:
		tex = back
	var target_h = maxf(10.0, draw_size.y)
	var aspect = float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	var target_w = target_h * aspect
	var max_w = maxf(10.0, draw_size.x)
	if target_w > max_w:
		target_w = max_w
		target_h = target_w / maxf(0.001, aspect)
	var rect = Rect2(center.x - target_w * 0.5, center.y - target_h * 0.58, target_w, target_h)
	var mirror = (rs == 2) if back != null else _should_mirror_icon(icon_key, rotation_steps)
	if mirror:
		_cv.draw_set_transform(Vector2(rect.position.x + rect.size.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
		_cv.draw_texture_rect(tex, Rect2(Vector2.ZERO, rect.size), false, tint)
		_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_cv.draw_texture_rect(tex, rect, false, tint)
	return true


## A building's picture on the map: the drawn part of it as wide as the thing is
## (ICON_SPAN), standing on the front corner of the ground it covers. `squash` flattens it
## (the bounce when it lands).
func _draw_building_icon(center: Vector2, footprint: Vector2i, icon_key: String, rotation_steps: int, tint: Color, tile_w: float, tile_h: float, squash: float = 1.0) -> bool:
	var view := _view_of(icon_key, rotation_steps)
	if not view.is_empty():
		_draw_view(view, center, tint, tile_w, squash)
		return true
	var tex = _get_icon(icon_key)
	if tex == null:
		return false
	rotation_steps = _view_steps(icon_key, rotation_steps)
	var rs := wrapi(rotation_steps, 0, 4)
	var back: Texture2D = _get_back_icon(icon_key) if (rs == 1 or rs == 2) else null
	if back != null:
		tex = back
	var used := _drawn_rect(tex)
	var span := float(ICON_SPAN.get(icon_key, float(footprint.x + footprint.y) * 0.45))
	var k := span * tile_w / maxf(1.0, used.size.x)
	var mirror = (rs == 2) if back != null else _should_mirror_icon(icon_key, rotation_steps)
	var mid_x := (used.position.x + used.size.x * 0.5) * k
	if mirror:
		mid_x = float(tex.get_width()) * k - mid_x
	var foot := center.y + span * tile_h * 0.5
	var rect := Rect2(center.x - mid_x, foot - used.end.y * k * squash, float(tex.get_width()) * k, float(tex.get_height()) * k * squash)
	if mirror:
		_cv.draw_set_transform(Vector2(rect.position.x + rect.size.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
		_cv.draw_texture_rect(tex, Rect2(Vector2.ZERO, rect.size), false, tint)
		_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_cv.draw_texture_rect(tex, rect, false, tint)
	return true


## The part of a picture that is drawn (not its empty canvas), in its own pixels; read
## once from a small copy of it.
func _drawn_rect(tex: Texture2D) -> Rect2:
	var id := tex.get_instance_id()
	if _drawn_rects.has(id):
		return _drawn_rects[id]
	var r := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img != null:
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var sc := minf(1.0, 160.0 / float(maxi(img.get_width(), img.get_height())))
		img.resize(maxi(1, int(img.get_width() * sc)), maxi(1, int(img.get_height() * sc)), Image.INTERPOLATE_BILINEAR)
		var lo := Vector2i(img.get_width(), img.get_height())
		var hi := Vector2i(-1, -1)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.25:
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		if hi.x >= lo.x:
			var f := Vector2(tex.get_size()) / Vector2(img.get_width(), img.get_height())
			r = Rect2(Vector2(lo) * f, Vector2(hi - lo + Vector2i.ONE) * f)
	_drawn_rects[id] = r
	return r


func _should_mirror_icon(icon_key: String, rotation_steps: int) -> bool:
	if ICON_NO_MIRROR.has(icon_key):
		return false
	var normalized = wrapi(rotation_steps, 0, 4)
	# Requested mapping:
	# - arrow down-left / up-right => normal
	# - arrow down-right / up-left => mirrored
	return normalized == 0 or normalized == 2


func _get_back_icon(icon_key: String) -> Texture2D:
	var k := "back:" + icon_key
	if not _icon_cache.has(k):
		var path := str(ICON_BACK_PATHS.get(icon_key, ""))
		_icon_cache[k] = _load_texture(path) if path != "" and ResourceLoader.exists(path) else null
	return _icon_cache[k] as Texture2D


func _preload_icons() -> void:
	_icon_cache.clear()
	for key in ICON_PATHS.keys():
		_icon_cache[key] = _load_texture(str(ICON_PATHS[key]))


func _get_icon(icon_key: String) -> Texture2D:
	if _icon_cache.has(icon_key):
		return _icon_cache[icon_key] as Texture2D
	var path = str(ICON_PATHS.get(icon_key, ""))
	if path.is_empty():
		return null
	var tex = _load_texture(path)
	_icon_cache[icon_key] = tex
	return tex


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _icon_key_for_type(building_type: String) -> String:
	match building_type:
		"main_building":
			return "main_building"
		"tent_1":
			return "tent_1"
		"tent_2", "tent_3", "cabin_2", "cabin_3":
			return building_type
		"cabin", "cabin_1":
			return "cabin_1"
		"caravan_1", "caravan_2", "caravan_3", "bonfire", "sports_field", "lake_slide":
			return building_type
		"bench", "picnic_table", "flower_bed", "gnome", "flagpole", "playground", "ping_pong", "hammock", "corn_stand", "mega_gnome":
			return building_type
		"toilet_block":
			return "toilet_block"
		"shower_block":
			return "shower_block"
		"pub":
			return "pub"
		"pub_2":
			return "pub_2"
		"restaurant":
			return "restaurant"
		"staffroom":
			return "staffroom"
		"vecerka":
			return "vecerka_iso" if _get_icon("vecerka_iso") != null else "vecerka"
		"bowling":
			return "bowling"
		"sewer", "water_pump", "sewage_tank":
			return "sewer"
		"power_generator":
			return "power_generator"
		"lamp_post":
			return "lamp_iso" if _get_icon("lamp_iso") != null else "lamp_post"
		"path":
			return "path"
		_:
			return ""


func _is_path_at(coord: Vector2i) -> bool:
	var gm = _grid_model()
	if gm == null:
		return false
	var node = gm.occupants.get(coord, null)
	if node == null or not is_instance_valid(node):
		return false
	var root = _resolve_occupant_root(node)
	if root == null:
		return false
	if root.is_in_group("paths"):
		return true
	return str(root.get_meta("building_type", "")) == "path"


func _path_screen_step(offset: Vector2i, tile_w: float, tile_h: float) -> Vector2:
	var base = _grid_to_iso(Vector2i.ZERO, Vector2.ZERO, tile_w, tile_h)
	var shifted = _grid_to_iso(offset, Vector2.ZERO, tile_w, tile_h)
	return shifted - base


func _rotation_to_screen_dir(rotation_steps: int, tile_w: float, tile_h: float) -> Vector2:
	var world_offset = Vector2i(0, 1)
	match wrapi(rotation_steps, 0, 4):
		1:
			world_offset = Vector2i(1, 0)
		2:
			world_offset = Vector2i(0, -1)
		3:
			world_offset = Vector2i(-1, 0)
	var dir = _path_screen_step(world_offset, tile_w, tile_h)
	if dir.length_squared() < 0.001:
		return Vector2(0.0, 1.0)
	return dir.normalized()


func _is_valid_coord(coord: Vector2i) -> bool:
	return grid_manager != null and grid_manager.is_in_bounds(coord)


## Why a footprint cannot go here, in a word or two, for the ghost's tag.
func _blocked_reason(coord: Vector2i, footprint: Vector2i) -> String:
	for oy in range(footprint.y):
		for ox in range(footprint.x):
			var c := coord + Vector2i(ox, oy)
			if not _is_valid_coord(c):
				return "Off the site"
			var tile = grid_manager.get_tile(c)
			if tile == null:
				continue
			if tile.tile_type == grid_manager.TILE_LAKE:
				return "Water"
			if tile.tile_type == grid_manager.TILE_RESERVED and not tile.occupied:
				return "Entrance: keep clear"
			if tile.occupied and tile.occupant != null:
				var root = _resolve_occupant_root(tile.occupant)
				if root != null and root.is_in_group("trees"):
					return "Trees: bulldoze first"
				if root != null and root.is_in_group("corn"):
					return "Corn: bulldoze first"
				var t := str(root.get_meta("building_type", "")) if root != null else ""
				return "Taken: %s" % _nice_name(t) if t != "" else "Taken"
	return "Blocked"


func _nice_name(t: String) -> String:
	var names := {"path": "path", "main_building": "reception", "lamp_post": "lamp", "toilet_block": "toilets", "shower_block": "showers"}
	return str(names.get(t, t.replace("_", " ").trim_suffix(" 1").trim_suffix(" 2").trim_suffix(" 3")))


func _can_place(coord: Vector2i, footprint: Vector2i, _building_type: String) -> bool:
	if grid_manager == null:
		return false
	if not _is_valid_coord(coord):
		return false
	# A lamp may go on a path tile; it stands at the edge.
	if _building_type == "lamp_post" and _path_cell(coord) and not _path_has_lamp(coord):
		return true
	return grid_manager.can_place_footprint(coord, footprint)


func _has_money(building_type: String) -> bool:
	if building_type == "" or building_type == "demolish":
		return true
	var cost = _get_cost(building_type)
	if cost <= 0:
		return true
	var core = get_node_or_null("/root/CoreRoot")
	if core == null or not core.has_method("get_money"):
		return true
	return int(core.get_money()) >= cost


func _get_cost(building_type: String) -> int:
	var econ = _resolve_economy_manager()
	if econ != null and econ.has_method("get_cost"):
		return int(econ.get_cost(building_type))
	return 0


func _resolve_economy_manager() -> Node:
	if _economy_manager != null and is_instance_valid(_economy_manager):
		return _economy_manager
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	_economy_manager = tree.root.find_child("EconomyManager", true, false)
	return _economy_manager


func _get_footprint(building_type: String) -> Vector2i:
	if building_manager != null and building_manager.has_method("get_footprint_for_building"):
		return building_manager.get_footprint_for_building(building_type)
	var def = CoreRoot.registry.get_def(StringName(building_type)) if CoreRoot != null and CoreRoot.registry != null else null
	if def != null:
		return def.footprint
	return Vector2i.ONE


## Oblong footprints turn only half round (building_manager.gd turns them so too).
func _turns_round_only(building_type: String) -> bool:
	if not _supports_rotation(building_type):
		return false
	var fp := _get_footprint(building_type)
	return fp.x != fp.y


func _supports_rotation(building_type: String) -> bool:
	if building_type == "" or building_type == "path" or building_type == "demolish":
		return false
	return true


func _display_name(building_type: String) -> String:
	var econ = _resolve_economy_manager()
	if econ != null and econ.has_method("get_label"):
		# "Tent Lv1 (1x1)" -> "Tent Lv1": the footprint is the catalogue's business.
		var label := str(econ.get_label(building_type))
		var cut := label.find(" (")
		return label.substr(0, cut) if cut > 0 else label
	return building_type


func _reason_text(reason: String) -> String:
	match reason:
		"insufficient_funds":
			return "insufficient funds"
		"blocked_or_out_of_bounds", "placement_denied":
			return "blocked or out of bounds"
		"not_buildable":
			return "tool is not buildable"
		"only_one":
			return "the camp has one already"
		"area_too_large":
			return "area too large"
		"protected_structure":
			return "protected structures cannot be removed"
		"empty_selection":
			return "selection has no removable targets"
		"demolish_failed":
			return "nothing was removed"
		"authority_not_ready":
			return "authority not ready"
		"out_of_bounds":
			return "selection out of bounds"
		_:
			if reason.is_empty():
				return "request denied"
			return reason


## Push a status line to the builder window.
##
## Repeats are NOT suppressed. Retrying the same failing action is exactly when the
## player most needs confirmation that the click registered -- swallowing the second
## identical message made the UI look frozen.
func _emit_status(text: String, kind: int = STATUS_INFO) -> void:
	_last_status = text
	status_changed.emit(text, kind)


func _any_pending_interaction() -> bool:
	return _pending_build_wait or _pending_demolish_wait or _ghost_locked or _path_drag_active or _demolish_drag_active


func _on_mouse_exited() -> void:
	hover_coord = Vector2i(-1, -1)
	if _path_drag_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_path_drag()
	if _demolish_drag_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_demolish_drag()
	queue_redraw()


func _mouse_inside() -> bool:
	var local = get_local_mouse_position()
	return local.x >= 0.0 and local.y >= 0.0 and local.x <= size.x and local.y <= size.y


func _compute_iso_layout(grid_w: int, grid_h: int) -> Dictionary:
	var draw_dims = _display_grid_dimensions(grid_w, grid_h)
	var draw_w = max(1, draw_dims.x)
	var draw_h = max(1, draw_dims.y)
	var margin = clamp(min(size.x, size.y) * 0.018, 2.0, 16.0)
	var available_w = max(40.0, size.x - (margin * 2.0))
	var available_h = max(40.0, size.y - (margin * 2.0))

	var tile_w_by_width = (available_w * 2.0) / float(draw_w + draw_h)
	var tile_w_by_height = (available_h * 4.0) / float(draw_w + draw_h)
	var tile_w = max(7.0, min(tile_w_by_width, tile_w_by_height))
	tile_w = clamp(tile_w * _zoom_level, 6.0, 120.0)
	var tile_h = tile_w * 0.5

	var map_w = float(draw_w + draw_h) * tile_w * 0.5
	var map_h = float(draw_w + draw_h) * tile_h * 0.5
	var map_top_left = Vector2((size.x - map_w) * 0.5, (size.y - map_h) * 0.5)
	var origin0: Vector2 = map_top_left + Vector2(float(draw_h) * tile_w * 0.5, tile_h * 0.5)
	_pan_offset = _pan_on_map(_pan_offset, origin0, tile_w, tile_h, Vector2(draw_w, draw_h))
	var origin = origin0 + _pan_offset
	return {
		"tile_w": tile_w,
		"tile_h": tile_h,
		"origin": origin,
	}


func _clamp_pan_offset_for_current_map() -> void:
	if grid_manager == null:
		return
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	if grid_w <= 0 or grid_h <= 0:
		return
	_compute_iso_layout(grid_w, grid_h)


## The pan, kept so the middle of the view is always over the map (playtest 2026-10-17:
## "textures vanish when zooming in": zooming at the cursor near an edge used to slide the
## view off the diamond into an empty corner of its bounding box, all black). The middle of
## the view, in display cells, is held inside the grid; the map can still run off the
## sides of the view, but never out from under it.
func _pan_on_map(pan: Vector2, origin0: Vector2, tile_w: float, tile_h: float, dims: Vector2) -> Vector2:
	var mid := size * 0.5
	var d := mid - (origin0 + pan)
	var ua := d.x / (tile_w * 0.5)
	var vb := d.y / (tile_h * 0.5)
	var cell := Vector2((ua + vb) * 0.5 + 0.5, (vb - ua) * 0.5 + 0.5)
	var held := Vector2(clampf(cell.x, 0.0, dims.x), clampf(cell.y, 0.0, dims.y))
	if held.is_equal_approx(cell):
		return pan
	var at := Vector2((held.x - 0.5 - (held.y - 0.5)) * tile_w * 0.5, (held.x - 0.5 + held.y - 0.5) * tile_h * 0.5)
	return mid - origin0 - at


func _display_grid_dimensions(grid_w: int, grid_h: int) -> Vector2i:
	if wrapi(view_rot, 0, 4) % 2 == 1:
		return Vector2i(grid_h, grid_w)
	return Vector2i(grid_w, grid_h)


func _rotate_coord_for_display(coord: Vector2i) -> Vector2i:
	var rot = wrapi(view_rot, 0, 4)
	if rot == 0 or grid_manager == null:
		return coord
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	match rot:
		1:
			return Vector2i(coord.y, grid_w - 1 - coord.x)
		2:
			return Vector2i(grid_w - 1 - coord.x, grid_h - 1 - coord.y)
		3:
			return Vector2i(grid_h - 1 - coord.y, coord.x)
		_:
			return coord


func _grid_to_iso(coord: Vector2i, origin: Vector2, tile_w: float, tile_h: float) -> Vector2:
	var draw_coord = _rotate_coord_for_display(coord)
	return origin + Vector2((draw_coord.x - draw_coord.y) * tile_w * 0.5, (draw_coord.x + draw_coord.y) * tile_h * 0.5)


func _local_to_grid(local_pos: Vector2) -> Vector2i:
	if grid_manager == null:
		return Vector2i(-1, -1)
	if _in_3d():
		return map3d.cell_at(local_pos)
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	if grid_w <= 0 or grid_h <= 0:
		return Vector2i(-1, -1)
	var iso = _compute_iso_layout(grid_w, grid_h)
	var tile_w: float = iso.tile_w
	var tile_h: float = iso.tile_h
	var origin: Vector2 = iso.origin
	if tile_w <= 0.0 or tile_h <= 0.0:
		return Vector2i(-1, -1)

	# The inverse of _grid_to_iso: display cell from the point, then undo the rotation.
	var dlt := local_pos - origin
	var ua := dlt.x / (tile_w * 0.5)
	var vb := dlt.y / (tile_h * 0.5)
	var dcell := Vector2i(roundi((ua + vb) * 0.5), roundi((vb - ua) * 0.5))
	var coord := dcell
	match wrapi(view_rot, 0, 4):
		1:
			coord = Vector2i(grid_w - 1 - dcell.y, dcell.x)
		2:
			coord = Vector2i(grid_w - 1 - dcell.x, grid_h - 1 - dcell.y)
		3:
			coord = Vector2i(dcell.y, grid_h - 1 - dcell.x)
	if coord.x < 0 or coord.y < 0 or coord.x >= grid_w or coord.y >= grid_h:
		return Vector2i(-1, -1)
	return coord


func _footprint_center_iso(coord: Vector2i, footprint: Vector2i, origin: Vector2, tile_w: float, tile_h: float) -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	for oy in range(max(1, footprint.y)):
		for ox in range(max(1, footprint.x)):
			sum += _grid_to_iso(coord + Vector2i(ox, oy), origin, tile_w, tile_h)
			count += 1
	if count <= 0:
		return _grid_to_iso(coord, origin, tile_w, tile_h)
	return sum / float(count)


func _diamond_points(center: Vector2, tile_w: float, tile_h: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.push_back(center + Vector2(0.0, -tile_h * 0.5))
	points.push_back(center + Vector2(tile_w * 0.5, 0.0))
	points.push_back(center + Vector2(0.0, tile_h * 0.5))
	points.push_back(center + Vector2(-tile_w * 0.5, 0.0))
	return points


func _draw_diamond(center: Vector2, tile_w: float, tile_h: float, fill: Color, outline: Color, outline_width: float) -> void:
	var points = _diamond_points(center, tile_w, tile_h)
	_cv.draw_colored_polygon(points, fill)
	if outline.a > 0.0:
		for i in range(4):
			var a = points[i]
			var b = points[(i + 1) % 4]
			_cv.draw_line(a, b, outline, outline_width)


func _point_in_diamond(point: Vector2, center: Vector2, tile_w: float, tile_h: float) -> bool:
	var dx = abs(point.x - center.x) / max(tile_w * 0.5, 0.001)
	var dy = abs(point.y - center.y) / max(tile_h * 0.5, 0.001)
	return (dx + dy) <= 1.0


func _resolve_occupant_root(occupant: Variant) -> Node:
	if occupant == null:
		return null
	var node = occupant as Node
	if node == null:
		return null
	if node.has_meta("grid_origin"):
		return node
	var current = node.get_parent()
	while current != null:
		if current.has_meta("grid_origin"):
			return current
		current = current.get_parent()
	return node


func _rect_from_points(a: Vector2i, b: Vector2i) -> Rect2i:
	var min_x = mini(a.x, b.x)
	var min_y = mini(a.y, b.y)
	var max_x = maxi(a.x, b.x)
	var max_y = maxi(a.y, b.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


func _rect_contains_coord(rect: Rect2i, coord: Vector2i) -> bool:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return false
	return coord.x >= rect.position.x and coord.y >= rect.position.y and coord.x < rect.position.x + rect.size.x and coord.y < rect.position.y + rect.size.y


func _rect_equals(a: Rect2i, b: Rect2i) -> bool:
	return a.position == b.position and a.size == b.size



# ── feedback and life ────────────────────────────────────────────────────────

func _add_fx(kind: String, cell: Vector2, life: float, text := "", color := Color.WHITE) -> void:
	_fx.append({"kind": kind, "cell": cell, "t": 0.0, "life": life, "text": text, "color": color, "seed": randf()})


func _deny_fx(coord: Vector2i, text: String) -> void:
	if _is_valid_coord(coord):
		_add_fx("pop", Vector2(coord), 0.9, text, Color8(255, 90, 80))


func _draw_fx(origin: Vector2, tile_w: float, tile_h: float) -> void:
	for f in _fx:
		var k := float(f["t"]) / float(f["life"])
		var p := _cell_to_iso_f(f["cell"], origin, tile_w, tile_h)
		match str(f["kind"]):
			"dust":
				var sd := float(f["seed"])
				for i in 4:
					var a := sd * TAU + i * 1.7
					var r := tile_h * (0.15 + k * 0.55)
					var q := p + Vector2(cos(a) * r * 1.6, sin(a) * r * 0.7 - k * tile_h * 0.4)
					if _dust_tex != null:
						# Puffs that swell, drift up and thin out, each turned its own way.
						var ps := tile_h * (0.5 + k * 0.6)
						_cv.draw_set_transform(q, a + k * 0.8, Vector2.ONE)
						_cv.draw_texture_rect(_dust_tex, Rect2(Vector2(-ps, -ps * 0.8), Vector2(ps * 2.0, ps * 1.6)), false, Color(1, 1, 1, 0.85 * (1.0 - k)))
						_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					else:
						_cv.draw_circle(q, tile_h * (0.14 + k * 0.18), Color(0.62, 0.56, 0.46, 0.55 * (1.0 - k)))
			"pop":
				var txt := str(f["text"])
				var q := (p + Vector2(0, -tile_h * (1.2 + k * 1.6))).floor()
				var col: Color = f["color"]
				col.a = 1.0 - maxf(0.0, k - 0.6) / 0.4
				var w := T.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
				_cv.draw_string(T.FONT_BOLD, q + Vector2(-w * 0.5 + 1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color(0, 0, 0, col.a))
				_cv.draw_string(T.FONT_BOLD, q + Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)


## Grey puffs rising from a fire or a chimney, leaning with the wind (in a gale they
## go almost flat), in steps.
func _draw_smoke(center: Vector2, tile_h: float, strength: float, seed: int) -> void:
	var wind := float(_wx.get("wind", 0.15))
	var dir: Vector2 = _wx.get("dir", Vector2(0.94, 0.34))
	var lean := clampf(wind, 0.1, 1.4)
	var t := floorf(_time * 12.0) / 12.0
	for i in 4:
		var ph := fmod(t * 0.35 + float(i) * 0.25 + float(seed % 17) * 0.06, 1.0)
		var q := center + Vector2(sin(ph * 5.0 + seed) * tile_h * 0.2 + ph * tile_h * (0.4 + 2.2 * lean) * signf(dir.x + 0.001), -tile_h * (1.0 + ph * 2.4 / (1.0 + lean)))
		var r := tile_h * (0.12 + ph * 0.26)
		var col := Color(0.74, 0.74, 0.72, 0.5 * strength * (1.0 - ph))
		if _dust_tex != null:
			_cv.draw_texture_rect(_dust_tex, Rect2(q - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, col)
		else:
			_cv.draw_rect(Rect2(q - Vector2(r, r) * 0.5, Vector2(r, r)), col)


## KAREL: how the camp stood under the uncle, over the map a few seconds (from the
## world's seed, the same each time: tents in rows by the lake, two cabins, a fire).
func show_old_camp(seconds: float) -> void:
	_karel_until = _time + seconds


func show_buried(seconds: float) -> void:
	_mole_until = _time + seconds
	_emit_status("Something is buried here.")


func _draw_old_camp(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if grid_manager == null:
		return
	var rng := RandomNumberGenerator.new()
	var wg = get_tree().current_scene.get("world_generator") if get_tree().current_scene != null else null
	rng.seed = (int(wg.get("world_seed")) if wg != null else 0) * 13 + 5
	var gw := int(grid_manager.grid_width)
	var gh := int(grid_manager.grid_height)
	var a := clampf((_karel_until - _time) / 0.8, 0.0, 1.0) * 0.45
	var tint := Color(0.86, 0.80, 0.66, a)
	var rows := rng.randi_range(2, 3)
	var start := Vector2i(rng.randi_range(3, gw / 2), rng.randi_range(3, gh / 2))
	for r in rows:
		for i in 5:
			var c := start + Vector2i(i * 2, r * 2)
			if _is_valid_coord(c):
				_draw_building_icon(_footprint_center_iso(c, Vector2i.ONE, origin, tile_w, tile_h), Vector2i.ONE, "tent_1", 0, tint, tile_w, tile_h)
	for k in 2:
		var cc := start + Vector2i(11 + k * 3, 1)
		if _is_valid_coord(cc):
			_draw_building_icon(_footprint_center_iso(cc, Vector2i(2, 2), origin, tile_w, tile_h), Vector2i(2, 2), "cabin_1", 0, tint, tile_w, tile_h)
	var fc := start + Vector2i(4, rows * 2 + 1)
	if _is_valid_coord(fc):
		_draw_building_icon(_footprint_center_iso(fc, Vector2i.ONE, origin, tile_w, tile_h), Vector2i.ONE, "bonfire", 0, tint, tile_w, tile_h)


func _tick_lie() -> void:
	if _time < _lie_at:
		return
	_lie_at = _time + randf_range(1200.0, 2600.0)
	var h := float(_wx.get("hour", 12.0))
	if h < 15.0 or h > 20.0:
		return
	# Beside a tent that is there: on open ground next to it.
	var tents: Array = []
	for o in _known:
		if str(_known[o][0]).begins_with("tent"):
			tents.append(o)
	if tents.size() < 2:
		return
	var t: Vector2i = tents[randi() % tents.size()]
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c: Vector2i = t + d
		if _is_valid_coord(c) and structure_at(c).is_empty() and _can_place(c, Vector2i.ONE, "tent_1"):
			_lie = {"cell": c, "until": _time + 1.0 / 12.0}
			return


## The one tile of this camp that says something is buried there (from the world's seed:
## the same tile every time in the same camp; open forest floor, away from the middle).
func _buried_tile() -> Vector2i:
	if _buried.x == -2 and grid_manager != null:
		_buried = Vector2i(-1, -1)
		var wg = get_tree().current_scene.get("world_generator") if get_tree() != null and get_tree().current_scene != null else null
		var seed_v := int(wg.get("world_seed")) if wg != null and wg.get("world_seed") != null else 0
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v * 31 + 7
		var gw := int(grid_manager.grid_width)
		var gh := int(grid_manager.grid_height)
		for i in 60:
			var c := Vector2i(rng.randi_range(1, gw - 2), rng.randi_range(1, gh - 2))
			var tile = grid_manager.get_tile(c)
			if tile != null and tile.tile_type != grid_manager.TILE_LAKE and tile.tile_type != grid_manager.TILE_RESERVED and (Vector2(c) - Vector2(gw, gh) * 0.5).length() > float(mini(gw, gh)) * 0.3:
				_buried = c
				break
	return _buried


func _read_weather() -> void:
	var tree := get_tree()
	var main = tree.current_scene if tree != null else null
	if main == null:
		return
	var wx := {"state": 0, "snow": false, "wind": 0.15, "dir": Vector2(0.94, 0.34), "flash": 0.0, "hour": 12.0}
	if main.get("_weather_state") != null:
		wx["state"] = int(main.get("_weather_state"))
	var ws = main.get("weather_system")
	if ws != null and ws.has_method("is_snowing"):
		wx["snow"] = bool(ws.is_snowing())
	var wv = main.get("_weather_visuals")
	if wv != null:
		if wv.get("_wind_now") != null:
			wx["wind"] = float(wv.get("_wind_now"))
		if wv.get("wind_dir") != null:
			wx["dir"] = wv.get("wind_dir")
		if wv.get("_storm_flash_strength") != null:
			wx["flash"] = float(wv.get("_storm_flash_strength"))
	if main.get("_time_of_day_hours") != null:
		wx["hour"] = float(main.get("_time_of_day_hours"))
	_wx = wx


## The evening's light in palette steps before the night's own dark: gold toward five, red
## at a quarter past six, the blue hour after; a pink dawn. Four steps, never smooth.
func _draw_dusk() -> void:
	var h := float(_wx.get("hour", 12.0))
	var bands := [
		[5.4, 6.2, 7.2, Color(1.0, 0.62, 0.58), 0.12],
		[16.2, 17.2, 17.9, Color(1.0, 0.74, 0.34), 0.12],
		[17.7, 18.25, 18.9, Color(0.95, 0.36, 0.22), 0.18],
		[18.6, 19.3, 20.6, Color(0.24, 0.30, 0.66), 0.22],
	]
	for b in bands:
		if h <= float(b[0]) or h >= float(b[2]):
			continue
		var k := (h - float(b[0])) / (float(b[1]) - float(b[0])) if h < float(b[1]) else (float(b[2]) - h) / (float(b[2]) - float(b[1]))
		k = floorf(clampf(k, 0.0, 1.0) * 4.0) / 4.0
		if k <= 0.0:
			continue
		var c: Color = b[3]
		c.a = float(b[4]) * k
		_cv.draw_rect(Rect2(Vector2.ZERO, size), c)


## Rain in slanting streaks (the wind's slant), splashes on the ground, snow as flakes
## drifting down; fog in dithered bands; the storm's flash with the camp's.
func _draw_weather(origin: Vector2, tile_w: float, tile_h: float) -> void:
	var state := int(_wx.get("state", 0))
	var wind := float(_wx.get("wind", 0.15))
	var dir: Vector2 = _wx.get("dir", Vector2(0.94, 0.34))
	var t := floorf(_time * 12.0) / 12.0
	var w := size.x
	var h := size.y
	if _wx_drops.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 240:
			_wx_drops.append([rng.randf(), rng.randf(), rng.randf_range(0.8, 1.2)])
	var n := int(WX_RAIN_DROPS.get(state, 0))
	var snow := bool(_wx.get("snow", false))
	if n > 0:
		var slant := clampf(dir.x * wind * 0.7, -0.9, 0.9)
		if snow:
			for i in mini(int(n * 0.7), _wx_drops.size()):
				var d: Array = _wx_drops[i]
				var y := fmod(float(d[1]) * h + t * 24.0 * float(d[2]), h)
				var x := fposmod(float(d[0]) * w + sin(t * 1.3 + float(i)) * 5.0 + t * slant * 18.0, w)
				_cv.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(2, 2) if i % 3 == 0 else Vector2.ONE), Color(1, 1, 1, 0.85))
		else:
			var col := Color(0.70, 0.78, 0.92, 0.5)
			for i in mini(n, _wx_drops.size()):
				var d: Array = _wx_drops[i]
				var sp := 260.0 * float(d[2])
				var y := fmod(float(d[1]) * (h + 12.0) + t * sp, h + 12.0) - 12.0
				var x := fposmod(float(d[0]) * w + t * sp * slant, w)
				var l := 7.0 * float(d[2])
				_cv.draw_line(Vector2(x, y).floor(), (Vector2(x, y) + Vector2(slant * l, l)).floor(), col, 1.0)
			# Splashes: a few new ones each step, where the drops land.
			var step := int(t * 12.0)
			for k in n / 7:
				var hx := (k * 7919 + step * 104729) % 9973
				var hy := (k * 15485863 + step * 32452843) % 9967
				var p := Vector2(float(hx) / 9973.0 * w, float(hy) / 9967.0 * h).floor()
				_cv.draw_rect(Rect2(p, Vector2(3, 1)), Color(0.80, 0.86, 0.96, 0.55))
	# Under rain the map goes overcast (a flat shade, a step darker in a storm).
	if n > 0 and not snow:
		_cv.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.12, 0.18 if state == 5 else 0.10))
	# Fog: a thin dithered veil, and banks of it lying on the ground (on the map's own
	# tiles: they stay where they are when the map moves), drifting with the wind, each a
	# long low wisp of three puffs, thin enough to see the camp through.
	if state == 2:
		_ensure_dither()
		var fc := Color(0.80, 0.82, 0.84)
		_cv.draw_texture_rect(_dither[0], Rect2(Vector2.ZERO, size), true, Color(fc, 0.16))
		if _fog_tex != null and grid_manager != null:
			var gw := float(grid_manager.grid_width)
			var gh := float(grid_manager.grid_height)
			var tb := floorf(_time * 4.0) / 4.0
			var drift := Vector2(dir.x, dir.y) * tb * 0.04
			for b in 12:
				var d: Array = _wx_drops[(b * 17) % _wx_drops.size()]
				var cell := Vector2(fposmod(float(d[0]) * gw + drift.x, gw), fposmod(float(d[1]) * gh + drift.y, gh))
				var c := _cell_to_iso_f(cell, origin, tile_w, tile_h)
				var bw := tile_w * (3.0 + 3.0 * float(d[2]))
				for k in 3:
					var off := Vector2((float(k) - 1.0) * bw * 0.32, (float(k % 2) - 0.5) * tile_h * 0.4)
					var pw := bw * (0.55 if k != 1 else 0.7)
					_cv.draw_texture_rect(_fog_tex, Rect2((c + off - Vector2(pw * 0.5, pw * 0.12)).floor(), Vector2(pw, pw * 0.24).floor()), false, Color(fc, 0.2))
	# Leaves on the wind (the autumn's, before the snow).
	if wind > 0.6 and not snow:
		var lc := [Color8(150, 74, 30), Color8(186, 130, 44), Color8(120, 70, 36)]
		for i in int(wind * 18.0):
			var d: Array = _wx_drops[(i * 13) % _wx_drops.size()]
			var x := fposmod(float(d[0]) * w + t * 90.0 * float(d[2]) * signf(dir.x + 0.001), w)
			var y := fposmod(float(d[1]) * h + sin(t * 3.0 + float(i)) * 8.0 + t * 12.0, h)
			_cv.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(2, 1)), lc[i % 3])
	var flash := float(_wx.get("flash", 0.0))
	if flash > 0.05:
		_cv.draw_rect(Rect2(Vector2.ZERO, size), Color(0.86, 0.90, 1.0, floorf(flash * 3.0) / 3.0 * 0.45))


## Ordered-dither ink (4x4 Bayer): 25 % and 50 % of the pixels, tiled over the map.
func _ensure_dither() -> void:
	if not _dither.is_empty():
		return
	if _dust_tex != null:
		var img := _dust_tex.get_image().duplicate() as Image
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(1, 1, 1, c.a))
		_fog_tex = ImageTexture.create_from_image(img)
	var bayer := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
	for level in [4, 8]:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			for x in 4:
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if int(bayer[y][x]) < level else 0.0))
		_dither.append(ImageTexture.create_from_image(img))


## The lodgings lived in after dark, as the camp has them (scripts/ambient/window_lights.gd):
## a cabin's or a caravan's windows lit (their picture from the model's own windows), the
## telly's blue in steps, a candle when the power is off; a tent glowing through its cloth.
func _draw_lit_windows(tile_w: float) -> void:
	if _night <= 0.02 and float(_wx.get("hour", 12.0)) < 17.0:
		return
	if _window_lights == null or not is_instance_valid(_window_lights):
		_window_lights = get_tree().root.find_child("WindowLights", true, false) if get_tree() != null else null
		if _window_lights == null:
			return
	var step := int(_time * 12.0)
	for s in _lit_spots:
		var o: Vector2i = s[2]
		var lit: Dictionary = _window_lights.lit_state("%d:%d" % [o.x, o.y])
		if lit.is_empty():
			continue
		var view: Array = s[1]
		var col := Color(1.0, 0.82, 0.46)
		if bool(lit.get("candle", false)):
			col = Color(1.0, 0.62, 0.3) * (0.8 + 0.2 * float((step + o.x) % 3) / 2.0)
		elif bool(lit.get("tv", false)):
			col = Color(0.55, 0.7, 1.0).lerp(Color(0.92, 0.94, 1.0), float((step / 3 + o.y) % 4) / 3.0)
		var a := clampf(0.35 + _night, 0.0, 1.0)
		if str(s[3]).begins_with("tent") or view.size() < 3 or view[2] == null:
			# The cloth lit from inside: the tent's own picture in the lantern's colour.
			_draw_view(view, _s2d(s[0]), Color(col.r, col.g * 0.9, col.b * 0.6, 0.4 * a), tile_w)
		else:
			_draw_view([view[2], view[1]], _s2d(s[0]), Color(col.r, col.g, col.b, a), tile_w)


## Dusk and night: the map darkens, lamps and fires make pools of light.
func _draw_night(lights: Array, tile_w: float, tile_h: float) -> void:
	if _night <= 0.01:
		return
	_cv.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.10, 0.55 * _night))
	for l in lights:
		var c: Vector2 = l[0]
		var fire: bool = l[1] == "bonfire"
		var col := Color(1.0, 0.55, 0.15) if fire else Color(1.0, 0.86, 0.45)
		var flick := 1.0 + (0.12 * sin(_time * 11.0 + c.x) if fire else 0.0)
		for r in 3:
			var rr := tile_w * (0.9 - r * 0.25) * flick
			col.a = (0.10 + r * 0.07) * _night
			_cv.draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
			_cv.draw_circle(Vector2.ZERO, rr, col)
			_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not fire:
			_cv.draw_circle(c + Vector2(-tile_h * 0.15, -tile_h * 0.65), maxf(1.5, tile_h * 0.12), Color(1.0, 0.95, 0.7, _night))


func _night_amount() -> float:
	var tree := get_tree()
	var main = tree.current_scene if tree != null else null
	if main == null or main.get("_time_of_day_hours") == null:
		return 0.0
	var h := float(main.get("_time_of_day_hours"))
	if h >= 7.0 and h <= 18.5:
		return 0.0
	if h > 18.5 and h < 21.0:
		return (h - 18.5) / 2.0 if h < 20.5 else 1.0
	if h > 5.0 and h < 7.0:
		return (7.0 - h) / 2.0
	return 1.0


func _play(name: String, db := 0.0) -> void:
	var path := SFX_DIR + name + ".mp3"
	if not ResourceLoader.exists(path):
		return
	# From the PC's speaker: quieter away from it, never in the menu (it was heard all
	# over the camp, and in the main menu, at full volume).
	var shell: Node = self
	while shell != null and not shell.has_method("sound_db"):
		shell = shell.get_parent()
	if shell != null:
		db += float(shell.call("sound_db"))
	if db <= -60.0:
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = randf_range(0.94, 1.06)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## What the map sounds like under the pointer (builder_module's loops): what is most of
## the ground round it, "" off the map.
func sound_under_pointer() -> String:
	if grid_manager == null or not _is_valid_coord(hover_coord):
		return ""
	var count := {"lake": 0, "forest": 0, "play": 0, "pub": 0, "camp": 0}
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := hover_coord + Vector2i(dx, dy)
			if not _is_valid_coord(c):
				continue
			var tile = grid_manager.get_tile(c)
			if tile == null:
				continue
			var k := "camp"
			if tile.tile_type == grid_manager.TILE_LAKE:
				k = "lake"
			elif tile.occupied and tile.occupant != null:
				var root = _resolve_occupant_root(tile.occupant)
				if root != null and (root.is_in_group("trees") or root.is_in_group("corn")):
					k = "forest"
				elif root != null:
					var t := str(root.get_meta("building_type", ""))
					if t in ["playground", "sports_field", "lake_slide", "ping_pong", "bonfire"]:
						k = "play"
					elif t in ["pub", "restaurant", "vecerka", "corn_stand", "bowling"]:
						k = "pub"
			count[k] = int(count[k]) + (2 if dx == 0 and dy == 0 else 1)
	var best := "camp"
	for k in count:
		if int(count[k]) > int(count[best]):
			best = k
	return best


## "12:7  Tent", "4:3  Forest", "20:1  Lake", for the status bar.
func _describe(coord: Vector2i) -> String:
	if not _is_valid_coord(coord):
		return ""
	var tile = grid_manager.get_tile(coord)
	var what := "Forest floor"
	if tile != null:
		if tile.tile_type == grid_manager.TILE_LAKE:
			what = "Lake"
		elif tile.tile_type == grid_manager.TILE_RESERVED:
			what = "Camp entrance"
		if tile.occupied and tile.occupant != null:
			var root = _resolve_occupant_root(tile.occupant)
			if root != null and root.is_in_group("trees"):
				what = "Pine tree"
			elif root != null:
				what = _display_name(str(root.get_meta("building_type", "")))
				var o = root.get_meta("grid_origin", null)
				if o is Vector2i and GuestManager != null and GuestManager.room_number("%d:%d" % [o.x, o.y]) > 0:
					# The room and how it stands: ready, dirty, taken.
					var key := "%d:%d" % [o.x, o.y]
					var rs: Dictionary = GuestManager.get_room_state(key)
					var st := "guests" if bool(rs.get("occupied", false)) else ({"ready": "ready", "dirty": "dirty", "unprepared": "not made up"}.get(str(rs.get("status", "")), "") as String)
					return GuestManager.room_label(key) + (("  -  " + st) if st != "" else "")
	if coord == _buried_tile() and (what == "Forest floor" or what == "Pine tree"):
		return "%d:%d  %s  -  Something is buried here" % [coord.x, coord.y, what]
	return "%d:%d  %s" % [coord.x, coord.y, what]



func _path_cell(coord: Vector2i) -> bool:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	return state != null and str((state.grid.cells.get(coord, {}) as Dictionary).get("type", "")) == "path"


## Where a path's lamp stands on the map: the camp's own spot for it (LampSpot), turned
## with the map.
func _path_lamp_point(coord: Vector2i, center: Vector2, tile_w: float, tile_h: float) -> Vector2:
	var off: Vector2 = LampSpot.offset(coord, Callable(self, "_path_cell"))
	var a := _cell_to_iso_f(Vector2(coord), Vector2.ZERO, tile_w, tile_h)
	var b := _cell_to_iso_f(Vector2(coord) + off, Vector2.ZERO, tile_w, tile_h)
	return center + (b - a)


func _path_has_lamp(coord: Vector2i) -> bool:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	return state != null and bool((state.grid.cells.get(coord, {}) as Dictionary).get("lamp", false))
