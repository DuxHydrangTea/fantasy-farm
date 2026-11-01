# Nông sản tách ô theo chất lượng — 01/11/2026

Theo yêu cầu người dùng, Thường/Bạc/Vàng là các chồng vật phẩm độc lập trong túi, hotbar, kho và giỏ worker. Mỗi ô chỉ chứa một chất lượng. Không gộp khác chất lượng khi thêm vật phẩm, kéo thả hay chuyển kho; khác chất lượng thì đổi chỗ. Tên hiển thị gồm tên nông sản và chất lượng; giữ huy hiệu bạc/vàng. Áp dụng mọi ItemType.PRODUCE hỗ trợ quality. Star fruit vẫn là nguyên liệu đặc biệt riêng đã có trong game.

Định danh chồng là cặp base item ID + tier; giữ resource gốc dùng chung để công thức, đơn hàng và bảng giá tiếp tục tham chiếu đúng loại nông sản. Không tạo bộ ID/resource rời thay thế toàn bộ catalog. Các hàm kiểm đếm/tiêu đồ vẫn yêu cầu đúng tier; không tự đổi Bạc/Vàng thành Thường.

## Triển khai

- InventoryComponent chặn stack hỗn hợp và tính capacity theo tier; transfer chỉ trừ số thực nhận. ShopService và FarmStorageService stage đúng chất lượng.
- Harvest/worker scan kiểm tra sức chứa đúng chất lượng, không bỏ cây khi chỉ có chỗ trong chồng chất lượng khác.
- InventoryUI hiển thị và tìm kiếm tên kèm chất lượng, sắp các tier theo Thường/Bạc/Vàng, bỏ bảng đếm ba tier của stack hỗn hợp cũ. Kéo thả kiểm tra cả tier để từ chối payload đã cũ.
- Nhấn thẻ chất lượng trong kho chọn đúng tier, tô đúng thẻ, giới hạn lượng chuyển theo capacity đúng tier.
- Save v39: chuyển save v38 và các phiên bản cũ qua chuỗi migration hiện hữu. Tách ô hỗn hợp, giữ vị trí phần chất lượng đầu và lấp ô trống trước. Nếu container đầy thì thêm đúng số ô cần, bảo toàn mọi đơn vị. Không cấp thêm đồ; mặc định túi mới vẫn 64 ô. Kho và giỏ worker cũng được xử lý; lưu/tải lại nhận số ô bổ sung.
- Migration kiểm tra dữ liệu cũ trước khi tách, không sửa DTO đầu vào. Save v39 không nhận stack hỗn hợp.

## Kiểm chứng

- 106/106 test, 2602 assertion, 12 suite: separate_quality_final_tests.log. Gồm inventory, quality, storage, crop quality, inventory UI, sale service, Chef, orders và supply storage.
- Sau tìm kiếm theo chất lượng và drag payload: 43/43 test, 1612 assertion trong separate_quality_ui_followup.log. Gồm hotbar, mobile, worker compile và migration.
- Ca stale-drag bổ sung + UI/worker compile cuối: 18/18, 92 assertion, separate_quality_final_followup.log.
- Migration kiểm tra mọi nông sản trong catalog, container đầy ở túi/kho/worker, disk roundtrip, dữ liệu lỗi và input immutability. Test full bag tách 64 ô hỗn hợp thành 192 ô, giữ đúng 64 Thường + 128 Bạc + 192 Vàng.
- Preview thật: docs/ui_after_separate_quality.png; cà rốt và lúa mì ba chất lượng ở sáu ô riêng. Preview không bind save người dùng.
- Lint cuối 0 lỗi/cảnh báo: separate_quality_lint.json. Component validator kiểm tra 173 script, không parse/runtime error; còn 45 cảnh báo engine từ mã hiện có (shadowing, integer division, signal chưa dùng, await dư): separate_quality_validation.json. Không tuyên bố toàn repo sạch lỗi.
- Các lỗi fixture bán hàng/kho/migration cũ ghi ở các báo cáo trước vẫn ngoài phạm vi; không đổi vị trí building hay dữ liệu người dùng để làm xanh các suite đó. Không commit/reset worktree.
