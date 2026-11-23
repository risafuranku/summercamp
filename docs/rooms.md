# Rooms, doors and windows (one world)

Interiors, the one-world rooms, doorways and windows.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **Interiors live under InteriorManager (the full-res root view), not in World3D**: the
  world is drawn small and scaled up by the render style, and 2D inside it scaled with it
  (huge prompts). Rooms have their own 3D viewports; the office window portal gets the
  camp's world by hand (`_bind_window_world`).

- **Main resets the active camera every frame** (`_sync_active_camera`) unless an interior
  or the lake trip is active: a mode with its own camera must be added to that check.

- **What a camp view hides, nothing may give back**: window_shared_view hides a building
 from its camera by setting its meshes' `layers` to HIDE_LAYER and restoring them after; a
 script that ORs a layer into a building's meshes every second (business/room_lights.gd did
 for the crew) must skip the hidden ones, or the pub's own room stood in its doorway seen
 from inside (4. 11.).

- **A panel over a room must mute the room**: rooms read clicks and their way out (S, the
 bottom band, a right click) in `_input`, which runs before any Button. The upgrade offer
 (`building_upgrade_menu.gd`) turns off the asking room's `set_process_input` while it is
 up and closes itself when that room is gone; before that its Close never got the click
 and S left the room with the panel still on screen and the mouse captured.

