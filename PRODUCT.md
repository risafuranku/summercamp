# PRODUCT.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-16*

## What it is

A two-halved game set in a decaying post-communist summer camp you inherit from your aunt
Vera: shut since last summer, wanted by a firm for a feed mill, and you have a month, the
autumn of 1998, to show the district it is open and paying.

- **Day: a tycoon on the office PC.** A Windows-95-like terminal in the reception: CampMail
  (bookings, story, bills), Builder (an isometric 1:1 map of your camp, RollerCoaster Tycoon
  style, with your guests walking around in it), Camp Status, Finance, GuestRack, a browser (Beeternet Explorer 4: cool toolbar with icons, menus, Favorites/History, globe throbber, Links band, status bar with progress and zone; pages with background tiles, rotating GIF banners with a night frame, [blink]/[marquee]/[rainbow], weather with icons and forecast, a search engine, a band page, the Water Board, the camp team). Okna 98 boots through the maker's screen to its own splash, shuts down with its own screen; desktop context menu, Display Properties (wallpaper, screen saver), Flying Okna screen saver.
  You can also walk the camp in first person: talk to guests, service broken buildings.
- **Evening: the bill comes due.** At 20:00 the builder locks. Each guest archetype has a
  night threat; the more guests of one archetype you booked (and the unhappier they are),
  the likelier its enemy spawns. The forecast is always visible before you commit.
- **Night: first-person horror** in the spirit of Slender and Five Nights at Freddy's:
  flashlight with a battery, lamps as safe ground, enemies with readable tells.

The pitch in one line: **RollerCoaster Tycoon on a haunted office PC, and you have to sleep
on the campsite you built.**

## Tone

A serious mid-90s Build-engine product — Duke 3D / Redneck Rampage status bar, pixel fonts,
256-colour palette, chunky low-res 3D — made by someone slightly wrong. Mostly it is a
competent, even charming management game. Occasionally a detail is off in a way that makes
you look over your shoulder: one guest too many on the map, staff procedures that say
"Incidents are not to be reported", a face in the HUD that widens its eyes.

## Feature status

**Legend:** ✅ working · 🟡 partial / needs work · ❌ not built

### Front end and presentation

