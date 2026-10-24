# Mẻ mật tổ ong — 24/10/2026

## Luật mẻ mới

Mỗi mẻ cho 100 hũ. Tổ chỉ trữ một mẻ đầy, chờ người chơi thu mới làm mẻ tiếp theo. Offline nhiều ngày không cộng dồn nhiều mẻ. Giá tổ ong 150.000 xu và giá bán mật rừng/hướng dương/hoa quý 150/250/400 xu mỗi hũ giữ theo dữ liệu kinh tế đã áp dụng trước đó.

| Nguồn được duy trì liên tục | Hệ số công sản xuất | Thời gian đủ mẻ | Sản lượng |
| --- | ---: | ---: | ---: |
| Không có nguồn chuyên biệt, hoặc chỉ hoa thường 01–05 | ×1 | 24 giờ | 100 hũ mật rừng |
| Hướng dương đã nở trong phạm vi | ×4/3 | 18 giờ | 100 hũ mật hướng dương |
| Hoa chậu 06–10 đã nở trong phạm vi | ×2 | 12 giờ | 100 hũ mật hoa quý |

Tốc độ ×4/3 nghĩa là thời gian giảm 25% so với 24 giờ, không phải cộng 25% tốc độ. Master specs đã được sửa cách diễn đạt này. Mốc 80.000 xu/ngày của mật hoa quý yêu cầu thực sự thu đủ hai mẻ; offline chỉ giữ một mẻ 40.000 xu.

## Nguồn phấn, thời tiết và thụ phấn

- Mỗi nguồn hoa vẫn được phân cho một tổ gần nhất; hòa khoảng cách dùng ID ổn định. Không nhân cùng một nguồn cho nhiều tổ.
- Trong các nguồn của tổ, ưu tiên tốc độ cao hơn: hoa quý → hướng dương → hoa thường. Cùng tốc độ chọn loài nhiều hoa hơn, rồi khoảng cách gần hơn và ID.
- Hoa 01–05 vẫn hỗ trợ thụ phấn cây ruộng theo cơ chế cũ nhưng không tăng tốc mật và không tạo mật hoa quý trong mẻ mới.
- Ghi nhận công do từng loài đóng góp. Chỉ tạo mật chuyên biệt khi một nguồn đóng góp ít nhất 50% công toàn mẻ. Các loài hoa khác nhau không được cộng gộp thành một nguồn. Hòa đóng góp chọn ID theo quy tắc ổn định hiện có.
- Đặt hoa vào cuối mẻ không đổi ngay mật rừng thành mật quý. Nguồn thay đổi, bị thu hoạch hoặc nở giữa khoảng offline chỉ tác động từ đúng thời điểm thay đổi; tiến độ và công đã tích được giữ lại.
- Mưa làm ong trú, nguồn phấn tạm ngừng và mật tiếp tục ở tốc độ cơ bản. Gió giữ hiệu ứng tăng bán kính 50%. Thụ phấn cây ruộng +10% và cơ chế không cộng chồng được giữ nguyên.
- Vì nguồn và thời tiết có thể thay đổi, thời gian thực của một mẻ có thể khác 24/18/12 giờ trong bảng nguồn liên tục.

## Thu hoạch và giao diện

Túi phải chứa đủ toàn bộ 100 hũ mới thu được. Nếu chỉ còn chỗ cho 99 hũ, giữ nguyên mẻ và túi, báo thiếu chỗ. Chặn thu lồng nhau qua signal inventory để không phát lại mẻ. Hiệu ứng thu hoạch được phát đúng số lượng thật, kể cả mẻ cũ 1 hũ.

Thông tin tổ hiển thị tiến độ, thời gian ước tính theo nguồn hiện tại và số hũ/mẻ. Khi đầy hiển thị loại mật ×100. Hoa thường có giải thích mật rừng; mẻ cũ có dòng cho biết mẻ kế tiếp là 100 hũ. Đã bổ sung bản dịch EN/VI.

Bảng tương tác nay tránh HUD mục tiêu, khung hướng dẫn và thời tiết, ngoài hotbar đã tránh từ trước, để phần thông tin dài không bị che trên màn hình nhỏ.

## Tương thích save v19

Save v18 trở về trước được chuyển tiếp bằng bản sao, không sửa DTO đầu vào:

- Mẻ đã đầy hoặc đang tích công giữ `legacy_batch = true`: giữ công, đóng góp nguồn, loại mật, tốc độ cũ ×1,3 khi có phấn và sản lượng 1 hũ. Giữ cả luật chọn nguồn cũ cho mẻ này.
- Sau khi thu mẻ cũ, cờ được xóa và mẻ tiếp theo dùng đủ luật mới, sản lượng 100 hũ.
- Tổ cũ còn trống chuyển ngay sang luật mới.
- Hũ mật đã ở trong túi không bị thay đổi hoặc nhân lên.
- Save mới lưu cờ cho từng tổ để tải lại giữa quá trình chuyển tiếp không đổi luật hay phát thêm mật. Validator kiểm tra kiểu cờ, tổng công nguồn, nguồn hợp lệ và loại mật đã đầy trước khi phục hồi thế giới.

Mẻ đã đầy không bị đổi loại bởi nguồn hoa hiện tại. Nguồn hoa trong vườn còn khóa không tham gia hệ thống thụ phấn.

## Kiểm thử

Bằng chứng nằm trong [honey_batches_2026-10-24](honey_batches_2026-10-24/).

- Kiểm tra đúng các chu kỳ thật 86.400/64.800/43.200 giây; trước hạn một giây chưa đầy, đủ hạn thì đầy; tiếp tục offline 40 ngày vẫn chỉ một mẻ.
- Kiểm tra cả 10 loại hoa, ưu tiên nguồn và đảo thứ tự; ngưỡng 50%, thay nguồn cuối mẻ, hoa nở giữa khoảng offline, thu hoa, mưa/gió và thụ phấn không cộng chồng.
- Thu 100 hũ, túi còn chỗ cho 99/100 hũ, thu lồng nhau, lưu/tải nhiều lần và ghi file async. Save v18 được thử ở trạng thái trống, đang làm và đã đầy.
- **180/180 test, 13.769 assertions, 17 suite**. Hồi quy bao gồm kinh tế, gói khởi đầu, offline chuồng, vòng đời, ăn uống, mục tiêu, onboarding, đơn hàng, save repository và thời tiết. Test tương tác dùng lượng cám 200 đơn vị và giá đất 60.000 hiện hành thay cho kỳ vọng cũ 300 đơn vị/15.000 xu.
- Native Compatibility: 64/64 kiểm tra ở EN/VI, 1024×720 và 844×390; tiến độ, đầy mẻ, giải thích mẻ cũ, vị trí tránh HUD, thao tác thu thật, số lượng phản hồi và túi sát giới hạn. Đã xem ảnh tiếng Việt ở kích thước điện thoại.
- Lint toàn dự án 0 lỗi/0 cảnh báo. Engine kiểm tra nhóm bees không có lỗi; cảnh báo dependency có sẵn và cảnh báo group do lint riêng thư mục không thấy garden ở thư mục khác. Lint toàn dự án thấy group hợp lệ.
- Web Compatibility export thành công. Chưa kiểm thử Android/iPhone thật trong lượt này.

## Phần tiếp theo

Đo cân bằng theo lịch đăng nhập và phối hợp các nguồn thu: số lần thu mật thực tế, mức thiếu thức ăn/nước, sản lượng cây và tiến độ mở đất. Đây là bước nghiệm thu trải nghiệm kinh tế, sau khi các luật sản xuất đã được nối vào game.
