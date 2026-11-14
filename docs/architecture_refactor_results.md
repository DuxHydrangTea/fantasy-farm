# Kết quả refactor kiến trúc Fantasy Farm

## Sửa các vấn đề còn tồn tại — 13/11/2026

- Trace giao việc từ cùng checkpoint xác định lần lệch đầu tiên ở thông báo máng đúng lúc task tuần tra đến hạn. `request_scan()` từng xóa task trước khi scheduler ghi nhận vị trí đến nơi; lượng tiêu thụ làm tròn khác nhau rất nhỏ giữa các checkpoint khiến hai lượt đi theo hai nhánh. Giữ task đã đến hạn (cùng tolerance 10µs với scheduler) để hoàn tất việc đến trước khi nghỉ hoặc giao việc. Checkpoint đã tái hiện lỗi trước sửa đạt lại **14.809 assertion** sau sửa; log `%TEMP%/farm-replay-controlled.log`. Các cảnh báo Float/Int trong lượt này đến từ đọc checkpoint JSON cho công cụ chẩn đoán tạm; công cụ đã được gỡ khỏi source.
- Giữ task đến hạn chưa đủ để xử lý mọi bộ ID: một lượt ngẫu nhiên sau sửa vẫn lệch. Khi chuẩn bị sự kiện offline, service nay không biến thông báo đồng bộ trạng thái thành lệnh hủy tuần tra hoặc sửa wake; scheduler dùng các ranh giới đã lập lịch. Thay đổi gameplay bên ngoài bước đồng bộ vẫn yêu cầu quét như trước. Phạm vi này chỉ bao quanh `bridge.sync()` và xử lý pickup; các transaction thực thi task vẫn phát thông báo bình thường.
- Máng chỉ yêu cầu ngắt tuần tra khi vừa phát sinh nhu cầu tiếp (đồ ăn thiếu một đơn vị, nước thiếu một lần dùng), thay vì sau mọi biến động tồn kho. Trái cây còn dưới 10ms để chín vẫn giữ lần đánh thức tiếp theo, tránh bỏ qua sự kiện gần chín. Có test cho đồng bộ pickup offline so với lệnh gameplay bên ngoài, task đến hạn, ngưỡng máng và trái cây gần chín. Năm suite worker, optimization, warehouse, save repository và worker roles đạt **89/89**, **1.505 assertion**; log `%TEMP%/farm-sync-tests.log`.
- Bật hai stress lớn từng để pending phát hiện fixture cũ trồng trên ô bị overlay chặn: đất không được restore nhưng cây vẫn được tạo. Fixture nay chọn đủ **192 ô thực sự canh tác được** trong khu đất mở khóa, vẫn giữ đầy đủ kiểm tra schema/preflight và parity, cùng 153 cây lâu năm. Hai stress 48 giờ và 7 ngày đạt **2/2**, **60.933 assertion** trong `%TEMP%/farm-clean-stress.log`.
- Khôi phục tham chiếu ảnh của hai scene cửa hàng cũ bằng asset có sẵn, sửa cả script tạo scene để không tái tạo đường dẫn hỏng. Bỏ UID catalog cửa hàng thú đã lỗi thời. Hai scene load/chạy độc lập đạt, không có lỗi hoặc cảnh báo runtime (`%TEMP%/farm-clean-scenes-runtime.json`). Không cần loại hai scene khỏi Web export nữa.
- Benchmark dựng đường dẫn báo cáo từ thư mục và tên file, thể hiện đây là output được tạo khi chạy thay vì resource đầu vào bị thiếu. Lint toàn dự án hiện **0 lỗi, 0 cảnh báo, 0 lỗi cú pháp** (`%TEMP%/farm-final-clean-lint.json`). `git diff --check` đạt.
- Sau khi tách thông báo đồng bộ offline khỏi lệnh gameplay, chạy **3 lượt liên tiếp** ca 7 ngày với ID ngẫu nhiên: cả ba đạt, mỗi lượt **14.796 assertion**. Log `%TEMP%/farm-boundary-replay-1.log` đến `-3.log`. Không cố định ID hoặc nới tolerance trong test hiện tại.
- Smoke nông trại 180 frame trên source cuối không có lỗi/cảnh báo runtime (`%TEMP%/farm-final-smoke.log`). Export Web release cuối đạt `ok: true`, không lỗi export (`%TEMP%/farm-complete-web.log`); artifact và báo cáo ở `.dist/architecture-refactor/`.
- Chạy toàn bộ suite offline trên source cuối với `FARM_OFFLINE_STRESS=all`: **7/7 đạt**, không còn ca pending. Lượt trực tiếp đạt **93.945 assertion** nhưng có cảnh báo giải phóng 2 object/1 resource lúc thoát (`%TEMP%/farm-offline-complete.log`). Chạy lại toàn bộ với `--verbose` trong staging Web đã tắt editor/MCP, dữ liệu người dùng tạm: **7/7 đạt**, **93.919 assertion**, engine thoát sạch, không có lỗi hoặc cảnh báo (`%TEMP%/farm-isolated-final.log`). Không tái hiện cảnh báo thoát khi chạy riêng các ca bằng verbose; chưa quy kết nguyên nhân cụ thể cho plugin nào.
- Kết quả chốt: **96/96 test liên quan đạt** (89 worker/save và 7 offline, gồm cả hai stress lớn), ba lượt 7 ngày ngẫu nhiên bổ sung đạt, lint sạch, smoke và Web release đạt. Phạm vi refactor cùng các vấn đề replay/tài nguyên/lint đã nêu đã hoàn tất. Các số liệu lỗi ở các mục bên dưới là lịch sử của những lượt trước sửa.

