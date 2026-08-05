# Architecture - Cursed Camp Simulator
*Poslední update: 2026-02-23 (16:34 CET)*

## Vrstvy systému
1. View/UI: `crt_os_shell.gd`, interiérové UI, HUD
2. Orchestrace: `scripts/main.gd`
3. Core systems (pure): `core/systems/*`
4. State/actions: `CoreRoot` + `GameActions` + `GameState` + `GridModel`
5. Data registry: `BuildingRegistry`
6. Signal bus: `EventBus`

## Autoloads
- `EventBus`: `state_changed`, `day_tick`, `time_tick`, `money_changed`, `building_placed/removed`, `weather_changed`, `email_received`, `customer_booking_confirmed`, `customer_booking_rejected`
- `CoreRoot`: `get_state()`, `get_money()`, `get_day()`, `actions`
- `BuildingRegistry`: building defs z `res://data/buildings/`
- `EmailManager`: `email_received`, `customer_booking_confirmed`, `customer_booking_rejected`, `unread_count_changed` — spravuje inbox, načítá pool z `data/pools/emails/`
- `GuestManager`: lifecycle hostů (`omw -> book -> active/sleep -> leave`), přiřazení ubytování, dirty/clean status, recenze + checkout payout

## Canonical data flow
- Čas/počasí:
  `TimeSystem + WeatherSystem -> main._sync_runtime_state_from_systems() -> apply visuals/audio -> EventBus.state_changed`
- Budovy:
  `UI -> CoreRoot.actions.place/remove_building -> GridModel mutace -> EventBus.building_* -> LegacyBuilderAdapter -> BuildingManager`
- Peníze:
  `CoreRoot.actions -> EventBus.money_changed -> HUD update`
- Grid runtime (merge krok 2):
  `GridManager` je kompatibilní fasáda bez vlastního `_tiles`; prostorová logika + `tile_types` + `occupants` žijí v `GridModel`.
- Footstep audio:
  `PlayerController movement state + GridManager surface sampling -> dual-loop (grass/gravel) mix + pitch/volume -> camera bobbing stride sync`

## Klíčové runtime systémy
- `TimeSystem`: drží `time_of_day_hours`, `time_state`, `day_index`
- `WeatherSystem`: drží `current_weather` a přechody počasí
- `AudioManager`: weather loops, thunder sync, interior rain logic, 8MB guard
- `PlayerController`: first-person movement + head bob + footstep loop engine (surface-aware crossfade)

## Aktuální refaktor main.gd
- Cíl: stáhnout `main.gd` na orchestrace-only vrstvu (~700 ř.)
- Hotovo: `loading_screen.gd`, `hud_manager.gd`
- Teď: `weather_visuals.gd` (sky/celestial/clouds/weather particles)
- Potom: `interior_manager.gd` (open/close interiérů, upgrade/guest flows)

## CRT Desktop — struktura (`crt_os_shell.gd`)

### Vizuální vrstvy (render order, bottom → top)
1. Wallpaper (`TextureRect`, full-rect)
2. Wall tint + noise (dva `ColorRect`, full-rect, MOUSE_FILTER_IGNORE)
3. `_desktop_icons` (Control, full-rect) — ikony plochy
4. `DreamClutter` (Control, full-rect, MOUSE_FILTER_IGNORE) — pouze tile tinting
5. `_window_layer` (aplikační okna, MOUSE_FILTER_STOP, visible pouze když je otevřené okno)
6. `_taskbar` (Panel, PRESET_BOTTOM_WIDE, výška 28px = `DESKTOP_TASKBAR_HEIGHT`)
7. `_start_menu` (Panel, nad taskbarem)
8. `TopStatusBar` (`_top_status_bar`, Panel, PRESET_TOP_WIDE, výška 22px)

### Top Status Bar
```
[CAMP-NODE-04 ::] | ←← scrolling ticker (clipped) ←← | DAY MODE | MAIL 01
```
- `_top_bar_ticker_clip`: Control s `clip_contents = true` — ticker nikdy nevyjede ven
- `_desktop_marquee_label` je child tickerClipu (ne DreamClutteru)
- `_desktop_marquee_right_bound` = šířka clip containeru (aktualizuje `_layout_desktop`)
- Wrap: `position.x + size.x < 0` → skoč na `right_bound`
- `_day_status_label` je child TopStatusBaru (ne taskbaru)

