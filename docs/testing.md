# Running, checking and seeing the game

Every harness, the screenshot driver, co-op runners and how to keep out of the user's way.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*


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
godot --headless --path godot res://tools/pub_check.tscn        # the pub: the tap from the books, Papa's serve, the hands, the stations
godot --headless --path godot res://tools/stand_check.tscn      # the corn stand: the pot, the bowl, the orders, Papa's serve, the hands, the stations
godot --headless --path godot res://tools/jednota_check.tscn    # the Jednota: the rack, the queue, the till, boxes, the hands, the stations, it pays
godot --headless --path godot res://tools/proto_check.tscn      # PROTOTYP 540: awake hours, the sack's nights, fed, the meat in the stock
godot --headless --path godot res://tools/pa_check.tscn         # the PA poles (24. 11.): the building, pa_rules, a light sleeper by a pole after ten
godot --headless --path godot res://tools/site_check.tscn       # building takes time (25. 11.): the hours, the workers' day, an order as a site, RequestBuild at once, the work, done, a site taken down, the clock
godot --headless --path godot res://tools/podniky_check.tscn    # the businesses' polish: thirst, the Jednota's bag, the rush, corn drinks, the grill, the bufet, the deli, the Z mark
python godot/tools/podniky_coop.py [OUT_DIR] # the four places for two: a drink, a bill, the slot, the grill, the bufet, the deli done on one machine and seen on the other
python godot/tools/coop_check.py [OUT_DIR]   # co-op: two windowed copies (host + client on 127.0.0.1), camps compared; looks, a build, a room's jobs both ways, the boat
python godot/tools/boat_coop.py [OUT_DIR]    # the boat for two: the other rows out (their oars stroke on the host's lake), rides in the host's bow, both ashore apart, back in the bow, both out
python godot/tools/coop_photo.py [OUT_DIR]   # co-op Photographer on the joining warden: the white and their polaroid, the run at their back, at their window, the last picture: theirs alone
godot --headless --path godot res://tools/post_check.tscn      # the second monitor: the order paid, the van on the clock, the postman at the counter, the slip, two screens and the swap, the keys, the save, the postman who gives up
python godot/tools/post_coop.py [OUT_DIR]   # the second monitor for two: ordered on the joining machine (paid once), the host's van and postman on both, signed for there, the monitor on both
python godot/tools/desk_coop.py [OUT_DIR]   # the reception's counter for two: the check-in drawer the host pulls out and in goes out and in on the other machine (in the office, and out of it: it is out as they come back), the other's pulled out at the host's, two at once go the host's way
python godot/tools/site_coop.py [OUT_DIR]   # building takes time for two: the host's ordered cabin and the other's ordered pub stand as sites on both, and as the cabin and the pub on both once the host's clock did the work
python godot/tools/bowling_coop.py [OUT_DIR] # the bowling for two: the host at each station, the other in the hall sees it: the bufet's tray, the beer under the tap and onto the tray, the pit's pin in the hand (where it is held) and in the pit, the counter's lane, the cellar's crank
python godot/tools/office_figs_coop.py [OUT_DIR] # the other warden in the office as the host sees them: standing, at the desk (on their feet), to the PC behind your back (a picture every 0.15 s), the shoulder at the taken PC
python godot/tools/voice_coop.py [OUT_DIR]  # the voice for two: the walkie in both bags, V the own voice ("local"), a click the walkie ("radio"), the choice kept, the megaphone set at the three horns nearest (the packets: no microphone here)
python godot/tools/window_coop.py [OUT_DIR] # the reception's windows for two: from outside the joining warden sees the host at the PC, in the back room, the curtain drawn, the lights out
python godot/tools/sleep_coop.py [OUT_DIR]  # to bed for two: a tent each (host first, client first), office and tent, one kept awake; the night passes for both at once, both wake at the alarm
python godot/tools/down_coop.py [OUT_DIR]   # a warden knocked down at night: their torch left lit in the grass, seen by the other at 4, 10 and 18 m (and with yours off); theirs is your torch at 0.85 (remote_player.THEIR_TORCH, the numbers player_controller's own)
python godot/tools/rooms_coop.py [OUT_DIR]  # the rooms seen from the camp for two: the door swings before the warden is through it, their figure goes from window to window in the room
python godot/tools/coop_mail.py OUT [SAVE]  # mail for two in a camp hosted from a save (a sandbox camp saved, or a copy of SAVE in the host's own APPDATA): bookings keep coming, both inboxes alike
godot --headless --path godot --script res://tools/night_swell_check.gd   # the nights by the guests: a step at a time, up and down, what the night may have
# windowed, --audio-driver Dummy, -- --out=DIR: res://tools/theatre_check.tscn   what comes down from the god cursor against the rooms in buildings: the cabin's leaf, two vans
# windowed, --audio-driver Dummy, -- --out=DIR: res://tools/env_shots.tscn   the camp's light through a day (dawn to night), fog, rain; --part=twilight: 5:24-6:30 and 18:53-20:06
# Playtest 4. 11. checks (windowed, --audio-driver Dummy, -- --out=DIR):
#   res://tools/dvere_check.tscn     every building's door in and out on foot (pictures of the doorway, frame times)
#   res://tools/okna_check.tscn      the cabins'/caravans' windows from afar (the baked room cubes) against the live view; --part=dump|debug
#   res://tools/hlasky_check.tscn    the pager's and feed's lines as the player reads them, "EN" for any still English (-- --lang=cs --lang-audit)
#   res://tools/hover_check.tscn     the reception's glints from behind the counter and from the bench (run alone: it moves the real pointer)
#   res://tools/kukurice_hover.tscn  the corn stand's glints under the pointer
#   shot_driver --scenario=torch_cone      the torch at the office's front at night: the new beam, then the old one, the same frame
#   shot_driver --scenario=at_desk_notice  the pager's "is at reception" at the counter, not at the barrier
#   shot_driver --scenario=settings_tabs   the configuration's tabs: the title's printouts, then the pause menu's plate
#   res://tools/stand_look.tscn      the corn stand's eyes (24. 11.): the way in round the counter's end, W let go (the look stays), Q/E (it goes with you), Space tapped (serves) and held (away)
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
#   res://tools/noc_check.tscn       the night and the month's end played one by one (run with its own APPDATA, it saves): the Antlered Man seen and lost at a door, no window looked at from the PC, the PC on its UPS with a bill unpaid, the boy's job, the granny's bulbs, a catch holding you, dawn, your health in a save, the black after the bite: "NOC: PASS"; --part=report: the books with everything on them, at any --resolution, measured and shot
#   res://tools/smycka_check.tscn    the core loop's holes played one by one (the checklist's bill, the corn stand, Mirek writing again, a building bulldozed, a guest storming off, deleted letters, the line at the desk, the left button on a door, the torch by day, a night loaded): "SMYCKA: PASS"; --part=hands (the made bed by day, the catalogue's grey line, the stand's Z report, the left button at the fire, E and Space on the far shore), --part=books (every page of every place's books as shots, --lang=cs)
#   res://tools/smrk_check.tscn      a walk into a spruce: held off at its branches' tips, crouched in under it, eased out standing up; what the branches cut off on the map
#   res://tools/smrt_check.tscn      dead and back: a warden's camp saved, killed, LOAD LAST SAVE straight in (run with its own empty APPDATA: it makes a warden)
#   res://tools/provoz_check.tscn    the camp running without you (8. 11.): every building and a full crew, then days on a fast clock with nobody at the keys (--days=N --speed=K, --hands=none for the camp alone, --accept=1 to answer the letters as a player would): an hourly line "PROVOZ d3 14:00 ..." (cash, letters, who is where, the plates as they stand with their "(who)"), a day's sums, the screen and the plan at set hours, CampStat's pages; --part=office (the hand at the reception, three ways you look), --part=books (the staffroom's book, a place's ORDER page, Personal 98, CampStat's first page; with --lang=cs)
#                                    --money: at 11:00 on the last day every book and office program with the real days in them (--days=3 --lang=cs, 1366x768)
#                                    --part=boss: every page of Boss 98 in a minute, on a made-up week (--lang=cs)
# W26 one world (5. 11.; windowed, --audio-driver Dummy, -- --out=DIR --part=...):
#   res://tools/onesun_check.tscn    sweep: the reception by the hour, three views held still; ratio: the sun's square on the counter
#                                    and the back door, with and without the sun (scratchpad patch_stat); out / glass: the reception
#                                    from the camp; rain: 35 s of rain inside; weather; lights (every light near the room); perf (what
#                                    each viewport draws); cabin (--quick: noon only): cabin_1 inside and out;
#                                    recgraze, recwalk: the reception along its walls, roomsgraze (--rooms=pub,cabin_2): the other
#                                    buildings, with their room and without, then python godot/tools/room_diff.py DIR [type_];
#                                    recwin: into its windows by the hour after walking out; rechis: somebody's own last camp;
#                                    recrain: the rain on its glass, a held flash; bizday: the businesses' windows by the hour;
#                                    wedges; unpair (--build=cabin_walk ...: free_lights names the light of the engine's message);
#                                    svcwalks (--rooms=toilet_block,shower_block,power_generator,sewer): in and out of both toilet
#                                    doors, the showers, the generator (and its switch room), down the sewer, frame by frame;
#                                    townrooms (--rooms=jednota,pub,kiosk,motel,wc,chapel): Liblice's places by day and night, from
#                                    the street, inside looking round and out, the motel's corridor and number four, outside after;
#                                    towndoors (--rooms=jednota,pub,kiosk,chapel,wc,motel): into each on foot through its door and
#                                    out again, frame by frame (door_anim's leaves printed: hung, angle); moteldoors: the motel's
#                                    doors inside on foot, reception > corridor > number four > its bathroom and out > corridor >
#                                    reception (--timed: no pictures, "ONESUN click" each click's hold, "ONESUN frames");
#                                    motelwarm: what the motel's inside reads the first time (land_warmup.MOTEL)
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
- Benign headless only: `Parameter "t" is null` (texture_2d_initialize) and `Parameter
  "material" is null` (material_get_instance_shader_parameters), a handful a run, no script
  frames: the dummy renderer's; a windowed run has none.

