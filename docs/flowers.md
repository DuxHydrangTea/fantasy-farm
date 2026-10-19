# Vườn hoa trong chậu

`FlowerGarden` nằm bên phải chuồng gà, tại `(1424, 288)`, rộng 384 × 256 px (24 × 16 tile), bằng kích thước CoopPen. Có 60 chậu, chia 4 cụm 5 × 3; khoảng cách ô 32 px, lối đi chữ thập rộng 32 px và viền 16 px. Tất cả chậu có collision nhỏ tại chân, hỗ trợ Y-sort với người chơi. Tile nền vườn riêng, không thay đổi terrain hoặc custom data FarmLand.

Vườn có sẵn 8 chậu hoa ở nhiều stage, gồm 2 chậu chờ tưới và 2 chậu đã nở để thu ngay. Các chậu còn lại trống. Hoa trồng sẵn được bổ sung một lần cho file lưu cũ, giữ nguyên những chậu người chơi đã trồng; thu hoạch rồi lưu/tải sẽ không mọc lại.

## Chơi

Mép trên vườn có đủ 10 mẫu hạt hoa, mỗi mẫu 6 hạt. Đi gần để nhặt. Mở túi đồ bằng I, kéo hạt hoa vào một trong 6 ô hotbar. Đứng gần và quay mặt về chậu cần dùng (tầm 28 px):

1. Chọn hạt hoa, chuột phải hoặc phím dùng vật phẩm để gieo.
2. Chọn bình tưới rồi dùng trên chậu đã gieo. Tưới một lần bắt đầu chu kỳ 120 giây.
3. Hoa lớn qua 5 stage; mỗi stage có animation 6 frame riêng. Khi nở hoàn toàn, nhấn E để thu vào túi đồ. Chậu giữ lại để tái sử dụng.

Chậu được focus có viền, hướng dẫn và progress bar cùng asset với cây trồng. Hoa chưa tưới giữ nguyên stage đầu kể cả khi offline; hoa đã tưới tiếp tục lớn theo timestamp. Tưới lặp không reset thời gian. Túi đầy thì giữ nguyên hoa để thu sau. Gieo/thu chỉ thực hiện một lần tại impact frame, khóa chậu và stack hạt trong lúc animation chạy. Di chuyển ra xa, mở inventory để hủy thao tác, hoặc dời stack hạt trước impact sẽ không tiêu hao hạt.

## Tài nguyên và thành phần

- `flowers/definitions/flower_01.tres` … `flower_10.tres`: thời gian lớn, 5 SpriteFrames và sản phẩm.
- `flowers/frames`: 50 stage, dùng sheet `Potted/Flowers_1...5_Potted_Anim.png`, mỗi hàng là một mẫu, 6 cột là animation.
- `items/seeds/flower_01_seed.tres` … `flower_10_seed.tres` và `items/flowers/flower_01.tres` … `flower_10.tres`: hạt/sản phẩm. Tên đánh số theo asset vì bộ sprite không cung cấp tên thực vật.
- `FlowerPot`: trạng thái và hình ảnh từng chậu, không sở hữu inventory hoặc đồng hồ toàn cục.
- `FlowerGarden`: tọa độ grid, danh sách chậu và một subscription TimeManager cho cả vườn. Preview editor tạo 60 chậu tạm, không serialize bản sao vào scene.
- `FlowerInteraction`: focus và thao tác dùng chung animation/state/hotbar của player. Máng ăn/uống giữ ưu tiên hiện có; focus đất ẩn khi đang focus chậu.

## Lưu tiến trình

Save schema version 2 thêm `flower_gardens`: ID vườn, cell chậu, loại hoa, `planted_at`, `growth_started_at` (-1 nếu chưa tưới), `matures_at`, tiến độ cao nhất. File version 1 được migrate trong bộ nhớ, giữ nguyên dữ liệu cũ; lần lưu kế tiếp ghi version 2. Vườn mới chưa có trong snapshot nhận 8 chậu trồng sẵn và nguồn hạt mặc định. Sau lần lưu mới, hạt đã nhặt không xuất hiện lại. Migration cũng áp dụng khi phục hồi `.bak` version 1.

GUT: `test_flower_pots.gd`, `test_flower_garden.gd`, các test bổ sung trong `test_world_persistence.gd` và `test_save_repository.gd`. Preview độc lập: chạy `tests/support/flower_garden_preview.gd`; không bind hồ sơ thật và chỉ tạo hình minh họa dưới `.godot`.
