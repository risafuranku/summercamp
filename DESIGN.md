# DESIGN.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-16*

How the game is meant to feel and the rules that produce it. For what exists today see
[PRODUCT.md](PRODUCT.md); for wiring see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 1. The idea

Aunt Vera's old camp is yours now: the family camp at the reservoir, shut since last summer
(after your uncle went), and Agrostroj Hlubocany wants the land for a feed mill. The
district inspects on 19 October; if the camp is not open and paying by then, the land is
sold. So you have a month, the autumn of 1998 (19 September to 19 October: the golden end of summer, the leaves, the fog and rain of October, bare trees and the first snow on the last nights). Vera is not coming back to run it; she writes from her sister's in Pelhrimov, tips and warnings, and the
curse is only ever hinted at (the count at night, the shoe, the uncle). By day it is a pleasant, slightly fiddly tycoon you play
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
              one guest of that kind turns into it for the night
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
- **The radio is a readable tell, not a detail.** It reads the NIGHT RISK lamps, the hour,
  what is out tonight and how close it is (`scripts/radio/radio_dread.gd`), so it gets
  worse exactly when the night does: by day a skip or a sag at most; then static under the
  songs, another station bleeding through, the dial drifting onto the OK 76 buzz with a
  bird or a knock on the frequency; at its worst, between songs, the transmitter reads its
  code words in Czech (tonight's word names what is coming, then the guests, plus one).
  With something close it drops to a dead carrier. Its broadcasts are Czech by design,
  like the songs: the station is a place, not UI. Checked by `tools/radio_dread_check.gd`
  and `tools/radio_game_check.tscn`.

## 3. The first hour

A new camp starts at the desk in the reception, the computer already booting. Two mails:
Nela's, and Vera's "The camp is yours now" (the land, Agrostroj, the nineteenth, where to
start). It carries the links to Builder 98 and GuestRack (a click installs them, as
the button on their tab does); CampStat is on the panel already. Little mail after that: the checklist
(`scripts/quest_manager.gd`) sends only "The book" and "Tonight", and the story pool is
the camp and its people, not system notices.

Outside, the old cabin by the office (`main._place_ruined_cabin`) is the first job and the
lesson in how a room works: boarded up, weeds up the walls, roof sheets in the grass, its
condition at the bottom (broken: hold R to patch it up, as any building), and inside every
mess there is (`mess_rules` derelict pool) and the bed to make. It takes no bookings until
it is patched up (`GuestManager.get_bed_metrics`), so the first requests come when the camp
is open. Then the programs, new lodging, the toilet block, Mirek's booking and the desk.
A title card (THE CAMP, DAY 1) marks the first step outside. From then on the day is split
between the screen and the place.

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
  generator, the fee (double after nine).
  Other numbers are the world: the district, Jednota, the pub, the police who say lock
  the door, the talking clock, Vera's answering machine (it changes after three bad
  nights), and the lake keeper's crossed-out number, which after 23:00 is picked up once.
- **The back room** through the door in the office's left wall: your bed, the little
  set (the programme, the test card and its tone after midnight), the VFD alarm clock.
  Sleep is only at night and only while nothing is out there (`camp_office.sleep_refusal`):
  you lie down, watch the set, your eyes close, the night passes in quarter hours (so
  the jobs, the dawn and the bills happen in order) and the alarm wakes you at 06:30.

## 3b. Daily rhythm

One in-game day = about 19 real minutes (1 real second = 1.25 game minutes,
`BalanceConfig.GAME_MINUTES_PER_SECOND`; 1.0 was too slow, 1.5 a touch quick). The night is ~8.

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

*Reworked 2026-10-18 with the user: simpler rules, every enemy worked out to the end;
18+, the most nerve-racking thing we can make.*

**A guest turns.** Each night one guest of a kind may turn into that kind's thing (the
forecast as before: the more of one kind, the unhappier, the likelier). It is that guest,
by name, from their own bed (`main._pick_turned_guest`), and the first time you see it
far off it still wears their clothes. Get through the night and they come out of their
room in the morning, remembering nothing; let it get you and they are gone by morning,
their bed not slept in, their things in the lost and found (`main._claim_turned_guests`,
`GuestManager.vanish_guest`). Several kinds can turn on the same night: their counters
contradict each other, which is the price of a camp booked without thought. (The
Antlered Man, who came for two kinds at once, is gone.)

**One grammar for all of them**, so players learn it, each with its own counter:
omen (far, unmistakably this one) -> approach (the tell grows, sound layers, the insects
stop) -> test (it tries its trick; you answer with the counter) -> strike (you did not:
the close-up of what the guest has become, the hit, the screen) -> gone (a trace left
behind; the next loop comes sooner and harder). The guest mutates through the night in
stages (whole art per stage, Loab-like nightmare, never cheap gore), farther ones first.

**The screen goes wrong** when something is near (`scripts/night/nightmare_fx.gd`, shared
by all): grain, the colour bleeding apart and draining to rust as it comes closer; on a
strike the frame stops, a face for a few frames, tears and split channels, red, a ring in
the ears with the world muffled under it.

All of them: forecast before encountered (night risk, then its sound on first sign);
avoidable by attention (each has a tell and a counter); bodies are lit by the scene, so
in the dark they exist only where the flashlight or a lamp touches them, and their
**eyes** (below) are what you see of them in the dark.

**No text at night** (Richard, 20. 10.: it kills the vibe). No line on the screen says
what is out there or what just happened: no "somebody is whistling", no "he was right
behind you". The sounds, the eyes, the sixth sense and the HUD face say it. (The brains
still call `_announce`/`_feed`; main keeps the line for the log, `last_enemy_line`.) In
co-op a warden who is hit cries out, a real call far off from where they are, not a line.

**Every enemy has its own eyes** (`scripts/enemies/enemy_eyes.gd`, STYLES): two small
glowing points in the world, in whole game pixels, the shape near and a point far off
(never under two game pixels, two always apart), only while it is in the dark and in
your line of sight; a torch on them makes them flare. They are in the world, so they show
through a cabin's window and the other wardens see them. You know what it is before you
know where it is:

| Enemy | Eyes |
| --- | --- |
| Silent Man | his glasses: two round lenses glinting a dull yellow, nothing behind them, a little too far apart, never blinking; now and then a light runs over the glass, one lens then the other. They sit on his glasses in every piece of art (tilted with his head) and flare white in your torch before he comes apart |
| The Photographer | one eye, the lens: a cold blue ring with a light in it; the red focus lamp blinks in its middle |
| The Girl | her eyeshine: two pale points, each blinking on its own, one a little higher, only where the torch points but does not reach (to 45 m); nearer, bigger and wider apart (her face stretching). The terror pass (20. 10.): when your torch dies near her she takes her step in that dark and you see her eyes there, nearer; while your torch holds her, a second pair of her eyes opens off to one side with a soft giggle (look and it is gone, and she has moved); under a lamp she goes round the edge of its light towards your back; the drone and the heart as she comes |
| The Antlered Man | deer eyeshine in the skull's sockets, pale green, high, far apart; both go out together now and then |
| The Basket Man | two wet red points deep in the hood, close together, swinging slowly over the ground |
| The Extra Child | nothing while its back is to you; turned and running, two small white points that do not blink |
| The Whistler | not on its body (never in sight): two pale slits up in the trees where the tune was, a little while after each one |

| Enemy | From | Tell | Counter | Punishes |
| --- | --- | --- | --- | --- |
| Silent Man | Quiet Guy | footsteps on the gravel behind you, closer each time, stopping when you stop; a whisper at your ear | turn round and put light on him; under a lamp he will not come nearer; at the whisper, turn round at once | standing still in the dark |
| The Photographer | Drunk | always there: he hums wherever he is, a weak lamp on his chest strap and the camera's red standby blink; he walks from spot to spot in plain view (steps, the film wound on as he stops), raises the camera, the focus beeps speed up, the flash whines (~2-3 s); a shot every 7-10 s | turn your back or get behind something before the flash; indoors draw the curtains (every building's windows look out for real, scripts/ui/window_portal.gd) | looking at him when it fires, or an open window you can see when he fires through it: a lot of health (16-26), a white blast, ringing ears, his flash-lit picture burnt in; then he waves with the instant photo, giggling |
| The Girl | Cheap Chick | far off, eyeshine: where your torch points but does not reach, two small pale points where her eyes are, each blinking on its own; a woman humming; heels scurry on the gravel while you are not looking, and a sting when you find her again nearer; close, the torch dies in your hand for a moment by itself (her face is there for a frame, once a loop all of it) | she moves only while you do not see her, and in the dark you see her only in light (the torch on her, a lamp near her, or very close): keep her lit and in view, back to a lamp (she never steps into its light; stay under it ~18 s and she gives the loop up); never walk towards her (the torch dies more often, and in each dark she is a step nearer) | looking away, letting the light leave her; the torch drains five times over while it holds her; look away ~3.5 s and she may be right behind you when you turn (face to face, the jump: back off). Always the guest's own colours, only deformed: the guest -> fixed smile, white eyes -> legs too long, flushed cheeks -> neck and arms stretched -> her back to you, face turned round -> arms to the ground. Strike: you cannot look away; her drooling face, then stretched long, then the jaw dropped too far; the shriek in static; black and a ring. Leaves a red heel |
| The Whistler | Tramps | a campfire tune whistled out in the trees, moving | do not walk towards it; stand under a lamp until the tune breaks off | following the sound into the dark |
| The Extra Child | Family | a child humming among the tents, back turned | torch off, walk past, never shine the light on it | looking at it with the torch |
| The Basket Man | Mushroom Pickers | 02:30-06:00, a wicker basket creaking out of the trees, a knife scraping | stand still while it is near; it only sees movement | moving while it is close |

