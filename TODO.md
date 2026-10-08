# TODO — Cursed Camp Manager Simulator

*Updated: 2026-10-08. Vision: DESIGN.md. What exists: PRODUCT.md.*

---

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
- [ ] The camera at the desk frames the monitor properly from the first second (it starts zoomed out)

### 2. The computer: a whole game inside the game (rebuild from scratch)
- [x] Inventory of what the old shell does (mail + bookings + risk, Beeternet + downloads,
      installer, Builder, GuestRack, Camp Status: power/upkeep/reviews/night, finance, notes, mines)
- [x] A period system font: W95FA baked to BMFont (w95, w95b)
- [ ] New OS at a fixed 640x480: real Win98 look (bevels, navy title bars, Start, taskbar, clock)
- [ ] BIOS POST + OEM splash (Camptronics) + desktop; resumes instantly once booted
- [ ] Deliberately empty: CampMail, Beeternet, Notepad (Vera's notes), Mines, My Computer, Recycle Bin
- [ ] Builder 98 downloaded from a period shareware site, installed with a setup wizard
- [ ] CampStat (power company site) and GuestRack (district office site) downloaded the same way
- [ ] CampMail rebuilt: list, reader, booking panel (party, nights, pay, arrival, night-risk impact, Accept/Reject)
- [ ] CampStat rebuilt: power bill (pay), upkeep (crew), reviews, night forecast + procedures, money
- [ ] Web 1.0 internet: portal/directory, the camp's own homepage + guestbook, pub, Jednota,
      bus timetable, regional newspaper archive (lore of the enemies), power company,
      district office, a webring, 404 - the player works out where and what this place is
- [ ] Night use: mail and web work at night; Builder refuses (licence: daytime only)
- [ ] Computer sounds (ElevenLabs): HDD seek, fan, keyboard, modem dial-up, boot chime-ish, clicks
- [ ] Keep the old interface for the rest of the game (setup, open_panel, export/import state,
      desktop_ready, program unlocks, quest hooks, shot driver hooks); delete crt_os_shell.gd

### 3. Builder (a game of its own)
- [ ] Rework HUD/UI for the new 640x480 OS: clear toolbar, categories, prices, tooltips
- [ ] Feedback: placement/invalid previews, build animation, money pop, sounds per action
- [ ] Life: animated guests, smoke, water, day/night tint on the map
- [ ] Period atmosphere; fun even on its own

### 4. Campaign: survive one week
- [ ] Scripted events across days 1-7 that escalate (story mails exist; add events in the camp)
- [ ] An ending on day 8 (Vera returns): what a good week means
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
- [ ] Visual finish: real models (bed, toilet, sink, table), camp textures on walls/floors

### 11. More interiors
- [x] Cabins: room, bed, bathroom/WC, cleaning, prep
- [ ] Pub / restaurant: complete interior, own interactions, more life, activities
- [ ] Cellar / machine room: design the dark mechanic (the meatball machine) and prepare
      the space so it can be hooked up (design doc + interactive stub)

### 12. 3D models and the camp's look
- [x] New gatehouse (generated textures)
- [ ] Remodel cabins, tents, restaurant/pub, toilets/showers, reception; reuse the existing
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
- [ ] Sound when the breaker trips (power_out.mp3 exists, not yet played)

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
- [ ] Gatehouse sign text spills past the board
- [ ] Cabin level-1 has no bathroom; the bucket outside is decoration only
- [ ] The bathroom toilet is a box (part of the interiors visual pass)
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
