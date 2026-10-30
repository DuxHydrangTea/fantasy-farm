# Worker World Stroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khi worker đã thuê rảnh việc (không còn task nào), task patrol fallback trỏ tới một điểm ngẫu nhiên đi được trên toàn world (gồm khu làng) thay vì 4 góc zone.

**Architecture:** Giữ nguyên patrol-as-task. `WorkerWorldBridge.patrol_point()` thử trước một điểm ngẫu nhiên (physics-clear check bằng footprint thật của actor, tránh điểm trong `blocked_targets`), hết lượt thì fallback về code 4 góc zone cũ. `WorkerService` miễn `kind == "patrol"` khỏi gate `zone_contains` (cả ở quét việc lẫn offset-retry trong `blocked()`), tạo id patrol theo điểm để blocked_targets chặn đúng điểm hỏng, và chèn nghỉ 1–3 giây giữa các chặng dạo.

**Tech Stack:** Godot 4.x GDScript, GUT (`.gutconfig.json`: `tests/unit` + `tests/integration`).

**Spec:** `docs/superpowers/specs/2026-10-31-worker-world-stroll-design.md`

## Global Constraints

- Kiến trúc patrol-as-task giữ nguyên: fallback vẫn tạo task `{"kind": "patrol", "priority": 9}` tại `worker_service.gd:383`.
- Gate `zone_contains` chỉ được miễn cho `kind == "patrol"` — việc thật vẫn bị chặn ngoài zone.
- Điểm stroll phải qua physics query với footprint thật (mẫu: `_point_clear` trong `player_navigation_component.gd:224-237`, `_target_is_clear` trong `animal_wander_component.gd:93-104`); tối đa 8 lần thử/lần chọn, KHÔNG quét toàn map.
- Điểm hỏng đi vào `blocked_targets` 120 giây (cơ chế hiện có, `worker_service.gd:302-327`), key `"<row.id>:<task.id>"`.
- `patrol_index` giữ nghĩa 0..3 (schema `worker_save_schema.gd:24` bắt buộc) — chỉ dùng cho fallback corner.
- Không đổi `persistence/worker_save_schema.gd` — task `"patrol"` đã chấp nhận point là vector bất kỳ (dòng 49) và id là String bất kỳ.
- Offline simulation (advance offline=true, dùng khi save/load) phải hoạt động: worker teleport tới điểm patrol như hiện tại.
- Áp cho cả 3 role: sampler + gate exemption + nghỉ đều role-agnostic (stroll được thử TRƯỚC các nhánh role trong `patrol_point`); test tự động phủ role crop, orchard/ranch dùng chung đường code — smoke thủ công.
- Binary/test runner: dùng godot skill của project để chạy GUT headless (`-s addons/gut/gut_cmdln.gd`, file `.gutconfig.json` có sẵn); chạy 1 file thêm `-gtest=res://tests/integration/test_worker_stroll.gd -gexit`.

## Review Focus

- Worker đứng trong vùng bị rào vây hoàn toàn (không tới được điểm nào): kỳ vọng — sau ≤4 lần offset retry trong `blocked()` rồi `blocked_targets` 120s, worker chọn điểm khác, không bao giờ treo vĩnh viễn. (Được test ở mức sampler: Task 1 fallback test; đường nav-fail đầy đủ smoke thủ công.)
- Ranch worker đang đi dạo xa khi máng cạn: kỳ vọng — trễ tối đa = thời gian đi bộ về + nghỉ ≤3s; `next_wake` vẫn đánh thức đúng lịch. (Smoke thủ công; đã chấp nhận trong spec.)
- Save cũ (task patrol id `"patrol"` 4 góc zone) load lại: kỳ vọng — load không lỗi, worker tiếp tục bình thường. (Không đổi schema nên an toàn; kiểm chứng bằng Task 3 save-validate test trên định dạng mới + schema chỉ nới lỏng.)
- Điểm stroll chọn lúc trống nhưng player xây chồng lên sau đó: kỳ vọng — nav replan ≤3 lần rồi `blocked()`, worker đi tiếp. (Cơ chế hiện có, không test tự động — smoke.)
- Hiệu năng: 5 worker rảnh × 8 physics query mỗi lần chọn điểm (tần suất = thời gian đi bộ + nghỉ), không có chi phí mỗi frame. (Không test tự động; khẳng định bằng review code là chỉ query trong lúc chọn điểm.)

