# AGENTS.md — operating manual for this repo

Onboarding for any agent or developer working on **Cursed Camp Manager Simulator**.
Read this first, then [ARCHITECTURE.md](ARCHITECTURE.md) for wiring and [DESIGN.md](DESIGN.md)
for intent. [PRODUCT.md](PRODUCT.md) says what exists.

> **When docs and code disagree, the code wins.** Fix the doc in the same change.

---

## 1. Ground rules

| Rule | Why |
| --- | --- |
| Mutate state through `CoreRoot.actions`, never `CoreRoot.state.x = y` from outside `core/` | Single write path; `EventBus` notifications are emitted there |
| `EventBus` is the only cross-module signal hub | Modules listen, core emits |
| Systems in `core/systems/` stay pure | No `get_node`, no `SceneTree`; data in, numbers out. Rules modules (`maintenance_rules.gd`, `weather_system.gd`) are static/pure too |
| UI is a read-only view | UI forwards intent; it does not compute costs or odds |
| The game ships in **English** | Czech in comments/commits is fine, never in player-facing strings |
| Refactor strangler-style | New module → route through it → delete the legacy block; one concern per change, verify between |
| Tabs, not spaces | |
| `config/name` stays `"icloud ccs2"` | It names the `user://` folder holding players' saves/settings. The displayed title is set at runtime (`main.WINDOW_TITLE`) |

### Design lock — do not "improve" these without being asked

- The look is a **mid-90s Build-engine game**: pixel fonts on an integer scale, palette,
  bevelled square plates, no rounded corners, no glossy gradients, no app-store polish.
- The tone is **serious, with rare uncanny details** (DESIGN.md §2). No jumpscare spam.
- Every night threat is forecast before it is encountered and has a readable counter.
- `UTILITY_REPAIRS_ENABLED = false` stays off (repairs go through upkeep, hold R).

---

## 2. Layout

```
godot/
  core/                       # canonical simulation, no scene dependencies
    balance/balance_config.gd
    data/                     # BuildingDef + BuildingRegistry (the ONLY building catalog)
    events/event_bus.gd
    state/                    # GameState, GridModel, GameActions, CoreRoot (autoload)
    systems/                  # pure: energy, infra, satisfaction, karma, time, weather,
                              # maintenance, failure, maintenance_rules, guest_needs, builder
  data/buildings/*.tres       # building definitions
  data/pools/                 # email + guest content
  scripts/
    main.gd                   # orchestration (~3k lines; still the biggest file)
    os98/                     # the camp computer "Okna 98" at 640x480: os_shell (desktop,
                              # windows, taskbar, boot), os_theme, os_window, os_files
                              # (the disk), web_pages (the 1998 web), apps/<app>_app.gd
    ui/                       # retro_ui (kit), retro_menu (menu parts), main_menu,
                              # pause_menu, game_over_screen, boot_screen
    enemies/                  # i_enemy_brain, enemy_base, silent_man, tourist, girl, stalker
    hud_manager.gd            # Build-engine HUD
    maintenance_controller.gd # upkeep in the world (signs, hold R, crew)
    electricity_billing.gd    # bills, power cut, UPS
    blood_fx.gd, menu_flythrough.gd, save_codec.gd, ...
  assets/fonts/*.fnt          # baked bitmap fonts (do not edit by hand, see §7)
  tools/                      # in-engine harnesses (§3) and the screenshot driver
tools/                        # repo-level tooling: gen_pixel_fonts.py, gen_sfx.py,
                              # gen_palette_lut.py, artgen/ (Grok Imagine), godot MCP
```

Autoloads (order matters): `SaveManager`, `GameSettings`, `EventBus`, `CoreRoot`,
`EmailManager`, `GuestManager`.

---

## 3. Running and verifying

