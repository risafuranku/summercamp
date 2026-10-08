# AGENTS.md — operating manual for this repo

Onboarding for any agent or developer working on **Cursed Camp Manager Simulator**.
Read this first, then [ARCHITECTURE.md](ARCHITECTURE.md) for wiring and [DESIGN.md](DESIGN.md)
for intent. [PRODUCT.md](PRODUCT.md) says what exists.

> **When docs and code disagree, the code wins.** Fix the doc in the same change.

---

## 1. Ground rules

| Rule | Why |
| --- | --- |
| Mutate state through `CoreRoot.actions`, never `CoreRoot.state.x = y` from outside `core/` | Single write path; `EventBus` notifications are emitted there |
| `EventBus` is the only cross-module signal hub | Modules listen, core emits |
| Systems in `core/systems/` stay pure | No `get_node`, no `SceneTree`; data in, numbers out. Rules modules (`maintenance_rules.gd`, `weather_system.gd`) are static/pure too |
| UI is a read-only view | UI forwards intent; it does not compute costs or odds |
| The game ships in **English** | Czech in comments/commits is fine, never in player-facing strings |
| Refactor strangler-style | New module → route through it → delete the legacy block; one concern per change, verify between |
| Tabs, not spaces | |
| `config/name` stays `"icloud ccs2"` | It names the `user://` folder holding players' saves/settings. The displayed title is set at runtime (`main.WINDOW_TITLE`) |

### Design lock — do not "improve" these without being asked

- The look is a **mid-90s Build-engine game**: pixel fonts on an integer scale, palette,
  bevelled square plates, no rounded corners, no glossy gradients, no app-store polish.
- The tone is **serious, with rare uncanny details** (DESIGN.md §2). No jumpscare spam.
- Every night threat is forecast before it is encountered and has a readable counter.
- `UTILITY_REPAIRS_ENABLED = false` stays off (repairs go through upkeep, hold R).

