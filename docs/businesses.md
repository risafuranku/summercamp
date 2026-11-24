# Businesses and their stations

The pub, the bistro, the Jednota, the corn stand and their work.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **One room a kind of place** (12. 11.): `interior_manager` keeps a `service_interior` for
  every kind (`service_interior.KINDS`: rest, pub, vecerka, staff, toilet, wash, generator,
  sewer; `profile_for(building type)`), each built once behind the loading bar, one a step
  (`room_jobs`, `_service_room(kind)`), registered as "service:<kind>" so the time, the
  weather and the power reach them all; `_service_interior` is the one in use, chosen at
  the door (`_use_service_room(type)`, before the walk up). One room for every kind was
  built anew at each switch between them (100-350 ms at the door; the walk in up to half a
  second). A tool that opens a business room directly selects it first
  (`_interior_manager._use_service_room('pub')`). A business's stations are made before its first
  door: a closed room looks every 2 s for the first business of its kind on the plan and
  makes the stations it lacks, one a frame (`_tick_prepare`, `_business_of_my_kind`,
  `_make_station`); the door finds them ("make up ..., round 1" 3-34 ms).

- **Business rooms** (`service_interior.gd`): the pub, the bistro and the Jednota change
  rooms only by their doors (`scripts/food/business_doors.gd`; `_build_business_doors`
  puts them in walls the layouts keep free: move a prop off a wall and check the door
  still fits). While a door walk runs it owns the camera (`_doors.walking()`). The work
  marks (`scripts/food/work_marks.gd`) read `business_runtime.waiting_at` and the site's
  books; a new counter game needs its job in `coop_job`, `COOP_JOB_SPOTS` and SPOTS.

- **A station's hand** (`scripts/business/station_hands.gd`): made by station3d while a
  station is open, under the frame (layer 95; the stand's view is 94, its books 98). The
  station's member is `_hands_ui` (the stove has its own `_hand`, a sprite). Where a tool
  works is its picture's topmost end (`_tip_of`). Shot drivers move the pointer with
  `station.debug_mouse_to(design px)` (a warped mouse does not always reach the window
  in a test run: `station3d.debug_mouse`, read through `mouse_of`).

- **A pub bill lives fifteen game minutes** (`pub_rules.BILL_WAIT`; the clock runs about a
  minute a real second), then it is left on the bar or walked out on. A harness that jumps
  the clock to get one must wait for it (`["until", "<taproom>.bills(key).size() > 0"]`)
  and read it at once, on both machines (`tools/podniky_coop.gd`).

- **`pub_rules.tickets_for / more_rounds / bill_for` take `shut`** (last orders): the rail, the bills and the holds must agree on who is still coming for a round.

- **Render layer 1 << 14 is the corn stand's two back posts** (`stand_layout.BACK_LAYER`): every eye sees them but the stations', a hand from them.

## Rozhodnutí 24. 11. 2026: podniky postupně

Richard, 24. 11. 2026: „Pojď využít to že máme groka, a totálně prostě ještě obohatit hru… management u počítače je prostě suchej… bojim se že hospoda či bistro pořád nebudou vůbec dobře implementovaný a promyšlený… v bistru je toho prostě strašně moc… přijdu a pálí se guláš a ani nevim proč, u nandavání mi chyběj věci a nevim k čemu… Co tam dát nejdřív jedno basic jídlo a pak to přidávat postupně? za peníze upgrady? to samý hospoda a kuželkárna případně? tam ani nevim jeslti občerstvení funguje“

Kolo 1 (otázka → odpověď doslova):
- *Bistro: dnes má od začátku 9 stanic a hosté objednávají všechno. Jak má nové bistro začít?*
  „Jedno jídlo, menu za peníze“: nové bistro umí jedno jednoduché jídlo na 2–3 stanicích; další
  jídla kupuješ do menu (v knize bistra nebo v programu na PC); každé přinese svoje stanice a hosté
  objednávají jen to, co je v menu.
- *Hospoda a kuželna: mají jít stejnou cestou?* „Ano, od základu“: hospoda začne jen čepovaným pivem
  (sud a výčep); rum, kofola, myčka a hry se dokupují. Kuželna začne drahami a bufet je upgrade,
  který spolehlivě funguje.

Kolo 2:
- *Bistro od jednoho jídla: které má být to první?* „Klobása z grilu“: gril a výdej, 2 stanice,
  klobása s hořčicí a chlebem; menu se pak dokupuje od nejjednoduššího: polévka a lahve na bufetu,
  guláš s knedlíkem, nakonec hranolky a smažák se sklepem.
- *Kde se kupují další jídla do menu bistra, pití a hry v hospodě a bufet v kuželně?* „Kniha na pultu
  i PC“: v knize podniku na pultu přibude záložka Menu s věcmi ke koupi; stejný seznam v programu
  podniku na PC v recepci (Boss 98); koupíš tam, kde zrovna jsi.
