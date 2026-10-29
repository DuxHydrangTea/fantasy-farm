# Kết quả triển khai tối ưu loading và khôi phục offline

Ngày chốt: **29/10/2026, UTC+7**. Engine: **Godot 4.7.2**.

## 1. Kết luận và trạng thái

**Đã triển khai đợt tối ưu hẹp, sửa lỗi timeline và bổ sung kiểm thử. Chưa hoàn thành toàn bộ P2–P5 trong PLAN.** Trên cùng save lớn, median `load_game()` headless giảm từ **89,656 giây xuống 20.539 giây** cho offline 15,5 giờ, tương đương giảm **77.1%**, nhanh khoảng **4.37 lần**. Gap 1 giờ giảm từ 8,019 xuống 1.517 giây.

Hai đối chiếu với thuật toán không cache, cùng timeline đã sửa, cho **0 khác biệt** ở toàn bộ snapshot cho gap 1h/15,5h. Sáu đối chiếu lặp lại cũng không có khác biệt. Cả 9 snapshot kết quả đều qua SaveSchema thật.

**Trải nghiệm native vẫn chưa đạt mục tiêu.** Có lượt 22,611 giây, lượt cửa sổ QA luôn nhìn thấy 24,959 giây, và một lượt cửa sổ bình thường 93,118 giây với nhiều khoảng frame đúng 1 giây. Các lượt đều vào game thành công; mã cuối đã xác nhận điều khiển nhân vật được. Không loại mẫu chậm để công bố SLA đẹp hơn. Mục tiêu headless 5 giây / native p95 10 giây chưa đạt.

## 2. Những thay đổi đã có trong game

| Khu vực | Thay đổi và tác dụng |
|---|---|
| Loading shell | `world/loading_screen.tscn` trở thành main scene, có chữ/tiến độ tương phản rõ. Asset farm tải bằng `load_threaded_request`, sau frame đầu được vẽ. Cửa sổ giữ 960×540, viewport 1920×1080. |
| Truy vấn nông trại | Kiểm tra soil/crop trước permission/physics; wet soil không còn hỏi collision để tưới. TileMapLayer index cập nhật khi thêm/bớt layer, vẫn đọc tile data hiện tại. |
| Lookup chuồng | Cache weak-reference theo ID, kiểm tra instance/parent/ID trước dùng; tránh quét toàn world cho mỗi pickup trong chuồng. |
| Ong/hoa | Tách `pollination_assignment.gd` thành hàm geometry thuần. Cache ownership/assignment có chữ ký geometry/radius/repair/garden/legacy và biên nở hoa. Nguồn hoa invalid khi plant/harvest/restore/clear/lock, deadline/vị trí vẫn cập nhật. |
| Vùng crop của ong | Chỉ xét crop trong bán kính có thể nhận boost. Sunflower xa vẫn giữ bloom deadline trong source list. Crop thường xa mọi hive không thể thay đổi pollen, nên bỏ những split không tác động. |
| Cây lâu năm | Dùng chung weather/radius trong một lượt; cây đầy quả hoặc timber trưởng thành không có stump không tính growth thừa. Stump vẫn chạy sự kiện tái sinh; có regression riêng. |
| Soil rendering | Độ ẩm, trạng thái khô/ướt và signal commit từng event; gom việc dựng đường viền đất ướt về cuối async job. Không dùng ảnh làm model độ ẩm. |
| Weather UI | Giữ mô phỏng thời tiết; HUD/lighting được refresh ở trạng thái cuối thay vì mọi event offline. |
| Loading contract | Tiếp tục pause clock, khóa world/saving khi load, yield giữa event; khôi phục clock/process state sau job. Không mở saving khi mới hiển thị loading. |

Các cache không được serialize vào save. Không thêm migration/schema cho tối ưu này. Thuật toán trả lương, thứ tự thuê, hạn kho, quality tiers, travel/work time và patrol phase vẫn được giữ.

## 3. Ba lỗi thứ tự/trạng thái đã sửa

1. **Garden advance tới tương lai trước workers.** Restore cũ gọi garden.refresh(target) trong checkpoint, kéo ong/cây tới target trước khi workers phát lại từ saved_at. Hiện garden khôi phục ở saved_at rồi chạy trên cùng timeline; refresh hình cuối sau replay. Regression so kết quả offline restore với advance trực tiếp.
2. **Pickup notification phụ thuộc frame.** Thông báo node mới từng chạy deferred tại lúc yield, có thể hủy patrol ở mốc khác khi đổi budget/tốc độ máy. Hiện queue weak references được drain sau bridge.sync ở đúng logical timestamp, khi vị trí pickup đã được đặt.
3. **Pickup cũ queue_free che pickup mới trùng ID.** Commit từng có thể chọn instance cũ đang chờ xóa và trả thất bại trước khi xét instance mới restore. Hiện bỏ qua node đang queue_free/amount=0. Test tái hiện ID trùng và test nhiều budget đều đạt.

