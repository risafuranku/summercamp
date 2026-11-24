# The camp world, the land and the villages

Guests, weather, trees, the map, Lesna and Liblice, the lake.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **Sky/weather profiles derive from a fresh time baseline** each frame; weather changes
  crossfade over 40 s (`weather_visuals`), don't snap the environment directly.

- **Guests asleep are `sleep`, not `active`**: anything that asks "who is in the camp" at
  night must take both (the director saw an empty camp every night because of it).

- **Machinery moves in steps, twelve a second; rooms move smoothly** (playtest 18. 10.:
  the stepped room cameras were "choppy"). The fire, the torch hand, the gate go through
  `Step12` (the step bob is smooth since 21. 10.: the camera never steps) (scripts/ui/step12.gd); camera moves in rooms, the door
  transition, the A/D push and the walk through a doorway run at the full frame rate.
  Anything that starts in the frame a room is built (or a still is read back from the
  GPU) must wait for a steady frame (`CAM_MOVE.hold`), or its first part goes in one
  jump. A new kind of room must call `interior_manager._door_transition(true)` before it
 opens and, when it has closed, `_step_out_of(its structure)` (no dissolve on the way
 out, playtest 18. 10.); a close that goes straight on into something else (the repair
 under a service room) sets `_no_step_out` around it. Since 4. 11. a room you walk into
 gives door_through its `door_spec` (scripts/ui/door_through.gd) and walks out through
 `interior_manager.leave_on_foot(self, structure, close)`; `_step_out_of(was, _through_eye())`.

- **Seated guest sprites** (`*_sit`, `*_drink`, `*_eat`): the node goes on the floor just in
  front of the seat, the seat line is 0.45 m up the sprite; for a bar stool put the node at
  stool top - 0.45, in front of the stool, or its seat cuts the legs.

- **The warden in an attraction** (`scripts/attractions/warden_play.gd`): the attraction
  places a stand-in through its own `pose_member(0, key, ...)` with a warden key (-11 the
  host's warden, -12 the other's: keys below 0 are never guests, nor counted in
  `guests_here`); each attraction answers `warden_offer/join/leave/slot/force/focus/press`
  (+ `warden_pose/hint/exit/done/hold/extra` where it has them). The other machine's
  warden is put in with `warden_force` (their place there) and drawn from
  `mate_place()` (remote_player.gd, state "att"). The ball games are the host's in
  co-op: `_launch` sends each flight (`Coop.send_play` "shot"), the other machine only
  follows (`coop_take_shot`) and sends its swings ("press").

- **Things outside the camp are clicked through InteriorManager**: give the body a
  `building_type` starting `trip_` or `town_` and `town_trip.gd` answers `hint_for` and
  `interact` (the hint can depend on the thing's state: `get_hint_for_structure`). Things
  you click but walk through go on collision layer 12 only (`1 << 11`, mask 0): the
  interaction ray hits every layer, the player's body only layer 1.

- **The villages are in the same world, at their real places** (`scripts/geo/`, built on
  the first trip or when you walk out; Liblice's stop 2.9 km north-east by road, Pristoupim
  2 km east): the sun, sky, fog and weather are the camp's. `town_trip.away()` (more than
  420 m from the camp) makes main keep the night off (`_away_in_town`: no enemy actions,
  director place "away"). The bus ride is in that world too: the ride's SubViewport shares
  the main World3D (`own_world_3d = false`) and the main viewport is set to
  `UPDATE_DISABLED` while it is open; its cabin is on render layer 2 with its own fill
  light; the sun lights only layer 1.

- **Trees on the map**: spruce, birch and linden (`world_generator._tree_mesh`: `linden_trunk`, `linden_crown`, `linden_cards`, `LINDEN_BLOBS`); the broadleaves, alleys, single trees and fruit trees are lindens at their scales (`geo_world._trees`); birch and linden get leaf cards round their lumps within 420 m (`_multimesh`), or they read as balls.

