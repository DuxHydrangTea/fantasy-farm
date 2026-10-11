@tool
class_name FarmPlot
extends Node2D

@export var dry_texture: Texture2D
@export var wet_texture: Texture2D
@onready var soil_sprite: Sprite2D = $SoilSprite
@onready var crop_sprite: Sprite2D = $CropSprite
@onready var growth_bar: ProgressBar = $CropSprite/GrowthBar
@onready var focus_component: FocusComponent = $FocusComponent

var wet_duration: float = 5.0
var plot_id: StringName
var wet_remaining: float = 0.0 #seconds
var _focused: bool = false
var crop: CropDefinition
var growth_elapsed: float = 0.0
var _normal_progress_fill: StyleBox
var _mature_progress_fill: StyleBoxFlat

func _ready() -> void:
	growth_bar.hide()
	_normal_progress_fill = growth_bar.get_theme_stylebox("fill")
	_mature_progress_fill = StyleBoxFlat.new()
	_mature_progress_fill.bg_color = Color("#34eb4c")
	
	if Engine.is_editor_hint():
		set_process(false)
		return
		
	assert(dry_texture != null, "Chưa gán dry_texture")
	assert(wet_texture != null, "Chưa gán wet_texture")
	focus_component.focus_changed.connect(set_focused)
	
	_refresh_soil()
	_refresh_crop()
	_update_processing()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_wet():
		wet_remaining = maxf(0.0, wet_remaining - _delta)
		if not is_wet():
			_refresh_soil()
		
	if has_crop() and not is_mature():
		growth_elapsed = minf(
			crop.growth_seconds,
			growth_elapsed + _delta
		)
		_refresh_crop()

	_update_processing()
		
func _update_processing() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
		
	var crop_is_growing: bool = has_crop() and not is_mature()
	set_process(crop_is_growing or is_wet())

func _refresh_soil() -> void:
	soil_sprite.texture = wet_texture if is_wet() else dry_texture
	
func is_wet() -> bool:
	return wet_remaining > 0.0
	
func water() -> bool:
	if Engine.is_editor_hint() or is_wet():
		return false
		
	wet_remaining = wet_duration
	
	if has_crop() and not is_mature():
		var growth_bonus: float = crop.growth_seconds * 0.05
		growth_elapsed = minf(
			crop.growth_seconds,
			growth_elapsed + growth_bonus
		)
		_refresh_crop()

	_refresh_soil()
	_update_processing()
	return true
	
func set_focused(value: bool) -> void:
	if _focused == value:
		return
	
	_focused = value
	_refresh_growth_bar()
	
func has_crop() -> bool:
	return crop != null
	
func plant(defination: CropDefinition) -> bool:
	if Engine.is_editor_hint():
		return false
		
	if has_crop():
		return false
	
	if defination == null:
		return false
		
	if not defination.is_valid():
		return false
		
	crop = defination
	growth_elapsed = 0.0
	_refresh_crop()
	_update_processing()
	return true


func is_mature() -> bool:
	if not has_crop():
		return false	
	return growth_elapsed >= crop.growth_seconds
	
func get_stage_index() -> int:
	if not has_crop():
		return -1
	
	if is_mature():
		return 3
	
	var progress: float = growth_elapsed / crop.growth_seconds
	return clamp(int(progress * 3.0), 0, 2)
	
func _refresh_crop() -> void:
	var stage_index: int = get_stage_index()
	
	if stage_index == -1:
		crop_sprite.texture = null
		crop_sprite.visible = false
		_refresh_growth_bar()
		return
		
	var stage_texture: Texture2D = crop.stage_textures[stage_index]
	
	if crop_sprite.texture != stage_texture:
		crop_sprite.texture = stage_texture
	
	crop_sprite.visible = true
	_refresh_growth_bar()

func harvest() -> bool:
	if Engine.is_editor_hint():
		return false
		
	if not is_mature():
		return false
		
	crop = null
	growth_elapsed = 0.0
	_refresh_crop()
	_update_processing()
	return true	

func _refresh_growth_bar() -> void:
	if not _focused or not has_crop():
		growth_bar.hide()
		return
		
	var progress: float = clampf(
		growth_elapsed / crop.growth_seconds,
		0.0,
		1.0
	)

	growth_bar.value = progress * 100
	
	if progress == 1.0:
		growth_bar.add_theme_stylebox_override("fill", _mature_progress_fill)
	else:
		growth_bar.add_theme_stylebox_override("fill", _normal_progress_fill)
	growth_bar.show()
