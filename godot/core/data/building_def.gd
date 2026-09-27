class_name BuildingDef
extends Resource

## Data definition for a single building type.

@export var id: StringName
@export var display_name: String = ""
@export var category: StringName
@export var cost: int = 0
@export var radius: int = 0

# Consumption / Production
@export var power_draw: float = 0.0
@export var power_production: float = 0.0
@export var infra_load: float = 0.0
@export var hygiene_delta: float = 0.0
@export var fun_delta: float = 0.0
@export var passive_income: float = 0.0
@export var karma_delta: float = 0.0

# Legacy economy compatibility fields (used by EconomyManager utility summary paths)
@export var capacity: int = 0
@export var power_use: int = 0
@export var water_use: int = 0
@export var sewage_use: int = 0
@export var waste_use: int = 0
@export var power_provide: int = 0
@export var water_provide: int = 0
@export var sewage_provide: int = 0
@export var waste_provide: int = 0

# Guest simulation (see core/systems/guest_needs_system.gd)
## Need -> points restored per visit, e.g. {"hunger": 90.0, "fun": 10.0}. Negative drains.
@export var guest_services: Dictionary = {}
## How many guest parties can use the facility at once (0 = not a guest facility).
@export var guest_capacity: int = 0
## Game minutes a visit takes.
@export var use_minutes: int = 0
## Housing comfort 0-100: sleep quality and a standing mood modifier for residents.
@export var comfort: float = 0.0
## Guest-facing requirements: "sewer" (needs a working sewer) and/or "power".
@export var requires: PackedStringArray = []

# Systems
@export var maintenance_decay: float = 0.0
@export var tags: PackedStringArray = []

# Visuals
@export var icon_path: String = ""
@export var footprint: Vector2i = Vector2i(1, 1)
