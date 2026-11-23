# AGENTS.md — Cursed Camp Manager Simulator

A mid-90s Build-engine game found on an unlabeled CD: by day you run a run-down summer camp
from the office PC like RollerCoaster Tycoon, at night you go out in first person with a torch
to meet what your bookings let in. Played straight, wrong in ways nobody made on purpose.
Godot 4.7.1, project root `godot/`, English and Czech, a PC game for one to four wardens.

Read this file whole before the first command (Claude reads it through CLAUDE.md, Codex
directly). It is the entry: the rules, the focus, how to run and check. The detail lives in
`docs/`, one file an area. **When docs and code disagree, the code wins: fix the doc in the
same commit.**

<!-- BEGIN:grimroot-common -->
## Společná pravidla grimroot

Platí v každém repu v `C:\grimroot` pro každého agenta (Claude, Codex) i člověka. Pravidla repa níž je upřesňují, neruší. Tenhle oddíl se needituje v repu: zdroj je `C:\grimroot\context\agents-common.md`, do všech AGENTS.md ho rozkopíruje `node C:\grimroot\context\sync-agents.mjs`.

### Architektura (10. 11. 2026, nejvyšší priorita)

- Stav kód čistě, modulárně, se správnou architekturou a oddělenými odpovědnostmi. Funkci nikdy jen nepřilepuj k tomu, co je po ruce, jen proto, že o ni Richard požádal.
- Když ji nejde postavit přirozeně do stávající struktury a doporučil bys refaktor, aby celek zůstal čistý, **zastav se předem, ještě než začneš lepit, a řekni to**: co brání, jaký refaktor navrhuješ a kolik práce zabere. Rozhodne Richard.
- Nová věc patří tam, kde už žije stejná odpovědnost. Sdílené chování (UI, pravidla, spawn, efekty, audio, ukládání) jde do sdíleného modulu, ne do kopie pro jednu obrazovku, mapu nebo režim.
- Když kód a dokumentace nesouhlasí, platí kód a dokument oprav ve stejné změně.

### Pořádek v repu (23. 11. 2026)

Každé repo má stejnou kostru, aby se v něm kterýkoli agent vyznal za minutu a nikdo si nedělal vlastní místa:

- `AGENTS.md` je vstup, do ~250 řádků: co to je, **Teď** (aktuální fokus a co se nedělá), pravidla a zámky repa, rozložení kódu, spuštění a ověření (příkazy), mapa dokumentace. Nic podrobného.
- `CLAUDE.md` obsahuje jen `@AGENTS.md` (Claude i Codex čtou totéž).
- `TODO.md` je jen otevřená práce v pořadí důležitosti: **Teď** (fokus), **Později** (odložené směry), **Nápady**. Hotová položka dostane hash commitu a při nejbližším úklidu jde do `docs/historie/`. Chyby i funkce v jednom seznamu.
- `docs/<oblast>.md`: podrobnosti, jeden soubor na oblast (soubory, kontrakty, pasti, testy té oblasti). Nově zjištěná past nebo pravidlo jde do souboru své oblasti ve stejném commitu, nikdy na konec AGENTS.md.
- `docs/historie/`: archiv (hotové úkoly, staré audity, staré zadání). Při běžné práci se nečte.
- Deník a předávka: `C:\grimroot\context\<projekt>.md`. Nahoře oddíl **Stav** (5–10 řádků, kde projekt je a co je další, přepisuje se), pod ním záznamy sezení, novější dolů.
- V kořeni repa nezakládej další .md (NOTES, AUDIT, HANDOFF2…) ani zadání mimo repo. Dočasné skripty a výstupy patří do scratchpadu; co musí být v repu (dočasná Godot scéna), se jmenuje `_tmp_*` a smaže se v téže práci.

### Postup práce

