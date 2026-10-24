# Phần 4A — Thông số kinh tế thử nghiệm

Triển khai ngày 24/10/2026 theo `thong_so/farm_economy_master_specs.md`. Đây là lượt đầu của Step 4: áp dụng dữ liệu và bảo đảm tải được save cũ. Chưa nghiệm thu cân bằng qua phiên chơi dài.

## Thông số đã áp dụng

- 22 cây ruộng: giá hạt, thời gian 60–86.400 giây, sản lượng và giá bán theo bảng.
- 10 loại hoa: giá hạt, thời gian, sản lượng 100 và giá bán theo bảng; giữ nguyên ID/hình ảnh hiện tại.
- 7 loài vật nuôi: giá mua, thời gian trưởng thành, chu kỳ sản xuất và 100 sản phẩm/lứa. No/nước đều tiêu hao từ 100 về 0 trong 3.600 giây cơ sở, tuổi thọ vẫn 14 ngày.
- Cám: 2.000 xu/gói, 200 đơn vị/gói. Nông sản, phụ phẩm, hoa, gỗ, mật có stack 32.000; hạt/cây giống/cám/booster stack 999; công cụ giữ 1.
- Cây ăn quả: thời gian lớn, chu kỳ, 300 quả/lứa, giá giống/bán theo bảng. Cây gỗ lớn ban đầu 24 giờ, 400 gỗ/lần, giữ cơ chế trả cây giống và tái sinh sau 12 giờ 2 phút.
- Giá tổ ong 150.000; giá bán mật rừng/hướng dương/hoa quý là 150/250/400. Sản lượng 100 hũ và tốc độ theo từng nguồn phấn cần logic riêng ở phần tiếp theo, chưa áp dụng trong lượt Resource này.
- Ví hồ sơ mới 10.000 xu. Thưởng năm mục tiêu đầu 5.000/5.000/5.000/10.000/10.000; mục tiêu sở hữu con vật 10.000, đổ thức ăn 5.000, đổ nước 5.000 và mở đất 25.000. Tiến trình và trạng thái đã nhận thưởng không được đặt lại.
- Mỗi chuồng có hai máng ăn và hai máng nước, mỗi máng capacity 1.200. Giữ lượng stock authored hiện có; sức chứa đủ 24 giờ chỉ có ý nghĩa sau khi đổ đầy và khi đã có mô phỏng offline cấp chuồng.
- Sáu mẫu đơn mới đúng công thức 1,25×/1,40×, tối đa hai loại hàng. Mẫu sữa/trứng xét nguồn giống và chuồng phù hợp để không bị bộ lọc cây trồng loại bỏ.

Các giá chưa được chốt trong bảng hiện tại như rìu, booster và rễ gỗ giữ nguyên. Luật tưới cây ruộng và tác dụng booster giữ nguyên; không tự đổi thành cơ chế khác trong lượt dữ liệu.

## Giá mở đất

Phân biệt một cột mở sẵn với lượt mua đầu tiên. Giá ba lượt mua đầu là 60.000 / 150.000 / 350.000 xu. Từ lượt mua thứ k>3 dùng `round(350000 × (k/3)^1.8)`, tiếp tục độ tăng 1,8 của hệ thống cũ và liên tục qua mốc 350.000. Tổng vẫn có 47 lượt mua thêm; không thu hồi cột đã sở hữu.

## Tương thích save v16