### 5a. Outdoor hunters, indoor tormentors (the rule for every enemy)

An enemy is one of two kinds, so the night never stacks two deadly things in one place:

- **outdoor hunters** (the Silent Man, the Photographer, the Girl, the Whistler, the Basket
  Man) can hurt you only outside. Indoors they cannot reach you, and they know where you
  are: they work at getting you out (sounds at the walls, the door, the window) and, if
  you hide long enough, they take it out on the camp instead (a guest's night goes wrong:
  mood, the review, the camp's name). Hiding is safe and it costs.
- **indoor tormentors** (to come: the thing in the pipes is one already, in its own place)
  are dangerous only inside a building, and they are what makes a cabin no refuge.

The night's jobs (the breaker, the sewer, a lamp) and the pager pull you out regardless.
The director budgets the night so that at most one hunter presses on a warden at a time.
In co-op an enemy hunts one warden; what it does to make itself felt reaches only that
one; the other warden's light counts as light (watching each other's backs is the
counter for two).

### 5a.1 The Silent Man in full (`scripts/enemies/silent_man_brain.gd`)

Often the first night's only enemy: the first meeting has to be the best scare of the
game, every time, and never scripted to a place.

- **Lurk**: you in light, he hums round a corner in the dark 7-13 m off, leaning out now
  and then. The light is safe and you still feel watched (a little of the sixth sense).
- **The stare** (half his lurks once you have met him): not round a corner but out in
  the open dark 9-15 m off, facing you, his glasses on you, motionless. Look away and
  back: he is a step nearer, his head a little further over, never into the light.
- **The glasses go out**: step out of the light and the humming stops and the two
  yellow lenses go dark, both at once: the only time they ever "blink". They stay dark
  till he has taken his first step. That is how you know he is coming.
- **The glint**: your torch beam far past where it lights anything (to ~45 m) catches
  his lenses; they swell and flash back at you, white (a low sting the first time each
  round). He is not lit, so he does not go: he is just standing there.
- **His head goes over**: the nearer he is, the more his glasses tilt; within a few
  metres it now and then cocks hard, near sideways. In the dark the eyes are all you see.
- **Glasses that are not him**: when the sixth sense is high, a pair or two at the
  edges of your view in the dark, 10-20 m off; look at one and it goes out. Only the
  warden he hunts sees them.
- **The first meeting** (once per camp, `director.ever["silent_man_met"]`): the first
  step out of the light, the humming stops and he is there in front of you at the edge
  of the light, caught mid-stride; look at him and he goes, look away and he is gone when
  you look back. The first time he reaches your neck you get longer to react, and he does
  not bite: he turns you round to him, face to face, the skin over his mouth tearing, and
  comes apart. No text says the rule: the turn itself teaches it.
- **The sixth sense** (`nightmare_fx.set_presence`): a pressure builds while you are out
  in the dark and he comes on, faster the closer he is; it drains in the light. You feel
  it as a drone in the ears that climbs (two low tones beating, a pressure whine), your
  heart (slow, then fast), the picture's edges closing in, banded, pulsing with the heart,
  the colour going to rust, the torch catching and stuttering in your hand. The insects
  fall silent and the HUD face looks round, as for every enemy.
- **At your neck**: the whisper, his breath, cloth, the frame stops for a beat, his hands
  come over your shoulder from the side he is on, and he holds you (half speed). Turn
  round (a light on him) or get away; else the catch (ear, above, turned round), and when
  it would be the last, his kill (strangled, the neck turned, the mouth).
- **Indoors** (an outdoor hunter): in order, a pause of 16-28 s between: the humming
  through the wall; three knocks, and a fourth after you have stopped listening; the
  handle tried; a hand brushing along the outside wall, following you; a tap at the
  window (in the office, his figure at the window; in a cabin, he stoops to the glass of
  the window you look at, his face in it and his glasses glowing, lit by the room's light
  falling out, and is gone in a few seconds: the window is a view of the real camp);
  then he goes to a guest (a Quiet Guy first): a tent zip somewhere, slowly, and that
  guest's night is spoiled.

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

## 5g. The night's director

The hunters (§5) come from the night roll; everything around them is played by a director
(`scripts/night/night_director.gd`, its hands `director_effects.gd`, checked by
`tools/director_check.gd`). It does not make the night busier, it makes it *about you*.

- **Tension** 0-1 builds over minutes from the hour, the camp's pressure (§5e), what hunts,
  the dark, being out alone, and cues you ignored; investigating calms it a little.
