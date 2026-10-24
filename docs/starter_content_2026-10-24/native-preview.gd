extends Node
var world: FarmWorld
var failures: Array[String] = []
var checks: int = 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures.append(label)
  push_error(label)
func _ready() -> void:
 run.call_deferred()
func run() -> void:
 world = load("res://world/main_world.tscn").instantiate() as FarmWorld
 add_child(world)
 world.weather.set_debug_hour(12)
 var garden: FlowerGarden = world.get_node("FlowerGarden") as FlowerGarden
 world.player.global_position = garden.to_global(Vector2(192, 128))
 world.player.camera.zoom = Vector2(1.8, 1.8)
 for language: String in ["en", "vi"]:
  Language.set_language(language)
  DisplayServer.window_set_size(Vector2i(1024, 720))
  await get_tree().create_timer(0.4).timeout
  print("NOTICE_RECT=",garden._lock_notice.get_global_rect()," SIZE=",garden._lock_notice.size)
  check(garden._lock_notice.visible, "Locked notice visible " + language)
  check(garden._lock_notice.size.x <= garden.SIZE.x, "Notice fits garden " + language)
  check(garden.tr(garden._lock_notice.text) == ("Mua phần đất mở rộng đầu tiên để mở khóa vườn hoa." if language == "vi" else garden._lock_notice.text), "Translated notice " + language)
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://../starter-locked-" + language + ".png")
 world.player.wallet.set_balance(87000)
 check(world.land.state.purchase(world.player.wallet, 1).ok, "Real land purchase")
 check(not garden._lock_notice.visible, "Unlock hides notice")
 check(not garden.starter_content_locked, "Unlocked garden")
 await get_tree().create_timer(0.3).timeout
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://../starter-unlocked.png")
 print("STARTER_PREVIEW=" + JSON.stringify({"checks": checks, "failures": failures}))
 get_tree().quit(0 if failures.is_empty() else 1)
