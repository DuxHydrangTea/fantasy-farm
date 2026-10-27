# Storage UI — 27/10/2026

Đã gắn concept kho vào cả kho nông sản và kho giống/thức ăn. `FarmStorageAccess` tạo `scenes/storage/storage_menu.tscn` thay cho UI dựng toàn bộ bằng code. Dùng lại theme, font, khung NinePatch của HUD/túi đồ/cửa hàng.

## Hành vi

- Hai grid cuộn riêng, hiển thị các ô thực; kho nông sản 128 ô, kho vật tư 64 ô. Sức chứa lấy từ inventory hiện tại, kể cả dữ liệu save đã thay đổi số ô.
- Chọn nguồn ở túi hoặc kho, chọn thường/bạc/vàng nếu vật phẩm có chất lượng, chọn số lượng hoặc Tối đa rồi cất/lấy. Hết chất lượng đang chọn sẽ khóa lệnh; không tự chuyển sang chất lượng khác.
- Tối đa giới hạn theo nguồn và sức chứa đích. Khi nơi nhận đầy, nút bị khóa và có thông báo. Đồng bộ SpinBox với nút Tối đa ngay trong cùng khung nhập để apply không dùng lại số cũ.
- Vật phẩm không thuộc kho bị làm mờ và không chọn được. Cất hết/lấy hết vẫn dùng service lọc loại và giữ nguyên mọi chất lượng.
- Slot là hình vuông với góc khung cố định, số cột thích ứng. Có thể chọn bằng bàn phím, click hoặc chạm; EN/VI cập nhật khi menu đang mở. Đóng menu/rời cửa kho trả lại điều khiển nhân vật.
- `FarmStorageService.transfer` thêm tham số quality mặc định -1, giữ hành vi cũ cho caller không truyền; 0–2 chuyển riêng chất lượng đã chọn. Khóa giao dịch và staging/rollback của hai inventory được giữ nguyên; không đổi schema save.

## Kiểm chứng

Godot 4.7.2, staging và userdata QA tách biệt, không nạp save cá nhân.

- 26/26 test, 2350 assertions đạt: storage service, world/menu, supply storage flow, localization. Bao gồm đầy đích, số dư từng chất lượng, Tối đa và chặn thao tác khi hết chất lượng đang chọn.
- Probe giao diện mới: 39/39 kiểm tra đạt; desktop EN/VI, touch 844×390 với safe inset và 667×375; cất bạc bằng chuột, lấy bạc bằng chạm, chất lượng khác không đổi, slot vuông, cuộn tới ô 128.
- Probe storage hiện có: 26/26 kiểm tra đạt; E/Enter/Escape, chuột/chạm, lọc kho, chuyển hàng loạt, đóng/mở, capture/restore snapshot. Dùng X11 và tắt VSync trong QA vì backend cửa sổ mặc định đã chặn tiến trình khung hình ở một số lượt.
- UI report với fail_on=any tại hai kích thước: header, thanh chọn vật phẩm/chất lượng, thanh lệnh, thông báo và hai heading đều không zero-size/offscreen/overlap. Có Control hiển thị thật trong mọi report. Grid cuộn được kiểm tra riêng bằng native probe; không tuyên bố toàn bộ các hàng bị clip là offscreen-free.
- Ảnh runtime đã kiểm tra không rỗng. `concept.png` chỉ là mock; các PNG còn lại là ảnh trong engine. Inspect_scene xác nhận 45 node có đúng phân cấp.
- Validation scenes/storage kiểm tra 2 scene, 0 lỗi/parse error/node config warning; 28 cảnh báo dependency có sẵn, không có diagnostic trỏ vào file storage thay đổi. Lint 0 lỗi, 11 cảnh báo đường dẫn cũ cả trước/sau. Runtime vẫn có UID cũ của tài nguyên hoa dùng đường dẫn dự phòng.
- Kiểm tra mở rộng: worker warehouse 8/10 đạt, còn 2 test save legacy thất bại; offline parity 0/1, thất bại ở validate/restore checkpoint. Đã chạy cùng các test với service/menu/access trước thay đổi trong project QA riêng: cùng 3 test và cùng assertions thất bại, không có parse error. Không sửa hệ thống save/offline trong thay đổi UI này.
- Chưa nghiệm thu trên điện thoại vật lý.

`verification.json` tổng hợp kết quả; `*-scenario.json` tái chạy các phạm vi UI report bằng script run_scenario.py của skill Godot. `redesign-runtime-report.json` và `report.json` là kết quả hai probe native.
