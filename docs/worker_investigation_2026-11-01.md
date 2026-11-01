# Điều tra 15 worker — 01/11/2026

Kết luận: có hai nguồn tải CPU độc lập. Chọn ô trồng bị gọi lại cho worker đang bận, gây dừng main thread hàng trăm ms; navigation nhân bản lưới và truy vấn va chạm theo số worker, gây tải liên tục ngay cả khi tắt tự trồng. Số lượng 15 làm lộ các vấn đề này, không phải một giới hạn cố hữu của Godot.

## Phạm vi và cách đo

- Godot 4.7.2 standard, headless; chạy scene chẩn đoán riêng trong `.godot/web-stage` đã import.
- Dùng world mới từ scene dự án, mở 16 cột ruộng (544 ô), cung cấp 1.000 hạt giống, thuê lần lượt 0/1/5/15 worker; thêm ca 15 worker tắt tự trồng. Không nạp save đang chơi.
- World bị tắt xử lý tự động; gọi scheduler mỗi 15 bước, behaviour mỗi bước, với delta mô phỏng 1/60 s; chờ physics frame để thế giới vật lý đồng bộ. Mỗi ca 180 bước và 12 mẫu scheduler. Đồng hồ mô phỏng cố định, seed cố định, ID worker cố định.
- Scene chẩn đoán là `current_scene`; FarmWorld chỉ là con của root, nên `WorldPersistence` không bind save. Tất cả JSON kết quả xác nhận `save_bound: false`.
- Đo thời gian đồng hồ thực bao quanh lời gọi đồng bộ. Đây là **chi phí thành phần CPU**, không phải benchmark FPS/render, không phải toàn bộ thời gian physics. Không quy đổi các số này thành FPS. Chưa đo GPU, phiên chơi dài, bản export hay save cụ thể của người dùng.
- Lượt đầu có chồng thời gian với import cache nên số sơ bộ cao hơn. Bảng dưới dùng lượt chạy lại sau khi import kết thúc. Lượt riêng 15 worker cũng tái hiện scheduler trung bình 613 ms; kết quả lần chạy lại toàn bộ là 603 ms.

## Kết quả đo sau khi import xong

| Worker / chế độ | Scheduler TB / lần (ms) | Scheduler cao nhất (ms) | Behaviour + navigation TB / bước (ms) | Truy vấn navigation / 180 bước |
|---|---:|---:|---:|---:|
| 0 | 0,016 | 0,021 | 0,007 | 0 |
| 1 / tự trồng | 0,395 | 0,633 | 1,083 | 17.302 |
| 5 / tự trồng | 0,395 | 0,512 | 4,353 | 86.510 |
| 15 / tự trồng | **603,070** | **870,598** | 3,907 | 103.812 |
| 15 / tắt tự trồng | 0,813 | 4,494 | **9,783** | **259.490** |

Không so sánh các dòng như tải công việc giống nhau: 1 và 5 worker đang lấy nước; ở ca 15 tự trồng có 6 worker lấy nước và 9 worker trồng. Tắt tự trồng biến 9 worker này thành đi dạo. Đây cũng giải thích vì sao việc thêm worker có thể gây một bước tụt hiệu năng đột ngột: các mục tiêu ưu tiên cao đã được giữ chỗ, các worker tiếp theo đi vào nhánh thuật toán trồng đắt hơn.

Trong ca 15 tự trồng:

- `planting_task()` được gọi **216 lần khi worker đã bận**, cộng 9 lần khi cần việc mới, trong chỉ 3 giây mô phỏng.
- Tổng thời gian trong hàm này là **7.108,681 ms**, khoảng **98%** tổng thời gian scheduler được đo.
- Probe riêng một worker đang trồng: `planting_task()` 31,973 ms, `candidates()` 30,370 ms, `next_wake()` 0,193 ms. Các phép đo là lời gọi riêng nối tiếp, không cộng/trừ để suy ra chi phí chính xác; chênh lệch nhỏ do trạng thái/cache và dao động thời gian chạy.

## Nguyên nhân sâu xa

### 1. Nhánh ưu tiên chuồng trại vô tình chạy lại thuật toán chọn ô trồng

`components/workers/worker_service.gd:350` gọi `bridge.candidates()` cho worker đang `till/plant/fertilize`, chỉ để tìm việc `feed/fetch_water/water_trough` có thể ngắt việc hiện tại. Nhưng `candidates()` gọi cả `crop_policy.planting_task()` ở `worker_world_bridge.gd:165`.

Kết quả: ngay cả worker đã có ô đích vẫn đi chọn thêm ô trồng rồi bỏ kết quả. `advance()` có thể xử lý cả mốc thời gian cũ và mốc `until` trong một lần gọi; 9 worker đang bận tạo ra 18 lượt chọn ô thừa mỗi lần cập nhật ở phép đo này. Comment “lazy evaluation” ở nhánh cấp việc mới không ngăn nhánh kiểm tra ưu tiên này.

### 2. Chọn ô trồng có vòng lặp lồng nhau và tạo dữ liệu tạm trong vòng nóng

