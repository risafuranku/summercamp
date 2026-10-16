# DESIGN.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-16*

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
- **The details we have** (each used once, or rarely): the extra guest on the Builder map;
  the insects falling silent before you see anything; the HUD face glancing at what is
  behind you (and, on some still nights, at nothing); the radio drifting onto a station that
  plays a music-box phrase and then one pip per guest, plus one; the 03:00 night log
  stamped with tomorrow's date, reporting the operator asleep at the desk; a sleeping
  stay with no booking at the bottom of GuestRack; Vera's mails knowing where your socks
  are. Checked by `tools/uncanny_check.tscn`.

## 3. The first hour

A new week starts at the desk in the reception, the computer already booting. Vera's
first mail, Beeternet, Builder 98, the first tent and toilet: all of it on the screen.
Then the first booking is accepted and Vera writes "You can get up, you know": Esc, and
you stand up from the computer into a camp you have only seen as a map. A title card
(THE CAMP, DAY 1) marks it. From then on the day is split between the screen and the
place. (Checklist: `scripts/quest_manager.gd`.)

The first night is quiet: nothing has been in the camp long enough to bring anything, and
there are no night jobs (`main.QUIET_NIGHTS`). Vera's 20:06 mail says so and sends you to
the room behind the office.

## 3c. The office and the back room

The reception is a place, not only a desk (`scripts/reception/`). Everything usable glints
under the cursor (pixel glints, `materials/hover_glint.gdshader`) and the cursor is your
gloved hand (`scripts/ui/hand_cursor.gd`): a carved arrow, the pointing finger over things,
the flat palm at doors, the fist while you hold a job.

- **The phone** on the counter opens a DOS-style close-up (`scripts/closeup/`): lift the
  handset, dial, hear it ring. Who answers is `phone_book.gd`: the numbers are the ones on
  the noticeboard (Vera's notes, held up to read in their own close-up). The electrician
  Novotny comes when you ring him and only then: his van on the gate road, his torch, the
  generator, the fee (double after nine). He refuses the nights the Antlered Man is out.
  Other numbers are the world: the district, Jednota, the pub, the police who say lock
  the door, the talking clock, Vera's answering machine (it changes after three bad
  nights), and the lake keeper's crossed-out number, which after 23:00 is picked up once.
- **The back room** through the door in the office's left wall: your bed, the little
  set (the programme, the test card and its tone after midnight), the VFD alarm clock.
  Sleep is only at night and only while nothing is out there (`camp_office.sleep_refusal`):
  you lie down, watch the set, your eyes close, the night passes in quarter hours (so
  the jobs, the dawn and the bills happen in order) and the alarm wakes you at 06:30.

## 3b. Daily rhythm

One in-game day = 16 real minutes (1 real second = 1.5 game minutes,
`BalanceConfig.GAME_MINUTES_PER_SECOND`; an experiment, tune by feel). The night is ~7.

| Time | Phase | The player |
| --- | --- | --- |
| 06:30 | Day | Builder unlocked; bookings, building, upkeep, talking to guests |
| 18:00 | Evening | last building window; guests drift back |
| 19:30 | | lamps and flashlight come on |
| 20:00 | Night | Builder locks; bills are issued; the night roll happens |
| ~22:40-02:20 | | archetype trouble windows; enemies active |
| 06:30 | | enemies leave; battery recharged; reviews, consequences |

## 4. Guests and the booking puzzle

Six archetypes, with different needs (`core/systems/guest_needs_system.gd`):

| Archetype | Pays/day | Wants | Brings at night |
| --- | --- | --- | --- |
| Quiet Guy | 70 | hygiene, safety, the bonfire, food | **Silent Man** |
| Drunk | 120 | the pub, the shop, fun; needs toilets often | **The Tourist** |
| Cheap Chick | 190 | showers, the lake slide, comfort | **The Girl** |
| Tramps | 55 | the bonfire, the pub, fun; barely wash, sleep anywhere | **The Whistler** |
| Family | 150 | everything at once: food, toilets, the field, the slide, safety | **The Extra Child** |
| Mushroom Pickers | 90 | sleep, food, the shop; quiet; up at four | **The Basket Man** |

