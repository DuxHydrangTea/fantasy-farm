extends GutTest

var selection: ToolSelectionComponent

func before_each() -> void:
	selection = ToolSelectionComponent.new()
	add_child_autofree(selection)

func test_default_selection_is_empty_hands() -> void:
	assert_eq(selection.selected_index, -1)
	assert_null(selection.get_selected_item())
	assert_eq(selection.get_selected_action(), &"")

func test_selection_changes_tool_and_emits_once() -> void:
	watch_signals(selection)
	assert_true(selection.select_slot(1))
	assert_eq(selection.get_selected_action(), &"water")
	assert_signal_emitted_with_parameters(selection, "selection_changed", [1, &"watering_can"])
	selection.select_slot(1)
	assert_signal_emit_count(selection, "selection_changed", 1)

func test_invalid_slot_does_not_change_selection() -> void:
	assert_false(selection.select_slot(-2))
	assert_false(selection.select_slot(6))
	assert_eq(selection.selected_index, -1)

func test_empty_slot_has_no_action() -> void:
	selection.select_slot(2)
	assert_eq(selection.get_selected_action(), &"")
	assert_eq(selection.get_selected_name(), tr("Empty slot"))

func test_cycle_selection_wraps_indices() -> void:
	selection.cycle_selection(-1)
	assert_eq(selection.selected_index, 5)
	selection.cycle_selection(1)
	assert_eq(selection.selected_index, 0)

func test_toggle_clears_item_action_and_emits_once() -> void:
	selection.select_slot(0)
	watch_signals(selection)
	assert_true(selection.toggle_slot(0))
	assert_eq(selection.selected_index, -1)
	assert_eq(selection.get_selected_action(), &"")
	assert_signal_emitted_with_parameters(selection, "selection_changed", [-1, &""])
	selection.select_slot(-1)
	assert_signal_emit_count(selection, "selection_changed", 1)
	assert_true(selection.toggle_slot(0))
	assert_eq(selection.get_selected_action(), &"tool")
