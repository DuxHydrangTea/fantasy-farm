# Tối ưu đội worker — 01/11/2026

Đã triển khai cả scheduler, chọn ô/giữ chỗ, cache tiếp cận máng, navigation chung và đi dạo gần. Không đổi schema save hoặc giảm giới hạn 15 worker. Kết quả render thật tái hiện được đứng hình của bản gốc và xác nhận đội worker tiếp tục làm việc sau tối ưu.

## Kết quả render thật trước/sau

Godot 4.7.2 standard, Windows, Forward+ / D3D12, NVIDIA GeForce RTX 3050 Ti Laptop GPU, cửa sổ 1280 × 720, VSync 1, `Engine.max_fps = 0`. Chạy tuần tự, cùng scene/asset/fixture và cùng harness. Mỗi ca nhắm 18 giây; world mới, 16 cột ruộng, 1.000 hạt giống và trạng thái chuồng mặc định. Không nạp profile đang chơi; cả hai JSON xác nhận `save_bound: false`.

| Kịch bản | FPS trước | FPS sau | Frame P95 trước / sau (ms) | Frame chậm nhất trước / sau (ms) |
|---|---:|---:|---:|---:|
| 0 worker | 142,36 | 142,51 | 8,80 / 8,76 | 166,56 / 165,89 |
| 15 worker, tự trồng | **0,20** | **141,86** | **16.798,55 / 10,18** | **16.798,55 / 182,24** |
| 15 worker, tắt tự trồng | 125,51 | 142,58 | 13,92 / 9,73 | 284,02 / 168,84 |

Bản gốc tự trồng chỉ trả được **5 frame** trong 24,78 giây vì main thread bị chặn, làm phép đo vượt mục tiêu 18 giây. Vì vậy 0,20 FPS/P95 là mô tả đúng lần tái hiện này, không phải một ước lượng FPS ổn định hoặc cam kết mức tăng cho mọi save. Các ca sau tối ưu có hơn 2.500 frame trong khoảng 18 giây. Đồng hồ thực giữa các `process_frame` là chỉ số chính; monitor `Performance` có thể còn mẫu từ lần khởi tạo/ca trước nên không dùng các monitor đó để suy ra thời gian từng hàm.

Trong ca 15 worker tự trồng sau sửa:

- Cả **15 worker** đều dịch chuyển hơn 16 px so với điểm xuất phát.
- **25 lần trồng cây**, **27 đường đi hoàn tất**, 0 đường thất bại và 0 đường còn đợi ở cuối phép đo.
- Một cache địa hình chung cho footprint hiện tại; không tạo 15 `AStarGrid2D` phủ toàn bản đồ.
- 1 frame >50 ms, so với mọi frame đều >50 ms ở lần tái hiện cũ. Vẫn có spike khởi tạo **182 ms**; ca 0 worker cũng có spike khoảng **166 ms**. Không tuyên bố đã xóa mọi giật khung hình.

Đây là fixture ngắn, chưa phải benchmark toàn bộ save thực tế, thiết bị yếu, Web/mobile hoặc mọi layout công trình. Các kiểm tra riêng về đi vòng qua tường và đi tới chuồng khác dùng không gian physics thật.

Đã chạy bổ sung ngay trong **project chính có MCP autoload**, không chỉ staging: 15 worker tự trồng đạt **140,40 FPS**, frame P95 **9,79 ms**, 18 cây được trồng và 26 đường hoàn tất trong 18 giây; cả 15 worker di chuyển. Ca tắt tự trồng đạt 142,13 FPS. Root probe cũng xác nhận `save_bound: false`. Dữ liệu: `worker_optimization_live_root_2026-11-01.json`.

## Những thay đổi đã triển khai

### Scheduler và giữ chỗ

- `WorkerService.advance()` chỉ gọi `ranch_candidates()` khi kiểm tra việc khẩn cấp để ngắt một công việc trồng hiện tại. Không quét cây/ruộng/pickup hoặc tìm ô trồng mới trong nhánh đó.
- Tạo snapshot giữ chỗ cell/station/pickup/vật tư từ records, rồi tra dictionary trong vòng quét ô. Snapshot được dựng tại ranh giới truy vấn nên không bị cũ sau restore, nghỉ, bị chặn hoặc đổi việc. Không còn tạo task dictionary và duyệt cả đội cho từng ô.
- Chỉ tìm ô trồng nếu không có việc ưu tiên cao hơn thực sự còn nhận được. Các máng đã được worker khác giữ chỗ bị loại trước khi tính điểm tiếp cận.
- `CropWorkerPolicy` cache tọa độ world của ô và chỉ giữ 16 ứng viên tốt nhất trong một lượt quét; không quét lại cả ruộng cho mỗi lần thử physics bị từ chối. Giữ thứ tự lịch sử trồng, ô chuẩn bị, khoảng cách và tie-break theo y/x.
- Scheduler online có ngân sách chung **2.000 µs mỗi process frame**. Lưu con trỏ row và con trỏ tìm ô để tiếp tục ở frame sau; không luôn bắt đầu lại từ worker đầu tiên. Quét ô kiểm tra deadline mỗi 16 ô và đảm bảo có tiến triển ngay với ngân sách thử nghiệm 1 µs.
- Save/command đồng bộ gọi `settle()` để hoàn tất sự kiện đang dở trước khi capture hoặc thay roster. Offline vẫn dùng timeline cũ, thứ tự thuê và cơ chế yield giữa các sự kiện; cursor tìm việc là trạng thái tạm, không thêm vào save.

