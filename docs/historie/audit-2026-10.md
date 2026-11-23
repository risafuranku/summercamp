# AUDIT.md — history

## Remaster pass, 2026-10-07/08

Merged the cloud branch (Build-engine look, guest simulation, HUD, questline), then fixed
and extended. Commits on `main` from `fe01223` to the docs commit; each message says what
was wrong. The real bugs found on the way:

| Severity | Finding | Fix |
| --- | --- | --- |
| 🔴 | Only Quiet Guy ever spawned an enemy; Drunk/Cheap Chick night odds did nothing | an enemy per archetype + the Antlered Man for mixed nights |
| 🔴 | Any building could break, only the sewer could be repaired; FailureSystem ran in the main menu and broke things at 5% even at full condition | upkeep loop: condition-driven odds, hold R, crew |
| 🔴 | An exported build would load zero buildings (registry matched `*.tres`, exports list `*.tres.remap`) | strip `.remap` |
| 🟠 | Weather never ran during play (whole subsystem unseen) | designed cycle + crossfade |
| 🟠 | Body text font not on a pixel grid (C read as G), fi ligature showed "Arst"; 1.5x blurry canvas at 1080p | baked bitmap fonts, runtime integer canvas scale |
| 🟠 | HUD overlaps (banner over tracker, card over tracker), night risk shown twice, stale "Evening" line at night, waypoint sprite huge/clipped up close | HUD layout rewrite + screen-space marker |
| 🟠 | No pause: Esc only toggled the mouse; no way to save or quit to title in play | pause menu |
| 🟠 | CRT: a window opening during another's open delay never appeared; one requested during the splash was dropped | per-window reveal that waits for the desktop |
| 🟡 | Mouse yaw applied twice per event; HUD stamina/light bars never fed | single yaw with explicit factor; stamina + battery |
| 🟡 | Two hand-synced building catalogs | registry is the only catalog |
| 🟡 | Radio asked a freed reception for its transform on every load; footsteps played before entering the tree | guards |
| 🟡 | HUD harness reported PASS when hud_manager.gd failed to compile | can_instantiate guard |
| 🔴 | The sewer repair could never finish (`repair_completed` was never emitted) | pipe crawl rebuilt |
| 🟡 | `hud.set_fear()` was never called: the status face never widened its eyes | night senses (`threat_senses.gd`) |
| 🟡 | Interiors: the tent's A-frame never met at the ridge (sky showed through), the cabin had no front wall and a gap round the door; Czech signs in the interiors ("HAJZLY"); the sewer's "R" hint hung behind the camera; `service_repair`/`service_kitchen_variant` actions were unregistered (an engine error per key press) | closed rooms, English signs, stateful sewer hint, actions always registered |
| 🔴 | Blood drops that hit nothing stopped 2-5 m in front of the camera and left a stain in mid-air | ballistic drops, stains only where they land |
| 🟠 | Up to nine booking mails and four spam mails an hour, around the clock | office-hours cadence rising through the week, one night false alarm at most |
| 🟠 | Accepting a booking teleported the party into the camp at once | the road, the barrier, room preparation |
| 🟠 | `main._sync_guest_accommodation_state` rebuilt the room states itself and overwrote them with a legacy "clean" | it only mirrors guest counts onto structures now |
| 🟠 | Upgrades (tent_1 -> tent_2, cabin_1 -> cabin_2) swapped the 3D model but left the old type in the core grid: wrong capacity, wrong room tasks, wrong saves | `actions.retype_building` |
| 🔴 | The Silent Man hurt you from hidden meters (no position, no warning you could read); the Photographer moved in front of you after each hit, so hits chained | both rebuilt around audible tells and a counter that always works; tools/enemy_check.tscn |
| 🟡 | Story pool padded with re-sent copies tagged "[day N transmission tag]", read as a bug; two mails duplicated the questline | story week rewritten |

---

## Cleanup pass, 2026-08-05

Findings from a full read of the project after ~6 months dormant, and what was done
about them. Kept as a record so the same ground isn't re-covered.

**Starting point:** ~40,400 lines of GDScript across 60 files, no version control, no
tests. The project parsed and ran headless without errors — the bones were sound. The
problems were dead layers, two disagreeing sources of truth, and a handful of silent
logic bugs.

---

## Fixed

### 🔴 Guest reviews were permanently pinned to 1 star

`SatisfactionSystem.calculate()` returned a **0.0–1.0** value into `GameState.satisfaction`,
which every consumer treats as **0–100**. `CoreRoot.recalculate_systems()` overwrote the
state on every building placement and every day tick.

