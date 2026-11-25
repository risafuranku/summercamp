# The office PC: Okna 98 and Builder

The camp computer, its programs and Builder 98.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **The camp computer is a panel, not a desktop** (playtest 19. 10.): one program on the
  screen at a time, all kept running; tabs by keys 1-9 (read by `physical_keycode`, a
  Czech keyboard types +ěšč on that row). A program's own keys must not use the digits,
  S (stands you up), A or D (they turn you between the monitors): Builder pans with the arrows, its tools are B/P/L,
  its catalogues F1-F5, O the overlay. A method called `hidden()` clashes with
  CanvasItem's signal: the panel calls `page_hidden()` / `shown()`.

- **The OS's own words are a real 1998 system's**: it never addresses the player, jokes
  about the story or knows Vera ("do not tell Vera" was rejected). The lore goes in the
  data: file dates and contents, the games' high-score names, the mails, the web, the
  programs' publishers' texts.

- **Message boxes are modal**: a catcher under them rings and flashes the dialog on a click
  elsewhere; while one is up the tab keys do nothing (`has_dialog()`).

- **Demolish takes any box up to 64x64** and charges per tile it clears (trees, corn, a
  building's footprint), not per tile of the box; the Builder's tag reads the same numbers
  from `builder_authority.summarize_demolish(rect)`. Build rejections print as
  `SHOT DRIVER build rejected`.

- **Paths go down on release**: the Builder's path tool drags an L-shaped line (Shift keeps
  it straight) and sends the whole line when the button is let go (`_end_path_drag`);
  the confirmations of that batch (`_path_batch`) give one sound and one price, a co-op
  client's arriving later.

- **The OS boot takes ~7 s** (warm-up, BIOS, maker's screen, Okna; a key or click hurries
  each): harness waits must be longer than that, and a test that skips itself when an app
  does not open must fail.

- **The monitor glass bends the picture**: `CRT_CURVE` in `building_interior.gd` must match
  `curve` in `crt_glass.gdshader` and `crt_sharp.gdshader`; `_map_mouse_to_crt` runs the
  same barrel, so clicks land where the OS draws.

