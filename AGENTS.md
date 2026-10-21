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
| The game ships in **English and Czech** (since 21. 10.) | The code's strings are English; the Czech is in `godot/locale/cs.po` (§8). Every new player-facing string goes in with its Czech in the same change. Czech in comments/commits is fine |
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
    os98/                     # the camp computer "Okna 98" at 640x480: os_shell (the panel:
                              # tabs, pages, taskbar, boot, installs), os_page, os_theme,
                              # os_window (dialogs), os_files (the disk), web_pages (the
                              # 1998 web), apps/<app>_app.gd, apps/job_*, apps/game_*
    ui/                       # retro_ui (kit), retro_menu (menu parts), main_menu,
                              # pause_menu, game_over_screen, boot_screen
    enemies/                  # i_enemy_brain, enemy_base, silent_man, tourist, girl, stalker
    hud_manager.gd            # Build-engine HUD
    maintenance_controller.gd # upkeep in the world (signs, hold R, crew)
    electricity_billing.gd    # bills, power cut, UPS
    blood_fx.gd, menu_flythrough.gd, save_codec.gd, ...
  assets/fonts/*.fnt          # baked bitmap fonts (do not edit by hand, see §7)
  tools/                      # in-engine harnesses (§3) and the screenshot driver
tools/                        # repo-level tooling: gen_pixel_fonts.py, audiogen/,
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
godot --headless --path godot --script res://tools/goggle_check.gd
godot --headless --path godot --script res://tools/builder98_check.gd
godot --headless --path godot --script res://tools/lang_check.gd    # the Czech lookup, every translation keeps its values (§8)
godot --headless --path godot --script res://tools/bistro_check.gd
godot --headless --path godot res://tools/business_check.tscn   # the books: lots, going off, gear, one order, wages
godot --headless --path godot res://tools/staff_check.tscn      # the hands: ways, applicants, shifts, away, theft, the kitchen's crew
godot --headless --path godot res://tools/pub_check.tscn        # the pub: the tap from the books, Papa's serve, flat kegs, the hands, the stations
godot --headless --path godot res://tools/stand_check.tscn      # the corn stand: the pot, the bowl, the orders, Papa's serve, the hands, the stations
godot --headless --path godot res://tools/jednota_check.tscn    # the Jednota: the rack, the queue, the till, boxes, the hands, the stations, it pays
godot --headless --path godot res://tools/proto_check.tscn      # PROTOTYP 540: awake hours, the sack's nights, fed, the meat in the stock
godot --headless --path godot res://tools/podniky_check.tscn    # the businesses' polish: thirst, the Jednota's bag, the rush, corn drinks, the grill, the bufet, the deli, the Z mark
python godot/tools/podniky_coop.py [OUT_DIR] # the four places for two: a drink, a bill, the slot, the grill, the bufet, the deli done on one machine and seen on the other
python godot/tools/coop_check.py [OUT_DIR]   # co-op: two windowed copies (host + client on 127.0.0.1), camps compared; looks, a build, a room's jobs both ways, the boat
python godot/tools/coop_photo.py [OUT_DIR]   # co-op Photographer on the joining warden: the white and their polaroid, the run at their back, at their window, the last picture: theirs alone
godot --headless --path godot res://tools/post_check.tscn      # the second monitor: the order paid, the van on the clock, the postman at the counter, the slip, two screens and the swap, the keys, the save, the postman who gives up
python godot/tools/post_coop.py [OUT_DIR]   # the second monitor for two: ordered on the joining machine (paid once), the host's van and postman on both, signed for there, the monitor on both
python godot/tools/window_coop.py [OUT_DIR] # the reception's windows for two: from outside the joining warden sees the host at the PC, in the back room, the curtain drawn, the lights out
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

Films of the businesses' work (the camera to a station, frying, a beer, the till, PROTOTYP 540):
`godot --path godot --write-movie <out>/<movie>.avi --fixed-fps 30 res://tools/movie_driver.tscn -- --movie=till|fry|tap|proto --out=<out> --size=1280x720`,
then `python tools/movie_cut.py <out>/<movie>.avi` keeps only the work (its `mark` steps) as `<movie>_cut.avi` and
a small animated `<movie>.webp`. The business shot drivers (`jednota_shots`, `proto_shots`) take `--size=WxH` too.

---

## 4. Where things live

| I want to change… | Go to |
| --- | --- |
| A building's cost/capacity/needs/decay | `data/buildings/<id>.tres` (only place) |
| Tuning constants | `core/balance/balance_config.gd` |
| Upkeep odds/costs | `core/systems/maintenance_rules.gd` |
| Weather durations/transitions | `core/systems/weather_system.gd` |
| Guest needs and archetype personalities | `core/systems/guest_needs_system.gd` (the night's rest: `night_sleep` in `decay_needs`, `sleep_mood_target`, `MORNING_NEEDS`, called from `guest_life._advance_guest`) |
| The marker over a guest's head ("!", heart, the need plates) | `guest_agents._update_marker`, `MARKER_NEEDS`; the plates drawn by `tools/gen_stink_sprites.py` |
| Which enemy an archetype brings | `main.ENEMY_FOR_ARCHETYPE` + `scripts/enemies/` |
| HUD | `scripts/hud_manager.gd` (+ `scripts/ui/retro_ui.gd` kit) |
| Menus / pause / game over | `scripts/ui/` |
| Camera moves in rooms; things that move in steps | the camera moves in rooms (sitting down, getting up, looking back, the window, the bus seat) are smooth: `scripts/ui/cam_move.gd` `CAM_MOVE.move(host, camera, {"position": p, "rotation": r}, seconds)`; it holds the tween for a steady frame (`CAM_MOVE.hold(host, tween)` for any tween started while a room is built); the fire, the torch hand, the gate and such machinery step twelve a second through `scripts/ui/step12.gd`; the door transition into buildings `scripts/ui/door_transition.gd` (frozen frame, smooth dither dissolve), called from `interior_manager._door_transition()`, skipped since 21. 10. when you walked in through the door by hand (`_walk_up_first`, `_walked_in_ms`); out of them no dissolve: `interior_manager._step_out_of(structure)` puts the warden at the building's door (`door_anim.entry_points`) facing out and walks him off the doorstep (`_walk_body`) |
| Story or sandbox, the sandbox's switches | NEW CAMP page in `scripts/ui/main_menu.gd` (`_set_nc_mode`, `NC_RULE_TEXT`); in game `main.CAMP_RULES` / `camp_rule(id)` ("threats", "weather", "events", "wear", "money"), saved as the snapshot's "rules"; a new system that the sandbox should be able to switch off checks `camp_rule` |
| The title screen's camera (shots, their light and weather) | `scripts/menu_flythrough.gd` (a shot = rails + subject + two looks; nodes found by script, a regenerated camp names them CampLake2 etc.) |
| Studio splash (UNDO LABS + POWERED BY GODOT neon, the first scene) | `scripts/ui/studio_splash.gd` + `materials/studio_neon.gdshader`; palette `tools/gen_splash_palette.py`, sounds recorded (ElevenLabs, `splash_*` rows in `tools/audiogen/prompts_world.tsv`); after any change re-bake the engine boot image: `godot --path godot --script res://tools/studio_splash_bake.gd -- --boot` (frames for a look: `-- --frames=<dir>`) |
| The check-in desk's key board (Dymo labels, the label maker), the room across the counter by hour/weather and its night scares | `scripts/reception/checkin_desk.gd` (`_slots`, `_pick_view`, `_roll_scare`); art `tools/artgen/desk_art.py views` |
| Out of the camp: barrier, road, bus stop, timetable | `camp_gate.gd open_for_player / close_for_player`, `scripts/town/road_south.gd` (built by world gen), `bus_timetable.gd` (the one schedule), `timetable_closeup.gd` |
| The 380 bus (outside, inside, the ride, tickets, the people on board) | `scripts/town/bus_model.gd` (a Karosa SM 11 in CSAD white and yellow, its faces drawn to the metre by `tools/artgen/karosa.py` (`karosa_*.png`, holes where the door, the windscreen and the wheel arches are; keep its measures and the model's in step); the front door a real opening with jambs and four glazed panels folding in on their hinges (`_build_door`, `_fold`: smoothstep over `DOOR_TIME`, the hiss from `open_door`); see-through windscreen and door glass; inside, for the door and the windscreen, the steps, the yellow pole with the punch, the tan seats and the driver's place), `karosa_cab.gd` (the driver's seat, wheel, dashboard, gear stick and the grey tube after the photo, built the same outside and in the cabin; the driver is Grok's `bus_driver_seated.png` / `_front.png`, no seat painted in), `bus_ride.gd` (its cabin uses the bus's own door leaves and builds the stairwell; `_try_sit` refuses a seat a villager sits on, tours use `first_free_seat`) (you ride the real road in the game's world: the cabin is carried by `town_trip._ride_bus` along `bus_ride.path`, which `town_trip._ride_road` builds from the route in `scripts/geo/` with a speed for each stretch and slower in the bends; the main viewport stops drawing while it is open; the clock slowed by `main.clock_scale` so the ride takes the timetable's minutes, in co-op for both); tickets: the stop's yellow machine `ticket_machine.gd` (`trip_ticket_machine` -> its close-up `ticket_machine_closeup.gd` via `town_trip._open_machine`, a `ticket` in the bag; `_buy_ticket` is the instant one for tests), the driver with the surcharge (`bus_ride._buy_from_driver`), the orange validator on the door pole (`_punch` opens `punch_closeup.gd`, its `punched` at the cvak: `ticket` -> `ticket_used`); the riders are villagers `npc/bus_<id>_sit/_back.png` facing the way the bus goes (`_face_passengers`; campers get a back made by `_back_of`), their coughs, conversations and turning round planned by `_plan_life` from the run's seed (co-op: the same on both); old Vacek (`VACEK`, Grok `npc/bus_vacek_sit/_back/_turn/_walk.png`) gets on at Pristoupim now and then by day (`_board_plan` from `_life_rng`; the bus stops for him, `_board_start` walks him in, `_boarder_seat` puts him behind, in front of or across from one of you, his "May I?" and then a story `v1`-`v3`, turned round to you over his shoulder while he talks, `vo` at the end of the line); you change seats mid-ride by clicking a free one (`_move_seat`: WALK_PATH up, down the aisle and into it; others see you in the aisle, "wz"); the driver's lines are his Czech voice by keys (`_driver("d_*")`, `DRIVER_LINES`; outside the bus `town_trip._driver_voice`); the Czech `assets/sfx/bus/talk/` from `tools/audiogen/bus_talk.tsv` (scenes s*, turns t*, Vacek v*, the driver d_*): `<id>.mp3` by `bus_talk.py` (ElevenLabs: the key can only speak, so voices are premade ids tried by hand; Sarah is gone, the woman is Lily) wins over the stand-in `<id>.wav` by `bus_talk_local.ps1`; a line with neither still shows its subtitle; potholes and lorries come by the metre (`_hash01` of the distance), so in co-op they come at once; buses run by the clock in `town_trip.gd` (`_plan`, `_run_special`, `_run_works`); the Karosa's sounds `assets/sfx/bus/karosa_*` (rows in `tools/audiogen/prompts.tsv`; `bus_ride._sfx` falls back to the old ride.mp3 when one is missing) |
| The real land round the camp (1:1, OpenStreetMap) | `tools/geo/build_world.py` turns `tools/geo/osm/area.json` (an Overpass export, not committed; the script's header says how to fetch it) into `godot/data/geo/world.json`: roads, fields, woods, water, ~1600 buildings, trees, power lines, the 380's route and its stops, the masts, the fuel stations (x east, z south, metres from the camp's GPS 50.0606589 N, 14.8477650 E). `scripts/geo/geo_data.gd` (static: the data, the route `at(s, lane)`, `nearest`, `s_near`, `line_path`, `stop_s`, and the places' names in one place: `CAMP_NAME`, `TOWN`, `HAMLET`, `BROD`, `BEYOND`, `SHOP`); `scripts/geo/geo_world.gd` (ground, fields, roads at once; buildings, trees, poles, fences in 250 m chunks streamed round the eye by `update(eye)`; the Benzina at the camp's turn off road 12, the villages' name signs; it hides the camp generator's horizon hills). `town_trip._ensure_country` builds it and sets Liblice (`town_lesna.ORIGIN/YAW`, `GEO_MODE`) and Pristoupim (`hamlet_podlesi.HAMLET_ORIGIN/HAMLET_YAW`) at their real stops; the camp's own map is untouched. Look at a place with an ad-hoc shot driver: `<town_trip>._geo.build_all_near(p)`, then put the player there. Benches you sit on (`town_bench`, `town_trip._sit`, `player_controller.seated`). Map data (c) OpenStreetMap contributors, ODbL: keep the credit |
| Liblice (the village round its stop: people, the Jednota u Marku, pub, motel, the self-service Benzina, pockets; the scripts keep their old name `town_lesna`) | `scripts/town/town_lesna.gd`, `town_people.gd`, `shop_closeup.gd`, `pub_closeup.gd`, `pockets.gd`; its Benzina: the village's cars fill up themselves (`pump_job.gd` with `self_service`, `spots["station_cars"]`), its pumps fill Vondra's can (`town_trip._fill_can`); all routed by `town_trip.gd` (InteriorManager module `trip`); art `tools/artgen/town_art.py` |
| Lojza's job at the Benzina by the camp's turn off road 12 | `geo_world._benzina` / `_benzina_job` (the station, the cars' ways in and out in its frame, the pumps `trip_pump`, Lojza `trip_lojza`, his hours in `set_hour`), `pump_job.gd` (paths from the owner: `setup(stops, ins, outs)`) + `pump_closeup.gd`; `town_trip._job()`, `_start_job`, `_watch_job` (the shift ends 32 m from `geo_world.benzina_at`) |
| Liblice's houses, fronts and lettering | `town_lesna.gd` `_houses()` (the street list), `_gable_house` / `_hip_house` / `_eaves_house` / `_flat_house` build a house to fit its Grok elevation (`lib_*` rows in prompts.tsv) as measured by `tools/artgen/town_facades.py` (`lib_facades.json`: walls, eave; `<id>_win.png` lit windows, `<id>_side.png` side walls; window rectangles are measured by hand on the raw render); lettering `tools/artgen/lettering.py` (`sign_<name>.png`, put on a wall with `_letters`); the green `_green()`, fields `_fields()`; what stands out of the walls (plinth, sills, gutters, ridge, chimney caps, aerials, the yard porch, back windows) `_plinth`, `_front_sills`, `_gutters`, `_aerial`, `_porch`; a front too patchy to tile gets plain plaster on its other walls (`SIDE_FROM`); look at it with `res://tools/lesna_tour.tscn -- --out=<dir>` |
| The transmitter masts, road posts | `scripts/town/liblice_masts.gd` (made by `town_trip._update_masts`, haze from the outdoor fog), `scripts/town/road_post.gd` (`place(parent, pos, to_road)`, `set_night`) |
| Pristoupim (the hamlet on the way, its request stop, Vondra's Skoda; the scripts keep their old name `hamlet_podlesi`) | `scripts/town/hamlet_trip.gd` (state and save, its bus by `bus_timetable.hamlet_to_town/_camp`, the "ham_*" clicks, Vondra), the place `hamlet_podlesi.gd` (extends `town_lesna.gd` for the house kit: do not change the parent's method signatures), the repair close-up `car_closeup.gd`; in the ride: `bus_ride.path_hamlet` (how far along the ride's path the request stop is), `bus_ride._press_stop` (STOP buttons, STOJIME), `arrived_where`; boarding there: stops "hamlet_town" / "hamlet_camp" (`town_trip._board`; no machine there: the driver sells) |
| The walkie-talkie and the megaphone (your voice to the other wardens) | `scripts/coop/voice.gd` (Coop's child): hold `radio_talk` (V) in co-op or `megaphone_talk` (G) with the megaphone in the bag; the microphone (project setting `audio/driver/enable_input`) through a muted bus with an AudioEffectCapture, 16 kHz mono mu-law, 20 ms a packet over `Coop.send_voice` (unreliable, channel 6); heard through the "VoiceRadio" bus (2D, a little speaker) or "VoiceMegaphone" (3D at the shouter's figure, loud and far); the squelch sounds `assets/sfx/radio/` from `tools/audiogen/synth_sfx.py` (it also makes the validator's `ticket_punch.wav`); guests near the megaphone look up (`guest_agents.alert`); the hand `hands_lo/radio.png` / `megaphone.png` while you talk. The megaphone lies by the chest of drawers in the room behind the office (`back_room.gd` "megaphone", `reception_extras._take_megaphone`; inventory "megaphone"). Keys you can change: `GameSettings.REBINDABLE` (saved in settings.cfg [keys]), Controls page: click the key, press a new one (`key_clash` says what else is on it) |
| Pristoupim's ruin, Vondra's lift | `ruin_closeup.gd` (the Hronek kitchen close-up and its scare, `state["ruin"]` counts the looks); `skoda_ride.gd` (the garage Skoda driven along the real road to the camp stop: `_build_path` = the hamlet's track + `GEO.line_path` + `road.bus_arrive_path`; it parks its camera in `main.debug_camera`, which main makes current every frame, and slows the clock like the bus; `town_trip._eye_for_geo` follows the car); his lines `vd*` in bus_talk.tsv (voice "vondra"); co-op: `hamlet_trip.shared` / `take_shared` (main's sync "hamlet", merged forwards), `town_trip._coop_hold_hamlet` |
| Testing the town and the bus | the title screen's secret page (L) "Bus to Liblice" (`main._start_test_bus`: a fresh camp, the camp stop as the 13:50 comes); played through for screenshots by `res://tools/bus_tour.tscn -- --out=<dir>`; Liblice alone `res://tools/lesna_tour.tscn` |
| Testing the businesses' work | the title screen's secret page (L) "Businesses" (`main._start_test_businesses`: a fresh camp at 10:30 with the corn stand, the pub, the bistro and the Jednota on paths up from the gate, tents and cabins full of guests made hungry and thirsty by `GuestManager.debug_want_food`, every blueprint open) |
| The camp computer (the panel: tabs and their keys, badges, boot, covers, one-click installs) | `scripts/os98/os_shell.gd` (`TABS`, `PROGRAMS`, `HOST`), a program's place `os_page.gd`, look: `os_theme.gd` |
| The second monitor (PC Servis's page, the post van, the postman, the slip; the two screens) | the order and its stages `scripts/reception/post_delivery.gd` (kept in the PC's store "post", so saved and sent with the PC both ways; only `Coop.sim_here()` moves it on by the clock; the van and the man drawn on every machine from the stage and its `t0`; the man across the counter is its `_desk_man` + the extras' hot "postman" -> `building_interior.dressing_click`), the slip `scripts/closeup/post_closeup.gd` (SIGN_BOX, PARCEL_BOX in picture px), the page `pc-servis-hlubocany.cz` in `web_pages.gd` (found only from the bazaar's foot or the search) with `{{pcservis}}` and `order://monitor2` in `browser_app.gd`; the monitor itself `building_interior.set_second_monitor` / `_build_second_monitor` (MON2_PIVOT, the radio moved on top `_place_radio`), A/D at the PC `_crt_turn` / `_look_screen()`; the second screen in `os_shell.gd` (`set_dual`, `_select_tab_on`, `screen_origin`, `keys_for`; `scripts/os98/os_keys.gd` for the programs); art `tools/artgen/prompts_post.tsv` -> `post_art.py`, sounds `tools/audiogen/prompts_post.tsv` |
| The reception's windows from the camp (the real office behind the glass) | `building_interior._update_inview` (a camera in the office's own world at the camp's eye, through `ReceptionLayout.room_to_local` and the panes' parent node; live within `INVIEW_RANGE` with a pane turned to you; the room's light kept to the camp's hour while shut; the curtains go on moving `reception_extras.tick_unseen`), the panes' shader `materials/window_into.gdshader` (SCREEN_UV, `live`, `glow` the dark fallback, `bright` by the hour), the other wardens inside seen from outside `interior_manager._coop_office_from_camp` with the same placing as inside `_place_office_fig` |
| Its programs (CampMail, Beeternet, CampStat, GuestRack, Files, Shops…) | `scripts/os98/apps/*_app.gd`; Builder map: `builder_module.gd` (toolbar, keys, the building card) + `crt_map_panel.gd` (overlays `set_overlay`, `structure_at`, `building_clicked`); upgrades from the map `interior_manager.map_upgrade`, the crew to one building `main.request_maintenance_crew_at` |
| Jobs and Games (the program folders) | `scripts/os98/apps/program_shelf.gd` (Web View folder pane) with `jobs_app.gd` (`datapunch_app`, `job_adclick`, `job_census`; pay through `shell.earn`, day limits `shell.job_done`) and `games_app.gd` (`mines_app`, `game_mosquito`, `game_hike`, `game_pexeso`; tables `shell.scores`, seeds `SCORE_SEEDS`, drawn by `score_board.gd`); icons `tools/artgen/panel_icons.py` |
| Web pages, the files on its disk | `scripts/os98/web_pages.gd`, `scripts/os98/os_files.gd` |
| Electricity | `scripts/electricity_billing.gd` |
| Save format helpers | `scripts/save_codec.gd`; snapshot build/apply in `main.gd` |
| Player movement, flashlight battery, stamina | `scripts/player_controller.gd` |
| Bookings, arrivals, the barrier, room states | `scripts/guest_manager.gd`, rules `core/systems/room_rules.gd` |
| The gatehouse, barrier, road | `scripts/camp_gate.gd` (built by world_generator) |
| Room tasks in interiors (hover, hold, checklist) | `scripts/interior_tasks.gd` + `scripts/interior_prep.gd`; what the mess is: `core/systems/mess_rules.gd`; toilet/shower blocks: `service_interior.gd` `set_upkeep_target` |
| Generated sound effects | `tools/audiogen/` (ElevenLabs; key in the gitignored `.env`); then `python tools/audiogen/normalize.py 'assets/sfx/<dir>/*.mp3'` to bring them to -23 LUFS (each comes back as loud as it likes: one clipping, the next inaudible), and set the loudness in the code; sounds with an exact timing (the phone's cadences and keys, the station's pips, the set's tone) are cut from recordings in `tools/audiogen/raw/` by `tools/audiogen/cuts.py`; a music loop: `python tools/audiogen/loop_cut.py <clip> <dest.ogg> [bars]` (whole bars from the first strong beat, the end cross-faded, -23 LUFS, OGG: MP3's encoder gap would click at every repeat) |
| Night jobs, the distribution board | `scripts/night_jobs.gd`, `scripts/breaker_panel.gd` |
| Day events, camp life sounds | `scripts/day_events.gd` (sounds in `assets/sfx/life/`) |
| The camp's sounds where they come from; life far off; footsteps | `scripts/ambient/world_sounds.gd` (lamps, the generator, the lake, the frogs, the trees in the wind, the flagpole's rope, the washrooms' tube and tap), `scripts/ambient/far_life.gd` (voices at the fire, children, a dog, a car, a train, the village bell; on the NightInsects bus), footsteps in `player_controller._surface_under` (`assets/sfx/steps/<surface>_a..d.mp3`); rows in `tools/audiogen/prompts_world.tsv`; `tools/world_check.tscn` checks they load |
| Head turning inside interiors | `scripts/interior_look.gd` (limits set per interior script) |
| Insects falling silent, the HUD face's glance | `scripts/threat_senses.gd` (reads `get_presence()`) |
| Story mails (Vera, Nela, the odd ones) | `data/pools/emails/story/week01_story.json` |
| The radio (playlist, outdoor source, the station) | `scripts/building_interior.gd`; the station that does not exist is recorded (`un_*` rows in `tools/audiogen/prompts_world.tsv`, its pips cut by `tools/audiogen/cuts.py`); songs in `assets/sfx/radio/` (8 kHz 32 kbps, a `night` prefix = night only; originals `ost/<name>_hq.mp3`) |
| The radio going wrong with the night (layers, song bus, broadcasts) | `scripts/radio/radio_dread.gd`; sounds `tools/audiogen/radio_lines.tsv` → `radio_fetch.py` → `tools/gen_radio_dread.py` → `assets/sfx/radio_dread/`; listen: `tools/radio_dread_demo.gd` with `--write-movie` |
| The office: phone, noticeboard, back room, sleep | `scripts/reception/` (reception_extras, back_room, sleep_sequence, camp_office, electrician_visit); the back room's door by hand `reception_extras._swing_back_door`, shut over the night in `_try_sleep`'s `fast_forward`; when beds take a click `camp_office.bedtime()` |
| 2D close-ups (phone, noticeboard, logbook) | `scripts/closeup/closeup_view.gd` + subclasses; who answers the phone: `phone_book.gd`; voices `tools/audiogen/tts.py` + `voices.tsv` (needs a key with text_to_speech) |
| The cursor and the hover glint | `scripts/ui/hand_cursor.gd` (`HandCursor.want(kind)` per frame), `scripts/ui/hover_glint.gd` |
| The thing in the pipes, its staging | `scripts/pipes/pipe_director.gd` (the minigame keeps the network, movement, map, clamp) |
| The night's director (tension, events, log) | `scripts/night/night_director.gd` (pure logic, `tools/director_check.gd`), effects `scripts/night/director_effects.gd`, context `main._director_context()`; sounds `assets/sfx/director/`; F10 panel (debug builds) |
| The reception's plan (office, back room, building, windows) | `scripts/reception/reception_layout.gd`; the building `building_models.reception()`; curtains `scripts/reception/curtain.gd` |
| Builder construction effects | `scripts/builder_fx.gd` (wave, local grid, outlines, ripples); lamp spot on paths `scripts/lamp_spot.gd`; building sites and rubble in `crt_map_panel.gd` (`_start_site`, `_tick_sites`, `_draw_site`, `_leave_rubble`; `_known` = what the static layer last drew), rows by dragging (`ROW_TYPES`, `_update_row`, `_end_row`); coins, the odometer, the music and the tool on the pointer in `builder_module.gd` (`_launch_coins`, `_draw_odo`, `_tick_music`, `cursor_texture` -> `os_shell.tool_cursor`); the sprites from `tools/artgen/web_review_art.py`; `scripts/builder/`: `day_graph.gd` (main's `_day_graph`, recorded at dawn) and `graphs_window.gd`, `shareware.gd` (the nag, the key, the cheats; the PC's store "builder98"), `courier_news.gd` + `news_paper.gd` (extra editions, diplomas; the PC's store "courier"), `about_dozer.gd`; the Mega gnome `data/buildings/mega_gnome.tres` + `building_models._mega_gnome` |
| Builder's pictures of the buildings (four views each) | drawn from the 3D models: `godot/tools/iso_render.tscn -- --out=<repo>/tools/artgen/out/iso3d [--only=pub]` (each built alone on its own render layer, an orthographic camera from the map's four corners at 30 degrees, 128 px across a tile, light from the camera's upper left; also each lodging's lit windows alone, `_win`), then `python tools/artgen/iso_views.py sheet <type>` (2x2 sheet for Grok, rows `iso4_<type>_a/_b` from `tools/artgen/builder_prompts.py` in `prompts_builder.tsv`; small things four to a sheet: `sheet4`/`cut4`) and `iso_views.py cut iso4_<type>_b <type>` (or `raw <type>`: the render itself) -> `assets/textury/builder/iso3d/<type>_<s>.png` + `views.json` (the anchor: the footprint's middle); the map draws `<type>_<(view + turn) % 4>` (`crt_map_panel._view_of`, `_draw_view`); look at it with `godot/tools/builder_shots.tscn` (the map in four views beside the camp from the same corners) |
| The map's turning, its people, its message line, its sound | `crt_map_panel.gd`: `view_rot`/`rotate_view` (builder_module `turn_view`, T, the PC's store "builder_view"), the guests (`_update_guests` from `guest_agents.get_visible_guest_positions`: each member, its pose picture, its way; `_peep_frame`, `PEEP_KIND`, faces `REACTS`, `_draw_sleepers`), `sound_under_pointer`; lit windows `_draw_lit_windows` (`window_lights.lit_state`); `scripts/builder/ticker.gd` (the message line and its corner window, EventBus + GuestManager); Builder's clicks `builder_module._ui(id)` (`assets/sfx/builder/ui_*.mp3`, rows in `tools/audiogen/prompts_builder.tsv`); the guests behind buildings `_occ`/`_draw_occluders`; the small life `scripts/builder/map_life.gd` (frames `builder/life/<thing>_<n>.png`); the site's stages, the bulldozer and its dust `builder/site/stage_<0-2>.png`, `dozer_<0-7>.png`, `dust_<0-3>.png` (`_draw_site`, `_draw_dozers`); the trees in the wind `tree_sway_*` (`_swaying`); the moving tool cursors `builder_module.CURSOR_FRAMES` (`builder/cursors/`) |
| Builder's hidden 3D view (the status bar's corner grip) | `scripts/builder/map3d.gd` (made by `builder_module._build_ui`, toggled by `toggle_3d`, the grip `_build_grip`/`_draw_grip`, remembered as the PC's store "builder_3d"): its own SubViewport into the camp's World3D (`building_manager.get_world_3d()`), the camera, the way in/out (`enter`, `leave`, `_pose`), the plates (one MultiMesh, `materials/builder3d_plate.gdshader`), the ghost (`_ghost_model`: a building's model from `building_models.gd` built off the tree and copied to meshes only, `materials/builder3d_ghost.gdshader`), the paper over it (tags, pops, thoughts, badges, compass, minimap); the view through the palette `materials/builder3d_view.gdshader`. The map panel asks it through `map3d` (`_in_3d()`: `_local_to_grid`, `cell_screen_point`, `guest_at`, `follow_guest`, `debug_center_on`, `_minimap_click`, `apply_zoom_step`, the pan, the arrows; `take_input` first); `set_3d_layers`, `match_view` for the way out. Shots: `shot_driver` scenario `builder3d` |
| Path tiles (joined from the eight neighbours, the camp and the 2D map alike) | `scripts/path_tiles.gd` (`mask_at`, `texture`); the fill `assets/textury/redneck/paths/gravel_fill.png` from `python tools/artgen/path_fill.py`; the camp `building_manager._refresh_path_visual_at` (all eight neighbours refreshed), the map `crt_map_panel._draw_path`. Shots: `shot_driver` scenario `pathyard`. OSM roads stop at the camp's fence (`geo_world._outside`) |
| The god cursor over the camp | `scripts/god/god_cursor.gd` (main `_god_cursor`, made with the guest agents; `from_peer` set by main around co-op builds; `debug_force` for tools; `finish_all()` from `_leave_everything`); guests jump aside `guest_agents.dodge`, the view shakes `player_controller.ground_shake`; sounds `assets/sfx/god/`; look: `godot/tools/god_shots.tscn -- --out=<dir> [--part=day|fog|dusk|window]` |
| Toilet scrubbing | `scripts/scrub_minigame.gd` (opened by `interior_tasks.gd` for tasks with `scrub`) |
| Toilets and showers getting dirty, their stink | `maintenance_rules.gd` `SOILED_BY_USE`, `STINK_FROM`, `FILTHY`; `actions.soil_building` (GuestManager's "visit" event, the host's); the fumes and flies `scripts/stink_fx.gd`, set by `maintenance_controller._sync_stink` (keeps their dirt out of `_clear_old_wear`); art `tools/gen_stink_sprites.py`; look: `res://tools/stink_shots.tscn -- --out=<dir>` |
| Night work programs | `scripts/os98/apps/datapunch_app.gd`; guest book replies `EmailManager.reply_to_review` |
| The lost and found, the bazaar | `scripts/bazaar.gd` (pure, `tools/bazaar_check.gd`); main `_on_guest_state_for_bazaar` / `_settle_bazaar`; page `bazar-hlubocany.cz` in `web_pages.gd`, `{{bazaar}}` and `bazaar://list/ID` in `browser_app.gd` |
| The generator shed (junk, switch room) | `scripts/shed/generator_shed.gd`; the board's close-up `scripts/breaker_panel.gd` |
| The lake trip, far shore, fishing | `scripts/lake/lake_trip.gd`, far shore in `scripts/camp_lake.gd`, logbook `scripts/lake/logbook_closeup.gd` |
| Corn tiles in the camp | `scripts/world_generator.gd` (`_corn_band`, `_create_corn_patch`), Builder icon in `crt_map_panel.gd` |
| Web pictures | `{{img:name:w}}` in `scripts/os98/web_pages.gd`, files from `tools/artgen/web_image.py` |
| Guests at the campfire, on the slide, on the court | `scripts/attractions/campfire.gd`, `slide_ride.gd`, `pitch_play.gd` (group "attraction": `covers_tile`, `pose_member`; guest_agents hands them the visiting party); the models in `building_models._bonfire/_slide/_sports` (the slide's line and the court's size are metas) |
| Guests in the pub, bistro, Jednota; counter minigames | `scripts/food/service_life.gd` (seats from `service_interior._start_life`; the Jednota's queue along its till: `queue_spots`, `_queue_tick`), shared `orders.gd` (visits kept past their time: `set_holds`); a counter close-up would be opened by the `CounterGameSpot` body in `service_interior._build_counter_game` (none now: every place's work is a station) |
| The corn stand (its two stations in the camp) | `scripts/corn/`: the view behind the counter `stand_view.gd` (a camera of its own in the camp world, the frame, the input; opened by `interior_manager._on_corn_stand_interact`, its `coop_room`), the stations on the stand's counter `stand_layout.gd` (SURFACES in the stand's own space; made by `business/corn_stand_life.gd make_stations`), `corn_station.gd` + `counter_station.gd`, `husk_station.gd` on `business/station3d.gd`, the stands' state and their co-op ops `cornstand.gd` (`Coop.send_place("corn", ...)`, the node in group `places_corn`), the rules `core/systems/corn_rules.gd`; art rows `ct_counter`, `ct_husk`, `cts_corn` in `tools/artgen/prompts_pubcorn.tsv` -> `pub_art.py`; shots `tools/stand_shots.tscn`, co-op `python godot/tools/stand_coop.py` |
| The Jednota (rooms, stations, the shop for four) | `scripts/jednota/`: the rooms `jednota_layout.gd` (STATIONS, SURFACES: the till on its counter, the rack and the trolley as one wall, the packing table; QUEUE, BROWSE: where the guests stand), the shop's state and its co-op ops `jednota.gd` (`Coop.send_place("vecerka", ...)`, group `places_vecerka`; the queue `tickets`, `serve`, `make_box`, `shelve`, the hands `_crew_work`, the visits kept `_holds`), the stations `jednota_station.gd` + `till_station.gd`, `shelves_station.gd`, `store_station.gd` on `business/station3d.gd`, the rules `core/systems/jednota_rules.gd` (PLANOGRAM, baskets, change, `day_model`); the model `building_models._jednota`; art `tools/artgen/jednota_prompts.py` -> `jednota_art.py`, sounds `tools/audiogen/prompts_jednota.tsv`; shots `tools/jednota_shots.tscn`, co-op `python godot/tools/jednota_coop.py` |
| The pub (rooms, stations, the bar for four) | `scripts/pub/`: the rooms `pub_layout.gd` (STATIONS, SURFACES: the bar's three stations along its top, the keg in the cellar; the bar model's tower hidden), the bar's state and its co-op ops `taproom.gd` (made by `business_runtime`, `Coop.send_taproom`; the hands by role `_crew_work`, flat kegs, `waste_keg`), the rules `core/systems/pub_rules.gd`, the stations `pub_station.gd` + `tap/back/wash/keg_station.gd` on `scripts/business/station3d.gd` (opened through `service_interior._station_layout()/_station_scripts()`), the marks `pub_marks.gd`; art `tools/artgen/pub_art.py` (rows in `prompts_pubcorn.tsv`: the glassware drawn plain for 16 px, the tap tower); shots `tools/pub_shots.tscn`, co-op `python godot/tools/pub_coop.py` |
| PROTOTYP 540 (the bistro cellar's machine) | the rules `core/systems/bistro_rules.gd` (`PROTO_MEAT`, `proto_awake`, `proto_night`, `proto_sack`), its state in `scripts/bistro/kitchen.gd` (`proto` in the site record and the kitchen's save, op "proto", the host's `_proto` once a second, `_on_guest_state`: a departure at dawn marks the night), the station `scripts/bistro/machine_station.gd` (the sack, the lift, running, the meat), the stock `actions.biz_gift`; harness `tools/proto_check.tscn`, shots `tools/proto_shots.tscn`. What the sack holds is never said anywhere in the game: keep it so |
| The bistro (rooms, stations, tickets, the kitchen for four) | `scripts/bistro/`: the rooms `bistro_layout.gd` (STATIONS: click boxes, where a warden stands, marks), the kitchen's state and its co-op ops `kitchen.gd` (`Coop.send_kitchen`), the rules and timings `core/systems/bistro_rules.gd`, the stations in the room `bistro_station.gd` + `*_station.gd` on the shared 3D base `scripts/business/station3d.gd` (sprites at the room's pixel `sprite()`/`room_tex()`, the pointer cast onto the counter `point()`, `held_at()`, meters, pops; the order rail `ticket_rail.gd`, the frame `station_hud.gd`; opened by `service_interior._open_station`, the camera in steps `station3d.step_camera`), the room marks `bistro_marks.gd`, the sentence under the room `room_sentence.gd`; art `tools/artgen/bistro_prompts.py` -> `gen.sh` -> `bistro_art.py`, sounds `tools/audiogen/prompts_bistro.tsv`; shots `tools/bistro_shots.tscn`, co-op `python godot/tools/bistro_coop.py` |
| The businesses' polish (DESIGN §7b "The businesses' polish") | the hand at a station `scripts/business/station_hands.gd` (TOOLS: tool -> rest/act pictures `hands_lo/st_*.png`; a station answers `hand_tool()`; `flash(tool, ticks)` for something done in passing), Papa's slip `station_hud.serve_card` (stations call `score_card(v, what)`), the eye pointer `HandCursor.LOOK` (rooms: `bistro_look` things), thirst and the Jednota's bag `guest_needs_system` (`NEED_THIRST`, `HOME_WATER`, `STASH_FROM`, `use_stash`, `RUSH_SEEK`; the bag used in `guest_life._advance_guest`, filled in `_on_complete`), the Z mark `business_rules.day_grade` (+ `unit_cost`: the goods' cost in `actions.biz_take`), the hands' temper `business_runtime.hand_mood`; the corn drinks `scripts/corn/drinks_station.gd` (+ `corn_rules.DRINKS`, `judge_drink`, `cornstand.serve_drink`), the pub's tab `scripts/pub/bill_spot.gd` on the tap (+ `pub_rules` TAB, `bill_for`, `taproom.bills/settle`, the holds "pub") and fun `core/systems/pub_fun.gd` + `slot/darts/cards_station.gd` (`taproom.fun`, `_guests_play`), the bistro's `grill_station.gd`, `bufet_station.gd` (+ `kitchen` grill, soup, `tickets(key, "pass"/"bufet")`), the Jednota's `deli_station.gd` (+ `jednota` deli, cut, parcel; `jednota_rules.DELI`, `BEHIND`); art `tools/artgen/podniky_prompts.py` -> `prompts_podniky.tsv` -> `podniky_art.py` (PICK the variant), sounds `tools/audiogen/prompts_podniky.tsv` |
| The businesses' Papa's frame (2026-10-21: the same in all four places) | `scripts/business/station_hud.gd` (the frame: tabs `tabs` [[id, LABEL, icon]], `alert_of`, SERVE, BOOKS, the mark, the clock, `serve_pop`, the hint and the ghost glove, `key_action`), `station3d.gd` (`draw_ticket`/`draw_big_ticket` the same everywhere from `ticket_items`/`checklist`; `serve_ready`/`serve_now`, `next_hint`, `alert`, `guest_point`, `fly`, `hop`, `score_card(v, what, t)` with the run; `last_station`), `guest_face.gd`, `guest_mood.gd` (bubbles over heads: the stand's `corn_stand_life._moods`, the rooms' `service_interior._tick_moods`), `ticket_rail.gd`; the rooms: `service_interior._room_tabs` (every room's stations, the layouts' `ENTRY`, `tab`, `icon`, `menu`), `_enter_business`; the menu `business_rules.MENU`/`menu_on` + `actions.biz_set_menu` (the books' MENU page); last orders `business_rules.last_orders_at`, `business_runtime.takes_orders_at`/`to_last_orders`/`last_call`, `guest_life.order_hours`; the run `business_runtime.note_order`, `business_rules.combo_bonus`/`shift_mark`; the bistro's floor `scripts/bistro/floor_station.gd` + `kitchen` `hatch`/`to_hatch`/`serve_hatch`, the prepared goods `kitchen._prepared`; Options "Work hints" `profiles.profile_hints` |
| The businesses' shared systems (ratings, lots and going off, gear, the hands, open late) | numbers and people `core/systems/business_rules.gd` (KINDS goods with `life`, GEAR, ROLES, PEOPLE, `applicants`, `score`/`reward`); the books' writes `actions.biz_*` (`biz_spoil`, `biz_bin`, `biz_buy_gear`, `biz_hire(key, person, day)`, `biz_set_job`, `biz_set_late`, `biz_score`, `biz_close_shift`, `biz_order_all`); the running side `scripts/business/business_runtime.gd` (`shift_now`, `crew_now`, attendance, theft, the strange ones, the Z report signal, `price_k`, `debug_hire`); the hands in the rooms `crew_figures.gd`; the night inside a place open late `late_night.gd`; the books on the counter `ledger_closeup.gd` (STOCK, ORDER, STAFF, GEAR, BOOKS), the receipt `zreport_closeup.gd`, the PC's SoftSklad `scripts/os98/apps/business_app.gd`; art `tools/artgen/biz_prompts.py` -> `prompts_biz.tsv` -> `biz_art.py` |
| Doors opening for guests | `scripts/attractions/door_anim.gd` (finds Door/DoorLeaf boxes, hinges them) |
| Windows that look out (a real view of the camp from where the building stands, curtains to draw), the flash through them | `scripts/ui/window_portal.gd` (`make`, `room_to_world`: the room laid over the building's box); used by `service_interior._make_windows` (a layout's painted `window_view` picture becomes a real window), `caravan_interior`, the cabins' own portals (curtains added) and the reception's; every room answers `photo_windows()` (InteriorManager collects it), curtains go to the other wardens with `Coop.send_curtains` |
| The Photographer | `scripts/enemies/tourist_brain.gd` (poses `npc/tourist_*.png` from `tools/artgen/photographer_prompts.py`, made from `npc/host2.png`; sounds `ph_*` in `tools/audiogen/prompts_photographer.tsv`); shots `tools/photographer_shots.tscn` |
| The torch | outdoors `player_controller._aim_beam` + `scripts/ui/torch_hand.gd`; in rooms `scripts/ui/interior_torch.gd` (each interior's `room_is_dark()`) |
| Your hands (who holds what, their pixel size, their light, how they sway) | `scripts/ui/hands.gd` (`Hands.of(node)`: `claim/release(hand, who)`, `torch_hand()`, `light`, `motion`, `px(h)`); the coarse hand sprites `assets/textury/hands_lo/` (`tools/artgen/hands_lo.py` halves the old ones, new ones are processed straight to it) |
| How you move and look (DESIGN §9c) | `scripts/player_controller.gd`: speeds and the ground's quickness (`ground_acceleration`, `ground_deceleration`, `air_*`), the bob by the ground covered (`stride_*`, `bob_*`, `_after_physics` counts the steps, `foot_fell`), the head drawn between physics steps (`_update_head_motion` in `_process`), the look's limits (`look_limits()`: up stops short of the zenith) and Build's shift (`build_shift_degrees`, `_apply_projection`: a frustum offset), where you really look `look_basis()`, crouch and crawl (`stance`, `set_stance`, `STANCE_*`, Ctrl, `move_crouch`), the warden's Options `view` (`profiles.profile_body`: fov, mouse_x, mouse_y, bob, lean, crouch_toggle; the Options page's "View and body" section in `retro_menu.OptionsPage`); measured and pictured by `tools/move_shots.tscn -- --out=<dir> --part=measure|shots|body` |
| Your own body seen (boots looking down, the crawl's hands, your shadow) | `scripts/ui/body_view.gd` (art `hands_lo/feet_*.png`, rows `body_*` in `tools/artgen/prompts_body.tsv`) |
| The world answering the body (grass parting, rustle, a branch, leaves, birds, ducks, splashes, wet and muddy prints, guests bumped, the other wardens' doors) | `scripts/ambient/body_world.gd` (the shader globals `body_0..3` in project.godot, read by `materials/ground_tuft.gdshader`, which the forest floor's soft plants use too: `forest_floor.SOFT`); wading at the lake `camp_lake.WADE`, `in_water`, `duck_spots` |
| Picking up, carrying, throwing; the sack to the dumpsters | `scripts/ambient/carry.gd` (its own E and click in `_input`, the hint through `main._update_interaction_hint`), the things themselves `nudge_props.gd` (`props_near`, `take_prop`, `put_prop`, `throw_prop`, `add_loose`, `_landed`: the night hook group "night_ears"), the sack `day_events._sack_to_carry` / `sack_binned`; co-op `Coop.send_body` |
| Work by a gesture of the mouse | `scripts/ui/gesture.gd` (`kind_for(verb)`, `feed`, `strokes_for(seconds)`, `ghost_offset`; `auto` for tools), `work_hand.gesture_offset` / `ghost_kind` / `stroke()`; used by `interior_tasks.gd` (rooms), `maintenance_controller._update_work` (R) and `day_events._update_target` (E), the look held by `player.lock_look(who, on)` |
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
- **The camp computer is a panel, not a desktop** (playtest 19. 10.): one program on the
  screen at a time, all kept running; tabs by keys 1-9 (read by `physical_keycode`, a
  Czech keyboard types +ěšč on that row). A program's own keys must not use the digits,
  S (stands you up), A or D (they turn you between the monitors): Builder pans with the arrows, its tools are B/P/L,
  its catalogues F1-F5, O the overlay. A method called `hidden()` clashes with
  CanvasItem's signal: the panel calls `page_hidden()` / `shown()`.
- **The OS's own words are a real 1998 system's**: it never addresses the player, jokes
  about the story or knows Vera ("do not tell Vera" was rejected). The lore goes in the
  data: file dates and contents, the games' high-score names, the mails, the web, the
  programs' publishers' texts.
- **Message boxes are modal**: a catcher under them rings and flashes the dialog on a click
  elsewhere; while one is up the tab keys do nothing (`has_dialog()`).
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
- **The OS boot takes ~7 s** (warm-up, BIOS, maker's screen, Okna; a key or click hurries
  each): harness waits must be longer than that, and a test that skips itself when an app
  does not open must fail.
- **The first scene is the studio splash** (`scenes/studio_splash.tscn`), not main.tscn:
  it loads main.tscn on a thread and changes to it (headless runs skip it at once). The
  engine boot image `assets/boot/undo_labs_boot.png` is its first frame: re-bake it
  (`tools/studio_splash_bake.gd -- --boot`) after changing the sign, wall or shader.
- **Machinery moves in steps, twelve a second; rooms move smoothly** (playtest 18. 10.:
  the stepped room cameras were "choppy"). The fire, the torch hand, the gate go through
  `Step12` (the step bob is smooth since 21. 10.: the camera never steps) (scripts/ui/step12.gd); camera moves in rooms, the door
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
- **Co-op scares are the quarry's alone** (21. 10.: "the other must not glimpse it"):
  - while a brain's `is_private_now()` says so (the strike, right behind them, at their
    window, close), `coop_night._is_private` hides it on every machine but its quarry's
    (the host's root hidden and muted, left out of the others' pictures);
  - what is only ever the quarry's (a decoy pair of eyes, the ring round the lamp, Quiet
    Guy's false glasses) is a child of `_root` with meta `coop_quarry_only`, and a sound
    only they hear is `_sound_quarry`;
  - the quarry's screen is reached through `_fx()`: on the host's own warden it is
    nightmare_fx, on a stand-in it is `scripts/coop/remote_fx.gd`, which sends the same
    calls (`Coop.send_night_fx` → `coop_night.on_fx`, which holds levels and close-ups and
    applies them each frame);
  - never set the camera or the player directly in a scare: `_view_begin`, `_set_yaw`,
    `_set_pitch`, `_set_roll`, `_view_end`, `_move_player`, `_play_2d_remote` (a sound in
    their room), `_quarry_indoors` (their room, not the host's). The stand-in forwards
    `flashlight_stutter`, `held_speed_mult` and `set_controls_enabled`;
  - a texture made in code that has to show on the other machine carries meta `fx_src`
    (`scripts/night/fx_tex.gd` makes and remakes it: `flip_head`, the Silent Man's
    `dissolve`); an AtlasTexture travels as is (one that cannot go is left out of the
    picture: on the other machine the sprite is simply gone);
  - an enemy's own thing on their screen goes as `remote_fx.ext(what, args)` → `coop_night._on_ext`
    (the Photographer's polaroid is taken there, of them: `polaroid.take_of`; his flash through
    their window). Their health is their warden state `hp` (`_player_health()` reads it, so a
    kill is played on the right one); their room's windows at night are `pw` (where, which
    way, the curtain, how squarely they look at it), `tools/coop_photo.py` checks it;
  - `tools/coop_scare.py` checks it: a strike on either warden is on their screen and
    nowhere on the other's; `tools/coop_quiet.py` the Silent Man (his catch, the hold at
    the neck, coming apart in their light, his neck round a corner: theirs alone; his
    catch on the host not on the other's). A scare made for where the quarry stands (the
    neck round a corner) is private too: from anywhere else it reads as a prop.
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
- **Co-op bus** (`bus_ride.gd`, `town_trip.gd`): each machine runs its own ride, but
  the one with the lowest peer id on that bus leads (`_leader_state`): the others follow
  its distance and its life clock ("tr", "rt": `_follow`), go when it goes
  (`_leader_went`), take STOP from anyone (`_merge_stops`, "sa"/"sw") and seat Vacek where
  it did ("bs"); checked with two copies on one machine (the same line, the same second).
  The warden state's `bus` ({st, s, go, ...}: stop, seat, under way) is what the other sees. A
  partner aboard and not gone turns that stop's bus into a "hold" special
  (`_coop_hold`); seated, the ride sits in HELD till `_mate_ready`. When the bus goes with
  one alone, the other's stop gets a "drop" and `_coop_gone` keeps that run off it. The
  passengers are seeded (stop, day, half-hour) so both rides match, and so is what they do
  (`_life_rng`, timed from the doors shutting: both buses go together); a seated figure
  needs a `*_sit.png` beside its sprite (wardens: the "sit" pose in `warden_looks.gd`).
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
- **The villages are in the same world, at their real places** (`scripts/geo/`, built on
  the first trip or when you walk out; Liblice's stop 2.9 km north-east by road, Pristoupim
  2 km east): the sun, sky, fog and weather are the camp's. `town_trip.away()` (more than
  420 m from the camp) makes main keep the night off (`_away_in_town`: no enemy actions,
  director place "away"). The bus ride is in that world too: the ride's SubViewport shares
  the main World3D (`own_world_3d = false`) and the main viewport is set to
  `UPDATE_DISABLED` while it is open; its cabin is on render layer 2 with its own fill
  light; the sun lights only layer 1.
- **Trees on the map**: spruce, birch and linden (`world_generator._tree_mesh`: `linden_trunk`, `linden_crown`, `linden_cards`, `LINDEN_BLOBS`); the broadleaves, alleys, single trees and fruit trees are lindens at their scales (`geo_world._trees`); birch and linden get leaf cards round their lumps within 420 m (`_multimesh`), or they read as balls.
- **Co-op on the bus**: the ride's state carries the bus's place (`bus_ride.coop_state` "bt", "v", "d"); the other machine shows it as `town_trip._mate_bus` (eased between the 15 Hz states, taking over from the stop's bus that pulled away with them). `town_trip.debug_mate` feeds it a state for screenshots.
- **Rebuilding the map data**: `python -I tools/geo/build_world.py` (OSM in
  `tools/geo/osm/area.json`). The Overpass export repeats an element without its tags: keep
  the tagged copy. The route is Dijkstra between `ROUTE_VIA` nodes; check
  `route_len` and the stops' `s` in the output after a change, and the times in
  `bus_timetable.gd` (13 minutes camp to Liblice, the clock slows during the ride to fit).
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
- **A station's hand** (`scripts/business/station_hands.gd`): made by station3d while a
  station is open, under the frame (layer 95; the stand's view is 94, its books 98). The
  station's member is `_hands_ui` (the stove has its own `_hand`, a sprite). Where a tool
  works is its picture's topmost end (`_tip_of`). Shot drivers move the pointer with
  `station.debug_mouse_to(design px)` (a warped mouse does not always reach the window
  in a test run: `station3d.debug_mouse`, read through `mouse_of`).
- **Grok draws a station's top in perspective** (its front showing, black round it): the
  four corners of the top go in `tools/artgen/podniky_art.py` TEXTURES and the top is
  unwarped to 16:9; then the station's rects are moved onto the picture's things. Pieces
  that touch (a row of cards) are cut in even slices (EVEN_ROWS); things Grok drew beside a
  hand that the station has as its own sprites are cleared (CLEAR); a ring drawn round
  frames the station already has is cut away (INNER_ONLY). Each run of gen.sh may rewrite
  its raw.png a second time (the agent's own retouch): process again when it does.
- **A pub bill lives fifteen game minutes** (`pub_rules.BILL_WAIT`; the clock runs about a
  minute a real second), then it is left on the bar or walked out on. A harness that jumps
  the clock to get one must wait for it (`["until", "<taproom>.bills(key).size() > 0"]`)
  and read it at once, on both machines (`tools/podniky_coop.gd`).
- **Hands are claimed** (`scripts/ui/hands.gd`): anything drawn in the player's hand claims
  "right" or "left" while it is up and releases it when it is down (work > bottle >
  lighter > torch/cigarette). The torch changes hands by itself (the right busy: the left,
  mirrored; both busy: in the pocket, `player_controller.hand_busy` puts its light out).
  A new hand overlay must claim, draw at `Hands.px(view height)` on that pixel grid, take
  `light` as its modulate and add `motion`; never rotate a hand sprite.
- **Frames at 50, physics at 60** (`run/max_fps=50`): anything moved in `_physics_process`
  judders whenever it moves (a double step every fifth frame). The player's head is drawn in
  `_process` between the last two physics positions (`Engine.get_physics_interpolation_fraction`);
  a new camera that follows a physics body must do the same.
- **A body walked with its collisions off** (`collision_mask = 0`: the door walks in
  `interior_manager`) is left alone by the player's physics: main hands the keys back every
  frame no room is open, and with gravity on it sank through the floor while it waited.
- **The camp camera's picture can be shifted** (Build's look up and down is a frustum offset,
  `player_controller._apply_projection`): a camera that copies it must copy `projection`,
  `size` and `frustum_offset` (scaled to its own near), and "where the warden looks" is
  `player.look_basis()` (the camera's -Z is up to 12° off).
- **A new PNG is not there until imported**: `ResourceLoader.exists` is false for a picture
  with no `.import` in a run that is not the editor. Run `godot --headless --path godot --import`
  after adding art, before a shot run.
- **Work goes by gestures** (`scripts/ui/gesture.gd`): a held click or key with no mouse
  movement does nothing. The shot driver sets `GESTURE.auto` (a held press makes strokes by
  itself, ~the old hold's time), so scenarios with `["lmb", true], ["wait", s]` still work; a
  harness that does not extend the shot driver must set it.
- **A close-up hides the hands**: `closeup_view.gd` (and the breaker, scrub, corn stand,
  check-in desk) are in group "closeup"; pockets.gd keeps the hands down while one is
  visible. A new full-screen overlay where your hands are busy joins that group.
- **Builder's building pictures come from the models**: change a model in
  `building_models.gd`/`building_manager.gd` and its four pictures must be drawn again
  (`tools/iso_render.tscn`, then `iso_views.py cut`/`raw`); never mirror one to make
  another side (a mirrored front put the pub's door where the camp has a wall). Bit 19 of
  the render layers is the glass layer (every window in the camp): the render uses bit 18.
  The render turns the retro shader's vertex snap off (`iso_render._unsnap`): at 150 lines
  on its 768 px a thin part (a flagpole's pole, the gnome's coat, a lamp's post) folded to
  nothing from one corner, and Grok repainted the hole.
- **The god cursor hides what it has still to bring down** (`visible` off, the body's
  collision layer 0, a shadow on the ground) until it lands: code that reads a building's
  visibility must expect it; `finish_all()` brings all of it down at once.
- **Builder runs behind the other programs**: its map is `is_visible_in_tree()` while the
  PC shows something else, or nothing (the startup view): "the warden is building now" is
  that and `building_interior.is_crt_view_active()` (`god_cursor._staged`).
- **Python in the Bash tool**: the tool turns a doubled backslash into a single one before
  bash sees it, so an escaped backslash at the end of a line in a heredoc reaches Python as
  a line continuation (the replacement silently changes nothing); write such scripts with
  the Write tool to a .py file instead.
- **Two monitors, one picture** (21. 10.): with the second monitor the CRT viewport is two
  screens wide (1280 x 480); the shell stays a 640 x 480 Control at the left (no
  FULL_RECT: it would stretch) with `clip_contents` off, the second screen's pages sit at
  x 640, and each tube's glass shows its half through the shaders' `uv_rect`. Mouse
  positions on the second monitor come in at x 640+ (`_map_mouse_to_crt` adds
  `_look_origin()`); anything that measured the PC by `_crt_viewport.size` must use
  `CRT_RESOLUTION`. Both programs on screen are visible and running: a program that reads
  keys in `_input` must also ask `OS_KEYS.here(self)` (only the screen looked at takes
  keys), message boxes open on the screen looked at (`_make_dialog` adds `screen_origin`).
- **The office's windows render the office** (21. 10.): from the camp the reception's panes
  show the office's own world through a second camera (`_inview_*`). Anything in the office
  that lies over its windows for the inside only (the camp's view, the doorway's view, the
  rain on the glass) is on `INVIEW_HIDE_LAYER` (bit 17) so the camera from outside skips
  it: a new such quad must go there too (`_hide_from_camp`). Office state that should
  show from outside must live in the room while it is shut (it is not `visible` then).

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

- **Generated art** — Grok Imagine through the Cursor agent CLI (`cursor-agent`, logged in
  with `cursor-agent login`; `gen.sh` finds it under `%LOCALAPPDATA%\cursor-agent` or takes
  `CURSOR_AGENT`; the bare `agent` command may be the Grok CLI on some PCs):
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
- **Building fronts and lettering** (Lesna): ask Grok for a flat orthographic elevation on
  magenta (`lib_*` rows), then `python tools/artgen/town_facades.py [id]`; signs are drawn,
  not generated (Grok cannot spell Czech): `python tools/artgen/lettering.py [name]` (Windows
  fonts for now, swap for OFL faces before a public release).
- **Batches**: `tools/artgen/batch.sh <id>...` (textures, 128 px) and
  `tools/artgen/batch_panels.sh <width> <id>...` (posters, views) generate and process one
  after another; never start a second batch while one runs. `crop_goods.py` crops the
  shop-goods renders (Grok puts the row at the bottom of a dark canvas).
- **The night sky and the moon**: `python tools/artgen/night_sky.py` turns the
  `sky_night_stars` render into `godot/assets/textury/skybox/skystars.png` (the clear
  night's panorama: the render mirrored round the sky, the stars taken out and set back
  as sharp pixels, each of the render's pixels 4 x 4 so the sky shader's linear filter
  keeps them hard) and `spr_moon` into `skybox/moon.png` (24 px).
  `python tools/artgen/light_sprites.py` turns a render of light on black (the lamp's
  cone) into a sprite of four warm shade steps for additive drawing, or of mist into four
  steps of see-through white. `night_sky.py dawn golden sunset bluehour` makes the
  morning's and the evening's panoramas (a glow on one side: east at dawn, west at night).
  `python tools/artgen/sky_fine.py` makes the ones the game takes first (`skyf_dawn`,
  `skyf_golden`, `skyf_sunset`, `skyf_blue`, the late `skyf_grey` and `skyf_greyeve`;
  rows in `prompts_sky.tsv`): two renders per sky, the glow side and the other, side by
  side round the sky (no mirror), seams blended, Grok's fuzzy 4-wide blocks taken out
  (down by area, up smooth, 160 colours): the 4 x 4 blow-up read as coarse blocks.
  `python tools/artgen/cloud_sprites.py` cuts the cloud layers' high streaks and low scud
  (`spr_clouds_high`, `spr_clouds_low` in `prompts_sky.tsv`) into `skybox/cloud_hi_*` and
  `cloud_lo_*` with soft edges (`scripts/ambient/cloud_layers.gd` draws them filtered);
  `cloud_sprites.py cover` makes the cloud deck's cover (`tex_cloud_cover`, `_b` in
  `prompts_deck.tsv`: satellite views straight down, brightness = thickness) into
  `skybox/cloud_cover_a/b.png`, tiling, ranked so `coverage` is the share of sky.
  `python tools/artgen/ground_tex.py <id> <dest> [size] [--own]` makes a ground render
  tile (Grok's "seamless" does not) and snaps it to the palette, or with `--own` to 48
  colours of its own (the palette has few mid greens). Agent B's world rows
  (the lit windows, the reception at night, the sky) are in `tools/artgen/prompts_world.tsv`.
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
  Czech letters a font lacks (Silkscreen's č ř ě ď ť ň ů, all of W95FA's carons, its broken
  ý Ý) are put together there from the base letter and a mark (`compose_czech`).
- **Flags** (the WARDEN page's languages): `python tools/gen_flags.py`.
- **No synthesised SFX** (the user: "to nechcem", 20. 10.: replace them all): every sound is a
  recording (ElevenLabs, `tools/audiogen/`); exact timings are cut from recordings
  (`tools/audiogen/cuts.py`: the phone line's 425 Hz tone to its cadences, ring 1 s / 4 s,
  engaged 0.33 / 0.33, keys 0.13 s). The one exception is the radio's dread, layered in
  code on purpose (`tools/gen_radio_dread.py`, `scripts/radio/radio_dread.gd`).
- **Palette LUT**: `tools/gen_palette_lut.py`.

Licensing: most world textures are rips from Redneck Rampage (`assets/textury/redneck/RRTX*`).
Fine for a private prototype, a blocker for any public release; replace them with generated
textures (§7) before shipping.

---

## 8. Languages (English and Czech)

The user, 21. 10.: "the language is the warden's, flags when a warden is made; the whole
game in Czech; from now on everything we make, in English and Czech".

- **How it works**: the code is written in English; `godot/locale/cs.po` (gettext, the
  English text is the msgid) holds the Czech. `scripts/lang.gd` reads it (the file is kept
  as is, `cs.po.import` = keep) and answers every lookup the engine makes: Controls,
  Label3D and RichTextLabel translate their own text, so most code needs no change. The
  lookup also answers an UPPER-CASE copy of a msgid (menus upper-case their rows), a
  formatted one ("3 CAMPS" from the msgid "%d CAMPS": the values carried over, a %s value
  looked up itself), a line wrapped in non-words ("<  Plum  >") and text line by line.
- **The language is the warden's**: `profiles.gd` "lang" ("en"/"cs"), the flags on the
  WARDEN page (a new warden starts on them; the system's language is the default),
  `LANG.apply()` when a warden is chosen. `-- --lang=cs` on the command line overrides it
  (tools, shots: never switch the user's own wardens to test).
- **What you must do in code**:
  - Text drawn with `draw_string` / `draw_multiline_string` is not translated by the
    engine: pass `tr(text)` (in static code `LANG.t(text)`). Translate *before*
    `to_upper()`, padding, measuring or cutting it.
  - Text put together from pieces ("Hello " + name) is never found: write it as one
    format string, `tr("Hello %s") % name`.
  - A count with a noun: `LANG.t_n(n, "%d guest", "%d guests")` (Czech has three forms:
    1, 2-4, 5+), or in the translation `{host|hosté|hostů}` after the number.
  - Czech past tense has a gender: `{g:zemřel|zemřela}` in a translation takes the warden
    figure's (`LANG.FEMININE_FIGURES`: Jana, Bara).
- **New strings**: `python tools/i18n/extract.py` merges the code's strings into cs.po
  (keeps every translation; `--stats`, `--todo [N] [--file part]` for what is left);
  translations go in by `python tools/i18n/fill.py <batch.json>` ({msgid: msgstr},
  `"one||many": [three forms]`; the batches are kept in `tools/i18n/batches/`) or by hand.
  `godot --headless --path godot --script res://tools/lang_check.gd` checks the lookup and
  that every translation keeps its msgid's values. See it: the shot driver with
  `-- --lang=cs` (scenario `menupages`: every title page).
- **Words** (keep them the same everywhere): warden = správce, camp = kemp, guest = host,
  booking = rezervace, sandbox = volná hra, story = příběh, the Builder stays Builder,
  CampMail/CampStat/GuestRack/Goggle and the like keep their names; the player is "ty".
  Money is crowns in Czech (the user, 21. 10.: "KORUNY"): the game counts in dollars
  and `lang.gd` shows "$1,250" as "12 500 Kč" (`CROWNS_PER_DOLLAR` 10) in anything that
  passes through the lookup, and "$%d" in a format string as "%d0 Kč"; drawn text that
  skips tr() can use `LANG.money(text)`. Write money in the code as "$%d" / "$" + digits
  and Czech follows. The tone is the English one's: dry,
  short, a 1998 Czech camp.
- **In Czech the big menu rows are taller** (`retro_menu.MenuList._row_vp`): a capital's
  accent stands four of the big font's pixels above the letters.
- Not done yet: textures with words on them (signs, posters, the web's pictures) and
  recorded voices in English (the phone, the electrician) need Czech versions (Godot's
  locale remaps: `internationalization/locale/translation_remaps`).
