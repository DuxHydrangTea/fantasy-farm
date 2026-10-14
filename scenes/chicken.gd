class_name Chicken
extends CharacterBase

@export var definition: AnimalDefinition

@onready var needs_component: AnimalNeedsComponent = $AnimalNeedsComponent
@onready var status_ui = $AnimalStatusUI

func _ready() -> void:
	super._ready()
	needs_component.need_flags_changed.connect(_on_need_flags_changed)
	
	if not needs_component.initialize(definition):
		return
	
	status_ui.setup(needs_component, state_machine)

func _on_need_flags_changed(hungry: bool, thirsty: bool) -> void:
	print(
		name,
		" | Đói: ", hungry,
		" | Khát: ", thirsty
	)
