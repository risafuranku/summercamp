# ARCHITECTURE.md — Cursed Camp Manager Simulator

*Status snapshot: 2026-10-08. Engine: Godot 4.7.1.*

Technical wiring. For rules of engagement see [AGENTS.md](AGENTS.md); for intent see
[DESIGN.md](DESIGN.md).

---

## 1. Layers

```
┌──────────────────────────────────────────────────────────────┐
│ 6  View / UI      crt_os_shell, interiors, hud_manager,      │
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
  → crt_os_shell: MAIL counter + desktop toast + notification sfx

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

## 5. The CRT desktop (`crt_os_shell.gd`)

Render order, bottom → top:

1. Wallpaper (`TextureRect`, full rect)
2. Wall tint + noise (two `ColorRect`, `MOUSE_FILTER_IGNORE`)
3. `_desktop_icons` (`Control`, full rect)
4. `DreamClutter` (`Control`, `MOUSE_FILTER_IGNORE`) — tile tinting only
5. `_window_layer` — application windows, `MOUSE_FILTER_STOP`
6. `_taskbar` (`Panel`, `PRESET_BOTTOM_WIDE`, height `DESKTOP_TASKBAR_HEIGHT = 24`)
7. `_start_menu` (`Panel`, above the taskbar, height 336)
8. `_top_status_bar` (`Panel`, `PRESET_TOP_WIDE`, height 22)

> **`_window_layer` must be `visible = false` when no window is open.** It uses
> `MOUSE_FILTER_STOP` and will otherwise swallow every click on the desktop.

### Top status bar

```
[CAMP-NODE-04 ::] | ←← scrolling ticker (clipped) ←← | DAY MODE | MAIL 01
```

`_top_bar_ticker_clip` is a `Control` with `clip_contents = true`; the marquee label is
its child so it can never escape the bar. Wrap condition: `position.x + size.x < 0`.

### Desktop icons — the drag/click gotcha

- **Press** → `gui_input` on the icon sets `_dragging_icon`, `_dragging_icon_callback`,
  `_icon_has_dragged = false`
- **Release (LMB up) → handled in `_input()`, NOT `gui_input`.** `move_to_front()` in the
  press handler disturbs Godot 4's GUI mouse-focus tracking and the `gui_input` release
  is unreliable. The click callback fires only if `not _icon_has_dragged`.
- **Motion** → `_input()`, 4px threshold, clamped between the top bar and the taskbar

### App unlock model

Apps are gated behind `DEFAULT_UNLOCK_STATE`. Locked apps must be downloaded from
Beeternet and installed:

```
Beeternet.meta_clicked("download://cbuilder")
  → EventBus.file_downloaded("_builder98_setup.exe")
  → crt_os_shell._add_to_downloads()
  → run from Downloads → _open_install_wizard("builder")
  → EventBus.program_installed("builder")
  → desktop icon + start menu entry appear
```

Unlocked by default: `campmail`, `beeternet`, `downloads`, `bin`.

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
| `crt_os_shell.gd` ≈ 5k lines | Every terminal app in one file. Next: split per app (Camp Status text builders are pure and go first) |
| `main.gd` ≈ 3k lines | Menu, billing, blood, flythrough and save helpers are out; liminal debug window, save snapshot build/apply and night orchestration remain |
| `BuildingManager` is not a pure view over `GridModel` | Holds its own structure state |
| `GameActions.end_day()` | Legacy, bypasses `day_tick` |
| Redneck Rampage texture rips | Licensing blocker for any public build (AGENTS.md §7) |

See [AUDIT.md](AUDIT.md) for history and [TODO.md](TODO.md) for priorities.
