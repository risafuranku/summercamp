# AGENTS.md — operating manual for this repo

Onboarding for any agent or developer working on **Summer Camp Incident Simulator 2**.
Read this first, then [ARCHITECTURE.md](ARCHITECTURE.md) for wiring and [DESIGN.md](DESIGN.md)
for intent. [PRODUCT.md](PRODUCT.md) says what the game is and what state each feature is in.

> **When docs and code disagree, the code wins.** Fix the doc in the same change.

---

## 1. Ground rules

| Rule | Why |
| --- | --- |
| Mutate state through `CoreRoot.actions`, never `CoreRoot.state.x = y` from outside `core/` | Single write path; `EventBus` notifications are emitted there |
| `EventBus` is the only cross-module signal hub | Modules listen, core emits — no module→module wiring |
| Systems in `core/systems/` stay pure | No `get_node`, no `SceneTree`, no node refs. They take `GridModel` + `BuildingRegistry` and return numbers |
| UI is a read-only view | UI forwards intent to `Actions`; it does not compute costs, capacity or metrics |
| The game ships in **English** | Czech is fine in comments and commit messages, never in player-facing strings |
| Refactor strangler-style | Add the new module → route through it → delete the legacy block. Never big-bang |
| Tabs, not spaces | GDScript convention and the rest of the codebase |

### Design lock — do not "improve" these without being asked

- No modern/clean UI polish. No rounded corners, no glossy gradients, no app-store look.
  Everything is square, utilitarian, **corporate terminal**.
- Horror comes from emptiness, systems that don't quite agree, and anomaly — not jumpscare spam.
- Grid legibility and simulation readability beat visual flourish every time.
- `UTILITY_REPAIRS_ENABLED = false` stays off until explicitly requested.

---

## 2. Layout

```
godot/                        # the Godot project root (project.godot lives here)
  core/                       # ── canonical simulation layer, no scene dependencies
    balance/balance_config.gd #    all tuning constants
    data/                     #    BuildingDef resource + BuildingRegistry loader
    events/event_bus.gd       #    the signal hub (autoload)
    state/                    #    GameState, GridModel, GameActions, CoreRoot (autoload)
    systems/                  #    pure calculators: energy, infra, satisfaction, karma,
                              #    time, weather, maintenance, failure, builder authority
  data/
    buildings/*.tres          #    BuildingDef instances — the canonical building catalog
    pools/emails/{story,customers,spam}/   # email content pools
    pools/{guestprofiles,emailprofiles}/   # guest generation pools
    beeternet/pages/          #    in-game web pages
  modules/
    adapters/                 #    legacy UI adapter (bridges EventBus → BuildingManager)
    visual/                   #    post-process / enemy FX module
  scripts/                    # ── runtime layer: managers, UI, interiors, player
  scenes/main.tscn            #    the only scene; everything else is built in code
  materials/                  #    shaders (PSX post, grass, distortion, sky)
  assets/                     #    textures + audio
```

`scenes/main.tscn` is deliberately tiny (5 nodes). Almost the entire game is constructed
procedurally at runtime. If you're looking for a node, it's created in a `_build_*`,
`_setup_*` or `_create_*` function, not in the scene file.

### Autoloads (order matters — declared in `project.godot`)

| Autoload | File | Role |
| --- | --- | --- |
| `SaveManager` | `scripts/save_manager.gd` | slot enumeration, read/write |
| `GameSettings` | `scripts/game_settings.gd` | user settings persistence |
| `EventBus` | `core/events/event_bus.gd` | signal hub |
| `CoreRoot` | `core/state/core_root.gd` | owns `GameState`, `GameActions`, `BuildingRegistry` |
| `EmailManager` | `scripts/email_manager.gd` | inbox, pool delivery, booking confirm/reject |
| `GuestManager` | `scripts/guest_manager.gd` | guest lifecycle, beds, reviews, liminal forecast |

---

## 3. Running and verifying

Godot **4.7.1** is what this project is currently built and tested against
(`project.godot` still declares `4.6` features — harmless, but see [AUDIT.md](AUDIT.md)).

Headless smoke test — the cheapest way to catch parse errors and startup regressions:

```bash
godot --headless --path godot --quit-after 400
```

A healthy run prints exactly this and nothing else:

```
BuildingRegistry: Loaded 23 buildings.
Audio bus created: OutdoorAmbience (index=1)
Ambient OST loaded tracks: 8
Audio streams: open=true close=true crickets=true weather_loops=true thunder=true ambient_tracks=8 boot=true
```

Anything containing `SCRIPT ERROR`, `Parse Error`, or a `push_warning` about building
catalog drift is a regression. An occasional `ObjectDB instances were leaked at exit`
for `ambience3A.mp3` is a known benign audio-thread shutdown race — see [AUDIT.md](AUDIT.md).

### Godot MCP — run the real game and read its output