Kết quả có thể khác bản có lỗi thứ tự trước đây. Đối chiếu bảo toàn dùng **timeline tham chiếu đã sửa**, không lấy kết quả sai của bản cũ làm luật kinh tế. Không cắt gap hoặc nhân thưởng theo năng suất trung bình.

## 4. Số đo cùng fixture

Fixture bảo tồn: `profile_local.before-quality-particles.json`, schema nguồn v35; **283.497 bytes**, 396 crops, 306 trees, 48 animals, 3 workers, 20 pickups ban đầu. SHA-256:

`a8aae94e9232bd9d5fe6819bde245a9817a1a7ef337188bc28f6a39634e9badf`

CPU quan sát: i3-12100, 8 logical processors. Native: X11 / Forward+ / Intel UHD Graphics 730. Headless và native probe dùng clock/target cố định theo saved_at + gap; clock bị pause trong probe để tránh thời gian benchmark trôi vào trạng thái kinh tế. Chưa đo đầy đủ wall-clock resume/sleep sau READY. Assets đã import và OS cache được tái dùng. Đây không phải cold import, mobile/Web hay export acceptance.

| Gap | Baseline median | Sau tối ưu median | Thay đổi | Mẫu cuối |
|---|---:|---:|---:|---:|
| 0h | 0,282 s | 0.295 s | Gần như không đổi; chênh nhỏ chưa có ý nghĩa thống kê | 3/3 |
| 1h | 8,019 s | 1.517 s | Giảm 81.1% | 3/3 |
| 15,5h | 89,656 s | 20.539 s | Giảm 77.1% | 3/3 |
| 48h | Chưa có baseline | 41,645 s | Một mẫu chẩn đoán; chưa phải median/p95 | 1/1 |

Gap 15,5h của 3 lượt cuối: **20,410 / 22,289 / 20,539 giây**. Không suy p95 load từ ba mẫu.

| Chỉ số ở gap 15,5h | Baseline | Sau tối ưu |
|---|---:|---:|
| Median checkpoint | 2.604,994 ms | 234.317 ms |
| Median p95 heartbeat trong từng run headless | 63,972 ms | 39.918 ms |
| Max heartbeat quan sát trong nhóm 3 run | 2.772,043 ms | 324.036 ms |

Checkpoint/scene instantiate vẫn có đoạn đồng bộ vài trăm ms. Budget 32 ms được xét giữa event, không phải bảo đảm toàn frame ≤32 ms.

### Native và mẫu chậm

| Lượt | Startup từ probe autoload | p95 frame gap | Max frame gap | Kết quả |
|---|---:|---:|---:|---|
| Native thông thường ban đầu | 22,611 s | 39,944 ms | 546,400 ms | Vào game |
| Mã cuối, cửa sổ bình thường | 93,118 s | 999,999 ms | 1.112,060 ms | Vào game, input/movement đạt |
| QA cửa sổ luôn nhìn thấy | 24,959 s | 44,268 ms | 584,193 ms | Vào game, input/movement đạt |

Mẫu visible vẫn **không focus**, `Engine.max_fps=0`, low-processor mode=false. Vì vậy riêng mất focus không giải thích được mọi trường hợp. Chênh lệch gợi ý ảnh hưởng của trạng thái hiển thị/presentation hoặc tải môi trường; nguyên nhân chính xác của các frame 1 giây **chưa được xác định**. Không thay VSync, ép always-on-top hay tắt render trong cấu hình game. `--always-on-top` chỉ dùng ở QA có ghi rõ.

Màn hình loading đã được chụp sau frame_post_draw, khoảng 30–50 ms tính từ probe autoload, layout đạt ở 960×540 và 1280×720. Số này **không tính toàn bộ thời gian engine/process khởi tạo** và không phải đo display scanout. Các file native lưu ảnh loading và ảnh vào farm. SLO native cần 30+ mẫu với điều kiện cửa sổ/cache/GPU được kiểm soát.

## 5. Kiểm thử, parity và giới hạn

