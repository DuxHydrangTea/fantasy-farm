# Crop worker v2 — tự cuốc, gieo lại và bón phân

Đã triển khai ngày 25/10/2026, save **v26**. Đây là hướng dẫn hiện hành, thay thế phần giới hạn Crop v1 trong các tài liệu worker/kho cũ.

## Cách sử dụng

1. Gửi hạt cây trồng vào **SeedInventory / kho vật tư**. Có thể gửi nhiều giống cùng lúc, không cần chọn giống bằng G hoặc gán vùng cho worker.
2. Thuê người trồng trọt và mở bảng quản lý Crop. Worker thuê mới bật **Tự cuốc và gieo lại** mặc định. Worker có sẵn trong save v25 giữ chế độ chăm/thu cũ: bật nút này một lần để cho phép tiêu hạt trong kho.
3. Worker tự cuốc đất hợp lệ đã mở, gieo, tưới, thu hoạch và gieo tiếp. Mỗi lần gieo thành công trừ đúng **một hạt**; cuốc riêng không trừ hạt. Khi loại hạt đầu tiên trong thứ tự slot hết, tự dùng loại tiếp theo.
4. Muốn bón, gửi `crop_fertilizer` vào kho vật tư và bật **Tự bón cây do người làm trồng**. Mặc định tắt. Không dùng tonic hoặc hạt hoa/cây giống lâu năm để trồng ruộng.
5. Nông sản thu hoạch chuyển trực tiếp vào **Warehouse**. Rút ở kho nông sản để bán hoặc nấu ăn.

Worker làm một ô mỗi nhiệm vụ, độc lập nông cụ 6×6 của player. Phạm vi là toàn bộ ruộng đã mở; không có chọn vùng, giống cố định hay quota ngày. Nước tưới miễn phí. Hạt chỉ nằm trong túi player không được lấy thay kho.

## Quy tắc bảo toàn vật tư

- Hết hạt sau khi cuốc: giữ đất đã chuẩn bị, không trừ hạt hoặc tạo cây miễn phí; vẫn chăm và thu cây sẵn có.
- Player vừa trồng vào ô mục tiêu hoặc rút hạt/phân trước khi worker hoàn thành: kiểm tra lại, bỏ lượt không còn hợp lệ.
- Ưu tiên thu cây chín, tưới cây khô, bón hợp lệ, gom sản phẩm, rồi cuốc/gieo. Luân phiên theo lịch sử gieo để không chỉ trồng lại vài ô gần nhất.
- Chỉ bón cây thuộc đúng lứa do worker gieo, một lần/cây, trước 50% tăng trưởng. Dùng API phân hiện tại giảm 20% thời gian gốc. Không tự tiêu phân lên cây player gieo.
- Warehouse không đủ chứa nguyên đợt thu: giữ cây chín. Các ô trống khác vẫn có thể được gieo nếu còn hạt.
- Tắt tự trồng vẫn chăm/thu; tạm dừng dừng toàn bộ việc Crop và giữ phần thời gian công việc còn lại. **Tạm dừng vẫn trả lương** theo hợp đồng.

## Save và offline

Migration v25 → v26 thêm cấu hình tự động và lịch sử gieo hữu hạn theo ruộng, giữ nguyên kho và các hệ thống hiện có. Công việc cuốc/gieo/bón dùng chung timeline online/offline, tính cả di chuyển và thời gian làm; không cộng sản lượng trung bình hoặc bỏ qua vật tư. Không thêm node quản lý riêng cho mỗi ô. Giống G và túi player không bị đổi.

## Kiểm chứng

- Hồi quy chọn lọc: **153/153 test, 2.430 assertions**, 19 script, bao gồm ba vai worker, kho, nông cụ, Chef, tutorial và save. Log: `.godot/crop-worker-regression-engine.log`.
- Native trên **Compatibility và Forward+**: mỗi renderer **26/26 kiểm tra**, worker đi/làm thật trên map, gieo ba ô bằng hai giống, bón, thu và trồng lại. Kiểm tra nút tạm dừng/tiếp tục bằng cảm ứng ở 844×390. Dùng profile QA riêng, không sửa save cá nhân. Báo cáo và ảnh: `.godot/crop-worker-native/`.
- Mô phỏng 48 giờ một lần so với chia từng giờ khớp trạng thái/cây/kho/xu. Kịch bản hai ô, 12 lượt gieo: khoảng 606 ms. Kịch bản cache toàn bộ **1.632 ô**, 60 hạt và 60 phân: khoảng 2.810 ms, tiêu đúng tồn kho. Đây là số đo trên máy phát triển với nguồn hữu hạn, không phải bảo đảm hiệu năng cho mọi thiết bị hoặc nguồn vô hạn.
- Lint toàn dự án: 0 lỗi, 0 cảnh báo. Engine kiểm tra 9 script worker: 0 lỗi; còn 29 cảnh báo dependency có sẵn, không thuộc script worker mới.
- Build Web bằng Godot 4.7.2 thành công, báo cáo `.dist/build-report.json` có `ok: true`; bản xuất tại `.dist/index.html`.
- Không tuyên bố toàn bộ test lịch sử của repository đã xanh; một số fixture cũ về map/kinh tế đã được ghi nhận trước lượt triển khai này.

Nguồn chính: `components/workers/crop_worker_policy.gd`, `crop_automation_state.gd`, `worker_service.gd`, `worker_menu.gd`; kiểm thử mới: `tests/integration/test_crop_automation.gd` và `scripts/run_crop_worker_qa.py`.
