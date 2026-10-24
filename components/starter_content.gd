class_name StarterContent
extends RefCounted
## Runtime defaults and one-time garden reward; authored editor previews stay intact.
var world: FarmWorld
var flower_garden_unlocked: bool = false
var _restoring: bool = false

func _init(farm: FarmWorld) -> void:
	world = farm

func prepare() -> void:
	for child: Node in world.get_children():
		if child is PondPen:
			for actor: Node in child.get_children():
				if actor is AnimalActor:
					actor.free()
		if child is FlowerGarden:
			(child as FlowerGarden).starter_content_locked = true

func setup() -> void:
	world.land.state.changed.connect(refresh)
	_apply_lock()
	refresh()

func refresh() -> void:
	if _restoring or flower_garden_unlocked or world.land.state.unlocked_columns <= world.land.state.starting_columns:
		return
	# Commit before adding pickups: inventory/save callbacks must see the reward claimed.
	flower_garden_unlocked = true
	_apply_lock()
	for garden: FlowerGarden in _gardens():
		garden.starter_flowers_added = true
		garden.restore_initial_supplies()

func begin_restore(unlocked: bool) -> void:
	_restoring = true
	flower_garden_unlocked = unlocked
	_apply_lock()

func finish_restore() -> void:
	_restoring = false
	refresh()

func _apply_lock() -> void:
	for garden: FlowerGarden in _gardens():
		garden.set_starter_content_locked(not flower_garden_unlocked)

func _gardens() -> Array[FlowerGarden]:
	var result: Array[FlowerGarden] = []
	for child: Node in world.get_children():
		if child is FlowerGarden:
			result.append(child as FlowerGarden)
	return result
