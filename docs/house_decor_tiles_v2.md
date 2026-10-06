# House Decor TileSet v2

Resource: `res://tilesets/house_decor/house_decor_tiles.tres`.
Generator: `res://scripts/setup/setup_house_decor_tiles_v2.gd`.
Ma trận vùng chọn: `res://scripts/setup/data/house_decor_selection_matrix_v2.json`.

V2 tạo một tile Godot cho mỗi vùng chọn của đồ vật, bằng
`TileSetAtlasSource.create_tile(atlas_coords, size_in_atlas)`.
Ví dụ cửa dùng `size_in_atlas = Vector2i(1, 2)` — vùng ảnh 16 × 32,
chọn và đặt nguyên cửa bằng một tile. Lưới cơ sở của TileSet vẫn là 16 × 16.

Ma trận được xác định từ 19 PNG trước khi chạy generator. Không suy ra vùng chọn
bằng cách tạo một tile cho mọi ô có alpha. Generator chỉ dùng alpha để kiểm tra
vùng đã khai báo: không trống, không chồng lấn và không bỏ sót phần hình.
Hash SHA-256 và kích thước PNG giúp phát hiện sheet thay đổi cần kiểm tra lại.

## Các vùng chọn

1.670 vùng, trong đó 1.138 vùng có kích thước lớn hơn 1 × 1.
Source ID giữ thứ tự sheet của bản đầu:

| ID | Sheet | Vùng | Kích thước vùng (ô atlas) |
|---:|---|---:|---|
| 0 | Bathroom_Furniture | 70 | Chậu 1×2; bồn 2×2 / 1×3; toilet, gương, khăn theo từng hình |
| 1 | Beds | 24 | 2×2 / 1×2 |
| 2 | BookShelves | 18 | 1×2 / 2×2 / 2×3 |
| 3 | Carpets | 104 | 3×3 / 2×2 / 1×1 |
| 4 | Chairs | 168 | Ghế 1×2; sofa 2×2; ghế đẩu 1×1 |
| 5 | Clocks | 10 | Đồng hồ đứng 1×2; đồng hồ treo 1×1 |
| 6 | Doors | 72 | **Tất cả 1×2** |
| 7 | Fireplaces | 4 | 2×3 / 1×3 |
| 8 | Furnaces | 2 | 1×2 |
| 9 | Furniture_Other | 71 | Tủ, bàn 1×1 / 1×2 / 2×1 / 2×2; piano 2×3 |
| 10 | House_Plants | 201 | Cây 1×2; cây lớn 3×2; chậu rỗng 1×1 |
| 11 | Indoor_Decor | 52 | Theo từng hình: ghế dài, giường, lò, chậu, biển, thùng |
| 12 | Kitchen | 568 | 344 mảnh mặt bếp module 1×1; 224 tủ 1×2 |
| 13 | Kitchen_Furniture | 20 | Thiết bị 1×2; giá treo 2×2 / 1×2 |
| 14 | Placeable_Decoration | 78 | Đồ nhỏ 1×1 |
| 15 | Planters | 18 | 3×1 / 2×1 / 3×2 / 2×2 |
| 16 | Standing_Lamps | 90 | 1×2 |
| 17 | Tables | 84 | Bàn ngang 4×3 / 3×3; bàn dọc 3×4 |
| 18 | windows | 16 | 1×2 / 2×2 |

Bàn và chậu cây có một số cạnh không trùng lưới 16 px. Vùng chọn bao đủ pixel,
kể cả chân bàn và mép lá, nên bàn ngang lớn cần 4×3 thay vì cắt còn 3×2.
Một số vùng giữ khoảng trong suốt để bao trọn hình hoặc giữ chung canvas giữa các hướng.
Phần mặt bếp ở đầu `Kitchen.png` là mẫu ghép module, giữ từng mảnh 1×1 để lắp
các cạnh và góc. Tủ phía dưới được gom nguyên hình 1×2.

## Xem và sửa ma trận

Mở `docs/house_decor_tiles_v2_preview.html` bằng trình duyệt. Trang tự chứa PNG
và ma trận; chọn sheet, bật/tắt viền, phóng ảnh và bấm vào vùng để xem ảnh cắt
cùng tọa độ. Trang mặc định mở sheet Doors.

Trong JSON, mỗi phần tử `groups[].rects[]` là `[x, y, width, height]`, đơn vị ô
16 px, tọa độ bắt đầu từ 0 ở góc trên trái. Ví dụ:

```json
[0, 0, 1, 2]
```

Vùng cửa đầu tiên bắt đầu tại atlas `(0, 0)`, rộng 1 ô, cao 2 ô.
Sửa rectangle trong JSON, rồi chạy lại:

```sh
godot --headless --path . --script res://scripts/setup/setup_house_decor_tiles_v2.gd
```

Generator kiểm tra toàn bộ ma trận trước khi tạo atlas, rồi lưu TileSet và trang preview.
Nếu thay PNG, cần kiểm tra lại vùng chọn và cập nhật `size_px` / `sha256` tương ứng.

TileSet theo ma trận hiện dùng tên chính `house_decor_tiles.tres`.
Gán resource vào `TileMapLayer.tile_set`. Map đã dùng bản chia ô cũ cần chọn/đặt lại
đồ vật vì atlas anchor và kích thước tile đã thay đổi, dù source ID của PNG giữ nguyên.
Collision, y-sort và texture origin được cấu hình theo scene; resource giữ texture
origin mặc định của Godot.
