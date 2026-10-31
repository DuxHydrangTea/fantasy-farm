# Unified Worker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gộp 3 loại worker (crop/orchard/ranch) thành một loại duy nhất làm mọi việc — hạn mức 15, lương 2.800, một bảng tuyển, migration save không mất worker.

**Architecture:** Giữ id role nội bộ `"crop"` (decision #1 trong spec); pipeline việc gộp cả 3 nhánh trong `WorkerWorldBridge.candidates()`/`next_wake()`; `WorkerRole` còn 1 role với LIMITS 15 / WAGES 2.800; save migration 37→38 chuyển các row `ranch`/`orchard` thành `crop` + slot re-assign; `WorkerMenu` hiển thị bộ cài automation cho mọi worker, bỏ ZoneBox; world scene gỡ 2 bảng cũ.

**Tech Stack:** Godot 4.7 GDScript, GUT headless (`-gconfig=` + `-gtest=`), SaveSchema migration tuần tự, test harness khổ mẫu `test_workers.gd`.

**Spec:** `docs/superpowers/specs/2026-10-31-unified-worker-design.md`

## Global Constraints

- Id role thống nhất: `"crop"` — hiển thị "Nhân công"/"Worker"; KHÔNG cosmetic rename hệ thống.
- Hạn mức `LIMITS = {"crop": 15}`; `WAGES = {"crop": 2800}`; `trial_used` hợp nhất (bất kỳ role cũ nào → `"crop"`).
- Migration phải bảo toàn mọi worker (không drop row); slot re-assign duy nhất 1..N theo `hire_order`; `zone` → `""`.
- Diện mạo: Bob (`farmer_bob_frames` qua `crop_hand.tres`); xóa `orchard_hand.tres`, `ranch_hand.tres`, `orchard_worker.tscn`, `ranch_worker.tscn` sau khi gỡ tham chiếu.
- Feed cho máng từ `farm_supply_storage` (luồng ranch hiện hành); `water_units` giữ nguyên.
- Điều kiện mở khóa duy nhất: `unlocked_columns < 12`.
- Task kinds hợp nhất: `["fruit", "harvest", "water_crop", "pickup", "feed", "fetch_water", "water_trough", "patrol", "till", "plant", "fertilize"]`.
- Không hand-edit `.tscn`: dùng godot skill (remove_node/scene_batch) cho world scene; `.uid` sidecars đi theo.
- Test runner: `GODOT=/c/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe` chạy `--headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/... -gexit`; SAU MỖI lần chạy phải kiểm tra log có "Nothing was run"/Parse Error trước khi kết luận (bài học stroll).
- Suite nền đỏ sẵn (~135 flaky/pre-existing): tiêu chí = các file đụng tới đạt baseline hoặc tốt hơn + test mới RED→GREEN; so sánh per-file, không kết luận từ 1 lần chạy full suite.

## Review Focus

- Save cũ v37 với 7 worker lẫn loại, có worker đang mang task `feed`/`fruit` → load phải giữ nguyên task và công việc tiếp diễn. (Task 1 migration test chứa task.)
- Worker đang đứng ở chuồng (position ngoài vùng ruộng) khi save → preflight phải chấp nhận. (Task 1 preflight test.)
- 16 worker thứ 16 bị chặn đúng thông báo team-full; hire thứ 15 thành công ở tất cả các điểm gọi LIMITS (menu, schema slot, preflight). (Task 2 test.)
- Trough cạn phải ĐÁNH THỨC được worker đang gieo (next_wake hợp nhất min 3 nhánh) — nếu merge thiếu nhánh ranch, động vật đói âm thầm. (Task 3 test.)
- Nhãn tiếng Việt menu/badge sau khi đổi key (vi.po/en.po cả hai) — smoke bằng `ui_report` hoặc đọc po. (Task 4.)

---

### Task 1: Save schema — migration 37→38 + hạn mức 15

**Files:**
- Modify: `persistence/save_schema.gd` (thêm block migration `if data.get("version") == 37:` trước chuỗi hiện có; VERSION 37→38)
- Modify: `persistence/worker_save_schema.gd` (valid(): rows cap 15, ROLES/LIMITS, allowed kinds, prepared cap)
- Modify: `components/workers/worker_role.gd` (ROLES/LIMITS/WAGES)
- Modify: `components/workers/crop_automation_state.gd` (valid(): prepared cap 5→15)
- Modify: `persistence/world_state_adapter.gd:178` (bỏ check pen ranch)
- Test: `tests/integration/test_workers.gd` (thêm test migration + hạn mức)

**Interfaces:**
- Consumes: `SaveSchema.VERSION = 37` hiện tại; khổ mẫu migration tuần tự (`if data.get("version") == N: ...; data.version = N + 1`).
- Produces: `WorkerRole.ROLES == ["crop"]`, `WorkerRole.LIMITS == {"crop": 15}`, `WorkerRole.WAGES == {"crop": 2800}`; schema nhận rows ≤ 15; preflight không đòi pen. Task 2-5 phụ thuộc.

- [ ] **Step 1: Viết test migration + hạn mức trong `test_workers.gd`** (khổ mẫu `test_v22_migration...` dòng 97):

```gdscript
func test_v37_migration_unifies_roles_without_loss() -> void:
	var old: Dictionary = adapter.capture("worker_test", 1, now)
	# mô phỏng save v37 lẫn loại: đổi role 2 row thành ranch/orchard, slot theo LIMITS cũ
	var rows: Array = old.workers.rows
	rows[0].role = "ranch"
	rows[0].zone = "pen_x"
	rows[0].task = {"kind": "feed", "id": "trough_1", "point": [100.0, 100.0], "base_point": [100.0, 100.0], "attempt": 0, "work_at": now, "finish_at": now + 2.0}
	if rows.size() > 1:
		rows[1].role = "orchard"
	old.workers.trial_used = ["ranch"]
	old.version = 37
	var migrated: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(migrated.ok, str(migrated))
	assert_eq(int(migrated.snapshot.version), SaveSchema.VERSION)
	var unified: Array = migrated.snapshot.workers.rows
	assert_eq(unified.size(), rows.size(), "No worker lost")
	for row: Dictionary in unified:
		assert_eq(String(row.role), "crop")
		assert_eq(String(row.zone), "")
	var slots: Dictionary = {}
	for row: Dictionary in unified:
		slots[int(row.slot)] = true
	assert_eq(slots.size(), unified.size(), "Slots unique 1..N")
	assert_true("crop" in migrated.snapshot.workers.trial_used)
	assert_eq(String(unified[0].task.kind), "feed", "Active ranch task survives")
	var preflight: Dictionary = adapter.preflight(migrated.snapshot)
	assert_true(bool(preflight.ok), "Preflight accepts unified rows without pens: " + str(preflight))

func test_worker_limit_fifteen_enforced_everywhere() -> void:
	for i: int in range(15):
		assert_eq(service.hire("crop"), "")
	assert_ne(service.hire("crop"), "", "16th hire must be rejected")
```

(Chỉnh `adapter`/`now` theo tên biến cục bộ của file — đọc `before_each` + `test_v22_migration...` trước khi viết.)

- [ ] **Step 2: Chạy xác nhận FAIL** — migration chưa có → save v37 báo lỗi/future hoặc role "ranch" bị từ chối. Run: GUT với `-gtest=res://tests/integration/test_workers.gd -gexit`. Expected: 2 test mới FAIL.

- [ ] **Step 3: Implement.** (a) `save_schema.gd`: thêm block `if data.get("version") == 37:` chuyển `data.workers.rows` (role → "crop", zone → "", slot = index + 1 theo thứ tự hire_order tăng dần, giữ task/basket), `data.workers.trial_used = ["crop"] if not data.workers.trial_used.is_empty() else []`, rồi `data.version = 38`; cập nhật `VERSION` = 38. (b) `worker_role.gd`: `ROLES = ["crop"]`, `LIMITS = {"crop": 15}`, `WAGES = {"crop": 2800}`. (c) `worker_save_schema.gd`: `data.rows.size() > 15`; dòng `allowed` cho role "crop" là union đầy đủ (bỏ 3 nhánh else vì không còn role khác); slot cap theo `LIMITS["crop"]`. (d) `crop_automation_state.gd` valid: `prepared.size() > 15`. (e) `world_state_adapter.gd`: xóa dòng `if row.role == "ranch" and world.workers.bridge.pen_for(row.zone) == null:`.

- [ ] **Step 4: Chạy lại `test_workers.gd`.** Expected: test mới PASS, các test cũ của file PASS (riêng những test fail baseline sẵn — đối chiếu danh sách baseline nếu lệch).

- [ ] **Step 5: Commit** `git add -A persistence components/workers/worker_role.gd components/workers/crop_automation_state.gd tests/integration/test_workers.gd && git commit -m "feat(workers): unify save schema to single role, limit 15 (migration v38)"`

### Task 2: Service — một role, một scene, một definition

**Files:**
- Modify: `components/workers/worker_service.gd` (SCENES/DEFINITIONS 1 entry; spawn_point bỏ zone; unlock_error; feed_inventory; _warehouse_changed)
- Test: `tests/integration/test_workers.gd` (thêm test unlock + spawn)

**Interfaces:**
- Consumes: `WorkerRole.LIMITS/WAGES` (Task 1).
- Produces: `WorkerService.DEFINITIONS == {"crop": crop_hand}`; `SCENES == {"crop": crop_worker.tscn}`; `feed_inventory(key) -> farm_supply_storage` (mọi worker); `spawn_point(role, zone, except_id)` bỏ qua `zone`; `unlock_error` chỉ gate 12 cột. Task 3-4 phụ thuộc.

- [ ] **Step 1: Test:**

```gdscript
func test_unified_unlock_and_spawn() -> void:
	world.land.state.restore_columns(4, 4)
	assert_true(not service.unlock_error("crop").is_empty(), "12-column gate still gates")
	world.land.state.restore_columns(12, 4)
	assert_eq(service.unlock_error("crop"), "")
	var first: Vector2 = service.spawn_point("crop", "")
	var second: Vector2 = service.spawn_point("crop", "pen_x")
	assert_true(first.distance_to(second) < 0.01, "Zone no longer moves the spawn")
```

- [ ] **Step 2: Chạy xác nhận FAIL hoặc PASS-sẵn** (nếu spawn_point nhánh crop vốn không phụ thuộc zone thì test spawn pass sẵn — chấp nhận, vẫn giữ làm pin; test gate phải FAIL trước Task 1? KHÔNG — gate thuộc Task 1 constants, ở đây chỉ pin lại).

- [ ] **Step 3: Implement:** `SCENES = {"crop": preload("res://scenes/workers/crop_worker.tscn")}`; `DEFINITIONS = {"crop": preload("res://resources/workers/crop_hand.tres")}`; `feed_inventory(key)` → `return world.storages.inventory("farm_supply_storage")`; `spawn_point` bỏ nhánh ranch/zone (spawn theo bảng CropWorkers — giữ công thức hiện có của nhánh crop); `unlock_error` chỉ còn gate 12 cột; `_warehouse_changed` bỏ điều kiện role; `hire()` bỏ ý nghĩa `zone` (giữ tham số để không vỡ callers).

- [ ] **Step 4: PASS** + chạy `test_crop_automation.gd`, `test_worker_warehouse.gd` đối chiếu baseline.

- [ ] **Step 5: Commit** `git commit -m "feat(workers): single scene/definition/spawn for unified worker"`

### Task 3: Bridge — pipeline việc hợp nhất

**Files:**
- Modify: `components/workers/worker_world_bridge.gd` (candidates gộp 3 nhánh; next_wake = min 3 nguồn; zone_contains → true; patrol_point fallback crop; home/spawn helpers)
- Test: `tests/integration/test_workers.gd` + `tests/integration/test_animals.gd` (trough)

**Interfaces:**
- Consumes: role thống nhất `"crop"` (Task 1-2).
- Produces: `candidates(row, feed_inventory)` trả union việc fruit + troughs + crops + pickups cho mọi row; `next_wake(row, feed, now)` = min(dawn, fruit-wake, crop-wake, ranch-boundary); `zone_contains(row, point, columns=-1) -> true` (worker đi mọi nơi; preflight đã nới từ stroll).

- [ ] **Step 1: Test wake + việc liên vùng:**

```gdscript
func test_unified_worker_feeds_troughs_and_harvests_trees() -> void:
	# kịch bản: 1 crop đang cần nước + 1 máng cạn + 1 cây có trái →
	# worker thống nhất nhận việc ưu tiên cao nhất có thể là feed (priority 0)
	var pen: AnimalPen = world.get_node("BarnPen") nếu có (theo fixture test_animals)
	# rút cạn máng → service.advance(...) → row.task.kind in ["feed", "fetch_water", "water_trough"]
	# cây FruitTree có trái (theo khổ mẫu test_grafting/test_tree_plantation) → task "fruit" xuất hiện khi không có việc priority thấp hơn
```

(Viết theo fixture có sẵn của `test_animals.gd` trước_each — tái dùng pen/trough tại chỗ; 2 khẳng định: task feed xuất hiện cho worker crop; task fruit xuất hiện khi cây chín.)

- [ ] **Step 2: FAIL** (candidates crop hiện không trả việc feed/fruit).

- [ ] **Step 3: Implement:** trong `candidates()`: gộp nhánh orchard (fruit loop) + ranch (trough loop) vào nhánh "crop" — chạy cả 3 vòng cho mọi row; `next_wake`: bỏ 3 nhánh role, tính `next = min(dawn, fruit-min, crop-min, _ranch_boundary(...))`; `zone_contains` → `return true` (tham số giữ nguyên cho callers); `patrol_point` fallback: bỏ nhánh ranch pen + orchard region, chỉ còn fallback góc vùng ruộng; `_warehouse_changed`/`_trough_changed` → `request_scan("crop")` (đã từ Task 2 nếu trùng).

- [ ] **Step 4: PASS** — chạy `test_workers.gd`, `test_animals.gd`, `test_grafting.gd`, `test_tree_plantation.gd` đối chiếu baseline từng file.

- [ ] **Step 5: Commit** `git commit -m "feat(workers): merged task pipeline feeds waters and harvests everywhere"`

### Task 4: Menu + Board + World scene + localization

**Files:**
- Modify: `components/workers/worker_menu.gd` (TITLES/DESCRIPTIONS 1 entry; heading "Worker team {count}/15"; %CropOptions luôn hiện; bỏ %ZoneBox + code zone; _hire bỏ zone)
- Modify: `scenes/ui/workers.tscn` (gỡ node %ZoneBox — qua godot skill scene_batch, không hand-edit)
- Modify: `world/main_world.tscn` (remove_node OrchardWorkers + RanchWorkers)
- Modify: `components/workers/worker_board.gd` (export_enum còn "crop"; label giữ "Hire workers")
- Modify: `localization/vi.po`, `localization/en.po` (key mới/sửa)
- Test: `tests/integration/test_worker_ui.gd` + supports

**Interfaces:**
- Consumes: Task 1-3.
- Produces: menu thống nhất; 1 bảng trong world.

- [ ] **Step 1: Test UI** trong `test_worker_ui.gd` (khổ mẫu hiện có): mở board CropWorkers → menu có hire button; `%CropOptions` visible; team list chiều dài = số worker đã thuê; heading text chứa "/15". KHÔNG mở được board tại vị trí 2 bảng cũ (node không tồn tại → `world.get_node_or_null("OrchardWorkers") == null`).

- [ ] **Step 2: FAIL** (menu cũ vẫn hiện ZoneBox cho ranch; heading "/5").

- [ ] **Step 3: Implement** theo Interfaces trên; localization: thêm/sửa key `"Worker team {count}/15"`, `"Worker"`, mô tả hợp nhất ("Waters, harvests, tends crops, orchards and animal pens.") trong cả vi.po (msgstr "Đội làm việc {count}/15", "Nhân công", mô tả tiếng Việt) và en.po.

- [ ] **Step 4: PASS** — chạy `test_worker_ui.gd`, `test_worker_stroll.gd`, `test_component_wiring.gd` đối chiếu baseline.

- [ ] **Step 5: Commit** `git commit -m "feat(workers): unified hiring board menu and world scene"`

### Task 5: Dọn dẹp references + full suite

**Files:**
- Delete: `resources/workers/orchard_hand.tres`, `resources/workers/ranch_hand.tres`, `scenes/workers/orchard_worker.tscn`, `scenes/workers/ranch_worker.tscn` (+ .uid/.import sidecars)
- Modify: `tests/support/workers_probe.gd`, `worker_redesign_probe.gd`, `worker_layout_fixture.gd`, `supply_flow_probe.gd`, `economy_audit.gd`, `grafting_probe.gd` (role strings → "crop", mở 1 board)

**Interfaces:**
- Consumes: tất cả task trước.

- [ ] **Step 1: Grep còn sót** `grep -rn '"orchard"\|"ranch"' --include="*.gd" components/ persistence/ tests/support/ | grep -v "test_"` — sửa từng dòng còn lại sang "crop" hoặc bỏ nhánh; chạy `lint_project.py` (godot skill) → `counts.errors == 0`.

- [ ] **Step 2: Xóa 4 file** sau khi `grep -rln "orchard_hand\|ranch_hand\|orchard_worker.tscn\|ranch_worker.tscn"` trả về rỗng (ngoài .godot/); dùng remove chuẩn của OS + `--import` một lần sau xóa (godot skill) để dọn sidecars.

- [ ] **Step 3: Sửa supports** theo Interfaces (thay hire("ranch")→hire("crop"), board map 1 phần tử).

- [ ] **Step 4: Chạy full suite GUT headless** (không -gtest). Expected: không test mới vỡ so với baseline; đối chiếu per-file với danh sách baseline đã lưu (lưu ý flaky world-gen — chạy lại file riêng nếu nghi).

- [ ] **Step 5: Commit** `git commit -m "chore(workers): remove orchard ranch variants and refresh test probes"`