`.mcp.json` registers the [godot-mcp](https://github.com/Coding-Solo/godot-mcp) server,
so `mcp__godot__*` tools (`run_project`, `get_debug_output`, `stop_project`,
`get_project_info`, `launch_editor`, …) are available **after a Claude Code restart**.

This matters: `--headless` suppresses GDScript parse warnings and never exercises
rendering. A real windowed run surfaces both. Baseline is **22 warnings, 0 errors** —
any new diagnostic in a file you touched is yours.

For a session that started before the server was registered, or for scripting, drive the
same server over stdio. Tools that hold state across calls (`run_project` →
`get_debug_output`) need `--seq` so they share one server session:

```bash
node tools/godot_mcp_call.mjs --seq 'run_project {"projectPath":"godot"}' sleep:20000 get_debug_output stop_project
```

### Checks

There is **no general test suite.** Two harnesses exist; add more in `godot/tools/`:

```bash
godot --headless --path godot res://tools/hud_layout_check.tscn
```

Asserts the world HUD's module geometry at 1280/1600/1920 — widths fit, the tallest
module clears the bar's inner height, and every caption and readout actually renders.
It caught a 17px vertical overflow that headless startup did not.

> Run tool scenes as **scenes**, not with `--script`. `--script` does not register
> autoloads, so anything referencing `CoreRoot`/`EmailManager`/`GuestManager` fails to
> compile and the harness reports a false pass.

Everything else still needs a real playthrough.

### Useful debug keys (gameplay only, blocked while any interior UI is open)

| Key action | Effect |
| --- | --- |
| `toggle_day_night` | advance time by 1 hour |
| `toggle_weather` | cycle to next weather state |
| `interact` | interaction raycast |

Input actions are registered at runtime in `main._ensure_input_actions()`, not in the
project's input map.

---

## 4. Where things live — a lookup table

| I want to change… | Go to |
| --- | --- |
| Building cost / capacity / power | `data/buildings/<id>.tres` **and** `EconomyManager.BUILDING_DATA` (see warning below) |
| Any tuning constant | `core/balance/balance_config.gd` |
| Time of day thresholds | `core/systems/time_system.gd` |
| The CRT desktop, its apps, windows, taskbar | `scripts/crt_os_shell.gd` |
| Main menu, save/load, blood FX, electricity billing, night enemy orchestration | `scripts/main.gd` |
| Reception office interior (the CRT room, radio) | `scripts/building_interior.gd` |
| Tent / cabin / service interiors | `scripts/{tent,cabin,service}_interior.gd` |
| Guest lifecycle, reviews, liminal pressure | `scripts/guest_manager.gd` |
| Email content | `data/pools/emails/**/*.json` |
| First-person movement, footsteps, head bob | `scripts/player_controller.gd` |
| Weather visuals (sky, clouds, rain, celestial) | `scripts/weather_visuals.gd` |
| All audio | `scripts/audio_manager.gd` |

> ⚠️ **Two building catalogs still exist.** `data/buildings/*.tres` is canonical
> (`BuildingRegistry` + all pure systems read it). `EconomyManager.BUILDING_DATA` is the
> legacy builder-UI catalog being strangled out. They are currently in sync, and
> `EconomyManager._validate_against_building_registry()` shouts in debug builds if they
> drift. **Edit both until the legacy dictionary is deleted.**

### Adding a new building

1. Create `godot/data/buildings/<id>.tres` with the `BuildingDef` script attached.
2. Fill in `id` (must equal the runtime building type string), `display_name`,
   `category`, `cost`, `footprint`, plus the simulation fields.
3. Mirror it into `EconomyManager.BUILDING_DATA` until that dictionary is retired.
4. `BuildingRegistry` auto-loads the directory on startup; the builder UI auto-populates.

---

## 5. Gotchas that will cost you an hour

- **Loading screen teardown.** After startup the `_loading_*` references in `main.gd`
  are expected to be `null`. Don't assume they exist.
- **Interior nodes are children of `_world_3d`,** not of the `Main` root.
- **`_window_layer` in the CRT shell uses `MOUSE_FILTER_STOP`.** It must be
  `visible = false` when no window is open, or it eats every desktop click.
- **Desktop icon drag/click:** the press is handled in `gui_input`, but the
  **release is handled in `_input()`** — `gui_input` release is unreliable after
  `move_to_front()`. Drag threshold is 4px.
- **Sky/weather profiles must be derived from a fresh time baseline,** otherwise the
  tint drifts across day transitions.
- **Rain direction is driven by weather wind (`_rain_weather_wind`),** never by player
  movement.
- **Footstep pitch modulation must stay subtle.** A wide range or slow release produces
  an audible "whoosh" artifact when stopping from a sprint.
- **Weather does not auto-cycle during gameplay** — only in the menu flythrough.
  See [AUDIT.md](AUDIT.md) §Gameplay gaps before "fixing" it.
- **`main.gd` and `crt_os_shell.gd` are ~4.5k lines each.** Read the symbol map
  (`grep -n "^func " <file>`) before editing; don't load the whole file blindly.

---

## 6. Working style for this repo

1. Check [TODO.md](TODO.md) for the current priority.
2. Skim [ARCHITECTURE.md](ARCHITECTURE.md) for how the affected area is wired.
3. Make the change, keeping to the scope of the current priority.
4. Run the headless smoke test.
5. Run the game if the change is gameplay- or UI-visible.
6. Update the docs that your change invalidated — especially [PRODUCT.md](PRODUCT.md)'s
   status table if you moved a feature between states.

### Refactoring the two god files

`main.gd` (4.5k) and `crt_os_shell.gd` (4.8k) are the two big targets. The established
pattern, already used successfully for `loading_screen.gd`, `hud_manager.gd`,
`weather_visuals.gd` and `interior_manager.gd`:

1. Create the new module script under `scripts/`.
2. Move one cohesive concern into it with an explicit `setup(...)` injection point.
3. Have `main.gd` instantiate it and forward calls.
4. Delete the legacy block only once the module is proven at runtime.

Do **one** concern per change. Verify between each.
