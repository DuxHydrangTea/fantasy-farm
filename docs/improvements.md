# Cải thiện hiệu năng và dọn code

## Nội dung đã triển khai

- Loại bỏ 7 script legacy (4 controller, needs cũ và 2 focus cũ), UID sidecar, scene `farmer_bob.tscn` đã được thay bằng `player.tscn`, theme UI cũ, cấu hình .NET và output `tests/Core/bin`, `obj`. `.gitignore` chặn build output quay lại. Tài liệu thiết kế cũ được đánh dấu lịch sử và trỏ mã đã xoá về commit gốc.
- `PlayerNavigationComponent` giữ AStarGrid2D/occupancy cache qua các lần click. Sampling được chia theo ngân sách 256 ô/physics frame; lúc rảnh tiếp tục bake nền. Unknown cells tạm được coi là solid. Cold click chờ vài frame; mục tiêu xa/không tới được có thể cần chờ bake nhiều hơn, nhưng không chặn input/render. Keyboard, click mới và mở inventory huỷ ngay. Kiểm tra shape/cast khi đi và replan vẫn được giữ.
- Geometry mới/xoá, TileMap có collision thay đổi, load save, footprint hoặc giới hạn map đổi sẽ invalidation cache. Công trình đổi vị trí/collision trực tiếp lúc chạy cần gọi `navigation.invalidate_region(rect)` hoặc `invalidate_cache()`. Shape query được dùng lại; smoothing giới hạn số cast thêm.
- Autosave dùng `write_profile_async`: Thread xử lý đọc file, parse/serialize JSON, hash, ghi/flush/kiểm tra temp và xoay backup. Main thread chỉ capture node, kiểm tra schema/catalog và cập nhật service. DTO được copy trước await; worker không đọc Resource/Node. Thread được join trước khi báo lưu xong; close chờ operation_finished. API sync vẫn dành cho công cụ/test, backend online cũ được hỗ trợ qua fallback.
- Revision của service vẫn được cache, nhưng không bỏ kiểm tra file: hash được đối chiếu lại trước commit để phát hiện sửa file bên ngoài; primary hỏng không được xoay đè backup tốt. Cơ chế này vẫn không phải transaction hỗ trợ hai process ghi đồng thời.
- Input dùng action `harvest`, `interact`, `click_move`, `use_item`, `toggle_inventory`, `ui_cancel`. Mặc định: E thu hoạch; Space/chuột phải hoặc gamepad X dùng đồ; chuột trái di chuyển; I/Tab hoặc gamepad Y mở túi; Esc/gamepad B đóng; gamepad A tương tác. GUI tiếp tục được xử lý trước world; inventory không nuốt phím save/debug không liên quan.
- Inventory có `get_slot_item/count`, `is_empty_slot`; UI/selection không clone Dictionary cho từng lần đọc. `slot()` vẫn trả bản sao để bảo vệ state và giữ tương thích API cũ.
- GrowthSchedule dùng min-heap deadline và weak reference: cây/hoa chỉ refresh khi tới stage tiếp theo. Cây đã chín/chậu chưa tưới không được quét mỗi tick. Focus/hover refresh riêng đối tượng đang hiện để thanh tiến độ vẫn mượt; capture/harvest cập nhật timestamp chính xác. Reset/load và cây bị xoá không để lịch cũ tác động tới cây mới.
- Impact được clamp theo số frame thật. Tín hiệu animation_changed deferred bảo đảm animation chỉ có một frame vẫn thực thi đúng một lần; mở túi/rời tầm/đổi stack vẫn có thể huỷ thao tác.

## Audit resource

Chạy `python scripts/maintenance/audit_resources.py --output .godot/resource-audit.json`. Audit theo cả đường dẫn, UID, thư mục tải động và root catalog/setup/test. Danh sách review không tự động bị xoá: scene công trình và TileSet chưa đặt trong MainWorld vẫn là thư viện editor/setup. Sprite, font, license, asset nguồn và resource dùng bởi save/catalog được giữ lại.

Không thay đổi schema version 3 hay định dạng save trong đợt tối ưu này. Test save dùng thư mục riêng; không sửa hồ sơ người chơi.

## Kiểm tra

GUT toàn bộ `tests/unit` và `tests/integration`, gồm test mới cho ngân sách/caching tìm đường, remap input, shortcut khi mở túi, heap/stage deadline, animation một frame, lưu worker không chặn frame, copy DTO, recovery và xung đột trước commit. Smoke MainWorld dùng hồ sơ tạm riêng và kiểm tra save/load thật.
