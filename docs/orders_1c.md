# 1C — Bảng đơn hàng

Triển khai ngày 24/10/2026 theo completion_plan.md.

## Cách chơi

Bảng treo giấy nằm trên đường phía trái cửa hàng, tọa độ world-local **(1664, 248)**. Đến gần, hướng về bảng rồi nhấn **E**, chạm **Tương tác**, hoặc bấm vào bảng để đi đến và mở. Đóng bằng nút **Đóng** hoặc Esc. Bảng dùng khóa menu và reset input hiện có; không mở chồng túi/shop/trang mục tiêu.

Có tối đa **3 đơn đang có**, mỗi đơn yêu cầu một hoặc hai loại sản phẩm. Chọn đơn để xem số lượng trong túi/yêu cầu và phần thưởng. **Giao đơn hàng** mở trang xác nhận; xác nhận giao đủ toàn bộ vật phẩm, không nộp từng phần. **Bỏ đơn hàng** cũng cần xác nhận và không phạt xu. Hủy xác nhận, đóng UI hoặc tải game không giao/bỏ đơn.

Sau khi giao hoặc bỏ, ô đó nhận mẫu hợp lệ tiếp theo trong vòng cố định. Không có hạn chót, reset ngày, reroll trả phí hoặc thưởng khi đổi đơn. Nếu chưa có nguồn sản phẩm hợp lệ thì ô trống giải thích điều kiện; **Tìm đơn hàng** chỉ lấp ô trống, không đổi đơn đang có. Mở bảng hoặc load save hiện tại không tự thay đơn.

Bán nông sản thường vẫn hoạt động. Khi túi có hàng được các đơn yêu cầu, màn hình bán nhắc rằng **Bán tất cả** sẽ bán cả những hàng đó. Cảnh báo giữ lại sau bán một phần; hệ thống không tự khóa đồ và bán thường không hoàn thành đơn.

## Mẫu và mức thưởng ban đầu

Định nghĩa tại `resources/orders/farm_orders.tres`, có ID ổn định. Giá thưởng bằng giá bán thường của lượng hàng yêu cầu cộng **20%**, làm tròn lên; đây là giá trị phát triển, phần 4 sẽ cân bằng bằng số liệu chơi thử.

| Mẫu | Vật phẩm | Xu |
| --- | --- | ---: |
| carrot_crate | Cà rốt ×12 | 72 |
| tomato_crate | Cà chua ×10 | 84 |
| potato_crate | Khoai tây ×12 | 87 |
| corn_crate | Ngô ×10 | 84 |
| salad_basket | Cà rốt ×8, cà chua ×6 | 99 |
| soup_basket | Khoai tây ×8, ngô ×6 | 108 |
| flower_bouquet | Hoa 01 ×6 | 144 |
| mixed_bouquet | Hoa 01 ×4, hoa 02 ×4 | 192 |

`OrderAvailability` kiểm tra cửa hàng có hạt giống hợp lệ cho đúng sản phẩm và khu trồng tương ứng: farmland đã có đất mở hoặc flower garden có chậu. Khả năng mua ở đây nghĩa là có nguồn hạt trong thế giới; không yêu cầu đủ xu mua hạt ngay lúc xét đơn. Tám mẫu hiện có đều có nguồn trong map. Đơn vật nuôi/mật ong để giai đoạn sau.

## Cấu trúc và lưu game

- `OrderDefinition`/`OrderCatalog`: Resource chứa yêu cầu và thưởng, không đọc đường dẫn từ save.
- `OrderService`: trạng thái ba ô, ID instance dạng serial, cursor vòng mẫu và tổng đơn đã giao. Kiểm tra tất cả yêu cầu/ví trước; trừ hàng trên nhiều stack, cộng xu và thay đơn xong mới phát signal. Chặn lệnh tái nhập trong giao dịch/restore; ID cũ không áp dụng cho đơn thay thế.
- `OrderBoard`: collider/sprite dùng atlas Signs có sẵn, tích hợp resolver/click/E/prompt dùng chung. `FarmWorld.order_board_position` cấu hình điểm đặt; không sửa bố cục main_world.tscn.
- `OrderUI`: kế thừa TradeMenu, layout bằng Container, EN/VI, UIScale/safe area. Nút tối thiểu cao 48 điểm; mô tả/xác nhận có vùng cuộn, nút hành động nằm ngoài vùng cuộn.
- Save **v14** thêm DTO orders. Migration v13 tạo trạng thái chưa khởi tạo; lần restore migration tạo bộ đơn ban đầu từ nguồn hợp lệ. Các migration cũ tiếp tục đi qua v13→v14. Save v14 thiếu/sai orders bị từ chối trước khi đổi thế giới.
- DTO kiểm tra số nguyên hữu hạn, giới hạn counter/cursor, serial duy nhất, template hợp lệ, không trùng mẫu đang có và trạng thái khởi tạo. Không lưu lịch sử vô hạn. Offline không tự reset/thay đơn hoặc trả thưởng lại.

## Xác minh

Bằng chứng: [thư mục QA](orders_1c_2026-10-24/).

- **155/155 test, 6.773 assertions, 17 suite**, log cuối không có lỗi GUT/runtime: orders unit/integration và 15 suite hồi quy từ 1B.
- Bao gồm giao hàng chia nhiều stack, thiếu một trong hai loại hàng, ví đầy, bấm lặp/tái nhập, giao liên tục 40 vòng, bỏ đơn không cộng/trừ xu, mẫu không đủ nguồn, lưu cursor/instance, dữ liệu hỏng, migration v13, cancel/load đóng xác nhận và cảnh báo bán tất cả sau bán một phần.
- EN/VI tại 667×375, 740×360, 844×390 ở mật độ 1×/3×, safe area và nút 48 điểm, cả trang chính và trang xác nhận.
- **29/29 kiểm tra native** bằng Input.parse_input_event: tiếp cận bảng, chạm tương tác/giao/xác nhận/hủy/bỏ/đóng, ba kích thước điện thoại, E/Esc và cửa sổ 500×400. Có ghi/đọc file save bất đồng bộ trong cache riêng, tải sau một giờ offline, giữ đúng instance/cursor/count/xu. Không truy cập save cá nhân.
- Ảnh board, trang EN/VI và xác nhận đã xem trực tiếp. Query vật lý xác nhận collider bảng không chồng collider có sẵn; resolver nhận đúng bảng ở điểm tiếp cận.
- Lint toàn dự án **0 lỗi, 0 cảnh báo**. Engine validation 4 script orders không có lỗi/cảnh báo thuộc phần mới; báo cáo vẫn có 22 cảnh báo dependency cũ.
- Web Compatibility export thành công; báo cáo build kèm theo. Lượt này xác minh tương tác trên native Compatibility, chưa xác nhận lại browser hoặc Android/iPhone thật.

Các suite ngoài 17 suite này không được coi là đã xanh toàn dự án. Các fixture cũ đã ghi ở 1A không nằm trong phạm vi thay đổi này. Bước tiếp theo theo lộ trình: **phần 2 — hướng dẫn đầu game và trang trợ giúp**.