- **Začátek:** `git status` a `git log -5` (kdo tu ještě dělá), celý `AGENTS.md`, v `TODO.md` oddíl Teď, v deníku oddíl Stav a soubor `docs/` oblasti, na kterou sáhneš.
- **Fokus:** dělej to, co je v oddílu Teď, nebo co Richard právě zadal. Co je mimo, zapiš do TODO (Později, Nápady) a nedělej to. Odložené věci nerozbíjej.
- **Jedna věc, jeden commit:** kód, test a dokumentace té oblasti spolu. Zpráva říká, co bylo špatně a co je teď jinak.
- **Ověření:** spouštěč kontrol repa (příkaz je v AGENTS.md) a test nebo snímek přesně ve stavu, o kterém byla řeč. Co ověřit nejde (poslech, telefon, dva lidé), napiš jako neověřené.
- **Konec:** odškrtni v TODO, přepiš Stav v deníku a přidej záznam, Richardovi napiš, co je hotové, jak ověřené, co ne a další kroky.
- Dokumentace, která lže nebo bobtná, se opravuje hned, jako součást práce.

### Kontext a komunikace

- Hlavní pravidla jsou v `C:\grimroot\context\context.md` (kapitoly 02–05 a kapitola projektu), deník projektu v `C:\grimroot\context\<projekt>.md`.
- S Richardem česky, krátce, bez žargonu. Na nic, co umíš rozhodnout sám, se neptej; ptej se jen na produktová rozhodnutí.

### Souběžná práce a git

- Na repu můžou zároveň pracovat jiné sessions, Codex a kolegové (Matěj, Josefína). Cizí rozpracované změny nech být, necommituj je a nepřepisuj cizí soubory.
- Commituj průběžně, jen vlastní soubory přes explicitní cesty (ve sdílené pracovní kopii přes vlastní index, `context.md` 02). Identita: hry a undohub `Richard Remes <remes.richard@gmail.com>`, undocollective `Ricky Grimroot <rickygrimroot@icloud.com>`, pokud repo níž neříká jinak.
- Push do `main` u projektů na Vercelu spouští placený deploy: jen na Richardův pokyn a jednou na konci dávky; vyvíjí se ve větvi `dev` (`vercel.json` → `git.deploymentEnabled.dev: false`), náhledy se ručně nevyrábí. Hry bez Vercelu (Godot, Unity) pushují ověřené dávky rovnou do `main`. Další vedlejší větve nezakládej.
- Tajemství jen v `.env*` (gitignored), nikdy v repu, v commitu ani ve výpisu.

### Hry

- Hra je hra, ne webovka: menu nescrolluje (taby, stránky, swipe), žádné vysvětlující texty ani nápovědy; mechaniku vysvětluje obrázkový návod o 2–4 krocích. Herní funkce mají vidět jméno a stav.
- Platformu určuje AGENTS.md repa. Hry na UNDO.games jsou primárně pro mobil (kontroluj 390×844, 360×640, 844×390 a desktop, ovládání na palce, žádné webové artefakty). Hry na PC (launcher, Steam) kontroluj v 1280×720 a 1920×1080. Nic nesmí přetéct ani se useknout.
- Nic nesmí škubnout: všechno přednačíst a předkompilovat (shadery, modely, zvuky), loading se pořád hýbe. V klidu nic neanimuje.
- Každý povrch otexturovaný (Grok), žádný finální art kreslený kódem. Zvuky z ElevenLabs, nikdy syntetizované v kódu; herní a normalizované, hudba vyvážená proti efektům.
- U her na UNDO.games: zvuk jen přes undobar (samostatná hlasitost hudby a efektů, hraje i bez focusu okna), po každé změně audia to ověř. Standard hry je ve skillu `undo-hra` a v `undogames/AGENTS.md`.

### Ověření a provoz

- „Hotovo“ jen po ověření ve stejném stavu, jaký byl popsaný (zařízení, režim, co-op, den/noc), stejným testem nebo snímkem.
- Testy běží bez zvuku (prohlížeč muted, Godot `--audio-driver Dummy`), nikdy nesahají na skutečné savy ani produkční účty a nikdy na Richardovu myš: bez obrázku headless, okenní běhy na skryté ploše Windows (vzor `cursedcampsimulatormanager98/tools/hidden_desktop.py`).
- Testovací servery: zapínej jen server toho, na čem děláš (`C:\grimroot\_servers\<hra>.cmd`, viditelné okno). Běžící servery ani cizí procesy nevypínej, ukončuj jen vlastní PID.
<!-- END:grimroot-common -->

