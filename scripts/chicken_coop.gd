class_name ChickenCoop
extends Node2D

@export_range(0.1, 10.0) var needs_tick_seconds: float = 1.0
var _needs_components: Array[AnimalNeedsComponent] = []
var _elapsed: float = 0.0

func _ready() -> void:
	_collect_needs_components(self)

func _collect_needs_components(node: Node) -> void:
	for child in node.get_children():
		if child is AnimalNeedsComponent:
			register_needs(child)
		
		_collect_needs_components(child)

func register_needs(needs: AnimalNeedsComponent) -> void:
	if not is_instance_valid(needs):
		return
		
	if not needs.is_initialized():
		return
	
	if _needs_components.has(needs):
		return
		
	_needs_components.append(needs)

func _process(delta: float) -> void:
	_elapsed += delta
	
	if _elapsed < needs_tick_seconds:
		return
		
	var elapsed_seconds := _elapsed
	_elapsed = 0
	
	for index in range(_needs_components.size() -1, -1, -1):
		var needs := _needs_components[index]
		
		if not is_instance_valid(needs):
			_needs_components.remove_at(index)
			continue
			
		needs.advance_time(elapsed_seconds)