- **77/77 GUT tests trong bộ chính đạt**, 1.473 assertions: queries, geometry, worker roles, pen offline, workers, weather, crop automation.
- **1/1 test bổ sung về clock resume đạt**, 6 assertions: load thành công/thất bại đều khôi phục trạng thái processing; saving giữ hợp đồng busy. Log: `implementation/test-clock-resume.log`.
- **3/3 Python tests đạt** cho comparator: chuẩn hóa UUID liên kết, phát hiện mất item/tier/wage/slot order, dung sai float và patrol/task phase.
- **9/9 output snapshots qua SaveSchema**. Hash input save gốc và bản sao không đổi ở mọi run benchmark/native.
- **2/2 so sánh reference** cho 1h/15,5h: difference_count=0, max_float_error=0.
- **6/6 so sánh lặp cùng gap** của mã cuối: difference_count=0, max_float_error=0.
- **2/2 scene smoke thời gian thực + input fuzzing đạt**, 0 runtime errors. Loading scene chuyển sang main_world được ghi là info bình thường. Hai scene có 66 warnings tổng hợp từ mã hiện hữu.
- Validator scoped `components` và `world`: **0 errors, 0 node_config warnings**, mỗi scope có 33 diagnostics warnings tổng hợp; world có hint về TileMapLayer6 trống và hai physics-layer hints.
- Lint cuối: **0 errors, 11 warnings** về đường dẫn ảnh preview sinh lúc runtime.

Reference thay `_flowers`, `_assign`, tree advance bằng thuật toán từ HEAD và dùng full crop scan; giữ timeline đã sửa và bridge/soil batching hiện tại. Đây là kiểm tra các model/index được tối ưu, không phải chứng minh hai bản runtime cũ/mới hoàn toàn tương đương ở mọi luật/RNG.

Comparator chỉ chuẩn hóa ID pickup sinh mới, liên kết tham chiếu và thứ tự collection theo id/cell; giữ nguyên inventory slot order, counts, tiers, coins, hire order, task timestamps, position và patrol phase. Dung sai float cho phép 0,0001; sai số thực quan sát bằng 0. Fixture lớn không có tonic_pending; chưa bao phủ mọi đường RNG.

### Bộ toàn dự án chưa xanh

- `test_beehives.gd`: **16/19 đạt**, ba test legacy garden đã thất bại tương tự trên HEAD. Fixture mong hive sản xuất trong khi luật legacy garden đang pause new batches. Chỉ sửa fixture locale để các assertion tiếng Anh không phụ thuộc ngôn ngữ máy; không đổi luật honey để ép test.
- Full validator còn lỗi script QA `tests/support/workers_probe.gd`, WindowDialog/tool-instantiation và nhiều warning ngoài scope. Raw validator trên workspace còn gặp bản backup trong output; validator staging loại output vẫn chưa sạch toàn dự án.
- Full sweep mọi scene đã được thử nhưng **vượt 300 giây**, không có kết quả hoàn chỉnh. Lượt tự tìm scene ban đầu không theo symlink staging, sau đó đã thử danh sách rõ ràng; hai scene chịu ảnh hưởng trực tiếp được kiểm tra riêng và đạt. Không gọi whole-scene suite đã pass.
- Các baseline failures persistence/grafting ở báo cáo trước chưa được xử lý hết trong đợt tối ưu này.

## 6. Ảnh hưởng, rủi ro và lựa chọn phương pháp

| Thay đổi | Rủi ro / mất mát | Bằng chứng / xử lý |
|---|---|---|
| Cache/query/index | Cache stale khi thay đất, hoa, hive, bán kính hoặc restore | Có invalidation/fingerprint và tests bloom/move/repair/lock/harvest; reference snapshot parity. |
| Batch wet edges | Hình trung gian khi loading không dựng từng event | Moisture/soil signal vẫn chính xác từng event; test so soil và final terrain. |
| Capped tree fast path | Bỏ sót stump regrowth | Chỉ skip timber không stump; regression riêng đã chạy. |
| Timeline/notification fixes | Có thể đổi kết quả so với bản lỗi | Giữ thứ tự logic xác định; parity direct/restore và nhiều budget; không bỏ sản phẩm hoặc reset task để tăng tốc. |
| Loading main scene mới | Thêm bước tải resource và pha instantiate còn đồng bộ | Native ảnh/layout/input, main/loading smoke đạt; lỗi resource báo ngắn, chưa bind save. |
| Runtime/background | Catch-up vẫn chờ frame/render loop, có mẫu 1 FPS | Chưa giải quyết triệt để. Không cam kết native ready dưới 10 giây hoặc max frame 100 ms. |
| Bộ nhớ/save | Cache thêm O(crops + sources + geometry); không lưu vào schema | Chưa đo peak RSS đủ chuẩn. Save source bất biến khi QA; output schema đạt. |

