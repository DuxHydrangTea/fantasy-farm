# Người làm thuê — bản v1

> **Cập nhật 25/10/2026 — save v26:** Crop đã tự cuốc, lấy hạt bất kỳ từ kho vật tư, gieo lại và tùy chọn bón phân. Nông sản worker về Warehouse; Ranch lấy feed từ kho vật tư, giỏ worker chỉ còn phục vụ dữ liệu cũ. Xem [hướng dẫn hiện hành](crop_worker_automation.md). Phần v1 bên dưới là tài liệu lịch sử; giới hạn không cuốc/gieo/bón và yêu cầu chọn giống/vùng đã được thay thế bởi [kế hoạch v2](crop_worker_automation_plan.md).

Hoàn thiện tiếp từ M0 của ZCode ngày 25/10/2026. Cả ba vai đã có thuê/quản lý, làm việc, lương, giỏ và save/offline. M5 có số đo kỹ thuật ban đầu; lương và stack cap vẫn giữ mức thử nghiệm trong tài liệu thiết kế.

## Chơi trong game

Mở lại game để nạp code mới. Ba biển **Thuê người làm** được đặt ở lối vào vườn cây, cạnh khu chuồng và bên phải ruộng. Biển có sprite trong scene nên nhìn thấy trong editor; không cần bật `debug_worker_enabled`.

Đến gần biển rồi E/click hoặc tương tác cảm ứng. Mỗi vai tối đa một người. Có thể mở cùng bảng bằng cách tương tác trực tiếp với người làm đang đi lại.

| Vai | Điều kiện thuê | Phạm vi và công việc | Lương/ngày |
|---|---|---|---:|
| Vườn cây | Có ít nhất 10 cây ăn quả | Thu trái chín, gom sản phẩm rơi trong khu cây ăn quả | 1.800 xu |
| Chăn nuôi | Map có ít nhất 2 chuồng | Chọn một chuồng; tiếp thức ăn/nước trước, gom WORLD_DROP sau | 2.200 xu |
| Trồng trọt | Mở ít nhất 12 cột đất | Tưới cây đang trồng bị khô, thu cây chín, gom sản phẩm trên vùng ruộng đã mở | 2.800 xu |

Map hiện có sẵn ba khu chuồng nên điều kiện hai chuồng đang được đáp ứng từ đầu. Đây là cách đếm theo tài liệu v1, không phải hai chuồng có vật nuôi hay hai chuồng đã mua mới.

Crop tự theo vùng cột đang mở; chưa có bộ chọn giới hạn riêng một đoạn ruộng. Ranch chỉ phục vụ chuồng đã chọn. Muốn đổi chuồng thì cho nghỉ rồi thuê lại và chọn chuồng mới.

Người làm không cuốc/gieo, không bón phân, không mua/bán và không chặt/trồng cây. Không hưởng nâng cấp nông cụ 6×6 của player. Ranch chỉ gom sản phẩm rơi; không tự lấy loại DIRECT_COLLECTION từ vật nuôi.

## Giỏ và thao tác

- 16 slot, không tặng cuốc/bình tưới. Mỗi stack tối đa 100, hoặc thấp hơn nếu item có giới hạn nhỏ hơn.
- **Nhận sản phẩm**: chuyển PRODUCE về túi player; không rút feed.
- **Nạp thức ăn / Rút thức ăn**: chỉ chuyển FEED, dành cho Ranch. Nạp theo sức chứa; feed không dùng được ở chuồng vẫn có thể rút lại.
- Tràn túi giữ phần dư ở nguồn. Không xóa đồ theo số lượng yêu cầu nếu thực nhận ít hơn.
- Thu cây là nguyên đợt: 300 quả cần ba stack 100. Còn một slot trống chỉ chứa được 100 thì worker giữ nguyên cả đợt trên cây. Vì vậy giỏ 15/16 có thể đã không đủ cho đợt quả tiếp theo.
- Giỏ không nhận thêm sản phẩm được thì vẫn tưới hoặc tiếp máng nếu có thể.
- **Cho nghỉ việc** cần nhấn xác nhận lần hai. Giỏ được giữ; vẫn nhận lại từ biển. Hợp đồng đã cho nghỉ không tự trả lương hay làm việc nữa.

Nguồn nước miễn phí được đánh dấu trong từng chuồng. Worker lấy một lượt 30 đơn vị rồi mang tới máng; cả đi lấy và đi tiếp đều mất thời gian. Thức ăn dùng gói feed phù hợp từ giỏ. Tất cả nạp qua API máng, không gán stock trực tiếp.

## Lương và ca làm

Bình minh dùng mốc 06:00 UTC+7 của WeatherSchedule. Ca đầu miễn tới bình minh tiếp theo **một lần mỗi vai trong profile**. Sa thải rồi thuê lại không có ca miễn phí mới: trả lương ngày hiện tại ngay khi thuê lại.

Tại bình minh, xét theo thứ tự thuê được lưu ổn định. Đủ xu thì trả trước ngày mới; thiếu thì tạm nghỉ, giữ hợp đồng, giỏ và phần nhiệm vụ dở. Có đủ tiền ở bình minh tiếp theo thì làm lại. Không tự bán sản phẩm để trả lương.

`last_wage_day` ghi ngày đã xét lương; `paid_through_day` chỉ ghi ngày được bảo đảm tiền công. Hai mốc riêng tránh trả lặp khi reload và tránh ghi ngày chưa trả thành ngày đã trả.