## Kiểm tra chốt độc lập — 13/11/2026

Mục này ghi kết quả trước vòng sửa ở trên; các lỗi replay và lint được mô tả dưới đây là lịch sử kiểm chứng.

- Đối chiếu lại diff với giai đoạn 0–6. Sửa một sai khác khi tách `_finish_due_task()`: `wake_at` phải chỉ cập nhật khi task đã hoàn tất, không cập nhật sau mỗi ô của task nhiều ô. Thêm `test_area_task_keeps_wake_checkpoint_until_last_cell` để kiểm tra checkpoint giữa batch và sau ô cuối.
- Godot 4.7.2 / GUT 9.7.1, dữ liệu người dùng trong thư mục tạm: năm suite worker, worker optimization, warehouse, worker roles và save repository đạt **85/85** sau sửa (worker 40, optimization 9, warehouse 10, roles 5, repository 21). Log: `%TEMP%/farm-workers-final.log` và `%TEMP%/farm-refactor-final-gut.log`. Lượt cuối dùng `--fixed-fps 60`.
- Suite offline đạt **4/7**, với **2 pending** stress lớn và **1 lỗi** ở `test_matrix_small_7_days`: lệch tuần tra và `fruit_work`, cùng loại sai lệch đã ghi nhận trước refactor ở giai đoạn 3. Cả hai ca 48 giờ đạt. Không nới tolerance hoặc bỏ assertion để làm xanh ca 7 ngày; vấn đề replay có sẵn này vẫn chưa được giải quyết trong đợt refactor.
- Lượt đối chiếu khởi chạy trước sửa đạt **89/91**, chỉ có 2 stress pending; ca 7 ngày đạt trong lượt này. Log: `%TEMP%/farm-refactor-close-gut.log`. Kết quả một lượt đạt, một lượt lỗi tiếp tục cho thấy tính thất thường đã ghi nhận ở giai đoạn 3; không coi đây là bằng chứng replay đã được sửa.
- Lint sau sửa: **0 lỗi cú pháp**, giữ nguyên **2 lỗi tài nguyên và 5 cảnh báo** của mốc ban đầu. Log: `%TEMP%/farm-refactor-final-lint.json`. Smoke scene `world/main_world.tscn` 180 frame đạt, không có lỗi runtime; còn cảnh báo UID cũ của `pet_merchant`. Log: `%TEMP%/farm-refactor-final-smoke.log`.
- Export lại Web release sau sửa bằng `scripts/build_web.py`: `ok: true`, không có lỗi export. Artifact tại `.dist/architecture-refactor/index.html`, báo cáo tại `.dist/architecture-refactor/build-report.json`; log `%TEMP%/farm-refactor-final-web.log`. `git diff --check` đạt. Phạm vi refactor giai đoạn 0–6 đã chốt, với các vấn đề có sẵn ghi rõ ở trên.


Theo dõi [kế hoạch](architecture_refactor_plan.md). Mỗi mục ghi trạng thái sau khi đối chiếu mã và chạy kiểm thử. Mốc trước khi sửa lấy từ `main` tại `90d7d432` cùng bản sửa bố cục UI đang có trong workspace.

