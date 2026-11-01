# Bàn giao hoàn thiện UI — 01/11/2026

Phạm vi: HUD và nền tảng dùng chung của P0, nâng cấp các luồng quản lý chính của P1 trong [hồ sơ thiết kế](ui_completion_dossier_2026-11-01.md). Giữ tài nguyên pixel đang có. Không tạo art bằng PixelLab và không tiêu lượt tạo ảnh.

## Thay đổi đã triển khai

| Nhóm | Kết quả |
|---|---|
| HUD | Thời gian/thời tiết trên trái; mục tiêu ngay bên dưới; tiền/cài đặt trên phải; thao tác tập trung ở hotbar |
| Mục tiêu | Thẻ có tên, tiến độ, thanh tiến trình, thông tin thưởng; nút Hiện/Ẩn thay dấu cộng/trừ; tooltip giữ mô tả đầy đủ |
| Hướng dẫn | Đặt dưới thẻ mục tiêu theo kích thước thật; giảm chiều cao theo khoảng trống ở màn hình thấp; không đè thẻ hoặc hotbar |
| Hotbar | Hiện tên vật phẩm/feedback và hướng dẫn phím theo InputMap; dock chọn giống cạnh túi đồ ở desktop rộng; bố cục gọn riêng khi cửa sổ hẹp/touch |
| Tiền | HUD rút gọn số triệu/tỷ; tooltip giữ số chính xác và dấu phân cách theo ngôn ngữ; túi chỉ rút gọn khi cửa sổ rất hẹp |
| Thông báo lưu | Một panel nhỏ bên phải, tự ẩn bằng Timer; không polling mỗi frame; thông báo thành công không che menu vừa mở; lỗi giữ thời gian đọc dài hơn |
| Debug | Ẩn khỏi HUD thông thường, bật/tắt bằng F3 trên debug desktop; không bị hiện lại khi đổi ngôn ngữ/thời tiết |
| Túi đồ | Tìm theo tên đã dịch, lọc loại, trạng thái không có kết quả; lọc không đổi vật phẩm/số lượng; khi di chuyển đồ tạm mở toàn bộ ô đích; gõ I/J/H/1 trong tìm kiếm không kích hoạt phím tắt menu/gameplay |
| Worker | Phân biệt đang có công việc/chờ/nghỉ, đếm trường hợp cần chú ý; nhãn đi tuần chuyển sang Nghỉ khi đã đến đích |
| NPC | Bubble căn tâm khung trên nhân vật, giới hạn trong màn hình có tính cả scale của hiệu ứng xuất hiện |
| Theme | Dùng chung khoảng cách, màu chữ, focus, tooltip, ô nhập, dropdown, popup, thanh trượt; giữ các skin riêng của màn hình |
| Co giãn | Bù scale cho cửa sổ nhỏ, không đổi camera zoom; thu gọn checkout rất thấp; lọc vật phẩm không ép panel tràn chiều ngang |
| Menu | Chuyển động mở 12 đơn vị/160 ms, đóng 120 ms; giữ khóa input và vòng đời giao dịch hiện có |
| Cài đặt | Nút ở góc phải; tiếng Việt/Anh, UI 100/125/150%, âm lượng Master; lưu riêng `user://ui_preferences.cfg`, debounce ghi khi kéo slider |

Menu cài đặt dùng cùng khóa modal với các menu giao dịch. Không mở đồng thời túi đồ/cửa hàng/cài đặt. Preview và benchmark dùng world con, không bind SaveManager vào hồ sơ người chơi.

## Kiểm tra

