class_name HotbarSlotView
extends Control

@export_range(0, 10, 1) var slot_number: int = 1

@onready var item_view: InventoryItemView = $ItemView
@onready var selection_border: Panel = $SelectionBorder
@onready var shortcut_label: Label = $ShortcutLabel

func _ready() -> void:
    shortcut_label.text = str(slot_number % 10)

func set_selected(value: bool) -> void:
    selection_border.visible = value

func set_item(definition: ItemDefinition, amount: int) -> void:
    item_view.set_item(definition, amount)

func setup(inventory_component: InventoryComponent, index: int) -> void:
    item_view.inventory = inventory_component
    item_view.slot_index = index
    item_view.drag_enabled = true