- Save v15 được chuyển tiếp bằng bản sao, không sửa DTO đầu vào/backup. Coins, inventory, đàn và các ID hiện có giữ nguyên; không cấp lại 10.000 xu cho hồ sơ cũ. Migration lịch sử v3 vẫn dùng gói xu 1.000 của phiên bản đó.
- Các đơn đã phát hành trước bản kinh tế giữ ID, lượng hàng và tiền thưởng trong catalog `legacy_orders_v15.tres`. Catalog luân phiên mới chỉ chọn sáu mẫu mới; đơn cũ không tiếp tục sinh mới. Cursor cũ được đưa về miền hợp lệ của danh sách mới.
- Bốn máng thêm gần đây được bổ sung vào snapshot v15 nếu snapshot chỉ có các máng cũ tương ứng. Máng bổ sung có stock 0, không tặng thêm thức ăn/nước. Tham chiếu/ID trùng hoặc đơn legacy không hợp lệ vẫn bị từ chối.
- Cám giữ dư theo đơn vị máng. Phần dư gói cũ 300 đơn vị được chuyển vào stock khi migrate các máng thức ăn đã biết (stock cũ tối đa 600 + dư tối đa 299 nằm trong capacity mới 1.200). Tổng đơn vị không tăng/giảm.
- Cây đang lớn giữ thời hạn đã lưu; validator chấp nhận các thời lượng lịch sử 180 giây của cây quả và 240/120 giây của cây gỗ để save tiếp tục tải lại được. Chu kỳ/yield Resource mới áp dụng theo bộ luật kinh tế mới; số sản phẩm đã nằm trong túi, kho hoặc trên đất không bị sửa.

## Phần tiếp theo

- Gói hồ sơ mới đã triển khai ở lượt tiếp theo: ao trống, khu hoa khóa đến lần mua đất đầu; xem [starter_content.md](starter_content.md). Vòng nhập môn 87.000 → 27.000 xu đã được kiểm tra bằng hành động thật và đồng hồ thử nghiệm.
- Offline cấp chuồng đã triển khai ở lượt tiếp theo: kho chung, cơ thể dự trữ, tuổi thọ, thời tiết, phần lẻ và checkpoint chống tính lặp; xem [pen_offline.md](pen_offline.md). AI tìm máng vẫn được giữ cho các tick online thông thường.
- Mẻ mật 100 hũ, nguồn hoa quý, chu kỳ 24/18/12 giờ và migration mẻ cũ đã triển khai; xem [honey_batches.md](honey_batches.md).
- Đo các lịch đăng nhập, hiệu suất thao tác và tổng thu nhập khi phối hợp các hệ. Hệ số thao tác 75% là giả thuyết.

## Kiểm tra

Bằng chứng được lưu trong [thư mục QA](economy_4a_2026-10-24/). Có kiểm tra mua–thu hoạch–bán theo giá mới, giao đơn lớn một lần, mốc mua đất, dự trữ máng, sản lượng quả/gỗ và giới hạn một lứa; migration giữ đồ 32.000, xu, đàn, timer cây, lượng cám dư, đơn đã phát hành và vòng lưu/tải tiếp theo.

Kết quả kiểm tra:

- **109/109 test, 3.639 assertions trong 13 suite**: giao dịch, các mốc đất, Resource hợp lệ, đơn hàng mới/legacy, save repository, mục tiêu, hướng dẫn, khởi tạo persistence và vòng đời vật nuôi.
- **48/48 kiểm tra native**: mua bằng nút thật, xác nhận/giao đơn với số tiền lớn, EN/VI ở 667×375 và 844×390 có safe area, cùng desktop 500×400. Đã xem ảnh xác nhận bí ngô thưởng 3.625.000 xu.
- Đọc lại bằng engine: **144 Resource, 49 giá mua và 47 giá bán** được áp dụng trong manifest đều khớp. Giá bán rễ gỗ không có giá mới được chốt nên giữ nguyên, không nằm trong 47 giá thay đổi/đối chiếu này.
- Lint toàn dự án 0 lỗi/0 cảnh báo. Engine validation persistence không có lỗi/cảnh báo thuộc phần mới; còn 22 cảnh báo dependency đã có. Không có lỗi runtime trong log hồi quy cuối.
- Web Compatibility xuất thành công sau bản sửa UI cuối. Lượt này không xác nhận trình duyệt hoặc điện thoại thật.

Bảng xác nhận đơn hàng được tính lại sau khi minimum size thay đổi, tránh giãn quá màn hình ở lần mở đầu hoặc lúc đổi giữa danh sách và xác nhận. Các test hành vi dùng fixture có giá/chu kỳ xác định; các test kinh tế mới dùng Resource thật. Các suite ngoài 13 suite này không được coi là đã xanh toàn dự án.

Sau sửa bố cục cuối, chạy lại riêng 7/7 test tích hợp đơn hàng (258 assertions) đều đạt.
