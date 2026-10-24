extends GutTest
var progress: TutorialProgress

func before_each() -> void:
	progress = TutorialProgress.new()

func after_each() -> void:
	Language.set_language("en")

func test_seen_skip_toggle_restore_are_preferences_without_objective_counts() -> void:
	assert_true(TutorialSaveSchema.valid(progress.capture()))
	progress.mark_seen("first_soil")
	progress.mark_seen("first_soil")
	progress.mark_seen("unknown")
	assert_eq(progress.capture().seen, ["first_soil"])
	progress.skip()
	var saved: Dictionary = progress.capture()
	assert_true(saved.skipped)
	assert_false(saved.enabled)
	progress.set_enabled(true)
	assert_false(progress.capture().skipped)
	assert_true(progress.seen("first_soil"))
	assert_true(progress.restore(saved))
	assert_eq(progress.capture(), saved)

func test_schema_rejects_unknown_duplicate_and_wrong_types_without_mutation() -> void:
	var before: Dictionary = progress.capture()
	for key: String in ["enabled", "skipped", "support_used"]:
		var bad: Dictionary = before.duplicate(true)
		bad[key] = 1
		assert_false(progress.restore(bad))
	for seen: Variant in [["unknown"], ["first_soil", "first_soil"], [1], "first_soil"]:
		var bad: Dictionary = before.duplicate(true)
		bad.seen = seen
		assert_false(progress.restore(bad))
	var bad: Dictionary = before.duplicate(true)
	bad.skipped = true
	assert_false(progress.restore(bad))
	assert_eq(progress.capture(), before)

func test_single_seed_support_is_atomic_reentrant_and_persisted() -> void:
	var bag: InventoryComponent = autofree(InventoryComponent.new()) as InventoryComponent
	var attempts: Array = []
	bag.changed.connect(func() -> void:
		assert_true(progress.capture().support_used)
		assert_eq(bag.count_item(StarterSupport.SEED.item_id), 1)
		attempts.append(progress.grant_support(bag, StarterSupport.SEED))
	)
	assert_true(progress.grant_support(bag, StarterSupport.SEED))
	assert_false(progress.grant_support(bag, StarterSupport.SEED))
	assert_eq(attempts, [false])
	var loaded: TutorialProgress = TutorialProgress.new()
	assert_true(loaded.restore(JSON.parse_string(JSON.stringify(progress.capture()))))
	assert_false(loaded.grant_support(bag, StarterSupport.SEED))
	assert_eq(bag.count_item(StarterSupport.SEED.item_id), 1)

func test_all_objectives_have_short_and_full_instructions() -> void:
	for definition: ObjectiveDefinition in ObjectiveProgress.DEFAULT_CATALOG.steps:
		assert_true(GuideContent.SHORT.has(String(definition.objective_id)))
		assert_true(GuideContent.DETAILS.has(String(definition.objective_id)))
	Language.set_language("vi")
	for text: String in GuideContent.SHORT.values() + GuideContent.DETAILS.values():
		assert_ne(tr(text), text)
	for title: String in GuideContent.TOPICS:
		assert_ne(tr(title), title)
	assert_ne(tr(GuideContent.controls(true)), GuideContent.controls(true))
	assert_ne(tr(GuideContent.controls(false)), GuideContent.controls(false))
