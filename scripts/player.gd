class_name Player
extends CharacterBase

# if you want to define _ready(), you must have to call super._ready()

@onready var tool_state: ToolState = $StateMachine/ToolState
@onready var interaction_focus: InteractionFocusComponent = $InteractionFocusComponent

@export var hotbar: Hotbar
@export var inventory: Inventory
@export var inventory_panel: InventoryPanel
@export_range(1, 32000) var trough_refill_amount: int = 100
@export var inventory_button: BaseButton

var focused_plot: FarmPlot
var _target_plot: FarmPlot
var _pending_slot: ItemSlot
var _pending_item: ItemDefinition
var _target_water_trough: WaterTrough
var _target_feed_trough: FeedTrough

func _ready() -> void:
	super._ready()
	tool_state.effect_requested.connect(_on_tool_effect_requested)
	if is_instance_valid(inventory_button):
		inventory_button.pressed.connect(_on_inventory_button_pressed)
	assert(is_instance_valid(inventory_panel), "Player chưa được gán inventory panel")

func _process(_delta: float) -> void:
	if state_machine.current_state is ToolState:
		return
	
	focused_plot = interaction_focus.get_focused_target() as FarmPlot
		

func _physics_process(_delta: float) -> void:
	interaction_focus.active = not is_inventory_open()
	interaction_focus.locked = state_machine.current_state is ToolState

func use_tool(action: String) -> void:
	if not (state_machine.current_state is IdleState or state_machine.current_state is WalkState):
		return

	_target_plot = null
	
	if action == "water":
		if not is_instance_valid(focused_plot):
			return
		
		_target_plot = focused_plot
	tool_state.action = action
	state_machine.change_state(&"tool")

func _on_tool_effect_requested(action: String) -> void:
	if _pending_item == null:
		return
		
	if _pending_item.item_type == ItemDefinition.ItemType.FEED:
		if action != "tool":
			return
		_apply_feed_effect()
		return
	
	if action == "water":
		if _pending_item.item_type != ItemDefinition.ItemType.TOOL:
			return
			
		if _pending_item.tool_type != ItemDefinition.ToolType.WATERING_CAN:
			return
		
		if is_instance_valid(_target_water_trough):
			var added := _target_water_trough.add_water(trough_refill_amount)
			print("Đã thêm nước vào máng: ", added)
			return
		
		if is_instance_valid(_target_plot):
			_target_plot.water()
		return

	if not is_instance_valid(_target_plot):
		return
		
	if _pending_item.item_type == ItemDefinition.ItemType.SEED:
		if action != "tool":
			return
		
		if _pending_slot == null or _pending_slot.is_empty():
			return
		
		if _pending_slot.item != _pending_item:
			return
			
		var planted := _target_plot.plant(_pending_item.crop)
		
		if planted:
			_pending_slot.consume_seed(1)
		return
	
func use_selected_item() -> void:
	if is_inventory_open():
		return

	if not (state_machine.current_state is IdleState or state_machine.current_state is WalkState):
		return

	# Chốt một mục tiêu cho toàn bộ thao tác trước khi chạy animation.
	var focused_target := _get_focused_interaction_target()
	focused_plot = focused_target as FarmPlot
		
	if is_instance_valid(focused_plot):
		if focused_plot.is_mature():
			_try_harvest_focused_plot()
			return
	
	if not is_instance_valid(hotbar):
		return
		
	var slot := hotbar.get_selected_slot()
	
	if slot == null or slot.is_empty():
		return
		
	var item := slot.item
	var action: String
	var target_plot: FarmPlot = null
	var target_water_trough: WaterTrough = null
	var target_feed_trough: FeedTrough = null
	
	match item.item_type:
		ItemDefinition.ItemType.TOOL:
			match item.tool_type:
				ItemDefinition.ToolType.HOE:
					action = "tool"
				ItemDefinition.ToolType.WATERING_CAN:
					target_water_trough = focused_target as WaterTrough

					if is_instance_valid(target_water_trough):
						if target_water_trough.get_free_capacity() == 0:
							return
					else:
						if not is_instance_valid(focused_plot):
							return
							
						target_plot = focused_plot
					action = "water"
				_:
					return
		ItemDefinition.ItemType.SEED:
			if not is_instance_valid(focused_plot):
				return
			
			if focused_plot.has_crop():
				return
			
			if item.crop == null:
				return
			
			if not item.crop.is_valid():
				return
				
			action = "tool"
			target_plot = focused_plot
		ItemDefinition.ItemType.FEED:
			if item.food_units_per_item <= 0:
				return
			
			target_feed_trough = focused_target as FeedTrough
			
			if not is_instance_valid(target_feed_trough):
				return
			
			if target_feed_trough.get_free_capacity() == 0:
				return
			action = "tool"
		_:
			return
	_pending_slot = slot
	_pending_item = item
	_target_plot = target_plot
	_target_water_trough = target_water_trough
	_target_feed_trough = target_feed_trough

	tool_state.action = action
	state_machine.change_state(&"tool")
	
func _try_harvest_focused_plot() -> bool:
	if not is_instance_valid(focused_plot):
		return false
	
	if not focused_plot.is_mature():
		return false
		
	if not is_instance_valid(inventory):
		return false
		
	var defination: CropDefinition = focused_plot.crop
	
	if defination == null:
		return false
	
	if not defination.has_valid_harvest():
		push_warning("Cây chưa có cấu hình thu hoạch hợp lệ!")
		return false
		
	var remaining: int = inventory.add_item(
		defination.harvest_item,
		defination.harvest_amount
	)
	if remaining == defination.harvest_amount:
		print("Thêm thất bại, có thể inventory đã đầy!")
		return false
	elif remaining > 0:
		print("Slot không đủ chỗ, phần còn thừa bị tiêu biến!")
		return focused_plot.harvest()
	
	return focused_plot.harvest()

func is_inventory_open() -> bool:
	return inventory_panel.visible
	
func toggle_inventory() -> void:
	if not is_inventory_open():
		if not (
			state_machine.current_state is IdleState
			or state_machine.current_state is WalkState
		):
			return
	
	inventory_panel.toggle()
	
	if is_inventory_open():
		movement_vector = Vector2.ZERO

func select_hotbar_slot(index) -> void:
	if is_inventory_open():
		return
	
	if not is_instance_valid(hotbar):
		return
		
	hotbar.select_slot(index)

func _get_focused_interaction_target() -> Node2D:
	interaction_focus.refresh_focus()
	return interaction_focus.get_focused_target()

func _on_inventory_button_pressed() -> void:
	toggle_inventory()

func _apply_feed_effect() -> void:
	if not is_instance_valid(_target_feed_trough):
		return
		
	if _pending_slot == null or _pending_slot.is_empty():
		return
		
	if _pending_slot.item != _pending_item:
		return
		
	var food_units := _pending_item.food_units_per_item
	
	if food_units <= 0:
		return
	 
	var amount_to_add := mini(
		food_units,
		_target_feed_trough.get_free_capacity()
	)
	
	if amount_to_add <= 0:
		return
		
	if not _pending_slot.consume(1):
		return
		
	var added := _target_feed_trough.add_food(amount_to_add)
	print("Đã dùng 1 bao, nạp ", added, " đơn vị thức ăn")
	
