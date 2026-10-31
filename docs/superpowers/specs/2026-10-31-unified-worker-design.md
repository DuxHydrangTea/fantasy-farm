# Design: Gộp 3 loại worker thành một loại worker duy nhất

Ngày: 2026-10-31 · Quy mô: project · Phương án: A — gộp triệt để (đã chọn)

## Ý định & lý do

Hiện tại game có 3 loại worker tách biệt (crop — ruộng, orchard — vườn cây,
ranch — chuồng), mỗi loại có bảng tuyển riêng, lương riêng, hạn mức riêng,
điều kiện mở khóa riêng và bộ cài riêng. Người chơi muốn **một loại worker
duy nhất** làm được mọi việc, hạn mức **15 người**, lương **2.800 xu/ngày**
(đề xuất đã được duyệt), dọn về **một bảng tuyển duy nhất**.

## Goals

- Một loại worker: pipeline việc gộp cả 3 nhánh (ruộng + vườn cây + chuồng)
  trong cùng hàng đợi ưu tiên hiện có (`WorkerRole.choose` — ưu tiên số nhỏ
  hơn thắng, giữ nguyên cơ chế ngắt việc khi có việc gấp).
- Hạn mức 15, lương 2.800, một bảng tuyển tại vị trí bảng CropWorkers hiện
  tại; 2 bảng cũ (OrchardWorkers, RanchWorkers) gỡ khỏi `main_world.tscn`.
- Điều kiện mở khóa duy nhất: **≥ 12 cột đất** (gate cũ của crop).
- Worker chăm **tất cả chuồng** tự động (candidates đã duyệt qua mọi pen);
  feed cho máng lấy từ **kho vật tư** (`farm_supply_storage`) đúng luồng
  ranch hiện hành — demand-check lẫn commit đều đọc kho này, người chơi chỉ
  cần đổ feed tại building; cơ chế `water_units` giữ nguyên.
- Menu chung: bộ cài tự gieo/bón phân/tạm dừng/chờ chăm sóc hiển thị cho mọi
  worker; bỏ hộp chọn chuồng; tiêu đề "Đội làm việc {count}/15".
- **Migration save cũ không mất worker**: row `ranch`/`orchard` → role mới,
  slot đánh lại duy nhất 1..N theo hire_order, `trial_used` hợp nhất.
- Save schema: rows 7→15, prepared 5→15; old task kinds đều nằm trong tập
  kind cho phép hợp nhất.

## Non-goals

- Không đổi hành vi từng loại việc (tưới/thu hoạch/cho ăn/g lấy nước như cũ).
- Không per-worker assignment (gán worker theo khu) — mọi worker tự chọn việc.
- Diện mạo: worker thống nhất dùng **Bob** (`farmer_bob_frames`) — quyết định
  của người chơi. Lưu ý: ba worker hiện tại là 3 nhân vật khác nhau
  (crop=Bob, orchard=Jack `lumberjack_jack_frames`, ranch=Buba
  `farmer_buba_frames`); worker Jack/Buba trong save cũ sẽ đổi thành Bob khi
  load — chấp nhận (lưu ý: đây là sửa cho việc tôi ghi sai ở bản doc đầu
  tiên). Stats vốn giống nhau (speed 120, work 2s).
