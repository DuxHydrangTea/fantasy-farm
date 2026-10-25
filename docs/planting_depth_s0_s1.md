# Planting Depth — S0 và S1

Đã triển khai ngày 25/10/2026. Save hiện hành **v28**: v27 thêm tầng vật phẩm, v28 thêm cờ chất lượng theo vụ. S2–S5 và ghép cành chưa triển khai trong lượt này.

## Cách chơi

- Rau chưa được tưới trong vụ cho **Thường**. Tưới tay, tưới bằng vùng công cụ, worker tưới hoặc mưa đều ghi nhận **Bạc** cho cả vụ. Gieo trên đất còn ẩm hoặc đang mưa cũng được tính.
- Đất khô về sau không làm mất Bạc. Không tưới không làm chậm hoặc mất sản lượng. Ong và phân tăng tốc giữ cơ chế hiện tại.
- Đem **Root Wood / rễ cây** tới Chef, chọn **Root Tonic / Dưỡng chất rễ cây**. Công thức thử nghiệm: 1 rễ → 1 tonic, thời gian 60 giây, dùng chung hàng đợi Chef. Nhận thành phẩm vào túi.
- Chọn tonic trên hotbar, hướng về cây đã tưới và dùng như phân bón. Mỗi cây chỉ nhận một lần, tăng lên **Vàng**, không đổi thời gian lớn. Chưa tưới hoặc đã dùng thì từ chối và không tiêu tonic.
- Worker thu rau đúng tầng trực tiếp vào **Warehouse**. Worker chỉ tự dùng phân tăng tốc, không tự dùng Root Tonic.
- Chạm nông sản trong túi để xem bảng ba dòng Thường/Bạc/Vàng; danh sách Warehouse hiện cả ba số lượng. Nhãn chất lượng trên cây xuất hiện khi xem trạng thái; cây bón Root giữ dấu Vàng ngay cả khi đất khô. Burst thu hoạch được nhuộm theo tầng.

## Túi, kho và giao dịch

Một stack chứa số lượng của cả ba tầng, **tổng không vượt max_stack hiện có**. Hết sức chứa stack thì tràn sang stack tiếp theo. Giới hạn túi/kho và quy tắc worker không thu khi kho thiếu chỗ cho cả đợt vẫn được giữ.

Vận chuyển giữa túi/kho, gộp stack và nhận sản phẩm giỏ worker cũ bảo toàn số lượng từng tầng. Phần túi ngoài hotbar được nhóm theo item khi hiển thị; không đổi vị trí lưu hoặc phím tắt công cụ.

Đơn hàng thường và công thức Chef hiện tại chỉ tiêu đúng hàng Thường, thiếu thì báo thiếu. Không tự thay bằng Bạc/Vàng. Công thức có thể khai báo `ingredient_tiers` để yêu cầu đúng tầng ở các slice sau; chưa thêm món ăn cao cấp hoặc Perfect Delivery.

Ở NPC mua nông sản, chọn **Thường / Bạc / Vàng** trước khi bán. Số lượng, đơn giá và tiền nhận được hiện trước khi bấm bán. **Bán tất cả chỉ bán tầng đang chọn**, giữ nguyên hai tầng còn lại. Giá thử nghiệm: 1× / 1,8× / 3,5×, làm tròn đơn giá tới xu gần nhất.

## API và dữ liệu

- `InventoryComponent.add(item, amount, tier=0)` nhận đúng tầng.
- `consume(id, amount, ItemQuality.exact(tier))` chỉ tiêu đúng tầng; `ItemQuality.tier_set(allowed, high_first)` chỉ tiêu tập được cho phép theo thứ tự đã chọn. Trả số thực tiêu ở từng tầng; lệnh giao dịch kiểm tra đủ trước khi tiêu.
- `remove` và `count_item` cũ mặc định tầng Thường. `count_item(id, -1)` đọc tổng khi chỉ cần thống kê; chuyển đồ dùng API vận chuyển riêng.
- Slot giữ `count` làm tổng tương thích với các luồng hiện có, cùng `tiers=[normal,silver,gold]`; restore/save bắt buộc tổng tầng khớp count. Non-produce chỉ có tầng Thường. Snapshot mảng tầng là bản sao sâu.
- Các giao dịch kho chuẩn bị cả hai phía trước khi phát signal; bán chuẩn bị ví và stack trước khi thông báo. Snapshot, rollback, giỏ worker và DTO Warehouse đều mang đủ tầng.
- Crop lưu `watered` và `root_boost` theo lứa, độc lập `_moisture`. Reset khi gieo mới, giữ qua load/offline. Không thể lưu `root_boost=true` mà `watered=false`.

## Migration

v26 → v27: vật phẩm cũ vào tầng Thường, giữ nguyên số lượng và sức chứa. v27 → v28: cây cũ đang có được `watered=true`, `root_boost=false` để nhận Bạc một vụ chuyển tiếp. Các vụ mới theo luật tưới thực tế. Không sửa trực tiếp save cá nhân; migration chạy khi game nạp save qua schema.

## Kiểm chứng

- **177/177 test, 3.064 assertions, 23 script**: chất lượng stack, giới hạn sức chứa, tiêu đúng tầng, giá bán, Chef, migration, worker/kho, 48 giờ offline một lần so với chia đoạn, công cụ và onboarding. Log: `.godot/quality-final-engine.log`.
- Native **35/35 kiểm tra trên mỗi renderer Compatibility và Forward+**: chế/nhận tonic bằng UI, áp dụng tonic, thu ba tầng, gửi/rút kho, mở bảng tầng bằng cảm ứng, bán riêng Bạc và roundtrip save giữ Vàng. Profile QA riêng, không dùng save cá nhân. Ảnh/báo cáo: `.godot/quality-native/`.
- Một số fixture hồi quy được cập nhật đúng DTO tầng mới; bài kiểm tra worker tưới chuyển kỳ vọng sang Bạc. Fixture bán hàng đặt vốn rõ ràng thay vì phụ thuộc vốn mặc định của game.
- Lint toàn dự án không lỗi/cảnh báo. Build Web dùng preset hiện có; báo cáo `.dist/build-report.json`.

Không khẳng định mọi fixture lịch sử trong repository đều đã xanh; bộ hồi quy trên tập trung các hệ bị thay đổi và các hệ liên quan.
