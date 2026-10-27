# Inventory UI — 27/10/2026

Đã gắn vào `scenes/ui/inventory.tscn`, dùng `resources/ui/cozy_hud/inventory_theme.tres` và slot NinePatchRect chung với HUD. Asset có góc cố định 8 px, lọc nearest; nút chính thêm màu xanh sage.

- Grid 64 ô có cuộn; sáu ô đầu là hotbar. Sidebar hiển thị icon, tên, loại, tổng số và chất lượng thường/bạc/vàng trực tiếp.
- Chuyển vật phẩm: chọn nguồn, bấm nút chuyển, chọn đích. Gán hotbar: chọn vật phẩm, bấm gán, chọn một trong sáu ô đầu hoặc phím 1–6. Ô đã có đồ được hoán đổi theo logic inventory hiện có. Đóng túi hủy thao tác đang chờ.
- Desktop có tám cột; chế độ nhỏ giảm số cột, icon và chữ, đặt hai nút cạnh nhau. Mô tả và grid cuộn riêng. Hỗ trợ đổi EN/VI khi đang mở.
- `concept.png` là concept đã duyệt; `inventory-*.png` là ảnh runtime thực, không phải mockup.

## Kiểm chứng

Godot 4.7.2, bản staging với dữ liệu QA riêng; không nạp save cá nhân.

- 37/37 test inventory/hotbar/mobile, 429 assertions đạt.
- Localization: 4/5 test đạt, gồm đổi ngôn ngữ trực tiếp của túi/hotbar/ví và kiểm tra bản dịch/font. Test bán vật nuôi không đạt do danh sách AnimalActor rỗng; nằm ngoài UI túi đồ. Fixture ngôn ngữ và số dư được khai báo tường minh để không phụ thuộc mặc định dự án.
- Probe native Compatibility: 40/40 kiểm tra đạt; desktop EN/VI, touch 844×390 có safe inset, màn hình 667×375, cuộn tới ô 64, gán vào hotbar có đồ, đóng hủy thao tác, bảo toàn tổng vật phẩm và chất lượng.
- UI reports: desktop 234 Control, compact 233 Control; không zero-size/offscreen. Mỗi report có 8 overlap được xem xét: nhãn phím tắt/số lượng nằm trên vùng TextureRect của icon trong slot theo thiết kế. Không tắt ghi nhận overlap. Probe native kiểm tra thêm grid không đè sidebar và nút nằm trong panel.
- Lint: 0 lỗi, 11 cảnh báo đường dẫn có sẵn. Runtime còn cảnh báo UID cũ dùng đường dẫn dự phòng. Chưa kiểm thử điện thoại vật lý.

`desktop-scenario.json` và `compact-scenario.json` có thể chạy qua script run_scenario.py của skill Godot trên staging project. Report dùng viewport UI đã qua UIScale nên kích thước logic compact có thể khác kích thước cửa sổ. `report.json` là kết quả probe native; `verification.json` tổng hợp kiểm chứng.
