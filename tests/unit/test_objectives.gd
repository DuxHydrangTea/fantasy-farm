extends GutTest
var wallet: WalletComponent
var progress: ObjectiveProgress
var state: Dictionary

func before_each() -> void:
	wallet = autofree(WalletComponent.new()) as WalletComponent
	wallet.set_balance(1000)
	state = {&"own_animal": 1, &"land_columns": 2}
	# Counter tests use an action as step one; production's existing-soil state
	# condition is exercised against the real farm in the integration suite.
	var definitions: ObjectiveCatalog = ObjectiveProgress.DEFAULT_CATALOG.duplicate(true) as ObjectiveCatalog
	var rewards: Array[int] = [25, 50, 50, 100, 100, 100, 50, 50, 250]
	for index: int in range(definitions.steps.size()):
		definitions.steps[index].reward_coins = rewards[index]
	definitions.steps[0].condition = &"till"
	definitions.steps[0].state_condition = false
	progress = ObjectiveProgress.new(wallet, func(condition: StringName) -> int: return int(state.get(condition, 0)), definitions)

func after_each() -> void:
	Language.set_language("en")

func test_preferences_round_trip_and_follow_next_goal_after_claim() -> void:
	progress.track("first_soil")
	progress.set_collapsed(true)
	var saved: Dictionary = progress.capture()
	progress.track("first_expansion")
	progress.set_collapsed(false)
	assert_true(progress.restore(saved))
	assert_eq(progress.tracked_index(), 0)
	assert_true(progress.hud_collapsed)
	progress.record(&"till")
	assert_true(progress.claim(&"first_soil").ok)
	assert_eq(progress.tracked_index(), 1)
	progress.track("unknown")
	assert_eq(progress.tracked_index(), 1)
	var invalid: Dictionary = progress.capture()
	invalid.tracked_id = "unknown"
	assert_false(progress.restore(invalid))
	invalid = progress.capture()
	invalid.hud_collapsed = 1
	assert_false(progress.restore(invalid))

func test_definitions_have_vietnamese_titles_and_descriptions() -> void:
	Language.set_language("vi")
	for step: ObjectiveDefinition in progress.catalog.steps:
		assert_ne(tr(step.title), step.title)
		assert_ne(tr(step.description), step.description)

func _finish_current() -> void:
	var step: ObjectiveDefinition = progress.active()
	if step.state_condition:
		progress.refresh_state()
	else:
		progress.record(step.condition, step.required)
	assert_true(progress.claim(step.objective_id).ok)

func test_counts_only_active_matching_events_and_caps_progress_until_claim() -> void:
	progress.record(&"plant", 100)
	progress.record(&"till", -1)
	assert_eq(progress.progress(), 0)
	progress.record(&"till", 1000000000)
	assert_eq(progress.progress(), 1)
	progress.record(&"plant")
	assert_eq(progress.active().objective_id, &"first_soil")
	assert_false(progress.claim(&"first_seed").ok)
	assert_true(progress.claim(&"first_soil").ok)
	assert_eq(progress.active().objective_id, &"first_seed")
	assert_eq(progress.progress(), 0, "Earlier planting does not count retroactively")
	assert_false(progress.claim(&"first_soil").ok)
	assert_eq(wallet.balance, 1025)

func test_all_steps_state_activation_and_exact_total_reward() -> void:
	var reward: int = 0
	for step: ObjectiveDefinition in progress.catalog.steps:
		reward += step.reward_coins
		assert_eq(progress.active(), step)
		if step.state_condition:
			progress.refresh_state()
			assert_true(progress.ready_to_claim(), "Existing ownership counts on activation")
		_finish_current()
	assert_null(progress.active())
	assert_eq(wallet.balance, 1000 + reward)
	assert_true(ObjectiveSaveSchema.valid(progress.capture(), progress.catalog))

func test_reentrant_claim_observers_see_wallet_and_claimed_flags_together() -> void:
	progress.record(&"till")
	var attempts: Array = []
	wallet.changed.connect(func(_balance: int) -> void:
		attempts.append(progress.claim(&"first_soil"))
		assert_true(progress.capture().steps[0].claimed)
		assert_eq(wallet.balance, 1025)
		assert_eq(progress.active().objective_id, &"first_seed")
	)
	assert_true(progress.claim(&"first_soil").ok)
	assert_eq(attempts.size(), 1)
	assert_false(attempts[0].ok)
	assert_eq(wallet.balance, 1025)

func test_full_wallet_retains_pending_reward_then_can_retry() -> void:
	progress.record(&"till")
	wallet.set_balance(WalletComponent.MAX_COINS)
	var before: Dictionary = progress.capture()
	assert_false(progress.claim(&"first_soil").ok)
	assert_eq(progress.capture(), before)
	wallet.set_balance(0)
	assert_true(progress.claim(&"first_soil").ok)
	assert_eq(wallet.balance, 25)

func test_roundtrip_pending_and_claimed_does_not_grant_or_replay_rewards() -> void:
	progress.record(&"till")
	var pending: Dictionary = JSON.parse_string(JSON.stringify(progress.capture()))
	assert_true(progress.restore(pending))
	assert_eq(wallet.balance, 1000)
	assert_true(progress.ready_to_claim())
	assert_true(progress.claim(&"first_soil").ok)
	var claimed: Dictionary = progress.capture()
	assert_true(progress.restore(claimed))
	assert_false(progress.claim(&"first_soil").ok)
	assert_eq(wallet.balance, 1025)
	claimed.steps[0].claimed = false
	assert_true(progress.capture().steps[0].claimed, "Restore takes a deep copy")

func test_validation_rejects_unknown_ids_future_progress_noninteger_and_skipped_claims() -> void:
	var pristine: Dictionary = progress.capture()
	for value: Variant in [-1, 2, 0.5, NAN, INF, "1", true]:
		var bad: Dictionary = pristine.duplicate(true)
		bad.steps[0].progress = value
		assert_false(progress.restore(bad))
	for index: int in [0, 1, 8]:
		var bad: Dictionary = pristine.duplicate(true)
		bad.steps[index].claimed = true
		assert_false(progress.restore(bad))
	var future: Dictionary = pristine.duplicate(true)
	future.steps[1].progress = 1
	assert_false(progress.restore(future))
	future = pristine.duplicate(true)
	future.steps[0].id = "invented_objective"
	assert_false(progress.restore(future))
	assert_false(progress.restore({}))
	assert_eq(progress.capture(), pristine)

func test_suspend_blocks_record_claim_and_state_observation() -> void:
	progress.suspended = true
	progress.record(&"till")
	progress.refresh_state()
	assert_eq(progress.progress(), 0)
	assert_false(progress.claim(&"first_soil").ok)
	progress.suspended = false
	assert_false(progress.ready_to_claim())

func test_partial_progress_roundtrips_without_unlocking_next_step() -> void:
	var custom: ObjectiveCatalog = progress.catalog.duplicate(true) as ObjectiveCatalog
	custom.steps[0].required = 3
	var counter: ObjectiveProgress = ObjectiveProgress.new(wallet, Callable(), custom)
	counter.record(&"till")
	assert_eq(counter.progress(), 1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(counter.capture()))
	assert_true(counter.restore(saved))
	assert_eq(counter.progress(), 1)
	assert_false(counter.claim(&"first_soil").ok)
	counter.record(&"till", 100)
	assert_eq(counter.progress(), 3)
	assert_true(counter.claim(&"first_soil").ok)
	assert_eq(counter.active().objective_id, &"first_seed")
