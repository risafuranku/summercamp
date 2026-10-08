# PRODUCT.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-08*

## What it is

A two-halved game set in a decaying post-communist summer camp you mind for your aunt Vera
for a week.

- **Day: a tycoon on the office PC.** A Windows-95-like terminal in the reception: CampMail
  (bookings, story, bills), Builder (an isometric 1:1 map of your camp, RollerCoaster Tycoon
  style, with your guests walking around in it), Camp Status, Finance, GuestRack, a browser.
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

### Day: management

| Feature | State | Notes |
| --- | --- | --- |
| Vera's Checklist (13-step onboarding questline) | ✅ | task mails, rewards, tracker, waypoint |
| CampMail bookings with night-risk impact | ✅ | |
| Arrivals: road, gatehouse, barrier, waiting parties | ✅ | HUD ARRIVALS panel counts down; parties wait at the barrier until their room is ready, give up after ~2.5 h |
| Room preparation in the interiors | ✅ | hover-glow, hold to do it, sounds, checklist; tent 2 tasks, cabin 2-3 |
| Builder with isometric map, guests walking on it | ✅ | the "extra guest" uncanny event |
| Economy, power/water/sewage/waste balance | 🟡 | numbers want a balance pass |
| Guest needs, moods, activities, reviews | ✅ | archetypes have different needs and favourite facilities |
| Visible guest agents in the 3D camp | ✅ | |
| Upkeep: wear, breakdowns, service/repair (hold R), crew | ✅ | Camp Status > Upkeep |
| Electricity bills, power cut, UPS game over | ✅ | |
| Weather cycle (7 states) with gameplay effect | ✅ | rain closes outdoor attractions; the red anomaly at night |
| Camp Status > Reviews | ✅ | |

### Night: horror

| Feature | State | Notes |
| --- | --- | --- |
| Night roll per archetype from the forecast | ✅ | |
| Silent Man (Quiet Guy) | ✅ | footsteps that close in while you stand in the dark, a whisper, then the hit; light drives him off |
| The Photographer (Drunk) | ✅ | film advance, red focus lamp and beeps, whine, flash; never look at him when it fires |
| The Girl (Cheap Chick) | ✅ | advances when unwatched; eats the battery; cannot enter lamp light |
| The Antlered Man (two or more archetypes) | ✅ | fence-line charger |
| Flashlight battery, stamina | ✅ | |
| Player health, blood FX, death | ✅ | |
| Night procedures in the terminal | ✅ | |
| Night work: breaker board, lamps, sewer, toilets | ✅ | 2-4 jobs a night, paged, TONIGHT list, waypoint; the breaker is a small puzzle |
| Night senses | ✅ | insects and frogs fall silent around a presence; the HUD face widens its eyes and glances toward what you are not looking at |
| Raccoon thing (waste/dumpster threat) | ❌ | art exists (`npc/racoon*`), no brain |

### Interiors and minigames

| Feature | State | Notes |
| --- | --- | --- |
| Reception (CRT, radio, light switch) | ✅ | |
| Tent / cabin interiors, upgrades | ✅ | closed rooms (the tent is a proper A-frame) |
| Service interiors | ✅ | the sewer hatch says whether there is a leak; R crawls in only then |
| Pipe crawl (sewer repair) | ✅ | generated network, paper map without your position, no turning around, coordinates and landmarks, clamp the leak, the thing in the pipes (day 3+ / night) |
| Interior look-around (restricted) | ✅ | you stay put and turn your head: cursor at the screen edge or the arrow keys; tent ±48°, services ±65°, office ±70°, cabin ±72° |

### Atmosphere and the uncanny

| Feature | State | Notes |
| --- | --- | --- |
| Ambience bed: day, dusk birds, crickets, lake insects, owl, weather | ✅ | |
| Reception radio audible across the camp | ✅ | positional source in the office, muffled with distance |
| The station that does not exist | ✅ | late at night, at most once, from day 2: a music-box phrase and one pip per guest, plus one |
| The night log stamped tomorrow | ✅ | one mail delivered at 03:00 dated the next day |
| The unbooked sleeper in GuestRack | ✅ | some evenings, one row more than there are records |
| The extra guest on the Builder map | ✅ | |
| Vera knows too much | ✅ | her mails drift from instructions to the socks in your drawer |

## Known non-goals

- Multiplayer. Combat (the player cannot fight back). Modern clean UI.