| Giai đoạn | Trạng thái |
|---|---|
| 0 — Đo trước khi sửa | Hoàn thành |
| 1 — Phụ thuộc của farming | Hoàn thành |
| 2 — Kết nối farming và worker | Hoàn thành |
| 3 — Lập lịch worker và save | Hoàn thành. Lỗi replay có sẵn đã được điều tra và sửa trong vòng kiểm chứng bổ sung ở đầu tài liệu |
| 4 — Tài liệu và kiểm tra tích hợp | Hoàn thành |
| 5 — Tách bộ lập lịch worker | Hoàn thành |
| 6 — Ranh giới giữa scheduler và service | Hoàn thành |

## Giai đoạn 0 — Mốc trước khi sửa

- Godot 4.7.2 stable, GUT 9.7.1, dữ liệu trong thư mục tạm. Lượt chính đạt **172/204 ca**, gồm farming rules 10/10, query cost 2/2, worker roles 5/5, save repository 21/21, farming 7/8, farming area 2/6, forestry 9/10, soil focus 8/13, weather 14/17, farm health 25/26, worker care 13/14, workers 40/40 và world persistence 16/32.
- 32 ca lỗi có sẵn gồm fixture ô đất và kỳ vọng theo bản đồ cũ, fixture animal/popup, cùng các kỳ vọng về dữ liệu khi tải. Lượt chính có log tại `%TEMP%/fantasy-farm-refactor-baseline.log`.
- Lint của skill Godot báo 2 lỗi đường dẫn tài nguyên và 5 cảnh báo, không có lỗi cú pháp. Trình kiểm tra scene của Gamedev báo 10 lỗi và 8 cảnh báo trên toàn repo. Dùng các mốc này để phát hiện lỗi mới trong phạm vi refactor.
- Lượt worker, warehouse và đối chiếu offline đạt **23/25 ca**, gồm hai ca stress lớn mặc định ở trạng thái pending. Các ca mô phỏng nhỏ 48 giờ và 7 ngày đạt. Log tại `%TEMP%/fantasy-farm-refactor-offline-baseline.log`.

### Chạy lại các suite

Từ thư mục dự án, đặt `godot` trên `PATH` trỏ tới Godot 4.7.2. Các lượt trước và sau dùng cùng lệnh, mỗi lượt có một thư mục dữ liệu thử nghiệm riêng.

```powershell
$env:APPDATA = Join-Path $env:TEMP ('fantasy-farm-refactor-' + [guid]::NewGuid())
$suites = @(
    'unit/test_farming_rules', 'unit/test_farming_query_cost', 'unit/test_worker_roles',
    'unit/test_save_repository', 'integration/test_farming', 'integration/test_farming_area',
    'integration/test_forestry', 'integration/test_soil_focus', 'integration/test_weather',
    'integration/test_farm_health_world', 'integration/test_worker_care_improvements',
    'integration/test_workers', 'integration/test_world_persistence'
)
$testArgument = '-gtest=' + (($suites | ForEach-Object { "res://tests/$_.gd" }) -join ',')
godot --headless --path . -s addons/gut/gut_cmdln.gd '-gconfig=' $testArgument -gexit -glog=1 -gdisable_colors
godot --headless --path . -s addons/gut/gut_cmdln.gd '-gconfig=' '-gtest=res://tests/integration/test_storage_offline_parity.gd,res://tests/integration/test_worker_optimization.gd,res://tests/integration/test_worker_warehouse.gd' -gexit -glog=1 -gdisable_colors
```

## Giai đoạn 1 — Phụ thuộc của farming

- `FarmWorld` nối thao tác đồng bộ thời tiết và `TreePlantation` khi khởi tạo. `SoilFocusComponent` dùng truy vấn của farming để xác định mục tiêu cây.
- Đã đối chiếu luồng tưới đơn và tưới vùng. Mỗi luồng đồng bộ thời tiết tại điểm cũ và giữ điều kiện khóa thao tác. Luồng dụng cụ vẫn giới hạn việc đào cây cho người chơi, còn fixture không có world có thể chạy mà không cần các phụ thuộc tùy chọn.
- GUT đạt **52/66 ca** trên Godot 4.7.2. Tên của cả 14 ca lỗi trùng với mốc trước khi sửa trong cùng 7 suite. Hai ca lâm nghiệp kiểm tra đào gốc/cây non và quyền worker đều đạt. Lint có cùng 2 lỗi, 5 cảnh báo và 0 lỗi cú pháp. `git diff --check` đạt. Log tại `%TEMP%/fantasy-farm-refactor-phase1.log`.

