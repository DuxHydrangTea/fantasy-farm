# 1A — Nền tảng mục tiêu và tiến trình

Ngày triển khai: 24/10/2026. Đây là phần model/service, event adapter và persistence. Chưa thêm HUD hoặc nút nhận thưởng; phần đó thuộc 1B theo kế hoạch đã duyệt.

## Chuỗi mục tiêu

Định nghĩa tại `resources/objectives/onboarding.tres`. Mỗi lúc có một bước chính; nhận thưởng bước trước mới mở bước sau. Các hành động khác của người chơi vẫn hoạt động bình thường.

| ID ổn định | Điều kiện | Xu thưởng khởi đầu |
| --- | --- | ---: |
| first_soil | Có một ô đất đã cuốc, trong vùng đã mở; tính cả đất có sẵn | 25 |
| first_seed | Gieo thành công một hạt bất kỳ sau khi kích hoạt | 50 |
| first_water | Tưới thành công một ô khô đang có cây; mưa không tính | 50 |
| first_harvest | Thu hoạch thành công một cây sau khi kích hoạt | 100 |
| first_sale | Bán thành công ít nhất một nông sản | 100 |
| first_animal | Sở hữu một vật nuôi còn sống; tính cả vật nuôi có sẵn | 100 |
| first_feed | Bổ sung thành công thức ăn vào máng sau khi kích hoạt | 50 |
| first_trough_water | Bổ sung thành công nước vào máng sau khi kích hoạt | 50 |
| first_expansion | Sở hữu ít nhất hai cột đất; tính cả đất đã mở | 250 |

Tổng thưởng 775 xu. Đây là giá trị khởi đầu để phát triển 1B và chơi thử; chưa phải kết luận cân bằng kinh tế. Không thay giá, tốc độ tăng trưởng hay sản lượng của game.

Bước chuẩn bị đất là điều kiện trạng thái để farm đã cuốc kín mọi ô không bị kẹt ở thao tác không thể thực hiện thêm. Những bước hành động không suy đoán lịch sử từ inventory: cấp đồ, load, animation hoặc bấm nút thất bại không tạo tiến trình. Hoàn thành chưa nhận thưởng vẫn giữ nguyên bước hiện tại.

## Cấu trúc

- `ObjectiveDefinition`/`ObjectiveCatalog`: Resource chứa ID, nội dung EN/VI, điều kiện, ngưỡng, thưởng và thứ tự mở khóa.
- `ObjectiveProgress`: API đọc bước hiện tại, ghi commit, xét trạng thái, nhận thưởng, capture/restore. Không phụ thuộc Control hoặc tên node map.
- `ObjectiveTracker`: được FarmWorld khởi tạo sau khi player đã ready; nối commit farming, bổ sung máng tại frame tác động, service bán nông sản theo từng lượt mở menu và trạng thái đất/vật nuôi. Setup lặp không nhân subscription. Không có event bus toàn cục.
- Farming có signal commit riêng để phân biệt tưới thủ công với mưa/restore. Máng chỉ phát tiến trình khi thao tác player thực sự bổ sung được tài nguyên.
- Service giữ khóa khi nhận thưởng, cập nhật tiền và cờ đã nhận trước khi phát signal. Observer và save luôn thấy cả hai cùng trạng thái; gọi nhận lồng nhau/double click bị từ chối. Ví đầy giữ nguyên phần thưởng chờ nhận.

## API cho phần 1B

```gdscript
var objectives: ObjectiveProgress = world.objectives.progress
var current: ObjectiveDefinition = objectives.active() # null khi đã nhận hết
var count: int = objectives.progress()
var ready: bool = objectives.ready_to_claim()
# Chỉ gọi từ thao tác nhận thưởng của người chơi:
var result: Dictionary = objectives.claim(current.objective_id) if current != null else {"ok": false}
```

Theo dõi `objectives.changed`; dịch `current.title`, `current.description` và `result.error` tại UI bằng `tr`/GameText như các màn hiện có. Không dùng `record` từ nút nhiệm vụ, không cấp thưởng tự động khi nhận signal hoàn thành. Thông báo lỗi trả source key để UI dịch ở biên trình bày.

## Lưu và migration

