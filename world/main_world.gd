class_name FarmWorld
extends Node2D
## Node gốc lắp ghép các hệ thống gameplay của trang trại.
##
## Player và FarmingController được gán trong scene. Các hệ thống đất, thời tiết,
## ong và cây được nối khi vào cây; dịch vụ phụ thuộc ví người chơi được tạo
## khi scene sẵn sàng.

## Người chơi trong scene.
@export var player: FarmPlayer
## Bộ điều khiển đất và cây trồng trong scene.
@export var farming: FarmingController
## Hiệu ứng môi trường.
var atmosphere: FarmAtmosphere
## Âm thanh môi trường.
var soundscape: FarmSoundscape
## Mở rộng đất.
var land: LandExpansionComponent
## Hệ thống tổ ong và thụ phấn.
var apiary: ApiarySystem
## Thời tiết và ngày đêm.
var weather: WeatherManager
## Quản lý khu cây lâu năm.
var trees: TreePlantation
## Theo dõi mục tiêu.
var objectives: ObjectiveTracker
## Giao diện mục tiêu.
var objective_ui: ObjectiveUI
## Bảng đơn hàng.
var orders: OrderBoard
## Trạng thái hướng dẫn.
var tutorial: TutorialProgress = TutorialProgress.new()
## Giao diện trợ giúp.
var help_ui: HelpUI
## Gợi ý hướng dẫn theo tiến độ.
var tutorial_hints: TutorialHints
## Các bảng quản lý chuồng đã đăng ký.
var pen_boards: Array[PenBoard] = []
## Dịch vụ nâng cấp khu cây.
var tree_plot_upgrades: TreePlotUpgradeService
## Dịch vụ nâng cấp chuồng.
var pen_upgrades: PenUpgradeService
## Điều phối nội dung khởi đầu.
var starter_content: StarterContent
## Giao diện chọn hạt từ kho.
var seed_picker: FarmSeedPicker
## Dịch vụ kho trang trại.
var storages: FarmStorageService
## Ánh xạ mã kho sang điểm mở kho.
var storage_accesses: Dictionary = {}
## Dịch vụ công nhân.
var workers: WorkerService
## Dịch vụ ghép cây ăn quả.
var grafting: GraftService = GraftService.new()
## Điều phối vườn mật ong.
var honey_garden: HoneyGardenSystem
## Giao diện mật ong.
var honey_menu: HoneyMenu
## Giao diện ghép cây.
var graft_menu: GraftMenu
## Giao diện mua và trồng cây trực tiếp trên ô đất.
var tree_plant_menu: TreePlantMenu
## Hạn mức mua gỗ.
var wood_market: WoodMarket = WoodMarket.new()
## Hàng đợi nấu ăn.
var cooking: ChefCooking = ChefCooking.new()
## Trạng thái nâng cấp công cụ.
var tool_upgrade_state: ToolUpgradeState = ToolUpgradeState.new()
## Dịch vụ mua nâng cấp công cụ.
var tool_upgrades: ToolUpgradeService
## Danh mục giá nâng cấp công cụ.
@export var tool_upgrade_catalog: ToolUpgradeCatalog = preload("res://resources/tools/upgrades.tres")
## Hệ thống cỏ trang trại.
var grass: FarmGrassField
## Bật cỏ GPU khi cấu hình hệ thống cỏ.
@export var gpu_grass_enabled: bool = true
## Bật actor tuần tra thử nghiệm trong bản debug.
@export var debug_worker_enabled: bool = false
## Actor tuần tra thử nghiệm nếu được bật.
var debug_worker: WorkerActor
## Vị trí bảng đơn trong tọa độ thế giới.
@export var order_board_position: Vector2 = Vector2(1664, 248)
## Các điểm đèn cửa sổ và cổng trong tọa độ cục bộ thế giới.
@export var night_light_positions: Array[Vector2] = [Vector2(1350, 308), Vector2(1183, 622), Vector2(1740, 172), Vector2(1666, 622), Vector2(1010, 274), Vector2(1384, 274), Vector2(1480, 274)]

func _enter_tree() -> void:
	assert(player != null and farming != null, "Assign MainWorld player and farming references")
	player.farming_actions.farming = farming

	if is_instance_valid(land):
		return
	preload("res://components/animals/pen_produce_system.gd").new().configure(self)
	starter_content = StarterContent.new(self)
	starter_content.prepare()
	weather = WeatherManager.new()
	weather.world = self
	weather.name = "WeatherManager"
	farming.weather = weather.schedule
	farming.sync_weather = weather.advance
	_wire_weather(self)
	# Typed composition keeps land wiring independent of node names.
	land = LandExpansionComponent.new()
	land.name = "LandExpansion"
	land.farming = farming
	land.player = player
	farming.land = land.state
	add_child(land)
	apiary = ApiarySystem.new()
	apiary.name = "Apiary"
	apiary.world = self
	apiary.farming = farming
	farming.apiary = apiary
	add_child(apiary)
	add_child(weather)
	trees = TreePlantation.new()
	trees.name = "TreePlantation"
	trees.world = self
	farming.trees = trees
	add_child(trees)
	objectives = ObjectiveTracker.new()
	objectives.name = "Objectives"
	objectives.world = self
	add_child(objectives)

