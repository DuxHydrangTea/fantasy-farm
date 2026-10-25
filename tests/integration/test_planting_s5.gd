extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var garden: FlowerGarden
var service: HoneyGardenSystem
var now: float
var clock: Array[float]
var original_clock: Callable
var original_floor: float

func before_each() -> void:
	original_clock = TimeManager.clock_source
	original_floor = TimeManager._last_timestamp
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12,4)
	world.starter_content.begin_restore(true)
	world.starter_content.finish_restore()
	world.player.wallet.set_balance(1000000)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	now = world.farming.time_manager.now()
	clock = [now]
	var manual: Array[float] = clock
	world.farming.time_manager.clock_source = func() -> float: return manual[0]
	garden = world.apiary.gardens[0]
	service = world.honey_garden
	for pot: FlowerPot in garden.pots.values():
		pot.clear()

func after_each() -> void:
	TimeManager.clock_source = original_clock
	TimeManager._last_timestamp = original_floor

func _cell(fertile: bool) -> Vector2i:
	for y: int in range(19,53):
		for x: int in range(45,57):
			var cell: Vector2i = Vector2i(x,y)
			if world.farming.fertility.is_fertile(cell) == fertile:
				return cell
	return Vector2i.ZERO

func _ripe(cell: Vector2i, tier: int = 1) -> Crop:
	var seed: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
	world.farming.restore_crop(cell,seed.crop as CropDefinition,now-120,now-1,1.0,now,false,0,true,tier==2)
	return world.farming.get_crop(cell)

func test_layout_distribution_is_stable_per_cell_and_not_entire_columns() -> void:
	var fertile: int = 0
	for x: int in range(9,57):
		var column: int = 0
		for y: int in range(19,53):
			if world.farming.fertility.is_fertile(Vector2i(x,y)):
				column += 1
		fertile += column
		assert_gt(column,0)
		assert_lt(column,34)
	assert_between(float(fertile)/1632.0,0.15,0.20)
	assert_false(world.farming.fertility.is_fertile(Vector2i.ZERO))
	assert_false(FertileSoil.valid_version(99))
	var first: bool = world.farming.fertility.is_fertile(Vector2i(50,20))
	world.farming.fertility.layout_version = 1
	assert_eq(world.farming.fertility.is_fertile(Vector2i(50,20)),first)

func test_yield_uses_rounding_without_changing_quality_and_warehouse_capacity_is_atomic() -> void:
	var cell: Vector2i = _cell(true)
	assert_eq(world.farming.fertility.amount(cell,1),2)
	assert_eq(world.farming.fertility.amount(cell,4),6)
	var crop: Crop = _ripe(cell,2)
	var amount: int = world.farming.harvest_amount(cell)
	var produce: ItemDefinition = crop.definition.harvest_item
	assert_eq(crop.harvest_tier(),2)
	var output: InventoryComponent = world.storages.inventory("produce_warehouse")
	assert_true(world.farming.harvest(cell,output))
	assert_eq(output.count_item(produce.item_id,2),amount)
	assert_eq(output.count_item(produce.item_id,0),0)
	assert_eq(world.farming.harvest_amount(cell),0)
	crop = _ripe(cell)
	var tiny: InventoryComponent = InventoryComponent.new()
	tiny.starting_tools = false
	tiny.slot_count = 1
	tiny.stack_cap = amount-1
	add_child_autofree(tiny)
	assert_false(world.farming.harvest(cell,tiny))
	assert_eq(world.farming.get_crop(cell),crop)
	assert_eq(tiny.count_item(produce.item_id,-1),0)

func test_normal_cell_unchanged_and_layout_save_v31_migrates_once() -> void:
	var cell: Vector2i = _cell(false)
	var crop: Crop = _ripe(cell)
	assert_eq(world.farming.harvest_amount(cell),crop.definition.harvest_amount)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var data: Dictionary = adapter.capture("test",1,now)
	data.version = 31
	data.erase("fertile_layout_version")
	var checked: Dictionary = SaveSchema.validate(data,adapter.catalog)
	assert_true(checked.ok,str(checked.get("error")))
	assert_eq(checked.snapshot.fertile_layout_version,1)
	assert_false(data.has("fertile_layout_version"))
	assert_true(adapter.restore(checked.snapshot,now).ok)
	assert_eq(world.farming.fertility.layout_version,1)
	var bad: Dictionary = checked.snapshot.duplicate(true)
	bad.fertile_layout_version = 2
	assert_false(adapter.restore(bad,now).ok)

func test_perfect_ui_previews_exact_tiers_and_stale_confirmation_stays_disabled() -> void:
	var board: OrderBoard = world.orders
	world.player.global_position = board.global_position+Vector2(0,24)
	var serial: int = int(board.service.capture().slots[0].serial)
	var entry: OrderDefinition = board.service.definition(serial)
	for i: int in range(entry.items.size()):
		world.player.selection.inventory.add(entry.items[i],entry.amounts[i],1)
	assert_true(board.open_board(world.player))
	board.menu._request("perfect")
	assert_false(board.menu.confirm_button.disabled)
	assert_eq(board.menu._pending_plan.rows[0].tiers,[0,entry.amounts[0],0])
	world.player.selection.inventory.consume(entry.items[0].item_id,1,ItemQuality.exact(1))
	assert_true(board.menu.confirm_button.disabled)
	var coins: int = world.player.wallet.balance
	board.menu._confirm()
	assert_eq(world.player.wallet.balance,coins)
	board.menu.close(false)
