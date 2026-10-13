# Trồng trọt bằng C#

Code hiện tại nằm trong `src/Farming`, `src/Core/CropProgress.cs`, `src/Data/CropDefinition.cs` và `src/Interactions`.

## Luồng tương tác

Input → Player → InteractionFocusComponent → IInteractable.PrepareAction → ActionContext → ToolState → frame hiệu lực → ExecuteOnce → FarmPlotInteractable.
Thu hoạch không cần animation. ActionContext giữ item đã chọn lúc chuẩn bị; nếu slot đổi item hoặc target đã bị giải phóng thì không áp dụng hiệu lực.

## Quy tắc giữ từ bản GDScript

- FarmLand tạo plot có ID `plot_<col>_<row>` từ Rows/Cols/Gap; chỉ xóa plot do nó tạo khi rebuild, giữ các node khác như TileMapLayer.
- CropDefinition có 4 texture tăng trưởng, thời gian, item và số lượng thu hoạch.
- Cây tăng trưởng theo thời gian kể cả khi đất khô; tưới cộng 5% tổng thời gian, đất ướt 5 giây. Không thể tưới lại trong thời gian còn ướt.
- Plot đã có cây không nhận hạt khác; gieo thành công tiêu thụ một hạt.
- Thu hoạch yêu cầu kho nhận đủ toàn bộ sản lượng. Kho đầy giữ nguyên cây chín.
- FarmPlot hiển thị thanh tăng trưởng khi được focus, đổi màu khi chín.
- Mở inventory khóa việc di chuyển/tương tác; focus được khóa trong animation dùng công cụ.

## Dữ liệu và scene

Resource `.tres` tiếp tục tham chiếu PNG/atlas cũ và dùng thuộc tính C# PascalCase. CropDefinition, ItemDefinition và ItemSlot là Resource C# có `[GlobalClass]`/`[Tool]` để dùng trong Inspector.
Scene chính: `scenes/farm_plot.tscn`, `scenes/farm_land.tscn`, `scenes/player.tscn`, `scenes/world.tscn`.
Logic tiến độ nằm trong model CropProgress; physics/hiển thị/vòng đời Node nằm ở lớp Godot. Kho nhận sản phẩm qua IInventoryStore để tránh phụ thuộc giao diện.

## Kiểm tra

Chạy hướng dẫn build/test trong README. Unit checks kiểm tra thời gian, stage, tưới và thu hoạch; runner Godot kiểm tra trực tiếp các scene và trường hợp kho đầy/đổi item/target bị xóa.
