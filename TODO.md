# TODO — Cursed Camp Manager Simulator

Only open work, the most important first. A ticked item gets its commit hash, and at the next
tidy-up it moves to `docs/historie/`. Everything up to 22. 11. 2026, done and open, with its
full wording and Richard's words: [docs/historie/todo-do-2026-11-22.md](docs/historie/todo-do-2026-11-22.md)
(the codes below, P12, D2, W6..., are its headings: search for them there).

## Teď

Richard, 23. 11. 2026: „Zatím dáme bokem splitscreen i controller support. Znovu main focus na
singleplayer sandbox, zároveň i coop funkcionalita. Až bude na 100 % dotáhnut, uděláme
příběhovej režim, controller a splitscreen.“

100 % means: a sandbox camp is a finished game, alone and for two. Every system works end to
end, nothing is half-done, nothing breaks, it is balanced, nothing hitches. The story camp,
the pad and the split screen must keep working (do not break them), but get no new work.

### Playtest 24. 11. večer (Richard's words, then what it means; in the order they are done)

- [x] P4 „ESC mě nevrátí z pause menu zpět do hry“ (Esc in the pause menu must resume). d76aab07
- [x] P13 „nevidím syncnutý šuplík při checkinu. když ho kdokoliv vysune, musí to vidět všichni.
      takovýhle client side chyby se už nesmí nikdy opakovat! v žádných projektech!“ (the check-in
      drawer for everyone; a rule for every project: state another player can see is synced).
      0ff3b0e6 (desk_coop.py PASS); the rule in context/agents-common.md and CLAUDE.md, synced.
- [x] P11 „"čeká na recepci" notifkace chodí moc brzo, když jsou lidé u závory. posuň to až když
      budou fakt na recepci“. 0ff3b0e6
- [x] P1 „když dám myš ke spodní hraně, objeví se "otočit a odejít". to chceme pryč“ (the band and
      its words gone everywhere, the PC's "Stand up" too; the edge keeps the flat hand and its
      click, Esc and Space leave). 0ff3b0e6, 1a049e47
- [x] P6 „animace přechodu z pokojíku na recepci trvá moc dlouho“ (3.4 s → 2.4 s). 0ff3b0e6
- [x] P15 „podržením space odejdu z obsluhování, ať mezerníkem můžu odejít stejně jako z interiérů,
      ale ne na stisknutí protože tim vydávám objednávku“ (hold Space leaves a station). 1a049e47
- [x] P9 „podržení W u kukuřičného stánku mě zvedne, ale něco mi pak tahá pohled dolu. nech pohled
      volný!“. 1a049e47
- [x] P14 „při vstupu do podniku stánek s kukuřicí neni smooth plynulý přechod kamery. při přechodu
      mezi stanicemi mi zachovej můj úhel“. 1a049e47
- [ ] P12 „coop hráč při check inu má divně posunutý sprite do výšky“.
- [ ] (Found 24. 11.) The storm's flash through a room's windows (`ambient/room_weather.gd`
      LightningIn) has a projector and no shadow: in Godot 4.7 such a light gives nothing
      (docs/godot.md). See it in a storm scene, then give it its shadow (or drop the picture).
- [ ] P7 „COOP hráče vidím jak projde skrz pult když jde k počítači, měl bych vidět jak to obejde.
      vždy půjde tak aby mi šel za zády, mimo záběr“.
- [ ] P8 „COOP hráči můžu náhlížet blíže přes rameno, když kliknu na PC a sedí u něj, je obsazen“.
- [ ] P5 „udělat lepší světelný kužel baterky, takový co se více hodí do hry, klidně nažloutlý“.
- [ ] P3 „pořádně zprovoznit VOIP. když držim V, kliknutím přepínám jestli mluvim lokálně nebo do
      vysílačky, když jí mám v inventáři“.
- [ ] P10 „všem čtvercovým higlightům a hoverům udělej lehce zaoblené hrany“ (the highlights and
      hovers only; the plates keep their square bevels).