Godot **4.7.1**. Portable binary on the dev PC:
`C:\Users\arnold\Downloads\Godot_v4.7.1-stable_win64.exe\` (use the `_console.exe` headless).

```bash
godot --headless --path godot --quit-after 400            # smoke
godot --headless --path godot res://tools/hud_layout_check.tscn
godot --headless --path godot res://tools/guest_sim_check.tscn
godot --headless --path godot res://tools/upkeep_check.tscn
godot --headless --path godot res://tools/billing_check.tscn
godot --headless --path godot res://tools/pipes_check.tscn
godot --headless --path godot res://tools/uncanny_check.tscn
godot --headless --path godot res://tools/radio_game_check.tscn
godot --headless --path godot --script res://tools/radio_dread_check.gd
godot --headless --path godot res://tools/look_check.tscn
godot --headless --path godot res://tools/mail_check.tscn
godot --headless --path godot res://tools/arrival_check.tscn
godot --headless --path godot res://tools/enemy_check.tscn
godot --headless --path godot res://tools/nightjobs_check.tscn
godot --headless --path godot res://tools/dayevents_check.tscn
godot --headless --path godot res://tools/os98_check.tscn      # add -- --shots=<dir> (windowed) for screenshots
godot --headless --path godot --script res://tools/weather_check.gd
godot --headless --path godot --script res://tools/week_check.gd
godot --headless --path godot --script res://tools/omens_check.gd
godot --headless --path godot --script res://tools/corn_check.gd
godot --headless --path godot --script res://tools/checkin_check.gd
godot --headless --path godot --script res://tools/season_check.gd
godot --headless --path godot --script res://tools/director_check.gd
godot --headless --path godot --script res://tools/bazaar_check.gd
python godot/tools/coop_check.py [OUT_DIR]   # co-op: two windowed copies (host + client on 127.0.0.1), camps compared; looks, a build, a room's jobs both ways, the boat
```

- **Grep the smoke output for `SCRIPT ERROR` / `Parse Error`.** A tail of the log can hide
  a parse error: the game still prints its normal startup lines after a failed script.
- Harnesses that need autoloads must run as **scenes**, not `--script`.
- Benign at exit: "N resources still in use" / leaked ObjectDB (audio thread race).

### Seeing the game: the screenshot driver

```bash
godot --path godot --resolution 1280x720 res://tools/shot_driver.tscn -- --scenario=<name> --out=<dir>
```

Scenarios: `boot menu views hud quest pause gameover crt crtmap weather upkeep blood night backroom shed boat
saveload guests pipes senses uncanny look gate prep prepcabin mess blockclean day night2 night3 breaker probe`.
Useful steps for the new loops: `topdown` (a camera above the camp, no fog), `open_room`,
`aim_task` (turns the head to a room task and puts the cursor on it), `clean_room` (does every task in the interior's current room), `lmb`, `until` (wait for an Expression on Main), `gm` (call a
GuestManager method: `eval` cannot reach autoloads), `prep_all`. Steps include `build`, `book`, `hours`, `player`, `money`, `press`,
`condition`, `break`, `look_at_enemy`, `crt_screen` (saves the terminal's own frame),
`eval` (Expression against Main; autoload names are not reachable from it).
Check visual changes at 1280x720 **and** 1920x1080.

---

## 4. Where things live

| I want to change… | Go to |
| --- | --- |
| A building's cost/capacity/needs/decay | `data/buildings/<id>.tres` (only place) |
| Tuning constants | `core/balance/balance_config.gd` |
| Upkeep odds/costs | `core/systems/maintenance_rules.gd` |
| Weather durations/transitions | `core/systems/weather_system.gd` |
| Guest needs and archetype personalities | `core/systems/guest_needs_system.gd` |
| Which enemy an archetype brings | `main.ENEMY_FOR_ARCHETYPE` + `scripts/enemies/` |
| HUD | `scripts/hud_manager.gd` (+ `scripts/ui/retro_ui.gd` kit) |
| Menus / pause / game over | `scripts/ui/` |
| Camera moves in rooms; things that move in steps | the camera moves in rooms (sitting down, getting up, looking back, the window, the bus seat) are smooth: `scripts/ui/cam_move.gd` `CAM_MOVE.move(host, camera, {"position": p, "rotation": r}, seconds)`; it holds the tween for a steady frame (`CAM_MOVE.hold(host, tween)` for any tween started while a room is built); the fire, the torch hand, the gate and such machinery step twelve a second through `scripts/ui/step12.gd`; the door transition into buildings `scripts/ui/door_transition.gd` (frozen frame, smooth dither dissolve), called from `interior_manager._door_transition()`; out of them no dissolve: `interior_manager._step_out_of(structure)` puts the warden at the building's door (`door_anim.entry_points`) facing out and walks him off the doorstep (`_walk_body`) |
| Story or sandbox, the sandbox's switches | NEW CAMP page in `scripts/ui/main_menu.gd` (`_set_nc_mode`, `NC_RULE_TEXT`); in game `main.CAMP_RULES` / `camp_rule(id)` ("threats", "weather", "events", "wear", "money"), saved as the snapshot's "rules"; a new system that the sandbox should be able to switch off checks `camp_rule` |
| The title screen's camera (shots, their light and weather) | `scripts/menu_flythrough.gd` (a shot = rails + subject + two looks; nodes found by script, a regenerated camp names them CampLake2 etc.) |
| Studio splash (UNDO LABS + POWERED BY GODOT neon, the first scene) | `scripts/ui/studio_splash.gd` + `materials/studio_neon.gdshader`; palette `tools/gen_splash_palette.py`, sounds `tools/gen_splash_sfx.py`; after any change re-bake the engine boot image: `godot --path godot --script res://tools/studio_splash_bake.gd -- --boot` (frames for a look: `-- --frames=<dir>`) |
| The check-in desk's key board (Dymo labels, the label maker), the room across the counter by hour/weather and its night scares | `scripts/reception/checkin_desk.gd` (`_slots`, `_pick_view`, `_roll_scare`); art `tools/artgen/desk_art.py views` |
| Out of the camp: barrier, road, bus stop, timetable | `camp_gate.gd open_for_player / close_for_player`, `scripts/town/road_south.gd` (built by world gen), `bus_timetable.gd` (the one schedule), `timetable_closeup.gd` |
| The 380 bus (outside, inside, the ride, the ticket machine) | `scripts/town/bus_model.gd`, `bus_ride.gd`, `ride_scenery.gd`, `ticket_closeup.gd`; buses run by the clock in `town_trip.gd` (`_plan`, `_run_special`, `_run_works`) |
| Lesna (village, people, shop, pub, motel, the pump job, pockets) | `scripts/town/town_lesna.gd`, `town_people.gd`, `shop_closeup.gd`, `pub_closeup.gd`, `pump_job.gd` + `pump_closeup.gd`, `pockets.gd`; all routed by `town_trip.gd` (InteriorManager module `trip`); art `tools/artgen/town_art.py` |
| The camp computer (desktop, boot, windows) | `scripts/os98/os_shell.gd`, look: `os_theme.gd` |
| Its programs (CampMail, Beeternet, CampStat, GuestRack, Setup…) | `scripts/os98/apps/*_app.gd`; Builder map: `builder_module.gd` + `crt_map_panel.gd` |
| Web pages, the files on its disk | `scripts/os98/web_pages.gd`, `scripts/os98/os_files.gd` |
| Electricity | `scripts/electricity_billing.gd` |
| Save format helpers | `scripts/save_codec.gd`; snapshot build/apply in `main.gd` |
| Player movement, flashlight battery, stamina | `scripts/player_controller.gd` |
| Bookings, arrivals, the barrier, room states | `scripts/guest_manager.gd`, rules `core/systems/room_rules.gd` |
| The gatehouse, barrier, road | `scripts/camp_gate.gd` (built by world_generator) |
| Room tasks in interiors (hover, hold, checklist) | `scripts/interior_tasks.gd` + `scripts/interior_prep.gd`; what the mess is: `core/systems/mess_rules.gd`; toilet/shower blocks: `service_interior.gd` `set_upkeep_target` |
| Generated sound effects | `tools/audiogen/` (ElevenLabs; key in the gitignored `.env`) |
| Night jobs, the distribution board | `scripts/night_jobs.gd`, `scripts/breaker_panel.gd` |
| Day events, camp life sounds | `scripts/day_events.gd` (sounds in `assets/sfx/life/`) |
| Head turning inside interiors | `scripts/interior_look.gd` (limits set per interior script) |
| Insects falling silent, the HUD face's glance | `scripts/threat_senses.gd` (reads `get_presence()`) |
| Story mails (Vera, Nela, the odd ones) | `data/pools/emails/story/week01_story.json` |
| The radio (playlist, outdoor source, the station) | `scripts/building_interior.gd`, synth: `tools/gen_sfx.py`; songs in `assets/sfx/radio/` (8 kHz 32 kbps, a `night` prefix = night only; originals `ost/<name>_hq.mp3`) |
| The radio going wrong with the night (layers, song bus, broadcasts) | `scripts/radio/radio_dread.gd`; sounds `tools/audiogen/radio_lines.tsv` → `radio_fetch.py` → `tools/gen_radio_dread.py` → `assets/sfx/radio_dread/`; listen: `tools/radio_dread_demo.gd` with `--write-movie` |
| The office: phone, noticeboard, back room, sleep | `scripts/reception/` (reception_extras, back_room, sleep_sequence, camp_office, electrician_visit); the back room's door by hand `reception_extras._swing_back_door`, shut over the night in `_try_sleep`'s `fast_forward`; when beds take a click `camp_office.bedtime()` |
| 2D close-ups (phone, noticeboard, logbook) | `scripts/closeup/closeup_view.gd` + subclasses; who answers the phone: `phone_book.gd`; voices `tools/audiogen/tts.py` + `voices.tsv` (needs a key with text_to_speech) |
| The cursor and the hover glint | `scripts/ui/hand_cursor.gd` (`HandCursor.want(kind)` per frame), `scripts/ui/hover_glint.gd` |
| The thing in the pipes, its staging | `scripts/pipes/pipe_director.gd` (the minigame keeps the network, movement, map, clamp) |
| The night's director (tension, events, log) | `scripts/night/night_director.gd` (pure logic, `tools/director_check.gd`), effects `scripts/night/director_effects.gd`, context `main._director_context()`; sounds `assets/sfx/director/`; F10 panel (debug builds) |
| The reception's plan (office, back room, building, windows) | `scripts/reception/reception_layout.gd`; the building `building_models.reception()`; curtains `scripts/reception/curtain.gd` |
| Builder construction effects | `scripts/builder_fx.gd` (wave, local grid, outlines, ripples); lamp spot on paths `scripts/lamp_spot.gd` |
| Toilet scrubbing | `scripts/scrub_minigame.gd` (opened by `interior_tasks.gd` for tasks with `scrub`) |
| Night work programs | `scripts/os98/apps/datapunch_app.gd`; guest book replies `EmailManager.reply_to_review` |
| The lost and found, the bazaar | `scripts/bazaar.gd` (pure, `tools/bazaar_check.gd`); main `_on_guest_state_for_bazaar` / `_settle_bazaar`; page `bazar-hlubocany.cz` in `web_pages.gd`, `{{bazaar}}` and `bazaar://list/ID` in `browser_app.gd` |
| The generator shed (junk, switch room) | `scripts/shed/generator_shed.gd`; the board's close-up `scripts/breaker_panel.gd` |
| The lake trip, far shore, fishing | `scripts/lake/lake_trip.gd`, far shore in `scripts/camp_lake.gd`, logbook `scripts/lake/logbook_closeup.gd` |
| Corn tiles in the camp | `scripts/world_generator.gd` (`_corn_band`, `_create_corn_patch`), Builder icon in `crt_map_panel.gd` |
| Web pictures | `{{img:name:w}}` in `scripts/os98/web_pages.gd`, files from `tools/artgen/web_image.py` |
| Guests at the campfire, on the slide, on the court | `scripts/attractions/campfire.gd`, `slide_ride.gd`, `pitch_play.gd` (group "attraction": `covers_tile`, `pose_member`; guest_agents hands them the visiting party); the models in `building_models._bonfire/_slide/_sports` (the slide's line and the court's size are metas) |
| Guests in the pub, bistro, Jednota; counter minigames | `scripts/food/service_life.gd` (seats from `service_interior._start_life`); `tap_closeup.gd`, `hatch_closeup.gd`, `till_closeup.gd` (closeup_view subclasses), shared `orders.gd`; opened by the `CounterGameSpot` bodies in `service_interior._build_counter_game` |
| Doors opening for guests | `scripts/attractions/door_anim.gd` (finds Door/DoorLeaf boxes, hinges them) |
| The torch | outdoors `player_controller._aim_beam` + `scripts/ui/torch_hand.gd`; in rooms `scripts/ui/interior_torch.gd` (each interior's `room_is_dark()`) |
| Your hands (who holds what, their pixel size, their light, how they sway) | `scripts/ui/hands.gd` (`Hands.of(node)`: `claim/release(hand, who)`, `torch_hand()`, `light`, `motion`, `px(h)`); the coarse hand sprites `assets/textury/hands_lo/` (`tools/artgen/hands_lo.py` halves the old ones, new ones are processed straight to it) |
| The cigarette and the bottle | `scripts/town/pockets.gd` (keys C / B / X, drawing, drunk), the states `scripts/habits/cigarette.gd` and `bottle.gd` (pure), the world and co-op `scripts/habits/habit_world.gd` (`Coop.send_habit`, the warden state's `hb`); sprites `assets/textury/habits/` (Grok sheets cut by `tools/artgen/split_sheet.py`), sounds `assets/sfx/habits/` (`hb_*` rows in `tools/audiogen/prompts.tsv`); shots `tools/habits_shots.tscn` |
| Lodging numbers and their signs | `GuestManager._number_lodgings / room_short / room_number`; signs `scripts/lodging_signs.gd` (meta `number_plate` from the models) |
| The caravan | `data/buildings/caravan_1..3.tres`, model `building_models.caravan(level)`, room `scripts/caravan_interior.gd` (module "caravan" in `interior_manager.gd`) |

### Adding a building
Create `data/buildings/<id>.tres` (BuildingDef). That is all for the data side; add it to
`builder_module.GROUPS` (+ icon) and `builder_authority.ALLOWED_BUILD_TYPES` to make it
buildable.

### Adding an enemy
Extend `scripts/enemies/enemy_base.gd`, implement `_on_start()` / `_on_tick(dt)`, give it a
tell, a counter, an `_announce()` line, keep `get_presence()` truthful (the base class
tracks the body and its sounds; it drives the insects and the HUD face), then map it in `main.ENEMY_FOR_ARCHETYPE` (or start
it from `_activate_runtime_enemy_for_night`). Add a row to DESIGN.md §5 and to
`scripts/os98/apps/campstat_app.gd` `NIGHT_PROCEDURES` (and the ghost webring in `web_pages.gd`). Test with `debug_spawn_enemy(id)` and the `night` scenario, and give it a row in
`main_menu.TEST_NIGHTS` (the title screen's secret TEST NIGHTS page, key L: a fresh camp at 20:00 with it already out).
The page's last row, Sewer, is no enemy: a sewer hatch by the test camp's toilets breaks
again 2 s after every mend, for the pipes minigame (`main._tick_test_sewer`).

A breakdown the night makes (`night_jobs._start`, the sewer test) is marked `night` in
`state.failures`: anything else that is not a lamp or the derelict cabin is old wear, and
`maintenance_controller._clear_old_wear` mends it on its next sync (until 18. 10. it mended
every night's sewer, toilets and frozen pipes the moment they broke).

---

## 5. Gotchas

- **Esc is always the pause menu** (main `_unhandled_input`), in rooms, at the PC, in
 close-ups and jobs: nothing else may consume it. Its CanvasLayer is 150, above every
 full-screen overlay (the check-in desk is 140); a new overlay stays below it. Leaving is S, the bottom band or a
 right click; the pause menu's "Go outside" (`main._on_pause_leave_requested`) ends any
 room or job the way its own exit would. Back to the title screen closes them too, silently
 (`main._leave_everything(true)` in `_enter_main_menu`): a room left open went on taking
 clicks behind the menu. Always-processing modals return early from
  `_input` while the tree is paused.
- **Interiors live under InteriorManager (the full-res root view), not in World3D**: the
  world is drawn small and scaled up by the render style, and 2D inside it scaled with it
  (huge prompts). Rooms have their own 3D viewports; the office window portal gets the
  camp's world by hand (`_bind_window_world`).
- **Mouse clicks never reach `_unhandled_input`** outdoors: the world's
  SubViewportContainer takes them. Read clicks in `_input`. A ray from a camera inside a
  SubViewport needs the window mouse scaled into that viewport (`lake_trip._mouse_in_cam_viewport`).
- **2D integer scale is chosen at runtime** (`main._apply_integer_canvas_scale`): the
  logical size is window / k so the canvas scale is a whole number and the window is
  filled. The engine's own integer mode letterboxes; do not switch to it.
- **Pixel fonts are bitmaps with integer-only scaling**: request `size_vp` = 8 (labels,
 text) or 10 (Jersey) or multiples; other sizes snap down.
- **2D is nearest everywhere**: the project's canvas default filter is Nearest, and
 `GameSettings` sets every SubViewport's `canvas_item_default_texture_filter` to nearest
 as it enters the tree (a SubViewport's own default is linear: centred text landed on
 half pixels and came out smeared, playtest 18. 10.). Nothing in the game wants linear.
- **Inner classes can't call the outer script's static funcs** (they can read its consts).
- **CRT windows open after a delay**; the reveal is per window and waits for the desktop.
- **`_window_layer` in the CRT shell uses `MOUSE_FILTER_STOP`**: keep it hidden with no
  windows open.
- **Desktop icon release is handled in `_input()`**, not `gui_input` (unreliable after
  `move_to_front()`).
- **Sky/weather profiles derive from a fresh time baseline** each frame; weather changes
  crossfade over 40 s (`weather_visuals`), don't snap the environment directly.
- **Footstep pitch modulation must stay subtle** (whoosh artifact otherwise).
- **Bash heredocs with long inline Python sometimes fail**; write the script to a file.
- **Main resets the active camera every frame** (`_sync_active_camera`) unless an interior
  or the lake trip is active: a mode with its own camera must be added to that check.
- **The shot driver's mouse steers interior looks**: warp it to the centre
  (`get_viewport().warp_mouse(...)`) before shots of a look-around view.
- **Guests asleep are `sleep`, not `active`**: anything that asks "who is in the camp" at
  night must take both (the director saw an empty camp every night because of it).
- **Demolish takes any box up to 64x64** and charges per tile it clears (trees, corn, a
  building's footprint), not per tile of the box; the Builder's tag reads the same numbers
  from `builder_authority.summarize_demolish(rect)`. Build rejections print as
  `SHOT DRIVER build rejected`.
- **Paths go down on release**: the Builder's path tool drags an L-shaped line (Shift keeps
  it straight) and sends the whole line when the button is let go (`_end_path_drag`);
  the confirmations of that batch (`_path_batch`) give one sound and one price, a co-op
  client's arriving later.
- **The OS boot takes ~13 s** (warm-up, BIOS, maker's screen, Okna): harness waits must be
  longer than that, and a test that skips itself when an app does not open must fail.
- **The first scene is the studio splash** (`scenes/studio_splash.tscn`), not main.tscn:
  it loads main.tscn on a thread and changes to it (headless runs skip it at once). The
  engine boot image `assets/boot/undo_labs_boot.png` is its first frame: re-bake it
  (`tools/studio_splash_bake.gd -- --boot`) after changing the sign, wall or shader.
- **Machinery moves in steps, twelve a second; rooms move smoothly** (playtest 18. 10.:
  the stepped room cameras were "choppy"). The fire, the torch hand, the gate, the step
  bob go through `Step12` (scripts/ui/step12.gd); camera moves in rooms, the door
  transition, the A/D push and the walk through a doorway run at the full frame rate.
  Anything that starts in the frame a room is built (or a still is read back from the
  GPU) must wait for a steady frame (`CAM_MOVE.hold`), or its first part goes in one
  jump. A new kind of room must call `interior_manager._door_transition(true)` before it
 opens and, when it has closed, `_step_out_of(its structure)` (no dissolve on the way
 out, playtest 18. 10.); a close that goes straight on into something else (the repair
 under a service room) sets `_no_step_out` around it.
- **Physics ignores visibility**: hidden rooms' bodies still catch rays. Disable a hotspot's
  `collision_layer` when its thing is absent (the empty counter spot stood before the door).
- **Load textures outside draw callbacks**: a texture first `load()`ed inside a `_draw`
  or a `draw` signal handler renders plain white (setup billboard, Display preview).
  Load it when the node is built and draw the cached one.
- **A panel over a room must mute the room**: rooms read clicks and their way out (S, the
 bottom band, a right click) in `_input`, which runs before any Button. The upgrade offer
 (`building_upgrade_menu.gd`) turns off the asking room's `set_process_input` while it is
 up and closes itself when that room is gone; before that its Close never got the click
 and S left the room with the panel still on screen and the mouse captured.
- **The reception's front door is a second portal**: the doorway (`_setup_door_view`) is
 drawn by a camera that copies the room camera mapped into the camp, at the room
 viewport's size (the quad samples `SCREEN_UV`), so it stays sharp right up to the
 cut into the camp; the camp building's DoorLeaf is on GLASS_LAYER, which portal cameras cull.
 Walking out sets `walked_out` and the player is put where the room's eye was
 (`walk_out_handoff`), collisions off for the last step.
- **The reception window is a portal**, not a picture: `building_interior._update_window_portal`
  moves a camera in the camp every frame; the room's fake Outdoor* boxes stay hidden.
- **The monitor glass bends the picture**: `CRT_CURVE` in `building_interior.gd` must match
  `curve` in `crt_glass.gdshader` and `crt_sharp.gdshader`; `_map_mouse_to_crt` runs the
  same barrel, so clicks land where the OS draws.
- **Cursor art is a hardware cursor**: `HandCursor` swaps the ARROW shape's image; scale
  is by whole numbers of the window height (not the logical 2D size).
- **A room's mess must go when its prep goes**: `INTERIOR_PREP.dispose()` takes the mess
  and its click bodies out of the tree at once. Freeing only the task overlay left the
  last visit's bodies under the new ones, and the cursor ray hit those ("I can't click
  the poop", after any re-entry). A room re-entered with the same profile is not rebuilt:
  put the camera back yourself (`open_service` does for the toilets and showers).
- **The bottom 7% of a room is the way out** (`INTERIOR_LOOK.EXIT_BAND`): keep things to
  click above it; a click on a hovered task never leaves.
- **Seated guest sprites** (`*_sit`, `*_drink`, `*_eat`): the node goes on the floor just in
  front of the seat, the seat line is 0.45 m up the sprite; for a bar stool put the node at
  stool top - 0.45, in front of the stool, or its seat cuts the legs.
- **Co-op is for up to four** (`Coop.MAX_WARDENS`; 19. 10.): the other wardens are
  `Coop.others()` (peer ids, the host is 1), each with `state_of` / `look_of` / `name_of` /
  `figure_of`; in a handler of something that came in (`coop_request`, `coop_play`,
  `coop_sync`, `coop_inv`, `coop_habit`) `Coop.sender` is who sent it. Who is in the camp
  is the host's roster (`Coop._roster`): a joining machine takes the other joining ones
  from it, not from the relay's peer_connected (a fifth, told the camp is full, never
  shows up there; a hello before the roster is kept, `_early_looks`). Everything goes to
  everyone (the host relays: SceneMultiplayer's server relay); something meant for one
  warden carries their id and the others drop it (the lift, a pipe knock, a light for a
  cigarette, an item picked up). `partner_*` / `remote_figure()` / `partner_name()` are the
  first of the others only, left for what has no need to count. A thing for "the other
  warden" in a room, on the bus, at an attraction, in a Lesna place, in the pipes, on the
  map is one figure per id (look how `interior_manager._coop_figs` does it). The night
  calls a warden "host" or "p<peer>" (`coop_night.who_of`); each has a stand-in, a
  sanity and their own private enemies. `tools/coop4_check.py` runs four copies.
- **Co-op: the joining machine simulates nothing** (`Coop.sim_here()` false): no clock,
  weather, billing, nights, arrivals or saves of its own; main gates them in `_process`
  and the handlers. A new system that changes the camp must check `Coop.sim_here()`.
  The camp is sent as the save snapshot, so whatever the camp is must be in it (and
  survive `save_codec.gd`: it drops keys it does not know, as it did the old cabin's
  `derelict`).
- **The same camp needs the same dice**: `world_generator.world_seed` seeds the lake,
  fences, corn, litter and horizon; a tile's tree comes from `_tile_rng(coord)`; trees and
  corn are saved (`nature`). Draw new world dressing from `_rng` inside
  `generate_base_world` (or a tile's own dice), never `randf()`. Duplicate node names get
  Godot's `@Name@NNN`: tell kinds apart by group, not by name.
- **Testing co-op on one PC**: a copy of the game takes ~50 s to boot beside another, and
  the joining one stops answering for tens of seconds while it builds the camp (ENet is
  told to wait a minute, `Coop._patient`). The console binary starts the game as a child:
  end the tree (`taskkill /T`), or a stray copy keeps the port.
- **Co-op in a room**: an interior is a world of its own (`own_world_3d`), so the other
  warden there is a second `remote_player.gd` (manual) in the open interior's `_viewport`,
  put there by `InteriorManager.coop_partner` from the room the other machine reports
  (`coop_room()`: key, kind, part, the job in hand). A new kind of room needs
  `_room_part` and `_room_tasks` to answer for it, or the two never meet in it.
- **Co-op: the joining warden's hands** go to the host: `Coop.send_request(kind, data)` →
  `main.coop_request` does it in the host's camp, and it comes back (a build as a fact,
  the rest with the camp pulse). Something new that changes the camp from the joining
  machine must forward like this (look at `email_manager._coop_send`, `desk_room.gd`,
  `maintenance_controller.gd`); on that machine GuestManager and the mail simulate
  nothing (`Coop.sim_here()`), and its builder authority is unhooked from
  `RequestBuild`/`RequestDemolish` (`main._coop_forward_builds`): replay facts by calling
  the authority directly, never by emitting the request. That machine's E and click go
  through `main._coop_client_interact`, whose `_coop_client_room_target` lets through only
  the kinds it names: a new kind of thing to click must be added there (the barrier, the
  bus and Lesna were missing until 18. 10.).
- **Co-op nights** (`coop_night.gd`): an enemy brain hunts whatever `_player` it holds:
  the host swaps in the other warden's stand-in (`coop_proxy.gd`: a body, Head/Camera3D,
  their torch) with its own damage / allow / notify callables. A brain that reads or sets
  something new on the player must find it on the stand-in too. The other machine draws
  every Sprite3D, Light3D and playing AudioStreamPlayer3D under a brain's `_root`, so
  keep an enemy's look inside its root; anything else of the host's that the other should
  see (a caller like the electrician) goes in the `coop_mirror` group. The sanity is never
  to be shown or named.
- **Co-op till**: the other machine's money is the host's plus its own changes not yet
  counted there (`main._coop_follow_till`: any change of `state.money` on that machine goes
  over as a numbered "till" delta, the host's clock says up to which it counted). So
  spending or earning on that machine needs no forwarding of its own.
- **Co-op: things both machines change** (the office's lights, curtains and set, the desk's
  register and key hooks, the barrier) go both ways through `Coop.send_sync(kind, data)` →
  `main.coop_sync`; main polls them (`coop_sync_poll`, 0.3 s) and sends only what changed
  here. The host's events and arrivals reach the other machine through the pulse, so
  anything that rebuilds on a pulse must keep what is still open (the raccoons' bin loop
  restarted every second).
- **The warden in an attraction** (`scripts/attractions/warden_play.gd`): the attraction
  places a stand-in through its own `pose_member(0, key, ...)` with a warden key (-11 the
  host's warden, -12 the other's: keys below 0 are never guests, nor counted in
  `guests_here`); each attraction answers `warden_offer/join/leave/slot/force/focus/press`
  (+ `warden_pose/hint/exit/done/hold/extra` where it has them). The other machine's
  warden is put in with `warden_force` (their place there) and drawn from
  `mate_place()` (remote_player.gd, state "att"). The ball games are the host's in
  co-op: `_launch` sends each flight (`Coop.send_play` "shot"), the other machine only
  follows (`coop_take_shot`) and sends its swings ("press").
- **Business rooms** (`service_interior.gd`): the pub, the bistro and the Jednota change
  rooms only by their doors (`scripts/food/business_doors.gd`; `_build_business_doors`
  puts them in walls the layouts keep free: move a prop off a wall and check the door
  still fits). While a door walk runs it owns the camera (`_doors.walking()`). The work
  marks (`scripts/food/work_marks.gd`) read `business_runtime.waiting_at` and the site's
  books; a new counter game needs its job in `coop_job`, `COOP_JOB_SPOTS` and SPOTS.
- **Co-op business books** (`GameState.biz`): the host's. The pulse carries them; on the
  joining machine every `actions.biz_*` change also calls `biz_remote` (main sends it as
  a "biz" request; the host replays it without money: `biz_sale(..., credit=false)`,
  `biz_add_order`). New mutations of the books belong in actions.gd with `_biz_tell`.
- **Two in the pipes** (`scripts/pipes/pipe_mate.gd`): the crawl's network is seeded by
  the sewer and the day it broke, the holes by the raccoon level; the second one down
  takes both from the first (warden state "pipe": sd, lv, fx). `_try_move` and
  `_back_up` ask `mate.blocks`. Anything that changes the network's generation must keep
  `preview_network` (the chamber's terminal) and `open_repair` in step.
- **Co-op back office** (`main.coop_camp_pulse` "books"): reviews, transactions,
  satisfaction, karma, the electricity bills and the bazaar are the host's; the other
  machine's `request_pay_electricity_bill`, `request_maintenance_crew` and `bazaar_list`
  check there and ask the host (`Coop.send_request`), spending nothing themselves (the
  till follows the host's). Anything new that pays or charges from a PC program must
  do the same, or it is paid twice or lost at the next pulse.
- **Co-op radio** (`building_interior.gd`): the host's set is the one; `_play_radio_next`
  does nothing on the other machine, which plays what `coop_radio_state` says (main's
  `_coop_sync_things` "radio", sent when the piece or its 4 s step changes): a song by
  path, the station by its pips, an interlude by its pieces (`radio_dread.interlude_desc`
  / `coop_play_interlude`). Anything new that plays on the radio must call
  `_radio_on_air` or the other machine will not hear it.
- **Co-op knocked down** (`main._coop_come_to`): health 0 with a partner does not end
  the game: `_coop_down` (controls off, damage ignored, warden state "dn", the figure
  lies prone on the other machine, `coop_night._is_out` false); the other's E sends
  "lift" (`Coop.send_play` -> `main.coop_lifted`), else `COOP_DOWN_WAIT` and the office
  step. Anything that hurts the warden must go through `damage_player`.
- **Co-op bus** (`bus_ride.gd`, `town_trip.gd`): each machine runs its own ride; the
  warden state's `bus` ({st, s, go}: stop, seat, under way) is what the other sees. A
  partner aboard and not gone turns that stop's bus into a "hold" special
  (`_coop_hold`); seated, the ride sits in HELD till `_mate_ready`. When the bus goes with
  one alone, the other's stop gets a "drop" and `_coop_gone` keeps that run off it. The
  passengers are seeded (stop, day, half-hour) so both rides match; a seated figure needs
  a `*_sit.png` beside its sprite (wardens: the "sit" pose in `warden_looks.gd`).
- **Co-op sleep** (`camp_office.gd`): lying down sets `in_bed` (sent as the warden
  state's `z`); the host passes the night only when both are in bed and its own eyes are
  shut (the sleep sequence's DARK), and stops it if either gets up; the other machine
  waits in the dark for the host's clock to show the night passing (`sl`) and then not.
  Anything else that sleeps (the motel) must go through `start_sleep` /
  `is_sleeping_through` too.
- **Over the shoulder**: the one at the PC sends a small JPEG of the CRT viewport
  (`building_interior.coop_screen_frame`, only while the other is in the office) and the
  other puts it in the CRT glass shader's `screen_tex`; it falls back to its own PC's
  viewport when frames stop for 0.8 s. Reading the viewport stalls the GPU a moment:
  keep the rate low.
- **One pixel throughout** (the user, 18. 10.: everything in game pixelated, at the same
  Build-engine resolution): people 128 px to 1.74 m (73.6 px/m; a pose's picture is
  processed to its height in metres times that: lying 0.62 m = 46 px), rooms and things
  in them 128 px to a 1.4 m tile (91 px/m: a sprite 0.26 m tall is 24 px, a sign
  0.38 m is 35). A picture finer than that gets shrunk to it (`service_interior._wall_decal`),
  never shown small at its full size.
- **Warden looks** (`warden_looks.gd`): a jacket colour is the jacket's pixels moved to
  another hue, found by hue band, rows per pose and boxes left out (boots of the same
  green: `JACKETS`); a new warden or pose needs its entry, checked on a sheet of all
  colours. `Texture2D.get_image()` hands back the texture's own image: duplicate it
  before changing it, or every colour after the first comes out the same.
- **Grok poses of one character drift** (a cap, another shirt, older): name every piece
  of their clothes in the prompt, and look at each render. Background caught between
  legs or under an arm comes out darker magenta: `process.py` keys it; people then go
  through `tools/artgen/defringe.py --figure` (warden_b's red anorak: `--rows`).
- **Things outside the camp are clicked through InteriorManager**: give the body a
  `building_type` starting `trip_` or `town_` and `town_trip.gd` answers `hint_for` and
  `interact` (the hint can depend on the thing's state: `get_hint_for_structure`). Things
  you click but walk through go on collision layer 12 only (`1 << 11`, mask 0): the
  interaction ray hits every layer, the player's body only layer 1.
- **Interaction rays are cast in the camera's own viewport**: the world is drawn small and
  scaled up, so screen points must be in that viewport's pixels
  (`camera.get_viewport().get_visible_rect()`), not the window's. Until 17. 10. they were in
  window pixels and only the structures fallback ever found anything.
- **Lesna is in the same world, far off** (`town_lesna.ORIGIN`, x + 4200, built on the first
  trip): the sun, sky, fog and weather are the camp's. `town_trip.away()` (within 1.5 km
  of it) makes main keep the night off (`_away_in_town`: no enemy actions, director place
  "away"). The bus ride is its own world (like a room) that copies the main
  WorldEnvironment and Sun when it opens; its cabin is on render layer 2 and the sun lights
  only layer 1.
- **Emission with a mask texture multiplies, it does not add**: StandardMaterial3D adds
  `emission_texture` to `emission` by default (a mask lit the bus windows white by day);
  set `emission_operator = EMISSION_OP_MULTIPLY`.
- **BoxMesh UVs are a 3 x 2 atlas**: one texture on a box shows a third of it per face;
  `uv1_scale` (3, 2) shows it once per face (`town_lesna._tiled`). Put art that must read
  whole (signs, facades, the bus's sides) on a QuadMesh.
- **The shot driver's eval is a Godot Expression**: no assignment (use `.set('prop', v)`)
  and no autoloads (`CoreRoot` is not visible); a subclass of `tools/shot_driver.gd` that
  sets `_steps` in `_ready()` after `super._ready()` runs ad-hoc scenarios.
- **GDScript names**: a method called `_set` overrides `Object._set` (parse error about the
  signature); a subclass may not re-declare its base's constants (`SFX_OPEN` in closeup_view).
- **Hands are claimed** (`scripts/ui/hands.gd`): anything drawn in the player's hand claims
  "right" or "left" while it is up and releases it when it is down (work > bottle >
  lighter > torch/cigarette). The torch changes hands by itself (the right busy: the left,
  mirrored; both busy: in the pocket, `player_controller.hand_busy` puts its light out).
  A new hand overlay must claim, draw at `Hands.px(view height)` on that pixel grid, take
  `light` as its modulate and add `motion`; never rotate a hand sprite.
- **A close-up hides the hands**: `closeup_view.gd` (and the breaker, scrub, corn stand,
  check-in desk) are in group "closeup"; pockets.gd keeps the hands down while one is
  visible. A new full-screen overlay where your hands are busy joins that group.
- **Python in the Bash tool**: the tool turns a doubled backslash into a single one before
  bash sees it, so an escaped backslash at the end of a line in a heredoc reaches Python as
  a line continuation (the replacement silently changes nothing); write such scripts with
  the Write tool to a .py file instead.

---

## 6. Working style

1. Check [TODO.md](TODO.md).
2. Make the change in scope; keep `core/` pure.
3. Run the smoke test and every harness touching the area.
4. Run the screenshot driver for anything visible; look at the images.
5. Update the docs the change invalidated (PRODUCT status table, DESIGN rules).
6. Commit with a message that says what was wrong, not just what changed.
7. Push `main` to both remotes: `origin` (GitLab) and `github`.

---

## 7. Art, fonts and sound pipelines

- **Generated art** — Grok Imagine through the Cursor agent CLI:
  `tools/artgen/gen.sh <id>` reads `tools/artgen/prompts.tsv` (id, aspect, reference image
  relative to `godot/` or `-`, prompt), writes `tools/artgen/out/<id>/raw.png` (gitignored).
  **One at a time**: parallel runs swap outputs. ~2-5 min per image; `tools/artgen/queue.sh <id>...`
  runs a list one after another. `tools/artgen/os_art.py` turns the OS/Builder/mail renders
  (ico2_*, oem2_splash, wall2_*, bld_*, tb2_*, spam_*) into game files. The tool supports 1:1,
  4:3, 3:4, 16:9, 9:16 only.
  Then `python tools/artgen/process.py <id> sprite <height> <dest>` (keys out flat magenta,
  box-downsamples, snaps to the game palette) or `texture <size> <dest>`.
  For sprites ask for a flat pure magenta `#FF00FF` background and pass an existing sprite
  as reference so pixel scale and palette match.
- **Batches**: `tools/artgen/batch.sh <id>...` (textures, 128 px) and
  `tools/artgen/batch_panels.sh <width> <id>...` (posters, views) generate and process one
  after another; never start a second batch while one runs. `crop_goods.py` crops the
  shop-goods renders (Grok puts the row at the bottom of a dark canvas).
- **Interior props (Blender)**: `tools/blender/build_props.py` (+ `props_more.py`, kit in
  `propkit.py`) builds every low-poly prop from parts and exports
  `godot/assets/models/interior/<name>.glb` **without images** plus `materials.json`
  (material name -> camp texture + tint). Run headless:
  `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/build_props.py [-- name ...]`,
  then `godot --headless --path godot --import`. `preview_props.py -- out.png` renders them all.
  Conventions: metres, origin on the floor at the footprint centre, front towards Blender
  -Y (Godot +Z). Wall-mounted props: mind that the origin is the footprint centre.
  The user's Blender (with the MCP addon on :9876) may have another project open: do not
  touch it, work headless.
- **Interior kit** (`godot/scripts/interior_kit.gd`): `surface(tex, metres)` = a camp
  texture mapped in world space (Build-style, seamless, nearest); `room()`, `slab()`,
  `skirting()`, `picture()` and `prop()` (instances a .glb and puts the shared camp
  materials back by name). New interior work uses it instead of `texture_style` (the old
  colour-matched rips are left only on the cellar machine animation and a few small bits).
- **Fonts**: `python tools/gen_pixel_fonts.py` bakes `tools/font_src/*.ttf` into
  `godot/assets/fonts/*.fnt/.png` on their native grid. Import setting `scaling_mode=1`.
- **Synth SFX**: `python tools/gen_sfx.py` (shutter, flash whine, static/hum loops, thump).
- **Palette LUT**: `tools/gen_palette_lut.py`.

Licensing: most world textures are rips from Redneck Rampage (`assets/textury/redneck/RRTX*`).
Fine for a private prototype, a blocker for any public release; replace them with generated
textures (§7) before shipping.
