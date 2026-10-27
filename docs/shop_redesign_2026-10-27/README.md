# Shop UI — 27/10/2026

Đã tích hợp concept được duyệt vào cửa hàng Lái Buôn. Scene chính: `scenes/ui/shop.tscn`; controller: `components/shop_ui.gd`; theme riêng: `resources/ui/cozy_hud/shop_theme.tres`, dùng lại texture NinePatch và font của HUD/túi đồ.

## Hành vi

- Header hiển thị tiền hiện tại và nút đóng; lưới hàng bên trái, ảnh/tên/mô tả và thanh toán bên phải.
- Giữ cả sáu danh mục thực: hạt cây trồng, vật tư, hạt hoa, vật nuôi, bán vật nuôi, nâng cấp công cụ. Thanh danh mục cuộn ngang khi cần; grid và mô tả cuộn riêng.
- Giá đơn vị, số lượng trong túi và tổng tiền đọc trực tiếp từ model. Nút +/- dùng chung TouchQuantityComponent với tùy chọn hiển thị trên desktop; các nơi khác giữ mặc định cũ.
- Mua/bán và nâng cấp vẫn gọi các service hiện có, tiếp tục kiểm tra lại tiền, sức chứa, chuồng và điều kiện nâng cấp khi giao dịch.
- Màn hình nhỏ giảm số cột/cỡ icon, giữ nút tối thiểu 48 px; nút mua bị chặn hiện lý do trực tiếp. Đổi EN/VI cập nhật cả tên hàng và tab danh mục.
- Concept có giá và trạng thái minh họa. Bản chạy dùng giá/catalog thật; không thêm giới hạn tồn kho hoặc cơ chế khóa hàng giả chỉ để giống ảnh.

## Kiểm chứng

Godot 4.7.2; staging project và thư mục userdata QA riêng; không nạp save cá nhân.

- 29/29 test đạt, 2432 assertions: shop, tool upgrade UI, localization, mobile controls. Fixture khai báo EN và tiền rõ ràng, các kỳ vọng giá/số mặt hàng lấy theo catalog hiện tại thay cho số cũ. Test bán vật nuôi của localization trước đây thiếu tiền nay cũng đạt.
- Probe native Compatibility: 50/50 kiểm tra đạt. Desktop EN/VI; touch 844×390 có safe inset; 667×375. Giao dịch bằng chuột/cảm ứng trừ đúng tiền, thêm đủ vật phẩm, cập nhật số đang có; thiếu tiền chặn mua; tất cả danh mục vẫn trong màn hình và ô cuối có thể cuộn tới.
- UI report tại hai kích thước: header, sidebar/checkout, tabs đều 0 finding với fail_on=any. Toàn cây compact 0 finding. Toàn cây desktop có 2 offscreen là nhãn nằm trong phần danh sách đã bị ScrollContainer cắt; đã xem xét và giữ nguyên trong report. Reporter không tính clipping của tổ tiên. Không có overlap/zero-size. Probe riêng xác nhận các control tương tác nằm trong màn hình.
- Inspect_scene xác nhận 51 node có phân cấp đúng; các signal runtime kết nối qua controller.
- Validation thư mục scenes/ui: 7 scene kiểm tra, không resource/parse error hoặc node config warning. Có 28 warning từ dependency hiện có, gồm integer division trong hàm thời gian và shadowed variable của upgrade view; chưa dọn các cảnh báo ngoài thay đổi UI.
- Lint trước/sau: 0 lỗi, 11 cảnh báo đường dẫn cũ. Runtime còn cảnh báo UID cũ của tài nguyên hoa dùng đường dẫn dự phòng. Chưa thử trên điện thoại vật lý.

`concept.png` là bản mock đã duyệt; `shop-*.png` là ảnh runtime thật. `runtime-report.json`, `*-layout.json`, `verification.json` lưu bằng chứng kiểm tra. Các scenario dùng UIScale và viewport logic của dự án; số pixel logic trong report có thể khác kích thước cửa sổ.
