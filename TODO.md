# TODO — Cursed Camp Manager Simulator

*Updated: 2026-10-25. Vision: DESIGN.md. What exists: PRODUCT.md.*

---

## PLAYTEST 2026-10-25 — the user's notes (verbatim, then the note in brackets; tick with the commit)

- [ ] R1  „po otevření dveře chatky při animaci je tam zeď a projdu zdí. budova s elektřinou totéž“ (the door's walk-in: a wall drawn in the doorway during the swing, then you pass through it; cabin + the generator shed)
- [ ] R2  „na 60fps/hz mi stíny pořád hodně clippují/glitchují“ (shadow flicker/acne at 60 Hz)
- [ ] R3  „z dálky jsou číslka chatek na cedulkách utopené pod modrou texturou, u stanů a karavanů a obecně nápisů tatáž chyba“ (signs/labels sink under the surface at distance: depth/retro pull)
- [ ] R4  „při úklidových aktivitách kde je třeba pohyb kurzoru, změň kurzor na šipky které naznačují jaký pohyb hra očekává“ (gesture work: the cursor shows the expected motion)
- [x] R5  „odstranit psa v builderu“
- [x] R6  (cbd11c28) „SectiTo98 - umožni ENTEREM odklikávat na další fotku a rovnou označ textové pole“ (Enter = next photo, focus the field)
- [ ] R7  „za dveřmi recepce je jiný interiér než za oknem? proč?“ (the reception's door vs window view mismatch)
- [ ] R8  „nespamovat přes sebe zvuky (např řezání větve přes cestu)“ (one-shot sounds must not stack)
- [ ] R9  „opravit směry spritů. viděl jsem quiet guye běžet pozadu“ (8-direction sprites: facing of the night's Silent/Quiet man and others)
- [ ] R10 „z dálky clippujou okna u chatek? clippuje přes ně dřevěná textura a pak není vidět dovnitř“
- [x] R11 „klikbanka98 - OK okna na které mám klikat spawnuj always on top“
- [ ] R12 „přidej možnost prohlédnout si klikem diplom na zdi (očíčko jak kurzor)“
- [ ] R13 „přidej na nástěnku nakreslenou mapu bludiště v kukuřici“
- [ ] R14 „přidej ven ke vstupu kontejner/popelnici kam musíš odnášet smetí z eventů“ (event litter is carried to a bin, not vanishing)
- [x] R15 „po smazání mailu hned označ další“
- [x] R16 „v noci nejde v 3D verzi builderu nic vidět. umělé noční přisvícení? povol větší úhel naklopení, chci koukat vodorovně“
- [ ] R17 „slunce a měsíc musí obíhat kolem celé mapy, ne kolem kempu“
- [x] R18 „pamatuj si přes noc světla, závěsy atd v recepci, i coop. rozsvěcí se furt světla v pokojíku“
- [ ] R19 „když vypadne proud, zpomalit lehce animaci toho jak jde hráč ven z recepce“
- [ ] R20 „při sprintu více camera shake“
- [ ] R21 „zmenšit Silent Guyovo oči ve tmě. když na něj posvítíš, na 3 s ti vypadne baterka, pak se rozbliká a zapne. víc silent guyů = musíš si vybrat, na koho posvítit; lehce hustý efekt“
- [x] R22 „odstraň stahování/připojování přes beeternet při koupi licence do SoftSkladu, ať to celé probíhá v okně SoftSkladu“
- [ ] R23 „radio blbne, probliknul ksicht silent guye, a do toho vypadly pojistky. takových ‚náhodných‘ momentů víc, víc šancí na takové sekvence“ (the director: more chances for stacked omens)
- [x] R24 „z brigády opisování odstraň čísla, nech jen písmena“
- [x] R25 „brigády se zasekly na ‚done for today‘. ať jsou přístupné nonstop, bez limitu“
- [x] R26 „recepce uvnitř zvenku svítí, i když jsou shozené pojistky“
- [ ] R27 „v kukuřičném podniku sprity ke kameře (jen jedna osa), rozhlížení jako v interiérech, kamera níž, bez fáze trhání silku (jen listy), A/D mezi stanicemi“
- [ ] R28 „zákazníci chodí do fronty několikrát po sobě (3× porce): cooldown, výjimečně přidat; wait time hrozně krátký: než dojdu, ubývá pomaleji, a celkově navýšit“
- [ ] R29 „stánek s kukuřicí má zepředu neprůhlednou texturu?“
- [ ] R30 „mám JENOM DVA HOSTY a celý den je obsluhuju u kukuřice, furt se tam točí. big rework“
- [ ] R31 „staff u kukuřice stojí špatně otočený, potřebuje animace obsluhování; večer odchází přes vrátnici na bus, ranním busem přijedou na otevření kempu“

## POHYB, KAMERA, INTERAKCE — 2026-10-21 (the user: "it still feels a bit like I'm a spectator, a car, a tank"; "the trees and the world are static, we need to finish all of it")

Decided with the user (Q&A 21. 10.): bodily but quick (Firewatch, Dishonored), no sliding; the
Build look kept but wider; the camera always smooth, only sprites and hands in steps; crouch and
crawl; your own feet and shadow; the world answers you; doors without a seam; carry and throw;
work by a gesture of the mouse; Options. How it works: DESIGN.md §9c.

**Measured before** (`tools/move_shots.tscn -- --part=measure`, 1280x720, the businesses' test
camp, 40 guests; HEAD 2c2914f):

| | before | after |
|---|---|---|
| walk 0 -> 95 % (3.9 m/s) | 0.35 s, 0.71 m | 0.08 s, 0.19 m |
| walk: key let go -> stopped | 0.48 s, 0.92 m | 0.12 s, 0.19 m |
| sprint 0 -> 95 % (5.2 m/s) | 0.45 s, 1.16 m | 0.12 s, 0.35 m |
| sprint: key let go -> stopped | 0.65 s, 1.65 m | 0.17 s, 0.36 m |
| W -> S, at speed the other way | 0.70 s | 0.17 s |
| look up (limit / the eye itself) | 24° / 17.7° | 55° / 55° (12° Build shift + 43° turn; stops under the zenith) |
| look down (limit / the eye itself) | 46° / 33.5° | 80° / 80° (12° shift + 68° turn) |
| FOV | 56° | 72° (Options 60-90, +4° running) |
| FPS camp 19:36, 40 guests (worst frame) | 50 cap (31 ms) | 50 cap (31.5 ms) |
| FPS forest (worst frame) | 50 cap (39.6 ms) | 50 cap (39.4 ms; with the new sounds and sprites loaded at the start: a first load mid-walk was a 50 ms frame) |

What makes the tank (from the numbers and the shots `move_shots --part=shots`):
- the stop: half a second and nearly a metre of slide after the key goes (sprint 1.65 m), a turn
  back takes 0.7 s: "a car";
- the air keeps full braking (8 m/s²) but little push: you stop dead in a jump, odd both ways;
- the eye moves 0.72 of the mouse up and down (`pseudo_pitch_rotation_mix`) in 1.4° steps
  (`vertical_look_snap_degrees`): up 17.7°, down 33.5°: no boots, no crowns, no sky; FOV 56°
  (rooms are 68-70°): a narrow tube;
- the bob is stepped (12 a second, `bob_fps`, `bob_snap_*`) and counted by the clock, not the
  ground; the head moves in physics (60 Hz) while frames are capped at 50: a double step every
  fifth frame, a 10 Hz judder whenever you move;
- main forces the FOV back to 56° every frame (`_sync_active_camera`): the run's wider view hardly
  shows;
- the lean on a turn is set per mouse event (frame-rate dependent);
- the world does not answer: grass, ferns and bushes stand still as you walk through; nothing to
  pick up or throw (only kicks); doors: a frozen frame and a dither at every building.

The work, in the brief's order (tick as it lands):
- [x] 1. Quick to start and stop, no slide, turning without a skid, less control in the air;
  the bob by steps on the ground, in time with the footstep, the landing springs, the run's
  longer step and wider view, a settle when you stop; all smooth (no steps, no physics judder)
- [x] 2. Wider Build camera (FOV, up and down) and its limit written down (DESIGN §9c: the shift
  eased in to 12°, then the eye turns; up stops 2° under the zenith, where the sky pinches);
  mouse without lag or steps; Options: FOV, mouse X and Y, bob, lean, crouch hold/toggle
- [x] 3. Crouch and crawl (smooth height, slower, quieter, under 0.6 m), the crawl's hands; your
  feet and boots looking down (Grok, the hands' pixel and light), a shadow; co-op poses
- [ ] 3b. Room under things outdoors: the picnic tables, fences and cabins are solid boxes to
  the ground (their colliders), so there is little to crawl under yet; no reflection in water
- [x] 4. Grass and ferns part round every warden's feet (shader), ferns rustle, a low branch
  across the view, leaves fall under the birches and cones off the spruces, birds and crows fly up
- [x] 4a. A squirrel on a trunk (runs up as you come) and butterflies over the meadow (Grok
  `body_squirrel`, `body_butterflies`)
- [ ] 4b. The crowns' calm-day motion left as it was; needles (too small to read at 240 lines);
  bushes (the camp has none: ferns, nettles, blueberries take their place); new sounds for
  wings and bushes need an SFX key (the current key speaks only: the corn's rustle, the
  oar's splash and the crow reused)
- [x] 5. Puddles splash (rings, drops), the lake's edge splashes (you can wade a stride in), wet
  prints on boards and paths, mud slows and muddies the boots (seen on your feet, brown prints);
  the other wardens' wet and muddy prints are not drawn (their boots are not sent)
- [x] 6. Pick up, carry, set down, throw small things (bottles, cans, cones, the bucket, stones,
  logs); the rubbish sack carried in both arms to the dumpsters (the litter is done there); a
  throw at night calls `heard()` on the group "night_ears"
- [ ] 6b. No enemy listens to "night_ears" yet (none has ears: it is the night's code); the
  delivery's boxes (the `carry_box` hands are drawn) and a ladder are not carried yet; the
  stones' and logs' world pictures (`kick_stone`, `kick_log`) are not drawn yet, so none lie
  by the fire (their held hands `hold_stone`, `hold_log` are)
- [x] 7. Doors: the hand on the handle, the leaf swings, you step into the doorway and the room
  takes up from its door with no frozen frame and no dither (every lodging and service room)
- [ ] 7b. The room seen through the open door (a portal: a camera in the room's own world on a
  quad in the doorway, as the office's windows do): the rooms are worlds of their own built
  only when they open, so it needs a hidden build before the door opens; the dissolve is
  left where you did not walk in (the PC's start, rooms opened by tools)
- [x] 8. Work by a gesture of the mouse instead of the hold bar (sweep, round, a jerk down, pull,
  pick), the ghost hand and its trail after 2.4 s; rooms, repairs (R), sawing and bagging (E);
  the toilet's scrub close-up and the pipes keep their minigames; the HUD's line still shows
  how far (no hammer job exists yet)
- [x] 9. Guests you walk into hop aside and look at you with a word; ducks on the camp shore run
  and fly off (there is no dog in the camp: only a far bark)
- [x] 10. Co-op: carried things (at their hand, the sack as "bag"), crouch and crawl, open doors,
  thrown things on every machine (`Coop.send_body`); Czech for every new text
  (`tools/i18n/batches/07_body.json`)
- [x] 11. DESIGN §9c, PRODUCT, AGENTS (§4 rows, §5 gotchas); the numbers after
- [x] Checked: smoke (no SCRIPT ERROR), upkeep_check, hud_layout_check, lang_check, the shot
  driver's prepcabin (the rooms' jobs by the tools' auto gesture), `move_shots` measure /
  shots / body looked at; coop_check: 3 failures, all the trip to town and the bus (in_town,
  bus fingerprints: as before this work, Cod3x's); coop4_check not run

## PEOPLE AS IN DOOM — 2026-10-21 (the user: "the sprite changes with where you look from, like in Doom; the wardens first, then the guests; a few walking frames; the night's enemies left out; always the same person, no artefacts")

How it works: DESIGN.md "People as in Doom", AGENTS.md §7 "People from eight sides".

- [x] One base for everyone: `scripts/figures/doom_figure.gd` (8 sectors, hysteresis, frames by the ground covered, atlas + index), `tools/artgen/figures.py` (cut, scale, the person's own palette, defringe, checks, contact sheets, atlas, jacket mask), `figure_prompts.py` -> `prompts_figures.tsv`
- [x] The other warden in co-op from eight sides (the state's yaw), walking and running in frames, in rooms facing their job; the old flip and sway gone, a little lift between steps
- [x] The jacket's colour by a mask made with the atlas (`warden_looks.atlas`), not bands per pose
- [x] Guests: facing their way (smoothed), standing facing the queue, the attraction or their party, idles after a while; poses keep their old picture till drawn from the sides
- [x] The family as its people (father, boy, mother, second child; `poses.FAMILY`), a child as small as it is
- [x] Pepa (pilot): turnaround, walk, run, idle, sweep / fix / bag / sit from five sides
- [x] Ondra, Jana, Bara: the same; all nine jacket colours on every frame (Jana's side run failed: she walks there)
- [x] Guests: the quiet guy, the drunk, the girl, the tramp, the picker, the boy: stand, walk, run, idle (the drunk's 3/4-back run and the girl's side run failed: walking there)
- [x] The father and the mother (new sprites from the family's), their sets and their seats (sit, eat, drink, kick, bat for father, mother and boy)
- [x] Guests' seats from five sides (sit, eat, drink; the drunk's sit failed: his old picture)
- [x] The hands in the businesses (`crew_figures`, all fourteen: stand + work from five sides) and the electrician (stand + walk); the postman has no sprite of his own yet (`npc_postman.png` in the post session's queue)
- [x] FPS of a full camp, uncapped (36 guests out, `figure_shots --part=guests`, Grok running beside it both times): before 62 at noon / 75 in the evening, after 80 / 80
- [x] Shots: `tools/figure_shots.tscn` (eight sides, walk, run, colours walking, the camp at noon and evening); `tools/figure_check.gd` PASS (27 sets)
- [ ] Regenerate what failed (warden_c run3, host2 run4 and pose_sit, host3 run3): `figures.py batch <fig> <key>` makes the next variant
- [ ] Views 6-8 are mirrors: the torch and the shoulder bags change hands as in Doom; draw them apart only if it bites in play
- [ ] Guests in poses at attractions face the attraction's tile centre; benches and the slide may want their own facing
- [ ] Pipe crawl (`pipe_mate.gd`), the bus riders and the night's enemies stay as they are (out of scope)

## STAFFROOM — 2026-10-21 (the user: "a fifth tab in SoftSklad to hire staff; a staffroom with the PC as an old chunky laptop, a mattress in the boiler room, sofa, fridge, coffee machine, TV; lockers bought in the books; they see to the day's events and the lodgings; toggles per hand; home at night; curtains; co-op; the postman as a notification on the right edge")
- [x] Staffroom build (Utilities, one per camp), one plan inside and out, real glass, curtains, lamps (DESIGN §7c)
- [x] Lounge + boiler room, point and click, the laptop = the office PC, books, coffee, fridge, TV, lockers, mattresses
- [x] Hands: hire one to a locker, jobs ticked per hand, the day (coffee, jobs, rest, a guest's bed, home at eight)
- [x] Personal 98: SoftSklad's fifth program; licence at softsklad.cz
- [x] The post's plate at the right edge (van on the way, parcel at the desk)
- [ ] Co-op checked in two windows (the code is in: biz.staff in the pulse, s_* ops to the host, the laptop's screen and the figures)
- [x] The boiler room's mattress is the warden's bed (lodge_bed "staff"); the hands sit in the lounge (armchairs bought) and all go home at night (the user, the same evening)
- [ ] Sounds of their own: the boiler's roar, the fridge's hum, the coffee machine's gurgle, the locker's clang (ElevenLabs)
- [ ] A hand asleep in a guest's bed seen in that lodging's room

## CABINS — 2026-10-21 (the user: "the curtains do not glint, the windows by the door clip the coat and have no view, rebuild the inside to match the outside and remake that a bit; every tier a visible upgrade inside and out; old curtains left under the new ones")

- [x] One plan for the model and the room (`scripts/cabin_layout.gd`), every window a view out with a curtain that glints
- [x] The tiers inside and out (boards, porch, annex, shutters, chimney/stove, aerial/TV, furniture)
- [x] The jacket clear of the windows, no painted curtains under the drapes
- [x] Builder's pictures of the new cabins (renders repainted by Grok, Lv1 kept bare)
- [ ] The bathroom is cramped from its doorway: a better view or a bigger annex

## PODNIKY PAPA'S — 2026-10-21 (the user: "at first sight terribly complicated, I don't know where to click; choppy; how do I serve? I want it like Papa's games; the same in every place")

Decided with the user (Q&A 21. 10., DESIGN §7b "Papa's frame"): you come back to the station you were at (the first time the first of the chain); the camera and the things you move smooth, the glove frame by frame; patience seen everywhere; after a serve nothing that stops you; last orders half an hour before closing, who ordered waits; SERVE and a checklist; the next step lit (switch in Options); menu switches only; short orders, many guests; mouse, keys and tabs; by day play, by night the uncanny; a hand for every room.

- [x] The frame, the same in all four places (`station_hud.gd`): tabs with picture, key and name (blinking where something waits or burns), BOOKS (B) always in the same place, BACK (S), SERVE (Space, Enter), the shift's mark A-E and the average stars, the run (x3), the clock to last orders
- [x] Tickets with the guest's face as their patience goes, what they want (picture and word), the patience bar (`station3d.draw_ticket`, `guest_face.gd`); the big ticket as a checklist (`checklist`)
- [x] After a serve: the stars, the score and the tip fly up over the guest, the run of good ones with a little on top of the tip, the slip at the side
- [x] The next step lit and the ghost glove when you stand still (`next_hint`), Options "Work hints" (the warden's)
- [x] Smooth camera, sliding tickets, things hop when set down and fly to the guest in an arc; the glove stays at 12 fps
- [x] Last orders 30 min before closing (the bell, the word, the feed); nobody new goes there; who ordered waits past closing; the Z report when the last is served or gone
- [x] The books: MENU first, the same six pages everywhere (MENU, STOCK, ORDER, STAFF, GEAR, Z REPORT); the guests order only what is on
- [x] Patience over the guests' heads in the room (dots, the watch, a red scribble, lines, the stamp of a foot) (`guest_mood.gd`)
- [x] Corn stand: the frame's model; the camera sees the guests over the counter; the drinks a menu switch (off: no tab, no drink slips)
- [x] Pub: the frame, one-click bill, the games off the tabs, the keg on the frame and its tab, the cellar's hand, the menu
- [x] Bistro: cellar optional (prepared goods to buy dearer, a hand), the soup (bufet) into the kitchen, the floor = bottles and serving the plates off the hatch, a floor hand, the menu
- [x] Jednota: the frame on the till (SERVE = GIVE), the queue's patience over their heads, the shelves and the store for the hands, their tabs lit when the rack runs empty, the menu = the range
- [x] Bigger, readable food and goods: at the stations at their pictures' own pixel (`station3d.fine`), the pass's plate food a quarter bigger, the floor's plates, bigger icons with a word on the tickets
- [x] The food and drink pictures re-drawn by Grok with stronger silhouettes and colours: the fried cheese, chips, goulash, dumpling, tartar, onion and their ticket icons, the mug and the kofola, the cobs raw, boiled, mushy and buttered (`podniky_art.py` pk2_*)
- [x] Each place's own sound: the bistro's kitchen at work, the Jednota's tubes and now and then a till (`service_interior._tick_ambience`, recordings already there)
- [ ] New sounds for each action and the guests' sighs: the ElevenLabs key can only speak (TTS), a key with sound effects is wanted
- [x] The guests' impatient pictures for those who wait on their feet (the stand's queue, the Jednota's): a hand on the hip, a look at the watch, the toes tapping, the kid's arms crossed (`<sprite>_wait.png` by Grok, `guest_mood.show_wait`); the seated ones in the pub and the bistro keep the bubbles
- [ ] A note on the door at last orders
- [x] DESIGN §7b "Papa's frame", PRODUCT, AGENTS, the Czech of every new text (tools/i18n/batches/06_podniky_papas.json)

## RECEPTION WINDOWS — 2026-10-21 (the user: "the reception's windows have no depth from outside; curtains drawn, lights out, the players inside at the PC or going to the other room: all of it seen from outside and in step")

- [x] The real office behind the panes (a camera in its world), by day darker than the day outside
- [x] Curtains, lights and the back room from outside, the other wardens inside (`tools/window_coop.py` PASS)
- [ ] The PC's screen seen from outside is the last frame drawn on this machine (the other warden's screen comes only while you are in the office)
- [ ] The same for the cabins', caravans' and businesses' windows (they have interior mapping, not their room)

## THE SECOND MONITOR — 2026-10-21 (the user: "D once to look right, A back; a lowkey page to buy a second monitor; the post brings it, sign with the mouse, click the parcel; Builder on the left all day; everything in co-op")

- [x] A/D at the PC: one press turns you (right: the second monitor, or the window before it)
- [x] PC Servis's page (the bazaar's foot, the search), the order paid, the PC's record
- [x] The post van and the postman on the clock (office hours, gives up at 19:00, back next morning), at the counter
- [x] The slip signed by hand, the stamp, the parcel, the banner
- [x] The second monitor on phone books, the radio on top; two screens, the swap, the keys, dialogs on the screen looked at
- [x] Co-op: ordered and signed on either machine, the van and man on both, both screens over the shoulder (`tools/post_coop.py` PASS)
- [ ] The van's front and back faces and PC Servis's photo (Grok queue), then a look at the van turning round to leave
- [ ] Czech: the PC Servis page's own text (the web pages are not translated yet)

## CZECH VERSION — 2026-10-21 (the user: "the language is the warden's, flags when a warden is made; the whole game in Czech; from now on everything in English and Czech")

How it works: AGENTS.md §8. Left: `python tools/i18n/extract.py --stats` / `--todo`.

- [x] The language layer: `scripts/lang.gd` reads `locale/cs.po` and answers the engine's
  lookups (exact, UPPER-CASE, formatted, wrapped, line by line, plural forms, the warden's
  gender); `tools/lang_check.gd`
- [x] The language is the warden's (profiles "lang"), flags on the WARDEN page, the menu
  rebuilt in it at once; `-- --lang=cs` for tools and shots
- [x] Czech letters in every font (Silkscreen and W95FA composed in `gen_pixel_fonts.py`);
  taller big menu rows in Czech (capitals' accents)
- [x] `tools/i18n/extract.py` (5,125 strings found) and `fill.py`; the title screen, its
  pages, the options and controls translated (~200)
- [ ] The HUD, the pause menu, prompts and the feed
- [ ] Drawn text through `tr()`: ~350 `draw_string` calls (the PC's programs, the Builder,
  the stations, the close-ups, the paper map)
- [ ] The PC: Okna 98, CampMail and the mails (`data/pools/emails`), CampStat, GuestRack,
  Goggle, SoftSklad, the web pages, Files, the games and jobs
- [ ] The camp: buildings (`data/buildings` display names), guests and their lines, day
  events, night jobs, the director's log, Vera's checklist, the businesses and their
  stations, Papa's slip, the Z report
- [ ] Liblice, the bus (the driver is already Czech), Pristoupim, the phone book
- [ ] Text put together from pieces in code: find them in Czech shots, make them one
  format string
- [ ] Pictures with words (signs, posters, the web's pictures, the Builder's splash) and
  English voices (the phone, the electrician): Czech versions through locale remaps
- [x] Money in Czech: crowns (the user, 21. 10.), $1 = 10 Kč in `lang.gd` (`crowns()`,
  `LANG.money()`); drawn money that skips tr() (the Builder's odometer, the PC's
  programs) still to go through it
- [ ] Play a day and a night in Czech end to end and fix what reads wrong

## PODNIKY POLISH — 2026-10-20 (the brief: the four places to the top)

- [x] Two pointers in the rooms: the finger and the glint for what works, the eye for what is only worth a look
- [x] Your gloved hand with the station's tool at every station (station_hands.gd, 12 fps, phased presses)
- [x] Papa's slip after every serve (wait, order, cooking, stars, tip, a word, a sound)
- [x] The Z report: goods, net, all places, the mark A-E and what to mend; SoftSklad's Books show it
- [x] Thirst as a need; the plates over heads and GuestRack's NEEDS column; the Builder card says what a place fills
- [x] The Jednota's bag that feeds them for days; the evening rush 17:45-20:00
- [x] The ladder: build, licence, wages, prices, guest_services (corn < pub < bistro < Jednota)
- [x] The hands' temper on the guests' mood; the stand's hands seen behind its counter; SoftSklad says what a hand is like
- [x] Corn: the drinks table (iced tea, lemonade in a bag), the queue in a line out into the camp, the pot's water rolling
- [x] Pub: the tab (marks on the mats, the bill, the wallet, make-it tips, unpaid bills), hands settle bills
- [x] Pub: the fun (LUCKY 7, darts, oko bere), the guests play too
- [x] Bistro: the grill and the klobasa plate, the bufet (soup of the day, bottles with the opener, flying caps)
- [x] Jednota: cards, magazines, rum, cigarettes behind the till; the deli counter (cut, weigh, wrap, by weight)
- [x] Harness tools/podniky_check.tscn; co-op on two copies tools/podniky_coop.py
- [x] The Grok pictures of the stations (rows pk_* in tools/artgen/prompts_podniky.tsv, `python tools/artgen/podniky_art.py`): the Build tops of the drinks table, grill, bufet and deli; the corn drinks, sausages, bufet bowls and bottles, deli goods, the new Jednota goods, LUCKY 7 and its reels, darts and the clean board, the cards, the wallet, the pot's bubbles; every tool hand; the new ticket icons
- [ ] The second variant of every hand frame to pick from (the brief: two each, picked by hand); only grab and press got their _b so far (both A kept), the rest went through as A to get them past the shared queue
- [x] The pub's slot machine, darts and cards looked at with their pictures (the cards were under the table top, the darts scored round the board's bottom edge: both fixed)
- [ ] A guest figure at the slot machine and the dartboard while they play (now only the reels, the darts and the sounds)

## WORLD POLISH (agent B) — 2026-10-20 (the brief: the camp world, weather, light, sound, body)

The inventory: `godot/tools/_tmp_B_tour` (agent B's scratch, not in the repo) walks one
camp (sandbox, seed 4242, built up, guests in) at 6:30, 12:00, 17:00, 18:15, 20:30 and
2:00, in clear, rain, fog, storm and snow, from the reception, the tents, the fire, the
jetty, the forest edge, the corn, the gate road and the cabins. What did not look like a
finished game, by impact:

- [x] Night: the cabins, caravans and tents stay dark with guests in them (only the
  reception's windows light): the camp looks empty after 20:00 — lit since 20. 10.
  (`window_lights.gd`: curtains, the telly, tents, candles without power, lights out
  21:00-23:30, now and then one at three in the morning)
- [x] The reception's lit windows are flat white quads at night — the office and the
  back room show behind the glass (20. 10.)
- [x] Coarse halftone dots in shade (the torch's edge, dawn, snow): it was your breath,
  a 2 x 2 screen door lit black at night (an A/B of the post, light and distance dither
  found it); the breath is a see-through sprite now (20. 10.)
- [x] Lamps: standing by a lamp post its light cone is a big grey slab across the view —
  it fades out within two metres (20. 10.)
- [x] Lamps: the bulbs hardly read, the cone of light a grey column — the bulb lit at
  full, the cone a stepped warm sprite added to the scene, stronger in fog and rain
  (20. 10.)
- [x] The bonfire's smoke a dither shader — Grok puffs at Build's translucencies (20. 10.);
  the fire's light on the ground round it reads at night
- [x] The bonfire's sparks are flat-coloured quads (one or two pixels on screen) — Grok
  embers in three ages, added to the scene like light (20. 10.)
- [x] A clear night has the overcast sky: no stars, no moon — stars, the milky way and
  the full moon since 20. 10. (`night_sky.py`)
- [x] The sun, its glow and its flare are still drawn by code (`weather_visuals`
  `_create_pixel_sun_*`), the clouds' sprites too — Grok sun and clouds, no glow or flare
  (20. 10.; the first render was a cartoon orb and cute clouds, redone in the sky's own
  digitized-photo look)
- [x] Dawn (6:30) is flat and dark: no mist in the hollows and over the lake, no colour in
  the sky — a dawn sky (rose and peach in the east, the stars going) and the morning mist
  over the meadow and the lake, lifting by 8:30 (20. 10.)
- [x] The meadow reads as burnt black ground by day — a generated late-summer meadow (20. 10.)
- [x] The Builder's map still draws the old Redneck grass for the summer
  (`crt_map_panel.GROUND_TEX_SUMMER`, agent A's): `world/grass_summer.png` now, and the
  minimap's open ground follows the season too (20. 10.)
- [x] Golden hour (17:00) hardly shows; the red sunset (18:15) is one flat red over
  everything — the evening's own skies (gold, sunset, blue hour; glow in the west) and
  light (golden sun and cool shade, red light and lilac shade, blue) (20. 10.)
- [x] Snow falling does not show at noon; snow cover has the dot grid in the shade — the
  flakes bigger and denser in two layers; the dot grid was the breath (20. 10.)
- [x] Storm: a leaf blown into the lens fills a corner as a big blurred blob — no leaf
  nearer the eye than 2.2 m (20. 10.)
- [x] Rain: splashes and puddles hardly read from eye height; grey slabs of rain across
  the view — paler crowns, puddles nearer and mirroring the sky, the far streaks kept off
  (20. 10.); the water on the windows from inside (room_weather.gd) is as light as the
  light outside (at night it was a screen of grey static)
- [x] Rain: drips off the eaves after it stops (20. 10., world_sounds.gd)
- [x] Rain sound by surface: tin roofs, the tents' canvas, the lake, the trees over you
  (20. 10., world_sounds.gd)
- [x] Rain: drips you can see off roofs and trees — from fixed spots along each roof's
  lowest edge and off the trees near you, a crown where they land (20. 10.)
- [x] Sound: the lake's lapping and the frogs played in the middle of the camp (the jetty's
  body sits at the lake's origin) — fixed 20. 10.
- [x] Sound: footsteps on snow and in puddles (the jetty's boards were there); guests and
  the country far off by the hour (far_life.gd); the flagpole, the washrooms' tube and tap
  (the transformer by the corn and the swings were there) — 20. 10.
- [x] Sound: the jacket and the keys as you move (20. 10.)
- [x] Weather pass (21. 10.): the drizzle's slow full-length streaks stood in the grass
  like sticks (fine short drops now); the far forest went bright blue in rain, storm and
  snow (the wet fog's tint); falling snow did not show (self-lit, steady fall); the
  storm's rain comes in gusts; the lightning lights the world in steps (a step or two
  full, often a second flicker, dark: it faded out smoothly)
- [x] Wind in gusts (21. 10., the user: "polishnout vitr huste"): weather_visuals'
  `wind_gust` rises, holds and dies away on the weather's wind; its front runs over the
  meadow (the grass laid over, paler) and through the wood; straw, dust, twigs, newspaper
  and wrappers ride it (`wind_things.gd`, Grok sprites, the dust dotted like the breath),
  the leaves (`wind_life.gd`) go the trees' way in the same gusts; each gust heard, the
  trees creak; the storm's clouds come down, churn olive-grey and flash inside, the scud under
  them in the deck's grey (it went black) (`cloud_layers.gd`); shot scenario `wind`
- [x] Snow: boot prints behind every warden, frozen puddles; snowfall no longer grew
  puddles with rain rings on them (21. 10.)
- [x] A broken lamp shorts: sparks, a flash, the crackle (21. 10., lamp_sparks.gd)
- [x] The rowing boat, single and co-op (21. 10., the user: "totálně polishnout lodičku"):
  into the seat and out smoothly, strokes in a rhythm, backing and turning on the spot,
  looking round from the seat, the shore and jetties knock it back, alongside by itself
  (and off the keeper's jetty again: it took you straight back), the hull on the swell,
  3D oars, splashes, swirls and wake, the lantern, its sounds; in co-op the oars stroke on
  the other machine and the passenger sits in the bow face to face (they sat in the
  rower's face); the village's houses gone from the far shore (`boat_rig.gd`,
  `tools/boat_shots.tscn`, `tools/boat_coop.py`)
- [x] Sound: a guitar by the fire and a radio in a caravan in the evening, far off
- [x] The camp's own music (21. 10.): seven five-minute songs (morning, tycoon, golden, rain, nightstart, night, red; the title in the menu), mapped by `tools/audiogen/music_sections.py`; a piece comes in after a while on your feet outside, out of slow into its tempo, and winds down like a carousel on a bar (idle, the hour or weather turning, a presence at night, the Whistler playing); through the walls indoors, silent asleep; co-op: the host's piece on both machines in step
- [x] Radio: Prani a pozdravy on the clock (from 0:30 for as long as it runs, tuned into mid-way, never after the night skip or a load); Vypinac with its hook (0:44-1:12) twice and again before the outro, on the beat
  (21. 10., far_life.gd)
- [x] Sound: the country by day — the dawn chorus, birds, grasshoppers, a woodpecker, a
  crow, ducks on the lake (21. 10., `nature_life.gd`; there were only the night's
  crickets, frogs and owl)
- [x] Sound: reverb by room — the room's own sounds through a Room bus (wood rings a
  little, canvas hardly), the outside low-passed through the walls (20. 10.)
- [x] Sound: the small fridge hums in a better cabin — runs and rests, knocks as it
  starts, silent without power (20. 10.)
- [x] Body, movement: slower in snow, mud and puddles, slower out of breath, the view a
  little wider in a run (acceleration, the stepped bob, the lean and the landing were
  there) — 20. 10.
- [x] Body: doors with a feel — the guests' doors swing with weight, knock on the frame,
  creak and thud (20. 10.)
- [x] Things to nudge: bottles, cans, a bucket, cones your (and the other wardens') feet
  kick, with their sounds (20. 10., `nudge_props.gd`)
- [x] Body: the hands' sway and swing back on a turn, the cold and fear tremor, reaching
  for things (36b51c2, another session's area since 0749f84)
- [ ] Body: one glove and sleeve for every tool, more frames a motion, a look at the watch
  when idle (the hands' session)
- [x] The menu camera: calm film shots since 77e5bac; all of them seen again on 20. 10.
  after the new light (the misty jetty, the golden corn, the office in the rain, the far
  shore, the gate at night, the red sky after sunset of 35ac52b): they read
- [x] Every sound the code synthesised is a recording now (the camera, the thump, the
  pager, the station, the phone line, the splash's neon, the set's tone)
- [x] Production, frame time at 1920x1080 (the tour camp, clear and rain, noon and 20:30,
  reception, tents, cabins): before agent B's world polish (7011a1b) CPU process 28.8 ms
  and GPU 3.0 ms on average, after it (9193f0d + the fire) 28.7 ms and 3.0 ms, fps at the
  50 cap in both: the lit windows, the lamps' cones, the skies, far life and the rest
  cost nothing measurable (20. 10.; single spots vary by ±8 ms with other work on the PC)
- [x] Production: draw distance and pop-in, the forests and the lake from far off, the
  menu flythrough — seen 20. 10. (jetty, forest edge, west, east, gate; noon and 18:15,
  clear and fog): the forest ring has no gaps, the far shore and its houses read across
  the lake, the fog falls off in steps; the only thing cut by distance is the ground
  cover at 70 m (a tuft is a pixel there)
- [ ] coop4_check on HEAD 14e8dd1 (20. 10.): 23 failures, all the trip to town (in_town,
  the bus, Lesna, the bar of U Jezera, the fingerprints), no SCRIPT ERROR; coop_check
  the same in_town wait plus the derelict cabin and the jobs, on clean HEAD too (town:
  Cod3x)

## BUILDER 98, A GAME IN THE GAME — 2026-10-19 (agreed with the user; handoff)

The user: the Builder should feel like a 90s tycoon of its own, and fun. Everything below
was agreed, except a star rating inside the Builder: the rating became Goggle (the PC's
Reviews tab, DESIGN §5i), "a parody of Google reviews; not everything unlocked from the
start, collect good ratings; pay to delete bad reviews".

- [x] Goggle Reviews: the fifth tab (key 5), the page, blueprint tiers and room upgrades
  locked by rating, the booking pull, SpotlessName Ltd removals (caught = flagged), the
  owner's replies tied to CampMail's guest book, saved, co-op through the host
  (`scripts/reviews/goggle.gd`, `os98/apps/goggle_app.gd`, `tools/goggle_check.gd`)
- [x] Goggle's art (padlock, SpotlessName's banner, stars) processed and seen in both
  resolutions; the Jednota at 4.0 with the slide; Photos and People also searched for;
  how many found a review helpful; the owner's badge; long reviews cut with "..."
- [x] Building site instead of the drop-in: a scaffold with a worker hammering for a few
  seconds (`iso_scaffold`, `iso_worker_a/b`; `assets/sfx/builder/hammer.mp3`,
  `site_done.mp3`), then the building; in `crt_map_panel._on_build_confirmed` /
  `_dropped` / `_draw_structure`. Rubble on demolition (`iso_rubble`, `rubble.mp3`) in
  `_on_demolish_confirmed`
- [x] Money you can see: coins flying from a paying building to the cash counter
  (`spr_coin` -> `builder/coin.png`, `coins.mp3`), the toolbar's cash (`builder_module._money`)
  rolling like an odometer
- [x] Tool cursors (bulldozer, path, lamp, a blueprint) and drag-building rows of benches,
  lamps and flower beds
- [x] The map follows the weather and the hour: rain streaks, fog, dusk tint (the night is
  `_draw_night`)
- [x] Guests' thought bubbles over their heads (`think_*` -> `builder/think_*.png`) and a
  guest card on click with their thoughts, some of them wrong ("The lake looked at me.")
- [x] The map lies, rarely: a tent nobody built for one frame, a tile that says "Something
  is buried here"
- [x] A Graphs window (Transport Tycoon's): money, guests, satisfaction over 14 days (look
  for a day-by-day history first, e.g. the week ledger)
- [x] Builder music: a General MIDI-style loop (ElevenLabs), detuned a little at night
- [x] Hlubočanský zpravodaj (the district paper) now and then, and award diplomas for the
  camp
- [x] Cheats typed on the map (BOHEMIA: money, and the next day a letter from the district
  asking about it)
- [x] Shareware: a nag after ~10 builds, a registration-locked Mega gnome, Help > About
  with credits and a Snake easter egg
- [x] Registration in a couple of clicks (the user 21. 10.: not photographing the key off
  the screen and typing it back): Help > Register... > Yes, and once the key's mail has
  come (08:10 the next morning) Help > Register... has it filled in, OK
- [x] Builder polish (20. 10. evening, the brief "Builder 98 jako samostatna tycoon hra"):
  every building's four pictures from its 3D model (`tools/iso_render.tscn` ->
  `tools/artgen/iso_views.py` -> Grok -> fitted back), checked against the camp from the
  same corners in all four views (`tools/builder_shots.tscn`); the map turns (T); the
  guests as the camp poses them, their faces, Zzz over sleepers; every click's sound; the
  message line and the corner window; the card's turning picture, clean, today's takings;
  the sound under the pointer; lit windows at dusk; the music's seam measured
- [x] The god cursor over the camp (DESIGN §5k, `scripts/god/god_cursor.gd`): the queue
  with shadows, dominoes, buildings in parts, bulldozing pressed flat, hum, clicks and
  booms, guests jumping aside, the warden pushed off; co-op through `from_peer`; looked at
  from the camp (`tools/god_shots.tscn`)
- [x] Grok's repaints of the buildings, each looked at against its render: kept where they
  match the model; the bench, the gnomes, the flagpole, the lamp, the playground and the
  corn stand stay the render (palette-snapped), Grok's went wrong (`builder_art.sh` says how)
- [ ] A second Grok variant (b) to choose from for the buildings that only had a (most of
  them, to get through the shared queue), and new rows for the six kept as renders
- [x] The map's little people in frames (Grok gst_*, cut to `peeps/<kind>_<0-7>.png`), the
  faces (`react/`), the building site in its three stages (`site/stage_<0-2>.png`), the
  little yellow bulldozer and its dust (`site/dozer_*`, `dust_*`), the dog (`life/dog_*`),
  the moving tool cursors (`cursors/`, also the god cursor's tool over the camp)
- [x] The ducks and glints, the moths, mice and ants, the birds (`life/lake_*`, `bugs_*`,
  `birds_*`; the ducks cut at the waterline, the flocks cut in columns)
- [x] The news icons on the message line and in the corner window (Grok bld_icons ->
  `news/`, each on a 28 px square)
- [ ] The god cursor in co-op on two copies, by night and in the fog; its tempo by feel
- [x] The map's flags waving (frames from the 3D flagpole, faster in a wind); the trees
  sway while it blows (`tools/artgen/tree_sway.py`: strom.png leaned by whole pixels,
  Grok's bld_tree stood upright)
- [ ] A hint of the cheats somewhere in the PC (a README.TXT in Files, Vera's note), never
  a list
- [ ] Hear the music once: `assets/sfx/builder/music.ogg` was cut and measured
  (`loop_cut.py`: 16 bars, the seam cross-faded, -23 LUFS), not listened to; measured
  again 20. 10.: no click at the seam, the beat lands on the loop's start (19.2 s, a beat
  every 0.302 s), a dip of ~50 ms where it was cross-faded
- Notes for agent C: `tools/coop_check` still opens the old pub tap close-up
  (`_service_interior._open_counter_game()`), so "the other warden does not see the host
  behind the bar" fails since the tap went 3D (457d21b); `scripts/business/corn_closeup.gd`
  connects its canvas to `_draw` (the Control's own: it draws on another node from it and
  floods the log with "Drawing is only allowed inside this node's _draw()"; Goggle had the
  same, fixed by a `_draw_page` of its own) - moot if the corn stand's 3D stations
  replace it
- [x] `Parameter "material" is null` (8x) in the smoke test: gone by 20. 10. morning
- [x] Replace the other code-made sounds too? Yes, all of them (the user, 20. 10.): the
  Photographer's camera, the thump, the pager, the station that does not exist, the phone
  line, the splash's neon and the set's tone are recordings now (agent B; only the radio's
  dread stays layered in code)

## CO-OP — two wardens, step by step (DESIGN.md §12; each stage gone through with the user)

- [x] 1  Connect and see each other: CO-OP in the menu (host a sandbox camp / join by address), the whole camp sent on joining (same seed, same trees), the host's clock, weather, power and till; the other warden as a figure with torch and steps; no pause in co-op; only the host saves (`tools/coop_check.py`)
- [ ] 2  Hands for the joining warden: every action goes to the host (build, demolish, mail, check-in, cleaning, repairs, the PC); one at the PC, the other sees the screen over their shoulder; sleep skips the night only when both are asleep
  - so far (17. 10.): the rooms (tents, cabins, caravans: in, and their jobs, done in the host's camp), the one boat (whoever has it rows it on both lakes); the host's builds, demolitions, repairs and upgrades done again on the other machine; on the CO-OP page who you are (Pepa, Ondra, Jana, Bara) and your jacket's colour; the office building for both; sleep: the night passes only when both are in bed (one bed, in the back room); the PC over the shoulder: the one at it sends its screen, the other sees it on the office's PC
  - 18. 10.: the PC for either (one at a time): the Builder's builds and demolitions, CampMail (read, delete, bookings taken or turned down, replies, sent mail), the data-punch pay; the check-in desk, the phone, the shed key from the board; hold R on a lamp; fish sold. All of it done in the host's camp (`Coop.send_request` → `main.coop_request`). Room upgrades bought from either (the host buys them). The service buildings for either (toilets, showers, the pub, the shed...): their cleaning, the repairs (the pipe crawl, the utilities) and the breaker go to the host. A guest lost in the corn can be found and led out by either (they follow the other's stand-in). The other machine's till follows the host's with its own spending and takings sent over numbered (the town, the pub, the pump: `main._coop_follow_till`); it talks to guests and sorts the day's events with E too
- [ ] 3  The camp on both screens: guests and their walks, the bus, lamps, doors, failures and repairs, money and mail as they change
  - 18. 10.: the host's camp pulse once a second (`main.coop_camp_pulse`): the guests and their plans (they walk the same on both), breakdowns, the lamps' wear, the rooms, the mail, the shed key, the day's events (the other machine shows them and sorts them out through the host: rubbish, raccoons, the van, the boy, the branch, a knock); the other machine simulates no guests and gets no mail of its own. The electrician's visit and the night's lamp faults are seen from the other machine too (`coop_mirror` group, the pulse)
  - 18. 10.: one bus for both: while one is aboard (buying the ticket, finding a seat) the bus waits at the stop on both machines; seated, it still waits for the other a while if they are aboard or coming (up to 15 s within 30 m, the driver asks after them); they ride it together, each seeing the other sitting (from the front or the back) or standing by the driver, and get off side by side; gone with one alone, it leaves the other's stop too. The passengers are the same on both (seeded by stop, day and half-hour) and camp guests out for the day sit among them (`bus_ride.gd`, `town_trip._coop_hold`)
- [ ] 4  Rooms and minigames for two: both in one cabin, a job taken by one is locked for the other, the scrub/tap/till/sewer close-ups
  - so far (17. 10.): both in one room see each other, standing about or at their job (the broom, down on a knee scrubbing; in a tent lying on their belly); each one's jobs come back to the other's room
  - 18. 10.: the attractions for the warden, alone or two (`scripts/attractions/warden_play.gd`): E by one and you are in it as a guest is, from your own eyes: sit by the fire (a log on from the pile, LMB a sausage over the coals and eaten when done, Q the guitar), on a bench, at the picnic table, in the hammock, on the swing (LMB pumps) or the seesaw, down the slide (up the ladder, LMB at the top), at the nohejbal net and the ping-pong table (LMB in time kicks or hits the ball coming to you; missed, it rolls off and you fetch it). The other warden is seen in them (their figure placed by the same attraction); the ball games are the host's (each flight sent over, the other's swings sent to the host), the logs go on through the host. New sprites for the four wardens (guitar, sausage, kick, bat, ladder, swing) and the guests' kick and bat
  - 18. 10. (evening): the businesses for two and point and click (DESIGN §7b): doors between the rooms (`scripts/food/business_doors.gd`: walk, swing, dither, in through the next door; the bistro's dining room, kitchen and cellar, the pub's new cellar, the Jednota's storeroom), no side tabs; everything usable glints; marks where work waits (`scripts/food/work_marks.gd`); the pass moved to the kitchen's island; the cellars show the stock and open the books; the other warden at the tap, the bottles, the washer, the pass, the stove, the till, the books (`service_interior.coop_job` / `coop_job_spot`); the host's serving reaches the other machine (`_coop_sync_things` "served"); the HUD guests cell blinks N WAITING, the waypoint points to the business
  - 18. 10. (night): the corn stand for either warden (the joining one could not step behind it), the wholesaler's leaflet on its counter (the books' ORDER page), the warden behind it seen at the pot; the businesses' books are the host's in co-op: in the camp pulse ("biz"), and what the other warden does to them (a cob taken, a sale, an order, a hand taken on) goes to the host (`actions.biz_remote` -> `main._coop_biz_change`, the money with the till)
  - 18. 10. (night): the sewer's chamber (DESIGN §8): dense Grok room, the pipe mouth to click (in broken or not), the amber terminal with the network and its faults (`scripts/pipes/sewer_terminal.gd`); two in the pipes (`scripts/pipes/pipe_mate.gd`): the same network (seed and raccoon level of whoever went down first), each seen by the other, no getting past, backing up feet first (tap S), squeeze, a clamp by one is a clamp for both
  - 18. 10. (late): the back office is the host's on the other machine too: CampStat's reviews, takings and bills, satisfaction, the bazaar's lost and found (in the camp pulse "books"); a bill paid, the maintenance crew sent or a thing put up on the bazaar from there is done in the host's camp (`main.coop_request` pay_bill / crew / bazaar_list); Vera's checklist never runs in a sandbox camp (a loaded one started it, and on the other machine it paid its rewards a second time); Lesna's rounds (Sgt Vavra's patrol, Pepik's bike) walked by the clock, the same on both machines
  - 19. 10.: up to four wardens (the user: "chceme cílit na 4 hráče"): the host and three joining (`Coop.MAX_WARDENS`, everything to everyone through the host); each joining one has their place on the line and its figure if they chose none; one figure per warden in the camp, the rooms, the bus, Lesna's places, the attractions (keys -11..-14), the pipes and the map; the till counted per warden; the night passes when all are in bed; knocked down, the nearest gets you up; the night hunts any of them (a stand-in, a sanity and private enemies each; the director and its touches to the one pressed and those near); one boat for two (the oarsman and one in the bow); an item picked up goes to the one who picked it (`tools/coop4_check.py`)
  - 19. 10. (later): checked for four (`tools/coop4_check.py`): all four round the fire, in the old cabin, down the sewer's pipes (each sees the other three; the ones behind crawl into the first's boots; those lying right where you lie are felt, not drawn), one going home while the other three play on; the office names whoever has the PC or the desk; the 13:20 to Lesna for all four (it waits for the last one buying a ticket, all four ride it) and U Jezera's bar together (the others stand at the counter in sight, not out at your elbows: they were out of view even for two); at night an enemy only for one of the joining wardens is seen by them alone (not the host, not the other two), one for all by all; a fifth who calls is told the camp is full (one line more than the places, then hung up) and the others never hear of them (the host's roster)
- [ ] 5  The night for two: the director knows both; enemies hunt either; sometimes only one sees it; a hidden sanity per warden (no meter, never named)
  - 18. 10. (`scripts/coop/coop_night.gd`): the host's enemies hunt either warden (the other has a stand-in body there, `coop_proxy.gd`), whoever is out and alone in the dark sooner, and let go of one gone indoors; their hits and feed lines go to whom they hunt; the other machine shows them as on the host's (sprites, lights, sounds, 10x a second). Some are only for the one hunted (the other sees and hears nothing). The hidden sanity: hits, an enemy in front of you, the dark alone wear it down, day, company and sleep give it back; low, the night picks you sooner, more is only yours, and you glimpse the other warden where they are not. Down in co-op you come to on the office step instead of the game ending. The night director presses on one warden at a time (the one out, else the one with less sanity, held 40 s); its touches happen on that one's machine, and on both when they are together. Omens are each warden's own
  - 18. 10. (later): tonight's jobs are the host's on the other machine too (the TONIGHT list, the pager, the waypoint, "sorted" when either sorts one out: `night_jobs.coop_take`); knocked down you lie there till the other gets you up with E (90 s, else the office step; the night lets go of you meanwhile); the host's campfires sent every 4 s
  - 18. 10. (evening): one radio for both: the host's set plays on the other machine (the same song from the same place, the station's pips, the night's broadcast built from the same pieces), the switch from either (`building_interior.coop_radio_state` / `coop_take_radio`); in Lesna's places (the pub, the Jednota, the chapel, the kiosk, the motel) the other warden stands with you at the counter; seen at work in the camp (a spanner at R, the saw, the bin bag) and fishing on the far shore
- [ ] 6  Saves of a co-op camp (host), joining a camp already going, a dropped line and back, a name per warden
  - 18. 10.: the host's saves are marked co-op and the CO-OP page's Last camp hosts the newest one (its day and till beside it); joining a camp already going works (the whole camp on joining); a dropped line: the other's figure goes, the joining one is back at the menu and can join again; the other warden is called by the name they chose (Pepa, Ondra, Jana, Bara) in the feed
  - 18. 10. (evening): the look is the warden's, not the CO-OP page's: chosen on the WARDENS page when a warden is made and changed with Edit warden (name, figure, jacket); the other warden is called by their warden's name. The joining warden can work the barrier (the client's E skipped everything outside the camp), from the road too (the wall in the gap shadowed the handle), and E lowers it again

## BRIEF 2026-10-19 — the PC at the reception (the user's notes)

- [x] D1  Not a full-size OS but a game panel that parodies one, practical above all: quick switching between Builder, CampStat and GuestRack (tabs, keys 1-9, badges, programs kept running, modal dialogs, a short boot)
- [x] D2  Builder: a card for a clicked building (upgrade from the map, the crew, demolish, GuestRack), overlays (wear, power, rooms, light at night), keys (B P L, F1-F5, O, X, arrows); GuestRack's rooms and CampStat's upkeep open the building on the map
- [x] D3  CampStat's Today page: what wants doing, with the button that does it (Pay all, the crew, GuestRack, CampMail, the night)
- [x] D4  A clicking side job: the Jobs folder (DataPunch, KlikBanka pop-up shifts, SectiTo aerial counts), daily limits, paid into the till
- [x] D5  Funny games: Komar 98, Vylet 98, Pexeso 98 beside Mines; they are Vera's (on the PC from the start, her names on the high-score tables)
- [x] D6  The web: games, work from home, the #jih chat (somebody logs in as the camp at night), the horoscope
- [x] D7  The OS's wording is a plain 1998 system's (no "do not tell Vera"); Files with the Web View pane (types, sizes, the dates that tell the story)
- [ ] D8  Later: art for the new programs' icons from Grok (the drawn ones are stand-ins), Builder card for paths and lamps, more Bohemia Online pages

## BRIEF 2026-10-18 — the big list (the user's notes)

- [x] C1  PC: z-fighting at the lamp, the jerk after the OS boot; S stands you up, D leans out of the window
- [x] C2  Key fobs readable; lodgings numbered per kind (T1 T2, C1, V1) on the fobs, the TAB plan, the Builder, and signs in the camp (a board on a stake by each tent, an enamel plate by the cabin and caravan doors)
- [x] C3  The cabin inside matches outside (no bathroom door in Lv1; the windows look into the real camp)
- [x] C4  A/D turn in interiors; a wider view, more up and down; interiors at the low render resolution; the reception turns all the way round
- [x] C5  Jednota sprite size; back sprites in the Builder when turned; no vanishing textures while zooming; the lamp's z-fighting and bent stick
- [x] C6  Guests open the doors and step in and out
- [x] C7  Dotted arrival rings at the screen edge
- [x] C8  A cabin is let whole (its free beds are not free)
- [x] C9  The fire and the attractions: the campfire (fuel, logs, sparks, benches, sausages, guitar), the slide (climb, slide, splash), the nohejbal court (rally over the net); guests in the pub, bistro and Jednota; the counter minigames (tap, pass, till)
- [x] C10 The torch: the hand points into the scene, low and small; a weak beam that trails the view; in dark rooms it shines where the cursor points
- [x] C11 Toilets: each outside door its own stall (no A/D); the poop and the second bowl clickable again (stale bodies, the exit band)
- [x] C12 The caravan: model after the sprites (Grok textures), 3 levels by upgrade (2/3/4 beds), the interior (dinette bed, kitchenette, bunks), its niche (cheapest bed with a roof, most beds per tile, less comfort, needs power, wears faster)
- [x] C13 Tutorial and lore: less mail; CampStat preinstalled; Vera mails the links to the Builder and GuestRack; the camp is inherited from Vera's family, abandoned, a firm wants the land for a factory and you have a month to get it running; a hint of a curse; start with ruined buildings (a filthy, rotting first cabin to repair and clean, which teaches how a cabin works). Done: Vera hands the camp over for good (at her sister's in Pelhrimov, tips by mail), shut since last summer, Agrostroj's feed mill, the district's inspection at 08:00 on 19 October ends the month; the opener carries clickable download links; the story pool trimmed of system filler and week-era lines; the old cabin by the office boarded up, rotting, no bookings until patched (R), inside dark with the window boarded, cobwebs, and every mess there is
- [x] C14 More buildings, decorations and attractions, so a camp can be built up properly (bench, picnic table, flower bed, gnome, flagpole, playground, ping-pong, hammock; a Decor tab)
- [x] C15 The six guest types with their own tastes in attractions, lodging and entertainment; a deeper care simulation (the caravan's admirers and critics; noisy guests keep light sleepers up; wishes in the booking mail)

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
- [x] B15 Fake OS and internet overhaul: Build-style PC (boxes + Grok faces), Okna 98 splash/shutdown, desktop menu, Display Properties, screen saver, installer backdrop, IE4 browser chrome, new pages, GIF banners, tiles, blink/marquee
- [x] B16 Starter path from the barrier to the reception door, cannot be bulldozed; reception one tile in
- [x] B17 Reception redesign (behind the counter, PC left, keys right) and the Papers Please check-in desk, with the night stranger
- [x] B18 Tasks only while TAB is held; outdoors the site plan moves left of them, indoors tasks alone
- [x] B19 Screen saver would not wake (slow mouse moves were under a pixel on the monitor)
- [x] B20 Reception clicks dead (room raycast used get_world_3d on an own-world viewport)
- [x] B21 Corn: no falling through; second maze exit, the strip under the wires, the linemen's hut
- [x] B22 A month instead of a week, through the autumn, snow at the end; frozen pipes and cold tents
- [x] B24 OS: the maker's loading bar fixed (Grok boot screen, amber blocks); new icons, wallpapers (Autumn Lake by default), Okna splash (Grok)
- [x] B25 CampMail 3.0: folders, cool toolbar, sortable list with envelopes and attachments, From/To/Date header, spam that reads like 1998 spam with pictures (Grok), reply/forward/compose, delete to Deleted Items, keys
- [x] B26 The radio always opens a new game with "radiojedna"
- [x] B27 Download and setup progress bars: Win98 blocks per file, InstallShield bar with the percentage
- [x] B28 Builder remaster: static/dynamic layers (16 -> 50 fps), smooth zoom at the cursor, pan inertia, minimap, hover card, splash (Grok), flat cool toolbar (Grok icons), sliding catalogue with cards, info card, dust puffs (Grok)
- [x] B29 The reception window is a portal into the real camp (off-axis camera, parallax as you lean)
- [x] B30 The monitor is curved glass: barrel, rounded corners, bulge, highlight; the crisp overlay and the mouse use the same barrel
- [x] B31 Esc is always the pause menu; S / the bottom band / a right click leave; "Go outside" in the pause menu
- [x] B32 Pause menu clicks; screen saver never while seated; the far shore can be left; room UI no longer scales with the render style
- [x] B33 Back room: full turn, the doorway back, curtain and a window to the gate lane; office curtain, desk lamp, daylight, monitor turned to the counter
- [x] B34 Reception rebuilt from the office's plan; phone modelled after its close-up with ringing; toilets as two stalls with a scrubbing minigame
- [x] B35 Lamps: model, light, no lost path under them, same spot in the Builder; rubbish and raccoons beside buildings, not on roofs
- [x] B36 Builder: zoom no longer slides off the map; construction effects; guest miniatures
- [x] B37 The night director (tension, budget, archetypes, memory, 14 events, night log); night work (DataPunch, guest book)
- [x] B38a Director: a light in the woods, an object moved, a reported cabin that sounds at night (day event "someone", knock to look)
- [x] B38b Builder undo (Ctrl+Z / toolbar, today's builds, full refund); director: twig, the insects' silence, a door banging, steps in the back room; sleeping guests count for the camp's character (they did not)
- [x] B38c Director: a sleeping guest at the tree line (rare, named in the log, denies it by day)
- [x] B41 Playtest 21. 10. (the long list): the slowdown over hours (retro_materials kept every room's materials: ~400 objects and 20-38 MB of video memory a business visit, till rooms, windows and Builder 3D went black; now pruned), co-op (licences bought by the other warden, the PC on at the host on for a joining warden and the office's lamps right after a join: synced things are sent again once they have loaded, eyes 1.45 m and the other warden's figure to match), the back room dark in a blackout, no torch or glove over the title screen, guests' patience half as long again, litter picked up with one click (and found near the cursor), the cleaning signs lower, no NIGHT RISK lines at the top, the staffroom's applicants from anyone not in work and no guests strolling into it, rain and wind-blown leaves and twigs dark at night (the leaves turning as they fly), calmer trees, the cabins' gables closed, the WC/M/Z/SPRCHY lettering in front of its boards, the tent's door on E and a click anywhere on it, the cabins' windows showing the real room from the camp, the corn maze readable (walls dense where the corn is solid, trodden ways) and easier, the noise complaint's guest marked over their head and at their lodging, the sewer's shaft down into the pipes (thicker fog, the camp's breath, drops as streaks), the boat's mouse at the walk's speed, the jetty's steps level, Builder 3D's arrow off the building's front, the god cursor over the lake turning slowly, its tip at the camp, the lemonade bottle over the table as it pours
- [x] B40 Sleep: the radio fades out as the eyes close, silent through the night skip, a new song in the morning (back-room bed and lodging beds; co-op: each machine for its own sleeping warden, the song stays the host's)
- [x] B39 Save round trip checked (director memory and log, reputation, reported cabins, DataPunch nights); the PC no longer stays dark after a save is loaded in-game
- [x] B38 Bazar Hlubocany: the lost and found from checkouts, ads, morning sales, the red shoe; new game no longer shows the last game's night log
- [ ] B23 Later: lore in the linemen's hut; more winter challenges (snowed-in paths, the lake freezing, heating cabins)
- [x] B13c The boat at night as its own scare (scripts/lake/night_row.gd: knocks, lantern, fog, the hand, the scrape)
- [ ] B13 Later: something hidden in the shed (beyond the coat), more to do on the far shore
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
- [x] Setup screen: STORY or SANDBOX on NEW CAMP; the sandbox's switches (night threats, weather, day events, wear, starting money), saved with the camp
- [ ] Setup screen, more: map size, other parameters
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
- [x] Pub / restaurant: complete interior, own interactions, more life, activities (the bistro 19.-20. 10., the pub 20. 10.: DESIGN §7b)

## BUSINESSES (agent C, 2026-10-20; DESIGN §7b)

- [x] Phase 0: the bistro's stations in the 3D room (`scripts/business/station3d.gd`, the rail, the frame)
- [x] Phase 1: Papa's ratings, the Z report, goods going off by lots, one order from the PC, gear, the hands (roles, shifts, away, theft, the strange two), open late with the night inside
- [x] Phase 1 left: the chalk strike on the menu board, a note where a hand away today would stand (camp/note_away, crew_figures), the bistro's gear in the room (heat lamps, ticket clock, dishwasher)
- [x] Phase 2: the pub (stations along the bar in 3D, the keg in the cellar, its hands by role, kegs that go flat, gear; pub_check, pub_shots, pub_coop)
- [x] Phase 2 left: the pub's gear seen (the second tap by the tower, the quick coupler's head, the glass washer, the cooler), sounds of the keg (keg_roll, coupler, gas_hiss) and its own order (a coin on the bar)
- [x] Phase 3: the corn stand (counter and husking in 3D on the stand's counter, the live camp beyond it; its hands, gear; stand_check, stand_shots, stand_coop)
- [x] Phase 3 left: the gear seen at the stand (the bigger pot, the butter warmer, the husking table), sounds of its own (a leaf torn, a cob into the pot, the butter, the salt)
- [x] Phase 4: the Jednota (three by three with its Build model and Builder pictures; the till, the shelves and the storeroom in 3D; the queue; its hands, gear; dear and it pays; jednota_check, jednota_shots, jednota_coop)
- [x] Phase 5: PROTOTYP 540 (awake at night and on the late shift; the sack on its nights; fed, the goulash's meat for nothing by morning; proto_check, proto_shots)
- [x] Cellar / machine room: the dark mechanic designed and hooked up (PROTOTYP 540, DESIGN §7b "The bistro")

### 12. 3D models and the camp's look
- [x] New gatehouse (generated textures)
- [x] Remodel cabins, tents, restaurant/pub, toilets/showers, reception; reuse the existing
      atmospheric textures first, generate missing ones in the same style (Grok)
- [ ] Visible paths out of the camp where guests leave (forest trails, lake path)

### 13. Fewer guests in sight
- [x] Guests stay in lodgings, leave the camp by exits for hours, stand at the lake (64% -> ~35% outdoors)

### 14. The lake
- [x] Reflections (21. 10., the user: "jezero jen polish, remodel asi uplne ne"): the water
  gives back the far shore's forest, the houses, the boat and the jetty, lit windows, the
  stars and the sunset for real (`camp_lake.gd` mirror camera at half the game's pixels,
  near the water only; everything under the water clipped for it in the surface shaders)
- [ ] Remodel: shore, reeds, surrounding forest (not wanted for now)
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
