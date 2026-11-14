extends GutTest
var state: LandExpansionState
var wallet: WalletComponent

func before_each() -> void:
	state = LandExpansionState.new()
	wallet = WalletComponent.new()
	add_child_autofree(wallet)

func test_fresh_profile_opens_only_first_block_and_keeps_paths_accessible() -> void:
	assert_eq(state.unlocked_blocks, 1)
	assert_eq(state.starting_blocks, 1)
	assert_eq(LandExpansionState.block_rect(0), Rect2i(49, 19, 8, 8))
	var count: int = 0
	for y: int in range(19, 53):
		for x: int in range(9, 57):
			var cell: Vector2i = Vector2i(x, y)
			if LandExpansionState.block_index(cell) >= 0 and state.is_unlocked(cell):
				count += 1
	assert_eq(count, 64)
	assert_false(state.is_unlocked(Vector2i(56, 28)))
	assert_true(state.is_unlocked(Vector2i(48, 28)), "Path is always accessible")
	assert_true(state.is_unlocked(Vector2i(80, 20)))

func test_each_purchase_opens_one_whole_block_and_all_24_cover_only_planting_cells() -> void:
	wallet.set_balance(WalletComponent.MAX_COINS)
	var cells: Dictionary = {}
	var previous: int = 0
	for index: int in range(24):
		var block: Rect2i = LandExpansionState.block_rect(index)
		assert_eq(block.size, Vector2i(8, 8))
		for y: int in range(block.position.y, block.end.y):
			for x: int in range(block.position.x, block.end.x):
				var cell: Vector2i = Vector2i(x, y)
				assert_false(cells.has(cell))
				assert_true(state.is_unlocked(cell))
				cells[cell] = true
		if index < 23:
			assert_gt(state.next_price(), previous)
			previous = state.next_price()
			assert_eq(state.purchase(wallet, index + 1).block, index + 1)
	assert_eq(cells.size(), 1536)
	assert_true(state.is_complete())
	assert_eq(state.next_price(), 0)
	assert_false(state.purchase(wallet, 24).ok)

func test_purchase_prices_stale_offer_and_reentrancy() -> void:
	assert_false(state.purchase(wallet, 1).ok)
	wallet.set_balance(WalletComponent.MAX_COINS)
	assert_false(state.purchase(wallet, 2).ok)
	var attempts: Array[Dictionary] = []
	wallet.changed.connect(func(_coins: int) -> void:
		attempts.append(state.purchase(wallet, state.unlocked_blocks))
		assert_false(state.restore_blocks(24))
	)
	for price: int in [60000, 150000, 350000]:
		assert_eq(state.next_price(), price)
		assert_true(state.purchase(wallet, state.unlocked_blocks).ok)
	for attempt: Dictionary in attempts:
		assert_false(attempt.ok)
	assert_eq(state.unlocked_blocks, 4)

func test_restore_and_legacy_conversion_preserve_owned_cells() -> void:
	for invalid: int in [0, -1, 25, 48]:
		assert_false(state.restore_blocks(invalid))
	assert_false(state.restore_blocks(3, 4))
	assert_true(state.restore_blocks(7, 1))
	for columns: int in range(1, 49):
		var blocks: int = LandExpansionState.legacy_block_count(columns)
		assert_true(state.restore_blocks(blocks))
		for y: int in range(19, 53):
			for x: int in range(57 - columns, 57):
				assert_true(state.is_unlocked(LandExpansionState.from_legacy_cell(Vector2i(x, y))))
