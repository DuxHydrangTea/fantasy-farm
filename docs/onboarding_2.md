# Phần 2 — Hướng dẫn đầu game và trợ giúp

Triển khai ngày 24/10/2026. Dùng trực tiếp chuỗi mục tiêu 1A, không tạo bộ đếm hoàn thành riêng.

## Cách sử dụng

- Nhấn **H**, nút **?** cạnh thẻ mục tiêu hoặc chạm thẻ gợi ý để mở Trợ giúp. Đóng bằng **Đóng**, H hoặc Esc.
- Khi đủ chỗ trên HUD, thẻ gợi ý ngắn xuất hiện dưới thẻ mục tiêu. Nội dung đi theo bước đang mở; nếu bước đã xong thì nhắc nhận thưởng. Gợi ý không tự bật modal, không che joystick/hotbar và tự ẩn sau 8 giây hiển thị.
- Trang Trợ giúp có sáu mục: bước hiện tại, điều khiển, túi/mua bán, thời gian/vật nuôi, đơn hàng và cách xử lý khi mắc kẹt. Nội dung phân biệt desktop/cảm ứng và có đầy đủ EN/VI; vuốt hoặc dùng con lăn để đọc.
- **Gợi ý: Bật/Tắt** đổi tùy chọn. **Bỏ hướng dẫn** tắt gợi ý; có thể bật lại mà không xóa các gợi ý đã xem. Trang Trợ giúp luôn mở lại được.
- Xem/bỏ hướng dẫn không hoàn thành mục tiêu, không nhận thưởng. Hoàn thành vẫn chỉ qua hành động gameplay thành công; nhận thưởng vẫn dùng ObjectiveProgress.

## Vật tư và phục hồi

Hồ sơ mới có công cụ cuốc/bình tưới, 12 hạt cà rốt, thức ăn ban đầu, 1.000 xu và túi 64 ô còn chỗ. Công cụ dùng lại; hạt/thức ăn bị tiêu hao. Hướng dẫn nêu rõ chỉ sáu ô đầu nằm trên hotbar, cách chuyển đồ trên cảm ứng, vị trí người thu mua, bán nông sản rồi mua hạt mới, tưới và thu hoạch cây đang có, lấy sản phẩm vật nuôi/hoa.

Trong mục **Khi bị mắc kẹt**, nút **Xin một hạt cà rốt** chỉ mở khi:

- Hồ sơ chưa nhận gói hỗ trợ này.
- Xu hiện tại thấp hơn giá hạt giống rẻ nhất trong cửa hàng.
- Túi không còn hạt hoặc nông sản, ruộng không còn cây trồng.
- Túi còn chỗ chứa một hạt cà rốt.

Nhận đúng **một hạt, một lần mỗi hồ sơ**, không cấp xu, không đặt lại farm và không tự hoàn thành mục tiêu. Dữ liệu hỗ trợ được cập nhật trước khi thông báo inventory để chặn nhận lặp qua callback; kiểm tra đủ chỗ trước khi cấp. Sau đó người chơi phải tự gieo, tưới, thu hoạch và bán. Mức hỗ trợ là lựa chọn ban đầu; kinh tế/sản lượng vẫn cần cân bằng ở phần 4.

## Tích hợp và persistence

- `TutorialProgress`: tùy chọn enabled/skipped, danh sách ID gợi ý đã xem và support_used. Không sở hữu tiến trình hay tiền thưởng mục tiêu.
- `GuideContent`: nội dung theo chín objective ID và sáu chủ đề. Chỉ dẫn phím hiện khớp InputMap mặc định; nếu phần 3B bổ sung đổi phím thì cần chuyển phần diễn đạt sang binding tương ứng.
- `TutorialHints`: hiện xem trước ngắn khi có chỗ, đánh dấu đã xem sau tám giây hiển thị hoặc khi mở nội dung bước hiện tại. Menu mở hoặc điện thoại ở màn hình dọc sẽ ẩn gợi ý và dừng thời gian đánh dấu; màn hình quá ngắn chỉ giữ nút ? để mở nội dung đầy đủ.
- `HelpUI`: kế thừa TradeMenu, dùng khóa modal chung để hủy/reset di chuyển và thao tác đang chờ, loại trừ túi/shop/mục tiêu. Không dừng đồng hồ nông trại. Chủ đề và nội dung có vùng cuộn riêng; nút 48 điểm và status dài nằm trong vùng cuộn cố định.
- `StarterSupport`: điều kiện cứu trợ từ nguồn vật tư thực tế trong thế giới; query không sửa túi/ví.
- Save **v15** thêm DTO tutorial. v14 được chuyển tiếp với gợi ý bật/chưa xem/chưa dùng cứu trợ; migration cũ đi tiếp qua v14. Dữ liệu kiểm tra đúng kiểu bool, ID đã biết, không trùng ID và trạng thái enabled/skipped nhất quán. Load đóng trợ giúp và giữ lịch sử đã xem/bỏ/hỗ trợ theo hồ sơ.

## Xác minh

Bằng chứng: [thư mục QA](onboarding_2_2026-10-24/).

- **165/165 test, 7.239 assertions, 19 suite**: thêm tutorial unit/integration vào 17 suite hồi quy. Không có lỗi GUT/runtime trong log cuối.
- Kiểm tra bật/tắt/bỏ, không cộng tiến trình khi đọc/timer hết, đổi gợi ý sau thành công, nội dung EN/VI, migration v14, DTO sai, load đóng menu, cứu trợ tái nhập/lặp, thiếu chỗ và đang có cây.
- Help safe area tại 667×375 / 740×360 / 844×390 ở mật độ 1× và 3×, EN/VI, gồm nội dung dài và thông báo nhận hỗ trợ.
- **36/36 kiểm tra native**: ?/H/Esc, chạm chọn chủ đề, vuốt danh sách/nội dung, bật/bỏ gợi ý, ba kích thước điện thoại và cửa sổ 500×400. Có nhận cứu trợ bằng nút thật và ghi/đọc file bất đồng bộ trong cache riêng, giữ seen/skip/support_used sau một giờ offline, không nhận cứu trợ lần hai. Không dùng save cá nhân.
- Đã chạy vòng thật bằng native touch: chọn cuốc → cuốc → nhận thưởng → gieo → nhận thưởng → tưới → đợi cây chín theo thời gian thực → thu hoạch đủ 100 cà rốt → bán một sản phẩm tại đúng NPC. Không giả lập hoàn thành bằng đóng hướng dẫn hoặc cấp thẳng tiến trình.
- Ảnh HUD/Trợ giúp EN/VI đã xem trực tiếp. Lint toàn dự án **0 lỗi, 0 cảnh báo**. Engine validation năm script onboarding không có lỗi/cảnh báo thuộc phần mới; còn 22 cảnh báo dependency đã có.
- Web Compatibility export thành công. Tương tác lượt này kiểm tra trên native Compatibility; chưa xác nhận lại browser hoặc Android/iPhone thật.

Đây là kiểm thử chức năng và luồng sử dụng tự động; chưa thay thế chơi thử với người mới thật. Các suite ngoài 19 suite trên không được coi là đã xanh toàn dự án. Bước tiếp theo: **3A — màn hình bắt đầu, tiếp tục, chơi mới và thoát**.
