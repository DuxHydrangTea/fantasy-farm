# Kết quả sửa save và tối ưu đợt đầu — 22/10/2026

Đã sửa lỗi save tổ ong và triển khai weather/camera/UI nghỉ khi rảnh trên source dev hiện tại. Không thay đổi physics tick, navigation, tiến độ tăng trưởng hoặc giao dịch vật phẩm. Chưa đưa ra phần trăm tăng FPS vì môi trường đo xuất hiện các nhịp dừng khoảng 1 giây cả ở source cũ lẫn mới.

## Thay đổi đã hoàn tất

- **Save tổ ong:** `Beehive.capture()` tạo khóa `"id"` và `"position"` bằng String. Giữ nguyên validation primitive, revision guard và backup trong repository.
- **Weather:** ngừng `_process` sau khi fade về nắng hoàn tất; chuyển thời tiết đánh thức lại renderer. Fade out/in, audio và mô phỏng thời tiết vẫn hoạt động. Có test chuyển qua mưa → mây → gió → nắng và thay tween giữa chừng.
- **Camera:** nội suy dừng khi đạt đích; wheel input và resize đánh thức lại khi cần. Timer 100 ms kiểm tra thay đổi giới hạn camera/min/max zoom khi rảnh.
- **Hotbar:** tên/tooltip cập nhật theo selection/inventory, dịch và signal feedback. Callback chỉ kiểm tra đồng hồ khi có feedback chờ hết hạn; ưu tiên interaction → placement → booster được giữ. Đổi slot, hết hạn không cần input, hủy tương tác và dịch trực tiếp có regression test.
- **UI scale:** dùng resize event; bỏ callback GDScript mỗi frame, giữ Timer 100 ms chỉ kiểm tra thay đổi stretch/DPI đã cache. Các thao tác trên cửa sổ nhỏ và tọa độ click đã qua test.

## Save thực tế đã được xác nhận

Chạy kiểm tra chức năng với bản sao profile hiện tại, không dùng số liệu headless để đánh giá FPS:

| Điều kiện | Kết quả |
|---|---|
| Ghi và đọc lại | Thành công |
| Revision | 55 → 56 |
| Backup | Hợp lệ, revision 55 |
| Tổ ong | Đủ 5/5 sau đọc lại |
| Save gốc | SHA-256 không đổi |

Test hồi quy mới từng thất bại trên code cũ với `Save files accept only primitive data.`; sau sửa đã qua đường ghi async, đọc lại hai revision và kiểm tra nội dung backup.

## Kiểm tra

- Lượt full: **514 test**, 511 qua; 3 failure được đối chiếu và tái hiện trên source trước thay đổi.
- Nguyên nhân 3 test cũ: bounds/zoom vẫn dựa trên map 1920×1080; vách ngăn “không thể đi qua” cao 1080 vẫn để lại lối vòng trên map cao 1696. Đã sửa fixture/kỳ vọng theo camera limits được khai báo, không sửa geometry map.
- Chạy lại toàn bộ player + hotbar: **46/46 test qua**, gồm 3 test vừa sửa và test feedback/translation mới. Các suite save, weather, localization, small-window UI và các suite còn lại đã qua ở lượt full.
- Linter trước/sau: **0 lỗi**, giữ nguyên 11 cảnh báo cũ. `git diff --check` qua.
- Giữ nguyên chỉnh sửa scene `world/main_world.tscn` của người dùng.

## Đo lại native dev và giới hạn kết luận

Đã tạo một bản source trước thay đổi trong thư mục tạm: chỉ hoàn nguyên 8 script của đợt tối ưu bằng nội dung HEAD, còn scene hiện tại được giữ nguyên. Hai phía dùng cùng bản sao save, clock start, seed, renderer Forward+/Vulkan, cửa sổ 1280×720 và zoom 4×. Có 3 lượt idle trước và 3 lượt sau.

Lượt đầu bị nhiễu: một mẫu idle có nhân vật di chuyển và các nhịp dừng ~1 giây. Đã thử lại với đầu vào desktop bị chặn và callback MCP tạm nghỉ riêng trong benchmark. Nhân vật đứng yên ở cả hai phía, nhưng các nhịp dừng vẫn xuất hiện ngay cả ở source cũ. Không xác định được nguyên nhân từ các phép đo này.

| Lượt | FPS trước | FPS sau | Frame P95 trước (ms) | Frame P95 sau (ms) |
|---|---:|---:|---:|---:|
| 1 | 229.4 | 287.5 | 5.142 | 3.276 |
| 2 | 212.6 | 219.6 | 3.616 | 4.057 |
| 3 | 219.2 | 260.3 | 3.263 | 4.970 |

Các giá trị FPS trên bị ảnh hưởng mạnh bởi stall và không đủ để định lượng lợi ích tối ưu. Phân vị frame time có chồng lấp; không dùng bảng để khẳng định mức tăng. Lượt VSync tiếp theo cũng bị giới hạn gần 1 FPS và bị loại khỏi kết luận hiệu năng.

Điều đã xác nhận: các callback weather/camera/hotbar ngừng chạy khi rảnh và đánh thức đúng trong test; save tổ ong đã ghi thành công. Chưa xác nhận mức tiết kiệm CPU/GPU/FPS ổn định trên máy thử. **Không tuyên bố các tối ưu này đã xử lý hết frame spike.**

Bước tiếp theo hợp lý vẫn là profile riêng physics/tương tác và tìm nguồn spike trong phiên dev ổn định; chưa có thay đổi registry, navigation, culling hoặc pooling.

Dữ liệu và cấu hình: [JSON kết quả](performance_optimization_results_2026-10-22.json). Baseline lịch sử: [đánh giá dev trước thay đổi](dev_performance_baseline_2026-10-22.md). Bộ đo: [profile_dev.gd](/home/dungnguyen/Projects/test-js/tests/performance/profile_dev.gd).
