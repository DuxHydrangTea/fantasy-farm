# Management UI — 27/10/2026

Đã thay giao diện bảng quản lý chuồng và khu ô trồng cây theo hai concept đã chốt, dùng theme/khung/font của bộ UI hiện tại. Concept là tham chiếu bố cục; bản chạy dùng sprite và giá/nội dung thật của game.

## Tích hợp

- `scenes/animals/pen_dashboard.tscn` thay phần dựng UI bằng code. Header có tiền và đóng; ba ô tổng quan vật nuôi, máng thức ăn, máng nước. Roster cuộn riêng; sidebar nâng cấp có giá, sức chứa tiếp theo và phản hồi.
- `scenes/animals/animal_card.tscn` dùng portrait idle độc lập từ SpriteFrames của vật nuôi, độ no/nước và trạng thái sản xuất. Hiển thị tuổi/vòng đời thêm trong thẻ khi dùng bố cục nhỏ; desktop có tooltip. Không sửa AI, nhu cầu hoặc sản lượng khi mở bảng.
- `scenes/trees/tree_plot_menu.tscn` dùng cho cả cây ăn quả và cây lấy gỗ. Hiển thị đã mở/đã trồng/còn trống, sơ đồ thật 17×9 ô theo vị trí cây, phần mở tiếp theo và giá nâng cấp. Sơ đồ chỉ đọc; không thêm lệnh trồng/chặt/thu hoạch vào bảng này.
- PenBoard/TreePlotBoard instantiate các scene mới; giữ nguyên tương tác, modal lock và dịch vụ nâng cấp. Các lệnh vẫn có kiểm tra báo giá ở service và cooldown 500 ms ở UI.
- Mobile thu nhỏ sidebar, bỏ ảnh trang trí, giữ roster hai cột và vùng cuộn; nút thao tác tối thiểu 48 px. Bảng ao không hiển thị ảnh chuồng không phù hợp. Bảng chuồng độc lập không có FarmWorld vẫn hiện trạng thái trống và ẩn nâng cấp.
- Thêm màu chữ focus/hover-pressed vào theme dùng chung để dấu đóng không bị trắng trên nền kem. Không đổi giá, tiến trình nâng cấp hoặc schema save.

## Kiểm chứng

Godot 4.7.2, bản QA staging và userdata riêng, không nạp save cá nhân.

- 4/4 test UI mới đạt: báo giá/sức chứa/cooldown chuồng, nâng cấp đúng vùng cây, giới hạn tối đa, đổi ngôn ngữ không đổi model/roster.
- Bộ regression gồm dashboard, pen upgrades, tree plot upgrades, localization và UI mới: 31 test; 28 đạt, 1 lỗi cũ, 2 pending; 2616/2617 assertions. Đã chạy baseline trước thay đổi: cùng lỗi query va chạm tại bảng PondPen. Hai test profile tùy chọn được bỏ qua vì staging không chứa fixture profile; không đọc save cá nhân để chạy chúng.
- Hai kiểm tra mục tiêu bổ sung đều đạt: bảng chuồng trống ở màn hình VI ngắn (4 assertions) và thẻ trạng thái thiếu thức ăn/nước (7 assertions). Fixture được cập nhật để instantiate scene thay constructor, assertion trạng thái dùng bản dịch hiện tại.
- Native X11 Compatibility: 57/57 kiểm tra đạt. Desktop EN/VI; touch 844×390 có safe inset; 667×375. Click nâng cấp chuồng tăng 5 chỗ và trừ đúng tiền; chạm nâng khu cây thêm 9 ô đúng vùng; cooldown chặn phí lặp; thử cả chuồng trống, ao, cây lấy gỗ, thiếu tiền và đóng trả điều khiển.
- UI reports fail_on=any tại hai kích thước cho cả hai màn: 0 zero-size/offscreen/overlap; các report có Control hiển thị thật. Ảnh runtime không rỗng và đã xem trực tiếp.
- Inspect_scene xác nhận phân cấp: dashboard 50 node, animal card 15 node, tree menu 45 node. Signal nối trong controller đã được native probe kiểm tra qua thao tác.
- Lint trước/sau: 0 lỗi và 11 cảnh báo đường dẫn cũ. Validation kiểm tra 15 scene animals, 13 scene trees: 0 parse/resource error. Không diagnostic trong các file UI mới/thay đổi. Animals có 7 node configuration warning ở các scene vật nuôi cũ chờ cấp SpriteFrames lúc runtime; tổng warning dependency là 36 ở animals và 28 ở trees. Runtime còn UID cũ của tài nguyên hoa dùng đường dẫn dự phòng.
- Chưa nghiệm thu trên điện thoại vật lý.

`pen-concept.png` và `tree-plots-concept.png` là bản thiết kế. `*-runtime-*.png` là bản chạy thật. `verification.json`, `runtime-report.json`, `*-layout.json` và `*-tree.json` lưu bằng chứng; các scenario có thể tái chạy bằng run_scenario.py của skill Godot trên staging.
