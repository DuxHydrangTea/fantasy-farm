# Baseline hiệu năng sơ bộ — 22/10/2026

> Báo cáo cũ dùng bản export và headless, chưa đúng phạm vi đo dự án đang dev. Dùng [đánh giá native dev có render](dev_performance_baseline_2026-10-22.md) cho yêu cầu hiện tại.

Đã đo tự động; chưa tối ưu code. Chỉ hoàn tất phép đo CPU/physics/bộ nhớ cho cảnh đứng yên. Chưa hoàn tất bước 0 của kế hoạch tối ưu.

## Môi trường và bản đo

- CPU: Intel Core i3-12100; GPU do trình duyệt báo: Intel UHD Graphics 730, Mesa/ANGLE.
- Linux; Chrome 154 trong trình duyệt tích hợp Codex; canvas 626 × 906, DPR 1.
- Godot 4.7.2; bản Web release, single thread, logical viewport 1920 × 1080.
- Dùng đúng `.dist/index.pck` đã xuất trước các chỉnh sửa mới trong `world/main_world.tscn`; không sửa scene hay gameplay để đo.
- Tình huống: đứng yên ở vị trí bắt đầu. Chưa cố định seed cho các đối tượng ngẫu nhiên; chưa instrument mức zoom.
- Thời điểm ghi báo cáo: 2026-10-22T09:13:22.345107+07:00.

PCK SHA-256: `44f923a0b11f2bfadea09e5a84024eb6eb712e0e31709a3650d047351a1ecacf`.

## CPU / physics / bộ nhớ — headless

Chạy Godot native debug với chính PCK release ở trên, renderer dummy, thư mục user data tạm riêng cho từng lượt. Mỗi lượt làm nóng 600 frame rồi đo 10 giây theo thời gian thực; không dùng `--fixed-fps`. Thu Performance monitor mỗi 6 frame.

| Lượt | Process TB (ms) | Process P95 (ms) | Physics TB (ms) | Physics P95 (ms) | Bộ nhớ tối đa (MiB) | Node |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 1.74 | 4.53 | 3.93 | 9.58 | 167.82 | 3083 |
| 2 | 1.06 | 2.62 | 2.37 | 5.75 | 167.78 | 3083 |
| 3 | 1.18 | 3.37 | 4.46 | 9.14 | 167.79 | 3083 |

Cả 3 lượt hoàn tất; không có lỗi runtime, không có finding từ runner; số node giữ ở 3.083, orphan node bằng 0 trong mẫu. Mỗi lượt vẫn có 24 cảnh báo GDScript khi nạp code với debugger; chưa sửa các cảnh báo này. Một lượt thử trước đó bị loại vì monitor physics còn giữ giá trị từ giai đoạn khởi tạo; các lượt trong bảng đã tăng thời gian làm nóng.

**Cách đọc:** process/physics là monitor của engine native, không phải thời gian từng script. Engine làm mới các monitor thời gian theo chu kỳ; P95 trong bảng là phân vị của các giá trị monitor được lấy mẫu, không phải P95 CPU của từng frame. Không cộng hai cột để suy ra thời gian frame hay FPS. Bộ nhớ là bộ nhớ allocator mà Godot theo dõi, tính bằng MiB, không phải toàn bộ RAM tiến trình, trình duyệt hoặc GPU.

Renderer dummy không cho biết chi phí GPU/rendering, draw calls hoặc FPS khi chơi. Vòng lặp headless nhanh không chứng minh bản web đạt cùng FPS. Quan sát 30 giây chưa đủ kết luận về rò rỉ bộ nhớ.

## Thử đo độ mượt web — không dùng làm baseline FPS game

Sau 10 giây làm nóng, đo khoảng cách giữa các callback `requestAnimationFrame` trong 3 lượt × 20 giây. Thu cả Long Task API và thay đổi `document.hidden`. Đo lần lượt game và trang WebGL2 trống, cùng viewport/trình duyệt, không chạy đồng thời.

| Lượt | FPS callback game | P95 khoảng cách game (ms) | FPS callback WebGL trống |
|---|---:|---:|---:|
| 1 | 8.07 | 1000.99 | 1.00 |
| 2 | 7.25 | 1000.83 | 1.00 |
| 3 | 0.95 | 1001.86 | 1.00 |

Dù `document.hidden` không chuyển sang true, trang đối chứng cũng chỉ nhận khoảng 1 callback/giây và không có long task. Điều này cho thấy môi trường/scheduling trình duyệt đang làm sai lệch phép đo FPS. Game có ghi nhận long task khoảng 1 giây, nhưng chưa thể quy nguyên nhân cho code game từ phép đo này. **Không dùng các giá trị FPS web ở trên để đánh giá game hoặc chứng minh lợi ích tối ưu.**

## Kết luận và phần còn thiếu

- Có thể tự đo CPU/physics/bộ nhớ và lưu số liệu lặp lại. Cảnh idle native hiện có process trung bình 1,06–1,74 ms; physics trung bình 2,37–4,46 ms; bộ nhớ theo dõi tối đa khoảng 168 MiB.
- Chưa xác định bottleneck theo từng hàm; chưa có cơ sở chọn weather, camera, UI hay navigation làm nguyên nhân chính.
- Cần môi trường trình duyệt có nhịp vẽ ổn định để lấy baseline web hợp lệ và profiler có render để đo GPU.
- Chưa đo đi quanh map, zoom, chuyển thời tiết, nhiều cây/vật nuôi, thu hoạch hoặc autosave. Chưa có so sánh trước/sau vì chưa thay đổi tối ưu.

Dữ liệu và cấu hình từng lượt: [performance_baseline_2026-10-22.json](performance_baseline_2026-10-22.json). Các file trang đo nằm trong `.dist/benchmark.html`, `.dist/benchmark-control.html`, `.dist/benchmark.js`; chúng là công cụ chẩn đoán cục bộ, không nằm trong ZIP HTML5 đã đóng gói trước đó.

Có thể tái chạy phép đo headless bằng script hiện có, giữ nguyên cấu hình trong JSON báo cáo và truyền `--main-pack` để nạp đúng PCK. Các tham số chính là `seconds=10`, `settle_frames=600`, `sample_interval=6`, `mode=real_time`, `profile=true`, `fuzz=false`.
