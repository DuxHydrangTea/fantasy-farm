# Lớn lên, sản xuất phụ phẩm và nhặt vật phẩm

Các scene kế thừa `scenes/animals/animal.tscn` dùng chung vòng đời này cho cả 7 loài.
Animal mới có tuổi 0: cần **24 giờ thực** để trưởng thành, và chết khi đủ
**14 ngày thực tính từ tuổi 0**, bao gồm ngày còn non (13 ngày có thể sản xuất).
Thời gian đóng game vẫn được tính. Tuổi tăng độc lập với no/nước và hover/focus.

Cửa hàng LaiBuon có mục mua/bán vật nuôi. AnimalTradeService tạo actor với
`initial_age_seconds = 0` và gán clock trước khi đưa vào chuồng để bắt đầu tuổi
từ lúc mua. Load khôi phục tuổi từ snapshot và cộng phần offline, không đặt lại tuổi.
Xem [giá và quy tắc giao dịch](shops.md).
Các con đặt sẵn trong map vẫn giữ tuổi khởi tạo 120 giây (2 phút), riêng
`Chicken_8`/`Chicken_9` là 0; tất cả vẫn chưa đủ tuổi trưởng thành theo mốc mới.

## Cấu hình tuổi và sprite

- `AnimalDefinition.maturity_seconds`: số giây để trưởng thành, mặc định 86400 (24 giờ).
- `AnimalDefinition.lifespan_seconds`: tổng tuổi thọ, mặc định 1209600 (14 ngày), phải lớn hơn mốc trưởng thành.
- `Animal.initial_age_seconds`: tuổi ban đầu riêng của từng instance; mặc định
  0 là con non. Gán bằng hoặc lớn hơn `maturity_seconds` để bắt đầu trưởng thành.
- `juvenile_frames`: dùng khi con non và resource có animation idle/walk hợp lệ.
  Nếu thiếu hoặc không hợp lệ, dùng `skin_frames` của con đó, rồi tới `adult_frames`.
- Khi trưởng thành, dùng skin trưởng thành riêng. Nếu cần đổi bộ sprite, đợi
  animal đứng yên để giữ nguyên chuỗi ngồi/ngủ/đứng dậy và hành động ăn/uống.

`AnimalGrowthComponent` giữ tuổi riêng của mỗi con, phát `matured` khi qua mốc
trưởng thành và `lifespan_reached` khi đủ tuổi thọ. Mỗi tín hiệu chỉ phát một lần
khi advance vượt mốc; tuổi dừng tại tuổi thọ. `seconds_until_adult()` và
`seconds_until_death()` trả thời gian còn lại. Configure từ save không phát lại
signal; actor kiểm tra tuổi đã hết ngay cả khi không có thời gian offline.

## Cấu hình phụ phẩm

Gán `production` trong resource của loài. `AnimalProductionDefinition` giữ:

| Thuộc tính | Ý nghĩa |
| --- | --- |
| `production_item` | ItemDefinition của phụ phẩm, loại PRODUCE |
| `production_amount` | Số lượng mỗi chu kỳ, mặc định 1 |
| `production_seconds` | Số giây đủ điều kiện để hoàn tất một chu kỳ |
| `collection_mode` | WORLD_DROP mặc định, hoặc DIRECT_COLLECTION qua API |

Các resource đang cấu hình:

| Loài | Phụ phẩm | Chu kỳ |
| --- | --- | --- |
| Gà | Trứng gà | 30 giây |
| Bò | Sữa bò | 60 giây |
| Vịt | Trứng vịt | 40 giây |
| Ngỗng | Trứng ngỗng | 50 giây |
| Lợn | Nấm truffle | 60 giây |
| Cừu | Len | 60 giây |
| Ngựa | Phân hữu cơ | 60 giây |

Chỉ thời gian vừa **đã trưởng thành**, **còn sống**, vừa có **thức ăn > 0 và nước > 0** mới
được cộng. Khi hết thức ăn/nước, giữ tiến độ đang có và tiếp tục sau khi ăn/uống.
Ví dụ, chu kỳ 30 giây đang đạt 20 giây thì thiếu nước: sau khi có nước chỉ cần
thêm 10 giây hợp lệ, không tính bù khoảng thời gian khát.

Clock chung đi qua một khoảng dài vẫn tính đúng phần trước/sau trưởng thành
và thời điểm thức ăn/nước cạn. Gọi lặp cùng timestamp hoặc lùi timestamp không
tạo thêm tuổi hay vật phẩm. Nhiều chu kỳ được tính bằng một phép chia, không
tạo vòng lặp theo từng sản phẩm. Một lần offline vượt cả mốc trưởng thành và
mốc chết cũng chỉ cộng khoảng giao giữa thời gian đủ no/nước và tuổi 1–14 ngày.

## Khi hết tuổi thọ

Actor dừng AI/di chuyển, nhả reservation ở máng, bỏ khỏi danh sách hover/focus,
khóa cấp thức ăn/nước rồi được xóa khỏi chuồng. `AnimalActor.died` phát một lần
sau khi hoàn tất xử lý và đánh dấu xóa. Không có cơ chế hồi sinh tự động.