---

### Task 1: Sampler điểm stroll trong WorkerWorldBridge

**Files:**
- Modify: `components/workers/worker_world_bridge.gd` (thêm member + 3 hàm mới, viết lại `patrol_point` dòng 289-306)
- Test: `tests/integration/test_worker_stroll.gd` (tạo mới)

**Interfaces:**
- Consumes: `world.workers.blocked_targets` (Dictionary, `worker_service.gd`), `world.farming.time_manager.now()`, `world.player.camera` (Camera2D với limit_left/top/right/bottom), `WorkerActor.collision` (CollisionShape2D), `actor.get_rid()`, `actor.collision_mask`, `bridge.zone_contains(row, point)`.
- Produces (Task 2, 3 phụ thuộc):
  - `var stroll_rng: RandomNumberGenerator` — được `_init` gọi `randomize()`, test set `.seed`.
  - `func world_stroll_point(row: Dictionary, actor: WorkerActor) -> Vector2` — trả `Vector2.INF` khi hết 8 lần thử.
  - `func rest_seconds() -> float` — `stroll_rng.randf_range(1.0, 3.0)`.
  - `func patrol_point(row: Dictionary) -> Vector2` — luôn trả điểm finite (stroll trước, corner fallback sau).
  - Hằng: `const STROLL_ATTEMPTS: int = 8`, `const STROLL_MIN_DISTANCE: float = 48.0`.

- [ ] **Step 1: Tạo file test `tests/integration/test_worker_stroll.gd`** với khung `before_each`/`after_each` chép từ `tests/integration/test_crop_automation.gd:15-37` (WORLD preload, process_mode DISABLED, manual clock, `restore_columns(12, 4)`, wallet, SUNNY, `hire("crop")`). Thêm vào `before_each`: xóa mọi pile để đảm bảo options rỗng — `for pile: Node in world.get_tree().get_nodes_in_group(&"item_pickups"): pile.queue_free()`. Helper thu nhỏ camera quanh ô phía bắc vùng ruộng (ngoài `LandExpansionState.REGION` = Rect2i(9,19,48,34), chọn y < 19):

```gdscript
func _shrink_camera_to_village() -> void:
	var ground: TileMapLayer = world.farming.farmland
	var center: Vector2 = ground.to_global(ground.map_to_local(Vector2i(30, 5)))
	var camera: Camera2D = world.player.camera
	camera.limit_left = int(center.x) - 160
	camera.limit_top = int(center.y) - 160
	camera.limit_right = int(center.x) + 160
	camera.limit_bottom = int(center.y) + 160
```

(Test chạy thật; nếu assertion bounds fails vì cả 8 điểm đều bị chặn do map kín tại (30,5) → đổi sang ô trống khác có y < 19, x trong 10..56, rồi chạy lại — đây là knob đã ghi ở spec.)

Ba test:

```gdscript
func test_stroll_point_stays_within_camera_bounds_and_outside_zone() -> void:
	_shrink_camera_to_village()
	var row: Dictionary = service.record("crop")
	service.bridge.stroll_rng.seed = 12345
	var point: Vector2 = service.bridge.patrol_point(row)
	var camera: Camera2D = world.player.camera
	assert_true(point.x >= float(camera.limit_left) and point.x <= float(camera.limit_right))
	assert_true(point.y >= float(camera.limit_top) and point.y <= float(camera.limit_bottom))
	assert_false(service.bridge.zone_contains(row, point))
```

```gdscript
func test_stroll_avoids_recently_blocked_target() -> void:
	_shrink_camera_to_village()
	var row: Dictionary = service.record("crop")
	service.bridge.stroll_rng.seed = 4242
	var first: Vector2 = service.bridge.patrol_point(row)
	var key: String = "%s:patrol:%d_%d" % [String(row.id), roundi(first.x), roundi(first.y)]
	service.blocked_targets[key] = world.farming.time_manager.now() + 120.0
	var second: Vector2 = service.bridge.patrol_point(row)
	assert_ne(second, first)
```

