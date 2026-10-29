# Kế hoạch mở rộng đội trồng ruộng lên 5 nhân công

Ngày lập: 29/10/2026. Trạng thái: đã triển khai. Xem [báo cáo kiểm chứng](crop_team_2026-10-29/README.md).

## Mục tiêu và quy tắc đề xuất

- Cho thuê từ 0 đến 5 nhân công trồng ruộng sau khi đạt điều kiện mở khóa hiện tại: ít nhất 12 cột đất.
- Mỗi lần bấm thuê thêm một người. Người nghỉ do thiếu lương vẫn chiếm một chỗ; người đã sa thải không chiếm chỗ thuê.
- Cả đội làm trên ruộng đã mở khóa, tự chọn việc theo ưu tiên và khoảng cách. Không yêu cầu người chơi chia khu.
- Gieo tự động, bón tự động và tạm dừng là cài đặt chung của đội. Thao tác trên một nhân công mở bảng đội và chọn sẵn người đó.
- Lương đề xuất giữ 2.800 xu/người/ngày, trả tại bình minh; 5 người là 14.000 xu/ngày. Đây là mốc thử nghiệm để đo cân bằng.
- Ưu đãi ca đầu miễn phí chỉ một lần cho vai trò trồng trọt trong profile. Người thứ hai trở đi trả lương ngày thuê; thuê lại không cấp lại ưu đãi.
- Thiếu tiền trả theo thứ tự thuê ổn định; chỉ những người chưa được trả mới nghỉ. Tạm dừng đội vẫn tính lương như hiện tại.
- Giới hạn chăn nuôi và vườn cây tiếp tục là một người mỗi vai. Mở dần số chỗ theo diện tích là phương án cân bằng về sau, chưa thuộc bản này.

## Căn cứ từ mã hiện tại

- `WorkerService.record(role)` trả về bản ghi đầu tiên; `actors` lưu theo vai trò. Spawn, di chuyển, xử lý kẹt, giỏ, capture và restore đều cần chuyển sang định danh nhân công.
- `WorkerBehaviourComponent._step_work()` tìm công việc bằng vai trò; giao diện cũng thuê và sa thải theo vai trò.
- `CropAutomationState.prepared` chỉ giữ một ô vừa xới. `CropWorkerPolicy.planting_task()` giới hạn một ô chờ gieo, có thể làm đội 5 người bị tuần tự hóa.
- `WorkerSaveSchema.valid()` giới hạn tổng 3 bản ghi và cấm lặp vai trò. `SaveSchema` còn kiểm tra ô chờ gieo theo diện tích đã mở.
- Scheduler hiện đã có timeline chung và thứ tự thuê. Mở rộng trên nền này để giữ tính xác định khi offline và khi tải lại.

Các điểm trên được đối chiếu graph với mã nguồn; metadata coverage không ghi nhận khoảng thiếu tại các file đã kiểm tra. Đây là kiểm tra theo phạm vi tính năng, không phải kiểm toán toàn bộ dự án.

## M1 — Định danh và vòng đời từng nhân công

Phạm vi: `worker_service.gd`, `worker_role.gd`, `worker_actor.gd`, `worker_behaviour_component.gd`.

- Dùng ID có sẵn làm khóa của actor và truy xuất bản ghi. Tách truy vấn một người theo ID khỏi truy vấn danh sách theo vai trò.
- Khai báo giới hạn vai trò tại một nơi: crop 5, orchard 1, ranch 1. Kiểm tra trong API thuê, không chỉ khóa nút UI.
- Thuê, sa thải, báo kẹt, lấy giỏ và lưu vị trí phải nhắm đúng ID. Ưu tiên tái sử dụng bản ghi đã sa thải để danh sách không tăng vô hạn.
- Các thông báo theo vai trò như thay đổi kho, cây và đất phải đánh thức mọi nhân công liên quan.
- Định danh từng người trên badge và bảng đội bằng số thứ tự ổn định. Chọn điểm xuất hiện gần nhà làm việc còn trống, tránh chồng 5 actor tại một điểm.

