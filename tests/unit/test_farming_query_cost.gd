extends GutTest
## Reject impossible soil actions before an expensive world/physics query.
class ProbeFarm extends FarmingController:
	var soil: Soil = Soil.WET
	var permission: bool = true
	var physics_checks: int = 0
	func get_soil_state(_cell: Vector2i) -> Soil:
		return soil
	func _allowed(_cell: Vector2i, _permission: StringName, _actor: PhysicsBody2D) -> bool:
		physics_checks += 1
		return permission

func test_wet_field_does_not_query_physics_for_watering() -> void:
	var farm: ProbeFarm = ProbeFarm.new()
	add_child_autofree(farm)
	farm.set_process(false)
	for x: int in range(400):
		assert_false(farm.can_water(Vector2i(x, 0)))
	assert_eq(farm.physics_checks, 0)
	farm.soil = FarmingController.Soil.DRY
	assert_true(farm.can_water(Vector2i.ZERO))
	assert_eq(farm.physics_checks, 1)
	farm.permission = false
	assert_false(farm.can_water(Vector2i.ZERO), "Dry soil still requires the real permission/collision check")

func test_tilling_and_planting_preserve_soil_and_permission_rules() -> void:
	var farm: ProbeFarm = ProbeFarm.new()
	add_child_autofree(farm)
	farm.set_process(false)
	assert_false(farm.can_till(Vector2i.ZERO))
	assert_eq(farm.physics_checks, 0)
	farm.soil = FarmingController.Soil.UNTILLED
	assert_false(farm.can_plant(Vector2i.ZERO))
	assert_eq(farm.physics_checks, 0)
	assert_true(farm.can_till(Vector2i.ZERO))
	farm.permission = false
	assert_false(farm.can_till(Vector2i.ZERO))
	farm.soil = FarmingController.Soil.DRY
	assert_false(farm.can_plant(Vector2i.ZERO))
	farm.permission = true
	assert_true(farm.can_plant(Vector2i.ZERO))
