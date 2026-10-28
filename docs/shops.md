# Cửa hàng và tiền xu

## Cách dùng

Khu cửa hàng nằm thành một dãy phía trên vườn hoa. Mỗi cửa hàng có một NPC,
catalog và các mục giao dịch riêng:

| Cửa hàng | NPC / ngoại hình | Mục giao dịch | Catalog |
|---|---|---|---|
| Hạt giống | `LaiBuon` / Katy | Hạt cây trồng, vật tư trồng trọt | `seed_flower_shop.tres` |
| Hoa | `FlowerMerchant` / Bruno | 30 loại hạt hoa | `flower_shop.tres` |
| Vật nuôi | `PetMerchant` / Jack | Mua vật nuôi, bán vật nuôi, thức ăn và thuốc vật nuôi | `pet_shop.tres` |
| Lò rèn | `BlacksmithMerchant` / Mike | Mua nông cụ, nâng cấp nông cụ, gỗ | `blacksmith.tres` |

Các catalog nằm trong `resources/shops/`. Thuộc tính `ShopCatalog.category_ids`
quy định các mục được phép và thứ tự tab; `display_name` là tiêu đề được dịch.
Mỗi `ShopService` chỉ nhận offer thuộc catalog của NPC đang giao dịch.
Đứng trong phạm vi 48 pixel, quay mặt về NPC rồi nhấn **E** (hoặc action `interact` trên tay cầm).
Có thể click trực tiếp sprite NPC để tự tìm đường đến và mở menu khi đã tới gần.
Outline và huy hiệu dùng chung với [hệ thống tương tác](unified_interaction.md).
Các NPC có scene riêng trong `scenes/characters/`, dùng chung `ShopMerchant`,
`ShopUI` và vòng đời menu. Asset: `crop_flower_shop_red.png`,
`pet_shop_pigpen.png`, `Blacksmith_House_Black.png` và
`assets/Buildings/Extracted/VillageSet/flower_shop.png`.
Shop hoa và Bruno đứng bên phải shop hạt giống; vị trí các shop khác được giữ
theo bố cục đã soạn trong bản đồ. Catalog của LaiBuon không còn mục hạt hoa.
Chọn hàng, số lượng 1–99 rồi nhấn Mua (vật nuôi còn bị giới hạn bởi sức chứa chuồng).
Để bán, mở **Bán vật nuôi**, chọn đúng cá thể rồi nhấn nút Bán; mỗi lần bán một con.
Sau một lần bán phải chọn lại cá thể khác, tránh bấm lặp làm bán nhầm con kế tiếp.
Esc, E, Tab/I hoặc nút × đóng menu. Khi cửa hàng mở, di chuyển, click đi tới,
nông cụ, hotbar và zoom đều bị khóa; inventory không mở chồng lên cửa hàng.
Các phím lưu/tải vẫn hoạt động. Load đóng cửa hàng và không phát lời cảm ơn.

Menu dùng `game_theme.tres`, Upheaval và khung/ô của sprite UI hiện có.
Số dư xu chỉ hiển thị trong túi đồ. Cửa hàng giữ giá hàng và tổng giao dịch. NPC chỉ cảm ơn sau khi
**có ít nhất một giao dịch thành công trong lượt mở đó và menu đã đóng**.
Bong bóng tồn tại 3,5 giây; mở cửa hàng lại sẽ ẩn và bắt đầu lượt mới.

## Danh mục và giá ban đầu

Bốn catalog riêng giữ đủ hàng hóa và giá từ `farm_supply.tres`: 22 hạt cây trồng,
30 hạt hoa, cây giống, phân bón, tổ ong, thức ăn, thuốc vật nuôi, rìu và gỗ.
Lò rèn bổ sung cuốc và bình tưới, mỗi nông cụ có giá 250 xu.
`farm_supply.tres` được giữ làm catalog tổng cho kiểm thử/tương thích;
NPC trên bản đồ dùng các catalog riêng, không quét thư mục khi game chạy.
Giá tính cho một vật phẩm; thức ăn vẫn dùng lượng dinh dưỡng hiện có của item.
Chỉnh `price`, `category`, `item` trong Resource để đổi hàng bán. Hàng không giới hạn.

Bán vật nuôi tại `PetMerchant`; bán nông sản tại `ProduceBuyer` gần nhà bếp.

## Mua và bán vật nuôi

