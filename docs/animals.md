# Vật nuôi

Scene dùng: `scenes/animals/chicken.tscn` và `scenes/animals/rooster.tscn`.
MainWorld có 18 con gà trong `CoopPen`: 9 gà mái mang 9 màu lông khác nhau (`Chicken_01`…`Chicken_09`) và 9 gà trống (`Rooster`), ở khu hàng rào bên phải, cạnh công trình Coop hiện có.

## Thành phần dùng chung

- `animal.tscn` / `AnimalActor`: nối dữ liệu loài, collider chân, sprite và UI.
- `MovementComponent`, `AnimationComponent`: dùng chung với nhân vật hiện tại.
- `AnimalWanderComponent`: chọn đích và di chuyển; chọn đích khác khi bị vật cản
  chặn. Kiểm tra collider tại đích, dùng `move_and_slide` khi di chuyển.
- `AnimalBehaviourComponent`: quyết định đi, đứng, mổ đất/gặm cỏ, nằm nghỉ hoặc
  ngủ; chỉ gọi Wander khi đang đi. Đây là nơi sở hữu state và thời gian hành vi.
- `AnimalNeedsComponent`: no (`satiety`) và nước (`hydration`), mỗi con giữ riêng.
- `AnimalPen`: giới hạn cứng vùng đi lại; áp dụng cả khi hàng rào có khoảng hở.
- `AnimalDefinition`: tốc độ, thời gian nghỉ, kích thước chân, khoảng cách mép rào,
  thời gian tiêu hao thức ăn/nước và SpriteFrames. Không gắn logic riêng theo loài
  trong các component.

Scene gà kế thừa scene chung và gán `animals/definitions/chicken.tres`.
`skin_frames` có thể gán bất kỳ bộ `chicken_01_frames`…`chicken_18_frames`;
skin thiếu idle/walk tự dùng lại bộ mặc định. Hình gốc nhìn trái; quay phải lật
sprite, giữ hướng khi đi dọc. Sprite được neo chân từ vùng pixel không trong suốt.

## Vùng chuồng

`MainWorld/CoopPen` ở `(1008, 288)`, bounds local `(0, 0, 384, 256)` nằm trong
hàng rào `(62,17)`…`(87,34)`. Scene Pen có Y-sort để gà và công trình sắp theo chân.
Vùng xanh nhạt chỉ vẽ trong editor. Di chuyển Pen hoặc sửa Bounds ở Inspector để
đổi vùng; nó hỗ trợ tịnh tiến, xoay, scale. Đặt vật nuôi làm con của Pen sẽ tự nhận
vùng; hoặc gán thuộc tính `pen` khi đặt vật nuôi ở nơi khác trong scene tree.

Vật nuôi không được gán Pen sẽ đứng yên. Nếu bị đẩy hoặc đặt ra ngoài vùng,
component đưa nó về trong vùng và chọn lại đích. Công trình/vật cản ở Layer 1 (World) vẫn được xét va chạm bình thường.
Vật nuôi nằm ở Layer 3 (Animal) và chỉ quét va chạm với Layer 1; người chơi nằm ở Layer 2 (Player) và cũng chỉ quét Layer 1, giúp gà đi xuyên qua nhau và xuyên qua người chơi mượt mà không bị cản trở.
AI hiện chọn đường thẳng và chọn lại khi bị chặn, chưa tìm đường qua mê cung.

## Đói và khát

Hai giá trị là **mức còn lại**, từ 0 đến 100: càng thấp càng đói/khát.
Thanh cam phía trên biểu diễn độ no, thanh xanh bên dưới biểu diễn nước,
được bọc trong khung viền pixel art (`assets/Ui/progress_bar.png`) đồng bộ với cây trồng.
`show_needs` bật/tắt hiển thị. Gà mất hết độ no sau 600 giây, hết nước sau
300 giây theo cấu hình hiện có; từng loài có thể đổi các thông số này.

Component dùng Unix timestamp của TimeManager, không phụ thuộc FPS. Thời gian
pause/mở túi vẫn tính vào nhu cầu khi cập nhật tiếp, đồng bộ cách tính của cây.
Timestamp lặp/lùi không trừ hai lần; giá trị luôn giới hạn trong 0…100.

`needs.feed(25.0)` / `needs.drink(25.0)` hồi chỉ số và trả về lượng hồi thực tế.
Đây là điểm nối để bổ sung máng ăn/máng nước; chưa có thao tác tự ăn/uống,
chết, sinh sản, trưởng thành, tạo sản phẩm hay save/load trong lượt này.
Các resource sản phẩm cũ được giữ để các định nghĩa loài hiện có tải đúng.

## Trạng thái sinh hoạt

Vật nuôi bắt đầu bằng một lượt đi trong chuồng, rồi tự chọn hành vi xen kẽ.
Các trọng số trong `AnimalDefinition → Behaviour` mặc định là đi 5, kiếm ăn 3,
nằm nghỉ 1, ngủ 1. Thời gian mổ đất 1,5–3,5 giây; nghỉ 2–4 giây; ngủ 4–8 giây.
Có thể thay trọng số/thời gian theo loài mà không sửa controller.

- `IDLE` / `WALK`: đứng yên / đi trong vùng chuồng.
- `FORAGE`: gà phát `peck_down`; loài khác tự chọn `graze_down` hoặc `chew_down`.
- Nằm nghỉ: `LIE_DOWN` (animation `sit_down` hoặc `lie_down_down`) → `REST`
  (giữ frame cuối) → `STAND_UP` → `IDLE`.
- Ngủ: `LIE_DOWN` → `SLEEP_START` → `SLEEP` → `STAND_UP` → `IDLE`.

Các animation nằm xuống/vào giấc/đứng lên chờ tín hiệu hoàn tất thật, không dùng
thời gian giả định; do đó skin chạy 5 FPS hoặc 8 FPS vẫn nối đúng. Gà không đi
trong lúc mổ đất, nằm hoặc ngủ; ranh giới chuồng vẫn được kiểm tra ở mọi state.
Mổ đất hiện là hành vi sinh hoạt, không cộng thức ăn. Chưa gắn giấc ngủ với ngày/đêm.

Code có thể gọi `animal.behaviour.request_behaviour(&"forage")`, `&"rest"`,
`&"sleep"`, `&"walk"` hoặc `&"idle"`. Con vật đã nằm phải `wake()` và chạy xong
đứng lên trước khi nhận hành vi đứng/đi. Tín hiệu `state_changed` phục vụ UI/debug.

Mapping `forage_action` / `lie_down_action` để trống sẽ dò các animation có sẵn;
cũng có thể gán tên action cụ thể (không kèm `_down`). Loại không có animation
phụ tương ứng sẽ bỏ qua hành vi đó. Transition bị cấu hình loop không được chọn,
tránh bị kẹt chờ một tín hiệu hoàn tất không phát ra.

## Thêm bò, cừu, lợn

Tạo scene kế thừa `animal.tscn`, gán definition tương ứng, chỉnh move_speed,
footprint, pen_margin, thời gian nghỉ và nhu cầu theo loài. Đặt instance dưới Pen
phù hợp. Không cần sao chép AI, logic đói/khát hoặc animation controller.

## Kiểm tra

GUT kiểm tra tiêu hao/hồi nhu cầu, timestamp lặp/lùi, độc lập giữa các con,
giới hạn Pen có transform, đi lại thật qua physics frames, va chạm công trình,
lật sprite, đứng yên khi thiếu Pen, skin và khả năng dùng definition bò/cừu/lợn.

`godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`

Preview thủ công: `godot --path . -s tests/support/animal_preview.gd`.
