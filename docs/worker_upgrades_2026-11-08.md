# Đội 3 worker và nâng cấp năng suất — 08/11/2026

Giới hạn 3 người, 10 lần nâng kỹ năng, bốn nhánh vùng 1×1 → 2×2 → 3×3, migration v40 → v41 và tab nâng cấp đã có trong working tree. Đợt tiếp tục này rà code và kiểm chứng phần đang dở; không reset lại save local.

## Các phần bổ sung sau khi rà Git diff

- Commit batch kiểm tra worker còn hoạt động, đã ở điểm làm việc, reservation và đường nhìn từ **vị trí thực tế** trước từng ô. Giữ nguyên giới hạn tương tác tại điểm làm việc; không bắt mỗi ô 3×3 phải ở trong khoảng 1×1.
- Tưới dùng `FarmingController.apply_area()` với actor, giữ permission, sự kiện và chất lượng của API chung.
- Dọn toàn bộ prepared batch không còn hợp lệ sau khi player trồng/chặn ô; các ô hỏng không giữ worker chờ thay vì tìm ô mới. Cache tìm việc dùng toàn bộ tập prepared, thay vì chỉ ô đầu tiên.
- Lý do không mua được nâng cấp hiển thị trực tiếp dưới nút, dùng được trên thiết bị chạm.
- Thông báo đầy đội và migration lấy giới hạn từ `WorkerRole.LIMITS`.
- Giữ `patrol_index` để đọc save cũ nhưng ngừng tăng bộ đếm góc tuần tra đã không còn được dùng. Các checkpoint có thể ngắt đi dạo, khiến bộ đếm thừa này lệch dù vật tư/tiền/thời gian làm việc giống nhau; đường đi hiện tại dùng ID + vị trí.
- Thêm đo CPU scheduler/commit/navigation theo cờ `profiling` (mặc định tắt), fixture benchmark có ID ổn định, thứ tự chạy đảo ngược ở lượt hai, thống kê ô thành công và cơ cấu hoạt động.
- Thêm runner `scripts/run_worker_upgrades_qa.py`: giới hạn thời gian, chọn nhóm test, chạy tuần tự renderer, trả mã lỗi và lưu log/summary. Windows chạy engine trực tiếp để timeout không bỏ lại tiến trình con của console launcher.

Các test mới kiểm tra thời gian làm việc online sau khi đến muộn, mức 0/1/5/10, bị dịch chuyển/giữ chỗ/player can thiệp khi commit, khôi phục ở từng cursor gieo 1–8 và dọn nhiều ô prepared bị chặn. Test chất lượng cố định pest/weed rolls để đo watering/root độc lập với bệnh ngẫu nhiên.

## Kiểm chứng

Artifact tái tạo nằm trong `.godot/worker-upgrades-verified/`; lượt rà ban đầu ở `.godot/worker-upgrades-final/` và `.godot/worker-upgrades-render/`. Replay sau sửa cuối ở `.godot/worker-upgrades-replay-final/`; chẩn đoán trước sửa ở `.godot/worker-upgrades-replay/`.

| Nhóm | Kết quả |
|---|---|
| Nâng cấp và UI (sau sửa cuối) | 31/31 pass |
| Worker, care, kho, navigation, offline (lượt rà chính) | 109/109 pass |
| Crop team và automation (chạy lại sau sửa prepared) | 31/31 pass; là tập con của nhóm 109 ở trên |
| Crop quality | 7/7 pass |
| Farm health world | 26/26 pass |
| Persistence bootstrap | 3/3 pass |
| Worker performance | 5/5 pass |
| Save repository | 21/21 pass |
| Đi dạo sau sửa legacy cursor | 9/9 pass (gồm test mới giữ cursor save cũ) |
| Replay kho 48 giờ sau sửa cuối | 1/1 pass, 3.298 assertion |
| Supply storage flow của player | 6/12 pass |
| Farming area của player | 2/6 pass |

