# Nâng sức chứa chuồng bằng coins

Đã triển khai 26/10/2026. Mỗi chuồng bắt đầu 5 chỗ, nâng riêng qua 10/15/20/25/30. Chỉ dùng coins, hiệu lực ngay. Bảng quản lý chuồng hiện giá, sức chứa tiếp theo, thiếu tiền, đang xử lý và đã tối đa. Nút mua chặn bấm đôi 500ms. Slot dùng chung cho con non/trưởng thành và các loài thuộc chuồng đó.

## Dữ liệu và giao dịch

- `resources/animals/pen_upgrades.tres`: ánh xạ persistent_id chuồng gà/gia súc/ao vịt và năm giá mỗi loại; giá đúng bảng kế hoạch.
- `scripts/pen_upgrade_catalog.gd`: resource giá và kiểm tra cấu hình.
- `components/animals/upgrades/pen_upgrade_state.gd`: tiến độ 1–6, capture/restore/validation/migration.
- `components/animals/upgrades/pen_upgrade_service.gd`: kiểm tra quyền mua, báo giá cũ, khóa giao dịch, rollback tiền khi commit thất bại; commit tiền/mức/sức chứa trước khi phát tín hiệu.
- FarmWorld khởi tạo service khi runtime ready; chỉ ba persistent_id được quản lý nhận sức chứa từ state. Pen thử nghiệm/khác giữ capacity cấu hình riêng.
- GameSaveManager khóa lưu giữa transaction, yêu cầu lưu sau nâng và quản lý readiness. IO lỗi dùng thông báo/thử lại hiện có; không trừ tiền lần hai khi thử lưu lại.
- Mua vật nuôi đọc cùng effective capacity. Thông báo đầy chuồng có hướng dẫn mở bảng quản lý; thiếu chỗ đứng vẫn báo riêng.

## Save

Schema v34 bổ sung `pen_upgrades`. Save v33 trở về trước được migrate: ceil(số con / 5), tối thiểu mức 1 và tối đa mức 6. Không trừ coins khi migrate. Nếu vượt 30 con, giữ toàn bộ ở mức 6, chặn mua thêm. Tiến độ đã lưu không bị tính lại sau khi bán con. Capture, preflight, restore và kiểm tra dữ liệu đều đã nối.

Không thay save thật trong quá trình triển khai/QA. `legacy_profile.json` là bản sao chỉ dùng kiểm tra tương thích; không được ghi đè save người chơi từ fixture này.

## Kiểm tra

- Godot 4.7.2 + GUT: 37/37 test, 1244 assertions đạt (`tests.log`). Bao gồm 9 test tính năng mới, unit pen, save repository, trough compatibility.
- Kiểm tra giá/mức độc lập, thiếu tiền, tối đa, báo giá cũ, reentry, rollback, tăng sức chứa cho phép mua con thứ 6, chặn không gian bị vật cản, migration 0/5/6/29/30/31/36 con, giữ 36 con khi load, save/retry IO, và khôi phục bản sao profile hiện tại giữ tiền/đàn/cây lâu năm.
- Native OpenGL UI trên profile tạm: 34 kiểm tra đạt, không lỗi (`ui-verification.json`). Mouse/touch, double-click, thiếu coins, đạt max, bố cục 1280×720, 844×390, 390×844, tiếng Việt/Anh. Kiểm tra với physics map hoạt động: cả 7 loài tìm đủ 30 vị trí nhận con ở chuồng tương ứng.
- Ảnh: coop-before.png, coop-after.png, barn-insufficient.png, pond-max-mobile.png, coop-portrait-en.png.
- Lint toàn dự án: 0 lỗi; cùng 11 warning đường dẫn ảnh QA đã có trước, không phát sinh warning mới. Native import cũng có UID fallback warnings từ các scene cũ.
- Hai suite cũ animal_trade_service + pen_dashboard có tổng 5 lỗi: 4 test mua bán dùng giá/tiền cũ, 1 test resolver bảng ao vịt. Baseline dùng nguyên file mua bán và dashboard từ HEAD vẫn lỗi tương tự, 7/12 test đạt (`legacy-baseline.log`). Không sửa cân bằng cũ hoặc vị trí bảng ao trong tính năng này.

Lệnh test: `XDG_DATA_HOME=/tmp/codex-pen-validation python3 tests/run_tree_tests.py --godot /path/to/godot --suite tests/integration/test_pen_upgrades.gd --suite tests/integration/test_trough_save_compatibility.gd --suite tests/unit/test_save_repository.gd --suite tests/unit/test_animal_pen.gd`.