Ngân sách là cơ chế cooperative, không phải cam kết hard realtime: một lời gọi engine/commit/sync không thể bị ngắt giữa chừng. Phần tìm ô và A* có bước tiếp tục nội bộ, thay vì chỉ giới hạn bên ngoài một sự kiện dài.

### Cache world và điểm tiếp cận

- Danh sách crop invalidates khi trồng/thu hoạch/restore; không xóa sau mỗi sync. Có kiểm tra crop đã biến mất và TTL dự phòng cho nguồn dữ liệu thay đổi ngoài service.
- Nhu cầu chuồng trại và deadline đánh thức được dùng chung trong cùng sự kiện; invalidates khi vật tư, stock, crop/soil hoặc commit thay đổi.
- Cache mọi điểm tiếp cận hợp lệ của máng theo footprint, transform và geometry revision. Worker ở xa vẫn dùng cache; điểm gần nhất được chọn từ tập đã kiểm tra. Kết quả không có lối tiếp cận cũng được cache đến lần geometry thay đổi.
- Badge chỉ cập nhật `Label.text` một lần khi nội dung thực sự đổi, tránh nhiều lượt resize/layout mỗi lần ghép dòng.

### Navigation dành riêng cho worker

- `WorkerNavigationSystem` sở hữu cache walkability thưa, tách theo physics space, footprint, collision mask và giới hạn camera. Các worker tương thích chia sẻ dữ liệu; đường và trạng thái tìm kiếm của từng worker vẫn riêng.
- A* mở rộng từng bước qua hàng đợi round-robin với trần chung **96 truy vấn dò**, **384 bước xử lý** và mục tiêu **1.500 µs mỗi physics step**. Cả việc chọn điểm bắt đầu và mở rộng tìm đường đều tiếp tục qua nhiều tick; không có loạt `get_id_path()` đồng bộ cho nhiều đích.
- Ưu tiên đường thẳng đã quét footprint. Đường A* dùng bốn hướng, chỉ gộp các đoạn thẳng hàng; không nối tắt qua góc tường để làm đẹp đường.
- Khi đang đi, kiểm tra lại đoạn đường khi đổi waypoint hoặc mỗi 0,15 giây, thay vì thử tới 8 shortcut mỗi tick. `move_and_slide()` vẫn xử lý va chạm mọi bước; nếu bị chặn thì invalidate vùng và tìm lại đường.
- Thêm/xóa `StaticBody2D` invalidate vùng va chạm, giữ lại cache ở vùng khác. Theo dõi cả body bị tháo khỏi parent. Chỉ khởi động lại tìm kiếm đã chạm vùng đó; sửa đường của một worker không xóa tiến độ mọi worker khác. TileMap có physics thay đổi vẫn invalidates bảo thủ.
- Player tiếp tục dùng `PlayerNavigationComponent` hiện tại. Worker adapter kế thừa các phép kiểm tra footprint và khoảng tương tác, nhưng không chạy planner/lưới riêng của player.

Ngân sách trên áp dụng cho planner. Các phép sweep kiểm tra đường đang đi và kiểm tra hành động/điểm tiếp cận có giới hạn riêng; không mô tả 96 là trần của mọi physics query trong toàn game.

### Worker rảnh

- Chọn đoạn đi dạo khoảng **48–128 px**, quét cả chỗ đứng lẫn đoạn nối.
- Không có đoạn an toàn thì **nghỉ tại chỗ**, không đi tới một góc ruộng xa chưa kiểm tra.
- Thời gian nghỉ xác định từ ID + vị trí nằm trong **2–3 giây**, giúp các worker nhận việc lệch nhau. Công việc sản xuất vẫn có thể ở bất cứ đâu trong world.

## Tổ chức mã

Phạm vi chức năng là đội worker. `WorkerService` điều phối timeline; `CropWorkerPolicy` chọn mục tiêu; các dictionary snapshot là projection đọc từ records; `WorkerWorldBridge` nối nhu cầu/tác vụ với API world. Hai file mới `worker_navigation_system.gd` và `worker_navigation.gd` lần lượt sở hữu dữ liệu/hàng đợi tìm đường chung và chuyển đường thành chuyển động của actor. Không thêm autoload hoặc gộp hệ thống player vào service worker.

## Kiểm chứng