- **Builder's building pictures come from the models**: change a model in
  `building_models.gd`/`building_manager.gd` and its four pictures must be drawn again
  (`tools/iso_render.tscn`, then `iso_views.py cut`/`raw`); never mirror one to make
  another side (a mirrored front put the pub's door where the camp has a wall). Bit 19 of
  the render layers is the glass layer (every window in the camp): the render uses bit 18.
  The render turns the retro shader's vertex snap off (`iso_render._unsnap`): at 150 lines
  on its 768 px a thin part (a flagpole's pole, the gnome's coat, a lamp's post) folded to
  nothing from one corner, and Grok repainted the hole.

- **The god cursor hides what it has still to bring down** (`visible` off, the body's
  collision layer 0, a shadow on the ground) until it lands: code that reads a building's
  visibility must expect it; `finish_all()` brings all of it down at once.

- **Builder runs behind the other programs**: its map is `is_visible_in_tree()` while the
  PC shows something else, or nothing (the startup view): "the warden is building now" is
  that and `building_interior.is_crt_view_active()` (`god_cursor._staged`).

- **Two monitors, one picture** (21. 10.): with the second monitor the CRT viewport is two
  screens wide (1280 x 480); the shell stays a 640 x 480 Control at the left (no
  FULL_RECT: it would stretch) with `clip_contents` off, the second screen's pages sit at
  x 640, and each tube's glass shows its half through the shaders' `uv_rect`. Mouse
  positions on the second monitor come in at x 640+ (`_map_mouse_to_crt` adds
  `_look_origin()`); anything that measured the PC by `_crt_viewport.size` must use
  `CRT_RESOLUTION`. Both programs on screen are visible and running: a program that reads
  keys in `_input` must also ask `OS_KEYS.here(self)` (only the screen looked at takes
  keys), message boxes open on the screen looked at (`_make_dialog` adds `screen_origin`).

- **What is still to come from the god cursor is on BUILDER_EYE** (`god_cursor._veil`, meta `god_waiting` till it lands). A node added to the tree again (a leaf going onto its hinge) was noted twice and came back on the Builder's eye: a cabin with no door, the first one built, the one a room stood in at once. A room does not stand in a waiting building (`_find_cabins`, `_find_vans`): the van noted its shell's layers there and put them back, the van gone whenever the room left it. Whoever keeps a building's layers to put back asks for `god_waiting` first. `tools/theatre_check`.

## Rozhodnutí 24. 11. 2026: šťáva u PC i mimo něj

Richard, 24. 11. 2026: „Přijde mi že samotnej management u počítače je prostě suchej, odcházení od
kompu na dělání věcí nemá ještě uplně šťávu“. Na otázku *Kam nejvíc šlápnout?* (PC zadává práci venku
/ živější obrazovky PC / obojí): „Obojí stejně“.

Kolo 2 (24. 11. večer, otázka → odpověď doslova; vybíral víc možností):
- *Co má práce u počítače v recepci viditelně spustit venku v kempu? (Teď objednávka, stavba i nábor
  proběhnou hned a beze stopy.)* „Výsledek vidět venku“ (objednávka přijede dodávkou a vykládá se před
  podnikem, stavba z Builderu se pár hodin staví s dělníky a lešením, nový zaměstnanec přijede
  autobusem a dojde do práce), „Úkoly z tiskárny“ (jehličková tiskárna v recepci vytiskne lístek
  s prací: oprava, úklid, rozvoz; lístek se objeví v Úkolech v PDA a za splnění venku je odměna),
  „Hlášení do ampliónů“ (co změníš na PC: nové jídlo, otevřeno do 23:00, akce, se samo ohlásí
  z ampliónů a hosté se podle toho seběhnou).
- *Co nejvíc oživí samotné sezení u počítače v recepci?* „Kemp naživo v programech“ (CampStat
  a Boss 98 ukazují hosty jako tečky na plánku, fronty u podniků a tržby, jak přibývají; v okně běží
  webkamera kempu), „Stroj jako stroj“ (je slyšet disk, ventilátor, tiskárna a modem; občas se něco
  sekne a musíš počítač restartovat).

Kolo 3 (24. 11. večer):
- *Stavby z Builderu: jak dlouho má stavba trvat, než jde používat? (Teď stojí hned, jak klikneš.)*
  „Pár hodin podle velikosti“: stan a lavička hned, chatka a podniky 2 až 4 herní hodiny; mezitím
  lešení, dělníci a bouchání, hosté dovnitř nemůžou.
- *Tiskárna v recepci: co má tisknout a co je za splnění lístku venku?* „Jen připomínky“: tiskne, co
  v kempu čeká, bez odměny; lístek je jen v PDA a na papíře.
- *Hlášení do ampliónů: jak má hlášení znít, když na PC přidáš jídlo, otevřeš do 23:00 nebo vyhlásíš
  akci?* „Jen znělka“: gong a nesrozumitelné brumlání, co se hlásí, je napsané v PDA.
- *Stroj jako stroj: jak často se má PC v recepci seknout a co restart stojí?* „Jen zvuky, nesekat“:
  disk, ventilátor, tiskárna a modem jsou slyšet, ale PC nikdy nezamrzne.

Hotovo 24. 11. (hlášení do ampliónů): koupený řádek menu a otevření do 23:00 (z knihy i z Boss 98,
jedno místo: `actions.biz_add_menu`, `biz_set_late` vysílají `EventBus.biz_news`, v co-opu na obou
strojích) jdou z ampliónů jako gong a nesrozumitelný hlas (`assets/sfx/pa/`, ElevenLabs,
`tools/audiogen/prompts_pda.tsv`), rádio se pod tím ztlumí, do PDA přijde „Rozhlas: …“ a hosté
v dosahu sloupu, kteří zrovna plánují, co dál, jdou s pravděpodobností 35 % do toho podniku (jednou
na hlášení, 90 minut; `pa_rules.PULL_*`, `guest_life._pulled_visit`). Bez sloupu v kempu se nehlásí
nic. Test `pa_check`, ve hře `--scenario=pa_pole` (hospoda otevře do 23:00).

Hotovo 24. 11. (stroj jako stroj): `scripts/os98/pc_noises.gd` (dítě `os_shell`): když je PC zapnuté,
hučí větrák a točí se disk (bezešvá smyčka `assets/sfx/os98/pc_hum.ogg` z ElevenLabs přes
`tools/audiogen/ambience_loop.py`, loop v .import), disk sám občas cvakne (18-55 s) a cvakne při
otevření programu (`seek.mp3`); hlasitost jako ostatní zvuky PC (`sound_db`: u stolu plně, přes
místnost tišeji, venku nic). Nikdy se nesekne. Oprava cestou: odchod z kanceláře vsedě (pauza „Go
outside“) nechával PC „otevřené“ a jeho zvuky (i pípání pošty) hrály v kempu naplno;
`building_interior.close_interior` teď zavře panel. Ve hře `--scenario=pc_noises`.

Hotovo 24. 11. (tiskárna): `scripts/reception/office_printer.gd` (v rohu s PC, `building_interior`
ji staví na stůl mezi skříň PC a rádio; s druhým monitorem se odstěhuje na zem vedle stolu,
`place()`). Obrázek od Groka (`camp/office_printer.png`, řádek `spr_printer`). Každé 2 s se dívá na
`camp_plan.reminders` (noční práce, dnešní události, poruchy; hosté čekající u pultu ne, jejich počet
se mění po minutách) a co přibylo, vytiskne, když je PC zapnuté: zvuk tisku (ElevenLabs
`os98/printer.mp3`, hlasitost jako PC), lístek s časem a textem vyjede z tiskárny po krocích 12×/s,
předchozí leží vedle, drží se tři. První pohled po načtení jen zjistí, co už čeká (netiskne celý
seznam). Jen připomínka, nic se za ni nedostává. Ve hře `--scenario=printer`.

Hotovo 25. 11. (kemp naživo): GuestRack, záložka Pokoje: plánek kreslí každou partu jako tečku
(zelená spokojení, oranžová tak napůl, červená nešťastní) tam, kde zrovna je, u pultu se tečky
skládají do fronty; čte se 2× za sekundu, jen když je plánek vidět (`camp_plan._read_guests`), tečka
má 4 px a víc (3 px se v mřížce ztrácely). Boss 98, Přehled: tržby podniku, které od minulého
překreslení vzrostly, svítí 2,5 s zeleně, sloupec Čeká je fronta. CampStat, DNES: kamera kempu
vpravo nahoře vedle pokladny (128×96, čas snímku vpálený dole, nový snímek po 8 s); pod tabulkou
byla useknutá u spodní hrany okna. Kamera (`camp_webcam.gd`, i stránka cerne-jezero.cz/kamera) se
otáčí na střed toho, co je postavené (stany, chatky, podniky; ne cesty, stromy, sloupy), nejvýš 75°
od čela recepce: v novém kempu ukazovala jen les za recepcí. Ve hře `--scenario=live_pc`.