`ShopCatalog.animal_offers` khai báo 7 `AnimalShopOffer` riêng tại `resources/shops/animals/`.
Giá bán cố định bằng 50% giá mua cho con non, 75% cho con trưởng thành (làm tròn xuống).

| Loài | Mua (xu) | Bán con non | Bán trưởng thành | Chuồng |
|---|---:|---:|---:|---|
| Gà | 160 | 80 | 120 | CoopPen |
| Vịt | 240 | 120 | 180 | PondPen |
| Ngỗng | 320 | 160 | 240 | PondPen |
| Lợn | 480 | 240 | 360 | BarnPen |
| Cừu | 560 | 280 | 420 | BarnPen |
| Bò | 720 | 360 | 540 | BarnPen |
| Ngựa | 960 | 480 | 720 | BarnPen |

Mua thành công đưa con vật trực tiếp vào chuồng, không chiếm inventory. Cá thể có ID mới,
tuổi 0 và clock của nông trại: sau 24 giờ thực trưởng thành, đủ 14 ngày tuổi thì chết.
Giữ nguyên no/nước, chu kỳ phụ phẩm và quy tắc offline trong [vòng đời](animal_lifecycle.md).

`AnimalPen.accepted_species` và `capacity` cấu hình bằng Inspector. MainWorld có sức chứa
30 ở CoopPen (gà), 36 ở BarnPen (bò/cừu/lợn/ngựa), 20 ở PondPen (vịt/ngỗng).
Số lượng tính cả con non và trưởng thành đang sống. Đàn cũ vượt sức chứa vẫn được giữ;
chỉ chặn mua thêm. Pen chưa cấu hình loài không nhận giao dịch.

Service kiểm tra toàn bộ số lượng trước khi trừ tiền; tìm vị trí trong bounds, không
đè collision/vật nuôi hiện có, kể cả nhiều lượt mua trong cùng frame. Chim ao được
thả trên bờ có navigation hợp lệ. Không có pen phù hợp, chuồng đầy, không còn vị trí
hoặc thiếu xu thì không trừ tiền và không thêm một phần đàn.

Danh sách bán hiển thị từng cá thể và chi tiết tuổi/thời gian sống còn lại khi chọn.
Chỉ bán con đang sống trong chính nông trại của khách; chốt clock lần nữa khi bấm Bán
để không bán được con vừa hết tuổi thọ. Bán nhả chỗ ở máng, dừng AI và xóa cá thể,
không phát signal `died`. Phụ phẩm hoàn tất vẫn là pickup; trứng chờ dưới ao được
đưa lên bờ. Tiến độ phụ phẩm chưa hoàn tất không đổi thành xu.

## Trách nhiệm và giao dịch

- `WalletComponent`: số nguyên 0–1.000.000.000, tín hiệu thay đổi và API cộng xu.
- `ShopCatalog` / `ShopOffer` / `AnimalShopOffer`: dữ liệu hàng bán dùng lại giữa các NPC.
- `ShopService`: lệnh mua duy nhất, kiểm tra danh mục, số lượng, giá, tiền và
  sức chứa; chuẩn bị toàn bộ slot trước khi commit. Thất bại không trừ tiền,
  không thêm một phần vật phẩm. Chặn gọi mua lồng nhau trong thông báo.
- `ShopUI`: hiển thị báo giá, gọi lệnh mua và ghi nhận thành công trong lượt mở.
- `AnimalTradeService`: kiểm tra loài/chuồng/vị trí, mua đàn con non và bán cá thể;
  chặn reentry, ví tràn và bán lặp. Signal ví chỉ phát sau khi cả xu và đàn đã commit.
- `PlayerInteractionComponent` / `InteractionResolver`: chọn một mục tiêu theo
  hướng nhìn và ưu tiên NPC/biển > máng > vật nuôi > thu hoạch; click chốt chính NPC
  đã chọn và mở menu sau khi tới gần. `ShopInteraction` giữ adapter menu cũ.
- `ShopMerchant`: sprite, collision, gợi ý E và lời cảm ơn sau đóng menu.

Service độc lập với UI/file IO để dễ thay bằng lệnh online sau này. Khi có server,
server phải sở hữu giá, ví và inventory và commit cả giao dịch; kiểm tra phía client
hiện tại là logic chơi offline, không phải cơ chế chống gian lận online.

