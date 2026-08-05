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

# Systems
@export var maintenance_decay: float = 0.0
@export var tags: PackedStringArray = []

# Visuals
@export var icon_path: String = ""
@export var footprint: Vector2i = Vector2i(1, 1)