Đầu ra: 5 người có trạng thái độc lập; thuê người thứ sáu bị từ chối; sa thải đúng người và có thể thuê bù.

## M2 — Điều phối chung và chống nhận trùng

Phạm vi: `worker_service.gd`, `worker_world_bridge.gd`, `crop_worker_policy.gd`, `crop_automation_state.gd`; thêm `crop_work_assignments.gd` nếu cần tách quản lý phân công.

- Giữ chỗ theo ô đất hoặc pickup ngay lúc giao việc. Một ô chỉ có một người phụ trách, kể cả hai loại việc khác nhau như tưới và bón.
- Lọc mục tiêu đã có người nhận trước khi chọn ứng viên tốt nhất. Với gieo trồng, phải tiếp tục tìm ô khác thay vì trả lại cùng một ô rồi đứng chờ.
- Chuyển ô chờ gieo thành trạng thái theo từng nhân công; mỗi người giữ tối đa một ô vừa xới. Lịch sử cây và thứ tự luân phiên ô vẫn thuộc cả đội.
- Ưu tiên gieo nốt ô đã chuẩn bị, giữ quy tắc ưu tiên công việc hiện có; không cho nhiều người liên tục xới thêm mà bỏ quên gieo.
- Giữ chỗ số hạt/phân cần dùng tại bộ điều phối; chỉ trừ kho khi hành động thành công. Trước commit vẫn xác thực lại vật tư, cây, đất và sức chứa kho vì người chơi có thể can thiệp.
- Giải phóng phân công và vật tư giữ chỗ khi hoàn thành, hủy, sa thải, nghỉ lương, tạm dừng hoặc mục tiêu mất hiệu lực. Khi tiếp tục, kiểm tra và nhận lại việc trước khi làm.
- Phân biệt kẹt đường riêng của một người với mục tiêu thực sự không hợp lệ; một người kẹt không được khiến cả đội bỏ ô trong 120 giây.
- Giữ thứ tự xử lý ổn định khi nhiều sự kiện trùng timestamp. Tránh quét lại toàn bộ ruộng cho từng người ở mỗi frame; chia sẻ dữ liệu ứng viên trong một lượt điều phối khi còn hợp lệ.

Đầu ra: đội chia việc được trên nhiều ô, không thu hai lần, không dùng vượt vật tư, không giữ chỗ vĩnh viễn.

## M3 — Save, migration và tiến độ offline

Phạm vi: `worker_save_schema.gd`, `save_schema.gd`, capture/restore trong `worker_service.gd`, serialization trong `crop_automation_state.gd`.

- Tăng phiên bản save và viết migration rõ ràng cho trạng thái ô chờ gieo theo người. Giữ ID, lương, giỏ cũ, công việc dở và cờ ưu đãi đã dùng.
- Save cũ có một người vẫn tải thành một người; không tự thuê thêm hay cấp lại ca miễn phí. Gắn ô chuẩn bị cũ cho nhân công crop hiện có; xử lý trường hợp không có người tương ứng.
- Validation đếm tối đa 5 bản ghi crop và một bản ghi mỗi vai khác; tổng tối đa 7, bao gồm bản ghi được giữ lại sau sa thải. Tiếp tục cấm trùng ID và thứ tự thuê.
- Kiểm tra mọi ô chuẩn bị theo đất đã mở, chủ sở hữu và tính duy nhất; trạng thái nghỉ không được giữ phân công đang hoạt động.
- Tái dựng phân công và vật tư giữ chỗ từ nhiệm vụ hợp lệ khi tải, theo thứ tự xác định. Không lưu thêm bản sao cache có thể lệch với nhiệm vụ.
- Offline dùng cùng điều phối và quy tắc lương. Chạy một bước dài và nhiều bước ngắn phải cho kết quả tương đương trong điều kiện kiểm soát; giữ ngân sách xử lý để catch-up không khóa giao diện.

