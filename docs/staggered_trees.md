# Cây theo hàng so le

Cập nhật ngày 24/10/2026. Hai khu cây ăn quả và cây lấy gỗ dùng hàng so le: hàng kế tiếp lệch nửa khoảng cách giữa hai gốc. Giữ khoảng cách dọc 48 pixel; bước ngang 46 pixel, hàng lẻ lệch 23 pixel. Bước ngang được tính từ chiều rộng vùng và làm tròn về pixel nguyên để giữ đủ 17 cột mà không đẩy tán cây mép ra ngoài giới hạn cũ.

Giữ 153 vị trí mỗi khu, tổng 306. Không đổi mã ô logic hoặc schema save; `TreePlantation.point_for()` đổi mã ô thành vị trí mới khi tạo/tải cây. Cả node cây và collider đi theo vị trí đó; Y-sort, hit-test và điều hướng tiếp tục dùng vị trí node thực tế. `planting_cell()` tính ngược vị trí so le để marker và trồng cây khớp hình. Cây đã có trong save giữ loài, thời hạn lớn và tiến trình; tải lại thế giới sẽ áp dụng vị trí mới, không cần xóa đàn cây hoặc trồng lại.

Kiểm tra: 30/30 test, 2.879 assertions trong ba suite (bố trí cây, kinh tế/save migration và save repository). Kiểm tra cả 306 mã ô, nửa bước giữa hàng, mép vùng, vòng save/load toàn bộ cây, collider, marker và thao tác trồng/thu hoạch hàng lẻ. Engine validation không có lỗi/cảnh báo thuộc script cây vừa sửa; còn cảnh báo dependency có sẵn. Native render khu cây trưởng thành đầy đủ đã xem trực tiếp.

[Ảnh và log QA](staggered_trees_2026-10-24/). Ảnh dùng hồ sơ preview riêng, trồng đủ bốn loại cây quả và ba loại cây gỗ để kiểm tra bố cục; không thay loài hoặc số cây trong save cá nhân. Khởi động lại hoặc tải lại world để cây đang có trong phiên chạy cũ được dựng theo vị trí mới.

Web Compatibility export thành công với bố cục mới.
