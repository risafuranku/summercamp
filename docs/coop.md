# Co-op and instances

Two to four wardens, the host's authority, and the split screen's instances.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

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

- **Co-op in a room**: the room you are in is yours (built on your machine where its building
  stands), so the other warden there is a second
  `remote_player.gd` (manual) in the open interior's room,
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

- **Warden looks** (`warden_looks.gd`): a jacket colour is the jacket's pixels moved to
  another hue, found by hue band, rows per pose and boxes left out (boots of the same
  green: `JACKETS`); a new warden or pose needs its entry, checked on a sheet of all
  colours. `Texture2D.get_image()` hands back the texture's own image: duplicate it
  before changing it, or every colour after the first comes out the same.

- **Co-op on the bus**: the ride's state carries the bus's place (`bus_ride.coop_state` "bt", "v", "d"); the other machine shows it as `town_trip._mate_bus` (eased between the 15 Hz states, taking over from the stop's bus that pulled away with them). `town_trip.debug_mate` feeds it a state for screenshots.

- **A co-op client's clock runs by itself** (`main._coop_run_clock`): the host's word four times a second only corrects it, softly, and over midnight at once. The bus, the road and the guests on them are worked out from the clock every frame.

- **The radio's night is the host's:** `dr`, `tn` in `coop_radio_state`, each event goes over with a seed (`radio_ev`), a client draws none of its own.

- **The game runs as instances** (TODO.md SPLITSCREEN, scripts/instance/instance.gd): a
  split screen is a co-op host and a local co-op client in one program, each with its own
  main and its own Coop, CoreRoot, EventBus, GuestManager and EmailManager (the host's are
  the autoloads at /root, a local client's are children of its branch). In code that runs
  for an instance never write the autoload's name before a member: `INSTANCE.core(self)`,
  `INSTANCE.bus(self)`, `INSTANCE.guests(self)`, `INSTANCE.mail(self)`, `INSTANCE.coop(self)`
  (a RefCounted helper: its owner node instead of self; an enemy brain: `_world_root`), and
  never `get_tree().current_scene` for main: `INSTANCE.main_of(self)`. Constants stay
  (`Coop.Role.HOST`). One instance costs nothing (`INSTANCE.count` is 1). The scripts that
  routed the old calls: tools/refactor.
