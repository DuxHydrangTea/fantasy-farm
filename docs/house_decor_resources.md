# Resource House Decor

TileSet hiện gom nguyên đồ vật theo [ma trận vùng chọn](house_decor_tiles_v2.md)
và dùng tên chính `house_decor_tiles.tres`.

Nguồn: `res://world/decorations/house/art`, gồm 19 sheet tĩnh và 7 sheet animation.

## TileSet nội thất

`res://world/decorations/house/tilesets/house_decor_tiles.tres` có 19 atlas source và 1.670 vùng chọn.
Lưới cơ sở 16 × 16; mỗi đồ vật được gom vào một tile với kích thước atlas tương ứng,
ví dụ cửa 1 × 2 ô. Gán resource vào `TileMapLayer.tile_set` để vẽ nội thất.
Resource này chứa phần hình ảnh,
collision và y-sort cho đồ nội thất cần cấu hình theo cách đặt đồ trong scene.

Source ID được giữ cố định:

| ID | Sheet |
|---:|---|
| 0 | Bathroom_Furniture |
| 1 | Beds |
| 2 | BookShelves |
| 3 | Carpets |
| 4 | Chairs |
| 5 | Clocks |
| 6 | Doors |
| 7 | Fireplaces |
| 8 | Furnaces |
| 9 | Furniture_Other |
| 10 | House_Plants |
| 11 | Indoor_Decor |
| 12 | Kitchen |
| 13 | Kitchen_Furniture |
| 14 | Placeable_Decoration |
| 15 | Planters |
| 16 | Standing_Lamps |
| 17 | Tables |
| 18 | windows |

Khi thêm sheet mới trong generator, thêm ở cuối danh sách để giữ ID của các ô map đã vẽ.

## SpriteFrames

11 resource nằm trong `res://world/decorations/house/animations`. FPS mặc định 8.
Gán vào `AnimatedSprite2D.sprite_frames`, rồi chọn animation tương ứng.

| Resource | Khung | Animation |
|---|---|---|
| `chest_frames.tres` | 16 × 16 | `closed`, `open`, `opened`, `close` |
| `golden_chest_frames.tres` | 16 × 16 | Như trên |
| `metal_chest_frames.tres` | 16 × 16 | Như trên |
| `golden_jeweled_chest_01_frames.tres` … `05_frames.tres` | 16 × 16 | Như trên; mỗi resource lấy một hàng màu trong sheet |
| `furnace_frames.tres` | 16 × 32 | `off`: 1 frame; `burn`: 5 frame, loop |
| `anvil_frames.tres` | 16 × 16 | `idle`: 1 frame; `shine`: 8 frame, loop |
| `chimney_smoke_frames.tres` | 32 × 32 | `smoke`: 5 frame, loop |

Rương đọc 6 frame từ trái sang phải: `open` phát một lần, `close` dùng cùng chuỗi
đảo ngược và phát một lần. `closed` giữ frame đầu, `opened` giữ frame cuối.
Các biến thể rương đính đá đánh số hàng từ 1 đến 5, từ trên xuống.

Hình lò tắt lấy từ ô bên trái của `Furnaces.png`; animation cháy dùng toàn bộ
`Furnace_Anim.png`. Chuỗi đe thay đổi ánh sáng trên bề mặt, nên đặt tên `shine`.
Khói dùng 5 khung 32 × 32, không chia thành 10 mảnh 16 × 32.

Tất cả resource tham chiếu PNG gốc. AtlasTexture của animation bật `filter_clip`;
atlas của TileSet bật texture padding. Không bundle đường dẫn `.godot/imported`.

## Tạo lại

Chạy từ thư mục dự án:

```sh
godot --headless --path . --script res://tools/setup/setup_house_decor_resources.gd
```

Generator kiểm tra danh sách và kích thước sheet trước khi tạo resource.
Phần TileSet gọi `setup_house_decor_tiles_v2.gd` để dùng ma trận vùng chọn đã duyệt;
phần SpriteFrames tiếp tục tạo các animation trong bảng trên.