## Giai đoạn 2 — Kết nối farming và worker

- Farming phát `crop_treated` tại vị trí trước đây gọi worker trực tiếp. Worker tự đăng ký nghe để yêu cầu quét lại. Bridge truyền điều kiện hiệu ứng cũ khi áp dụng thuốc, gồm cả trường hợp gọi trực tiếp ngoài vòng lập lịch.
- Đã đối chiếu thứ tự xóa trạng thái, thông báo cây, yêu cầu quét và thông báo hoàn thành. Vị trí giữ khóa kho, trừ thuốc, rollback và phát thông báo kho vẫn như trước.
- GUT đạt **45/48 ca**. Hai lỗi popup đã xuất hiện ở mốc ban đầu. Lỗi migration v6 trong suite booster cũng tái hiện trên bản sao mã gốc. Các ca worker xử lý cây và tiêu hao thuốc offline, hiệu ứng xử lý cây và hủy dùng thuốc đều đạt. Lint giữ 0 lỗi cú pháp và cùng các chẩn đoán cũ. Log tại `%TEMP%/fantasy-farm-refactor-phase2.log` và `%TEMP%/fantasy-farm-refactor-reference-recheck.log`.

## Giai đoạn 3 — Lập lịch worker và save

- Tách lọc và chọn ứng viên sang `_choose_task()`. Kiểm tra thứ tự giữ ô, giữ mục tiêu, chặn tạm thời, phạm vi và chọn theo độ ưu tiên. Nhánh hết ngân sách vẫn khôi phục đồng hồ và giữ điểm tiếp tục trước khi gọi hàm mới.
- `WorldStateAdapter` đi qua `WorkerService` cho xác thực mục tiêu trong save và đồng bộ sau restore. Kiểm tra vẫn dùng số lô đất trong save và giữ ngoại lệ của task tuần tra. Việc đồng bộ giữ cùng timestamp, chế độ offline mặc định và thứ tự so với cập nhật HUD. Schema vẫn là v41.
- Lượt GUT chính đạt **172/204**, đúng 32 tên ca lỗi ban đầu, và cùng **3.045/3.184** assertion đạt. Worker đạt 40/40, save repository 21/21. Log tại `%TEMP%/fantasy-farm-refactor-final.log`.
- Lượt offline đạt **22/25** với 2 ca stress pending. Ca 48 giờ, worker optimization và worker warehouse đạt. Ca 7 ngày lệch vị trí tuần tra và tiến độ cây ở cuối mô phỏng trong cả hai lượt sau refactor dùng ID ngẫu nhiên. Log tại `%TEMP%/fantasy-farm-refactor-offline-final.log` và `%TEMP%/fantasy-farm-refactor-offline-7d-recheck.log`.
- Worker tạo ID bằng `Crypto` và dùng ID trong seed tuần tra. Đã chạy lại ca 7 ngày với cùng bộ ID worker và vật nuôi trên mã gốc và mã sau refactor. Hai bản đều đạt **14.809 assertion**. Log tại `%TEMP%/fantasy-farm-refactor-controlled-0.log` và `%TEMP%/fantasy-farm-refactor-controlled-1.log`.
- Chạy thêm ba lượt dùng ID ngẫu nhiên trên bản sao mã gốc. Hai lượt đạt, một lượt tái hiện sai lệch vị trí, mục tiêu và thời điểm tuần tra cuối kỳ. Kết quả đối chiếu xác nhận ca 7 ngày có thể thất bại từ trước. Chưa xác định điều kiện mô phỏng cụ thể gây lệch. Log tại `%TEMP%/fantasy-farm-refactor-stock-replay-1.log` đến `-3.log`.

## Giai đoạn 4 — Tài liệu và kiểm tra tích hợp

- Bổ sung bản đồ luồng hiện tại trong [tài liệu runtime](runtime_system_reference.md), gồm nơi sở hữu dữ liệu, hướng gọi giữa các hệ thống và test tương ứng. Kiểm tra cả 16 liên kết nội bộ trong phần tài liệu thêm mới.
- Smoke test scene nông trại chạy 180 frame trên Godot 4.7.2, không có lỗi runtime. Có cảnh báo UID cửa hàng thú đã xuất hiện ở mốc ban đầu. Log tại `%TEMP%/fantasy-farm-refactor-smoke.log`.
- Kiểm tra bổ sung trên Godot 4.8 beta 3 đạt **25/25 ca**, gồm farming rules, query cost, worker roles và worker optimization. Log tại `%TEMP%/fantasy-farm-refactor-beta.log`.
- Kiểm tra tĩnh không phát sinh chẩn đoán ở file refactor. Lint và checker scene giữ số lỗi/cảnh báo ở mốc trước khi sửa. `git diff --check` đạt. Bản sửa bố cục UI có từ trước vẫn hiện diện trong workspace.