Scenario `bookingcard` (24. 11.): a letter from each kind of guest and a tempting big party in
CampMail, each card shot on the CRT (`card_*.png`); with `--lang=cs` the Czech, which wraps
more. The card must show no scrollbar.

Scenario `pda` (24. 11.): a message buzzing in with the PDA away (the bell in the corner), the
PDA up and each app (home, messages, plan, tasks, clock, snake), the backlight at night, down,
and with the bag as TAB opens it (the bag on the right). Scenario `pa_pole`: a PA pole built by
the office, seen by day, from afar and at night; `PA` evals say it plays the reception's set, and
a forced night drift (static, a voice, the radio ducked and back).

### The money over a month: economy_sim

`godot/tools/economy_sim.tscn` (24. 11. 2026) plays a sandbox month on the real rules
without 3D and without the nights: EmailManager's bookings, every party accepted, let in
and every room made up at once, GuestManager's payments, the electricity bill paid the day
it comes, and the camp built each morning from what it earned (`--play=careful`: beds and
what the guests need; `--play=lazy`: tents and one toilet). It prints the cash, the guests'
money, the power bill, beds, how full, the mood and the reviews day by day. It is the
balance's measure, not a check (asserts nothing, not in `tools/checks.py`), and slow: a
month is 10-20 minutes, so run it in the background.

