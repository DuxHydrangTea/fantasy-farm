extends Node2D

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var satiety_display: ProgressBarDisplay = $VBoxContainer/SatietyDisplay
@onready var hyration_display: ProgressBarDisplay = $VBoxContainer/ProgressBarDisplay

var _needs: AnimalNeedsComponent
var _action_text: String = "Đứng nghỉ"

func setup(
	needs: AnimalNeedsComponent,
	machine: StateMachine
) -> void:
	_needs = needs
	needs.needs_changed.connect(_on_needs_changed)
	machine.state_changed.connect(_on_state_changed)
	_on_needs_changed(needs.satiety, needs.hydration)
	_on_state_changed(null, machine.current_state)

func _on_needs_changed(satiety: float, hyration: float) -> void:
	print(" Satiety: %f, Hydration: %f " % [satiety, hyration])
	satiety_display.progress_value = satiety
	hyration_display.progress_value = hyration
	_refresh_status()
	
func _on_state_changed(_from: State, to: State) -> void:
	if to == null:
		_action_text = "Đứng nghỉ"
	else:
		match str(to.name):
			"IdleState":
				_action_text = "Đứng nghỉ"
			"WalkState":
				_action_text = "Đi dạo"
			"PeckState":
				_action_text = "Mổ đất"
			"RestState":
				_action_text = "Nghỉ ngơi"
			"SleepState":
				_action_text = "Đang ngủ"
			_:
				_action_text = "Đứng nghỉ"
			
	_refresh_status()

func _refresh_status() -> void:
	if _needs.is_hungry() and _needs.is_thirsty():
		status_label.text = "Đói và khát"
	elif _needs.is_hungry():
		status_label.text = "Đói"
	elif _needs.is_thirsty():
		status_label.text = "Khát"
	else:
		status_label.text = _action_text