- Bộ UI chính: **100/100 test qua, 2.042 assertion**, 10 suite gồm HUD, inventory, mobile layout, small window, thời tiết, worker, objectives và cửa hàng. Kết quả cuối nằm trong [ui_completion_final_tests.log](ui_completion_final_tests.log).
- Gõ phím thật trong ô tìm kiếm được kiểm tra cùng modal Objectives/Help. Onboarding **6/6 test qua, 300 assertion**: [ui_completion_onboarding_checks.log](ui_completion_onboarding_checks.log). Tổng UI + onboarding: **106/106 test qua**. Kiểm tra timer hướng dẫn chờ đúng signal timeout và layout đã sắp xếp xong, thay vì giả định đủ thời gian sau một khoảng chờ ngắn.
- Các trường hợp mới: tiếng Việt/Anh, 1280/1920/2560, tìm kiếm không làm mất đồ, hoe thuộc bộ lọc Tool, lưu cài đặt vào file test riêng, khóa modal, popup ở hai mép và scale 0,85/1/1,06, thông báo lưu không chạy polling.
- Bố cục hiện hữu được kiểm tra thêm ở 500×281, 640×360 và các kích thước/density touch trong suite có sẵn. Các bài test thao tác chờ menu đóng đủ thời gian; kiểm tra feedback dùng đồng hồ thật vì deadline của ứng dụng dùng ticks, không dùng delta mô phỏng của headless.
- Fixture giao dịch mobile/small-window được cấp ngân sách riêng đủ mua hàng, thay vì phụ thuộc số tiền khởi đầu cũ của game.
- Kiểm tra mở rộng: 66 test ở 7 suite, 60 qua và 6 chưa qua; chi tiết bên dưới. Không coi toàn bộ dự án đã sạch lỗi.
- Lint sau cùng: [ui_completion_lint.json](ui_completion_lint.json).
- Đo thực tế Full HD, 20 giây, 64 cây và 15 worker thiếu vật tư: **120,97 FPS trung bình, frame time p95 12,41 ms**, cả 15 worker đều di chuyển; frame chậm nhất 211,43 ms. SaveManager không bind hồ sơ. Dữ liệu: [ui_completion_worker_benchmark.json](ui_completion_worker_benchmark.json).
- Đây là số đo sau thay đổi; không dùng làm khẳng định phần trăm cải thiện khi chưa có lượt đo trước/sau liền nhau trên cùng điều kiện máy. Các số đo cũ ở độ phân giải khác không phải baseline đối chứng trực tiếp.

## Những kiểm tra mở rộng chưa qua

Nguồn: [ui_completion_management_tests.log](ui_completion_management_tests.log).

1. `test_pen_upgrades.gd`: một fixture save cũ so sánh nguyên dictionary động vật trước/sau migration; dữ liệu đã được chuẩn hóa thêm trường trạng thái. Chưa chỉnh logic migration hoặc phép đối chiếu này trong đợt UI.
2. `test_farm_storage_world.gd`: bốn bài dùng các vị trí/vùng cửa kho cụ thể chưa mở được menu hoặc không khớp kiểm tra khoảng cách; một bài so sánh nguyên dữ liệu worker khi migrate v23 khác trường mặc định hiện tại. Một số lỗi tiếp theo là truy cập customer chưa được gán sau khi mở menu thất bại.

Các luồng kho ở `test_supply_storage_flow.gd` qua 11/11; đơn hàng 10/10, nấu ăn 5/5, ghép cây 5/5, vườn ong 20/20. Kết quả này không thay thế việc điều tra riêng 6 lỗi trên. Không đổi vị trí tòa nhà/vùng cửa hoặc schema save chỉ để làm bộ test mở rộng xanh.

## Ảnh review

- [HUD trước — tiếng Việt, 1920](ui_before_hud_vi_1920.png)
- [HUD sau — tiếng Việt, 1920](ui_after_hud_vi_1920.png)
- [HUD sau — tiếng Việt, 1280](ui_after_hud_vi_1280.png)
- [Trạng thái đủ điều kiện nhận thưởng](ui_after_objective_ready.png)
- [Túi đồ](ui_after_inventory.png)
- [Cửa hàng](ui_after_shop.png)
- [Worker](ui_after_worker.png)
- [Cài đặt](ui_after_settings.png)

Fixture tái tạo: `tests/support/ui_completion_preview.tscn`; tham số `-- before` chỉ đặt tên file đầu ra để ghi baseline tại thời điểm chạy. Nó không tự chuyển mã nguồn sang bản trước.

## Giới hạn phạm vi

Đã áp dụng nền tảng chung và cải thiện trực tiếp các màn hình chính; không vẽ lại riêng toàn bộ card của từng menu. Các trạng thái/giao dịch đã có được giữ và kiểm tra, không tạo thêm chức năng gameplay mới như mùa/lịch hoặc bản đồ tổng quan.

P2 trong hồ sơ — bộ bố cục mobile thiết kế lại riêng, gamepad đầy đủ, âm thanh UI mới, giảm chuyển động và dashboard/bản đồ mới — chưa triển khai. Bố cục touch hiện hữu vẫn được giữ tương thích và kiểm tra.

Chạy lại game để khởi tạo các Control/theme mới. F3 chỉ mở công cụ debug trong debug build desktop. Nút Cài đặt nằm cạnh tiền ở góc phải.

Các lỗi mở rộng cửa kho/save cũ ở trên còn cần xử lý riêng trước khi tuyên bố toàn bộ luồng quản lý đã được nghiệm thu hoàn toàn.