- [ ] P2 „udělat pořádný settings, rozdělený audio video etc“.

### The big step of 24. 11. (Richard: „Chci mít z toho dneska pocit že jsme udělali velkej krok… Připrav to do TOP stavu a pak dám velkej playtest v coopu“; Q&A in four rounds, answers word for word in the docs named)

- [x] Enemies for two (docs/night.md, Rozhodnutí 24. 11.; done 24. 11., see there): nobody moves or scares where any
      warden looks (`enemy_base._is_seen` over every warden's eye, not the quarry's alone); a
      scare for one only where the other cannot see it; the night as hard as alone but cleverer:
      the straggler (over ~25 m from the others or torch off) is the one it picks.
- [x] The environment: the storm far stronger (rain, wind, things flying, a camera shake),
      the weather changing smoothly (both done 24. 11., 11b396bc), the post-processing and the
      light tuned (24. 11.: the day, fog and rain looked through in `tools/env_shots.tscn`; the
      dawn's and the dusk's ground light now follows the sky, docs/world.md).
- [x] The businesses step by step (docs/businesses.md, Rozhodnutí 24. 11.; done 24. 11., "Hotovo" there): the bistro starts
      with the grilled sausage (grill + pass), the menu bought dish by dish (soup and bottles,
      goulash, chips and fried cheese with the cellar) in the business's book (a Menu tab)
      and in Boss 98; the pub starts with draught beer (rum, kofola, the washer, the games
      bought); the bowling starts with the lanes, its refreshments an upgrade that works.
- [x] The PA horns (docs/audio.md, Rozhodnutí 24. 11.; done 24. 11., "Hotovo" there): a "PA pole" in Builder (money, power,
      ~35 m): what the reception radio plays goes out through them as an old PA; guests near
      them slowly more fun (at most a fire's); after 22:00 it disturbs sleepers; at night only
      eerie sounds through them, no effect. The megaphone louder at the poles. Grok sample first.
- [x] The PDA (docs/player.md, Rozhodnutí 24. 11.; done 24. 11., "Hotovo" there): hold TAB, the PDA in the left hand, the
      stylus by the mouse, you walk slower; a grey-green LCD with its own "Okna CE"; apps: the
      camp's plan, notifications (it buzzes in your pocket, a small icon blinks; the pager
      goes), tasks, clock and weather, a little game. Grok samples first (the device, the icons).
- [ ] Juice at the PC and away from it, both (docs/pc.md, Rozhodnutí 24. 11., three rounds), in
      steps:
  - [x] The PA's jingle: what you change at the PC (a dish bought, open till 23:00, an offer)
        goes out of the horns as a gong and a mumble, written in the PDA; guests in reach come
        (24. 11., docs/pc.md "Hotovo").
  - [x] The machine as a machine: the disk, the fan, the printer, the modem heard; it never hangs
        (24. 11.: the hum and the disk, docs/pc.md; the modem was there; the printer with it).
  - [x] The printer in the reception: a dot-matrix slip for what waits in the camp (reminders,
        no reward), the same as the PDA's Tasks (24. 11., docs/pc.md "Hotovo").
  - [ ] The camp live in the programs: guests as dots on a plan, queues, takings as they come
        (CampStat, Boss 98), the camp's webcam in a window.
  - [ ] Building takes hours by size (tents and benches at once, cabins and businesses 2-4 h):
        scaffolding, workers, banging, no guests till done.
  - [ ] What you order comes by van and is carried to the place; a new hand comes by bus.
- [ ] Camera movement, animations, optimisation: an alpha pass before the co-op playtest.

### Sandbox: the loop and the balance

- [x] Balance pass, the money (Richard 24. 11.: only the guests pay; a tight start, then
      calm; just make what is there dearer; docs/DESIGN.md §7 Decisions): the flat earnings
      of every building gone, electricity 5.5 a kWh and 30 a day, wages half as much again;
      measured by `godot/tools/economy_sim.tscn` (docs/testing.md); 7929f987.
