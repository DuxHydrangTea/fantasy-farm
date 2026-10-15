# Thư viện scene object

Generator có thể tạo 1.737 scene từ resource đã chuẩn bị:
8 NPC, 25 object có animation, 1.326 nội thất tĩnh, 51 cây trồng/biển và 327 vật phẩm.
Kéo `.tscn` vào map để đặt object. Danh mục đầy đủ:
`docs/object_scenes_index.json`. Các scene và index đã được xoá để viết lại game;
chạy generator để tạo lại khi cần. Scene mới được xuất theo tính năng.

## Cấu trúc

- NPC: `CharacterBody2D` → `AnimatedSprite2D`, `CollisionShape2D`.
- Vật tĩnh có animation: `StaticBody2D` → `AnimatedSprite2D`, `CollisionShape2D`.
- Vật tĩnh không có animation: `StaticBody2D` → `Sprite2D`, `CollisionShape2D`.

Các scene không gắn script hành vi, tương tác hay điều khiển. Gốc object đặt ở
đáy pixel hiển thị của sprite khởi đầu để dễ đặt lên mặt đất. Cây trồng dùng vùng
hình bao đủ các giai đoạn để giữ cùng vị trí gốc khi đổi texture. Sprite dùng lọc nearest.
Vị trí sprite giữ nguyên trong lúc animation phát, giúp giữ canvas giữa các frame.

654 scene thuần hình ảnh không có CollisionShape2D: vật phẩm, cây trồng nhỏ,
lửa/đuốc/khói, thảm, cửa sổ, gương/đồng hồ/khăn treo tường, vòi/nút,
giá treo nồi, đèn bàn và đồ trang trí nhỏ. Root vẫn giữ StaticBody2D.
Quy tắc nằm ở `tools/setup/data/object_collision_policy.json`; generator dùng
cùng quy tắc khi tạo mới. Chạy `python3 tools/setup/remove_visual_scene_collisions.py`
để áp dụng lên scene đã có, giữ các chỉnh sửa khác.

1.083 scene còn CollisionShape2D có RectangleShape2D làm footprint tham khảo.
Collider của generator mặc định **disabled = true**.
Chỉnh kích thước, vị trí, collision layer/mask rồi bật khi bắt đầu làm gameplay.
Kích thước khung này không phải collision được xác định chính xác từ hình.
Y-sort cần bật ở node cha quản lý các object trên map.

## Các nhóm

| Thư mục tính năng (từ `res://`) | Nội dung |
|---|---|
| `entities/npcs` | 8 NPC premade, kể cả Farmer Bob ở vai trò NPC độc lập |
| `world/decorations/house/animated` | 11 scene: rương, lò, đe, khói |
| `world/decorations/house/<sheet>` | Nội thất theo ma trận nguyên khối: cửa, giường, ghế, tủ, đèn, bàn, chậu, thiết bị… |
| `world/decorations/outdoor` | 14 scene: cổng, thùng/biển phá được, lửa, đuốc, lò sưởi, đài phun nước |
| `features/farming/crops/field` | 22 loại cây trồng, mặc định stage_01 |
| `features/farming/crops/signs` | 22 biển cây trồng |
| `features/farming/crops/fruit_trees` | 4 cây ăn quả, mặc định hình có quả |
| `features/farming/crops/berries` | Bụi quả đỏ và tím, mặc định appearance_01 |
| `features/farming/crops/grapes_bower.tscn` | Giàn nho, mặc định stage_05 |
| `features/inventory/items` | Vật phẩm từ icon outline/no_outline, hạt giống, hình thu hoạch và quả |

344 mảnh mặt bếp module, sàn/tường của TileSet và icon giao diện không được biến
thành scene riêng cho map. Các icon được dùng ở `features/inventory/items` là phiên bản vật phẩm
đặt dưới đất; giao diện vẫn dùng resource texture trực tiếp.
Thư viện không sinh scene động vật, enemy hay bộ điều khiển thời tiết.
Các scene buildings, cây và player có sẵn nằm ở thư mục scene hiện tại.

Rương/cổng mặc định `closed`, lò `off`, đe/thùng/biển `idle`, NPC `idle_down`.
Lửa, đuốc, lò sưởi, khói và nước tự phát animation loop đã chọn.
Các thao tác `open`, `close`, `break` sẽ do logic tương tác của bạn phát sau.

## Texture theo giai đoạn/biến thể

Cây trồng, cây ăn quả và giàn nho có metadata `growth_textures` ở node gốc:
các Texture2D theo thứ tự stage đã chuẩn bị. Các texture là resource tham chiếu
được lưu trong scene, không phải animation chạy tự động.
Hai bụi quả dùng metadata `appearance_textures` gồm 4 hình; không giả định đây
là các giai đoạn tăng trưởng. Khi viết logic, chọn texture rồi gán cho Sprite2D.

Tên scene cây trồng, biển, hạt giống và thu hoạch dùng chung tên loại cây, ví dụ
`features/farming/crops/field/wheat.tscn`, `features/farming/crops/signs/wheat_sign.tscn`,
`features/inventory/items/seeds/wheat_seed.tscn`, `features/inventory/items/harvest/wheat_harvest.tscn`.
Icon vật phẩm có tên riêng cho cả hai style, ví dụ `features/inventory/items/outline/tools/pickaxe.tscn`.
Metadata `object_id` trên các scene cây trồng, vật phẩm và outdoor là tên file không
có đuôi. `object_kind` vẫn mô tả nhóm (crop, seed, harvest, tools...).

Bảng tên được lưu ở `tools/setup/data/object_scene_names.json`, với tên cây trồng
đã được người dùng đồng ý. Quặng/crystal chưa có tên loại từ asset dùng màu sắc,
không tự gán thành kim loại giả tưởng. Resource cây trong `features/farming/crops/field` dùng cùng
tên cây với scene, ví dụ `features/farming/crops/field/wheat/stage_01.tres`. Key `crop_01` … `crop_22`
trong catalog vẫn chỉ định hàng của PNG; vùng cắt atlas không thay đổi.
Nội thất giữ index biến thể như trước. Xem bảng tên trong `docs/object_scene_names.md`.

Nếu còn bản scene tên cũ, chạy `python3 tools/setup/rename_object_scenes.py`
trước khi chạy generator. Công cụ đổi tên giữ nội dung scene, cập nhật đường dẫn
tham chiếu và từ chối ghi đè nếu cả tên cũ và tên mới cùng tồn tại.

## Tạo lại

```sh
godot --headless --path . --script res://tools/setup/setup_object_scenes.gd
```

Mặc định generator giữ các scene đã tồn tại để bảo vệ chỉnh sửa trên scene.
Muốn tạo lại toàn bộ scene do generator sinh:

```sh
godot --headless --path . --script res://tools/setup/setup_object_scenes.gd -- --overwrite
```

Lệnh overwrite áp dụng các đường dẫn tính năng trong `SCENE_ROOTS` của generator.
Generator kiểm tra resource, animation mặc định và vùng atlas nội thất trước khi lưu.
