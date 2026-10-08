# CLAUDE.md

See **[AGENTS.md](AGENTS.md)** — it is the operating manual for this repository
(ground rules, project layout, how to run and verify, and the gotchas that cost time).

Quick orientation:

- Godot project root is `godot/`. Engine: **Godot 4.7.1**.
- Smoke test before declaring anything done (grep for SCRIPT ERROR):
  `godot --headless --path godot --quit-after 400`
- Gameplay changes must also be seen: run the screenshot driver scenarios.
- State is mutated only through `CoreRoot.actions`. `EventBus` is the only cross-module
  signal hub. Systems in `core/systems/` stay pure.
- Buildings live only in `data/buildings/*.tres` (BuildingRegistry).
- Harnesses in `godot/tools/` and the screenshot driver: see AGENTS.md §3.
- The game ships in **English**; Czech belongs in comments and commit messages only.

Then: [PRODUCT.md](PRODUCT.md) for feature status, [DESIGN.md](DESIGN.md) for intent,
[ARCHITECTURE.md](ARCHITECTURE.md) for wiring, [TODO.md](TODO.md) for priorities.
