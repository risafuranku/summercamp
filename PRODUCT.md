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
| Silent Man (Quiet Guy) | ✅ | audio stalker + rare visible peeks |
| The Tourist (Drunk) | ✅ | camera flash; do not look |
| The Girl (Cheap Chick) | ✅ | advances when unwatched; eats the battery; cannot enter lamp light |
| The Antlered Man (two or more archetypes) | ✅ | fence-line charger |
| Flashlight battery, stamina | ✅ | |
| Player health, blood FX, death | ✅ | |
| Night procedures in the terminal | ✅ | |
| Raccoon thing (waste/dumpster threat) | ❌ | art exists (`npc/racoon*`), no brain |

### Interiors and minigames

| Feature | State | Notes |
| --- | --- | --- |
| Reception (CRT, radio, light switch) | ✅ | |
| Tent / cabin interiors, upgrades | ✅ | static views |
| Service interiors | ✅ | static views |
| Sewer pipe repair minigame | 🟡 | works; redesign planned (blind pipe crawl, see DESIGN §8) |
| Interior look-around (restricted) | ❌ | planned |

## Known non-goals

- Multiplayer. Combat (the player cannot fight back). Modern clean UI.