```bash
godot --headless --path godot --audio-driver Dummy res://tools/economy_sim.tscn -- --play=careful --days=31
```

What it cannot see: the nights (a hurt warden, enemies that keep guests in), the Atlas
stars pulling the bookings (no main scene), the businesses, a player slower than the
diligent warden. Numbers of 24. 11. are in the diary (`context/summercamp.md`).

### Seeing the game: the screenshot driver

```bash
godot --path godot --resolution 1280x720 res://tools/shot_driver.tscn -- --scenario=<name> --out=<dir>
```

A windowed run (the driver, and every check built on it) keeps out of the way of whoever sits
at the PC (the user, 12. 11.: "every test opens a window and I have to alt-tab to get my mouse
back"): its window cannot take focus and starts minimised, then sits in the screen's bottom
right corner (`shot_driver._stay_out_of_the_way`; `--keep-focus` after `--` turns that off for
a run you watch). Screenshots need a window: headless draws nothing. Frame times measured in the
corner came out longer (`dvere_check` 12. 11.: medians about twice those of a run in front):
measure smoothness with `--keep-focus`.

**Every windowed run goes on a desktop of its own** (the user 22. 11.: "it drives me mad how you
keep jerking my mouse while I am working"): a test window that captures the mouse for the look clips
and centres the real cursor even unfocused and minimised. `python tools/hidden_desktop.py --log LOG --
<godot> <args>` runs one there and waits (a second Windows desktop: its own pointer and keys, never
shown, it still renders, the shots come out the same); the two-machine runners (`godot/tools/*_coop.py`,
`coop_check.py`, `coop4_check.py`) start their copies there (`HIDDEN.popen`). Headless runs need none.

Scenarios: `boot menu views hud quest pause gameover crt crtmap weather upkeep blood night backroom shed boat
saveload guests pipes senses uncanny look gate prep prepcabin mess blockclean day night2 night3 breaker probe`.
A night's shots need `["torch", true]` (the torch's own switch, F): since 14. 11. nothing turns it on by itself, and without it the enemies' shots are black.
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

## Traps

- **Bash heredocs with long inline Python sometimes fail**; write the script to a file.

- **The shot driver's mouse steers interior looks**: warp it to the centre
  (`get_viewport().warp_mouse(...)`) before shots of a look-around view. A station's view
  (station3d `_look`) turns the head toward a pointer left at the edge: the bowling's station
  shots looked at the wall until `bowling_shots` warped it first (24. 11.).

- **The hidden desktop's 1280x720 window has a 1264x681 client area**: the HUD's scale is 2
  there, not 3 (a real 720p window is the same; fullscreen is 3). The PDA keeps 3 at least.

- **Testing co-op on one PC**: a copy of the game takes ~50 s to boot beside another, and
  the joining one stops answering for tens of seconds while it builds the camp (ENet is
  told to wait a minute, `Coop._patient`). The console binary starts the game as a child:
  end the tree (`taskkill /T`), or a stray copy keeps the port.

- **The shot driver's eval is a Godot Expression**: no assignment (use `.set('prop', v)`)
  and no autoloads (`CoreRoot` is not visible); a subclass of `tools/shot_driver.gd` that
  sets `_steps` in `_ready()` after `super._ready()` runs ad-hoc scenarios.
  Nor type constants: `Vector3.UP`, `Vector3.ZERO` are a parse error (a warning in the log,
  the step does nothing): write `Vector3(0, 1, 0)`. One step a frame: fields an enemy's tick
  checks together (`_neck_from`, `_neck_until`) are set in an order its tick survives.

- **Measure frames on an idle machine**: another session's headless browsers took 82 % of the CPU and last night's build ran at 40 like today's. `tools/fps_check`; compare with a `git archive` of the old commit and a copy of `.godot`, turn about.

- **Python in the Bash tool**: the tool turns a doubled backslash into a single one before
  bash sees it, so an escaped backslash at the end of a line in a heredoc reaches Python as
  a line continuation (the replacement silently changes nothing); write such scripts with
  the Write tool to a .py file instead.

- **Frame times on the dev PC**: it has 16 GB and Unity, Grok Bot and other sessions' Godots
  run beside you. Look at the free RAM and the other processes first: at 3 GB free one run
  had an 81 s frame (paging). A frame-time failure only counts when it repeats on a quiet PC.
