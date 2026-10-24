# Gói mở đầu: 4 cột và 24 hạt cà rốt — 24/10/2026

Hồ sơ mới có 4 cột đất mở sẵn, mỗi cột 34 ô: tổng 136 ô trồng. Túi có 24 hạt cà rốt; vốn ban đầu giữ 10.000 xu. Ao vẫn trống và vườn hoa vẫn khóa.

## Mở rộng đất

Giá tính theo lượt mua kể từ phần đất ban đầu, không lấy số cột mở sẵn làm số lượt đã mua:

| Lượt mua | Tổng cột sau khi mua | Giá |
| --- | ---: | ---: |
| 1 | 5 | 60.000 xu |
| 2 | 6 | 150.000 xu |
| 3 | 7 | 350.000 xu |

Có sẵn 4 cột không tự hoàn thành mục tiêu mở đất hoặc phát quà hoa. Lần mua đầu mở vườn và quà 60 hạt hoa. Mô tả mục tiêu EN/VI được đổi để nói về mở thêm đất ngoài phần ban đầu, không còn yêu cầu chỉ sở hữu hai cột.

## Vòng kinh tế đầu

24 hạt × 100 cà rốt × 35 xu = 84.000 xu bán sản phẩm. Cộng 10.000 vốn và 35.000 thưởng năm mục tiêu đầu = 129.000 xu; mua đất 60.000 còn 69.000 xu. Đây là kết quả sau khi trồng, thu, bán đủ vụ và nhận đủ năm thưởng, không phải số dư ngay khi tạo hồ sơ.

## Save v20

Snapshot lưu thêm `land_starting_columns`. Hồ sơ mới ghi 4; save v19 trở về trước migrate giá trị 1, giữ số đất, hạt, tiền và tiến trình đã có. Nhờ đó các save cũ tiếp tục giá mua/mốc mở hoa theo số lần mua cũ. Không cấp thêm hạt hoặc thu hồi đất cho save đã chơi. Giá trị phần đất ban đầu phải nằm từ 1 đến số cột sở hữu, nếu sai sẽ bị từ chối trước restore.

Riêng hồ sơ vừa reset của người dùng đã được xác nhận chưa trồng cây, chưa có vật nuôi và chưa nhận mục tiêu. Đã áp dụng trực tiếp 4 cột/24 hạt cho hồ sơ này sau khi tạo candidate, kiểm tra checksum và tải thử vào thế giới thật bằng engine. Chỉ thay cấu hình đất, số hạt cà rốt và revision/version; giữ nguyên các tài sản khác. Save chính và backup cũ được sao lưu trong `.godot/save-backups/starter-four-20261024-085158Z/`; hai file đang dùng đều có cấu hình mới.

## Kiểm thử

Bằng chứng nằm trong [starter_four_columns_2026-10-24](starter_four_columns_2026-10-24/).

- **110/110 test, 4.910 assertions, 12 suite** đều đạt.
- Đếm đúng 136 ô; thử xới đất thực ở cả bốn cột; cột thứ năm còn khóa.
- Mua đất theo các giá 60.000/150.000/350.000, không mở hoa trước lần mua đầu.
- Trồng/tưới/thu/bán thật 24 hạt với đồng hồ fixture: 2.400 cà rốt, 129.000 → 69.000 xu.
- Save/load cấu hình mới, migration giữ số hạt và đất cũ, từ chối baseline không hợp lệ; hồi quy onboarding, mục tiêu, đơn hàng, mật ong và offline chuồng.
- Native: 12/12 kiểm tra candidate của hồ sơ thực, 4 cột, 24 hạt, 10.000 xu, vườn còn khóa và menu mở đất đầu 60.000 xu. Đã xem ảnh khu đất và hotbar 24 hạt.
- Lint toàn dự án 0 lỗi/0 cảnh báo.
- Web Compatibility xuất thành công. Chưa xác nhận điện thoại thật trong lượt này.
