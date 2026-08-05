# TODO — Summer Camp Incident Simulator 2

*Updated: 2026-08-05, after the cleanup pass. See [AUDIT.md](AUDIT.md) for context.*

---

## P0 — verify the cleanup pass

The 2026-08-05 pass fixed bugs that changed simulation values. These need a real
playthrough, not a headless run.

- [ ] Play 3–4 in-game days. Confirm guest reviews now vary (were always 1 star).
- [ ] Watch `satisfaction`, `karma`, `energy_load`, `infra_load` in the Camp Status app.
      These four systems have never actually run before — check the numbers aren't absurd.
- [ ] Confirm building costs are unchanged from before the registry regeneration.
- [ ] Confirm no debug-build warnings about building catalog drift.
- [ ] Confirm the reception notebook click no longer eats input (it should now fall
      through to the room raycast).

## P0 — balance the newly live systems

- [ ] Tuning pass on `hygiene_delta` / `fun_delta` / `radius` in `data/buildings/*.tres`.
      Current values are mechanical derivations from `service_points` / `attraction_points`,
      not designed numbers. See [DESIGN.md](DESIGN.md) §Comfort model.
- [ ] Decide what `karma` and `infra_load` should actually *do* to the player. They are
      computed and stored; nothing consumes them meaningfully.

## P1 — turn on the weather

The single best value-per-effort item in the project. ~1,700 lines of finished weather
visuals plus a complete weather audio mix currently never fire during gameplay.

- [ ] Replace the placeholder Markov table in `WeatherSystem._transition_weather()` with
      a designed transition model (duration ranges per state, plausible sequences).
- [ ] Enable `auto_cycle_enabled` during gameplay (`main._start_gameplay_runtime()`).
- [ ] Verify the sky/celestial profile stays stable across weather changes and day
      transitions — the fresh-baseline rule in [AGENTS.md](AGENTS.md) §Gotchas applies.
- [ ] Tune weather frequency against the 24-minute day so a session sees variety without
      thrashing.

## P1 — close the maintenance loop

- [ ] Surface maintenance decay before failure (visual wear, status app warning).
- [ ] Give failure a consequence the player feels beyond the repair minigame.
- [ ] Decide the fate of `UTILITY_REPAIRS_ENABLED` — wire it up or delete the minigame.

## P2 — guest simulation phase 2

The largest gap between design and build. Guests are pure data with no world presence.

- [ ] Needs model: hunger, energy, hygiene, social/fun, comfort, safety + tick.
- [ ] ACTIVE-state brain: goal selection weighted by needs, cooldowns, anti-stuck fallback.
- [ ] Service usage: guests read available camp services and react to them.
- [ ] Visual guest agents — placeholder 3D representation bound to the guest entity,
      simple pathing with a teleport fallback.
- [ ] Event pool: small random ambient events, larger condition-driven story events.

## P2 — horror layer depth

- [ ] Second enemy archetype implementing `i_enemy_brain.gd`.
- [ ] Answer DESIGN.md open question 1: what does the player *do* during a quiet night?
- [ ] Answer DESIGN.md open question 4: rules for when the terminal is allowed to lie.

## P2 — CRT desktop debt

- [ ] Minesweeper as a real app (currently a text-window skeleton).
- [ ] Icon texture filtering: blur → pixel (asset pipeline).
- [ ] Fake loading progress tuning.
- [ ] Wire up or delete `_open_notepad_app()` and `_open_explorer_app()`.

## P2 — email / CampMail

- [ ] Bind the desktop ticker to real runtime state (weather, occupancy, finance).
- [ ] Thread/reply simulation for story pacing (Aunt Vera, Nela, the unknown sender).

## P3 — structural

- [ ] Retire `EconomyManager.BUILDING_DATA`; make `BuildingRegistry` the sole catalog.
      Touches ~15 call sites across builder UI, costs, income, power breakdown, capacity.
- [ ] Continue extracting `main.gd` toward orchestration-only (currently ~4.5k lines).
      Next candidates: the main menu (~800 lines), electricity billing, blood FX.
- [ ] Split `crt_os_shell.gd` (~4.8k lines) — one file per desktop app.
- [ ] Make `BuildingManager` a pure view over `GridModel`.
- [ ] Move `crt_map_panel.gd` off its direct `EconomyManager` reads onto `CoreRoot`/`EventBus`.
- [ ] Remove `GameActions.end_day()` once nothing calls it.
- [ ] Bump `project.godot` `config/features` from `4.6` to match the 4.7.1 toolchain.

## P3 — housekeeping

- [ ] Decide on `.claude/worktrees/pensive-heyrovsky/` (354 MB orphan — check
      `textury rip/` first, then delete).
- [ ] Audit unused RRTX textures (~267 of 363 appear unused, ~200 MB).
- [ ] Remove root debug PNGs.
- [ ] Consider a minimal test harness — even a headless script that places buildings and
      asserts on state would have caught both P0 bugs from the audit.