## Di chuyển và timeline

Kế thừa body/animation/movement của M0, không sửa cấu hình player. Worker đi tới điểm tiếp cận thay vì tâm cây/máng. Kẹt khoảng 2 giây thì thử tối đa bốn offset; mục tiêu thất bại được tạm bỏ qua 120 giây để tìm việc khác. Đi tuần khi rảnh; badge hiển thị việc và số slot đã dùng. Không tự mở bảng hoặc ngắt hoạt động vật nuôi khi hover.

Mỗi nhiệm vụ lưu điểm đích, thời điểm bắt đầu làm và hoàn thành tuyệt đối. Phí thời gian = khoảng cách/tốc độ + khoảng đệm tăng tốc + thời lượng làm (mặc định 2 giây). Luôn kiểm tra lại cây/máng/pickup trước commit. Online còn chờ actor tới gần đích; mở menu hay lưu không được teleport người làm đang bị chặn để nhận sản phẩm.

Offline dùng cùng lịch nhiệm vụ. Các hệ thống được restore ở checkpoint trước, sau đó xử lý theo thứ tự thời gian, xen lương và các biên sinh trưởng/thời tiết/nguồn máng. Worker chạy trước tick chung khi trở lại sau khoảng nghỉ. Giữ phần công việc dở qua save và biên ngày; không chia ngân sách trung bình rồi làm tròn theo từng đoạn.

Va chạm vật lý có thể khiến online chậm hơn trường hợp đường trống của offline. Kiểm thử parity xác nhận tính nhất quán của lịch logic và kết quả khi chia nhỏ thời gian; không khẳng định mọi frame vật lý giống offline.

## Lưu và cấu hình

Schema **v23** thêm `workers`. Profile v22 trở xuống được khởi tạo danh sách rỗng qua migration tuần tự, giữ xu, túi, nông cụ và cooking. Không tự tặng worker khi tải save cũ.

Lưu role/khu, ID và thứ tự thuê, trạng thái hợp đồng/nghỉ, các mốc lương, vị trí, giỏ, nước đang mang, nhiệm vụ dở và cờ ca miễn theo vai. Validate trước khi thay đổi World: role/item hợp lệ, stack cap, ID/order duy nhất, khu/đích và timestamp. Worker Crop được kiểm tra theo số cột **trong save**, không theo đất của world mới mở trước load.

- Sprite, tốc độ, thời gian làm: `resources/workers/*.tres`.
- Lương v1: `WorkerRole.WAGES` trong `components/workers/worker_role.gd`.
- Giỏ: cấu hình tại `WorkerActor` (16 slot / stack cap 100); inventory player giữ nguyên.
- Biển: ba instance `worker_board.tscn` trong MainWorld. Biển ruộng nằm ngoài vùng canh tác, biển vườn ngoài ô trồng cây.
- `WorkerRole` giữ chính sách chọn việc bằng dữ liệu thuần; `WorkerWorldBridge` gom ứng viên và gọi API scene theo vai. V1 chưa tạo ba class strategy chỉ để chuyển tiếp tới bridge.
- Biển và tương tác trên worker dùng TradeMenu/ShopMerchant chung; không giữ thêm ShopUI mua bán không dùng ở mỗi instance.

## Kiểm chứng

75/75 bài test liên quan, 1.264 assertions, gồm: M0, chia 300 quả thành ba stack, đầy giỏ, chuyển tràn túi, khóa callback tái nhập, lương/ca miễn/thứ tự thuê, cả ba vai, parity chia đoạn, migration v22→v23, save/load, không teleport khi mở menu và hồi quy Chef/nông cụ/chuồng/bootstrap.

Native QA dùng map đầy đủ ban ngày, thêm 10 cây thử mà không ẩn các thành phần scene, click thuê/nhận, worker thực sự đi và thu trái; kiểm tra bố cục 844×390 và ScreenTouch xác nhận nghỉ/thuê lại. Chưa kiểm thử điện thoại vật lý hay chạy bản Web trong trình duyệt.

Bằng chứng: [ảnh, log và báo cáo](workers_2026-10-25/).

## M5 — số đo ban đầu

Kịch bản: một Orchard worker, 10 cây táo, không nhận giỏ trong khoảng offline 48 giờ. Có 1.500 táo trong giỏ sau catch-up, không vượt stack cap; lương cho hai ngày mới là 3.600 xu. Giỏ còn một slot nhưng không đủ chứa thêm cả đợt 300 quả.

Theo catalog hiện tại, 1.500 táo × 25 = 37.500 xu giá trị bán; lương bằng 9,6% giá trị đó. Đây không phải tiền tự nhận và chưa trừ đầu tư cây. Nếu người chơi nhận giỏ thường xuyên, sản lượng và tỷ lệ lương sẽ khác. Chưa dùng một kịch bản ngắn này để tuyên bố cân bằng kinh tế đã chốt.

| Renderer | CPU catch-up 48h | Táo trong giỏ | Lương đã trả |
|---|---:|---:|---:|
| Compatibility | 1.622 giây | 1,500 | 3,600 xu |
| Forward+ | 1.637 giây | 1,500 | 3,600 xu |

Đo trên máy phát triển, không phải cam kết FPS/hiệu năng điện thoại. Cả hai renderer đạt 29 kiểm tra native, gồm chạm xác nhận nghỉ/thuê lại. Lint không lỗi/cảnh báo, engine không có diagnostic mới thuộc worker, Web export thành công.
