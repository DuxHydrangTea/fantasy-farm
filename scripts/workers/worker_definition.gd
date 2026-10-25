class_name WorkerDefinition
extends Resource
## Tunable body/pace constants for one worker role variant. The role itself
## (task scan/actions/offline contribution) lives in WorkerRole strategies.
@export var worker_id: StringName
@export var display_name: String
@export var frames: SpriteFrames
@export_range(20.0, 400.0) var move_speed: float = 120.0
@export_range(0.5, 10.0) var work_seconds: float = 2.0
@export var footprint: Vector2 = Vector2(14.0, 8.0)
## Hướng nhìn gốc của ảnh sprite (AnimationComponent.single_direction_faces_left).
@export var faces_left: bool = true

func is_valid() -> bool:
	return frames != null and worker_id != null and not String(worker_id).is_empty()
