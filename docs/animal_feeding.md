# Animal tự tìm máng ăn/uống

`scenes/animals/animal.tscn` có sẵn chức năng này nên chicken, rooster và các
loài dùng scene Animal chung đều tái sử dụng được. Không có controller riêng
cho gà trong luồng ăn/uống mới.

## Các phần chịu trách nhiệm

- `AnimalDefinition`: cấu hình ngưỡng đói/khát và lượng tiêu thụ mỗi lần theo loài.
- `animal_needs_component.gd`: giữ chỉ số no/nước riêng của từng con, giảm theo
  đồng hồ, giới hạn trong 0–100 và phát signal để cập nhật thanh trạng thái.
- `animal_foraging_component.gd`: tìm máng phù hợp trong cùng pen, chọn điểm
  đứng gần nhất đi tới được, giữ chỗ, di chuyển và yêu cầu dùng một suất.
  CoopPen/BarnPen kiểm tra đường thẳng bằng shape; PondPen dùng traversal AStar
  của WaterfowlComponent, tính timeout theo chiều dài route qua các waypoint.
- `animal_trough.gd`: giữ lượng đồ hữu hạn, kiểm tra loài và khẩu phần, quản lý
  chỗ đứng bằng weak reference, trừ đồ khi animal thực sự tới và dùng suất.
- `animal_behaviour_component.gd`: điều phối `seek_resource`, `eat`, `drink`
  cùng các hành vi cũ. Gà đang ngủ/ngồi phải đứng dậy xong mới đi tới máng.

## Cấu hình một loài

Trong resource `animals/definitions/<loài>.tres`:

| Thuộc tính | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `food_seek_threshold` | 50 | Bắt đầu tìm thức ăn khi mức no bằng hoặc thấp hơn ngưỡng |
| `water_seek_threshold` | 50 | Bắt đầu tìm nước khi lượng nước bằng hoặc thấp hơn ngưỡng |
| `food_per_meal` | 1 | Số đơn vị đồ trong máng cần cho một bữa |
| `water_per_drink` | 1 | Số đơn vị nước cần cho một lần uống |

Nếu cả hai nhu cầu đều thấp, ưu tiên chỉ số thấp hơn; bằng nhau ưu tiên nước.
Nếu chưa có máng đáp ứng nhu cầu ưu tiên, animal vẫn có thể phục vụ nhu cầu còn
lại. Mổ đất bình thường vẫn không tự sinh thức ăn.

## Đặt máng trong farm

Instance `scenes/animals/feed_trough.tscn` hoặc `water_trough.tscn` dưới node pen.
Máng tự nhận pen cha; nếu đặt ở vị trí khác thì gán thuộc tính `pen` thủ công.
Animal và máng phải trỏ tới cùng một pen.

Farm hiện có 8 máng: hai máng thức ăn và hai máng nước trong `CoopPen`, một cặp
ăn/nước trong `BarnPen` và một cặp trong `PondPen`. Các máng dùng atlas từ
`assets/Outdoor decoration/Water_Troughs.png`, chỉ phục vụ animal cùng pen.

| Thuộc tính máng | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `capacity`, `stock` | 120 | Sức chứa và lượng có sẵn lúc bắt đầu |
| `restoration_per_unit` | 40 | Số điểm nhu cầu được hồi trên mỗi đơn vị tiêu thụ |
| `serving_seconds` | 1.5 | Thời gian đứng ăn/uống trước khi nhận đồ |
| `allowed_species` | rỗng | Cho mọi loài; điền enum species để giới hạn |
| `access_offsets` | 6 điểm | Điểm đứng quanh máng trong tọa độ local |

Máng thức ăn Coop ghi đè `capacity = 600`, giữ `stock = 120`; máng nước Coop
giữ 120/120. Cả máng ăn và nước Barn/Pond khởi tạo 600/600. Barn giới hạn bò/cừu
và dùng livestock_feed; Pond giới hạn vịt/ngỗng và dùng poultry_feed. Mỗi gói thêm
300 stock. Xem [Barn](barn_animals.md), [Pond](waterfowl.md) và
[tương tác nạp máng](animal_refilling.md).

Điểm đứng phải nằm trong pen, đủ khoảng trống cho footprint của animal. Không
hai con nào được giữ cùng một điểm. Máng đổi sang hình rỗng khi `stock` về 0;
`refill(units)` nạp lại tối đa `capacity` và trả về số đơn vị thực tế đã thêm.
Người chơi đã có thể nạp qua TroughInteraction ở impact frame của hoạt ảnh.

Khi máng hết đồ, bị xóa/di chuyển, animal mất pen hoặc đường đi bị chặn, chuyến
đi bị hủy và chỗ đứng được trả. Máng gây thất bại được bỏ qua 3 giây trước khi
thử lại. Khi chưa có điểm tiếp cận phù hợp, animal tiếp tục hành vi thường và
tìm lại sau; không hồi chỉ số từ xa hay trừ âm lượng đồ trong máng.

## Chạy kiểm thử

```sh
python3 tests/run_animal_tests.py --godot /đường/dẫn/tới/godot
```

Runner dùng GUT đã có trong project, chạy các suite animal, inventory và pickup trong project tạm. Nó
chia sẻ source/asset qua symlink, tách cache/log/user data và bỏ autoload MCP
chỉ trong bản cấu hình tạm, tránh cạnh tranh cổng với editor đang mở. Mở/import
project bằng Godot ít nhất một lần trước khi chạy để có cache class và asset.

Các test bao gồm chọn nhu cầu/máng, khẩu phần và giới hạn loài, cạnh tranh suất
cuối, nhận/trả chỗ, giới hạn pen, ngủ → đứng dậy → tìm máng, phục vụ bò bằng
cùng component, hết đồ/xóa/di chuyển máng, vật cản có sẵn hoặc xuất hiện lúc
đang đi, và việc đặt đủ máng có đồ trong farm.

Thêm `--all` để chạy toàn bộ suite GUT. Một số test UI/camera hiện lỗi trong
môi trường headless cả trên mã trước thay đổi ăn/uống; runner trả exit code
thất bại khi các test đó lỗi.
