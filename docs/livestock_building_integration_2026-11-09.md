# Bộ chuồng nâng cấp đã tích hợp

- `assets/Buildings/UpgradedLivestock/chicken_coop.png`: Coop mái đỏ 80×128, nối vào scene ChickenCoop.
- `assets/Buildings/UpgradedLivestock/cattle_barn.png`: Barn móng đá 128×144, nối vào scene CattleBarn.
- `assets/Buildings/UpgradedLivestock/goose_shelter.png`: Shed ngỗng 96×112, thay hình DuckShelter trong PondPen dùng chung cho vịt/ngỗng.

Giữ node và vị trí gốc của công trình trong MainWorld. Căn sprite theo chân và cập nhật collider chân tường cho silhouette mới: Coop 46×36, Barn 100×40, shelter 70×26. Các cửa trong hình là chi tiết trang trí, chưa có scene nội thất hoặc chuyển cảnh. Collider công trình chặn phần chân tường và cửa như vật cản thế giới.

Đã chạy preview Godot native MainWorld, kiểm tra kích thước cả ba texture và collider PondPen, xuất `.godot/livestock-upgraded.png`. Preview vô hiệu hóa process của world, không chạy quy trình hồ sơ người chơi. Không dùng thêm generation PixelLab.

Nhóm GUT `test_waterfowl.gd` và `test_barn_animals.gd` chạy 20 test nhưng 19 lỗi, 1 pending: các test còn giả định có đàn vật nuôi đặt sẵn (ví dụ Goose_1), số dư và fixture cũ. Scene trước chỉnh sửa cũng không còn Goose_1; không sử dụng kết quả này để khẳng định gameplay đã đạt test.

Runtime preview có cảnh báo UID cũ của catalog pet_shop từ thay đổi khác trong workspace; engine tải được qua text path. Lint được đối chiếu trước/sau trong `.godot/buildings-before.json` và `.godot/buildings-after.json`.
