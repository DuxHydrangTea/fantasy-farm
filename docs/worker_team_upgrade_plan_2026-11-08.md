# Kế hoạch đội 3 worker và nâng cấp bằng xu

Ngày: 08/11/2026. Trạng thái: đã triển khai giới hạn 3, nâng cấp chung, thao tác vùng, migration và UI. Đã tiếp tục rà soát và bổ sung kiểm thử, đo render; xem [báo cáo triển khai](worker_upgrades_2026-11-08.md). Giá vẫn là cấu hình thử; chưa chốt cân bằng lợi nhuận dài hạn hoặc cam kết mọi frame dưới ngân sách CPU.

## Các lựa chọn đã chốt

- Tối đa 3 worker đa năng, bắt đầu thuê lại từ đầu trong profile local.
- Nâng cấp chung cả đội, thuộc profile; không mất khi nghỉ việc hoặc thuê lại.
- Kỹ năng có 10 lần nâng (mức 0–10), mỗi lần giảm 10% thời gian thao tác còn lại, áp dụng mọi thao tác làm việc.
- Cuốc, gieo, tưới và thu hoạch nâng riêng 1×1 → 2×2 → 3×3. Không dùng chung cấp nông cụ của player.
- Mua bằng xu, tiến triển ở mức đầu tư vừa; giá dưới đây là cấu hình thử ban đầu cần đo cân bằng.
- Giữ lương 2.800 xu/người/ngày, điều kiện thuê và ưu tiên chăm sóc hiện có trong bản đầu.
- Chưa thêm nhánh nâng tốc độ đi bộ: câu trả lời hiện tại chỉ chốt kỹ năng và diện tích nông cụ.

## 0. Reset save — đã hoàn tất

Profile được xác định qua `profiles.cfg`: `local`, schema v40. Save chính revision 3215 và backup revision 3214 đều có 15 hồ sơ đã nghỉ việc, không có vật phẩm trong giỏ.

Đã sửa hai file trong `C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves/`:

- `profile_local.json`: revision mới 3216.
- `profile_local.json.bak`: revision mới 3215.

Thay đổi: xóa `workers.rows`, `trial_used`, `crop_automation.prepared`; đặt `next_order = 1`. Thuê lại bắt đầu chu kỳ thử việc mới theo yêu cầu bắt đầu từ đầu. Giữ timestamp mô phỏng, tùy chọn tự động hóa và lịch sử 589 ô trồng. Giữ nguyên mọi phần ngoài workers và revision, bao gồm tiền, inventory, kho, ruộng, cây, chuồng và nông cụ player.

Bản sao nguyên trạng, giữ cả checksum gốc:

- `profile_local.json.before-worker-reset-2026-11-08T09-18-53-733Z.bak`
- `profile_local.json.bak.before-worker-reset-2026-11-08T09-18-53-733Z.bak`

Kiểm chứng: hash SHA-256 đúng trước/sau; so sánh sâu các phần dữ liệu được bảo toàn; đọc trực tiếp cả primary và backup qua `LocalSaveRepository._read()` và `SaveSchema.validate()` trong Godot 4.7.1: cả hai hợp lệ, 0 worker, không cần phục hồi backup. Không có game runtime đang chạy lúc sửa, chỉ có Godot editor.

## 1. Quy tắc gameplay

### Thời gian làm việc

`duration = base_work_seconds × pow(0.9, speed_level)`.

Với base hiện tại 2 giây: mức 0 = 2,00s; mức 1 = 1,80s; mức 5 = 1,18s; mức 10 ≈ 0,697s. Lưu và tính bằng giá trị chính xác, chỉ làm tròn số hiển thị.

Áp dụng cho till, plant, fertilize, water_crop, harvest, fruit, pickup, feed, fetch_water, water_trough, treat_pests, treat_weeds, cure_animal. Không tác động patrol/nghỉ, di chuyển, thời gian cây sinh trưởng, lượng thu hoạch hay thời gian chờ hết bị chặn.

Một hàm truy vấn duration duy nhất dùng cho giao việc, đến đích thật, thử lại đường đi, cập nhật mục tiêu vật nuôi, capture/restore và offline. Hiện `definition.work_seconds` được dùng tại nhiều chỗ trong service, behaviour và bridge; phải thay nhất quán để behaviour không kéo duration đã nâng trở lại 2 giây.