- Không cosmetic rename lớn (xem Quyết định nội bộ #1).

## Anti-goals (thất bại nếu xảy ra)

- Save cũ load lỗi hoặc mất worker.
- Worker dính kẹt do pipeline gộp (ví dụ quên cho ăn vì đang gieo).
- Hai bảng cũ còn mở được menu trong world.

## Ràng buộc

- Save schema (`persistence/worker_save_schema.gd`) là strict: mọi sửa phải
  giữ `valid()` nhất quán; `zone` vẫn là String (đặt `""`); basket 16 slot
  giữ nguyên; `patrol_index` 0..3 giữ nguyên.
- Preflight (`world_state_adapter.gd`): bỏ check `pen_for(row.zone)` cho
  ranch; giữ nguyên các check world_bounds/zone đã nới ở tính năng stroll.
- Hiệu năng: 15 worker × `candidates()` quét toàn bộ ô trồng + cây + chuồng
  mỗi lần quét việc — chi phí tuyến tính so với 7 hiện tại; test
  `test_full_1632_plot_field...` đã chứng minh quét lớn chạy nổi. Không thêm
  cache mới trong lần này.
- Localization: `TITLES`/`DESCRIPTIONS`, "Crop team {count}/5", "Hire
  workers"… phải cập nhật cả `vi.po` lẫn `en.po`.

## Các phương án đã cân nhắc

- **A — Gộp triệt để (CHỌN):** một role, một bảng, một pipeline, migration
  save; 2 bảng cũ gỡ khỏi world. Đánh đổi: diff lớn chạm schema + world
  scene; mất 2 điểm tuyển cũ.
- **B — Gộp mềm:** cùng loại worker chung nhưng giữ 3 bảng làm điểm tuyển
  (mở cùng menu). Được chọn bởi không ai; để lại 3 điểm dư thừa vĩnh viễn
  và vẫn phải sửa menu/schema như A — phần khó của A không giảm.
- **C — 1 worker + gán khu ưu tiên (loại):** thêm assignment per worker —
  đi ngược mục tiêu đơn giản hóa, tăng công việc UI + schema mới.

## Quyết định đã chốt (của người chơi)

1. Một loại worker duy nhất làm mọi việc.
2. Hạn mức **15 người**.
3. Lương **2.800 xu/ngày** (đề xuất của tôi, người chơi duyệt).
4. Phương án **A** — một bảng tuyển duy nhất.

## Quyết định nội bộ (my calls — người chơi có quyền phủ quyết)

1. **Giữ id role nội bộ `"crop"`** — đa số code đã khóa theo nó
   (`crop_automation`, `CropWorkerPolicy`, DEFINITIONS key...); đổi sang id
   mới chỉ tăng diff và rủi ro mà không đổi trải nghiệm. Tên hiển thị (menu,
   badge, localization) là "Nhân công"/"Worker". Cosmetic rename cả hệ thống
   là việc khác, không thuộc lần này.
2. **Bảng tuyển giữ node `CropWorkers`** (đổi nhãn hiển thị thành "Hire
   workers" như cũ — đã có sẵn), `WorkerBoard.role` export giữ nguyên cơ chế
   (mặc định "crop").
3. **`trial_used` migration:** nếu save cũ có BẤT KỲ role nào trong
   `trial_used` → role thống nhất được đánh dấu đã dùng trial (mua lẻ miễn
   phí lần đầu chỉ áp một lần toàn game như cũ).
4. **Diện mạo & definition:** một definition duy nhất (Bob) — `DEFINITIONS`
   thu về 1 entry; `orchard_hand.tres`/`ranch_hand.tres` và scene
   `orchard_worker.tscn`/`ranch_worker.tscn` gỡ tham chiếu rồi xóa nếu không
   còn ai dùng sau khi sửa tests/supports. Worker cũ Jack/Buba trong save
   đổi thành Bob khi load (người chơi đã chọn A).
5. **Tưới nước crop vs máng nước ranch:** worker dùng chung quỹ
   `water_units` hiện có (fetch_water từ máng/giếng như ranch cũ) — không
   tách quỹ.
6. **Feed cho máng lấy từ kho vật tư** (`farm_supply_storage`) — đúng luồng
   ranch hiện hành, demand-check lẫn commit đều đọc kho; giữ nguyên. Bỏ
   hedge sai trong bản nháp trước ("bag worker chứa feed") — bag vẫn nhận
   feed qua `transfer(..., supplies=true)` nếu UI còn nút đó, nhưng nguồn
   refill máng là kho.

## Phần còn lại cho builder

- Gộp `candidates()` 3 nhánh thành 1; các task kind union:
  `["fruit", "harvest", "water_crop", "pickup", "feed", "fetch_water",
  "water_trough", "patrol", "till", "plant", "fertilize"]` cho role thống
  nhất (schema dòng `allowed`).
- `feed_inventory(key)` trả `farm_supply_storage` cho worker thống nhất
  (quyết định #6); xác minh nhánh `candidates()` feed và
  `world.storages.refill_feed` vẫn khớp.
- Sửa `WorkerMenu`: TITLES/DESCRIPTIONS một entry, luôn hiện %CropOptions
  (đổi nhãn), bỏ %ZoneBox, hire cost theo LIMITS/WAGES mới, heading mới.
- Migration trong `WorkerSaveSchema.valid()`/một hàm migrate riêng theo
  khổ mẫu migration có sẵn trong `SaveSchema` (xem `test_workers`
  `test_v22_migration...`, `v28_roundtrip...` — tăng version schema).
- Tests: cập nhật supports (`workers_probe`, `worker_redesign_probe`,
  `worker_layout_fixture`, `supply_flow_probe`, `economy_audit`,
  `grafting_probe`) và integration tests gọi `hire("ranch"/"orchard")`;
  thêm test migration save cũ 3-role → mới (khổ mẫu v22/v28) + test hạn mức
  15 + test preflight không còn đòi pen.
- Localization vi.po/en.po theo key mới.
- Xóa `OrchardWorkers`/`RanchWorkers` khỏi `main_world.tscn` (dùng công cụ
  move/remove của godot skill, không hand-edit tscn).