**Khuyên dùng tiếp P2–P3:** tách đầy đủ worker/pen/crop/tree/weather state khỏi live Nodes rồi commit kết quả cuối. Các counter của run cuối vẫn cho thấy sync farming khoảng 6,1 s, pen bridge 5,4 s và crop candidates 2,7 s ở một run 15,5h. Đây là chỗ còn đáng làm, cùng checkpoint/render dependency. Sau khi kernel chỉ còn dữ liệu mới thêm thread executor/cancel/token và Web fallback (P4).

Không đưa SceneTree, physics hoặc Resource live hiện tại sang thread. Cache đã giúp giảm chi phí, nhưng chưa thay thế việc tách model. Giữ patrol/travel, wage order, quality và warehouse limits làm các gate bắt buộc.

## 7. Trạng thái nghiệm thu

| Gate | Trạng thái |
|---|---|
| Code tối ưu hẹp đã triển khai và chạy thật | Đạt |
| Đối chiếu cùng fixture và model reference ở 1h/15,5h | Đạt trong phạm vi đã đo |
| Save input bất biến, output schema hợp lệ | Đạt trên corpus benchmark |
| Headless median 15,5h ≤5 s | **Chưa đạt** |
| Native p95 15,5h ≤10 s | **Chưa đạt / chưa đủ mẫu** |
| Native p95 48h ≤20 s | **Chưa đo xác nhận** |
| p95 frame ≤50 ms trên mọi điều kiện | **Chưa đạt xác nhận; có mẫu 1 FPS** |
| Max frame ≤100 ms | **Chưa đạt** |
| Pure OfflineInput/Output + WorkerOfflineSimulation | **Chưa triển khai đầy đủ** |
| Thread/cancel/fallback Web, peak memory, export rollout | **Còn P4–P5** |

Đây là kết quả hoàn tất của **đợt tối ưu đầu tiên**, chưa phải tuyên bố hoàn thành toàn bộ PLAN hoặc sẵn sàng phát hành theo tất cả SLO.

## 8. Bằng chứng và tái hiện

- [Baseline trước tối ưu](docs/offline_loading_2026-10-29/benchmark/summary.json), [báo cáo baseline lưu lại](docs/offline_loading_2026-10-29/baseline-report.md).
- [9 run mã cuối](docs/offline_loading_2026-10-29/implementation/final-benchmark/summary.json), có fingerprint nội dung các file production, JSON/log và snapshot từng run.
- [Reference parity 15,5h](docs/offline_loading_2026-10-29/implementation/final-reference-parity-55800.json), [reference parity 1h](docs/offline_loading_2026-10-29/implementation/final-reference-parity-3600.json), [repeat parity](docs/offline_loading_2026-10-29/implementation/final-repeat-parity.json), [schema validation](docs/offline_loading_2026-10-29/implementation/output-schema-validation.json).
- [Native thông thường](docs/offline_loading_2026-10-29/implementation/final-native/startup.json), [native visible](docs/offline_loading_2026-10-29/implementation/native-visible/startup.json), [layout 1280×720](docs/offline_loading_2026-10-29/implementation/native-1280/startup.json), [48h](docs/offline_loading_2026-10-29/implementation/48h/summary.json).
- [Core tests](docs/offline_loading_2026-10-29/implementation/tests-core.log), [beehive tests](docs/offline_loading_2026-10-29/implementation/tests-beehives.log), [HEAD bee baseline](docs/offline_loading_2026-10-29/implementation/head-beehives.log), [smoke](docs/offline_loading_2026-10-29/implementation/smoke-changed-scenes.json), [full sweep status](docs/offline_loading_2026-10-29/implementation/smoke-all-status.json).
- [Kế hoạch và phần còn lại](PLAN.md). Graph Verify, generation được lưu ở graph-coverage.json; no_recorded_issue chỉ là best-effort. Source và engine/tests được dùng để xác minh các thay đổi vật chất.

```bash
python3 scripts/benchmark_offline_load.py --godot /path/to/Godot \
  --save /path/to/preserved/profile_local.json --gaps 0,3600,55800 --repeats 3 \
  --output output/offline-after

python3 scripts/benchmark_offline_load.py --godot /path/to/Godot \
  --save /path/to/preserved/profile_local.json --gaps 3600,55800 --reference-models \
  --output output/offline-reference

python3 scripts/benchmark_startup_load.py --godot /path/to/Godot \
  --save /path/to/preserved/profile_local.json --gap 55800 --output output/startup-native

python3 tests/test_compare_offline_states.py
```

`--budget 0` chọn synchronous reference để kiểm tra thêm async/sync. `--always-on-top` chỉ phục vụ QA native có ghi điều kiện, không phải cấu hình sản phẩm. Các runner dùng staging/userdata tạm và kiểm tra hash input; không dùng save đang autosave làm fixture bất biến.
