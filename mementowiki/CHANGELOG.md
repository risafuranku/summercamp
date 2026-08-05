# CHANGELOG (historical) — Cursed Camp Simulator

> ⚠️ **Superseded.** This file was the agent onboarding document until 2026-08-05.
> It is kept only as a record of the February 2026 development sessions and is
> **out of date in places** — most notably it still describes the guest assignment /
> cleaning flow, which was removed from the code and whose UI was deleted in the
> 2026-08-05 cleanup pass.
>
> Current documentation lives at the repository root:
> [AGENTS.md](../AGENTS.md) · [PRODUCT.md](../PRODUCT.md) · [DESIGN.md](../DESIGN.md) ·
> [ARCHITECTURE.md](../ARCHITECTURE.md) · [AUDIT.md](../AUDIT.md) · [TODO.md](../TODO.md)

*Last updated as onboarding doc: 2026-02-23 (16:34 CET)*

## Projekt
- Engine: Godot 4.x
- Projekt root: `godot/` (`project.godot`)
- Styl: low-poly PSX/CRT, corporate-liminal horror, post-communist vibe
- Gameplay: build/manage kemp + first-person pohyb + interiéry + tlak času/počasí

## Changelog (2026-02-23, email core + guest ingest)
- Přidán `EmailManager` autoload (`scripts/email_manager.gd`): načítá JSON pooly z `data/pools/emails/{story,customers,spam}/`, doručuje maily podle `day`+`time` při `time_tick`.
- `EventBus` — přidány signály: `email_received`, `customer_booking_confirmed`, `customer_booking_rejected`.
- `crt_os_shell.gd` — `MAIL --` button v top baru je klikatelný, otevírá `CampMail`.
  - Fullscreen okno, 3 panely: Folders (Inbox/Spam) | List | Preview+Actions
  - Customer emaily: tlačítka CONFIRM [v] (zelené) + REJECT [x] (červené)
  - Confirm → `EmailManager.confirm_customer_booking()` → `EventBus.customer_booking_confirmed`
- Confirm booking vytváří hosty v `GuestManager` do stavu `omw` s příjezdem další den; reject email maže z inboxu.
- Pool obsahuje 7 dní placeholder komunikace (story/spam/customer), delivery pacing je nepravidelný.
- Desktop ikona `CampMail` přidána (potřebuje asset `res://assets/textury/crt/icons/email.png`, fallback na PC ikonu).

## Changelog (2026-02-23, CampMail UX + notif audio consistency)
- `crt_os_shell.gd`:
  - opravena top-right desktop oblast (šířky + clipping), indikátor je teď stabilně čitelný (`MAIL --` / `MAIL XX`),
  - incoming mail event (`EmailManager.email_received`) dělá 3 věci naráz: unread update, zvuk, desktop toast,
  - email list rework: `newest-first`, řádky sender+time+subject+snippet, selected highlight, lepší preview header,
  - folder counters ve stylu `INBOX 12*`, `SPAM 4`.
- `building_interior.gd`:
  - CRT setup teď předává `self` do desktop shellu (`_crt_ui.setup(..., self)`),
  - přidána metoda `get_radio_notification_volume_db()`; email ping používá stejný loudness/falloff rule set jako rádio (interiér/exteriér konzistentně).
- Smoke test:
  - headless run bez script parse/runtime errorů po změnách,
  - v logu pouze známý macOS cert warning + `ObjectDB instances leaked at exit`.

## Changelog (2026-02-23, audio hotfix)
- Fix parse regrese v `scripts/audio_manager.gd`: odstraněna mrtvá funkce `_are_main_crickets_active()` odkazující na neexistující `CRICKET_VARIANT_ACTIVE_THRESHOLD_DB`.
  Důvod: parse fail blokoval načtení audio manageru a sekundárně weather/door audio větví.
- Radio mix tuning v `scripts/building_interior.gd`:
  - interiér ztišen (`RADIO_INTERIOR_VOLUME_DB -24 -> -28`),
  - venkovní near zóna zesílena (`RADIO_OUTSIDE_NEAR_VOLUME_DB -14 -> -10.5`) a mírně rozšířena (`NEAR 1.0 -> 1.35`, `FAR 2.8 -> 3.25`).
- Radio fallback robustnost v `scripts/building_interior.gd`:
  - distance resolver už nevrací `INF` (fallback na hodnotu za `RADIO_OUTSIDE_FAR_DISTANCE`),
  - robustnější lookup listeneru (`Player` + name fragment `player`) a hlavní budovy (`mainbuilding*`, `main_building*`).
