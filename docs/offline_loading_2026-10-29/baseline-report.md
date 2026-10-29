# Báo cáo tổng thể: thời gian tải và khôi phục offline

Ngày chốt: **29/10/2026, UTC+7**.

## 1. Kết luận điều hành

**Hiện tượng cửa sổ kẹt ở splash đã được xử lý ở lượt trước, nhưng tổng thời gian catch-up vẫn chưa đạt mức chấp nhận được.** Đo lại bằng runner tái lập trên save lớn cho thấy median `load_game()` khoảng **0,282 giây với gap 0 giờ**, **8,019 giây với gap 1 giờ**, **89,656 giây với gap 15,5 giờ** trong headless. Đây là thời gian của bản code hiện tại, không phải số đo sau một đợt tối ưu kiến trúc mới.

Chốt hướng triển khai: **tách kernel offline trên dữ liệu thuần, giữ timeline sự kiện chính xác, giảm broad scans bằng chỉ mục/revision và dựng scene từ trạng thái cuối**. Thêm thread chỉ sau khi kernel đã tách khỏi live scene. Kế hoạch đầy đủ, rollout và các gate nằm trong [PLAN.md](../../PLAN.md).

Đợt này đã hoàn thành: khảo sát nguyên nhân, so sánh phương án, tạo benchmark có bảo vệ save, bổ sung **6 unit/regression tests**, chạy bộ chọn lọc **36/36 đạt**, và lưu bằng chứng. Các pha tối ưu kiến trúc P1–P5 là kế hoạch tiếp theo; chưa có số đo `after` để công bố hệ số tăng tốc thực tế.

## 2. Phạm vi đã thực hiện

| Hạng mục | Trạng thái |
|---|---|
| PLAN.md: mục tiêu, kiến trúc, công việc, rủi ro, kiểm thử và rollback | Hoàn tất |
| RESULT.md: số đo hiện tại, kết luận và giới hạn | Hoàn tất |
| Runner `scripts/benchmark_offline_load.py` + hai GDScript support | Hoàn tất, smoke và 9 run workload đều thành công |
| Sáu kiểm tra mới | Hoàn tất, nằm trong 36 test đã chạy |
| Bảo vệ input save khi benchmark | Hash bản gốc và bản sao đều giữ nguyên |
| Tối ưu kernel/chỉ mục/thread theo thiết kế đề xuất | Chưa triển khai trong đợt lập báo cáo |
| SLO native p95, cold import/shader, memory peak, Web export | Chưa đo trong đợt này |

Các thay đổi chống kẹt, cache truy vấn/ảnh và async loading từ lượt sửa trước được giữ làm baseline working tree. Đợt này bổ sung tài liệu, công cụ đo và tests; không đưa thuật toán kinh tế offline mới vào game.

## 3. Môi trường và fixture

| Trường | Giá trị |
|---|---|
| Engine | `4.7.2.stable.official.ed1daf0bf` |
| CPU quan sát được | Intel Core i3-12100, 8 logical processors |
| Renderer benchmark | `headless` |
| Git HEAD nền | `e102018f198ddab02c9f8e65cb11510be6279431` |
| SHA-256 diff production lúc đo | `99a07c6a45adb1ddb3bc356bc14775589d9e85c560406a0774fed0cd4d83d372` |
| Fixture | Bản lưu bảo tồn `profile_local.before-quality-particles.json`, schema nguồn v35 |
| Kích thước file | 283.497 bytes |
| SHA-256 fixture | `a8aae94e9232bd9d5fe6819bde245a9817a1a7ef337188bc28f6a39634e9badf` |
| Workload | 396 crops, 306 trees, 48 animals, 3 workers; 20 pickups có sẵn trong snapshot nguồn |
| Số mẫu | 3 process mới cho mỗi gap 0 / 3.600 / 55.800 giây; tổng 9 run |
| Clock | `target_at = saved_at + gap`; không phụ thuộc giờ máy đang chạy |
| Cache | Dùng assets đã import và OS cache có sẵn; không phải cold import |
| Staging | Bỏ MCPRuntimeServer, userdata tạm riêng; bản sao save chỉ dùng để đọc |

