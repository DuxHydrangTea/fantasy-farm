extends Node

signal selection_changed(index: int, tool: StringName)
signal inventory_visibility_changed(open: bool)

const Inventory = preload("res://components/inventory_component.gd")
const Item = preload("res://scripts/item_definition.gd")
const HOTBAR_SIZE: int = 6
@export var inventory: Inventory
@export var starting_seeds: Array[Item] = []
@export var starting_feed: Item
@export_range(0, 99) var starting_feed_amount: int = 5
@export_range(1, 99) var starting_seed_amount: int = 12
var selected_index: int = 0
var inventory_open: bool = false

func _ready() -> void:
	if inventory == null:
		inventory = Inventory.new()
		inventory.name = "Inventory"
		add_child(inventory)
		for seed_item: Item in starting_seeds:
			inventory.add(seed_item, starting_seed_amount)
		if starting_feed != null:
			inventory.add(starting_feed, starting_feed_amount)
	inventory.changed.connect(_on_inventory_changed)

func set_inventory_open(open: bool) -> void:
	if open != inventory_open:
		inventory_open = open
		inventory_visibility_changed.emit(open)

func get_selected_item() -> Item:
	return inventory.slot(selected_index).item if inventory != null else null

func _on_inventory_changed() -> void:
	var item: Item = get_selected_item()
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
	var item: Item = get_selected_item()
	if item != null and item.item_type == Item.ItemType.SEED:
		return &"plant"
	if item != null and (item.item_type == Item.ItemType.TOOL or item.item_type == Item.ItemType.HOE):
		return &"water" if item.tool_type == Item.ToolType.WATERING_CAN else &"tool"
	return &""

func get_selected_name() -> String:
	var item: Item = get_selected_item()
	return item.display_name if item != null else "Ô trống"
