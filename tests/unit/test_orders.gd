extends GutTest
var bag: InventoryComponent
var wallet: WalletComponent
var orders: OrderService
var eligible: Dictionary

func before_each() -> void:
	bag = autofree(InventoryComponent.new()) as InventoryComponent
	wallet = autofree(WalletComponent.new()) as WalletComponent
	wallet.set_balance(1000)
	eligible = {}
	for entry: OrderDefinition in (load("res://resources/orders/legacy_orders_v15.tres") as OrderCatalog).entries:
		eligible[entry.order_id] = true
	orders = OrderService.new(bag, wallet, func(entry: OrderDefinition) -> bool: return bool(eligible.get(entry.order_id, false)), load("res://resources/orders/legacy_orders_v15.tres") as OrderCatalog)
	orders.initialize()

func _first() -> int:
	return int(orders.capture().slots[0].serial)

func _stock(serial: int) -> void:
	var definition: OrderDefinition = orders.definition(serial)
	for index: int in range(definition.items.size()):
		bag.add(definition.items[index], definition.amounts[index])

func test_catalog_is_authored_and_rewards_reference_normal_sales() -> void:
	assert_eq(orders.catalog.entries.size(), 8)
	for entry: OrderDefinition in orders.catalog.entries:
		assert_true(entry.is_valid())
	assert_eq(orders.catalog.find(&"carrot_crate").reward_coins, 72)

func test_atomic_delivery_across_split_stacks_and_reentry() -> void:
	var serial: int = _first()
	var item: ItemDefinition = orders.definition(serial).items[0]
	bag.add(item, 5)
	bag._slots[8] = {"item": item, "count": 10}
	var attempts: Array = []
	bag.changed.connect(func() -> void:
		assert_eq(wallet.balance, 1072)
		assert_eq(bag.count_item(item.item_id), 3)
		assert_null(orders.definition(serial))
		assert_eq(orders.capture().completed, 1)
		attempts.append(orders.deliver(serial))
	)
	assert_true(orders.deliver(serial).ok)
	assert_eq(attempts.size(), 1)
	assert_false(attempts[0].ok)
	assert_false(orders.deliver(serial).ok)
	assert_eq(wallet.balance, 1072)
	assert_true(OrderSaveSchema.valid(orders.capture(), orders.catalog))

func test_missing_items_and_full_wallet_leave_all_state_unchanged() -> void:
	var serial: int = _first()
	var before: Dictionary = orders.capture()
	assert_false(orders.deliver(serial).ok)
	assert_eq(orders.capture(), before)
	_stock(serial)
	wallet.set_balance(WalletComponent.MAX_COINS)
	var count: int = bag.count_item(orders.definition(serial).items[0].item_id)
	assert_false(orders.deliver(serial).ok)
	assert_eq(orders.capture(), before)
	assert_eq(bag.count_item(orders.definition(serial).items[0].item_id), count)
	wallet.set_balance(1000)
	assert_true(orders.deliver(serial).ok)

func test_roundtrip_keeps_instances_and_cursor_and_abandon_has_no_reward() -> void:
	var serial: int = _first()
	var before: Dictionary = orders.capture()
	assert_true(orders.abandon(serial).ok)
	assert_eq(wallet.balance, 1000)
	assert_eq(orders.capture().completed, 0)
	assert_ne(orders.capture().slots[0].serial, serial)
	assert_false(orders.abandon(serial).ok)
	assert_true(orders.restore(before))
	assert_eq(orders.capture(), before)
	assert_true(orders.abandon(serial).ok)
	assert_eq(orders.capture().slots[0].template, "corn_crate")

func test_rotation_skips_unavailable_and_active_templates_and_handles_empty() -> void:
	eligible.clear()
	for row: Dictionary in orders.capture().slots:
		assert_true(orders.abandon(int(row.serial)).ok)
	assert_eq(orders.capture().slots, [{}, {}, {}])
	var saved: Dictionary = orders.capture()
	eligible[&"mixed_bouquet"] = true
	assert_true(orders.restore(saved))
	assert_eq(orders.capture(), saved, "Load must not reroll or refill existing saves")
	orders.fill_empty()
	assert_eq(orders.capture().slots[0].template, "mixed_bouquet")
	assert_true(orders.capture().slots[1].is_empty(), "No duplicate active template")

func test_corrupt_saves_rejected_before_mutation() -> void:
	var before: Dictionary = orders.capture()
	for key: String in ["next_serial", "cursor", "completed"]:
		var bad: Dictionary = before.duplicate(true)
		bad[key] = -1
		assert_false(orders.restore(bad))
	var bad: Dictionary = before.duplicate(true)
	bad.slots[1] = bad.slots[0].duplicate()
	assert_false(orders.restore(bad))
	bad = before.duplicate(true)
	bad.slots[0].template = "res://injected.tres" # lint:ignore res_path -- intentional invalid save input
	assert_false(orders.restore(bad))
	bad = before.duplicate(true)
	bad.slots[0].serial = 1.5
	assert_false(orders.restore(bad))
	assert_eq(orders.capture(), before)

func test_multiple_requirements_are_all_checked_before_any_removal() -> void:
	orders.abandon(_first())
	orders.abandon(_first())
	var serial: int = _first()
	var entry: OrderDefinition = orders.definition(serial)
	assert_eq(entry.items.size(), 2)
	bag.add(entry.items[0], entry.amounts[0])
	assert_false(orders.deliver(serial).ok)
	assert_eq(bag.count_item(entry.items[0].item_id), entry.amounts[0])
	bag.add(entry.items[1], entry.amounts[1])
	assert_true(orders.deliver(serial).ok)
	assert_eq(bag.count_item(entry.items[0].item_id), 0)
	assert_eq(bag.count_item(entry.items[1].item_id), 0)

func test_repeatable_rotation_keeps_three_unique_instances_and_bounded_state() -> void:
	var seen: Dictionary = {}
	for iteration: int in range(40):
		var serial: int = _first()
		seen[orders.definition(serial).order_id] = true
		_stock(serial)
		assert_true(orders.deliver(serial).ok)
		assert_false(orders.deliver(serial).ok)
		assert_eq(orders.capture().completed, iteration + 1)
		assert_true(OrderSaveSchema.valid(orders.capture(), orders.catalog))
	assert_gte(seen.size(), 6)

func test_restore_notifies_once_and_blocks_reentrant_delivery() -> void:
	_stock(_first())
	var saved: Dictionary = orders.capture()
	var callbacks: Array = []
	orders.changed.connect(func() -> void: callbacks.append(orders.deliver(_first())))
	assert_true(orders.restore(saved))
	assert_eq(callbacks.size(), 1)
	assert_false(callbacks[0].ok)
	assert_eq(orders.capture(), saved)
	assert_eq(wallet.balance, 1000)
