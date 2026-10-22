# Đánh giá hiệu năng bản dev — 22/10/2026

> Đây là baseline trước thay đổi. Lỗi save và tối ưu đợt đầu đã được xử lý; xem [kết quả triển khai](performance_optimization_results_2026-10-22.md).

**Kết luận:** với source hiện tại và save đang chơi, dự án giữ khoảng 59–60 FPS ở 1280 × 720 trên máy thử. GPU còn dư địa lớn; có vài frame khựng ngắn. Chưa có cơ sở để làm một đợt refactor hiệu năng lớn. Phát hiện cần ưu tiên hơn là save có tổ ong đang bị từ chối bởi kiểm tra dữ liệu primitive.

## Đúng phạm vi đo

- Chạy trực tiếp `--path` dự án hiện tại bằng Godot 4.7.2 debug, có cửa sổ render; không dùng HTML5, PCK export hoặc renderer headless.
- Vulkan / Forward+, Intel UHD Graphics 730; CPU Intel Core i3-12100.
- Cửa sổ 1280 × 720; logical viewport 1920 × 1080; zoom 4×; 48 bướm.
- Nạp bản sao save hiện tại, revision 55; cảnh có khoảng 4.992 node. Bài đo không ghi vào save gốc; SHA-256 đã được đối chiếu trước/sau.
- Mỗi kịch bản đo 10 giây, làm nóng 3 giây; lặp 2 lượt, đảo thứ tự ở lượt sau. Có 5 giây ổn định sau khởi tạo.
- Di chuyển bằng bốn action WASD, có kiểm tra quãng đường thực tế trên 1.000 px mỗi lượt. Không phải bài đo click-to-move/navigation.
- Source gameplay không đổi trong suốt phép đo; giữ nguyên chỉnh sửa hiện có của người dùng trong `world/main_world.tscn`.

## Kết quả khi bật VSync như cấu hình dev

P95 là ngưỡng mà 95% mẫu không vượt qua; frame time đo bằng đồng hồ thực giữa các frame. GPU là timestamp viewport do RenderingServer cung cấp.

| Kịch bản | FPS (2 lượt) | Frame P95 (ms) | GPU trung bình (ms) | Draw calls trung bình | Frame >50 ms |
|---|---:|---:|---:|---:|---:|
| Đứng yên, nắng | 59.24–59.80 | 19.07–20.68 | 1.01–1.02 | 109.37–109.77 | 3 |
| Di chuyển WASD | 59.69–60.00 | 19.59–20.06 | 0.83–0.83 | 133.90–136.40 | 0 |
| Mưa | 59.21–59.78 | 19.94–20.53 | 1.07–1.14 | 313.02–313.34 | 0 |
| Nắng, tạm nghỉ 3 callback | 59.39–59.89 | 17.73–20.13 | 1.01–1.05 | 111.16–112.77 | 0 |

- Frame chậm nhất trong các bài đo chính không lưu game: **65,12 ms**, ở lượt đứng yên thứ hai. Ba frame vượt 50 ms tập trung ở lượt này; chưa xác định nguyên nhân.
- Physics monitor trung bình khoảng **3,42–7,69 ms**, có mẫu cao nhất **15,65 ms**. Đây là phần đáng profile sâu hơn nếu muốn giảm khựng, nhưng chưa quy được cho vật nuôi, tương tác hay collision.
- Bộ nhớ allocator Godot theo dõi tối đa khoảng **168 MiB**; video memory khoảng **74,2 MiB**. Không phải tổng RAM/RSS của tiến trình. Bài đo ngắn chưa đủ kết luận về memory leak.
- Mưa tăng draw calls từ khoảng 110 lên 313, nhưng GPU vẫn khoảng 1,1 ms; chưa cho thấy nghẽn GPU trong viewport/zoom này.

## Thử nghiệm CPU bổ sung: tạm tắt VSync

Đây là phép chẩn đoán riêng; cấu hình dự án không bị sửa. Đo 2 lượt × 6 giây/kịch bản, làm nóng 2 giây, thứ tự đảo ở lượt sau.

| Kịch bản | FPS lượt 1 | FPS lượt 2 | Frame trung bình (ms) |
|---|---:|---:|---:|
| Đứng yên, nắng | 631.54 | 608.55 | 1.582–1.642 |
| Nắng, tạm nghỉ 3 callback | 667.02 | 674.47 | 1.482–1.498 |

Tạm dừng cùng lúc `WeatherEffects._process`, camera zoom `_process` và hotbar `_process` khi đứng yên cho tín hiệu tăng khoảng **6–11% FPS uncapped**, tương ứng giảm khoảng **0,08–0,16 ms/frame** trong các lượt thử. Đây là hiệu quả gộp, chưa tách riêng từng thành phần và chỉ có 2 lượt; không xem là cam kết cải thiện. Ở giới hạn 60 FPS, các lượt đều quanh cùng mức FPS.

Chỉ thử trong trạng thái idle: camera đã đạt zoom đích, không feedback mới, thời tiết đã về nắng. Không tắt mô phỏng thời tiết. Đây không phải bản triển khai tối ưu và không chứng minh có thể bỏ các callback trong gameplay.