```gdscript
func test_stroll_falls_back_to_zone_corner_when_no_walkable_point() -> void:
	_shrink_camera_to_village()
	var camera: Camera2D = world.player.camera
	for offset: Vector2 in [Vector2(0, 0), Vector2(320, 0), Vector2(0, 320), Vector2(320, 320)]:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.collision_layer = 0xFFFFF
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(340, 340)
		shape.shape = rect
		wall.add_child(shape)
		wall.position = Vector2(camera.limit_left, camera.limit_top) + offset
		world.add_child(wall)
	var row: Dictionary = service.record("crop")
	service.bridge.stroll_rng.seed = 777
	var point: Vector2 = service.bridge.patrol_point(row)
	assert_true(service.bridge.zone_contains(row, point))
```

- [ ] **Step 2: Chạy test xác nhận FAIL** (sampler chưa tồn tại → `patrol_point` trả góc zone → test 1 & 2 fail; test 3 pass sẵn vì fallback là hành vi cũ). Run: GUT headless với `-gtest=res://tests/integration/test_worker_stroll.gd -gexit`. Expected: test 1, 2 FAIL.

- [ ] **Step 3: Implement trong `worker_world_bridge.gd`.** Thêm member `var stroll_rng: RandomNumberGenerator = RandomNumberGenerator.new()`, `_init` gọi `stroll_rng.randomize()`; hai hằng nêu ở Interfaces. Thêm:

```gdscript
func world_stroll_point(row: Dictionary, actor: WorkerActor) -> Vector2:
```
— lấy bounds từ `world.player.camera` (limit_left/top/right/bottom, `.grow(-24.0)`); lặp `STROLL_ATTEMPTS` lần: điểm ngẫu nhiên trong bounds qua `stroll_rng`, bỏ nếu `< STROLL_MIN_DISTANCE` từ `actor.global_position`, bỏ nếu `blocked_targets["<row.id>:patrol:<roundi(x)>_<roundi(y)>"] > now`, bỏ nếu không `_stroll_clear`; trả điểm đầu đạt; hết lượt trả `Vector2.INF`. `_stroll_clear(point, actor) -> bool` chép mẫu `animal_wander_component.gd:93-104` (shape query với `actor.collision`, `collision_mask`, `exclude = [actor.get_rid()]`, `query.margin = 0.25`, `intersect_shape(query, 1).is_empty()`). Thêm `func rest_seconds() -> float: return stroll_rng.randf_range(1.0, 3.0)`. Viết lại đầu `patrol_point(row)`: `var actor: WorkerActor = world.workers.actor_for(String(row.id))`, `var stroll: Vector2 = world_stroll_point(row, actor)` — `if not stroll.is_finite(): return stroll` giữ nguyên phần corner cũ làm fallback bên dưới (ranch/pen, orchard/crop region). Actor null → coi như `Vector2.INF` (dùng corner fallback).

- [ ] **Step 4: Chạy lại file test.** Expected: 3/3 PASS.

- [ ] **Step 5: Commit** `git add components/workers/worker_world_bridge.gd tests/integration/test_worker_stroll.gd && git commit -m "feat(workers): sample world-wide stroll points for idle patrol"`

### Task 2: Miễn patrol khỏi gate zone + id patrol theo điểm

**Files:**
- Modify: `components/workers/worker_service.gd` (dòng ~383-385 fallback, dòng ~314 trong `blocked()`)
- Test: `tests/integration/test_worker_stroll.gd` (thêm test)

**Interfaces:**
- Consumes: `bridge.patrol_point(row)` (Task 1), `bridge.zone_contains`, `WorkerRole.pair/point`.
- Produces: task patrol fallback có `id = "patrol:%d_%d" % [roundi(x), roundi(y)]` (khớp key mà sampler Task 1 đã check); mọi task khác không đổi.

- [ ] **Step 1: Thêm test vào `test_worker_stroll.gd`:**

```gdscript
func test_idle_worker_patrols_outside_their_zone() -> void:
	_shrink_camera_to_village()
	service.bridge.stroll_rng.seed = 999
	service.advance(now + 0.5)
	var task: Dictionary = service.record("crop").task
	assert_eq(String(task.get("kind")), "patrol")
	assert_false(service.bridge.zone_contains(service.record("crop"), WorkerRole.point(task.point)))
```

