# PRODUCT.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-16*

## What it is

A two-halved game set in a decaying post-communist summer camp you mind for your aunt Vera
for a month, through the autumn of 1998.

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
| Title screen over a live camp flythrough | ✅ | Continue (with day/time/cash), New, Load (save list), Configuration, Controls |
| Pause menu (Esc), autosave on quit to title, pause on alt-tab | ✅ | |
| Build-engine HUD (status bar, feed, objective tracker, guest card, banners) | ✅ | crisp bitmap pixel fonts, integer scale at every resolution |
| Screen-space objective marker | ✅ | edge arrow when off-screen / behind |
| Low-res render + 256-colour palette, settings presets | ✅ | |
| Window title / logo "Cursed Camp Manager Simulator" | ✅ | |
| Studio splash: UNDO LABS, POWERED BY GODOT | ✅ | neon signs on a cabin wall at night (Build palette with the mosaic's ramps, shade-stepped light): the mosaic strikes diagonal by diagonal, the view slides down the cable to the Godot robot, then the power goes (the camp's power-out sound); plays while main.tscn loads; the engine boot image is its first frame; any key skips to the cut |

### Day: management

| Feature | State | Notes |
| --- | --- | --- |
| Vera's Checklist (14-step onboarding questline) | ✅ | task mails, rewards, tracker, waypoint; the tracker column shows only while TAB is held (outdoors beside the site plan, indoors alone) |
| CampMail bookings with night-risk impact | ✅ | CampMail 3.0 (`os98/apps/mail_app.gd`): folder tree (Inbox, Sent, Deleted), cool toolbar, sortable list with envelope icons and attachment marks, From/To/Date header, quoted lines, spam with pictures (Grok, `textury/mail/`), reply/forward/compose (`EmailManager.send_mail`), Delete/Ctrl+R/Ctrl+N/F5 |
| Arrivals: road, gatehouse, barrier, waiting parties | ✅ | HUD ARRIVALS panel counts down; the barrier lifts as a party arrives, they walk up the starter path and queue at the reception (first at the counter, second on the bench, the rest at the door), give up after ~2.5 h |
| Starter path gate → reception | ✅ | laid by world gen through the barrier, up the gate lane, turning in front of the reception door; the bulldozer cannot remove it (meta `permanent`); the road outside wears the same dirt track |
| Reception: behind the counter | ✅ | you stand behind the counter facing the room and the front door; PC on the low desk to the left, key board on the right wall, bell and phone on the counter |
| Check-in desk (Papers Please style) | ✅ | `scripts/reception/checkin_desk.gd`: 480x270 Grok-painted close-up; ID card + booking slip slide across, drag them onto the register (3x5 pixel handwriting), the right key off the board, stamp CHECKED IN / REFUSED, give the papers back; wrong or unready keys come back; late at night an unbooked man with a black photo may be at the counter (letting him in feeds the omens); checkin_check |
| Room preparation in the interiors | ✅ | hover-glow, hold to do it, sounds, checklist; a new mess every time (place, kind, amount by who stayed), 2-10 jobs; the mess is Grok floor sprites (sick, piss, shit, mould, footprints, cans, bottles, ends, wrappers, paper, food, clothes) |
| Builder with isometric map, guests walking on it | ✅ | the "extra guest" uncanny event; `crt_map_panel.gd` draws the ground and buildings once into a static layer and only the living things each frame; smooth zoom at the cursor, pan inertia, minimap (click to go), hover card, dust puffs; undo (Ctrl+Z or the toolbar) takes back today's builds with a full refund; `builder_module.gd`: Grok splash, flat cool toolbar, sliding catalogue cards, info card |
| Economy, power/water/sewage/waste balance | 🟡 | numbers want a balance pass |
| Guest needs, moods, activities, reviews | ✅ | six archetypes (Quiet Guy, Drunk, Cheap Chick, Tramps, Family, Mushroom Pickers) with different needs and favourite facilities; bookings arrive as letters in their own voice |
| Visible guest agents in the 3D camp | ✅ | |
| Upkeep: wear, breakdowns, service/repair (hold R), crew | ✅ | Camp Status > Upkeep; toilet and shower blocks are cleaned and fixed by hand inside |
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
| The month's end: Vera returns on day 31 (Monday 19 October 1998) | ✅ | at 08:00 the books (takings, guests, reviews, what came at night, hurt, jobs left), her verdict and the breakfast count; Stay on = endless |
| The autumn (a month, 19 Sep - 18 Oct 1998) | ✅ | `core/systems/season.gd` + `scripts/season_look.gd`: golden end-of-summer evenings, the days draw in (light shifts ~1 h earlier), birch crowns gold then rust then bare, falling leaves, dry autumn grass (Grok) from day 10, greyer October, weather odds lean to fog and rain, snow from the evening of day 26 (rain falls as snow, snow sky, snow lies on the ground and the spruces), HUD date, web dates/temperatures/forecast, booking mix by season; season_check |
| Winter trouble | ✅ | hard-frost nights freeze the pipes (night job "frozen": pump, showers or toilets out until thawed, twice on the coldest), frost nights in tents and caravans sour the mood at dawn |
| Night on the lake | ✅ | `scripts/lake/night_row.gd`: a night crossing gets one thing (two from the third): three knocks from under the hull (again if you sit still), a lantern on the water that comes and goes out (the boathouse window lit after), fog that swallows the camp lamps and a bell under the water, a pale hand on the gunwale (Grok), the long scrape underneath |
| Corn walk to the linemen's hut | ✅ | solid ground and bounds under the whole field; the maze's second exit, the strip under the wires, a concrete hut by a pylon (locked, lore later) |