- **One world (W26, 5. 11.)**: the reception and the cabins are built in the camp's own
 World3D (their SubViewport has `own_world_3d = false` and meta `retro_room`), the room
 standing in its building every frame (`building_interior._bind_one_world`,
 `cabin_interior._bind_one_world`: the cabin you are in, or out in the camp the one you
 look in at; farther cabins keep their `room_cube`). What they share is
 `scripts/one_world_room.gd`: the room's eye culls the building's own glass, frames and door
 leaf (`GLASS_LAYER`, bit 19) and has its own exposure; an interior ReflectionProbe gives the
 ambient (the room's `Environment` only holds the numbers); a `GPUParticlesCollisionBox3D`
 keeps the rain out (the rain hides on contact); by day, while the sun shines in
 (`sun_shining`), the room's own fill and lamps go down and the eye opens; heard from the
 camp the room's 3D sounds go through `WORLD_SOUNDS.wall_bus`; while you are in a room the
 camp's own viewport is not drawn nor heard from (`camp_view`). The building and the room
 must be one plan (`reception_layout`, `cabin_layout`): the model's walls have the room's
 openings (the cabin's a 4 cm skin, the room's walls 3 cm short of its outer face, so no two
 faces meet), its window frames are rings, its panes glass while the room is in it. The
 reception's doorway is a real opening; walking out still sets `walked_out` and puts the
 player where the room's eye was (`walk_out_handoff`). Also in one world: the bowling hall
 (its floor on the model's; the cellar far over the hall, shown only while you are in it),
 the tents (every tent at least its room, `building_manager.TENT_SIZE`; the canvas's front a
 real doorway the size of the room's front gable, `building_models.TENT_DOORWAY`) and the
 caravans (the room is the van's body by plan; the van it stands in has its shell, marked
 `van_shell`, left out of the room's eye and its shadow off while it does). One room
 serves every cabin, tent and van: it stands in the one you are in or look in at
 (`_host_panes`, `_host_way`, `_host_shell_of`); the others keep their cubes and darks.
 **Doors in one world** (the user 5. 11.: "a broken portal into the endless" inside the
 cabin's door, a tent crawled into from across the camp): every room stands in its building,
 so `door_through` has no panes and no portal at all (11. 11.: the last rooms of their own,
 the toilets, showers, generator shed and sewer, came into the one world and the portal code
 went): the eye goes on where it is, the doorway's dark (`<leaf>Way`) and the room's own shut
 leaf are hidden while you come through, and `door_ready` binds the room into that building
 at once. The room hides its host's darks while it stands there (`one_world_room.doorways` /
 `hide_ways`, given back when it leaves). Every model's doorway must be a real hole: no
 board behind the leaf (the cabin's `DoorFrame` is a ring, `_frame`), a painted front has its
 door cut out (`_door_cut_face`), a solid box is a shell with the doorway through it
 (`_hall_shell`: the bowling hall, the van's body), a picture skin in pieces round it
 (`_skin_round`), and the room's own wall has the opening too (`bowling_layout._door_hole`).
 The van is built round its room (`caravan_layout.gd`, one plan for both, as `cabin_layout`):
 its walls stood inside the room's, the wallpaper seen from the camp. The reception is walked
 into for real (the leaf opens, the camp's walk goes on into the doorway, no frozen frame).
 A walk held a frame or two while a room is built (`CAM_MOVE.hold`) is still a walk: test
 `_walk.is_valid()`, not `is_running()` (the look turned the eye out of the door for a frame).
 Floors: the plinths are rings (`_plinth_ring`, top 0.13) and a tent's room is lifted
 `TENT_LIFT` off the ground. Rain: a drop is born unseen for 75 ms and its streak is never
 drawn inside a room (`materials/rain_streak.gdshader` cuts it by the rooms' dry boxes, group
 `dry_box`, `weather_visuals._update_dry_boxes`): a dry box hides a drop only a step after it
 went in, and a streak hangs half its length round its drop (the cabin's single drip from
 the ceiling in heavy rain is its roof leak, room_weather). Check a converted room with
 `tools/onesun_check.gd --part=walks` (in and out by every door, frame by frame).
 **Under the land nothing is drawn** (a room put below y 0 rendered as sky): bake a room's
 cubes far over the camp (`one_world_room.BAKE_UP`). Lamps without shadows in a room built in
 the camp light the grass outside its walls: `one_world_room.own_lights` (the room's own
 layer, 13). **The businesses too** (5. 11.: the pub, the bistro, the Jednota, the
 staffroom): `service_interior` switches its viewport to the camp's world for them
 (`world_3d` null = the root's world; `_room_env` only holds the room's light numbers for
 its probe) and binds the room where it stands (`_bind_one_world`, `_one_seat`): a business's
 where its building's own copy stands (`ONE_WORLD_COPY`: PubRoom, BistroRoom, JednotaRoom, the
 staffroom's `Inside`), the copy hidden while it does; the front room's walls are opened at
 its windows and its door (`K.open_windows`), the windows glass; a room behind the front one
 (the cellar, the kitchen, the storeroom) stands 60 m over the building (`BACK_ROOM_UP`, a
 dark box round it); put away 2000 m up when shut. The fronts' painted doors are cut out
 (`_glass_door_face`), the plinths are rings, the staffroom's under its walls only (its
 block under the floors fought them). By day, as the sun comes in, the front room's fill and
 lamps go down and its eye opens (`service_interior.DAY_*`, less than a lodging's: the
 stations want seeing; a room with no windows keeps its lamps). **The toilet block, the shower
 house and the generator shed too** (11. 11.): one plan with their buildings,
 `scripts/service_plan.gd` (the room's inside size, its doors in the front; the building's
 skin `SKIN` outside the room's walls, the floor `FLOOR` over the ground): the models are
 skins round their rooms with a doorway and a sill behind each leaf (`building_models
 ._service_skin`, `_skin_walls`: one mesh, the boards' triplanar runs on; the doorways open to
 the ground, the sill fills under the leaf; the shower house's darker base band is the walls'
 foot, `base`, the walls standing on it, never laid over them), the leaves are the
 building's own (seen from inside, swung on the way out), the room stands on the building's
 floor (`_one_seat`); the generator's switch room is its room behind (over the building in
 the dark, where the set room is, the hidden one's click boxes off: `generator_shed.set_room`)
 and so is the sewer's chamber down the hatch (`SEWER_ROOM`). Walking up to a business's door brings up its people, stations and marks
 already (`door_ready` calls `set_upkeep_target`, `_started_for` stops the second call): the
 open door shows the room as it is. A shot of a station or a room turned the wrong way in a
 run is the real mouse: the look follows the PC's cursor; run it again before looking for a
 bug. **Stock on a quad:** a quad is pulled toward the eye (`retro_materials._pull_of`), from
 metres off it comes out in front of sprites standing on it: `retro_no_pull` on the picture
 behind them (the Jednota's `RackFront`: its goods were seen only at the station). **A record
 made before the books:** a room in the camp can ask for a business's record the frame the
 building is put up, the books come within the second (`Jednota.site`: `no_books`, the rack
 filled once they are there, or a new shop stayed empty for good). **A room's probe is for its own things only**
 (`reflection_mask` = `ROOM_LAYER`, the room's meshes marked by `one_world_room.own_layer`
 now and then): its box takes in what stands outside the walls, and the room's dim ambient
 darkened the reception's back wall and the lean-to's roof from outside. To see a room's
 traces from outside: `onesun_check --part=recdiff` shoots the building with and without the
 room from 96 places, `tools/room_diff.py` compares them: only its windows may differ.
 **That is not enough: look along the walls** (`--part=recgraze`, the user's "the back room's
 textures seen from outside" came back twice after recdiff found nothing). Straight on a wall
 hides what a slant shows: **a building a room stands in does not snap**
 (`retro_materials.HOLDS_ROOM`, a new kind of building with a room goes on that list): its
 wall's corners moved on the screen and the room's did not, and at 15 degrees a whole
 triangle of the wall fell behind the wallpaper (over 160 views along the walls 40 000 px of
 the room on them before, after it what moves by itself: birds, a leaf, the porch bulb, the
 day's title). A room's own quads and boards are not pulled for the camp's eye
 (`room_thing`; the camp's eye is the one camera with bit 19 and without bit 17). **Two walls
 or two faces meet at a corner**: a slit of a few centimetres between them and the corner
 post showed a line of wallpaper down the corner (the reception's walls run to the corners'
 outer faces; the pub's, bistro's and Jednota's faces end at the room's corners, 1 cm off it:
 `_corner_beads`). **A wedge faces out** (`_prism` was inside out: you saw its far face, in
 one plane with the store's ceiling), **its faces flat** (`set_smooth_group(-1)`: a triplanar
 material goes by the normal, smoothed corners took the picture from different sides and
 the boards came out as grain; look at a turned mesh up close, `--part=wedges`). **A room's ceiling ends under the model's top** (the
 cabins' bathroom: its edge stood out under the annex's roof, `annex_box`). **A mesh on no layer at
 all** (`layers = 0`) shown while lamps are in reach pairs with them and never lets go: the
 engine's "BUG, indexing did not unpair geometries from light" when the game is shut, and
 a crash after it (the doorway's dark behind a cabin's door). Hide on `one_world_room.NO_EYE`
 (bit 20, no camera has it); a hole casts no shadow, it would still stand in the sun's way.
 **A room nobody is in is not drawn**: `render_target_update_mode` ALWAYS in its open,
 DISABLED in its close (door_through opens it as you walk up), and interior_manager's
 `_tick_eyes` shuts them all 5 s in, once what they show is compiled. The cabin, the tent, the
 van and the service room were left on: 3000 draws and a quarter of every frame for pictures
 nobody saw, in the camp and at the PC alike (33-37 fps, 50 without them and the next
 line). A new room does the same. **Nothing makes text per node per frame**: retro_materials'
 rolling check wrote eight values of each material out as a string to compare them, 400
 nodes a frame, 7 ms. **The first step into a business**: its stations' scripts compile in
 LandWarmup's threads while the boot is up (the restaurant froze for 1.3 s, 190 ms now);
 a business in a new folder goes on `land_warmup.ROOTS`. **Headless nothing is drawn**, so a
 room's cubes never finish and the rooms stay up at `BAKE_UP` on top of each other: a ray from
 one finds another's curtains (`--part=hover` clears `_cube_baking`).
 **A room's lit side is its inside**: the camp's eye sees a curtain's back, unlit, a lit
 window was the darkest thing on the wall. For the eye out in the dark a lit room has more
 fill and a lamp more (`one_world_room.camp_lamp`, `glow_step`, `glow_fill`, gone as you
 come in at the door) and the lamp's colour in the glass, more of it from further off
 (`pane_figure`'s `glow`, from window_lights). **Main calls `set_grid_power_available` every
 tick of the clock**: a room that lights itself afresh on it, from its base, pulsed all
 night: only on a change. **Everything over a pulled skin is pulled** (a van's panes had no
 `depth_pull`: from a few metres the skin stood in front of every window). **A pane's quad
 under a hidden view**: what hangs under it (`RainOnGlass`, `LightningIn`) goes with it; hide
 the material, not the node (the reception's, `_hide_painted_views`: clear glass on
 `INVIEW_HIDE_LAYER`). **A freed object
 equals null**: `if v != null and not is_instance_valid(v)` lets it through, test
 `is_instance_valid` alone (a van upgraded under the room). **A room looks right from the camp before it is ever
 opened**: a camp loaded with you outside never opens the reception, and its painted panes,
 hidden only on the way in, stood pale over all three windows (`_hide_painted_views` is in
 the build now). A new camp starts at the PC and never shows this: test a load too. **The
 user's own state is on this machine**: `%APPDATA%/Godot/app_userdata/icloud ccs2`:
 `settings.cfg` (the look: `retro_preset` crisp, 360 lines, not the default a fresh APPDATA
 gets), `logs/` (what his last run printed), `profiles/last.json` and
 `profiles/<p>/camps/<c>/` (`thumb.png` is what he last saw, `saves/`). Copy those into a
 run's own APPDATA (`window_mode` windowed, never over his screen) and `--part=rechis` is his
 camp as he left it: the windows were found this way in one run.

- **A room's windows share ONE view of the camp** (`scripts/ui/window_shared_view.gd`, the
  user 25. 10.: "shared like this in all interiors, and in every future one"): one camera
  at the room's eye mapped into the camp, the room camera's lens, the room's pixel size;
  every pane, doorway and window reads it at SCREEN_UV (`window_into.gdshader`). Never give
  a window a camera of its own: make windows with `window_portal.make` (shared by default;
  pass the building to `update` so it is hidden from the view while you are inside) or
  call `WINDOW_SHARED_VIEW.for_host(room).offer(eye, room, room_to_world, world, building)`
  each frame a window is in sight. The caravan went from 23-28 to 44-51 FPS. The reception
  (its building over the room exactly: not hidden) and the cabins do the same; the room's
  fake Outdoor* boxes stay hidden.

- **A room's mess must go when its prep goes**: `INTERIOR_PREP.dispose()` takes the mess
  and its click bodies out of the tree at once. Freeing only the task overlay left the
  last visit's bodies under the new ones, and the cursor ray hit those ("I can't click
  the poop", after any re-entry). A room re-entered with the same profile is not rebuilt:
  put the camera back yourself (`open_service` does for the toilets and showers).

- **The bottom 7% of a room is the way out** (`INTERIOR_LOOK.EXIT_BAND`): keep things to
  click above it; a click on a hovered task never leaves.

- **Rooms draw through their own viewports, far above the camp**: in a room
  `get_viewport().get_camera_3d()` is still the camera outside; the room's is
  the open room's `_interior_camera`: `InteriorManager.room_camera()` (enemy_base `_room_camera`,
  `_eye(in_room)` for what a brain puts on the view; coop_night `_eye_cam` for "their camera" on
  the other machine). Every room's viewport keeps a current camera, open or not: asking for the
  first current one gave the office's in a cabin (22. 11.: the photographer's light came in from
  the middle of the view whichever window he stood at). The rooms' ceilings have
  no collision (find one by its mesh: `RenderingServer.instances_cull_ray`, which takes the
  ray as endless).

- **The room in `building_interior` is built by jobs behind the loading bar** (`build_job`, `BUILD_JOBS`): its `_process` stays off till `_finish_ready`, what runs earlier meets it half made (the radio took no tracks for the whole game).

- **A body walked with its collisions off** (`collision_mask = 0`: the door walks in
  `interior_manager`) is left alone by the player's physics: main hands the keys back every
  frame no room is open, and with gravity on it sank through the floor while it waited.

- **A one-world room's inside-only things** (its own front door, the rain on its glass, a
  cabin's own panes) are on `INVIEW_HIDE_LAYER` (bit 17), which the player's camera culls
  (`player_controller._ensure_camera`): a new such thing must go there too
  (`_hide_from_camp`). Office state that should show from outside must live in the room
  while it is shut (it is not `visible` then).

- **A room's light switch is its lamp's, nothing else** (the user, 25. 10., the third time:
  "fix the reception's light properly"): off is 0 for that lamp, never a share of it (14 %
  left a ring round the tube at night), and a switch or a power cut never scales the day
  through the window or the ambient (off by day took the daylight to a fifth). Check a light
  change by the picture's mean brightness: the office, lights on / off, day / night
  (12:00: 134 / 121, 22:30: 81 / 21 on 25. 10.), not by eye.

- **A room's windows from the camp look through openings in its walls**: a window's glass
  (its portal) on a solid wall showed the wall's own boards from outside (the caravan,
  `caravan_interior._cut_walls`: the doorway and every window cut out; the windows across
  the room show the camp beyond it through the shared view, put back at the camp's eye).

- **A tent's doorway draws a cube of the room** (`tent_interior._show_cubes`) unless the one room stands in it; `_prism_flap` is wound clockwise from outside for that.