- [ ] **Step 2: Chạy xác nhận FAIL** — hiện task patrol góc zone (nằm trong zone) nên assert cuối fail. Expected: FAIL.

- [ ] **Step 3: Implement trong `worker_service.gd`.** (a) Dòng ~383: fallback tạo id theo điểm — `var stroll: Vector2 = bridge.patrol_point(row)` rồi `chosen = {"kind": "patrol", "id": "patrol:%d_%d" % [roundi(stroll.x), roundi(stroll.y)], "point": WorkerRole.pair(stroll), "priority": 9}`. (b) Dòng ~385 gate: `if not chosen.is_empty() and (String(chosen.get("kind", "")) == "patrol" or bridge.zone_contains(row, WorkerRole.point(chosen.point))):`. (c) Dòng ~314 trong `blocked()`: `if String(task.get("kind", "")) == "patrol" or bridge.zone_contains(row, point):` — cho phép offset retry ±20px ở điểm ngoài zone.

- [ ] **Step 4: Chạy lại toàn bộ file test stroll + file test_crop_automation.gd** (đụng chung worker_service). Expected: PASS tất cả.

- [ ] **Step 5: Commit** `git add components/workers/worker_service.gd tests/integration/test_worker_stroll.gd && git commit -m "feat(workers): exempt patrol tasks from zone gate with per-point ids"`

### Task 3: Nghỉ giữa các chặng dạo + chốt save schema

**Files:**
- Modify: `components/workers/worker_service.gd` (sau `bridge.commit(...)` trong `advance`, dòng ~372-375)
- Test: `tests/integration/test_worker_stroll.gd` (thêm 2 test)

**Interfaces:**
- Consumes: `bridge.rest_seconds()` (Task 1), biến `task` cục bộ trong `advance` sau commit.
- Produces: sau khi commit task `kind == "patrol"`, `row.wake_at = simulated_at + rest_seconds()`; task khác giữ `wake_at = simulated_at`.

- [ ] **Step 1: Thêm 2 test:**

```gdscript
func test_rest_between_strolls_is_one_to_three_seconds() -> void:
	service.bridge.stroll_rng.seed = 7
	var rest: float = service.bridge.rest_seconds()
	assert_true(rest >= 1.0 and rest <= 3.0)
```

```gdscript
func test_save_schema_accepts_out_of_zone_patrol_task() -> void:
	_shrink_camera_to_village()
	service.bridge.stroll_rng.seed = 999
	service.advance(now + 0.5)
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var snapshot: Dictionary = adapter.capture("stroll_test", 1, world.farming.time_manager.now())
	assert_true(SaveSchema.validate(snapshot, catalog).ok)
```

- [ ] **Step 2: Chạy xác nhận FAIL.** Test rest: PASS sẵn (rest_seconds đã có từ Task 1) — ghi rõ điều này, không sửa gì cho test này. Test save: nếu schema từ chối task patrol ngoài zone → FAIL; nếu PASS sẵn thì ghi nhận là bằng chứng constraint thỏa (không phải bỏ qua). Expected: test save PASS hoặc FAIL — cả hai đều là dữ liệu; chỉ FAIL mới cần bước 3a bổ sung.

- [ ] **Step 3: Implement trong `worker_service.gd` advance loop** — dòng ~374 sau `row.task = {}`:

```gdscript
row.wake_at = simulated_at + (bridge.rest_seconds() if String(task.get("kind", "")) == "patrol" else 0.0)
```

Nếu bước 2 cho thấy schema FAIL: điều tra nguyên nhân trong `worker_save_schema.gd` trước khi đổi bất cứ gì, báo lại người duyệt — KHÔNG tự ý sửa schema (constraint Global: không đổi schema).

- [ ] **Step 4: Chạy toàn bộ suite GUT headless** (không `-gtest`, dùng `.gutconfig.json`). Expected: tất cả PASS, không test cũ nào vỡ (đặc biệt `test_crop_automation.gd`, `test_component_wiring.gd`, save/restore tests).

- [ ] **Step 5: Commit** `git add components/workers/worker_service.gd tests/integration/test_worker_stroll.gd && git commit -m "feat(workers): rest pause between world strolls, pin save schema"`
