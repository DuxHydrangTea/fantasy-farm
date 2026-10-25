# Nâng cấp nông cụ — tối đa 6×6

Đã hoàn thành U1–U6 ngày 25/10/2026. Tại NPC thương nhân hiện có, mở mục **Nâng cấp nông cụ** để nâng riêng Cuốc, Bình tưới và Gieo hạt. Service và catalog độc lập với NPC để có thể chuyển sang nhân vật khác sau này.

| Công cụ | 1×1 → 2×2 | 2×2 → 3×3 |
|---|---:|---:|
| Cuốc | 30.000 xu | 90.000 xu |
| Bình tưới | 30.000 xu | 90.000 xu |
| Gieo hạt | 40.000 xu | 120.000 xu |

Cấp 2 cần mua thêm 1 cột đất, cấp 3 cần mua thêm 3 cột, tính từ số cột khởi đầu của từng profile. Tổng sáu nâng cấp là 400.000 xu. Đây là cấu hình v1 trong `resources/tools/upgrades.tres`, có thể chỉnh sau phản hồi chơi thực tế.

## Mở rộng: cấp tối đa 6×6

Sáu cấp tương ứng 1, 4, 9, 16, 25 và 36 ô. Phạm vi chẵn lệch phải một ô; phạm vi lẻ cân giữa. Save cấp 1–3 giữ nguyên, có thể nâng tiếp. Tổng giá nâng cả ba công cụ lên cấp 6 là 3.500.000 xu.

| Cấp đích | Cuốc / Bình tưới | Gieo hạt | Cột mua thêm |
|---|---:|---:|---:|
| 4×4 | 180.000 | 240.000 | 5 |
| 5×5 | 300.000 | 400.000 | 7 |
| 6×6 | 450.000 | 600.000 | 9 |

Giá và điều kiện cấp 4–6 là cấu hình ban đầu. Benchmark và bằng chứng 80 bài test bên dưới thuộc bản 3×3 trước đó, chưa đại diện chi phí 36 ô.

## Sử dụng

- Khi cầm công cụ hoặc hạt giống cây trồng, bấm **R** hoặc nút **Vùng** trên HUD để đổi phạm vi đã mở. Điện thoại dùng nút này, kể cả khi ngón còn lại giữ joystick.
- Mua cấp mới tự chọn vùng lớn nhất. Cấp và vùng đã chọn được lưu riêng cho từng công cụ.
- Vùng nằm phía trước nhân vật, xoay theo bốn hướng. Vùng 2×2 lệch về bên phải; vùng 3×3 cân giữa theo chiều ngang.
- Preview xanh: thực hiện được; vàng: thiếu hạt; đỏ: ô bị chặn. Bỏ qua ô khóa, sai địa hình hoặc đã có cây. Gieo theo hàng gần trước, từ trái sang phải theo hướng nhìn.
- Có 5 hạt và 9 ô hợp lệ thì gieo đúng 5 ô. Một hạt cho mỗi ô thành công. Nâng cấp gieo áp dụng mọi hạt cây trồng; không mở rộng tương tác chậu hoa.
- Mỗi lần dùng chỉ có một animation và một lần commit ở impact. Khóa phạm vi trong động tác; chặn mua và đổi vùng khi menu hoặc animation đang khóa thao tác.

## Lưu và tính nhất quán

Save schema v21 bổ sung cấp và vùng; schema hiện tại v23 đã bổ sung Chef và workers, giữ nguyên dữ liệu nông cụ. Save cũ v20 được bổ sung mức 1×1; giữ chuỗi migration từ v19. Giao dịch kiểm tra lại giá, cấp, đất và xu; commit xu/cấp trước khi phát thông báo, chống mua lặp qua callback. Batch gieo commit toàn bộ cây trước thông báo và trừ hạt đúng một lần.

## Kiểm chứng

- 80 bài kiểm thử, 1.214 assertions: model, giao dịch, persistence, phạm vi bốn hướng, gieo thiếu hạt, một impact, NPC, HUD và cảm ứng.
- Chạy native: 28 kiểm tra đạt trên mỗi renderer Compatibility và Forward+, gồm click NPC, phím R, animation thật, lưu/tải trong bộ nhớ và ScreenTouch hai ngón.
- Lint không lỗi/cảnh báo; kiểm tra engine và Web export thành công.
- Bố cục cảm ứng được kiểm tra ở 844×390. Chưa kiểm chứng trên điện thoại vật lý hoặc chạy bản Web trong trình duyệt; các kết quả này không bảo đảm FPS thiết bị thật.
- Một lượt kiểm tra rộng hơn phát hiện 3 assertion kinh tế cũ trong `test_mobile_layout.gd` vẫn kỳ vọng vốn khởi đầu 1.000 thay vì cấu hình hiện tại 10.000. Không tính bộ fixture cũ đó vào 80 bài đạt ở trên.

### Chi phí CPU của commit 9 ô

P95, đơn vị ms; 30 mẫu sau warm-up cho mỗi renderer. Loại thời gian chuẩn bị, vẽ và animation. Đây là đo ngắn trên máy phát triển, không phải benchmark FPS điện thoại.

| Renderer | Cuốc | Tưới | Gieo |
|---|---:|---:|---:|
| compatibility | 2.348 | 2.480 | 3.962 |
| forward-plus | 2.062 | 2.838 | 3.768 |

Đã cache biên texture theo stage dùng chung của cây, tránh đọc ảnh GPU cho từng cây mới. Animation hiện là 0,75 giây: riêng 27 động tác cuốc/tưới/gieo cho 9 ô mất 20,25 giây ở cấp 1, so với 3 động tác mất 2,25 giây ở cấp 3. Đây chỉ là thời gian animation, chưa gồm di chuyển, tăng trưởng hay thu hoạch; không suy ra thu nhập tăng 9 lần.

## Chơi thử an toàn

Chạy F6 scene `tests/support/tool_upgrades_preview.tscn`: có vốn và đất thử, mở sẵn tab nâng cấp, không bind save cá nhân. Để dùng trong game chính, chạy lại game sau khi script được cập nhật. Kiểm chứng save dùng bản sao và xác minh hash file gốc không đổi.

Bằng chứng: [thư mục báo cáo](tool_upgrades_2026-10-25/), gồm ảnh giao diện, báo cáo native, log test, lint, engine và Web build.