Runner gọi đường `GameSaveManager.load_game()` với repository và adapter có đo thời gian, world đang khóa. Catalog/world setup đo riêng. Bản đồ preview không được gắn thành `current_scene`, nên không tự bind profile thật. Thao tác khởi tạo và quá trình catch-up vẫn dùng code production hiện tại.

Đây là fixture lưu trước lượt kiểm tra chơi gần đây, nhằm giữ workload ổn định. Không thay bằng save đang autosave trong lúc đo. Có thể có tải nền của máy phát triển; vì vậy số mẫu này dùng chẩn đoán, chưa đủ xác nhận SLA/SLO cho người chơi.

## 4. Số liệu đã đo

Nguồn gốc: [benchmark/summary.json](benchmark/summary.json), kèm từng JSON/log của 9 run trong cùng thư mục.

### 4.1 Thời gian `load_game()`

| Gap offline | Run thành công | Min | Median | Max |
|---|---:|---:|---:|---:|
| 0 giờ | 3/3 | 274,980 ms | **281,727 ms** | 532,969 ms |
| 1 giờ | 3/3 | 7.877,357 ms | **8.019,439 ms** | 9.351,584 ms |
| 15,5 giờ | 3/3 | 89.505,830 ms | **89.656,178 ms** | 90.143,332 ms |

Không công bố p95 thời gian load từ 3 mẫu. Timeout/failure: **0/9** trong nhóm đo này; không suy rộng thành tỷ lệ lỗi ngoài nhóm đo.

### 4.2 Phân rã median theo pha

| Pha/chỉ số | Gap 0 giờ | Gap 1 giờ | Gap 15,5 giờ |
|---|---:|---:|---:|
| Catalog setup | 1,743 ms | 1,689 ms | 1,854 ms |
| World setup + setup frame/physics fence | 660,865 ms | 650,342 ms | 662,324 ms |
| Repository read + checksum/schema | 17,516 ms | 18,605 ms | 17,973 ms |
| `_restore_checkpoint()` | 236,486 ms | 244,764 ms | 2.604,994 ms |
| Final sync | 2,802 ms | 3,446 ms | 1,653 ms |
| Phần còn lại của load, gồm workers/yields và manager validation/preflight | 25,472 ms | 7.617,092 ms | 87.039,717 ms |
| Toàn process (khởi động đến thoát) | 2.201,444 ms | 10.230,467 ms | 91.542,839 ms |

Mỗi ô là median độc lập; tổng các median pha có thể khác median tổng. Phần “còn lại” là phép trừ trên từng run, **không phải CPU profile độc quyền của WorkerService**. Nó gồm cả chờ frame và một số bước validate/preflight của manager chưa có counter riêng.

Ở gap 15,5 giờ, median tỷ trọng phần “còn lại” khoảng **97,09%** của `T_load_game`. Chi phí đọc khoảng 18 ms không giải thích được gần 90 giây chờ. Tập trung chỉ vào đọc file hoặc tăng thread IO sẽ không giải quyết nút thắt chính đang quan sát.

### 4.3 Khả năng phản hồi và giới hạn của budget

- Worker progress kết thúc ở 100%, đơn điệu trong tất cả 9 run.
- Gap 15,5 giờ có 1.864–1.992 cập nhật progress, tùy số lần chạm budget theo tốc độ máy.
- Median khoảng heartbeat p95 **trong từng run headless** khoảng 63,972 ms ở workload 15,5 giờ. Đây không phải p95 native FPS hay p95 thời gian load qua nhiều người chơi.
- Frame gap lớn nhất quan sát được trong ba run dài: **2.772,043 ms**. `_restore_checkpoint()` vẫn có thể giữ main thread hàng giây, ngoài phần worker đã biết yield.
- Budget worker hiện tại 32 ms chỉ được kiểm tra giữa các event, không phải bảo đảm tất cả công việc hoặc toàn frame ≤ 32 ms.

Vì thế, “có thanh tiến độ” chưa đủ kết luận chất lượng tải đã tốt. Cần xử lý cả synchronous checkpoint, single-event cost và số lần tính.

