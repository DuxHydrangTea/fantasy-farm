class_name Player
extends CharacterBase

# if you want to define _ready(), you must have to call super._ready()

@onready var tool_state: ToolState = $StateMachine/ToolState
@export var farm_land: FarmLand
@export var tool_reach: float = 16.0
@export var hotbar: Hotbar
@export var inventory: Inventory
@export var inventory_panel: InventoryPanel

var focused_plot: FarmPlot
var _target_plot: FarmPlot
var _pending_slot: ItemSlot
var _pending_item: ItemDefinition

func _ready() -> void:
	super._ready()
	tool_state.effect_requested.connect(_on_tool_effect_requested)
	assert(is_instance_valid(inventory_panel), "Player chưa được gán inventory panel")

func _process(_delta: float) -> void:
	if state_machine.current_state is ToolState:
		return
	
	var next_plot: FarmPlot = null
	
	if is_instance_valid(farm_land):
		var target_position = (
			global_position 
			+ animation_component.facing_vector * tool_reach	
		)
		next_plot = farm_land.get_plot_at_world(target_position)
	
	set_focused_plot(next_plot)
		

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

func set_focused_plot(next_plot: FarmPlot) -> void:
	if is_instance_valid(focused_plot) and focused_plot == next_plot:
		return
		
	if is_instance_valid(focused_plot):
		focused_plot.set_focused(false)
	
	focused_plot = next_plot
	
	if is_instance_valid(focused_plot):
		focused_plot.set_focused(true)

func _on_tool_effect_requested(action: String) -> void:
	if _pending_item == null:
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
	
	if action == "water":
		_target_plot.water()
	
func use_selected_item() -> void:
	if is_inventory_open():
		return

	if not (state_machine.current_state is IdleState or state_machine.current_state is WalkState):
		return
		
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
	
	match item.item_type:
		ItemDefinition.ItemType.TOOL:
			match item.tool_type:
				ItemDefinition.ToolType.HOE:
					action = "tool"
				ItemDefinition.ToolType.WATERING_CAN:
					if not is_instance_valid(focused_plot):
						return
					
					action = "water"
					target_plot = focused_plot
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
		
		_:
			return
	_pending_slot = slot
	_pending_item = item
	_target_plot = target_plot
	
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
		
	var added: bool = inventory.try_add_item(
		defination.harvest_item,
		defination.harvest_amount
	)
	
	if not added:
		print("Slot không đủ chỗ!")
		return false
		
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
