# ARCHITECTURE.md — Summer Camp Incident Simulator 2

*Status snapshot: 2026-08-05. Engine: Godot 4.7.1.*

Technical wiring. For rules of engagement see [AGENTS.md](AGENTS.md); for intent see
[DESIGN.md](DESIGN.md).

---

## 1. Layers

```
┌──────────────────────────────────────────────────────────────┐
│ 6  View / UI      crt_os_shell, interiors, HUD, panels       │
├──────────────────────────────────────────────────────────────┤
│ 5  Orchestration  main.gd  (+ extracted managers)            │
├──────────────────────────────────────────────────────────────┤
│ 4  Runtime mgrs   Guest, Email, Economy, Audio, Building     │
├──────────────────────────────────────────────────────────────┤
│ 3  Signal bus     EventBus                                   │
├──────────────────────────────────────────────────────────────┤
│ 2  State/actions  CoreRoot → GameState + GameActions + Grid  │
├──────────────────────────────────────────────────────────────┤
│ 1  Pure systems   Energy, Infra, Satisfaction, Karma, Time,  │
│                   Weather, Maintenance, Failure, Builder     │
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
  → WeatherSystem.process(delta)          [auto_cycle is OFF during gameplay]
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
  → main._roll_liminal_night_spawn_snapshot()   [reads GuestManager forecast]
  → main._activate_runtime_enemy_for_night()
  → SilentManBrain.setup(...) — ticked from main._process
  → on day phase: main._despawn_all_runtime_enemies()
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
| **Two building catalogs** — `data/buildings/*.tres` (canonical) vs `EconomyManager.BUILDING_DATA` (legacy UI) | Must edit both. Debug-build drift guard added 2026-08-05 |
| `main.gd` ≈ 4.5k lines | Menu, save/load, blood FX, electricity, enemies, liminal forecast, debug windows all in one file |
| `crt_os_shell.gd` ≈ 4.8k lines | Every desktop app in one file |
| `BuildingManager` is not a pure view over `GridModel` | Holds its own structure state |
| `crt_map_panel.gd` reads `EconomyManager` directly | Should go through `CoreRoot`/`EventBus` |
| `GameActions.end_day()` | Legacy, bypasses `day_tick`; warns once on use |
| `WeatherSystem.auto_cycle_enabled` is false during gameplay | The weather subsystem never runs in a real session |

See [AUDIT.md](AUDIT.md) for the full finding list and [TODO.md](TODO.md) for priorities.