### 4.4 Những kết luận chưa được phép rút ra

- Chưa có native A/B có stopwatch, đủ mẫu và cùng fixture/renderer cho đợt này. Lượt trước đã xác nhận tải xong và nhân vật di chuyển được; thời gian “vài phút” là quan sát, không dùng để tính phần trăm cải thiện.
- Chưa đo riêng CPU time của kernel, peak RSS, số event/physics query, image readback hoặc cache-hit rate.
- Chưa đo cold import/shader compilation, mobile/Web hay bản export.
- Không so sánh trực tiếp 89,656 giây headless với mục tiêu native 10 giây để công bố tốc độ tăng.

## 5. Nguyên nhân chốt lại

| Nguyên nhân | Căn cứ trong source | Mức kết luận |
|---|---|---|
| Timeline gắn với live scene | `worker_service.gd::advance` gọi bridge sync/commit và truy cập actors/inventory | Đã xác minh |
| Nhiều truy vấn toàn vùng mỗi sự kiện | `worker_world_bridge.gd::candidates/next_wake`, pickup group, crop planting scan | Đã xác minh; chưa tách tỷ trọng CPU từng hàm |
| Physics/topology được hỏi lại | `farming_controller.gd::_allowed`, crop policy thử nhiều ô | Đã xác minh; chi phí native cần profile riêng |
| Catch-up và yield chiếm phần lớn độ tăng theo gap | Phần còn lại 87 giây của run 15,5 giờ; read khoảng 18 ms | Đã đo ở mức pha, chưa phải profiler CPU |
| Checkpoint đồng bộ vẫn chặn frame | Median checkpoint 2,605 giây; max heartbeat gap 2,772 giây | Đã đo headless |
| Progress theo simulated time không theo lượng việc | Công thức progress trong `advance_async` | Đã xác minh; không thể dùng làm ETA tuyến tính |
| GPU readback có thể làm native chậm thêm | Trước đó đã cache bounds ảnh cây; headless không đo được GPU stall | Khả năng kỹ thuật, chưa lượng hóa tác động ở native |

Scheduler đã là event-driven. Vấn đề không phải chỉ “đổi vòng lặp từng giây sang event”, mà là **giảm event/truy vấn dư và giảm chi phí mỗi event**, đồng thời tách các pha dựng/cập nhật scene.

IO đọc đồng bộ và preflight/validation lặp là các điểm nên sửa, nhưng ưu tiên theo tỷ trọng đo được. Tách Node ra khỏi kernel còn giúp loại dependency vào frame timing và các deferred notifications khi yield.

## 6. Phương pháp khuyên dùng và cải thiện kỳ vọng

**Khuyên dùng: P1 giảm công việc dư và làm màn hình tải nhẹ, sau đó P2–P3 pure model + indices + timeline chính xác; P4 thread là lớp thực thi tùy nền tảng.** Không thay bằng công thức thưởng trung bình khi mục tiêu là bảo toàn luật.

| Chỉ số | Baseline đã đo | Mục tiêu đề xuất | Trạng thái |
|---|---|---|---|
| Headless median `T_load_game`, 15,5 giờ | 89,656 giây | ≤ 5 giây | Chưa đạt; cần P1–P3 |
| Native p95 ready, save lớn 15,5 giờ | Chưa có benchmark thống kê | ≤ 10 giây | Chưa đo/chưa đạt xác nhận |
| Native p95 ready, gap 48 giờ | Chưa đo | ≤ 20 giây | Chưa đo |
| First visible loading frame | Chưa đo đúng metric | ≤ 1 giây warm / 2 giây process cold, assets đã import | Cần loading shell và đo native |
| Native loading heartbeat | Chưa đo thống kê | p95 ≤ 50 ms, max ≤ 100 ms trên thiết bị chuẩn hỗ trợ | Cần chia checkpoint/event lớn và giảm render |
| Economic mismatch | Test chọn lọc hiện tại: 0 | 0 qua reference-vs-optimized và migration matrix | Gate bắt buộc |

