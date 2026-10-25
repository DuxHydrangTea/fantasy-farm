extends GutTest
const CATALOG: ToolUpgradeCatalog = preload("res://resources/tools/upgrades.tres")
var state: ToolUpgradeState
var wallet: WalletComponent
var land: LandExpansionState
var service: ToolUpgradeService

func before_each() -> void:
	state = ToolUpgradeState.new()
	wallet = WalletComponent.new()
	add_child_autofree(wallet)
	wallet.set_balance(1000000)
	land = LandExpansionState.new()
	land.restore_columns(7, 4)
	service = ToolUpgradeService.new(state, wallet, land, CATALOG.duplicate(true) as ToolUpgradeCatalog)
	service.profile_ready = true
	service.purchasing_enabled = true

func test_defaults_and_captured_data_are_independent() -> void:
	assert_true(CATALOG.valid())
	for tool: StringName in ToolUpgradeState.TOOLS:
		assert_eq(state.level(tool), 1)
		assert_eq(state.selected_size(tool), 1)
	var copy: Dictionary = state.capture()
	copy.hoe.level = 3
	assert_eq(state.level(&"hoe"), 1)
	assert_eq(ToolUpgradeState.new().capture(), ToolUpgradeState.fresh())
	assert_eq(state.level(&"axe"), 0)

func test_all_tools_upgrade_one_level_autoselect_and_stop_at_maximum() -> void:
	wallet.set_balance(WalletComponent.MAX_COINS)
	land.restore_columns(13, 4)
	for tool: StringName in ToolUpgradeState.TOOLS:
		for current: int in range(1, ToolUpgradeState.MAX_LEVEL):
			var offer: Dictionary = service.quote(tool)
			var balance: int = wallet.balance
			assert_true(service.purchase(tool, current, offer.price).ok)
			assert_eq(wallet.balance, balance - int(offer.price))
			assert_eq(state.level(tool), current + 1)
			assert_eq(state.selected_size(tool), current + 1)
			assert_true(state.select_size(tool, 1))
		assert_true(state.select_size(tool, 6))
		assert_eq(service.purchase(tool, 6, 0).code, "max_level")
	assert_true(state.restore(state.capture()))
	assert_eq(state.selected_size(&"hoe"), 6)

func test_tools_remain_separate_and_selection_cannot_exceed_level() -> void:
	assert_true(service.purchase(&"hoe", 1, 30000).ok)
	assert_eq(state.level(&"watering_can"), 1)
	assert_eq(state.level(&"sowing"), 1)
	assert_false(state.select_size(&"watering_can", 2))
	assert_false(state.select_size(&"axe", 1))
	assert_true(state.select_size(&"hoe", 1))

func test_land_gates_use_each_profiles_initial_column_count() -> void:
	for initial: int in [1, 4]:
		state = ToolUpgradeState.new()
		service.state = state
		land.restore_columns(initial, initial)
		assert_eq(service.quote(&"hoe").code, "land_locked")
		land.restore_columns(initial + 1, initial)
		assert_true(service.purchase(&"hoe", 1, 30000).ok)
		assert_eq(service.quote(&"hoe").code, "land_locked")
		land.restore_columns(initial + 3, initial)
		assert_true(service.purchase(&"hoe", 2, 90000).ok)

func test_insufficient_coins_and_stale_quotes_never_spend() -> void:
	wallet.set_balance(29999)
	assert_eq(service.purchase(&"hoe", 1, 30000).code, "insufficient_coins")
	assert_eq(wallet.balance, 29999)
	assert_eq(state.level(&"hoe"), 1)
	wallet.set_balance(30000)
	assert_eq(service.purchase(&"hoe", 2, 30000).code, "stale_offer")
	assert_eq(service.purchase(&"hoe", 1, 1).code, "stale_offer")
	service.catalog.find(&"hoe", 2).price = 29000
	assert_eq(service.purchase(&"hoe", 1, 30000).code, "stale_offer")
	assert_eq(wallet.balance, 30000)
	assert_true(service.purchase(&"hoe", 1, 29000).ok)
	assert_eq(wallet.balance, 1000)

func test_unready_profile_disabled_feature_and_invalid_catalog_are_rejected() -> void:
	assert_eq(service.quote(&"axe").code, "unknown_tool")
	service.profile_ready = false
	assert_eq(service.quote(&"hoe").code, "unavailable")
	service.profile_ready = true
	service.purchasing_enabled = false
	assert_eq(service.quote(&"hoe").code, "unavailable")
	service.purchasing_enabled = true
	service.catalog.offers[0].price = 0
	assert_eq(service.purchase(&"hoe", 1, 0).code, "invalid_catalog")
	assert_eq(wallet.balance, 1000000)

func test_atomic_notifications_and_reentrant_second_vendor() -> void:
	var other: ToolUpgradeService = ToolUpgradeService.new(state, wallet, land, service.catalog)
	other.profile_ready = true
	other.purchasing_enabled = true
	wallet.changed.connect(func(_balance: int) -> void:
		assert_eq(state.level(&"hoe"), 2)
		assert_eq(state.selected_size(&"hoe"), 2)
		assert_eq(other.purchase(&"hoe", 2, 90000).code, "busy")
		assert_eq(service.purchase(&"watering_can", 1, 30000).code, "busy")
		assert_false(state.restore(ToolUpgradeState.fresh()))
		assert_false(state.select_size(&"hoe", 1)))
	assert_true(service.purchase(&"hoe", 1, 30000).ok)
	assert_eq(wallet.balance, 970000)
	assert_eq(state.level(&"hoe"), 2)
	assert_false(state.is_busy())

func test_strict_schema_and_json_number_normalization() -> void:
	assert_true(ToolUpgradeState.valid(ToolUpgradeState.fresh()))
	var invalid: Array = [null, [], {}, {"hoe": {"level": 1, "selected_size": 1}}]
	for field: String in ["level", "selected_size"]:
		for value: Variant in [0, 7, -1, 1.5, "2", true, NAN, INF]:
			var data: Dictionary = ToolUpgradeState.fresh()
			data.hoe[field] = value
			invalid.append(data)
	var extra: Dictionary = ToolUpgradeState.fresh()
	extra["axe"] = {"level": 1, "selected_size": 1}
	invalid.append(extra)
	var too_large: Dictionary = ToolUpgradeState.fresh()
	too_large.hoe.selected_size = 2
	invalid.append(too_large)
	for value: Variant in invalid:
		assert_false(ToolUpgradeState.valid(value))
	var saved: Dictionary = ToolUpgradeState.fresh()
	saved.hoe = {"level": 3.0, "selected_size": 2.0}
	assert_true(state.restore(saved))
	assert_eq(state.level(&"hoe"), 3)
	assert_eq(state.selected_size(&"hoe"), 2)