| Feature | State | Notes |
| --- | --- | --- |
| Title screen over a live camp flythrough | ✅ | Continue (with day/time/cash), New, Load (save list), Configuration, Controls; behind it `menu_flythrough.gd` cuts between slow dolly/crane shots (out on the jetty past the boat, the corn and pylons, the gate's bulb, the office, the boathouse across the water, the camp from above and back across the lake; a campfire and the cabins once built), each in its own time and weather, dips to black between them; shots dodge the trees of each camp |
| Pause menu (Esc), autosave on quit to title, pause on alt-tab | ✅ | in a co-op camp the world goes on behind it (no pause, no alt-tab pause) |
| Co-op for two, stage 1 and parts of 2 and 4 (`scripts/coop/coop.gd`, autoload `Coop`) | 🟡 | menu CO-OP: host a (sandbox) camp, this machine's addresses beside it, or join (the address typed into the row, remembered); who you are (Pepa, Ondra, Jana, Bara) and your jacket's colour (9; `scripts/coop/warden_looks.gd`, the warden drawn beside the rows); ENet, one guest. The joining machine gets the host's whole camp (the save snapshot, ~5 KB packed) to the tree, then the host's clock, weather, power and till, and the host's builds, demolitions, repairs and upgrades as they happen; each warden sees the other walking (`scripts/coop/remote_player.gd`: Grok sprite, the guests' walk, their torch beam and bulb, their steps), in the room they are both in (standing about, or at their job: the broom, down on a knee scrubbing; in a tent lying on their belly) and rowing the one boat (it is where they have it on both lakes; not yours to take till it is back). The joining warden goes into tents, cabins and caravans and does their jobs (done in the host's camp, the room comes back to both); the rest of their hands, sleep and the PC come next. `tools/coop_check.py` runs two copies and compares them |
| Sandbox camp | ✅ | no month, no checklist, the programs already on the PC, the story's mails without the deadline ones; co-op camps are always sandbox (saved with the camp: "mode") |
| The same camp after a load | ✅ | the world has its own seed (lake, fences, corn, litter, horizon) and the trees and corn are saved where they stand (cleared land stays cleared; each tile's tree is its own) |
| Build-engine HUD (status bar, feed, objective tracker, guest card, banners) | ✅ | crisp bitmap pixel fonts, integer scale at every resolution |
| Screen-space objective marker | ✅ | edge arrow when off-screen / behind |
| Low-res render + 256-colour palette, settings presets | ✅ | |
| Window title / logo "Cursed Camp Manager Simulator" | ✅ | |
| Twelve-frames-a-second feel | ✅ | into and out of every building the frozen frame steps closer (or back) and breaks up in a dither of game pixels into the new view (`ui/door_transition.gd`); the reception's camera moves (sitting down, standing up, looking back, leaning to the window, the walk to the back room), the A/D room swipes and the step bob outdoors move in steps (`ui/step12.gd`), like the fire and the torch hand |
| Studio splash: UNDO LABS, POWERED BY GODOT | ✅ | neon signs on a cabin wall at night (Build palette with the mosaic's ramps, shade-stepped light), in beats: UNDO LABS dark, the mosaic strikes diagonal by diagonal and the name after it, it burns a while; the view slides slowly down the cable to POWERED BY GODOT, still dark, which then lights up in its turn (moths stay with their sign, leaves blow through on a light wind); then it all fades out through the palette and the title card fades in (main then shows the same card); plays while main.tscn loads; the engine boot image is its first frame; Esc, space, Enter or a click skip to the fade |

### Day: management

| Feature | State | Notes |
| --- | --- | --- |
| Vera's Checklist (16-step onboarding questline) | ✅ | tracker, rewards, waypoint, three mails only (the opener, "The book", "Tonight"); the tracker column shows only while TAB is held (outdoors beside the site plan, indoors alone). Starts with the old cabin: patch it up (R), clean it, make the bed; then the programs from the links in Vera's opener (a click downloads them; CampStat is preinstalled) |
| The old cabin by the office (`main._place_ruined_cabin`) | ✅ | a new game starts with it rotten (condition 6%, broken) and boarded up, weeds up the walls, roof sheets in the grass; no bookings until it is patched up; inside dark (window boarded, bulb dead), cobwebs to sweep down, every mess there is; saved with the game |
| CampMail bookings with night-risk impact | ✅ | CampMail 3.0 (`os98/apps/mail_app.gd`): folder tree (Inbox, Sent, Deleted), cool toolbar, sortable list with envelope icons and attachment marks, From/To/Date header, quoted lines, spam with pictures (Grok, `textury/mail/`), reply/forward/compose (`EmailManager.send_mail`), Delete/Ctrl+R/Ctrl+N/F5 |
| Arrivals: road, gatehouse, barrier, waiting parties | ✅ | HUD ARRIVALS panel counts down; the barrier lifts as a party arrives, they walk up the starter path and queue at the reception (first at the counter, second on the bench, the rest at the door), give up after ~2.5 h |
| Starter path gate → reception | ✅ | laid by world gen through the barrier, up the gate lane, turning in front of the reception door; the bulldozer cannot remove it (meta `permanent`); the road outside wears the same dirt track |
| Out of the camp: barrier, road, bus stop, bus 380, Lesna | 🔨 | click the barrier (`trip_barrier`, click-only collision layer 12) and it stays up 10 s, never comes down on you (`camp_gate.gd open_for_player`); `scripts/town/road_south.gd` (built by world gen with the gate) carries the gravel road ~250 m through spruce/birch walls (invisible verges) to the stop CERNE JEZERO, KEMP: concrete shelter, bench, sign, a lamp that flickers at night, a gravel loop where the bus turns; the timetable case opens a close-up sheet (`timetable_closeup.gd`) printed from `bus_timetable.gd` (line 380: camp 6:15/13:50/19:15 to Lesna, in 5:45/13:20/18:45; noticeboard note and the CSAD web page agree); interactions out there go through InteriorManager module `trip` → `scripts/town/town_trip.gd`. The bus (`bus_model.gd`, Karosa from Grok faces composed by `tools/artgen/town_art.py`, door folds open, windows lit at night, wheels and body in steps) runs by the clock at both stops (in, stands, out; held while you are on board); click it while it stands → `bus_ride.gd`: its own small world (cabin on render layer 2, the game world's sky/sun/fog copied in), restricted look, the ticket machine close-up (`ticket_closeup.gd`: fare buttons, coins = cash, ticket prints in steps, sometimes jams → thump it; half fare/dog/bag tickets the driver refuses), the driver talks, click a seat → doors shut, ~1 min ride (cruise 17 m/s) past the Vysocina of `ride_scenery.gd`, 60 m pieces in route order: the camp's spruce wood (thick, a wall of needles behind it, the camp's own grass), a wayside cross with a deer that bolts, the reservoir behind a rail, cows behind an electric fence, corn walls right up to the road (layered quads + cross-quad plants), stubble with straw bales, a ploughed field with a tractor working it and a power line, an apple alley, the JZD cowshed with a silo and a dung heap, the LESNA sign, the village church (Grok front) on the green, farmhouses gable-on with fences, a cyclist; white road posts with reflectors every 25 m, grass verges and a ditch; oncoming cars, a figure by the road at night), then out at the other end. Lesna (`town_lesna.gd`, built on first trip at x+4200): road, both stops (only the bus to the camp takes you; miss the last and you stay), square with pond/memorial/benches/lime, chapel, Jednota, pub U Jezera, Motel Lesna, Benzina, houses, lamps, forest ring, invisible walls; facades from Grok. While you are there `main._away_in_town()` keeps the night (enemies, director place "away") off; saved as `town_trip`. Fix on the way: interaction rays were cast with window pixels through the small retro viewport (only the structures fallback ever found anything). Lesna's people (`town_people.gd`, Grok billboards `npc/town_*.png`): Mrs Hruba (the lake keeper's widow), Franta, Mr Kubat, Lojza, Mr Simek, Sgt Vavra, Pepik on his bike, each with a day (places by the hour, walking in steps, indoors at night) and lines full of camp lore (night lines after dark); click to talk (`town_npc`). Doors (`town_door`): the Jednota 7-17 (`shop_closeup.gd`: Mrs Novotna, Start $2, Lesnak $1, RYCHLA KACKA scratch cards scratched with the mouse, batteries sold out), the pub U Jezera 10-23 (`pub_closeup.gd`: a beer you drink at the bar, the LUCKY 7 fruit machine), the motel (from 19:00, $15: sleep through to 6:30 via camp_office, wake by the motel), the kiosk (Start $3), the chapel; the memorial to read. Pockets (`pockets.gd`): C smokes a cigarette (bare left hand, lighter, three drags, pixel smoke, stamina back), B drinks a bottle (gloved right hand; each bottle adds a stepped screen warp that wears off); counts saved. Village day/night ambience and the chapel bell at noon and six. Side job at the Benzina (`pump_job.gd` + `pump_closeup.gd`): ask Lojza (or click a pump) while open 6-21, cars (Build boxes, a head at the wheel) come in off the road every 16-30 s and wait at a free pump; the close-up has the pump's rolling drums (litres, dollars, odometer carry in quarter steps), three nozzles (green Natural, yellow Special, black diesel), hold LMB to pump (slow start, full flow), a full tank clicks off; orders in dollars, litres or full; $2 a car + tip $3-5 on the money, $1 near, nothing extra over, wrong fuel -$10; the shift ends when you walk off or at 21. The bus driver gets out for a smoke (pixel puffs) while the bus stands at the end of the line; click him to talk. The works bus (the timetable's +): lit, SLUZEBNI on the board, past the camp stop at ~0:06 without slowing, up the road towards the camp and gone round the bend; through Lesna at 23:46. Lesna's evenings: each window lit for its own hours (emission multiplied by the window art), chimney smoke in stepped pixel puffs. Rain runs down the bus's panes (shader, blown back with speed) |
| Sky life | ✅ | `scripts/ambient/sky_life.gd` (made by InteriorManager in the camp world, follows the player outdoors, camp, road or Lesna): flocks of small birds over by day (two-frame wing beats in steps, a glide, a rush of wings), crows to roost at dusk (cawing), bats flitting round the nearest lit lamp after dark, moths round every lit lamp within 32 m; procedural pixel sprites; hidden in rooms |
| Upkeep: only the lamps wear | ✅ | `core/systems/maintenance_rules.gd` WEARS = lamp_post: a lamp loses `maintenance_decay` 0.06 a day (on a path: the cell's `lamp_maintenance`), burns dimmer (`lamp_brightness`, `building_manager.set_lamp_wear`) and flickers more as it goes, goes out when spent (failure_system, no dice); hold R (the wrench) for a new bulb. Nothing else decays or breaks (old saves: `maintenance_controller._clear_old_wear` → `actions.clear_wear`); the derelict cabin of the start is still mended with R. Toilets/showers no longer say DIRTY on hover; upkeep_check |
| Reception: behind the counter | ✅ | you stand behind the counter facing the room and the front door; PC on the low desk to the left, key board on the right wall, bell and phone on the counter |
| Check-in desk (Papers Please style) | ✅ | `scripts/reception/checkin_desk.gd`: 480x270 Grok-painted close-up; ID card + booking slip slide across, drag them onto the register (3x5 pixel handwriting), the right key off the board, stamp CHECKED IN / REFUSED, give the papers back; wrong or unready keys come back; late at night an unbooked man with a black photo may be at the counter (letting him in feeds the omens). Key board: just keys (brass bit key = cabin, nickel padlock key = tent, black Yale = caravan) on 8x3 hooks under Dymo labels (green/red/blue tape) rewritten from what is built, a pin green/red for made up; the label maker on the desk peels labels off to stick them on other hooks (key moves along, swaps), hooks saved in the desk state. The room across the counter: Grok pictures per morning/day/evening/night, rain, fog, snow (`desk_view_*`, stepped cross-fade); at night a scare picture (`desk_scare_*`: forest, bench, window, ceiling, door, counter) now and then, likelier and worse with the radio's dread, gone with a bulb flicker; checkin_check |
| Room preparation in the interiors | ✅ | hover-glow, hold to do it, sounds, checklist; a new mess every time (place, kind, amount by who stayed), 2-10 jobs; the mess is Grok floor sprites (sick, piss, shit, mould, footprints, cans, bottles, ends, wrappers, paper, food, clothes) |
| Builder with isometric map, guests walking on it | ✅ | the "extra guest" uncanny event; `crt_map_panel.gd` draws the ground and buildings once into a static layer and only the living things each frame; smooth zoom at the cursor, pan inertia, minimap (click to go), hover card, dust puffs; undo (Ctrl+Z or the toolbar) takes back today's builds with a full refund; `builder_module.gd`: Grok splash, flat cool toolbar, sliding catalogue cards, info card |
| Economy, power/water/sewage/waste balance | 🟡 | numbers want a balance pass |
| Guest needs, moods, activities, reviews | ✅ | six archetypes (Quiet Guy, Drunk, Cheap Chick, Tramps, Family, Mushroom Pickers) with different needs and favourite facilities; bookings arrive as letters in their own voice |
| Visible guest agents in the 3D camp | ✅ | they open the door and step in and out of the buildings (`scripts/attractions/door_anim.gd`); a family is one figure per two (the sprite is a father and his boy) |
| Guests using the places | ✅ | the campfire (`scripts/attractions/campfire.gd`: fuel that burns down, logs thrown on, sparks and smoke, guests on the benches drinking, sausages on sticks, the tramp's guitar), the lake slide (`slide_ride.gd`: queue, climb, slide, splash, wade out), the nohejbal court (`pitch_play.gd`: juggling alone, a rally over the net, a missed ball fetched), and indoors the pub, bistro and Jednota (`scripts/food/service_life.gd`: at the tables and on the bar stools with mugs and plates, browsing the racks) |
| Counter minigames for extra money | ✅ | click the tap, the pass or the till in the room (`scripts/food/`): the pub tap (left pulls beer, right pushes foam; hladinka / snyt / mliko by the guest's taste; a tip for a proper pour, sent back when wrong), the bistro pass (tickets with pictures of the plate, plates from the stack, the bell; a tip when quick), the Jednota till (key the total, the crank, count the change from the drawer; no overcharging, undercharging and extra change are the camp's loss); only for the guests the simulation has inside, on top of the passive takings (`orders.gd`) |
| Lodging numbers | ✅ | per kind (tents 1, 2.., cabins 1.., caravans 1..): T1 / C2 / V1 on the key fobs (coloured by kind), the TAB plan and the Builder badges; in the camp a board on a stake in front of each tent and a blue enamel plate by the door of each cabin and caravan (`scripts/lodging_signs.gd`); a cabin or caravan is let whole (its free beds are not free) |
| Caravan (2x1) | ✅ | Lv1 2 beds / Lv2 3 / Lv3 4 (upgrades from the brochure inside): the cheapest bed with a roof and the most beds per tile, but less comfort than a cabin, needs power, wears faster; model after the Builder sprites (awning, chairs and table, fairy lights, aerial, steps, twin axle); inside the dinette that makes up into the bed, kitchenette, bunks (`scripts/caravan_interior.gd`) |
| Arrivals on screen | ✅ | dotted rings at the right edge, one per party on the way, filling as they come; green and breathing at the barrier with a red ring of patience (`scripts/ui/arrival_rings.gd`) |
| Upkeep: wear, breakdowns, service/repair (hold R), crew | ✅ | Camp Status > Upkeep; toilet and shower blocks are cleaned and fixed by hand inside |
| Shower house | ✅ | a concrete block (`building_models._showers`): grey roughcast, a strip of glass blocks over the cubicles, a green steel door with the SPRCHY plate and a caged bulb, the hot-water tank on the flat roof, the boiler's flue, a tap with a bucket outside; inside one shared room for all three showers (A/D turn the head, no sub-rooms), the daylight through the glass blocks; Builder sprites front and back from the model |
| Electricity bills, power cut, UPS game over | ✅ | |
| Weather cycle (7 states) with gameplay effect | ✅ | rain closes outdoor attractions; the red anomaly at night |
| Camp Status > Reviews | ✅ | |
| Corn maze behind a wicket gate; night job: a lost guest in the corn, the scarecrow moves when unseen | ✅ | maze new every game, corn_check |
| Corn inside the camp | ✅ | the west columns are corn tiles (ragged edge), a "tree" for the Builder (Grok iso sprite, bulldoze clears it); you wade through it slower; the west fence is posts and wire |
| The office phone | ✅ | 2D DOS-style close-up (Grok), keys, LCD, 425 Hz tones, DTMF; numbers on the noticeboard; 113 recorded lines (ElevenLabs): Novotny, Vera's machine, the district, Jednota, the pub, police, ambulance, buses, the talking clock |
| The electrician | ✅ | rung on the phone he really comes: van on the gate road, walks in with a torch, fixes the main and the dead circuit at the generator, $60 / $120 after nine; nobody comes by themselves at dawn |
| The noticeboard | ✅ | close-up: Vera's notes held up to read (numbers, bus, Novotny), the shed key hangs on it |
| Visible work: a gloved hand with the tool for every held job, stepped 8-12 fps animation (guests, fire, fan, gate, ripples) | ✅ | 8 hand sprites from Grok |
| Omens: torch by the fence, one too many, the barrier, the phone, someone by the office | ✅ | no schedule: a hazard from the camp's pressure (guests, unhappy, what came, dark, hunting), weighted draw; omens_check |
| The month's end: the district's inspection on day 31 (Monday 19 October 1998) | ✅ | Vera comes out on the first bus (in at 5:45) for it; at 08:00 the books (takings, guests, reviews, what came at night, hurt, jobs left), her verdict (the sale withdrawn, off for now, or recommended) and the breakfast count; Stay on = endless |
| The autumn (a month, 19 Sep - 18 Oct 1998) | ✅ | `core/systems/season.gd` + `scripts/season_look.gd`: golden end-of-summer evenings, the days draw in (light shifts ~1 h earlier), birch crowns gold then rust then bare, falling leaves, dry autumn grass (Grok) from day 10, greyer October, weather odds lean to fog and rain, snow from the evening of day 26 (rain falls as snow, snow sky, snow lies on the ground and the spruces), HUD date, web dates/temperatures/forecast, booking mix by season; season_check |
| Winter trouble | ✅ | hard-frost nights freeze the pipes (night job "frozen": pump, showers or toilets out until thawed, twice on the coldest), frost nights in tents and caravans sour the mood at dawn |
| Night on the lake | ✅ | `scripts/lake/night_row.gd`: a night crossing gets one thing (two from the third): three knocks from under the hull (again if you sit still), a lantern on the water that comes and goes out (the boathouse window lit after), fog that swallows the camp lamps and a bell under the water, a pale hand on the gunwale (Grok), the long scrape underneath |
| Corn walk to the linemen's hut | ✅ | solid ground and bounds under the whole field; the maze's second exit, the strip under the wires, a concrete hut by a pylon (locked, lore later) |

### Night: horror

| Feature | State | Notes |
| --- | --- | --- |
| Night roll per archetype from the forecast | ✅ | one of a kind safe, risk from the second |
| Day events (rubbish, raccoons, delivery, lost boy, noise, fallen branch) + camp life sounds | ✅ | `scripts/day_events.gd`, harness `dayevents_check` |
| Rubbish only as sprites | ✅ | every bit of mess in rooms and blocks (`interior_prep.gd build_mess`: bottles, cans, sand, mushrooms, toys, ash, sawdust, hair, puddle, toilet roll) and the day event's bin bag are Grok sprites/floor decals in `assets/textury/mess/`, no 3D boxes. Still boxes: the ground litter of world gen (`world_generator.gd` GroundLitter) |
| Silent Man (Quiet Guy) | ✅ | footsteps that close in while you stand in the dark, a whisper, then the hit; light drives him off |
| The Photographer (Drunk) | ✅ | film advance, red focus lamp and beeps, whine, flash; never look at him when it fires |
| The Girl (Cheap Chick) | ✅ | advances when unwatched; eats the battery; cannot enter lamp light |
| The Whistler (Tramps) | ✅ | a tune in the trees; following it gets you hit from behind; lamp light makes it give up |
| The Extra Child (Family) | ✅ | hums among the tents; a torch on it makes it run at you |
| The Basket Man (Mushroom Pickers) | ✅ | 02:30-06:00; sees only movement; stand still |
| The Antlered Man (two or more archetypes) | ✅ | fence-line charger |
| Flashlight battery, stamina | ✅ | |
| Player health, blood FX, death | ✅ | |
| Night procedures in the terminal | ✅ | |
| Night work: breaker board, lamps, sewer, toilets | ✅ | 2-4 jobs a night from the second night (the first is quiet), paged, TONIGHT list, waypoint; the breaker is a small puzzle in the shed's switch room |
| The first night | ✅ | nothing comes and there are no jobs (main.QUIET_NIGHTS); Vera's 20:06 mail sends you to bed |
| Night senses | ✅ | insects and frogs fall silent around a presence; the HUD face widens its eyes and glances toward what you are not looking at |
| Raccoon thing (waste/dumpster threat) | ❌ | art exists (`npc/racoon*`), no brain |

### Interiors and minigames

| Feature | State | Notes |
| --- | --- | --- |
| The night director | ✅ | `scripts/night/`: tension, states, budget, archetypes from the guests, memory of how you play; 21 events through the camp's own systems (window, door, phone, radio, lamps, steps, calls, figures, omens, a far light, a moved cup, a reported cabin, a twig, the insects' silence, a door banging, steps in the back room, a sleeping guest standing at the tree line); night log and the camp's character on CampStat's NIGHT page; `tools/director_check.gd`; F10 debug panel in debug builds |
| Night work on the PC | ✅ | DataPunch 98 (register cards, $4 each, 24 a night); guest book replies move the reputation and the bookings; Bazar Hlubocany sells what guests left behind (`scripts/bazaar.gd`, `tools/bazaar_check.gd`), and the red shoe that comes back |
| Reception building | ✅ | built from the office's plan (`scripts/reception/reception_layout.gd`): plank cabin, porch, RECEPCE sign, the door and both windows where they are inside; windows glow at night with the lights on |
| Curtains, desk lamp, daylight | ✅ | `scripts/reception/curtain.gd` in the office and the back room (whose window looks out over the gate lane, a second portal); the green desk lamp switches; a sun beam with shadows through the office window |
| Phone | ✅ | modelled after its close-up; a key lifts the handset; incoming calls ring in the room and outside, CALL on the display |
| Toilets | ✅ | two single stalls as outside, each behind its own door: you go into the one whose door you walk up to (no A/D between them); scrubbing close-up (`scripts/scrub_minigame.gd`): the filth wears off where you drag the brush, CLEAN %, flush, SPOTLESS |
| Reception (CRT, radio, light switch, phone, noticeboard) | ✅ | everything usable glints under the cursor (pixel glints, Grok) and gets the gloved finger; the window is a portal into the real camp (`_update_window_portal`: an off-axis camera where your eye is, laid over the reception building); the monitor is curved glass (`materials/crt_glass.gdshader`; the desk overlay and the mouse use the same barrel, `CRT_CURVE`); the radio opens a new game with "radiojedna" |
| The back room and sleep | ✅ | through the door in the office: bed, little TV (programme, test card after midnight), VFD alarm clock, curtains, wardrobe; sleep only at night with nothing out there: lie down, the TV, eyelids, the night passes, the alarm; any key skips |
| The cursor | ✅ | a gloved hand (Grok): carved arrow, pointing finger, flat palm for doors and the way out, fist while working |
| Generator shed | ✅ | junk to shove aside, a locked switch room (the key from the noticeboard), the distribution board on the wall; the close-up is a Grok picture of the board with its states painted on; some nights a coat in the corner |
| The lake trip | ✅ | row the keeper's boat across (oars sprite, W stroke, A/D), his boathouse on the far shore: the logbook close-up (1979-1993), fishing from his jetty; sometimes something passes under the boat at night |
| Tent / cabin interiors, upgrades | ✅ | closed rooms (the tent is a proper A-frame) |
| Service interiors | ✅ | the sewer hatch says whether there is a leak; R crawls in only then |
| Pipe crawl (sewer repair) | ✅ | generated network, paper map without your position, no turning around, coordinates and landmarks (brick sections, scratches, the red shoe), clamp the leak; climbing down, the map unfolds, the torch hand, water running away from the leak, drips, look back (S); the thing and its director (scripts/pipes/pipe_director.gd): never shown the first time down, glimpses the second, the hunt after |
| Interior look-around (restricted) | ✅ | you stay put and turn your head: cursor at the screen edge, the arrow keys or A/D; tent ±48°, services ±65°, cabin ±72°, the office and the caravan all the way round |
| The torch | ✅ | a weak narrow beam with a dim halo that trails a turn a beat behind; the hand holding it low at the bottom right (Grok sprite, the torch pointing into the scene); in a dark room (lights off, no power, a tent at night) it comes on by itself and shines where the cursor points (`scripts/ui/interior_torch.gd`) |
| Cabin windows | ✅ | the room matches the cabin outside (front door and windows, back window, the side window or the bathroom door by level); the windows look out into the real camp (off-axis cameras) |

### Atmosphere and the uncanny

| Feature | State | Notes |
| --- | --- | --- |
| Ambience bed: day, dusk birds, crickets, lake insects, owl, weather | ✅ | |
| Reception radio audible across the camp | ✅ | positional source in the office, muffled with distance |
| The radio going wrong with the night | ✅ | dread from NIGHT RISK, hour, tonight's enemies, proximity: static, skips, tape sag, ghost station, drift onto the OK 76 buzz, birds/dog/knock on the frequency, Czech numbers-station broadcasts (tonight's code word, the guest count plus one, an open-mic leak), dead carrier when something is close, the switched-off set murmuring once; ElevenLabs voices + synth (`tools/gen_radio_dread.py`) |
| The station that does not exist | ✅ | late at night, at most once, from day 2: a music-box phrase and one pip per guest, plus one |
| The night log stamped tomorrow | ✅ | one mail delivered at 03:00 dated the next day |
| The unbooked sleeper in GuestRack | ✅ | some evenings, one row more than there are records |
| The extra guest on the Builder map | ✅ | |
| Vera knows too much | ✅ | her mails drift from instructions to the socks in your drawer |

## Known non-goals

- Multiplayer. Combat (the player cannot fight back). Modern clean UI.