Nếu median headless giảm thật từ 89,656 xuống 5 giây **trên cùng workload và điều kiện**, đó tương đương giảm khoảng **94,42%**, hay **17,93 lần**. Các số này là mức cải thiện cần đạt theo mục tiêu, **không phải thành tích đã có** và không phải dự báo bảo đảm. Nếu không đạt, giữ trạng thái “chưa đạt”, profile tiếp hoặc đánh giá lại phạm vi, không tự giảm offline time để làm đẹp chỉ số.

Thread riêng không bảo đảm tăng tốc theo số core. Lợi ích chính trước tiên phải đến từ bớt scan, bớt physics/scene/GPU interaction, chỉ xử lý dependency bị thay đổi và dựng entity một lần từ output đã chốt. Thiết kế thread tuân theo [giới hạn API thread của Godot](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html), với input/kết quả riêng cho từng job.

## 7. Ảnh hưởng, mất mát và nguy cơ break core logic

| Thay đổi đề xuất | Mức rủi ro | Mất mát được chấp nhận | Gate trước phát hành |
|---|---|---|---|
| Budget/loading shell/cache hình ảnh | Thấp–vừa | Có thể bỏ animation trung gian lúc chưa vào chơi | Final state, input/save gates, UI regression |
| Cache candidate/capacity/topology | Vừa | Không có mất mát kinh tế dự kiến | Revision/invalidation, kho đầy, unlock, vật cản |
| Tách model và integrated event scheduler | Cao về triển khai | Không chấp nhận mất tiền/đồ/growth | 0 economic diff; deadlines, hire order, seed, partial tasks |
| Gộp interval không có quyết định mới | Vừa–cao | Chỉ bỏ công việc trình bày/scan vô ích | Chứng minh tương đương qua weather/death/depletion/patrol phase |
| Worker thread + commit | Cao về concurrency | Không chấp nhận ghi một phần hoặc double commit | Frozen DTO, job token, cancel/failure tests, Web fallback |
| Thưởng trung bình/cắt gap/tăng năng suất | Cao về sản phẩm/core | Có thể đổi sản lượng, tiêu hao và cân bằng | Quyết định gameplay riêng; không khuyến nghị cho đợt sửa này |

Các bất biến quan trọng: nguyên đợt thu hoạch khi kho không đủ, quality tiers, nguồn supplies, free trial một lần, xét lương theo thứ tự thuê, số lần thu/chi trả, tuổi và sản phẩm trước khi chết, fair sharing máng, thời tiết tại đúng đoạn lịch sử, phần task đang dở và khả năng đọc save cũ. Chi tiết comparator/tolerance và rollout ở PLAN mục 7–9.

Trong đợt lập báo cáo: benchmark xác minh **0 thay đổi byte trên save nguồn và save copy**; 6 tests mới không sửa public gameplay API. Điều này không thay thế việc chứng minh mô hình tối ưu tương lai bảo toàn toàn bộ core logic.

## 8. Unit test và hồi quy đã thực hiện

Log: [tests.log](tests.log). Máy đọc được: [tests-summary.json](tests-summary.json).

| Suite | Đạt / tổng |
|---|---:|
| `tests/unit/test_worker_roles.gd` | 5/5 |
| `tests/unit/test_pen_offline.gd` | 9/9 |
| `tests/integration/test_workers.gd` | 22/22 |
| **Tổng** | **36/36; 545 assertions; 11,25 giây** |

Sáu test mới:

1. Chọn task ổn định qua 6 hoán vị; ưu tiên/khoảng cách/ID đúng; task trả về không alias dữ liệu chỉ mục.
2. Schema từ chối simulated cursor trong tương lai, âm, NaN và vô cực.
3. Pen model cho kết quả tương đương khi chia thời gian không đều qua weather/death/arrival và stock phân số.
4. Async không có nhân công xử lý gap một năm mà không đổi tiền/kho, progress hoàn tất và clock scope được phục hồi.
5. Async kết thúc đúng deadline chỉ thu một lần; gọi lặp tại cùng mốc không nhân đôi sản phẩm hoặc đổi task còn lại.
6. Async qua dawn khi kho không đủ nguyên đợt: giữ trái trên cây, không mất đồ và thiếu tiền thì ngừng ca đúng luật.

