extends Node
var world: FarmWorld
var clock: FarmClock
var timestamp: float
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures.append(message)
  push_error(message)
func _ready() -> void:
 run.call_deferred()
func run() -> void:
 timestamp = TimeManager.now()
 clock = FarmClock.new()
 clock.clock_source = func() -> float: return timestamp
 add_child(clock)
 clock.set_process(false)
 world = load("res://world/main_world.tscn").instantiate() as FarmWorld
 world.farming.time_manager = clock
 (world.get_node("FlowerGarden") as FlowerGarden).time_manager = clock
 add_child(world)
 world.weather.set_debug_hour(12)
 for value: int in range(1000):
  world.weather.schedule.seed = value
  if world.weather.schedule.weather_at(timestamp) == WeatherSchedule.Weather.SUNNY and world.weather.schedule.weather_at(timestamp + 86400) == WeatherSchedule.Weather.SUNNY:
   break
 var pen: AnimalPen = world.get_node("BarnPen") as AnimalPen
 var first_food: bool = true
 for child: Node in pen.get_children():
  if child is AnimalTrough:
   var trough: AnimalTrough = child as AnimalTrough
   trough.stock = 1200 if trough.kind == AnimalTrough.Kind.WATER else (60 if first_food else 0)
   if trough.kind == AnimalTrough.Kind.FOOD:
    first_food = false
 for index: int in range(4):
  var cow: AnimalActor = load("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
  cow.definition = load("res://animals/definitions/cow.tres") as AnimalDefinition
  cow.initial_age_seconds = 28800 if index < 3 else 0
  cow.persistent_id = StringName("preview_cow_%d" % index)
  cow.pen = pen
  cow.position = Vector2(48 + index * 64, 120)
  cow.needs.time_manager = clock
  pen.add_child(cow)
  cow.needs.restore_state(100, 100, timestamp)
 var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
 var data: Dictionary = adapter.capture("offline_preview", 1, timestamp)
 timestamp += 43200
 check(adapter.restore(data, timestamp).ok, "12-hour restore succeeds")
 var board: PenBoard = pen.get_node("ManagementSign") as PenBoard
 world.player.global_position = board.global_position + Vector2(0, 24)
 world.player.animation.face(Vector2.UP)
 await get_tree().create_timer(0.2).timeout
 check(board.open_board(world.player), "Open real management board")
 var menu: PenDashboard = board.menu
 for language: String in ["en", "vi"]:
  Language.set_language(language)
  for window: Vector2i in [Vector2i(1024, 720), Vector2i(844, 390)]:
   get_tree().root.set_meta(&"touch_layout", window.x == 844)
   get_tree().root.set_meta(&"safe_insets", Vector4(44, 0, 44, 21) if window.x == 844 else Vector4.ZERO)
   DisplayServer.window_set_size(window)
   await get_tree().create_timer(0.3).timeout
   menu.refresh()
   check(menu.cards.size() == 4, "All four cards " + language)
   check(menu.overview.text.contains("0%"), "Empty food reported " + language)
   check(menu.panel.position.x >= 0 and menu.panel.position.y >= 0 and menu.panel.size.x <= menu.root.size.x + 1 and menu.panel.size.y <= menu.root.size.y + 1, "Panel fits " + language)
   for card: AnimalCard in menu.cards.values():
    check(card.food.value == 0, "Offline starvation card " + language)
    check(card.produce.text.contains(card.tr("Needs food")), "Pause reason translated " + language)
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://../pen-offline-" + language + "-" + str(window.x) + ".png")
 print("PEN_OFFLINE_PREVIEW=" + JSON.stringify({"checks": checks, "failures": failures}))
 get_tree().quit(0 if failures.is_empty() else 1)