- [x] The booking card in CampMail (Richard 24. 11., DESIGN §7 Decisions; edebe46e): who comes as
      pictures (kinds and how many), what they want (the facilities' icons, what the camp
      lacks in red), the price of a night per guest; now and then a tempting big party for
      a lot of money that brings a hard night. Today the card is lines of text
      (`os98/apps/mail_app.gd` `_booking_card`), mind the no-explanations rule. Done as
      DESIGN §4 "The booking card" and "The tempting big party".
- [x] A lazy camp earns like a careful one (economy_sim 24. 11.: tents and one toilet, mood
      35-43 and 1.3 stars, still full and paying in full, and tents draw no power). Only the
      nights and the Atlas stars punish it, which the sim cannot see: play it, then decide
      whether unhappy guests pay less or leave sooner (ask Richard). Richard: pay less
      (1148b80a, `GuestNeedsSystem.pay_share`: full from Okay, 30 % at worst).
- [ ] The night played and balanced: the enemies' damage, cadence, battery; how often two
      kinds cross the threshold on a lazy and on a careful booking (P0); the uncanny details'
      frequency (the station 14 %, the phantom glance 35 % of nights).
- [ ] Endless sandbox: randomised offers, events and enemy mixes; the new camp's setup (map
      size, other parameters); goals (last longest, earn most, best camp, best stats) and a
      score and stats screen (iteration 5 of 8. 10.).
- [ ] D2 half-done things (looked through 24. 11.; done then: the hands' glove on every tool,
      work by gesture, doors without a seam, the god cursor in fog, dusk and for two: PRODUCT).
      Left:
  - [ ] People from eight sides: four sheets failed in October (the drunk's run 4 and his sit,
        the girl's run 3, Jana's run 3; the walk stands in for them). Not redone 24. 11.:
        `figures.py stage/pack` re-cuts every sheet of a figure from `tools/artgen/out/<id>/raw.png`
        and the out folder has been cleared since, the turnaround refs too, so adding one sheet
        means Grokking the figure's whole set again (and its look may drift). Only if play
        shows the missing runs.
  - [x] The world's own sounds (24. 11., keys from ~/.greed-secrets): the ferns' rustle (`body_world._rustle` plays nothing), the
        wade in the shallows (the oar's stroke now), small birds flying up (silent; the crow
        has its own); the corn stand's three silent presses (a cob out of the pot, the butter
        brush on the board, a husk leaf grabbed). Rows in `tools/audiogen/prompts.tsv`
        (cob_lift, brush_dab, husk_grab, fern_rustle, wade_step, birds_up): the .env's
        ElevenLabs key answers 401; `gen.py` now rotates through the GREED keys: generated,
        normalised to -23 LUFS, wired and preloaded. Not heard yet.
  - [ ] The megaphone's horns on poles round the camp (PRODUCT "Not yet"): a pole with a horn
        (Grok sample first), the voice from the nearest ones.
  - Out of the camp (the barrier, the road, the 380, Přistoupim): the land round the camp is
    Matěj's, see `matej_todo.md`.

### Sandbox: the world and the feel

- [ ] Atmosphere (P0): a dusk sky, wind in the trees by day, dogs or a train far off at
      night; a whole day and night listened through and mixed. Morning mist, a deep-forest
      place the guests walk to.
- [ ] The pipe crawl: the thing's pace played by a person; the tally on the wall is still
      letters ("IIII", wants a picture); a second map style (torn, partly wrong).
- [ ] The tent's canvas inside: a Grok source with the weave and a seam, no folds.
- [ ] Movement and camera left from 21. 10.: 3b room under things outdoors, 4b the crowns'
      calm motion (7b, the room through the open door: there since the one world, 24. 11.).
- [ ] People: the failed figure sheets again (warden_c run3, host2 run4 and pose_sit, host3
      run3); guests at attractions facing the attraction; views 6-8 drawn apart if mirroring
      bites.
