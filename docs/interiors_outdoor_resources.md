# Resource Houses Interiors và Outdoor Decoration

## Sàn, tường và cầu thang

Nguồn: `res://assets/Buildings/Houses_Interiors`.
Gán `res://tilesets/house_interiors/house_interiors_tiles.tres` vào
`TileMapLayer.tile_set` để vẽ sàn, tường, khung nhà kính và cầu thang.
TileSet dùng lưới 16 × 16, gồm 7 atlas source và 254 ô có pixel hiển thị.
Chọn nhiều ô cùng lúc để đặt cụm tường, khung hoặc mẫu sàn đúng như sheet gốc.

| Source ID | Sheet | Số tile |
|---:|---|---:|
| 0 | Brick_Wall_Fillers | 4 |
| 1 | Greenhouse_Interior_Tiles | 114 |
| 2 | Interior_Walls | 54 |
| 3 | Stone_Wall_Fillers | 4 |
| 4 | Wood_Floor_Tiles | 62 |
| 5 | Wood_Stairs | 8 |
| 6 | Wood_Wall_Fillers | 8 |

Source ID cố định theo bảng; khi bổ sung sheet, thêm ở cuối danh sách trong generator.
Atlas bật texture padding. Resource chứa phần hình ảnh; collision, terrain,
y-sort và xử lý di chuyển qua cầu thang cần cấu hình theo scene/gameplay.

## SpriteFrames ngoài trời

14 resource nằm trong `res://sprite_frames/outdoor_decor`. Gán vào
`AnimatedSprite2D.sprite_frames`, rồi phát animation tương ứng. FPS mặc định: 8.

| Resource (`*_frames.tres`) | Canvas | Animation |
|---|---|---|
| `campfire` | 16 × 32 | `burn`: 8 frame, loop |
| `torch` | 16 × 32 | `burn`: 8 frame, loop |
| `small_torch` | 16 × 16 | `burn`: 6 frame, loop |
| `big_torch` | 16 × 48 | `burn`: 8 frame, loop |
| `fireplace_01`, `fireplace_02` | 32 × 48 | `burn`: 8 frame, loop; hai hàng màu của sheet |
| `fountain` | 32 × 48 | `flow`: 8 frame, loop |
| `horizontal_gate_01`, `horizontal_gate_02` | 48 × 32 | `closed`, `open`, `opened`, `close` |
| `vertical_gate` | 32 × 80 | `closed`, `open`, `opened`, `close` |
| `barrel` | 48 × 48 | `idle`, `break`: 5 frame, `broken` |
| `crate` | 48 × 48 | `idle`, `break`: 6 frame, `broken` |
| `sign_01`, `sign_02` | 48 × 48 | `idle`, `break`: 5 frame, `broken` |

Cổng ngang: `01` lấy hàng trên, mở cánh lên; `02` lấy hàng dưới, mở cánh xuống.
Cổng dọc dùng cả hai cánh trong cùng một khung 32 × 80.
`open` lấy 5 frame từ trái sang phải; `close` đảo ngược chuỗi.
Cả hai chạy một lần. `closed` giữ frame đầu, `opened` giữ frame cuối.
Sau khi `animation_finished`, gameplay có thể chọn trạng thái giữ tương ứng và đổi collision.

Đồ phá được: `idle` giữ frame đầu; `break` phát toàn bộ chuỗi một lần;
`broken` giữ frame cuối với mảnh vỡ. Gameplay quyết định giữ mảnh vỡ hay xoá node
sau khi animation kết thúc. Canvas luôn giữ nguyên 48 × 48 để mảnh vỡ có đủ chỗ.

PNG gốc nằm trong `assets/Outdoor decoration`: `Big_Torch_Anim.png` ở thư mục gốc,
các nguồn còn lại ở `Outdoor_Decor_Animations/Other_Animations` và `Break_Animations`.
Resource tham chiếu PNG gốc; các frame là AtlasTexture với `filter_clip` bật.

## Tạo lại

Chạy từ thư mục dự án:

```sh
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- generate --group=sprite_frames/outdoor_decor
```

Generator kiểm tra danh sách sheet nội thất, kích thước 19 PNG nguồn và vùng frame
trước khi lưu resource. Các animation ngoài trời được chọn theo danh sách trong generator.

Các lệnh dùng biến `FARM_GODOT` trỏ đến Godot .NET. Output mặc định nằm trong `.godot/generator-check`; xem README để áp dụng có chủ đích vào dự án.