## Bản Web chạy thử

- Export release bằng Godot 4.7.2 đạt, báo cáo `.dist/architecture-refactor/build-report.json` ghi `ok: true` và không có lỗi export. Preset Web bỏ hai scene cửa hàng cũ trỏ đến ảnh đã bị xóa. Scene nông trại hiện dùng các cửa hàng trong `online_farm`.
- Thêm font dự phòng có sẵn trong repo cho môi trường Web thiếu font hệ thống. Chrome ở 1280×720 đã tạo hồ sơ thử, vào nông trại và mở túi đồ. Chữ tiếng Việt đọc được. Ký hiệu mặt trời còn hiện ô vuông và runtime có cảnh báo UID cũ ở máng thức ăn.
- GUT đạt **20/20** cho bản địa hóa, UI completion, worker roles và farming query cost. Server thử nghiệm phục vụ ở `http://127.0.0.1:8061/index.html`.

## Giai đoạn 5 — Tách bộ lập lịch worker

- `WorkerScheduler` giữ ngân sách mỗi frame và vị trí tiếp tục của sự kiện. Các bước tiến timeline, xử lý worker, hoàn tất việc và giao việc có phương thức riêng. `WorkerService` còn 623 dòng và tiếp tục cung cấp API gameplay và save hiện có.
- Đối chiếu thứ tự trả lương, kiểm tra công việc khẩn, hoàn tất task, giao việc và chuyển sang mốc thời gian kế tiếp. Các nhánh nhường frame giữ nguyên điểm tiếp tục. `advance()` khôi phục timestamp, khóa và deadline tại cùng một điểm sau mỗi lượt chạy.
- GUT trên Godot 4.7.2 đạt **84/84 trước và sau**. Nhóm kiểm tra gồm worker, worker optimization, warehouse, worker roles và save repository. Có ca đối chiếu offline 48 giờ, kiểm tra giữ chỗ và tiếp tục khi hết ngân sách, thời gian logic của thông báo pickup và lưu/tải tại ranh giới hoàn tất task. Log tại `%TEMP%/worker-scheduler-before.log` và `%TEMP%/worker-scheduler-after.log`.
- Scene nông trại chạy 180 frame headless. Lint có cùng 2 lỗi tài nguyên và 5 cảnh báo đã có, 0 lỗi cú pháp. `git diff --check` đạt.
- Export lại bản Web chứa `WorkerScheduler`. Chrome tải game, tạo nông trại và mở túi đồ ở 1280×720. Không có lỗi runtime trong lượt chạy, còn cảnh báo UID máng thức ăn đã ghi ở trên.

## Giai đoạn 6 — Ranh giới giữa scheduler và service

- `WorkerService.advance()` kiểm tra điều kiện chạy, giữ khóa và khôi phục timestamp cùng deadline. `WorkerScheduler` nhận đồng hồ và lịch thời tiết trực tiếp. Scheduler vẫn dùng service để đọc hồ sơ đội và gọi các thao tác gameplay.
- `prepare_simulation_event()` giữ thứ tự xử lý đồ từ save cũ, đồng bộ world, rồi xử lý pickup. Scheduler gọi `pay_daily_wage()` trước khi xét công việc của worker. Cách tiếp tục sau khi nhường frame và schema v41 giữ nguyên.
- Cùng 5 suite GUT trên Godot 4.7.2 đạt **84/84** trước và sau. Godot 4.8 beta 3 đạt **13/13** ở worker optimization và worker roles. Smoke test nông trại chạy 180 frame. Lint có cùng 2 lỗi tài nguyên và 5 cảnh báo cũ, 0 lỗi cú pháp. Log GUT tại `%TEMP%/worker-scheduler-phase6-before.log` và `%TEMP%/worker-scheduler-phase6-after.log`.
- Export Web release đạt. Chrome chạy bản mới, vào nông trại và mở túi đồ, với cảnh báo UID máng thức ăn đã ghi ở trên. Kiểm tra 18 liên kết tài liệu và `git diff --check` đều đạt.
