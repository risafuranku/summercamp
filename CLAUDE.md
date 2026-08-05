# CLAUDE.md

See **[AGENTS.md](AGENTS.md)** — it is the operating manual for this repository
(ground rules, project layout, how to run and verify, and the gotchas that cost time).

Quick orientation:

- Godot project root is `godot/`. Engine: **Godot 4.7.1**.
- Smoke test before declaring anything done:
  `godot --headless --path godot --quit-after 400`
- There is **no automated test suite.** Gameplay changes must be verified by running the game.
- State is mutated only through `CoreRoot.actions`. `EventBus` is the only cross-module
  signal hub. Systems in `core/systems/` stay pure.
- **Two building catalogs still exist** — `data/buildings/*.tres` (canonical) and
  `EconomyManager.BUILDING_DATA` (legacy). Edit both until the legacy one is retired.
- The game ships in **English**; Czech belongs in comments and commit messages only.

Then: [PRODUCT.md](PRODUCT.md) for feature status, [DESIGN.md](DESIGN.md) for intent,
[ARCHITECTURE.md](ARCHITECTURE.md) for wiring, [TODO.md](TODO.md) for priorities.
