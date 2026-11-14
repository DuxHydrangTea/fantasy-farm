# Kế hoạch refactor kiến trúc Fantasy Farm

Mục tiêu là đọc được luồng gameplay từ điểm gọi đến nơi sở hữu trạng thái và thêm hành vi mà chỉ cần sửa các hệ thống liên quan. Phạm vi đợt này gồm farming, lập lịch worker và các điểm kết nối với lưu game. Kết quả mỗi giai đoạn được ghi vào [nhật ký kiểm chứng](architecture_refactor_results.md).

## Giai đoạn 0 — Đo trước khi sửa

- Chạy GUT trên Godot 4.7.2 cho farming, thời tiết, lâm nghiệp, worker và persistence. Dùng thư mục dữ liệu thử nghiệm riêng.
- Chạy kiểm tra tĩnh GDScript và tham chiếu scene/resource. Ghi phiên bản engine, phạm vi chạy và lỗi có sẵn để đối chiếu từng giai đoạn.

## Giai đoạn 1 — Khai báo rõ phụ thuộc của farming

- `FarmWorld` nối việc đồng bộ thời tiết và truy cập `TreePlantation` ở chỗ khởi tạo. Farming và preview ô đất dùng chung truy vấn mục tiêu cây.
- Giữ thứ tự đồng bộ thời tiết trước khi kiểm tra tưới, quyền đào của người chơi và cách hoạt động của `FarmingController` trong fixture độc lập.
- Kiểm chứng bằng GUT cho farming, thao tác theo vùng, thời tiết, lâm nghiệp và soil focus.

## Giai đoạn 2 — Để worker phản ứng với việc xử lý cây

- Farming phát thông báo có kiểu sau khi trạng thái sâu/cỏ đã cập nhật. Worker tự yêu cầu quét lại. Bên gọi từ worker truyền tùy chọn hiệu ứng theo chế độ mô phỏng.
- Đối chiếu thứ tự cập nhật, quét lại, hiệu ứng và tiêu hao thuốc. Kiểm tra người chơi, worker đang chạy và mô phỏng offline.

## Giai đoạn 3 — Làm rõ luồng chọn việc và kết nối save

- Tách phần lọc và chọn ứng viên ra khỏi `advance()`, dùng lại `WorkerRole` và `WorkerWorldBridge`. Giữ thứ tự ứng viên, giữ chỗ, ngân sách mỗi frame và điểm tiếp tục khi hết ngân sách.
- Cho `WorldStateAdapter` gọi phương thức có mục đích rõ trên `WorkerService` để kiểm tra vị trí task và đồng bộ sau khôi phục. Giữ schema v41, khóa dữ liệu và ID hiện có.
- Kiểm chứng bằng các ca worker, kho, save/load và đối chiếu mô phỏng offline từ cùng checkpoint.

## Giai đoạn 4 — Cập nhật tài liệu và kiểm tra tích hợp

- Ghi rõ hệ thống sở hữu trạng thái, chỗ nối phụ thuộc và đường đi của thao tác tưới hoặc xử lý cây. Liên kết với tài liệu runtime hiện có.
- Chạy lại nhóm test liên quan và smoke test scene nông trại. Kiểm tra diff cuối cùng để phát hiện thay đổi ngoài phạm vi.

## Giai đoạn 5 — Tách bộ lập lịch khỏi dịch vụ worker

- Chuyển vòng sự kiện, ngân sách mỗi frame, vị trí tiếp tục và logic giao việc sang `WorkerScheduler`. Giữ `WorkerService` làm điểm gọi cho gameplay, lưu và khôi phục.
- Trong scheduler, tách tiến dòng thời gian, xử lý một worker, hoàn tất việc đến hạn và giao việc mới. Gom khôi phục đồng hồ, khóa và deadline về một điểm sau khi chạy scheduler.
- Chạy cùng nhóm GUT trước và sau, bao gồm giữ chỗ, giao việc khi hết ngân sách, kho, replay offline và save. Đối chiếu cách tiến timestamp, thứ tự xử lý và điểm tiếp tục với luồng cũ.

## Giai đoạn 6 — Làm rõ ranh giới giữa scheduler và service

- Để `WorkerService.advance()` quản lý khóa mô phỏng và khôi phục đồng hồ. Truyền `FarmClock` và `WeatherSchedule` khi gọi scheduler.
- Để service chuẩn bị mốc mô phỏng và trả lương qua các phương thức đặt tên theo hành vi. Scheduler giữ vòng tiến thời gian, giới hạn mỗi frame và quyết định giao việc.
- Đối chiếu cùng nhóm GUT trước và sau, tập trung vào thứ tự đồng bộ world, thông báo pickup, trả lương qua mốc bình minh và tiếp tục đúng worker khi hết ngân sách.

## Kiểm chứng bổ sung — xử lý lỗi có sẵn

- Điều tra replay 7 ngày từ cùng checkpoint, xác định lần giao việc đầu tiên bị lệch, rồi thêm test cho ranh giới gây lỗi. Không nới tolerance để bỏ qua sai lệch.
- Phân biệt thông báo đồng bộ offline với thay đổi gameplay; bảo toàn task tuần tra đã đến hạn trước khi quét lại.
- Sửa đường dẫn tài nguyên và script sinh tài nguyên, bỏ UID lỗi thời. Xác minh scene cũ vẫn load được và không cần loại khỏi export.
- Sửa fixture stress theo các ô thực sự canh tác được trên bản đồ hiện tại, chạy đủ cả 48 giờ và 7 ngày. Chạy lại nhiều lượt ID ngẫu nhiên, lint, smoke và Web release; ghi kết quả trong nhật ký kiểm chứng.

## Cách chốt từng giai đoạn

1. Đọc diff và so với mục tiêu của giai đoạn. Lần theo các điểm gọi thực tế, điều kiện thành công/thất bại và thứ tự thay đổi trạng thái.
2. Chạy kiểm tra tĩnh và GUT phù hợp trước khi báo cáo. Khi kết quả lệch, tái hiện và sửa hồi quy do đợt này gây ra. Đối chiếu lỗi có sẵn bằng cùng phiên bản engine và cùng lệnh kiểm tra.
3. Cập nhật một mục trong [nhật ký kiểm chứng](architecture_refactor_results.md) với thay đổi, kiểm tra logic, kết quả test, lỗi còn tồn tại và trạng thái. Ghi hoàn thành sau khi đã xác minh hành vi trong phạm vi giai đoạn.

Các skill Gamedev được dùng theo phần việc. `godot-nodes-scenes` và `godot-gdscript` cho wiring và kiểu dữ liệu, `godot-signals-groups` cho thông báo sau cập nhật, `save-systems` và `godot-gdscript-headless-testing` cho xác minh GUT và tương thích save.