- Radio playlist maintenance:
  - `_setup_radio()` teď bere playlist přímo z celé složky `res://assets/sfx/radio` (bez hardcoded seznamu).
  - Runtime smoke check: `Radio: loaded 9 tracks` (včetně nově přidaných souborů).

## Changelog (2026-02-23, builder icon + demolish hotfix)
- Builder map icon refresh:
  - `scripts/crt_map_panel.gd` přidáno `refresh_builder_icons()` a reload se volá při otevření Builder app (`scripts/crt_os_shell.gd`), aby se po update assetů načetly nové verze ikon.
- Tool placeholder ikonky:
  - v Builder tool rail jsou `path` a `demolish` dočasně přepnuté na emoji placeholdery (`🛣️`, `🚜`) místo souborových ikon.
- Bagr/demolish oprava:
  - demolice se nyní vykoná hned na release myši (click i drag), nevyžaduje druhý potvrzovací klik.
  - v `core/state/actions.gd` opraveno čtení dictionary polí při `remove_building()` (instance id lookup), což blokovalo odstranění ve vybraných případech.

## Changelog (2026-02-23, footstep engine refactor)
- `scripts/player_controller.gd`:
  - odstraněn one-shot footstep model (`walktrava*` trigger na sinus crossing),
  - nahrazeno 2 kontinuálními loopy: `grassfootsteps.mp3` + `gravelfootsteps.mp3`.
- Povrchové přepínání:
  - equal-power crossfade `grass <-> gravel` (bez skoku hlasitosti),
  - blend je smooth přes více vzorků pod hráčem (`FOOTSTEP_SURFACE_SAMPLE_OFFSETS`),
  - gravel detekce jede přes grid occupancy (`paths` group / `building_type == "path"`).
- Synchronizace pohyb ↔ zvuk ↔ kamera:
  - tempo + hlasitost loopů jsou řízené stejným motion/stride signálem jako camera bobbing,
  - při zrychlení loopy zrychlí/zesílí, při dojezdu zpomalí/ztiší se,
  - step kick v bobbingu je pořád svázaný s krokovou vlnou (crossing `sin(_bob_time)`).
- Anti-artefakt tuning (stop ze sprintu):
  - pitch modulace výrazně zúžena (`0.985 -> 1.03`),
  - přidaná deadzone pro low-speed (`footstep_pitch_deadzone = 0.16`),
  - rychlejší návrat pitch na neutrální `1.0` (`footstep_pitch_return_speed = 14.0`) kvůli odstranění slyšitelného "vžuuum".
- `scripts/main.gd`:
  - při spawnu hráče se injectuje `grid_manager` do playeru (`set_grid_manager`) pro runtime surface sampling.

## Design Lock (neměnit bez explicitního zadání)
- Žádný moderní clean UI polish (kulaté rohy, glossy, modern app look)
- UI musí být hranaté, utilitární, "corporate terminal"
- Horor přes prázdno, nesoulad systému a anomálie, ne přes jumpscare spam
- Grid logika a čitelnost simulace mají prioritu
- Celá hra je anglicky (překlady z češtiny průběžně dokončovat)

## Aktuální technický snapshot
- `scripts/main.gd`: ~3230 ř. (z 3666)
- Hotovo: extrakce `loading_screen.gd`, `hud_manager.gd`
- Další krok: `weather_visuals.gd`; potom `interior_manager.gd`
- Time thresholds: day `06:00`, evening `17:00`, night `20:00`
- Weather enum: `CLEAR=0`, `WINDY=1`, `FOG=2`, `LIGHT_RAIN=3`, `RAIN=4`, `STORM=5`, `EVENT=6`
- Audio guard: stream source >8MB se při fallback loadu přeskočí (záměrně)
- Office radio mix (building interior): tuned for quieter interior + audible-near-wall outside
  (`RADIO_INTERIOR_VOLUME_DB=-28`, `RADIO_OUTSIDE_NEAR_VOLUME_DB=-10.5`,
  `RADIO_OUTSIDE_NEAR_DISTANCE=1.35`, `RADIO_OUTSIDE_FAR_DISTANCE=3.25`,
  `RADIO_OUTSIDE_SILENT_DB=-58`, eased `pow(t, 1.6)` falloff + finite distance fallback).
