# Bảng quản lý chuồng trại

Triển khai ngày 24/10/2026, bổ sung theo yêu cầu sau phần 2.

## Cách sử dụng

- Biển gỗ tại lối vào chuồng gà, chuồng gia súc và ao vịt. Đến gần, nhấn **E** hoặc click/chạm biển để mở bảng của đúng khu chuồng. Trên cảm ứng có nút tương tác dùng chung.
- Đầu bảng hiển thị số cá thể còn sống / sức chứa và phần trăm đầy của máng thức ăn, máng nước. Tỷ lệ = tổng lượng còn lại / tổng sức chứa các máng trong cùng chuồng; nếu chưa có máng thì báo rõ.
- Lưới thẻ có portrait `AnimatedSprite2D` phát idle độc lập, đúng bộ hình giai đoạn/ngoại hình của từng con; mã ngắn sáu chữ số, độ no/đủ nước, tiến độ sản phẩm và nguyên nhân tạm dừng. Sản phẩm thu trực tiếp còn tồn được ghi trên thẻ.
- Dùng con lăn hoặc vuốt để xem các hàng phía dưới. Đóng bằng nút Đóng, Esc hoặc E. Bảng cập nhật mỗi 0,25 giây, hỗ trợ EN/VI và vùng an toàn màn hình.
- Rê chuột/hướng nhân vật vào vật nuôi không mở popup và không dừng di chuyển, ngủ, tìm máng hay ăn uống. Đồng hồ và đàn tiếp tục chạy khi bảng mở. Tương tác thu sữa/lông trực tiếp vẫn được giữ khi có sản phẩm.

## Cấu trúc và dữ liệu

`PenBoard` là scene `scenes/animals/pen_board.tscn`, được đặt sẵn dưới ba khu chuồng trong `world/main_world.tscn`. Trong editor, mở `CoopPen/ManagementSign`, `BarnPen/ManagementSign` hoặc `PondPen/ManagementSign` để kéo chỉnh vị trí; hình và va chạm có sẵn trước khi Play. FarmWorld chỉ thu thập các biển đã đặt, không sinh biển mới. `PenDashboard` dùng TradeMenu cùng khóa modal với túi/shop/mục tiêu, tự đóng khi load. `PenStatus` chỉ đọc thành viên/máng; `AnimalCard` dùng sprite preview riêng, không gọi AI của con vật.

ID bền vững được cấp ngay khi cá thể khởi tạo, giữ nguyên khi lưu/đọc. Mã trên thẻ được dẫn xuất từ ID đó; tooltip chứa ID đầy đủ. Nếu mã ngắn trùng trong cùng chuồng thì hiển thị ID đầy đủ để phân biệt. Không thay cấu trúc save v15, không sinh thêm vật nuôi cho các chuồng đang trống.

Các hàm focus cũ còn được giữ tương thích nhưng không thay đổi hành vi vật nuôi. Resource inspector cũ không còn được gameplay tự tạo/sử dụng; cơ chế thanh trạng thái cây trồng/hoa giữ nguyên.

## Xác minh

Bằng chứng và kết quả cuối nằm trong [thư mục QA](pen_management_2026-10-24/). Kiểm tra tự động gồm tương tác ba biển, loại trừ modal, membership và ID sau load, tỷ lệ máng có sức chứa khác nhau, portrait idle riêng, AI không bị focus ngắt và bố cục EN/VI tại nhiều kích thước/mật độ. Native Compatibility kiểm tra nút tương tác/chạm, E/Esc, vuốt thẻ, đàn di chuyển trong khi menu mở và cửa sổ desktop nhỏ.

Chưa kiểm tra trực tiếp trên Android/iPhone thật. Kết quả native không được coi là xác nhận trình duyệt hoặc thiết bị thật.

Kết quả cuối:

- **244/244 test, 8.188 assertions trong 26 suite** (214 test hồi quy + 30 test tương tác/vòng đời). Không có lỗi runtime/GUT trong hai log cuối.
- **24/24 kiểm tra native**; ảnh EN/VI đã xem trực tiếp. Bố cục kiểm tra ở 667×375, 740×360, 844×390 với safe area và mật độ 1×/3×, cùng desktop 500×400. Bản Web Compatibility xuất thành công.
- Lint toàn dự án: 0 lỗi, 0 cảnh báo. Engine validation bốn lớp quản lý: không có lỗi/cảnh báo thuộc tính năng mới; còn 22 cảnh báo dependency đã có.
- Kiểm tra thêm lần mở đầu tiên với chuồng trống và chữ Việt dài; lỗi đo chiều cao trước khi khung có chiều rộng đã được sửa. Callback hướng dẫn cũng bỏ qua lúc rời SceneTree để đóng menu an toàn khi giải phóng world.

Các suite ngoài 26 suite trên không được coi là đã kiểm thử toàn bộ dự án.

Sửa bổ sung: biển hiển thị ngay trong Scene editor; scene riêng chứa sprite và collision, chỉ tạo menu khi chạy. Có kiểm tra instantiate world trước khi vào SceneTree để bảo đảm đủ ba biển có texture và chưa tạo menu.

Kiểm tra bổ sung sau sửa biển editor: 9/9 test (139 assertions), 24/24 kiểm tra native, lint 0 lỗi/cảnh báo.
