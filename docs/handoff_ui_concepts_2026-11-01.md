# Bàn giao phiên — Fantasy Farm UI và concept

Ngày 01/11/2026. Repo: `C:/projects/fantasy-farm`. Ngôn ngữ trao đổi: tiếng Việt.

Handoff ai-memory: `01a196cc-56d4-71f2-8f5e-7db5ac102b57`, workspace `default`, project `duxhydrangtea-fantasy-farm`. Bàn giao dành cho phiên kế tiếp; file này vẫn đọc được nếu agent mới không có kết nối memory.

## Điểm dừng và ý muốn mới nhất

Người dùng yêu cầu lưu/cập nhật phiên để chuyển sang agent khác. Công việc đang dừng ở **review concept UI**, chưa được yêu cầu triển khai concept mới vào game.

Người dùng không hài lòng việc lặp đi lặp lại cùng một asset khung, cũng không thích ảnh gen lớn rồi downscale thành pixel art. PixelLab đang queue ở gói free, nên hướng mới là **UI vẽ bằng code/vector, nền kem–nâu, điểm nhấn xanh lá, chữ sắc nét**, kết hợp thế giới và icon vật phẩm pixel hiện có. Mỗi thành phần có hình thức phù hợp chức năng, không ép nút/bảng nhiệm vụ/hotbar dùng một khung giống hệt.

Đã dựng hai concept tương tác:

- **Đồng quê ấm áp**: đồng hồ dạng capsule, thẻ nhiệm vụ riêng bên trái, tiền và nút cài đặt tròn bên phải, hotbar nổi giữa phía dưới. Assistant nghiêng về hướng này.
- **Gọn nhẹ**: thời gian/nhiệm vụ/tiền/cài đặt gom lên thanh trên; nhiệm vụ mặc định thu gọn; hotbar ở góc dưới trái.

Người dùng đã chuyển carousel về **Đồng quê ấm áp** trong UI. Đây chỉ là trạng thái xem, **chưa phải lời xác nhận chọn hoặc cho triển khai**. Không tự suy ra đã được chốt thiết kế.

## Concept: file và cách xem

Đã đặt bản sao trong repo để agent/profile khác không phụ thuộc thư mục riêng của chat:

- `docs/concepts/fantasy-farm-ui-concepts.html`: fragment gốc, tự chứa ảnh nền và sprite icon dưới dạng data URI, dưới 1 MB.
- `docs/concepts/fantasy-farm-ui-concepts-preview.html`: bản preview standalone đã có runtime cho carousel và icon; có thể mở trong browser.
- `docs/ui_concept_cozy.png`, `docs/ui_concept_minimal.png`, `docs/ui_concept_settings.png`: ảnh review.
- `docs/ui_concept_background.jpg`, `docs/ui_concept_icons.json`: ảnh nền chụp trực tiếp từ Godot và icon đọc từ resource game.

Bản inline gốc ở `C:/Users/faker/.codex/visualizations/2026/11/01/01a194b5-3869-7ab1-ba49-0cc36b54eb89/fantasy-farm-ui-concepts.html`.

Concept vẽ bằng HTML/CSS, không phải ảnh AI gen rồi thu nhỏ. Nền được chụp từ world thật với HUD ẩn; icon lấy nguyên từ resource có sẵn. Không gọi PixelLab, không tiêu lượt tạo ảnh. Concept chỉ mô phỏng thao tác chọn vật phẩm, mở túi/kho giống/cài đặt, chỉnh phản hồi âm lượng và nhận thưởng một lần; không ghi dữ liệu nông trại và không phải UI production.

Đã kiểm tra bằng Playwright + Chrome headless: không lỗi JS, icon khởi tạo, chọn vật phẩm từ hotbar/túi cập nhật nhãn, slider cập nhật số, không nhận thưởng hai lần, nhiệm vụ bản Gọn nhẹ mở/đóng được, không tràn ngang ở các viewport 1100/736/375/320. Script QA nằm ở thư mục `qa` cạnh bản inline gốc; package QA không cài vào repo game.

Nếu sửa inline: đọc skill `visualize` đầy đủ trước. Skill có contract riêng cho fragment, carousel, Tweak và directive hiển thị. Có thể dùng bản trong repo để triển khai Godot mà không cần giữ cấu trúc HTML.

