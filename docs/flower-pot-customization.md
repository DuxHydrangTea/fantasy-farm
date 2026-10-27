# Chỉnh chậu và hoa trong Godot

## Các file chính

- `scenes/flowers/flower_garden.tscn`: 80 instance (mỗi khối 5 cột × 4 hàng) được lưu thật, chia bốn node `BlockTopLeft`, `BlockTopRight`, `BlockBottomLeft`, `BlockBottomRight` dưới `Pots`.
- `scenes/flowers/flower_pot.tscn`: mẫu một vị trí trồng.
- `resources/pots/clay_pot.tres`: cấu hình chậu đất nung mặc định.
- `assets/Flowers/Unzoom30/clay_pot_32x24.png`: texture chậu dùng trực tiếp cho cả chậu trống và chậu có cây.
- `assets/Flowers/Unzoom30/flower_*.png` và `flowers/frames/*.tres`: art/animation cây, không chứa chậu.

## Di chuyển vị trí trồng

Mở `flower_garden.tscn`, chọn một node `Pot_xx_yy` hoặc node khối rồi kéo trong viewport. Lưu scene. Runtime đăng ký các node này, không tự dựng lại lưới hay reset `position`.

Giữ nguyên `Cell` của mỗi chậu: đây là định danh cây trong save, không phải vị trí trên màn hình. Mỗi cell phải duy nhất; cảnh báo cấu hình báo cell trùng, thiếu slot hoặc thiếu chỗ tổ ong.

Chọn root `FlowerPot` khi muốn di chuyển cả hình, collision và điểm tương tác. `VisualRoot` chỉ điều chỉnh phần nhìn thấy.

## Chỉnh riêng vị trí cây

Mở các child node của instance (đã bật Editable Children), chọn:

`VisualRoot/PlantSocket/PlantOffset`

Chỉnh `Position` tại đây. Tăng Y một pixel sẽ hạ cây thêm một pixel. Giá trị mặc định đã giữ độ hạ cây ba pixel so với bản ghép ban đầu; không cần đặt Y=3 lần nữa. Các lần tưới/refresh/chuyển stage không ghi đè offset này.

`PlantSocket` là mốc chung của loại chậu; `PlantOffset` là phần chỉnh riêng cho instance. `Flower` giữ khung cây 32x32 với gốc tại pixel y=30.

## Sửa ảnh chậu hoặc thêm loại chậu

Sửa PNG đang được `PotDefinition.Texture` tham chiếu rồi để Godot reimport. Chạy lại game nếu cửa sổ game đang giữ texture cũ. Không có bước ghép ảnh/bake lại.

Để thêm loại chậu, tạo một Resource `PotDefinition`, đặt `Pot Id`, chọn `Texture`, chỉnh `Pot Offset` và `Plant Socket`, rồi gán resource đó vào `Pot Definition` của root FlowerPot. Một resource dùng chung sẽ cập nhật tất cả instance cùng loại. Dùng resource mới hoặc Make Unique nếu muốn chỉnh một loại/instance mà không ảnh hưởng các chậu khác.

Đổi skin không thay cây, thời gian lớn, sản lượng hay dữ liệu kho. Collision giữ nguyên cấu hình gốc, có thể chỉnh riêng khi chủ động thiết kế một loại chậu có gameplay khác.

## Preview trong editor

`Preview Flower` và `Preview Stage` của root FlowerPot chỉ điều khiển hình trong editor. Chúng không đặt `definition`, trừ hạt giống, tăng thời gian hoặc ghi save. Khi chạy, dữ liệu cây thực tế được ưu tiên.

## Lưu game và ong

Save vẫn dùng các ID `cell` hiện tại. Vị trí scene và skin cấu hình trong scene không bị save ghi đè. Các cây dư từ layout cũ 180 slot vẫn được giữ trong save; chỉ đưa vào chậu trống khi tải save hoặc mở khóa vườn. Thu hoạch hoặc xóa cây luôn để lại chậu trống, không tự trồng cây khác từ hàng đợi.

Ba tổ ong cố định lấy vị trí từ các chậu thực tế. Khi tải save sau khi chỉnh scene, vị trí lưu của tổ ong cố định được căn về slot tương ứng; hive thường vẫn được kiểm tra placement như trước. Các phép đo khoảng cách và overlay đã dùng tọa độ thực tế qua parent của node khối.

## Bảo trì

Không chạy lại công cụ authoring một lần trong `output/flower_scene_refactor/build_scenes.gd` sau khi đã custom scene; nó dùng bố cục chuẩn để tạo scene ban đầu. Chỉnh scene trực tiếp từ đây trở đi.

`scripts/setup/prepare_flower_layers.py` chỉ chuẩn bị các frame cây từ nguồn animation gốc, không sửa texture chậu. Script ghép chậu cũ và các PNG `_potted` đã được loại khỏi asset đang dùng.

Bố cục hiện tại giữ Cell 0–4 và 7–11 theo chiều X để không đổi định danh cây cũ. Những cell đã bỏ vẫn đọc được từ save và được giữ trong hàng đợi. Ba slot ong giữ nguyên định danh slot, lấy vị trí mới từ các cell (1,2), (1,6), (8,2) để mỗi tổ có đủ tám ô hoa xung quanh.
