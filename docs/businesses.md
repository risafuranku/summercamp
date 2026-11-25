# Businesses and their stations

The pub, the bistro, the Jednota, the corn stand and their work.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **At a station Space serves when pressed and leaves when held** (Richard 24. 11.:
  „podržením space odejdu z obsluhování… ale ne na stisknutí protože tím vydávám
  objednávku“): `station_hud.key_action` gives "serve" for the press and starts
  `_space_t`; held `HOLD_BACK_SEC` (0.6 s) the frame emits `back` (BACK fills along its foot
  meanwhile), and the place takes it as its Esc (the pub's rooms and the bowling alley close
  the station, the corn stand closes the stand). Enter only serves.

- **The look at a station stays where you put it, and goes with you to the next one**
  (Richard 24. 11.: „něco mi pak tahá pohled dolu. nech pohled volný!“, „při přechodu mezi
  stanicemi mi zachovej můj úhel“): the corn stand's peek (W up while held, back down to the
  work after) is gone, every station has the rooms' look (W and S tilt and it stays). A room
  steps up to a station through `STATION3D.step_to(host, cam, st, was)`: the station opens
  with the one it leaves' `look_angles()` and the camera goes to its `eye()` (the pose turned
  by that look), so nothing snaps when the look takes over. Into the corn stand from the camp
  the stand's camera walks from your own eyes (the camp camera, its fov) round the nearer end
  of the counter to the station (`stand_view._way_in`, WALK_PATH and its steps, `WALK_MPS`);
  it started from a set point out front and went through the counter in a third of a second.
  Test: `res://tools/stand_look.tscn` (the way in a picture every 0.3 s, W let go, Q/E, Space
  tapped and held).

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

Hotovo 24. 11.: řádek `business_rules.MENU` má čtvrtý údaj, cenu (0 = podnik ho má od začátku).
Nový podnik má v knize `menu_bought: []`, takže bistro umí jen klobásu, hospoda jen čepované pivo
a kuželna jen dráhy. Koupě jde přes `actions.biz_buy_menu` (peníze, kniha, v co-opu `menu_buy`
přes `_biz_tell`), smažák až po hranolkách (`MENU_NEEDS`). Hosté objednávají jen to, co je
`menu_on` (koupené a zaškrtnuté). Stanice podniku má v layoutu `"menu"` (jídla, která dělá) nebo
`"gear"` (vybavení) a `business_rules.station_open` rozhoduje, jestli má záložku a jde k ní
přistoupit: v bistru gril (klobása), polévka (polévka a lahve), hrnec (guláš), sporák a brambory
(hranolky, smažák), obalování (smažák); v kuželně bufet; v hospodě LUCKY 7, šipky a karty jako
vybavení (`PUB_GAMES`, hosté hrají jen to, co hospoda má). Na výdeji v bistru je tatarka jen
s hranolkami nebo smažákem a cibule jen s gulášem. Kupuje se v knize na pultu (záložka MENU:
nekoupený řádek má cenu, klik ho koupí) i v Boss 98 (podnik → Menu: cena a Koupit). Kniha
uložená před 24. 11. (bez `menu_bought`) má všechno, co prodávala, koupené a stará hospoda má
svoje hry (`actions._biz_upgrade`). Testy: `business_check` (koupě, pořadí, peníze, stará kniha),
`pub_check`, `podniky_check`; obrazem `provoz_check --part=boss` a `bowling_shots` (bufet zavřený,
po koupi objednávka od dráhy, natočit, podat).

## Rozhodnutí 25. 11. 2026: co-op u stanic a věci na pultu stánku

- Richardova poznámka: „nevidím jak COOP hráči připravují kukuřici, nevidím ho vedle sebe, jak se jím tam hýbe pod rukama (vše co vidí jeden hráč musí vidět i ostatní)“.
- Otázka: stanice si rozdělanou práci drží lokálně, ve všech podnicích. Odpověď: **„Všechny podniky“** (jeden společný mechanismus pro stanice všech podniků, rozdělaná práce i věc v ruce se posílá ostatním).
- Poznámka: „všechny předměty na pultu s kukuřicí převést z 2D textury na 3D sprites co tam stojí, podobně jako když se kukuřice vaří“. Otázka na obrázky, odpověď: **„Grok, nejdřív vzorek“** (každá věc zvlášť šikmo shora, vzorek ke schválení, pult s čistou deskou).

## Rozhodnutí 25. 11. 2026: dodávka zboží a nástup zaměstnance