## UI production đã thay đổi trước khi dựng concept

Xem `docs/ui_completion_dossier_2026-11-01.md` (23 mục P0–P2) và `docs/ui_completion_implementation_2026-11-01.md` (kết quả, ảnh, giới hạn).

- Quy hoạch lại HUD; thẻ nhiệm vụ có tiến độ/thưởng/Hiện–Ẩn; hướng dẫn nằm dưới thẻ và tự giảm chiều cao ở màn hình thấp.
- Hotbar hiện tên vật phẩm/feedback và phím theo InputMap; chọn giống dock cạnh túi ở desktop rộng, có bố cục hẹp/touch.
- HUD tiền rút gọn số lớn nhưng tooltip giữ số chính xác; thông báo lưu nhỏ bên phải, Timer tự ẩn, thành công không che menu.
- Debug HUD ẩn mặc định, F3 bật trong debug desktop.
- Túi có tìm kiếm theo tên đã dịch, lọc loại, trạng thái không tìm thấy. Hoe thuộc nhóm Tool. Lọc chỉ ảnh hưởng trình bày, không đổi/chuyển/tiêu đồ; lúc di chuyển mở lại các ô đích.
- Đã xử lý xung đột nhập liệu: gõ I/J/H/1 trong search không đóng túi hay bị Objectives/Help nuốt phím. Escape/Tab vẫn theo luồng menu hiện hữu.
- Menu cài đặt tiếng Việt/Anh, UI 100/125/150%, âm lượng Master, lưu riêng `user://ui_preferences.cfg`, debounce ghi slider. Khóa modal dùng chung với túi/cửa hàng.
- UI scale hỗ trợ cửa sổ nhỏ, không đổi camera zoom; checkout rất thấp có chế độ gọn. Menu mở/đóng bằng dịch chuyển ngắn 12 đơn vị thay vì trượt cả màn hình.
- Worker summary phân biệt có việc/chờ/nghỉ và cần chú ý. Caption patrol hiển thị Nghỉ khi đã đến đích; không thay scheduler.
- Bubble NPC đã căn tâm cả khung trên nhân vật, căn chữ và clamp cạnh màn hình có tính scale animation.
- Sau phản hồi gần nhất về asset: `ObjectiveUI.root` và `WalletHUD.root` dùng `cozy_hud/inventory_theme.tres`; bỏ theme riêng trên `hud_card` để thừa kế. Sửa cả board nhiệm vụ và nút Cài đặt đang rơi về theme cũ. Đây vẫn là UI pixel hiện tại, chưa phải concept mượt mới.

Các file trọng tâm:

`components/farm_ui.gd`, `farm_settings.gd`, `farm_player.gd`, `ui_scale_component.gd`, `inventory_ui.gd`, `hotbar_ui.gd`, `wallet_hud.gd`, `language_settings.gd`, `modal_slide.gd`, `shop_ui.gd`, `shop_merchant.gd`; `components/objectives/objective_ui.gd`; `components/onboarding/help_ui.gd`, `tutorial_hints.gd`; `components/storage/farm_seed_picker.gd`; `components/weather/weather_hud.gd`; `components/workers/worker_role.gd`, `worker_board.gd`, `worker_menu.gd`; `persistence/world_persistence.gd`; `localization/en.po`, `vi.po`.

## Kiểm chứng và lỗi đang mở

- Bộ UI chính **100/100**, 2.042 assertion: `docs/ui_completion_final_tests.log`.
- Onboarding **6/6**, 300 assertion: `docs/ui_completion_onboarding_checks.log`.
- Sau sửa asset board/cài đặt: **18/18**, 584 assertion: `docs/ui_asset_consistency_tests.log`.
- Lint UI và concept gần nhất đều không lỗi/cảnh báo: `docs/ui_asset_consistency_lint.json`, `docs/ui_concept_lint.json`.
- Đo sau thay đổi ở Full HD, 20 giây, 64 cây và 15 worker thiếu vật tư: **120,97 FPS**, p95 **12,41 ms**, worst **211,43 ms**, cả 15 worker di chuyển. `docs/ui_completion_worker_benchmark.json`, `save_bound:false`. Không khẳng định phần trăm cải thiện vì thiếu baseline trước/sau cùng điều kiện; số đo cũ có độ phân giải khác.

