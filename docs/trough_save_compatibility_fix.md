# Sửa lỗi tải save do máng — 25/10/2026

Triệu chứng: `Load failed; autosave disabled: A trough was not found or its capacity changed.`

Scene hiện tại có một số máng bị override sức chứa 120, trong khi save v20 đang giữ 600 đơn vị. Bốn instance thêm sau cũng không còn persistent ID đã dùng trong save. Hai sai lệch authoring này khiến preflight từ chối tải; autosave bị tắt để bảo vệ profile.

Đã sửa `world/main_world.tscn`:

- Các máng trong MainWorld có capacity 1200 theo bảng kinh tế. Hai máng gốc của PondPen đã kế thừa capacity 1200 từ scene con.
- Khôi phục ID `barn_feedtrough_02`, `barn_watertrough_02`, `pond_feedtrough_02`, `pond_watertrough_02`.
- Giữ vị trí, stock khởi tạo và các thiết lập còn lại. Không sửa file save hoặc nới validation, không thêm migration/schema mới.

Kiểm chứng:

- Bản sao của profile đang gặp lỗi đã qua preflight **và restore** trong một World cô lập. SHA-256 của file save gốc trước/sau giống nhau.
- **15/15 tests, 117 assertions**: năm test mới kiểm tra ID/capacity của đủ 12 máng, giữ nguyên stock 600 và DTO đầu vào, vẫn từ chối mất ID hoặc giảm capacity thật, bật lại quyền lưu và roundtrip bằng repository trong bộ nhớ; thêm bootstrap và core trough tests.
- Lint không lỗi/cảnh báo; engine validation của World đạt; Web export đạt.
- Lượt kiểm tra rộng hơn: 33/54 tests đạt, 21 lỗi thuộc các test persistence/refill cũ. Chạy riêng hai suite đó trên scene HEAD chưa sửa cũng có đúng cùng 21 test thất bại; không có test mới thất bại do bản sửa. Các fixture này còn giả định kinh tế/đàn mặc định cũ, ví dụ vốn 1000 và feed package 300 đơn vị.

Log QA nằm trong `.godot/trough-save-qa/`, `.godot/trough-save-targeted-tests.log`, `.godot/trough-save-tests.log`, `.godot/trough-save-after-lint.json`, `.godot/trough-save-world-validation.json` và `.godot/trough-save-web.log`. Bản sao profile trong `.godot` là dữ liệu QA cục bộ, không đưa vào Git hoặc báo cáo công khai.

Để áp dụng vào phiên đang mở: dừng Play rồi chạy lại. Khi bind lại World, save sẽ được tải và quyền autosave được bật lại sau restore thành công.
