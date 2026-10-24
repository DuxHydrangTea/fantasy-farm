extends Node
var world: FarmWorld
var hive: Beehive
var clock: FarmClock
var checks: int = 0
var failures: Array[String] = []
var yielded: Array[int] = []
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  push_error(label)
func _ready() -> void:
 run.call_deferred()
func show_frame(label: String) -> void:
 world.player.interactions.refresh()
 await get_tree().create_timer(0.25).timeout
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://../honey-" + label + ".png")
 var badge: Control = world.player.interactions.presenter.badge
 var root: Control = world.player.interactions.presenter.root
 check(badge.visible and badge.position.x >= -1 and badge.position.y >= -1 and badge.position.x + badge.size.x <= root.size.x + 1 and badge.position.y + badge.size.y <= root.size.y + 1, "Interaction badge fits " + label)
 var presenter: InteractionPresenter = world.player.interactions.presenter
 check(not badge.get_rect().intersects(presenter._ui_rect(world.objective_ui.hud,world.objective_ui)),"Badge clears objectives " + label)
 if world.tutorial_hints.button.visible:
  check(not badge.get_rect().intersects(presenter._ui_rect(world.tutorial_hints.button,world.objective_ui)),"Badge clears tutorial " + label)
func reset_batch(legacy: bool = false) -> void:
 hive.production.work = 0.0
 hive.production.ready_item = null
 hive.production.contributions = {}
 hive.production.legacy_batch = legacy
func run() -> void:
 clock = FarmClock.new()
 clock.clock_source = func() -> float: return 1000.0
 add_child(clock)
 clock.set_process(false)
 world = load("res://world/main_world.tscn").instantiate() as FarmWorld
 world.farming.time_manager = clock
 (world.get_node("FlowerGarden") as FlowerGarden).time_manager = clock
 add_child(world)
 world.starter_content.begin_restore(true)
 world.starter_content.finish_restore()
 world.weather.set_debug_hour(12)
 world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
 var point: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(56,22)))
 hive = world.apiary.create_hive(point, &"preview_hive")
 var pot: FlowerPot = world.apiary.gardens[0].pots[Vector2i.ZERO]
 pot.global_position = point + Vector2(32, -16)
 pot.restore_state({"planted_at":800.0,"growth_started_at":800.0,"matures_at":900.0,"progress":1.0}, load("res://flowers/definitions/flower_06.tres"),1000.0)
 world.apiary.advance(1000.0)
 world.player.global_position = point + Vector2(0, 24)
 world.player.animation.face(Vector2.UP)
 world.farming.harvest_yielded.connect(func(_item: ItemDefinition, amount: int, _point: Vector2, _bag: InventoryComponent) -> void: yielded.append(amount))
 var bag: InventoryComponent = world.player.selection.inventory
 for language: String in ["en", "vi"]:
  Language.set_language(language)
  for window: Vector2i in [Vector2i(1024,720),Vector2i(844,390)]:
   get_tree().root.set_meta(&"touch_layout",window.x == 844)
   get_tree().root.set_meta(&"safe_insets",Vector4(44,0,44,21) if window.x == 844 else Vector4.ZERO)
   DisplayServer.window_set_size(window)
   reset_batch()
   hive.production.advance(21600.0,"flower_06")
   await show_frame("progress-" + language + "-" + str(window.x))
   check(hive.action_text().contains("100"),"Shows batch size")
   check(hive.action_text().contains("100%"),"Rare flower speed +100 percent")
   hive.production.advance(21600.0,"flower_06")
   await show_frame("ready-" + language + "-" + str(window.x))
   check(hive.action_text().contains("×100"),"Ready quantity")
   var before: int = bag.count_item(&"floral_honey")
   check(world.player.interactions.focused.node == hive,"Hive is current interaction")
   check(world.player.interactions.press(),"E/context action accepted")
   check(bag.count_item(&"floral_honey") == before + 100,"Exactly 100 jars collected")
   check(hive.production.ready_item == null,"Batch cleared")
 reset_batch(true)
 hive.production.advance(86400.0/1.3,"flower_01")
 await show_frame("legacy-vi-844")
 check(hive.action_text().contains("Mẻ cũ"),"Legacy explanation translated")
 var before: int = bag.count_item(&"floral_honey")
 check(hive.collect(bag),"Legacy collection succeeds")
 check(bag.count_item(&"floral_honey") == before + 1,"Legacy grants one jar")
 check(not hive.production.legacy_batch,"Next batch uses new rules")
 reset_batch()
 hive.production.advance(86400.0,"")
 var slots: Array[Dictionary] = []
 slots.append({"item":hive.definition.wild_honey,"count":31901})
 for index: int in range(1,bag.slot_count):
  slots.append({"item":InventoryComponent.HOE,"count":1})
 bag.replace_slots(slots)
 check(not hive.collect(bag),"99 free spaces block collection")
 check(hive.production.ready_item != null and bag.count_item(&"wild_honey") == 31901,"Blocked batch and bag preserved")
 bag.remove(&"wild_honey",1)
 check(hive.collect(bag),"100 free spaces permit collection")
 check(bag.count_item(&"wild_honey") == 32000,"Exact inventory limit respected")
 check(yielded == [100,100,100,100,1,100],"Harvest feedback reports actual batch amounts")
 print("HONEY_PREVIEW=" + JSON.stringify({"checks":checks,"failures":failures}))
 get_tree().quit(0 if failures.is_empty() else 1)