Mua nâng cấp không rút ngắn công việc đang dở. Chốt duration và tập ô tại lúc giao task; task sau mới nhận cấp mới. Save nhiệm vụ lưu duration hữu hạn hợp lệ để reload không tăng/giảm tiến độ. Mua không invalidate cả đội hoặc kéo dài task do thay revision thiết lập tự trồng.

### Vùng thao tác

- Chọn ô neo theo ưu tiên công việc hiện tại, hướng cố định theo hàng ruộng; vùng 2×2 từ neo sang phải/xuống, 3×3 quanh neo. Sắp theo khoảng cách ô tới neo, rồi y/x để replay ổn định.
- Loại ô khóa, ngoài ruộng, sai trạng thái, có vật cản, bị người khác giữ chỗ hoặc không thể tác động từ điểm làm việc thực tế. Không tác động xuyên hàng rào/tường; không đòi worker phải đứng trong khoảng tương tác 1×1 với mọi ô của nông cụ 3×3.
- Một lượt chỉ thực hiện một loại thao tác; một lượt gieo dùng một loại hạt được chọn theo chính sách kho hiện có.
- Cuốc/gieo/tưới dùng lại `FarmingController.apply_area()` và luật quyền từng ô; phải kiểm tra lại range/obstruction cho worker trước commit.
- Thu hoạch ruộng cần adapter batch riêng: API apply_area hiện chưa hỗ trợ harvest. Gọi đường thu hoạch hiện có để giữ quality, yield, crop lifecycle và sự kiện nhiệm vụ, thay vì tự xóa cây và thêm sản phẩm.
- Thu trái cây, chăm chuồng, bón phân và chữa bệnh vẫn từng mục tiêu, hưởng nâng tốc độ. Nâng vùng thu hoạch chỉ áp dụng cây trên ruộng.
- Gieo chỉ trừ một hạt cho mỗi ô thành công. Thiếu hạt thì làm số ô có thể làm, không giữ chỗ quá số hạt thực còn sau reservation của đội.
- Kho đầy: xử lý theo thứ tự ổn định, không thu cây nếu không đủ chỗ cho toàn bộ sản lượng của cây đó; có thể tiếp tục cây khác phù hợp. Không mất phần dư, không xóa cây khi chưa nhận đủ.
- Giữ hành vi tưới worker hiện có; không tự thêm vật tư nước cho ruộng. Vật tư ở mọi tác vụ khác chỉ tiêu hao theo API và số ô/mục tiêu thành công.

### Reservation và tiến độ batch

Task có danh sách tối đa 9 ô; giữ chỗ tất cả ô và số vật tư cần, không chỉ ô neo. Hai worker có thể làm các tác vụ khác nhau nhưng không giữ cùng ô. Prepared state cho cuốc → gieo phải hỗ trợ nhiều ô, thay cho một ô mỗi worker hiện tại; giữ ưu tiên gieo các ô vừa chuẩn bị.

Xác minh lại từng ô tại commit: cây có thể đã bị player thu, đất có thể đã đổi, kho có thể hết hạt. Bỏ qua ô không còn hợp lệ, trả reservation tương ứng; số liệu chỉ tính ô thật sự thành công. Care-first/wait-for-care áp dụng theo từng cây trong batch, không chỉ ô neo.

Giữ ngân sách scheduler 2.000µs/frame và navigation chung. Không await giữa một giao dịch kho đang khóa. Đo commit 9 ô trước; nếu vượt ngân sách, chia thành các commit nhỏ ở ranh giới ô, lưu cursor và kết quả đã làm, nhả khóa giữa các phần, giữ reservation còn lại. Không tạo node/timer mới cho từng ô. Save giữa batch phải tiếp tục chính xác, không thu hoặc trừ hạt lặp.

## 2. Giá thử ban đầu

Chỉ tốn xu, không yêu cầu gỗ hoặc mua cấp nông cụ player. Không tăng lương theo cấp. Không yêu cầu phải thuê người mới được mua nâng cấp.

| Lần nâng kỹ năng | Giá xu | Thời gian thao tác sau nâng (giây) |
|---|---:|---:|
| 1 | 10.000 | 1,800 |
| 2 | 15.000 | 1,620 |
| 3 | 22.000 | 1,458 |
| 4 | 32.000 | 1,312 |
| 5 | 45.000 | 1,181 |
| 6 | 60.000 | 1,063 |
| 7 | 80.000 | 0,957 |
| 8 | 105.000 | 0,861 |
| 9 | 135.000 | 0,775 |
| 10 | 170.000 | 0,697 |

