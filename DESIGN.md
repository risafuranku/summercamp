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
start). It carries the links to Builder 98 and GuestRack (a click downloads them);
CampStat is on the desktop already. Little mail after that: the checklist
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

All of them: forecast before encountered (night risk + one feed line on first sign);
avoidable by attention (each has a tell and a counter); bodies are lit by the scene, so
in the dark they exist only where the flashlight or a lamp touches them.

| Enemy | From | Tell | Counter | Punishes |
| --- | --- | --- | --- | --- |
| Silent Man | Quiet Guy | footsteps on the gravel behind you, closer each time, stopping when you stop; a whisper at your ear | turn round and put light on him; under a lamp he will not come nearer; at the whisper, turn round at once | standing still in the dark |
| The Photographer | Drunk | the ratchet of a film advance where he settles; a red focus lamp blinking in the trees with beeps that speed up; the flash whine | turn your back or get behind something before the flash (he gives ~3 s); the flash lights the place up from his side | looking at him when it fires |
| The Girl | Cheap Chick | far off, eyeshine: where your torch points but does not reach, two small pale points where her eyes are, each blinking on its own; a woman humming; heels scurry on the gravel while you are not looking, and a sting when you find her again nearer; close, the torch dies in your hand for a moment by itself (her face is there for a frame, once a loop all of it) | she moves only while you do not see her, and in the dark you see her only in light (the torch on her, a lamp near her, or very close): keep her lit and in view, back to a lamp (she never steps into its light; stay under it ~18 s and she gives the loop up); never walk towards her (the torch dies more often, and in each dark she is a step nearer) | looking away, letting the light leave her; the torch drains five times over while it holds her; look away ~3.5 s and she may be right behind you when you turn (face to face, the jump: back off). Always the guest's own colours, only deformed: the guest -> fixed smile, white eyes -> legs too long, flushed cheeks -> neck and arms stretched -> her back to you, face turned round -> arms to the ground. Strike: you cannot look away; her drooling face, then stretched long, then the jaw dropped too far; the shriek in static; black and a ring. Leaves a red heel |
| The Whistler | Tramps | a campfire tune whistled out in the trees, moving | do not walk towards it; stand under a lamp until the tune breaks off | following the sound into the dark |
| The Extra Child | Family | a child humming among the tents, back turned | torch off, walk past, never shine the light on it | looking at it with the torch |
| The Basket Man | Mushroom Pickers | 02:30-06:00, a wicker basket creaking out of the trees, a knife scraping | stand still while it is near; it only sees movement | moving while it is close |

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
  and the books; the kitchen behind the counter is the stove (frying ahead) and the pass
  on the island in its middle (plating, the bell): the plate then lands on their table.
  Under the kitchen the cellar is the stock: sacks, crates and boxes as many as the
  books have on the shelf; click them for the books and the orders. (The machine
  nobody ordered stands down there too.)
- **The pub's cellar.** A door by the bar end goes down to the kegs: one for every 25
  pints the books hold, crates of rum and kofola; click them for the books.
- **The corn stand** is one more of them: E behind its counter (either warden), the
  wholesaler's leaflet beside the cash box orders corn and butter (the books' ORDER
  page), Klasek 98 on the office PC runs it like the others; the other warden sees you
  behind it at the pot.
- **For two.** The other warden is in the room with you at the job they have open,
  behind the bar pulling a beer, at the bottles, the washer, the pass, the stove, the
  till, over the books; the place they are at is theirs (no mark over it for you), and
  what they serve lands on the tables on both machines.

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

## 12. Two wardens (co-op)

Decided with the user on 2026-10-17. Two players run one camp together; only in a
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