- **96/96 test worker** qua, bao gồm 8 regression mới: không quét trồng khi đang bận, ưu tiên việc chuồng trại, reservation/stock, nhường frame và checkpoint, đi dạo gần, invalidate geometry khi thêm/xóa body, cache máng ở xa, chia lượt cho 15 navigator và đi vòng qua tường.
- **43/43 test liên quan tới crop** trong bốn suite tăng trưởng, tự trồng, chất lượng và đội trồng qua trong lượt mở rộng. Bao gồm ruộng **1.632 ô**, tiêu thụ đủ 60 hạt/vật tư không quota, replay **48 giờ** một lần/qua nhiều bước và worker đi tới ô rồi thực sự trồng sau restore.
- **16/16 test farm health world** qua, bao gồm tùy chọn đợi chăm sóc trước khi worker thu hoạch. Tổng cộng **155 test liên quan** qua; không cộng các test player ngoài phạm vi vào số đó.
- Lint toàn project và import/compile project chính được kiểm tra; các lần benchmark native không có script/runtime error. XML và log kiểm tra nằm trong `.godot/worker-fix-*`.
- Suite player `test_crops.gd` mở rộng có lỗi cũ độc lập: giả định stack khởi đầu 12 trong khi hiện là 24, kỳ vọng đổi hotbar giữa action cũ, và yield ngẫu nhiên nhưng so với lượng thu hoạch cố định. Những trường hợp đó được đối chiếu ở fixture worker gốc; không thay controller/economy của player để làm chúng qua. Không tuyên bố toàn bộ test của repository đều qua.

Fixture test worker đã được sửa điều kiện thuê/mở khóa, khôi phục clock sau test, đứng đúng doorway đã được tác giả di chuyển và đưa actor vào viewport thu nhỏ. Fixture tự trồng dùng máng đầy và roll sức khỏe/yield cố định, giống suite crop team, để phép replay không bị chi phối bởi công việc ranch hoặc sâu bệnh ngẫu nhiên. Bản worker gốc cũng thất bại các fixture cũ đó trước khi sửa fixture.

Test idle replay cho phép sai lệch một mốc wake 0,25 giây ở cả arrival và departure của **patrol**, theo tolerance trước đó đã có cho idle finish/wake. Mục tiêu, vị trí, inventory, lương, sản lượng và task sản xuất vẫn kiểm tra chính xác. Test checkpoint với budget 1 µs so sánh toàn bộ kết quả giao việc mà không dùng tolerance.

## Chạy lại

`scripts/prepare_worker_baseline.py` dựng `.godot/worker-baseline` với bốn file worker gốc từ git, dùng chung asset đã import và cùng harness hiện tại. Revision dùng cho bảng trên: `3a9834bf116e41cf40342573fd280b2e456ac808`. Nó không checkout source đang sửa. Hai fixture không bind persistence vì scene chạy là scene chẩn đoán, không phải FarmWorld.

```powershell
$godotBin = 'C:/Users/faker/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
& $godotBin --path C:/projects/fantasy-farm/.godot/web-stage --resolution 1280x720 --rendering-method forward_plus --log-file C:/projects/fantasy-farm/.godot/worker-after-live.log res://tests/performance/investigate_workers.tscn -- C:/projects/fantasy-farm/docs/worker_optimization_live_after_2026-11-01.json all live
```

`all live` đo 0 worker, 15 tự trồng và 15 tắt tự trồng. Bỏ `live` để đo CPU từng thành phần bằng bước thủ công. Harness thủ công đã được sửa để giữ CharacterBody2D trong physics space và chỉ tắt callback tự động; world tắt toàn bộ process làm body không có physics space khi bắt đầu di chuyển, nên không dùng cách đó để đo worker đang đi.

Để dựng lại đúng baseline trong tương lai, truyền `--ref 3a9834bf116e41cf40342573fd280b2e456ac808` cho `scripts/prepare_worker_baseline.py`, rồi đổi `--path` thành `.godot/worker-baseline` và chọn output khác. Chạy benchmark tuần tự, không đồng thời với test/import hoặc một game instance khác.

Chạy lại các nhóm test liên quan trong staging đã import:

```powershell
& $godotBin --headless --path C:/projects/fantasy-farm/.godot/web-stage -s res://addons/gut/gut_cmdln.gd '-gdir=res://tests/unit,res://tests/integration' '-gselect=worker' -gexit
& $godotBin --headless --path C:/projects/fantasy-farm/.godot/web-stage -s res://addons/gut/gut_cmdln.gd '-gdir=' '-gtest=res://tests/unit/test_crop_growth.gd,res://tests/integration/test_crop_automation.gd,res://tests/integration/test_crop_quality.gd,res://tests/integration/test_crop_team.gd,res://tests/integration/test_farm_health_world.gd' -gexit
```

Artifacts chính: `worker_optimization_live_before_2026-11-01.json`, `worker_optimization_live_after_2026-11-01.json` và hai ảnh `*-15-workers.png`. Báo cáo điều tra trước đó là dữ liệu lịch sử; kết quả render thật ở đây là bằng chứng đối chiếu cuối.
