# Kế hoạch cải thiện code sau rà soát

## Mục tiêu và phạm vi

Khôi phục QA nhân công, đánh giá và xử lý có căn cứ các rủi ro hiệu năng của nhân công và focus cây, đồng thời đánh giá khả năng bảo trì luồng restore. Phạm vi dựa trên 5 điểm của lượt rà soát trước; không triển khai vườn nấm, thay đổi cân bằng hoặc chỉnh save thật. Đây là kế hoạch; chưa có task implementation nào được thực hiện.

## Bằng chứng và giới hạn

- `tests/support/workers_probe.gd:136` có thụt lề dư; `scripts/run_workers_qa.py` chạy scene chứa script này, trên staging tách biệt save.
- `WorkerService.advance` mô phỏng theo sự kiện; `WorkerWorldBridge.candidates` quét đối tượng. Test 48 giờ so sánh kết quả từng giờ đã có trong `tests/integration/test_workers.gd`. Chưa có phép đo quy mô lớn xác nhận giật/lag.
- `ContextBarsComponent.refresh_at` kiểm tra hover mặc định mỗi 0,05 giây; `_hovered_target` quét cây lâu năm và chậu, nhưng chỉ xét ô gần chuột cho cây nông sản. Chưa benchmark thực tế.
- `WorldStateAdapter.restore` được `SaveManager.load_game` gọi; restore preflight rồi thay đổi nhiều hệ thống theo thứ tự có chủ ý. Chưa có bằng chứng cần refactor ngay. `LocalSaveRepository` đã có checksum, backup và kiểm tra revision.
- `PlantFocusEffect._sync` chạy khi focus và sao chép texture, thuộc tính sprite, tham số shader; chưa đo chi phí hoặc kiểm tra hình ảnh runtime trong lượt trước.
- Graph generation `2026-10-28T01:29:14Z`; các file code có coverage không ghi nhận lỗi, là tín hiệu best-effort. `tests/support/workers_probe.tscn` không được graph theo dõi; đã đối chiếu tham chiếu trong source. Các thay đổi focus hiện đang chưa commit: phải giữ nguyên và phối hợp theo mã thực tế.
- Shell chưa tìm thấy `godot`/`godot4`; công cụ editor đã kết nối nhưng kiểm tra script tạm của `PerennialTree` có báo sai khác kiểu cần xác minh độc lập. Chưa chạy GUT, QA native, benchmark hay xem UI cho kế hoạch này. Cần đường dẫn Godot khả dụng và renderer native cho kiểm tra tương ứng; không dùng save cá nhân.

## Contract và ràng buộc chung

- Không thay đổi schema, version, migration, checksum, revision, chính sách backup hoặc format save trong các task này. Tải save cũ, thứ tự và signal khi restore phải giữ nguyên.
- Mô phỏng một lần và từng bước phải cho cùng trạng thái nhân công, tiền lương, kho, cây và công việc dở dang; không giới hạn thời gian offline bằng cách bỏ sự kiện.
- Focus tiếp tục xử lý đồng thời tối đa mục tiêu trước mặt và mục tiêu hover khác; giữ ưu tiên hiện có, hit-test theo sprite và transform camera, ẩn khi mở menu hoặc chuột ngoài viewport. Cây nông sản, hoa, cây ăn quả và cây gỗ vẫn rung và sáng; vật lý và tài nguyên gốc không bị thay đổi.
- Benchmark dùng world/fixture riêng, không ghi vào `user://` của game cá nhân. Ghi thiết bị, renderer, số đối tượng, số nhân công, khoảng offline, thời gian và kết quả đúng/sai; không đặt ngưỡng hiệu năng tùy tiện trước khi có baseline và mục tiêu được thống nhất.
- Rủi ro hiệu năng là giả thuyết: nếu phép đo không cho thấy vấn đề có ý nghĩa thì ghi kết quả và không tối ưu chỉ vì code có vòng lặp.

## Task

### T01 — Khôi phục QA nhân công

