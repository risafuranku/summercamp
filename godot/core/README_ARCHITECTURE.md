# Godot Architecture Guide (Cursed Camp Simulator 2)

## 1. Single Source of Truth
All persistent runtime data MUST live in `GameState` (Resource).
Access is provided via the `CoreRoot` autoload.

## 2. Global Write Access (Actions Only)
Modifying the state directly from outside `core/` is **FORBIDDEN**.
- **Correct**: `CoreRoot.actions.place_building(...)`
- **Incorrect**: `CoreRoot.state.money -= 100`

## 3. EventBus Contract
Modules communicate via signals on `EventBus`. 
- **Modules** listen to `EventBus`.
- **Core (Actions/Systems)** emits to `EventBus`.

## 4. Pure Systems
All simulation logic (Income, Power, Hygiene) should be in `core/systems/`.
- Systems must NOT refer to `SceneTree` or `get_node`.
- Systems receive `GridModel` and `BuildingRegistry` and return results or modified deltas.

## 5. UI Rules
UI is a **ReadOnly View**.
- UI should NOT calculate costs or metrics.
- UI should forward user intent to `Actions`.
- If a complex UI summary is needed (e.g. demolish plan), `Actions` should provide a helper.

## 6. How to add a new building (Data-Only)
1. Create a new `.tres` file in `res://data/buildings/`.
2. Assign it the `BuildingDef` resource script.
3. Fill in `id`, `display_name`, `cost`, `footprint`, etc.
4. The `BuildingRegistry` will auto-load it on startup.
5. The UI will auto-populate with the new building.