## Teď

Richard, 23. 11. 2026: the main focus is the **singleplayer sandbox and co-op, to 100 %**.
The story camp, the pad (Steam Deck) and the split screen wait until then: keep them working,
give them no new work. What 100 % means and the open work, in order: [TODO.md](TODO.md) „Teď“.

## 1. Ground rules

| Rule | Why |
| --- | --- |
| Mutate state through `CoreRoot.actions`, never `CoreRoot.state.x = y` from outside `core/` | Single write path; `EventBus` notifications are emitted there |
| `EventBus` is the only cross-module signal hub | Modules listen, core emits |
| Systems in `core/systems/` stay pure | No `get_node`, no `SceneTree`; data in, numbers out. Rules modules (`maintenance_rules.gd`, `weather_system.gd`) are static/pure too |
| UI is a read-only view | UI forwards intent; it does not compute costs or odds |
| Every feature works for two to four wardens | The host simulates, the others send intents (`docs/coop.md`); a feature without its co-op path is not done |
| The game ships in **English and Czech** | The code's strings are English, the Czech is in `godot/locale/cs.po` ([docs/i18n.md](docs/i18n.md)); every new player-facing string gets its Czech in the same change |
| An instance's services, never the autoload's name | `INSTANCE.core(self)`, `INSTANCE.coop(self)`, `INSTANCE.main_of(self)`... (`docs/coop.md`, the split screen) |
| Refactor strangler-style | New module → route through it → delete the legacy block; one concern per change, verify between |
| Tabs, not spaces; the files keep their line endings (most are CRLF) | Edits that rewrite a whole file change every line |
| `config/name` stays `"icloud ccs2"` | It names the `user://` folder holding players' saves; the title is set at runtime (`main.WINDOW_TITLE`) |
| Push `main` to both remotes, `origin` (GitLab) and `github` | No Vercel: a push costs nothing; push verified batches |
| Commit through a private index (the working copy is shared) | `context/context.md` 02: `GIT_INDEX_FILE=<tmp> git read-tree HEAD`, your blobs only, `commit-tree`, `update-ref` |

### Design lock — do not "improve" these without being asked

- The look is a **mid-90s Build-engine game**: pixel fonts on an integer scale, palette,
  bevelled square plates, no rounded corners, no glossy gradients, no app-store polish.
- The tone is **serious, with rare uncanny details** (DESIGN.md §2). No jumpscare spam, no
  words at night (sounds, eyes, effects instead).
- Every night threat is forecast before it is encountered and has a readable counter.
- `UTILITY_REPAIRS_ENABLED = false` stays off (repairs go through upkeep, hold R).
- A PC game (1280x720 and 1920x1080, mouse and keyboard; the pad later). Never a phone.

## 2. Layout

```
godot/
  core/                       # canonical simulation, no scene dependencies
    balance/balance_config.gd
    data/                     # BuildingDef + BuildingRegistry (the ONLY building catalog)
    events/event_bus.gd
    state/                    # GameState, GridModel, GameActions, CoreRoot (autoload)
    systems/                  # pure: energy, infra, satisfaction, karma, time, weather,
                              # maintenance, failure, maintenance_rules, guest_needs, builder
  data/buildings/*.tres       # building definitions
  data/pools/                 # email + guest content
  scripts/
    main.gd                   # the game's flow (title, new camp, load, pause, game over) and
                              # one-line facades others call it by (~3.7k lines)
    main_debug.gd             # main.gd + the debug_* hooks the tools call (the scene runs it);
                              # new hooks go here
    camp/ save/ night/ coop/ instance/ input/ demo/ debug/
    os98/                     # the office PC "Okna 98" at 640x480 (docs/pc.md)
    ui/ ui/title/             # HUD kit, menus, the title's office (docs/player.md)
    enemies/ pipes/           # the night's brains, the pipe crawl (docs/night.md)
    business/ pub/ bistro/ jednota/ corn/ bowling/   # the camp's places (docs/businesses.md)
    town/ geo/                # Lesna, Liblice, the bus, the land (geo/ is Matěj's)
  assets/                     # textures (Grok), sounds (ElevenLabs), fonts (baked: docs/art.md)
  tools/                      # in-engine harnesses and the screenshot driver (docs/testing.md)
tools/                        # repo tooling: checks.py, hidden_desktop.py, artgen/, audiogen/,
                              # geo/, i18n/, web/, refactor helpers
docs/                         # everything in detail, one file an area (below)
```

