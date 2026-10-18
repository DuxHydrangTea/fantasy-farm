# Trồng và thu hoạch

- Hotbar bắt đầu với cuốc, bình tưới và 12 hạt cà rốt ở ô 3.
- Cuốc đất trước, chọn hạt, hướng vào ô liền kề rồi chuột phải / Space để trồng.
- Chỉ trồng trên DrySoil hoặc WetSoil có custom data `can_plant`, không có cây,
  vật cản hoặc dấu chiếm chỗ. Trừ đúng một hạt ở stack đã chọn tại frame tác động.
- Tưới vẫn dùng bình tưới ở ô 2. Cây không chặn việc tưới đất của chính nó.
- Nhấn E khi đứng trước cây chín để thu hoạch vào túi. Túi phải chứa được toàn bộ
  sản lượng; nếu không đủ chỗ cây vẫn giữ nguyên. Thu hoạch giữ đất để trồng lại.

## Thời gian và hình ảnh

`TimeManager` là autoload cung cấp Unix timestamp, phát `tick` mỗi 0,1 giây để
cập nhật hình ảnh. Thời gian sinh trưởng **không cộng delta mỗi frame**:

`progress = clamp((now - planted_at) / (matures_at - planted_at), 0, 1)`

Mỗi cây giữ `planted_at` và `matures_at`; thời hạn trưởng thành được chốt khi trồng
bằng `growth_seconds` trong CropDefinition. Stage 1: 0–<1/3; stage 2: 1/3–<2/3;
stage 3: 2/3–<100%; stage 4: 100%, thu hoạch được. Nhảy thời gian hoặc rớt frame
vẫn tính đúng tiến độ. Đồng hồ lùi không làm cây nhỏ lại. Pause/mở túi không đổi
thời hạn; khi cập nhật tiếp sẽ bắt kịp giờ thực.

22 resource hiện có dùng trực tiếp bốn `stage_01`…`stage_04` tương ứng. Không đổi
thông số hiện có (cà rốt hiện là 10 giây). Nước chưa cộng bonus hoặc là điều kiện
tăng trưởng; đất chưa tự khô. Các luật này có thể bổ sung riêng.

Mỗi instance `scenes/crops/crop.tscn` đặt cùng tầng Y-sort với player, neo gốc vào
mép dưới ô đất. Thanh tiến độ dùng `assets/Ui/progress_bar.png`, luôn ở trên cây,
không chặn click; đầy thanh khi cây chín. Các loại cây dùng chung scene nhưng giữ
timestamp, tiến độ và texture riêng, không thay đổi resource dùng chung.

Chưa có save/load: timestamp sẵn để lưu nhưng cây và túi chưa tồn tại qua lần
thoát game. Vì vậy hiện chưa có tăng trưởng offline qua lần khởi động khác.

`docs/farming_design.md` là đề xuất cũ, dùng FarmPlot riêng và đếm delta;
triển khai hiện tại dùng TileMap cùng timestamp như tài liệu này.

## Kiểm tra

GUT: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`.
Test mới kiểm tra ngưỡng stage, nhảy/lùi timestamp, toàn bộ 22 resource, thanh
tiến độ, trồng/tưới, trừ hạt đúng stack, đổi hotbar/hủy trước frame tác động,
thu hoạch/túi đầy và vị trí cây khi map được dịch hoặc phóng to.
