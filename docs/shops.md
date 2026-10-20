# Cửa hàng và tiền xu

## Cách dùng

Cửa hàng được gắn trực tiếp vào node `MainWorld/LaiBuon` có sẵn, tại
`(1779, 214)`, cạnh hai quầy hàng phía trên vườn hoa. Giữ nguyên sprite và
collision của nhân vật. Điểm tương tác lệch `(-38, 10)` theo vị trí sprite thực;
đến trong phạm vi 48 pixel rồi nhấn **E** (hoặc action `interact` trên tay cầm).
`ShopMerchant` thêm phần menu/bong bóng từ `scenes/ui/merchant_interaction.tscn`
vào chính NPC khi chạy. Không sinh thêm NPC Buba.
Chọn một trong ba nhóm, chọn vật phẩm, số lượng 1–99 rồi nhấn Mua.
Esc, E, Tab/I hoặc nút × đóng menu. Khi cửa hàng mở, di chuyển, click đi tới,
nông cụ, hotbar và zoom đều bị khóa; inventory không mở chồng lên cửa hàng.
Các phím lưu/tải vẫn hoạt động. Load đóng cửa hàng và không phát lời cảm ơn.

Menu dùng `game_theme.tres`, Pixelify Sans và khung/ô của sprite UI hiện có.
Xu hiển thị góc trên bên phải và trong cửa hàng. NPC chỉ cảm ơn sau khi
**có ít nhất một giao dịch thành công trong lượt mở đó và menu đã đóng**.
Bong bóng tồn tại 3,5 giây; mở cửa hàng lại sẽ ẩn và bắt đầu lượt mới.

## Danh mục và giá ban đầu

`resources/shops/farm_supply.tres` khai báo rõ 34 `ShopOffer`, không quét thư mục
khi game chạy: 22 hạt cây trồng (10 xu), 10 hạt hoa (15 xu), 2 thức ăn (25 xu).
Giá tính cho một vật phẩm; thức ăn vẫn dùng lượng dinh dưỡng hiện có của item.
Chỉnh `price`, `category`, `item` trong Resource để đổi hàng bán. Hàng không giới hạn.

Game mới có 1.000 xu. Chưa thêm bán nông sản hoặc nguồn thu xu khác trong tính năng này.

## Trách nhiệm và giao dịch

- `WalletComponent`: số nguyên 0–1.000.000.000, tín hiệu thay đổi và API cộng xu.
- `ShopCatalog` / `ShopOffer`: dữ liệu hàng bán dùng lại giữa các NPC.
- `ShopService`: lệnh mua duy nhất, kiểm tra danh mục, số lượng, giá, tiền và
  sức chứa; chuẩn bị toàn bộ slot trước khi commit. Thất bại không trừ tiền,
  không thêm một phần vật phẩm. Chặn gọi mua lồng nhau trong thông báo.
- `ShopUI`: hiển thị báo giá, gọi lệnh mua và ghi nhận thành công trong lượt mở.
- `ShopInteraction`: chọn NPC gần nhất; StateComponent ưu tiên mở shop trước
  hành động thu hoạch của E. Ngoài phạm vi NPC, E giữ chức năng cũ.
- `ShopMerchant`: sprite, collision, gợi ý E và lời cảm ơn sau đóng menu.

Service độc lập với UI/file IO để dễ thay bằng lệnh online sau này. Khi có server,
server phải sở hữu giá, ví và inventory và commit cả giao dịch; kiểm tra phía client
hiện tại là logic chơi offline, không phải cơ chế chống gian lận online.

## Save và kiểm thử

Save schema 4 thêm trường primitive `coins`; schema hiện tại **5** mở rộng túi 24 → 64 ô. Save v1/v2 đi qua các migration
cũ; v3 được cấp 1.000 xu đúng một lần. V4 trở lên bắt buộc số nguyên trong phạm vi ví,
kể cả số dư 0; tải lại không cấp xu thêm. Migration không sửa DTO đầu vào.
WorldStateAdapter chụp/khôi phục ví cùng inventory, dùng repository và checksum cũ.

GUT bổ sung test giao dịch, đầy túi, thiếu tiền, số lượng sai, reentry, danh mục,
modal input, khoảng cách, lời cảm ơn, tháo NPC, layout Full HD, migration và
roundtrip file sau mua. Các fixture file nằm trong `.godot`; không sửa save thật.
