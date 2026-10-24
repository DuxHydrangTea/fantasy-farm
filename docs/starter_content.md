# Gói hồ sơ mới và mở khóa vườn hoa — 24/10/2026

> Cấu hình mới đã đổi sang 4 cột mở sẵn và 24 hạt cà rốt; xem [starter_four_columns.md](starter_four_columns.md). Các con số 12 hạt và 87.000 → 27.000 bên dưới là bằng chứng của cấu hình trước.

## Hành vi

- Hồ sơ mới bắt đầu với ao trống, 10.000 xu và 12 hạt cà rốt như gói nhập môn. Không tự nhận thưởng mục tiêu sở hữu vật nuôi.
- Vườn hoa vẫn có chậu trống và thông báo EN/VI tại lối đi giữa vườn. Trước lần mua đất đầu tiên, không gieo/tưới/thu hoạch hoa; hạt mua được không bị trừ khi thử gieo. Nguồn hoa bị khóa không được tính là nguồn hoàn thành đơn hàng.
- Mua phần đất mở rộng đầu tiên (60.000 xu, nâng tổng cột sở hữu từ 1 lên 2) mở vườn và phát 10 đống hạt, mỗi loại 6 hạt, tổng 60. Không phát thêm 8 chậu hoa trồng sẵn cho hồ sơ mới.
- Quà chỉ phát một lần. Nhặt quà, lưu và tải lại không tạo lại các đống đã nhặt. Capture trong signal thay đổi ví khi mua đất cũng thấy trạng thái mở khóa và đủ quà.
- Các đối tượng authored trong scene giữ nguyên cho editor/preview. `StarterContent` áp dụng mặc định mới trước khi các node con chạy `_ready`; vật nuôi trong save được phục hồi bởi adapter.

## Lưu và tương thích

Save v17 lưu boolean `flower_garden_unlocked`. Save v16 trở về trước được chuyển tiếp với vườn đã mở, bất kể số cột đất đã mua. Giữ xu, túi, vật nuôi và ID, hoa cùng hạt đã lưu. Không cộng lại vốn nhập môn hay đặt lại mục tiêu. Save sai kiểu flag bị từ chối trước khi thay đổi thế giới.

Trong restore, việc phát quà tạm dừng trong lúc thay đất/túi/entity. Sau khi phục hồi hoàn chỉnh mới xét mở khóa còn thiếu. Migration v15 kinh tế vẫn chạy trước migration v16 → v17, không bỏ qua bước.

## Kiểm thử

Bằng chứng nằm trong [starter_content_2026-10-24](starter_content_2026-10-24/).

- 57/57 test, 1.190 assertions trong 7 suite: gói mới, mục tiêu, kinh tế, save repository, onboarding, đơn hàng và persistence bootstrap. Có kiểm tra save v16 giữ vật nuôi, 8 hoa đã trồng, hạt, xu và túi; reload hồ sơ khóa/mở và chống phát quà lặp.
- Vòng nhập môn dùng đúng 12 hạt, trồng/tưới/thu hoạch/bán qua các service hiện có, nhận 5 thưởng đầu; đồng hồ fixture tiến 61 giây để cây chín. Thu 1.200 cà rốt, đạt 87.000 xu, mua đất còn 27.000 xu. Đây là kiểm tra logic, chưa đo tốc độ thao tác của người chơi.
- Native Compatibility: 9/9 kiểm tra thông báo EN/VI, kích thước và ẩn thông báo sau khi mua đất; đã xem ảnh trước/sau mở khóa.
- Lint toàn dự án không có lỗi/cảnh báo. Engine kiểm tra nhóm flower không có lỗi; còn cảnh báo dependency đã có, gồm UID dự phòng và tên biến cũ.
- Web Compatibility export thành công; chưa kiểm thử trên điện thoại thật trong lượt này.

## Tiếp theo

Offline cấp chuồng đã triển khai ở lượt sau, xem [pen_offline.md](pen_offline.md). Tiếp theo hoàn thiện mẻ mật và đo các lịch đăng nhập theo bảng kinh tế.
