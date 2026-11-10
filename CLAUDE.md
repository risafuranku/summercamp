# CLAUDE.md

See **[AGENTS.md](AGENTS.md)** — it is the operating manual for this repository
(ground rules, project layout, how to run and verify, and the gotchas that cost time).

Quick orientation:

- Godot project root is `godot/`. Engine: **Godot 4.7.1**.
- Smoke test before declaring anything done (grep for SCRIPT ERROR):
  `godot --headless --path godot --quit-after 400`
- Gameplay changes must also be seen: run the screenshot driver scenarios.
- State is mutated only through `CoreRoot.actions`. `EventBus` is the only cross-module
  signal hub. Systems in `core/systems/` stay pure.
- Buildings live only in `data/buildings/*.tres` (BuildingRegistry).
- Harnesses in `godot/tools/` and the screenshot driver: see AGENTS.md §3.
- The game ships in **English and Czech**: code strings in English, their Czech in
  `godot/locale/cs.po`; every new player-facing string gets its Czech in the same change
  (AGENTS.md §8: drawn text needs `tr()`, `tools/i18n/extract.py`, `fill.py`, `lang_check`).

Then: [PRODUCT.md](PRODUCT.md) for feature status, [DESIGN.md](DESIGN.md) for intent,
[ARCHITECTURE.md](ARCHITECTURE.md) for wiring, [TODO.md](TODO.md) for priorities.

<!-- BEGIN:grimroot-common -->
## Společná pravidla grimroot

Platí v každém repu v `C:\grimroot` pro každého agenta (Claude, Codex) i člověka. Pravidla repa níž je upřesňují, neruší. Tenhle oddíl se needituje v repu: zdroj je `C:\grimroot\context\agents-common.md`, do všech AGENTS.md ho rozkopíruje `node C:\grimroot\context\sync-agents.mjs`.

### Architektura (10. 11. 2026, nejvyšší priorita)

- Stav kód čistě, modulárně, se správnou architekturou a oddělenými odpovědnostmi. Funkci nikdy jen nepřilepuj k tomu, co je po ruce, jen proto, že o ni Richard požádal.
- Když ji nejde postavit přirozeně do stávající struktury a doporučil bys refaktor, aby celek zůstal čistý, **zastav se předem, ještě než začneš lepit, a řekni to**: co brání, jaký refaktor navrhuješ a kolik práce zabere. Rozhodne Richard.
- Nová věc patří tam, kde už žije stejná odpovědnost. Sdílené chování (UI, pravidla, spawn, efekty, audio, ukládání) jde do sdíleného modulu, ne do kopie pro jednu obrazovku, mapu nebo režim.
- Když kód a dokumentace nesouhlasí, platí kód a dokument oprav ve stejné změně. Změněný systém = aktualizovaný AGENTS.md (nebo wiki repa) v témže commitu.

### Kontext a komunikace

- Hlavní poznámky jsou v `C:\grimroot\context\context.md` (kapitoly 02–05 a kapitola projektu), deník a handoff projektu v `C:\grimroot\context\<projekt>.md` nebo v `HANDOFF.md` repa. Úkoly jsou v jednom `TODO.md` / `todo.md` repa (chyby i funkce dohromady).
- S Richardem česky, krátce, bez žargonu. Na nic, co umíš rozhodnout sám, se neptej; ptej se jen na produktová rozhodnutí.

### Souběžná práce a git

- Na repu můžou zároveň pracovat jiné sessions, Codex a kolegové (Matěj, Josefína). Před prací `git status`; cizí rozpracované změny nech být, necommituj je a nepřepisuj cizí soubory.
- Commituj průběžně lokálně, jen vlastní soubory přes explicitní cesty. Identita: hry a undohub `Richard Remes <remes.richard@gmail.com>`, undocollective `Ricky Grimroot <rickygrimroot@icloud.com>`, pokud repo níž neříká jinak.
- Push do `main` spouští placený deploy: jen na Richardův pokyn a jednou na konci celé dávky. Kde se vyvíjí ve větvi `dev`, push do `dev` nic nenasazuje (`vercel.json` → `git.deploymentEnabled.dev: false`) a náhledy se ručně nevyrábí. Další vedlejší větve nezakládej.
- Tajemství jen v `.env*` (gitignored), nikdy v repu, v commitu ani ve výpisu.

### Hry

- Hra je hra, ne webovka: menu nescrolluje (taby, stránky, swipe), žádné vysvětlující texty ani nápovědy; mechaniku vysvětluje obrázkový návod o 2–4 krocích. Herní funkce mají vidět jméno a stav.
- Primární je mobil: kontroluj 390×844, 360×640, 844×390 a desktop. Ovládání na palce, žádné webové artefakty (zoom, výběr textu, zaseknuté tlačítko), nic nesmí přetéct ani se useknout.
- Nic nesmí škubnout: všechno přednačíst a předkompilovat (shadery, modely, zvuky), loading se pořád hýbe. V klidu nic neanimuje.
- Každý povrch otexturovaný (Grok), žádný finální art kreslený kódem. Zvuky herní a normalizované, hudba vyvážená proti efektům.
- U her na UNDO.games: zvuk jen přes undobar (samostatná hlasitost hudby a efektů, hraje i bez focusu okna), po každé změně audia to ověř. Standard hry je ve skillu `undo-hra` a v `undogames/AGENTS.md`.

### Ověření a provoz

- „Hotovo“ jen po ověření ve stejném stavu, jaký byl popsaný (zařízení, režim, co-op, den/noc), stejným testem nebo snímkem. Testy běží bez zvuku (prohlížeč muted, Godot `--audio-driver Dummy`) a nikdy nesahají na skutečné savy ani na produkční účty.
- Testovací servery: zapínej jen server toho, na čem děláš (`C:\grimroot\_servers\<hra>.cmd`, viditelné okno). Běžící servery ani cizí procesy nevypínej, ukončuj jen vlastní PID.
<!-- END:grimroot-common -->