- [ ] Hands: the second variant of every hand frame; the body: a glove and sleeve for every
      tool, more frames a motion, a look at the watch.
- [ ] The in-game internet (P12): the games' own title cards, sounds and impossible high
      scores (P12g); earning tied to the camp, what is left of P12h.
- [ ] Builder 98: second Grok variants (b), a hint of the cheats somewhere in the PC, the
      music heard once; the new programs' icons, a Builder card for paths and lamps, more
      Bohemia Online pages (D8).
- [ ] The second monitor: the van's front and back and PC Servis's photo (Grok), the van
      turning round to leave.
- [ ] The main menu: hotspots in the office matching the book's lines and the camera going
      to them (M5), a loading screen of its own (M6), the logo (M7, Grok, 2 samples first).

### Sandbox: no hitch, no bug, clean code

- [ ] The first hour's hitches: a thing seen first outside still compiles pipelines; the
      Jednota's one 289 ms frame 2.5 s after the walk in. Measure on a quiet PC. Through the
      doors (`tools/dvere_check.tscn` 24. 11., a busy PC: standing median 21 ms): cabin, pub and
      toilets 4-8 frames of 50-97 ms on each walk in and out, the process time 50-79 ms.
- [ ] Their own sounds for the three silent presses (the counter's board, a cob in the pot,
      the husking table's cob).
- [ ] Czech from end to end: a day and a night played in Czech (`--lang-audit`), the pictures
      with words in them (signs, posters, the web's pictures, the Builder's splash).
- [ ] Clean-up (D0, P2): `main.gd` (~3.7k lines) down to the game's flow; `BuildingManager`
      as a pure view over `GridModel`; `GameActions.end_day()` gone; dead code and unused
      assets out.
- [ ] Replace the Redneck Rampage texture rips with generated textures (`docs/art.md`).
- [x] Flaky checks: `radio_tiers_check` "splinters through the song", `steps_check` "a kick
      bounces it" (44541260: read every frame; a fixed seed).

### Co-op: two to four wardens, everything the sandbox has

- [ ] The month's end for two (the week report, the inspection) is shown on the host only.
- [ ] Sometimes in Lesna the wardens do not see each other (seen once, not since).
- [ ] The god cursor in co-op on two copies, by night and in the fog; its tempo by feel.
- [ ] Windows from outside: the PC's screen is the last frame drawn on this machine; the
      cabins', caravans' and businesses' windows show interior mapping, not their room.
- [ ] `podniky_coop`: the bufet's check waits for a soup nobody ordered (the test's fault).
- [ ] A co-op playtest with two people on two PCs, its notes into this list.

## Později

Put aside on 23. 11. 2026. Keep them working, give them no new work.

- **Story camp and demo**: Vera's polaroids (the paper and the felt-tip from Grok), the demo's
  three days (D1), the Steam page (D4), the full game's goals and mystery (D5).
- **The pad and the Steam Deck** (D3): the buttons drawn as glyphs, the pad's layout on the
  Controls sheet, an on-screen keyboard, text and frame time on a Deck.
- **The split screen** (I3-I6): 23-33 fps measured on 22. 11. against 60 alone, because the
  second warden runs a whole copy of the camp; 60 needs the second warden to look into the
  host's world (a refactor, ask Richard first). Its prompts by its own pad; business_runtime's
  static API and ~15 helpers still on the host's services.
- **The web demo** (W2-W8): the export, the boot, the size, co-op over Cloudflare, the session
  recorder, the undogames entry and the privacy paragraph.

## Nápady

- The raccoon thing: waste overflowing as a fifth night threat (an open question in DESIGN.md).
- A later brief's ideas: something hidden in the shed, more on the far shore (B13); the maze
  walls (B14); the linemen's hut's lore, a winter (B23); hidden pages; upgrades from the map,
  terrain painting, a minimap; a camp patrol and getting ready for the next day; visible paths
  out of the camp.