- Trạng thái: TODO
- Phụ thuộc: Không.
- Người thực hiện: Terra Medium.
- Sửa: `tests/support/workers_probe.gd`, hàm `_run` tại dòng `_tap` thụt lề dư.
- Tạo mới: Không. Xóa: Không.
- Contract: giữ nguyên các bước, fixture, assertions, kịch bản 48 giờ và save cách ly; không thay kỳ vọng để qua test.
- Nghiệm thu: script parse được; QA touch, thu hoạch và báo cáo benchmark chạy hết; báo cáo không có failure.
- Kiểm tra: Godot kiểm tra cú pháp script thực và chạy `python scripts/build_web.py --godot <đường-dẫn-Godot>` (cần Web export template phù hợp), sau đó `python scripts/run_workers_qa.py --godot <đường-dẫn-Godot> --output <thư-mục-kết-quả>`; kiểm tra `run-summary.json`, log và báo cáo của cả hai renderer. Nếu thiếu renderer/binary, ghi BLOCKED và kết quả đã kiểm tra, không đánh DONE.
- Kết quả: Chưa thực hiện. Chưa xác minh: engine và renderer khả dụng.

### T02 — Đo mô phỏng nhân công và bảo vệ tính đúng

- Trạng thái: TODO
- Phụ thuộc: T01 cho benchmark native; test GUT độc lập có thể chạy trước.
- Người thực hiện: Sol phụ trách logic offline; Terra có thể hỗ trợ thiết lập benchmark theo contract.
- Sửa: `tests/integration/test_workers.gd` khi cần bổ sung kịch bản quy mô lớn và đối chiếu trạng thái; `tests/support/workers_probe.gd` nếu cần ghi thêm số liệu benchmark sau T01.
- Đọc, chưa sửa: `components/workers/worker_service.gd`, `components/workers/worker_world_bridge.gd`.
- Tạo mới: Không. Xóa: Không.
- Contract: so sánh một lần với các bước thời gian cho cùng dữ liệu đầu vào, gồm ít nhất thời gian 48 giờ hiện có và một kịch bản dài hơn; bao gồm kho đầy và công việc chưa hoàn tất. Không đo bằng save thật.
- Nghiệm thu: ghi baseline ở quy mô nhỏ và lớn với số cây/crop, worker, khoảng offline, thời gian và kết quả; đưa ra quyết định có cần tối ưu cùng bằng chứng. Không tự thay đổi scheduler trong task đo.
- Kiểm tra: chạy test `tests/integration/test_workers.gd` qua GUT và native QA T01; giữ lại báo cáo. Sai khác trạng thái là lỗi cần chẩn đoán trước khi tối ưu.
- Kết quả: Chưa thực hiện. Chưa xác minh: thời gian và mục tiêu thiết bị.

### T03 — Giới hạn tìm cây khi hover

- Trạng thái: TODO
- Phụ thuộc: Không; phối hợp với T04 vì cùng liên quan focus, thực hiện tuần tự nếu sửa cùng file.
- Người thực hiện: Terra Medium; Sol review phạm vi và kết quả.
- Sửa: `components/context_bars_component.gd`, `_hovered_target`; `tests/integration/test_context_bars.gd`.
- Đọc, chưa sửa: `components/trees/tree_plantation.gd` (`trees`, `point_for`, `cell_for`), `components/flowers/flower_garden.gd` (`pots`).
- Tạo mới: Không. Xóa: Không.
- Contract: input là điểm world; output là cây gần nhất theo quy tắc hiện tại hoặc null. Giữ hit-test tán cây vươn khỏi ô gốc, cây lệch hàng, transform/zoom, chậu, thứ tự chọn và xử lý menu; không thay đổi layout hoặc save.
- Nghiệm thu: đo số ứng viên/thời gian ở fixture nhỏ và lớn trước và sau. Chỉ thay đổi thuật toán nếu phép đo cho thấy lợi ích đáng kể và kết quả chọn tương đương; nếu không, báo baseline và không sửa code runtime.
- Kiểm tra: GUT `tests/integration/test_context_bars.gd` với biên tán, hai cây chồng gần nhau, cây/hoa và chuột ngoài viewport; so sánh kết quả với cách hiện hành trên dữ liệu fixture. Kiểm tra chuột runtime trên scene cách ly khi renderer khả dụng.
- Kết quả: Chưa thực hiện. Chưa xác minh: phạm vi tán lớn nhất và mức cải thiện đo được.