Autoloads (order matters): `SaveManager`, `GameSettings`, `EventBus`, `CoreRoot`,
`EmailManager`, `GuestManager`. Where each thing lives, area by area: [docs/map.md](docs/map.md).

## 3. Run and verify

Godot **4.7.1**: `C:\Users\arnold\Downloads\Godot_v4.7.1-stable_win64.exe\` (the
`_console.exe` for headless runs). The checks run muted and on their own APPDATA.

```bash
python tools/checks.py                      # every headless check (smoke + ~40 harnesses): CHECKS: PASS
python tools/checks.py --only lang_check    # one or a few
python tools/hidden_desktop.py --log LOG -- <godot> --path godot --resolution 1280x720 \
    res://tools/shot_driver.tscn -- --scenario=<name> --out=<dir>   # screenshots, never on the user's desktop
python godot/tools/coop_check.py OUT        # co-op for two (both copies on the hidden desktop)
```

Done means: `tools/checks.py` passes, the area's own check passes, and anything visible was
seen in a screenshot of the state it was described in (day or night, inside or out, alone or
for two). Every harness, scenario and co-op test: [docs/testing.md](docs/testing.md).

## 4. The docs

| File | Read it when |
| --- | --- |
| [TODO.md](TODO.md) | always: the open work, „Teď“ first |
| [docs/map.md](docs/map.md) | before touching an area: its files |
| [docs/DESIGN.md](docs/DESIGN.md) | the game's intent and rules, by section (§5 the night, §8 the pipes, §12 co-op...) |
| [docs/PRODUCT.md](docs/PRODUCT.md) | what exists and how finished it is |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | the wiring: autoloads, core, signals, saves |
| [docs/testing.md](docs/testing.md) | running anything: harnesses, the shot driver, co-op runners |
| [docs/godot.md](docs/godot.md) | engine and renderer traps (read once, they cost days) |
| [docs/player.md](docs/player.md) | the body, the eye, input, the HUD, the cursor, the hands |
| [docs/rooms.md](docs/rooms.md) | interiors, the one-world rooms, doors and windows |
| [docs/world.md](docs/world.md) | guests, weather, trees, the map, the villages, the lake |
| [docs/pc.md](docs/pc.md) | the office PC: Okna 98, Builder 98 |
| [docs/businesses.md](docs/businesses.md) | the pub, the bistro, the Jednota, the corn stand |
| [docs/night.md](docs/night.md) | the enemies and the director |
| [docs/coop.md](docs/coop.md) | co-op for two to four, the split screen's instances |
| [docs/audio.md](docs/audio.md) | buses, the mixer, 3D sound |
| [docs/art.md](docs/art.md) | Grok, the figures, fonts, sound generation |
| [docs/i18n.md](docs/i18n.md) | the Czech |
| [docs/web-demo.md](docs/web-demo.md) | the web export (put aside) |
| [docs/historie/](docs/historie/) | the old TODO with every done item, the October audit, the February changelog |
| `C:\grimroot\context\summercamp.md` | the diary: „Stav“ at the top, then every session's entry |

A trap you hit or a rule you learn goes into its area's file in `docs/`, in the commit that
needed it. AGENTS.md stays short: what every agent needs before the first command.

Older code comments cite this file's old sections: §3 is now `docs/testing.md`, §4
`docs/map.md`, §5 the area files, §7 `docs/art.md`, §8 `docs/i18n.md`.