`AnimalTradeService.new(catalog, wallet, farm_root, clock)` nhận tham chiếu có kiểu;
chỉ dùng các AnimalPen con trực tiếp của farm_root. API gồm `quote_buy(offer, quantity)`,
`buy(offer, quantity)`, `owned_animals()`, `quote_sell(animal)` và `sell(animal)`.
Các lệnh trả Dictionary có `ok`, `error` khi thất bại và `total` khi thành công;
buy còn trả `animals`/`quantity`. Quote không thay đổi đàn/ví; buy/sell kiểm tra lại tại commit.

## Save và kiểm thử

Save schema 4 thêm trường primitive `coins`; schema 5 mở rộng túi 24 → 64 ô, schema 8 lưu thức ăn dư của máng và schema hiện tại **9** lưu tổ ong cùng tăng trưởng do thụ phấn. Save v1/v2 đi qua các migration
cũ; v3 được cấp 1.000 xu đúng một lần. V4 trở lên bắt buộc số nguyên trong phạm vi ví,
kể cả số dư 0; tải lại không cấp xu thêm. Migration không sửa DTO đầu vào.
WorldStateAdapter chụp/khôi phục ví cùng inventory, dùng repository và checksum cũ.
Animal mới và số xu được lưu bằng schema hiện có; con đã bán không còn trong snapshot,
`animal_pens` giữ chuồng đã khởi tạo nên tải lại không hồi sinh con đó. Phụ phẩm còn lại
được lưu độc lập. Tuổi sau mua tiếp tục tăng khi offline, không bị đặt lại khi mở shop/load.

GUT bổ sung test giao dịch, đầy túi, thiếu tiền, số lượng sai, reentry, danh mục,
modal input, khoảng cách, lời cảm ơn, tháo NPC, layout Full HD, migration và
roundtrip file sau mua. Các fixture file nằm trong `.godot`; không sửa save thật.
`test_animal_trade_service.gd` kiểm tra mua nhiều con, đầy/thiếu/bị chặn chuồng, vị trí
khác nhau cùng frame, giá bán theo tuổi, giao dịch lồng nhau, ví tràn và hết tuổi thọ tại
checkout. Integration kiểm tra đủ 7 loài trên map thật, thao tác hai tab và lưu/tải sau mua/bán.

## Giao diện cửa sổ nhỏ và thông tin cá thể

Menu dùng `UIScaleComponent` riêng cho CanvasLayer, không đổi camera. Ở cửa sổ
500×400, menu gần kín vùng nội dung, chữ và thẻ hàng lớn hơn. Bố cục chia danh
sách hàng và mô tả thành hai vùng cuộn riêng; hàng số lượng/Mua/Bán và nút đóng
luôn ở ngoài vùng cuộn. Các tab thu gọn tên khi thiếu diện tích, tooltip giữ tên
đầy đủ. Đổi kích thước hoặc ngôn ngữ giữ nguyên nhóm, mặt hàng/cá thể và số lượng.

Khi chọn cá thể để bán, phần mô tả dùng chung `AnimalStatusText` với bảng hover/focus:
thời gian trưởng thành, tuổi thọ còn lại, phần trăm chu kỳ sản xuất và các lý do
tạm dừng. Giá bán nằm trên nút xác nhận. Thẻ giữ WeakRef và
kiểm tra cá thể còn sống trước khi chọn/giao dịch để không gọi vào Node đã bị xóa.
Xem [animal_status_ui.md](animal_status_ui.md).

## NPC thu mua nông sản

`ProduceBuyer` là instance của scene riêng tại `(1445, 206)`, dùng avatar Farmer Buba. Đến gần NPC
cần giao dịch rồi nhấn E. Menu riêng có **Sell quantity** cho loại đang chọn và
**Sell all produce** cho toàn bộ mặt hàng được thu mua trong túi; đều hiển thị
số xu nhận trước khi bán. Bảng giá, phạm vi thu mua và quy tắc giao dịch được mô
tả tại [produce_sales.md](produce_sales.md).

Crop Fertilizer (5 coins) is sold by the seed/flower merchant; Animal Tonic
(3 coins) is sold by the animal merchant. See [boosters](boosters.md).

## Beehives and honey

Supplies / Farm supplies now includes a placeable Beehive for 1,500 coins. The
produce buyer accepts Wild Honey (150), Sunflower Honey (225) and Floral Honey
(300), using the same quantity/bulk sale flow. See [beehives](beehives.md).
