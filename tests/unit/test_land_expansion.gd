extends GutTest
var state: LandExpansionState
var wallet: WalletComponent

func before_each() -> void:
	state = LandExpansionState.new()
	state.restore_columns(1) # Historic profile fixture; fresh defaults are tested separately.
	wallet = WalletComponent.new()
	add_child_autofree(wallet)

func test_initial_right_column_and_every_grid_cell() -> void:
	var count: int = 0
	for y: int in range(19, 53):
		for x: int in range(9, 57):
			if state.is_unlocked(Vector2i(x, y)):
				count += 1
	assert_eq(count, 34)
	assert_eq(state.next_column(), 55)
	assert_eq(state.next_price(), 60000)
	assert_true(state.is_unlocked(Vector2i(80, 20)), "Other regions retain their own rules")

func test_insufficient_funds_and_stale_confirmation_do_not_mutate() -> void:
	assert_false(state.purchase(wallet, 1).ok)
	assert_eq(wallet.balance, WalletComponent.STARTING_COINS)
	wallet.set_balance(100000)
	assert_false(state.purchase(wallet, 2).ok)
	assert_eq(wallet.balance, 100000)
	assert_eq(state.unlocked_columns, 1)

func test_purchase_is_atomic_and_reentrant_signals_cannot_double_charge() -> void:
	wallet.set_balance(100000)
	var attempts: Array[Dictionary] = []
	wallet.changed.connect(func(_coins: int) -> void:
		assert_eq(state.unlocked_columns, 2)
		attempts.append(state.purchase(wallet, 2))
		assert_false(state.restore_columns(48))
	)
	assert_true(state.purchase(wallet, 1).ok)
	assert_eq(wallet.balance, 40000)
	assert_eq(attempts.size(), 1)
	assert_false(attempts[0].ok)
	assert_true(state.is_unlocked(Vector2i(55, 52)))
	assert_false(state.is_unlocked(Vector2i(54, 19)))

func test_all_47_purchases_cover_exact_rectangle_and_price_curve() -> void:
	wallet.set_balance(WalletComponent.MAX_COINS)
	var total: int = 0
	var previous: int = 0
	for c: int in range(1, 48):
		assert_gt(state.next_price(), previous)
		previous = state.next_price()
		total += previous
		assert_eq(state.purchase(wallet, c).column, 56 - c)
	assert_eq(state.unlocked_columns, 48)
	assert_true(state.is_complete())
	assert_eq(state.next_price(), 0)
	assert_eq(wallet.balance, WalletComponent.MAX_COINS - total)
	assert_false(state.purchase(wallet, 48).ok)
	for cell: Vector2i in [Vector2i(9, 19), Vector2i(9, 52), Vector2i(56, 52)]:
		assert_true(state.is_unlocked(cell))

func test_restore_rejects_invalid_column_counts() -> void:
	assert_false(state.restore_columns(0))
	assert_false(state.restore_columns(49))
	assert_true(state.restore_columns(7))
	assert_true(state.is_unlocked(Vector2i(50, 19)))
	assert_false(state.is_unlocked(Vector2i(49, 19)))

func test_fresh_four_columns_keep_first_three_purchase_prices() -> void:
	var fresh: LandExpansionState = LandExpansionState.new()
	assert_eq(fresh.unlocked_columns, 4)
	assert_eq(fresh.starting_columns, 4)
	wallet.set_balance(WalletComponent.MAX_COINS)
	for price: int in [60000, 150000, 350000]:
		assert_eq(fresh.next_price(), price)
		assert_true(fresh.purchase(wallet, fresh.unlocked_columns).ok)
	assert_eq(fresh.unlocked_columns, 7)
	assert_eq(fresh.starting_columns, 4)
	assert_false(fresh.restore_columns(3, 4))
