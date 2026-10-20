# Khu nuôi vịt/ngỗng

`PondPen` dùng vùng ao và bờ đã vẽ trong MainWorld: gốc `(1424, 592)`, bounds `384 × 272`. Có 5 mẫu vịt (gồm vịt đội mũ), 6 mẫu ngỗng trưởng thành, máng thức ăn/nước riêng và 5 gói poultry feed gần cửa. Hai tile hàng rào bên trái `(89,38)` và `(89,39)` được mở để người chơi vào chăm sóc, nhặt trứng. Các layer mặt đất, ao và Fisherman_House giữ bố trí hiện có.

## Di chuyển và hình ảnh

- Vịt đi bộ trên bờ, dùng `swim`, `swim_idle`, `swim_sleep` khi ở nước. Nằm/ngủ trên nước không chạy chuỗi đứng dậy trên cạn.
- Ngỗng dùng animation trên cạn, không đi vào tile nước. Cùng pen, máng và hệ nhu cầu với vịt.
- `pond_pen.gd` xây hai AStarGrid2D, ô 16 px, đường đi 4 hướng. Graph chung cho vịt đi cả bờ/nước; graph đất chặn nước cho ngỗng. Cả hai loại trừ hàng rào, nhà và máng theo physics layer 1, footprint 10 × 6 px. Không cắt đường chéo qua góc vật cản.
- Nhận biết nước bằng chính FarmLand, source 1, terrain 1; nếu đổi TileSet cần cập nhật các export `water_source`, `water_terrain`, `water_layer` trên instance PondPen. Tile viền đá terrain -1 được coi là bờ.
- Navigation chờ 2 physics tick khi mở/tải game để collider ổn định. Đổi vật cản/terrain bằng code trong runtime cần gọi `rebuild_after_load()` hoặc `rebuild_navigation()` sau khi physics cập nhật.

`WaterfowlComponent` chỉ gắn cho actor có `eggs_on_land` trong PondPen. Wander/Foraging dùng các phương thức destination chung; động vật ở pen cũ giữ cách di chuyển hiện tại. AnimationComponent có mapper tùy chọn cho hình ảnh môi trường, tín hiệu kết thúc animation giữ tên action gốc.

## Trứng, nhu cầu và offline

Chu kỳ resource hiện tại: trứng vịt 40 giây, trứng ngỗng 50 giây. Tuổi/no/nước, điều kiện sản xuất và progress bar dùng các component chung. Máng của chuồng khác không được dùng; tìm máng từ dưới ao đi qua đường AStar thay vì kiểm tra đường thẳng.

Trứng đủ chu kỳ dưới nước nằm trong `ProductionComponent.stored_amount`, chưa tạo pickup và chưa cộng vào đống trứng cũ. Vịt tự tìm đường lên một vị trí bờ đi tới được rồi mới thả; trứng xuất hiện ở ô đất trống, không rơi xuống ao dù chim đứng sát mép nước. Các đợt sau cộng vào đúng đống sản phẩm của con đó.

Offline tiếp tục tính tuổi/giảm no/nước, sản xuất chỉ tính thời gian được cung cấp đủ no/nước theo hệ cũ. Không mô phỏng đi lại, ăn/uống hoặc bơi trong lúc đóng game. Nếu tải lên khi vịt còn dưới nước, trứng tích lũy giữ nguyên trong stock và chờ chim lên bờ. Route và trạng thái tìm bờ được tính lại khi chạy, không serialize các waypoint/handle của engine.

## File lưu cũ

Snapshot version 2 bổ sung danh sách ID `animal_pens` để phân biệt chuồng mới với chuồng đã được người chơi lưu. Với file cũ thiếu danh sách này, suy ra các chuồng hiện có từ vật nuôi và máng trong snapshot. PondPen mới giữ đàn/máng/thức ăn mặc định; các chuồng cũ vẫn được phục hồi đúng dữ liệu. Sau lần lưu mới, chim bị xóa hoặc thức ăn đã nhặt không tự xuất hiện lại. Trạng thái trứng đang giữ dùng trường stock đã có.

GUT: `tests/integration/test_waterfowl.gd` kiểm tra 11 skin, va chạm spawn, animation, bờ/nước, đường tới máng, lên bờ đẻ, patrol, file roundtrip và khởi tạo chuồng mới từ save cũ. Preview: `tests/support/waterfowl_preview.gd`, không bind hồ sơ thật.

Kiểm chứng cửa vào: hai ô Fence `(89,38)` và `(89,39)` đều trống (source -1); shape chân player đi qua được cả hai hàng cửa. Lượt GUT sau sửa đạt 282/282 test toàn project.