- Sky timing update:
  night sky transition starts `19:30` (`NIGHT_SKY_FADE_START_HOUR=19.5`) and still ends `21:15` (`21.25`),
  stars now fade in from `20:30` (`STAR_FADE_IN_START_HOUR=20.5`).
  Sun shadow toggle is now gated by day/night fade window to avoid dusk flicker around ~`18:45`.
  Fixed `17:45` brightness pop: removed duplicate pre-evening blend segment that reset profile at transition boundary.
  Night post-darkening is now blended continuously (no hard threshold at `21:15`/`06:45`), and dusk->night
  skybox transition duration is aligned to the long night ramp (`105s` at `TIME_SCALE=1`).
  Time profile is now applied each frame (`update_frame`) to remove minute-step color/light jumps.
- Ambient wildlife audio tweak:
  `rrbird` daytime cadence increased (`20-42s`) and night cricket variants (`rrcvrk`, `rrcricket`) now
  gate directly by night window (not by main-loop volume threshold), with louder/closer spatial settings.
- Door SFX reliability:
  door open/close now use resilient one-shot playback (lazy stream restore + forced restart), and base
  door SFX level was raised from `-3dB` to `-1dB` for audibility in dense ambience mix.
- Footstep loop system:
  dual-loop footsteps (`grass/gravel`) with surface-aware crossfade and shared movement cadence signal
  (audio + bobbing stay locked together).
- Guest flow data loop (playable skeleton):
  - `omw -> book -> active/sleep -> leave` běží na `GuestManager` časových tikech,
  - recepční assign + cleaning je manuální přes notebook UI (auto-assign default OFF),
  - checkout nastaví accommodation na `dirty`, připíše payout a review.

## CRT desktop snapshot (crt_os_shell.gd)
- Top status bar: `_top_status_bar` Panel 22px, PRESET_TOP_WIDE
  - ticker uvnitř `_top_bar_ticker_clip` (clip_contents=true) — nefloatuje přes UI
  - `_day_status_label` je child top baru, ne taskbaru
- Desktop ikony: bez rámečku, Win95 bare style, draggable (threshold 4px)
- DreamClutter: obsahuje jen tile tinting, `_layout_desktop_clutter` je noop
- Start menu: 336px, skupiny [Programs], Log Out placeholder, anglické názvy
- START button: pixel-art sprite `res://assets/textury/crt/UI/start.png` (203×64px)
  - button: 76×DESKTOP_TASKBAR_HEIGHT px, position (2, 0) — vyplňuje celou výšku taskbaru, žádné mezery
  - hover: bílý overlay 10%, pressed: tmavý overlay 18%
  - fallback na programmatický styl, pokud sprite chybí
- Taskbar: výška `DESKTOP_TASKBAR_HEIGHT=24` (`offset_top = -DESKTOP_TASKBAR_HEIGHT`)
- Desktop ikony mají icon paths: builder, guestrack, campstat, finance, minesweeper (`res://assets/textury/crt/icons/*.png`)
- Nové konstanty: `DESKTOP_TOP_BAR_HEIGHT=22`, `DESKTOP_TOP_BAR_NODE_LABEL_W=148`, `DESKTOP_TOP_BAR_TRAY_W=238`, `DESKTOP_TOP_BAR_EMAIL_W=92`, `DESKTOP_TASKBAR_HEIGHT=24`

## Desktop icon drag/click — GOTCHA
- Press: `gui_input` na ikoně → nastaví `_dragging_icon`, `_dragging_icon_callback`, `_icon_has_dragged=false`
- **Release (LMB up): zpracováno v `_input()`, NE v `gui_input`** — `gui_input` release je nespolehlivý po `move_to_front()`
- Motion: `_input()` → pokud vzdálenost od press >4px → `_icon_has_dragged=true`, clamped na desktop area
- Drag state vars: `_dragging_icon`, `_dragging_icon_callback`, `_dragging_icon_offset`, `_icon_press_global_start`, `_icon_has_dragged`

## Pravidla implementace
- Mutace stavu dělej přes `CoreRoot.actions`, ne napřímo z UI
- `EventBus` je canonical signal hub
- Startup flow má záměrně interior + CRT start
- `UTILITY_REPAIRS_ENABLED = false` nech vypnuté, dokud není explicitní požadavek
- Refaktor dělej strangler stylem: přidat modul -> napojit -> odstranit legacy blok

## Start workflow
1. Otevři `mementowiki/TODO.md` (co je aktuálně priorita).
2. Otevři `mementowiki/ARCHITECTURE.md` (jak je to zapojené).
3. Pak řeš jen scope aktuální priority v `godot/scripts/`.