## Phát hiện lỗi save: cần ưu tiên trước tối ưu

Bài đo gọi đúng `SaveManager.save_game()` trên bản sao save. Cả hai lượt với bộ lấy mẫu bất đồng bộ và lượt kiểm tra kiểu dữ liệu đều thất bại:

```text
code: invalid
error: Save files accept only primitive data.
$.beehives[0].id       — dictionary_key:StringName
$.beehives[0].position — dictionary_key:StringName
```

Các tổ ong tiếp theo cũng có kiểu khóa tương tự. Snapshot qua bước schema nhưng bị `_primitive()` từ chối vì hàm này chỉ chấp nhận khóa `String`. `Beehive.capture()` thêm khóa bằng `result.id` và `result.position`; phép kiểm tra runtime đã xác nhận hai khóa đó là `StringName` trong snapshot của save đang thử.

Vị trí liên quan: [Beehive.capture](/home/dungnguyen/Projects/test-js/components/bees/beehive.gd:63), [kiểm tra primitive](/home/dungnguyen/Projects/test-js/persistence/local_save_repository.gd:133), [đường ghi async](/home/dungnguyen/Projects/test-js/persistence/local_save_repository.gd:148).

Các lần thất bại mất khoảng **29–44 ms**; đó là thời gian trả lỗi, không phải latency của lưu thành công. Vì lỗi xảy ra trước bước commit, **chưa có baseline autosave ghi thành công**. Save gốc không đổi. Chưa sửa lỗi này trong đợt đo.

## Đánh giá thứ tự ưu tiên

1. **Sửa tính đúng đắn của save trước.** Chuẩn hóa khóa DTO tổ ong về String và kiểm tra round-trip save/load cùng revision/backup; không nới lỏng kiểm tra bằng cách bỏ validation. Đây là đề xuất cho công việc tiếp theo, chưa triển khai.
2. **Profile sâu physics và các frame spike.** Game đang chạy ổn ở mục tiêu 60 FPS, nhưng physics chiếm đáng kể trong ngân sách một tick 16,67 ms và có frame 65 ms. Cần script profiler để phân biệt engine collision với callback vật nuôi/tương tác; chưa thể chọn một hàm làm bottleneck.
3. **Weather idle → camera zoom → UI là đợt dọn CPU nhỏ, hợp lý về rủi ro.** Thử nghiệm gộp cho tín hiệu tiết kiệm nhỏ; giữ toàn bộ điều kiện gameplay/test trong kế hoạch hiện có, đo riêng từng thay đổi. Không kỳ vọng giải quyết mọi spike bằng ba mục này.
4. **Chưa ưu tiên registry, cache navigation, culling hay pooling chỉ từ số đo này.** Chưa có bằng chứng cho chi phí lớn ở các phần đó; đặc biệt bài đi WASD chưa kiểm tra click navigation và bài đo chưa thu hoạch liên tiếp.
5. **Chưa cần thay renderer hoặc giảm chất lượng đồ họa cho viewport đã thử.** Chi phí GPU thấp; cần đo lại ở zoom nhỏ, cảnh đêm hoặc độ phân giải cao hơn trước khi kết luận cho toàn game.

## Kiểm chứng và giới hạn

Các lượt dùng để đánh giá hoàn tất không có lỗi parse/runtime. Có 24 cảnh báo GDScript sẵn có khi nạp với debugger; linter trước/sau đều 0 lỗi và 11 cảnh báo cũ, không thêm cảnh báo cho bộ đo. Lượt thử đầu của bộ đo bị lỗi khởi tạo đã bị loại. Hai mẫu save đầu dùng sampler chờ coroutine cũng bị loại và đo lại bằng sampler vẫn lấy mẫu mỗi frame trong lúc worker chạy.

`Performance.TIME_PROCESS` là thời gian của frame, không phải riêng thời gian script. `TIME_PHYSICS_PROCESS` là thời gian tick physics. Monitor có chu kỳ cập nhật riêng; phân vị monitor không đồng nghĩa phân vị của từng hàm. Các thời gian render CPU/GPU là số đo viewport, không cộng đơn giản với frame time để tính FPS. Tham khảo [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) và [RenderingServer GPU timing](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu).

Chưa đo: từng hàm script, click navigation, thao tác thu hoạch, zoom cực trị, ban đêm, autosave thành công và chạy lâu để kiểm tra memory leak. Hai lượt trên một máy chưa đủ khẳng định lợi ích tối ưu cho mọi máy.

Bộ đo tái sử dụng: [profile_dev.gd](/home/dungnguyen/Projects/test-js/tests/performance/profile_dev.gd). Chạy bằng editor binary với `--debug --ignore-error-breaks --path` source hiện tại và `--script tests/performance/profile_dev.gd -- <config.json>`. Dùng XDG_DATA_HOME tạm có bản sao save; cấu hình các lượt và số liệu nằm trong [JSON báo cáo](dev_performance_baseline_2026-10-22.json). Config/lượt chạy cục bộ nằm tại `.godot/dev-profile/`.
