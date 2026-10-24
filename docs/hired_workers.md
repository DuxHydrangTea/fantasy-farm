# Người làm thuê — NPC đi tuần (Hired Workers)

Thuê worker tại **Worker Board** (biển gỗ đặt cạnh nhà người chơi, clone pattern
`PenBoard`/`pen_dashboard`): chọn nhân dạng (lumberjack / bartender / chef —
sprite đã import trong `sprite_frames/character/`), chọn khu trực và trả lương
ngày. Worker là NPC có thân: đi tuần trong khu được giao, tự tìm việc, không
cần người chơi điều khiển.

## Quy tắc đã chốt

| Quy tắc | Giá trị |
| --- | --- |
| Kiểu worker | NPC có thân (phương án B), FSM đơn giản riêng — không tái dùng FSM 11 trạng thái của vật nuôi. |
| Việc làm được | Tưới ô trồng đang khô, gom `ItemPickup` rơi trong khu, **thu hoạch cây chín trong khu**. Không cuốc, không gieo, không feeding máng. |
| Khu trực | Theo cột đất của land expansion (`land_columns`) — mỗi worker nhận 1 khoảng cột liên tục; ô ngoài khu không bị động vào. |
| Giỏ đồ | Harvest/pickup vào giỏ worker (InventoryComponent riêng, 16 slot); người chơi E vào worker để nhận cả giỏ. Giỏ đầy → worker ngừng thu hoạch, tiếp tục tưới. |
| Lương | 2,500 xu/ngày, trừ lúc bình minh (`DAWN=21600`). Không đủ xu → worker nghỉ việc, đứng về Board, giỏ giữ nguyên chờ nhận. |
| Số lượng tối đa | 1 worker mỗi 12 cột đất đã mở (map 48 cột → tối đa 3). |
| Nước tưới | V1 worker có bình vô hạn (không phải mang nước); flag cân bằng lại ở phần 4 nếu quá mạnh. |
| Ưu tiên việc | Cây chín > ô khô gần nhất > pickup gần nhất > patrol waypoint. Mỗi lần đổi đích đều qua `movement.set_destination`, không poll. |

## Thành phần

| Type | Trách nhiệm |
| --- | --- |
| `WorkerDefinition` | Sprite variant, tốc độ, tốc độ làm việc (giây/ô). `.tres` tại `resources/workers/`. |
| `WorkerActor` (CharacterBody2D) | Composite: `MovementComponent` + `AnimationComponent` + `WorkerBehaviourComponent` + giỏ + outline tương tác. Persistent ID như `AnimalActor`. |
| `WorkerBehaviourComponent` | FSM 4 trạng thái: `IDLE → WALK_TO_TASK → WORKING → PATROL`. Chọn đích bằng scan khu (query `farming.crop_cells()` lọc theo cột + `get_soil_state`), không A* toàn map — đi thẳng như wander, kẹt 0.5s thì bỏ việc đó chọn việc kế tiếp. |
| `WorkerService` | Farm-level điều phối (pattern `ApiarySystem`): đăng ký worker, tính lương tại biên ngày, và **mô phỏng offline**. |
| `WorkerBoard` | Biển thuê: clone cấu trúc `pen_board.tscn` + `pen_dashboard.gd` (danh sách, khu trực, lương, sa thải có xác nhận). |

Hành động worker gọi thẳng API sẵn có: `farming_controller.water(cell)` và
`farming_controller.harvest(cell, worker_basket)`; gom pickup dùng logic trùng
`item_collector`. Không script nào của worker đụng nội bộ TileMap.

## Offline và đồng hồ

`WorkerService.advance(timestamp)` chạy mô hình thuần (pattern
`pen_offline_model.gd`): chia đoạn tại các biên ngày (trừ lương), biên cây chín
(tưới trước/chín sau trong cùng khoảng thì chỉ tính từ biên), biên giỏ đầy. Mỗi
đoạn: tưới mọi ô trồng khô trong khu (không tính di chuyển), thu hoạch cây chín
nếu giỏ còn chỗ, cộng pickup theo công suất. Người chơi đóng game 2 ngày → mọi
khu vẫn được tưới, lương vẫn trừ đúng từng ngày, giỏ đầy thì dừng đúng chỗ.
Worker không "đi" khi offline — chỉ kết quả được tính; vị trí đứng khi load lại
là waypoint gần nhất trong khu.

Mưa: `WeatherSchedule` báo RAIN cho ngày đó thì việc tưới bị bỏ qua trong toàn
ngày (đất đã được `rain_water()` ướt sẵn) — worker chỉ thu hoạch/gom.

## Tương tác, UI, save

`InteractionTarget.Kind` thêm `WORKER`: E nhận giỏ (move toàn bộ sang túi,
xử lý tràn túi như `add` trả số thực nhận — phần không nhận được giữ lại trong
giỏ, không rơi vỡ). Click worker → navigate tới rồi nhận. Worker không nằm
trong group `animal_status_targets` — không thanh nhu cầu, chỉ badge trạng
thái việc đang làm (tưới/ thu hoạch/ giỏ đầy X/16).

Worker Board mở qua cùng một luồng E/click như Pen Board, khóa theo
`tool_selection_component` menu-lock hiện hành.

Save schema **v22** thêm `workers`: mỗi row gồm persistent ID, variant, khoảng
cột khu trực, `last_paid_day`, giỏ (slot item_id + count). Migration v1…v21
khởi tạo list rỗng. Validation: khu trực nằm trong số cột đã mở, giỏ ≤ 16 slot,
item nằm trong allowlist `SaveCatalog`, không trùng persistent ID.

## Cân bằng và móc nối

- Lương 2,500/ngày với thu nhập scale ×100 của master spec (~một ô carrot chín
  bán ~10,000): 1 worker rẻ hơn 1 ngày thu hoạch 1 ô — chủ đích để mid-game
  thuê 1–2 worker là quyết định rõ ràng, late-game cả 3 vẫn không "tự chơi" vì
  không gieo/cuốc/feeding.
- Objectives: thêm "Thuê worker đầu tiên", "Nhận giỏ worker đầy 16 món" vào
  `objective_catalog` (data-only).
- Kết hợp nhà bếp (`docs/kitchen.md`): v1 sau có thể cho worker nạp bếp — để
  phần triển khai sau, không đưa vào scope này.

Tests: `tests/unit/test_worker_service.gd` (lương biên ngày, offline segments,
giỏ đầy, mưa bỏ tưới) + `tests/integration/test_workers.gd` (thuê/sa thải qua
board, tưới/thu hoạch thật trên tilemap, nhận giỏ tràn túi, migration v21→v22,
disk roundtrip, replay offline 48h).