Tổng kỹ năng: 674.000 xu.

| Nông cụ worker | Lên 2×2 | Lên 3×3 | Tổng |
|---|---:|---:|---:|
| Cuốc | 30.000 | 90.000 | 120.000 |
| Gieo | 40.000 | 120.000 | 160.000 |
| Tưới | 30.000 | 90.000 | 120.000 |
| Thu hoạch | 50.000 | 150.000 | 200.000 |

Tổng nông cụ: 600.000; hoàn thiện tất cả: 1.274.000 xu. Giá cuốc/tưới/gieo lấy mức 2×2 và 3×3 của hệ player làm mốc tham khảo, chưa chứng minh là cân bằng vừa. Đội 3 người tiết kiệm tối đa 33.600 xu/ngày lương so với 15 người; phải đo cả lợi nhuận ròng và chi phí vật tư, không chỉ dùng khoản tiết kiệm này để suy ra thời gian hoàn vốn.

## 3. Cấu trúc triển khai

Bounded context: đội worker. Không thêm autoload mới; world/WorkerService nối các thành phần.

| Thành phần | Trách nhiệm |
|---|---|
| `components/workers/upgrades/worker_upgrade_state.gd` | Model: speed_level 0–10, hoe/sowing/watering/harvest 1–3, revision giao dịch; độc lập roster |
| `scripts/workers/worker_upgrade_catalog.gd`, `resources/workers/upgrades.tres` | Dữ liệu giá, phạm vi hợp lệ và duration multiplier; không chứa UI |
| `components/workers/upgrades/worker_upgrade_service.gd` | Query quote và command purchase: settle timeline, kiểm tra offer/cấp/xu/profile-ready/busy, commit ví + cấp trước signal; chống tái nhập |
| `components/workers/worker_area_policy.gd` | Quy tắc thuần chọn tập ô, thứ tự, eligibility và reservation batch |
| `WorkerService`, `CropWorkerPolicy`, `WorkerWorldBridge` | Điều phối task, prepared/reservation nhiều ô, commit qua API world và truy vấn duration tập trung |
| `WorkerMenu` và view nâng cấp riêng | Controller hiển thị quote, gửi purchase; không tự sửa ví hoặc actor |
| `WorkerSaveSchema`, `SaveSchema`, repository hiện có | DTO/migration/validation/capture/restore; không chứa quyết định UI |

Tái dùng mẫu giao dịch ToolUpgradeService nhưng không dùng chung level, giá, vật tư gỗ hay giao diện shop của player. Event purchased phát sau khi ví và model đã commit; thay đổi UI qua signal, không refresh hàng loạt mỗi frame.

## 4. Thứ tự làm và điều kiện hoàn thành

### P1 — Giới hạn 3 và nền save/nâng cấp

- Dùng một hằng số cho giới hạn 3 ở hire, slot, thông báo team full, tiêu đề, fixture. Hiện menu và thông báo còn hardcode 15.
- Thêm model/catalog/service, capture/restore nâng cấp độc lập roster. Schema tăng từ phiên bản thực tế lúc triển khai (hiện v40), migration cũ khởi tạo level mặc định.
- Reset local phía trên là thao tác một lần; không thêm mã xóa worker mỗi lần load, không xóa worker ở profile khác.
- Với save legacy còn hơn 3 hồ sơ, đọc bằng validator legacy trước khi normalize. Không chỉ đổi LIMITS khiến slot 4–15 bị từ chối. Giữ tối đa 3 hợp đồng làm việc theo hire_order; phần dư ở dữ liệu dự trữ legacy không spawn/không tính lương, giữ giỏ để hoàn trả qua đường kho có kiểm soát. Không làm mất đồ khi kho đầy. Hồ sơ nghỉ việc rỗng có thể loại bỏ. Save mới chỉ cho tối đa 3 actor/hợp đồng đang thuê.
- Kiểm thử mua đúng/thiếu xu/max level/click lặp/quote cũ/tái nhập, thuê người thứ 4 thất bại; cho nghỉ toàn bộ rồi thuê lại vẫn giữ cấp; validate cả primary và backup.

### P2 — Kỹ năng làm việc