- Per-archetype pressure curve: one guest of a kind is safe; tiny at 2, small from 3, medium
  from 7, large from 11, guaranteed at 15 (repeats). Unhappy guests count double. (It
  was 3 safe until the 2026-10-09 playtest: two full cabins and nothing ever happened.)
- The puzzle: a wide mixed camp spreads the odds but needs more kinds of facilities;
  taking the first booking that arrives fills the camp with whoever wrote first. Lazy
  booking makes a hard night; deliberate booking (mix + the right facilities, so nobody
  is unhappy) makes a quiet one.
- The inbox is slow at first: bookings arrive 07:00-20:00, about three on day 1 rising
  to ten on day 7, never more than a few waiting; spam now and then. At night at most
  one false alarm (a relay test, a wrong number), and the belt pager beeps for every
  new mail while you are out: you go to the office not knowing which kind it is.
- Guests mostly keep to themselves: a third are out in the open by day; the rest rest
  in their lodging, stand at the lake or walk out of the camp by the gate road, the
  forest edges or the lake path for hours. Twenty guests, and where is everybody?
- **Arrival.** Accepting a booking does not put anyone in the camp. The party is on the
  road for an hour or two (ARRIVALS in the HUD counts down), then stands outside the
  barrier at the gatehouse; it lifts and they walk up the starter path to the reception
  and queue. The player checks them in at the desk, by hand, the way Papers Please did
  it: their card and booking into the register, the right key off the board (only for a
  room that is made up), the stamp, the papers back. Until then they wait, grumble after
  ~45 minutes and drive off after ~2.5 hours with a one-star review; stamped REFUSED they
  go at once and say so. Time at the desk sours the mood they arrive with. Late at
  night someone unbooked may stand at the counter; his card is wrong. Write him in and
  the nights get worse.
- **Rooms.** A new tent or cabin is *unprepared*; when its last guests leave it is
  *dirty*. Either way you go in and do it by hand: look at the mess (it glows under the
  cursor), hold the mouse, hear the work, see it change. The bed is always there; the
  rest is a new mess every time (`core/systems/mess_rules.gd`): a seed and a level, so
  the bottles are somewhere else each time and how bad it is depends on who stayed.
  A new room has only the builders' sawdust and wrappers; a quiet pensioner leaves a
  couple of things; three lads after three nights leave cans, sick and cigarette ends
  all over the room and the bathroom (toilet, sink, floor). Families leave toys and
  food, tramps ash and tent pegs, pickers rotten mushrooms.
  The checklist in the corner says what is left. An upgrade brings new furniture: the
  empty room needs making up again. Rules: `core/systems/room_rules.gd`.
- So five booked parties at the gate and five unmade cabins is a real rush: that is the
  warden's job, and it is the day's main loop next to the Builder.
- Facilities can be closed by circumstance: no power (unpaid bill), broken sewer, rain
  (outdoor attractions), a breakdown. Closed facilities make unhappy guests.

## 5. Night: the enemies

All of them: forecast before encountered (night risk + one feed line on first sign);
avoidable by attention (each has a tell and a counter); bodies are lit by the scene, so
in the dark they exist only where the flashlight or a lamp touches them.

| Enemy | From | Tell | Counter | Punishes |
| --- | --- | --- | --- | --- |
| Silent Man | Quiet Guy | footsteps on the gravel behind you, closer each time, stopping when you stop; a whisper at your ear | turn round and put light on him; under a lamp he will not come nearer; at the whisper, turn round at once | standing still in the dark |
| The Photographer | Drunk | the ratchet of a film advance where he settles; a red focus lamp blinking in the trees with beeps that speed up; the flash whine | turn your back or get behind something before the flash (he gives ~3 s); the flash lights the place up from his side | looking at him when it fires |
| The Girl | Cheap Chick | static and humming growing; she stands where the light ends | keep her in sight, keep to the lamps | looking away; she drains the battery while watched |
| The Whistler | Tramps | a campfire tune whistled out in the trees, moving | do not walk towards it; stand under a lamp until the tune breaks off | following the sound into the dark |
| The Extra Child | Family | a child humming among the tents, back turned | torch off, walk past, never shine the light on it | looking at it with the torch |
| The Basket Man | Mushroom Pickers | 02:30-06:00, a wicker basket creaking out of the trees, a knife scraping | stand still while it is near; it only sees movement | moving while it is close |
| The Antlered Man | 2+ archetypes in one night | heavy footfalls along the fence | stay off the fence line, stay in lamp light | being near the fence in the dark |

