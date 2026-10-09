# ARCHITECTURE.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-08. Engine: Godot 4.7.1.*

Technical wiring. For rules of engagement see [AGENTS.md](AGENTS.md); for intent see
[DESIGN.md](DESIGN.md).

---

## 1. Layers

```
┌──────────────────────────────────────────────────────────────┐
│ 6  View / UI      os98 shell, interiors, hud_manager,      │
│                   ui/ (menus, pause, game over, boot)        │
├──────────────────────────────────────────────────────────────┤
│ 5  Orchestration  main.gd + extracted modules: blood_fx,     │
│                   electricity_billing, menu_flythrough,      │
│                   maintenance_controller, save_codec,        │
│                   enemies/* (one brain per night threat)     │
├──────────────────────────────────────────────────────────────┤
│ 4  Runtime mgrs   Guest (+life, agents), Email, Economy,     │
│                   Audio, Building, Quest                     │
├──────────────────────────────────────────────────────────────┤
│ 3  Signal bus     EventBus                                   │
├──────────────────────────────────────────────────────────────┤
│ 2  State/actions  CoreRoot → GameState + GameActions + Grid  │
├──────────────────────────────────────────────────────────────┤
│ 1  Pure systems   Energy, Infra, Satisfaction, Karma, Time,  │
│                   Weather, Maintenance, Failure, Builder,    │
│                   GuestNeeds, MaintenanceRules               │
├──────────────────────────────────────────────────────────────┤
│ 0  Data           BuildingRegistry ← data/buildings/*.tres   │
└──────────────────────────────────────────────────────────────┘
```

Dependency direction is strictly downward. Layer 1 knows nothing above it — the pure
systems take a `GridModel` and a `BuildingRegistry` and return numbers.

---

## 2. State ownership

`CoreRoot` (autoload) owns everything persistent:

```gdscript
CoreRoot.state       # GameState (Resource) — the single source of truth
CoreRoot.actions     # GameActions — the only sanctioned write path
CoreRoot.registry    # BuildingRegistry — building definitions
```

### `GameState` fields

| Field | Scale | Notes |
| --- | --- | --- |
| `money` | int | starts at 850 |
| `day` | int | starts at 1 |
| `is_night` | bool | driven by `TimeSystem` |
| `karma` | float | −100 … +100 |
| `satisfaction` | float | **0 … 100** (default 50) |
| `hrotfaktor` | float | 0 … 1 — camp weirdness pressure |
| `energy_load` | float | 0 … 1 (draw / capacity) |
| `infra_load` | float | absolute sum, not normalised |
| `grid` | GridModel | cells, tile types, visual occupants |
| `failures` | Dictionary | `"x:y"` → failure data |
| `guests`, `accommodation_states`, `guest_reviews`, `guest_transactions` | | guest runtime |

> `satisfaction` is 0–100 and `energy_load` is 0–1. These differ deliberately. Mixing
> them up is exactly the bug that pinned every guest review to 1 star for months.

### `GridModel`

Canonical grid. Three parallel maps keyed by `Vector2i`:

| Map | Persisted | Contents |
| --- | --- | --- |
| `cells` | ✅ | `{type, id, root_coord, maintenance}` — the building layer |
| `tile_types` | ✅ | `LAKE` / `RESERVED` overrides; `GRASS` = absent key |
| `occupants` | ❌ | `Node3D` refs — runtime visual layer only |

Multi-tile footprints write every covered cell with the same instance `id` and a shared
`root_coord`. There is **no reverse index** from instance id to cells, so removal sweeps
the whole grid. Fine at 20×20; add an index if the map grows.

`GridManager` (`scripts/grid_manager.gd`) is a thin compatibility facade over `GridModel`
with no state of its own.

---

## 3. EventBus contract

The only cross-module signal hub. **Core emits, modules listen.**

| Signal | Emitted by | Payload |
| --- | --- | --- |
| `state_changed` | `CoreRoot.apply_changes` | changed keys only |
| `money_changed` | `GameActions` | new amount |
| `building_placed` / `building_removed` | `GameActions` | id, origin, footprint, rotation |
| `RequestBuild` / `RequestDemolish` / `RequestRotate` | UI | builder intent |
| `BuildConfirmed` / `BuildRejected` | `BuilderAuthority` | outcome + reason |
| `DemolishConfirmed` / `DemolishRejected` | `BuilderAuthority` | area, counts, fees |
| `day_tick` / `time_tick` / `night_tick` / `day_advanced` | `TimeSystem` | |
| `email_received` | `EmailManager` | mail dict |
| `customer_booking_confirmed` / `customer_booking_rejected` | `EmailManager` | mail dict |
| `guest_created` / `guest_state_changed` | `GuestManager` | |
| `accommodation_state_changed` / `guest_review_posted` / `guest_payment_received` | `GuestManager` | |
| `file_downloaded` / `program_installed` | Beeternet / install wizard | |
| `building_failed` | `FailureSystem` | coord, type |
| `building_serviced` | `GameActions.service_building` | coord, type, was_broken, cost |

---

## 4. Canonical data flows

### Building placement

```
Builder UI
  → EventBus.RequestBuild
  → BuilderAuthority (validates funds, bounds, occupancy)
  → CoreRoot.actions.place_building()
  → GridModel.occupy_cell() ×footprint
  → EventBus.building_placed + money_changed
  → LegacyUIAdapter → BuildingManager (spawns the 3D structure)
  → CoreRoot.recalculate_systems() → energy/infra/satisfaction → EventBus.state_changed
```