Phụ phẩm đã rơi vẫn giữ nguyên. Sản phẩm hoàn tất còn trong kho DIRECT_COLLECTION,
hoặc trứng chờ đưa lên bờ, được chuyển thành pickup (trứng luôn nằm trên bờ).
Phần chu kỳ chưa hoàn tất không tạo thêm sản phẩm. Chết không cộng xu hay trả lại
giá mua. Đói/khát hiện chỉ dừng sản xuất; không làm chết sớm và không kéo dài tuổi thọ.

## Sinh vật phẩm và nhặt vào túi

Các resource hiện dùng WORLD_DROP. Animal tạo `scenes/objects/item_pickup.tscn`
bằng icon sẵn có của item, trong cùng pen và nằm trong giới hạn chuồng. Những
lần sản xuất tiếp theo cộng vào cùng một đống tới khi người chơi nhặt hết;
vật phẩm đã rơi vẫn tồn tại nếu animal bị xóa.

Với vịt/ngỗng có `eggs_on_land` trong PondPen, sản lượng hoàn tất khi ở nước
được giữ ở `ProductionComponent.stored_amount`. WaterfowlComponent đưa chim
lên bờ trước khi actor tạo/cộng đống trứng; không thả trứng xuống ao. Xem
[waterfowl.md](waterfowl.md) cho navigation và animation bơi.

Player có `ItemCollector`: đi lại gần phụ phẩm để tự nhặt vào inventory đang
được hotbar và túi đồ dùng chung. Túi đầy thì vật phẩm ở lại; nếu chỉ nhận được
một phần, phần còn lại vẫn nằm trên đất. Bỏ bớt đồ khi vẫn đứng cạnh sẽ tự thử
nhặt lại, không cần bước ra rồi vào lại. Việc nhặt chống gọi lặp và chống xử lý
đệ quy từ signal inventory, tránh nhân đôi item.

Pickup dùng layer vật lý 4 (bitmask 8), sensor của player chỉ theo dõi layer đó;
animal và các vật thể khác không nhặt được. Component pickup/collector tái sử
dụng được cho item khác ngoài phụ phẩm.

Với DIRECT_COLLECTION, output ở `ProductionComponent.stored_amount`; gọi
`animal.collect_produce(inventory)` để chuyển vào túi, trả về số nhận thực tế
và giữ phần dư. Chế độ này không tự tạo item trên đất.

## Các phần chịu trách nhiệm

- `AnimalNeedsComponent`: đồng hồ, mức no/nước và khoảng thời gian được cấp đủ.
- `AnimalGrowthComponent`: tuổi, mốc trưởng thành và tuổi thọ.
- `AnimalProductionComponent`: chu kỳ, tiến độ, số lượng chờ chuyển ra.
- `Animal` scene/controller: nối các component, lựa chọn sprite và tạo đống phụ phẩm.
- `ItemPickup`, `ItemCollector`: chuyển vật phẩm vào InventoryComponent dùng chung.

## Lưu/tải và thời gian offline

WorldStateAdapter lưu tuổi, no/nước, tiến độ/stock sản xuất và liên kết đống sản
phẩm theo persistent_id. `restore_lifecycle()` đặt lại baseline tại `saved_at`,
nối lại pile rồi đồng bộ tới thời điểm tải, tránh cộng lại thời gian/sản phẩm.
Offline tăng tuổi và chỉ cộng sản xuất trong phần còn sống, đã trưởng thành và đủ cả no/nước, không
giả lập đi lại hoặc tiêu thụ máng. Trứng còn dưới nước vẫn chờ lên bờ sau tải.
Nếu hết tuổi thọ khi offline, actor được xử lý chết ngay trong restore; snapshot
tiếp theo không còn actor đó. Capture cũng bỏ qua actor vừa chết trong chính lần
đồng bộ thời gian, dù queue_free chưa chạy xong cuối frame. `animal_pens` vẫn ghi
chuồng đã khởi tạo để không hồi sinh đàn mẫu. Schema 5 hiện có đã lưu age/saved_at
nên không cần đổi format; tuổi save cũ được giữ, áp các mốc mới khi tải.
Chi tiết schema, backup và phím F5/F9: [saving.md](saving.md).

## Kiểm thử

```sh
python3 tests/run_animal_tests.py --godot /đường/dẫn/tới/godot
```

Runner kiểm tra cả ăn/uống trước đó, tuổi, fallback sprite và đổi sprite an
toàn, phần chu kỳ qua mốc trưởng thành, hết thức ăn/nước, cấp đồ lại sau một
khoảng dài, clock đi lùi/lặp, nhiều chu kỳ, tất cả 7 loài, nhận trực tiếp, gom
vật phẩm, túi đầy, nhặt một phần và sensor thật trên scene player.

`--all` chạy thêm các suite khác. Những lỗi UI/camera headless đã có trên mã
gốc vẫn được báo thất bại bình thường; runner không bỏ qua chúng.

## Animal tonic

A juvenile dose halves the maturity threshold while retaining age and lifespan.
Adult doses enhance one completed production cycle with a 50% chance of +1 item.
See [boosters](boosters.md) for pauses, offline catch-up and save flags.