func _ready() -> void:
	# Player creates its wallet after the world's _enter_tree; bind once children are ready.
	tool_upgrades = ToolUpgradeService.new(tool_upgrade_state, player.wallet, land.state, tool_upgrade_catalog)
	tool_upgrades.world = self
	tool_upgrades.inventory = player.selection.inventory
	tool_upgrades.purchasing_enabled = true
	pen_upgrades = PenUpgradeService.new(self)
	tree_plot_upgrades = TreePlotUpgradeService.new(self)
	trees.setup_plot_upgrades()
	player.farming_actions.upgrades = tool_upgrade_state
	player.tool_range_ui = ToolRangeUI.new()
	player.tool_range_ui.world = self
	player.tool_range_ui.name = "ToolRangeUI"
	add_child(player.tool_range_ui)
	storages = FarmStorageService.new()
	storages.world = self
	storages.name = "Storages"
	add_child(storages)
	player.selection.storage_service = storages
	seed_picker = FarmSeedPicker.new()
	seed_picker.world = self
	seed_picker.name = "SeedPicker"
	add_child(seed_picker)
	workers = WorkerService.new()
	workers.world = self
	workers.name = "Workers"
	add_child(workers)
	starter_content.setup()
	objectives.setup()
	objective_ui = ObjectiveUI.new()
	objective_ui.name = "ObjectiveUI"
	objective_ui.model = objectives.progress
	objective_ui.selection = player.selection
	add_child(objective_ui)
	orders = OrderBoard.new()
	orders.name = "OrderBoard"
	orders.world = self
	orders.position = order_board_position
	add_child(orders)
	grafting.world = self
	graft_menu = preload("res://scenes/ui/grafting.tscn").instantiate() as GraftMenu
	graft_menu.name = "FruitGrafting"
	graft_menu.world = self
	add_child(graft_menu)
	tree_plant_menu = preload("res://scenes/trees/tree_plant_menu.tscn").instantiate() as TreePlantMenu
	tree_plant_menu.name = "TreePlantMenu"
	tree_plant_menu.world = self
	add_child(tree_plant_menu)
	honey_garden = HoneyGardenSystem.new()
	honey_garden.world = self
	honey_garden.name = "HoneyGarden"
	add_child(honey_garden)
	honey_menu = HoneyMenu.new()
	honey_menu.world = self
	honey_menu.name = "BeeJournal"
	add_child(honey_menu)
	help_ui = HelpUI.new()
	help_ui.name = "HelpUI"
	help_ui.world = self
	add_child(help_ui)
	objective_ui.help_requested.connect(help_ui.open_help)
	tutorial_hints = TutorialHints.new()
	tutorial_hints.name = "TutorialHints"
	tutorial_hints.world = self
	add_child(tutorial_hints)
	for child: Node in get_children():
		if child is AnimalPen:
			for node: Node in child.get_children():
				if node is PenBoard:
					pen_boards.append(node as PenBoard)
	var fertile_overlay: FertileSoilOverlay = FertileSoilOverlay.new()
	fertile_overlay.world = self
	fertile_overlay.name = "FertileSoil"
	add_child(fertile_overlay)
	grass = FarmGrassField.new()
	grass.name = "GPUGrass"
	grass.world = self
	add_child(grass)
	soundscape = FarmSoundscape.new()
	soundscape.world = self
	soundscape.name = "Soundscape"
	add_child(soundscape)
	atmosphere = FarmAtmosphere.new()
	atmosphere.world = self
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	if OS.is_debug_build() and debug_worker_enabled:
		debug_worker = _spawn_debug_orchard_worker()
	if OS.is_debug_build():
		var console: Node = load("res://components/debug/debug_console.gd").new()
		console.set("world", self)
		console.name = "DebugConsole"
		add_child(console)

## Tạo công nhân debug tuần tra quanh khu cây ăn quả để kiểm tra chuyển động.
func _spawn_debug_orchard_worker() -> WorkerActor:
	var worker: WorkerActor = (preload("res://scenes/workers/crop_worker.tscn") as PackedScene).instantiate() as WorkerActor
	worker.name = "OrchardWorkerM0"
	add_child(worker)
	var region: Rect2i = TreePlantation.FRUIT_REGION
	var ground: TileMapLayer = farming.ground
	var corner_a: Vector2 = ground.map_to_local(region.position)
	var corner_b: Vector2 = ground.map_to_local(region.position + region.size)
	var ring: Rect2 = Rect2(corner_a, corner_b - corner_a).grow(-56.0)
	var points: Array[Vector2] = [
		ring.position + Vector2(20, 20),
		Vector2(ring.end.x - 20.0, ring.position.y + 20.0),
		ring.end - Vector2(20, 20),
		Vector2(ring.position.x + 20.0, ring.end.y - 20.0),
	]
	worker.global_position = points[0]
	worker.configure_patrol(points)
	return worker

func _wire_weather(node: Node) -> void:
	if node is AnimalPen:
		(node as AnimalPen).weather = weather.schedule
	for child: Node in node.get_children():
		_wire_weather(child)
