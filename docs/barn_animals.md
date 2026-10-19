# Bò và cừu sống chung

`scenes/animals/cow.tscn` và `sheep.tscn` kế thừa `animal.tscn`, dùng toàn bộ
component di chuyển, animation, sinh hoạt, đói/khát, tìm máng, trưởng thành và
sản xuất hiện có. Không có AI hoặc bộ đếm thời gian riêng cho từng loài.

MainWorld có `BarnPen` tại `(1008, 592)`, bounds `(0, 0, 384, 272)` nằm bên trong
rào đá lớn quanh Barn. Cả 9 màu bò và 9 màu cừu cùng thuộc Pen này, dùng chung
máng ăn và nước. Các con được đặt sẵn ở tuổi trưởng thành 120 giây để bắt đầu
sản xuất ngay. Scene bò/cừu riêng vẫn mặc định tuổi 0 như scene vật nuôi chung.

## Sản phẩm

| Loài | Resource cấu hình | Sản phẩm | Chu kỳ |
| --- | --- | --- | --- |
| Bò | `animals/productions/cow_milk_production.tres` | Sữa bò (`cow_milk`) | 60 giây |
| Cừu | `animals/productions/sheep_wool_production.tres` | Lông cừu (`sheep_wool`) | 60 giây |

Dùng timestamp từ TimeManager và luồng `Needs.time_advanced` hiện có. Chỉ thời
gian đã trưởng thành và còn cả thức ăn/nước mới tính vào chu kỳ. Hết một chỉ số
sẽ tạm dừng; cho ăn/uống tiếp tục từ tiến độ đang có, không cộng bù thời gian đói.

Sản phẩm dùng WORLD_DROP: mỗi con có một đống vật phẩm trên đất, các lượt tiếp
theo cộng số lượng vào đống đó. Người chơi đi gần để ItemCollector nhặt vào
inventory. Túi đầy thì sản phẩm còn trên đất; không mất hoặc nhân đôi sản lượng.
Chu kỳ, số lượng và chế độ thu có thể đổi trong resource sản phẩm của từng loài.

## Máng dùng chung

Hai máng ban đầu có 600 đơn vị mỗi loại, cho phép bò và cừu; slot ăn/uống được
đặt cách collider đủ cho kích thước chân của bò. Reservation giữ từng chỗ riêng
cho từng con. Vật nuôi chỉ tìm máng cùng Pen, nên không lấy thức ăn ở Coop.

Máng ăn dùng `items/feeds/livestock_feed.tres` (Thức ăn gia súc), mỗi gói thêm
300 đơn vị. Có 5 gói trong một pickup gần cửa rào bên trái Barn để người chơi
nhặt. Đứng cạnh máng rồi nhấn E để bổ sung; nước dùng bình tưới và E theo hệ
thống refill đang có. Máng ăn gia cầm ở Coop giữ cấu hình riêng.

Bò/cừu dùng lại hai thanh no/nước có khung pixel giống cây trồng. Bò có chân
18×10, tốc độ 22; cừu chân 14×8, tốc độ 26. Các dữ liệu khác vẫn lấy từ định nghĩa
loài và có thể sửa trong Inspector.

## Kiểm tra

`tests/integration/test_barn_animals.gd`: đủ 9 skin mỗi loài trong cùng Pen,
chu kỳ thật 60 giây, bắt kịp timestamp, tạm ngừng khi đói, nhặt sữa/lông qua sensor,
túi đầy, dùng chung máng nhưng không trùng reservation, cách ly Pen và thêm thức ăn.

Preview (tạo một lượt sản phẩm chỉ trong phiên preview):
`godot --path . -s tests/support/barn_preview.gd`.