### Desktop ikony
- Žádný Panel/border rámeček — čistý Win95 bare style
- Container: `Control` (76×80), `TextureRect` 48×48, `Label` se shadow
- Press: `gui_input` → `_on_desktop_icon_input()` — nastaví drag state + callback
- **Release (LMB up): zpracováno v `_input()`, NE v `gui_input`**
  - Důvod: `move_to_front()` v press handleru může narušit Godot 4 GUI mouse-focus tracking
  - `_dragging_icon_callback.call()` pokud `not _icon_has_dragged`
- Drag threshold: 4px; motion v `_input()`, clamped na desktop area (mezi top bar a taskbar)
- Drag state vars: `_dragging_icon`, `_dragging_icon_callback`, `_dragging_icon_offset`, `_icon_press_global_start`, `_icon_has_dragged`

### START tlačítko
- Pixel-art sprite: `res://assets/textury/crt/UI/start.png` (203×64px, RGBA)
- Button: 76×`DESKTOP_TASKBAR_HEIGHT` px, position `(2, 0)` — vyplňuje celou výšku taskbaru, žádný gap nahoře/dole
- `expand_icon=true`, `icon_alignment=CENTER`, nulové StyleBox margins
- Hover: bílý StyleBoxFlat overlay `Color(1,1,1,0.10)`; Pressed: tmavý `Color(0,0,0,0.18)`
- Žádný shadow ColorRect — 3D raised efekt je bakeovaný přímo ve spritu
- Fallback na programmatický styl (warm sand + PC ikona) pokud sprite chybí
- `focus_mode = FOCUS_NONE`

### Start menu
- Výška 336px, sidebar "CAMP OS 95"
- Skupina `[Programs]`: Builder, GuestRack, Camp Status, Finance, Minesweeper
- Settings | Log Out (placeholder `_placeholder_logout`) | Shut Down
- `_make_start_item(text, callback, icon_path="")` — optional icon
- `_make_start_folder(label)` — folder header (HBoxContainer, non-interactive)

## Gotchas (důležité)
- Loading screen se po startu teardownuje: `_loading_*` reference pak mají být `null`
- Sky/weather profil musí vycházet z fresh time baseline (jinak tint drift)
- Směr deště je řízen počasím (`_rain_weather_wind`), ne pohybem hráče
- Interiérové nody jsou children `_world_3d`, ne rootu main
- `crt_map_panel.gd` má legacy fallback read na `EconomyManager` (tech debt)
- `_layout_desktop_clutter()` je nyní `pass` (noop) — vše je v `_layout_desktop()`
- `_window_layer` (MOUSE_FILTER_STOP): visible=true pouze pokud je aspoň 1 viditelné okno — jinak blokuje všechny kliky na plochu
- Footstep pitch modulace musí zůstat subtilní; velký rozsah nebo pomalý release vytváří slyšitelný stop artefakt ("vžuuum").

## Email systém — CampMail

### Pool struktura
```
data/pools/emails/
  story/      ← příběhové maily (automaticky doručeny, jen ke čtení)
  customers/  ← zákazníci (confirm ✔ / reject ✘ tlačítka)
  spam/       ← spam (složka Spam, žádné akce)
```

### JSON formát (jeden soubor = jeden mail)
```json
{
  "from":    "Novak Family <novakovi@seznam.cz>",
  "subject": "Camping spot - 4 persons",
  "body":    "Hello,\n\nWe'd like to book...",
  "day":     1,
  "time":    "08:30",
  "type":    "customer",
  "guests":  4,
  "nights":  2
}
```
- `type`: `"story"` | `"customer"` | `"spam"`
- `guests` a `nights` pouze pro customer (volitelné, zatím jen pro display)

### Datový tok
```
TimeSystem → EventBus.time_tick → EmailManager._on_time_tick()
  → inbox.append(mail) → EmailManager.email_received(mail)
  → crt_os_shell._email_update_unread_indicator()
  → MAIL counter + desktop toast + notif sfx

Hráč klikne MAIL / CampMail ikona → _open_email_app()
  → plnoobrazovkové okno, 3 panely: Folders | List | Preview
  → CONFIRM → EmailManager.confirm_customer_booking() → EventBus.customer_booking_confirmed → GuestManager vytvoří hosty
  → REJECT  → EmailManager.reject_customer_booking()  → EventBus.customer_booking_rejected + mail se smaže z inboxu
```