- **States**: DORMANT, OBSERVATION (it only watches), UNEASE, SUSPICION, ESCALATION,
  MANIFESTATION by tension; CONFRONTATION while a hunter is within 14 m (it keeps quiet and
  lets the hunter's own tells speak); RECOVERY for half a minute after anything big.
- **Budget**: points that come back with time; each event costs its weight (2-8), big ones
  are rare and never back to back; at least 18-46 s between two events, 8 s after you
  arrive somewhere; most decisions come to nothing. A seven-minute night: about 8-10 things.
- **Character**: the camp's guests set it (quiet ones and pickers OBSERVER, drinkers and the
  girls MIMIC, families and tramps DISTURBER; strangers let in add OBSERVER, a dark camp
  DISTURBER, tonight's hunters HUNTER). An archetype much weaker than the strongest does
  nothing: a camp of drinkers hears knocks, calls and steps, not figures in the window.
- **You**: hide in the office most of the night and the office is where it comes (the
  tension rises for it too); keep watching the window and it happens elsewhere; ignore
  things and the night tightens. A near-empty camp with you inside all night still gets a
  few small things, never a big one.
- **Who counts**: every guest checked in, awake or asleep (at night they all sleep).

| Event | Where you are | Archetype | What remains |
| --- | --- | --- | --- |
| tapping on the window, then a person outside it facing it | office | observer | prints where they stood |
| knocking (or two knocks and one), the handle tried | office, back room | mimic, hunter | wet prints on the step |
| the phone at 23-04: breathing | office, back room | mimic | |
| something along the back room's wall | back room | hunter, disturber | |
| the radio loses the station | office | mimic, disturber | |
| the room changed while you were out (curtain, light, radio, lamp) | coming in | disturber | yours to put back |
| a lamp dies over you, stutters back | outdoors in light | disturber | |
| steps behind you that stop when you stop | outdoors | observer, mimic, hunter | |
| a call from the woods | outdoors | mimic | |
| a person crosses the camp in the dark | outdoors | observer | prints |
| an omen (§5e) when it wants one | outdoors | observer, disturber | |
| a light in the woods where no lamp is, breathing; out when you are halfway there | outdoors | observer | |
| movement in a guest's cabin while they sleep (one a guest reported by day) | near it, outdoors | mimic, hunter, observer | |
| the cup on the PC desk is on the window sill (put back at dawn) | coming in | disturber | |
| a branch snaps in the dark near you | outdoors | observer, hunter, mimic | |
| the insects stop all at once, for a few seconds | anywhere | all | |
| a cabin door bangs 18-60 m off; nobody comes out | outdoors | disturber, mimic | |
| steps in the back room, which is empty | office | mimic, hunter | |
| one of your sleeping guests at the edge of the trees, still, facing you; gone at 13 m (a night in three, after midnight) | outdoors | mimic, observer | the log names them; by day: "Slept right through. Why do you ask?" |

Never in close-ups, jobs, the lake, a guest's room; never a door blocked or a hurt.
The morning after, CampStat's NIGHT page has **last night's log** with times and, before
the night, **the camp tonight**: one line of what its character means for you. The insects
go quiet as the state rises and come back after.

## 5h. Night work at the computer

The PC is free at night (the Builder locks): pocket money for whoever stays at it, and
while you type you are not watching the camp.

- **DataPunch 98** (the District Office, from the Courier's web page): copy old register
  cards 1961-1989 into four fields; $4 a card without mistakes, half with one or two, none
  with more; 24 cards a night. Some cards should not be in the box.
- **The guest book**: every review arrives as an entry to answer (thank, apologise, set them
  straight). The answer moves the camp's reputation (-0.25..0.25), which moves the chance
  of booking letters; it fades a tenth every morning.
- **Bazar Hlubocany** (`bazar-hlubocany.cz`, from the portal): a third of the parties that
  check out leave something behind (families more): a Walkman, a camera, a fishing rod. It
  goes to the office's lost and found and onto the camp's own ads; put it up and it sells
  from the next morning, at its worth ($4-45). Other people's ads carry the district (a
  camera whose last film nobody developed, antlers by the camp fence, a red boot on the
  reservoir shore). From the sixth day the box may hold a child's red shoe, small and wet,
  that nobody left: it sells for a dollar to a buyer with no name, and is back the morning
  after.

**Across the day.** From day 3 a guest may say someone else was in their cabin in the night
(a day event: knock at their door and look round with them; nobody, the boards under the
bed wet). Look or not, the director remembers that cabin: at night, near it, it makes sounds.

## 5d. The end of the month: the inspection

Vera's last mail (day 30, 20:10): "The man from the district comes at eight. I will come
out on the first bus and stand next to you... I will count them myself." On day 31
(Monday 19 October) the pager says so, and at 08:00 the game stops on THE BOOKS, "THE
INSPECTION" (`scripts/week_ledger.gd`, `scripts/ui/week_report_screen.gd`):

- **The ledger.** Takings against the starting till; guests hosted, average stars, parties
  who gave up at the barrier or stormed off; the thirty nights, how many something came on
  and what it was; how often you were hurt; night jobs left for the morning.
- **The verdict.** A plain grade of money, reviews and nights: *good* (the district
  withdraws the sale, "the winter is yours"), *fair* ("the sale is off, for now"), *poor*
  (they will recommend the sale, Agrostroj's pegs are in, "your bus is at ten").
- **The count at breakfast.** If nothing ever came, the number in the book and at
  breakfast agree ("I counted twice, because it is never right"). If anything came there
  is one more at breakfast than in the book, "like when your uncle ran it". The verdict
  answers *how well*, the count answers *what you let in*.
- **Then:** *Stay on* closes the month and the camp runs on with no end (Vera takes the noon
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

## 5i. The camp on Goggle

The PC's fifth tab, Reviews (key 5, after Mail), is the camp's page on Goggle, a 1998 search
engine's places page (`scripts/reviews/goggle.gd` the logic, `os98/apps/goggle_app.gd`
the page). Every guest's review goes up in public; the stars are the plain average of
what is up, to one decimal. The page was there before you: seven reviews from last
summer, mostly bad, and one nobody should have written ("Do not let the boy in the red
shoes in. He knocks.", answered by someone who is not you).

- **The guests are the progression, not the rating** (Richard, 2026-10-20: the start
  must play; the rating stays on the page and may matter again later, for now it opens
  nothing). Builder 98's blueprints open by the most guests the camp has had at once
  (`goggle.peak_guests`, main counts them every two seconds): tents, cabins, the
  basics and the **corn stand** from the start (the basic service: a cob and a drink,
  cheap, when nothing else is open); at 10 guests the pub, caravans, the hammock, the
  gnome and the pitch; at 20 the restaurant, the playground, ping-pong, the flagpole and
  level-2 rooms; at 30 the Jednota and the slide; at 40 level-3 rooms. A tier once
  reached stays open. Locked cards are grey with a padlock and the guests they wait for
  ("for Stavitel partner camps"); the room upgrades say 40 GUESTS.
- People look before they book: each star above or below three moves the booking
  chance by 0.07.
- SpotlessName Ltd take a review down by the next morning, for $45 and $30 more for each
  one after. Now and then Goggle notices (10 %, 5 % more per removal): the review stays,
  the money is gone, and the page carries "Unusual review activity" and loses 0.3 stars
  for three days.
- The owner can answer: an apology to a one- or two-star review has a 40 % chance of an
  edit by the morning (a star more), blaming the weather never does. Answering the same
  review in CampMail's guest book answers it on Goggle too.
- The tab's badge counts new reviews, red when one of them is bad.
- Photos (the tab after the sorts): last summer's guests' snaps of the camp, a cheap
  compact's prints with the orange date in the corner (`tools/artgen/goggle_photos.py`,
  made from the game's own frames), big on a click. In one of them somebody stands at the
  edge of the trees behind the tents; nothing on the page says so. Under them "People also
  searched for": Agrostroj Hlubocany's feed mill (planned; its site opens in the browser),
  U Jezera, Jednota Lesna.

## 5j. Builder 98, a game in the game

The user: "the Builder should feel like a game of its own: an imitation of the 90s
tycoon games, and fun." Builder 98 is Stavitel software's shareware site planner, and it
plays like RollerCoaster Tycoon or Transport Tycoon on a cheap 1998 PC
(`builder_module.gd` the program, `crt_map_panel.gd` the map). A star rating of its own
was left out: the camp's rating is Goggle (§5i); the blueprints open by guests (§5i).

- **A build is a building site.** For a moment the plot is a scaffold with a worker
  kneeling at a plank, hammering (two frames, a blow every 0.36 s), and on bigger plots a
  second one on his own beat; dust at the blows, the hammer's sound; then the building
  stands up with a thump and a bounce. Small things go up in a second, a cabin in about
  three, the biggest in four. The sim has the building at once: the site is only the
  map's picture, so nothing else waits for it. A room upgrade is a site too. In co-op the
  host's builds are sites on the other machine as well.
- **A demolition leaves rubble.** A heap of planks, bricks and tin where it stood, a wisp
  of smoke, the collapse's sound, gone after four seconds. The refund and the bulldozer's
  fee pop up side by side.
- **Money you can see.** Coins fly from the building that earned them to the cash: from a
  room when its guests pay, from a business when its takings rise. The cash in the
  toolbar is an odometer: the sum rolls to the camp's money, its wheels turning over one
  into the next, green coming in, red going out.
- **The tool on the pointer.** Over the map, the bulldozer, the path, the lamp or a
  blueprint (any building) sits beside the arrow; the arrow's tip is still where the
  click goes.
- **Rows by dragging.** Benches, lamps, flower beds, picnic tables, gnomes and flagpoles
  are dragged out in a straight row, a ghost on every tile and the price on a tag
  ("6 x $25 = $150"), built on letting go, as many as the till pays for; undo takes the
  row back. A click without a drag builds one, as before.
- **Music.** A cheerful General MIDI loop (ElevenLabs, cut to sixteen bars with
  `tools/audiogen/loop_cut.py`) plays while the Builder is open, from the PC's speaker
  (quieter away from it). From 18:00 to the lock at 20:00 it goes a little flat and slow,
  more so on the eve of a bad night (NIGHT RISK high); the speaker button in the toolbar
  turns it off (remembered by the PC).
- **The map has the camp's weather and hour** (read from the camp, never worked out on
  the map): rain in slanting streaks with the wind's slant and splashes, the map a shade
  darker under it (a step more in a storm); fog as a thin dithered veil with banks
  drifting with the wind; snow as flakes over the snowy ground; the storm's flash with
  the camp's; smoke leaning with the wind (flat in a gale); autumn leaves blowing in a
  wind. The evening in palette steps before the night: gold toward five, red at a
  quarter past six, the blue hour; a pink dawn.
- **What the guests think.** A bubble over a guest a few seconds in every nine: their
  worst need (hungry, the toilet, tired, dirty, frightened), cold after a cold night, a
  smile when all is well. A click on a guest opens their card: name and party, room,
  mood, six needs in bars, what they last thought (theirs, from their stay; now and then,
  more often when they are frightened, one that is not quite right: "The lake looked at
  me."), Follow to keep them in the middle of the map.
- **The map lies, rarely, never in a log.** Late in the day, once in a long while, a tent
  nobody built stands beside the others for one frame (no number over it). One tile of
  each camp (from its seed, open forest away from the middle) says in the status line
  that something is buried there. The site report now and then counts one guest more
  than there are, after six.
- **Graphs** (the toolbar's chart, or G): Transport Tycoon's window in the 98 look, one
  page at a time: Cash, Guests (people staying), Mood, Goggle, Takings (a line per kind
  of business, each name in the legend turning it off and on), the last two weeks with
  today's point live. Main records each day that ended at dawn
  (`scripts/builder/day_graph.gd`, saved as "graph").
- **The Courier's extra editions.** The district paper the web has a page of (the
  Hlubocany Courier) brings out an extra in the Builder when the camp does something
  worth printing: the first caravan, the slide, a pub, its own Jednota, the Mega gnome,
  each Goggle tier, being caught tidying up its reviews, ten, twenty, forty, eighty guests
  at once. A newspaper window: the masthead, the date, the headline, a halftone of the
  thing, the story; a fanfare; a click puts it away. Each runs once; a camp already
  going when this came in has its old news counted as printed.
- **The district's diplomas**, each once: Most Improved Camp (a star more on Goggle than
  last summer's page), the Guests' Favourite (ten or more in good spirits), the Tidiest
  Camp (ten buildings or more in good repair). The district's own paper (Grok, no words)
  with the award typed on it.
- **Shareware.** Stavitel software's nag after ten builds and every twelve after
  ("You have built 10 things with an unregistered copy..."), and once when it starts.
  Help > Register...: $99 of the camp's money, the key by mail the next morning
  (Stavitel software), typed in; registered: no nag, About says so, and the Mega gnome
  (a garden gnome four and a half times over on a 2x2, $1998) is in Decor. All of it on
  the PC (os_shell's store "builder98", `scripts/builder/shareware.gd`).
- **Cheats**, typed on the map, written down nowhere: BOHEMIA ($5,000, and the next
  morning a letter from the district asking where it came from), KAREL (the uncle's old
  camp over the map a few seconds, pale), MOLE (the buried tile marked), VERA (Vera has
  a word). Their letters are tool keys too; once a cheat is typed the tools are put back
  as they were.
- **About** has the credits and, under them, a little bulldozer flattening tents in a
  strip of grass; it drives itself until the arrow keys take it.
- The Jednota is buildable again (the camp's own; locked at Goggle 4.0).
- **The buildings stand as the camp has them** (playtest 20. 10.: the mirrored front and
  back pictures put the pub's door where the 3D pub has a wall). Every building's four
  pictures are drawn from its own 3D model, from the four corners the map turns to, at the
  map's angle and one scale for all (`tools/iso_render.tscn`), repainted by Grok in the
  tycoon look and fitted back over the render, so the door, the porch, the chimney are
  where they are in the camp and a gnome is a gnome's size next to a pub.
- **The map turns** a quarter at a time, as RCT's park did (T, Shift+T back, the toolbar's
  turning tile): the ground, the paths, the trees, the guests and the order things stand
  in turn with it; the spot in the middle stays there. The PC remembers which way.
- **Its people.** The guests are drawn as the camp has them: walking, or posed by what they
  are at (sat at the fire, eating, a kick on the pitch); their faces over them now and then
  (a smile, hearts, a song, anger, panic for the toilet, fright), a Zzz over the lodgings
  somebody sleeps in. Their walk towards you and away and each kind's own doings come in
  frames (the quiet man watching the lake or smoking, the drunk staggering or sick, the
  woman in heels with her cigarette and her shopping, the tramp strumming on a log or
  carrying firewood, the father hanging washing while the boy kicks a ball, the old picker
  after a mushroom): `peeps/<kind>_<0-7>.png`, the camp's pose until they are there.
  They walk behind the buildings and trees in front of them (RCT's: what stands nearer is
  drawn again over them), not over the roofs. Their card says what they are about ("by the
  fire", "in the pub", "asleep"), how many nights they booked and what they have paid.
- **The small life of the map** (Grok frames, stepped; none of it without the pictures):
  the camp's dog trotting from lodging to lodging, sniffing, sitting, barking; ducks
  paddling and dipping on the lake and the sun glinting on the water; moths round the lit
  lamps after dusk; a mouse darting out by the pub, the bistro, the Jednota or the corn
  stand; ants at the picnic tables when close enough to see; now and then a few birds
  crossing the whole map with a flutter. The trees sway in a wind (three frames a second,
  each a beat after its neighbour: a gust going over the map).
- **A building site in its stages**: the foundation (formwork and fresh concrete), the walls
  going up in a scaffold, the roof on its trusses under a tarpaulin, a third of the time
  each, each with its sound (the concrete, the planks, the tiles); the worker hammering as
  before. **A demolition** brings the little yellow bulldozer (Transport Tycoon's): it
  drives in over what went, shoves, backs off in a puff of smoke, dust bursting where it
  pushed. The tools on the pointer move (the blade, the spade, the lamp blinking, the
  blueprint unrolling).
- **Every click has its sound** (Builder's own, not the PC's): a toolbar button, a
  catalogue card sliding out, a window opening and closing, a tool picked up, a refusal, the
  map turning, the message line's tick.
- **The message line** along the foot of the map, RCT's: what happens in the camp as it
  happens, each with its little picture (a guest's new thought, who is at the gate, who
  moved in, who drove off, a room to clean, toilets gone filthy, a breakdown and its fix,
  a review, the Courier and the diplomas), sliding in, creeping along when long; a click
  takes the map there or follows the guest. What matters more (a breakdown, guests driving
  off, a diploma) pops up a moment as a small window in the map's corner.
- **The building's card is alive**: its picture turns slowly through its four sides, and
  besides the room, the guests in it, the wear and the power it says how clean a toilet or
  shower block is and what a business took and served today.
- **The map's sound** under the pointer: the lake lapping, the woods, the playground, a
  pub's door, the camp; quiet loops fading into each other as the pointer goes over the map.
- **Lit windows at dusk**: the lodgings lived in light their windows on the map as the camp
  lights them (`window_lights.gd`): a lamp behind the curtains, the telly's blue, a candle
  with the power off, a tent glowing through its cloth; the windows are the model's own
  (the render's window pass), so they sit on the picture's windows.
- **Music**: the loop's seam measured (no click, the beat lands on the loop's start, a dip
  of a few hundredths of a second where it was cross-faded); still to be heard by an ear.

## 5k. The god cursor

The user: when the Builder builds, a giant computer cursor appears high over the camp you
stand in and puts the paths and buildings down into it: surreal, the camp a simulation
somebody assembles with a mouse. **Only theatre**: the Builder builds at once as before,
the camp's sim has the building at once (guests, books, everything), and nothing waits for
the show, hinders or hurts (`scripts/god/god_cursor.gd`).

- **What it is**: the Builder's own pointer (the OS's arrow with the tool beside it: the
  blueprint, the path, the lamp, the bulldozer), thirty metres of flat pixels in the sky,
  the haze of the camp's fog over it and banks of mist drifting through it, dithered away
  and back in Build's way; it glides slowly to the work and rises back into the haze after.
  A deep hum like thunder and organ pipes from far off; the slowed, giant Okna click and
  ding; heavy landings with an echo from the woods (ElevenLabs, `assets/sfx/god/`).
- **Paths like dominoes**: the pointer clicks, the line's tiles come down one after
  another from high up, a thud and dust each (louder every third).
- **Buildings in their parts**: the foundations, the walls, the roof (its own meshes, split
  by height), each falling in steps of a twelfth of a second, landing with a boom and a ring
  of dust; small things in one piece.
- **Bulldozing** is short: the pointer dives with the bulldozer, clicks, and what was there
  (copies of its meshes: the camp has already taken it away) is pressed flat in four steps
  and sinks into the ground in a burst of dust and a crunch.
- **The queue**: what the Builder ordered waits as a shadow on the ground (the building
  hidden, not a wall to walk into) and comes down in turn, quicker the longer the queue.
  While the warden sits at the PC it waits; it comes down when they stand up, seen through
  the office window (a portal into the camp), from its door or outside. In co-op each
  machine plays its own theatre of the builds it hears of: the other warden outside sees
  the host's Builder come down (who builds is told by what happens where).
- **Under it**: the shadow grows as it falls; guests round it jump out of the way and look
  up; a warden standing under it is pushed off and the view shakes. Nobody is hurt.
- Leaving the camp (the menu, a load) brings everything still waiting down at once, unseen.

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

## 7b. The businesses' rooms (point and click)

Decided with the user on 2026-10-18 ("interiors aim at the feel of point-and-click
games"). The pub, the bistro and the Jednota are rooms you look round in and click:
everything usable glints under the gloved finger, and the doors are things too (the flat
palm): click one and you walk to it, it swings open on the dark behind it and you come
in through the next room's door, which swings shut behind you. No side tabs, no pushing
the head through the end of the turn.

- **Where the work is.** Over each place a small Grok picture bobs while there is work
  waiting there: the tap and the bottles while somebody waits at the bar, the washer
  when the clean mugs run out, the pass while somebody waits for a plate (seen from the
  dining room over the kitchen door), the stove when nothing is fried ahead, the till.
  Outside, the HUD's guests cell says how many wait to be served and the waypoint
  points to the business.
- **The bistro's logistics.** The dining room (na place) is the guests' tables, the till
  and the books; the kitchen behind it and the cellar under it are the work. See "The
  bistro" below.
- **The pub's cellar.** A door by the bar end goes down to the kegs: the keg on the line
  on its pallet (the keg's station, below), the full ones along the rack (a keg is 50
  pints of the books' beer), crates of rum and kofola; click the rack for the books.
- **The corn stand** is one more of them: E behind its counter (either warden), its two
  stations on the counter with the camp beyond it (below, "The corn stand"), the books on
  the frame (BOOKS, or the cash box), Klasek 98 on the office PC runs it like the others.
- **For two.** The other warden is in the room with you at the job they have open,
  behind the bar pulling a beer, at the bottles, the washer, the pass, the stove, the
  till, over the books; the place they are at is theirs (no mark over it for you), and
  what they serve lands on the tables on both machines.

### The bistro (2026-10-19)

*Asked for by the user on 2026-10-19: "the interior full of details, fun to explore like a
point-and-click adventure, for four in co-op, good indicators like Traveller's Rest; the
stations a game of their own like Papa's; the square close-ups were strange and
unclear; think up the cellar." Then: "the minigames less like AI pixel art, more like
imperfect human Build-engine textures."*

- **Nobody waits on tables.** You cook; what you make goes out by itself. A guest who
  sits down reads the menu a moment and their ticket clips onto the rail (a ding); over
  their head a bubble with the dish and a bar for how long they have waited (green,
  amber, red: three minutes of game time and they get up hungry). The plate rung out at
  the pass comes through the hatch and lands on their table; the money floats up.
  Everybody at a table orders: a family of four is four tickets.
- **The chain, cellar to table** (`core/systems/bistro_rules.gd`). Potatoes are peeled
  and cut into raw chips in the cellar; cheese is sliced and breaded there (flour, egg,
  crumbs, in that order: out of order it is badly breaded, burns sooner and goes out
  poorer). Upstairs the stove fries the slices (each side to golden, turned by hand) and
  the chips (the basket down, up when golden); the pot keeps the goulash, topped up from
  the catering tins, back to the boil before it is ladled, stirred now and then or it
  catches and the bottom goes in the bin; the steamer gives a loaf of dumplings, cut with
  the cotton thread a slice at a click. The pass builds the plate to the ticket, Papa's
  way: the ticket hangs big beside it and ticks off what is on the plate; the bell
  judges it (the right dish, the right counts: six dumplings is not four, onion or not,
  tartar or not; how long they waited) into the money, a tip and one to three stars.
  The plates come back dirty when they have eaten: the sink, scrub, the rack. No clean
  plates, no plating.
- **The stations are in the room, in 3D** (decided with the user on 2026-10-20: "the
  stations in the 3D room, no flat screens"; `scripts/business/station3d.gd`, shared by all
  four businesses). A station is its counter in the Build room: the counter's top is its
  Build texture (the pan, the fryer, the bowls painted on it), the things on it are Duke 3D
  sprites at the room's pixel (91 px to a metre): the slices lying in the pan, the basket
  on its hook, the plate you build, the stacks of plates standing by. Everybody in the
  room sees them, whoever is at the station. Click the station and the camera goes over
  its counter in steps, twelve a second; there you point, press, hold and drag in the
  room itself: a slice off the tray into a free place in the pan (the place lights up
  under it), the spoon round the pot, the plate into the water. A click does the same
  thing for whoever does not drag. Over the counter hangs the order rail (Papa's,
  `ticket_rail.gd`): the tickets as little papers on a steel rail across the top of the
  view, in the room's pixel, swinging on as they come; the one picked hangs lower and is
  big in the corner, ticking off what is on the plate at the pass. Each thing that cooks
  has its column standing over it (a pixel meter: the side in the oil, the basket, the
  pot's heat and its bottom), and the stove's and the pot's columns are mirrored small in
  the frame at the other stations of the room. Under the room the frame
  (`station_hud.gd`): the sentence of what a click would do (like an old adventure
  game's verb line), BACK (S, the right button), the room's other stations (Tab, 1-4).
  Nothing explains anything: the glint, the lit target, the ticket, the columns and the
  sounds do.
- **Things go on without you.** The pan and the fryer cook and burn, the pot catches,
  whether anyone is at them: the room says so (Traveller's Rest marks over each station:
  the frying bars and "!", the pot's portions and STIR, the tickets at the pass, the
  dirty plates, LOW over the cellar's corners and over the cellar door; smoke when
  something burns).
- **Look at things.** Everything worth a look in the three rooms answers a click with a
  line under the room (the deer's eyes, the clock that is four minutes slow and today
  fast, the coat on the stand nobody came in with); the pointer names what it is over.
  Mostly dry; a few are wrong in the quiet way of the rest of the game.
- **The cellar** is the prep room: the potato peeler and the chip cutter, the breading
  table, the shelves of stock (the books), and behind a chain-link partition the
  machine nobody ordered, PROTOTYP 540: unplugged, dead by day; at night (and from eight
  while the bistro is open late) its lamp is lit with the plug out, the gauge stands off
  nought, the crank turns a quarter by itself.
- **PROTOTYP 540** (decided 2026-10-20, agent C, on the user's brief: the goulash's meat
  for nothing, at night, if it is fed; what it is fed is the bistro's dark side and is
  never said). Some nights a jute sack lies against the wall beside it, tied, heavy, that
  nobody brought down: always the night after the camp woke without somebody (a guest
  gone at dawn, whom the night took: `main._claim_turned_guests`), else about one night
  in five. Hold the button on it and it goes up into the hopper; the lid drops, the lamp
  burns steady, the machine shakes in its bolts and grinds till morning, and in the
  morning its tray is heaped with meat for twenty goulashes, in the cellar's stock as a
  lot of that day that nobody paid for. A sack nobody lifts is gone in the morning. The
  game never says what is in the sack, never shows it, never puts the sack and the one
  who was gone side by side: no name, no shape, no line in the feed or a review; the only
  word for it is the verb, "Lift it into the hopper". The hands never go near it. Rare,
  quiet, serious (`bistro_rules.proto_*`, `kitchen.gd _proto`, `machine_station.gd`,
  `actions.biz_gift`; `tools/proto_check.tscn`, `tools/proto_shots.tscn`).
- **For four.** Each station is one warden's while they are at it: the others see them
  there in the room at the job (the cook's pose, the washer's), see their name over it
  instead of its mark, and get "Jana is at the stove" if they click it; the bar's tab
  for it shows their name. The kitchen is shared: a slice put in the pan, a tray filled,
  a plate out of the hatch is an op every machine applies at once
  (`scripts/bistro/kitchen.gd`, `Coop.send_kitchen`), so the stove burns the same on all
  four; the tickets are worked out from the guests on each machine alike. Splitting the
  work is the game: one in the cellar, one at the stove, one at the pass, one washing up.
- **The hands** work the kitchen by job (below, "The hands"): one at the cellar fills
  the trays, one at the stove turns and racks the slices and minds the basket and the pot,
  one at the pass plates whatever ticket it has everything ready for, one at the sink
  washes up. What nobody does is yours; a warden at a hand's station works beside them.

### The pub (2026-10-20)

*Agent C, phase 2 of the businesses (the user, 20. 10.: "the bistro and the pub: 3D
minigames that work like Papa's Pizzeria, with sprites and textures like the Build
engine; clear the first time without a tutorial").*

- **The bar is the work.** Three stations along the bar top on the barman's side, the
  camera behind them in the narrow way between the bar and the bottle shelf, as the
  bistro's over its counters (Tab, 1-3 between them), and the keg in the cellar:
  - *The tap* (the middle): the chrome tower seen from the side, its faucet over the
    drip tray, the black handle on top (Grok sprites). A clean mug off the board at its
    left goes under the spout (a click); take the handle and draw it towards you (down
    the screen): beer with a little head; push it away: foam only; let go and it springs
    back. The head settles back to beer while you wait; over the rim it runs onto the
    tray. The knife by it takes the top off the head. The mug over the bar goes to the
    beer mat picked on the rail, else to whoever's order it matches best: hladinka (beer
    to the line, a collar of foam to the rim), snyt (half and half), mliko (all foam, a
    finger of beer); the wrong pour comes back. The column by the mug is how full it is.
  - *The bottles* (the left end): the rum, the zelena, the slivovice and the kofola in a
    row; take one (a click) and it comes up beside its glass (a shot glass, the tall one
    for the kofola); hold: it tips over the rim and pours, the glass fills to the line
    (the column, its green window). Then the glass over the bar.
  - *The sink* (the right end): the empties come back from the tables onto the bar in
    front of it when they are drunk; one into the water, hold and rub up and down, the
    dirt comes off stroke by stroke; clean, onto the board by the tap. No clean mugs on
    the board, no beer.
  - *The keg* (the cellar, by its pallet): the keg on the line with what is left in it
    chalked on it; the head (coupler) on its hose: a click takes it off, held on a full
    keg it screws down. A spent keg (the chalk cross) or a flat one is rolled off the
    pallet and a full one rolled on from the rack (a keg is the books' 50 pints). The
    gas: hold the valve and drag up for more, down for less; in the green it pours right,
    low it comes slow and flat, high all foam, and it creeps down as the tap runs. A keg
    on the line keeps three days (six with the keg cooler); then it is flat: no head,
    poor beer, and the guests say so; what is left in it goes down the drain, the books'
    waste.
- **The orders** are beer mats on the rail over the bar: the guest's name in pencil,
  what they want (its picture and its word), a stroke a drink they have had, the wait
  under it; the picked one big in the corner. One at a time each, the next when the last
  is drunk (half an hour of game time); after an hour and a half of waiting they stop
  ordering. The money, the tip and the stars Papa's way (the shared systems below).
- **The hands at the pub**: the tap's pours the oldest beer ordered (a fair pour, never
  a perfect one), the bar's the shots and the kofolas, the washer's washes the mugs, the
  cellar's changes a spent or flat keg and sets the gas right; each slips now and then (a
  short pour, a mug dropped). They stand at their places behind the bar and by the
  pallet; one whose station a warden takes stands aside.
- **The gear**: the second tap (the beer comes faster; a hand draws two at once), the
  glass washer (at the end of the way behind the bar: the empties come out clean by
  themselves), the keg cooler (in the cellar: a tapped keg keeps six days), the quick
  coupler (the head clicks on in a moment, a keg changed in no time).
- **For four**: as the bistro: each station one warden's while they are at it, seen
  there, named, refused to the others; what is poured, washed and changed is an op every
  machine applies at once (`scripts/pub/taproom.gd`, `Coop.send_taproom`).

### The corn stand (2026-10-20)

*Agent C, phase 3 of the businesses. The playtest's split stays (18. 10.: "the corn stand
is the bottom of the screen, the top is the live view into the camp"); the user, 20. 10.:
the stations in 3D, like the bistro's and the pub's.*

- **Behind the counter, out in the camp.** E at the stand and you are behind it: a camera
  of its own in the camp's world stands behind the counter and looks out over it, so the
  counter is the bottom of the picture and the camp the top of it (whoever comes up to the
  stand, the paths, the weather), through the Build palette like every view. Your warden
  stands behind the counter meanwhile (the others see you there). The frame under it as
  at the bistro: BACK (S, the right button), the two stations (Tab, 1-2), BOOKS.
- **Two stations on the counter**, worked where they are (the stand's own Build
  pictures laid on its counter top; everybody going by sees the cobs in the pot):
  - *The husking* (the left): the crate of cobs in their husks; a click puts one on the
    table (off the books' cobs); hold the button on it and pull away: a leaf comes off and
    flies into the bucket (four leaves; two with the husking table); then the silk at its
    tip, a click a tuft (three); clean, a click puts it in the bowl.
  - *The counter* (the right): the pot of boiling water, the board, the butter and its
    brush, the salt, the napkins, the cash box. A click on the pot puts a husked cob from
    the bowl in (three places; six with the bigger pot); it boils pale, then bright yellow
    (done, nine seconds), then from twenty-one seconds grey and soft. A cob out onto the
    board (a click, however done it is), brushed with butter where the brush passes (hold
    and rub along it; the butter warmer does it in one stroke), a shake of salt a click,
    a napkin round it, then over the counter to the slip picked on the rail (else the
    oldest). Hard, soft, unbuttered or the salt far off and they hand it back. BIN throws
    away what is on the board.
- **The orders** are paper slips on the rail: the name, a cob, the salt they want (a mark a
  shake, NO S for none), the wait; the picked one big in the corner, ticking off BUTTER,
  the salt (green when it is right, red when too much) and NAPKIN. One cob each, all at
  once; after an hour of waiting they go. Papa's score from the wait, the build (butter,
  salt) and the cooking into the tip, the stars and the mood.
- **The hands at the stand**: the husk's takes cobs from the crate and husks them into the
  bowl (one dropped now and then), the counter's puts them in the pot as wanted, takes a
  done one out, butters it and salts it to the order (the salt off now and then) and hands
  it over; a soft one they throw away.
- **For four**: one warden a station (the other gets the husking: "Jana is at the
  counter"); the pot, the bowl and what was served are ops every machine applies
  (`scripts/corn/cornstand.gd`, `Coop.send_place`).

### The Jednota (2026-10-20)

*Agent C, phase 4 of the businesses. Decided with the user on 2026-10-20: store, shelf and
till work only; very dear; the guests love it; it needs several hands; its blueprint opens
at 30 guests (was Goggle 4.0); a building of three by three with a Build model and a Builder picture of
its own.*

- **The building.** Three tiles by three, $1800 and the licence (Pult 98) $100; the
  Builder's blueprint opens at 30 guests in the camp (Stavitel partner camps). A long single-storey
  1970s village samoobsluha under a flat concrete roof (`building_models._jednota`, Grok
  faces): the band of shop windows with green racks behind the glass, the glass door
  under a small canopy, the red board with the sheet-metal letters JEDNOTA (Lesna's), the
  crates of empties, the ice-cream freezer and the bench out front, the delivery door
  and the staff door with its bell at the back. The Builder's map has it from the front
  and from behind.
- **Two rooms.** The shop: tiles, oil paint, two tubes; the long green rack at the back
  with the cage trolley beside it, the till's counter on the right by the door and the
  queue along it, the bread rack, the fridge, the shelf of tins and the ice-cream chest
  on the left, the baskets by the door, the books on a shelf behind the till, the
  storeroom's door in the back wall. The storeroom: concrete under a bare bulb, the
  packing table with the shelf of cartons behind it and the trolley beside it, the empty
  pallet, last year's cartons (the stock: click for the books), the locker, the empties.
- **The guests** come in and look round at the racks for a few minutes, then take what
  they came for off the rack into a basket, each kind its own (the drinkers beer and
  salami, the families milk, rolls and ice cream, the pickers bread and veg; one to five
  things); what is not on the rack they go without, and say so in their review if half of
  it was sold out. With their basket they queue along the till in the order they came,
  kept in the shop while they wait; after an hour of it they put it all back and go.
  The camp's own Jednota is loved: a little more on their mood every time.
- **The till** (the counter top, from behind it): their basket's goods are clicked
  through one by one (a beep, the display adds it up, into their bag; the cabbage over
  the scale); then they put their money on the mat, the right money now and then, mostly
  the smallest note it fits under (5, 10, 20, 50); a click takes it into the drawer and
  the display shows the change. The change is counted out of the drawer's four places
  (1, 2, 5, 10) onto the mat, a piece back with a click, CLEAR all of it; GIVE (Enter)
  hands it over. Short and they say so and wait; too much and they keep it (the money
  lost, the score lower). Their receipt in the corner: each thing with its price, rung
  up in ink, the total, what they paid, the change. Papa's score from how long they
  stood and how right the change was.
- **The shelves** (standing at the rack): every good has its place (sweets and soap at
  the top; pickles, beer and veg; bread, rolls and salami; milk and ice cream at the
  bottom), a little picture of it on the shelf's edge, six a place (eight with more
  shelves). The boxes made up in the storeroom wait on the trolley: press on one, carry
  it to its place, let go, and its goods go up one by one as far as there is room;
  anywhere else it goes back on the trolley. What went off lies grey at the end of its
  place; a click throws it out.
- **The storeroom** (at the packing table): the cartons off the van on the shelf behind
  it (what the books have that is not on the rack, the trolley or in a basket; what the
  rack will run out of first on the lower board): a click brings one onto the table, a
  drag across its tape cuts it open (with the pallet truck they come open), held down
  the price gun prices what is in it, and onto the trolley it goes, six to a box. BOOKS
  on the frame for the order.
- **The hands**: the till's serves the first in the queue (a coin over now and then) and
  leaves the till to a warden who steps up to it; the second till's (gear) the second in
  the queue at its own counter by the door; the shelves' puts a box onto the emptiest
  place it has one for (one dropped now and then: broken); the storeroom's throws out
  what went off and makes up a box for what will run out first (twice as quick with the
  pallet truck).
- **Dear, and it pays with hands and a busy camp.** The shelf prices are the dearest
  (bread 5, salami 8, milk, beer, pickles, ice cream and veg 4, soap 5, sweets 3, rolls 2),
  the goods cheap off the van; with three hands at forty a day, a camp that sends
  twenty-five baskets a day, served well, pays the building and the licence back in about
  eight days (`jednota_rules.day_model`, `tools/jednota_check.tscn`); eight baskets a day
  lose money.
- **For four**: a warden a station, the others refused it ("Jana is at the till"); the
  rack, the trolley, the queue, what is rung up and the change on the mat are ops every
  machine applies (`scripts/jednota/jednota.gd`, `Coop.send_place("vecerka", ...)`).

### The businesses' shared systems (2026-10-20)

*Decided with the user on 2026-10-20 (Q&A): Papa's ratings; goods that go off; one order
for every place from the office PC once licensed; better gear as the only progression;
hands taken on one by one, each with a job and a shift; places open late into the night.
Built once for all four places (the bistro first); `core/systems/business_rules.gd`,
`actions.biz_*`, `scripts/business/`.*

- **How an order went down (Papa's).** Each order is scored 0-100 from its wait, its build
  against the ticket and its cooking (the slice's two sides across the golden window, best
  in its middle; the chips likewise; the goulash hot off the boil and not catching), and
  the score is the tip (none under 65, a third of the price from 80, half from 95), the
  stars (1-3) and the guest's mood. The guest remembers the best and the worst meal of
  the stay, and their review says so: "The fried cheese was perfect.", "The goulash was
  burnt at the bottom.", "Waited forever for my food at the bistro." (the review reaches
  Goggle as before). Food left on the shelf goes cold (a tenth of its quality every half
  minute, down to half) unless the heat lamp is bought.
- **The shift's end.** At 20:00 (or 23:00 when open late) the till prints its Z report: a
  long thermal receipt with the orders, the average score, the tips, the best and the
  worst order and whose they were, who went away unserved, what was thrown out, the
  takings and the wages tonight, one to three stars for the shift. It comes out of the
  till if you are in the place; else the books keep it (BOOKS, Z REPORT). The books also
  keep the place's running average.
- **Goods go off.** Each delivery is a lot dated the day it came; the oldest is used
  first. Past its days (bread and rolls 2, dumplings and milk 3, cobs and fruit 4,
  potatoes 5, cheese 6, beer 6 a tapped keg, the tins and the spirits never) a lot goes
  bad on the shelf: it is not sold, it is there in the cellar (sprouting, mouldy, bloated
  sprites) and in red in the books till somebody throws it out (THROW OUT: the books
  count it as waste). The chiller and the keg cooler double their goods' days. What the
  shelves cannot make today is crossed off the menu board in chalk.
- **Ordering.** In the place, on the books' ORDER page, as before (the van in the
  morning). With a licence (softsklad.cz) the office PC's SoftSklad window runs every
  licensed place at once: a tab per place, and one order across all of them that one van
  brings for one fee.
- **Gear, the only progression.** The menu is whole from the first day; what money buys
  is better gear for a place, Papa's way: the bistro's second fryer basket (two baskets'
  worth at once), the heavy pan (a fourth place, slower to burn), the dishwasher (the
  dirty plates in, clean out a while later), the big pot (twenty portions, catches
  slower), the heat lamp (fried food keeps hot), the ticket clock (the guests wait a
  quarter longer); the pub's second tap, glass washer, keg cooler and quick coupler; the
  corn stand's bigger pot, butter warmer and husking table; the Jednota's second till,
  pallet truck, chiller cabinet and more shelves. Bought in the books (GEAR) or on the PC;
  each is seen in the room once it is in (the lamps over the pass lit, the clock on the
  wall, the dishwasher on the sink's counter, the fourth slice in the pan).
- **The hands.** Taken on one by one from the three who ask at a place each day (the
  same three on every machine; nobody already working in the camp). Each is a person with
  an ID photo and the sprites of the photo (Grok), their speed (seconds a piece of work:
  9, 6, 4), their honesty (never said: a dishonest one asks a little less, their papers
  are thin, and now and then the books come up short, money or goods), their temper
  (warm, flat, sour) and the wage that follows from them. Each has a job (the place's
  front job first: the bistro's pass, the pub's tap, the stand's counter, the Jednota's
  till; then the others) and a shift (day, or late at half as much again). They are seen
  at their job in the room, at work; one whose station a warden takes stands back. They
  are slower and worse than a good warden: a slice left to burn, a plate dropped, six
  dumplings for four, a badly breaded slice. About one shift in twenty one does not come
  in (a note on the door, a line in the feed); paid at the day's close for the shift they
  did, and two days unpaid they leave.
- **The two nobody quite remembers** (asking now and then among the others, every few
  days): *Jaromir*, "has worked here before" though the camp was shut all last year:
  quick, warm, honest, cheap; when the place is shut at night he is at his place in the
  dark, and in the morning the plates are washed and what went off is gone, though nobody
  had a key. *Marta*, references left blank: as good and as cheap, never away, never
  announced in the feed, already at her place when anybody comes in, and her ID photo is
  a little different every other day (the eyes a touch further apart, the mouth a little
  longer). Let go, they do not argue. Neither is ever explained.
- **Open late** (the books' BOOKS page, or the PC): the place shuts at 23:00 instead of
  20:00. The night comes into it: some guests go out to it in the evening (the drinkers
  most), the prices are a quarter higher, the late shift's hands cost half as much again,
  and inside it the night's director plays it by its tension: the tubes buzz and
  flicker, static creeps under the room, something scrapes or knocks in the cellar, the
  breaker drops the lights for a few seconds (once a shift at most), and once a shift at
  most there is one more at a table than came in, facing away, dark, two small pale
  points for eyes, gone at the next flicker or when you look at it a moment. The
  forecast says so: from the afternoon the NIGHT RISK footer alternates with "PUB LATE",
  and the feed says the place is open late tonight. The scares are rare and fast; nothing
  in a place hurts.

### The businesses' polish (2026-10-20, "podniky")

*The user's brief of 2026-10-20 ("bring the four places to the top: looks, mechanics,
hands, sound, readability, economy, co-op"). The camp is about time: one warden manages the
upkeep, the rooms and one place, not all of it at once; a place takes one warden's whole
attention, or hands. Two wardens: one cooks, one cleans, or each holds a place.*

- **The ladder.** Corn stand < pub < bistro < Jednota, in what they cost to build and to
  license ($140/$60, $420/$120, $640/$140, $1800/$220), what a hand asks a day (15, 30,
  35, 40), what a visit spends and what it fills of the guests' needs
  (`data/buildings/*.tres` guest_services): the stand a quick bite and a small drink
  (hunger 45, thirst 25), the pub a light drink and fun (thirst 60, fun 50), the bistro a
  big meal and a big drink (hunger 95, thirst 55), the Jednota the most at once (hunger,
  thirst, fun, wash) and a bag to take home (below). The Builder's card says what a place
  fills ("food, drink, fun").
- **Thirst** is a need of its own (`guest_needs_system.NEED_THIRST`): it falls by day
  (twelve hours to empty, faster for the drunks), a night costs a little of it, their own
  water at the lodging brings it back to about half and no further: a proper drink is the
  places'. A guest short of it walks to one; over their head the blue plate with a cup
  (`need_thirst.png`), in GuestRack's list a NEEDS column with the worst need's plate and
  the words of all they are short of.
- **The Jednota's bag.** A basket rung up at the Jednota goes home with them
  (`guest_needs_system.STASH_FROM`, `use_stash`): food, drink, a magazine, the soap, which
  top their needs up a little a minute whenever they run low, for days, till the bag is
  empty. The top of the ladder pays for the whole stay.
- **The evening rush** (`RUSH_FROM` 17:45 to 20:00): supper time, everybody goes for food,
  a drink and some fun much sooner than by day (`RUSH_SEEK`), so every place has a queue.
  One warden at one place holds it; at all of them, no.
- **Two pointers in the rooms.** The gloved finger and the glint only over what does
  something (a station, a door, the books, a switch); over what is only worth a look the
  eye (`HandCursor.LOOK`, `cursor_look.png`): a click says a line under the room and
  nothing more. What is neither is not clickable.
- **Your hands at every station** (`scripts/business/station_hands.gd`): the right hand in
  the work glove comes up from the bottom of the view with the station's tool, Duke 3D
  style: whole pictures at twelve a second on the hands' pixel grid, lit like the other
  hands, the press phased (wind-up, the act held, the follow-through); the tongs over the
  pot and the grill, the butter brush, the salt, the tap's handle, the bottle, a mug at the
  brushes, the pencil marking a mat, the coins from the wallet and the till, the dart, the
  ladle, the opener, the knife, the wrapping paper; the bare glove for the rest. Off the
  work it sinks; it never turns. Each station says its tool (`hand_tool()`).
- **Papa's slip after every serve** (`station_hud.serve_card`): the wait, the order and
  the cooking as bars, one to three stars as they land, the money and the tip, a word for
  it (POOR, GOOD, PERFECT!), a sound by how it went; SENT BACK with their words when it
  comes back. The money floats up off the counter as before.
- **The Z report's mark.** The receipt has the goods used and the net, all the places'
  takings today beside this one's, the average stars; by it the manager's note in pencil:
  the shift's mark A to E (`business_rules.day_grade`: the orders' scores, how many of
  those who came were served, whether it paid) and the one thing to mend first (another
  pair of hands for the rush, mind the worst dish, order less more often, the wages ate
  the takings). SoftSklad's Books show the last mark and the goods used.
- **The hands by their ways.** Speed is how good and how quick their work is (a quick one
  pours better than a slow one), honesty is the till, and the temper is the guests' mood
  (`TEMPER_MOOD`: a warm hand cheers who they serve, a sour one sours them). A quick, warm,
  honest hand asks the most and can be better than a warden in a hurry. The stand's hands
  stand at their places behind its counter (`crew_figures` in `corn_stand_life.gd`).
  SoftSklad's Staff page says what the one picked is like.
- **The corn stand** gets its drinks: the little table at its end (a third station), iced
  tea run from the orange barrel's tap into a cup, raspberry lemonade poured into a bag and
  tied round a straw, filled to the line (`corn_rules.DRINKS`, `FILL_OK`); a drink slip of
  its own on the rail beside the cob's. The pot's water rolls (three Grok frames). The
  queue stands in a line out into the camp, slanting off so every one of them is seen
  from behind the counter, stepping up as those in front are served.
- **The pub's tab.** Nothing is paid as it is poured: a mark in pencil on the guest's mat
  (a stroke a beer, a cross a shot, a ring a kofola: `pub_rules.TAB`, the board's prices
  4, 3, 2). When they have had their last, or their time is nearly up, the mat comes back
  on the rail as BILL: at the tap's right their mat and the note they put down (often too
  big), and your black waiter's wallet with its four places; count the marks, take the
  note, the change onto the mat, hand it over. A guest pleased with the evening says
  "make it" a round sum (their tip). Short and they wait; too much and they keep it. Nobody
  comes in a quarter of an hour: the happy ones leave the money on the bar, the cross ones
  nothing. The hands at the tap and the bar settle bills too.
- **The pub's fun** (`core/systems/pub_fun.gd`): the LUCKY 7 in the corner (pull the lever
  down, three reels stop one after another; it is the camp's machine, so a warden plays for
  the fun of it, but three sevens and the pub cheers); darts at the board on the left wall
  (hold to aim, the hand sways the longer you hold, three darts against the last guest's
  turn); oko bere with the Czech pack at the second table, two dollars a game against
  whoever is in. The guests have their go too (`taproom._guests_play`): what they feed the
  LUCKY 7 is the pub's takings, their darts stay in the board; they like the pub better.
- **The bistro's grill and bufet.** On the kitchen island the grill (a station): sausages
  out of the box onto the grate, turned with the tongs, brown on both sides onto the rack,
  black into the bin; at the pass a klobasa plate is a sausage, a spoon of mustard and a
  slice of bread. In the dining room the bufet counter (a station): the soup of the day
  ladled into a bowl (two ladles; a third slops) and over the counter, quick and cheap;
  the big drinks in glass bottles, kofola and malinovka, a ticket of their own for some
  guests, opened with the opener (hold on the cap and lift: the cap flies off and lies
  where it lands). Hands for the grill and the bufet.
- **The Jednota's whole range and its deli counter.** The rack's top shelf has playing
  cards and magazines, the rum stands by the beer, the cigarettes are behind the till (they
  ask; you take a pack off the wall before it can be rung up). At the till counter's far
  end the deli counter: salami, cheese, bread cut to the weight they ask (in deka): slices
  off the piece onto the scale (each a little thicker or thinner), the scale's window says
  the grams, wrap it in paper, hand the parcel over; short and they want more, over and
  they take it but it counts against you. The parcel goes into their basket and is paid at
  the till by its weight. A deli hand.
- **For two.** Every new thing is an op of its place (`cornstand.act`, `taproom.act`,
  `kitchen.act`, `jednota.act`): a drink served, a bill settled, the slot's spin, the
  darts in the board, a sausage on the grill, the soup pot, a deli order, a cut kilo; the
  money is wherever it was taken (the till follows the host's). Checked on two copies by
  `tools/podniky_coop.py`.

## 8. The pipe crawl (sewer repair)

*The chamber and two in the pipes, 2026-10-18 with the user ("let them find out it is not
a good idea").* Down the sewer's hatch is a pumping chamber, dense and wrong: wet stained
concrete, a gutter running out of a pipe mouth low in the back wall (its grille hanging
open, claw marks, hair, hand prints going in, a child's shoe), a wall of valves and
gauges, a bare bulb that will not stay on, and an amber 1980s terminal that draws the
network under it and blinks where the pressure is lost (and on the worse nights a MOTION
line wandering from pipe to pipe). Click the pipe mouth and you crawl in, broken or not
(nothing broken: nothing to mend, the raccoon as ever). Two can go down together: the
same pipes, each sees the other lying in them (from behind, the soles of their boots;
from the front, their torch in your eyes; from the side across a junction), and their
body fills the pipe: you cannot get past, head to head one of you backs up, feet first
(tap S); close up the walls close in. Each has their own raccoon.

*Reworked 2026-10-18 with the user: the raccoon. Staging `scripts/pipes/pipe_director.gd`,
its catches `scripts/pipes/pipe_catch.gd`, the crawl `scripts/sewer_pipe_minigame.gd`.*

**The hole is the raccoon.** A sewer only breaks because it chewed through the pipes,
so whenever you climb down, it is there; the night sewer job comes the more often the
harder the night presses on the camp (`night_jobs.sewer_chance`). How far it goes is that
pressure (omens.pressure) as a level, and as many holes to clamp:
1 (one hole): chittering far off, claws over the crown, its eyes at the end of the beam,
trails of its guts along the floors; it never comes near; its little wet hand prints on
the ladder after. 2 (two holes): a snare of its guts across a pipe you will want (seen
from the junction: go round, or crawl in and tear free while it comes for the noise and
bites); it stands upright at the end of the beam, peers round the next corner, crosses a
junction dragging its belly, copies your crawl from behind, hisses like a hole from a
dead end. 3 (three holes, two snares): the hunt: blind, to your last noise a junction at
a time; from next door it chitters, and after that it takes you. Torchlight down a
straight pipe makes it rear up, its belly opens in three frames, its guts let go
everywhere and it is gone for a while.

**The catches** (the worst thing in the game, each a few seconds in steps): a rope of its
guts with little fingers at the end wraps your hand and drags you down the pipe to its
belly opened like a mouth; dragged back by the ankle, your hands clawing, then it climbs
down onto your face; the torch dies, one wet click, the torch comes back and its face is
right there, the jaw opening too far; a wall of guts up the pipe, your hands sinking; it
takes your free hand down out of sight, the torch drops, in its light it eats your glove,
looks up. Then the dark, and you come to at the foot of the ladder, hurt, the clamp lost.

**The crawl**: pipes 80 cm across (the old brick ones tighter and slower), crawled in
three pulls a pipe (the free hand reaches, slaps down, the body drags after it; the head
knocks the crown now and then); you cannot turn round, lying in a pipe: at a junction
A/D (or the pointer to that side) turns your head into a side pipe and the hand takes the
edge, W or a click takes you in; the first junctions the head goes to each way on by
itself. Almost no light but the torch; everything rings with a metal echo (the PipeEcho
bus), the rusted steel pipes ring under your knees; your own breath and heart rise as it
comes; slime, moss, drips falling, hair, a dead rat, a child's bear.

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

## 9b. The camp world: weather, light, sound, body

The camp is where the game is lived, so it has to read as a real place at every hour and
in every weather (agent B's polish, from 20. 10.; the list is in TODO.md, WORLD POLISH).

- **The night is lived in.** A cabin, caravan or tent with its guests in is lit after
  dark: a cabin's red curtains glow from a lamp behind them, or in one cabin in three the
  blue of a telly flickers through them; a caravan's curtains glow orange, a tent glows
  through its canvas, and their light lies on the grass in front. Each lodging puts its
  light out at its own time between 21:00 and 23:30; now and then one lights again round
  three in the morning, and before dawn some are up early. With the power off the cabins
  have candles. The same windows light on every machine in co-op.
- **The sky.** A clear night has its stars, the milky way and a full moon; under cloud
  (rain, fog, snow, the storm) the night is overcast and the moon hidden. The reception's
  lit windows show the office and the back room behind them.
- **Your breath** shows in the cold, a puff drawn see-through as Build drew its smoke,
  only as bright as the light it is in: at night you see it in your torch.
- **The evening** keeps its clock: gold from four (a low golden sun, cool shade, long
  shadows), red at a quarter past six with the sun gone (red where its last light falls,
  lilac in the shade, the haze rose), the blue hour round seven with the lamps coming on,
  dark from eight.
- **The morning.** Before the sun a clear sky turns rose and peach low in the east, the
  last stars going out over it; mist lies over the meadow and the lake at first light and
  lifts by half past eight. The meadow is a late-summer meadow, green and straw, until
  the autumn dries it.
- **The sky's colours** are the game's surreal look, painted fine like the old Build
  skies (no big blocks): a blood-red west at sundown with a hot pink afterglow over the
  violet shadow of the earth in the east, a rose, coral and violet dawn, a purple blue
  hour with a last red line under it. **Winter coming**: from half the campaign more and
  more days without weather of their own go under a leaden grey lid instead of the blue
  (from four fifths all of them); their evening is a dull red slit under the cloud, their
  night overcast, no dawn glow.
- **The lamps** are the light itself at night: the bulb bright, its cone of light a warm
  shaft that shows faintly in clear air and fully in mist and rain.

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
  to the game palette, so it matches the existing sprites pixel for pixel. Nothing seen
  in the world is drawn by code: the stars and the moon are generated too.
- See-through things (breath, steam, smoke) are drawn as Build drew them: the whole
  sprite at one of a few fixed levels of see-through, never a screen door of dots.
- Every sound effect is a recording (ElevenLabs); tones and cadences that must be exact
  are cut from recordings by script. Only the radio's dread is layered in code.

## 11. Open questions

1. ~~Win condition~~: answered in §5d (the books on day 8). Still open: should a poor
   week end the run outright instead of offering Stay on?
2. How much may the terminal lie? (Section 2 rules apply: specific, never numeric.)
3. The raccoon thing: tie it to waste (dumpsters overflowing) as a fifth threat?

## 12. Wardens together (co-op, up to four)

Decided with the user on 2026-10-17 for two, widened to four on 2026-10-19 ("chceme cílit
na 4 hráče"). Up to four players run one camp together; only in a
**sandbox** camp (no month, no checklist, but the district's mail on how to start and a
first booking sure to come once a bed stands; the story is for one warden, and NEW CAMP says
so when STORY is chosen). Built and tested in stages, each mechanic gone
through for two (TODO.md, CO-OP).

- **One camp, one keeper of it.** The host's machine runs the camp exactly as a single
  player's does; the other machine is a window onto it and sends what its warden does.
  It gets the whole camp when it joins (the save snapshot; the world's seed and the
  saved trees make it the same camp to the tree), then the clock, weather, power and the
  till. Nothing there runs the camp by itself (`Coop.sim_here()`).
- **The PC.** One sits at it and clicks; the other, standing in the reception, sees the
  screen normally over their shoulder (the screen as it is on the other machine, a few
  times a second, on the office's own PC). Either may sit at it, one at a time.
- **Sleep.** The day is skipped only when both are asleep. Lying down alone you lie
  awake watching the little set till the other lies down too; then the night passes
  for both, and either getting up stops it. Both sleep in the room behind the office.
- **The pause menu** stops nothing: the camp goes on for the other warden.
- **Nights for two.** Sometimes asymmetric: one sees what the other does not ("didn't you
  see that?"). Behind it a hidden sanity per player: no meter, never named anywhere,
  it just works. Each enemy hunts one warden at a time, the one out and alone in the dark
  sooner; the lower someone's sanity, the sooner the night picks them, the more of it
  is only theirs, and the likelier they glimpse the other warden somewhere they are not.
  Knocked down in co-op, you lie where you fell, face in the grass, and the night leaves
  you be: the other warden can come and haul you up (E), or, nobody coming, you come to
  on the office step a while later. The camp goes on for the other either way.
- **The other warden** is a figure like the guests (Grok sprites) with their torch and
  their steps. The look belongs to the player's warden (the WARDENS page: chosen when the
  warden is made, changed later with Edit warden): one of four figures, two men and two
  women, and the colour of their jacket; the other warden is called by that warden's
  name, not the figure's; each warden is drawn
  standing, rowing, sweeping, down on a knee scrubbing, lying on their belly, at the PC and sitting.
- **Rooms for two.** Each warden sees a room from where they stand in it; the other is
  in it too: across the room, or at the job they are doing (with the broom, on a knee).
- **The attractions for two.** Either warden can sit by the fire, swing, go down the
  slide, play nohejbal or ping-pong, as the guests do, and each sees the other there
  (strumming, roasting, on the ladder, in the kick). A ball between them is one ball: the
  host's, each one's kick at it their own.
- **One bus.** The bus does not leave while either warden is on it buying a ticket or
  finding a seat, and once one sits it waits a little for the other if they are on it or
  coming down the road ("Your mate coming or what?"). They ride it together, each seeing
  the other in their seat, and get off side by side. Guests out for the day ride it too,
  sitting among the strangers.
  In a tent the other lies on their belly, chin in hand, boots up in the air.
  A job either does is done in the host's camp and shows in both rooms.
- **One boat.** Whoever takes it rows it on both lakes; the other sees them in it and
  cannot take it till it is back at the jetty.