`crop_worker_policy.gd:74–100`: tối đa 16 lần thử; mỗi lần quét cả `cells`. Với từng ô, tạo dictionary task để gọi `target_available()`. Hàm này lại duyệt `records` và dựng khóa mục tiêu (`worker_service.gd:94`).

Với W worker, C ô và A lần thử, phần giữ chỗ có giới hạn chi phí dạng **O(A × C × W²)** cho một lượt quét cả đội. Còn có chuyển đổi tọa độ, chuỗi và array/dictionary tạm cho từng ô. Đổi 32 lần thử thành 16 chỉ giảm trường hợp xấu nhất, không loại bỏ cấu trúc lặp này. Ngay 544 ô đã đủ tái hiện vấn đề.

### 3. Mỗi worker sở hữu navigation thiết kế cho một player

`worker_behaviour_component.gd:20` tạo một `PlayerNavigationComponent` riêng với `sampling_budget = 96`. Mỗi instance có `_sampled`, `AStarGrid2D` và cache riêng. Với camera 2544 × 1696, ô lưới 8 px, mỗi grid có 317 × 211 = **66.887 điểm**; 15 grid có thể chứa tổng cộng hơn một triệu điểm, chưa tính dictionary cache.

Ở ca tắt tự trồng, đo được 15 grid và 259.200 ô đã dò, phần lớn là cùng hình học thế giới được kiểm tra riêng cho từng worker. Khi cả 15 đang dò, ngân sách thành **1.440 ô / physics step**, chưa gồm các phép kiểm tra khác. Nếu đạt 60 bước/s thì riêng ngân sách này tương ứng 86.400 truy vấn/s; đây là phép tính theo ngân sách lúc planning, không phải số truy vấn/s tường thực trong phiên chơi.

`_advance_plan()` chỉ giới hạn dò ô. `_build_path_in_region()` có thể gọi `get_id_path()` cho nhiều ô quanh đích trong một lần; tìm A* và tạo grid chạy đồng bộ. `move()` còn kiểm tra nối tắt mỗi bước; `_segment_clear()` dùng cả `intersect_shape` và `cast_motion`. Vì vậy giảm `sampling_budget` không tạo ra trần thời gian cho toàn bộ navigation.

Thêm/xóa `StaticBody2D` cũng có thể làm tất cả instance xóa cache (`_geometry_changed`). Đây là nguy cơ từ mã, chưa đo riêng chi phí invalidate trong lần điều tra này.

### 4. Worker rảnh vẫn làm việc tìm đường nặng

`world_stroll_point()` chọn điểm trên gần toàn bộ giới hạn camera, kiểm tra chỗ đứng trống nhưng chưa chứng minh có đường tới. Giảm số lần chọn điểm từ 8 xuống 2 không giảm được chiều dài hành trình hay chi phí A* sau đó. Trong ca tắt tự trồng, 9 worker đi dạo khiến chi phí navigation tăng dù scheduler nhẹ đi.

## Phép thử loại trừ

Chỉ trong scene chẩn đoán, dùng subclass của policy để trả `{}` khi `planting_task()` được gọi cho worker đã bận. Cấp việc cho worker rảnh vẫn chạy nguyên bản; không đổi mã gameplay.

- Scheduler trung bình **33,703 ms**, so với 603–613 ms ở hai lượt gốc (lượt thử loại trừ trước đó: 34,848 ms).
- Vẫn có spike **292,310 ms** khi 9 worker cần cấp ô ban đầu (lượt trước: 306,473 ms). Trung vị của lượt mới là 8,717 ms.
- Cùng cơ cấu 6 `fetch_water` + 9 `plant` và cùng 103.812 truy vấn navigation.

Kết quả xác nhận quét thừa là nguyên nhân lớn, đồng thời cho thấy bỏ quét thừa **chưa đủ** để đạt ngân sách khung hình. Đây chưa phải bản sửa được kiểm tra đầy đủ về tính đúng gameplay.

## Hướng khắc phục theo thứ tự