Every hit can be explained afterwards: each enemy says where it is and when it is about
to strike, by sound first, and the counter always works (tools/enemy_check.tscn plays
both the careless and the careful player against the Silent Man and the Photographer).

Together they contradict each other (watch the Girl, never watch the Tourist, never stand
still for the Silent Man), which is what makes a lazily booked camp lethal.

Every enemy reports a *presence* (its visible body, or where its last sound came from).
Within ~26 m the crickets, frogs and the owl fall silent, fast, and come back slowly;
within ~18 m the HUD face widens its eyes and glances left or right toward it when it is
outside your view. It is a tell for the attentive, never an arrow.

Lamp posts (built by day) are the night's safe ground; the flashlight has ~5 minutes of
light per charge for a ~7 minute night and stutters when low; stamina allows ~6 s of
sprint.

## 5b. Night work

The night is not for waiting. A director (`scripts/night_jobs.gd`) plans 2-4 jobs per
night between 21:00 and 04:30 and pages you for each (HUD: TONIGHT, plus the waypoint):

- **Breaker**: the main at the generator trips; every lamp is out and powered
  facilities shut. At the distribution board one circuit has a fault that throws the
  main again whenever it is up. The way to find it is written on Vera's note inside
  the door: all down, main up, then one at a time; the one that throws it stays down.
  If that was a lamp circuit, half the camp's lamps stay dark for the rest of the night.
  Left until dawn, an electrician resets it for $60.
- **Lamp**: one lamp post goes dark (hold R at it).
- **Sewer**: the sewer blocks; toilets and showers close (crawl the pipes).
- **Toilets**: the block blocks (go in and unblock it).
- **Someone is in the corn**: only with wanderers in camp (drunks, families, tramps,
  mushroom pickers). Past the wicket gate in the west fence the corn is cut into a maze,
  new every game (`scripts/cornfield.gd`). The lost guest stands at the end of some
  corridor and calls out every few seconds; press E and they follow you, walk them out
  through the gate (+15 mood). The scarecrow is in there: it never moves while you can
  see it, and steps one tile closer whenever you cannot, faster the longer you take
  (`scripts/corn_hunt.gd`). Hold the flashlight on it a moment and it is somewhere far
  off the next time you look away. If it reaches you: a hit, and the guest bolts back
  into the corn. Left until dawn, they walk out alone and won't say what they saw (-18).
  The way in is readable: what they dropped (cans, a sock, a bottle) lies along the path
  from the gate to them, and their lighter clicks on and off, a small warm glow over the
  stalks. Following you, they talk ("Is it still behind us?"). The crickets go quiet
  when the scarecrow is near; when it moves, leaves and husks come down where it went
  through; held in the light it tilts its head, once. Mist lies in the corridors at
  night, thickest before dawn. On the TAB plan the gate and the field are drawn, and the
  job is circled there.

So the night is "keep the camp running" and "something is out there" at the same time:
the lamps you fix are the safe ground the enemies respect.

## 5c. The day: life and small trouble

By day the camp must sound and feel lived in, and the warden has more to do than the
Builder (`scripts/day_events.gd`).

- **Life.** While guests are about, the facilities make their noise: kids at the slide,
  a football match, a guitar at the fire (tramps, or anyone after 19:00), the pub through
  its door, children between the tents when a family is in. Far off: an axe, a village
  dog, a moped on the road. Rain silences everything but the pub.
- **Trouble.** Two events on day 1, up to five with a full camp, between 08:30 and 18:30.
  Each pages, shows in the TODAY list with a waypoint, and has a deadline:

| Event | When | Fix | Left alone |
| --- | --- | --- | --- |
| Rubbish dumped | always | hold E by it | every guest's mood -6 |
| Raccoons in the bins | bistro / shop / pub | E: shoo | -$40, mood -4 |
| Jednota delivery | bistro / shop / pub | E at the van by the gate | no bread, mood -5 |
| A boy is missing | a family in camp | find him at the camp's edge, or (45%) at the end of a corridor in the corn maze, E | the family -20: "he came back by himself, humming" |
| Noise complaint | tramps or lads next to pickers / quiet ones / families | talk to the loud party | the quiet ones -15 |
| A branch across the path | paths; likelier in wind | hold E: saw it | mood -4 |