Kiểm tra mở rộng **60/66 qua, 6 chưa qua** trong `docs/ui_completion_management_tests.log`:

1. `test_pen_upgrades.gd`: 1 ca đối chiếu nguyên dữ liệu động vật của fixture save cũ sau migration.
2. `test_farm_storage_world.gd`: 4 ca về vị trí/vùng cửa kho và menu không mở ở các tọa độ test; lỗi tiếp theo có customer null do open thất bại. 1 ca so sánh worker data v23 khác mặc định hiện tại.

Không coi toàn bộ repo sạch lỗi, không âm thầm sửa vị trí building/schema chỉ để làm test xanh. `test_supply_storage_flow.gd` 11/11 qua; orders 10/10; cooking UI 5/5; graft UI 5/5; honey garden 20/20. P2 (thiết kế mobile mới riêng, gamepad đầy đủ, âm thanh UI mới, giảm motion, dashboard/map mới) chưa triển khai.

## Bối cảnh công việc game trước đó

- Đã điều tra/giảm chi phí 15 worker, thêm bounded navigation/cache/budget. Các báo cáo ở `docs/worker_investigation_2026-11-01.md`, `worker_optimization_2026-11-01.md`, `worker_p0_p1_2026-11-01.md`.
- Đã thêm thuốc diệt cỏ bán trong shop, chữa sâu/cỏ cho cây, worker chăm bệnh vật nuôi; dùng kho vật tư, ưu tiên việc, thông báo thiếu thuốc và hiệu ứng chăm sóc.
- Động vật focus về Idle; chữa bệnh có hiệu ứng và bubble “Khoẻ quá!”; cây chữa xong có icon cỏ/sâu bay lên mờ dần. Bubble NPC sau đó đổi sang cùng họ khung động vật, rồi sửa căn giữa/clamp.
- Badge worker ngoài world đã rút còn số và icon việc, chi tiết khi focus/menu.
- **Patrol chưa sửa sâu**: scheduler còn có thể giữ job gần 60 giây dù đã tới đích; sampler reseed theo id + vị trí nên đứng một chỗ có thể thử lại đúng hai điểm bị chặn. Đã giải thích nguyên nhân; trong đợt UI chỉ làm caption đúng trạng thái, không tuyên bố đã sửa việc đi dạo.

## Cách tiếp tục và lưu ý worktree

1. Đọc hồ sơ và ảnh concept trước. Giữ điểm dừng ở review; làm tiếp theo yêu cầu mới của người dùng. Nếu họ yêu cầu triển khai concept, dùng component code/vector có các biến thể theo chức năng và giữ sprite vật phẩm gốc.
2. Không đưa UI cũ đồng nhất một asset vào concept mới. Không tạo ảnh lớn rồi downscale để giả pixel, không phụ thuộc PixelLab cho hình học UI cơ bản.
3. Worktree có rất nhiều thay đổi từ trước và từ công việc khác, chưa tạo commit trong phần UI này. Không reset/clean/revert hàng loạt. Có sửa cây gỗ 64×80, `world/main_world.tscn`, ảnh `assets/Buildings/Extracted/VillageSet/produce_warehouse.png`, và các thay đổi health/worker cũ không thuộc concept. Snapshot tên file: `docs/handoff_ui_worktree_status_2026-11-01.txt`.
4. Đọc AGENTS.md/RTK và skill Godot khi sửa game. Không in khóa `.env`. Bản bàn giao này không chứa nội dung hướng dẫn cài ai-memory.

Tooling hiện có:

- Godot console: `C:/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe`.
- Python: `C:/Users/faker/AppData/Local/Python/pythoncore-3.14-64/python.exe`.
- GUT luôn dùng `-gconfig=` khi chỉ chạy suite chỉ định, nếu không config mặc định sẽ kéo thêm toàn bộ test.
- Lint: chạy `.agents/skills/godot/scripts/debug/lint_project.py . --pretty` bằng Python trên.
- Preview production UI: `tests/support/ui_completion_preview.tscn`. Tham số `concept_background` chỉ xuất nền và icon cho concept, không bind hồ sơ/save. Đổi `before` chỉ đổi tên file output, không tự revert mã nguồn.
- Benchmark: `tests/performance/worker_care_benchmark.tscn -- ui_review`; ghi riêng JSON/ảnh cho UI, không ghi đè báo cáo benchmark cũ.
