class_name WorkerBoard
extends ShopMerchant
@export_enum("orchard", "ranch", "crop") var role: String = "orchard"
@export var worker_access: bool = false
var worker_id: String = ""

func _enter_tree() -> void:
	create_shop_ui = false
	super._enter_tree()
	if menu is WorkerMenu:
		return
	menu = preload("res://scenes/ui/workers.tscn").instantiate() as WorkerMenu
	(menu as WorkerMenu).role = role
	(menu as WorkerMenu).selected_worker_id = worker_id
	add_child(menu)

func _ready() -> void:
	super._ready()
	if worker_access:
		get_node("Sprite2D").hide()
		(get_node("CollisionShape2D") as CollisionShape2D).disabled = true
	else:
		var label: Label = Label.new()
		label.text = tr("Hire workers")
		label.position = Vector2(-20, -44)
		label.scale = Vector2(0.4, 0.4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

func interaction_sprite() -> Node2D:
	if worker_access and get_parent() is WorkerActor:
		return (get_parent() as WorkerActor).sprite
	return super.interaction_sprite()
