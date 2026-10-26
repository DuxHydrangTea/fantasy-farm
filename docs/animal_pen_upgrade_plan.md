# Kế hoạch mở rộng sức chứa chuồng bằng coins

Ngày: 26/10/2026. Trạng thái: đã triển khai; xem `docs/pen_upgrades_2026-10-26/README.md` để biết kiểm tra và tương thích.

## Quy tắc đã thống nhất

- Ba chuồng độc lập: gà, gia súc, vịt/ngỗng.
- Hồ sơ mới có 5 chỗ mỗi chuồng. Sáu mức sức chứa: 5, 10, 15, 20, 25, 30.
- Mỗi lần nâng thêm 5 chỗ, chỉ thanh toán coins. Không cần nguyên liệu, cấp nhân vật, đất mở rộng hay thời gian xây dựng.
- Nâng từng mức liên tiếp, hiệu lực ngay. Slot dùng chung cho mọi loài hợp lệ trong cùng chuồng; con non và trưởng thành đều chiếm một chỗ.
- Mở chỗ không tặng con giống; mua vật nuôi vẫn kiểm tra sức chứa và vị trí đứng thực tế.
- Không thay kích thước chuồng, vị trí máng hay sản lượng vật nuôi trong tính năng này.

## Giá đề xuất cho lần triển khai đầu

Giá dưới đây là giá của riêng lần nâng, không phải tổng tích lũy. Đây là đề xuất cần kiểm nghiệm nhịp kiếm tiền, chưa phải giá đã cân bằng qua playtest.

| Sức chứa | Chuồng gà | Chuồng vịt/ngỗng | Chuồng gia súc |
|---|---:|---:|---:|
| 5 → 10 | 20.000 | 30.000 | 60.000 |
| 10 → 15 | 40.000 | 60.000 | 120.000 |
| 15 → 20 | 80.000 | 120.000 | 240.000 |
| 20 → 25 | 140.000 | 210.000 | 420.000 |
| 25 → 30 | 220.000 | 330.000 | 660.000 |
| Tổng lên 30 | 500.000 | 750.000 | 1.500.000 |

Cơ sở: giá con giống hiện tại là gà 16.000; vịt 25.000; ngỗng 36.000; cừu 50.000; bò 75.000; heo 100.000; ngựa 150.000. Lần mở đầu thấp hơn chi phí mua thêm năm con, tạo cơ hội mở rộng sớm; các lần cuối tăng mạnh để thành mục tiêu dài hạn. Chưa suy ra thời gian hoàn vốn chỉ từ giá mua: cần đo sản lượng, giá bán, thức ăn và thời gian chăm sóc khi playtest. Giá đặt trong resource để chỉnh độc lập với code.

## Thứ tự triển khai

### 1. Dữ liệu và sức chứa

- Thêm catalog giá theo loại chuồng và mức đích, cùng state mức nâng theo `persistent_id` chuồng. Không phụ thuộc tên node hoặc loài vật đang ở trong chuồng.
- Công thức sức chứa: mức × 5, mức hợp lệ 1–6. Catalog là nguồn giá duy nhất; state là nguồn tiến độ duy nhất.
- AnimalPen nhận sức chứa hiện tại từ state; hồ sơ mới khởi tạo ba chuồng ở mức 1.
- Giữ khả năng cấu hình sức chứa cho các pen thử nghiệm không thuộc ba chuồng được quản lý.
- Logic mua vật nuôi và bảng quản lý cùng đọc sức chứa hiệu lực, tránh UI báo một giới hạn còn giao dịch dùng giới hạn khác.

### 2. Giao dịch nâng cấp

- Service riêng cung cấp báo giá và mua nâng cấp, theo mẫu giao dịch nâng công cụ hiện có.
- Kiểm tra chuồng hợp lệ, profile đã tải thành công và cho phép lưu, chưa tối đa, không có giao dịch xung đột, đủ coins.
- Khi mua, kiểm tra lại mức và giá so với báo giá đang hiển thị. Báo giá cũ không được tự tính tiền theo mức mới.
- Khóa giao dịch chống bấm liên tiếp/tái nhập từ callback. Commit trừ coins và tăng mức trước khi phát tín hiệu cập nhật giao diện.
- Nếu bước commit thất bại, khôi phục số coins; không trừ tiền một nửa giao dịch. Chỉ thay đổi chuồng được chọn.
- Sau giao dịch yêu cầu lưu theo SaveManager, phối hợp autosave để không chụp trạng thái đang commit. Dùng cơ chế báo lỗi/thử lưu lại hiện có nếu IO thất bại.