Schema **v12** thêm `objectives.steps`: các row gồm `id`, `progress`, `claimed`, toàn bộ là dữ liệu nguyên thủy. Validator kiểm tra ID/thứ tự, số nguyên hữu hạn trong giới hạn, các bước đã nhận phải là một prefix liên tục và các bước chưa mở không được có tiến trình. Catalog cần migration nếu thay ID/thứ tự/ngưỡng theo cách khiến save cũ không còn hợp lệ.

Migration v11 → v12 khởi tạo chuỗi mới, không suy đoán hành động cũ và không tự cấp thưởng. Khi restore xong, các mục tiêu trạng thái xét thế giới thực vừa khôi phục. Migration từ v10 trở về trước vẫn đi tuần tự qua các bước cũ. Inventory, xu, cây, vật nuôi và revision được giữ.

Preflight không thay đổi world hoặc bật chế độ suspend. Chỉ sau preflight thành công mới tạm ngừng đếm; đóng UI, khôi phục entity/tiền/inventory rồi restore ledger mục tiêu. Thưởng/tiền nằm trong cùng snapshot: tải checkpoint trước khi nhận thưởng rollback cả hai; không cộng lại xu mà giữ cờ nhận của checkpoint khác.

## Baseline đã đối chiếu

Probe tạo MainWorld mới trong runner có save/cache riêng, không tải profile cá nhân:

| Dữ liệu hiện tại | Giá trị |
| --- | ---: |
| Xu ban đầu | 1.000 |
| Cột đất mở | 1 |
| Vật nuôi trong map | 11 |
| Hạt ở slot 3 | 12 hạt cà rốt |
| Thời gian lớn của cà rốt | 10 giây |
| Sản lượng một cây | 100 |
| Giá bán một sản phẩm | 5 xu |
| Giá mở cột đất đầu | 15.000 xu |

Một lần thu hoạch cà rốt tương ứng 500 xu theo catalog hiện tại. Đây là số đọc từ Resource và hồ sơ mới, chưa phải thời gian đo chơi từ spawn đến bán/mở đất. Thông số tăng trưởng/sản lượng hiện rất nhanh; phần 0 cần đo trải nghiệm và phần 4 mới chốt cân bằng. Chưa tăng phần thưởng để bù một giả định về thời gian chơi chưa được đo.

## Kiểm chứng và giới hạn

**132/132 bài GUT đạt, 6.050 assertions**, trên 14 suite liên quan. Native staging còn đạt **22/22 kiểm tra input/giao dịch**, không có runtime error/warning trong log thu thập; Web release export thành công. Lint có 0 lỗi/0 cảnh báo. Log, build report và thống kê cuối nằm trong `objectives_1a_2026-10-24/`.

Các test mới kiểm tra commit thật, mưa/restore không đếm, máng tại impact frame, giao dịch thất bại, tiền/flag nguyên tử dưới signal gọi lồng nhau, ví đầy, tiến trình dở dang/chờ nhận/đã nhận, JSON + async repository, rollback, migration và farm cũ đã cuốc kín.

Lượt mở rộng có 7 ca trong suite `test_boosters.gd` bị lỗi fixture: lấy phần tử đầu của đàn trong CoopPen đang rỗng, dẫn đến các ca dùng `animal.growth`/`animal.pen` lỗi và một kỳ vọng mua hàng không còn phù hợp. Log được giữ riêng; chưa coi suite đó đạt hoặc thay đổi map/fixture đó để làm xanh. Log lịch sử này còn ghi một assertion roundtrip 1A so sánh int với float sau JSON; test đã được sửa để so cùng biểu diễn JSON và model chuẩn hóa progress về int, rồi đạt trong lượt 132 test cuối. Các fixture world persistence đã ghi ở audit cũ vẫn cần xử lý riêng. Kiểm tra engine với debugger cũng báo các warning sẵn có ở dependency; báo cáo phân biệt chúng với script mục tiêu mới.

Phần tiếp theo là **1B — HUD và trang mục tiêu**, gồm tiến trình, theo dõi, nhận thưởng và thông báo gọn bằng EN/VI, dùng được trên desktop/mobile. 1A chưa thay thế UI đó, chưa hoàn thành cân bằng hoặc nghiệm thu thiết bị điện thoại thật.