- Thay toàn bộ chỗ tính duration trong service, behaviour, bridge bằng nguồn chung; task đã giao giữ duration cũ.
- Kiểm thử mức 0/1/5/10, đến muộn, đổi đường, bệnh vật nuôi đổi vị trí, save/load đang làm, mua khi đang làm và replay offline chia đoạn.
- Không áp multiplier vào travel/patrol/growth. Mức 10 phải chạy thực tế gần 0,697s với đường tới đích đã hoàn tất, không chỉ kiểm tra phép tính.

### P3 — Nông cụ theo vùng

- Làm cuốc/gieo/tưới trước, harvest sau; test task nhiều ô, prepared, slot kho và vật tư dự trữ cùng lúc.
- Kiểm thử đủ/thiếu hạt, mix cây chín/chưa chín/cần chăm sóc, kho gần đầy, quality khác nhau, rào chắn, mép đất khóa, player can thiệp, hai worker vùng chồng nhau, pause/nghỉ/chặn/đổi setting giữa task.
- Chốt lựa chọn commit 9 ô một lượt hay chia nhỏ dựa trên đo thời gian. Nếu chia nhỏ, thêm test capture ở từng cursor và replay không lặp tác dụng.

### P4 — Giao diện và cân bằng

- Giữ danh sách tối đa 3 người, thêm tab “Nâng cấp đội” tại bảng quản lý worker hiện tại.
- 5 dòng nâng cấp: kỹ năng, cuốc, gieo, tưới, thu hoạch. Mỗi dòng có mức hiện tại → tiếp theo, số giây/phạm vi, giá, nút mua và lý do bị khóa/max.
- Ghi rõ “Áp dụng cả đội; giữ khi thuê lại” và “Công việc mới nhận hiệu lực nâng cấp”. Kỹ năng hiển thị 0/10 để tránh nhầm 10 mức chỉ có 9 lần nâng.
- Layout theo container/scroll; kiểm tra desktop và 844×390, cả thao tác chạm. Dùng theme và dịch thuật hiện có.
- Fixture cân bằng riêng: cùng đất/cây/vật tư/kho/thời tiết; đo baseline 15, 3 level gốc, 3 mức trung gian và 3 tối đa. Không đụng save đang chơi khi benchmark.

### P5 — Kiểm chứng trước bàn giao

- Chạy lint trước/sau chỉnh Godot, import/compile, suite worker/crop team/care/storage/persistence và test mới.
- Online/offline dùng cùng chính sách, cùng thứ tự task/ô và charge vật tư. Offline hiện tắt trong cấu hình, vẫn phải giữ đường replay hợp lệ.
- Benchmark render thật tuần tự, có warm-up và nhiều lượt trên cùng fixture: FPS/frame P95/P99, spike lớn nhất, scheduler/navigation/commit CPU, số ô thực hoàn thành/phút và tỷ lệ thời gian di chuyển/chăm sóc.
- Tiêu chí: không tạo hơn 3 actor, không mất/nhân đồ, không phá task dở, không có lỗi parse/runtime mới; 3 worker nâng cấp phục vụ cùng ruộng ổn định. Không quy đổi mức giảm countdown thành cam kết thu nhập hoặc FPS.
- Đo save thực tế bằng bản sao vì report 01/11 là fixture cũ, không thay thế phép đo hiện tại. Nếu cây, vật nuôi hoặc hiệu ứng là nút thắt còn lại, ghi số liệu riêng thay vì tuyên bố giảm worker đã giải quyết toàn bộ FPS.

## Ghi chú triển khai

Task vùng đã dùng commit từng ô tại ranh giới sự kiện scheduler; cursor được lưu để tiếp tục đúng sau reload. Giỏ legacy dư được lưu dưới `workers.legacy_baskets`, không tạo actor, tự chuyển nông sản/feed về kho khi có chỗ. Giữ tối đa 3 hồ sơ theo ưu tiên đang thuê rồi thứ tự thuê. Giá nằm trong resource `resources/workers/upgrades.tres` và các giá trị mặc định của `WorkerUpgradeCatalog`.

Migration v40 → v41 khởi tạo nâng cấp mặc định. Reset save local là thao tác một lần ở bước 0, không lặp lại khi tải game. Các tên file và pha bên trên mô tả thiết kế; báo cáo triển khai ghi phạm vi đo thực tế và các giới hạn.
