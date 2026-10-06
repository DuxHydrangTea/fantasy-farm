# Resource hình ảnh cây trồng

181 `AtlasTexture` `.tres` trong `res://crops`, tạo từ `res://assets/Crops`.
Các resource này chứa hình ảnh; giai đoạn tăng trưởng được chọn bởi logic trồng trọt.
Không cấu hình animation loop hay thời gian tăng trưởng, giá bán hoặc sản lượng.

| Folder | Nội dung | Số resource |
|---|---|---:|
| `field/crop_01` … `field/crop_22` | Mỗi bộ: biển, hạt giống, 4 giai đoạn, hình thu hoạch | 154 |
| `fruit_trees/shared` | 3 giai đoạn cây ăn quả chưa có quả | 3 |
| `fruit_trees/apple`, `pear`, `peach`, `cherry` | Hình cây có quả, mỗi loại một `ready.tres` | 4 |
| `fruit_objects` | Nho, táo, lê, đào, cherry theo thứ tự sheet | 5 |
| `grapes_bower` | 5 trạng thái giàn nho | 5 |
| `berries/red`, `berries/purple` | Mỗi màu: 4 hình bụi và 1 hình quả thu hoạch | 10 |

## Mapping và khung ảnh

- `Crops.png`: 22 hàng × 7 cột, mỗi ô 16 × 32. `crop_01` là hàng đầu tiên,
  `crop_22` là hàng cuối. Tên theo hàng giúp đối chiếu chính xác mà không tự gán tên item.
  Cột 1 là biển, cột 2 là hạt, cột 3–6 là `stage_01` … `stage_04`, cột 7 là thu hoạch.
- Stage giữ toàn bộ khung 16 × 32 để cây thấp/cao có cùng vị trí gốc. Biển, hạt và
  hình thu hoạch nằm trong nửa dưới ô, được cắt 16 × 16 để dùng như icon.
- `Crops_2.png` trùng pixel với hàng 15–22 của `Crops.png`. Dùng resource ở
  `field/crop_15` … `field/crop_22`, không tạo lặp từ sheet này.
- Cây ăn quả giữ khung 32 × 64. Ba hình trong `Fruit_Tree_Stages.png` nằm trong
  `fruit_trees/shared`; hình có quả được lưu riêng theo tên PNG gốc.
- `Fruit_Trees_Fruit_Objects.png`: 5 ô 16 × 16, thứ tự trái sang phải là nho, táo,
  lê, đào, cherry. Đây là hình quả trong thế giới, khác các icon có viền ở nhóm khác.
- `Grapes_Bower.png`: khung 96 × 80; hàng trên có 3 hình, hàng dưới có 2 hình và
  một ô trống. `stage_01` … `stage_05` đọc trái sang phải, từ trên xuống.
- `Berries.png`: ô 16 × 16. Cột 1 và 3 có 4 hình bụi đỏ/tím từ trên xuống;
  cột 2 và 4 chỉ có hình quả ở hàng đầu. Các hình bụi được đặt `appearance_01`
  … `appearance_04`, chưa gán thành giai đoạn tăng trưởng hoặc animation.

Mọi AtlasTexture tham chiếu PNG gốc, bật `filter_clip`, không crop sát phần có màu
và không lưu đường dẫn cache `.godot/imported`.

## Sử dụng

Gán resource stage vào `Sprite2D.texture`. Ví dụ:

```gdscript
var stage_texture: Texture2D = preload("res://crops/field/crop_01/stage_01.tres")
```

Các `seed_icon.tres` và `harvest_icon.tres` có thể dùng với `TextureRect` hoặc
trường `Texture2D` trong dữ liệu item. Cây ăn quả dùng chung 3 hình tăng trưởng,
sau đó chuyển sang `fruit_trees/<loại>/ready.tres` khi có quả.

## Tạo lại

Chạy từ thư mục dự án:

```sh
godot --headless --path . --script res://scripts/setup/setup_crop_resources.gd
```

Generator kiểm tra kích thước của cả 10 PNG, xác nhận sheet trùng và xác minh
vùng cắt trước khi lưu. Nếu bố cục asset thay đổi, cập nhật mapping trước khi chạy lại.