Sorted ones give a little back (the lost boy's parents tip). Night ends the day's chances.

## 5e. Omens

No scheduled events: the night camp produces its own small wrong things out of the
simulation (`scripts/omens.gd`, checked by `tools/omens_check.gd`). Every in-game minute
you are outdoors between 21:30 and 04:30 there is a chance of an omen, proportional to
the **pressure** of the camp:

    pressure = 0.3 + 0.08 x guests + 0.35 x unhappy guests + 0.5 x kinds of thing that
               have come so far + 0.3 x nights something came
               + 0.4 if something hunts tonight + 0.6 if the camp is dark (breaker, cut)

Which omen is a weighted draw from what fits where you stand and who is in the camp; an
omen you have had is a third as likely next time:

| Omen | Can happen when | Weight |
| --- | --- | --- |
| a torch walks along the fence nearest you, outside it | a fence 22-40 m off, in sight | 1, +0.8 in the dark |
| one person too many, 25-30 m off, facing the office | guests in camp | 0.5 + 0.1/guest + 0.2/unhappy |
| the barrier lifts and drops with nobody at it | you are within 45 m of the gate | 0.8 |
| the office phone rings four times | you are 25 m+ from the office | 0.7 |
| a person and a torch at the fence by the office; the insects stop | 2+ kinds have come, or pressure 3+ | 0.3 x pressure |

At most one a night, then at least 15 hours of quiet. Rules as in §2: one specific thing,
seen across open ground (line of sight, never next to you), gone when you walk up to it
or when its time is up. Measured over 400 simulated weeks: an empty camp sees ~0.4 a week,
an ordinary one ~1.6, an overfull troubled one ~3.7, never in the same order twice.

What comes at night also comes back harder: every third night something came raises the
enemies' minimum difficulty (1 -> 2 -> 3), from the ledger, not the calendar.

## 5d. The end of the week

Vera's last mail (day 7, 20:10): "Leave the books on the desk and the terminal on. I will
count them myself." On day 8 the pager says her train gets in at eight, and at 08:00 the
game stops on THE BOOKS (`scripts/week_ledger.gd`, `scripts/ui/week_report_screen.gd`):

- **The ledger.** Takings against the starting till; guests hosted, average stars, parties
  who gave up at the barrier or stormed off; the seven nights, how many something came on
  and what it was; how often you were hurt; night jobs left for the morning.
- **The verdict.** A plain grade of money, reviews and nights: *good* ("the summer is
  yours"), *fair* ("sleep more and accept less"), *poor* ("your bus is at ten").
- **The count at breakfast.** If nothing ever came, the number in the book and at
  breakfast agree ("I counted twice, because it is never right"). If anything came there
  is one more at breakfast than in the book, "like when your uncle ran it"; if the
  Antlered Man came, the extra one stood by the fence facing the office. The verdict
  answers *how well*, the count answers *what you let in*.
- **Then:** *Stay on* closes the week and the camp runs on with no end (Vera takes the noon
  bus back to town: "You know the way."), or back to the main menu.

## 5f. Work you can see

Every held job shows your hand doing it (`scripts/ui/work_hand.gd`): a Build-engine
"weapon" sprite of a gloved hand with the right tool (brush, hand broom, mop, rag, bin
bag, plunger, wrench, bare hand), rising from under the status bar and working the thing
under the cursor or crosshair: circles for scrubbing, strokes for sweeping and mopping,
picking up, patting the bed flat, plunging, turning the wrench, with suds, dust, drops
or sparks flying. The mess itself jitters under the brush. All of it moves in steps,
8-12 frames a second, never smooth: the guests' walk, the bonfire's flames and sparks,
the desk fan, the wicket gate, the ripples where a fish jumps. That stutter is the look.

## 6. Upkeep

Every building has a condition (0-100%) that drops daily by its `maintenance_decay`.
**Above 50% nothing breaks.** Below it, each in-game hour it may break down (up to 10% per
hour at 0%). Worn buildings look worn (darker, corroded); poor ones carry an amber hazard
sign, broken ones a blinking red one. Walk up and **hold R**: servicing is cheap and quick,
repairing a breakdown costs a quarter of the building. **Toilet and shower blocks are
cleaned by hand inside** like the rooms: the worse the condition, the more there is to
do (puddles, mould, hair in the drains, writing on the stall doors); a breakdown is one
more job (unblock the toilet, screw the shower head back on). The last job done pays
the supplies (or the spare part) and puts the block back to 100%. The maintenance crew (Camp Status >
Upkeep) fixes everything at 1.5x, daylight only. Rules: `core/systems/maintenance_rules.gd`.

## 7. Economy

- Starting money 850; demolish refunds 50%, fee 4 per tile.
- Income per guest per day (above); the most profitable guests bring the most dangerous
  enemy.
- Electricity: billed at 20:00 for the previous day (2.2 per kWh, 3 kWh per power unit,
  12/day base), due 3 days later. An overdue bill cuts the grid: lamps off, power-hungry
  facilities closed, and a 6-minute UPS countdown to game over. Paying restores the grid.

## 8. The pipe crawl (sewer repair)

*Reworked 2026-10-16: the staging of the thing is `scripts/pipes/pipe_director.gd`.*
The thing is honest (blind, goes to the last noise, folds away from the light, takes you
only after it has breathed at you from next door) and a director plays with you around it:
build-up with signs only, stalking (closer, breathing, the torch stutters), one staged look
(it crosses a junction ahead, peeks round the next corner, crouches at the end of your
beam, is behind you: hold S to look back), then it backs off for a while. Unseen it may be
moved to set a scene up, never closer than its sounds told you. What you meet grows with
your visits (the camp office counts them): the first time down it never shows, only knocks
that answer the clamp, the drip stopping, and wet long-fingered hand prints on the ladder
when you come back; the second time glimpses; then the hunt. The water along the bottom
runs away from the leak: follow it upstream. Lore: the lake keeper Hruby went down with
the 1993 works and did not come up (the web's ghost page, his logbook, his phone number).

The original design:

Inspired by pipe-crawler games: you crawl the sewer with only a hand-drawn paper map of
the pipes. The map does **not** show where you are. You can only turn at junctions and
never turn around 180°; you navigate by coordinates printed at junctions, by counting your
turns, and by rare landmarks (cracks, scratches, junk). The broken section is marked on the
map. Hold E at the leak to clamp it, then find the ladder again. From day 3 (or at night)
something lives down there: it moves a junction at a time toward you, your light held on it
down a straight pipe holds it back, and you hear it first. One red high-heeled shoe lies in
one of the pipes. Code: `scripts/sewer_pipe_minigame.gd`, check: `tools/pipes_check.tscn`.

## 8b. The generator shed and the board

The shed is entered like any interior (`scripts/shed/generator_shed.gd`): the set room is
full of junk in front of the steel door (shove it aside, once), the switch room behind is
locked (the key hangs on the office noticeboard) and holds the distribution board. Its
close-up is a Grok painting of the real board with the lever, the breakers, their lamps
and the ammeter painted onto it (`scripts/breaker_panel.gd`). Some nights a coat hangs in
the corner; after you have been at the board, it does not.

## 8c. The lake trip

The keeper's rowing boat (`scripts/lake/lake_trip.gd`): W pulls a stroke, A/D turn, the
gloved hands on the oars. The far shore is his boathouse: looked at like an interior (the
camp across the water, its lamps at night), his logbook in the doorway, his jetty to fish
from (carp and pike to the kitchen, now and then a red shoe). Sometimes at night something
long passes under the boat. Nothing there is required.

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
- Interiors are places you stand in, not walk through: the head turns within limits
  (cursor at the screen edge, or the arrow keys), the cursor stays free for clicking things,
  and every room is closed on all sides because you can look at all of them
  (`scripts/interior_look.gd`).
- The terminal is a separate, period-correct Win95 aesthetic (it is a program inside the
  world), the HUD and menus are the game's own Build-engine chrome.
- New art: generated with Grok Imagine (AGENTS.md §7), then keyed, downsampled and snapped
  to the game palette, so it matches the existing sprites pixel for pixel.

## 11. Open questions

1. ~~Win condition~~: answered in §5d (the books on day 8). Still open: should a poor
   week end the run outright instead of offering Stay on?
2. How much may the terminal lie? (Section 2 rules apply: specific, never numeric.)
3. The raccoon thing: tie it to waste (dumpsters overflowing) as a fifth threat?