Nhóm kho/persistence mở rộng tổng cộng 70/80 pass, có 10 lỗi ở hai suite player trong bảng. Các lỗi gồm vùng 6×6 chỉ tác động 25/30 ô thay vì 36, số hạt còn lại và API action không có `changed` trong nhánh bị từ chối. Chưa sửa các fixture/vùng player này hoặc xác nhận toàn bộ trên HEAD riêng. Runner giữ mã thoát khác 0 khi có lỗi; không che kết quả bằng summary xanh.

UI native đã render ở 1280×720 và 844×390; đã xem cả hai ảnh. Hai lượt mua bằng `InputEventScreenTouch` (kỹ năng và thu hoạch sau khi cuộn) thành công, có 3 actor và `SaveManager.adapter == null`.

Lint trước/sau có cùng 2 lỗi tài nguyên và 5 cảnh báo, không có lỗi inference/parse được linter phát hiện. Hai tài nguyên thiếu có sẵn trước đợt sửa: `assets/Buildings/pet_shop_pigpen.png` và `assets/Buildings/Shops/crop_flower_shop_red.png`. Không tuyên bố toàn dự án lint sạch.

Suite tổng quát `test_world_persistence.gd` hiện chỉ pass 16/32. Ví dụ fixture kỳ vọng 970 xu sau mua nhưng cấu hình hiện tại cho 9460, và kỳ vọng 9 hạt thay vì 21; còn các lỗi giả định vật nuôi/migration/flower. Chưa chứng minh toàn bộ là lỗi nền qua checkout HEAD riêng; không coi đây là suite đã pass hoặc sửa các hệ thống đó trong task worker. Ma trận lưu trữ 7 ngày mở rộng đã dừng ở lượt rà để tách khỏi QA tính năng.

Replay kho 48 giờ dùng cùng helper so sánh đệ quy đã có trong suite: dữ liệu rời rạc so chính xác, timestamp/đại lượng float dùng tolerance được khai báo theo đường dẫn (1 µs cho timestamp). Phép `assert_eq` cả dictionary worker trước đó báo sai khác không chỉ ra trường; helper này giữ so sánh mọi trường và chẩn đoán đúng đường dẫn.

Chẩn đoán chỉ ra sai khác **rời rạc** ở `workers.rows[0].patrol_index`, không phải sai số float. Đã sửa mutation bộ đếm legacy trong production; không bỏ trường khỏi phép so sánh.

Runner lượt `verified` giữ lại kết quả replay lỗi trước sửa trong summary để lưu bằng chứng. Kết quả thay thế cho nhóm đó là `worker-upgrades-replay-final/summary.json` (cả `stroll` và `storage-offline` đều exit 0). UI và cả hai benchmark native đều exit 0.

## Cách đo

Godot 4.7.1 Mono; renderer thật theo cấu hình dự án. Mỗi cấu hình warm-up ít nhất 120 frame và 3 giây, đo fixture 20 giây / bản sao profile 60 giây, hai lượt tuần tự; lượt hai đảo thứ tự. Fixture có cùng đất, hạt, cây chín/cần tưới, thời tiết và kho. Baseline 15 actor được tạo riêng trong benchmark trên mã hiện tại; production hire và validator vẫn giới hạn 3.

Các cột throughput tính **ô thao tác thành công** (cuốc + gieo + tưới + thu), có thể gồm nhiều thao tác trên cùng một ô. Không phải số cây thu hoạch hay thu nhập/phút. Activity được lấy mẫu theo thời gian actor: di chuyển tới task, chăm sóc, làm ruộng và nghỉ/patrol.

Benchmark profile chỉ đọc primary và backup, validate checksum/schema, restore bản sao vào world con; không bind SaveManager. Ghi lại hash cả hai file trước/sau. Không dùng số liệu fixture cũ ngày 01/11 thay cho phép đo này.

### Fixture render, hai lượt

Forward+ / D3D12, NVIDIA GeForce RTX 3050 Ti Laptop GPU. Mỗi khoảng trong bảng là min–max của hai lượt; không phải khoảng tin cậy thống kê.