---

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
    main.gd                   # orchestration (~3k lines; still the biggest file)
    crt_os_shell.gd           # the in-world Win95 terminal and its apps (~5k lines)
    ui/                       # retro_ui (kit), retro_menu (menu parts), main_menu,
                              # pause_menu, game_over_screen, boot_screen
    enemies/                  # i_enemy_brain, enemy_base, silent_man, tourist, girl, stalker
    hud_manager.gd            # Build-engine HUD
    maintenance_controller.gd # upkeep in the world (signs, hold R, crew)
    electricity_billing.gd    # bills, power cut, UPS
    blood_fx.gd, menu_flythrough.gd, save_codec.gd, ...
  assets/fonts/*.fnt          # baked bitmap fonts (do not edit by hand, see §7)
  tools/                      # in-engine harnesses (§3) and the screenshot driver
tools/                        # repo-level tooling: gen_pixel_fonts.py, gen_sfx.py,
                              # gen_palette_lut.py, artgen/ (Grok Imagine), godot MCP
```

Autoloads (order matters): `SaveManager`, `GameSettings`, `EventBus`, `CoreRoot`,
`EmailManager`, `GuestManager`.

---

## 3. Running and verifying

Godot **4.7.1**. Portable binary on the dev PC:
`C:\Users\arnold\Downloads\Godot_v4.7.1-stable_win64.exe\` (use the `_console.exe` headless).

```bash
godot --headless --path godot --quit-after 400            # smoke
godot --headless --path godot res://tools/hud_layout_check.tscn
godot --headless --path godot res://tools/guest_sim_check.tscn
godot --headless --path godot res://tools/upkeep_check.tscn
godot --headless --path godot res://tools/billing_check.tscn
godot --headless --path godot res://tools/pipes_check.tscn
godot --headless --path godot res://tools/uncanny_check.tscn
godot --headless --path godot --script res://tools/weather_check.gd
```

- **Grep the smoke output for `SCRIPT ERROR` / `Parse Error`.** A tail of the log can hide
  a parse error: the game still prints its normal startup lines after a failed script.
- Harnesses that need autoloads must run as **scenes**, not `--script`.
- Benign at exit: "N resources still in use" / leaked ObjectDB (audio thread race).

### Seeing the game: the screenshot driver

```bash
godot --path godot --resolution 1280x720 res://tools/shot_driver.tscn -- --scenario=<name> --out=<dir>
```

Scenarios: `boot menu views hud quest pause gameover crt crtmap weather upkeep blood night
saveload guests pipes senses uncanny probe`. Steps include `build`, `book`, `hours`, `player`, `money`, `press`,
`condition`, `break`, `look_at_enemy`, `crt_screen` (saves the terminal's own frame),
`eval` (Expression against Main; autoload names are not reachable from it).
Check visual changes at 1280x720 **and** 1920x1080.

---

## 4. Where things live

| I want to change… | Go to |
| --- | --- |
| A building's cost/capacity/needs/decay | `data/buildings/<id>.tres` (only place) |
| Tuning constants | `core/balance/balance_config.gd` |
| Upkeep odds/costs | `core/systems/maintenance_rules.gd` |
| Weather durations/transitions | `core/systems/weather_system.gd` |
| Guest needs and archetype personalities | `core/systems/guest_needs_system.gd` |
| Which enemy an archetype brings | `main.ENEMY_FOR_ARCHETYPE` + `scripts/enemies/` |
| HUD | `scripts/hud_manager.gd` (+ `scripts/ui/retro_ui.gd` kit) |
| Menus / pause / game over | `scripts/ui/` |
| Terminal apps (CampMail, Builder, Camp Status…) | `scripts/crt_os_shell.gd`, map: `crt_map_panel.gd` |
| Electricity | `scripts/electricity_billing.gd` |
| Save format helpers | `scripts/save_codec.gd`; snapshot build/apply in `main.gd` |
| Player movement, flashlight battery, stamina | `scripts/player_controller.gd` |
| Insects falling silent, the HUD face's glance | `scripts/threat_senses.gd` (reads `get_presence()`) |
| Story mails (Vera, Nela, the odd ones) | `data/pools/emails/story/week01_story.json` |
| The radio (playlist, outdoor source, the station) | `scripts/building_interior.gd`, synth: `tools/gen_sfx.py` |

### Adding a building
Create `data/buildings/<id>.tres` (BuildingDef). That is all for the data side; add it to
`builder_module.GROUPS` (+ icon) and `builder_authority.ALLOWED_BUILD_TYPES` to make it
buildable.

### Adding an enemy
Extend `scripts/enemies/enemy_base.gd`, implement `_on_start()` / `_on_tick(dt)`, give it a
tell, a counter, an `_announce()` line, keep `get_presence()` truthful (the base class
tracks the body and its sounds; it drives the insects and the HUD face), then map it in `main.ENEMY_FOR_ARCHETYPE` (or start
it from `_activate_runtime_enemy_for_night`). Add a row to DESIGN.md §5 and to
`crt_os_shell.NIGHT_PROCEDURES`. Test with `debug_spawn_enemy(id)` and the `night` scenario.

---

## 5. Gotchas

- **Interiors consume Esc in their `_input`**; whatever reaches `main._unhandled_input`
  is first-person play, where Esc pauses (the tree is paused; menus run `PROCESS_MODE_ALWAYS`).
- **2D integer scale is chosen at runtime** (`main._apply_integer_canvas_scale`): the
  logical size is window / k so the canvas scale is a whole number and the window is
  filled. The engine's own integer mode letterboxes; do not switch to it.
- **Pixel fonts are bitmaps with integer-only scaling**: request `size_vp` = 8 (labels,
  text) or 10 (Jersey) or multiples; other sizes snap down.
- **Inner classes can't call the outer script's static funcs** (they can read its consts).
- **CRT windows open after a delay**; the reveal is per window and waits for the desktop.
- **`_window_layer` in the CRT shell uses `MOUSE_FILTER_STOP`**: keep it hidden with no
  windows open.
- **Desktop icon release is handled in `_input()`**, not `gui_input` (unreliable after
  `move_to_front()`).
- **Sky/weather profiles derive from a fresh time baseline** each frame; weather changes
  crossfade over 40 s (`weather_visuals`), don't snap the environment directly.
- **Footstep pitch modulation must stay subtle** (whoosh artifact otherwise).
- **Bash heredocs with long inline Python sometimes fail**; write the script to a file.

---

## 6. Working style

1. Check [TODO.md](TODO.md).
2. Make the change in scope; keep `core/` pure.
3. Run the smoke test and every harness touching the area.
4. Run the screenshot driver for anything visible; look at the images.
5. Update the docs the change invalidated (PRODUCT status table, DESIGN rules).
6. Commit with a message that says what was wrong, not just what changed.
7. Push `main` to both remotes: `origin` (GitLab) and `github`.

---

## 7. Art, fonts and sound pipelines

- **Generated art** — Grok Imagine through the Cursor agent CLI:
  `tools/artgen/gen.sh <id>` reads `tools/artgen/prompts.tsv` (id, aspect, reference image
  relative to `godot/` or `-`, prompt), writes `tools/artgen/out/<id>/raw.png` (gitignored).
  **One at a time**: parallel runs swap outputs. ~5 min per image. The tool supports 1:1,
  4:3, 3:4, 16:9, 9:16 only.
  Then `python tools/artgen/process.py <id> sprite <height> <dest>` (keys out flat magenta,
  box-downsamples, snaps to the game palette) or `texture <size> <dest>`.
  For sprites ask for a flat pure magenta `#FF00FF` background and pass an existing sprite
  as reference so pixel scale and palette match.
- **Fonts**: `python tools/gen_pixel_fonts.py` bakes `tools/font_src/*.ttf` into
  `godot/assets/fonts/*.fnt/.png` on their native grid. Import setting `scaling_mode=1`.
- **Synth SFX**: `python tools/gen_sfx.py` (shutter, flash whine, static/hum loops, thump).
- **Palette LUT**: `tools/gen_palette_lut.py`.

Licensing: most world textures are rips from Redneck Rampage (`assets/textury/redneck/RRTX*`).
Fine for a private prototype, a blocker for any public release; replace them with generated
textures (§7) before shipping.
