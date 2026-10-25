# S3–S5 — Kho vật tư chung, gieo từ kho và kiểm thử toàn luồng

> **Cập nhật 25/10/2026 — save v26:** Crop đã tự cuốc, lấy hạt bất kỳ từ kho vật tư, gieo lại và tùy chọn bón phân. Nông sản worker về Warehouse; Ranch lấy feed từ kho vật tư, giỏ worker chỉ còn phục vụ dữ liệu cũ. Xem [hướng dẫn hiện hành](crop_worker_automation.md). Phần v1 bên dưới là tài liệu lịch sử; giới hạn không cuốc/gieo/bón và yêu cầu chọn giống/vùng đã được thay thế bởi [kế hoạch v2](crop_worker_automation_plan.md).

Ngày triển khai: 25/10/2026. Luồng kho v1 đã nối từ gửi vật tư đến sản phẩm worker; save **v25**.

## Cách chơi

1. Mua/nhận hạt và thức ăn vào túi như trước. Đến cửa **SeedInventory — kho vật tư**, nhấn E hoặc click/chạm, gửi các vật phẩm phù hợp vào kho.
2. Mở **Giống trong kho** bằng nút trên màn hình hoặc **G**, chọn giống còn hàng. Giống có hàng được xếp trước; giống hết hàng bị khóa. Không cần giữ hạt làm token trong túi/hotbar.
3. Hướng về đất đã cuốc, chọn kích thước đã mở từ 1×1 đến **6×6** bằng R/nút vùng, rồi Space/chuột phải hoặc nút Dùng trên điện thoại. Mỗi cây trồng thành công trừ đúng một hạt trong kho. Thiếu hạt thì chỉ gieo phần đủ, preview vàng chỉ phần thiếu.
4. Chọn lại hotbar để thoát giống đang chọn. Khi dùng hạt cây trồng từ hotbar, nguồn tiêu thụ vẫn là kho vật tư; hạt trong túi không được dùng làm nguồn dự phòng. Hạt hoa và cây giống lâu năm tiếp tục dùng túi theo luồng hiện tại.
5. Đến máng ăn và tương tác. Player/Ranch lấy đúng loại feed từ kho vật tư; giao diện máng và bảng Ranch hiển thị lượng trong kho. Không cần giữ feed trong túi hoặc giỏ worker.
6. Worker thu nông sản vào **Warehouse**. Rút về túi để bán, giao đơn hoặc nấu ăn. Thu hoạch thủ công và nguồn nguyên liệu của Chef giữ cách dùng hiện có.

Nước vẫn miễn phí với bình tưới/nguồn nước của Ranch. Không thêm vật phẩm nước. Crop worker vẫn tưới, thu hoạch và gom pickup; không tự cuốc/gieo.

## Quy tắc bảo toàn

- Đồng bộ chuồng trước khi đọc lượng cần nạp và trừ feed. Player phải ở gần máng; Ranch phải hoàn tất nhiệm vụ trên timeline. Các thao tác không nạp feed ngược về khoảng offline đã qua.
- Gói thức ăn dùng thông số thật của ItemDefinition, không giả định cố định 300 đơn vị. Phần dư của gói khi nạp đầy máng được giữ ở `feed_reserve` và lưu lại; không vứt bỏ phần dư.
- Giỏ Ranch cũ được chuyển feed vào kho theo sức chứa khi restore và khi kho có thay đổi. Phần không chứa được tiếp tục nằm trong giỏ, kể cả sau sa thải, và có nút **Nhận thức ăn còn trong giỏ cũ**. Nút nạp feed mới vào giỏ đã bỏ khỏi UI.
- Đích nông sản và nguồn feed là hai inventory riêng. Nhiều worker, player và hai máng không thể tiêu trùng gói cuối hoặc chiếm trùng chỗ kho.
- Gieo khóa ID giống, nguồn, revision lựa chọn và vùng tại lúc bắt đầu animation. Đổi giống/slot rồi đổi lại vẫn hủy lượt cũ; mở menu hoặc load hủy động tác đang chờ. Stock giảm trước impact thì chỉ gieo phần còn lại.
- Thông báo inventory chỉ phát khi cây và số hạt đã commit xong. Khóa kho/farming/worker ngăn tái nhập và chụp save giữa giao dịch.

## Save v25

v24 → v25 bổ sung `storage_seed`, mặc định chuỗi rỗng. Giống được chọn phải là hạt cây trồng hợp lệ trong catalog; có thể nhớ giống đã hết hàng. Giữ nguyên hai kho, sức chứa đã lưu, túi, giỏ cũ, xu, nông cụ, Chef và tiến trình khác.