| Đội / cấp kỹ năng / vùng | FPS | Frame P95 (ms) | Frame P99 (ms) | Ô thao tác/phút |
|---|---:|---:|---:|---:|
| 15 / 0 / 1×1 | 167,7–170,9 | 8,38–8,79 | 9,61–10,37 | 390,0–396,0 |
| 3 / 0 / 1×1 | 202,2–221,0 | 5,80–6,65 | 7,16–7,94 | 72,0 |
| 3 / 5 / 2×2 | 191,8–205,6 | 6,80–7,39 | 8,08–9,21 | 186,0 |
| 3 / 10 / 3×3 | 190,0–195,4 | 7,46–7,83 | 8,88–9,52 | 621,0–653,8 |

Trung bình mẫu: đội 3 tối đa khoảng 637 ô thao tác/phút so với 393 ở baseline 15, tức +62% trên fixture này. Đây là tổng thao tác ruộng, không phải +62% doanh thu. Đội 3 chưa nâng giảm mạnh năng suất dù FPS cao hơn.

Trong 20 giây fixture, đội 3 tối đa dùng scheduler 732–773 ms, gồm commit 217,54–231,24 ms; navigation 3,06–3,35 ms. Tỷ lệ di chuyển 12,0–12,3%, chăm sóc 31,3–32,5%. Baseline 15 dùng scheduler 2.405–2.407 ms và navigation 4,33–4,50 ms.

Đội 3 tối đa: commit đơn lớn nhất 7,30–7,40 ms; spike frame lớn nhất 26,53–40,20 ms. Baseline 15 có một spike commit 103,74 ms / frame 122,78 ms ở lượt đầu, lượt hai commit tối đa 9,84 ms / frame 32,97 ms. Không loại các spike khỏi báo cáo. Warm-up ngắn không chứng minh mọi nhánh hiệu ứng/tài nguyên đều đã được làm nóng.

### Bản sao save thật, hai lượt 60 giây

589 cây ruộng, 38 vật nuôi. Cùng camera/profile, không dùng preset nhẹ hơn.

| Đội | FPS | Frame P95 (ms) | Frame P99 (ms) | Thời gian di chuyển |
|---|---:|---:|---:|---:|
| 15, mức gốc | 53,9–54,1 | 28,82–28,83 | 32,82–33,20 | 90,0–91,5% |
| 3, kỹ năng 10 / vùng 3×3 | 67,5–68,9 | 19,54–20,19 | 23,25–26,01 | 83,3–83,5% |

CPU tích lũy trong mỗi cửa sổ 60 giây:

| Đội | Scheduler (ms) | Navigation (ms) | Commit (ms) |
|---|---:|---:|---:|
| 15 | 4.269–4.956 | 5.426–5.432 | 12,03–14,74 |
| 3 tối đa | 1.012–1.024 | 1.307–1.621 | 15,72–16,05 |

Scheduler bao gồm thời gian commit; không cộng hai cột đó để ước lượng tổng. Các monitor `Performance` được lưu kèm JSON nhưng có thể lặp mẫu từ chu kỳ cập nhật monitor; bảng CPU dùng bộ đếm trực tiếp trong code.

Cả bốn cửa sổ ghi nhận 6 lần bổ sung thức ăn và 1 lần bổ sung nước, **0 thao tác ruộng hoàn thành**. Vì vậy phép đo này chứng minh giảm chi phí actor/navigation trên save hiện tại, chưa chứng minh đội 3 đã chăm ổn định toàn bộ 589 cây qua nhiều vụ. Không ngoại suy throughput fixture sang ruộng thật.

Primary revision 3216 và backup revision 3215 đều đọc/validate thành công. JSON xác nhận `save_bound: false`, `save_unchanged: true`; hash của cả hai file không đổi. Không mua nâng cấp hay thuê người trong profile đang chơi.

## Giới hạn và phần chưa chốt

