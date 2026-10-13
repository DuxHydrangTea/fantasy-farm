# Fantasy Farm — Godot C#

Dự án dùng **Godot .NET 4.7.2** và target .NET 8. Mở bằng bản .NET; bản Godot standard không chạy gameplay C#.
Cần .NET SDK 8 trở lên và runtime .NET tương thích. Đã kiểm tra với SDK 10.0.112 và cả runtime 8.0.31 / 10.0.12. Addon `godot_mcp_toolkit` và `scatter2d` giữ nguyên mã bên thứ ba.

## Build và chạy

```sh
dotnet restore fantasy-farm.sln
dotnet build fantasy-farm.sln -m:1
# Đặt đường dẫn đến executable Godot .NET trên máy.
FARM_GODOT="/path/to/Godot_v4.7.2-stable_mono_linux.x86_64"
"$FARM_GODOT" --headless --editor --path . --import
"$FARM_GODOT" --path .
```

Scene chính: `scenes/world.tscn`. Giữ cách chơi hiện tại: phím mũi tên di chuyển, Space dùng vật phẩm/thu hoạch, Tab mở kho, phím số đổi slot hotbar.

## Cấu trúc

- `src/Core`: model và quy tắc thuần C#, kiểm tra được ngoài Godot.
- `src/Data`: Resource cấu hình item, crop, animal và production.
- `src/Characters`: actor, controller, movement, animation, state machine và `IState`.
- `src/Interactions`: `IInteractable`, chọn mục tiêu, action context và thực thi một lần.
- `src/Inventory`, `src/UI`: kết nối model kho/hotbar với scene và giao diện.
- `src/Farming`, `src/Animals`: hành vi trồng trọt và phần chăn nuôi hiện có.
- `src/World`: cursor và preview biến thể công trình trong editor.
- `tools`: runner C#, generator, catalog và validator.
- `tests/Core`: executable kiểm tra hành vi thuần C#, không dùng package test bên ngoài.

Dependency trong logic dùng interface/constructor; dependency của Node dùng export có kiểu. State có ID enum; các chuỗi tên animation được giới hạn ở phần tích hợp hình ảnh. Slot trong scene là cấu hình; mỗi instance hotbar tạo slot runtime riêng.

## Kiểm tra tự động

```sh
dotnet run --project tests/Core/CoreTests.csproj
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- validate
```

Validator kiểm tra dữ liệu cấu hình, nạp/instantiate thư viện scene, thực hiện chu trình gieo–tưới–thu hoạch, kho đầy, UI, item đổi trong animation, target bị xóa và instance độc lập. Cần build trước khi chạy runner.
Build release code dùng `dotnet build fantasy-farm.csproj -c ExportRelease`. Đây là cấu hình Godot; `Release` của solution đã map game sang `ExportRelease`.
Build và kiểm tra headless không thay thế kiểm tra trực tiếp hình ảnh, cảm giác di chuyển hoặc bản export.

## Generator C#

```sh
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- generate --group=all
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- objects
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- house-decor
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- animate --kind=grass
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- buildings
"$FARM_GODOT" --headless --path . res://tools/runner.tscn -- merge
```

Mặc định ghi vào `.godot/generator-check`, giữ resource/scene của game. Thêm `--output-root=res:// --overwrite` khi muốn áp dụng vào dự án. Không ghi đè file đã tồn tại nếu thiếu `--overwrite`.
`generate` hỗ trợ prefix nhóm: `crops`, `icons`, `sprite_frames/character`, `sprite_frames/animals`, `sprite_frames/house_decor`, `sprite_frames/outdoor_decor`, `tilesets`, `weather`, `items`, `animals`.
`animate` hỗ trợ `grass`, `rock`, `water`, `mushroom`, `potted`, `flowers`.
Lệnh `collisions` bảo trì scene thuần hình ảnh theo danh mục hiện tại và ghi trực tiếp vào scene của dự án; review danh mục trước khi chạy.

`tools/data/resource_recipes.json` là cấu hình tạo resource: class, thuộc tính lưu trữ, reference PNG, vùng atlas, frame và cấu hình TileSet. Hash/kích thước PNG được kiểm tra trước khi tạo; khi đổi sheet cần cập nhật mapping và hash sau khi review ảnh. Ma trận nội thất và tên object vẫn nằm trong `scripts/setup/data` để giữ tham chiếu dữ liệu ổn định.
`objects` dùng `docs/object_scenes_index.json` làm danh mục source, texture options, vùng atlas và collision; khi thêm object, cập nhật danh mục này. `house-decor` đọc ma trận hiện tại và tạo cả TileSet lẫn trang preview.

## Phạm vi chuyển đổi

Toàn bộ GDScript của game và editor tool do dự án sở hữu đã được chuyển hoặc hợp nhất vào C#. Mapping ở `tools/data/migration_map.json`.
Các helper đổi tên/split asset dùng một lần đã hoàn thành được gỡ khỏi mã hoạt động; lịch sử Git giữ bản cũ.
Chăn nuôi được giữ ở mốc hiện tại: AI gà, nhu cầu no/nước, tick chuồng và nạp máng. Việc tìm máng tự động, trưởng thành, sinh sản hoặc tạo sản phẩm là công việc tiếp theo nếu chưa có trong gameplay gốc.
Không thêm combat hoặc các chức năng mới trong đợt viết lại.