### T04 — Đánh giá chi phí và tính đúng của focus glow

- Trạng thái: TODO
- Phụ thuộc: T03 nếu cùng sửa `tests/integration/test_context_bars.gd`.
- Người thực hiện: Terra Medium.
- Sửa: `components/interaction/plant_focus_effect.gd`, `tests/integration/test_context_bars.gd` chỉ khi kết quả đo hoặc lỗi tái hiện chứng minh cần sửa.
- Đọc, chưa sửa: `components/context_bars_component.gd`, `shaders/plant_focus.gdshader`, `shaders/plant_wind.gdshader`.
- Tạo mới: Không. Xóa: Không.
- Contract: sáng ấm khoảng 0,14, fade 0,18 giây; lớp sáng theo sprite và shader gió khi cây đổi texture, kể cả gốc cây không có gió; không thay material gốc hoặc collision, không đổi feedback rung.
- Nghiệm thu: đo node/material và thời gian khi hover qua nhiều cây, kiểm tra phát sáng đúng theo gió và biến mất khi rời. Chỉ tối ưu khi có bằng chứng, không sửa shader hoặc hiệu ứng nếu chưa cần.
- Kiểm tra: GUT `tests/integration/test_context_bars.gd`; kiểm tra runtime các giai đoạn crop, hoa, cây ăn quả/gỗ, thay texture khi đang focus và khi xóa cây. Kiểm tra hiển thị bằng renderer native; báo rõ nếu không xem được.
- Kết quả: Chưa thực hiện. Chưa xác minh: chi phí thực tế và hiển thị runtime.

### T05 — Thiết kế bước tách restore an toàn

- Trạng thái: TODO
- Phụ thuộc: T01; T02 nếu kết quả liên quan worker catch-up.
- Người thực hiện: Sol. Chỉ khảo sát và cập nhật kế hoạch, chưa refactor save/load trong task này.
- Sửa: `PLAN.md` để ghi thứ tự restore, test còn thiếu và quyết định bước tách cụ thể nếu cần.
- Đọc, chưa sửa: `persistence/world_state_adapter.gd` (`preflight`, `restore`), `persistence/save_manager.gd` (`load_game`), `persistence/local_save_repository.gd`, `persistence/save_schema.gd`, `tests/integration/test_world_persistence.gd`, `tests/integration/test_workers.gd`.
- Tạo mới: Không. Xóa: Không.
- Contract: input snapshot hợp lệ và `now`; output/kiểu lỗi, thứ tự reset/restore, signal, thời gian mô phỏng và xử lý lỗi phải được ghi nhận trước khi sửa. Không thay migration hoặc file save.
- Nghiệm thu: liệt kê thứ tự và phụ thuộc đã xác minh, tests hiện có và khoảng trống; chỉ thêm task implementation có ID, file, contract và test cụ thể khi xác định được bước tách có lợi và an toàn.
- Kiểm tra: chạy các test save/restore liên quan trên profile fixture cách ly, gồm save cũ, restore lặp và thất bại preflight; ghi hạn chế. Không khẳng định atomic rollback nếu chưa kiểm chứng.
- Kết quả: Chưa thực hiện. Chưa xác minh: toàn bộ các phụ thuộc/signal và khả năng rollback.

## Review cuối

- Sol xem diff thực tế, trạng thái từng task, bằng chứng benchmark trước/sau và các kịch bản lỗi, không chỉ test xanh.
- Kiểm tra focus và hiệu ứng hoạt động trên tất cả loại cây, không đổi va chạm, khả năng chọn hoặc các thay đổi đang làm dở.
- Đối chiếu snapshot, inventory, thời gian và signal sau offline/restore; kiểm tra save cũ, save hỏng và backup nếu có thay đổi thuộc luồng save.
- Báo đúng các test, renderer/thiết bị chưa chạy; không đánh DONE khi nghiệm thu bắt buộc chưa đạt.