Các test có sẵn về 48h một bước vs chia theo giờ, ranch theo phút, crop theo giây và async parity vẫn được chạy. Không dùng assertion thời gian máy làm unit gate; timing được đo ở runner riêng.

Kiểm tra bổ sung: Python runner biên dịch thành công; `git diff --check` sạch; lint GDScript **0 lỗi**, còn **11 cảnh báo đường dẫn ảnh preview chưa được sinh** trong test support cũ, không thuộc các file benchmark mới. Tóm tắt: [lint-summary.json](lint-summary.json).

### Giới hạn kiểm thử

- Đây là bộ chọn lọc 36 test, **không phải toàn suite xanh**.
- Lượt xác minh trước đã có nhóm persistence báo 15 test lỗi, và trees/grafting báo 13 test lỗi trên cả mã HEAD cũ lẫn working tree; không phải lỗi mới từ đợt báo cáo. Log được giữ trong [prior-baseline/](prior-baseline/). Các số đếm theo summary của GUT; những log này thuộc lượt kiểm tra trước, không tính vào 36 test vừa chạy.
- Chưa chạy oracle mới-vs-cũ vì kernel mới chưa tồn tại. Test cùng thuật toán chia bước không tự chứng minh một thuật toán thay thế chưa được triển khai.
- Chưa xác minh cancel ở mọi phase, randomized nhiều seed, Web/native export và stress vô hạn supplies. Các hạng mục này đã được đưa vào PLAN.

## 9. Tái hiện, chứng cứ và mức độ tin cậy

```bash
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/unit/test_worker_roles.gd,res://tests/unit/test_pen_offline.gd,res://tests/integration/test_workers.gd -gexit

python3 scripts/benchmark_offline_load.py --godot "$GODOT_BIN" \
  --save /path/to/preserved/profile_local.before-quality-particles.json \
  --gaps 0,3600,55800 --repeats 3 --output output/offline-load-benchmark
```

Runner cần project đã import. Mỗi run dùng process mới, hash fixture, git HEAD và hash diff production. `summary.json` lưu cả timeout/failure và xác minh fixture không bị ghi. Muốn so sánh sau tối ưu phải dùng lại đúng fixture/checksum; một save đã chơi/thu hoạch/xử lý offline xong có workload khác.

Khảo sát code dùng Codebase Memory Verify tier, graph project `home-dungnguyen-Projects-test-js`; nhóm query discovery 16 kết quả đã trả hết, traces quan trọng không còn pagination. Đã đọc source cho các kết luận trọng yếu. Graph có một số cạnh dynamic/heuristic không phản ánh đầy đủ virtual dispatch, nên không lấy số cạnh làm bằng chứng toàn bộ luồng. Coverage best-effort không ghi nhận gap ở các file production liên quan lúc kiểm tra; tests/support mới được đọc và chạy trực tiếp.

## 10. Chốt tổng thể và bước triển khai tiếp theo

1. **Đủ căn cứ xác nhận còn vấn đề hiệu năng:** 15,5 giờ offline cần gần 90 giây chỉ ở headless và còn checkpoint giữ main thread hàng giây.
2. **Đủ căn cứ ưu tiên:** giảm quét/sync dư, tách kernel khỏi scene, chia pha khởi tạo; IO là tối ưu phụ theo số đo hiện tại.
3. **Chọn hướng bảo toàn gameplay:** event-driven pure model + indices + commit cuối, thread tùy nền tảng. Không đổi kinh tế để rút ngắn con số load.
4. **Đã có nền kiểm chứng:** benchmark tái lập, fixture bất biến và 36 test chọn lọc đạt với 6 test mới.
5. **Chưa chốt đạt mục tiêu tối ưu:** P1–P5, native p95 và oracle đa seed còn phải triển khai. Kết quả after phải được bổ sung vào báo cáo khi các gate của PLAN đạt.

Đánh giá hiện tại: **kế hoạch và baseline đã hoàn tất; nghiệm thu hiệu năng bản tối ưu mới chưa bắt đầu**.