- **Rebuilding the map data**: `python -I tools/geo/design_world.py` (no map data, the
  user's points only). Check `route_len` and the stops' `s` it prints after a change, and
  the times in `bus_timetable.gd` (7 minutes camp to Liblice, four runs a day; the clock
  slows during the ride to fit, the bus's speeds are `town_trip.RIDE_SPEED`). A wood or an
  orchard must stay off the roads (its trees are not kept off them in the game): the script
  says which one is too near.

- **Trees are cone or blob plus cards**: `world_generator._tree_mesh` `spruce_cards`, `birch_cards`, `linden_cards` go with their crowns everywhere a tree is drawn (the crowns are only a dark core now: a crown without its cards is a dark lump). A new planting takes all three parts. Cards carry their own normals (out from the crown; `own_normal` in `tree_wind.gdshader`, the engine turns a back face's round) and their pictures have mipmaps (`filter_nearest_mipmap`: nearest, from a smaller picture far off, no glitter; only pictures imported with mipmaps change, set it in the `.import`).

- **A chunk of the land has 4 ms**: nothing per tree in GDScript as it is made. `ambient/far_trees.gd` keeps the lists as they came and picks out what is round the player as they walk (per tree, tens of ms a chunk took the game to 9 fps).

- **The village is made as the game opens**, a share of each frame (`town_lesna.begin`, `await breath()` between pieces, `town_trip._tick_town`; `RetroMaterials.patient`: its nodes 40 a frame). `_town` is set only when it is whole; what must have it now calls `_ensure_town()`. Past 1.3 km it is hidden and its process off (`set_near`): what it does per frame stops with that, and a teleport into it goes through `_ensure_town()`. Anything added to its build that takes over 10 ms wants a `breath()`.

- **A shop's room behind the glass exists twice** (`town_lesna._shell`, open and shut): the hour only shows the other, named as the view looks for it (`SalesRoom`, `Taproom`, `Shop`). What lives in one of them is made once: reset it when it comes back (`pub_street.set_hour`).

- **A building's footprint turns with it** (playtest 25. 10.: "the caravan turns only 180
  degrees"): an oblong one (2x1, 3x5) stands across on an odd quarter turn. The tiles it
  takes, its middle and its `grid_footprint` meta are `GridModel.turned(def.footprint, rot)`;
  its model is built along its own footprint and the structure turned. A placed one's
  footprint is the cell's `fp` (`grid.footprint_of(origin, def.footprint)`) or the meta,
  never `def.footprint` alone; `building_manager.place_building_at(origin, type, rot)`.

- **A jump of the clock skips the hours' mail**: `EmailManager._on_time_tick` rolls each hour
  it saw and catches up three at most; `debug_jump_to` and `set_time_hours` skip the rest (no
  bookings, no spam in those hours). The debug menu's T and N (`scripts/ui/debug_menu.gd`)
  step the clock an hour at a time, so a day passed that way books like a day played
  (playtest 14. 11.: N from day 5 to day 9 brought no booking and read as broken co-op).

- **`building_manager._apply_corrosion_recursive` writes `albedo_color` on every StandardMaterial3D under a building.** A material with no meta `base_albedo_color` now notes its own first; before it went solid white, alpha and all: the reception's clear glass was a white pane from the first wear on.

- **The stove's orange in the office stays orange** (the user 7. 11.: "I liked it"; it was the sun's sprite he meant). **An eye in a room sees 600 m, the camp's 1000:** the sun and the moon hang 0.8 of the far plane off the eye; with the camp's view off (`one_world_room.camp_view`) they hang `ROOM_SKY_DISTANCE` off, else the disc went out as you looked at it and came back cut at the edge of the picture. A new camera that sees the sky needs its far past them.

- **`camp_lake.in_water` is false on a jetty:** `body_world._on_foot` splashes and plays an oar's stroke on whatever it calls water.

- **The dawn and the dusk light follow the sky** (24. 11., the environment pass, `tools/env_shots.tscn`,
  `--part=twilight`): the sky's dawn texture comes in from 5:15 (`DAWN_SKY_START_HOUR`), the
  ground's light only from 6:15, so at 6:15 a pink sky stood over a black camp. Since then the
  night's profile eases toward the dawn's from 5:15 (`weather_visuals.PRE_DAWN` of the way by
  6:15, the night overlay with it), and the evening's and the blue hour's ambient are higher
  (0.86, 0.52): the meadow under the red sky after sunset is dim, not black. The full night from
  ~20:30 is as it was.
