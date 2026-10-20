class_name ToolSelectionComponent
extends Node

signal selection_changed(index: int, tool: StringName)
signal inventory_visibility_changed(open: bool)
signal shop_visibility_changed(open: bool)

const HOTBAR_SIZE: int = 6
@export var inventory: InventoryComponent
@export var starting_seeds: Array[ItemDefinition] = []
@export var starting_feed: ItemDefinition
@export_range(0, 99) var starting_feed_amount: int = 5
@export_range(1, 99) var starting_seed_amount: int = 12
var selected_index: int = 0
var inventory_open: bool = false
var shop_open: bool = false

func _ready() -> void:
	if inventory == null:
		inventory = InventoryComponent.new()
		inventory.name = "Inventory"
		add_child(inventory)
		for seed_item: ItemDefinition in starting_seeds:
			inventory.add(seed_item, starting_seed_amount)
		if starting_feed != null:
			inventory.add(starting_feed, starting_feed_amount)
	inventory.changed.connect(_on_inventory_changed)

func set_inventory_open(open: bool) -> void:
	if open and shop_open:
		return
	if open != inventory_open:
		inventory_open = open
		inventory_visibility_changed.emit(open)

func set_shop_open(open: bool) -> void:
	if open and inventory_open:
		return
	if shop_open != open:
		shop_open = open
		shop_visibility_changed.emit(open)

func is_menu_open() -> bool:
	return inventory_open or shop_open

func get_selected_item() -> ItemDefinition:
	return inventory.get_slot_item(selected_index) if inventory != null else null

func _on_inventory_changed() -> void:
	var item: ItemDefinition = get_selected_item()
	selection_changed.emit(selected_index, item.item_id if item != null else &"")

func select_slot(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SIZE:
		return false
	if index != selected_index:
		selected_index = index
		_on_inventory_changed()
	return true

func cycle_selection(step: int) -> void:
	select_slot(posmod(selected_index + step, HOTBAR_SIZE))

func get_selected_action() -> StringName:
	var item: ItemDefinition = get_selected_item()
	if item != null and item.item_type == ItemDefinition.ItemType.SEED:
		return &"plant"
	if item != null and (item.item_type == ItemDefinition.ItemType.TOOL or item.item_type == ItemDefinition.ItemType.HOE):
		return &"water" if item.tool_type == ItemDefinition.ToolType.WATERING_CAN else &"tool"
	return &""

func get_selected_name() -> String:
	var item: ItemDefinition = get_selected_item()
	return item.display_name if item != null else "Ô trống"
