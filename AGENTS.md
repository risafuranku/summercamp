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
godot --headless --path godot --audio-driver Dummy --script res://tools/radio_tiers_check.gd
godot --headless --path godot --audio-driver Dummy res://tools/chase_check.tscn
godot --headless --path godot --audio-driver Dummy --script res://tools/steps_check.gd
godot --headless --path godot --audio-driver Dummy --script res://tools/bus_turn_check.gd
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
godot --headless --path godot --script res://tools/bowling_check.gd   # real ten-pin: the card, the ball's way and back, the deck (pocket, nose, splits)
godot --headless --path godot res://tools/business_check.tscn   # the books: lots, going off, gear, one order, wages
godot --headless --path godot res://tools/staff_check.tscn      # the hands: ways, applicants, shifts, away, theft, the kitchen's crew
godot --headless --path godot res://tools/pub_check.tscn        # the pub: the tap from the books, Papa's serve, flat kegs, the hands, the stations
godot --headless --path godot res://tools/stand_check.tscn      # the corn stand: the pot, the bowl, the orders, Papa's serve, the hands, the stations
godot --headless --path godot res://tools/jednota_check.tscn    # the Jednota: the rack, the queue, the till, boxes, the hands, the stations, it pays
godot --headless --path godot res://tools/proto_check.tscn      # PROTOTYP 540: awake hours, the sack's nights, fed, the meat in the stock
godot --headless --path godot res://tools/podniky_check.tscn    # the businesses' polish: thirst, the Jednota's bag, the rush, corn drinks, the grill, the bufet, the deli, the Z mark
python godot/tools/podniky_coop.py [OUT_DIR] # the four places for two: a drink, a bill, the slot, the grill, the bufet, the deli done on one machine and seen on the other
python godot/tools/coop_check.py [OUT_DIR]   # co-op: two windowed copies (host + client on 127.0.0.1), camps compared; looks, a build, a room's jobs both ways, the boat
python godot/tools/boat_coop.py [OUT_DIR]    # the boat for two: the other rows out (their oars stroke on the host's lake), rides in the host's bow, both ashore apart, back in the bow, both out
python godot/tools/coop_photo.py [OUT_DIR]   # co-op Photographer on the joining warden: the white and their polaroid, the run at their back, at their window, the last picture: theirs alone
godot --headless --path godot res://tools/post_check.tscn      # the second monitor: the order paid, the van on the clock, the postman at the counter, the slip, two screens and the swap, the keys, the save, the postman who gives up
python godot/tools/post_coop.py [OUT_DIR]   # the second monitor for two: ordered on the joining machine (paid once), the host's van and postman on both, signed for there, the monitor on both
python godot/tools/window_coop.py [OUT_DIR] # the reception's windows for two: from outside the joining warden sees the host at the PC, in the back room, the curtain drawn, the lights out
# Playtest 4. 11. checks (windowed, --audio-driver Dummy, -- --out=DIR):
#   res://tools/dvere_check.tscn     every building's door in and out on foot (pictures of the doorway, frame times)
#   res://tools/okna_check.tscn      the cabins'/caravans' windows from afar (the baked room cubes) against the live view; --part=dump|debug
#   res://tools/hlasky_check.tscn    the pager's and feed's lines as the player reads them, "EN" for any still English (-- --lang=cs --lang-audit)
#   res://tools/hover_check.tscn     the reception's glints from behind the counter and from the bench (run alone: it moves the real pointer)
#   res://tools/kukurice_hover.tscn  the corn stand's glints under the pointer
#   res://tools/kroky_check.tscn     the walk's steps: per second, the head's dip, nod and roll
# The polish pass of 4. 11. (evening; windowed, --audio-driver Dummy, -- --out=DIR):
#   res://tools/pruchod_check.tscn   a first day and night as a new warden plays it: a picture at every turn, the worst frame of each stretch
#   res://tools/trhnuti_check.tscn   every frame over 40 ms from a new camp's first frame (script time, pipelines), the autosave's,
#                                    the line's and the land's parts; --part=night: each thing made and seen; --part=nightstart: 20:00 with every kind in
#   res://tools/soak_check.tscn      three days and nights of every kind of guest at a fast clock (--days=N --speed=K): an hourly line; grep SCRIPT ERROR / ERROR:
# Where a frame goes (6. 11.; windowed unless said, --audio-driver Dummy, -- --out=DIR --part=...):
#   res://tools/onesun_check.tscn    vptime: at the PC, in the reception and in the camp, each viewport's time on the processor and
#                                    the graphics card and what it draws ("VP ..."), each node's own _process, biggest first
#                                    ("NODE ..."), the reception's jobs of a frame ("PART ..."). Start here when the game feels slow:
#                                    TIME_PROCESS is the worst frame of the last second, not an average. knockout: each child of
#                                    Main stopped in turn (+-4 ms of noise: a first look at best). hover (headless, the real mouse
#                                    stays put, the mouse is what the game is told): the cursor over the cabin's catalogue and
#                                    switch, on the way out, the tent's way out; cabinswitch: the switch in all three cabins.
#   res://tools/trhnuti_check.tscn   walkout: up from the PC, out and in by the door. firstrooms: tent, cabin, caravan, toilets walked
#                                    into twice, the worst frames, which eyes are open. bizrooms: what a business's room
#                                    costs at its door, cold and warm, and which files it loaded ("TRHNUTI make up", "LOADED").
#   res://tools/smrk_check.tscn      a walk into a spruce: held off at its branches' tips, crouched in under it, eased out standing up; what the branches cut off on the map
#   res://tools/smrt_check.tscn      dead and back: a warden's camp saved, killed, LOAD LAST SAVE straight in (run with its own empty APPDATA: it makes a warden)
# W26 one world (5. 11.; windowed, --audio-driver Dummy, -- --out=DIR --part=...):
#   res://tools/onesun_check.tscn    sweep: the reception by the hour, three views held still; ratio: the sun's square on the counter
#                                    and the back door, with and without the sun (scratchpad patch_stat); out / glass: the reception
#                                    from the camp; rain: 35 s of rain inside; weather; lights (every light near the room); perf (what
#                                    each viewport draws); cabin (--quick: noon only): cabin_1 inside and out;
#                                    recgraze, recwalk: the reception along its walls, roomsgraze (--rooms=pub,cabin_2): the other
#                                    buildings, with their room and without, then python godot/tools/room_diff.py DIR [type_];
#                                    recwin: into its windows by the hour after walking out; rechis: somebody's own last camp;
#                                    recrain: the rain on its glass, a held flash; bizday: the businesses' windows by the hour;
#                                    wedges; unpair (--build=cabin_walk ...: free_lights names the light of the engine's message)
#   res://tools/y_check.tscn         nightlit (--lodge=): a lit lodging from 9 to 70 m; duskpath (--from=18.55): the path at eye
#                                    height, then python tools/dusk_flicker.py and dusk_frames.py DIR (every frame at 18:48);
#                                    callrec, feverrec: for --write-movie (--fixed-fps 30), frame marks in the log
```

- On some PCs the headless run segfaults once the title screen is up (1. 11., at HEAD too:
  the dummy renderer): check the scripts with a windowed shot-driver run instead
  (`--audio-driver Dummy`, a `--steps` file that starts a new game; it also segfaults at
  exit there, after "SHOT DRIVER: done"). `--check-only --script` cannot tell (no autoloads).
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
| The 380 bus (outside, inside, the ride, tickets, the people on board) | How it takes a bend (the user 5. 11.: not about its middle): `bus_line.pose_at` puts its front axle on the lane and its back axle where the front dragged it (`_build_rear`, once along the whole way, the same on every machine; `PULL_IN` straightens it at the kerb of a stop past a bend), `steer_at` the front wheels' angle; `bus_model.set_steer` turns the driver's wheel hand over hand and leans the body out of the bend, twelve steps a second, the ride's cabin with it (`bus_ride._place_rig`, `_cab_wheel`); test `tools/bus_turn_check.gd`. `scripts/town/bus_model.gd` (a Karosa SM 11 in CSAD white and yellow, its faces drawn to the metre by `tools/artgen/karosa.py` (`karosa_*.png`, holes where the door, the windscreen and the wheel arches are; keep its measures and the model's in step); the front door a real opening with jambs and four glazed panels folding in on their hinges (`_build_door`, `_fold`: smoothstep over `DOOR_TIME`, the hiss from `open_door`); see-through windscreen and door glass; inside, for the door and the windscreen, the steps, the yellow pole with the punch, the tan seats and the driver's place), `karosa_cab.gd` (the driver's seat, wheel, dashboard, gear stick and the grey tube after the photo, built the same outside and in the cabin; the driver is Grok's `bus_driver_seated.png` / `_front.png`, no seat painted in), `bus_ride.gd` (its cabin uses the bus's own door leaves and builds the stairwell; `_try_sit` refuses a seat a villager sits on, tours use `first_free_seat`) (line 380 is one bus a round, the whole of its way, put where it is by the game's clock alone (the user, 4. 11.: one real bus in the one world): `scripts/town/bus_line.gd` builds its way end to end (the land's end east of Liblice, Liblice for the camp, Pristoupim, down the camp road round the loop to the shelter, back up, Liblice by the green, out) and works out how it drives each stretch once (`_leg`, the kinematics bus_ride drove with); `state(day, round, abs_hour)` says where a round is, `hold` keeps it at a stop (somebody getting on, or coming at its door: `town_trip._line_keep`), `request` makes it pull in at Pristoupim (STOP, a ticket there, somebody by the pole; else the round's own dice); `town_trip._run_line` draws the rounds near you from a pool of buses built with the land, `bus_at(stop)` is the one standing there; you ride the round's own bus (`bus_ride.line_mode`, fed by `feed_line` every frame: it no longer drives), off at its door where it stands (`_door_out`), and it goes on; the village and Vondra's farm are built as you get on; the clock runs as ever, so the timetable's times after the camp's come from the road (`bus_timetable.RIDE_HOURS` etc., checked by `tools/bus_line_check`); co-op: the host's word on holds and stops (`coop_line`, main's "ln") merged into the other machine's, the other warden seen sat in the round's bus from outside (`_update_rider_figs`); the main viewport stops drawing while you ride; off the bus the cabin leaves the world again (`_cabin_in_world`)); tickets: the stop's yellow machine `ticket_machine.gd` (`trip_ticket_machine` -> its close-up `ticket_machine_closeup.gd` via `town_trip._open_machine`, a `ticket` in the bag; `_buy_ticket` is the instant one for tests), the driver with the surcharge (`bus_ride._buy_from_driver`), the orange validator on the door pole (`_punch` opens `punch_closeup.gd`, its `punched` at the cvak: `ticket` -> `ticket_used`); the riders are villagers `npc/bus_<id>_sit/_back.png` facing the way the bus goes (`_face_passengers`; campers get a back made by `_back_of`), their coughs, conversations and turning round planned by `_plan_life` from the run's seed (co-op: the same on both); old Vacek (`VACEK`, Grok `npc/bus_vacek_sit/_back/_turn/_walk.png`) gets on at Pristoupim now and then by day (`_board_plan` from `_life_rng`; the bus stops for him, `_board_start` walks him in, `_boarder_seat` puts him behind, in front of or across from one of you, his "May I?" and then a story `v1`-`v3`, turned round to you over his shoulder while he talks, `vo` at the end of the line); you change seats mid-ride by clicking a free one (`_move_seat`: WALK_PATH up, down the aisle and into it; others see you in the aisle, "wz"); the driver's lines are his Czech voice by keys (`_driver("d_*")`, `DRIVER_LINES`; outside the bus `town_trip._driver_voice`); the Czech `assets/sfx/bus/talk/` from `tools/audiogen/bus_talk.tsv` (scenes s*, turns t*, Vacek v*, the driver d_*): `<id>.mp3` by `bus_talk.py` (ElevenLabs: the key can only speak, so voices are premade ids tried by hand; Sarah is gone, the woman is Lily) wins over the stand-in `<id>.wav` by `bus_talk_local.ps1`; a line with neither still shows its subtitle; potholes and lorries come by the metre (`_hash01` of the distance), so in co-op they come at once; the works bus passes by the clock in `town_trip._run_works`; the Karosa's sounds `assets/sfx/bus/karosa_*` (rows in `tools/audiogen/prompts.tsv`; `bus_ride._sfx` falls back to the old ride.mp3 when one is missing) |
| The land round the camp (designed by hand, no map data) | `tools/geo/design_world.py` writes `godot/data/geo/world.json`: the 380's route drawn through the user's points (the camp 50.0606589 N 14.8477650 E, the Pristoupim and Liblice stops) as straights joined by arcs (`fillet`), its long stretches half the real ones (the user, 23. 10.); road 12 and the side roads, field tracks, JZD fields laid along road 12's sweep, woods, the brook and its alders, the ponds, the masts and their station, the pylons and village lines, alleys; nothing built along road 12 (the houses are the game's villages); `marks` (road 12's stretch on the route, the village signs) for the code. It prints what stands too near a road; `python tools/geo/preview.py out.png` draws it from above (x east, z south, metres from the camp). The user asked for no OpenStreetMap: do not put map data back in. `scripts/geo/geo_data.gd` (static: the data, the route `at(s, lane)`, `nearest`, `s_near`, `line_path`, `stop_s`, `mark_s`, and the places' names in one place: `CAMP_NAME`, `TOWN`, `HAMLET`, `BROD`, `BEYOND`, `SHOP`); `scripts/geo/geo_world.gd` (ground, fields, roads at once; buildings, trees, poles, fences in 250 m chunks streamed round the eye by `update(eye)`; the Benzina at the camp's turn off road 12, the villages' name signs; it hides the camp generator's horizon hills). `town_trip._ensure_country` builds it and sets Liblice (`town_lesna.ORIGIN/YAW`, `GEO_MODE`) and Pristoupim's poles (`hamlet_podlesi.STOP_ORIGIN/STOP_YAW`) at their real stops, Vondra's farm (`HAMLET_ORIGIN/HAMLET_YAW`) on Liblice's street just past its stop; the camp's own map is untouched. Look at a place with an ad-hoc shot driver: `<town_trip>._geo.build_all_near(p)`, then put the player there. Benches you sit on (`town_bench`, `town_trip._sit`, `player_controller.seated`). Liblice's centre stands `town_trip.LIBLICE_PAST_STOP` past its stop, so `design_world.py` keeps the road straight there (and through Pristoupim's stop); change one, change the other |
| Liblice (the village round its stop: people, the Jednota u Marku, pub, motel, the self-service Benzina, pockets; the scripts keep their old name `town_lesna`) | `scripts/town/town_lesna.gd`, `town_people.gd`, `shop_closeup.gd`, `pub_closeup.gd`, `pockets.gd`; its Benzina: the village's cars fill up themselves (`pump_job.gd` with `self_service`, `spots["station_cars"]`), its pumps fill Vondra's can (`town_trip._fill_can`); all routed by `town_trip.gd` (InteriorManager module `trip`); art `tools/artgen/town_art.py` |
| The Liblice motel (the user, 3. 11.: "the whole block of rooms"; 4. 11.: "it should work like in some RPG") and a night in it | one plan `scripts/town/motel_plan.gd` (seven bays of `BAY` m: the reception in the two west ones downstairs, rooms 1-5 in the rest, 6-12 over all seven, the rooms along the street with their windows on it, the corridor `CORRIDOR_Z` behind them on both floors, a room from its door a little hall, the bathroom off it, the bedroom beyond; `LETS` the four rooms Simek lets and what each costs, `NEVER` six, `beside(n)`/`above(n)` who is next to a room; the rooms taken tonight, six's light, the bell at three and the guest in the car park all from the night's seed, the same on every machine); the block in the village `motel_block.gd` (built by `town_lesna._motel` when its pictures are there: the front cut round every door and window with the rooms' shells behind the glass, built by `motel_rooms.gd` and lit by who is in them; the car park the windows look out on, `_car_park`: sodium lamps, parked cars, the dumpster; the reception door's click `town_door` "motel"; `set_state(hour, night)` rebuilds only the rooms whose look changed), the corridor `motel_hall.gd` (place "motel_hall": both floors, the passage from the reception, the stairs at the east end, every room's door: yours opens, `town_trip.may_enter(n)`, the rest do not; dying lamps, sets behind taken rooms' doors, its windows at the ends),, the rooms you go into `motel_view.gd` in `town_room.gd` (places "motel" and "motel_room", `motel_n` which; `room.go_to(place, n, spot)` from door to door without closing: its windows real views out of the block where it stands (`window_portal.gd`, the room's shell hidden from them); one star (the user, 4. 11.: "like Hotel Hell"): the dirty textures `motel_*_dirty`, grime decals `motel_rooms.decal`, the bowl under the ceiling's drip, a roach now and then; the reception on foot (`_lobby_spots`): a key off the board `key<n>`, once for Simek's line (`trip.key_line`), again to take it (`trip.rent`, sent as "book": the other warden sees it go), the door to the corridor `hall`; every room its own (`motel_furnish.gd` builds two, nine, eleven for the room and for its shell; what they do, one script each with `spots/ways/things/click/tick/woken/set_by_itself/morning/state/take`: `motel_two.gd` the hunters' stove, cuckoo, owl, guns; `motel_nine.gd` the minibar, armchair, radiogram, the tape of the room itself (`tape_on`, layer `ONLY_MIRROR`), `motel_eleven.gd` Mr Hora's notebook (`gbook.gd`), hot plate, aquarium, washing, slippers, suitcase; `view.quirk`, null in four); a radio in each (`motel_radio.gd`, one programme, four voices); as a clicking horror adventure (4. 11.): you walk to what you click (`room_walk.gd`: `_spots()` and `_ways()`, from the bed `FROM_BED` or the room's `from_bed()` is in reach, the rest gets you up first), the key turning twice, the chain, the peephole (`_open_peephole`: a stub of the corridor in the room's own world through a lens shader, `PEEP_SHADER`), the lamps over the beds (the headboard picture cropped west of the bathroom's door, `PLAN.headwall_at`), the switch by the door, the TV's picture laid over its sprite (`_tick_tv`), late at night one more channel, the car park from the pole (`_tv_cam_on`, `CAM_SHADER`), the curtains, the wardrobe opening (`motel_wardrobe_open`), the radiator knocking back, the bedside cabinet with the clock radio (its digits drawn by `seven_seg.gd` in a little viewport over the picture's black window, `_clock_window`; the radio in the morning, `_alarm`) and the telephone (`_phone`: lift, dial tone; ringing: on the line `_on_the_line`, never a voice), the print over the beds (`marks[n]["painting"]`: whoever is by the river comes nearer some mornings, `motel_painting_0..2`; the block's `marks` show it from outside), the bathroom off the little hall (`motel_rooms._bathroom`, `_back`: tiles of the room's colour, the shower's curtain, the toilet, the basin under the mirror cabinet; its light with the fan, the line under its door; the mirror a real one, `_tick_mirror`: a camera across the glass, render layers `ROOMS.BEHIND_MIRROR`/`ONLY_MIRROR`, you in it from `warden_looks`, some nights somebody behind you); the bed: lie down, at night sleep; woken (`woken(kind)`): the event's sounds and sights in `_tick_event`; in the morning what the night left (`morning`); co-op: you see the others walk (`room_mates.gd`, "walk" with the spot, shared with the corridor), asleep in the other bed (`_lay`, `parts["sleeper"]`), out through the door they took (`mate_leaves`); what is switched in a room is switched for both (`_state`, `take_state`, op "room"), and a room stays as you left it tonight (`kept`)), the key and the night in `town_trip.gd` (`rent(n)` from seven: the money, the key into the bag, the spare at the desk for the room a warden has; `_sleep_in_room`: the night passes through `camp_office` and you wake in the bed, black only once the night begins (co-op: whoever lies down first lies there till the other does); `_motel_night`: while the night passes in four the host weighs at each step what wakes you (`motel_night.gd`: `hazard(ctx)` from the hidden sanity, the guest in the car park, six's light, the rain, the hour, the wakes so far; `pick` weighted, never the same twice a night; the bell at three its own), sends it (`Coop.send_place("town", "motel", "wake")` to `coop_town_place`) and stops the night (`camp_office.cancel_sleep`): still the night, so `_room.woken_now(kind)` instead of the morning; in co-op only with every warden asleep in four; `debug_force_wake`/`debug_quiet` for the tools; `left_motel_room`: out of a room after a night the key stays in its door and the room is free; `_update_motel` each second; `_update_watcher` the last guest to leave the camp in the car park some nights, gone once you came near and looked away; six's light out once its door was tried). Simek lives in the reception (`town_people` has him indoors). Art `tools/artgen/prompts_mesto.tsv` -> `mesto_art.py` (the doors' numbers painted on their plates, RECEPCE through `lettering.py`), sounds `tools/audiogen/prompts_mesto.tsv` at -23 LUFS (loops from `tools/audiogen/raw/` by `ambience_loop.py`: `motel/room_night`, `neon_buzz`, `fan_rattle`, `tap_run`, `tap_drip`, `flies`, `neighbour_tv`, `lobby_fan`); somebody's music through the wall at night `motel/wall_music.ogg` (Richard's `nightmotel` from Suno, its top cut off; `motel_view._wall_snd`, `motel_hall._wall_snd`); shots by a steps file (`town_trip._open_room('motel')`, `_room._clicked('key4')`, `_clicked('hall')`, `_clicked('door4')`, `_room.go_to('motel_room', n, '')`, `town_trip.debug_force_wake`), co-op `python godot/tools/motel_coop.py` (the key seen going off the board, the corridor, in at the door behind the other, the set switched for both, a knock waking both) |
| The chapel in Liblice (3. 11., damp and bigger 4. 11.) | `scripts/town/chapel_view.gd` in `town_room.gd` (place "chapel"): bigger inside than its baroque front outside (the user's choice, 4. 11.; `town_lesna._chapel`: the house kit's opt "bare", its oval windows outside at `CHAPEL_VIEW.WINDOWS_Z`/`WINDOW_Y`, the nave's own `NAVE_WINDOWS_Z`): the long nave, the vault in planks (`vault_y(x)`), the triumphal arch cut in steps, the presbytery two steps up beyond it, the choir loft over the door on two posts with its stair; damp and dust: the damp band `chapel_damp_wall2` up every wall (`_damp`), decals `decay_*`/`floor_*` (`_decal`), the vault leaking into a bucket in the aisle (`_tick_drip`, faster in rain), cobwebs, the chandelier, the haze (fog) and dust motes (`CPUParticles3D`), light shafts turned to the eye (`_shaft`, `_face_shaft`); you walk to what you click (`room_walk.gd`, `_spots()`, `WAYS`; sit in a pew); never explained, weighed by the hidden sanity: somebody up in the loft while you do not look there (`_tick_watcher`, the last guest to leave the camp), St Prokop turned (`saint_statue_turned`), the figure under the dust sheet elsewhere each time (`SHEET_SPOTS`), a breath behind the confessional's curtain; sounds `chapel/room_tone.ogg`, `wind_gap.ogg`, `drip_bucket`, `pigeons`, `loft_creak`, `confession_breath`; the retable on the back wall with the altar's table before it (one Grok picture cut in two by `mesto_art.py`), pews with carved ends, the Stations, St Prokop on his console, the harmonium, the stoup, the box for coins, the votive stand (a coin and a match: a flame on the next cup, the cups found in the stand's picture; `room._candles` keeps them while you are in Liblice; co-op `Coop.send_place("town", "chapel", "candles")` through `town_places.gd` to `town_trip.coop_town_place`), the rope (`town_trip._ring_bell_now`), Mrs Hruba kneeling 16-18 (`town_people` has her indoors then); the rest looked at closer (`_look_at`: the eye narrows on it, a click lets it go); nobody narrates. Open day and night (the user, 4. 11.); the light follows the clock while you stand there (`_follow_hour` every half second, `_set_dusk(k, late)`: `night_k`, `late_k` blend morning, late afternoon and night; the sun's shafts sink and go, the moon's come); the altar's candlesticks, the eternal light, the lanterns and the stubs stand there by day too (`_lamps_and_candles`), what burns from six on (`lit_time`) is lit while you do not look (`_evening`: Mrs Hruba gone when you turn round, `_light_altar`, `_light_stubs`, the stand's `_stand_done`); at night the moon through the west windows (`_moon_ray`, `MOON_DIR`: banded rays down to the aisle's floor, a pale patch and a light there, `_moon_motes` dust only in them, `_moon` clouds going over, behind rain hardly any), the day's haze grey-blue and big faint glows in it (`_halo` round the windows, the altar, the lamp, `_stand_glow`), the altar's two candles lit (`altar_candlestick`), the eternal light on its chain (`sanctuary_lamp`, unshaded: its own red light would blaze it), grave lanterns at the rail, under St Prokop and a Station (`grave_lantern`), stubs (`candle_stubs`), the stand with the night's own number of flames already lit (`_night_lit` from `town_trip._night_index`: the same on every machine), a stepped glow round every flame (`_halo`: added on, no fog), all flickering in `_tick_night`; an owl instead of the pigeons, the candles' crackle `chapel/night_candles.ogg` louder beside them (`_by_candles`) and `night_beam`, `night_wax`, `night_moth` now and then (`_tick_night_sound`); `_low()` +0.15 at night; outside the oval windows glow warm (`town_lesna._chapel_oval`). Art `sheet_chapel_night` in `tools/artgen/prompts_mesto.tsv` (`mesto_art.py`, its pink fringe `DESPILL`) |
| Liblice's Jednota, pub and Benzina kiosk behind their glass (the user, 3. 11.: "the other town interiors too") | one script per place for its building and its room: `scripts/town/jednota_view.gd`, `pub_view.gd`, `kiosk_view.gd` (`W`, `H`, `PX_M`: the front's picture; `PANES`, `DOOR_GLASS`: its glass in the picture's pixels; `origin()`, `pane()`: the room in the building's frame; the static `build(root, room, lit)` builds the one room twice: the shell behind the glass in the village (`room` null: lit by emission while open, the people as sprites) and the room you stand in (`room` = town_room: its hot boxes, the npc, the light, where you stand)); the buildings `town_lesna._jednota_hollow`, `_pub_hollow`, `_kiosk_hollow` (only when the `*_front_glass.png` are there: the walls hollow, the front wall cut round the glass behind the picture with its holes, glass quads with `retro_skip`, a solid core to walk into; the room under the node "SalesRoom", "Taproom", "Shop", `spots["<place>_shell"]`) and `_update_jednota`, `_update_pub`, `_update_kiosk` from `set_hour` (the shell rebuilt only when open or shut changes); `town_trip._open_room` hands town_room `place_anchor` and `place_shell`, the room's windows are `window_portal.gd` views out of the building where it stands (the shell hidden from them), the pub's curtains click open and shut. Kubat stays behind his bar and Simek in the reception (`town_people` "day": []). The holes cut by `tools/artgen/mesto_art.py` (`jednota_glass`, `pub_glass`, `kiosk_glass`), the window displays `jednota_display_a`/`_b` (rows in `prompts_mesto.tsv`); co-op: the other wardens stand at the counter (each view's `place_mates`), checked by `python godot/tools/motel_coop.py` After dark from the street: the pub's smoke, the guests black against the lamps at the window tables, somebody going along the windows, the warm spill on the pavement (`pub_street.gd`, a child of the Taproom, on while it is open at night; at closing, `CLOSE_FROM` to `CLOSE_TO`, the guests get up one by one and the windows go dark in turn, the room lit till then); the street's comings and goings by the clock alone, `street_life.gd` (`update` from town_trip, a function of the hour, the same on every machine: the pub's last guests going home not quite straight, the baker's van at the Jednota from 6:31, its driver carrying the crates, Mrs Novotna unlocking at seven, sounds in `CUES`); the closed Jednota's one tube left on, the dying one (`town_lesna._jednota_night_tube`); in the kiosk and the pub a clock that keeps the game's time (`wall_clock.gd`) |
| Shopping at the counter in Liblice (the Jednota and the Benzina kiosk; the user, 4. 11.: "you point at goods, the shopkeeper puts them on the counter and rings them up, you pay with coins and notes from your wallet, she gives change") | `scripts/town/counter_goods.gd` (what is sold where: `STOCK` prices and her line taking it down, `LINES` her words per shop, `LOOK` each good's picture on the counter, the money: `PIECES`, `WALLET_CAP`, `wallet(money)`, `change_in`, `face` the value printed on it, crowns in Czech; the price tags `tag`, shop_art.py paints them in both languages; bread by the weekday `BREAD_DAYS`), `counter_shop.gd` (town_room's `counter()`, handed the shops' clicks by `_shop_click` / `_kiosk_click`: a good clicked where it stands goes on the counter's free `slots`, `ctr<n>` clicked goes back, the till or she rings it up: `_tick_ring` a key each, the sum in the till's window (`_make_window`: digits by `seven_seg.gd` in a little viewport over the dark window of the till's picture), then the close-up; what the bag has no room for stays: `inventory.fitting`; paid goods out through town_room's `bought`; co-op: `Coop.send_place("shop", place, "goods"/"till", ...)`, this node is the group `places_shop`: the others in the shop see your goods on the counter's `mate_slots`, hear the till; money is each machine's `spend_money` through the till deltas), `counter_pay.gd` (the close-up on closeup_view: mat, wallet, till; `PILES`, `COIN_SPOTS`, `TRAY`; a piece dragged or clicked across, covered sum: her hand `_state` reach, sweep, count_in, count, count_out, thanks; `paid` spends the money; Esc / right click / outside leave it unpaid; `force_close` when the room goes), the rooms `jednota_view.gd`, `kiosk_view.gd` (each kind its hot box, `SLOTS`, `MATE_SLOTS`, `TILL_WINDOW`, `begin`), the goods' uses `scripts/ui/inventory.gd` (`use`: matches strike one `counter_match.gd`: the hand, the flame, a small light for its seconds, wind and rain shorten it; bread four bites and Kofola: `_feed` stamina and `pockets.drunk`; the paper `newspaper_closeup.gd`, its `n` the day it came out: which notices and photograph; candle and matches for the chapel `candle_closeup.gd`; `uses_of`, `consume`), art `tools/artgen/prompts_shop.tsv` -> `shop_art.py` -> `assets/textury/shop/`, `items/`, sounds `tools/audiogen/prompts_shop.tsv` -> `assets/sfx/shop/` at -23 LUFS |
| The Hruska gBook in the motel's eleven (the user, 4. 11.: "no camp programs, you cannot install them, no admin rights; another OS look, a wannabe nineties laptop") | `scripts/town/gbook.gd` the close-up (one node the town room keeps, named "GBook": `open_for(room)`, signal `closed`; Esc goes back a step, then leaves; Shut Down ends it, the next open boots cold), `gbook_os.gd` gOS drawn small in a SubViewport and scaled by whole numbers, `gbook_win.gd` its windows, `gbook_apps.gd` the apps, `gbook_files.gd` Mr Hora's documents (`phone` grows a line each game day); art `tools/artgen/gbook_art.py` + `prompts_gbook.tsv` into `assets/textury/gbook/`, sounds `tools/audiogen/prompts_gbook.tsv` into `assets/sfx/gbook/`; its Czech through `cs.po` (`gbook|Special`, the plural `%d item`) |
| Lighting a candle in the chapel with a match (the user, 4. 11.) and the Benzina's toilet ("not my job, this one") | `scripts/town/candle_closeup.gd` (your hand is the mouse: a match from the bag or for a coin, strike it on the box: a slow pull only scrapes, a fast one catches by chance; hold the flame to a wick; burns 6 s and drops; your own candle set first; the stand 1:1 with the chapel's, `chapel_view.lit_on_stand()` lights one without the hands for tools, `GESTURE.auto` in the tools), the chapel's eerie systems in `chapel_view.gd` weighed by the hidden sanity (the flames out behind your back, the harmonium's three notes, the draught); the toilet `scripts/town/wc_view.gd` (door `town_door` "wc" on the kiosk's east wall, hint "Go to the toilet"; the bowl and the mop: "Not my job, this one."); art `tools/artgen/chapel2_art.py` + `prompts_chapel2.tsv` (`camp/candle_*`, `camp/wc_*`), sounds `tools/audiogen/prompts_chapel2.tsv` (`sfx/chapel/candle_*`, `sfx/town/wc_*`) |
| Lojza's job at the Benzina by the camp's turn off road 12 | `geo_world._benzina` / `_benzina_job` (the station, the cars' ways in and out in its frame, the pumps `trip_pump`, Lojza `trip_lojza`, his hours in `set_hour`), `pump_job.gd` (paths from the owner: `setup(stops, ins, outs)`) + `pump_closeup.gd`; `town_trip._job()`, `_start_job`, `_watch_job` (the shift ends 32 m from `geo_world.benzina_at`) |
| Liblice's houses, fronts and lettering | `town_lesna.gd` `_houses()` (the street list), `_gable_house` / `_hip_house` / `_eaves_house` / `_flat_house` build a house to fit its Grok elevation (`lib_*` rows in prompts.tsv) as measured by `tools/artgen/town_facades.py` (`lib_facades.json`: walls, eave; `<id>_win.png` lit windows, `<id>_side.png` side walls; window rectangles are measured by hand on the raw render); lettering `tools/artgen/lettering.py` (`sign_<name>.png`, put on a wall with `_letters`); the green `_green()`, fields `_fields()`; what stands out of the walls (plinth, sills, gutters, ridge, chimney caps, aerials, the yard porch, back windows) `_plinth`, `_front_sills`, `_gutters`, `_aerial`, `_porch`; a front too patchy to tile gets plain plaster on its other walls (`SIDE_FROM`); look at it with `res://tools/lesna_tour.tscn -- --out=<dir>` |
| The transmitter masts, road posts | `scripts/town/liblice_masts.gd` (made by `town_trip._update_masts`, haze from the outdoor fog), `scripts/town/road_post.gd` (`place(parent, pos, to_road)`, `set_night`) |
| Pristoupim's request stop (only its poles, in the fields) and old Vondra's farm with his Skoda at Liblice's south end (the user, 1. 11.: one town; the scripts keep their old name `hamlet_podlesi`) | `scripts/town/hamlet_trip.gd` (state and save, the stop's bus by `bus_timetable.hamlet_to_town/_camp`, the "ham_*" clicks, Vondra), the place `hamlet_podlesi.gd` (two frames: the farm's `HAMLET_ORIGIN` on Liblice's street `town_trip.FARM_PAST_STOP` past its stop, `w()`, with the track, the farm and the ruin back down the road; the stop's `STOP_ORIGIN` at Pristoupim, `stop_w()`, its poles under a top-level `Stop` node; extends `town_lesna.gd` for the house kit: do not change the parent's method signatures), the repair close-up `car_closeup.gd`; in the ride: `bus_ride.path_hamlet` (how far along the ride's path the request stop is), `bus_ride._press_stop` (STOP buttons, STOJIME), `arrived_where`; boarding there: stops "hamlet_town" / "hamlet_camp" (`town_trip._board`; no machine there: the driver sells) |
| The walkie-talkie and the megaphone (your voice to the other wardens) | `scripts/coop/voice.gd` (Coop's child): hold `radio_talk` (V) in co-op or `megaphone_talk` (G) with the megaphone in the bag; the microphone (project setting `audio/driver/enable_input`) through a muted bus with an AudioEffectCapture, 16 kHz mono mu-law, 20 ms a packet over `Coop.send_voice` (unreliable, channel 6); heard through the "VoiceRadio" bus (2D, a little speaker) or "VoiceMegaphone" (3D at the shouter's figure, loud and far); the squelch sounds `assets/sfx/radio/` from `tools/audiogen/synth_sfx.py` (it also makes the validator's `ticket_punch.wav`); guests near the megaphone look up (`guest_agents.alert`); the hand `hands_lo/radio.png` / `megaphone.png` while you talk. The megaphone lies by the chest of drawers in the room behind the office (`back_room.gd` "megaphone", `reception_extras._take_megaphone`; inventory "megaphone"). Keys you can change: `GameSettings.REBINDABLE` (saved in settings.cfg [keys]), Controls page: click the key, press a new one (`key_clash` says what else is on it) |
| The Hronek ruin, Vondra's lift | `ruin_closeup.gd` (the Hronek kitchen close-up and its scare, `state["ruin"]` counts the looks); `skoda_ride.gd` (the garage Skoda driven along the real road to the camp stop: `_build_path` = the farm's track + `GEO.line_path` from Liblice's street (`GEO.s_near` of the track's mouth) + `road.bus_arrive_path`; it parks its camera in `main.debug_camera`, which main makes current every frame, and slows the clock like the bus; `town_trip._eye_for_geo` follows the car); his lines `vd*` in bus_talk.tsv (voice "vondra"); co-op: `hamlet_trip.shared` / `take_shared` (main's sync "hamlet", merged forwards), `town_trip._coop_hold_hamlet` |
| Testing the town and the bus | the title screen's secret page (L) "Bus to Liblice" (`main._start_test_bus`: a fresh camp, the camp stop as the 13:50 comes); played through for screenshots by `res://tools/bus_tour.tscn -- --out=<dir>`; Liblice alone `res://tools/lesna_tour.tscn` |
| The content reel (filming the game) | the title screen's secret page (L) "Content reel": `scripts/content_reel.gd` on the businesses' test camp (`main._start_content_reel` -> `_start_test_businesses(true)`): a day of scenes, L the next, Shift+L the same again (`SCENES`: dawn with the god cursor dropping buildings, the pub's tap at lunch, the PC with both monitors at the golden hour, the last 380 in the drizzle, the Photographer in the storm by the office, the Silent Man in the fog); its L comes before the rooms' and the debug menu's (a node last on the root) |
| Testing the businesses' work | the title screen's secret page (L) "Businesses" (`main._start_test_businesses`: a fresh camp at 10:30 with the corn stand, the pub, the bistro and the Jednota on paths up from the gate, tents and cabins full of guests made hungry and thirsty by `GuestManager.debug_want_food`, every blueprint open) |
| The camp computer (the panel: tabs and their keys, badges, boot, covers, one-click installs) | `scripts/os98/os_shell.gd` (`TABS`, `PROGRAMS`, `HOST`), a program's place `os_page.gd`, look: `os_theme.gd`; the shown program's taskbar button clicked again puts it down to the desktop (`_minimize_on`, the button lifts it back); Builder's scripts and art are read on the loader's threads while the PC boots (`scripts/builder/warmup.gd`, from `_start_boot`/`_process`: its first open took 1.7-4.3 s, now ~0.1 s); the monitor's SubViewport embeds its subwindows (`building_interior._build_crt_viewport`: menus and tooltips inside the screen, not on the game's window) |
| The second monitor (PC Servis's page, the post van, the postman, the slip; the two screens) | the order and its stages `scripts/reception/post_delivery.gd` (kept in the PC's store "post", so saved and sent with the PC both ways; only `Coop.sim_here()` moves it on by the clock; the van and the man drawn on every machine from the stage and its `t0`; the man across the counter is its `_desk_man` + the extras' hot "postman" -> `building_interior.dressing_click`), the slip `scripts/closeup/post_closeup.gd` (SIGN_BOX, PARCEL_BOX in picture px), the page `pc-servis-hlubocany.cz` in `web_pages.gd` (found only from the bazaar's foot or the search) with `{{pcservis}}` and `order://monitor2` in `browser_app.gd`; the monitor itself `building_interior.set_second_monitor` / `_build_second_monitor` (MON2_PIVOT, the radio moved on top `_place_radio`), A/D at the PC `_crt_turn` / `_look_screen()`; the second screen in `os_shell.gd` (`set_dual`, `_select_tab_on`, `screen_origin`, `keys_for`; `scripts/os98/os_keys.gd` for the programs); art `tools/artgen/prompts_post.tsv` -> `post_art.py`, sounds `tools/audiogen/prompts_post.tsv` |
| The reception's windows from the camp (the real office behind the glass) | `building_interior._update_inview` (a camera in the office's own world at the camp's eye, through `ReceptionLayout.room_to_local` and the panes' parent node; live within `INVIEW_RANGE` with a pane turned to you; the room's light kept to the camp's hour while shut; the curtains go on moving `reception_extras.tick_unseen`), the panes' shader `materials/window_into.gdshader` (SCREEN_UV, `live`, `glow` the dark fallback, `bright` by the hour), the other wardens inside seen from outside `interior_manager._coop_office_from_camp` with the same placing as inside `_place_office_fig` |
| Its programs (CampMail, Beeternet, CampStat, GuestRack, Atlas, Files, Shops…) | `scripts/os98/apps/*_app.gd` (Atlas, the fifth tab, is `atlas_app.gd` over `scripts/reviews/goggle.gd`: the code kept Goggle's name, saves too; its advertising `goggle.ADS`, bought through `main.atlas_buy_ad`, read by `EmailManager._roll_customer_mail_count`); Builder map: `builder_module.gd` (toolbar, keys, the building card) + `crt_map_panel.gd` (overlays `set_overlay`, `structure_at`, `building_clicked`); upgrades from the map `interior_manager.map_upgrade`, the crew to one building `main.request_maintenance_crew_at`; in CampMail a program's name is a link to it (`mail_app._program_links`, from `os_shell.PROGRAMS`' titles: a new program is linked by its title) and a mail with `"rich": true` draws its `:name:` lines as points with a picture (`MAIL_ICONS`) |
| Jobs and Games (the program folders) | `scripts/os98/apps/program_shelf.gd` (Web View folder pane) with `jobs_app.gd` (`datapunch_app`, `job_adclick`, `job_census`; pay through `shell.earn`, day limits `shell.job_done`) and `games_app.gd` (`mines_app`, `game_mosquito`, `game_hike`, `game_pexeso`; tables `shell.scores`, seeds `SCORE_SEEDS`, drawn by `score_board.gd`); icons `tools/artgen/panel_icons.py` |
| Web pages, the files on its disk | `scripts/os98/web_pages.gd`, `scripts/os98/os_files.gd` |
| Electricity | `scripts/electricity_billing.gd` |
| Save format helpers | `scripts/save_codec.gd`; snapshot build/apply in `main.gd` |
| Player movement, flashlight battery, stamina | `scripts/player_controller.gd` |
| Bookings, arrivals, the barrier, room states | `scripts/guest_manager.gd`, rules `core/systems/room_rules.gd`; how many letters come `email_manager._roll_customer_mail_count` (every free bed a chance, `bookings_waiting_cap`), measured by `tools/mail_check.tscn` (camps of one tent to thirty beds) and in the real camp by the shot driver's `bookings` scenario (`auto_accept`) |
| The gatehouse, barrier, road | `scripts/camp_gate.gd` (built by world_generator) |
| Room tasks in interiors (hover, hold, checklist) | `scripts/interior_tasks.gd` + `scripts/interior_prep.gd` (a hold begun on a thing goes on wherever the pointer goes while the button is down; let go, what was done is kept, `_partial`; `pause(on)` for a walk through a door); what the mess is: `core/systems/mess_rules.gd`; toilet/shower blocks: `service_interior.gd` `set_upkeep_target`; shots: scenario `prepslip` |
| The camp's own music (not the radio's) | `scripts/audio/music_director.gd` (made in `main._setup_audio`, ticked in `_process`; co-op kind "music" in `_coop_sync_things`); the songs `godot/assets/music/<cue>.mp3` (Suno, -18 dB mean, 128 kbps; `title.mp3` is the menu's `MENU_THEME_PATH`); **after adding or replacing a song run `python tools/audiogen/music_sections.py [cue]`**, which writes `music_cues.json` (bars, sections, where its fade begins) — the director only plays what is in it; which song when: `_cue_for`; the Suno side (the motif, the styles): `tools/audiogen/SUNO.md`, `tools/audiogen/motif.py`. Debug: `_music_director.debug_play(cue, at)`, `debug_out()`, `debug_text()` |
| Retro look and leaks | `scripts/retro_materials.gd` stands a ShaderMaterial in for every StandardMaterial3D and **forgets it when the original is gone** (`_prune`, weak refs): keep it that way, rooms build new materials every visit (they piled up: ~400 objects and 20-38 MB of video memory per business visit, interiors and windows went black after hours). Meta `retro_skip` (also when set right after `add_child`) keeps a node's own material; `retro_no_pull` keeps a thin board from being pulled in front of its lettering. A soak to measure: in and out of every room with `Performance.OBJECT_COUNT` / `RENDER_VIDEO_MEM_USED` per cycle. Run test windows muted: `--audio-driver Dummy` |
| Generated sound effects | `tools/audiogen/` (ElevenLabs; key in the gitignored `.env`); then `python tools/audiogen/normalize.py 'assets/sfx/<dir>/*.mp3'` to bring them to -23 LUFS (each comes back as loud as it likes: one clipping, the next inaudible), and set the loudness in the code; sounds with an exact timing (the phone's cadences and keys, the station's pips, the set's tone) are cut from recordings in `tools/audiogen/raw/` by `tools/audiogen/cuts.py`; a music loop: `python tools/audiogen/loop_cut.py <clip> <dest.ogg> [bars]` (whole bars from the first strong beat, the end cross-faded, -23 LUFS, OGG: MP3's encoder gap would click at every repeat) |
| Night jobs, the distribution board | `scripts/night_jobs.gd`, `scripts/breaker_panel.gd` |
| Day events, camp life sounds | `scripts/day_events.gd` (sounds in `assets/sfx/life/`) |
| The camp's sounds where they come from; life far off; footsteps | `scripts/ambient/world_sounds.gd` (lamps, the generator, the lake, the frogs, the trees in the wind, the flagpole's rope, the washrooms' tube and tap), `scripts/ambient/far_life.gd` (voices at the fire, children, a dog, a car, a train, the village bell; on the NightInsects bus), footsteps in `player_controller._surface_under` (`assets/sfx/steps/<surface>_a..d.mp3`); rows in `tools/audiogen/prompts_world.tsv`; `tools/world_check.tscn` checks they load |
| Head turning inside interiors | `scripts/interior_look.gd` (limits set per interior script) |
| Insects falling silent, the HUD face's glance | `scripts/threat_senses.gd` (reads `get_presence()`) |
| Story mails (Vera, Nela, the odd ones) | `data/pools/emails/story/week01_story.json` |
| The radio (playlist, outdoor source, the station) | `scripts/building_interior.gd`; the station that does not exist is recorded (`un_*` rows in `tools/audiogen/prompts_world.tsv`, its pips cut by `tools/audiogen/cuts.py`); songs in `assets/sfx/radio/` (8 kHz 32 kbps, a `night` prefix = night only; originals `ost/<name>_hq.mp3`) |
| The radio going wrong with the night (layers, song bus, broadcasts) | `scripts/radio/radio_dread.gd`; sounds `tools/audiogen/radio_lines.tsv` → `radio_fetch.py` → `tools/gen_radio_dread.py` → `assets/sfx/radio_dread/`; listen: `tools/radio_dread_demo.gd` with `--write-movie` Past a raised night the song goes the way of a memory (`_care`, the user 4. 11.: The Caretaker): the hall `_fx_hall` on the song bus, the echo, the tape slow for good, the `crackle` layer, `Ev.NEEDLE` a phrase turn after turn, the ghost the song itself; hidden indoors at night, `scripts/audio/caretaker.gd` (main ticks it, `caretaker_context`; static `level`, read here): a phrase of an old song from nowhere in a huge hall on its own bus "Caretaker", two players crossfading the turns, gaps, each machine its own, quiet with the set playing beside you; listen `tools/caretaker_demo.gd --part=hide|radio` with `--write-movie`. The four tiers by the file's prefix (the user 5. 11.; `scripts/radio/radio_tiers.gd`): none any time, `night*` at night, `teror_` past `TEROR`, `peklo_` past `PEKLO`; drawn instead of the playlist's next (building_interior has only hooks: `_radio_tiers`, `_radio_play_path`, `_radio_break_in`, the playlist skips tiers 2-3, ctx `raw`), the worst cuts the song (`Ev.BREAK`, `take_break`), the splinters (`Ev.FLASH`, `radio_dread/h_*.mp3` cut by `_sc/mesto/tools/hell_shards.py`), a dread song on air left raw (`_raw`: no memory hall, no slow tape); the granny's lullaby more often on her night. New radio songs: 8 kHz, 32 kbps, -14.4 LUFS under a limiter, the original in `ost/<name>_hq.mp3`; `<name>_song.mp3` for the caravan's set too. The Caretaker's treatment offline, three ways (`tools/audiogen/caretaker_treat.py`: `night_care_*`, `teror_care_*`, `peklo_care_*`); the hide's phrases now and then a hell far gone (`caretaker.HELLS`); the motel set's lists (`motel_radio.gd` SONGS/NIGHT/LOW/HELL). Test `tools/radio_tiers_check.gd` |
| The hunts' beat (the user 5. 11.: loops out of the chaos for chases, only some enemies) | `scripts/audio/chase_music.gd`, owned by `nightmare_fx` (`set_chase(id, level, near)` each tick, below 0 cuts it dead; `remote_fx`/`coop_night` carry it to the hunted warden's machine); loops `assets/sfx/chase/*.ogg` cut on the beat, a hit at both ends (`_sc/mesto/tools/find_loops.py` the beat to the sample and the candidates, `cut_loops.py`, `draw_loops.py` the seams against the grid, `chase_assets.py`; `loop=true` in each `.import`): the granny's `granny_a`/`granny_b` the same length (in step), the harder one by `near`; her stop to look cuts it (`basket_brain._tick_chase`); the antlered man's charge `antler`; the whistler's rush `whistler`, cut where he listens and at his strike. Test `tools/chase_check.tscn` (the real brains), co-op `tools/coop_babka.py` (`chase_seen`) |
| The wholesaler's van and its driver (the day's delivery) | `scripts/reception/delivery_driver.gd` (made by building_interior beside the postman's `post_delivery.gd`, whose way in and pace it shares): the open event's `started` (day_events `delivery_event`; its wait counts from the counter: `DRIVER_WAY_MIN`) is its clock: the van up the road (VAN_IN), parked outside the barrier west of the postman's, the driver the guests' way to the office door, across the counter at `DESK_SPOT` (hot body "van_driver" -> building_interior.dressing_click -> `open_delivery_note`); the folder on the desk only while he is there (`at_desk`); when it ends he walks back from where he was and the van turns and goes. Drawn on every machine from the event as each has it. The van: Grok faces `post/jvan_*.png` on boxes (CAB_FRAC, CAB_H, WHEELS_Z: measured on the side picture), art `tools/artgen/post_art.py wholesale_van` (rows `jednota_van_*`, `npc_jednota_driver` in `prompts_post.tsv`) |
| Benches on paths (like the lamps) | `core/systems/builder_authority.gd` (a bench on a path cell: the cell stays a path, its `bench` = the turn; one lamp or one bench a tile), `scripts/lamp_spot.gd` `bench_edge` / `bench_offset` (the camp and the Builder's map alike: the edge the turn points to, the nearest where the path does not go on), `building_manager.place_bench_on_path_at` (meta `on_path`, the path's `bench_node`, gone with the path), `crt_map_panel` draws it on the path's tile; saved with the structures (since 1. 11. the ones on paths too: lamps on paths were lost on every load), `main._rebuild_core_cells_from_visual_structures` puts the flag back; the guests sit on it (`guest_needs_system.collect_facilities` reads such a cell as a bench) |
| The noticeboard's timetable | `scripts/closeup/board_closeup.gd` TIMETABLE_RECT: the 380's ČSAD sheet drawn small on the cork; held up, the pole's own sheet (a `timetable_closeup.gd` kept off the tree draws it, stop "camp"), times from `bus_timetable.gd` |
| The office: phone, noticeboard, back room, sleep | `scripts/reception/` (reception_extras, back_room, sleep_sequence, camp_office, electrician_visit); the back room's door by hand `reception_extras._swing_back_door`, shut over the night in `_try_sleep`'s `fast_forward`; when beds take a click `camp_office.bedtime()` |
| 2D close-ups (phone, noticeboard, logbook) | `scripts/closeup/closeup_view.gd` + subclasses; who answers the phone: `phone_book.gd`; voices `tools/audiogen/tts.py` + `voices.tsv` (needs a key with text_to_speech) |
| The cursor and the hover glint | `scripts/ui/hand_cursor.gd` (`HandCursor.want(kind)` per frame), `scripts/ui/hover_glint.gd` |
| The thing in the pipes, its staging | `scripts/pipes/pipe_director.gd` (the minigame keeps the network, movement, map, clamp) |
| The night's director (tension, events, log) | `scripts/night/night_director.gd` (pure logic, `tools/director_check.gd`), effects `scripts/night/director_effects.gd`, context `main._director_context()`; sounds `assets/sfx/director/`; F10 panel (debug builds) |
| The reception's plan (office, back room, building, windows) | `scripts/reception/reception_layout.gd`; the building `building_models.reception()`, turned a quarter in the camp (`building_manager.place_main_building`: its door and office window face the gate lane, arrivals queue by the door, `camp_gate.waiting_spot`/`way_in`); the office's side window by the stove `SIDE_WINDOW_*` (room `building_interior._build_side_window`, curtain `reception_extras.side_curtain`, co-op "sc", pane `side_glass`); curtains `scripts/reception/curtain.gd` |
| Things moving in steps (the user 5. 11.: "more low-fps animations like the bus doors") | `scripts/ambient/step_motion.gd` (one node for the world, `attach(node, kind, axis, amount, opts)`: swing, rattle, flap; `kick(node, axis, turns)`; twelve steps a second, near the eye, by weather_visuals' `_wind_now` or a `drive` Callable; opts shift, from, with, near, pivot; a node something else moved since is re-based, a kick gives up). It finds the camp's outhouse, shower and generator doors and the tents' flaps itself (`CAMP_DOORS`, `_scan_camp`); the pub's sign (town_dressing), the stops' signs and Lesna's lamps (town_lesna, hamlet_podlesi), the barrier (camp_gate `_swing`), the Karosa's panes, tickets and needles (bus_ride, bus_model, karosa_cab.needles/set_needles); the washing by `wind_strength` in materials/cloth_wind.gdshader. Test `tools/steps_check.gd` |
| Wires (the masts' guys, the power lines) | `scripts/ambient/wire_ribbons.gd` (`mesh(pairs)`, `hang(a, b, sag)`, `material(colour, radius, own_haze, fade)`): ribbons turned to the eye, a pixel wide (1.02), solid; long ones in 10 m pieces. The masts' guys `fade`: solid to `solid_to` (150 m true distance: the node's scale taken off, liblice_masts draws them nearer and smaller), from `faint_from` (700 m) a third and less in haze, as before V13 (the user 5. 11.: a pixel-wide solid guy is a hair at a kilometre, three dozen of them ran together into a grey tent round each mast from the camp). After any change to them look from the camp (`_sc`-style shot: the player turned to `LibliceMasts`) and from up close (150 m, 400 m), both |
| Builder construction effects | `scripts/builder_fx.gd` (wave, local grid, outlines, ripples); lamp spot on paths `scripts/lamp_spot.gd`; building sites and rubble in `crt_map_panel.gd` (`_start_site`, `_tick_sites`, `_draw_site`, `_leave_rubble`; `_known` = what the static layer last drew), rows by dragging (`ROW_TYPES`, `_update_row`, `_end_row`); coins, the odometer, the music and the tool on the pointer in `builder_module.gd` (`_launch_coins`, `_draw_odo`, `_tick_music`, `cursor_texture` -> `os_shell.tool_cursor`); the sprites from `tools/artgen/web_review_art.py`; `scripts/builder/`: `day_graph.gd` (main's `_day_graph`, recorded at dawn) and `graphs_window.gd`, `shareware.gd` (the nag, the key, the cheats; the PC's store "builder98"), `courier_news.gd` + `news_paper.gd` (extra editions, diplomas; the PC's store "courier"), `about_dozer.gd`; the Mega gnome `data/buildings/mega_gnome.tres` + `building_models._mega_gnome` |
| Builder's pictures of the buildings (four views each) | drawn from the 3D models: `godot/tools/iso_render.tscn -- --out=<repo>/tools/artgen/out/iso3d [--only=pub]` (each built alone on its own render layer, an orthographic camera from the map's four corners at 30 degrees, 128 px across a tile, light from the camera's upper left; also each lodging's lit windows alone, `_win`), then `python tools/artgen/iso_views.py sheet <type>` (2x2 sheet for Grok, rows `iso4_<type>_a/_b` from `tools/artgen/builder_prompts.py` in `prompts_builder.tsv`; small things four to a sheet: `sheet4`/`cut4`) and `iso_views.py cut iso4_<type>_b <type>` (or `raw <type>`: the render itself) -> `assets/textury/builder/iso3d/<type>_<s>.png` + `views.json` (the anchor: the footprint's middle); the map draws `<type>_<(view + turn) % 4>` (`crt_map_panel._view_of`, `_draw_view`); look at it with `godot/tools/builder_shots.tscn` (the map in four views beside the camp from the same corners) |
| The map's turning, its people, its message line, its sound | `crt_map_panel.gd`: `view_rot`/`rotate_view` (builder_module `turn_view`, T, the PC's store "builder_view"), the guests (`_update_guests` from `guest_agents.get_visible_guest_positions`: each member, its pose picture, its way; `_peep_frame`, `PEEP_KIND`, faces `REACTS`, `_draw_sleepers`), `sound_under_pointer`; lit windows `_draw_lit_windows` (`window_lights.lit_state`); `scripts/builder/ticker.gd` (the message line and its corner window, EventBus + GuestManager); Builder's clicks `builder_module._ui(id)` (`assets/sfx/builder/ui_*.mp3`, rows in `tools/audiogen/prompts_builder.tsv`); the guests behind buildings `_occ`/`_draw_occluders`; the small life `scripts/builder/map_life.gd` (frames `builder/life/<thing>_<n>.png`); the site's stages, the bulldozer and its dust `builder/site/stage_<0-2>.png`, `dozer_<0-7>.png`, `dust_<0-3>.png` (`_draw_site`, `_draw_dozers`); the trees in the wind `tree_sway_*` (`_swaying`); the moving tool cursors `builder_module.CURSOR_FRAMES` (`builder/cursors/`) |
| Builder's hidden 3D view (the status bar's corner grip) | `scripts/builder/map3d.gd` (made by `builder_module._build_ui`, toggled by `toggle_3d`, the grip `_build_grip`/`_draw_grip`, remembered as the PC's store "builder_3d"): its own SubViewport into the camp's World3D (`building_manager.get_world_3d()`), the camera, the way in/out (`enter`, `leave`, `_pose`), the plates (one MultiMesh, `materials/builder3d_plate.gdshader`), the ghost (`_ghost_model`: a building's model from `building_models.gd` built off the tree and copied to meshes only, `materials/builder3d_ghost.gdshader`), the paper over it (tags, pops, thoughts, badges, compass, minimap); the view through the palette `materials/builder3d_view.gdshader`. The map panel asks it through `map3d` (`_in_3d()`: `_local_to_grid`, `cell_screen_point`, `guest_at`, `follow_guest`, `debug_center_on`, `_minimap_click`, `apply_zoom_step`, the pan, the arrows; `take_input` first); `set_3d_layers`, `match_view` for the way out. The 3D view roams the whole land (`ROAM`, up to 1.6 km out; the land and Liblice are built round what it looks at: group `builder_3d`, `geo_eye()`, asked by `town_trip._eye_for_geo`; the far darkness pushed out by `retro_materials.vis_far`). Shots: `shot_driver` scenarios `builder3d`, `walkcam` |
| Keys at the PC desk; Builder's camera with legs (WASD) | `building_interior._input` (crt): E turns the head (`_crt_turn(1 - _crt_look)`: second monitor or the office window, and back), S stands you up unless `_crt_keys_taken()` (the shell's meta "builder_walk" = the Builder module, its `walk_keys()`: walk on, Builder on the screen you look at (`OS_KEYS.here`), not looking out of the window (shell meta "look_away")); `_exit_crt_view` ends the walk. The module's button `_walk_btn` (icon `tb2_walkcam.png`, rows `prompts_walkcam.tsv` -> `os_art.keyed/fit`), `_set_walk`, `_tick_walk` (sets the map's `wasd`; the map pans by WASD in `_update_keyboard_pan`, 2D and 3D). Building turn keys Q / R (E is the desk's). Shots: scenario `walkcam` |
| Path tiles (joined from the eight neighbours, the camp and the 2D map alike) | `scripts/path_tiles.gd` (`mask_at`, `texture`); the fill `assets/textury/redneck/paths/gravel_fill.png` from `python tools/artgen/path_fill.py`; the camp `building_manager._refresh_path_visual_at` (all eight neighbours refreshed), the map `crt_map_panel._draw_path`. Shots: `shot_driver` scenario `pathyard`. OSM roads stop at the camp's fence (`geo_world._outside`) |
| The god cursor over the camp | `scripts/god/god_cursor.gd` (main `_god_cursor`, made with the guest agents; `from_peer` set by main around co-op builds; `debug_force` for tools; `finish_all()` from `_leave_everything`); guests jump aside `guest_agents.dodge`, the view shakes `player_controller.ground_shake`; sounds `assets/sfx/god/`; look: `godot/tools/god_shots.tscn -- --out=<dir> [--part=day|fog|dusk|window]` |
| Toilet scrubbing | `scripts/scrub_minigame.gd` (opened by `interior_tasks.gd` for tasks with `scrub`) |
| Toilets and showers getting dirty, their stink | `maintenance_rules.gd` `SOILED_BY_USE`, `STINK_FROM`, `FILTHY`; `actions.soil_building` (GuestManager's "visit" event, the host's); the fumes and flies `scripts/stink_fx.gd`, set by `maintenance_controller._sync_stink` (keeps their dirt out of `_clear_old_wear`); art `tools/gen_stink_sprites.py`; look: `res://tools/stink_shots.tscn -- --out=<dir>` |
| Night work programs | `scripts/os98/apps/datapunch_app.gd`; guest book replies `EmailManager.reply_to_review` |
| The lost and found, the bazaar | `scripts/bazaar.gd` (pure, `tools/bazaar_check.gd`); main `_on_guest_state_for_bazaar` / `_settle_bazaar`; page `bazar-hlubocany.cz` in `web_pages.gd`, `{{bazaar}}` and `bazaar://list/ID` in `browser_app.gd` |
| The generator shed (junk, switch room) | `scripts/shed/generator_shed.gd`; the board's close-up `scripts/breaker_panel.gd` |
| The lake trip, far shore, fishing | `scripts/lake/lake_trip.gd` (seats, rowing, docking, camera moves, the hands on the oars, co-op `coop_state`/`coop_mirror_boat`), the boat itself `scripts/lake/boat_rig.gd` (hull on the swell, the oars' stroke `stroke_pose`, splashes and swirls, lantern, sounds; seats `ROWER_EYE`, `BOW_FEET`...), far shore and the jetties' rects in `scripts/camp_lake.gd`, logbook `scripts/lake/logbook_closeup.gd`; models `rowboat`, `rowboat_oar` in `tools/blender/props_more.py`; sounds `tools/audiogen/prompts_lake.tsv`; shots `tools/boat_shots.tscn`, co-op `python godot/tools/boat_coop.py` |
| Corn tiles in the camp | `scripts/world_generator.gd` (`_corn_band`, `_create_corn_patch`), Builder icon in `crt_map_panel.gd` |
| Web pictures | `{{img:name:w}}` in `scripts/os98/web_pages.gd`, files from `tools/artgen/web_image.py` |
| Guests at the campfire, on the slide, on the court | `scripts/attractions/campfire.gd`, `slide_ride.gd`, `pitch_play.gd` (group "attraction": `covers_tile`, `pose_member`; guest_agents hands them the visiting party); the models in `building_models._bonfire/_slide/_sports` (the slide's line and the court's size are metas) |
| Guests in the pub, bistro, Jednota; counter minigames | `scripts/food/service_life.gd` (seats from `service_interior._start_life`; the Jednota's queue along its till: `queue_spots`, `_queue_tick`), shared `orders.gd` (visits kept past their time: `set_holds`); a counter close-up would be opened by the `CounterGameSpot` body in `service_interior._build_counter_game` (none now: every place's work is a station) |
| The corn stand (its two stations in the camp) | `scripts/corn/`: the view behind the counter `stand_view.gd` (a camera of its own in the camp world, the frame, the input; opened by `interior_manager._on_corn_stand_interact`, its `coop_room`), the stations on the stand's counter `stand_layout.gd` (SURFACES in the stand's own space, each with its camera and its "peek": `station3d.peek_up`, the eyes up to the guests while the pointer is at the top, back down below it; made by `business/corn_stand_life.gd make_stations`; things lying on the counter lean back to face that camera, `corn_station.lying`), `corn_station.gd` + `counter_station.gd`, `husk_station.gd` on `business/station3d.gd`, the stands' state and their co-op ops `cornstand.gd` (`Coop.send_place("corn", ...)`, the node in group `places_corn`), the rules `core/systems/corn_rules.gd`; art rows `ct_counter`, `ct_husk`, `cts_corn` in `tools/artgen/prompts_pubcorn.tsv` -> `pub_art.py`; shots `tools/stand_shots.tscn`, co-op `python godot/tools/stand_coop.py` |
| The Jednota (rooms, stations, the shop for four) | `scripts/jednota/`: the rooms `jednota_layout.gd` (STATIONS, SURFACES: the till on its counter, the rack and the trolley as one wall, the packing table; QUEUE, BROWSE: where the guests stand), the shop's state and its co-op ops `jednota.gd` (`Coop.send_place("vecerka", ...)`, group `places_vecerka`; the queue `tickets`, `serve`, `make_box`, `shelve`, the hands `_crew_work`, the visits kept `_holds`), the stations `jednota_station.gd` + `till_station.gd`, `shelves_station.gd`, `store_station.gd` on `business/station3d.gd`, the rules `core/systems/jednota_rules.gd` (PLANOGRAM, baskets, change, `day_model`); the model `building_models._jednota`; art `tools/artgen/jednota_prompts.py` -> `jednota_art.py`, sounds `tools/audiogen/prompts_jednota.tsv`; shots `tools/jednota_shots.tscn`, co-op `python godot/tools/jednota_coop.py` |
| The pub (rooms, stations, the bar for four) | `scripts/pub/`: the rooms `pub_layout.gd` (STATIONS, SURFACES: the bar's three stations along its top, the keg in the cellar; the bar model's tower hidden), the bar's state and its co-op ops `taproom.gd` (made by `business_runtime`, `Coop.send_taproom`; the hands by role `_crew_work`, flat kegs, `waste_keg`), the rules `core/systems/pub_rules.gd`, the stations `pub_station.gd` + `tap/back/wash/keg_station.gd` on `scripts/business/station3d.gd` (opened through `service_interior._station_layout()/_station_scripts()`), the marks `pub_marks.gd`; art `tools/artgen/pub_art.py` (rows in `prompts_pubcorn.tsv`: the glassware drawn plain for 16 px, the tap tower); shots `tools/pub_shots.tscn`, co-op `python godot/tools/pub_coop.py`. The LUCKY 7's reels and lever are drawn into the room's own cutout of the machine (`slot_station._take_machine`, `_paint_face`: the cutout turns to face you, sprites before it did not); the bar's three stations' bodies take the whole counter in front of them (`station_body`, meta `glint_sprites_only`) and glint their sprites from across the room (`station3d.room_glint`); a spot with things standing on it lists them (`"on": [sprites]`: the clean mugs, the dirty pile) and pointing at one is pointing at it; the front door seen from inside `pub_layout._front_door` (where `building_models._pub` has it) |
| PROTOTYP 540 (the bistro cellar's machine) | the rules `core/systems/bistro_rules.gd` (`PROTO_MEAT`, `proto_awake`, `proto_night`, `proto_sack`), its state in `scripts/bistro/kitchen.gd` (`proto` in the site record and the kitchen's save, op "proto", the host's `_proto` once a second, `_on_guest_state`: a departure at dawn marks the night), the station `scripts/bistro/machine_station.gd` (the sack, the lift, running, the meat), the stock `actions.biz_gift`; harness `tools/proto_check.tscn`, shots `tools/proto_shots.tscn`. What the sack holds is never said anywhere in the game: keep it so |
| The bistro (rooms, stations, tickets, the kitchen for four) | `scripts/bistro/`: the rooms `bistro_layout.gd` (STATIONS: click boxes, where a warden stands, marks), the kitchen's state and its co-op ops `kitchen.gd` (`Coop.send_kitchen`), the rules and timings `core/systems/bistro_rules.gd`, the stations in the room `bistro_station.gd` + `*_station.gd` on the shared 3D base `scripts/business/station3d.gd` (sprites at the room's pixel `sprite()`/`room_tex()`, the pointer cast onto the counter `point()`, `held_at()`, meters, pops; the order rail `ticket_rail.gd`, the frame `station_hud.gd`; opened by `service_interior._open_station`, the camera in steps `station3d.step_camera`), the room marks `bistro_marks.gd`, the sentence under the room `room_sentence.gd`; art `tools/artgen/bistro_prompts.py` -> `gen.sh` -> `bistro_art.py`, sounds `tools/audiogen/prompts_bistro.tsv`; shots `tools/bistro_shots.tscn`, co-op `python godot/tools/bistro_coop.py` |
| The businesses' polish (DESIGN §7b "The businesses' polish") | the hand at a station `scripts/business/station_hands.gd` (TOOLS: tool -> rest/act pictures `hands_lo/st_*.png`; a station answers `hand_tool()`; `flash(tool, ticks)` for something done in passing), Papa's slip `station_hud.serve_card` (stations call `score_card(v, what)`), the eye pointer `HandCursor.LOOK` (rooms: `bistro_look` things), thirst and the Jednota's bag `guest_needs_system` (`NEED_THIRST`, `HOME_WATER`, `STASH_FROM`, `use_stash`, `RUSH_SEEK`; the bag used in `guest_life._advance_guest`, filled in `_on_complete`), the Z mark `business_rules.day_grade` (+ `unit_cost`: the goods' cost in `actions.biz_take`), the hands' temper `business_runtime.hand_mood`; the corn drinks `scripts/corn/drinks_station.gd` (+ `corn_rules.DRINKS`, `judge_drink`, `cornstand.serve_drink`), the pub's tab `scripts/pub/bill_spot.gd` on the tap (+ `pub_rules` TAB, `bill_for`, `taproom.bills/settle`, the holds "pub") and fun `core/systems/pub_fun.gd` + `slot/darts/cards_station.gd` (`taproom.fun`, `_guests_play`), the bistro's `grill_station.gd`, `bufet_station.gd` (+ `kitchen` grill, soup, `tickets(key, "pass"/"bufet")`), the Jednota's `deli_station.gd` (+ `jednota` deli, cut, parcel; `jednota_rules.DELI`, `BEHIND`); art `tools/artgen/podniky_prompts.py` -> `prompts_podniky.tsv` -> `podniky_art.py` (PICK the variant), sounds `tools/audiogen/prompts_podniky.tsv` |
| The businesses' Papa's frame (2026-10-21: the same in all four places) | `scripts/business/station_hud.gd` (the frame: tabs `tabs` [[id, LABEL, icon]], `alert_of`, SERVE, BOOKS, the mark, the clock, `serve_pop`, the hint and the ghost glove, `key_action`), `station3d.gd` (`draw_ticket`/`draw_big_ticket` the same everywhere from `ticket_items`/`checklist`; `serve_ready`/`serve_now`, `next_hint`, `alert`, `guest_point`, `fly`, `hop`, `score_card(v, what, t)` with the run; `last_station`), `guest_face.gd`, `guest_mood.gd` (bubbles over heads: the stand's `corn_stand_life._moods`, the rooms' `service_interior._tick_moods`; who queues on their feet in the impatient picture `<sprite>_wait.png` via `show_wait`, drawn by `tools/artgen/podniky_art.py` WAITS), `ticket_rail.gd`; the rooms: `service_interior._room_tabs` (every room's stations, the layouts' `ENTRY`, `tab`, `icon`, `menu`), `_enter_business`; the menu `business_rules.MENU`/`menu_on` + `actions.biz_set_menu` (the books' MENU page); last orders `business_rules.last_orders_at`, `business_runtime.takes_orders_at`/`to_last_orders`/`last_call`, `guest_life.order_hours`; the run `business_runtime.note_order`, `business_rules.combo_bonus`/`shift_mark`; the bistro's floor `scripts/bistro/floor_station.gd` + `kitchen` `hatch`/`to_hatch`/`serve_hatch`, the prepared goods `kitchen._prepared`; Options "Work hints" `profiles.profile_hints` |
| Stations: the tabs' order, looking about | the tabs and keys 1-9 go in the order of the `STATIONS` dict of each layout (`stand_layout`, `pub_layout`, `bistro_layout`, `jednota_layout`): the order of the work, prep first, serving, side jobs last (corn: husk, counter, drinks); where you come in is `ENTRY`. Looking about from any station: `station3d._tick_look` (`LOOK_BAND`, `LOOK_DWELL`, `LOOK_YAW`, on `interior_look.gd`; the room's camera turned about `cam_pose()`, never while something is held). Shots: `tools/station_look_shots.tscn` |
| The businesses' shared systems (ratings, lots and going off, gear, the hands, open late) | numbers and people `core/systems/business_rules.gd` (KINDS goods with `life`, GEAR, ROLES, PEOPLE, `applicants`, `score`/`reward`); the books' writes `actions.biz_*` (`biz_spoil`, `biz_bin`, `biz_buy_gear`, `biz_hire(key, person, day)`, `biz_set_job`, `biz_set_late`, `biz_score`, `biz_close_shift`, `biz_order_all`); the running side `scripts/business/business_runtime.gd` (`shift_now`, `crew_now`, attendance, theft, the strange ones, the Z report signal, `price_k`, `debug_hire`); the hands in the rooms `crew_figures.gd`; the night inside a place open late `late_night.gd`; the books on the counter `ledger_closeup.gd` (STOCK, ORDER, STAFF, GEAR, BOOKS), the receipt `zreport_closeup.gd`, the PC's SoftSklad `scripts/os98/apps/business_app.gd`; art `tools/artgen/biz_prompts.py` -> `prompts_biz.tsv` -> `biz_art.py` |
| Doors opening for guests | `scripts/attractions/door_anim.gd` (finds Door/DoorLeaf boxes, hinges them; two leaves side by side are a double door, the right one hinged on its right edge; a Sprite3D or a leaf-sized quad on a leaf swings with it) |
| Through any door on foot, in and out (no dissolve, no black doorway) | `scripts/ui/door_through.gd` (the doorway's pane shows the room from your eye carried through the door; the room's eye takes the walk on in the doorway; out, the leaf opens on the camp and the camp takes it on). Each room gives `door_spec(structure)` (+ `door_ready`, `door_walking`, optional `door_tick` / `door_walk_in` / `door_opening`); interior_manager `_walk_up_first(structure, again, room)`, `_step_in`, `leave_on_foot`, `_through_eye()`. A painted door is made a leaf by `building_models._painted_leaf` (its face cut from the front's picture). Tents: `interior_manager.tent_doors` (unzipped for everybody, co-op `Coop.send_tent_door`), `tent_interior._update_inview` (the inside seen from the camp through the open flap, the other warden in it). Check: `tools/dvere_check.tscn` |
| Windows that look out (a real view of the camp from where the building stands, curtains to draw), the flash through them | `scripts/ui/window_portal.gd` (`make`, `room_to_world`: the room laid over the building's box), all of a room's windows reading its one `scripts/ui/window_shared_view.gd`; used by `service_interior._make_windows` (a layout's painted `window_view` picture becomes a real window), `caravan_interior`, the cabins' own portals (curtains added) and the reception's; every room answers `photo_windows()` (InteriorManager collects it), curtains go to the other wardens with `Coop.send_curtains` |
| People seen from eight sides (guests, the other wardens, the hands, the electrician) | `scripts/figures/doom_figure.gd` (`set_of(name)`: `assets/textury/npc/sets/<name>.png/.json`; `sector_for`, `face`, `turn_toward`, `set_anim`, `advance(metres)`, `show(eye)`; `restore`/`release` when a pose draws its own picture); used by `guest_agents._drive_figure`, `remote_player._walk_doom/_room_doom`, `crew_figures`, `electrician_visit`; poses through `poses.set_pose` (a pose the set has stays in it); the family's people `poses.FAMILY`; the jacket `warden_looks.atlas(model, colour)` (the mask `sets/warden_<x>_mask.png`); art and checks: §7 "People from eight sides"; shots `tools/figure_shots.tscn` |
| The Photographer | `scripts/enemies/tourist_brain.gd` (poses `npc/tourist_*.png` from `tools/artgen/photographer_prompts.py`, made from `npc/host2.png`; sounds `ph_*` in `tools/audiogen/prompts_photographer.tsv` at -23 LUFS, his hum loops `ph_hum*.ogg`/`ph_breath_broken.ogg` from `tools/audiogen/ambience_loop.py`, his steps `ph_step_*`/`ph_drag_*` cut from `ph_steps.mp3`/`ph_step_drag.mp3`; frames `npc/ph_anim/` from `tools/artgen/photographer_frames.py`; the pictures of you `scripts/enemies/polaroid.gd`; DESIGN §5a.5); shots `tools/photographer_shots.tscn`, `tools/photographer_worse_shots.tscn`, `tools/foto_shots.tscn` (`--part=walk`), co-op `tools/coop_photo.py` |
| The fever when you run (no faces: the user 5. 11.) | `scripts/audio/fever_dream.gd`, owned by `nightmare_fx` (`_fever_want`: the largest of presence, dread and the hunt's level, a share of it standing still, all of it running; `fx.fever_pulse(level, seconds)` a moment of it with nothing at your back, what the director's `face_flash` and the Girl's aftermath are now): the ears ring, splinters of the night's voices and blows from ear to ear on the buses "FeverL"/"FeverR" into "Fever", over the master's muffle. Material `tools/audiogen/fever_dream.py` -> `assets/sfx/fever/` (seeded, levelled by RMS). `fx.subliminal` is left for one picture: the Silent Man's `sm_face`, at most once a night (`FACE_CHANCE`); heard, not played (the user 5. 11.): the files stretched, backwards, caught on a syllable, slow to come up, in stereo halls (`tools/audiogen/fever_dream.py`), the `Fever` bus a phaser and a reverb that grows with it, each splinter's pitch wandering (`_tick_wander`) |
| The Silent Man calling you out | `silent_man_brain._call_out`: rare and far (the user 5. 11.: "like Freddy Fazbear"): `_call_due` rolls a night (`CALL_NIGHTS`), `CALLS_A_NIGHT` at most, the first Silent Man only, after `CALL_WAIT` inside; `npc/sm_call_far.ogg`, made by `tools/audiogen/fever_dream.py` `far_call` from `tools/audiogen/raw/sm_lure_a.mp3` (ElevenLabs row in `prompts_playtest.tsv`). His humming round his corner: `HUM_SEC`, `HUM_EVERY`, none indoors. The torch on him shorts out (`player_controller.torch_blackout`: `TORCH_FAIL` surges, `torch_short.mp3`, dead dark, then the flicker back) |
| Your torch on the Silent Man | `silent_man_brain._driven_off` to `nightmare_fx.lock(..., negative = true)`, the Girl's moment the other way round: the world bone white for `LOCK_FIGURE_SEC`, him black in it (`materials/lock_figure.gdshader` `negative`), his lenses (`_draw_lock_eyes`, for the blink only: nothing of it stays on the screen, the user 5. 11.), the roll the other way, `npc/sm_lock.mp3`. `tools/y_check --y=lock` |
| Eyes in the dark | The only eyes that shine are really the enemy's (the user 5. 11.: "the only glowing eyes will really be the enemy, no fakes"): `enemy_eyes` at the body of a brain, nowhere else: no decoy, no ring of pairs round a lamp, no false glasses, the owl's do not shine (`sky_life.gd`). The Girl under a lamp goes round to your back herself (`_round_the_lamp`) |
| The Girl and a door | `girl_brain._went_in`/`_tick_room`/`_came_out` (the user 5. 11.: "make it real"): while you are in she has a place out there (`_out_pos`): up to `DOOR_STAND` in front of the door you went in by, tries the door and the window, loses interest after `LOSES_INTEREST`, walks off; you follow her through the walls (`_through_walls`: `_wall_hum` by distance, heels, a warden on another machine in phrases); past `HEARD_TO` she is gone, and out after that she is `OUT_DIST` off and has not noticed you for `OUT_GRACE`; out while you hear her and she is there before you with `OUT_MOMENT`. `tools/y_check --y=girlout --stay=N` |
| The torch | By itself in the dark (`set_flashlight_allowed`); in rain and storms by F only, day or night (`set_flashlight_rain` from `main._set_weather_state`, `_flashlight_wet`: switched on in the rain it stays on till you switch it off); clicks `torch_on/off.mp3` (`torch_click`; a room's F clicks in `interior_torch`, only it knows the room is dark) |
| Guests and their curtains, life behind the windows | `scripts/ambient/window_lights.gd` (`_watched`, `_pull`, `_tick_panes`, `_life`): each pane its own `shut` (an instance uniform in `materials/window_cube.gdshader`, `meta wl_shut`), `figure` somebody's shape on it (also `materials/pane_figure.gdshader`, `one_world_room.figure_glass`, the cabin's near panes); near, the room's real curtains go with the panes (`guest_curtains` in cabin_interior, caravan_interior). `SPY_NEAR`, `REOPEN` the chances they draw them again; a tent's `hiding` is its light. Each machine by its own warden. Test `tools/y_check --y=curtains|curtains2 --lodge=caravan_1` |
| A toilet block's two sides | The cells' `maint_l/r` (MaintenanceRules): the hint at the door you look at (`interior_manager._door_in_view`, `_toilet_door_of`) and a plate per dirty bowl (`main._work_rows`, `_wc_word`). A door you mean = the one in the middle of the view, `_walk_up_first` walks to it |
| The trouble plates | `scripts/ui/trouble_strip.gd`; goods running out are `cat: "stock"`: wider (`STOCK_WIDER`, the whole name fits: the longest Czech 71 of 79 px), cardboard, the crate at the end (`trouble_crate.png`, `tools/artgen/trouble_icons.py`) |
| Planted trees | `tree_spruce`, `tree_birch` (`data/buildings/`, `builder_authority`, Decor, row by dragging): `world_generator.plant_tree`, the forest's own, by `building_models._planted_tree`. On the map `tree_birch` for planted and forest birches alike (`iso_birch.png`) |
| The corn field's ground | One surface, `materials/corn_ground.gdshader`: `corn_soil.png`, `corn_way.png` (Grok `tex_corn_soil`, `tex_corn_way`) and a map of the maze a pixel a tile; no tiles over the soil to fight it |
| Faces in one plane, things that fly | `tools/y_check --y=clip|rooms`: `fights(tag, room, around)` lists a room's faces lying in one plane with its building's, facing the same way; `intruders()` what of the camp stands in a room's box. A shell's walls start 3 cm outside the rooms' (`building_models.reception`), a plinth is a ring outside the walls (`_plinth_ring`, band 0.13). Anything that reparents a Label3D: `retro_materials._pull_labels` keeps one record a label (`_label_recs`) |
| One way for a door | A room's leaf swings out with the camp's (`door_anim.OPEN_DEG`, `reception_extras.FRONT_DOOR_OPEN_DEG`, `pub_layout` `swing_deg`): never in from inside and out from outside |
| The Silent Man (Quiet Guy) | `scripts/enemies/silent_man_brain.gd` (DESIGN §5a.1; art `npc/sm_*.png` and `npc/sm2_*.png`, sm2 wins where both are, rows in `tools/artgen/prompts_nightmare.tsv`, samples for his decision page in `prompts_quiet.tsv`; sounds `sfx/npc/sm_*` and `silent_*` at -23 LUFS with the gains in the code, his loops `sm_hum.ogg`/`sm_breath.ogg` from `tools/audiogen/ambience_loop.py`; inside, his sounds from out there go through `WORLD_SOUNDS.wall_bus`); tests `tools/quiet_shots.tscn` (`--sim=careful|careless|still|hidden` his night by a bot, `--part=hitch` his firsts timed, `--part=glass` at a cabin's glass), `tools/silentman_shots.tscn` (the worse catches), the shot driver's `testsilent`, `tools/coop_quiet.py` |
| The Girl (Cheap Chicks) | `scripts/enemies/girl_brain.gd` (DESIGN §5a.6; art `npc/girl*.png`, stages in `M`, rows `girl*` in `tools/artgen/prompts.tsv`, decision samples `prompts_holka.tsv`; sounds `sfx/npc/girl_*` at -23 LUFS, loops `girl_hum.ogg`/`girl_static.ogg` from `tools/audiogen/ambience_loop.py`, her laugh `npc/girl_laugh.mp3` (Richard's own cut, the user 5. 11.; -20 LUFS; `_tick_far_laugh` from where she is, unit size 9, round the lamp, through the wall; one voice, `_voice_free`); the director's `hell_far` far off in the trees, `assets/sfx/night/illusion_*.ogg`, inside through `WORLD_SOUNDS.wall_bus`; spots via `enemy_base._stand`, windows via `_room_windows`, the other warden's torch via `_lit_by_others`, which holds her like the hunted warden's: `_held`; out of sight she jams you, `nightmare_fx.set_jam`/`jam_burst`, found she locks, `nightmare_fx.lock` from `_found`: both generic, through `remote_fx` and `coop_night` too, shader `materials/nightmare_screen.gdshader` `jam`, `jam_at`, `hold`, `clean`, `punch`, the blink `materials/lock_figure.gdshader`, the clunk `npc/girl_lock.wav` from `tools/audiogen/mix_lock.py`); her `girl4_*` stages and reach drawn after `host3` itself (rows `gl_m2_2`, `gl_tall_1` narrowed to 0.75 before `process.sprite`, `gl_back_5`, `gl_arms_1`, `gl_reach_2` in `prompts_holka.tsv`); tests `tools/enemy_check.tscn`, `tools/holka_shots.tscn` (`--part=stages` her art on pictures, `--part=hitch` her firsts timed with the pipelines compiled per long frame, `--part=probe` her run-time pictures timed, `--part=jam` with `--fixed-fps 30` her interference from all round and the find frame by frame, `--part=film` with `--write-movie` the real thing with its sound), the shot driver's `testgirl`, co-op `tools/coop_scare.py` (her face counts as the close-up or split down the middle) and `tools/coop_girl.py` (held by the host's torch, comes when unlit, theirs alone) |
| The mushroom granny (Mushroom Pickers) | `scripts/enemies/basket_brain.gd` (DESIGN §5a.4: the hunt along `staff_runtime.way`, the stop, the catch and the limp (`held_speed_mult`), lamps put out by her arm, the guests eaten lodging by lodging while you hide, `dawn()` from `main._claim_rings`); her hooks elsewhere: `radio_dread.relay`/`relay_off`, `window_lights.set_forced`, `nightmare_fx.set_spores` (+ `remote_fx`, `coop_night`), `GuestManager.make_room_carnage`/`shaken_leave` (a guest's `review_text`), mess_rules `carnage` + `interior_prep` arms, the tent's wall spot `w1`; art rows `tools/artgen/prompts_babka.tsv` (from `npc/host_pensioner.png`), sounds `tools/audiogen/prompts_babka.tsv` -> `assets/sfx/npc/babka/`; the way she came in left open: the tent's hole `materials/tent_tear.gdshader` + `interior_prep.tear` + `tent_interior._tick_tear` (the room's shared view of the camp through it), the smashed window `interior_prep.smashed_window` (cabin `_tick_smashed`, caravan `_tick_smashed`, spot `win`, mess_rules `CARNAGE_WALL`/`CARNAGE_WALL_SPOT`), seen from the camp `building_manager._refresh_tent_tear` / `_refresh_cabin_smash`, heard through `audio_manager.set_room_leak`; her eight views figure `babka_s0` (`tools/artgen/figure_prompts.py` BABKA); her rules `tools/enemy_check.tscn`, shots `tools/babka_shots.tscn` (`--part=tear|smash|look|windows|hitch`, `--sim=careful|careless|hidden`) |
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
| The bowling alley (KUŽELKY on the roof in both languages) | `data/buildings/bowling.tres` (3x5, Services, open from 40 guests: `goggle.TIERS`), model `building_models._bowling` (Grok's painted walls `camp/bowling_*` from `tools/artgen/bowling_art.py`, rows in `prompts_kuzelna.tsv`; the painted bulbs' glow map; the neon `lettering.py` "kuzelky" and BOWLING on the board "bowling"; the neon, the bulbs and their hum lit with the camp's lamps by `scripts/bowling/bowling_sign.gd`, sounds `tools/audiogen/prompts_bowling.tsv`; the fibreglass pin on the roof `scripts/bowling/pin_mesh.gd`, the regulation profile, also the lanes' pins), Builder views `builder_shots`/`iso_render` (`iso3d/bowling_*`); the rules of real ten-pin bowling `core/systems/bowling_rules.gd` (the lane in metres, the ball's way with its hook, a 2D sim of the deck, the card); what goes on in it is `scripts/bowling/bowling.gd` (group `bowlings`, made by `business_runtime`; a record per alley whether anybody is inside: the queue at the counter with shoe sizes, who is checked in, four lanes each with its party, card, standing pins, `set` "sweep"/"rack" while the pins wait, `seq` per ball and `last` {entry, res}; the shoe shelf and the pairs handed back; the host bowls every ball seeded, the hands (`ROLES` desk, pins) work by role; co-op ops `checkin`/`set`/`shelve` + the host's `snap`, `Coop.send_place("bowl")`, group `places_bowl`); the books' kind `bowl` in `business_rules.gd` (goods, menu, roles, gear); inside (InteriorManager module "bowling", `scripts/bowling/bowling_interior.gd`: the hall shows the record, the parties in the queue, at tables, on their lanes; it hosts the stations on the business frame like `service_interior`, `STATION3D`/`STATION_HUD`, BOOKS = `ledger_closeup` "bowling"): the hall `bowling_layout.gd` (four lanes squeezed along, to scale across, `lane_point()` maps the rules' metres; the counter, the snack bar, the tables, the masking mural, the pit trough with kickbacks and cushion, the walkway; `STATIONS`/`SURFACES`/`ENTRY_STATION`, `DESK_QUEUE`; Grok's `bowl_*` textures), each lane `lane.gd` (draws its record: plays a new ball, the step, the swing, the roll, the pins falling as the sim says and lying on the deck or in the pit until the record has them up; the chalkboard; the pins worked by the pit through `take_pin`/`stand_pin`/`pit_pin`/`send_ball`), the stations `desk_station.gd` (shoe sizes from the cubbies, the lanes' lamps, SERVE = `check_in` + pay, the pairs handed back sprayed and shelved) and `pit_station.gd` (behind each pair: the ball back, the deadwood off after a first ball, all ten stood after a frame, then `set_pins`) and `bufet_station.gd` (the snack bar: the lanes' orders `bowling.gd _bufet` by the place's wants of what is on the menu and the shelf, the steamer, the jar, crisps and Tatranky, the beer and Kofola taps held to the line, the tray, SERVE = `serve_bufet` sells the goods off the books; a hand on "bufet" serves; what was brought stands on the lane's little table `LAYOUT.snack_table`); a warden bowls on a free lane themselves (`lane_play.gd`, a click on the lane in the hall: stand, aim with the red chalk dashes, hold-pull-flick-let go = speed and hook; `bowling.gd take_lane`/`warden_ball`/`leave_lane`, ops `wtake`/`wball`/`wleave`, the visit `w:<who>`, pins set by themselves after `WARDEN_SET_SEC`; the gloved hand `hands/bowl_hold`, `bowl_release`); the pinsetting machines from the books (`GEAR["bowl"]`: `machine` the Stavomat S-12, `brnoswick` the Brnoswick A-2 with `"needs": "machine"`, checked by `actions.biz_buy_gear` and the ledger): `bowling.gd _machine` sets each lane after `MACHINE_SEC`, the Stavomat jams now and then (`MACHINE_JAM`, what is caught `JAMS`; every lane waits; a hand on "pins" frees it after `FIX_SEC`), `lane.gd` plays the machine's cycle (the setting table out from behind the masking panel, the sweep bar), the lamp in the masking panel's corner blinks red while jammed; the cellar `bowling_layout.cellar()` (its own room at `CELLAR_AT`, *over* the hall in its world: `retro_materials` discards whatever is under the ground for a camera under it) with `cellar_station.gd` (pull out the jam in tugs, crank back two turns, the lever; the Brnoswick's chrome parts `brn_*`), tabs by the gear (`bowling_interior._room_tabs`: the pits by hand, CELLAR with the Stavomat), a tab across rooms goes through `interior_manager._door_transition`; the score screens (`scoreboard`) make the chalkboards monitors (`lane.gd _dress_board`); sprites `assets/textury/bowling/` (sheets `bows_desk`, `bows_bufet`, `bows_pit`, `bows_cellar`, `bows_jams`, `bows_brnoswick`), sounds `tools/audiogen/prompts_bowling.tsv` (loops from `tools/audiogen/raw/` by `ambience_loop.py`), the guests' poses from behind `npc/host*_ball`, `_bowl` (`tools/artgen/bowling_prompts.py`, standing poses in `poses.gd`); shots `tools/bowling_shots.tscn -- --out=<dir>` |
| The cabin (its plan, the model, the room, each tier) | one plan for both sides `scripts/cabin_layout.gd` (`SIZE`, `WALL_H`, `windows(level)`, `ANNEX`, `BED`, room space = model space lowered by `ROOM_TO_MODEL`); the model `building_models.cabin` (each tier's dress: Lv1 grey boards and rust, Lv2 red boards, porch, flower box, bathroom annex, Lv3 dark boards, shutters, chimney over the stove, aerial over the TV, gutters, porch with bench and lantern), sized by `building_manager.place_cabin_at`; the room `cabin_interior.gd` (`_build_level_shell` per tier: `_wall_with_holes`, `_room_window` with its portal and curtain, `_level_furniture`; the bed, its pillow, the catalogue and the bucket shared; the bathroom `_build_bathroom_room` moved to the annex `_bath_origin()`, walked into through its door: `_build_bath_door` (the frame `_door_frame`, the leaf on `BathDoorHinge` swinging into the room, `CabinLayout.bath_door_z` in the annex's front half clear of the shower and the chair), `_walk_to(room)` (`WALK_PATH`, the stands `_main_stand()` / `_bath_stand()`, the tasks paused on the way; in the bathroom the room stays drawn and the head turns only `_yaw_limit()`; S there walks you back); in it `BATH_WC`, `BATH_SINK`, `BATH_BOILER` (the cleaning spots follow them), placed so that from the doorway nothing you clean is behind the Lv3 shower's curtain and the basin's click box is not on the line to the toilet's grime (the picker takes the smallest box on a ray); shots: scenarios `cabinwalk`, `bathmess`); a window's view is `_update_portals` through `_room_to_world()`; the curtain under the cursor glints `_update_hover`. A change to the model wants Builder's four pictures again (`tools/iso_render.tscn --only=cabin_1,...`, `iso_views.py sheet`, Grok `iso4_cabin_<n>_b`, `iso_views.py cut`) |

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

- **`PROJECTION_MATRIX[1][1]` is negative in this renderer** (its clip space has y down).
  A shader that sizes something in pixels from it (`2 * depth / (P[1][1] * VIEWPORT_SIZE.y)`
  metres a pixel) must take `abs()`: without it the least width never held and wires drew
  as dashes (4. 11., `wire_ribbons.gd`, the bus's lamp dots).
- **`get_meta(key, null)` still prints an error when the key is missing** (a null default
  is no default): `x.get_meta(k) if x.has_meta(k) else null`.
- **A Label3D leaves out the pixel fonts' one-stroke glyphs** (the I, the dash, the bar: in
  Jersey and Silkscreen alike they are solid rectangles in the font's page and come out
  blank in 3D; 2D text draws them). Words on a 3D surface go through
  `scripts/bowling/board_text.gd` (a 2D Label in a small SubViewport, drawn again only when
  the words change, shown on a quad: the bowling's boards and the cellar machine's plate).
- **Nothing under the ground is drawn for a camera under the ground** (`retro_materials`'
  fragment: the lake mirror's cut, camera y < -0.4 and the pixel's y < 0.1 are discarded).
  A room of its own world goes over the ground, never under it (the bowling's cellar sits at
  `CELLAR_AT` y 60 over its hall: built at y -40 it came out black).
- **Leaving is Esc or Space, the pause menu P or F10** (the user, 4. 11.): Esc leaves a
 room, the PC, a close-up or a job a step at a time (`INTERIOR_LOOK.is_exit_event`) and is
 the pause menu only outdoors (main `_unhandled_input`); Space leaves the same way wherever
 it is nobody else's (`INTERIOR_LOOK.is_space`; a close-up asks its `_key` first, so the
 till, the phone, a page and the PC keep it); P and F10 pause anywhere
 (`ui/pause_keys.gd`). The pause menu's CanvasLayer is 150, above every full-screen overlay
 (the check-in desk is 140); a new overlay stays below it. Leaving is also the bottom band
 or a right click; the pause menu's "Go outside" (`main._on_pause_leave_requested`) ends any
 room or job the way its own exit would. Back to the title screen closes them too, silently
 (`main._leave_everything(true)` in `_enter_main_menu`): a room left open went on taking
 clicks behind the menu. Always-processing modals return early from
  `_input` while the tree is paused. In a co-op camp the tree is not paused: the menu turns
  every other node's input off while it is up (`pause_menu._mute_others`, back as it was on
  closing; the walkie-talkie stays) and `HandCursor.menu_over` is set: something that reads
  the mouse in `_process` (room tasks, the scrubbing, a signature, a station's hand) must
  look at it.
- **Interiors live under InteriorManager (the full-res root view), not in World3D**: the
  world is drawn small and scaled up by the render style, and 2D inside it scaled with it
  (huge prompts). Rooms have their own 3D viewports; the office window portal gets the
  camp's world by hand (`_bind_window_world`).
- **A SubViewport hears no 3D sound unless `audio_listener_enable_3d` is on** (Godot's
  default is off). The camp's (main.tscn) had it off until 21. 10.: every
  AudioStreamPlayer3D in the camp (the enemies, world_sounds, the radio outside, the
  co-op voices) was silent and nobody could tell from the code. A new viewport with 3D
  sounds turns it on (the office room's only while it is open, else its sounds play
  outdoors); a sound heard through a building's walls goes on `world_sounds.wall_bus(...)`
  (a low-pass bus; the 3D player's own filter only works with distance).
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
 under a service room) sets `_no_step_out` around it. Since 4. 11. a room you walk into
 gives door_through its `door_spec` (scripts/ui/door_through.gd) and walks out through
 `interior_manager.leave_on_foot(self, structure, close)`; `_step_out_of(was, _through_eye())`.
- **What a camp view hides, nothing may give back**: window_shared_view hides a building
 from its camera by setting its meshes' `layers` to HIDE_LAYER and restoring them after; a
 script that ORs a layer into a building's meshes every second (business/room_lights.gd did
 for the crew) must skip the hidden ones, or the pub's own room stood in its doorway seen
 from inside (4. 11.).
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
 cabin's door, a tent crawled into from across the camp): a room built in its building says
 `"one_world": true` in its `door_spec`; `door_through` then makes no panes, leaves the eye
 where it is (`_to_room` identity), hides the doorway's dark (`<leaf>Way`) and the room's own
 shut leaf while you come through, and `door_ready` binds the room into that building at
 once. The room hides its host's darks while it stands there (`one_world_room.doorways` /
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
 (`_set_one_world`: `world_3d` null = the root's world, the room's WorldEnvironment taken out;
 the toilets, showers, generator and sewer get `_own_world` back) and binds the room where its
 building's own copy stands (`ONE_WORLD_COPY`: PubRoom, BistroRoom, JednotaRoom, the
 staffroom's `Inside`), the copy hidden while it does; the front room's walls are opened at
 its windows and its door (`K.open_windows`), the windows glass; a room behind the front one
 (the cellar, the kitchen, the storeroom) stands 60 m over the building (`BACK_ROOM_UP`, a
 dark box round it); put away 2000 m up when shut. The fronts' painted doors are cut out
 (`_glass_door_face`), the plinths are rings, the staffroom's under its walls only (its
 block under the floors fought them). By day, as the sun comes in, the front room's fill and
 lamps go down and its eye opens (`service_interior.DAY_*`, less than a lodging's: the
 stations want seeing). Only the toilets, showers, generator and sewer keep a world of their
 own (no windows). Walking up to a business's door brings up its people, stations and marks
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
  Godot's `@<Class>@NNN` (4.7: the class's name, not the node's: a second "Sill" is
  `@MeshInstance3D@123`): tell kinds apart by group or meta, not by name.
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
  - a sound only the quarry hears is `_sound_quarry` (meta `coop_quarry_only`);
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
- **Rebuilding the map data**: `python -I tools/geo/design_world.py` (no map data, the
  user's points only). Check `route_len` and the stops' `s` it prints after a change, and
  the times in `bus_timetable.gd` (7 minutes camp to Liblice, four runs a day; the clock
  slows during the ride to fit, the bus's speeds are `town_trip.RIDE_SPEED`). A wood or an
  orchard must stay off the roads (its trees are not kept off them in the game): the script
  says which one is too near.
- **Emission with a mask texture multiplies, it does not add**: StandardMaterial3D adds
  `emission_texture` to `emission` by default (a mask lit the bus windows white by day);
  set `emission_operator = EMISSION_OP_MULTIPLY`.
- **BoxMesh UVs are a 3 x 2 atlas**: one texture on a box shows a third of it per face;
  `uv1_scale` (3, 2) shows it once per face (`town_lesna._tiled`). Put art that must read
  whole (signs, facades, the bus's sides) on a QuadMesh.
- **The shot driver's eval is a Godot Expression**: no assignment (use `.set('prop', v)`)
  and no autoloads (`CoreRoot` is not visible); a subclass of `tools/shot_driver.gd` that
  sets `_steps` in `_ready()` after `super._ready()` runs ad-hoc scenarios.
  Nor type constants: `Vector3.UP`, `Vector3.ZERO` are a parse error (a warning in the log,
  the step does nothing): write `Vector3(0, 1, 0)`. One step a frame: fields an enemy's tick
  checks together (`_neck_from`, `_neck_until`) are set in an order its tick survives.
- **Rooms draw through their own viewports, far above the camp**: in a room
  `get_viewport().get_camera_3d()` is still the camera outside; the room's is
  `<interior>._interior_camera` (silent_man_brain `_room_camera`). The rooms' ceilings have
  no collision (find one by its mesh: `RenderingServer.instances_cull_ray`, which takes the
  ray as endless).
- **A 3D sound at the player's ear**: 0.3 m off with `unit_size` 3 it gets +20 dB and every
  one hits `max_db` (+3) alike; set its `unit_size` to the distance it is at
  (`_near_you` in the Silent Man and the Girl) and the gain written is what plays.
- **An enemy's ground**: `enemy_base._ground` casts from 20 m up and stops on roofs and in
  tree crowns (the Photographer stood up there a quarter of the time); spots go through
  `_stand` (refuses covered ones), steps through `_floor_at` (from over the warden's feet).
- **A ray from another warden's torch** starts inside their own body: pass them to
  `enemy_base._ray_blocked(from, to, [them])`, or it stops on them (till 4. 11. no
  other warden's torch ever held the Girl or the Silent Man; `tools/coop_girl.py`).
- **First-use hitches at night**: `main._prewarm_hurt` (when the night begins, and at an
  enemy's start) makes the night's layer, the hurt and the blood and draws them once
  unseen. A new material on the night's layer gets its see-through pixel in
  `nightmare_fx._ready` too (not the layer's own parts: a test reads them as a flash). Find one with `tools/holka_shots.tscn --part=hitch` and a cold cache (a fresh
  `APPDATA`): each long frame prints the pipelines compiled in it.
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
- **Trees are cone or blob plus cards**: `world_generator._tree_mesh` `spruce_cards`, `birch_cards`, `linden_cards` go with their crowns everywhere a tree is drawn (the crowns are only a dark core now: a crown without its cards is a dark lump). A new planting takes all three parts. Cards carry their own normals (out from the crown; `own_normal` in `tree_wind.gdshader`, the engine turns a back face's round) and their pictures have mipmaps (`filter_nearest_mipmap`: nearest, from a smaller picture far off, no glitter; only pictures imported with mipmaps change, set it in the `.import`).
- **Two faces on the same corners cancel**: a double-sided triangle through `generate_normals()` without `st.set_smooth_group(-1)` has zero normals, no light reaches it and it stands in the sky's colour (every gable did).
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
- **A one-world room's inside-only things** (its own front door, the rain on its glass, a
  cabin's own panes) are on `INVIEW_HIDE_LAYER` (bit 17), which the player's camera culls
  (`player_controller._ensure_camera`): a new such thing must go there too
  (`_hide_from_camp`). Office state that should show from outside must live in the room
  while it is shut (it is not `visible` then).
- **Faces, signs and boards on walls fight them** under the PS1 vertex snap (the snap moves
  the corners of a quad and the wall under it a different way; a centimetre between them
  is not enough). `retro_materials.gd` pulls every QuadMesh / PlaneMesh and every thin
  BoxMesh (under 6 cm) towards the eye along its own ray (`depth_pull`, a plain uniform on
  a material of their own: smaller quads more, so a sign wins over the face under it;
  never an `instance uniform` in that shader: every instance drawn with it takes a slot,
  they run out and the game crashed); keep new ones as such meshes and they are handled.
  The sun's shadow pass (an orthographic projection) gets neither the snap nor the pull,
  and the light and shadows are worked out at the true point under each pixel
  (`LIGHT_VERTEX` on the face's plane), so the faces warp and their shadows do not.
  Lettering (Label3D) is not redrawn by it: `retro_materials._pull_labels` puts every
  Label3D 1.1 % of its distance nearer its eye each frame (the board under it is pulled, the
  number was under its enamel). A thing that must stay over a pulled quad takes the meta
  `retro_pull` (a window's bar: building_models.WINDOW_BAR_PULL).
- **A room's light switch is its lamp's, nothing else** (the user, 25. 10., the third time:
  "fix the reception's light properly"): off is 0 for that lamp, never a share of it (14 %
  left a ring round the tube at night), and a switch or a power cut never scales the day
  through the window or the ambient (off by day took the daylight to a fifth). Check a light
  change by the picture's mean brightness: the office, lights on / off, day / night
  (12:00: 134 / 121, 22:30: 81 / 21 on 25. 10.), not by eye.
- **The eye's motion is the body's, never a wobble** (the user, 25. 10., furious at a sprint
  "shake" of 23-37 Hz sines: "like being shaken, linear up and down, mad fast"): a camera
  movement comes from a cause (a foot landing kicks a spring, a landing, a stop) and settles
  on a spring; nothing faster than the steps, no noise on top. Measure it before handing it
  over (the head's y, pitch and roll sampled while sprinting: reversals a second, the biggest
  second difference): the sprint is 3.6 steps a second, 4 cm, the nod a soft spring kicked
  per foot (player_controller RUN_NOD_*).
- **A building's footprint turns with it** (playtest 25. 10.: "the caravan turns only 180
  degrees"): an oblong one (2x1, 3x5) stands across on an odd quarter turn. The tiles it
  takes, its middle and its `grid_footprint` meta are `GridModel.turned(def.footprint, rot)`;
  its model is built along its own footprint and the structure turned. A placed one's
  footprint is the cell's `fp` (`grid.footprint_of(origin, def.footprint)`) or the meta,
  never `def.footprint` alone; `building_manager.place_building_at(origin, type, rot)`.
- **A spring stepped by the frame must hold at any frame time** (playtest 25. 10.: in the
  caravan "the view flies everywhere with the mouse"): `interior_look`'s sway was a stiff
  spring (w 16) stepped by Euler, unstable over 52 ms a frame, and the caravan's windows
  took the frame there. Step a stiff spring by its exact solution (interior_look) or clamp
  what it moves; check `4 - k dt^2 - 2 c dt > 0` at 0.1 s for a semi-implicit one.
- **A room's windows from the camp look through openings in its walls**: a window's glass
  (its portal) on a solid wall showed the wall's own boards from outside (the caravan,
  `caravan_interior._cut_walls`: the doorway and every window cut out; the windows across
  the room show the camp beyond it through the shared view, put back at the camp's eye).
- **D3D12 resource descriptors** (`rendering_device/d3d12/max_resource_descriptors`, raised
  to 524288 on 25. 10.): the default 65536 ran out after a long session; every draw past it
  failed (black screen in the busy directions) and the log took hundreds of errors a frame.
- **Label3D is unlit by default**: paint on a board or a wall needs `shaded = true`, or its
  letters shine on the air at night with the board gone dark (4. 11.: the sluice's board,
  the buildings' signs). Lit signs (the bus's boards) stay unshaded.
- **Springs in `_process`**: a long frame's delta thrown at an explicit spring multiplies its
  speed; step it in hundredths and cap the time (`player_controller._update_head_motion`).
  A fast clock (`Engine.time_scale`) finds these: the head's speeds ran off to infinity and
  the whole view went NaN (`tools/soak_check`).
- **Frame times on the dev PC**: it has 16 GB and Unity, Grok Bot and other sessions' Godots
  run beside you. Look at the free RAM and the other processes first: at 3 GB free one run
  had an 81 s frame (paging). A frame-time failure only counts when it repeats on a quiet PC.
- **First-time loads**: what is built the first time costs its pictures and sounds from
  disk, not the building (the land 265-947 ms cold, 25 ms warm). Read them on the loader's
  threads while something else is on screen (`builder/warmup.gd`, `town/land_warmup.gd`).

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

- **People from eight sides** (DESIGN.md §10b): `tools/artgen/figure_prompts.py` writes
  `prompts_figures.tsv` (who everyone is, piece by piece: FIGURES; the idles; the poses
  from five sides; the family's new people BASES), `tools/artgen/figures.py batch <fig> turn
  walk1..5 run1..5 idle1 pose_<p>` runs Grok sheet after sheet (a variant more when one
  does not cut into the right number of figures), `figures.py all <fig>` stages, checks,
  draws the contact sheet (`out/fig_<fig>/_contact.png`, `_walk.gif`, `_run.gif`) and packs
  the atlas. What was learnt on the pilot (Pepa): one picture per view (a row of four
  frames), never one per frame; the reference is the front sprite x4 on magenta beside the
  picked turnaround (`figures.py ref`); ask for "a walk cycle" and Grok draws one stride
  four times: name each frame by its shape (STRIDE, PASSING standing on one leg with the
  other knee lifted, "this frame is narrower than frame 1", "each frame a clearly
  DIFFERENT pose"); the five views as "turned toward the right edge of the image" (2, 3,
  4) so 6-8 are mirrors; the frames are snapped to the colours of the person's own front
  sprite (nothing can drift) and scaled per sheet (the turnaround by its front figure, a
  walk by its tallest frame x0.985, a run x0.95); the magenta rim is taken off at Grok's
  size before shrinking (it came out as red flecks on the nose). Picks by eye go in
  `tools/artgen/figure_picks.json` (`mirror`, `order`, `k` per sheet). Never run two
  queues with the same ids, and never kill a `gen.sh` without its agent: a second agent
  at once swaps outputs, and a waiting copy of an id deletes the finished picture.
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

**The catalogue goes before the scripting does**: `lang.gd` is a Translation made from a script
and the server keeps it to the end, past the scripting's own: every Czech game crashed as it
closed (exit 139, nothing in the log, English never), until GameSettings' `_exit_tree` called
`LANG.release()`. A run that crashes on quitting only in one language: look here first.

The user, 21. 10.: "the language is the warden's, flags when a warden is made; the whole
game in Czech; from now on everything we make, in English and Czech".

- **How it works**: the code is written in English; `godot/locale/cs.po` (gettext, the
  English text is the msgid) holds the Czech. `scripts/lang.gd` reads it (the file is kept
  as is, `cs.po.import` = keep) and answers every lookup the engine makes: Controls,
  Label3D and RichTextLabel translate their own text, so most code needs no change. The
  lookup also answers an UPPER-CASE copy of a msgid (menus upper-case their rows), a
  lower-case one ("rolls" for the msgid "Rolls": a word the code lower-cased for the middle
  of a sentence), a formatted one ("3 CAMPS" from the msgid "%d CAMPS": the values carried
  over, a %s value looked up itself, "3 guests" in it too), a line wrapped in non-words
  ("<  Plum  >") and text line by line. A web page's link `{site.cz|Label}` is not taken
  for forms (a first part with `.`, `/` or `:`).
- **The language is the warden's**: `profiles.gd` "lang" ("en"/"cs"), the flags on the
  WARDEN page (a new warden starts on them; the system's language is the default),
  `LANG.apply()` when a warden is chosen. `-- --lang=cs` on the command line overrides it
  (tools, shots: never switch the user's own wardens to test).
- **What you must do in code**:
  - Text drawn with `draw_string` / `draw_multiline_string` is not translated by the
    engine: pass `tr(text)` (in static code `LANG.t(text)`). Translate *before*
    `to_upper()`, padding, measuring or cutting it.
  - Text put together from pieces ("Hello " + name) is never found: write it as one
    format string. Drawn: `LANG.f("Hello %s", [name])` (26. 10.), not `tr(fmt) % vals`:
    a lookup chooses a translation's `{a|b|c}` forms before the numbers are in (always
    the 5+ form), and a translation may leave out a `%s` the code fills with an English
    ending (`"%d bill%s"` -> `"%d {účet|účty|účtů}"`, or `{noc|noci|nocí|%s}`: a fourth
    form never chosen) or put the values in by `{k}`; `LANG.f` writes each value as the
    English asks, fills them in as a formatted lookup does and then chooses the forms.
    Text set on a Label/Button is translated by the engine after it is filled (the same
    filling), so `label.text = fmt % vals` is fine there.
  - A key, arrows, a name or a number put round a text ("[E] %s", "< %s >", "%s: \"%s\"",
    "FAMILY 12%") is no catalogue's whole: look the text up first (`"[E] %s" % tr(hint)`,
    `"< %s >" % tr(value)`). A format whose words are two letters ("IN %d:%02d") is no
    template either: `tr(fmt) % vals`. (2. 11.: the HUD's hints, arrivals and risk, the
    options' values, CampMail's folders, sort heads, booking and review cards were English.)
  - A web page is its pieces joined with `HR` (`os98/web_pages.gd`): the browser looks
    each piece up (`browser_app._page_in_language`; the whole was never found and forty
    pages stayed English till 2. 11.). Text a page builds at run time (`{{bazaar}}`, the
    guest book) goes through `tr` / `LANG.f` where it is built.
  - The fonts are BMFonts with a fixed set of glyphs; a character they lack is drawn as a
    box. `python tools/i18n/font_gaps.py` lists what the Czech uses that a font has not
    („ was in none and – not in the PC's `w95`: added 2. 11. as entries reusing a glyph the
    font has). The register's 3x5 hand draws a Czech letter as its plain one with a dot
    above (`checkin_desk.HAND_MARKS`).
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
  `-- --lang=cs` (scenario `menupages`: every title page). Find what is left: the shot
  driver with `-- --lang-audit` writes `<out>/lang_missing.txt` when it is done, every text
  asked for in Czech that found none, with the script that asked (2. 11.: 32 scenarios;
  what stays is names, Czech looked up again, the BIOS and the debug menu).
- **Words** (keep them the same everywhere): warden = správce, camp = kemp, guest = host,
  booking = rezervace, sandbox = volná hra, story = příběh, the Builder stays Builder,
  CampMail/CampStat/GuestRack/Atlas and the like keep their names; the player is "ty".
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