### 3. Bảng quản lý chuồng

- Bổ sung khu mở rộng ở PenDashboard hiện có, dùng được với chuột và cảm ứng.
- Hiển thị số con/sức chứa hiện tại, mức nâng và kết quả lần tiếp theo: ví dụ `4/5 · Mức 1/6`, `5 → 10 chỗ`, `20.000 coins`.
- Một nút mua có giá rõ ràng. Thiếu coins hiển thị trạng thái/thiếu bao nhiêu; đang giao dịch khóa nút; mức 6 hiện `Đã tối đa · 30 chỗ`.
- Nâng xong cập nhật đồng thời tiền và sức chứa. Bán bớt vật nuôi không làm giảm mức nâng.
- Khi mua vật nuôi thất bại vì đầy chuồng, hướng dẫn tới bảng quản lý. Nếu thiếu vị trí đứng dù còn slot, thông báo đúng lý do, không gợi ý nâng slot như một bảo đảm giải quyết chỗ đứng.
- Thêm chuỗi dịch theo hệ thống ngôn ngữ của dự án.

### 4. Save và tương thích

- Bổ sung tiến độ nâng chuồng vào schema save, tăng version từ phiên bản hiện tại tại thời điểm triển khai. Capture/restore/preflight đều đọc state này.
- Profile mới: ba chuồng 5 slot.
- Save cũ chưa có tiến độ: mỗi chuồng nhận mức nhỏ nhất đủ chứa vật nuôi đang có, làm tròn lên theo gói 5, tối thiểu 5 và tối đa 30. Không trừ coins cho bước chuyển đổi.
- Nếu save cũ có hơn 30 con: giữ toàn bộ và đặt mức 6. UI hiển thị số thực tế, ví dụ 34/30; chặn mua thêm. Restore không được xóa con hoặc từ chối chỉ vì vượt giới hạn mới.
- Save đã có tiến độ hợp lệ phải được giữ nguyên, không tính lại mức theo số con sau khi bán hoặc khi reload. Giá trị level sai, ID trùng/không hợp lệ được kiểm tra theo schema.
- Không cập nhật save thật chỉ để thử tính năng; dùng bản sao/hồ sơ kiểm thử.

### 5. Kiểm thử và nghiệm thu

- Unit: sáu mức; năm giá cho từng chuồng; đủ/thiếu coins; mức tối đa; bấm đôi; báo giá cũ; rollback; nâng một chuồng không ảnh hưởng hai chuồng kia.
- Integration: đủ 5 con chặn con thứ 6; mua nâng lên 10 cho phép mua thêm; con non và trưởng thành dùng chung giới hạn; slot trống vẫn phải qua kiểm tra không gian vật lý.
- Persistence: save/load giữ mức và coins; migration với 0, 5, 6, 29, 30, 31, 36 con; save/load sau khi bán không giảm mức; trạng thái vượt giới hạn cũ được giữ.
- Native UI: ba bảng chuồng, thiếu coins, nâng thành công, tối đa, click/touch. Kiểm tra cả mua vật nuôi và màn hình quản lý cập nhật ngay.
- Kiểm tra ba chuồng có đủ chỗ đứng cho 30 con trong bố cục hiện tại, đặc biệt ao vịt/ngỗng đang giới hạn 20. Không cam kết đủ chỗ chỉ bằng thay biến capacity; nếu không đạt, báo cụ thể vấn đề bố trí trước khi mở rộng phạm vi sang thiết kế chuồng.
- Chạy lint, các suite chăn nuôi/save bị tác động và smoke world. Ghi riêng lỗi đã tồn tại để tránh quy nhầm cho tính năng mới.

## Điểm tích hợp đã đối chiếu

- `components/animals/animal_pen.gd`: sức chứa cố định hiện tại.
- `components/animal_trade_service.gd`: kiểm tra capacity và vị trí trước mua.
- `components/animals/management/pen_dashboard.gd`: giao diện quản lý và số lượng/sức chứa.
- `components/tools/tool_upgrade_service.gd`: tham khảo khóa giao dịch, báo giá cũ, rollback, tín hiệu sau commit; không gộp logic chuồng vào service công cụ.
- `persistence/world_state_adapter.gd`, `persistence/save_schema.gd`: lưu và khôi phục tiến độ mới.
- `resources/shops/animals/*.tres`: giá con giống tham khảo cho bảng đề xuất.