### Klíčové soubory
- `scripts/email_manager.gd` — autoload, pool load, deliver logic, signály
- `scripts/crt_os_shell.gd` — `_open_email_app()`, `_email_build_content()`, `_email_refresh_list()`, `_email_open_message()`, `_email_update_unread_indicator()`
- `core/events/event_bus.gd` — nové signály: `email_received`, `customer_booking_confirmed`, `customer_booking_rejected`
- `scripts/building_interior.gd` — `get_radio_notification_volume_db()` sdílí audio falloff pravidla s radiem

## Beeternet + Install systém

### Moduly
- `scripts/beeternet.gd` — standalone Panel, vlastní chrome, adresní lišta, content area, status bar
  - načítá stránkové moduly přes `preload`
  - při downloadu emituje `EventBus.file_downloaded(filename)`
  - signály: `close_requested`, `minimize_requested`
- `scripts/beeternet_pages/page_home.gd` — static func `render(ctx) -> {title, body}`
- `scripts/beeternet_pages/page_404.gd`  — static func `render(ctx) -> {title, body}`
- `scripts/install_wizard.gd` — standalone Panel, 4-krokový wizard s fake progress barem
  - při dokončení emituje `EventBus.program_installed(app_id)`
  - signály: `close_requested`

### Desktop shell (crt_os_shell.gd)
- `_open_beeternet_app()` — instantiuje `beeternet.gd`, vloží do `_window_layer`
- `_open_install_wizard(app_id)` — instantiuje `install_wizard.gd`
- `_on_program_installed(app_id)` — listener na EventBus, přidá desktop ikonu + start menu
- `_open_downloads_folder()`, `_open_bin_folder()` — desktop shell složky
- `_unlock_registry: Dictionary`, `_downloads_items: Array`, `_bin_items: Array`

### EventBus signály (nové)
- `file_downloaded(filename)` — Beeternet → desktop: přidej do Downloads
- `program_installed(app_id)` — Wizard → desktop: odemkni ikony

### Datový tok
```
Beeternet.meta_clicked("download://cbuilder")
  → _handle_download() → EventBus.file_downloaded("_cbuilder98_wizard.exe")
  → crt_os_shell._add_to_downloads()

Downloads._handle_downloads_run("_cbuilder98_wizard.exe")
  → _open_install_wizard("cbuilder")
  → install_wizard: progress → EventBus.program_installed("cbuilder")
  → crt_os_shell._on_program_installed() → desktop ikona + start menu
```

## Guest assignment / cleaning (manual reception loop)
- `GuestManager.auto_assignment_enabled = false` (default) — žádné auto-assign.
- `guest_assignment_notebook.gd` otevírá mapu kempu + čekající hosty.
- Notebook akce volají:
  - `GuestManager.request_assignment_by_key(guest_id, accommodation_key, actor)`
  - `GuestManager.request_cleaning_by_key(accommodation_key, actor)`
  - `GuestManager.request_clean_all_dirty(actor)`
- Staff automation hook je připraven:
  - `enqueue_staff_task({type:"assign_guest"| "clean_accommodation", ...})`
  - `process_staff_tasks(max_tasks, actor="staff")`
- Checkout flow:
  - host opustí ubytování, objekt přejde na `dirty`,
  - připíše se payout (`CoreRoot.actions.add_money`) + review (`guest_reviews`).

## Otevřený tech debt
- Dokončit extrakci `weather_visuals.gd` a `interior_manager.gd`
- Odstranit/deprecate legacy `GameActions.end_day()`
- Dotáhnout `crt_map_panel.gd` na čisté `CoreRoot/EventBus`
- Přetavit `BuildingManager` na čistý view renderer nad `GridModel`
- Minesweeper: zatím jen skeleton `_open_text_window`
- Guest flow phase 2: potřeby, RNG "mozek", service usage simulace, outdoor/indoor vizuální agenti, random+story eventy
