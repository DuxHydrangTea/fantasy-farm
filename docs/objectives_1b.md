# 1B — HUD và trang mục tiêu

Triển khai ngày 24/10/2026. Dùng model và 9 Resource mục tiêu của 1A.

## Cách sử dụng

- Bấm thẻ mục tiêu bên trái hoặc phím **J** để mở trang. **Esc**, J hoặc **Đóng** để đóng.
- Danh sách hiển thị tất cả bước với trạng thái **Chưa mở khóa / Đang thực hiện / Chờ nhận thưởng / Đã hoàn thành**. Chọn một bước để đọc mô tả, tiến trình và phần thưởng; danh sách và mô tả đều cuộn được.
- **Theo dõi mục tiêu** đổi nội dung HUD. Cho phép theo dõi cả bước tương lai để xem yêu cầu; chỉ bước hiện tại đủ điều kiện mới nhận thưởng được.
- Bấm **Nhận thưởng** khi đủ điều kiện. Sau khi nhận bước đang theo dõi, HUD tự chuyển sang bước kế tiếp. Bước đã nhận không trả thưởng lần hai.
- Nút **− / +** thu gọn/mở rộng HUD. Thẻ thu gọn vẫn nhắc khi có thưởng đang chờ.
- Hoàn thành mới có thông báo ngay trên thẻ HUD trong 4 giây, không tự bật trang. Trang hiển thị kết quả nhận thưởng hoặc lý do thất bại.

## Tích hợp

`FarmWorld` tạo `ObjectiveUI` sau khi tracker sẵn sàng. UI cập nhật qua signal, dùng theme/font hiện có, UIScaleComponent và safe area. Trang chia danh sách/mô tả thành hai cột; nút đóng, theo dõi, nhận thưởng luôn nằm ngoài vùng cuộn. Nút có chiều cao tối thiểu 48 điểm. Màn hình ngang nhỏ cần vuốt mô tả để đọc toàn bộ.

`ToolSelectionComponent.objectives_open` tham gia `is_menu_open()`: mở trang hủy di chuyển/hành động chờ, reset touch và ẩn joystick; túi/shop/trang mục tiêu loại trừ nhau. Vuốt dùng TouchScrollGesture hiện có của MobileControls, không tạo router chạm thứ hai. HUD bên dưới thời tiết, bên trái inspector và phía trên hotbar/joystick; bản debug desktop dành chỗ cho thanh debug thời tiết.

Save **v13** lưu thêm `tracked_id` và `hud_collapsed` trong DTO objectives. v12 được chuyển tiếp với giá trị mặc định, giữ nguyên tiến trình/thưởng; các phiên bản cũ tiếp tục chuỗi migration. Load đóng trang, xóa thông báo và đồng bộ trạng thái, không phát lại thông báo hoàn thành. Claim vẫn dùng giao dịch nguyên tử của 1A.

Sửa vòng đời WorldPersistence: chờ frame đầu qua signal one-shot tự ngắt khi node bị hủy, tránh coroutine tiếp tục trên preview đã xóa. Giữ kiểm tra chỉ main scene thật mới bind save.

## Xác minh

Bằng chứng: [thư mục QA](objectives_1b_2026-10-24/).

- **139/139 test, 6.229 assertions**, 15 suite: objectives, objective UI, persistence/repository/bootstrap, farming, bán nông sản, mở đất, máng, bản địa hóa, cây lâu năm, thời tiết, tổ ong và mobile controls/layout. Log cuối không có lỗi runtime/GUT.
- UI test bao gồm EN/VI, ba kích thước landscape 667×375 / 740×360 / 844×390 ở mật độ 1× và 3×, safe area, nút 48 điểm, nhận thưởng lặp, loại trừ modal, migration v12, lưu và khôi phục tùy chọn, không phát lại completion khi load.
- **21/21 kiểm tra native** bằng Input.parse_input_event: chạm mở/đóng, vuốt không chọn nhầm, nhận thưởng đúng một lần, thu gọn HUD, safe area ba kích thước; J/Esc và cửa sổ desktop 500×400. Ảnh PNG đã xem trực tiếp.
- Lint toàn dự án: **0 lỗi / 0 cảnh báo**. Engine validation 3 script objectives: không lỗi, không cảnh báo thuộc phần objectives; còn 22 cảnh báo từ dependency sẵn có, lưu trong báo cáo.
- Web Compatibility export thành công, báo cáo build lưu cùng bằng chứng. Lượt này chưa tương tác browser: công cụ từ chối truy cập tab localhost theo URL policy; không thử đi vòng chặn. Native Compatibility và export đã kiểm tra độc lập.

Chưa nghiệm thu Android/iPhone thật. Các suite ngoài 15 suite nêu trên không được coi là đã xanh toàn dự án; lỗi fixture boosters/world-persistence đã ghi ở 1A chưa nằm trong phạm vi này. Thưởng 775 xu của 1A vẫn là giá trị khởi đầu, chưa kết luận cân bằng kinh tế.

Phần kế tiếp theo kế hoạch: **1C — bảng đơn hàng thủ công**, tối đa ba đơn, giao vật phẩm và nhận xu nguyên tử, lưu instance đơn hàng.
