# Tài liệu GDScript

Các tệp XML trong thư mục này được Godot tạo từ comment `##` trong mã nguồn.
Mỗi tệp mô tả một script gameplay, gồm lớp, phương thức, tham số, tín hiệu và
thuộc tính mà Godot xuất được. Script không có `class_name` được đặt tên theo
đường dẫn, với `--` thay dấu phân cách thư mục. Phần mô tả có thể chứa cú pháp
tham chiếu của Godot như `[param name]` và `[code]...[/code]`; trang HTML cần
xử lý cú pháp này khi hiển thị.

Để cập nhật tài liệu trên Windows, chạy từ thư mục dự án, thay đường dẫn Godot
cho phù hợp với máy đang sử dụng:

```powershell
$godot = 'C:\duong-dan\Godot_console.exe'
foreach ($dir in @('components', 'scripts', 'persistence', 'world', 'scenes', 'resources')) {
    & $godot --headless --path . --doctool xml_documents --gdscript-docs "res://$dir"
    if ($LASTEXITCODE -ne 0) { throw "Không thể xuất tài liệu cho $dir" }
}
Remove-Item -LiteralPath 'xml_documents/scripts--grass--audit_farm_grass.gd.xml' -ErrorAction SilentlyContinue
```

Lệnh chạy lần lượt để mỗi lần xuất bổ sung vào cùng thư mục. Script kiểm tra
cỏ được loại khỏi kết quả vì là công cụ kiểm tra, không phải mã chạy gameplay.
Nếu xóa hoặc đổi tên script, cần xóa XML tương ứng đã cũ sau khi xuất lại;
Godot có thể giữ tệp của tên cũ. Thư mục `tests` và `addons` không nằm trong
phạm vi xuất.
