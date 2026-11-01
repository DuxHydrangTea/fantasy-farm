class_name WorkerBoard
extends ShopMerchant
@export_enum("crop") var role: String = "crop"
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

func interaction_action_text() -> String:
	if worker_access and get_parent() is WorkerActor:
		var actor: WorkerActor = get_parent() as WorkerActor
		var row: Dictionary = actor.worker_service.record_for(worker_id)
		if not row.is_empty():
			var title: String = tr("Worker #{number}").format({"number": actor.worker_service.worker_number(worker_id)})
			var state: String = tr("Resting") if not actor.worker_service.running(row) else tr(WorkerRole.task_caption(row.task, actor.global_position))
			return title + " · " + state
	return super.interaction_action_text()
