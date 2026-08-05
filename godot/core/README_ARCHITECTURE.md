# `core/` — rules for the canonical layer

Full architecture: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md).
Working rules: [`../../AGENTS.md`](../../AGENTS.md).

This file covers only the constraints that apply *inside* `core/`.

## 1. Single source of truth

All persistent runtime data lives in `GameState` (a `Resource`), reached through the
`CoreRoot` autoload.

## 2. Writes go through Actions

Modifying state directly from outside `core/` is **forbidden**.

```gdscript
CoreRoot.actions.place_building(...)   # correct
CoreRoot.state.money -= 100            # wrong
```

`GameActions` is the only place that mutates `GameState` and emits the corresponding
`EventBus` notification. Keep those two together — a mutation without its signal is how
UI goes stale.

## 3. EventBus contract

Core emits, modules listen. Never the reverse, and never module → module.

## 4. Systems stay pure

Everything in `core/systems/` takes a `GridModel` and a `BuildingRegistry` and returns a
number or a delta. No `get_node`, no `SceneTree`, no node references, no signals.

**Mind the scales.** They are not uniform, and mixing them up has already cost this
project a shipped bug:

| Value | Scale |
| --- | --- |
| `satisfaction` | 0 – 100 (neutral 50) |
| `energy_load` | 0 – 1 (draw / capacity) |
| `infra_load` | absolute sum, unbounded |
| `karma` | −100 – +100, systems return a *delta* |
| `hrotfaktor` | 0 – 1 |

## 5. UI is a read-only view

UI forwards intent to `Actions` and renders what it's given. It does not compute costs,
capacity or metrics. If UI needs a derived summary, add a helper to `Actions`
(e.g. `get_demolish_summary()`) rather than recomputing it in the view.

## 6. Adding a building

1. Create `res://data/buildings/<id>.tres` with the `BuildingDef` script attached.
2. `id` **must equal the runtime building type string** used on the grid
   (`tent_1`, `cabin_2`, `toilet_block`, …). A mismatch makes every registry lookup
   return `null`, which silently disables all four pure systems for that building —
   this was the state of the project until 2026-08-05.
3. Fill in `display_name`, `category`, `cost`, `footprint` and the simulation fields.
4. Mirror the entry into `EconomyManager.BUILDING_DATA` until that legacy catalog is
   retired. `EconomyManager._validate_against_building_registry()` warns in debug builds
   if the two drift.
5. `BuildingRegistry` auto-loads the directory on startup; the builder UI auto-populates.
