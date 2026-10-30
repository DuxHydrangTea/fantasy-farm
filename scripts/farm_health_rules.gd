extends Resource
## Shared balance only; per-plant/per-animal state never lives in this resource.
@export_range(0, 1) var pest_chance: float = 0.15
@export_range(0, 1) var weed_chance: float = 0.15
@export_range(0, 1) var pest_yield: float = 0.8
@export_range(0, 1) var weed_yield: float = 0.85
@export_range(0.01, 1) var sick_production_rate: float = 0.5
@export_range(0.001, 0.99) var disease_chance: float = 0.05
@export_range(1, 86400) var disease_check_seconds: float = 600.0
@export_range(0, 86400) var protection_seconds: float = 300.0
