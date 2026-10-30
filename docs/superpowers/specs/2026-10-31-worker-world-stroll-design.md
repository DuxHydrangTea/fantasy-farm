# Design: Worker rảnh rỗi đi dạo cả world

Ngày: 2026-10-31 · Quy mô: thay đổi nhỏ

## Ý định & lý do

Khi không còn việc (tưới/thu hoạch/trồng/nhặt đồ...), worker đang thuê chỉ đứng ở
4 góc zone của mình. Map trông "chết". Mục tiêu: worker rảnh đi dạo khắp world —
gồm ruộng, vườn cây, và khu làng — để thế giới sống động hơn.

## Goals

- Worker rảnh (cả 3 role: crop, orchard, ranch) nhận task `"patrol"` trỏ tới một
  điểm ngẫu nhiên **đi được** anywhere trên map (theo giới hạn camera của world).
- Việc thật xuất hiện → ngắt đi tuần ngay lập tức (không đổi: `WorkerRole.choose`
  luôn ưu tiên priority số nhỏ hơn 9).
- Không phá save cũ; không giảm hiệu năng (không quét physics toàn map).

## Non-goals

- Không đổi hành vi đi tuần của actor chưa thuê (M0 `WorkerBehaviourComponent`).
- Không làm NPC/dân làng đi lại.
- Không đổi cách chọn việc thật (watering/harvest/plant...).

## Anti-goals (thất bại nếu xảy ra)

- Worker kẹt tại chỗ, dịch chuyển tức thời, hoặc đi xuyên vật cản.
- Việc thật bị trễ vì worker đi tuần (ngoài độ trễ đi bộ vốn có).

## Ràng buộc

- Giữ kiến trúc patrol-as-task: `worker_service.gd` fallback (dòng ~383) tiếp tục
  tạo task `"patrol"` priority 9; chỉ đổi **nguồn điểm**.
- Gate `zone_contains` (worker_service.gd:385) vẫn chặn mọi việc thật ngoài zone;
  chỉ miễn cho `kind == "patrol"`.
- Điểm tuần phải qua kiểm tra va chạm bằng footprint thật của worker (kiểu
  `_point_clear` trong `player_navigation_component.gd`); giới hạn số lần thử
  (không loop vô hạn), đạt yêu cầu "không quét toàn map".
- Điểm bị đi không tới (bị rào enclosing, nav fail) phải đi vào `blocked_targets`
  để không bị chọn lại ngay — tái dùng cơ chế hiện có.
- Save schema không được từ chối task patrol có điểm ngoài zone (cần xác minh khi
  làm — kind "patrol" đã tồn tại, chỉ tọa độ mới rộng hơn).

## Các cách đã cân nhắc

- **A — Điểm ngẫu nhiên on-demand (CHỌN):** khi cần patrol, lấy vài điểm ngẫu
  nhiên trong world bounds, thử kiểm tra clear bằng physics query, chọn điểm đầu
  tiên đạt; không điểm nào đạt sau N lần thử thì fallback về góc zone cũ (hành vi
  hiện tại). Mỗi lần chỉ tốn vài physics query, không cần cache và không cần vô
  hiệu hóa cache khi địa hình đổi (mỗi lần chọn đều kiểm tra lại tại thời điểm chọn).
- **B — Nới 4 góc thành 4 góc cả map (LOẠI):** rẻ nhất nhưng worker chỉ đứng rìa
  map, không đi qua làng — không đạt mục tiêu sống động.
- **C — Lớp wander kiểu `AnimalWanderComponent` (LOẠI):** chuyển động đẹp nhất
  nhưng xung đột kiến trúc: `worker_service` sở hữu chuyển động của worker đã thuê
  qua `row.task`; hai hệ thống cùng ra lệnh di chuyển. Rủi ro/công sức cao nhất.

## Quyết định đã chốt (gọi là của tôi — bạn có quyền phủ quyết)

1. **Áp cho cả 3 role** (bạn hỏi "worker" chung chung; ranch đi xa dễ trễ việc nhất
   nhưng patrol chỉ chạy khi không có việc nào cần làm ngay, và `next_wake` vẫn
   đánh thức ranch đúng lúc máng cạn).
2. **Nghỉ ngắn giữa các chặng dạo:** sau một task patrol, nếu lần quét tiếp vẫn
   chỉ có patrol, chèn nghỉ ngẫu nhiên ngắn (~1–3 giây) trước khi đi tiếp — để
   giống "đi dạo" chứ không chạy marathon.
3. **Fallback an toàn:** không tìm được điểm clear sau N lần thử → dùng góc zone
   cũ. Worker không bao giờ đứng đóng đinh vì thiếu điểm.

## Còn lại cho người làm (builder)

- Tham số cụ thể: số lần thử tối đa, khoảng nghỉ, khoảng cách tối thiểu giữa
  điểm mới và vị trí hiện tại.
- Đặt code lấy mẫu điểm ở đâu (helper nhỏ trong `worker_world_bridge.gd` hay class
  riêng) — ưu tiên khớp style hiện có.
- Viết test GUT trong `tests/integration/` (khổ mẫu: `test_crop_automation.gd`):
  worker rảnh nhận patrol point ngoài zone; việc thật ưu tiên hơn patrol; điểm
  patrol qua physics check; fallback khi không có điểm clear.
- Xác minh save schema chấp nhận patrol point mới (load save cũ không lỗi).