1. **Tách truy vấn ưu tiên chuồng trại.** Nhánh ngắt việc chỉ đọc các nhu cầu chuồng trại; không tạo candidate trồng, thu hoạch, bón phân hay pickup. Chia sẻ snapshot nhu cầu giữa worker trong cùng sự kiện, cập nhật sau commit để giữ đúng reservation và thứ tự ưu tiên.
2. **Bỏ vòng duyệt worker cho từng ô.** Duy trì bảng giữ chỗ theo cell/station/pickup và bảng số vật tư đã giữ chỗ; tra O(1), cập nhật khi giao việc, hoàn thành, bị chặn, nghỉ, sa thải và restore. Chỉ tạo task dictionary cho mục tiêu đã chọn. Giữ đúng quy tắc ô đã chuẩn bị, thứ tự luân canh và tie-break khi chọn việc.
3. **Chia tải cấp việc bằng ngân sách chung của đội.** Ví dụ bắt đầu thử 1–2 ms/frame cho scheduler, có hàng đợi công bằng và con trỏ quét tiếp được qua nhiều frame. Phải giới hạn bên trong tìm ô/candidate; budget hiện tại chỉ kiểm tra giữa các sự kiện, không chặn được một sự kiện kéo dài 600 ms. Không thay trực tiếp timeline offline bằng xử lý theo frame; cần giữ kết quả online/offline và replay xác định.
4. **Dùng dữ liệu walkability chung cho hình học tĩnh.** Chia sẻ cache theo footprint/collision mask tương thích; invalidate vùng thay đổi thay vì cả bản đồ. Tránh chia sẻ trực tiếp grid có `_blocked_cells` riêng của từng worker; giữ phần đường và vật cản tạm riêng. Dùng ngân sách dò/lập đường chung, xếp hàng replanning; chỉ thử số ít điểm đích phù hợp thay vì nhiều A* đồng bộ.
5. **Giảm chi phí đi dạo.** Chọn điểm gần, trong vùng đã biết đi được hoặc cùng miền liên thông; nghỉ lâu hơn và giãn thời điểm nhận việc. Không tắt toàn bộ physics ngoài camera vì worker vẫn cần tiến triển công việc đúng.

Ngân sách 1–2 ms là điểm bắt đầu để thử, chưa phải cam kết đạt FPS. Nên xử lý 1 và 2 trước, sau đó đo lại để đặt ngân sách cho 3 và 4.

## Vì sao báo cáo/test cũ chưa bắt được

`docs/performance_workers_2026-10-31.md` có các số ước tính 660–800 query/s và dự kiến tăng FPS 40–60%; chúng không bao phủ truy vấn navigation đo được ở đây và không phải kết quả FPS đã xác minh.

`test_worker_performance.gd` tắt process của world và gọi `advance()` mặc định offline; ngưỡng 5 giây cho catch-up 30 giây không bảo vệ frame 16,67 ms. Test cache chỉ so sánh kết quả hai lần gọi, chưa đếm số lần quét hay query. Script `profile_workers.gd` hiện gán FarmWorld làm current_scene, có thể bind/autosave profile local; không dùng script đó trên save gốc để điều tra.

Cache crop hiện bị xóa sau mỗi `bridge.sync()`; cache máng chỉ được dùng ngay nếu worker trong khoảng 100 px. Đây là các giới hạn phụ; số đo đã chỉ ra chọn ô trồng là ưu tiên lớn hơn.

## Kiểm chứng cần có khi triển khai sửa

- Dùng bản sao save thực tế và render thật, cùng camera/render settings; so sánh 0/1/5/10/15 worker. Tách tự trồng, tưới/bón, thu hoạch, chuồng trại và đi dạo; đo cả cache lạnh/ấm và lúc thêm/xóa công trình.
- Báo frame time p50/p95/p99, số frame >33/>50 ms, thời gian scheduler/navigation, số lần chọn ô khi đang bận, số A*, truy vấn vật lý và độ trễ nhận việc. Giới hạn 60 FPS cần tổng frame time quanh 16,67 ms, không chỉ FPS trung bình đẹp.
- Regression cho giữ chỗ và vật tư không bị dùng trùng, ưu tiên vật nuôi, không xuyên tường, mục tiêu không tới được, pause/hire/dismiss, save/restore và kết quả online/offline. Đảm bảo đội lớn vẫn hoàn thành công việc nhanh hơn, tránh chỉ đổi giật hình thành worker đứng chờ lâu.

## Artifacts và chạy lại

- `tests/performance/investigate_workers.tscn` + `.gd`: probe độc lập, có instrumentation policy và chế độ thử loại trừ; không thay gameplay.
- `worker_investigation_2026-11-01.json`: lượt đầy đủ sau import.
- `worker_investigation_deep_2026-11-01.json`: lượt riêng 15 worker, probe từng hàm.
- `worker_investigation_ablation_2026-11-01.json`: thử bỏ chọn ô mới khi đang bận.
- Lint phạm vi `tests/performance`: 0 lỗi, 0 warning; scene đo chạy hết các ca, log lượt đo thành công không có `SCRIPT ERROR`, `ERROR` hay `WARNING`.

Chạy scene bằng Godot đã import project, truyền đường dẫn output tuyệt đối để dùng trên máy khác. Trong staging, TimeManager cần trỏ path script hợp lệ; không chạy probe bằng `--script` vì các dependency cần autoload đã khởi tạo.

```powershell
& $godot --headless --path C:/projects/fantasy-farm/.godot/web-stage --log-file C:/projects/fantasy-farm/.godot/worker-investigation.log res://tests/performance/investigate_workers.tscn -- C:/projects/fantasy-farm/docs/worker_investigation_2026-11-01.json
```

Thêm `15` sau output để chỉ đo 15 worker; thêm `skip_busy_planting` sau `15` để chạy phép thử loại trừ. Fixture cố ý tắt process tự động để đo từng thành phần; cần bài render thật riêng trước khi công bố mức cải thiện FPS.
