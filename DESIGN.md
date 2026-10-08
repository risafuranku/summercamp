# DESIGN.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-08*

How the game is meant to feel and the rules that produce it. For what exists today see
[PRODUCT.md](PRODUCT.md); for wiring see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 1. The idea

A week minding aunt Vera's camp. By day it is a pleasant, slightly fiddly tycoon you play
on the reception PC. At 20:00 the PC locks and the consequences of your day walk around
outside in the dark, and you have to go out there with a flashlight.

Every management choice has a horror price, and the player can see the exchange rate
before paying it. That is the load-bearing idea; any new system feeds it or stays out of
its way.

```
accept booking -> +income -> +guests of an archetype
                                   |   (unhappy guests count double)
                                   v
                     night odds for that archetype's enemy
                                   |
              two or more archetypes spawn -> the Antlered Man as well
```

## 2. Tone: the found CD

- **Serious product of 1996.** Build-engine look (low-res 3D, 256-colour shade-ramp
  palette, Duke3D/Redneck Rampage status bar), a Win95 terminal, dry administrative
  writing. It should feel competent and real, never parody.
- **Something is wrong with it.** Small, quiet, deniable details that make you wonder who
  made this and why: one guest too many on the Builder map, standing still at the edge,
  facing the office; staff procedures that end "Incidents are not to be reported"; the
  HUD face that widens its eyes; a red haze that "is not weather". Rules for them:
  - rare, short, never explained, never a jumpscare;
  - never indistinguishable from a bug: they are *specific* (a person, a sentence, a
    look), not glitches in numbers the player relies on;
  - they belong to the world (diegetic) rather than to a UI flourish.
- **Atmosphere is the product.** Dusk sky, crickets, the radio from the reception audible
  across the field, rain on the roof. A standing-still player should feel the place is
  alive and slightly watching.

## 3. Daily rhythm

One in-game day = 24 real minutes (1 real second = 1 game minute).

| Time | Phase | The player |
| --- | --- | --- |
| 06:30 | Day | Builder unlocked; bookings, building, upkeep, talking to guests |
| 18:00 | Evening | last building window; guests drift back |
| 19:30 | | lamps and flashlight come on |
| 20:00 | Night | Builder locks; bills are issued; the night roll happens |
| ~22:40-02:20 | | archetype trouble windows; enemies active |
| 06:30 | | enemies leave; battery recharged; reviews, consequences |

## 4. Guests and the booking puzzle

Three archetypes, with different needs (`core/systems/guest_needs_system.gd`):

| Archetype | Pays/day | Wants | Brings at night |
| --- | --- | --- | --- |
| Quiet Guy | 70 | hygiene, safety, the bonfire, food | **Silent Man** |
| Drunk | 120 | the pub, the shop, fun; needs toilets often | **The Tourist** |
| Cheap Chick | 190 | showers, the lake slide, comfort | **The Girl** |

- Per-archetype pressure curve: up to 3 guests safe, then tiny / small / medium / large
  odds, guaranteed at 24 (repeats). Unhappy guests count double.
- The puzzle: a wide mixed camp spreads the odds but needs more kinds of facilities;
  taking the first booking that arrives fills the camp with whoever wrote first. Lazy
  booking makes a hard night; deliberate booking (mix + the right facilities, so nobody
  is unhappy) makes a quiet one.
- Facilities can be closed by circumstance: no power (unpaid bill), broken sewer, rain
  (outdoor attractions), a breakdown. Closed facilities make unhappy guests.

## 5. Night: the enemies

All of them: forecast before encountered (night risk + one feed line on first sign);
avoidable by attention (each has a tell and a counter); bodies are lit by the scene, so
in the dark they exist only where the flashlight or a lamp touches them.

| Enemy | From | Tell | Counter | Punishes |
| --- | --- | --- | --- | --- |
| Silent Man | Quiet Guy | footsteps / whispers behind you; sometimes he is standing there | react: turn, move | standing still in the dark |
| The Tourist | Drunk | a flash charging somewhere (rising whine) | turn your back before it fires | looking at him |
| The Girl | Cheap Chick | static and humming growing; she stands where the light ends | keep her in sight, keep to the lamps | looking away; she drains the battery while watched |
| The Antlered Man | 2+ archetypes in one night | heavy footfalls along the fence | stay off the fence line, stay in lamp light | being near the fence in the dark |

Together they contradict each other (watch the Girl, never watch the Tourist, never stand
still for the Silent Man), which is what makes a lazily booked camp lethal.

Lamp posts (built by day) are the night's safe ground; the flashlight has ~7 minutes of
light per charge for a ~10 minute night and stutters when low; stamina allows ~6 s of
sprint.

## 6. Upkeep

Every building has a condition (0-100%) that drops daily by its `maintenance_decay`.
**Above 50% nothing breaks.** Below it, each in-game hour it may break down (up to 10% per
hour at 0%). Worn buildings look worn (darker, corroded); poor ones carry an amber hazard
sign, broken ones a blinking red one. Walk up and **hold R**: servicing is cheap and quick,
repairing a breakdown costs a quarter of the building. The maintenance crew (Camp Status >
Upkeep) fixes everything at 1.5x, daylight only. Rules: `core/systems/maintenance_rules.gd`.

## 7. Economy

- Starting money 850; demolish refunds 50%, fee 4 per tile.
- Income per guest per day (above); the most profitable guests bring the most dangerous
  enemy.
- Electricity: billed at 20:00 for the previous day (2.2 per kWh, 3 kWh per power unit,
  12/day base), due 3 days later. An overdue bill cuts the grid: lamps off, power-hungry
  facilities closed, and a 6-minute UPS countdown to game over. Paying restores the grid.

## 8. The pipe crawl (sewer repair)

Inspired by pipe-crawler games: you crawl the sewer with only a hand-drawn paper map of
the pipes. The map does **not** show where you are. You can only turn at junctions and
never turn around 180°; you navigate by coordinates printed at junctions, by counting your
turns, and by rare landmarks (cracks, scratches, junk). The broken section is marked on the
map. Hold E at the leak to clamp it, then find the ladder again. From day 3 (or at night)
something lives down there: it moves a junction at a time toward you, your light held on it
down a straight pipe holds it back, and you hear it first. One red high-heeled shoe lies in
one of the pipes. Code: `scripts/sewer_pipe_minigame.gd`, check: `tools/pipes_check.tscn`.

## 9. Weather

A designed state machine in game minutes (`core/systems/weather_system.gd`): clear about
half the time, fog favoured at dawn, storms in the late afternoon and evening, ~7 changes
per day, 40 s visual crossfades. The anomaly (red haze) only at night, rarer and more
likely the stranger the camp (hrotfaktor), at most once a day. Rain closes outdoor
attractions.

## 10. Presentation rules

- Everything 2D is pixel art on an integer scale: baked bitmap fonts (Silkscreen, Tiny5,
  Jersey 10), bevelled plates, no rounded corners, no smooth gradients (darkening is a
  flat shade with ordered-dither edges, as the Build engine did with shade tables).
- The terminal is a separate, period-correct Win95 aesthetic (it is a program inside the
  world), the HUD and menus are the game's own Build-engine chrome.
- New art: generated with Grok Imagine (AGENTS.md §7), then keyed, downsampled and snapped
  to the game palette, so it matches the existing sprites pixel for pixel.

## 11. Open questions

1. Win condition: Vera returns on day 8. What does a "good" week look like, and what does
   the ending say about what you let in?
2. How much may the terminal lie? (Section 2 rules apply: specific, never numeric.)
3. The raccoon thing: tie it to waste (dumpsters overflowing) as a fifth threat?