### Time and weather

```
main._process
  → TimeSystem.process(delta) → EventBus.time_tick / day_tick / night_tick
  → WeatherSystem.process(delta, hour)    [designed cycle; anomaly pressure = hrotfaktor]
  → main._sync_runtime_state_from_systems()
  → WeatherVisuals.apply(...) + AudioManager.refresh_ambient_audio(...)
```

### Email → guest

```
EventBus.time_tick
  → EmailManager delivers pool mail matching day+time, plus generated customer/spam
     mail scaled by hrotfaktor × bed metrics
  → EventBus.email_received
  → os_shell: tray envelope blinks + mail sfx; CampMail refreshes

Player presses CONFIRM
  → EmailManager.confirm_customer_booking()
  → EventBus.customer_booking_confirmed
  → GuestManager checks the group in immediately, reserves beds, starts the stay
```

### Night

```
TimeSystem crosses NIGHT_START_HOUR → EventBus.night_tick
  → main._roll_liminal_night_spawn_snapshot()   [per-archetype odds from GuestManager]
  → main._activate_runtime_enemy_for_night()
       for each archetype that spawned: ENEMY_FOR_ARCHETYPE → brain.start_night()
       two or more kinds → also StalkerBrain
  → brains ticked from main._process (enemy_base: refs, body, sounds, view/light tests)
  → on day phase: _stop_active_enemy_brain(), flashlight recharged
```

### Upkeep

```
day_tick → MaintenanceSystem decays cell "maintenance" by BuildingDef.maintenance_decay
FailureSystem (enabled in play), every game hour → MaintenanceRules.hazard_per_hour
  → GameState.failures + EventBus.building_failed → HUD feed, red sign, guests lose it
Player holds R at a building (MaintenanceController) → GameActions.service_building
  → condition 100%, failure cleared, money charged → EventBus.building_serviced
```

### Footsteps

```
PlayerController movement state
  + GridManager surface sampling (paths group / building_type == "path")
  → dual-loop grass/gravel equal-power crossfade
  → tempo and volume share the camera bobbing stride signal
```

---

## 5. The camp computer (`scripts/os98/`)

"Okna 98" on a Camptronics PC. `building_interior` renders `os_shell.gd` into a fixed
**640x480** SubViewport shown on the CRT quad (4:3); mouse events are raycast onto the
quad and pushed into the viewport, keys too (S turns round unless a text field has focus:
`os_shell.wants_keyboard()` / `_is_crt_text_input_focused()`).

```
os_shell.gd     boot (BIOS -> OEM splash -> desktop), desktop icons, windows, taskbar,
                Start menu, Run, message boxes, the UPS monitor, the drawn cursor,
                save state (installed programs, downloads, Recycle Bin), sfx
os_theme.gd     the Theme: bevelled StyleBoxTextures, W95FA bitmap font, colours
os_window.gd    one window: frame, title bar, caption buttons, drag; app goes in .content
os_files.gd     the disk: folders, Vera's text files, what each .EXE opens
web_pages.gd    the 1998 web: pages as BBCode with {target|text} links and {{tokens}}
apps/*_app.gd   one script per program, setup(shell, window, args) / reopen / refresh
```

The shell is the apps' service layer: `open_app`, `open_file`, `message_box`,
`start_download` / `finish_download`, `install_program`, `play`, `main_node()` (for
billing, upkeep and the clock), `icon()`.

Programs that are not there at the start come off the web:

```
Beeternet (dials the modem once) -> www.stavitel98.cz -> download://BLDR98SW.EXE
  -> download_app (modem speed) -> C:\DOWNLOAD -> EventBus.file_downloaded
  -> double-click -> setup_app (licence must be accepted) -> shell.install_program()
  -> EventBus.program_installed("builder") -> icon, Start menu, setup file to the bin
```

CampStat comes from www.campgrid.cz, GuestRack from www.okres-hlubocany.cz. Builder
refuses to start between 20:00 and 06:30 and closes at nightfall (`set_is_day`).
Harness: `tools/os98_check.tscn` (boots, opens every app and page, installs, saves).

---

## 6. Save system

- Version **3**, autosave every **60s** plus on window close
- `main._build_save_snapshot()` collects: state, grid cells, structures, CRT desktop
  layout, email runtime, guest runtime, electricity bills, player transform
- Each subsystem exposes `export_runtime_state()` / `import_runtime_state()`
- `_apply_save_snapshot(snapshot, preview_only)` is used for both real loads and the menu
  preview world; `preview_only` also selects whether weather auto-cycles (menu: yes,
  gameplay: no)
- `Vector2i` keys are serialised as `"x:y"` strings — see `_coord_from_key_string()`

---

## 7. Known structural debt

| Item | Impact |
| --- | --- |
| `main.gd` ≈ 3k lines | Menu, billing, blood, flythrough and save helpers are out; liminal debug window, save snapshot build/apply and night orchestration remain |
| `BuildingManager` is not a pure view over `GridModel` | Holds its own structure state |
| `GameActions.end_day()` | Legacy, bypasses `day_tick` |
| Redneck Rampage texture rips | Licensing blocker for any public build (AGENTS.md §7) |

See [AUDIT.md](AUDIT.md) for history and [TODO.md](TODO.md) for priorities.