- Batch commit theo từng ô, có cursor và nhả khóa giữa các sự kiện; save/load không lặp trừ hạt hoặc tạo cây. Ngân sách scheduler vẫn 2.000 µs/frame, navigation vẫn dùng ngân sách chung. Một giao dịch ô riêng lẻ có thể vượt 2 ms; chia batch không bảo đảm loại hết spike.
- Cửa sổ 20 giây có thể còn đang đầu tư hạt vào cây chưa chín. Giá trị sản lượng ruộng trừ giá thay thế vật tư và lương phân bổ chỉ là quan sát ngắn hạn, chưa phải lợi nhuận đã bán. Không gồm doanh thu vườn cây/chuồng, vốn nâng cấp hoặc hoàn vốn.
- Do đó giữ giá thử 1.274.000 xu hoàn thiện, chưa kết luận “đầu tư vừa” đã cân bằng. Cần đo dài qua nhiều vụ, bán hàng và vật tư chăm sóc trước khi chốt giá.
- FPS đo trên phần cứng/camera hiện tại; không suy ra mọi save/thiết bị sẽ tương tự. Dữ liệu render, cây và vật nuôi có thể vẫn tạo chi phí sau khi giảm đội.

## Chạy lại

```powershell
& C:/Users/faker/AppData/Local/Python/pythoncore-3.14-64/python.exe scripts/run_worker_upgrades_qa.py --godot C:/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe --render --profile
```

Mặc định gồm worker, nâng cấp/UI, kho, repository, persistence bootstrap và replay kho 48 giờ; hiện có các lỗi suite player nêu trên. `--extended` thêm fixture world persistence cũ và toàn bộ ma trận lưu trữ dài. `--groups` chọn nhóm cần chạy lại; `--groups none --render --profile` chỉ chạy phần native UI/benchmark. Runner không ghi profile đang chơi.

## Sửa gián đoạn khi chữa vật nuôi đang di chuyển

Worker giữ bệnh nhân đứng yên từ lúc focus tác vụ `cure_animal`, kể cả trong lúc tiếp cận. Quyền giữ thuộc worker và được kiểm tra theo task hiện tại; độc lập với focus trạng thái của player. Chữa xong, player chữa trước, hủy/đổi task, pause, nghỉ việc, timeout hoặc xóa worker đều nhả quyền giữ. Worker restore nhả owner cũ và lấy lại focus theo task được khôi phục.

`AnimalBehaviourComponent` tái dùng nhánh đứng yên/idle hiện có; dừng tuyến đi/ăn và nhả reservation máng, vẫn giữ các đồng hồ nhu cầu, tăng trưởng và sản xuất. Owner dùng WeakRef cùng điều kiện hiệu lực để không để lại vật nuôi bị khóa. Không lưu focus vào DTO hoặc thay schema.

Kiểm chứng Godot 4.7.1: **84 test liên quan pass**: care improvements 14/14, animal behaviour 10/10, animal feeding 18/18, worker upgrades 16/16, farm health world 26/26. Test mới dùng physics online thật, tái hiện bệnh nhân đang đi, xác nhận đứng yên suốt quá trình chữa và chỉ mất một thuốc; có test chồng focus player, pause/resume, đổi bệnh nhân, nghỉ việc, xóa worker, timeout và restore. Test vịt tạo riêng trong ao xác nhận không tự đi lên bờ khi đang được giữ, giữ nguyên trứng và tiếp tục tuyến lên bờ sau nhả.

Log ở `.godot/worker-animal-focus-tests-final.log` và `.godot/worker-animal-focus-regressions.log`. Suite `test_waterfowl.gd` cũ vẫn có 11 test lỗi và 1 test không assertion do kỳ vọng 11 con vật được đặt sẵn (`Duck_3`, `Goose_1`...), trong khi scene hiện không có chúng. Không coi suite đó đã pass. Lint không phát sinh chẩn đoán mới; vẫn 2 lỗi tài nguyên và 5 cảnh báo nền đã nêu.