Thứ tự restore: hai kho → thế giới tại checkpoint → worker/giỏ cũ → chuyển phần tương thích → catch-up theo timeline. Không tự thu nhỏ kho khi cấu hình mặc định thay đổi. Không reset hoặc chỉnh save cá nhân để kiểm thử.

Hướng dẫn đầu game và trợ giúp đã đổi sang gửi hạt/feed vào kho. Hỗ trợ một hạt khẩn cấp cũng kiểm tra hạt/nông sản đang nằm trong cả hai kho trước khi cấp.

## Kiểm chứng S5

Các suite hiện hành kiểm tra: nguồn kho/seed picker; sáu kích thước × bốn hướng; năm hạt cho 36 ô; giảm stock giữa animation; đổi giống/mở menu; giữ feed reserve; máng tranh gói cuối; giỏ cũ; save v24→v25 và save trước impact; worker/warehouse; nông cụ; Chef; onboarding và save repository.

Fixture 48 giờ có cả ba worker, **hai gà và một bò trưởng thành thật**, nguồn feed hữu hạn, Warehouse ba slot thử nghiệm và chỉ 10.000 xu. Chạy một lần và chia từng giờ khớp kho, nhiệm vụ, lương, cây, stock/fraction/reserve máng, no/khát, tuổi và tiến độ sản phẩm của vật nuôi (sai số float tối đa 0,01). Fixture kết thúc với 3.000 táo, feed gia cầm bằng 0, trả 8.600 xu lương, còn 1.400 xu và hai worker tạm nghỉ vì thiếu lương. Thời gian CPU được ghi trong `STORAGE_PARITY_48H` của log; đây là fixture đo tính đúng, không phải dự báo sản lượng cho mọi farm.

Giữ mặc định Warehouse 128 slot/kho vật tư 64 slot và lương đã chốt. Không giảm sức chứa của save đang có. Baseline S2 ở farm 10 cây táo cho 33.300 quả/48 giờ, vượt trần giỏ cũ 1.600; vì vậy không dùng số cân bằng của giỏ cũ để tuyên bố kinh tế sau nối kho đã cân bằng hoàn toàn.

QA native dùng chuột và ScreenTouch mô phỏng trên Compatibility/Forward+, ở 1280×720 và 844×390: gửi hạt/feed vào kho, chọn giống không có hạt trong túi, preview/gieo 6×6, đổi hotbar, player tiếp máng, Ranch dùng kho, Crop đưa sản phẩm về Warehouse, gieo ba hạt bằng cảm ứng, mua vật nuôi thật và restore v25. Có 25 kiểm tra trên mỗi renderer. Ảnh/report ở `.godot/supply-flow-release/`.

Đã sửa lỗi scene mua vật nuôi bị preload rỗng trong đồ thị script phụ thuộc vòng: scene được tải và kiểm tra khi mua, trước khi trừ tiền. Test mới dùng giá và định nghĩa hiện hành.

```powershell
python scripts/run_supply_flow_qa.py --godot <Godot-standard-console.exe>
```

Chuẩn bị staging bằng `scripts/build_web.py` trước. Test dùng userdata riêng. Cảm ứng là mô phỏng desktop; chưa xác nhận trên điện thoại thật hoặc trình duyệt Web thật.

### Phạm vi kết quả test

- Bộ hồi quy hiện hành: **138/138 test, 2.295 assertion** trên 18 suite.
- Bộ biên cuối sau bổ sung test hỗ trợ giống/mua vật nuôi và kiểm tra hình học: **17/17 test, 777 assertion**. Bộ này có test trùng bộ hồi quy; không cộng hai số như các test độc lập.
- Native: **25/25 kiểm tra trên mỗi renderer**. Bản Web đóng gói thành công; build report không có lỗi.

Log bộ hồi quy hiện hành: `.godot/storage-s345-final-tests.log`; test biên bổ sung: `.godot/storage-s345-final-boundaries.log`; engine/lint: `.godot/storage-s345-final-validation.json`, `.godot/storage-s345-lint.json`.

Lượt kiểm tra mở rộng còn phát hiện fixture cũ ở `test_world_persistence.gd` dùng node `Cow_1`/nguồn hạt hoa không còn trên map, giá/vốn và sản lượng cũ; một số fixture `test_pen_offline.gd` cũng phụ thuộc thứ tự chạy/định nghĩa cũ. Log được giữ tại `.godot/storage-s345-regression.log`, `.godot/storage-s345-pen-only.log`. Không thay đổi map, giá hoặc bật lại đàn/vườn mặc định chỉ để làm các fixture đó xanh; không coi đây là kết quả toàn bộ repository đã qua.
