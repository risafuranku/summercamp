# TODO — Cursed Camp Manager Simulator

*Updated: 2026-10-16. Vision: DESIGN.md. What exists: PRODUCT.md.*

---

## BRIEF 2026-10-16 — polish and depth (the user's notes)

- [x] B1  The first night is quiet (no enemies, no jobs); Vera sends you to bed
- [x] B2  The door in the office opens: the back room (bed, small analog TV, heavy curtains, wardrobe)
- [x] B3  Sleep only when nothing is out there: lie down, the TV, eyes close, VFD alarm clock; skippable
- [x] B4  Interior look was "on ice": crisp braking, spring parallax, no double easing
- [x] B5  Cursor: the gloved hand (Grok), changes over usable things; glint highlight (Grok)
- [x] B6  Mess as Grok sprites: shit, piss, sick, mould, grime, litter
- [x] B7  Pipes: polish (descent, map, torch hand, water flow as guidance, drips, look back) and a director that plays with the player (not shown at first, then glimpses, then the hunt)
- [x] B8  The electrician is real: phone (2D close-up, keys, tones, voices), number on the noticeboard, he drives out and fixes it
- [x] B9  The fuse board in DOS close-up style, in a switch room behind junk and a locked door (key on the board)
- [x] B10 The lake: row across, the keeper's boathouse, his logbook, fishing
- [x] B11 Corn flows into the camp map, bulldozable in the Builder (Grok iso sprite); pylons stay
- [x] B12 The web: pictures (Grok), interlaced loading; better boot (warm-up, POST table), download and setup animations
- [ ] B13 Later: something hidden in the shed (beyond the coat), more to do on the far shore, the boat at night as its own scare
- [ ] B14 Later: walk through the outside maze walls? (the maze is the corn job's; the camp corn is walkable)

## PLAYTEST 2026-10-13 — the user's notes

- [x] Q1  Guests turned up for a booking at night: arrivals only 08:00-19:30 (evening bookings come next morning)
- [x] Q2  You could walk into occupied rooms: now you knock and are told off
- [x] Q3  Remove the fourth-wall "D > TOILETS" labels from interiors (side tabs in the UI; room names are enamel signs)
- [x] Q4  The reception window looked out of the camp, not into it
- [x] Q5  No cursor in the reception after getting up from the PC
- [x] Q6  At low render resolution the monitor was unreadable (crisp full-res overlay over the 3D screen)
- [x] Q7  Health comes back in the morning
- [x] Q8  Simpler, nicer TAB map
- [ ] Q9  Polish, polish, polish (ongoing: see below)

## PLAYTEST 2026-10-09 — the user's notes (do these next, tick as you go)

- [x] P1  Vera's checklist (quest tracker) visible while sitting at the PC
- [x] P2  The barrier opens into the ground: fix the pivot/rotation
- [x] P3  Manual check-in: guests wait at reception, the player checks them in; nobody walks through the reception walls
- [x] P4  Remodel ALL building exteriors and ALL interiors to match the Builder pixel art (keep textures/atmosphere); finish sports field, caravan
- [x] P5  Lamps can be placed on a path tile; the lamp snaps to the path edge
- [x] P6  Whole game in English with Czech in-jokes (world market): sweep signs, UI, mail
- [x] P7  Daytime is dead: more life outside (guests doing things, sounds, small events)
- [x] P8  Too easy: two full cabins and nothing happens -> more pressure (needs, complaints, mess, events, nights)
- [x] P9  Three more guest archetypes (each with its own night threat)
- [x] P10 GuestRack: better visuals
- [x] P11 Higher look sensitivity in interiors
- [x] P12 Cleaning variety: sometimes a few items, sometimes many across rooms, mess in different places each time
- [x] P13 Shower/toilet maintenance done inside like cleaning, not hold-E outside
- [x] P14 Pipe monster: finish the mechanics (risk, logic that makes sense)
- [x] P15 Nicer icons in the Builder toolbar
- [x] P16 Remove the hold-S look-back at the PC
- [x] P17 Hold TAB: paper map of the camp (no player dot) with tasks, broken things, room states at a glance
- [x] P18 Trees and leaves sway in the wind; bare trunks too in a gale
- [x] P19 Corn field with a scarecrow and a power line (humming steel pylons, faint red lights at night) on one map edge
- [x] P20 Storm: wind effects, rain blowing sideways, trees moving
- [x] P21 No bloom indoors (the PC screen glows white, mail unreadable)
- [x] P22 Leave an interior with S or by clicking the door behind you
- [x] P23 No popup after accepting a booking
- [x] P24 Reception lighting changes smoothly; a real view out of the window, visible from the PC
- [x] P25 Breaker minigame polish

## CURRENT ITERATION — the brief of 2026-10-08 (work through this first)

The brief: take the systems that exist, understand what they were for, and rework them
into one complete game. Not a feature list: computer -> Builder -> camp -> bookings ->
room prep -> guests -> upkeep -> night -> monsters -> next day must be one loop.
Tools: Grok Imagine (Cursor CLI) for textures, ElevenLabs for sound (key in
`tools/audiogen/.env`, gitignored).

### 1. Start of the game and the main flow
- [x] A new game starts seated at the computer in the reception (boots with the CRT)
- [x] The first part is all on the computer (Vera's mail, Builder, first tent, toilet, first booking)
- [x] Getting up is a discovery: Vera's "You can get up, you know", title card THE CAMP / DAY 1
- [x] The camera at the desk frames the monitor properly from the first second (it starts zoomed out)

### 2. The computer: a whole game inside the game (rebuild from scratch)
- [x] Inventory of what the old shell does (mail + bookings + risk, Beeternet + downloads,
      installer, Builder, GuestRack, Camp Status: power/upkeep/reviews/night, finance, notes, mines)
- [x] A period system font: W95FA baked to BMFont (w95, w95b)
- [x] New OS at a fixed 640x480: real Win98 look (bevels, navy title bars, Start, taskbar, clock)
- [x] BIOS POST + OEM splash (Camptronics) + desktop; resumes instantly once booted
- [x] Deliberately empty: CampMail, Beeternet, Notepad (Vera's notes), Mines, My Computer, Recycle Bin
- [x] Builder 98 downloaded from a period shareware site, installed with a setup wizard
- [x] CampStat (power company site) and GuestRack (district office site) downloaded the same way
- [x] CampMail rebuilt: list, reader, booking panel (party, nights, pay, arrival, night-risk impact, Accept/Reject)
- [x] CampStat rebuilt: power bill (pay), upkeep (crew), reviews, night forecast + procedures, money
- [x] Web 1.0 internet: portal/directory, the camp's own homepage + guestbook, pub, Jednota,
      bus timetable, regional newspaper archive (lore of the enemies), power company,
      district office, a webring, 404 - the player works out where and what this place is
- [x] Night use: mail and web work at night; Builder refuses (licence: daytime only)
- [x] Computer sounds (ElevenLabs): HDD seek, fan, keyboard, modem dial-up, boot chime-ish, clicks
- [x] Keep the old interface for the rest of the game (setup, open_panel, export/import state,
      desktop_ready, program unlocks, quest hooks, shot driver hooks); delete crt_os_shell.gd
- [x] Harness tools/os98_check (boot, every app and page, download, setup, night lock, save/load)
- [x] The monitor: 4:3 screen, beige plastic casing, dark bezel (was brick-textured, 16:10)
- [x] Keyboard clicks while typing; web images (Grok) on most pages
- [ ] Later: hidden pages

### 3. Builder (a game of its own)
- [x] Rework HUD/UI for the new 640x480 OS: menu, toolbar, catalogue cards with prices, tooltips, status bar (message / tile / cost)
- [x] Feedback: one-click placement, price tag on the preview (red when blocked/broke), drop-in, dust, money pops, sounds per action (ElevenLabs)
- [x] Life: guests (existing), smoke from fire and chimneys, light on the water, dusk tint and lamp/fire glow
- [x] Period atmosphere: shareware nag, About/Help/Site report, isometric Grok sprites for bonfire, caravan, slide, field, Jednota, lamp
- [ ] Later: upgrades from the map (tent -> tent 2), terrain painting, a minimap

### 4. Campaign: survive one week
- [x] Events across the week that escalate: not scripted, omens out of the simulation's pressure (DESIGN §5e)
- [x] An ending on day 8 (Vera returns): what a good week means (DESIGN §5d, week_check)
- [ ] Replayability: randomised offers, events, enemy mixes

### 5. Sandbox mode
- [ ] Setup screen: starting money, map size, weather, other parameters
- [ ] Endless play; goals: last longest, earn most, best camp, best stats
- [ ] Score/stats screen

### 6. Mail and HUD
- [x] HUD mail indicator + belt pager on new mail while outside
- [x] Far less spam, bookings in office hours, slower first days
- [x] Night false alarm (at most one a night, ~40% of nights)

### 7. Pace of time
- [x] 1.5x faster game time (BalanceConfig.GAME_MINUTES_PER_SECOND); tune by feel later
- [x] First days calmer (mail cadence rises through the week)

### 8. Bookings and arrival
- [x] Gatehouse, barrier, road, gap in the fence, defined arrival point
- [x] Arrival timer after accepting; HUD ARRIVALS with countdown and room readiness
- [x] Waiting at the barrier, complaining, giving up with a review

### 9. Room preparation
- [x] Room states: unprepared / dirty -> ready; occupied derived; upgrade resets
- [x] Prepared physically in the interior

### 10. Interiors
- [x] Restricted mouse look-around, hover highlight, hold LMB with a progress ring, sounds
- [x] Room switching by keys (cabin bathroom); bathroom upkeep task
- [x] Visual finish: real models (bed, toilet, sink, table), camp textures on walls/floors (interior_kit + tools/blender, 42 props)

### 11. More interiors
- [x] Cabins: room, bed, bathroom/WC, cleaning, prep
- [ ] Pub / restaurant: complete interior, own interactions, more life, activities
- [ ] Cellar / machine room: design the dark mechanic (the meatball machine) and prepare
      the space so it can be hooked up (design doc + interactive stub)

### 12. 3D models and the camp's look
- [x] New gatehouse (generated textures)
- [x] Remodel cabins, tents, restaurant/pub, toilets/showers, reception; reuse the existing
      atmospheric textures first, generate missing ones in the same style (Grok)
- [ ] Visible paths out of the camp where guests leave (forest trails, lake path)

### 13. Fewer guests in sight
- [x] Guests stay in lodgings, leave the camp by exits for hours, stand at the lake (64% -> ~35% outdoors)

### 14. The lake
- [ ] Remodel: a real forest lake (water surface, reflections, shore, reeds, surrounding forest)
- [ ] Morning mist, darker night, deep-forest, slightly eerie; a place guests walk to

### 15. Night gameplay loop
- [x] Night jobs director: 2-4 jobs a night, paged, TONIGHT list, waypoint
- [ ] Computer work at night (via the new OS: mail, web, CampStat)
- [ ] Camp patrol / checking things; preparing for the next day (e.g. laundry, restock)

### 16. Infrastructure upkeep at night
- [x] Breaker board puzzle at the generator; lamp failures go dark; sewer; toilets
- [x] Sound when the breaker trips (power_out.mp3 exists, not yet played)

### 17. Photographer
- [x] Readable cycle: film advance, red AF lamp + beeps, whine, flash from his side; backs off

### 18. Quiet Guy
- [x] Footsteps closing in the dark, light drives him off, whisper + grace window, then the hit

### 19. Blood
- [x] Ballistic drops that land; no stains in mid-air; fewer particles

### 20. One coherent loop
- [ ] Play a full day+night end to end (shot-driver run) and fix the seams
- [ ] Update DESIGN/PRODUCT/AGENTS after each block; commit + push per block

### Small leftovers found on the way
- [x] Gatehouse sign text spills past the board
- [x] Cabin level-1 has no bathroom; the bucket outside is decoration only (now a slop bucket in the room: "Empty the slop bucket")
- [x] The bathroom toilet is a box (part of the interiors visual pass)
- [ ] GitLab remote auth (needs the user to log in on the dev PC)

---

## P0 — the vision's missing pieces

- [ ] Pipe crawl polish: a proper shoe/bucket sprite, junction props, playtest the
      thing's pace; consider a second map style (torn, partly wrong).
- [ ] Atmosphere: a proper dusk skybox (generated), wind in the trees by day, distant dogs
      or a train at night; listen through a whole day/night with headphones and mix.
- [ ] Playtest the uncanny details' frequency (station 14%/track at night, phantom glance
      35% of nights): rare enough to doubt, common enough to be met in a week.
- [ ] **Night playtest + balance** of the four enemies (damage, cadence, battery, how
      often two archetypes cross the threshold on a lazy vs. a careful booking).

## P1 — management depth

- [ ] Booking offers that make the puzzle explicit (party mix, demands, a tempting
      high-paying lazy option) and a booking screen that shows the night price per guest.
- [ ] Balance pass: satisfaction/fun deltas, income vs. upkeep vs. electricity.
- [ ] The raccoon thing: waste overflow (dumpsters) as a fifth night threat; art exists.

## P2 — structure

- [ ] Move the liminal debug window and night orchestration out of `main.gd`.
- [ ] `BuildingManager` as a pure view over `GridModel`.
- [ ] Remove `GameActions.end_day()`.

## P2 — release blockers

- [ ] Replace Redneck Rampage texture rips with generated textures (AGENTS §7).
- [ ] Export test (the building registry now handles `.remap`; verify a real export).

## Done before this iteration

HUD fonts/layout, objective marker, front end + pause, integer scaling, weather cycle,
upkeep loop, single building catalog, main.gd extractions, four night enemies, stamina and
battery, RCT guests on the Builder map. Then: the pipe crawl; night senses; the radio as a
place; the station, the night log, the unbooked sleeper; the story week rewritten;
restricted look-around in every interior. Details: AUDIT.md.
