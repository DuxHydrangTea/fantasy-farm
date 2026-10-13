# Kết quả chuyển sang C#

Ngày: 13/10/2026. Nhánh: `rebuild/c-sharp`.
Commit làm mốc: `2b07c38cb4592473ff5307034787ac0f37896e48`.
Các thay đổi hiện ở working tree để review, chưa commit.

## Phạm vi đã hoàn tất

- 77 script GDScript sở hữu đã chuyển, hợp nhất vào C# hoặc gỡ placeholder không có hành vi. Không còn `.gd` ngoài addon và thư mục build/cache.
- 68 file C# cho game/công cụ, cùng solution và project kiểm tra core.
- Chuyển 119 scene/resource có liên kết script hoặc dữ liệu export; giữ UID script đã có ở các đường dẫn C# tương ứng.
- Kiến trúc có `IInteractable`, `IInventoryStore<T>`, `ICharacterController`, `IState`; model inventory, tiến độ cây và needs kiểm tra được ngoài Godot.
- Generator dùng C# và recipe khai báo tường minh; helper biến thể công trình giữ preview trong editor.
- Addon `godot_mcp_toolkit` và `scatter2d` giữ nguyên. Không có thay đổi source addon.
- Giữ mốc chức năng chăn nuôi hiện tại; không bổ sung combat hoặc chức năng mới.

Chi tiết nguồn → đích nằm trong `tools/data/migration_map.json`; các bước đổi tên/split asset dùng một lần được ghi là đã nghỉ dùng.

## Dọn file sau chuyển đổi

- Gỡ `scripts/CharacterBase.tscn` và `scripts/setup/setup_not_potted_flower_tiles.tscn`: cả hai chỉ chứa một Node2D rỗng, không gắn script và không có tham chiếu đường dẫn hoặc UID từ file dự án còn lại.
- 77 script GDScript cũ và các sidecar UID đã được gỡ trong bước chuyển đổi; không còn sidecar `.uid`/`.import` mồ côi ngoài addon và thư mục build/cache.
- Giữ dữ liệu ở `scripts/setup/data`: ma trận và template preview đang được generator sử dụng; catalog tên và quy tắc collision còn là tài liệu nguồn cho thư viện object.
- Giữ thư viện scene/resource/asset để đặt map và phát triển tính năng; việc chưa có instance trong world hiện tại không đủ để kết luận là file thừa.
- Kiểm tra sau dọn: build solution đạt 0 warning/error; 30 kiểm tra core và 6.049 assertion Godot đạt, nạp 711 resource và 1.780 scene trong thư mục `scenes`. Hai scene rỗng đã gỡ nằm ngoài thư mục này.

## Kiểm tra thực tế

| Kiểm tra | Kết quả |
|---|---|
| Build Debug solution | Đạt, 0 warning / 0 error |
| Build game `ExportRelease` | Đạt, 0 warning / 0 error |
| Core executable | 30 kiểm tra hành vi đạt |
| Godot validator | 6.049 assertion dữ liệu/tích hợp đạt; 711 resource và 1.780 scene |
| Dùng công cụ qua Player/ToolState | Gieo tại frame hiệu lực, không tiêu thụ hạt lặp, khóa/mở focus đúng |
| Inventory/UI/trồng trọt | Kho đầy giữ cây, nhận đúng sản lượng, item đổi/target bị xóa hủy action, slot độc lập giữa world instances |
| Vật nuôi/máng | Needs khởi tạo, giới hạn sức chứa và tiêu thụ đạt |
| Resource generator | Tạo 711 resource vào output kiểm tra |
| Object generator | Tạo 1.737 scene vào output kiểm tra |
| Nội thất theo ma trận | Tạo TileSet và preview HTML |
| Công trình | Đồng bộ 150 atlas source |
| Decor animation | Grass 18, rock 18, water 45, mushroom 8, hoa chậu 5, hoa đất 5 sheet |
| Gộp TileSet | 218 source, bảo toàn terrain/physics; không còn lỗi terrain index |
| Editor import headless | Đạt, không có error/warning |
| Reference resource trong scene/dữ liệu | Không có đường dẫn tường minh bị thiếu |
| `git diff --check` | Đạt |

Các lần chạy cuối được kiểm tra cả exit code lẫn log Godot. Generator được chạy trong `.godot/generator-check`, không ghi đè resource hoặc scene đang dùng của game.

Môi trường: Godot .NET 4.7.2, SDK .NET 10.0.112; validator đạt trên runtime 8.0.31 và 10.0.12. Editor import được kiểm tra với runtime 10 để khớp MSBuild SDK 10. Game target .NET 8.

## Điểm thay đổi cần biết

- Thuộc tính export dùng PascalCase; script/signal và dữ liệu nhúng được cập nhật cùng nhau. Resource dùng trong editor có `[Tool]` để giữ loại C# khi Inspector nạp reference.
- `InventoryStore.Add` trả số lượng chưa nhận cho item bị từ chối, thay cho cách báo thành công bằng `0` của helper cũ.
- Node WaterState trước đây chưa gắn script đã được nối C# và ID state; luồng tưới chính vẫn dùng ToolState.
- Helper gộp TileSet cũ chỉ gộp atlas, bỏ cấu hình terrain gây lỗi index. Bản C# giữ cấu hình và remap ID.
- Validator giữ reference resource trong thời gian kiểm tra hàng loạt, tránh giải phóng managed wrapper khi scene đang dùng lại resource.

## Chưa xác minh

- Hình ảnh thực tế, cảm giác điều khiển, thao tác Inspector trực tiếp và preview bằng mắt.
- Bản export desktop đóng gói: chưa có preset/target cụ thể và export templates trong phạm vi hiện tại. Build `ExportRelease` chỉ xác nhận phần code.
- Các tính năng chăn nuôi chưa có ở bản gốc vẫn là công việc phát triển tiếp theo.

Xem README để build, chạy và dùng generator. Khi mở dự án, dùng bản **Godot .NET**, không dùng bản standard.
