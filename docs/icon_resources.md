# Resource icon tĩnh

Đã tạo 276 `AtlasTexture` `.tres` từ `res://assets/Icons`, chia thành hai bản
`res://icons/outline` và `res://icons/no_outline`.

| Folder nhóm | Sheet nguồn | Resource / mỗi bản |
|---|---|---:|
| `food` | `Food_Icons` | 83 |
| `materials` | `Resources_Icons` | 34 |
| `tools` | `Tool_Icons` | 10 |
| `other` | `Other_Icons` | 11 |

Mỗi icon dùng vùng cắt 16 × 16, giữ PNG gốc làm external resource, bật `filter_clip`
để tránh lấy pixel từ icon kế bên. Không tạo resource cho ô trong suốt.
`Other_Icons_2_Outline.png` chứa 17 ô trùng pixel với các sheet Outline chính,
nên không tạo thêm resource từ sheet này.

## Tên và cách dùng

Tên theo mẫu `<nhóm>_r<hàng>_c<cột>.tres`, hàng/cột bắt đầu từ 1 và tính cả ô trống
trong sheet. Hai bản outline/no_outline dùng cùng tên và tọa độ.
Ví dụ `res://icons/outline/tools/tools_r01_c01.tres` là ô hàng 1, cột 1 của sheet
`Tool_Icons_Outline.png`. Tên theo tọa độ giữ mapping chính xác mà không tự gán tên
item hoặc loại khoáng sản từ màu ảnh.

Kéo `.tres` vào thuộc tính texture của `TextureRect`, `TextureButton`, `Sprite2D`
hoặc trường `@export var icon: Texture2D` trong resource dữ liệu item.

## Tạo lại

Chạy từ thư mục dự án bằng Godot 4:

```sh
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- generate --group=icons
```

Generator là script `SceneTree` chạy qua CLI. Script kiểm tra kích thước sheet và
số ô có hình trước khi ghi. Nếu thay đổi bố cục PNG, cập nhật cấu hình `SHEETS`
trong generator và kiểm tra lại mapping của các item đang dùng icon.

Các lệnh dùng biến `FARM_GODOT` trỏ đến Godot .NET. Output mặc định nằm trong `.godot/generator-check`; xem README để áp dụng có chủ đích vào dự án.