Đầu ra: save cũ tương thích, save 5 người round-trip đúng, offline không nhân đôi sản phẩm hoặc trừ lương lặp.

## M4 — Bảng quản lý đội

Phạm vi: `worker_menu.gd`, `worker_board.gd`, `scenes/ui/workers.tscn` và chuỗi dịch liên quan.

- Hiển thị số lượng như “Đội trồng ruộng 3/5”, số đang làm, số nghỉ, lương mỗi người và tổng lương hợp đồng mỗi ngày.
- Danh sách từng người: số thứ tự, trạng thái, công việc hiện tại, nút sa thải có xác nhận đúng ID.
- Nút “Thuê thêm” hiển thị giá thực tế và khóa khi đủ 5 người, chưa mở khóa hoặc thiếu tiền.
- Nhóm tùy chọn gieo, bón và tạm dừng ghi rõ áp dụng cho cả đội.
- Tương tác trực tiếp với NPC chọn đúng người; thao tác nhận giỏ dữ liệu cũ không trộn giữa các nhân công.
- Kiểm tra bố cục, cuộn, bàn phím và chuột ở kích thước cửa sổ nhỏ cùng kích thước mặc định.

## M5 — Kiểm thử và cân bằng

Mở rộng các bộ kiểm thử worker, crop automation, warehouse, UI và save hiện có. Chỉ thêm test cho các bất biến và tình huống thực tế:

1. Thuê 1–5 người, chặn người thứ sáu; nghỉ lương vẫn tính chỗ; thuê/sa thải nhiều lần không phình dữ liệu.
2. Hai người cùng muốn một ô hoặc pickup: chỉ một người nhận; người còn lại tìm mục tiêu khác.
3. Năm người cùng xới/gieo/bón; kho chỉ còn một hạt hoặc một phân; người chơi lấy vật tư khi NPC đang đi.
4. Người chơi thu/gieo trước NPC, kho đầy hoặc chỉ còn chỗ cho một lượt thu; không mất cây, mất hạt hay nhân sản phẩm.
5. Sa thải, tạm dừng, thiếu lương hoặc kẹt đường giữa nhiệm vụ; giải phóng chỗ và tiếp tục được.
6. Đổi cài đặt khi cả đội đang làm; mọi nhiệm vụ không còn hợp lệ đều bị hủy đúng cách.
7. Migration save cũ, lưu giữa xới và gieo, lưu khi cả 5 người có việc; tải lại giữ đúng người, tiến độ và lương.
8. Offline qua nhiều bình minh, có và không đủ tiền; so bước dài với bước ngắn và online trong cảnh không vật cản.
9. Kiểm thử hồi quy nhân công vườn cây, chăn nuôi, kho và thao tác của người chơi.

Đo đội 1, 3 và 5 người trên cùng ruộng, cùng vật tư, thời tiết và thời lượng: số việc hoàn thành, sản lượng, thời gian rảnh, thời gian tính offline và độ trễ khung hình. Không đặt kỳ vọng 5 người phải nhanh đúng 5 lần; dùng số liệu để đánh giá việc chia việc và mức lương.

## Thứ tự triển khai và tiêu chí hoàn thành

M1 → M2 → M3 → M4 → M5. Mỗi mốc có kiểm thử phù hợp trước khi chuyển tiếp. Trước phát hành, chạy lint/validation Godot, các suite liên quan và một lượt chơi thật với 5 người.

Hoàn thành khi thuê và quản lý được 5 người độc lập, không trùng việc hay hao vật tư sai, save cũ tải được, offline ổn định, giao diện hiển thị đúng chi phí và không có hồi quy ở hai vai trò còn lại. Cập nhật hướng dẫn nhân công theo hành vi đã kiểm chứng.