Downstream, `GuestManager._build_review_for_guest()` computes
`rating_base = round(clamp(satisfaction, 0, 100) / 25.0)`. With satisfaction stuck at
`0.5`, that is always `0`, so `rating = clampi(0 + randi_range(-1, 1), 1, 5)` was
**always exactly 1**, and the review text pool was always `REVIEW_NEGATIVE`.

Every guest who ever checked out left a one-star negative review. The entire review
system was inert.

**Fix:** `SatisfactionSystem` now works on and returns the 0–100 scale, with the scale
contract documented in the file so it can't silently regress.

### 🔴 The building registry was disconnected from the game

`data/buildings/*.tres` contained 5 definitions with IDs `tent_lv1`, `cabin_lv1`,
`shower_lv2`, `toilet_lv1`, `generator_lv1`. The actual runtime building types are
`tent_1`, `cabin`, `shower_block`, `toilet_block`, `power_generator`. **No ID ever
matched.** Categories didn't match either (`accommodation` vs `housing`).

Consequences:
- `BuildingRegistry.get_def()` returned `null` for every building ever placed.
- `EnergySystem`, `InfraSystem`, `SatisfactionSystem` and `KarmaSystem` iterated the grid,
  failed every lookup, and returned constants. Four "pure systems" computed nothing.
- `GameActions._get_building_cost()` always fell through to a recursive
  `find_child("EconomyManager")` scan of the entire scene tree.
- The documented "how to add a building (data-only)" workflow could not work.

**Fix:** regenerated all 23 building definitions from `EconomyManager.BUILDING_DATA`, so
IDs match runtime types and costs/footprints are preserved exactly. Added
`EconomyManager._validate_against_building_registry()`, which runs in debug builds and
warns on any cost or footprint drift between the two catalogs.

> ⚠️ **This turns on four systems that have never run.** Satisfaction, karma, energy load
> and infra load now receive real building data for the first time. The derived
> `hygiene_delta` / `fun_delta` / `radius` values are mechanical placeholders
> (see [DESIGN.md](DESIGN.md) §Comfort model) and need a balance pass.

### 🟠 Dead reception interaction that ate the player's click

The guest assignment system was removed at some point, but its UI survived:
`guest_assignment_notebook.gd` (562 lines) and `guest_assignment_map_panel.gd` (285 lines)
were still preloaded and still Czech-language. `GuestManager` kept 13 stub methods that
returned `{"ok": false, "reason": "assignment_removed"}` — none of them called by anything.
`building_interior.gd` had four no-op notebook functions, and `_try_click_room()` checked
the notebook hotspot in **three separate branches**, returning `true` (consuming the
click) and then calling a function whose entire body was `return`.

Clicking the reception notebook did nothing, and silently swallowed the input.

**Fix:** deleted both UI scripts, all 13 stubs, the vestigial `auto_assignment_enabled`
save field, and the no-op functions. Rewrote `_try_click_room()` from 35 lines of
duplicated branching to 17 linear lines. The notebook prop and its hotspot metadata
remain as a documented reserved interaction slot.

### 🟠 `BuildingRegistry` loaded every definition twice

`BuildingRegistry._ready()` calls `load_all()`, and `CoreRoot._ready()` called
`registry.load_all()` again immediately after `add_child()`. Visible in the startup log
as a duplicated "Loaded N buildings" line.

**Fix:** removed the redundant call.

### 🟠 Full scene-tree scan per building during demolish preview

`GameActions._find_economy_manager()` ran `root.find_child("EconomyManager", true, false)`
— a recursive walk of the whole tree — uncached. It's reached from `_get_building_cost()`
→ `_get_building_refund()` → `get_demolish_summary()`, which loops over every cell in the
dragged rectangle. A 10×10 demolish drag triggered up to 100 full tree walks per frame.

**Fix:** cached with an `is_instance_valid()` guard. (Now also mostly bypassed, since
registry lookups actually resolve.)

### 🟡 Audio streams leaked at shutdown

`ambience3A.mp3` was held by both the menu music player and `AudioManager`'s ambient
track array, neither of which released on teardown. Reported at exit as
`ObjectDB instances were leaked` + `resources still in use`.

**Fix:** added `_exit_tree()` cleanup to both `main.gd` and `audio_manager.gd` — stop
players, null their `stream` refs, clear the track arrays, `free()` the menu player
(not `queue_free()`, whose deferred queue may never flush on quit).

**Partially resolved.** The warning still appears intermittently. What remains is an
audio-thread shutdown race inside the engine — the playback object outlives the `stop()`
call. It is cosmetic, occurs only at process exit, and has no runtime effect. Not worth
further chasing.

### 🟡 Dead scaffolding

- `godot/systems/` — an entire abandoned parallel module tree. Only `crt_os/` had
  content (`crt_os.gd`, `crt_os.tscn`, `crt_post.gdshader`), and nothing referenced
  `crt_os.tscn`. The other six subdirectories were empty. **Deleted.**
