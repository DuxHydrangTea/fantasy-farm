# Sâu, cỏ dại và bệnh vật nuôi

## Cách chơi

- Cây trên ruộng có thể bị sâu, cỏ dại hoặc cả hai. Một bubble nền kem, viền nâu hiển thị sprite cỏ và con sâu 16×16 đã duyệt; hai biểu tượng có thể hiện cùng lúc.
- Đứng trước cây rồi nhấn E hoặc nhấp cây để dọn cỏ. Hiệu lực đến ở frame tác động của animation, không phải lúc nhấn phím.
- Mua **Thuốc trừ sâu** (120 xu) ở nhóm vật tư của cửa hàng hạt giống. Chọn vật phẩm, hướng về cây và nhấn chuột phải/Space để trị sâu.
- Vật nuôi có một bubble gộp mặt bệnh, đói và khát 16×16 tương ứng; bảng thông tin vẫn hiện đủ các trạng thái. **Thuốc thú y** (180 xu) mua tại cửa hàng vật nuôi, dùng khi đứng gần, hướng về vật nuôi và nhấn chuột phải/Space.
- Thuốc chữa bệnh không hồi no/nước. Cho ăn/uống không chữa bệnh. Hai thuốc mới có thể cất trong Kho hạt giống/vật tư.
- Worker ruộng mặc định chờ xử lý sâu/cỏ trước khi thu hoạch. Trong bảng worker, nút **Chờ chăm sóc** cho phép bật/tắt chính sách này. Worker chưa tự dọn cỏ, phun thuốc hoặc chữa bệnh.

Bubble chỉ xuất hiện khi có tình trạng và ẩn khi đã xử lý hết. Đói/khát dùng ngưỡng tìm thức ăn/nước hiện có của từng loài; không thay đổi điều kiện dừng sản xuất. Khi chăm sóc, icon tương ứng biến mất ngay và bubble co lại theo số icon còn lại. Animation chỉ bật khi bubble xuất hiện; bảng tương tác được đặt tránh bubble của mục tiêu. Asset nằm trong `assets/Ui/status_bubbles/`, giữ nguyên pixel của concept đã duyệt.

## Cân bằng hiện tại

- Cây kiểm tra sâu ở tiến độ 1/3, cỏ ở 2/3; mỗi loại có xác suất 15% độc lập mỗi vụ. Không tái nhiễm sau khi đã xử lý trong cùng vụ.
- Sâu giữ 80% sản lượng kỳ vọng, cỏ giữ 85%, cả hai giữ 68%. Áp dụng sau bonus đất màu mỡ; phẩm chất không thay đổi.
- Chữa trước thu hoạch phục hồi hệ số tương ứng. Kết quả làm tròn phần lẻ được cố định từ lúc trồng, dùng chung cho preview/người chơi/worker và lưu qua reload. Một cây có thể thu hoạch 0 sản phẩm; vụ vẫn kết thúc, không tạo phần thưởng giả hoặc nhân đôi.
- Bệnh giảm tốc độ sản xuất còn 50%, không trừ sản phẩm đã hoàn thành. Hết no hoặc nước vẫn dừng sản xuất như trước.
- Chỉ bắt đầu nguy cơ bệnh sau trưởng thành và thời gian bảo vệ 300 giây. Sau đó tương đương xác suất 5% ở mỗi lần kiểm tra cách nhau 600 giây. Chữa bệnh có lại thời gian bảo vệ. Không lây lan hoặc gây chết thêm.
- Dữ liệu cân bằng nằm trong `resources/farm_health_rules.tres`, các giá trị mặc định trong `scripts/farm_health_rules.gd`.

## Thời gian và save

Schema v37 lưu từng tình trạng, mốc đã kiểm tra, kết quả ngẫu nhiên của vụ và lịch bệnh/RNG của từng con. Save v36 được nâng cấp qua bản sao; cây cũ được bảo vệ hết vụ đầu và vật nuôi có thời gian bảo vệ trước khi phát bệnh.

Không bật offline progress khi thêm tính năng này. Với cấu hình mặc định hiện tại, restore tiếp tục từ checkpoint. Khi cho phép offline progress, sản xuất bị bệnh được tính bằng giao của khoảng đủ ăn/uống, trưởng thành, còn sống và thời gian thực sự mắc bệnh. Một bước lớn và nhiều bước nhỏ cho cùng kết quả; không chạy lại từng frame hoặc từng lần kiểm tra bệnh đã bỏ lỡ.

## Kiểm thử

- `tests/unit/test_farm_health.gd`: tổ hợp trạng thái, hệ số, làm tròn, RNG, dữ liệu không hợp lệ và tính nhất quán theo bước thời gian.
- `tests/integration/test_farm_health_world.gd`: thao tác chăm sóc ở frame tác động, hủy/thay mục tiêu/ngoài tầm không mất thuốc, sản lượng 0, worker, bệnh + đói + khát, migration và restore, pen offline so với online, cửa hàng/kho.
- `tests/unit/test_status_bubbles.gd`: thứ tự icon, kích thước bubble, nền trong suốt và animation không lặp.
- `tests/support/farm_health_test_runner.tscn`: chạy các bộ tính năng cùng unit crop growth và animal production bằng Godot/GUT.
- `tests/support/farm_health_regression_runner.tscn`: chạy các bộ hồi quy boosters, pen offline model, worker roles, kho, chính sách offline và phẩm chất cây.

Kết quả kiểm chứng ngày 30/10/2026: bộ tính năng + crop growth/animal production đạt 45 test, 336 assertion; bộ hồi quy đạt 36 test, 346 assertion. Tổng cộng 81 test / 682 assertion, không thất bại. Kiểm tra tĩnh thư mục components: không error/warning. Đã kiểm tra game thật, biểu tượng trạng thái, bảng worker ở cửa sổ 960×540 và cửa sổ thu nhỏ, cùng nút bật/tắt chờ chăm sóc. Các kiểm thử dùng world riêng, không ghi vào hồ sơ chơi cá nhân.

Hoa, cây ăn quả, cây lấy gỗ, lây lan và tự động chăm sóc của worker chưa thuộc phiên bản này.