Z rozhodnutí 24. 11. (docs/pc.md, kolo 2: „objednávka přijede dodávkou a vykládá se před podnikem…
nový zaměstnanec přijede autobusem a dojde do práce“) se Richard 25. 11. vybíral z otázek
(otázka → odpověď doslova):
- *Dodávka zboží: kdo krabice odnese dovnitř a kdy je zboží na regálu?* „Pomocník podniku, jinak ty“:
  dodávka zastaví u podniku a vyloží krabice před dveře; odnese je zaměstnanec podniku, bez něj je
  odneseš ty (klikneš na krabici); na regálu je zboží až po odnesení.
- *Nový zaměstnanec najatý v Boss 98: jak má nastoupit?* „Ranním autobusem“: najmeš ho dnes, přijede
  zítra ranním autobusem k zastávce u brány, dojde do práce a od té chvíle pracuje.
- *Vzorky* (dělník na staveništi, máslenka na pultu stánku): „Obojí OK“, dodělat ve stejném stylu.

Kolo 2 (25. 11. večer, architektura: dodávka do kempu nevjede, kemp nemá silnice):
- *Jak postavit dodávku?* „Krabice u závory“: dodávka zastaví za závorou jako dnes, řidič složí
  krabice na paletu u brány, podepisování na recepci odpadne; pomocník podniku nebo hráč je
  odnese do podniku, na regálu jsou po odnesení.
- *Co dělat jako první?* „Dodávky a nástup autobusem“.

Hotovo 25. 11. (věci na pultu stánku): pult má holou desku (`corn/st_counter_bare.png`, Grok) a
věci jsou sprity od Groka (`corn/prop_*.png`, `tools/artgen/corn_props_art.py`, řádky
`prompts_corn_props.tsv`): hrnec a prkénko leží na desce (6 mm nad ní, při 2 mm je deska
zakryla), protože se do nich kladou klasy; máslenka, slánka, ubrousky a kasička stojí a jsou
nakloněné k oku jako ležící klas (`corn_station.standing`), takže se při rozhlížení hýbou jako
věci. Klikací místa (`BUTTER`, `SALT`, `NAPKINS`, `CASH`) zůstala, kde byla. Ubrousek v ruce je
obrázek hromádky ubrousků. Snímky `tools/stand_look.tscn`.

Hotovo 25. 11. (krabice od dodávky, kolo 2): dodávka stojí za závorou jako dřív, řidič dojde
k paletě kousek za závorou vedle cesty (`business/delivery_pallet.gd`, `spot`), 6 herních minut
skládá krabice (`delivery_driver.UNLOAD_MIN`) a pak je událost hotová (`day_events.sign_delivery`
→ `actions.biz_unload`): každá objednávka je krabice pro svůj podnik v `biz["boxes"]` ({id, key,
goods, by, at, t0}), na regálu zatím nic. Podpis na recepci (složka na stole, close-up
`delivery_closeup.gd`, řidič u pultu) je pryč, dodávka už nikdy „neodjede bez podpisu“. Krabice
nosí: pomocník podniku ve službě (hostitel mu přidělí volnou krabici na paletě, jednu na podnik
naráz, `biz_box_carry("s<slug>", t0)`; `hands_commute.gd` kreslí jeho cestu k paletě a zpět s
krabicí v náručí na každém stroji z `t0`, mezitím není u pultu; po návratu `biz_box_in`), jinak
hráč: E na krabici ji vezme do náruče (`ambient/carry.gd`, ruce `carry_box`, pomalejší chůze),
u jejího podniku E odnese dovnitř (zboží na regálu), jinde ji E položí (leží tam), u palety ji
vrátí na paletu. Zvuky krabice ElevenLabs (`assets/sfx/world/box_lift/down.mp3`). V co-opu jsou
krabice ve stavu podniků hostitele (puls), co udělá druhý, jde hostiteli (`_biz_tell`
"box_carry", "box_down", "box_in"); cizí krabici v náručí vzít nejde. Sandbox bez denních
událostí dál dostane zboží rovnou na regály (`biz_receive`). Testy `box_check`,
`python godot/tools/box_coop.py`, obrazem `tools/van_check.tscn`.
Plaketa vpravo „Krabice“ (`trouble_board._box_rows`, ikona `trouble_crate`): kolik krabic nikdo
nemá v náručí, s tváří pomocníka, který je zrovna nese. Krabice u závory se počítají jako „na
objednávce“ (`business_runtime.on_order`), takže plaketa docházejícího zboží nesvítí, dokud zboží
leží u závory.
