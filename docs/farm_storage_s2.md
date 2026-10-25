# S2 — Worker thu hoạch vào Warehouse

Tài liệu ghi lại mốc này. Bản hiện tại đã nối đầy đủ kho vật tư và gieo từ kho; xem [S3–S5](farm_storage_s3_s5.md).

Ngày triển khai: 25/10/2026. Hoàn thành S2, chưa triển khai nguồn feed/hạt chung của S3–S4.

## Hành vi trong game

- Orchard hái trái, Crop thu cây/gom đồ và Ranch gom sản phẩm rơi trong khu phụ trách đều đưa sản phẩm thẳng vào **Warehouse**. Worker vẫn phải đi đến mục tiêu và hoàn thành thời gian làm việc; không thêm chuyến vận chuyển tới kho.
- Sản phẩm mới không đi qua giỏ worker hay túi player. Mở Warehouse để rút về túi khi cần dùng/bán. Thu hoạch thủ công của player giữ luồng hiện tại.
- Cây trái và cây trồng phải có chỗ cho **toàn bộ đợt thu hoạch** ở cả lúc chọn việc và lúc hoàn tất. Kho thiếu chỗ thì giữ nguyên cây/sản phẩm. Đồ rơi chuyển phần thực nhận, phần dư vẫn trên đất.
- Kho thay đổi sẽ yêu cầu worker xét việc lại qua signal, ngắt việc đi tuần nếu cần, giữ công việc đang thực hiện để kiểm tra lại ở lúc commit. Không thêm quét toàn map mỗi frame.
- Khi kho thiếu chỗ, worker vẫn có thể tưới cây/tiếp máng. Badge và bảng worker chỉ rõ đích Warehouse, đồng thời báo thiếu chỗ cho thu hoạch.
- **Feed vẫn lấy từ giỏ Ranch**, chưa lấy từ kho vật tư. S2 tách `output_inventory()` và `feed_inventory(role)` để hai luồng này độc lập.

## Save và giỏ cũ

Giữ schema **v24**, vì hình dạng DTO không đổi. Khi restore, kho được khôi phục trước worker. Nông sản PRODUCE trong giỏ cũ chuyển vào kho theo thứ tự thuê và sức chứa khả dụng; chỉ chuyển phần chứa được. Thức ăn giữ nguyên trong giỏ. Dữ liệu đang tải không bị sửa tại chỗ.

Phần dư tiếp tục nằm trong giỏ, kể cả sau sa thải. Nút **Nhận nông sản còn trong giỏ cũ** trên bảng worker cho phép lấy phần này về túi. Khi có chỗ trống trong kho, lần xử lý worker kế tiếp cũng thử chuyển phần dư vào kho. Không chờ kho chứa được nguyên stack cũ.

Chỉ phát thông báo sau khi cả nguồn và đích đã cập nhật, giữ khóa kho/worker trong lúc phát signal. Các lệnh gửi/rút, thuê/sa thải và save không thể xen vào giữa giao dịch. Lưu rồi tải lặp không cộng lại phần đã chuyển.

Hiệu ứng nhận đồ của player vốn kiểm tra inventory đích; sản phẩm về Warehouse không tạo thông báo hoặc hiệu ứng bay về túi player. Panel kho đang mở tự cập nhật khi worker nhập hàng.

## Kiểm chứng và tái hiện

**89 test / 897 assertion** qua trong bộ 10 suite liên quan. QA native qua **34 kiểm tra trên mỗi renderer** (Compatibility và Forward+), không dùng save cá nhân. Lint không có lỗi/cảnh báo; engine validation không có lỗi hoặc cảnh báo mới ở worker/storage (30 cảnh báo phụ thuộc cũ vẫn còn).

Ở fixture 10 cây táo, worker thực sự đi và thu 300 quả khi online. Catch-up 48 giờ thu tổng 33.300 quả vào Warehouse, giỏ worker vẫn rỗng; đây là fixture kỹ thuật, chưa phải kết quả cân bằng kinh tế S5.

- `tests/integration/test_worker_warehouse.gd`: giỏ đầy vẫn thu vào kho, kho đầy giữa hành trình, tranh slot cuối giữa Crop/Orchard, pickup từng phần, cả ba vai dùng chung kho, migration giỏ cũ/giữ feed/giữ đồ sau sa thải, load lặp, lấy phần dư và cập nhật panel.
- `tests/integration/test_workers.gd`: kiểm tra trực tiếp số dư Warehouse khi offline; so nhảy 48 giờ với từng giờ cho Orchard, hai giờ với từng phút cho Ranch, hai phút với từng giây cho Crop.
- `tests/support/workers_probe.gd`: worker di chuyển thật và thu 300 trái vào kho, giỏ/túi không được cộng; GUI worker PC/touch; catch-up 48 giờ vượt sức chứa giỏ cũ; rút sản phẩm bằng panel Warehouse thật.
- Các test kho, save repository, inventory, Chef và nâng cấp nông cụ tiếp tục được chạy hồi quy. Test dùng staging với userdata riêng, không sửa save cá nhân.

QA native trên Compatibility và Forward+:

```powershell
python scripts/run_workers_qa.py --godot <Godot-standard-console.exe> --output .godot/worker-warehouse-native
```

Runner yêu cầu staging được chuẩn bị bằng `scripts/build_web.py`. Báo cáo và ảnh ở `.godot/worker-warehouse-native/`. Cảm ứng là mô phỏng trên desktop ở 844×390, chưa phải thiết bị thật. Bản Web đã đóng gói thành công, build report không có lỗi.

Bước tiếp theo: **S3 — Ranch và người chơi tiếp máng lấy thức ăn từ kho vật tư**.
