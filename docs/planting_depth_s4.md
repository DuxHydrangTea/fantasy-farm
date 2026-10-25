# S4 — Vườn ong, công thức mật và giao diện

Đã triển khai ngày 25/10/2026, save v31. Thông số giá và hệ số là thử nghiệm, chờ cân bằng.

## Bố cục đã chốt

Giữ lưới 180 vị trí, gồm bốn khối 9×5. Chỉ khối trên trái dành cho combo:

- Tổ ở hàng 3, cột 2/5/8 (tọa độ code: `(1,2)`, `(4,2)`, `(7,2)`). Ba chậu tâm được ẩn và khóa để dành cho tổ.
- Mỗi tổ đọc đúng 8 chậu kề, tổng 24 chậu combo. Không kiểm tra bán kính với tổ combo.
- 18 chậu ngoài vòng combo trong khối này và toàn bộ 135 chậu của ba khối còn lại vẫn trồng tự do. Tổng 177 chậu có thể trồng + 3 tổ = 180 vị trí.
- Tổ giữa dùng miễn phí; mỗi tổ ngoài cần 15 gỗ Thường + 500 xu để sửa. Kho nông sản được trừ gỗ trước, sau đó mới đến túi. Tổ cũ được giữ lại luôn được coi là đã sửa.

## Cách chơi

Tới gần tổ, nhấn E, click hoặc chạm để mở **Sổ nuôi ong**. Không tự bung bảng khi đi ngang. Bảng dùng chung có cuộn, hỗ trợ màn hình ngang và dọc, cho xem tiến độ, thu trọn mẻ và sửa tổ.

| Công thức | Điều kiện hoa đã nở | Ưu tiên |
| --- | --- | --- |
| Mật Lai Hoa01–Hoa06 | Một cặp Hoa01 đối xứng và một cặp Hoa06 đối xứng qua tổ | 1 |
| Mật Lai Hoa02–Hoa07 | Một cặp Hoa02 đối xứng và một cặp Hoa07 đối xứng qua tổ | 2 |
| Mật Lai Hoa03–Hoa08 | Một cặp Hoa03 đối xứng và một cặp Hoa08 đối xứng qua tổ | 3 |
| Mật Hoa06 | Ít nhất 4 Hoa06 trong 8 chậu | 4 |
| Mật Hoa07 | Ít nhất 4 Hoa07 trong 8 chậu | 5 |
| Mật Tạp | Chưa khớp công thức nào | Cuối |

Đối xứng gồm trái–phải, trên–dưới hoặc hai đường chéo. Hoa chưa được tưới/chưa nở không được tính. Công thức lai được kiểm tra trước đơn hoa; nếu khớp nhiều công thức thì lấy thứ tự cố định trong bảng.

Loại mật được khóa ở lần tích tiến độ đầu tiên của mẻ. Hái hoặc thay hoa sau đó không đổi loại mật và không xóa tiến độ. Tốc độ vẫn đọc hoa hiện tại: hoa hiếm đang nở cho nhịp 2×, hết hoa hoặc trời mưa dùng nhịp cơ bản. Gió tăng thêm 25% tốc độ cho tổ vườn. Tổ ngoài ruộng giữ luật mật, bán kính, buff cây trồng và bán kính gió +50% như trước. Mỗi tổ chỉ giữ một mẻ tối đa 100 hũ; mẻ legacy giữ quy tắc cũ tới khi thu.

Sổ hiển thị cả năm công thức ngay từ đầu. Hình hũ là bóng đen cho tới khi người chơi **nấu xong và nhận món** tương ứng tại Chef. Có năm món kem trứng mới: mỗi món dùng 1 hũ mật tương ứng + 1 Sữa Bò Thường, nấu 4 giờ. Mật Tạp không có món mở hình riêng.

Giá thử nghiệm: Mật Tạp 150 xu, mật đơn 400 xu, mật lai 500 xu; kem trứng đơn 672 xu, kem trứng lai 812 xu (1,4× tổng giá nguyên liệu). Các SKU mật và món mới đã có trong bảng bán nông sản và catalog save.

## Save cũ và chuyển đổi bố cục

v30 → v31 chỉ bổ sung trường dữ liệu, giữ nguyên các mẻ cũ. Chuyển bố cục chạy sau khi hồ sơ tải xong và vườn được mở khóa:

1. Suy ra tổ cần dời/hoàn trả từ vị trí trong khu vườn **trước mọi catch-up offline**. Tổ trống chờ chuyển đổi không bắt đầu mẻ; mẻ đã chạy vẫn tiếp tục và cho thu bình thường. Tổ ruộng tiếp tục sản xuất.
2. Tính toàn bộ phương án: hoa ở ba tâm được dời tới chậu Tự Do trống gần nhất, giữ loài và tất cả timestamp/tiến độ. Giữ tối đa ba tổ cũ; tổ dư được hoàn trả thành item vào túi.
3. Nếu còn mẻ chạy/chờ thu, thiếu chậu Tự Do hoặc thiếu chỗ túi: giữ bố cục cũ, hiện điều kiện còn thiếu tại vườn và trong sổ ong. Tự kiểm tra lại mỗi 0,5 giây và sau lần tải tiếp theo.
4. Chỉ áp dụng sau khi đủ mọi điều kiện, khóa giao dịch xuyên suốt và đánh dấu đã chuyển. Save/load tiếp theo không nhân đôi tổ hoặc hoàn trả lần nữa.

Bản save lưu công thức mẻ, trạng thái sửa tổ, trạng thái chuyển đổi và các hũ đã mở hình. Preflight kiểm tra đúng ba tâm tổ, không chồng hoa và không nhận Recipe ID lạ. Save chờ chuyển đổi vẫn tải được nếu tổ cũ chồng vị trí chậu; công trình/vật cản khác vẫn được kiểm tra.

## Kiểm chứng

- Regression trước các guard cuối: **250/250 tests, 7.698 assertions, 29 scripts** — `.godot/s4-regression-engine.log`.
- Sau bổ sung guard và tương thích vị trí legacy: **38/38 tests** (19 S4 + 19 ong ruộng), 1.794 assertions — `.godot/s4-last-tests-engine.log`.
- Persistence và giao dịch sau guard: **39/39 tests**, 522 assertions — `.godot/s4-final-focused-engine.log`.
- Native UI chuột/chạm: **29/29 checks trên mỗi renderer** Compatibility và Forward+, gồm E mở bảng, 100 hũ/mẻ, sửa tổ đúng chi phí, silhouette → nấu → hiện hũ, lưu/tải và màn hình 1280×720, 720×960, 844×390. Báo cáo: `.godot/honey-native-final/{compatibility,forward-plus}/report.json`.
- Lint: 0 lỗi, 0 cảnh báo trong `.godot/s4-final-lint.json`. Build Web: `.dist/build-report.json`.

Các bài kiểm thử dùng project staging và hồ sơ QA riêng; không chỉnh save cá nhân. Đây là kiểm thử sự kiện touch trong ứng dụng native, chưa thay thế chạy trên thiết bị Android/iOS thật. Các cảnh báo UID cũ dùng đường dẫn thay thế vẫn là baseline của dự án.

Mã chính: `scripts/honey_combo_catalog.gd`, `components/bees/honey_garden_system.gd`, `components/bees/honey_menu.gd`. Bộ test mới: `tests/integration/test_honey_garden.gd`; native runner: `scripts/run_honey_qa.py`.