- `godot/resources/`, `godot/shaders/`, `modules/{builder,sim,ui}/` — empty. **Deleted.**
- `EventBus`: `spatnej1`, `spatnej2`, `spatnej3`, `dobrej1`, `dobrej2`, `dobrej3`,
  `event_tick` — never emitted, never connected. `open_builder_requested` and
  `open_guestrack_requested` were emitted only by the dead `crt_os.gd`. **Deleted.**
- 28 `.DS_Store` files and 21 `*~` editor backups. **Deleted and gitignored.**

### 🟡 Consistency

- Four files used 4-space indentation in an otherwise tab-indented codebase
  (`game_state.gd`, `time_system.gd`, `system_base.gd`, `weather_system.gd`,
  `visual_module.gd`). **Retabbed.**
- Remaining Czech player-facing strings in the tent/cabin upgrade menus and the upgrade
  dialog's Close button. **Translated** — the design lock says the game ships in English.
- Duplicated comment lines, a dead `old_state` branch in `TimeSystem._update_time_state()`,
  and an eight-line stream-of-consciousness comment block in `GameActions.remove_building()`.
  **Cleaned.**

### 🟢 Version control

The project had **no git repository** — six months of work with no history and no undo.
Initialised one with an appropriate `.gitignore` (`.godot/`, OS junk, editor backups,
Claude worktrees) and committed the untouched state as the baseline before any edit.

---

## Gameplay gaps found (not bugs — unbuilt connections)

### Weather never runs during gameplay

`WeatherSystem.auto_cycle_enabled` is set to `true` when entering the main menu and
`false` when gameplay starts. During an actual session, weather changes **only** via the
`toggle_weather` debug key.

This is consistent and deliberate in the code (the menu flythrough wants moving weather),
but it means `weather_visuals.gd` (1,684 lines), the weather audio mix, rain occlusion,
thunder sync and six of seven weather states contribute nothing to a real playthrough.

Probably the highest value-per-effort change available: a large, finished subsystem is
one boolean away from being in the game. It needs a transition-table tuning pass first —
`WeatherSystem._transition_weather()` is explicitly labelled placeholder logic.

### Maintenance decays into nothing

`MaintenanceSystem` and `FailureSystem` run. `BuildingDef.maintenance_decay` is authored.
But there is no player-visible progression from decay → warning → failure → repair, so
failures read as arbitrary rather than as the consequence of neglect.

### Unreachable code paths

- `crt_os_shell._open_notepad_app()`, `_open_explorer_app()`, `_build_status_app_text()`
  — defined, never called.
- `EconomyManager`: 12 public methods never called from anywhere, including the entire
  `get_builder_catalog()` / `get_builder_categories()` / `can_build_from_builder()` path.
  The builder gets its catalog somewhere else.
- `utility_repair_minigame.gd` is complete but gated off by `UTILITY_REPAIRS_ENABLED = false`.

Left in place: they're plausible extension points rather than clutter, but they should
be either wired up or deleted rather than left ambiguous.

---

## Not touched — decisions for you

| Item | Size | Note |
| --- | --- | --- |
| `.claude/worktrees/pensive-heyrovsky/` | **354 MB** | Orphaned git worktree from the old Mac (`gitdir: /Users/ricky/prac/Undo95/.git`). Contains a full duplicate of the project plus a `textury rip/` folder not present in the main tree. Gitignored, not deleted — check `textury rip/` before removing |
| Unused RRTX textures | ~200 MB of 234 MB | `all_rrtx.txt` lists 363 texture names, `used_rrtx.txt` lists 96. ~267 appear unused. Verify before pruning; the lists may be stale |
| Root debug PNGs | ~2.6 MB | `logo_alpha_debug.png`, `text_on_black_debug.png`, `splash_sim_current.png` etc. — asset iteration leftovers |
| `main.gd` / `crt_os_shell.gd` split | 9.3k lines | Real refactor work; needs runtime verification per step, not a blind pass |
| `EconomyManager.BUILDING_DATA` removal | — | The correct endgame, but touches the builder UI, costs, income, power breakdown and capacity across ~15 call sites. Too risky without tests |

---

## Verification

Every change above was verified with:

```bash
godot --headless --path godot --quit-after 400
```

Clean output, no script errors, no catalog drift warnings, `BuildingRegistry: Loaded 23
buildings` (was 5, of which 0 were reachable).

**Not verified:** actual gameplay. There is no test suite, and the changes to
satisfaction and the building registry alter simulation values that only a real
playthrough will expose. Play a few in-game days and watch review ratings before
building on top of this.