### Night: horror

| Feature | State | Notes |
| --- | --- | --- |
| Night roll per archetype from the forecast | ✅ | one of a kind safe, risk from the second |
| Day events (rubbish, raccoons, delivery, lost boy, noise, fallen branch) + camp life sounds | ✅ | `scripts/day_events.gd`, harness `dayevents_check` |
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
| Toilets | ✅ | two single stalls as outside, a proper bowl in each; scrubbing close-up (`scripts/scrub_minigame.gd`): the filth wears off where you drag the brush, CLEAN %, flush, SPOTLESS |
| Reception (CRT, radio, light switch, phone, noticeboard) | ✅ | everything usable glints under the cursor (pixel glints, Grok) and gets the gloved finger; the window is a portal into the real camp (`_update_window_portal`: an off-axis camera where your eye is, laid over the reception building); the monitor is curved glass (`materials/crt_glass.gdshader`; the desk overlay and the mouse use the same barrel, `CRT_CURVE`); the radio opens a new game with "radiojedna" |
| The back room and sleep | ✅ | through the door in the office: bed, little TV (programme, test card after midnight), VFD alarm clock, curtains, wardrobe; sleep only at night with nothing out there: lie down, the TV, eyelids, the night passes, the alarm; any key skips |
| The cursor | ✅ | a gloved hand (Grok): carved arrow, pointing finger, flat palm for doors and the way out, fist while working |
| Generator shed | ✅ | junk to shove aside, a locked switch room (the key from the noticeboard), the distribution board on the wall; the close-up is a Grok picture of the board with its states painted on; some nights a coat in the corner |
| The lake trip | ✅ | row the keeper's boat across (oars sprite, W stroke, A/D), his boathouse on the far shore: the logbook close-up (1979-1993), fishing from his jetty; sometimes something passes under the boat at night |
| Tent / cabin interiors, upgrades | ✅ | closed rooms (the tent is a proper A-frame) |
| Service interiors | ✅ | the sewer hatch says whether there is a leak; R crawls in only then |
| Pipe crawl (sewer repair) | ✅ | generated network, paper map without your position, no turning around, coordinates and landmarks (brick sections, scratches, the red shoe), clamp the leak; climbing down, the map unfolds, the torch hand, water running away from the leak, drips, look back (S); the thing and its director (scripts/pipes/pipe_director.gd): never shown the first time down, glimpses the second, the hunt after |
| Interior look-around (restricted) | ✅ | you stay put and turn your head: cursor at the screen edge or the arrow keys; tent ±48°, services ±65°, office ±70°, cabin ±72° |

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
